import uuid

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.auth.access_scope import AccessScope, get_access_scope
from app.auth.dependencies import get_current_app_user
from app.database.session import get_db
from app.models.app_user import AppUser
from app.services.audit import record_audit_event
from app.services.household_export import build_household_export

router = APIRouter(
    prefix="/v1/households/{household_id}/export", tags=["export"]
)


@router.get("")
def export_household_data(
    household_id: uuid.UUID,
    scope: AccessScope = Depends(get_access_scope),
    current_user: AppUser = Depends(get_current_app_user),
    db: Session = Depends(get_db),
) -> dict:
    export = build_household_export(db, household_id, scope.connection_ids)

    record_audit_event(
        db,
        household_id=household_id,
        actor_app_user_id=current_user.id,
        action="data.exported",
        target_type="household",
        target_id=household_id,
    )
    db.commit()

    return export
