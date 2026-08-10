import uuid
from datetime import date, timedelta

from fastapi import APIRouter, Depends, Query
from sqlalchemy import case, func
from sqlalchemy.orm import Session

from app.auth.access_scope import AccessScope, get_access_scope, resolve_member_ids
from app.database.session import get_db
from app.models.account import Account
from app.models.extended_finance import BalanceSnapshot, CreditCardBill, Investment, Loan
from app.models.transaction import Transaction
from app.schemas.extended_finance import (
    BalancePoint,
    CategoryBreakdownItem,
    CreditCardBillSummary,
    InvestmentSummary,
    LoanSummary,
)

router = APIRouter(prefix="/v1/households/{household_id}", tags=["extended-finance"])

DEFAULT_BALANCE_HISTORY_DAYS = 90


@router.get("/credit-card-bills", response_model=list[CreditCardBillSummary])
def list_credit_card_bills(
    household_id: uuid.UUID,
    member_ids: list[uuid.UUID] | None = Query(None),
    scope: AccessScope = Depends(get_access_scope),
    db: Session = Depends(get_db),
):
    connection_ids = resolve_member_ids(
        db, household_id, scope.connection_ids, member_ids
    )
    query = db.query(CreditCardBill).filter(CreditCardBill.household_id == household_id)
    if connection_ids is not None:
        query = query.join(Account, CreditCardBill.account_id == Account.id).filter(
            Account.pluggy_connection_id.in_(connection_ids)
        )
    bills = query.order_by(CreditCardBill.due_date).all()
    return [CreditCardBillSummary.model_validate(b) for b in bills]


@router.get("/investments", response_model=list[InvestmentSummary])
def list_investments(
    household_id: uuid.UUID,
    member_ids: list[uuid.UUID] | None = Query(None),
    scope: AccessScope = Depends(get_access_scope),
    db: Session = Depends(get_db),
):
    connection_ids = resolve_member_ids(
        db, household_id, scope.connection_ids, member_ids
    )
    query = db.query(Investment).filter(Investment.household_id == household_id)
    if connection_ids is not None:
        query = query.filter(Investment.pluggy_connection_id.in_(connection_ids))
    investments = query.order_by(Investment.type, Investment.name).all()
    return [InvestmentSummary.model_validate(i) for i in investments]


@router.get("/loans", response_model=list[LoanSummary])
def list_loans(
    household_id: uuid.UUID,
    member_ids: list[uuid.UUID] | None = Query(None),
    scope: AccessScope = Depends(get_access_scope),
    db: Session = Depends(get_db),
):
    connection_ids = resolve_member_ids(
        db, household_id, scope.connection_ids, member_ids
    )
    query = db.query(Loan).filter(Loan.household_id == household_id)
    if connection_ids is not None:
        query = query.filter(Loan.pluggy_connection_id.in_(connection_ids))
    loans = query.order_by(Loan.due_date).all()
    return [LoanSummary.model_validate(loan) for loan in loans]


@router.get("/balance-history", response_model=list[BalancePoint])
def get_balance_history(
    household_id: uuid.UUID,
    account_id: uuid.UUID | None = None,
    days: int = Query(DEFAULT_BALANCE_HISTORY_DAYS, gt=0),
    member_ids: list[uuid.UUID] | None = Query(None),
    scope: AccessScope = Depends(get_access_scope),
    db: Session = Depends(get_db),
):
    connection_ids = resolve_member_ids(
        db, household_id, scope.connection_ids, member_ids
    )
    since = date.today() - timedelta(days=days)
    query = db.query(
        BalanceSnapshot.snapshot_date.label("snapshot_date"),
        func.sum(BalanceSnapshot.balance).label("total_balance"),
    ).filter(
        BalanceSnapshot.household_id == household_id,
        BalanceSnapshot.snapshot_date >= since,
    )
    if account_id is not None:
        query = query.filter(BalanceSnapshot.account_id == account_id)
    if connection_ids is not None:
        query = query.join(Account, BalanceSnapshot.account_id == Account.id).filter(
            Account.pluggy_connection_id.in_(connection_ids)
        )

    rows = query.group_by(BalanceSnapshot.snapshot_date).order_by(
        BalanceSnapshot.snapshot_date
    ).all()

    return [
        BalancePoint(snapshot_date=row.snapshot_date, total_balance=float(row.total_balance or 0))
        for row in rows
    ]


def _category_totals(
    db: Session,
    household_id: uuid.UUID,
    connection_ids: set[uuid.UUID] | None,
    start_date: date,
    end_date: date,
) -> dict[str | None, float]:
    query = db.query(
        Transaction.category.label("category"),
        func.sum(case((Transaction.amount < 0, -Transaction.amount), else_=0)).label(
            "total"
        ),
    ).filter(
        Transaction.household_id == household_id,
        Transaction.transaction_date >= start_date,
        Transaction.transaction_date <= end_date,
    )
    if connection_ids is not None:
        query = query.join(Account, Transaction.account_id == Account.id).filter(
            Account.pluggy_connection_id.in_(connection_ids)
        )
    rows = query.group_by(Transaction.category).all()
    return {row.category: float(row.total or 0) for row in rows}


@router.get("/categories", response_model=list[CategoryBreakdownItem])
def get_category_breakdown(
    household_id: uuid.UUID,
    start_date: date | None = None,
    end_date: date | None = None,
    member_ids: list[uuid.UUID] | None = Query(None),
    compare_previous: bool = False,
    scope: AccessScope = Depends(get_access_scope),
    db: Session = Depends(get_db),
):
    # Default window preserves the old `months=1` behavior: the current
    # calendar month to date, when no explicit range is given.
    if end_date is None:
        end_date = date.today()
    if start_date is None:
        start_date = end_date.replace(day=1)

    connection_ids = resolve_member_ids(
        db, household_id, scope.connection_ids, member_ids
    )
    totals = _category_totals(db, household_id, connection_ids, start_date, end_date)

    previous_totals: dict[str | None, float] = {}
    if compare_previous:
        period_length = (end_date - start_date) + timedelta(days=1)
        previous_end = start_date - timedelta(days=1)
        previous_start = previous_end - period_length + timedelta(days=1)
        previous_totals = _category_totals(
            db, household_id, connection_ids, previous_start, previous_end
        )

    items = [
        CategoryBreakdownItem(
            category=category,
            total=total,
            previous_total=previous_totals.get(category) if compare_previous else None,
        )
        for category, total in totals.items()
    ]
    items.sort(key=lambda item: item.total, reverse=True)
    return items
