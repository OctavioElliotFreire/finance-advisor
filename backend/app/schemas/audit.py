import uuid
from datetime import datetime

from pydantic import BaseModel, ConfigDict


class AuditEventResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    actor_email: str
    action: str
    target_type: str | None
    target_id: uuid.UUID | None
    metadata_json: dict | None
    created_at: datetime
