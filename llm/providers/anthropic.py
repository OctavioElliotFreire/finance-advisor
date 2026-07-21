import json
import os

import anthropic

from llm.base import LLMProvider, MAX_TRANSACTIONS, SYSTEM_PROMPT


class AnthropicProvider(LLMProvider):
    def __init__(self, client=None):
        self.client = client or anthropic.Anthropic(api_key=os.getenv("ANTHROPIC_API_KEY"))
        self.model = os.getenv("LLM_MODEL", "claude-haiku-4-5-20251001")

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

        response = self.client.messages.create(
            model=self.model,
            max_tokens=2048,
            system=SYSTEM_PROMPT,
            messages=[{"role": "user", "content": user_message}],
        )
        text = response.content[0].text

        try:
            result = json.loads(text)
        except json.JSONDecodeError:
            return {"flagged": [], "error": "invalid_json", "raw": text}

        result.setdefault("flagged", [])
        return result
