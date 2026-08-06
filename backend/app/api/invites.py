import uuid
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.auth.dependencies import get_current_app_user
from app.database.session import get_db
from app.models.app_user import AppUser
from app.models.household import Household, HouseholdMember
from app.models.household_invite import HouseholdInvite
from app.schemas.invite import AcceptInviteResponse, InvitePreview
from app.services.audit import record_audit_event

router = APIRouter(prefix="/v1/invites", tags=["invites"])


def _get_invite_or_404(db: Session, invite_id: uuid.UUID) -> HouseholdInvite:
    invite = db.query(HouseholdInvite).filter(HouseholdInvite.id == invite_id).one_or_none()
    if invite is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Invite not found")
    return invite


@router.get("/{invite_id}", response_model=InvitePreview)
def preview_invite(invite_id: uuid.UUID, db: Session = Depends(get_db)):
    invite = _get_invite_or_404(db, invite_id)
    household = db.query(Household).filter(Household.id == invite.household_id).one()
    now = datetime.now(timezone.utc)
    return InvitePreview(
        household_name=household.name,
        email=invite.email,
        role=invite.role,
        expired=invite.expires_at < now,
        accepted=invite.accepted_at is not None,
    )


@router.post("/{invite_id}/accept", response_model=AcceptInviteResponse)
def accept_invite(
    invite_id: uuid.UUID,
    current_user: AppUser = Depends(get_current_app_user),
    db: Session = Depends(get_db),
):
    invite = _get_invite_or_404(db, invite_id)

    if invite.accepted_at is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="This invite has already been accepted.",
        )
    if invite.expires_at < datetime.now(timezone.utc):
        raise HTTPException(
            status_code=status.HTTP_410_GONE, detail="This invite has expired."
        )
    if invite.email.strip().lower() != current_user.email.strip().lower():
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="This invite was sent to a different email address.",
        )

    membership = HouseholdMember(
        household_id=invite.household_id,
        app_user_id=current_user.id,
        role=invite.role,
    )
    db.add(membership)
    try:
        db.flush()
    except IntegrityError:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="You are already a member of this household.",
        )

    invite.accepted_at = datetime.now(timezone.utc)
    record_audit_event(
        db,
        household_id=invite.household_id,
        actor_app_user_id=current_user.id,
        action="invite.accepted",
        target_type="household_invite",
        target_id=invite.id,
        metadata={"email": invite.email, "role": invite.role},
    )
    db.commit()

    household = db.query(Household).filter(Household.id == invite.household_id).one()
    return AcceptInviteResponse(household_id=household.id, household_name=household.name)
