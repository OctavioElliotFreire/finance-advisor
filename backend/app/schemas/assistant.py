import uuid
from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field

QUESTION_MAX_LENGTH = 500


class AssistantQuestionRequest(BaseModel):
    question: str = Field(min_length=1, max_length=QUESTION_MAX_LENGTH)


class AssistantMessageResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    question: str
    answer: str
    asked_by_email: str
    created_at: datetime
