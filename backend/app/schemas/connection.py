import uuid
from datetime import datetime
from typing import Optional

from pydantic import BaseModel, ConfigDict


class ConnectTokenResponse(BaseModel):
    connect_token: str


class ConnectionCreate(BaseModel):
    pluggy_item_id: str


class ConnectionCreatorResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    email: str


class ConnectionResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    pluggy_item_id: str
    status: str
    created_at: datetime
    created_by: Optional[ConnectionCreatorResponse] = None
