import anthropic

from app.llm.base import SYSTEM_PROMPT, LLMProvider, _user_message
from app.settings import settings

REQUEST_TIMEOUT_SECONDS = 20.0
ASSISTANT_MAX_TOKENS = 600


class AnthropicProvider(LLMProvider):
    def __init__(self, client=None):
        self.client = client or anthropic.Anthropic(
            api_key=settings.anthropic_api_key, timeout=REQUEST_TIMEOUT_SECONDS
        )
        self.model = "claude-haiku-4-5-20251001"

    def explain_anomaly(self, context: dict) -> str:
        response = self.client.messages.create(
            model=self.model,
            max_tokens=512,
            system=SYSTEM_PROMPT,
            messages=[{"role": "user", "content": _user_message(context)}],
        )
        return response.content[0].text.strip()

    def answer_question(self, system_prompt: str, user_message: str) -> str:
        response = self.client.messages.create(
            model=self.model,
            max_tokens=ASSISTANT_MAX_TOKENS,
            system=system_prompt,
            messages=[{"role": "user", "content": user_message}],
        )
        if response.stop_reason not in ("end_turn", "stop_sequence"):
            raise RuntimeError(f"Anthropic did not finish normally: {response.stop_reason}")
        return response.content[0].text.strip()
