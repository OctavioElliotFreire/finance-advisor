import time
import uuid
from datetime import date

import jwt
import pytest
from fastapi.testclient import TestClient

from app.api.assistant import get_assistant_provider
from app.api.household_members import get_invite_sender
from app.database.session import SessionLocal
from app.main import app
from app.models.account import Account
from app.models.anomaly import AnomalyFlag
from app.models.app_user import AppUser
from app.models.assistant import AssistantMessage
from app.models.audit_event import AuditEvent
from app.models.connection_access_grant import ConnectionAccessGrant
from app.models.extended_finance import BalanceSnapshot, CreditCardBill, Investment, Loan
from app.models.household import Household, HouseholdMember
from app.models.household_invite import HouseholdInvite
from app.models.pluggy_connection import PluggyConnection, SyncJob
from app.models.rate_limit_hit import RateLimitHit
from app.models.transaction import Transaction
from app.settings import settings


class _FakeInviteSender:
    async def invite_user_by_email(self, email, redirect_to):
        return {}


class _FakeLLMProvider:
    def __init__(self):
        self.calls = []

    def explain_anomaly(self, context):
        raise NotImplementedError

    def answer_question(self, system_prompt, user_message):
        self.calls.append(user_message)
        return "fake answer"


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
def fake_invite_sender():
    sender = _FakeInviteSender()
    app.dependency_overrides[get_invite_sender] = lambda: sender
    yield sender
    app.dependency_overrides.pop(get_invite_sender, None)


