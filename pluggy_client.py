import os
import time
import requests


BASE_URL = "https://api.pluggy.ai"


class PluggyClient:
    def __init__(self, client_id: str, client_secret: str):
        self.client_id = client_id
        self.client_secret = client_secret
        self.api_key: str | None = None

    def _headers(self) -> dict:
        if not self.api_key:
            raise RuntimeError("Not authenticated. Call authenticate() first.")
        return {"X-API-KEY": self.api_key, "Content-Type": "application/json"}

    def authenticate(self) -> str:
        resp = requests.post(
            f"{BASE_URL}/auth",
            json={"clientId": self.client_id, "clientSecret": self.client_secret},
        )
        resp.raise_for_status()
        self.api_key = resp.json()["apiKey"]
        return self.api_key

    def create_item(self, connector_id: int, parameters: dict) -> dict:
        resp = requests.post(
            f"{BASE_URL}/items",
            headers=self._headers(),
            json={"connectorId": connector_id, "parameters": parameters},
        )
        resp.raise_for_status()
        return resp.json()

    def get_item(self, item_id: str) -> dict:
        resp = requests.get(f"{BASE_URL}/items/{item_id}", headers=self._headers())
        resp.raise_for_status()
        return resp.json()

    def wait_for_item(self, item_id: str, timeout: int = 60, interval: int = 3) -> dict:
        deadline = time.time() + timeout
        while time.time() < deadline:
            item = self.get_item(item_id)
            status = item.get("status")
            if status == "UPDATED":
                return item
            if status in ("LOGIN_ERROR", "OUTDATED", "WAITING_USER_INPUT"):
                raise RuntimeError(f"Item sync failed with status: {status}")
            print(f"  Item status: {status} — waiting...")
            time.sleep(interval)
        raise TimeoutError(f"Item did not reach UPDATED status within {timeout}s")

    def get_accounts(self, item_id: str) -> list:
        resp = requests.get(
            f"{BASE_URL}/accounts",
            headers=self._headers(),
            params={"itemId": item_id},
        )
        resp.raise_for_status()
        return resp.json().get("results", [])

    def get_transactions(self, account_id: str, cursor: str | None = None) -> dict:
        params = {"accountId": account_id}
        if cursor:
            params["cursor"] = cursor
        resp = requests.get(
            f"{BASE_URL}/v2/transactions",
            headers=self._headers(),
            params=params,
        )
        resp.raise_for_status()
        return resp.json()

    def get_investments(self, item_id: str) -> list:
        resp = requests.get(
            f"{BASE_URL}/investments",
            headers=self._headers(),
            params={"itemId": item_id},
        )
        resp.raise_for_status()
        return resp.json().get("results", [])

    def get_identity(self, item_id: str) -> dict | None:
        resp = requests.get(
            f"{BASE_URL}/identity",
            headers=self._headers(),
            params={"itemId": item_id},
        )
        if resp.status_code == 404:
            return None
        resp.raise_for_status()
        return resp.json()

    def get_loans(self, item_id: str) -> list:
        resp = requests.get(
            f"{BASE_URL}/loans",
            headers=self._headers(),
            params={"itemId": item_id},
        )
        if resp.status_code == 404:
            return []
        resp.raise_for_status()
        return resp.json().get("results", [])

    def get_bills(self, account_id: str) -> list:
        resp = requests.get(
            f"{BASE_URL}/bills",
            headers=self._headers(),
            params={"accountId": account_id},
        )
        if resp.status_code == 404:
            return []
        resp.raise_for_status()
        return resp.json().get("results", [])
