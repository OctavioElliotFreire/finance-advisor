import httpx

BASE_URL = "https://api.pluggy.ai"
# httpx's 5s default cuts it close — a real auth call took 4.8s during
# manual QA (2026-08-05) and intermittently timed out, surfacing to the
# browser as a misleading CORS error (no CORS headers on the resulting
# unhandled 500) rather than the actual network timeout.
REQUEST_TIMEOUT = 30.0


class PluggyClient:
    """Async port of the root MVP's pluggy_client.py, plus Connect Token
    support for the widget flow (see backend/app/api/connections.py).
    """

    def __init__(self, client_id: str, client_secret: str):
        self.client_id = client_id
        self.client_secret = client_secret
        self.api_key: str | None = None

    def _headers(self) -> dict:
        if not self.api_key:
            raise RuntimeError("Not authenticated. Call authenticate() first.")
        return {"X-API-KEY": self.api_key, "Content-Type": "application/json"}

    async def authenticate(self) -> str:
        async with httpx.AsyncClient(timeout=REQUEST_TIMEOUT) as client:
            resp = await client.post(
                f"{BASE_URL}/auth",
                json={
                    "clientId": self.client_id,
                    "clientSecret": self.client_secret,
                },
            )
            resp.raise_for_status()
            self.api_key = resp.json()["apiKey"]
            return self.api_key

    async def create_connect_token(
        self,
        client_user_id: str,
        item_id: str | None = None,
        webhook_url: str | None = None,
    ) -> str:
        """Creates a short-lived (30 min) Connect Token for the client-side
        Pluggy Connect Widget. Pass `item_id` to update an existing item
        rather than create a new one.
        """
        body: dict = {"options": {"clientUserId": client_user_id}}
        if webhook_url:
            body["options"]["webhookUrl"] = webhook_url
        if item_id:
            body["itemId"] = item_id

        async with httpx.AsyncClient(timeout=REQUEST_TIMEOUT) as client:
            resp = await client.post(
                f"{BASE_URL}/connect_token",
                headers=self._headers(),
                json=body,
            )
            resp.raise_for_status()
            return resp.json()["accessToken"]

    async def get_item(self, item_id: str) -> dict:
        async with httpx.AsyncClient(timeout=REQUEST_TIMEOUT) as client:
            resp = await client.get(
                f"{BASE_URL}/items/{item_id}", headers=self._headers()
            )
            resp.raise_for_status()
            return resp.json()

    async def get_accounts(self, item_id: str) -> list:
        async with httpx.AsyncClient(timeout=REQUEST_TIMEOUT) as client:
            resp = await client.get(
                f"{BASE_URL}/accounts",
                headers=self._headers(),
                params={"itemId": item_id},
            )
            resp.raise_for_status()
            return resp.json().get("results", [])

    async def get_transactions(self, account_id: str, cursor: str | None = None) -> dict:
        params = {"accountId": account_id}
        if cursor:
            params["after"] = cursor
        async with httpx.AsyncClient(timeout=REQUEST_TIMEOUT) as client:
            resp = await client.get(
                f"{BASE_URL}/v2/transactions",
                headers=self._headers(),
                params=params,
            )
            resp.raise_for_status()
            return resp.json()

    async def get_investments(self, item_id: str) -> list:
        async with httpx.AsyncClient(timeout=REQUEST_TIMEOUT) as client:
            resp = await client.get(
                f"{BASE_URL}/investments",
                headers=self._headers(),
                params={"itemId": item_id},
            )
            resp.raise_for_status()
            return resp.json().get("results", [])

    async def get_identity(self, item_id: str) -> dict | None:
        async with httpx.AsyncClient(timeout=REQUEST_TIMEOUT) as client:
            resp = await client.get(
                f"{BASE_URL}/identity",
                headers=self._headers(),
                params={"itemId": item_id},
            )
            if resp.status_code == 404:
                return None
            resp.raise_for_status()
            return resp.json()

    async def get_loans(self, item_id: str) -> list:
        async with httpx.AsyncClient(timeout=REQUEST_TIMEOUT) as client:
            resp = await client.get(
                f"{BASE_URL}/loans",
                headers=self._headers(),
                params={"itemId": item_id},
            )
            if resp.status_code == 404:
                return []
            resp.raise_for_status()
            return resp.json().get("results", [])

    async def get_bills(self, account_id: str) -> list:
        async with httpx.AsyncClient(timeout=REQUEST_TIMEOUT) as client:
            resp = await client.get(
                f"{BASE_URL}/bills",
                headers=self._headers(),
                params={"accountId": account_id},
            )
            if resp.status_code == 404:
                return []
            resp.raise_for_status()
            return resp.json().get("results", [])
