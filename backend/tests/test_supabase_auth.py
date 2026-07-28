import time

import jwt
import pytest
from fastapi import HTTPException

from app.auth.supabase import verify_supabase_token
from app.settings import settings


@pytest.fixture(autouse=True)
def hs256_secret(monkeypatch):
    monkeypatch.setattr(settings, "supabase_url", "")
    monkeypatch.setattr(settings, "supabase_jwt_secret", "test-secret")
    monkeypatch.setattr(settings, "supabase_jwt_audience", "authenticated")
    monkeypatch.setattr(settings, "supabase_jwt_issuer", "")


def make_token(**overrides):
    claims = {
        "sub": "11111111-1111-1111-1111-111111111111",
        "email": "user@example.com",
        "aud": "authenticated",
        "exp": int(time.time()) + 3600,
        **overrides,
    }
    return jwt.encode(claims, "test-secret", algorithm="HS256")


def test_verify_valid_token_returns_claims():
    token = make_token()
    claims = verify_supabase_token(token)
    assert claims["sub"] == "11111111-1111-1111-1111-111111111111"
    assert claims["email"] == "user@example.com"


def test_verify_expired_token_raises_401():
    token = make_token(exp=int(time.time()) - 10)
    with pytest.raises(HTTPException) as exc_info:
        verify_supabase_token(token)
    assert exc_info.value.status_code == 401


def test_verify_wrong_secret_raises_401():
    token = jwt.encode(
        {
            "sub": "x",
            "aud": "authenticated",
            "exp": int(time.time()) + 3600,
        },
        "wrong-secret",
        algorithm="HS256",
    )
    with pytest.raises(HTTPException) as exc_info:
        verify_supabase_token(token)
    assert exc_info.value.status_code == 401


def test_verify_wrong_audience_raises_401():
    token = make_token(aud="other-audience")
    with pytest.raises(HTTPException) as exc_info:
        verify_supabase_token(token)
    assert exc_info.value.status_code == 401
