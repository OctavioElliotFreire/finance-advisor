import uuid

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.auth.dependencies import get_household_membership, require_role
from app.database.session import get_db
from app.models.app_user import AppUser
from app.models.household import HouseholdMember
from app.schemas.household import HouseholdMemberResponse, MemberInvite

router = APIRouter(
    prefix="/v1/households/{household_id}/members", tags=["households"]
)


@router.post("", response_model=HouseholdMemberResponse, status_code=201)
def invite_member(
    household_id: uuid.UUID,
    payload: MemberInvite,
    membership: HouseholdMember = Depends(require_role("owner")),
    db: Session = Depends(get_db),
):
    target = db.query(AppUser).filter(AppUser.email == payload.email).one_or_none()
    if target is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No account found for that email. Ask them to sign up, then invite again.",
        )

    new_membership = HouseholdMember(
        household_id=household_id,
        app_user_id=target.id,
        role=payload.role,
    )
    db.add(new_membership)
    try:
        db.flush()
    except IntegrityError:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="This person is already a member of this household.",
        )

    db.commit()
    db.refresh(new_membership)
    return HouseholdMemberResponse(
        id=new_membership.id,
        app_user_id=target.id,
        email=target.email,
        role=new_membership.role,
        created_at=new_membership.created_at,
    )


@router.get("", response_model=list[HouseholdMemberResponse])
def list_members(
    household_id: uuid.UUID,
    membership: HouseholdMember = Depends(get_household_membership),
    db: Session = Depends(get_db),
):
    rows = (
        db.query(HouseholdMember, AppUser.email)
        .join(AppUser, AppUser.id == HouseholdMember.app_user_id)
        .filter(HouseholdMember.household_id == household_id)
        .all()
    )
    return [
        HouseholdMemberResponse(
            id=member.id,
            app_user_id=member.app_user_id,
            email=email,
            role=member.role,
            created_at=member.created_at,
        )
        for member, email in rows
    ]
