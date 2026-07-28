from google import genai
from google.genai import types

from app.llm.base import SYSTEM_PROMPT, LLMProvider, _user_message
from app.settings import settings


class GeminiProvider(LLMProvider):
    def __init__(self, client=None):
        self.client = client or genai.Client(api_key=settings.gemini_api_key)
        self.model = "gemini-flash-latest"

    def explain_anomaly(self, context: dict) -> str:
        response = self.client.models.generate_content(
            model=self.model,
            contents=_user_message(context),
            config=types.GenerateContentConfig(system_instruction=SYSTEM_PROMPT),
        )
        return response.text.strip()
