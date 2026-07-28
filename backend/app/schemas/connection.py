import uuid
from datetime import datetime

from pydantic import BaseModel, ConfigDict


class ConnectTokenResponse(BaseModel):
    connect_token: str


class ConnectionCreate(BaseModel):
    pluggy_item_id: str


class ConnectionResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    pluggy_item_id: str
    status: str
    created_at: datetime
