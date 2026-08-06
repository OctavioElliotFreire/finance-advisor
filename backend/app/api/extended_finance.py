import uuid
from datetime import date, timedelta

from fastapi import APIRouter, Depends, Query
from sqlalchemy import case, func
from sqlalchemy.orm import Session

from app.auth.access_scope import AccessScope, get_access_scope
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
DEFAULT_CATEGORY_MONTHS = 1


@router.get("/credit-card-bills", response_model=list[CreditCardBillSummary])
def list_credit_card_bills(
    household_id: uuid.UUID,
    scope: AccessScope = Depends(get_access_scope),
    db: Session = Depends(get_db),
):
    query = db.query(CreditCardBill).filter(CreditCardBill.household_id == household_id)
    if scope.connection_ids is not None:
        query = query.join(Account, CreditCardBill.account_id == Account.id).filter(
            Account.pluggy_connection_id.in_(scope.connection_ids)
        )
    bills = query.order_by(CreditCardBill.due_date).all()
    return [CreditCardBillSummary.model_validate(b) for b in bills]


@router.get("/investments", response_model=list[InvestmentSummary])
def list_investments(
    household_id: uuid.UUID,
    scope: AccessScope = Depends(get_access_scope),
    db: Session = Depends(get_db),
):
    query = db.query(Investment).filter(Investment.household_id == household_id)
    if scope.connection_ids is not None:
        query = query.filter(Investment.pluggy_connection_id.in_(scope.connection_ids))
    investments = query.order_by(Investment.type, Investment.name).all()
    return [InvestmentSummary.model_validate(i) for i in investments]


@router.get("/loans", response_model=list[LoanSummary])
def list_loans(
    household_id: uuid.UUID,
    scope: AccessScope = Depends(get_access_scope),
    db: Session = Depends(get_db),
):
    query = db.query(Loan).filter(Loan.household_id == household_id)
    if scope.connection_ids is not None:
        query = query.filter(Loan.pluggy_connection_id.in_(scope.connection_ids))
    loans = query.order_by(Loan.due_date).all()
    return [LoanSummary.model_validate(loan) for loan in loans]


@router.get("/balance-history", response_model=list[BalancePoint])
def get_balance_history(
    household_id: uuid.UUID,
    account_id: uuid.UUID | None = None,
    days: int = Query(DEFAULT_BALANCE_HISTORY_DAYS, gt=0),
    scope: AccessScope = Depends(get_access_scope),
    db: Session = Depends(get_db),
):
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
    if scope.connection_ids is not None:
        query = query.join(Account, BalanceSnapshot.account_id == Account.id).filter(
            Account.pluggy_connection_id.in_(scope.connection_ids)
        )

    rows = query.group_by(BalanceSnapshot.snapshot_date).order_by(
        BalanceSnapshot.snapshot_date
    ).all()

    return [
        BalancePoint(snapshot_date=row.snapshot_date, total_balance=float(row.total_balance or 0))
        for row in rows
    ]


@router.get("/categories", response_model=list[CategoryBreakdownItem])
def get_category_breakdown(
    household_id: uuid.UUID,
    months: int = Query(DEFAULT_CATEGORY_MONTHS, gt=0),
    scope: AccessScope = Depends(get_access_scope),
    db: Session = Depends(get_db),
):
    since = date.today().replace(day=1) - timedelta(days=31 * (months - 1))
    since = since.replace(day=1)

    query = db.query(
        Transaction.category.label("category"),
        func.sum(case((Transaction.amount < 0, -Transaction.amount), else_=0)).label(
            "total"
        ),
    ).filter(
        Transaction.household_id == household_id,
        Transaction.transaction_date >= since,
    )
    if scope.connection_ids is not None:
        query = query.join(Account, Transaction.account_id == Account.id).filter(
            Account.pluggy_connection_id.in_(scope.connection_ids)
        )

    rows = (
        query.group_by(Transaction.category)
        .order_by(func.sum(case((Transaction.amount < 0, -Transaction.amount), else_=0)).desc())
        .all()
    )

    return [
        CategoryBreakdownItem(category=row.category, total=float(row.total or 0))
        for row in rows
    ]
