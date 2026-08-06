import time
import uuid

import jwt
import pytest
from fastapi.testclient import TestClient

from app.api.assistant import get_assistant_provider
from app.database.session import SessionLocal
from app.main import app
from app.models.app_user import AppUser
from app.models.assistant import AssistantMessage
from app.models.household import Household, HouseholdMember
from app.models.rate_limit_hit import RateLimitHit
from app.settings import settings


class _FakeLLMProvider:
    def __init__(self, answer="You spent R$50 on Food this month.", error=None):
        self.answer = answer
        self.error = error
        self.calls = []

    def explain_anomaly(self, context):
        raise NotImplementedError

    def answer_question(self, system_prompt, user_message):
        self.calls.append((system_prompt, user_message))
        if self.error is not None:
            raise self.error
        return self.answer


@pytest.fixture(autouse=True)
def hs256_secret(monkeypatch):
    monkeypatch.setattr(settings, "supabase_url", "")
    monkeypatch.setattr(settings, "supabase_jwt_secret", "test-secret")
    monkeypatch.setattr(settings, "supabase_jwt_audience", "authenticated")
    monkeypatch.setattr(settings, "supabase_jwt_issuer", "")


@pytest.fixture
def fake_provider():
    provider = _FakeLLMProvider()
    app.dependency_overrides[get_assistant_provider] = lambda: provider
    yield provider
    app.dependency_overrides.pop(get_assistant_provider, None)


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
            db.query(AssistantMessage).filter(
                AssistantMessage.household_id.in_(household_ids)
            ).delete(synchronize_session=False)
            db.query(RateLimitHit).filter(
                RateLimitHit.scope.in_(
                    [f"assistant_ask:{hid}" for hid in household_ids]
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


def test_ask_assistant_returns_answer_and_persists(client, make_user, fake_provider):
    headers = make_user("assistant-ask@example.com")
    household = client.post(
        "/v1/households", json={"name": "Assistant Family"}, headers=headers
    ).json()

    response = client.post(
        f"/v1/households/{household['id']}/assistant/ask",
        json={"question": "How much did I spend on Food?"},
        headers=headers,
    )

    assert response.status_code == 200
    body = response.json()
    assert body["question"] == "How much did I spend on Food?"
    assert body["answer"] == fake_provider.answer
    assert body["asked_by_email"] == "assistant-ask@example.com"

    assert len(fake_provider.calls) == 1
    system_prompt, user_message = fake_provider.calls[0]
    assert "household" in system_prompt.lower()
    assert "Assistant Family" in user_message
    assert "How much did I spend on Food?" in user_message

    history = client.get(
        f"/v1/households/{household['id']}/assistant", headers=headers
    )
    assert history.status_code == 200
    assert len(history.json()) == 1
    assert history.json()[0]["question"] == "How much did I spend on Food?"


def test_ask_assistant_rejects_empty_question(client, make_user, fake_provider):
    headers = make_user("assistant-empty@example.com")
    household = client.post(
        "/v1/households", json={"name": "Assistant Empty Family"}, headers=headers
    ).json()

    response = client.post(
        f"/v1/households/{household['id']}/assistant/ask",
        json={"question": ""},
        headers=headers,
    )

    assert response.status_code == 422
    assert fake_provider.calls == []


def test_ask_assistant_rejects_too_long_question(client, make_user, fake_provider):
    headers = make_user("assistant-long@example.com")
    household = client.post(
        "/v1/households", json={"name": "Assistant Long Family"}, headers=headers
    ).json()

    response = client.post(
        f"/v1/households/{household['id']}/assistant/ask",
        json={"question": "x" * 501},
        headers=headers,
    )

    assert response.status_code == 422
    assert fake_provider.calls == []


def test_ask_assistant_rate_limits_after_threshold(client, make_user, fake_provider):
    headers = make_user("assistant-rate@example.com")
    household = client.post(
        "/v1/households", json={"name": "Assistant Rate Family"}, headers=headers
    ).json()

    db = SessionLocal()
    for i in range(20):
        db.add(RateLimitHit(scope=f"assistant_ask:{household['id']}"))
    db.commit()
    db.close()

    response = client.post(
        f"/v1/households/{household['id']}/assistant/ask",
        json={"question": "One more question?"},
        headers=headers,
    )

    assert response.status_code == 429
    assert fake_provider.calls == []


def test_ask_assistant_provider_failure_returns_503_not_500(client, make_user):
    headers = make_user("assistant-fail@example.com")
    household = client.post(
        "/v1/households", json={"name": "Assistant Fail Family"}, headers=headers
    ).json()
    provider = _FakeLLMProvider(error=RuntimeError("provider exploded"))
    app.dependency_overrides[get_assistant_provider] = lambda: provider

    try:
        response = client.post(
            f"/v1/households/{household['id']}/assistant/ask",
            json={"question": "Will this fail?"},
            headers=headers,
        )
    finally:
        app.dependency_overrides.pop(get_assistant_provider, None)

    assert response.status_code == 503
    assert "provider exploded" not in response.text

    history = client.get(
        f"/v1/households/{household['id']}/assistant", headers=headers
    )
    assert history.json() == []


def test_viewer_can_ask_assistant(client, make_user, fake_provider):
    headers_owner = make_user("assistant-viewowner@example.com")
    headers_viewer = make_user("assistant-viewviewer@example.com")
    household = client.post(
        "/v1/households", json={"name": "Assistant Viewer Family"}, headers=headers_owner
    ).json()
    client.get("/v1/me", headers=headers_viewer)

    db = SessionLocal()
    viewer_user = (
        db.query(AppUser)
        .filter(AppUser.email == "assistant-viewviewer@example.com")
        .one()
    )
    db.add(
        HouseholdMember(
            household_id=household["id"], app_user_id=viewer_user.id, role="viewer"
        )
    )
    db.commit()
    db.close()

    response = client.post(
        f"/v1/households/{household['id']}/assistant/ask",
        json={"question": "Can a viewer ask?"},
        headers=headers_viewer,
    )

    assert response.status_code == 200


def test_family_a_cannot_ask_or_view_family_b_assistant(client, make_user, fake_provider):
    headers_a = make_user("assistant-isoa@example.com")
    headers_b = make_user("assistant-isob@example.com")
    household_a = client.post(
        "/v1/households", json={"name": "Assistant Iso Family A"}, headers=headers_a
    ).json()

    ask_response = client.post(
        f"/v1/households/{household_a['id']}/assistant/ask",
        json={"question": "Can I see family A's data?"},
        headers=headers_b,
    )
    assert ask_response.status_code == 403
    assert fake_provider.calls == []

    list_response = client.get(
        f"/v1/households/{household_a['id']}/assistant", headers=headers_b
    )
    assert list_response.status_code == 403
