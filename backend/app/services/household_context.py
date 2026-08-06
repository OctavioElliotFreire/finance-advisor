import uuid
from datetime import date, timedelta

from sqlalchemy import case, func
from sqlalchemy.orm import Session

from app.models.account import Account
from app.models.app_user import AppUser
from app.models.extended_finance import BalanceSnapshot, CreditCardBill, Investment, Loan
from app.models.household import Household, HouseholdMember
from app.models.transaction import Transaction

DESCRIPTION_MAX_LENGTH = 80
RECENT_TRANSACTIONS_LIMIT = 30
CASH_FLOW_MONTHS = 6
INVESTMENTS_LIMIT = 20
LOANS_LIMIT = 20
BILLS_LIMIT = 10
BALANCE_HISTORY_DAYS = 30
CATEGORY_BREAKDOWN_MONTHS = 1


def build_household_context(
    db: Session,
    household_id: uuid.UUID,
    connection_ids: set[uuid.UUID] | None = None,
) -> dict:
    """Builds the only data ever sent to the LLM for a free-text question.

    Explicit allowlist per record type — never includes `raw_json`, ORM
    objects, Pluggy identifiers, or account numbers (`Account.number`).
    Every list is capped to bound prompt size and LLM cost. `connection_ids`
    is the caller's resolved access scope (`None` = unrestricted) — every
    sub-query below is scoped the same way as its dashboard/extended_finance
    counterpart, so a restricted member's questions can only ever be answered
    from data they're allowed to see.
    """
    household = db.query(Household).filter(Household.id == household_id).one()

    member_rows = (
        db.query(HouseholdMember, AppUser.email)
        .join(AppUser, AppUser.id == HouseholdMember.app_user_id)
        .filter(HouseholdMember.household_id == household_id)
        .all()
    )
    members = [{"email": email, "role": member.role} for member, email in member_rows]

    accounts_query = db.query(Account).filter(Account.household_id == household_id)
    if connection_ids is not None:
        accounts_query = accounts_query.filter(
            Account.pluggy_connection_id.in_(connection_ids)
        )
    accounts = accounts_query.order_by(Account.type, Account.name).all()
    account_summaries = [
        {
            "name": a.name,
            "type": a.type,
            "subtype": a.subtype,
            "balance": float(a.balance) if a.balance is not None else None,
            "currency_code": a.currency_code,
        }
        for a in accounts
    ]

    recent_query = db.query(Transaction).filter(Transaction.household_id == household_id)
    if connection_ids is not None:
        recent_query = recent_query.join(
            Account, Transaction.account_id == Account.id
        ).filter(Account.pluggy_connection_id.in_(connection_ids))
    recent_rows = (
        recent_query.order_by(
            Transaction.transaction_date.desc(), Transaction.created_at.desc()
        )
        .limit(RECENT_TRANSACTIONS_LIMIT)
        .all()
    )
    recent_transactions = [
        {
            "description": (txn.description or "")[:DESCRIPTION_MAX_LENGTH],
            "amount": float(txn.amount),
            "currency_code": txn.currency_code,
            "category": txn.category,
            "transaction_date": txn.transaction_date.isoformat(),
        }
        for txn in recent_rows
    ]

    month_col = func.date_trunc("month", Transaction.transaction_date)
    cash_flow_query = db.query(
        month_col.label("month"),
        func.sum(case((Transaction.amount > 0, Transaction.amount), else_=0)).label(
            "income"
        ),
        func.sum(case((Transaction.amount < 0, -Transaction.amount), else_=0)).label(
            "expenses"
        ),
    ).filter(Transaction.household_id == household_id)
    if connection_ids is not None:
        cash_flow_query = cash_flow_query.join(
            Account, Transaction.account_id == Account.id
        ).filter(Account.pluggy_connection_id.in_(connection_ids))
    cash_flow_rows = (
        cash_flow_query.group_by(month_col).order_by(month_col.desc()).limit(CASH_FLOW_MONTHS).all()
    )
    monthly_cash_flow = [
        {
            "month": row.month.strftime("%Y-%m"),
            "income": float(row.income or 0),
            "expenses": float(row.expenses or 0),
        }
        for row in reversed(cash_flow_rows)
    ]

    investments_query = db.query(Investment).filter(Investment.household_id == household_id)
    if connection_ids is not None:
        investments_query = investments_query.filter(
            Investment.pluggy_connection_id.in_(connection_ids)
        )
    investments = investments_query.order_by(Investment.type, Investment.name).limit(
        INVESTMENTS_LIMIT
    ).all()
    investment_summaries = [
        {
            "name": i.name,
            "type": i.type,
            "subtype": i.subtype,
            "balance": float(i.balance) if i.balance is not None else None,
            "currency_code": i.currency_code,
        }
        for i in investments
    ]

    loans_query = db.query(Loan).filter(Loan.household_id == household_id)
    if connection_ids is not None:
        loans_query = loans_query.filter(Loan.pluggy_connection_id.in_(connection_ids))
    loans = loans_query.order_by(Loan.due_date).limit(LOANS_LIMIT).all()
    loan_summaries = [
        {
            "type": loan.type,
            "status": loan.status,
            "outstanding_balance": float(loan.outstanding_balance)
            if loan.outstanding_balance is not None
            else None,
            "currency_code": loan.currency_code,
            "due_date": loan.due_date.isoformat() if loan.due_date else None,
            "installments_paid": loan.installments_paid,
            "installments_total": loan.installments_total,
        }
        for loan in loans
    ]

    bills_query = db.query(CreditCardBill).filter(CreditCardBill.household_id == household_id)
    if connection_ids is not None:
        bills_query = bills_query.join(
            Account, CreditCardBill.account_id == Account.id
        ).filter(Account.pluggy_connection_id.in_(connection_ids))
    bills = bills_query.order_by(CreditCardBill.due_date).limit(BILLS_LIMIT).all()
    bill_summaries = [
        {
            "due_date": b.due_date.isoformat() if b.due_date else None,
            "total_amount": float(b.total_amount) if b.total_amount is not None else None,
            "minimum_payment": float(b.minimum_payment)
            if b.minimum_payment is not None
            else None,
            "currency_code": b.currency_code,
        }
        for b in bills
    ]

    since_balance = date.today() - timedelta(days=BALANCE_HISTORY_DAYS)
    balance_query = db.query(
        BalanceSnapshot.snapshot_date.label("snapshot_date"),
        func.sum(BalanceSnapshot.balance).label("total_balance"),
    ).filter(
        BalanceSnapshot.household_id == household_id,
        BalanceSnapshot.snapshot_date >= since_balance,
    )
    if connection_ids is not None:
        balance_query = balance_query.join(
            Account, BalanceSnapshot.account_id == Account.id
        ).filter(Account.pluggy_connection_id.in_(connection_ids))
    balance_rows = (
        balance_query.group_by(BalanceSnapshot.snapshot_date)
        .order_by(BalanceSnapshot.snapshot_date)
        .all()
    )
    balance_history = [
        {
            "snapshot_date": row.snapshot_date.isoformat(),
            "total_balance": float(row.total_balance or 0),
        }
        for row in balance_rows
    ]

    since_category = date.today().replace(day=1) - timedelta(
        days=31 * (CATEGORY_BREAKDOWN_MONTHS - 1)
    )
    since_category = since_category.replace(day=1)
    category_query = db.query(
        Transaction.category.label("category"),
        func.sum(case((Transaction.amount < 0, -Transaction.amount), else_=0)).label(
            "total"
        ),
    ).filter(
        Transaction.household_id == household_id,
        Transaction.transaction_date >= since_category,
    )
    if connection_ids is not None:
        category_query = category_query.join(
            Account, Transaction.account_id == Account.id
        ).filter(Account.pluggy_connection_id.in_(connection_ids))
    category_rows = (
        category_query.group_by(Transaction.category)
        .order_by(func.sum(case((Transaction.amount < 0, -Transaction.amount), else_=0)).desc())
        .all()
    )
    category_breakdown = [
        {"category": row.category, "total": float(row.total or 0)} for row in category_rows
    ]

    return {
        "household_name": household.name,
        "members": members,
        "accounts": account_summaries,
        "recent_transactions": recent_transactions,
        "monthly_cash_flow": monthly_cash_flow,
        "investments": investment_summaries,
        "loans": loan_summaries,
        "credit_card_bills": bill_summaries,
        "balance_history": balance_history,
        "category_breakdown": category_breakdown,
    }
