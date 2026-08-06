import uuid

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.auth.dependencies import require_role
from app.database.session import get_db
from app.models.app_user import AppUser
from app.models.audit_event import AuditEvent
from app.models.household import HouseholdMember
from app.schemas.audit import AuditEventResponse

router = APIRouter(
    prefix="/v1/households/{household_id}/audit-events", tags=["audit"]
)

LIST_LIMIT = 200


@router.get("", response_model=list[AuditEventResponse])
def list_audit_events(
    household_id: uuid.UUID,
    membership: HouseholdMember = Depends(require_role("owner")),
    db: Session = Depends(get_db),
):
    rows = (
        db.query(AuditEvent, AppUser.email)
        .join(AppUser, AppUser.id == AuditEvent.actor_app_user_id)
        .filter(AuditEvent.household_id == household_id)
        .order_by(AuditEvent.created_at.desc())
        .limit(LIST_LIMIT)
        .all()
    )
    return [
        AuditEventResponse(
            id=event.id,
            actor_email=email,
            action=event.action,
            target_type=event.target_type,
            target_id=event.target_id,
            metadata_json=event.metadata_json,
            created_at=event.created_at,
        )
        for event, email in rows
    ]
