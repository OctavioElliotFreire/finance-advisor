import uuid
from datetime import date, timedelta

from fastapi import APIRouter, Depends, Query
from sqlalchemy import case, func
from sqlalchemy.orm import Session

from app.auth.access_scope import (
    AccessScope,
    connection_member_map,
    get_access_scope,
    resolve_member_ids,
)
from app.database.session import get_db
from app.models.account import Account
from app.models.extended_finance import BalanceSnapshot, CreditCardBill, Investment, Loan
from app.models.transaction import Transaction
from app.models.transaction_split import TransactionSplit
from app.schemas.extended_finance import (
    BalancePoint,
    CategoryBreakdownItem,
    CreditCardBillSummary,
    InvestmentSummary,
    LoanSummary,
    MemberSpendItem,
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
    """Category-level spend, split-aware: a split transaction's spend
    attributes to each split's own category instead of the parent's single
    (now-stale) category. Splitting never changes the total (splits sum
    back to the parent), so unsplit transactions and splits are two
    disjoint slices of the same total — summed here rather than joined in
    one query, since a transaction is either counted via its own category
    or via its splits, never both.
    """
    has_split_subquery = (
        db.query(TransactionSplit.transaction_id)
        .filter(TransactionSplit.transaction_id == Transaction.id)
        .exists()
    )

    unsplit_query = db.query(
        Transaction.category.label("category"),
        func.sum(case((Transaction.amount < 0, -Transaction.amount), else_=0)).label(
            "total"
        ),
    ).filter(
        Transaction.household_id == household_id,
        Transaction.is_transfer.is_(False),
        Transaction.transaction_date >= start_date,
        Transaction.transaction_date <= end_date,
        ~has_split_subquery,
    )
    if connection_ids is not None:
        unsplit_query = unsplit_query.join(
            Account, Transaction.account_id == Account.id
        ).filter(Account.pluggy_connection_id.in_(connection_ids))
    unsplit_rows = unsplit_query.group_by(Transaction.category).all()

    split_query = (
        db.query(
            TransactionSplit.category.label("category"),
            func.sum(
                case((TransactionSplit.amount < 0, -TransactionSplit.amount), else_=0)
            ).label("total"),
        )
        .join(Transaction, TransactionSplit.transaction_id == Transaction.id)
        .filter(
            Transaction.household_id == household_id,
            Transaction.is_transfer.is_(False),
            Transaction.transaction_date >= start_date,
            Transaction.transaction_date <= end_date,
        )
    )
    if connection_ids is not None:
        split_query = split_query.join(
            Account, Transaction.account_id == Account.id
        ).filter(Account.pluggy_connection_id.in_(connection_ids))
    split_rows = split_query.group_by(TransactionSplit.category).all()

    totals: dict[str | None, float] = {}
    for row in unsplit_rows:
        totals[row.category] = totals.get(row.category, 0.0) + float(row.total or 0)
    for row in split_rows:
        totals[row.category] = totals.get(row.category, 0.0) + float(row.total or 0)
    return totals


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


@router.get("/spending-by-member", response_model=list[MemberSpendItem])
def get_spending_by_member(
    household_id: uuid.UUID,
    start_date: date | None = None,
    end_date: date | None = None,
    member_ids: list[uuid.UUID] | None = Query(None),
    scope: AccessScope = Depends(get_access_scope),
    db: Session = Depends(get_db),
):
    """Powers Análises · Gastos's per-member stacked bar (`design.md`'s
    Global Scope / density rulebook). Returns flat `(month, member_id,
    total)` rows with no folding — the 3%/4px "Outros" folding and the
    unstacked/stacked/ranked-list mode choice are frontend concerns, same
    convention as `/categories` returning raw category totals.
    """
    if end_date is None:
        end_date = date.today()
    if start_date is None:
        start_date = end_date.replace(day=1)

    connection_ids = resolve_member_ids(
        db, household_id, scope.connection_ids, member_ids
    )
    connection_to_member = connection_member_map(db, household_id, connection_ids)

    month_col = func.date_trunc("month", Transaction.transaction_date)
    query = (
        db.query(
            month_col.label("month"),
            Account.pluggy_connection_id.label("connection_id"),
            func.sum(case((Transaction.amount < 0, -Transaction.amount), else_=0)).label(
                "total"
            ),
        )
        .join(Account, Transaction.account_id == Account.id)
        .filter(
            Transaction.household_id == household_id,
            Transaction.is_transfer.is_(False),
            Transaction.transaction_date >= start_date,
            Transaction.transaction_date <= end_date,
        )
    )
    if connection_ids is not None:
        query = query.filter(Account.pluggy_connection_id.in_(connection_ids))
    rows = query.group_by(month_col, Account.pluggy_connection_id).all()

    # Two connections can map to the same member (or both to `None`), and a
    # connection can appear with no rows if it had no transactions in range
    # — fold by (month, member_id) rather than assuming one row per connection.
    totals: dict[tuple[str, uuid.UUID | None], float] = {}
    for row in rows:
        member_id = connection_to_member.get(row.connection_id)
        key = (row.month.strftime("%Y-%m"), member_id)
        totals[key] = totals.get(key, 0.0) + float(row.total or 0)

    items = [
        MemberSpendItem(month=month, member_id=member_id, total=total)
        for (month, member_id), total in totals.items()
    ]
    items.sort(key=lambda item: (item.month, item.member_id is None, str(item.member_id)))
    return items
