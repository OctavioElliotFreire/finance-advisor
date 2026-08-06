from datetime import datetime, timedelta, timezone

from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.models.rate_limit_hit import RateLimitHit


def check_and_record_rate_limit(
    db: Session,
    scope: str,
    max_calls: int,
    window: timedelta,
    error_detail: str,
) -> None:
    """Raises 429 if `scope` has already hit `max_calls` within `window`,
    otherwise records this call and lets it through. Recording happens
    before the caller's actual work runs, so a slot is consumed even if
    that work later fails — repeatedly retrying a failing call is exactly
    the kind of cost/abuse this guards against.
    """
    window_start = datetime.now(timezone.utc) - window
    recent_count = (
        db.query(RateLimitHit)
        .filter(RateLimitHit.scope == scope, RateLimitHit.created_at >= window_start)
        .count()
    )
    if recent_count >= max_calls:
        raise HTTPException(status_code=status.HTTP_429_TOO_MANY_REQUESTS, detail=error_detail)

    db.add(RateLimitHit(scope=scope))
    db.commit()
