import uuid
from datetime import timedelta

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session, joinedload

from app.auth.access_scope import AccessScope, get_access_scope
from app.auth.dependencies import get_current_app_user, require_role
from app.database.session import get_db
from app.models.app_user import AppUser
from app.models.household import HouseholdMember
from app.models.pluggy_connection import PluggyConnection, SyncJob
from app.schemas.connection import ConnectionCreate, ConnectionResponse, ConnectTokenResponse
from app.services.audit import record_audit_event
from app.services.rate_limiting import check_and_record_rate_limit
from app.settings import settings
from app.sync.pluggy_client import PluggyClient

router = APIRouter(
    prefix="/v1/households/{household_id}/connections", tags=["connections"]
)

RATE_LIMIT_MAX_CALLS = 10
RATE_LIMIT_WINDOW = timedelta(hours=1)


def _pluggy_client() -> PluggyClient:
    return PluggyClient(settings.pluggy_client_id, settings.pluggy_client_secret)


@router.post("/token", response_model=ConnectTokenResponse)
async def create_connect_token(
    household_id: uuid.UUID,
    current_user: AppUser = Depends(get_current_app_user),
    membership: HouseholdMember = Depends(require_role("owner", "member")),
    db: Session = Depends(get_db),
):
    check_and_record_rate_limit(
        db,
        scope=f"connections_token:{household_id}",
        max_calls=RATE_LIMIT_MAX_CALLS,
        window=RATE_LIMIT_WINDOW,
        error_detail="Too many connection attempts for this household. Please try again later.",
    )

    client = _pluggy_client()
    await client.authenticate()
    token = await client.create_connect_token(client_user_id=str(current_user.id))
    return ConnectTokenResponse(connect_token=token)


@router.post("", response_model=ConnectionResponse, status_code=201)
async def create_connection(
    household_id: uuid.UUID,
    payload: ConnectionCreate,
    current_user: AppUser = Depends(get_current_app_user),
    membership: HouseholdMember = Depends(require_role("owner", "member")),
    db: Session = Depends(get_db),
):
    check_and_record_rate_limit(
        db,
        scope=f"connections_create:{household_id}",
        max_calls=RATE_LIMIT_MAX_CALLS,
        window=RATE_LIMIT_WINDOW,
        error_detail="Too many connection attempts for this household. Please try again later.",
    )

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
        created_by_app_user_id=current_user.id,
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
    record_audit_event(
        db,
        household_id=household_id,
        actor_app_user_id=current_user.id,
        action="connection.created",
        target_type="pluggy_connection",
        target_id=connection.id,
        metadata={"pluggy_item_id": payload.pluggy_item_id},
    )
    db.commit()
    db.refresh(connection)
    return connection


@router.get("", response_model=list[ConnectionResponse])
def list_connections(
    household_id: uuid.UUID,
    scope: AccessScope = Depends(get_access_scope),
    db: Session = Depends(get_db),
):
    query = (
        db.query(PluggyConnection)
        .options(joinedload(PluggyConnection.created_by))
        .filter(PluggyConnection.household_id == household_id)
    )
    if scope.connection_ids is not None:
        query = query.filter(PluggyConnection.id.in_(scope.connection_ids))
    return query.all()
