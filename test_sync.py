import os
import tempfile
import pytest
import yaml

import db
from db import (
    init_schema, get_all_members, get_accounts_for_member,
    get_transactions_for_member, get_investments_for_member,
    get_loans_for_member, get_identity_for_member, get_connection,
)
from sync import load_members_yaml, sync_all

# --- Fixtures ---

@pytest.fixture(autouse=True)
def fresh_db(tmp_path):
    db.DB_PATH = str(tmp_path / "test.db")
    init_schema()


@pytest.fixture()
def yaml_file(tmp_path):
    def _make(content: dict) -> str:
        path = str(tmp_path / "members.yaml")
        with open(path, "w") as f:
            yaml.dump(content, f)
        return path
    return _make


# --- load_members_yaml ---

def test_load_members_yaml_basic(yaml_file):
    path = yaml_file({"members": [{"id": "dad", "name": "Dad", "item_ids": ["abc-123"]}]})
    members = load_members_yaml(path)
    assert len(members) == 1
    assert members[0]["id"] == "dad"
    assert members[0]["name"] == "Dad"
    assert members[0]["item_ids"] == ["abc-123"]


def test_load_members_yaml_defaults_item_ids(yaml_file):
    path = yaml_file({"members": [{"id": "kid", "name": "Kid"}]})
    members = load_members_yaml(path)
    assert members[0]["item_ids"] == []


def test_load_members_yaml_multiple_members(yaml_file):
    path = yaml_file({"members": [
        {"id": "dad", "name": "Dad", "item_ids": ["x"]},
        {"id": "mom", "name": "Mom", "item_ids": ["y", "z"]},
    ]})
    members = load_members_yaml(path)
    assert len(members) == 2
    assert members[1]["name"] == "Mom"
    assert len(members[1]["item_ids"]) == 2


def test_load_members_yaml_empty(yaml_file):
    path = yaml_file({"members": []})
    members = load_members_yaml(path)
    assert members == []


def test_load_members_yaml_missing_id_raises(yaml_file):
    path = yaml_file({"members": [{"name": "NoId"}]})
    with pytest.raises(AssertionError):
        load_members_yaml(path)


# --- sync_all integration (real Pluggy sandbox) ---

def _real_item_id() -> str | None:
    for member in load_members_yaml("members.yaml"):
        if member.get("item_ids"):
            return member["item_ids"][0]
    return None


ITEM_ID = _real_item_id()

@pytest.mark.skipif(
    not os.environ.get("PLUGGY_CLIENT_ID"),
    reason="PLUGGY_CLIENT_ID not set",
)
def test_sync_all_populates_members(yaml_file):
    path = yaml_file({"members": [{"id": "dad", "name": "Dad", "item_ids": [ITEM_ID] if ITEM_ID else []}]})
    result = sync_all(members_yaml_path=path)
    members = get_all_members()
    assert len(members) == 1
    assert members[0]["name"] == "Dad"
    assert result["members_synced"] == 1


@pytest.mark.skipif(
    not (os.environ.get("PLUGGY_CLIENT_ID") and ITEM_ID),
    reason="PLUGGY_CLIENT_ID or PLUGGY_ITEM_ID not set",
)
def test_sync_all_populates_accounts(yaml_file):
    path = yaml_file({"members": [{"id": "dad", "name": "Dad", "item_ids": [ITEM_ID]}]})
    sync_all(members_yaml_path=path)
    accounts = get_accounts_for_member("dad")
    assert len(accounts) > 0
    assert all("name" in a for a in accounts)
    assert all("balance" in a for a in accounts)


@pytest.mark.skipif(
    not (os.environ.get("PLUGGY_CLIENT_ID") and ITEM_ID),
    reason="PLUGGY_CLIENT_ID or PLUGGY_ITEM_ID not set",
)
def test_sync_all_populates_transactions(yaml_file):
    path = yaml_file({"members": [{"id": "dad", "name": "Dad", "item_ids": [ITEM_ID]}]})
    sync_all(members_yaml_path=path)
    txns = get_transactions_for_member("dad", days=3650)
    assert len(txns) > 0
    assert all("amount" in t for t in txns)
    assert all("date" in t for t in txns)