@pytest.fixture
def fake_provider():
    provider = _FakeLLMProvider()
    app.dependency_overrides[get_assistant_provider] = lambda: provider
    yield provider
    app.dependency_overrides.pop(get_assistant_provider, None)


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
            db.query(HouseholdMember)
            .filter(HouseholdMember.app_user_id.in_(app_user_ids))
            .all()
        )
        household_ids = [row.household_id for row in member_rows]
        member_ids = [row.id for row in member_rows]

        db.query(ConnectionAccessGrant).filter(
            ConnectionAccessGrant.household_member_id.in_(member_ids)
        ).delete(synchronize_session=False)
        db.query(HouseholdInvite).filter(
            HouseholdInvite.invited_by_app_user_id.in_(app_user_ids)
            | HouseholdInvite.household_id.in_(household_ids)
        ).delete(synchronize_session=False)
        if household_ids:
            db.query(AssistantMessage).filter(
                AssistantMessage.household_id.in_(household_ids)
            ).delete(synchronize_session=False)
            db.query(AnomalyFlag).filter(
                AnomalyFlag.household_id.in_(household_ids)
            ).delete(synchronize_session=False)
            db.query(Transaction).filter(
                Transaction.household_id.in_(household_ids)
            ).delete(synchronize_session=False)
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
            db.query(Account).filter(Account.household_id.in_(household_ids)).delete(
                synchronize_session=False
            )
            db.query(SyncJob).filter(SyncJob.household_id.in_(household_ids)).delete(
                synchronize_session=False
            )
            db.query(PluggyConnection).filter(
                PluggyConnection.household_id.in_(household_ids)
            ).delete(synchronize_session=False)
            db.query(AuditEvent).filter(
                AuditEvent.household_id.in_(household_ids)
            ).delete(synchronize_session=False)
            db.query(RateLimitHit).filter(
                RateLimitHit.scope.in_(
                    [f"connections_token:{hid}" for hid in household_ids]
                    + [f"connections_create:{hid}" for hid in household_ids]
                    + [f"anomaly_explain:{hid}" for hid in household_ids]
                    + [f"assistant_ask:{hid}" for hid in household_ids]
                    + [f"member_invite:{hid}" for hid in household_ids]
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


def _seed_two_connections(household_id):
    """Two connections, each with one account/transaction/investment/loan/bill,
    plus one household-wide category-deviation anomaly (transaction_id=None,
    can't be attributed to either connection)."""
    db = SessionLocal()

    conn_a = PluggyConnection(
        household_id=household_id, pluggy_item_id=f"item-a-{uuid.uuid4()}", status="UPDATED"
    )
    conn_b = PluggyConnection(
        household_id=household_id, pluggy_item_id=f"item-b-{uuid.uuid4()}", status="UPDATED"
    )
    db.add_all([conn_a, conn_b])
    db.flush()

    account_a = Account(
        household_id=household_id,
        pluggy_connection_id=conn_a.id,
        pluggy_account_id="acc-a",
        name="Account A",
        type="BANK",
        balance=100.0,
        currency_code="BRL",
    )
    account_b = Account(
        household_id=household_id,
        pluggy_connection_id=conn_b.id,
        pluggy_account_id="acc-b",
        name="Account B",
        type="BANK",
        balance=200.0,
        currency_code="BRL",
    )
    db.add_all([account_a, account_b])
    db.flush()

    txn_a = Transaction(
        household_id=household_id,
        account_id=account_a.id,
        pluggy_transaction_id="txn-a",
        description="Groceries A",
        amount=-50.0,
        currency_code="BRL",
        transaction_date=date.today(),
        category="Food",
    )
    txn_b = Transaction(
        household_id=household_id,
        account_id=account_b.id,
        pluggy_transaction_id="txn-b",
        description="Groceries B",
        amount=-60.0,
        currency_code="BRL",
        transaction_date=date.today(),
        category="Food",
    )
    db.add_all([txn_a, txn_b])
    db.flush()

    db.add_all(
        [
            Investment(
                household_id=household_id,
                pluggy_connection_id=conn_a.id,
                pluggy_investment_id="inv-a",
                name="Investment A",
                type="FIXED_INCOME",
                balance=1000.0,
                currency_code="BRL",
            ),
            Investment(
                household_id=household_id,
                pluggy_connection_id=conn_b.id,
                pluggy_investment_id="inv-b",
                name="Investment B",
                type="FIXED_INCOME",
                balance=2000.0,
                currency_code="BRL",
            ),
            Loan(
                household_id=household_id,
                pluggy_connection_id=conn_a.id,
                pluggy_loan_id="loan-a",
                type="PERSONAL",
                outstanding_balance=500.0,
                currency_code="BRL",
            ),
            Loan(
                household_id=household_id,
                pluggy_connection_id=conn_b.id,
                pluggy_loan_id="loan-b",
                type="PERSONAL",
                outstanding_balance=600.0,
                currency_code="BRL",
            ),
            CreditCardBill(
                household_id=household_id,
                account_id=account_a.id,
                pluggy_bill_id="bill-a",
                total_amount=300.0,
                currency_code="BRL",
            ),
            CreditCardBill(
                household_id=household_id,
                account_id=account_b.id,
                pluggy_bill_id="bill-b",
                total_amount=400.0,
                currency_code="BRL",
            ),
            BalanceSnapshot(
                household_id=household_id,
                account_id=account_a.id,
                balance=100.0,
                currency_code="BRL",
                snapshot_date=date.today(),
            ),
            BalanceSnapshot(
                household_id=household_id,
                account_id=account_b.id,
                balance=200.0,
                currency_code="BRL",
                snapshot_date=date.today(),
            ),
            SyncJob(household_id=household_id, pluggy_connection_id=conn_a.id, status="completed"),
            SyncJob(household_id=household_id, pluggy_connection_id=conn_b.id, status="completed"),
        ]
    )

    db.add_all(
        [
            AnomalyFlag(
                household_id=household_id,
                transaction_id=txn_a.id,
                rule="large_transaction",
                dedupe_key=str(txn_a.id),
                severity="high",
                summary="Anomaly A",
                status="open",
            ),
            AnomalyFlag(
                household_id=household_id,
                transaction_id=txn_b.id,
                rule="large_transaction",
                dedupe_key=str(txn_b.id),
                severity="high",
                summary="Anomaly B",
                status="open",
            ),
            AnomalyFlag(
                household_id=household_id,
                transaction_id=None,
                rule="category_deviation",
                dedupe_key=f"cat-{uuid.uuid4()}",
                severity="medium",
                summary="Category-wide anomaly",
                status="open",
            ),
        ]
    )

    db.commit()
    ids = {"conn_a": conn_a.id, "conn_b": conn_b.id}
    db.close()
    return ids


def _invite_and_get_member_id(client, headers_owner, headers_member, household_id, email):
    client.get("/v1/me", headers=headers_member)
    response = client.post(
        f"/v1/households/{household_id}/members",
        json={"email": email, "role": "member"},
        headers=headers_owner,
    )
    assert response.status_code == 201
    assert response.json()["outcome"] == "added"
    return response.json()["member"]["id"]


def test_owner_sees_everything_unrestricted(client, make_user):
    headers_owner = make_user("access-owner1@example.com")
    household = client.post(
        "/v1/households", json={"name": "Access Family 1"}, headers=headers_owner
    ).json()
    _seed_two_connections(household["id"])

    dashboard = client.get(
        f"/v1/households/{household['id']}/dashboard", headers=headers_owner
    ).json()
    assert len(dashboard["accounts"]) == 2

    anomalies = client.get(
        f"/v1/households/{household['id']}/anomalies", headers=headers_owner
    ).json()
    assert len(anomalies) == 3

    connections = client.get(
        f"/v1/households/{household['id']}/connections", headers=headers_owner
    ).json()
    assert len(connections) == 2


def test_restricted_member_sees_only_granted_connection(client, make_user):
    headers_owner = make_user("access-owner2@example.com")
    headers_member = make_user("access-member2@example.com")
    household = client.post(
        "/v1/households", json={"name": "Access Family 2"}, headers=headers_owner
    ).json()
    ids = _seed_two_connections(household["id"])
    member_id = _invite_and_get_member_id(
        client, headers_owner, headers_member, household["id"], "access-member2@example.com"
    )

    put_response = client.put(
        f"/v1/households/{household['id']}/members/{member_id}/access",
        json={"connection_ids": [str(ids["conn_a"])]},
        headers=headers_owner,
    )
    assert put_response.status_code == 200
    granted = [e for e in put_response.json() if e["granted"]]
    assert len(granted) == 1

    dashboard = client.get(
        f"/v1/households/{household['id']}/dashboard", headers=headers_member
    ).json()
    assert len(dashboard["accounts"]) == 1
    assert dashboard["accounts"][0]["name"] == "Account A"

    investments = client.get(
        f"/v1/households/{household['id']}/investments", headers=headers_member
    ).json()
    assert [i["name"] for i in investments] == ["Investment A"]

    loans = client.get(
        f"/v1/households/{household['id']}/loans", headers=headers_member
    ).json()
    assert len(loans) == 1

    bills = client.get(
        f"/v1/households/{household['id']}/credit-card-bills", headers=headers_member
    ).json()
    assert len(bills) == 1

    balance_history = client.get(
        f"/v1/households/{household['id']}/balance-history", headers=headers_member
    ).json()
    assert all(point["total_balance"] == 100.0 for point in balance_history)

    categories = client.get(
        f"/v1/households/{household['id']}/categories", headers=headers_member
    ).json()
    assert sum(c["total"] for c in categories) == 50.0

    anomalies = client.get(
        f"/v1/households/{household['id']}/anomalies", headers=headers_member
    ).json()
    assert len(anomalies) == 1
    assert anomalies[0]["summary"] == "Anomaly A"

    connections = client.get(
        f"/v1/households/{household['id']}/connections", headers=headers_member
    ).json()
    assert len(connections) == 1


def test_member_granted_every_connection_is_unrestricted(client, make_user):
    headers_owner = make_user("access-owner3@example.com")
    headers_member = make_user("access-member3@example.com")
    household = client.post(
        "/v1/households", json={"name": "Access Family 3"}, headers=headers_owner
    ).json()
    ids = _seed_two_connections(household["id"])
    member_id = _invite_and_get_member_id(
        client, headers_owner, headers_member, household["id"], "access-member3@example.com"
    )

    client.put(
        f"/v1/households/{household['id']}/members/{member_id}/access",
        json={"connection_ids": [str(ids["conn_a"]), str(ids["conn_b"])]},
        headers=headers_owner,
    )

    anomalies = client.get(
        f"/v1/households/{household['id']}/anomalies", headers=headers_member
    ).json()
    assert len(anomalies) == 3

    dashboard = client.get(
        f"/v1/households/{household['id']}/dashboard", headers=headers_member
    ).json()
    assert len(dashboard["accounts"]) == 2


def test_access_endpoints_are_owner_only(client, make_user):
    headers_owner = make_user("access-owner4@example.com")
    headers_member = make_user("access-member4@example.com")
    household = client.post(
        "/v1/households", json={"name": "Access Family 4"}, headers=headers_owner
    ).json()
    member_id = _invite_and_get_member_id(
        client, headers_owner, headers_member, household["id"], "access-member4@example.com"
    )

    get_response = client.get(
        f"/v1/households/{household['id']}/members/{member_id}/access", headers=headers_member
    )
    put_response = client.put(
        f"/v1/households/{household['id']}/members/{member_id}/access",
        json={"connection_ids": []},
        headers=headers_member,
    )

    assert get_response.status_code == 403
    assert put_response.status_code == 403


def test_get_member_access_lists_all_connections_with_granted_flag(client, make_user):
    headers_owner = make_user("access-owner5@example.com")
    headers_member = make_user("access-member5@example.com")
    household = client.post(
        "/v1/households", json={"name": "Access Family 5"}, headers=headers_owner
    ).json()
    ids = _seed_two_connections(household["id"])
    member_id = _invite_and_get_member_id(
        client, headers_owner, headers_member, household["id"], "access-member5@example.com"
    )

    before = client.get(
        f"/v1/households/{household['id']}/members/{member_id}/access", headers=headers_owner
    ).json()
    assert len(before) == 2
    assert all(not e["granted"] for e in before)

    client.put(
        f"/v1/households/{household['id']}/members/{member_id}/access",
        json={"connection_ids": [str(ids["conn_b"])]},
        headers=headers_owner,
    )
    after = client.get(
        f"/v1/households/{household['id']}/members/{member_id}/access", headers=headers_owner
    ).json()
    granted = {e["connection_id"] for e in after if e["granted"]}
    assert granted == {str(ids["conn_b"])}


def test_update_member_access_ignores_connection_from_another_household(client, make_user):
    headers_owner = make_user("access-owner6@example.com")
    headers_member = make_user("access-member6@example.com")
    household = client.post(
        "/v1/households", json={"name": "Access Family 6"}, headers=headers_owner
    ).json()
    _seed_two_connections(household["id"])
    member_id = _invite_and_get_member_id(
        client, headers_owner, headers_member, household["id"], "access-member6@example.com"
    )

    other_household = client.post(
        "/v1/households", json={"name": "Other Family 6"}, headers=headers_owner
    ).json()
    other_ids = _seed_two_connections(other_household["id"])

    response = client.put(
        f"/v1/households/{household['id']}/members/{member_id}/access",
        json={"connection_ids": [str(other_ids["conn_a"])]},
        headers=headers_owner,
    )

    assert response.status_code == 200
    assert all(not e["granted"] for e in response.json())


def test_assistant_context_excludes_ungranted_connection_data(
    client, make_user, fake_provider, fake_invite_sender
):
    headers_owner = make_user("access-owner7@example.com")
    headers_member = make_user("access-member7@example.com")
    household = client.post(
        "/v1/households", json={"name": "Access Family 7"}, headers=headers_owner
    ).json()
    ids = _seed_two_connections(household["id"])
    member_id = _invite_and_get_member_id(
        client, headers_owner, headers_member, household["id"], "access-member7@example.com"
    )
    client.put(
        f"/v1/households/{household['id']}/members/{member_id}/access",
        json={"connection_ids": [str(ids["conn_a"])]},
        headers=headers_owner,
    )

    response = client.post(
        f"/v1/households/{household['id']}/assistant/ask",
        json={"question": "What do I have?"},
        headers=headers_member,
    )

    assert response.status_code == 200
    assert len(fake_provider.calls) == 1
    context_message = fake_provider.calls[0]
    assert "Account A" in context_message
    assert "Account B" not in context_message
    assert "Investment A" in context_message
    assert "Investment B" not in context_message
