import uuid
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.auth.dependencies import get_household_membership
from app.database.session import get_db
from app.llm.base import LLMProvider, get_provider
from app.llm.redaction import redact_transaction_context
from app.models.anomaly import AnomalyFlag
from app.models.household import HouseholdMember
from app.models.transaction import Transaction
from app.schemas.anomaly import AnomalyStatusUpdate, AnomalySummary

router = APIRouter(
    prefix="/v1/households/{household_id}/anomalies", tags=["anomalies"]
)


def get_llm_provider() -> LLMProvider:
    return get_provider()


def _get_flag_or_404(db: Session, household_id: uuid.UUID, anomaly_id: uuid.UUID) -> AnomalyFlag:
    flag = (
        db.query(AnomalyFlag)
        .filter(AnomalyFlag.id == anomaly_id, AnomalyFlag.household_id == household_id)
        .one_or_none()
    )
    if flag is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Anomaly not found")
    return flag


@router.get("", response_model=list[AnomalySummary])
def list_anomalies(
    household_id: uuid.UUID,
    status_filter: str | None = None,
    membership: HouseholdMember = Depends(get_household_membership),
    db: Session = Depends(get_db),
):
    query = db.query(AnomalyFlag).filter(AnomalyFlag.household_id == household_id)
    if status_filter is not None:
        query = query.filter(AnomalyFlag.status == status_filter)
    flags = query.order_by(AnomalyFlag.created_at.desc()).all()
    return [AnomalySummary.model_validate(f) for f in flags]


@router.post("/{anomaly_id}/explain", response_model=AnomalySummary)
def explain_anomaly(
    household_id: uuid.UUID,
    anomaly_id: uuid.UUID,
    membership: HouseholdMember = Depends(get_household_membership),
    db: Session = Depends(get_db),
    provider: LLMProvider = Depends(get_llm_provider),
):
    flag = _get_flag_or_404(db, household_id, anomaly_id)
    transaction = (
        db.get(Transaction, flag.transaction_id) if flag.transaction_id else None
    )
    context = redact_transaction_context(flag, transaction)

    flag.explanation = provider.explain_anomaly(context)
    flag.explained_at = datetime.now(timezone.utc)
    db.commit()
    db.refresh(flag)
    return AnomalySummary.model_validate(flag)


@router.patch("/{anomaly_id}", response_model=AnomalySummary)
def update_anomaly_status(
    household_id: uuid.UUID,
    anomaly_id: uuid.UUID,
    body: AnomalyStatusUpdate,
    membership: HouseholdMember = Depends(get_household_membership),
    db: Session = Depends(get_db),
):
    flag = _get_flag_or_404(db, household_id, anomaly_id)
    flag.status = body.status
    db.commit()
    db.refresh(flag)
    return AnomalySummary.model_validate(flag)
