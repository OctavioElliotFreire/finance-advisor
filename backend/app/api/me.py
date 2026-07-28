from fastapi import APIRouter, Depends

from app.auth.dependencies import get_current_app_user
from app.models.app_user import AppUser
from app.schemas.user import MeResponse

router = APIRouter()


@router.get("/v1/me", response_model=MeResponse)
def read_me(current_user: AppUser = Depends(get_current_app_user)):
    return current_user
