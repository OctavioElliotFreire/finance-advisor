import uuid
from datetime import date, datetime

from sqlalchemy import func
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.orm import Session

from app.models.account import Account
from app.models.extended_finance import BalanceSnapshot, CreditCardBill, Investment, Loan
from app.models.transaction import Transaction


def _parse_date(value: str | None):
    if not value:
        return None
    return datetime.fromisoformat(value.replace("Z", "+00:00")).date()


def upsert_accounts(
    db: Session,
    household_id: uuid.UUID,
    pluggy_connection_id: uuid.UUID,
    accounts: list[dict],
) -> dict[str, uuid.UUID]:
    """Batch-upserts Pluggy accounts for one connection. Returns a map of
    pluggy_account_id -> internal Account.id for use when upserting
    transactions.
    """
    if not accounts:
        return {}

    rows = []
    for account in accounts:
        credit_data = account.get("creditData") or {}
        rows.append(
            {
                "id": uuid.uuid4(),
                "household_id": household_id,
                "pluggy_connection_id": pluggy_connection_id,
                "pluggy_account_id": account["id"],
                "name": account.get("name"),
                "type": account.get("type"),
                "subtype": account.get("subtype"),
                "number": account.get("number"),
                "balance": account.get("balance"),
                "currency_code": account.get("currencyCode") or "BRL",
                "credit_limit": credit_data.get("creditLimit"),
                "available_credit_limit": credit_data.get("availableCreditLimit"),
                "raw_json": account,
            }
        )

    stmt = pg_insert(Account).values(rows)
    stmt = stmt.on_conflict_do_update(
        index_elements=["household_id", "pluggy_account_id"],
        set_={
            "pluggy_connection_id": stmt.excluded.pluggy_connection_id,
            "name": stmt.excluded.name,
            "type": stmt.excluded.type,
            "subtype": stmt.excluded.subtype,
            "number": stmt.excluded.number,
            "balance": stmt.excluded.balance,
            "currency_code": stmt.excluded.currency_code,
            "credit_limit": stmt.excluded.credit_limit,
            "available_credit_limit": stmt.excluded.available_credit_limit,
            "raw_json": stmt.excluded.raw_json,
            "updated_at": func.now(),
        },
    ).returning(Account.id, Account.pluggy_account_id)

    result = db.execute(stmt)
    return {row.pluggy_account_id: row.id for row in result}


def upsert_transactions(
    db: Session,
    household_id: uuid.UUID,
    account_id: uuid.UUID,
    transactions: list[dict],
) -> None:
    """Batch-upserts Pluggy transactions for one account."""
    if not transactions:
        return

    rows = []
    for txn in transactions:
        rows.append(
            {
                "id": uuid.uuid4(),
                "household_id": household_id,
                "account_id": account_id,
                "pluggy_transaction_id": txn["id"],
                "description": txn.get("description"),
                "amount": txn.get("amount"),
                "currency_code": txn.get("currencyCode") or "BRL",
                "transaction_date": _parse_date(txn.get("date")),
                "category": txn.get("category"),
                "raw_json": txn,
            }
        )

    stmt = pg_insert(Transaction).values(rows)
    stmt = stmt.on_conflict_do_update(
        index_elements=["household_id", "pluggy_transaction_id"],
        set_={
            "account_id": stmt.excluded.account_id,
            "description": stmt.excluded.description,
            "amount": stmt.excluded.amount,
            "currency_code": stmt.excluded.currency_code,
            "transaction_date": stmt.excluded.transaction_date,
            "category": stmt.excluded.category,
            "raw_json": stmt.excluded.raw_json,
            "updated_at": func.now(),
        },
    )
    db.execute(stmt)


def upsert_credit_card_bills(
    db: Session,
    household_id: uuid.UUID,
    account_id: uuid.UUID,
    bills: list[dict],
) -> None:
    """Batch-upserts Pluggy credit card bills for one CREDIT account."""
    if not bills:
        return

    rows = []
    for bill in bills:
        rows.append(
            {
                "id": uuid.uuid4(),
                "household_id": household_id,
                "account_id": account_id,
                "pluggy_bill_id": bill["id"],
                "due_date": _parse_date(bill.get("dueDate")),
                "closing_date": _parse_date(bill.get("closingDate")),
                "total_amount": bill.get("balance"),
                "minimum_payment": bill.get("minimumPayment"),
                "currency_code": bill.get("currencyCode") or "BRL",
                "raw_json": bill,
            }
        )

    stmt = pg_insert(CreditCardBill).values(rows)
    stmt = stmt.on_conflict_do_update(
        index_elements=["household_id", "pluggy_bill_id"],
        set_={
            "account_id": stmt.excluded.account_id,
            "due_date": stmt.excluded.due_date,
            "closing_date": stmt.excluded.closing_date,
            "total_amount": stmt.excluded.total_amount,
            "minimum_payment": stmt.excluded.minimum_payment,
            "currency_code": stmt.excluded.currency_code,
            "raw_json": stmt.excluded.raw_json,
            "updated_at": func.now(),
        },
    )
    db.execute(stmt)


