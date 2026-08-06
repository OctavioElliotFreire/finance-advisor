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
from app.models.connection_access_grant import ConnectionAccessGrant
from app.models.household import Household, HouseholdMember
from app.models.pluggy_connection import PluggyConnection
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
        member_rows = (
            db.query(HouseholdMember).filter(HouseholdMember.app_user_id.in_(app_user_ids)).all()
        )
        household_ids = [row.household_id for row in member_rows]
        member_ids = [row.id for row in member_rows]

        db.query(AuditEvent).filter(
            AuditEvent.actor_app_user_id.in_(app_user_ids)
        ).delete(synchronize_session=False)
        if member_ids:
            db.query(ConnectionAccessGrant).filter(
                ConnectionAccessGrant.household_member_id.in_(member_ids)
            ).delete(synchronize_session=False)
        if household_ids:
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


def _seed_connection_and_account(household_id, *, item_id, account_name, txn_description):
    db = SessionLocal()
    connection = PluggyConnection(household_id=household_id, pluggy_item_id=item_id, status="UPDATED")
    db.add(connection)
    db.flush()
    account = Account(
        household_id=household_id,
        pluggy_connection_id=connection.id,
        pluggy_account_id=f"acc-{item_id}",
        name=account_name,
        balance=500.0,
        raw_json={"secret": "own-data-is-fine-to-include"},
    )
    db.add(account)
    db.flush()
    db.add(
        Transaction(
            household_id=household_id,
            account_id=account.id,
            pluggy_transaction_id=f"txn-{item_id}",
            description=txn_description,
            amount=-25.0,
            transaction_date="2026-08-01",
        )
    )
    db.commit()
    connection_id = connection.id
    db.close()
    return connection_id


def test_owner_export_includes_everything(client, make_user):
    headers = make_user("export-owner@example.com")
    household = client.post(
        "/v1/households", json={"name": "Export Family"}, headers=headers
    ).json()
    _seed_connection_and_account(
        household["id"], item_id="exp-1", account_name="Checking", txn_description="Groceries"
    )

    response = client.get(f"/v1/households/{household['id']}/export", headers=headers)

    assert response.status_code == 200
    body = response.json()
    assert body["household"]["name"] == "Export Family"
    assert len(body["accounts"]) == 1
    assert body["accounts"][0]["name"] == "Checking"
    assert body["accounts"][0]["raw_json"] == {"secret": "own-data-is-fine-to-include"}
    assert len(body["transactions"]) == 1
    assert body["transactions"][0]["description"] == "Groceries"


def test_export_records_audit_event(client, make_user):
    headers = make_user("export-audit@example.com")
    household = client.post(
        "/v1/households", json={"name": "Export Audit Family"}, headers=headers
    ).json()

    client.get(f"/v1/households/{household['id']}/export", headers=headers)

    db = SessionLocal()
    events = (
        db.query(AuditEvent).filter(AuditEvent.household_id == household["id"]).all()
    )
    db.close()
    assert len(events) == 1
    assert events[0].action == "data.exported"


def test_restricted_member_export_excludes_ungranted_connection(client, make_user):
    headers_owner = make_user("export-restrict-owner@example.com")
    headers_member = make_user("export-restrict-member@example.com")
    client.get("/v1/me", headers=headers_member)

    household = client.post(
        "/v1/households", json={"name": "Export Restrict Family"}, headers=headers_owner
    ).json()
    granted_connection_id = _seed_connection_and_account(
        household["id"], item_id="exp-granted", account_name="Granted Account", txn_description="OK"
    )
    _seed_connection_and_account(
        household["id"], item_id="exp-hidden", account_name="Hidden Account", txn_description="Secret"
    )

    client.post(
        f"/v1/households/{household['id']}/members",
        json={"email": "export-restrict-member@example.com", "role": "member"},
        headers=headers_owner,
    )
    db = SessionLocal()
    member_row = (
        db.query(HouseholdMember, AppUser)
        .join(AppUser, AppUser.id == HouseholdMember.app_user_id)
        .filter(
            HouseholdMember.household_id == household["id"],
            AppUser.email == "export-restrict-member@example.com",
        )
        .one()
    )
    member_id = member_row[0].id
    db.close()

    grant_response = client.put(
        f"/v1/households/{household['id']}/members/{member_id}/access",
        json={"connection_ids": [str(granted_connection_id)]},
        headers=headers_owner,
    )
    assert grant_response.status_code == 200

    response = client.get(
        f"/v1/households/{household['id']}/export", headers=headers_member
    )

    assert response.status_code == 200
    body = response.json()
    account_names = {a["name"] for a in body["accounts"]}
    assert account_names == {"Granted Account"}
    txn_descriptions = {t["description"] for t in body["transactions"]}
    assert txn_descriptions == {"OK"}


def test_export_requires_membership(client, make_user):
    headers_a = make_user("export-isoa@example.com")
    headers_b = make_user("export-isob@example.com")
    household = client.post(
        "/v1/households", json={"name": "Export Iso Family"}, headers=headers_a
    ).json()

    response = client.get(
        f"/v1/households/{household['id']}/export", headers=headers_b
    )

    assert response.status_code == 403


def test_export_requires_authentication(client):
    fake_id = uuid.uuid4()
    assert client.get(f"/v1/households/{fake_id}/export").status_code in (401, 403)
