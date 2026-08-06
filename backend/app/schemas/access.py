import uuid

from pydantic import BaseModel


class ConnectionAccessEntry(BaseModel):
    connection_id: uuid.UUID
    pluggy_item_id: str
    status: str
    granted: bool


class MemberAccessUpdate(BaseModel):
    connection_ids: list[uuid.UUID]
