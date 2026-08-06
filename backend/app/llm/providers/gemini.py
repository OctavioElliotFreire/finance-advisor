from google import genai
from google.genai import types

from app.llm.base import SYSTEM_PROMPT, LLMProvider, _user_message
from app.settings import settings

REQUEST_TIMEOUT_MS = 20_000
ASSISTANT_MAX_OUTPUT_TOKENS = 1024
ASSISTANT_THINKING_BUDGET = 512


class GeminiProvider(LLMProvider):
    def __init__(self, client=None):
        self.client = client or genai.Client(api_key=settings.gemini_api_key)
        self.model = "gemini-flash-latest"

    def explain_anomaly(self, context: dict) -> str:
        response = self.client.models.generate_content(
            model=self.model,
            contents=_user_message(context),
            config=types.GenerateContentConfig(
                system_instruction=SYSTEM_PROMPT,
                http_options=types.HttpOptions(timeout=REQUEST_TIMEOUT_MS),
            ),
        )
        return response.text.strip()

    def answer_question(self, system_prompt: str, user_message: str) -> str:
        # gemini-flash-latest's dynamic "thinking" tokens share the same
        # max_output_tokens budget as the visible answer — left uncapped, a
        # long reasoning pass can silently eat the whole budget and cut the
        # answer off mid-sentence even though the API reports success. A
        # fixed thinking_budget well under max_output_tokens keeps enough
        # headroom for the visible answer to always finish normally.
        response = self.client.models.generate_content(
            model=self.model,
            contents=user_message,
            config=types.GenerateContentConfig(
                system_instruction=system_prompt,
                max_output_tokens=ASSISTANT_MAX_OUTPUT_TOKENS,
                thinking_config=types.ThinkingConfig(
                    thinking_budget=ASSISTANT_THINKING_BUDGET
                ),
                http_options=types.HttpOptions(timeout=REQUEST_TIMEOUT_MS),
            ),
        )
        if response.candidates[0].finish_reason != types.FinishReason.STOP:
            raise RuntimeError(
                f"Gemini did not finish normally: {response.candidates[0].finish_reason}"
            )
        return response.text.strip()
