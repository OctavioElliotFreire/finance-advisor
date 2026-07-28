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


def test_create_household_makes_creator_owner(client, make_user):
    headers = make_user("owner@example.com")

    response = client.post("/v1/households", json={"name": "Elliot Family"}, headers=headers)

    assert response.status_code == 201
    body = response.json()
    assert body["name"] == "Elliot Family"

    listing = client.get("/v1/households", headers=headers).json()
    assert len(listing) == 1
    assert listing[0]["id"] == body["id"]
    assert listing[0]["role"] == "owner"


def test_family_a_cannot_read_family_b_household(client, make_user):
    headers_a = make_user("familya@example.com")
    headers_b = make_user("familyb@example.com")

    household_a = client.post(
        "/v1/households", json={"name": "Family A"}, headers=headers_a
    ).json()

    forbidden = client.get(f"/v1/households/{household_a['id']}", headers=headers_b)
    assert forbidden.status_code == 403

    listing_b = client.get("/v1/households", headers=headers_b).json()
    assert household_a["id"] not in [h["id"] for h in listing_b]


def test_owner_can_read_own_household(client, make_user):
    headers = make_user("soleowner@example.com")
    household = client.post(
        "/v1/households", json={"name": "Solo Family"}, headers=headers
    ).json()

    response = client.get(f"/v1/households/{household['id']}", headers=headers)

    assert response.status_code == 200
    assert response.json()["role"] == "owner"


def test_get_nonexistent_household_is_forbidden_not_found(client, make_user):
    headers = make_user("noone@example.com")
    fake_id = uuid.uuid4()

    response = client.get(f"/v1/households/{fake_id}", headers=headers)

    assert response.status_code == 403


def test_households_require_authentication(client):
    assert client.get("/v1/households").status_code in (401, 403)
    assert client.post("/v1/households", json={"name": "x"}).status_code in (401, 403)
