import uuid
from datetime import datetime

from pydantic import BaseModel


class FailedSyncJobSummary(BaseModel):
    id: uuid.UUID
    pluggy_connection_id: uuid.UUID
    pluggy_item_id: str
    updated_at: datetime


class FailureEventSummary(BaseModel):
    id: uuid.UUID
    action: str
    target_type: str | None
    target_id: uuid.UUID | None
    metadata_json: dict | None
    created_at: datetime


class HouseholdAlertsResponse(BaseModel):
    failed_sync_jobs: list[FailedSyncJobSummary]
    failure_events: list[FailureEventSummary]
