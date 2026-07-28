import uuid
from datetime import datetime

from pydantic import BaseModel, ConfigDict


class HouseholdCreate(BaseModel):
    name: str


class HouseholdResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    name: str
    created_at: datetime


class HouseholdWithRoleResponse(HouseholdResponse):
    role: str
