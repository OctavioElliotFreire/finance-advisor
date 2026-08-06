import time
import uuid
from datetime import datetime, timedelta, timezone

import jwt
import pytest
from fastapi.testclient import TestClient

from app.api.household_members import get_invite_sender
from app.database.session import SessionLocal
from app.main import app
from app.models.app_user import AppUser
from app.models.audit_event import AuditEvent
from app.models.household import Household, HouseholdMember
from app.models.household_invite import HouseholdInvite
from app.models.rate_limit_hit import RateLimitHit
from app.settings import settings


class _FakeInviteSender:
    def __init__(self):
        self.calls = []

    async def invite_user_by_email(self, email, redirect_to):
        self.calls.append((email, redirect_to))
        return {"id": str(uuid.uuid4()), "email": email}


@pytest.fixture(autouse=True)
def hs256_secret(monkeypatch):
    monkeypatch.setattr(settings, "supabase_url", "")
    monkeypatch.setattr(settings, "supabase_jwt_secret", "test-secret")
    monkeypatch.setattr(settings, "supabase_jwt_audience", "authenticated")
    monkeypatch.setattr(settings, "supabase_jwt_issuer", "")


@pytest.fixture
def fake_invite_sender():
    sender = _FakeInviteSender()
    app.dependency_overrides[get_invite_sender] = lambda: sender
    yield sender
    app.dependency_overrides.pop(get_invite_sender, None)


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
        db.query(HouseholdInvite).filter(
            HouseholdInvite.invited_by_app_user_id.in_(app_user_ids)
            | HouseholdInvite.household_id.in_(household_ids)
        ).delete(synchronize_session=False)
        if household_ids:
            db.query(AuditEvent).filter(
                AuditEvent.household_id.in_(household_ids)
            ).delete(synchronize_session=False)
            db.query(RateLimitHit).filter(
                RateLimitHit.scope.in_(
                    [f"member_invite:{hid}" for hid in household_ids]
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


def _invite_unknown_email(client, headers_owner, household_id, email):
    response = client.post(
        f"/v1/households/{household_id}/members",
        json={"email": email},
        headers=headers_owner,
    )
    assert response.status_code == 201
    return response.json()["invite"]["id"]


def test_preview_invite_returns_household_and_role(client, make_user, fake_invite_sender):
    headers_owner = make_user("preview-owner@example.com")
    household = client.post(
        "/v1/households", json={"name": "Preview Family"}, headers=headers_owner
    ).json()
    invite_id = _invite_unknown_email(
        client, headers_owner, household["id"], "preview-invitee@example.com"
    )

    response = client.get(f"/v1/invites/{invite_id}")

    assert response.status_code == 200
    body = response.json()
    assert body["household_name"] == "Preview Family"
    assert body["email"] == "preview-invitee@example.com"
    assert body["role"] == "member"
    assert body["expired"] is False
    assert body["accepted"] is False


def test_preview_invite_404_for_unknown_id(client):
    response = client.get(f"/v1/invites/{uuid.uuid4()}")
    assert response.status_code == 404


def test_accept_invite_creates_membership(client, make_user, fake_invite_sender):
    headers_owner = make_user("accept-owner@example.com")
    headers_invitee = make_user("accept-invitee@example.com")
    household = client.post(
        "/v1/households", json={"name": "Accept Family"}, headers=headers_owner
    ).json()
    invite_id = _invite_unknown_email(
        client, headers_owner, household["id"], "accept-invitee@example.com"
    )

    response = client.post(f"/v1/invites/{invite_id}/accept", headers=headers_invitee)

    assert response.status_code == 200
    body = response.json()
    assert body["household_id"] == household["id"]
    assert body["household_name"] == "Accept Family"

    listing = client.get(f"/v1/households/{household['id']}", headers=headers_invitee)
    assert listing.status_code == 200
    assert listing.json()["role"] == "member"

    preview = client.get(f"/v1/invites/{invite_id}")
    assert preview.json()["accepted"] is True


def test_accept_invite_wrong_email_is_forbidden(client, make_user, fake_invite_sender):
    headers_owner = make_user("wrongemail-owner@example.com")
    headers_other = make_user("someone-else@example.com")
    household = client.post(
        "/v1/households", json={"name": "Wrong Email Family"}, headers=headers_owner
    ).json()
    invite_id = _invite_unknown_email(
        client, headers_owner, household["id"], "intended-invitee@example.com"
    )

    response = client.post(f"/v1/invites/{invite_id}/accept", headers=headers_other)

    assert response.status_code == 403


def test_accept_invite_twice_is_conflict(client, make_user, fake_invite_sender):
    headers_owner = make_user("acceptTwice-owner@example.com")
    headers_invitee = make_user("acceptTwice-invitee@example.com")
    household = client.post(
        "/v1/households", json={"name": "Accept Twice Family"}, headers=headers_owner
    ).json()
    invite_id = _invite_unknown_email(
        client, headers_owner, household["id"], "acceptTwice-invitee@example.com"
    )

    first = client.post(f"/v1/invites/{invite_id}/accept", headers=headers_invitee)
    second = client.post(f"/v1/invites/{invite_id}/accept", headers=headers_invitee)

    assert first.status_code == 200
    assert second.status_code == 409


def test_accept_expired_invite_is_gone(client, make_user, fake_invite_sender):
    headers_owner = make_user("expired-owner@example.com")
    headers_invitee = make_user("expired-invitee@example.com")
    household = client.post(
        "/v1/households", json={"name": "Expired Family"}, headers=headers_owner
    ).json()
    invite_id = _invite_unknown_email(
        client, headers_owner, household["id"], "expired-invitee@example.com"
    )

    db = SessionLocal()
    invite = db.query(HouseholdInvite).filter(HouseholdInvite.id == invite_id).one()
    invite.expires_at = datetime.now(timezone.utc) - timedelta(days=1)
    db.commit()
    db.close()

    preview = client.get(f"/v1/invites/{invite_id}")
    assert preview.json()["expired"] is True

    response = client.post(f"/v1/invites/{invite_id}/accept", headers=headers_invitee)
    assert response.status_code == 410
