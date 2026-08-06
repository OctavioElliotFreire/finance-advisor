import uuid

from fastapi import APIRouter, Depends
from sqlalchemy import case, func
from sqlalchemy.orm import Session

from app.auth.access_scope import AccessScope, get_access_scope
from app.database.session import get_db
from app.models.account import Account
from app.models.household import Household
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
    scope: AccessScope = Depends(get_access_scope),
    db: Session = Depends(get_db),
):
    connection_ids = scope.connection_ids
    household = db.query(Household).filter(Household.id == household_id).one()

    accounts_query = db.query(Account).filter(Account.household_id == household_id)
    if connection_ids is not None:
        accounts_query = accounts_query.filter(
            Account.pluggy_connection_id.in_(connection_ids)
        )
    accounts = accounts_query.order_by(Account.type, Account.name).all()
    total_balance = sum(float(a.balance) for a in accounts if a.balance is not None)

    recent_query = (
        db.query(Transaction, Account.name)
        .join(Account, Transaction.account_id == Account.id)
        .filter(Transaction.household_id == household_id)
    )
    if connection_ids is not None:
        recent_query = recent_query.filter(
            Account.pluggy_connection_id.in_(connection_ids)
        )
    recent_rows = (
        recent_query.order_by(
            Transaction.transaction_date.desc(), Transaction.created_at.desc()
        )
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
        MonthlyCashFlow(
            month=row.month.strftime("%Y-%m"),
            income=float(row.income or 0),
            expenses=float(row.expenses or 0),
            net=float((row.income or 0) - (row.expenses or 0)),
        )
        for row in reversed(cash_flow_rows)
    ]

    sync_query = db.query(SyncJob).filter(SyncJob.household_id == household_id)
    if connection_ids is not None:
        sync_query = sync_query.filter(SyncJob.pluggy_connection_id.in_(connection_ids))
    latest_job = sync_query.order_by(SyncJob.updated_at.desc()).first()
    sync_status = SyncStatus(
        status=latest_job.status if latest_job else None,
        updated_at=latest_job.updated_at if latest_job else None,
    )

    return DashboardResponse(
        household_name=household.name,
        accounts=[AccountSummary.model_validate(a) for a in accounts],
        total_balance=total_balance,
        recent_transactions=recent_transactions,
        monthly_cash_flow=monthly_cash_flow,
        sync_status=sync_status,
    )
