import time
import uuid

import jwt
import pytest
from fastapi.testclient import TestClient

from app.database.session import SessionLocal
from app.main import app
from app.models.account import Account
from app.models.app_user import AppUser
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
        if household_ids:
            db.query(Transaction).filter(
                Transaction.household_id.in_(household_ids)
            ).delete(synchronize_session=False)
            db.query(Account).filter(Account.household_id.in_(household_ids)).delete(
                synchronize_session=False
            )
            db.query(SyncJob).filter(SyncJob.household_id.in_(household_ids)).delete(
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


def _seed_household_data(household_id):
    db = SessionLocal()
    connection = PluggyConnection(
        household_id=household_id, pluggy_item_id=f"item-{uuid.uuid4()}", status="UPDATED"
    )
    db.add(connection)
    db.flush()

    checking = Account(
        household_id=household_id,
        pluggy_connection_id=connection.id,
        pluggy_account_id="acc-checking",
        name="Checking",
        type="BANK",
        balance=1000.0,
        currency_code="BRL",
    )
    savings = Account(
        household_id=household_id,
        pluggy_connection_id=connection.id,
        pluggy_account_id="acc-savings",
        name="Savings",
        type="BANK",
        balance=500.0,
        currency_code="BRL",
    )
    db.add_all([checking, savings])
    db.flush()

    db.add_all(
        [
            Transaction(
                household_id=household_id,
                account_id=checking.id,
                pluggy_transaction_id="txn-income-june",
                description="Salary",
                amount=3000.0,
                currency_code="BRL",
                transaction_date="2026-06-05",
                category="Income",
            ),
            Transaction(
                household_id=household_id,
                account_id=checking.id,
                pluggy_transaction_id="txn-expense-june",
                description="Rent",
                amount=-1200.0,
                currency_code="BRL",
                transaction_date="2026-06-10",
                category="Housing",
            ),
            Transaction(
                household_id=household_id,
                account_id=checking.id,
                pluggy_transaction_id="txn-expense-july",
                description="Groceries",
                amount=-400.0,
                currency_code="BRL",
                transaction_date="2026-07-01",
                category="Food",
            ),
        ]
    )
    sync_job = SyncJob(
        household_id=household_id,
        pluggy_connection_id=connection.id,
        status="completed",
    )
    db.add(sync_job)
    db.commit()
    db.close()


def test_dashboard_returns_accounts_transactions_cash_flow_and_sync_status(
    client, make_user
):
    headers = make_user("dash@example.com")
    household = client.post(
        "/v1/households", json={"name": "Dashboard Family"}, headers=headers
    ).json()
    _seed_household_data(household["id"])

    response = client.get(
        f"/v1/households/{household['id']}/dashboard", headers=headers
    )

    assert response.status_code == 200
    body = response.json()

    assert len(body["accounts"]) == 2
    assert body["total_balance"] == 1500.0

    assert len(body["recent_transactions"]) == 3
    assert body["recent_transactions"][0]["description"] == "Groceries"

    cash_flow_by_month = {row["month"]: row for row in body["monthly_cash_flow"]}
    assert cash_flow_by_month["2026-06"]["income"] == 3000.0
    assert cash_flow_by_month["2026-06"]["expenses"] == 1200.0
    assert cash_flow_by_month["2026-06"]["net"] == 1800.0
    assert cash_flow_by_month["2026-07"]["income"] == 0.0
    assert cash_flow_by_month["2026-07"]["expenses"] == 400.0

    assert body["sync_status"]["status"] == "completed"
    assert body["sync_status"]["updated_at"] is not None


def test_dashboard_with_no_data_returns_empty_shape(client, make_user):
    headers = make_user("empty@example.com")
    household = client.post(
        "/v1/households", json={"name": "Empty Family"}, headers=headers
    ).json()

    response = client.get(
        f"/v1/households/{household['id']}/dashboard", headers=headers
    )

    assert response.status_code == 200
    body = response.json()
    assert body["accounts"] == []
    assert body["total_balance"] == 0.0
    assert body["recent_transactions"] == []
    assert body["monthly_cash_flow"] == []
    assert body["sync_status"] == {"status": None, "updated_at": None}


def test_viewer_can_view_dashboard(client, make_user):
    headers_owner = make_user("viewowner@example.com")
    headers_viewer = make_user("viewviewer@example.com")
    household = client.post(
        "/v1/households", json={"name": "Viewer Dashboard Family"}, headers=headers_owner
    ).json()
    client.get("/v1/me", headers=headers_viewer)

    db = SessionLocal()
    viewer_user = (
        db.query(AppUser).filter(AppUser.email == "viewviewer@example.com").one()
    )
    db.add(
        HouseholdMember(
            household_id=household["id"], app_user_id=viewer_user.id, role="viewer"
        )
    )
    db.commit()
    db.close()

    response = client.get(
        f"/v1/households/{household['id']}/dashboard", headers=headers_viewer
    )

    assert response.status_code == 200


def test_family_a_cannot_view_family_b_dashboard(client, make_user):
    headers_a = make_user("dashisoa@example.com")
    headers_b = make_user("dashisob@example.com")
    household_a = client.post(
        "/v1/households", json={"name": "Dash Iso Family A"}, headers=headers_a
    ).json()
    _seed_household_data(household_a["id"])

    response = client.get(
        f"/v1/households/{household_a['id']}/dashboard", headers=headers_b
    )

    assert response.status_code == 403


def test_dashboard_requires_authentication(client):
    fake_id = uuid.uuid4()
    response = client.get(f"/v1/households/{fake_id}/dashboard")
    assert response.status_code in (401, 403)
