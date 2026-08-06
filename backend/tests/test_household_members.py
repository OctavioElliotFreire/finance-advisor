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
    assert body["outcome"] == "added"
    assert body["member"]["email"] == "member3@example.com"
    assert body["member"]["role"] == "member"

    listing = client.get(
        f"/v1/households/{household['id']}", headers=headers_member
    )
    assert listing.status_code == 200
    assert listing.json()["role"] == "member"


def test_invite_unknown_email_creates_pending_invite_and_sends_email(
    client, make_user, fake_invite_sender
):
    headers_owner = make_user("owner4@example.com")
    household = client.post(
        "/v1/households", json={"name": "Unknown Invite Family"}, headers=headers_owner
    ).json()

    response = client.post(
        f"/v1/households/{household['id']}/members",
        json={"email": "never-signed-up@example.com"},
        headers=headers_owner,
    )

    assert response.status_code == 201
    body = response.json()
    assert body["outcome"] == "invited"
    assert body["invite"]["email"] == "never-signed-up@example.com"
    assert body["invite"]["role"] == "member"
    assert body["invite"]["accepted_at"] is None

    assert len(fake_invite_sender.calls) == 1
    email, redirect_to = fake_invite_sender.calls[0]
    assert email == "never-signed-up@example.com"
    assert f"invite={body['invite']['id']}" in redirect_to

    pending = client.get(
        f"/v1/households/{household['id']}/invites", headers=headers_owner
    )
    assert pending.status_code == 200
    assert len(pending.json()) == 1
    assert pending.json()[0]["email"] == "never-signed-up@example.com"


def test_reinviting_same_pending_email_reuses_invite(client, make_user, fake_invite_sender):
    headers_owner = make_user("owner-reinvite@example.com")
    household = client.post(
        "/v1/households", json={"name": "Reinvite Family"}, headers=headers_owner
    ).json()

    first = client.post(
        f"/v1/households/{household['id']}/members",
        json={"email": "pending-reinvite@example.com"},
        headers=headers_owner,
    )
    second = client.post(
        f"/v1/households/{household['id']}/members",
        json={"email": "pending-reinvite@example.com"},
        headers=headers_owner,
    )

    assert first.status_code == 201
    assert second.status_code == 201
    assert first.json()["invite"]["id"] == second.json()["invite"]["id"]
    assert len(fake_invite_sender.calls) == 2

    pending = client.get(
        f"/v1/households/{household['id']}/invites", headers=headers_owner
    )
    assert len(pending.json()) == 1


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


def test_non_owner_cannot_list_pending_invites(client, make_user, fake_invite_sender):
    headers_owner = make_user("owner-pending@example.com")
    headers_member = make_user("member-pending@example.com")
    client.get("/v1/me", headers=headers_member)

    household = client.post(
        "/v1/households", json={"name": "Pending Invites Family"}, headers=headers_owner
    ).json()
    client.post(
        f"/v1/households/{household['id']}/members",
        json={"email": "member-pending@example.com"},
        headers=headers_owner,
    )

    response = client.get(
        f"/v1/households/{household['id']}/invites", headers=headers_member
    )

    assert response.status_code == 403


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


def test_invite_existing_user_records_audit_event(client, make_user):
    headers_owner = make_user("owner-audit1@example.com")
    headers_member = make_user("member-audit1@example.com")
    client.get("/v1/me", headers=headers_member)

    household = client.post(
        "/v1/households", json={"name": "Audit Invite Family"}, headers=headers_owner
    ).json()
    client.post(
        f"/v1/households/{household['id']}/members",
        json={"email": "member-audit1@example.com", "role": "member"},
        headers=headers_owner,
    )

    db = SessionLocal()
    events = (
        db.query(AuditEvent).filter(AuditEvent.household_id == household["id"]).all()
    )
    db.close()
    assert len(events) == 1
    assert events[0].action == "member.added"
    assert events[0].metadata_json["email"] == "member-audit1@example.com"


def test_invite_unknown_email_records_audit_event(client, make_user, fake_invite_sender):
    headers_owner = make_user("owner-audit2@example.com")
    household = client.post(
        "/v1/households", json={"name": "Audit Unknown Invite Family"}, headers=headers_owner
    ).json()

    client.post(
        f"/v1/households/{household['id']}/members",
        json={"email": "audit-unknown@example.com"},
        headers=headers_owner,
    )

    db = SessionLocal()
    events = (
        db.query(AuditEvent).filter(AuditEvent.household_id == household["id"]).all()
    )
    db.close()
    assert len(events) == 1
    assert events[0].action == "member.invited"
    assert events[0].metadata_json["email"] == "audit-unknown@example.com"


def test_invite_rate_limits_after_threshold(client, make_user, fake_invite_sender):
    headers_owner = make_user("owner-inviterate@example.com")
    household = client.post(
        "/v1/households", json={"name": "Invite Rate Family"}, headers=headers_owner
    ).json()

    db = SessionLocal()
    for _ in range(10):
        db.add(RateLimitHit(scope=f"member_invite:{household['id']}"))
    db.commit()
    db.close()

    response = client.post(
        f"/v1/households/{household['id']}/members",
        json={"email": "should-be-blocked@example.com"},
        headers=headers_owner,
    )

    assert response.status_code == 429
    assert fake_invite_sender.calls == []
