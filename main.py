import os
from dotenv import load_dotenv
from pluggy_client import PluggyClient

load_dotenv()

SANDBOX_CONNECTOR_ID = 0
SANDBOX_CREDENTIALS = {"user": "user-ok", "password": "password-ok"}


def mask(key: str) -> str:
    return key[:6] + "..." + key[-4:] if len(key) > 10 else "***"


def main():
    client_id = os.environ["PLUGGY_CLIENT_ID"]
    client_secret = os.environ["PLUGGY_CLIENT_SECRET"]

    client = PluggyClient(client_id, client_secret)

    # --- Auth ---
    print("=== AUTH ===")
    api_key = client.authenticate()
    print(f"API Key: {mask(api_key)}")

    # --- Create sandbox item ---
    print("\n=== CREATE ITEM (sandbox connector 0) ===")
    item = client.create_item(SANDBOX_CONNECTOR_ID, SANDBOX_CREDENTIALS)
    item_id = item["id"]
    print(f"Item ID: {item_id}")
    print(f"Status:  {item.get('status')}")

    print("\nWaiting for sync...")
    item = client.wait_for_item(item_id)
    print(f"Item ready — status: {item['status']}")

    # --- Accounts ---
    accounts = client.get_accounts(item_id)
    bank_accounts = [a for a in accounts if a.get("type") == "BANK"]
    credit_cards  = [a for a in accounts if a.get("type") == "CREDIT"]

    print("\n=== BANK ACCOUNTS ===")
    if not bank_accounts:
        print("  None found.")
    for acc in bank_accounts:
        print(f"  {acc['name']}")
        print(f"    Subtype:  {acc.get('subtype', 'N/A')}")
        print(f"    Balance:  {acc.get('balance')} {acc.get('currencyCode', '')}")
        print(f"    Owner:    {acc.get('owner', 'N/A')}")
        print(f"    ID:       {acc['id']}")

    print("\n=== CREDIT CARDS ===")
    if not credit_cards:
        print("  None found.")
    for acc in credit_cards:
        print(f"  {acc['name']}")
        print(f"    Subtype:       {acc.get('subtype', 'N/A')}")
        print(f"    Balance:       {acc.get('balance')} {acc.get('currencyCode', '')}")
        print(f"    Credit Limit:  {acc.get('creditData', {}).get('creditLimit', 'N/A')}")
        print(f"    Available:     {acc.get('creditData', {}).get('availableCreditLimit', 'N/A')}")
        print(f"    ID:            {acc['id']}")

    # --- Transactions ---
    print("\n=== TRANSACTIONS (first bank account, first page) ===")
    if bank_accounts:
        data = client.get_transactions(bank_accounts[0]["id"])
        txns = data.get("results", [])
        if not txns:
            print("  No transactions found.")
        for t in txns[:5]:
            sign = "-" if t.get("type") == "DEBIT" else "+"
            print(f"  {t.get('date', '')[:10]}  {sign}{t.get('amount')}  {t.get('currencyCode', '')}  {t.get('description', '')}")
        if data.get("next"):
            print(f"  ... more pages available")
    else:
        print("  Skipped — no bank accounts.")

    # --- Investments ---
    print("\n=== INVESTMENTS ===")
    investments = client.get_investments(item_id)
    if not investments:
        print("No investments found.")
    for inv in investments:
        print(f"  {inv.get('name', 'N/A')}  |  value: {inv.get('value')}  {inv.get('currencyCode', '')}  |  type: {inv.get('type', '')}")


if __name__ == "__main__":
    main()
