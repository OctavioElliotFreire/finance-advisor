"""End-to-end security regression tests: auth bypass and cross-household
access attempts through real HTTP endpoints, plus real rate-limit
enforcement through a live endpoint (not just the service function).

Complements the auth/access-scope coverage already in test_supabase_auth.py,
test_access_grants.py, test_households.py, and test_rate_limiting.py rather
than duplicating it — see PLAN.md's Milestone 10 notes.
"""

import time
import uuid

import jwt
import pytest
from fastapi.testclient import TestClient

from app.database.session import SessionLocal
from app.main import app
from app.models.app_user import AppUser
from app.models.household import Household, HouseholdMember
from app.models.rate_limit_hit import RateLimitHit
from app.settings import settings


class _FakePluggyClient:
    async def authenticate(self):
        return "fake-api-key"

    async def create_connect_token(self, client_user_id, item_id=None, webhook_url=None):
        return "fake-connect-token"


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
            db.query(RateLimitHit).filter(
                RateLimitHit.scope.in_(
                    [f"connections_token:{hid}" for hid in household_ids]
                )
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


# --- Missing / malformed credentials, end-to-end through real endpoints ---


def test_no_authorization_header_rejected(client):
    fake_id = uuid.uuid4()
    response = client.get(f"/v1/households/{fake_id}/alerts")
    assert response.status_code in (401, 403)


def test_malformed_authorization_header_rejected(client):
    fake_id = uuid.uuid4()
    response = client.get(
        f"/v1/households/{fake_id}/alerts",
        headers={"Authorization": "not-a-bearer-token"},
    )
    assert response.status_code in (401, 403)


def test_garbage_bearer_token_rejected(client):
    fake_id = uuid.uuid4()
    response = client.get(
        f"/v1/households/{fake_id}/alerts",
        headers={"Authorization": "Bearer complete-garbage.not.a.jwt"},
    )
    assert response.status_code == 401


def test_missing_auth_takes_precedence_over_nonexistent_household(client):
    # A bogus household_id with no credentials should fail on auth, not leak
    # a distinction between "no auth" and "household doesn't exist".
    fake_id = uuid.uuid4()
    response = client.get(f"/v1/households/{fake_id}/audit-events")
    assert response.status_code in (401, 403)


# --- Cross-household access denial on endpoints not already covered ---


def test_cross_household_member_cannot_invite_into_other_household(client, make_user):
    headers_a = make_user("secA-owner@example.com")
    headers_b = make_user("secB-owner@example.com")
    household_a = client.post(
        "/v1/households", json={"name": "Security Family A"}, headers=headers_a
    ).json()
    client.post(
        "/v1/households", json={"name": "Security Family B"}, headers=headers_b
    ).json()

    response = client.post(
        f"/v1/households/{household_a['id']}/members",
        json={"email": "someone-else@example.com"},
        headers=headers_b,
    )

    assert response.status_code == 403


def test_cross_household_member_cannot_read_others_alerts(client, make_user):
    headers_a = make_user("secAlertsA-owner@example.com")
    headers_b = make_user("secAlertsB-owner@example.com")
    household_a = client.post(
        "/v1/households", json={"name": "Alerts Family A"}, headers=headers_a
    ).json()
    client.post(
        "/v1/households", json={"name": "Alerts Family B"}, headers=headers_b
    ).json()

    response = client.get(
        f"/v1/households/{household_a['id']}/alerts", headers=headers_b
    )

    assert response.status_code == 403


def test_cross_household_owner_cannot_read_others_member_access(client, make_user):
    headers_a = make_user("secAccessA-owner@example.com")
    headers_b = make_user("secAccessB-owner@example.com")
    household_a = client.post(
        "/v1/households", json={"name": "Access Family A"}, headers=headers_a
    ).json()
    client.post(
        "/v1/households", json={"name": "Access Family B"}, headers=headers_b
    ).json()
    members_a = client.get(
        f"/v1/households/{household_a['id']}/members", headers=headers_a
    ).json()
    owner_member_id = members_a[0]["id"]

    response = client.get(
        f"/v1/households/{household_a['id']}/members/{owner_member_id}/access",
        headers=headers_b,
    )

    assert response.status_code == 403


# --- Rate limiting enforced through a real endpoint, not just the service fn ---


def test_rate_limit_enforced_end_to_end_via_real_endpoint(client, make_user):
    headers = make_user("sec-ratelimit-owner@example.com")
    household = client.post(
        "/v1/households", json={"name": "Rate Limit Family"}, headers=headers
    ).json()
    url = f"/v1/households/{household['id']}/connections/token"

    for _ in range(10):
        response = client.post(url, headers=headers)
        assert response.status_code == 200

    blocked = client.post(url, headers=headers)

    assert blocked.status_code == 429
