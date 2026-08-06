import uuid

from sqlalchemy.orm import Session

from app.models.audit_event import AuditEvent


def record_audit_event(
    db: Session,
    household_id: uuid.UUID,
    actor_app_user_id: uuid.UUID,
    action: str,
    target_type: str | None = None,
    target_id: uuid.UUID | None = None,
    metadata: dict | None = None,
) -> None:
    """Appends an audit_events row. Does not commit — callers already commit
    as part of the same request (invite/grant/connection creation), so this
    rides in the same transaction rather than adding a second round-trip.
    """
    db.add(
        AuditEvent(
            household_id=household_id,
            actor_app_user_id=actor_app_user_id,
            action=action,
            target_type=target_type,
            target_id=target_id,
            metadata_json=metadata,
        )
    )
