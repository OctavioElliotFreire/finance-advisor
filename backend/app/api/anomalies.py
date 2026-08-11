import uuid
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import or_
from sqlalchemy.orm import Session

from app.auth.access_scope import AccessScope, get_access_scope
from app.auth.dependencies import get_current_app_user
from app.database.session import get_db
from app.llm.base import LLMProvider, get_provider
from app.llm.redaction import redact_transaction_context
from app.models.account import Account
from app.models.anomaly import AnomalyFlag
from app.models.app_user import AppUser
from app.models.transaction import Transaction
from app.schemas.anomaly import AnomalyStatusUpdate, AnomalySummary
from app.services.audit import record_audit_event
from app.services.rate_limiting import check_and_record_rate_limit

ERROR_METADATA_MAX_LENGTH = 500

router = APIRouter(
    prefix="/v1/households/{household_id}/anomalies", tags=["anomalies"]
)

EXPLAIN_RATE_LIMIT_MAX_CALLS = 20
EXPLAIN_RATE_LIMIT_WINDOW = timedelta(hours=1)


def get_llm_provider() -> LLMProvider:
    return get_provider()


def _get_flag_or_404(
    db: Session,
    household_id: uuid.UUID,
    anomaly_id: uuid.UUID,
    scope: AccessScope,
) -> AnomalyFlag:
    flag = (
        db.query(AnomalyFlag)
        .filter(AnomalyFlag.id == anomaly_id, AnomalyFlag.household_id == household_id)
        .one_or_none()
    )
    if flag is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Anomaly not found")

    if scope.connection_ids is not None:
        # A member-deviation flag is always visible to the member it's
        # about, regardless of their connection grants — that's the whole
        # point of the flag. Otherwise fall back to the transaction's
        # connection (category-deviation flags have neither and stay
        # hidden from restricted members, unchanged from before).
        if flag.household_member_id == scope.membership.id:
            return flag
        account = (
            db.query(Account)
            .join(Transaction, Transaction.account_id == Account.id)
            .filter(Transaction.id == flag.transaction_id)
            .one_or_none()
            if flag.transaction_id
            else None
        )
        if account is None or account.pluggy_connection_id not in scope.connection_ids:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Anomaly not found")

    return flag


@router.get("", response_model=list[AnomalySummary])
def list_anomalies(
    household_id: uuid.UUID,
    status_filter: str | None = None,
    scope: AccessScope = Depends(get_access_scope),
    db: Session = Depends(get_db),
):
    query = db.query(AnomalyFlag).filter(AnomalyFlag.household_id == household_id)
    if status_filter is not None:
        query = query.filter(AnomalyFlag.status == status_filter)
    if scope.connection_ids is not None:
        # Outer joins so transaction_id IS NULL rows (category-deviation,
        # member-deviation) survive the join instead of being dropped — a
        # member-deviation flag about this member is visible even with no
        # transaction/connection to match; a category-deviation flag (no
        # member either) still isn't, unchanged from before.
        query = (
            query.outerjoin(Transaction, AnomalyFlag.transaction_id == Transaction.id)
            .outerjoin(Account, Transaction.account_id == Account.id)
            .filter(
                or_(
                    AnomalyFlag.household_member_id == scope.membership.id,
                    Account.pluggy_connection_id.in_(scope.connection_ids),
                )
            )
        )
    flags = query.order_by(AnomalyFlag.created_at.desc()).all()
    return [AnomalySummary.model_validate(f) for f in flags]


@router.post("/{anomaly_id}/explain", response_model=AnomalySummary)
def explain_anomaly(
    household_id: uuid.UUID,
    anomaly_id: uuid.UUID,
    scope: AccessScope = Depends(get_access_scope),
    current_user: AppUser = Depends(get_current_app_user),
    db: Session = Depends(get_db),
    provider: LLMProvider = Depends(get_llm_provider),
):
    flag = _get_flag_or_404(db, household_id, anomaly_id, scope)

    check_and_record_rate_limit(
        db,
        scope=f"anomaly_explain:{household_id}",
        max_calls=EXPLAIN_RATE_LIMIT_MAX_CALLS,
        window=EXPLAIN_RATE_LIMIT_WINDOW,
        error_detail=(
            f"This household has reached the limit of "
            f"{EXPLAIN_RATE_LIMIT_MAX_CALLS} anomaly explanations per hour. "
            "Please try again later."
        ),
    )

    transaction = (
        db.get(Transaction, flag.transaction_id) if flag.transaction_id else None
    )
    context = redact_transaction_context(flag, transaction)

    try:
        explanation = provider.explain_anomaly(context)
    except Exception as exc:  # noqa: BLE001 - never leak raw SDK/provider errors
        record_audit_event(
            db,
            household_id=household_id,
            actor_app_user_id=current_user.id,
            action="anomaly_explain.call_failed",
            target_type="anomaly_flag",
            target_id=flag.id,
            metadata={"error": str(exc)[:ERROR_METADATA_MAX_LENGTH]},
        )
        db.commit()
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="The anomaly explanation service is temporarily unavailable. Please try again shortly.",
        ) from exc

    flag.explanation = explanation
    flag.explained_at = datetime.now(timezone.utc)
    db.commit()
    db.refresh(flag)
    return AnomalySummary.model_validate(flag)


@router.patch("/{anomaly_id}", response_model=AnomalySummary)
def update_anomaly_status(
    household_id: uuid.UUID,
    anomaly_id: uuid.UUID,
    body: AnomalyStatusUpdate,
    scope: AccessScope = Depends(get_access_scope),
    db: Session = Depends(get_db),
):
    flag = _get_flag_or_404(db, household_id, anomaly_id, scope)
    flag.status = body.status
    db.commit()
    db.refresh(flag)
    return AnomalySummary.model_validate(flag)
