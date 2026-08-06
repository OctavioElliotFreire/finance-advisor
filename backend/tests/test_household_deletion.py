import time
import uuid

import jwt
import pytest
from fastapi.testclient import TestClient

from app.database.session import SessionLocal
from app.main import app
from app.models.account import Account
from app.models.app_user import AppUser
from app.models.audit_event import AuditEvent
from app.models.household import Household, HouseholdMember
from app.models.pluggy_connection import PluggyConnection, SyncJob
from app.models.transaction import Transaction
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
        # Cleanup by actor, not just household_id: a successfully deleted
        # household nulls out its audit_events.household_id (by design —
        # see the migration), so those rows wouldn't match a household_id
        # filter anymore.
        db.query(AuditEvent).filter(
            AuditEvent.actor_app_user_id.in_(app_user_ids)
        ).delete(synchronize_session=False)
        if household_ids:
            db.query(SyncJob).filter(SyncJob.household_id.in_(household_ids)).delete(
                synchronize_session=False
            )
            db.query(Transaction).filter(
                Transaction.household_id.in_(household_ids)
            ).delete(synchronize_session=False)
            db.query(Account).filter(Account.household_id.in_(household_ids)).delete(
                synchronize_session=False
            )
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


def test_owner_can_delete_household_and_everything_cascades(client, make_user):
    headers = make_user("delete-owner@example.com")
    household = client.post(
        "/v1/households", json={"name": "Doomed Family"}, headers=headers
    ).json()
    household_id = household["id"]

    db = SessionLocal()
    connection = PluggyConnection(
        household_id=household_id, pluggy_item_id="item-doomed", status="UPDATED"
    )
    db.add(connection)
    db.flush()
    account = Account(
        household_id=household_id,
        pluggy_connection_id=connection.id,
        pluggy_account_id="acc-doomed",
        name="Doomed Account",
        balance=100.0,
    )
    db.add(account)
    db.flush()
    db.add(
        Transaction(
            household_id=household_id,
            account_id=account.id,
            pluggy_transaction_id="txn-doomed",
            description="Doom",
            amount=-10.0,
            transaction_date="2026-08-01",
        )
    )
    db.commit()
    db.close()

    response = client.delete(f"/v1/households/{household_id}", headers=headers)
    assert response.status_code == 204

    db = SessionLocal()
    assert db.get(Household, household_id) is None
    assert (
        db.query(HouseholdMember).filter(HouseholdMember.household_id == household_id).count()
        == 0
    )
    assert (
        db.query(PluggyConnection)
        .filter(PluggyConnection.household_id == household_id)
        .count()
        == 0
    )
    assert db.query(Account).filter(Account.household_id == household_id).count() == 0
    assert (
        db.query(Transaction).filter(Transaction.household_id == household_id).count() == 0
    )
    db.close()

    # Household is gone; a member of it can no longer reach it.
    assert client.get(f"/v1/households/{household_id}", headers=headers).status_code == 403


def test_deleting_household_with_audit_history_nulls_not_blocks(client, make_user):
    headers_owner = make_user("delete-audit-owner@example.com")
    headers_member = make_user("delete-audit-member@example.com")
    client.get("/v1/me", headers=headers_member)

    household = client.post(
        "/v1/households", json={"name": "Audited Family"}, headers=headers_owner
    ).json()
    household_id = household["id"]

    invite_response = client.post(
        f"/v1/households/{household_id}/members",
        json={"email": "delete-audit-member@example.com", "role": "member"},
        headers=headers_owner,
    )
    assert invite_response.status_code == 201

    db = SessionLocal()
    prior_event_ids = [
        row.id
        for row in db.query(AuditEvent)
        .filter(AuditEvent.household_id == household_id)
        .all()
    ]
    db.close()
    assert len(prior_event_ids) == 1  # the member.added event from the invite above

    response = client.delete(f"/v1/households/{household_id}", headers=headers_owner)
    assert response.status_code == 204

    db = SessionLocal()
    surviving = (
        db.query(AuditEvent).filter(AuditEvent.id.in_(prior_event_ids)).all()
    )
    assert len(surviving) == 1
    assert surviving[0].household_id is None  # nulled, not deleted

    delete_event = (
        db.query(AuditEvent)
        .filter(AuditEvent.action == "household.deleted")
        .filter(AuditEvent.metadata_json["household_name"].astext == "Audited Family")
        .one()
    )
    assert delete_event.household_id is None
    db.close()


def test_non_owner_cannot_delete_household(client, make_user):
    headers_owner = make_user("delete-nonowner-owner@example.com")
    headers_member = make_user("delete-nonowner-member@example.com")
    client.get("/v1/me", headers=headers_member)

    household = client.post(
        "/v1/households", json={"name": "Protected Family"}, headers=headers_owner
    ).json()
    client.post(
        f"/v1/households/{household['id']}/members",
        json={"email": "delete-nonowner-member@example.com", "role": "member"},
        headers=headers_owner,
    )

    response = client.delete(
        f"/v1/households/{household['id']}", headers=headers_member
    )

    assert response.status_code == 403

    db = SessionLocal()
    assert db.get(Household, household["id"]) is not None
    db.close()


def test_delete_household_requires_authentication(client):
    fake_id = uuid.uuid4()
    assert client.delete(f"/v1/households/{fake_id}").status_code in (401, 403)
