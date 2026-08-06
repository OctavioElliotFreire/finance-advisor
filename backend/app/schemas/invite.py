import uuid
from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict

from app.schemas.household import HouseholdMemberResponse


class InviteSummary(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    email: str
    role: str
    expires_at: datetime
    accepted_at: datetime | None
    created_at: datetime


class InviteResult(BaseModel):
    outcome: Literal["added", "invited"]
    member: HouseholdMemberResponse | None = None
    invite: InviteSummary | None = None


class InvitePreview(BaseModel):
    household_name: str
    email: str
    role: str
    expired: bool
    accepted: bool


class AcceptInviteResponse(BaseModel):
    household_id: uuid.UUID
    household_name: str
