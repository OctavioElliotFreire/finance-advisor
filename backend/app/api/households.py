import uuid

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.auth.dependencies import get_current_app_user, get_household_membership
from app.database.session import get_db
from app.models.app_user import AppUser
from app.models.household import Household, HouseholdMember
from app.schemas.household import (
    HouseholdCreate,
    HouseholdResponse,
    HouseholdWithRoleResponse,
)

router = APIRouter(prefix="/v1/households", tags=["households"])


@router.post("", response_model=HouseholdResponse, status_code=201)
def create_household(
    payload: HouseholdCreate,
    current_user: AppUser = Depends(get_current_app_user),
    db: Session = Depends(get_db),
):
    household = Household(name=payload.name)
    db.add(household)
    db.flush()

    membership = HouseholdMember(
        household_id=household.id,
        app_user_id=current_user.id,
        role="owner",
    )
    db.add(membership)
    db.commit()
    db.refresh(household)
    return household


@router.get("", response_model=list[HouseholdWithRoleResponse])
def list_my_households(
    current_user: AppUser = Depends(get_current_app_user),
    db: Session = Depends(get_db),
):
    rows = (
        db.query(Household, HouseholdMember.role)
        .join(HouseholdMember, HouseholdMember.household_id == Household.id)
        .filter(HouseholdMember.app_user_id == current_user.id)
        .all()
    )
    return [
        HouseholdWithRoleResponse(
            id=household.id,
            name=household.name,
            created_at=household.created_at,
            role=role,
        )
        for household, role in rows
    ]


@router.get("/{household_id}", response_model=HouseholdWithRoleResponse)
def get_household(
    household_id: uuid.UUID,
    membership: HouseholdMember = Depends(get_household_membership),
    db: Session = Depends(get_db),
):
    household = db.get(Household, household_id)
    return HouseholdWithRoleResponse(
        id=household.id,
        name=household.name,
        created_at=household.created_at,
        role=membership.role,
    )
