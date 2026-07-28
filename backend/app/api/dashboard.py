import uuid

from fastapi import APIRouter, Depends
from sqlalchemy import case, func
from sqlalchemy.orm import Session

from app.auth.dependencies import get_household_membership
from app.database.session import get_db
from app.models.account import Account
from app.models.household import HouseholdMember
from app.models.pluggy_connection import SyncJob
from app.models.transaction import Transaction
from app.schemas.dashboard import (
    AccountSummary,
    DashboardResponse,
    MonthlyCashFlow,
    SyncStatus,
    TransactionSummary,
)

router = APIRouter(
    prefix="/v1/households/{household_id}/dashboard", tags=["dashboard"]
)

RECENT_TRANSACTIONS_LIMIT = 10
CASH_FLOW_MONTHS = 6


@router.get("", response_model=DashboardResponse)
def get_dashboard(
    household_id: uuid.UUID,
    membership: HouseholdMember = Depends(get_household_membership),
    db: Session = Depends(get_db),
):
    accounts = (
        db.query(Account)
        .filter(Account.household_id == household_id)
        .order_by(Account.type, Account.name)
        .all()
    )
    total_balance = sum(float(a.balance) for a in accounts if a.balance is not None)

    recent_rows = (
        db.query(Transaction, Account.name)
        .join(Account, Transaction.account_id == Account.id)
        .filter(Transaction.household_id == household_id)
        .order_by(Transaction.transaction_date.desc(), Transaction.created_at.desc())
        .limit(RECENT_TRANSACTIONS_LIMIT)
        .all()
    )
    recent_transactions = [
        TransactionSummary(
            id=txn.id,
            account_name=account_name,
            description=txn.description,
            amount=float(txn.amount),
            currency_code=txn.currency_code,
            transaction_date=txn.transaction_date,
            category=txn.category,
        )
        for txn, account_name in recent_rows
    ]

    month_col = func.date_trunc("month", Transaction.transaction_date)
    cash_flow_rows = (
        db.query(
            month_col.label("month"),
            func.sum(
                case((Transaction.amount > 0, Transaction.amount), else_=0)
            ).label("income"),
            func.sum(
                case((Transaction.amount < 0, -Transaction.amount), else_=0)
            ).label("expenses"),
        )
        .filter(Transaction.household_id == household_id)
        .group_by(month_col)
        .order_by(month_col.desc())
        .limit(CASH_FLOW_MONTHS)
        .all()
    )
    monthly_cash_flow = [
        MonthlyCashFlow(
            month=row.month.strftime("%Y-%m"),
            income=float(row.income or 0),
            expenses=float(row.expenses or 0),
            net=float((row.income or 0) - (row.expenses or 0)),
        )
        for row in reversed(cash_flow_rows)
    ]

    latest_job = (
        db.query(SyncJob)
        .filter(SyncJob.household_id == household_id)
        .order_by(SyncJob.updated_at.desc())
        .first()
    )
    sync_status = SyncStatus(
        status=latest_job.status if latest_job else None,
        updated_at=latest_job.updated_at if latest_job else None,
    )

    return DashboardResponse(
        accounts=[AccountSummary.model_validate(a) for a in accounts],
        total_balance=total_balance,
        recent_transactions=recent_transactions,
        monthly_cash_flow=monthly_cash_flow,
        sync_status=sync_status,
    )
