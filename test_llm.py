import json
import os

import pytest

from llm.base import get_provider
from llm.providers.anthropic import AnthropicProvider, MAX_TRANSACTIONS
from llm.providers.gemini import GeminiProvider


class FakeContentBlock:
    def __init__(self, text):
        self.text = text


class FakeResponse:
    def __init__(self, text):
        self.content = [FakeContentBlock(text)]


class FakeMessages:
    def __init__(self, response_text):
        self.response_text = response_text
        self.last_call = None

    def create(self, **kwargs):
        self.last_call = kwargs
        return FakeResponse(self.response_text)


class FakeClient:
    def __init__(self, response_text):
        self.messages = FakeMessages(response_text)


class FakeGeminiResponse:
    def __init__(self, text):
        self.text = text


class FakeModels:
    def __init__(self, response_text):
        self.response_text = response_text
        self.last_call = None

    def generate_content(self, **kwargs):
        self.last_call = kwargs
        return FakeGeminiResponse(self.response_text)


class FakeGeminiClient:
    def __init__(self, response_text):
        self.models = FakeModels(response_text)


TXNS = [
    {"id": "t1", "date": "2026-07-01", "description": "Market", "amount": -50.0,
     "currency_code": "BRL", "category": "Food", "merchant_name": "Supermarket", "type": "DEBIT"},
    {"id": "t2", "date": "2026-07-02", "description": "Salary", "amount": 8000.0,
     "currency_code": "BRL", "category": "Income", "merchant_name": None, "type": "CREDIT"},
    {"id": "t3", "date": "2026-07-03", "description": "Unknown Wire", "amount": -900.0,
     "currency_code": "BRL", "category": "Other", "merchant_name": None, "type": "DEBIT"},
]


# --- get_provider ---

def test_get_provider_defaults_to_anthropic(monkeypatch):
    monkeypatch.delenv("LLM_PROVIDER", raising=False)
    monkeypatch.setenv("ANTHROPIC_API_KEY", "fake-key")
    provider = get_provider()
    print(f"provider: {type(provider).__name__}, model: {provider.model}")
    assert isinstance(provider, AnthropicProvider)


def test_get_provider_unknown_raises(monkeypatch):
    monkeypatch.setenv("LLM_PROVIDER", "unknown")
    with pytest.raises(ValueError) as exc_info:
        get_provider()
    print(f"raised: {exc_info.value}")


def test_get_provider_returns_gemini(monkeypatch):
    monkeypatch.setenv("LLM_PROVIDER", "gemini")
    monkeypatch.setenv("GEMINI_API_KEY", "fake-key")
    provider = get_provider()
    print(f"provider: {type(provider).__name__}, model: {provider.model}")
    assert isinstance(provider, GeminiProvider)


# --- AnthropicProvider.analyze_transactions ---

def test_analyze_transactions_parses_valid_response():
    client = FakeClient(json.dumps({"flagged": [{"transaction_id": "t3", "reason": "Unusual amount"}]}))
    provider = AnthropicProvider(client=client)
    result = provider.analyze_transactions("Dad", TXNS)
    print(f"result: {result}")
    assert result == {"flagged": [{"transaction_id": "t3", "reason": "Unusual amount"}]}


def test_analyze_transactions_only_sends_debits():
    client = FakeClient(json.dumps({"flagged": []}))
    provider = AnthropicProvider(client=client)
    provider.analyze_transactions("Dad", TXNS)
    sent = json.loads(client.messages.last_call["messages"][0]["content"].split("\n", 2)[-1])
    ids = {t["id"] for t in sent}
    print(f"sent to LLM: {sent}")
    assert ids == {"t1", "t3"}


def test_analyze_transactions_caps_at_max():
    client = FakeClient(json.dumps({"flagged": []}))
    provider = AnthropicProvider(client=client)
    many_debits = [{**TXNS[0], "id": f"t{i}"} for i in range(MAX_TRANSACTIONS + 50)]
    provider.analyze_transactions("Dad", many_debits)
    sent = json.loads(client.messages.last_call["messages"][0]["content"].split("\n", 2)[-1])
    print(f"input debits: {len(many_debits)}, sent to LLM: {len(sent)}")
    assert len(sent) == MAX_TRANSACTIONS


def test_analyze_transactions_handles_malformed_json():
    client = FakeClient("not json at all")
    provider = AnthropicProvider(client=client)
    result = provider.analyze_transactions("Dad", TXNS)
    print(f"result on malformed json: {result}")
    assert result["flagged"] == []
    assert result["error"] == "invalid_json"


