import time
import uuid

import jwt
import pytest
from fastapi.testclient import TestClient

from app.api.anomalies import get_llm_provider
from app.database.session import SessionLocal
from app.main import app
from app.models.account import Account
from app.models.anomaly import AnomalyFlag
from app.models.app_user import AppUser
from app.models.audit_event import AuditEvent
from app.models.household import Household, HouseholdMember
from app.models.pluggy_connection import PluggyConnection
from app.models.rate_limit_hit import RateLimitHit
from app.models.transaction import Transaction
from app.settings import settings


class _FakeLLMProvider:
    def __init__(
        self, explanation="This looks unusual because it's much larger than normal.", error=None
    ):
        self.explanation = explanation
        self.error = error
        self.calls = []

    def explain_anomaly(self, context):
        self.calls.append(context)
        if self.error is not None:
            raise self.error
        return self.explanation


@pytest.fixture(autouse=True)
def hs256_secret(monkeypatch):
    monkeypatch.setattr(settings, "supabase_url", "")
    monkeypatch.setattr(settings, "supabase_jwt_secret", "test-secret")
    monkeypatch.setattr(settings, "supabase_jwt_audience", "authenticated")
    monkeypatch.setattr(settings, "supabase_jwt_issuer", "")


@pytest.fixture
def fake_provider():
    provider = _FakeLLMProvider()
    app.dependency_overrides[get_llm_provider] = lambda: provider
    yield provider
    app.dependency_overrides.pop(get_llm_provider, None)


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
            db.query(RateLimitHit).filter(
                RateLimitHit.scope.in_(
                    [f"anomaly_explain:{hid}" for hid in household_ids]
                )
            ).delete(synchronize_session=False)
            db.query(AuditEvent).filter(
                AuditEvent.household_id.in_(household_ids)
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


def _seed_flag(household_id, *, with_transaction=True, status="open"):
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
        balance=100.0,
        currency_code="BRL",
    )
    db.add(account)
    db.flush()

    transaction_id = None
    if with_transaction:
        txn = Transaction(
            household_id=household_id,
            account_id=account.id,
            pluggy_transaction_id="txn-1",
            description="Suspicious Purchase",
            amount=-2000.0,
            currency_code="BRL",
            transaction_date="2026-07-20",
            category="Shopping",
        )
        db.add(txn)
        db.flush()
        transaction_id = txn.id

    flag = AnomalyFlag(
        household_id=household_id,
        transaction_id=transaction_id,
        rule="large_transaction",
        dedupe_key=str(transaction_id or uuid.uuid4()),
        severity="high",
        score=5.2,
        summary="R$ 2000.00 is much larger than usual",
        status=status,
    )
    db.add(flag)
    db.commit()
    flag_id = flag.id
    db.close()
    return flag_id


def test_list_anomalies(client, make_user):
    headers = make_user("anomaly-list@example.com")
    household = client.post(
        "/v1/households", json={"name": "Anomaly List Family"}, headers=headers
    ).json()
    _seed_flag(household["id"])

    response = client.get(f"/v1/households/{household['id']}/anomalies", headers=headers)

    assert response.status_code == 200
    body = response.json()
    assert len(body) == 1
    assert body[0]["rule"] == "large_transaction"
    assert body[0]["status"] == "open"


def test_list_anomalies_filters_by_status(client, make_user):
    headers = make_user("anomaly-filter@example.com")
    household = client.post(
        "/v1/households", json={"name": "Anomaly Filter Family"}, headers=headers
    ).json()
    _seed_flag(household["id"], status="dismissed")

    response = client.get(
        f"/v1/households/{household['id']}/anomalies",
        params={"status_filter": "open"},
        headers=headers,
    )

    assert response.status_code == 200
    assert response.json() == []


def test_explain_anomaly_uses_injected_provider(client, make_user, fake_provider):
    headers = make_user("anomaly-explain@example.com")
    household = client.post(
        "/v1/households", json={"name": "Anomaly Explain Family"}, headers=headers
    ).json()
    flag_id = _seed_flag(household["id"])

    response = client.post(
        f"/v1/households/{household['id']}/anomalies/{flag_id}/explain", headers=headers
    )

    assert response.status_code == 200
    body = response.json()
    assert body["explanation"] == fake_provider.explanation
    assert body["explained_at"] is not None

    assert len(fake_provider.calls) == 1
    context = fake_provider.calls[0]
    assert "raw_json" not in context
    assert context["amount"] == -2000.0
    assert context["description"] == "Suspicious Purchase"


