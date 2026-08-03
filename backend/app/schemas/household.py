import uuid
from datetime import datetime
from typing import Literal

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


class MemberInvite(BaseModel):
    email: str
    role: Literal["member", "viewer"] = "member"


class HouseholdMemberResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    app_user_id: uuid.UUID
    email: str
    role: str
    created_at: datetime
