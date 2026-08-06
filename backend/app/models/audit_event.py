import uuid

from sqlalchemy import ForeignKey, String, func
from sqlalchemy.dialects.postgresql import JSONB, TIMESTAMP, UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.database.session import Base


class AuditEvent(Base):
    """Records who did what to a household's sensitive data — invites,
    connection access grants, bank connections. Written by
    `app/services/audit.py`, read via `GET /v1/households/{id}/audit-events`
    (owner-only). `target_id` is a loose UUID (not a FK) since it points at
    different tables depending on `target_type`.
    """

    __tablename__ = "audit_events"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    household_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("households.id"), nullable=False
    )
    actor_app_user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("app_users.id"), nullable=False
    )
    action: Mapped[str] = mapped_column(String, nullable=False)
    target_type: Mapped[str | None] = mapped_column(String, nullable=True)
    target_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), nullable=True)
    metadata_json: Mapped[dict | None] = mapped_column(JSONB, nullable=True)
    created_at: Mapped[TIMESTAMP] = mapped_column(
        TIMESTAMP(timezone=True), nullable=False, server_default=func.now()
    )
