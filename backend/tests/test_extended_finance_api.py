import time
import uuid
from datetime import date, timedelta

import jwt
import pytest
from fastapi.testclient import TestClient

from app.database.session import SessionLocal
from app.main import app
from app.models.account import Account
from app.models.app_user import AppUser
from app.models.extended_finance import BalanceSnapshot, CreditCardBill, Investment, Loan
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
        household_ids = [
            row.household_id
            for row in db.query(HouseholdMember)
            .filter(HouseholdMember.app_user_id.in_(app_user_ids))
            .all()
        ]
        if household_ids:
            db.query(BalanceSnapshot).filter(
                BalanceSnapshot.household_id.in_(household_ids)
            ).delete(synchronize_session=False)
            db.query(CreditCardBill).filter(
                CreditCardBill.household_id.in_(household_ids)
            ).delete(synchronize_session=False)
            db.query(Investment).filter(
                Investment.household_id.in_(household_ids)
            ).delete(synchronize_session=False)
            db.query(Loan).filter(Loan.household_id.in_(household_ids)).delete(
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


def _seed_extended_finance_data(household_id):
    db = SessionLocal()
    connection = PluggyConnection(
        household_id=household_id, pluggy_item_id=f"item-{uuid.uuid4()}", status="UPDATED"
    )
    db.add(connection)
    db.flush()

    credit_account = Account(
        household_id=household_id,
        pluggy_connection_id=connection.id,
        pluggy_account_id="acc-credit",
        name="Credit Card",
        type="CREDIT",
        balance=-300.0,
        currency_code="BRL",
    )
    db.add(credit_account)
    db.flush()

    today = date.today()
    db.add_all(
        [
            CreditCardBill(
                household_id=household_id,
                account_id=credit_account.id,
                pluggy_bill_id="bill-1",
                due_date=today + timedelta(days=10),
                closing_date=today,
                total_amount=300.0,
                minimum_payment=60.0,
                currency_code="BRL",
            ),
            Investment(
                household_id=household_id,
                pluggy_connection_id=connection.id,
                pluggy_investment_id="inv-1",
                name="CDB Test",
                type="FIXED_INCOME",
                balance=1000.0,
                value=1000.0,
                quantity=1,
                currency_code="BRL",
                investment_date=today,
            ),
            Loan(
                household_id=household_id,
                pluggy_connection_id=connection.id,
                pluggy_loan_id="loan-1",
                type="PERSONAL",
                status="ACTIVE",
                contract_amount=5000.0,
                outstanding_balance=4000.0,
                installment_amount=500.0,
                installments_total=10,
                installments_paid=2,
                due_date=today + timedelta(days=30),
                interest_rate=1.5,
                currency_code="BRL",
            ),
            BalanceSnapshot(
                household_id=household_id,
                account_id=credit_account.id,
                balance=-300.0,
                currency_code="BRL",
                snapshot_date=today,
            ),
            Transaction(
                household_id=household_id,
                account_id=credit_account.id,
                pluggy_transaction_id="txn-groceries",
                description="Groceries",
                amount=-150.0,
                currency_code="BRL",
                transaction_date=today,
                category="Food",
            ),
            Transaction(
                household_id=household_id,
                account_id=credit_account.id,
                pluggy_transaction_id="txn-fuel",
                description="Gas Station",
                amount=-100.0,
                currency_code="BRL",
                transaction_date=today,
                category="Transport",
            ),
        ]
    )
    db.commit()
    db.close()


def test_list_credit_card_bills(client, make_user):
    headers = make_user("bills@example.com")
    household = client.post(
        "/v1/households", json={"name": "Bills Family"}, headers=headers
    ).json()
    _seed_extended_finance_data(household["id"])

    response = client.get(
        f"/v1/households/{household['id']}/credit-card-bills", headers=headers
    )

    assert response.status_code == 200
    body = response.json()
    assert len(body) == 1
    assert body[0]["total_amount"] == 300.0


def test_list_investments(client, make_user):
    headers = make_user("investments@example.com")
    household = client.post(
        "/v1/households", json={"name": "Investments Family"}, headers=headers
    ).json()
    _seed_extended_finance_data(household["id"])

    response = client.get(
        f"/v1/households/{household['id']}/investments", headers=headers
    )

    assert response.status_code == 200
    body = response.json()
    assert len(body) == 1
    assert body[0]["name"] == "CDB Test"


def test_list_loans(client, make_user):
    headers = make_user("loans@example.com")
    household = client.post(
        "/v1/households", json={"name": "Loans Family"}, headers=headers
    ).json()
    _seed_extended_finance_data(household["id"])

    response = client.get(f"/v1/households/{household['id']}/loans", headers=headers)

    assert response.status_code == 200
    body = response.json()
    assert len(body) == 1
    assert body[0]["outstanding_balance"] == 4000.0


def test_balance_history(client, make_user):
    headers = make_user("balance@example.com")
    household = client.post(
        "/v1/households", json={"name": "Balance Family"}, headers=headers
    ).json()
    _seed_extended_finance_data(household["id"])

    response = client.get(
        f"/v1/households/{household['id']}/balance-history", headers=headers
    )

    assert response.status_code == 200
    body = response.json()
    assert len(body) == 1
    assert body[0]["total_balance"] == -300.0


def test_category_breakdown(client, make_user):
    headers = make_user("categories@example.com")
    household = client.post(
        "/v1/households", json={"name": "Categories Family"}, headers=headers
    ).json()
    _seed_extended_finance_data(household["id"])

    response = client.get(
        f"/v1/households/{household['id']}/categories", headers=headers
    )

    assert response.status_code == 200
    body = response.json()
    totals_by_category = {row["category"]: row["total"] for row in body}
    assert totals_by_category["Food"] == 150.0
    assert totals_by_category["Transport"] == 100.0


def test_family_a_cannot_view_family_b_credit_card_bills(client, make_user):
    headers_a = make_user("bills-isoa@example.com")
    headers_b = make_user("bills-isob@example.com")
    household_a = client.post(
        "/v1/households", json={"name": "Bills Iso Family A"}, headers=headers_a
    ).json()
    _seed_extended_finance_data(household_a["id"])

    response = client.get(
        f"/v1/households/{household_a['id']}/credit-card-bills", headers=headers_b
    )

    assert response.status_code == 403


def test_family_a_cannot_view_family_b_investments(client, make_user):
    headers_a = make_user("inv-isoa@example.com")
    headers_b = make_user("inv-isob@example.com")
    household_a = client.post(
        "/v1/households", json={"name": "Investments Iso Family A"}, headers=headers_a
    ).json()
    _seed_extended_finance_data(household_a["id"])

    response = client.get(
        f"/v1/households/{household_a['id']}/investments", headers=headers_b
    )

    assert response.status_code == 403


def test_list_investments_filters_by_member_ids(client, make_user):
    headers_owner = make_user("invscopeowner@example.com")
    household = client.post(
        "/v1/households", json={"name": "Investment Scope Family"}, headers=headers_owner
    ).json()

    headers_second = make_user("invscopesecond@example.com")
    client.get("/v1/me", headers=headers_second)

    db = SessionLocal()
    owner_user = (
        db.query(AppUser).filter(AppUser.email == "invscopeowner@example.com").one()
    )
    second_user = (
        db.query(AppUser).filter(AppUser.email == "invscopesecond@example.com").one()
    )
    second_member = HouseholdMember(
        household_id=household["id"], app_user_id=second_user.id, role="member"
    )
    db.add(second_member)
    db.flush()
    second_member_id = second_member.id

    owner_connection = PluggyConnection(
        household_id=household["id"],
        pluggy_item_id=f"item-owner-{uuid.uuid4()}",
        status="UPDATED",
        created_by_app_user_id=owner_user.id,
    )
    second_connection = PluggyConnection(
        household_id=household["id"],
        pluggy_item_id=f"item-second-{uuid.uuid4()}",
        status="UPDATED",
        created_by_app_user_id=second_user.id,
    )
    db.add_all([owner_connection, second_connection])
    db.flush()
    db.add_all(
        [
            Investment(
                household_id=household["id"],
                pluggy_connection_id=owner_connection.id,
                pluggy_investment_id="inv-owner",
                name="Owner Fund",
                type="FIXED_INCOME",
                balance=100.0,
                value=100.0,
                quantity=1,
                currency_code="BRL",
                investment_date=date.today(),
            ),
            Investment(
                household_id=household["id"],
                pluggy_connection_id=second_connection.id,
                pluggy_investment_id="inv-second",
                name="Second Fund",
                type="FIXED_INCOME",
                balance=200.0,
                value=200.0,
                quantity=1,
                currency_code="BRL",
                investment_date=date.today(),
            ),
        ]
    )
    db.commit()
    db.close()

    response = client.get(
        f"/v1/households/{household['id']}/investments",
        params={"member_ids": [str(second_member_id)]},
        headers=headers_owner,
    )

    assert response.status_code == 200
    body = response.json()
    assert len(body) == 1
    assert body[0]["name"] == "Second Fund"


def test_category_breakdown_with_compare_previous(client, make_user):
    headers = make_user("comparecats@example.com")
    household = client.post(
        "/v1/households", json={"name": "Compare Categories Family"}, headers=headers
    ).json()

    db = SessionLocal()
    connection = PluggyConnection(
        household_id=household["id"],
        pluggy_item_id=f"item-{uuid.uuid4()}",
        status="UPDATED",
    )
    db.add(connection)
    db.flush()
    account = Account(
        household_id=household["id"],
        pluggy_connection_id=connection.id,
        pluggy_account_id="acc-compare",
        name="Compare Checking",
        type="BANK",
        balance=0.0,
        currency_code="BRL",
    )
    db.add(account)
    db.flush()
    db.add_all(
        [
            Transaction(
                household_id=household["id"],
                account_id=account.id,
                pluggy_transaction_id="txn-current-food",
                description="Current Food",
                amount=-150.0,
                currency_code="BRL",
                transaction_date="2026-07-15",
                category="Food",
            ),
            Transaction(
                household_id=household["id"],
                account_id=account.id,
                pluggy_transaction_id="txn-previous-food",
                description="Previous Food",
                amount=-100.0,
                currency_code="BRL",
                transaction_date="2026-06-15",
                category="Food",
            ),
        ]
    )
    db.commit()
    db.close()

    response = client.get(
        f"/v1/households/{household['id']}/categories",
        params={
            "start_date": "2026-07-01",
            "end_date": "2026-07-31",
            "compare_previous": True,
        },
        headers=headers,
    )

    assert response.status_code == 200
    body = response.json()
    food = next(row for row in body if row["category"] == "Food")
    assert food["total"] == 150.0
    assert food["previous_total"] == 100.0


def test_family_a_cannot_view_family_b_loans(client, make_user):
    headers_a = make_user("loan-isoa@example.com")
    headers_b = make_user("loan-isob@example.com")
    household_a = client.post(
        "/v1/households", json={"name": "Loans Iso Family A"}, headers=headers_a
    ).json()
    _seed_extended_finance_data(household_a["id"])

    response = client.get(
        f"/v1/households/{household_a['id']}/loans", headers=headers_b
    )

    assert response.status_code == 403
