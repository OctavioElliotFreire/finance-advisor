import uuid
from dataclasses import dataclass

from fastapi import Depends
from sqlalchemy.orm import Session

from app.auth.dependencies import get_household_membership
from app.database.session import get_db
from app.models.connection_access_grant import ConnectionAccessGrant
from app.models.household import HouseholdMember
from app.models.pluggy_connection import PluggyConnection


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
