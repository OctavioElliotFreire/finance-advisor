import time
import uuid

import jwt
import pytest
from fastapi.testclient import TestClient

from app.database.session import SessionLocal
from app.main import app
from app.models.account import Account
from app.models.anomaly import AnomalyFlag
from app.models.app_user import AppUser
from app.models.audit_event import AuditEvent
from app.models.household import Household, HouseholdMember
from app.models.pluggy_connection import PluggyConnection
from app.models.transaction import Transaction
from app.models.transaction_split import TransactionSplit
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
        if household_ids:
            db.query(TransactionSplit).filter(
                TransactionSplit.transaction_id.in_(
                    db.query(Transaction.id).filter(
                        Transaction.household_id.in_(household_ids)
                    )
                )
            ).delete(synchronize_session=False)
            db.query(AnomalyFlag).filter(
                AnomalyFlag.household_id.in_(household_ids)
            ).delete(synchronize_session=False)
            db.query(Transaction).filter(
                Transaction.household_id.in_(household_ids)
            ).delete(synchronize_session=False)
            db.query(Account).filter(Account.household_id.in_(household_ids)).delete(
                synchronize_session=False
            )
            db.query(PluggyConnection).filter(
                PluggyConnection.household_id.in_(household_ids)
            ).delete(synchronize_session=False)
        db.query(AuditEvent).filter(
            AuditEvent.actor_app_user_id.in_(app_user_ids)
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


def _seed_transaction(household_id, *, amount=-150.0, category="Compras"):
    db = SessionLocal()
    connection = PluggyConnection(
        household_id=household_id, pluggy_item_id=f"item-{uuid.uuid4()}", status="UPDATED"
    )
    db.add(connection)
    db.flush()
    account = Account(
        household_id=household_id,
        pluggy_connection_id=connection.id,
        pluggy_account_id="acc-1",
        name="Checking",
        type="BANK",
        balance=1000.0,
        currency_code="BRL",
    )
    db.add(account)
    db.flush()
    txn = Transaction(
        household_id=household_id,
        account_id=account.id,
        pluggy_transaction_id=f"txn-{uuid.uuid4()}",
        description="Supermercado",
        amount=amount,
        currency_code="BRL",
        transaction_date="2026-07-15",
        category=category,
    )
    db.add(txn)
    db.commit()
    txn_id = txn.id
    account_id = account.id
    connection_id = connection.id
    db.close()
    return txn_id, account_id, connection_id


def test_recategorize_updates_category(client, make_user):
    headers = make_user("recat@example.com")
    household = client.post(
        "/v1/households", json={"name": "Recategorize Family"}, headers=headers
    ).json()
    txn_id, _, _ = _seed_transaction(household["id"])

    response = client.patch(
        f"/v1/households/{household['id']}/transactions/{txn_id}",
        json={"category": "Restaurantes"},
        headers=headers,
    )

    assert response.status_code == 200
    assert response.json()["category"] == "Restaurantes"

    listed = client.get(
        f"/v1/households/{household['id']}/transactions", headers=headers
    ).json()
    assert listed[0]["category"] == "Restaurantes"


def test_recategorize_returns_404_for_other_household(client, make_user):
    headers_a = make_user("recat-isoa@example.com")
    headers_b = make_user("recat-isob@example.com")
    household_a = client.post(
        "/v1/households", json={"name": "Recategorize Iso A"}, headers=headers_a
    ).json()
    txn_id, _, _ = _seed_transaction(household_a["id"])

    response = client.patch(
        f"/v1/households/{household_a['id']}/transactions/{txn_id}",
        json={"category": "Restaurantes"},
        headers=headers_b,
    )

    assert response.status_code == 403


def test_recategorize_restricted_member_without_access_returns_404(client, make_user):
    headers_owner = make_user("recat-owner@example.com")
    headers_member = make_user("recat-member@example.com")
    household = client.post(
        "/v1/households", json={"name": "Recategorize Restricted"}, headers=headers_owner
    ).json()
    txn_id, _, _ = _seed_transaction(household["id"])

    client.get("/v1/me", headers=headers_member)
    invite_response = client.post(
        f"/v1/households/{household['id']}/members",
        json={"email": "recat-member@example.com", "role": "member"},
        headers=headers_owner,
    )
    member_id = invite_response.json()["member"]["id"]
    # Grant no connections at all — a fully restricted member.
    client.put(
        f"/v1/households/{household['id']}/members/{member_id}/access",
        json={"connection_ids": []},
        headers=headers_owner,
    )

    response = client.patch(
        f"/v1/households/{household['id']}/transactions/{txn_id}",
        json={"category": "Restaurantes"},
        headers=headers_member,
    )

    assert response.status_code == 404


def test_splits_create_and_reflect_in_totals(client, make_user):
    headers = make_user("splits@example.com")
    household = client.post(
        "/v1/households", json={"name": "Splits Family"}, headers=headers
    ).json()
    txn_id, _, _ = _seed_transaction(household["id"], amount=-400.0, category="Compras")

    response = client.put(
        f"/v1/households/{household['id']}/transactions/{txn_id}/splits",
        json={
            "splits": [
                {"category": "Mercado", "amount": -300.0},
                {"category": "Farmácia", "amount": -100.0},
            ]
        },
        headers=headers,
    )

    assert response.status_code == 200
    body = response.json()
    assert len(body["splits"]) == 2

    categories = client.get(
        f"/v1/households/{household['id']}/categories",
        params={"start_date": "2026-07-01", "end_date": "2026-07-31"},
        headers=headers,
    ).json()
    totals_by_category = {row["category"]: row["total"] for row in categories}
    assert totals_by_category["Mercado"] == 300.0
    assert totals_by_category["Farmácia"] == 100.0
    assert "Compras" not in totals_by_category


def test_splits_reject_sum_mismatch(client, make_user):
    headers = make_user("splits-badsum@example.com")
    household = client.post(
        "/v1/households", json={"name": "Splits Bad Sum"}, headers=headers
    ).json()
    txn_id, _, _ = _seed_transaction(household["id"], amount=-400.0)

    response = client.put(
        f"/v1/households/{household['id']}/transactions/{txn_id}/splits",
        json={"splits": [{"category": "Mercado", "amount": -300.0}]},
        headers=headers,
    )

    assert response.status_code == 400


def test_splits_reject_sign_mismatch(client, make_user):
    headers = make_user("splits-badsign@example.com")
    household = client.post(
        "/v1/households", json={"name": "Splits Bad Sign"}, headers=headers
    ).json()
    txn_id, _, _ = _seed_transaction(household["id"], amount=-400.0)

    response = client.put(
        f"/v1/households/{household['id']}/transactions/{txn_id}/splits",
        json={
            "splits": [
                {"category": "Mercado", "amount": -500.0},
                {"category": "Reembolso", "amount": 100.0},
            ]
        },
        headers=headers,
    )

    assert response.status_code == 400


def test_splits_clear_removes_them(client, make_user):
    headers = make_user("splits-clear@example.com")
    household = client.post(
        "/v1/households", json={"name": "Splits Clear"}, headers=headers
    ).json()
    txn_id, _, _ = _seed_transaction(household["id"], amount=-400.0, category="Compras")

    client.put(
        f"/v1/households/{household['id']}/transactions/{txn_id}/splits",
        json={"splits": [{"category": "Mercado", "amount": -400.0}]},
        headers=headers,
    )
    response = client.put(
        f"/v1/households/{household['id']}/transactions/{txn_id}/splits",
        json={"splits": []},
        headers=headers,
    )

    assert response.status_code == 200
    assert response.json()["splits"] == []


def test_flag_creates_manual_anomaly_and_is_idempotent(client, make_user):
    headers = make_user("flag@example.com")
    household = client.post(
        "/v1/households", json={"name": "Flag Family"}, headers=headers
    ).json()
    txn_id, _, _ = _seed_transaction(household["id"])

    first = client.post(
        f"/v1/households/{household['id']}/transactions/{txn_id}/flag", headers=headers
    )
    assert first.status_code == 200
    assert first.json()["rule"] == "manual"
    assert first.json()["status"] == "open"
    flag_id = first.json()["id"]

    second = client.post(
        f"/v1/households/{household['id']}/transactions/{txn_id}/flag", headers=headers
    )
    assert second.status_code == 200
    assert second.json()["id"] == flag_id

    listed = client.get(
        f"/v1/households/{household['id']}/transactions", headers=headers
    ).json()
    assert listed[0]["flag_id"] == flag_id
    assert listed[0]["is_flagged"] is True


def test_flag_then_dismiss_clears_flag_id(client, make_user):
    headers = make_user("flag-dismiss@example.com")
    household = client.post(
        "/v1/households", json={"name": "Flag Dismiss Family"}, headers=headers
    ).json()
    txn_id, _, _ = _seed_transaction(household["id"])

    flag_id = client.post(
        f"/v1/households/{household['id']}/transactions/{txn_id}/flag", headers=headers
    ).json()["id"]

    dismiss = client.patch(
        f"/v1/households/{household['id']}/anomalies/{flag_id}",
        json={"status": "dismissed"},
        headers=headers,
    )
    assert dismiss.status_code == 200

    listed = client.get(
        f"/v1/households/{household['id']}/transactions", headers=headers
    ).json()
    assert listed[0]["flag_id"] is None
    assert listed[0]["is_flagged"] is False

    # Re-flagging after a dismiss must reopen the same row, not be a
    # permanent no-op — a manual flag/unflag is a user-driven toggle,
    # unlike an automatic rule's dedupe-forever behavior.
    reflagged = client.post(
        f"/v1/households/{household['id']}/transactions/{txn_id}/flag", headers=headers
    )
    assert reflagged.status_code == 200
    assert reflagged.json()["id"] == flag_id
    assert reflagged.json()["status"] == "open"
