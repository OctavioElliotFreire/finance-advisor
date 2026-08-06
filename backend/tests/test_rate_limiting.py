import uuid
from datetime import datetime, timedelta, timezone

import pytest
from fastapi import HTTPException

from app.database.session import SessionLocal
from app.models.rate_limit_hit import RateLimitHit
from app.services.rate_limiting import check_and_record_rate_limit


@pytest.fixture
def db():
    session = SessionLocal()
    yield session
    session.query(RateLimitHit).filter(RateLimitHit.scope.like("test_scope:%")).delete(
        synchronize_session=False
    )
    session.commit()
    session.close()


def _scope():
    return f"test_scope:{uuid.uuid4()}"


def test_allows_calls_under_the_limit(db):
    scope = _scope()
    for _ in range(3):
        check_and_record_rate_limit(db, scope, max_calls=3, window=timedelta(hours=1), error_detail="blocked")

    count = db.query(RateLimitHit).filter(RateLimitHit.scope == scope).count()
    assert count == 3


def test_blocks_the_call_that_exceeds_the_limit(db):
    scope = _scope()
    for _ in range(3):
        check_and_record_rate_limit(db, scope, max_calls=3, window=timedelta(hours=1), error_detail="blocked")

    with pytest.raises(HTTPException) as exc_info:
        check_and_record_rate_limit(db, scope, max_calls=3, window=timedelta(hours=1), error_detail="blocked")

    assert exc_info.value.status_code == 429
    assert exc_info.value.detail == "blocked"
    # The blocked call must not consume a slot.
    count = db.query(RateLimitHit).filter(RateLimitHit.scope == scope).count()
    assert count == 3


def test_hits_outside_the_window_do_not_count(db):
    scope = _scope()
    db.add(
        RateLimitHit(scope=scope, created_at=datetime.now(timezone.utc) - timedelta(days=2))
    )
    db.commit()

    # The only existing hit is 2 days old, outside a 1-hour window, so it
    # doesn't count against the limit.
    check_and_record_rate_limit(db, scope, max_calls=1, window=timedelta(hours=1), error_detail="blocked")

    count = db.query(RateLimitHit).filter(RateLimitHit.scope == scope).count()
    assert count == 2


def test_different_scopes_do_not_interfere(db):
    scope_a, scope_b = _scope(), _scope()
    check_and_record_rate_limit(db, scope_a, max_calls=1, window=timedelta(hours=1), error_detail="blocked")

    # scope_b has its own independent budget.
    check_and_record_rate_limit(db, scope_b, max_calls=1, window=timedelta(hours=1), error_detail="blocked")

    with pytest.raises(HTTPException):
        check_and_record_rate_limit(db, scope_a, max_calls=1, window=timedelta(hours=1), error_detail="blocked")
