import os
import pytest
from dotenv import load_dotenv
from pluggy_client import PluggyClient

load_dotenv()

SANDBOX_CONNECTOR_ID = 0
SANDBOX_CREDENTIALS = {"user": "user-ok", "password": "password-ok"}


@pytest.fixture(scope="session")
def client():
    client_id = os.environ.get("PLUGGY_CLIENT_ID")
    client_secret = os.environ.get("PLUGGY_CLIENT_SECRET")
    assert client_id and client_secret, "PLUGGY_CLIENT_ID and PLUGGY_CLIENT_SECRET must be set in .env"
    c = PluggyClient(client_id, client_secret)
    c.authenticate()
    return c


@pytest.fixture(scope="session")
def synced_item(client):
    existing_id = os.environ.get("PLUGGY_ITEM_ID")
    if existing_id:
        print(f"\n  Reusing existing item: {existing_id}")
        return client.get_item(existing_id)
    item = client.create_item(SANDBOX_CONNECTOR_ID, SANDBOX_CREDENTIALS)
    item_id = item["id"]
    print(f"\n  Created new item: {item_id}")
    print(f"  Add to .env: PLUGGY_ITEM_ID={item_id}")
    return client.wait_for_item(item_id)


@pytest.fixture(scope="session")
def accounts(client, synced_item):
    return client.get_accounts(synced_item["id"])


# --- Auth ---

def test_authenticate_returns_api_key(client):
    assert client.api_key
    assert isinstance(client.api_key, str)
    assert len(client.api_key) > 10


# --- Item ---

def test_create_item_returns_id(synced_item):
    assert "id" in synced_item
    assert synced_item["id"]


def test_item_status_is_updated(synced_item):
    assert synced_item["status"] == "UPDATED"


def test_item_has_connector(synced_item):
    assert synced_item.get("connector") or synced_item.get("connectorId") is not None


# --- Accounts ---

def test_get_accounts_returns_list(accounts):
    bank = [a for a in accounts if a.get("type") == "BANK"]
    credit = [a for a in accounts if a.get("type") == "CREDIT"]
    print(f"\n  Total accounts: {len(accounts)}  (bank: {len(bank)}, credit: {len(credit)})")
    assert isinstance(accounts, list)
    assert len(accounts) > 0, "Expected at least one account in sandbox"


def test_accounts_have_required_fields(accounts):
    bank = [a for a in accounts if a.get("type") == "BANK"]
    credit = [a for a in accounts if a.get("type") == "CREDIT"]

    print("\n  --- Bank Accounts ---")
    for acc in bank:
        print(f"  {acc['name']}")
        print(f"    Subtype:  {acc.get('subtype', 'N/A')}")
        print(f"    Balance:  {acc.get('balance')} {acc.get('currencyCode', '')}")
        print(f"    Owner:    {acc.get('owner', 'N/A')}")

    print("\n  --- Credit Cards ---")
    for acc in credit:
        print(f"  {acc['name']}")
        print(f"    Subtype:      {acc.get('subtype', 'N/A')}")
        print(f"    Balance:      {acc.get('balance')} {acc.get('currencyCode', '')}")
        print(f"    Credit Limit: {acc.get('creditData', {}).get('creditLimit', 'N/A')}")
        print(f"    Available:    {acc.get('creditData', {}).get('availableCreditLimit', 'N/A')}")

    for acc in accounts:
        assert "id" in acc
        assert "name" in acc
        assert "type" in acc


# --- Transactions ---

def test_get_transactions_returns_list(client, accounts):
    data = client.get_transactions(accounts[0]["id"])
    assert isinstance(data.get("results"), list)


def test_transactions_have_required_fields(client, accounts):
    data = client.get_transactions(accounts[0]["id"])
    for t in data.get("results", []):
        assert "id" in t
        assert "amount" in t
        assert "date" in t
        assert "type" in t


# --- Investments ---

def test_get_investments_returns_list(client, synced_item):
    investments = client.get_investments(synced_item["id"])
    print(f"\n  Total investments: {len(investments)}")
    assert isinstance(investments, list)


def test_investments_have_required_fields(client, synced_item):
    investments = client.get_investments(synced_item["id"])
    print(f"\n  --- Investments ({len(investments)}) ---")
    for inv in investments:
        print(
            f"  [{inv.get('type', '?')}] {inv.get('name', 'N/A')}"
            f"  |  value: {inv.get('value')} {inv.get('currencyCode', '')}"
            f"  |  status: {inv.get('status', 'N/A')}"
        )
        assert "id" in inv
        assert "name" in inv
        assert "type" in inv
