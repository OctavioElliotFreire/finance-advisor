import json
import os

from google import genai
from google.genai import types

from llm.base import LLMProvider, MAX_TRANSACTIONS, SYSTEM_PROMPT


class GeminiProvider(LLMProvider):
    def __init__(self, client=None):
        self.client = client or genai.Client(api_key=os.getenv("GEMINI_API_KEY"))
        self.model = os.getenv("LLM_MODEL", "gemini-flash-latest")

    def analyze_transactions(self, member_name: str, transactions: list[dict]) -> dict:
        debits = [t for t in transactions if t.get("type") == "DEBIT"][:MAX_TRANSACTIONS]
        payload = [
            {
                "id": t.get("id"),
                "date": t.get("date"),
                "description": t.get("description"),
                "amount": t.get("amount"),
                "currency": t.get("currency_code"),
                "category": t.get("category"),
                "merchant": t.get("merchant_name"),
            }
            for t in debits
        ]
        user_message = (
            f"Member: {member_name}\n"
            f"Transactions (DEBIT only):\n{json.dumps(payload)}"
        )

        response = self.client.models.generate_content(
            model=self.model,
            contents=user_message,
            config=types.GenerateContentConfig(system_instruction=SYSTEM_PROMPT),
        )
        text = response.text

        try:
            result = json.loads(text)
        except json.JSONDecodeError:
            return {"flagged": [], "error": "invalid_json", "raw": text}

        result.setdefault("flagged", [])
        return result
