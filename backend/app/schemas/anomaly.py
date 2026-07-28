import uuid
from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict


class AnomalySummary(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    transaction_id: uuid.UUID | None
    rule: str
    severity: str
    score: float | None
    summary: str
    status: str
    explanation: str | None
    explained_at: datetime | None
    created_at: datetime


class AnomalyStatusUpdate(BaseModel):
    status: Literal["open", "confirmed", "dismissed"]
