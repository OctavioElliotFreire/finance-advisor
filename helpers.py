from datetime import date
from db import get_connection, get_all_members, get_accounts_for_member, get_transactions_for_member


def get_current_month() -> str:
    return date.today().strftime("%Y-%m")


def get_monthly_spend(member_id: str, month: str | None = None) -> float:
    month = month or get_current_month()
    with get_connection() as conn:
        row = conn.execute(
            """SELECT COALESCE(SUM(ABS(amount)), 0)
               FROM transactions
               WHERE member_id = ?
                 AND type = 'DEBIT'
                 AND strftime('%Y-%m', date) = ?""",
            (member_id, month),
        ).fetchone()
    return row[0] or 0.0


def get_total_bank_balance(member_id: str) -> float:
    with get_connection() as conn:
        row = conn.execute(
            """SELECT COALESCE(SUM(balance), 0)
               FROM accounts
               WHERE member_id = ? AND type = 'BANK'""",
            (member_id,),
        ).fetchone()
    return row[0] or 0.0


def get_total_investments_value(member_id: str) -> float:
    # `balance` is the investment's total current position value; `value` is
    # a per-unit/rate figure (e.g. quota price) and not comparable across
    # asset types -- confirmed against real synced Pluggy data.
    with get_connection() as conn:
        row = conn.execute(
            """SELECT COALESCE(SUM(balance), 0)
               FROM investments
               WHERE member_id = ? AND status != 'TOTAL_WITHDRAWAL'""",
            (member_id,),
        ).fetchone()
    return row[0] or 0.0


def get_credit_available(member_id: str) -> float:
    with get_connection() as conn:
        row = conn.execute(
            """SELECT COALESCE(SUM(available_credit), 0)
               FROM accounts
               WHERE member_id = ? AND type = 'CREDIT'""",
            (member_id,),
        ).fetchone()
    return row[0] or 0.0


def get_member_summary(member_id: str, month: str | None = None) -> dict:
    return {
        "bank_balance": get_total_bank_balance(member_id),
        "monthly_spend": get_monthly_spend(member_id, month),
        "investments_value": get_total_investments_value(member_id),
        "credit_available": get_credit_available(member_id),
    }


def get_family_summary(month: str | None = None) -> dict:
    members = get_all_members()
    total_balance = 0.0
    total_spend = 0.0
    total_investments = 0.0

    per_member = []
    for m in members:
        summary = get_member_summary(m["id"], month)
        total_balance += summary["bank_balance"]
        total_spend += summary["monthly_spend"]
        total_investments += summary["investments_value"]
        per_member.append({"id": m["id"], "name": m["name"], **summary})

    return {
        "total_bank_balance": total_balance,
        "total_monthly_spend": total_spend,
        "total_investments_value": total_investments,
        "per_member": per_member,
    }


def shift_month(month: str, delta: int) -> str:
    year, mo = map(int, month.split("-"))
    total = year * 12 + (mo - 1) + delta
    year2, mo2 = divmod(total, 12)
    return f"{year2:04d}-{mo2 + 1:02d}"


def get_balance_evolution(member_id: str | None, months: int = 24) -> list[dict]:
    member_ids = [member_id] if member_id else [m["id"] for m in get_all_members()]
    current_balance = sum(get_total_bank_balance(mid) for mid in member_ids)

    bank_account_ids = set()
    for mid in member_ids:
        for a in get_accounts_for_member(mid):
            if a["type"] == "BANK":
                bank_account_ids.add(a["id"])

    current_month = get_current_month()
    if not bank_account_ids:
        return [{"month": current_month, "balance": current_balance}]

    bank_txns = []
    for mid in member_ids:
        bank_txns.extend(
            t for t in get_transactions_for_member(mid, days=months * 31)
            if t["account_id"] in bank_account_ids
        )

    if not bank_txns:
        return [{"month": current_month, "balance": current_balance}]

    net_by_month: dict[str, float] = {}
    for t in bank_txns:
        month = (t["date"] or "")[:7]
        if not month:
            continue
        net_by_month[month] = net_by_month.get(month, 0.0) + (t["amount"] or 0.0)

    oldest_month = min(net_by_month)

    months_list = []
    m = current_month
    for _ in range(months):
        months_list.append(m)
        if m <= oldest_month:
            break
        m = shift_month(m, -1)
    months_list.reverse()  # ascending: oldest -> newest

    balances = {months_list[-1]: current_balance}
    running = current_balance
    for i in range(len(months_list) - 1, 0, -1):
        running -= net_by_month.get(months_list[i], 0.0)
        balances[months_list[i - 1]] = running

    return [{"month": mo, "balance": balances[mo]} for mo in months_list]
