import json
from abc import ABC, abstractmethod

from app.settings import settings

SYSTEM_PROMPT = (
    "You are a financial assistant explaining one flagged anomaly to a household "
    "member. Given a JSON context describing the deterministic rule that fired and "
    "the (already redacted) transaction details, write one short plain-language "
    "paragraph (2-3 sentences) explaining why this was flagged and what the member "
    "might want to check. No jargon, no bullet points, no markdown, no questions "
    "back to the user — just the explanation."
)


class LLMProvider(ABC):
    @abstractmethod
    def explain_anomaly(self, context: dict) -> str:
        """Returns a short plain-language explanation string for one anomaly."""
        ...


def _user_message(context: dict) -> str:
    return f"Anomaly context:\n{json.dumps(context)}"


def get_provider() -> LLMProvider:
    provider = settings.llm_provider
    if provider == "anthropic":
        from app.llm.providers.anthropic import AnthropicProvider

        return AnthropicProvider()
    if provider == "gemini":
        from app.llm.providers.gemini import GeminiProvider

        return GeminiProvider()
    raise ValueError(f"Unknown LLM_PROVIDER: {provider}")
