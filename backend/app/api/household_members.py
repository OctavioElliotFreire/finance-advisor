import uuid
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.auth.dependencies import get_current_app_user, get_household_membership, require_role
from app.auth.supabase_admin import InviteSender, get_invite_sender
from app.database.session import get_db
from app.models.app_user import AppUser
from app.models.connection_access_grant import ConnectionAccessGrant
from app.models.household import HouseholdMember
from app.models.household_invite import HouseholdInvite
from app.models.pluggy_connection import PluggyConnection
from app.schemas.access import ConnectionAccessEntry, MemberAccessUpdate
from app.schemas.household import HouseholdMemberResponse, MemberInvite
from app.schemas.invite import InviteResult, InviteSummary
from app.services.audit import record_audit_event
from app.services.rate_limiting import check_and_record_rate_limit
from app.settings import settings

router = APIRouter(
    prefix="/v1/households/{household_id}/members", tags=["households"]
)

pending_invites_router = APIRouter(
    prefix="/v1/households/{household_id}/invites", tags=["households"]
)

INVITE_EXPIRY_DAYS = 7
INVITE_RATE_LIMIT_MAX_CALLS = 10
INVITE_RATE_LIMIT_WINDOW = timedelta(hours=1)


@router.post("", response_model=InviteResult, status_code=201)
async def invite_member(
    household_id: uuid.UUID,
    payload: MemberInvite,
    membership: HouseholdMember = Depends(require_role("owner")),
    current_user: AppUser = Depends(get_current_app_user),
    db: Session = Depends(get_db),
    invite_sender: InviteSender = Depends(get_invite_sender),
):
    target = db.query(AppUser).filter(AppUser.email == payload.email).one_or_none()
    if target is not None:
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

        record_audit_event(
            db,
            household_id=household_id,
            actor_app_user_id=current_user.id,
            action="member.added",
            target_type="household_member",
            target_id=new_membership.id,
            metadata={"email": target.email, "role": new_membership.role},
        )
        db.commit()
        db.refresh(new_membership)
        return InviteResult(
            outcome="added",
            member=HouseholdMemberResponse(
                id=new_membership.id,
                app_user_id=target.id,
                email=target.email,
                role=new_membership.role,
                created_at=new_membership.created_at,
            ),
        )

    check_and_record_rate_limit(
        db,
        scope=f"member_invite:{household_id}",
        max_calls=INVITE_RATE_LIMIT_MAX_CALLS,
        window=INVITE_RATE_LIMIT_WINDOW,
        error_detail=(
            f"This household has reached the limit of "
            f"{INVITE_RATE_LIMIT_MAX_CALLS} invites per hour. Please try again later."
        ),
    )

    now = datetime.now(timezone.utc)
    invite = (
        db.query(HouseholdInvite)
        .filter(
            HouseholdInvite.household_id == household_id,
            HouseholdInvite.email == payload.email,
            HouseholdInvite.accepted_at.is_(None),
            HouseholdInvite.expires_at > now,
        )
        .one_or_none()
    )
    if invite is None:
        invite = HouseholdInvite(
            household_id=household_id,
            email=payload.email,
            role=payload.role,
            invited_by_app_user_id=current_user.id,
            expires_at=now + timedelta(days=INVITE_EXPIRY_DAYS),
        )
        db.add(invite)
        db.flush()

    redirect_to = f"{settings.frontend_base_url}/?invite={invite.id}"
    try:
        await invite_sender.invite_user_by_email(payload.email, redirect_to)
    except Exception as exc:  # noqa: BLE001 - never leak raw HTTP/SDK errors
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Could not send the invite email right now. Please try again shortly.",
        ) from exc

    record_audit_event(
        db,
        household_id=household_id,
        actor_app_user_id=current_user.id,
        action="member.invited",
        target_type="household_invite",
        target_id=invite.id,
        metadata={"email": invite.email, "role": invite.role},
    )
    db.commit()
    db.refresh(invite)
    return InviteResult(outcome="invited", invite=InviteSummary.model_validate(invite))


@pending_invites_router.get("", response_model=list[InviteSummary])
def list_pending_invites(
    household_id: uuid.UUID,
    membership: HouseholdMember = Depends(require_role("owner")),
    db: Session = Depends(get_db),
):
    invites = (
        db.query(HouseholdInvite)
        .filter(
            HouseholdInvite.household_id == household_id,
            HouseholdInvite.accepted_at.is_(None),
        )
        .order_by(HouseholdInvite.created_at.desc())
        .all()
    )
    return [InviteSummary.model_validate(i) for i in invites]


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
        .order_by(HouseholdMember.created_at)
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


def _get_target_member_or_404(
    db: Session, household_id: uuid.UUID, member_id: uuid.UUID
) -> HouseholdMember:
    target = (
        db.query(HouseholdMember)
        .filter(HouseholdMember.id == member_id, HouseholdMember.household_id == household_id)
        .one_or_none()
    )
    if target is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Member not found")
    return target


def _build_access_entries(
    db: Session, household_id: uuid.UUID, member_id: uuid.UUID
) -> list[ConnectionAccessEntry]:
    connections = (
        db.query(PluggyConnection)
        .filter(PluggyConnection.household_id == household_id)
        .order_by(PluggyConnection.created_at)
        .all()
    )
    granted_ids = {
        row[0]
        for row in db.query(ConnectionAccessGrant.pluggy_connection_id)
        .filter(ConnectionAccessGrant.household_member_id == member_id)
        .all()
    }
    return [
        ConnectionAccessEntry(
            connection_id=c.id,
            pluggy_item_id=c.pluggy_item_id,
            status=c.status,
            granted=c.id in granted_ids,
        )
        for c in connections
    ]


@router.get("/{member_id}/access", response_model=list[ConnectionAccessEntry])
def get_member_access(
    household_id: uuid.UUID,
    member_id: uuid.UUID,
    membership: HouseholdMember = Depends(require_role("owner")),
    db: Session = Depends(get_db),
):
    _get_target_member_or_404(db, household_id, member_id)
    return _build_access_entries(db, household_id, member_id)


@router.put("/{member_id}/access", response_model=list[ConnectionAccessEntry])
def update_member_access(
    household_id: uuid.UUID,
    member_id: uuid.UUID,
    payload: MemberAccessUpdate,
    membership: HouseholdMember = Depends(require_role("owner")),
    db: Session = Depends(get_db),
):
    _get_target_member_or_404(db, household_id, member_id)

    valid_connection_ids = {
        row[0]
        for row in db.query(PluggyConnection.id)
        .filter(
            PluggyConnection.household_id == household_id,
            PluggyConnection.id.in_(payload.connection_ids),
        )
        .all()
    }

    db.query(ConnectionAccessGrant).filter(
        ConnectionAccessGrant.household_member_id == member_id
    ).delete(synchronize_session=False)
    for connection_id in valid_connection_ids:
        db.add(
            ConnectionAccessGrant(
                household_member_id=member_id, pluggy_connection_id=connection_id
            )
        )
    record_audit_event(
        db,
        household_id=household_id,
        actor_app_user_id=membership.app_user_id,
        action="member.access_updated",
        target_type="household_member",
        target_id=member_id,
        metadata={"granted_connection_ids": [str(cid) for cid in valid_connection_ids]},
    )
    db.commit()

    return _build_access_entries(db, household_id, member_id)
