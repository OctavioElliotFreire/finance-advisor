import time
import uuid

import jwt
import pytest
from fastapi.testclient import TestClient

from app.database.session import SessionLocal
from app.main import app
from app.models.app_user import AppUser
from app.settings import settings


@pytest.fixture(autouse=True)
def hs256_secret(monkeypatch):
    monkeypatch.setattr(settings, "supabase_url", "")
    monkeypatch.setattr(settings, "supabase_jwt_secret", "test-secret")
    monkeypatch.setattr(settings, "supabase_jwt_audience", "authenticated")
    monkeypatch.setattr(settings, "supabase_jwt_issuer", "")


@pytest.fixture
def cleanup_app_user():
    provider_user_id = str(uuid.uuid4())
    yield provider_user_id
    db = SessionLocal()
    db.query(AppUser).filter(
        AppUser.auth_provider_user_id == provider_user_id
    ).delete()
    db.commit()
    db.close()


def make_token(provider_user_id, email):
    claims = {
        "sub": provider_user_id,
        "email": email,
        "aud": "authenticated",
        "exp": int(time.time()) + 3600,
    }
    return jwt.encode(claims, "test-secret", algorithm="HS256")


def test_me_creates_app_user_on_first_call(cleanup_app_user):
    provider_user_id = cleanup_app_user
    token = make_token(provider_user_id, "newuser@example.com")
    client = TestClient(app)

    response = client.get("/v1/me", headers={"Authorization": f"Bearer {token}"})

    assert response.status_code == 200
    body = response.json()
    assert body["email"] == "newuser@example.com"

    db = SessionLocal()
    rows = db.query(AppUser).filter(
        AppUser.auth_provider_user_id == provider_user_id
    ).all()
    db.close()
    assert len(rows) == 1


def test_me_reuses_existing_app_user_on_second_call(cleanup_app_user):
    provider_user_id = cleanup_app_user
    token = make_token(provider_user_id, "sameuser@example.com")
    client = TestClient(app)

    first = client.get("/v1/me", headers={"Authorization": f"Bearer {token}"})
    second = client.get("/v1/me", headers={"Authorization": f"Bearer {token}"})

    assert first.json()["id"] == second.json()["id"]

    db = SessionLocal()
    rows = db.query(AppUser).filter(
        AppUser.auth_provider_user_id == provider_user_id
    ).all()
    db.close()
    assert len(rows) == 1


def test_me_without_token_is_unauthorized():
    client = TestClient(app)
    response = client.get("/v1/me")
    assert response.status_code in (401, 403)