def test_patch_anomaly_status(client, make_user):
    headers = make_user("anomaly-patch@example.com")
    household = client.post(
        "/v1/households", json={"name": "Anomaly Patch Family"}, headers=headers
    ).json()
    flag_id = _seed_flag(household["id"])

    response = client.patch(
        f"/v1/households/{household['id']}/anomalies/{flag_id}",
        json={"status": "confirmed"},
        headers=headers,
    )

    assert response.status_code == 200
    assert response.json()["status"] == "confirmed"


def test_explain_anomaly_not_found_returns_404(client, make_user, fake_provider):
    headers = make_user("anomaly-404@example.com")
    household = client.post(
        "/v1/households", json={"name": "Anomaly 404 Family"}, headers=headers
    ).json()

    response = client.post(
        f"/v1/households/{household['id']}/anomalies/{uuid.uuid4()}/explain", headers=headers
    )

    assert response.status_code == 404


def test_family_a_cannot_view_family_b_anomalies(client, make_user):
    headers_a = make_user("anomaly-isoa@example.com")
    headers_b = make_user("anomaly-isob@example.com")
    household_a = client.post(
        "/v1/households", json={"name": "Anomaly Iso Family A"}, headers=headers_a
    ).json()
    _seed_flag(household_a["id"])

    response = client.get(
        f"/v1/households/{household_a['id']}/anomalies", headers=headers_b
    )

    assert response.status_code == 403


def test_family_a_cannot_explain_family_b_anomaly(client, make_user, fake_provider):
    headers_a = make_user("anomaly-explainisoa@example.com")
    headers_b = make_user("anomaly-explainisob@example.com")
    household_a = client.post(
        "/v1/households", json={"name": "Anomaly Explain Iso Family A"}, headers=headers_a
    ).json()
    flag_id = _seed_flag(household_a["id"])

    response = client.post(
        f"/v1/households/{household_a['id']}/anomalies/{flag_id}/explain", headers=headers_b
    )

    assert response.status_code == 403
    assert fake_provider.calls == []


def test_family_a_cannot_patch_family_b_anomaly(client, make_user):
    headers_a = make_user("anomaly-patchisoa@example.com")
    headers_b = make_user("anomaly-patchisob@example.com")
    household_a = client.post(
        "/v1/households", json={"name": "Anomaly Patch Iso Family A"}, headers=headers_a
    ).json()
    flag_id = _seed_flag(household_a["id"])

    response = client.patch(
        f"/v1/households/{household_a['id']}/anomalies/{flag_id}",
        json={"status": "dismissed"},
        headers=headers_b,
    )

    assert response.status_code == 403


def test_explain_anomaly_rate_limits_after_threshold(client, make_user, fake_provider):
    headers = make_user("anomaly-explain-rate@example.com")
    household = client.post(
        "/v1/households", json={"name": "Anomaly Explain Rate Family"}, headers=headers
    ).json()
    flag_id = _seed_flag(household["id"])

    db = SessionLocal()
    for _ in range(20):
        db.add(RateLimitHit(scope=f"anomaly_explain:{household['id']}"))
    db.commit()
    db.close()

    response = client.post(
        f"/v1/households/{household['id']}/anomalies/{flag_id}/explain", headers=headers
    )

    assert response.status_code == 429
    assert fake_provider.calls == []


def test_explain_anomaly_provider_failure_returns_503_and_records_audit_event(
    client, make_user
):
    headers = make_user("anomaly-explain-fail@example.com")
    household = client.post(
        "/v1/households", json={"name": "Anomaly Explain Fail Family"}, headers=headers
    ).json()
    flag_id = _seed_flag(household["id"])

    provider = _FakeLLMProvider(error=RuntimeError("provider exploded"))
    app.dependency_overrides[get_llm_provider] = lambda: provider

    try:
        response = client.post(
            f"/v1/households/{household['id']}/anomalies/{flag_id}/explain", headers=headers
        )
    finally:
        app.dependency_overrides.pop(get_llm_provider, None)

    assert response.status_code == 503
    assert "provider exploded" not in response.text

    db = SessionLocal()
    events = (
        db.query(AuditEvent)
        .filter(
            AuditEvent.household_id == household["id"],
            AuditEvent.action == "anomaly_explain.call_failed",
        )
        .all()
    )
    db.close()
    assert len(events) == 1
    assert "provider exploded" in events[0].metadata_json["error"]
