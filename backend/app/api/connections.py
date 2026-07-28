import uuid

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.auth.dependencies import get_current_app_user, get_household_membership, require_role
from app.database.session import get_db
from app.models.app_user import AppUser
from app.models.household import HouseholdMember
from app.models.pluggy_connection import PluggyConnection, SyncJob
from app.schemas.connection import ConnectionCreate, ConnectionResponse, ConnectTokenResponse
from app.settings import settings
from app.sync.pluggy_client import PluggyClient

router = APIRouter(
    prefix="/v1/households/{household_id}/connections", tags=["connections"]
)


def _pluggy_client() -> PluggyClient:
    return PluggyClient(settings.pluggy_client_id, settings.pluggy_client_secret)


@router.post("/token", response_model=ConnectTokenResponse)
async def create_connect_token(
    household_id: uuid.UUID,
    current_user: AppUser = Depends(get_current_app_user),
    membership: HouseholdMember = Depends(require_role("owner", "member")),
):
    client = _pluggy_client()
    await client.authenticate()
    token = await client.create_connect_token(client_user_id=str(current_user.id))
    return ConnectTokenResponse(connect_token=token)


@router.post("", response_model=ConnectionResponse, status_code=201)
async def create_connection(
    household_id: uuid.UUID,
    payload: ConnectionCreate,
    membership: HouseholdMember = Depends(require_role("owner", "member")),
    db: Session = Depends(get_db),
):
    client = _pluggy_client()
    await client.authenticate()
    try:
        item = await client.get_item(payload.pluggy_item_id)
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Could not verify this Pluggy item.",
        )

    connection = PluggyConnection(
        household_id=household_id,
        pluggy_item_id=payload.pluggy_item_id,
        status=item.get("status", "pending"),
    )
    db.add(connection)
    try:
        db.flush()
    except IntegrityError:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="This connection is already registered for this household.",
        )

    sync_job = SyncJob(
        household_id=household_id,
        pluggy_connection_id=connection.id,
        status="queued",
    )
    db.add(sync_job)
    db.commit()
    db.refresh(connection)
    return connection


@router.get("", response_model=list[ConnectionResponse])
def list_connections(
    household_id: uuid.UUID,
    membership: HouseholdMember = Depends(get_household_membership),
    db: Session = Depends(get_db),
):
    return (
        db.query(PluggyConnection)
        .filter(PluggyConnection.household_id == household_id)
        .all()
    )
