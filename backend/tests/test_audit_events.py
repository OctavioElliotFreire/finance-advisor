import time
import uuid

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
from app.settings import settings


class _FakeInviteSender:
    async def invite_user_by_email(self, email, redirect_to):
        return {"id": str(uuid.uuid4()), "email": email}


@pytest.fixture(autouse=True)
def hs256_secret(monkeypatch):
    monkeypatch.setattr(settings, "supabase_url", "")
    monkeypatch.setattr(settings, "supabase_jwt_secret", "test-secret")
    monkeypatch.setattr(settings, "supabase_jwt_audience", "authenticated")
    monkeypatch.setattr(settings, "supabase_jwt_issuer", "")


@pytest.fixture(autouse=True)
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
        if household_ids:
            db.query(AuditEvent).filter(
                AuditEvent.household_id.in_(household_ids)
            ).delete(synchronize_session=False)
            db.query(HouseholdInvite).filter(
                HouseholdInvite.household_id.in_(household_ids)
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


def test_owner_sees_audit_events_after_invite(client, make_user):
    headers_owner = make_user("audit-list-owner@example.com")
    household = client.post(
        "/v1/households", json={"name": "Audit List Family"}, headers=headers_owner
    ).json()

    client.post(
        f"/v1/households/{household['id']}/members",
        json={"email": "audit-list-invitee@example.com"},
        headers=headers_owner,
    )

    response = client.get(
        f"/v1/households/{household['id']}/audit-events", headers=headers_owner
    )

    assert response.status_code == 200
    events = response.json()
    assert len(events) == 1
    assert events[0]["action"] == "member.invited"
    assert events[0]["actor_email"] == "audit-list-owner@example.com"
    assert events[0]["metadata_json"]["email"] == "audit-list-invitee@example.com"


def test_audit_events_ordered_most_recent_first(client, make_user):
    headers_owner = make_user("audit-order-owner@example.com")
    household = client.post(
        "/v1/households", json={"name": "Audit Order Family"}, headers=headers_owner
    ).json()

    client.post(
        f"/v1/households/{household['id']}/members",
        json={"email": "audit-order-first@example.com"},
        headers=headers_owner,
    )
    client.post(
        f"/v1/households/{household['id']}/members",
        json={"email": "audit-order-second@example.com"},
        headers=headers_owner,
    )

    response = client.get(
        f"/v1/households/{household['id']}/audit-events", headers=headers_owner
    )

    events = response.json()
    assert len(events) == 2
    assert events[0]["metadata_json"]["email"] == "audit-order-second@example.com"
    assert events[1]["metadata_json"]["email"] == "audit-order-first@example.com"


def test_non_owner_cannot_list_audit_events(client, make_user):
    headers_owner = make_user("audit-nonowner-owner@example.com")
    headers_member = make_user("audit-nonowner-member@example.com")
    client.get("/v1/me", headers=headers_member)

    household = client.post(
        "/v1/households", json={"name": "Audit Non Owner Family"}, headers=headers_owner
    ).json()
    client.post(
        f"/v1/households/{household['id']}/members",
        json={"email": "audit-nonowner-member@example.com", "role": "member"},
        headers=headers_owner,
    )

    response = client.get(
        f"/v1/households/{household['id']}/audit-events", headers=headers_member
    )

    assert response.status_code == 403


def test_audit_events_require_authentication(client):
    fake_id = uuid.uuid4()
    response = client.get(f"/v1/households/{fake_id}/audit-events")
    assert response.status_code in (401, 403)
