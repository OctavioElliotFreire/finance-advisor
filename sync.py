import os
from typing import Callable
from urllib.parse import parse_qs, urlparse

import yaml

import db
from db import (
    upsert_member, upsert_item, upsert_accounts, upsert_transactions,
    upsert_investments, upsert_identity, upsert_credit_card_bills, upsert_loans,
)
from pluggy_client import PluggyClient

MEMBERS_YAML = os.getenv("MEMBERS_YAML", "members.yaml")


def load_members_yaml(path: str | None = None) -> list[dict]:
    with open(path or MEMBERS_YAML, "r", encoding="utf-8") as f:
        data = yaml.safe_load(f)
    members = data.get("members", [])
    for m in members:
        assert "id" in m, f"Member missing 'id': {m}"
        assert "name" in m, f"Member missing 'name': {m}"
        m.setdefault("item_ids", [])
    return members


def paginate_transactions(client: PluggyClient, account_id: str) -> list[dict]:
    all_txns: list[dict] = []
    cursor = None
    while True:
        data = client.get_transactions(account_id, cursor=cursor)
        all_txns.extend(data.get("results", []))
        next_link = data.get("next")
        if not next_link:
            break
        cursor = parse_qs(urlparse(next_link).query).get("after", [None])[0]
        if not cursor:
            break
    return all_txns


def sync_item(
    client: PluggyClient,
    item_id: str,
    member_id: str,
    log: Callable[[str], None] = print,
) -> dict:
    item = client.get_item(item_id)
    upsert_item(item, member_id)

    accounts = client.get_accounts(item_id)
    upsert_accounts(accounts, item_id, member_id)
    log(f"    accounts fetched: {len(accounts)}")

    for acc in accounts:
        txns = paginate_transactions(client, acc["id"])
        upsert_transactions(txns, acc["id"], member_id)
        log(f"    account {acc['id']} ({acc.get('type')}): {len(txns)} transaction(s)")

        if acc.get("type") == "CREDIT":
            bills = client.get_bills(acc["id"])
            if bills:
                upsert_credit_card_bills(bills, acc["id"], member_id)
                log(f"    account {acc['id']}: {len(bills)} credit card bill(s)")

    investments = client.get_investments(item_id)
    upsert_investments(investments, item_id, member_id)
    log(f"    investments fetched: {len(investments)}")

    identity = client.get_identity(item_id)
    if identity:
        upsert_identity(identity, item_id, member_id)
        log("    identity fetched: yes")

    loans = client.get_loans(item_id)
    if loans:
        upsert_loans(loans, item_id, member_id)
        log(f"    loans fetched: {len(loans)}")

    return item


def sync_all(
    members_yaml_path: str | None = None,
    progress_callback: Callable[[str], None] | None = None,
) -> dict:
    def log(msg: str) -> None:
        if progress_callback:
            progress_callback(msg)
        else:
            print(msg)

    members = load_members_yaml(members_yaml_path)
    if not members:
        log("No members found in config.")
        return {"members_synced": 0, "items_synced": 0}

    client = PluggyClient(
        os.environ["PLUGGY_CLIENT_ID"],
        os.environ["PLUGGY_CLIENT_SECRET"],
    )
    client.authenticate()
    log("Authenticated with Pluggy.")

    items_synced = 0
    for member in members:
        upsert_member(member["id"], member["name"])
        log(f"Syncing {member['name']} ({len(member['item_ids'])} item(s))...")

        for item_id in member["item_ids"]:
            log(f"  -> item {item_id}")
            sync_item(client, item_id, member["id"], log=log)
            items_synced += 1

    log(f"Sync complete. {len(members)} member(s), {items_synced} item(s).")
    return {"members_synced": len(members), "items_synced": items_synced}


def sync_single_item(
    item_id: str,
    member_id: str,
    log: Callable[[str], None] = print,
) -> dict:
    client = PluggyClient(
        os.environ["PLUGGY_CLIENT_ID"],
        os.environ["PLUGGY_CLIENT_SECRET"],
    )
    client.authenticate()
    return sync_item(client, item_id, member_id, log=log)


if __name__ == "__main__":
    from dotenv import load_dotenv
    load_dotenv()
    db.init_schema()
    result = sync_all()
    print(result)
