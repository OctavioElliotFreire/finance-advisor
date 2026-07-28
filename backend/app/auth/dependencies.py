import uuid

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.orm import Session

from app.auth.supabase import verify_supabase_token
from app.database.session import get_db
from app.models.app_user import AppUser
from app.models.household import HouseholdMember

bearer_scheme = HTTPBearer()


def get_current_app_user(
    credentials: HTTPAuthorizationCredentials = Depends(bearer_scheme),
    db: Session = Depends(get_db),
) -> AppUser:
    claims = verify_supabase_token(credentials.credentials)
    provider_user_id = claims["sub"]
    email = claims.get("email", "")

    user = (
        db.query(AppUser)
        .filter(
            AppUser.auth_provider == "supabase",
            AppUser.auth_provider_user_id == provider_user_id,
        )
        .one_or_none()
    )
    if user is None:
        user = AppUser(
            auth_provider="supabase",
            auth_provider_user_id=provider_user_id,
            email=email,
        )
        db.add(user)
        db.commit()
        db.refresh(user)
    elif email and user.email != email:
        user.email = email
        db.commit()
        db.refresh(user)

    return user


def get_household_membership(
    household_id: uuid.UUID,
    current_user: AppUser = Depends(get_current_app_user),
    db: Session = Depends(get_db),
) -> HouseholdMember:
    membership = (
        db.query(HouseholdMember)
        .filter(
            HouseholdMember.household_id == household_id,
            HouseholdMember.app_user_id == current_user.id,
        )
        .one_or_none()
    )
    if membership is None:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not a member of this household",
        )
    return membership


def require_role(*allowed_roles: str):
    def _check(membership: HouseholdMember = Depends(get_household_membership)) -> HouseholdMember:
        if membership.role not in allowed_roles:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Requires role in {allowed_roles}, has '{membership.role}'",
            )
        return membership

    return _check
