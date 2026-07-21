"""Pure aggregation functions over already-fetched data. No DB or Streamlit imports."""

from datetime import date

from config.settings import institution_label, asset_class_label


def _item_institution_map(items: list[dict]) -> dict[str, str]:
    return {i["item_id"]: institution_label(i.get("connector_name")) for i in items}


def filter_by_institution(rows: list[dict], items: list[dict], selected_names: list[str]) -> list[dict]:
    """Narrow rows (accounts/investments) to only those whose item's raw
    connector_name is in selected_names. Empty selection = no filter."""
    if not selected_names:
        return rows
    allowed_item_ids = {
        i["item_id"] for i in items
        if (i.get("connector_name") or "Unknown Institution") in selected_names
    }
    return [r for r in rows if r.get("item_id") in allowed_item_ids]


def group_accounts_by_institution(accounts: list[dict], items: list[dict]) -> list[dict]:
    total = sum(a["balance"] or 0.0 for a in accounts)
    item_to_name = _item_institution_map(items)

    groups: dict[str, dict] = {}
    for a in accounts:
        name = item_to_name.get(a["item_id"], "Unknown Institution")
        g = groups.setdefault(name, {"name": name, "account_count": 0, "balance": 0.0})
        g["account_count"] += 1
        g["balance"] += a["balance"] or 0.0

    result = list(groups.values())
    for g in result:
        g["pct_of_total"] = (g["balance"] / total * 100) if total else 0.0
    result.sort(key=lambda g: -g["balance"])
    return result


def credit_utilization(credit_accounts: list[dict]) -> dict:
    total_limit = sum(a["credit_limit"] or 0.0 for a in credit_accounts)
    total_available = sum(a["available_credit"] or 0.0 for a in credit_accounts)
    total_outstanding = total_limit - total_available
    utilization_pct = (total_outstanding / total_limit * 100) if total_limit else 0.0
    return {
        "total_balance_outstanding": total_outstanding,
        "total_limit": total_limit,
        "utilization_pct": utilization_pct,
    }


def group_investments_by_type(investments: list[dict]) -> list[dict]:
    # `balance` is the investment's total current position value; `value` is
    # a per-unit/rate figure (e.g. quota price) not comparable across types.
    active = [i for i in investments if i.get("status") != "TOTAL_WITHDRAWAL"]
    total = sum(i["balance"] or 0.0 for i in active)

    groups: dict[str, float] = {}
    for i in active:
        label = asset_class_label(i.get("type"))
        groups[label] = groups.get(label, 0.0) + (i["balance"] or 0.0)

    result = [
        {"type": t, "value": v, "pct_of_total": (v / total * 100) if total else 0.0}
        for t, v in groups.items()
    ]
    result.sort(key=lambda g: -g["value"])
    return result


def group_investments_by_institution(investments: list[dict], items: list[dict]) -> list[dict]:
    active = [i for i in investments if i.get("status") != "TOTAL_WITHDRAWAL"]
    total = sum(i["balance"] or 0.0 for i in active)
    item_to_name = _item_institution_map(items)

    groups: dict[str, float] = {}
    for i in active:
        name = item_to_name.get(i["item_id"], "Unknown Institution")
        groups[name] = groups.get(name, 0.0) + (i["balance"] or 0.0)

    result = [
        {"name": n, "value": v, "pct_of_total": (v / total * 100) if total else 0.0}
        for n, v in groups.items()
    ]
    result.sort(key=lambda g: -g["value"])
    return result


def group_expenses_by_category(transactions: list[dict]) -> list[dict]:
    groups: dict[str, float] = {}
    for t in transactions:
        if t.get("type") != "DEBIT":
            continue
        cat = t.get("category") or "Uncategorized"
        groups[cat] = groups.get(cat, 0.0) + abs(t.get("amount") or 0.0)

    result = [{"category": c, "total": v} for c, v in groups.items()]
    result.sort(key=lambda g: -g["total"])
    return result


_STATUS_BUCKETS = {
    "UPDATED": "Connected",
    "LOGIN_ERROR": "Needs Attention",
    "OUTDATED": "Needs Attention",
    "WAITING_USER_INPUT": "Needs Attention",
    "UPDATING": "Synchronizing",
    "CREATING": "Synchronizing",
    "LOGIN_IN_PROGRESS": "Synchronizing",
}


def connection_status_bucket(status: str | None) -> str:
    return _STATUS_BUCKETS.get(status, "Disconnected")


def upcoming_expenses(credit_card_bills: list[dict], transactions: list[dict]) -> list[dict]:
    today = date.today().isoformat()
    result = []

    for b in credit_card_bills:
        due = b.get("due_date")
        if due and due >= today:
            result.append({
                "description": "Credit card bill",
                "amount": b.get("balance") or 0.0,
                "due_date": due,
                "source": "credit_card_bill",
            })

    for t in transactions:
        if t.get("status") == "PENDING":
            result.append({
                "description": t.get("description") or "",
                "amount": abs(t.get("amount") or 0.0),
                "due_date": t.get("date"),
                "source": "pending_transaction",
            })

    result.sort(key=lambda x: x["due_date"] or "")
    return result
