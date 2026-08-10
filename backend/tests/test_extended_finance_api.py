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


def _seed_member_spend_data(household_id, owner_app_user_id, second_app_user_id):
    """Three connections in one household: one owned by each of two
    members, one deliberately unattributed (`created_by_app_user_id=None`)
    — for `/spending-by-member`'s member-grouping and Outros-bucket tests.
    """
    db = SessionLocal()
    owner_connection = PluggyConnection(
        household_id=household_id,
        pluggy_item_id=f"item-owner-{uuid.uuid4()}",
        status="UPDATED",
        created_by_app_user_id=owner_app_user_id,
    )
    second_connection = PluggyConnection(
        household_id=household_id,
        pluggy_item_id=f"item-second-{uuid.uuid4()}",
        status="UPDATED",
        created_by_app_user_id=second_app_user_id,
    )
    unattributed_connection = PluggyConnection(
        household_id=household_id,
        pluggy_item_id=f"item-unattributed-{uuid.uuid4()}",
        status="UPDATED",
    )
    db.add_all([owner_connection, second_connection, unattributed_connection])
    db.flush()

    owner_account = Account(
        household_id=household_id,
        pluggy_connection_id=owner_connection.id,
        pluggy_account_id="acc-owner",
        name="Owner Checking",
        type="BANK",
        balance=0.0,
        currency_code="BRL",
    )
    second_account = Account(
        household_id=household_id,
        pluggy_connection_id=second_connection.id,
        pluggy_account_id="acc-second",
        name="Second Checking",
        type="BANK",
        balance=0.0,
        currency_code="BRL",
    )
    unattributed_account = Account(
        household_id=household_id,
        pluggy_connection_id=unattributed_connection.id,
        pluggy_account_id="acc-unattributed",
        name="Unattributed Checking",
        type="BANK",
        balance=0.0,
        currency_code="BRL",
    )
    db.add_all([owner_account, second_account, unattributed_account])
    db.flush()

    db.add_all(
        [
            Transaction(
                household_id=household_id,
                account_id=owner_account.id,
                pluggy_transaction_id="txn-owner-spend",
                description="Owner spend",
                amount=-50.0,
                currency_code="BRL",
                transaction_date="2026-07-10",
                category="Food",
            ),
            Transaction(
                household_id=household_id,
                account_id=second_account.id,
                pluggy_transaction_id="txn-second-spend",
                description="Second spend",
                amount=-20.0,
                currency_code="BRL",
                transaction_date="2026-07-11",
                category="Food",
            ),
            Transaction(
                household_id=household_id,
                account_id=unattributed_account.id,
                pluggy_transaction_id="txn-unattributed-spend",
                description="Unattributed spend",
                amount=-10.0,
                currency_code="BRL",
                transaction_date="2026-07-12",
                category="Food",
            ),
        ]
    )
    db.commit()
    db.close()


def test_spending_by_member_groups_by_month_and_member(client, make_user):
    headers_owner = make_user("spendowner@example.com")
    household = client.post(
        "/v1/households", json={"name": "Spend Family"}, headers=headers_owner
    ).json()

    headers_second = make_user("spendsecond@example.com")
    client.get("/v1/me", headers=headers_second)

    db = SessionLocal()
    owner_user = db.query(AppUser).filter(AppUser.email == "spendowner@example.com").one()
    second_user = (
        db.query(AppUser).filter(AppUser.email == "spendsecond@example.com").one()
    )
    second_member = HouseholdMember(
        household_id=household["id"], app_user_id=second_user.id, role="member"
    )
    db.add(second_member)
    db.commit()
    owner_member_id = str(
        db.query(HouseholdMember)
        .filter(
            HouseholdMember.household_id == household["id"],
            HouseholdMember.app_user_id == owner_user.id,
        )
        .one()
        .id
    )
    second_member_id = str(second_member.id)
    owner_user_id = owner_user.id
    second_user_id = second_user.id
    db.close()

    _seed_member_spend_data(household["id"], owner_user_id, second_user_id)

    response = client.get(
        f"/v1/households/{household['id']}/spending-by-member",
        params={"start_date": "2026-07-01", "end_date": "2026-07-31"},
        headers=headers_owner,
    )

    assert response.status_code == 200
    body = response.json()
    totals_by_member = {row["member_id"]: row["total"] for row in body}
    assert totals_by_member[owner_member_id] == 50.0
    assert totals_by_member[second_member_id] == 20.0
    assert totals_by_member[None] == 10.0
    assert all(row["month"] == "2026-07" for row in body)


