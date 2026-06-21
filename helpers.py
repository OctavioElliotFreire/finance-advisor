from datetime import date
from db import get_connection, get_all_members


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
    with get_connection() as conn:
        row = conn.execute(
            """SELECT COALESCE(SUM(value), 0)
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
