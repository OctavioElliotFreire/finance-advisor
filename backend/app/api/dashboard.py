import uuid
from datetime import date

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
from app.models.household import Household
from app.models.pluggy_connection import PluggyConnection, SyncJob
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
transactions_router = APIRouter(
    prefix="/v1/households/{household_id}", tags=["dashboard"]
)

RECENT_TRANSACTIONS_LIMIT = 10
CASH_FLOW_MONTHS = 6
DEFAULT_TRANSACTIONS_LIMIT = 50


def _list_transactions(
    db: Session,
    household_id: uuid.UUID,
    connection_ids: set[uuid.UUID] | None,
    start_date: date | None,
    end_date: date | None,
    limit: int,
    offset: int = 0,
) -> list[TransactionSummary]:
    """Shared transaction query behind both the dashboard's fixed-10 teaser
    and the paginated `/transactions` endpoint (Contas · Extrato) — same
    scoping rules, different limit/offset/date-range inputs.
    """
    query = (
        db.query(Transaction, Account.name)
        .join(Account, Transaction.account_id == Account.id)
        .filter(Transaction.household_id == household_id)
    )
    if connection_ids is not None:
        query = query.filter(Account.pluggy_connection_id.in_(connection_ids))
    if start_date is not None:
        query = query.filter(Transaction.transaction_date >= start_date)
    if end_date is not None:
        query = query.filter(Transaction.transaction_date <= end_date)

    rows = (
        query.order_by(
            Transaction.transaction_date.desc(), Transaction.created_at.desc()
        )
        .limit(limit)
        .offset(offset)
        .all()
    )
    return [
        TransactionSummary(
            id=txn.id,
            account_name=account_name,
            description=txn.description,
            amount=float(txn.amount),
            currency_code=txn.currency_code,
            transaction_date=txn.transaction_date,
            category=txn.category,
        )
        for txn, account_name in rows
    ]


@router.get("", response_model=DashboardResponse)
def get_dashboard(
    household_id: uuid.UUID,
    start_date: date | None = None,
    end_date: date | None = None,
    member_ids: list[uuid.UUID] | None = Query(None),
    scope: AccessScope = Depends(get_access_scope),
    db: Session = Depends(get_db),
):
    connection_ids = resolve_member_ids(
        db, household_id, scope.connection_ids, member_ids
    )
    household = db.query(Household).filter(Household.id == household_id).one()

    accounts_query = db.query(Account).filter(Account.household_id == household_id)
    if connection_ids is not None:
        accounts_query = accounts_query.filter(
            Account.pluggy_connection_id.in_(connection_ids)
        )
    accounts = accounts_query.order_by(Account.type, Account.name).all()
    total_balance = sum(float(a.balance) for a in accounts if a.balance is not None)

    connection_status_by_id = {
        row[0]: row[1]
        for row in db.query(PluggyConnection.id, PluggyConnection.status).filter(
            PluggyConnection.household_id == household_id
        )
    }
    connection_to_member = connection_member_map(db, household_id, connection_ids)
    account_summaries = [
        AccountSummary.model_validate(a).model_copy(
            update={
                "connection_status": connection_status_by_id.get(a.pluggy_connection_id),
                "owner_member_id": connection_to_member.get(a.pluggy_connection_id),
            }
        )
        for a in accounts
    ]

    # Início's own transaction teaser is a fixed "last 10", not period-scoped
    # — the period/member controls narrow it by member only, matching
    # Início's unchanged hero content (see design.md's Global Scope table:
    # Início content itself isn't being rebuilt this pass).
    recent_transactions = _list_transactions(
        db, household_id, connection_ids, None, None, RECENT_TRANSACTIONS_LIMIT
    )

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

    if start_date is not None or end_date is not None:
        # A period was explicitly picked — bucket by month within that exact
        # range instead of the fixed last-N-months default below.
        if start_date is not None:
            cash_flow_query = cash_flow_query.filter(
                Transaction.transaction_date >= start_date
            )
        if end_date is not None:
            cash_flow_query = cash_flow_query.filter(
                Transaction.transaction_date <= end_date
            )
        cash_flow_rows = cash_flow_query.group_by(month_col).order_by(month_col).all()
        monthly_cash_flow = [
            MonthlyCashFlow(
                month=row.month.strftime("%Y-%m"),
                income=float(row.income or 0),
                expenses=float(row.expenses or 0),
                net=float((row.income or 0) - (row.expenses or 0)),
            )
            for row in cash_flow_rows
        ]
    else:
        cash_flow_rows = (
            cash_flow_query.group_by(month_col)
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

    sync_query = db.query(SyncJob).filter(SyncJob.household_id == household_id)
    if connection_ids is not None:
        sync_query = sync_query.filter(SyncJob.pluggy_connection_id.in_(connection_ids))
    latest_job = sync_query.order_by(SyncJob.updated_at.desc()).first()

    total_connections_query = db.query(PluggyConnection).filter(
        PluggyConnection.household_id == household_id
    )
    if connection_ids is not None:
        total_connections_query = total_connections_query.filter(
            PluggyConnection.id.in_(connection_ids)
        )
    total_connections = total_connections_query.count()

    # Latest job per connection, in the same scope — "há Xh" reuses the
    # single household-wide latest job above, but "N de M" needs each
    # connection's own most recent job, not just the overall latest.
    all_jobs_in_scope = sync_query.order_by(
        SyncJob.pluggy_connection_id, SyncJob.updated_at.desc()
    ).all()
    latest_job_by_connection: dict[uuid.UUID, SyncJob] = {}
    for job in all_jobs_in_scope:
        latest_job_by_connection.setdefault(job.pluggy_connection_id, job)
    synced_connections = sum(
        1 for job in latest_job_by_connection.values() if job.status == "completed"
    )

    sync_status = SyncStatus(
        status=latest_job.status if latest_job else None,
        updated_at=latest_job.updated_at if latest_job else None,
        synced_connections=synced_connections,
        total_connections=total_connections,
    )

    return DashboardResponse(
        household_name=household.name,
        accounts=account_summaries,
        total_balance=total_balance,
        recent_transactions=recent_transactions,
        monthly_cash_flow=monthly_cash_flow,
        sync_status=sync_status,
    )


@transactions_router.get("/transactions", response_model=list[TransactionSummary])
def list_transactions(
    household_id: uuid.UUID,
    start_date: date | None = None,
    end_date: date | None = None,
    member_ids: list[uuid.UUID] | None = Query(None),
    limit: int = Query(DEFAULT_TRANSACTIONS_LIMIT, gt=0, le=200),
    offset: int = Query(0, ge=0),
    scope: AccessScope = Depends(get_access_scope),
    db: Session = Depends(get_db),
):
    """Paginated, period/member-filterable transaction list for Contas ·
    Extrato — distinct from the dashboard's fixed-10 teaser above, which
    reuses the same `_list_transactions` query with no date range/pagination.
    """
    connection_ids = resolve_member_ids(
        db, household_id, scope.connection_ids, member_ids
    )
    return _list_transactions(
        db, household_id, connection_ids, start_date, end_date, limit, offset
    )
