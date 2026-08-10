import uuid
from dataclasses import dataclass

from fastapi import Depends
from sqlalchemy.orm import Session

from app.auth.dependencies import get_household_membership
from app.database.session import get_db
from app.models.connection_access_grant import ConnectionAccessGrant
from app.models.household import HouseholdMember
from app.models.pluggy_connection import PluggyConnection


def resolve_member_ids(
    db: Session,
    household_id: uuid.UUID,
    connection_ids: set[uuid.UUID] | None,
    member_ids: list[uuid.UUID] | None,
) -> set[uuid.UUID] | None:
    """Narrows `connection_ids` (the viewer's own visibility scope) to only
    connections created by one of `member_ids` — the voluntary "show me just
    these members' data" filter from the Global Scope member chips. Distinct
    from `get_accessible_connection_ids`, which is about what the viewer is
    *allowed* to see, not what they currently *want* to see.

    `member_ids` `None` or empty means "all members" — returns `connection_ids`
    unchanged. Otherwise resolves member_ids -> app_user_ids -> connections
    `created_by_app_user_id` in that set, intersected with `connection_ids`
    (an empty intersection is a valid "show nothing" result, not an error).
    """
    if not member_ids:
        return connection_ids

    app_user_ids = {
        row[0]
        for row in db.query(HouseholdMember.app_user_id)
        .filter(
            HouseholdMember.household_id == household_id,
            HouseholdMember.id.in_(member_ids),
        )
        .all()
    }
    member_connection_ids = {
        row[0]
        for row in db.query(PluggyConnection.id)
        .filter(
            PluggyConnection.household_id == household_id,
            PluggyConnection.created_by_app_user_id.in_(app_user_ids),
        )
        .all()
    }
    if connection_ids is None:
        return member_connection_ids
    return connection_ids & member_connection_ids


def get_accessible_connection_ids(
    db: Session, membership: HouseholdMember
) -> set[uuid.UUID] | None:
    """Returns the set of connection ids this member may see, or `None` for
    "unrestricted" — either an owner, or a member granted every connection in
    the household (not actually restricted, so anything that can't be
    attributed to one connection — e.g. the category-deviation anomaly rule,
    the household-wide latest sync job — is visible to them same as an owner).
    """
    if membership.role == "owner":
        return None

    all_connection_ids = {
        row[0]
        for row in db.query(PluggyConnection.id)
        .filter(PluggyConnection.household_id == membership.household_id)
        .all()
    }
    granted_ids = {
        row[0]
        for row in db.query(ConnectionAccessGrant.pluggy_connection_id)
        .filter(ConnectionAccessGrant.household_member_id == membership.id)
        .all()
    }
    if granted_ids >= all_connection_ids:
        return None
    return granted_ids


@dataclass
class AccessScope:
    membership: HouseholdMember
    connection_ids: set[uuid.UUID] | None


def get_access_scope(
    membership: HouseholdMember = Depends(get_household_membership),
    db: Session = Depends(get_db),
) -> AccessScope:
    return AccessScope(
        membership=membership,
        connection_ids=get_accessible_connection_ids(db, membership),
    )
