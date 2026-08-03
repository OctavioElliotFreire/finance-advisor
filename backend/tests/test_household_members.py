import time
import uuid

import jwt
import pytest
from fastapi.testclient import TestClient

from app.database.session import SessionLocal
from app.main import app
from app.models.app_user import AppUser
from app.models.household import Household, HouseholdMember
from app.settings import settings


@pytest.fixture(autouse=True)
def hs256_secret(monkeypatch):
    monkeypatch.setattr(settings, "supabase_url", "")
    monkeypatch.setattr(settings, "supabase_jwt_secret", "test-secret")
    monkeypatch.setattr(settings, "supabase_jwt_audience", "authenticated")
    monkeypatch.setattr(settings, "supabase_jwt_issuer", "")


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


def test_owner_can_invite_existing_user_as_member(client, make_user):
    headers_owner = make_user("owner3@example.com")
    headers_member = make_user("member3@example.com")
    client.get("/v1/me", headers=headers_member)  # ensure the app_users row exists

    household = client.post(
        "/v1/households", json={"name": "Invite Family"}, headers=headers_owner
    ).json()

    response = client.post(
        f"/v1/households/{household['id']}/members",
        json={"email": "member3@example.com"},
        headers=headers_owner,
    )

    assert response.status_code == 201
    body = response.json()
    assert body["email"] == "member3@example.com"
    assert body["role"] == "member"

    listing = client.get(
        f"/v1/households/{household['id']}", headers=headers_member
    )
    assert listing.status_code == 200
    assert listing.json()["role"] == "member"


def test_invite_unknown_email_is_not_found(client, make_user):
    headers_owner = make_user("owner4@example.com")
    household = client.post(
        "/v1/households", json={"name": "Unknown Invite Family"}, headers=headers_owner
    ).json()

    response = client.post(
        f"/v1/households/{household['id']}/members",
        json={"email": "never-signed-up@example.com"},
        headers=headers_owner,
    )

    assert response.status_code == 404


def test_invite_already_member_is_conflict(client, make_user):
    headers_owner = make_user("owner5@example.com")
    headers_member = make_user("member5@example.com")
    client.get("/v1/me", headers=headers_member)

    household = client.post(
        "/v1/households", json={"name": "Dup Invite Family"}, headers=headers_owner
    ).json()

    first = client.post(
        f"/v1/households/{household['id']}/members",
        json={"email": "member5@example.com"},
        headers=headers_owner,
    )
    second = client.post(
        f"/v1/households/{household['id']}/members",
        json={"email": "member5@example.com"},
        headers=headers_owner,
    )

    assert first.status_code == 201
    assert second.status_code == 409


def test_non_owner_cannot_invite(client, make_user):
    headers_owner = make_user("owner6@example.com")
    headers_member = make_user("member6@example.com")
    headers_outsider = make_user("outsider6@example.com")
    client.get("/v1/me", headers=headers_member)
    client.get("/v1/me", headers=headers_outsider)

    household = client.post(
        "/v1/households", json={"name": "Non Owner Invite Family"}, headers=headers_owner
    ).json()
    client.post(
        f"/v1/households/{household['id']}/members",
        json={"email": "member6@example.com"},
        headers=headers_owner,
    )

    response = client.post(
        f"/v1/households/{household['id']}/members",
        json={"email": "outsider6@example.com"},
        headers=headers_member,
    )

    assert response.status_code == 403


def test_outsider_with_no_membership_cannot_list_or_invite(client, make_user):
    headers_owner = make_user("owner8@example.com")
    headers_outsider = make_user("outsider8@example.com")
    client.get("/v1/me", headers=headers_outsider)

    household = client.post(
        "/v1/households", json={"name": "Outsider Family"}, headers=headers_owner
    ).json()

    list_response = client.get(
        f"/v1/households/{household['id']}/members", headers=headers_outsider
    )
    invite_response = client.post(
        f"/v1/households/{household['id']}/members",
        json={"email": "owner8@example.com"},
        headers=headers_outsider,
    )

    assert list_response.status_code == 403
    assert invite_response.status_code == 403


def test_list_members_returns_everyone_in_the_household(client, make_user):
    headers_owner = make_user("owner7@example.com")
    headers_member = make_user("member7@example.com")
    client.get("/v1/me", headers=headers_member)

    household = client.post(
        "/v1/households", json={"name": "List Members Family"}, headers=headers_owner
    ).json()
    client.post(
        f"/v1/households/{household['id']}/members",
        json={"email": "member7@example.com", "role": "viewer"},
        headers=headers_owner,
    )

    response = client.get(
        f"/v1/households/{household['id']}/members", headers=headers_owner
    )

    assert response.status_code == 200
    by_email = {m["email"]: m["role"] for m in response.json()}
    assert by_email == {
        "owner7@example.com": "owner",
        "member7@example.com": "viewer",
    }
