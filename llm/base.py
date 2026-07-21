import os
from abc import ABC, abstractmethod

MAX_TRANSACTIONS = 200

SYSTEM_PROMPT = (
    "You are a financial anomaly detector for a family finance dashboard. "
    "Flag unusual bank fees, unknown recipients, atypical amounts, and near-duplicate charges. "
    "Skip routine transactions (supermarkets, subscriptions, salary, known recurring bills). "
    "Respond with JSON only, no prose, matching this schema exactly: "
    '{"flagged": [{"transaction_id": "...", "reason": "..."}]}'
)


class LLMProvider(ABC):
    @abstractmethod
    def analyze_transactions(self, member_name: str, transactions: list[dict]) -> dict:
        """Return {"flagged": [{"transaction_id": ..., "reason": ...}]}."""
        ...


def get_provider() -> LLMProvider:
    provider = os.getenv("LLM_PROVIDER", "anthropic")
    if provider == "anthropic":
        from llm.providers.anthropic import AnthropicProvider
        return AnthropicProvider()
    if provider == "gemini":
        from llm.providers.gemini import GeminiProvider
        return GeminiProvider()
    raise ValueError(f"Unknown LLM_PROVIDER: {provider}")
