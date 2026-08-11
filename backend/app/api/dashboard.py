import uuid
from datetime import date

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import case, func
from sqlalchemy.orm import Session

from app.auth.access_scope import (
    AccessScope,
    connection_member_map,
    get_access_scope,
    resolve_member_ids,
)
from app.auth.dependencies import get_current_app_user
from app.database.session import get_db
from app.models.account import Account
from app.models.anomaly import AnomalyFlag
from app.models.app_user import AppUser
from app.models.household import Household
from app.models.pluggy_connection import PluggyConnection, SyncJob
from app.models.transaction import Transaction
from app.models.transaction_split import TransactionSplit
from app.schemas.anomaly import AnomalySummary
from app.schemas.dashboard import (
    AccountSummary,
    DashboardResponse,
    MonthlyCashFlow,
    SyncStatus,
    TransactionCategoryUpdate,
    TransactionSplitItem,
    TransactionSplitsUpdate,
    TransactionSummary,
)
from app.services.audit import record_audit_event

router = APIRouter(
    prefix="/v1/households/{household_id}/dashboard", tags=["dashboard"]
)
transactions_router = APIRouter(
    prefix="/v1/households/{household_id}", tags=["dashboard"]
)

RECENT_TRANSACTIONS_LIMIT = 10
CASH_FLOW_MONTHS = 6
DEFAULT_TRANSACTIONS_LIMIT = 50
SPLIT_SUM_TOLERANCE = 0.01
MANUAL_FLAG_SEVERITY = "low"
MANUAL_FLAG_SUMMARY = "Sinalizado manualmente por um membro da família"


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

    # Small, cheap follow-up query for "is this transaction currently
    # flagged" — Contas · Extrato's flag icon and the drill-down panel's
    # unflag button (which needs the flag's own id to call the existing
    # `PATCH /anomalies/{id}`). Only `open` flags count as currently
    # flagged; a dismissed/confirmed flag no longer needs the user's
    # attention on the statement row. If more than one rule has an open
    # flag on the same transaction, any one of their ids is returned —
    # the row only shows a single flag affordance either way.
    txn_ids = [txn.id for txn, _ in rows]
    flag_id_by_txn: dict[uuid.UUID, uuid.UUID] = {}
    if txn_ids:
        flag_id_by_txn = {
            row.transaction_id: row.id
            for row in db.query(AnomalyFlag.transaction_id, AnomalyFlag.id).filter(
                AnomalyFlag.transaction_id.in_(txn_ids),
                AnomalyFlag.status == "open",
            )
        }

    splits_by_txn: dict[uuid.UUID, list[TransactionSplitItem]] = {}
    if txn_ids:
        for split in db.query(TransactionSplit).filter(
            TransactionSplit.transaction_id.in_(txn_ids)
        ):
            splits_by_txn.setdefault(split.transaction_id, []).append(
                TransactionSplitItem.model_validate(split)
            )

    return [
        TransactionSummary(
            id=txn.id,
            account_id=txn.account_id,
            account_name=account_name,
            description=txn.description,
            amount=float(txn.amount),
            currency_code=txn.currency_code,
            transaction_date=txn.transaction_date,
            category=txn.category,
            is_flagged=txn.id in flag_id_by_txn,
            is_transfer=txn.is_transfer,
            flag_id=flag_id_by_txn.get(txn.id),
            splits=splits_by_txn.get(txn.id, []),
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
    ).filter(
        Transaction.household_id == household_id, Transaction.is_transfer.is_(False)
    )
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


def _get_transaction_or_404(
    db: Session,
    household_id: uuid.UUID,
    transaction_id: uuid.UUID,
    scope: AccessScope,
) -> Transaction:
    txn = (
        db.query(Transaction)
        .filter(Transaction.id == transaction_id, Transaction.household_id == household_id)
        .one_or_none()
    )
    if txn is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Transaction not found")

    if scope.connection_ids is not None:
        account = db.query(Account).filter(Account.id == txn.account_id).one_or_none()
        if account is None or account.pluggy_connection_id not in scope.connection_ids:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Transaction not found")

    return txn


def _build_transaction_summary(db: Session, txn: Transaction) -> TransactionSummary:
    """Builds a single-row `TransactionSummary` for the drill-down panel's
    mutation endpoints — the bulk `_list_transactions` above is shaped for
    a paginated list (date range, limit/offset), awkward to reuse for "just
    this one row after I changed it."
    """
    account = db.query(Account).filter(Account.id == txn.account_id).one_or_none()
    flag = (
        db.query(AnomalyFlag)
        .filter(AnomalyFlag.transaction_id == txn.id, AnomalyFlag.status == "open")
        .first()
    )
    splits = [
        TransactionSplitItem.model_validate(s)
        for s in db.query(TransactionSplit).filter(TransactionSplit.transaction_id == txn.id)
    ]
    return TransactionSummary(
        id=txn.id,
        account_id=txn.account_id,
        account_name=account.name if account else None,
        description=txn.description,
        amount=float(txn.amount),
        currency_code=txn.currency_code,
        transaction_date=txn.transaction_date,
        category=txn.category,
        is_flagged=flag is not None,
        is_transfer=txn.is_transfer,
        flag_id=flag.id if flag else None,
        splits=splits,
    )


@transactions_router.patch("/transactions/{transaction_id}", response_model=TransactionSummary)
def update_transaction_category(
    household_id: uuid.UUID,
    transaction_id: uuid.UUID,
    body: TransactionCategoryUpdate,
    scope: AccessScope = Depends(get_access_scope),
    current_user: AppUser = Depends(get_current_app_user),
    db: Session = Depends(get_db),
):
    """Recategorize — the drill-down panel's simplest action. No category
    vocabulary is enforced server-side (`Transaction.category` has always
    been unconstrained free text from Pluggy); the picker's vocabulary is
    a frontend concern.
    """
    txn = _get_transaction_or_404(db, household_id, transaction_id, scope)
    txn.category = body.category
    record_audit_event(
        db,
        household_id=household_id,
        actor_app_user_id=current_user.id,
        action="transaction.recategorized",
        target_type="transaction",
        target_id=txn.id,
        metadata={"category": body.category},
    )
    db.commit()
    db.refresh(txn)
    return _build_transaction_summary(db, txn)


@transactions_router.put(
    "/transactions/{transaction_id}/splits", response_model=TransactionSummary
)
def update_transaction_splits(
    household_id: uuid.UUID,
    transaction_id: uuid.UUID,
    body: TransactionSplitsUpdate,
    scope: AccessScope = Depends(get_access_scope),
    current_user: AppUser = Depends(get_current_app_user),
    db: Session = Depends(get_db),
):
    """Full-replace semantics, same shape as `PUT /members/{id}/access` —
    deletes whatever splits exist for this transaction and inserts the
    given set. An empty `splits` list clears them. Splits must sum back to
    the parent's own amount (same sign) — splitting only recategorizes
    spend across buckets, it never changes the total.
    """
    txn = _get_transaction_or_404(db, household_id, transaction_id, scope)

    if body.splits:
        total = sum(item.amount for item in body.splits)
        if abs(total - float(txn.amount)) > SPLIT_SUM_TOLERANCE:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=(
                    f"Splits must sum to the transaction amount "
                    f"(R$ {float(txn.amount):.2f}), got R$ {total:.2f}."
                ),
            )
        parent_is_negative = float(txn.amount) < 0
        for item in body.splits:
            if (item.amount < 0) != parent_is_negative:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Each split must have the same sign as the transaction.",
                )

    db.query(TransactionSplit).filter(TransactionSplit.transaction_id == txn.id).delete(
        synchronize_session=False
    )
    for item in body.splits:
        db.add(
            TransactionSplit(
                transaction_id=txn.id,
                category=item.category,
                amount=item.amount,
                description=item.description,
            )
        )
    record_audit_event(
        db,
        household_id=household_id,
        actor_app_user_id=current_user.id,
        action="transaction.splits_updated",
        target_type="transaction",
        target_id=txn.id,
        metadata={"split_count": len(body.splits)},
    )
    db.commit()
    db.refresh(txn)
    return _build_transaction_summary(db, txn)


