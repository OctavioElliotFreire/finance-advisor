import anthropic

from app.llm.base import SYSTEM_PROMPT, LLMProvider, _user_message
from app.settings import settings


class AnthropicProvider(LLMProvider):
    def __init__(self, client=None):
        self.client = client or anthropic.Anthropic(api_key=settings.anthropic_api_key)
        self.model = "claude-haiku-4-5-20251001"

    def explain_anomaly(self, context: dict) -> str:
        response = self.client.messages.create(
            model=self.model,
            max_tokens=512,
            system=SYSTEM_PROMPT,
            messages=[{"role": "user", "content": _user_message(context)}],
        )
        return response.content[0].text.strip()