def test_spending_by_member_filters_by_member_ids(client, make_user):
    headers_owner = make_user("spendscopeowner@example.com")
    household = client.post(
        "/v1/households", json={"name": "Spend Scope Family"}, headers=headers_owner
    ).json()

    headers_second = make_user("spendscopesecond@example.com")
    client.get("/v1/me", headers=headers_second)

    db = SessionLocal()
    owner_user = (
        db.query(AppUser).filter(AppUser.email == "spendscopeowner@example.com").one()
    )
    second_user = (
        db.query(AppUser).filter(AppUser.email == "spendscopesecond@example.com").one()
    )
    second_member = HouseholdMember(
        household_id=household["id"], app_user_id=second_user.id, role="member"
    )
    db.add(second_member)
    db.commit()
    second_member_id = second_member.id
    owner_user_id = owner_user.id
    second_user_id = second_user.id
    db.close()

    _seed_member_spend_data(household["id"], owner_user_id, second_user_id)

    response = client.get(
        f"/v1/households/{household['id']}/spending-by-member",
        params={
            "start_date": "2026-07-01",
            "end_date": "2026-07-31",
            "member_ids": [str(second_member_id)],
        },
        headers=headers_owner,
    )

    assert response.status_code == 200
    body = response.json()
    assert len(body) == 1
    assert body[0]["member_id"] == str(second_member_id)
    assert body[0]["total"] == 20.0


def test_spending_by_member_does_not_fan_out_across_households(client, make_user):
    """A guard against the join in `_connection_member_map` matching a
    `HouseholdMember` row from a *different* household that happens to
    share the same `app_user_id` — which would double-count this
    household's own transaction if the join weren't scoped by
    `household_id`.
    """
    headers_owner = make_user("fanoutowner@example.com")
    household_a = client.post(
        "/v1/households", json={"name": "Fanout Family A"}, headers=headers_owner
    ).json()
    household_b = client.post(
        "/v1/households", json={"name": "Fanout Family B"}, headers=headers_owner
    ).json()

    db = SessionLocal()
    owner_user = (
        db.query(AppUser).filter(AppUser.email == "fanoutowner@example.com").one()
    )
    # The owner is already a HouseholdMember row in both A and B (one per
    # household, created by the household-creation flow) — exactly the
    # shared-app_user_id-across-households shape this test guards against.
    connection = PluggyConnection(
        household_id=household_a["id"],
        pluggy_item_id=f"item-fanout-{uuid.uuid4()}",
        status="UPDATED",
        created_by_app_user_id=owner_user.id,
    )
    db.add(connection)
    db.flush()
    account = Account(
        household_id=household_a["id"],
        pluggy_connection_id=connection.id,
        pluggy_account_id="acc-fanout",
        name="Fanout Checking",
        type="BANK",
        balance=0.0,
        currency_code="BRL",
    )
    db.add(account)
    db.flush()
    db.add(
        Transaction(
            household_id=household_a["id"],
            account_id=account.id,
            pluggy_transaction_id="txn-fanout",
            description="Fanout spend",
            amount=-75.0,
            currency_code="BRL",
            transaction_date="2026-07-10",
            category="Food",
        )
    )
    db.commit()
    owner_member_id = str(
        db.query(HouseholdMember)
        .filter(
            HouseholdMember.household_id == household_a["id"],
            HouseholdMember.app_user_id == owner_user.id,
        )
        .one()
        .id
    )
    db.close()

    response = client.get(
        f"/v1/households/{household_a['id']}/spending-by-member",
        params={"start_date": "2026-07-01", "end_date": "2026-07-31"},
        headers=headers_owner,
    )

    assert response.status_code == 200
    body = response.json()
    assert len(body) == 1
    assert body[0]["member_id"] == owner_member_id
    assert body[0]["total"] == 75.0


def test_family_a_cannot_view_family_b_spending_by_member(client, make_user):
    headers_a = make_user("spend-isoa@example.com")
    headers_b = make_user("spend-isob@example.com")
    household_a = client.post(
        "/v1/households", json={"name": "Spend Iso Family A"}, headers=headers_a
    ).json()
    _seed_extended_finance_data(household_a["id"])

    response = client.get(
        f"/v1/households/{household_a['id']}/spending-by-member", headers=headers_b
    )

    assert response.status_code == 403


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