def test_analyze_transactions_defaults_missing_flagged_key():
    client = FakeClient(json.dumps({"note": "nothing suspicious"}))
    provider = AnthropicProvider(client=client)
    result = provider.analyze_transactions("Dad", TXNS)
    print(f"result with missing 'flagged' key: {result}")
    assert result["flagged"] == []


def test_analyze_transactions_uses_model_env(monkeypatch):
    monkeypatch.setenv("LLM_MODEL", "claude-haiku-4-5-20251001")
    client = FakeClient(json.dumps({"flagged": []}))
    provider = AnthropicProvider(client=client)
    provider.analyze_transactions("Dad", TXNS)
    print(f"model used in call: {client.messages.last_call['model']}")
    assert client.messages.last_call["model"] == "claude-haiku-4-5-20251001"


# --- GeminiProvider.analyze_transactions ---

def test_gemini_analyze_transactions_parses_valid_response():
    client = FakeGeminiClient(json.dumps({"flagged": [{"transaction_id": "t3", "reason": "Unusual amount"}]}))
    provider = GeminiProvider(client=client)
    result = provider.analyze_transactions("Dad", TXNS)
    print(f"result: {result}")
    assert result == {"flagged": [{"transaction_id": "t3", "reason": "Unusual amount"}]}


def test_gemini_analyze_transactions_only_sends_debits():
    client = FakeGeminiClient(json.dumps({"flagged": []}))
    provider = GeminiProvider(client=client)
    provider.analyze_transactions("Dad", TXNS)
    sent = json.loads(client.models.last_call["contents"].split("\n", 2)[-1])
    ids = {t["id"] for t in sent}
    print(f"sent to LLM: {sent}")
    assert ids == {"t1", "t3"}


def test_gemini_analyze_transactions_strips_markdown_code_fences():
    # Gemini sometimes wraps JSON in ```json ... ``` fences even with
    # response_mime_type set on older/edge-case responses -- must not be
    # silently discarded as invalid_json (real bug: 7 real flagged
    # transactions were lost this way before this fallback was added).
    fenced = "```json\n" + json.dumps({"flagged": [{"transaction_id": "t3", "reason": "Unusual amount"}]}) + "\n```"
    client = FakeGeminiClient(fenced)
    provider = GeminiProvider(client=client)
    result = provider.analyze_transactions("Dad", TXNS)
    print(f"result: {result}")
    assert result == {"flagged": [{"transaction_id": "t3", "reason": "Unusual amount"}]}


def test_gemini_analyze_transactions_requests_json_mime_type():
    client = FakeGeminiClient(json.dumps({"flagged": []}))
    provider = GeminiProvider(client=client)
    provider.analyze_transactions("Dad", TXNS)
    config = client.models.last_call["config"]
    print(f"response_mime_type: {config.response_mime_type}")
    assert config.response_mime_type == "application/json"


def test_gemini_analyze_transactions_handles_malformed_json():
    client = FakeGeminiClient("not json at all")
    provider = GeminiProvider(client=client)
    result = provider.analyze_transactions("Dad", TXNS)
    print(f"result on malformed json: {result}")
    assert result["flagged"] == []
    assert result["error"] == "invalid_json"


def test_gemini_provider_defaults_to_flash_latest(monkeypatch):
    monkeypatch.delenv("LLM_MODEL", raising=False)
    client = FakeGeminiClient(json.dumps({"flagged": []}))
    provider = GeminiProvider(client=client)
    print(f"default model: {provider.model}")
    assert provider.model == "gemini-flash-latest"


def test_gemini_analyze_transactions_uses_model_env(monkeypatch):
    monkeypatch.setenv("LLM_MODEL", "gemini-2.5-pro")
    client = FakeGeminiClient(json.dumps({"flagged": []}))
    provider = GeminiProvider(client=client)
    provider.analyze_transactions("Dad", TXNS)
    print(f"model used in call: {client.models.last_call['model']}")
    assert client.models.last_call["model"] == "gemini-2.5-pro"


# --- Real API smoke test (hits live Gemini, requires GEMINI_API_KEY) ---

@pytest.mark.skipif(not os.getenv("GEMINI_API_KEY"), reason="GEMINI_API_KEY not set")
def test_gemini_real_api_basic_prompt():
    provider = GeminiProvider()
    response = provider.client.models.generate_content(
        model=provider.model,
        contents="Who won the World Cup 2026?",
    )
    print(f"model: {provider.model}, served by: {response.model_version}")
    print(f"response: {response.text}")
    assert response.text