@pytest.mark.skipif(
    not (os.environ.get("PLUGGY_CLIENT_ID") and ITEM_ID),
    reason="PLUGGY_CLIENT_ID or PLUGGY_ITEM_ID not set",
)
def test_sync_all_populates_investments(yaml_file):
    path = yaml_file({"members": [{"id": "dad", "name": "Dad", "item_ids": [ITEM_ID]}]})
    sync_all(members_yaml_path=path)
    investments = get_investments_for_member("dad")
    assert len(investments) > 0
    assert all("name" in i for i in investments)


@pytest.mark.skipif(
    not (os.environ.get("PLUGGY_CLIENT_ID") and ITEM_ID),
    reason="PLUGGY_CLIENT_ID or PLUGGY_ITEM_ID not set",
)
def test_sync_all_returns_counts(yaml_file):
    path = yaml_file({"members": [{"id": "dad", "name": "Dad", "item_ids": [ITEM_ID]}]})
    result = sync_all(members_yaml_path=path)
    assert result["members_synced"] == 1
    assert result["items_synced"] == 1


@pytest.mark.skipif(
    not (os.environ.get("PLUGGY_CLIENT_ID") and ITEM_ID),
    reason="PLUGGY_CLIENT_ID or PLUGGY_ITEM_ID not set",
)
def test_sync_all_is_idempotent(yaml_file):
    path = yaml_file({"members": [{"id": "dad", "name": "Dad", "item_ids": [ITEM_ID]}]})
    sync_all(members_yaml_path=path)
    accounts_first = get_accounts_for_member("dad")
    sync_all(members_yaml_path=path)
    accounts_second = get_accounts_for_member("dad")
    assert len(accounts_first) == len(accounts_second)


@pytest.mark.skipif(
    not (os.environ.get("PLUGGY_CLIENT_ID") and ITEM_ID),
    reason="PLUGGY_CLIENT_ID or PLUGGY_ITEM_ID not set",
)
def test_print_db_contents(yaml_file):
    path = yaml_file({"members": [{"id": "dad", "name": "Dad", "item_ids": [ITEM_ID]}]})
    sync_all(members_yaml_path=path)

    # --- Accounts ---
    accounts = get_accounts_for_member("dad")
    bank = [a for a in accounts if a["type"] == "BANK"]
    credit = [a for a in accounts if a["type"] == "CREDIT"]

    print("\n=== BANK ACCOUNTS ===")
    for a in bank:
        print(f"  {a['name']} | {a['subtype']} | balance: {a['balance']} {a['currency_code']} | owner: {a['owner']}")

    print("\n=== CREDIT CARDS ===")
    for a in credit:
        print(f"  {a['name']} | limit: {a['credit_limit']} | available: {a['available_credit']} {a['currency_code']}")

    # --- Transactions ---
    txns = get_transactions_for_member("dad", days=3650)
    print(f"\n=== TRANSACTIONS ({len(txns)} total) ===")
    for t in txns[:10]:
        sign = "-" if t["type"] == "DEBIT" else "+"
        merchant = f" [{t['merchant_name']}]" if t["merchant_name"] else ""
        print(f"  {t['date'][:10]}  {sign}{t['amount']} {t['currency_code']}  {t['description']}{merchant}  [{t['category'] or 'uncategorized'}]")
    if len(txns) > 10:
        print(f"  ... and {len(txns) - 10} more")

    # --- Investments ---
    investments = get_investments_for_member("dad")
    print(f"\n=== INVESTMENTS ({len(investments)}) ===")
    for inv in investments:
        print(f"  [{inv['type']}] {inv['name']} | value: {inv['value']} {inv['currency_code']} | status: {inv['status']}")

    # --- Identity ---
    identity = get_identity_for_member("dad")
    print("\n=== IDENTITY ===")
    if identity:
        print(f"  Name: {identity['full_name']}")
        print(f"  CPF:  {identity['cpf_number']}")
        print(f"  DOB:  {identity['birth_date']}")
    else:
        print("  Not available")

    # --- Loans ---
    loans = get_loans_for_member("dad")
    print(f"\n=== LOANS ({len(loans)}) ===")
    for loan in loans:
        print(f"  [{loan['type']}] outstanding: {loan['outstanding_balance']} {loan['currency_code']} | rate: {loan['interest_rate']} | status: {loan['status']}")
    if not loans:
        print("  None")

    # --- Row counts ---
    with get_connection() as conn:
        for table in ["accounts", "transactions", "investments", "identity", "credit_card_bills", "loans"]:
            count = conn.execute(f"SELECT COUNT(*) FROM {table}").fetchone()[0]
            print(f"  {table}: {count} row(s)")

    assert True  # always passes — purely informational