def upsert_investments(
    db: Session,
    household_id: uuid.UUID,
    pluggy_connection_id: uuid.UUID,
    investments: list[dict],
) -> None:
    """Batch-upserts Pluggy investments for one connection (item)."""
    if not investments:
        return

    rows = []
    for inv in investments:
        rows.append(
            {
                "id": uuid.uuid4(),
                "household_id": household_id,
                "pluggy_connection_id": pluggy_connection_id,
                "pluggy_investment_id": inv["id"],
                "name": inv.get("name"),
                "type": inv.get("type"),
                "subtype": inv.get("subtype"),
                "balance": inv.get("balance"),
                "value": inv.get("value"),
                "quantity": inv.get("quantity"),
                "currency_code": inv.get("currencyCode") or "BRL",
                "investment_date": _parse_date(inv.get("date")),
                "raw_json": inv,
            }
        )

    stmt = pg_insert(Investment).values(rows)
    stmt = stmt.on_conflict_do_update(
        index_elements=["household_id", "pluggy_investment_id"],
        set_={
            "pluggy_connection_id": stmt.excluded.pluggy_connection_id,
            "name": stmt.excluded.name,
            "type": stmt.excluded.type,
            "subtype": stmt.excluded.subtype,
            "balance": stmt.excluded.balance,
            "value": stmt.excluded.value,
            "quantity": stmt.excluded.quantity,
            "currency_code": stmt.excluded.currency_code,
            "investment_date": stmt.excluded.investment_date,
            "raw_json": stmt.excluded.raw_json,
            "updated_at": func.now(),
        },
    )
    db.execute(stmt)


def upsert_loans(
    db: Session,
    household_id: uuid.UUID,
    pluggy_connection_id: uuid.UUID,
    loans: list[dict],
) -> None:
    """Batch-upserts Pluggy loans for one connection (item)."""
    if not loans:
        return

    rows = []
    for loan in loans:
        rows.append(
            {
                "id": uuid.uuid4(),
                "household_id": household_id,
                "pluggy_connection_id": pluggy_connection_id,
                "pluggy_loan_id": loan["id"],
                "type": loan.get("type"),
                "status": loan.get("status"),
                "contract_amount": loan.get("contractedAmount"),
                "outstanding_balance": loan.get("outstandingBalance"),
                "installment_amount": loan.get("installmentAmount"),
                "installments_total": loan.get("totalInstallments"),
                "installments_paid": loan.get("paidInstallments"),
                "due_date": _parse_date(loan.get("dueDate")),
                "interest_rate": loan.get("interestRate"),
                "currency_code": loan.get("currencyCode") or "BRL",
                "raw_json": loan,
            }
        )

    stmt = pg_insert(Loan).values(rows)
    stmt = stmt.on_conflict_do_update(
        index_elements=["household_id", "pluggy_loan_id"],
        set_={
            "pluggy_connection_id": stmt.excluded.pluggy_connection_id,
            "type": stmt.excluded.type,
            "status": stmt.excluded.status,
            "contract_amount": stmt.excluded.contract_amount,
            "outstanding_balance": stmt.excluded.outstanding_balance,
            "installment_amount": stmt.excluded.installment_amount,
            "installments_total": stmt.excluded.installments_total,
            "installments_paid": stmt.excluded.installments_paid,
            "due_date": stmt.excluded.due_date,
            "interest_rate": stmt.excluded.interest_rate,
            "currency_code": stmt.excluded.currency_code,
            "raw_json": stmt.excluded.raw_json,
            "updated_at": func.now(),
        },
    )
    db.execute(stmt)


def snapshot_balances(
    db: Session,
    household_id: uuid.UUID,
    account_balances: dict[uuid.UUID, tuple[float | None, str]],
    snapshot_date: date,
) -> None:
    """Upserts one balance snapshot per account for `snapshot_date`, keyed on
    (account_id, snapshot_date) so re-running sync the same day updates the
    existing row instead of duplicating it.
    """
    if not account_balances:
        return

    rows = [
        {
            "id": uuid.uuid4(),
            "household_id": household_id,
            "account_id": account_id,
            "balance": balance,
            "currency_code": currency_code or "BRL",
            "snapshot_date": snapshot_date,
        }
        for account_id, (balance, currency_code) in account_balances.items()
    ]

    stmt = pg_insert(BalanceSnapshot).values(rows)
    stmt = stmt.on_conflict_do_update(
        index_elements=["account_id", "snapshot_date"],
        set_={
            "balance": stmt.excluded.balance,
            "currency_code": stmt.excluded.currency_code,
        },
    )
    db.execute(stmt)
