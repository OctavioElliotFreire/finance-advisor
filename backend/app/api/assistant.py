import json
import uuid
from datetime import timedelta

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.auth.access_scope import AccessScope, get_access_scope
from app.auth.dependencies import get_current_app_user, get_household_membership
from app.database.session import get_db
from app.llm.base import ASSISTANT_SYSTEM_PROMPT, LLMProvider, get_provider
from app.models.app_user import AppUser
from app.models.assistant import AssistantMessage
from app.models.household import HouseholdMember
from app.schemas.assistant import AssistantMessageResponse, AssistantQuestionRequest
from app.services.household_context import build_household_context
from app.services.rate_limiting import check_and_record_rate_limit

router = APIRouter(
    prefix="/v1/households/{household_id}/assistant", tags=["assistant"]
)

HISTORY_LIMIT = 50
RATE_LIMIT_MAX_QUESTIONS = 20
RATE_LIMIT_WINDOW = timedelta(hours=1)


def get_assistant_provider() -> LLMProvider:
    return get_provider()


def _to_response(message: AssistantMessage, email: str) -> AssistantMessageResponse:
    return AssistantMessageResponse(
        id=message.id,
        question=message.question,
        answer=message.answer,
        asked_by_email=email,
        created_at=message.created_at,
    )


@router.get("", response_model=list[AssistantMessageResponse])
def list_assistant_messages(
    household_id: uuid.UUID,
    membership: HouseholdMember = Depends(get_household_membership),
    db: Session = Depends(get_db),
):
    rows = (
        db.query(AssistantMessage, AppUser.email)
        .join(AppUser, AppUser.id == AssistantMessage.asked_by_app_user_id)
        .filter(AssistantMessage.household_id == household_id)
        .order_by(AssistantMessage.created_at)
        .limit(HISTORY_LIMIT)
        .all()
    )
    return [_to_response(message, email) for message, email in rows]


@router.post("/ask", response_model=AssistantMessageResponse)
def ask_assistant(
    household_id: uuid.UUID,
    payload: AssistantQuestionRequest,
    scope: AccessScope = Depends(get_access_scope),
    current_user: AppUser = Depends(get_current_app_user),
    db: Session = Depends(get_db),
    provider: LLMProvider = Depends(get_assistant_provider),
):
    check_and_record_rate_limit(
        db,
        scope=f"assistant_ask:{household_id}",
        max_calls=RATE_LIMIT_MAX_QUESTIONS,
        window=RATE_LIMIT_WINDOW,
        error_detail=(
            f"This household has reached the limit of "
            f"{RATE_LIMIT_MAX_QUESTIONS} questions per hour. Please try again later."
        ),
    )

    context = build_household_context(db, household_id, scope.connection_ids)
    user_message = f"Household context:\n{json.dumps(context)}\n\nQuestion: {payload.question}"

    try:
        answer = provider.answer_question(ASSISTANT_SYSTEM_PROMPT, user_message)
    except Exception as exc:  # noqa: BLE001 - never leak raw SDK/provider errors
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="The assistant is temporarily unavailable. Please try again shortly.",
        ) from exc

    message = AssistantMessage(
        household_id=household_id,
        asked_by_app_user_id=current_user.id,
        question=payload.question,
        answer=answer,
    )
    db.add(message)
    db.commit()
    db.refresh(message)
    return _to_response(message, current_user.email)
