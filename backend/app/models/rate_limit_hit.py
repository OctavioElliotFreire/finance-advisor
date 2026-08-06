import uuid

from sqlalchemy import String, func
from sqlalchemy.dialects.postgresql import TIMESTAMP, UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.database.session import Base


class RateLimitHit(Base):
    """One row per rate-limited call, counted against a sliding window keyed
    by an arbitrary `scope` string (see `app/services/rate_limiting.py`).
    Postgres-backed rather than in-process so limits hold across server
    restarts and multiple worker processes.
    """

    __tablename__ = "rate_limit_hits"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    scope: Mapped[str] = mapped_column(String, nullable=False, index=True)
    created_at: Mapped[TIMESTAMP] = mapped_column(
        TIMESTAMP(timezone=True), nullable=False, server_default=func.now()
    )
