import time
import uuid

import jwt
import pytest
from fastapi.testclient import TestClient

from app.database.session import SessionLocal
from app.main import app
from app.models.app_user import AppUser
from app.models.household import Household, HouseholdMember
from app.models.pluggy_connection import PluggyConnection, SyncJob
from app.settings import settings


class _FakePluggyClient:
    def __init__(self, item_status: str = "UPDATED", token: str = "fake-connect-token"):
        self._item_status = item_status
        self._token = token

    async def authenticate(self):
        return "fake-api-key"

    async def create_connect_token(self, client_user_id, item_id=None, webhook_url=None):
        return self._token

    async def get_item(self, item_id):
        return {"id": item_id, "status": self._item_status}


@pytest.fixture(autouse=True)
def hs256_secret(monkeypatch):
    monkeypatch.setattr(settings, "supabase_url", "")
    monkeypatch.setattr(settings, "supabase_jwt_secret", "test-secret")
    monkeypatch.setattr(settings, "supabase_jwt_audience", "authenticated")
    monkeypatch.setattr(settings, "supabase_jwt_issuer", "")


@pytest.fixture(autouse=True)
def fake_pluggy(monkeypatch):
    monkeypatch.setattr(
        "app.api.connections._pluggy_client", lambda: _FakePluggyClient()
    )


@pytest.fixture
def client():
    return TestClient(app)


@pytest.fixture
def make_user():
    created_provider_ids = []

    def _make(email):
        provider_user_id = str(uuid.uuid4())
        created_provider_ids.append(provider_user_id)
        token = jwt.encode(
            {
                "sub": provider_user_id,
                "email": email,
                "aud": "authenticated",
                "exp": int(time.time()) + 3600,
            },
            "test-secret",
            algorithm="HS256",
        )
        return {"Authorization": f"Bearer {token}"}

    yield _make

    db = SessionLocal()
    app_user_ids = [
        row.id
        for row in db.query(AppUser)
        .filter(AppUser.auth_provider_user_id.in_(created_provider_ids))
        .all()
    ]
    if app_user_ids:
        household_ids = [
            row.household_id
            for row in db.query(HouseholdMember)
            .filter(HouseholdMember.app_user_id.in_(app_user_ids))
            .all()
        ]
        if household_ids:
            db.query(SyncJob).filter(
                SyncJob.household_id.in_(household_ids)
            ).delete(synchronize_session=False)
            db.query(PluggyConnection).filter(
                PluggyConnection.household_id.in_(household_ids)
            ).delete(synchronize_session=False)
        db.query(HouseholdMember).filter(
            HouseholdMember.app_user_id.in_(app_user_ids)
        ).delete(synchronize_session=False)
        if household_ids:
            db.query(Household).filter(Household.id.in_(household_ids)).delete(
                synchronize_session=False
            )
        db.query(AppUser).filter(AppUser.id.in_(app_user_ids)).delete(
            synchronize_session=False
        )
    db.commit()
    db.close()


def test_owner_can_create_connect_token(client, make_user):
    headers = make_user("owner@example.com")
    household = client.post(
        "/v1/households", json={"name": "Elliot Family"}, headers=headers
    ).json()

    response = client.post(
        f"/v1/households/{household['id']}/connections/token", headers=headers
    )

    assert response.status_code == 200
    assert response.json()["connect_token"] == "fake-connect-token"


def test_non_member_cannot_create_connect_token(client, make_user):
    headers_a = make_user("familya@example.com")
    headers_b = make_user("familyb@example.com")
    household = client.post(
        "/v1/households", json={"name": "Family A"}, headers=headers_a
    ).json()

    response = client.post(
        f"/v1/households/{household['id']}/connections/token", headers=headers_b
    )

    assert response.status_code == 403


