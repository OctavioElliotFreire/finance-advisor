import uuid

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.auth.dependencies import require_role
from app.database.session import get_db
from app.models.audit_event import AuditEvent
from app.models.household import HouseholdMember
from app.models.pluggy_connection import PluggyConnection, SyncJob
from app.schemas.alerts import (
    FailedSyncJobSummary,
    FailureEventSummary,
    HouseholdAlertsResponse,
)

router = APIRouter(prefix="/v1/households/{household_id}/alerts", tags=["alerts"])

FAILURE_EVENT_ACTIONS = ("assistant.call_failed", "anomaly_explain.call_failed")
LIST_LIMIT = 50


@router.get("", response_model=HouseholdAlertsResponse)
def list_household_alerts(
    household_id: uuid.UUID,
    membership: HouseholdMember = Depends(require_role("owner")),
    db: Session = Depends(get_db),
):
    """Queryable "needs attention" list — failed syncs and failed LLM
    calls. No external notification (email/Slack/etc.) is wired up; this
    only surfaces what already went wrong so an owner can check, rather
    than paging anyone. See PLAN.md's Milestone 10 notes for why.
    """
    failed_jobs = (
        db.query(SyncJob, PluggyConnection.pluggy_item_id)
        .join(PluggyConnection, PluggyConnection.id == SyncJob.pluggy_connection_id)
        .filter(SyncJob.household_id == household_id, SyncJob.status == "failed")
        .order_by(SyncJob.updated_at.desc())
        .limit(LIST_LIMIT)
        .all()
    )

    failure_events = (
        db.query(AuditEvent)
        .filter(
            AuditEvent.household_id == household_id,
            AuditEvent.action.in_(FAILURE_EVENT_ACTIONS),
        )
        .order_by(AuditEvent.created_at.desc())
        .limit(LIST_LIMIT)
        .all()
    )

    return HouseholdAlertsResponse(
        failed_sync_jobs=[
            FailedSyncJobSummary(
                id=job.id,
                pluggy_connection_id=job.pluggy_connection_id,
                pluggy_item_id=item_id,
                updated_at=job.updated_at,
            )
            for job, item_id in failed_jobs
        ],
        failure_events=[
            FailureEventSummary(
                id=event.id,
                action=event.action,
                target_type=event.target_type,
                target_id=event.target_id,
                metadata_json=event.metadata_json,
                created_at=event.created_at,
            )
            for event in failure_events
        ],
    )