@transactions_router.post(
    "/transactions/{transaction_id}/flag", response_model=AnomalySummary
)
def flag_transaction(
    household_id: uuid.UUID,
    transaction_id: uuid.UUID,
    scope: AccessScope = Depends(get_access_scope),
    current_user: AppUser = Depends(get_current_app_user),
    db: Session = Depends(get_db),
):
    """Manual flag — reuses the existing `AnomalyFlag` system entirely
    (`rule="manual"`) rather than inventing a second flag concept: same
    row icon, same status workflow, same anomalies list. Unflagging reuses
    the already-built `PATCH /anomalies/{id}` with `status: "dismissed"`.

    Deliberately queries for an existing row instead of relying purely on
    the `(household_id, rule, dedupe_key)` unique constraint's
    `ON CONFLICT DO NOTHING` (the pattern `run_anomaly_detection` uses) —
    that constraint alone can't distinguish "never flagged" from
    "flagged, then dismissed," and a dismissed manual flag must be
    re-openable (flag/unflag is a user-driven toggle, unlike an automatic
    rule's permanent-once-dismissed dedupe).
    """
    txn = _get_transaction_or_404(db, household_id, transaction_id, scope)

    existing = (
        db.query(AnomalyFlag)
        .filter(
            AnomalyFlag.household_id == household_id,
            AnomalyFlag.rule == "manual",
            AnomalyFlag.dedupe_key == str(txn.id),
        )
        .one_or_none()
    )
    if existing is not None:
        if existing.status != "open":
            existing.status = "open"
            record_audit_event(
                db,
                household_id=household_id,
                actor_app_user_id=current_user.id,
                action="transaction.flagged",
                target_type="transaction",
                target_id=txn.id,
            )
            db.commit()
            db.refresh(existing)
        return AnomalySummary.model_validate(existing)

    flag = AnomalyFlag(
        household_id=household_id,
        transaction_id=txn.id,
        rule="manual",
        dedupe_key=str(txn.id),
        severity=MANUAL_FLAG_SEVERITY,
        summary=MANUAL_FLAG_SUMMARY,
        status="open",
    )
    db.add(flag)
    record_audit_event(
        db,
        household_id=household_id,
        actor_app_user_id=current_user.id,
        action="transaction.flagged",
        target_type="transaction",
        target_id=txn.id,
    )
    db.commit()
    db.refresh(flag)
    return AnomalySummary.model_validate(flag)