def test_viewer_cannot_create_connect_token(client, make_user):
    headers_owner = make_user("owner2@example.com")
    headers_viewer = make_user("viewer2@example.com")
    household = client.post(
        "/v1/households", json={"name": "Viewer Family"}, headers=headers_owner
    ).json()
    client.get("/v1/me", headers=headers_viewer)  # ensure the app_users row exists

    db = SessionLocal()
    viewer_user = (
        db.query(AppUser)
        .filter(AppUser.email == "viewer2@example.com")
        .one()
    )
    db.add(
        HouseholdMember(
            household_id=household["id"], app_user_id=viewer_user.id, role="viewer"
        )
    )
    db.commit()
    db.close()

    response = client.post(
        f"/v1/households/{household['id']}/connections/token", headers=headers_viewer
    )

    assert response.status_code == 403


def test_create_connection_creates_row_and_queued_sync_job(client, make_user):
    headers = make_user("sync@example.com")
    household = client.post(
        "/v1/households", json={"name": "Sync Family"}, headers=headers
    ).json()

    response = client.post(
        f"/v1/households/{household['id']}/connections",
        json={"pluggy_item_id": "item-123"},
        headers=headers,
    )

    assert response.status_code == 201
    body = response.json()
    assert body["pluggy_item_id"] == "item-123"
    assert body["status"] == "UPDATED"
    assert body["created_by"]["email"] == "sync@example.com"

    db = SessionLocal()
    jobs = (
        db.query(SyncJob)
        .filter(SyncJob.household_id == household["id"])
        .all()
    )
    db.close()
    assert len(jobs) == 1
    assert jobs[0].status == "queued"


def test_create_connection_duplicate_is_conflict(client, make_user):
    headers = make_user("dup@example.com")
    household = client.post(
        "/v1/households", json={"name": "Dup Family"}, headers=headers
    ).json()

    first = client.post(
        f"/v1/households/{household['id']}/connections",
        json={"pluggy_item_id": "item-dup"},
        headers=headers,
    )
    second = client.post(
        f"/v1/households/{household['id']}/connections",
        json={"pluggy_item_id": "item-dup"},
        headers=headers,
    )

    assert first.status_code == 201
    assert second.status_code == 409


def test_connections_are_attributed_to_the_member_who_created_them(client, make_user):
    headers_a = make_user("membera@example.com")
    headers_b = make_user("memberb@example.com")
    household = client.post(
        "/v1/households", json={"name": "Attribution Family"}, headers=headers_a
    ).json()

    client.get("/v1/me", headers=headers_b)  # ensure the app_users row exists

    db = SessionLocal()
    member_b = db.query(AppUser).filter(AppUser.email == "memberb@example.com").one()
    db.add(
        HouseholdMember(
            household_id=household["id"], app_user_id=member_b.id, role="member"
        )
    )
    db.commit()
    db.close()

    client.post(
        f"/v1/households/{household['id']}/connections",
        json={"pluggy_item_id": "item-a1"},
        headers=headers_a,
    )
    client.post(
        f"/v1/households/{household['id']}/connections",
        json={"pluggy_item_id": "item-a2"},
        headers=headers_a,
    )
    client.post(
        f"/v1/households/{household['id']}/connections",
        json={"pluggy_item_id": "item-b1"},
        headers=headers_b,
    )

    response = client.get(
        f"/v1/households/{household['id']}/connections", headers=headers_a
    )
    assert response.status_code == 200
    by_item = {c["pluggy_item_id"]: c["created_by"]["email"] for c in response.json()}
    assert by_item == {
        "item-a1": "membera@example.com",
        "item-a2": "membera@example.com",
        "item-b1": "memberb@example.com",
    }


def test_family_a_cannot_list_family_b_connections(client, make_user):
    headers_a = make_user("isoa@example.com")
    headers_b = make_user("isob@example.com")
    household_a = client.post(
        "/v1/households", json={"name": "Iso Family A"}, headers=headers_a
    ).json()
    client.post(
        f"/v1/households/{household_a['id']}/connections",
        json={"pluggy_item_id": "item-iso"},
        headers=headers_a,
    )

    response = client.get(
        f"/v1/households/{household_a['id']}/connections", headers=headers_b
    )

    assert response.status_code == 403


def test_connections_require_authentication(client):
    fake_id = uuid.uuid4()
    assert client.get(f"/v1/households/{fake_id}/connections").status_code in (401, 403)
    assert client.post(f"/v1/households/{fake_id}/connections/token").status_code in (
        401,
        403,
    )
