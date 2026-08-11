import uuid
from datetime import date, timedelta

from sqlalchemy.orm import Session

from app.models.transaction import Transaction

TRANSFER_MATCH_WINDOW_DAYS = 2


def detect_internal_transfers(db: Session, household_id: uuid.UUID) -> int:
    """Marks pairs of transactions across different accounts in the same
    household as internal transfers when they match on amount, direction
    (opposite signs), and land within `TRANSFER_MATCH_WINDOW_DAYS` of each
    other — per `design.md`'s Data Model rule ("match on amount, direction,
    and a short time window across linked accounts; net out both legs").
    Only ever considers rows still `is_transfer=False`, so re-running is a
    no-op for anything already matched (idempotent by construction) —
    matches `run_anomaly_detection`'s pattern of being safe to call on
    every sync.
    """
    unmatched = (
        db.query(Transaction)
        .filter(
            Transaction.household_id == household_id,
            Transaction.is_transfer.is_(False),
            Transaction.amount != 0,
        )
        .order_by(Transaction.transaction_date, Transaction.created_at)
        .all()
    )

    debits = [t for t in unmatched if t.amount < 0]
    credits = [t for t in unmatched if t.amount > 0]
    matched_credit_ids: set[uuid.UUID] = set()
    matched_count = 0

    for debit in debits:
        match = _find_match(debit, credits, matched_credit_ids)
        if match is None:
            continue
        debit.is_transfer = True
        match.is_transfer = True
        matched_credit_ids.add(match.id)
        matched_count += 2

    return matched_count


def _find_match(
    debit: Transaction, credits: list[Transaction], already_matched: set[uuid.UUID]
) -> Transaction | None:
    debit_amount = abs(float(debit.amount))
    for credit in credits:
        if credit.id in already_matched:
            continue
        if credit.account_id == debit.account_id:
            continue
        if abs(float(credit.amount)) != debit_amount:
            continue
        if _date_gap(debit.transaction_date, credit.transaction_date) > TRANSFER_MATCH_WINDOW_DAYS:
            continue
        return credit
    return None


def _date_gap(a: date, b: date) -> int:
    return abs((a - b).days)
