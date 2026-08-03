import uuid
from typing import Optional

from sqlalchemy import ForeignKey, String, UniqueConstraint, func
from sqlalchemy.dialects.postgresql import TIMESTAMP, UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database.session import Base


class PluggyConnection(Base):
    __tablename__ = "pluggy_connections"
    __table_args__ = (
        UniqueConstraint(
            "household_id", "pluggy_item_id", name="uq_pluggy_connections_identity"
        ),
    )

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    household_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("households.id"), nullable=False
    )
    pluggy_item_id: Mapped[str] = mapped_column(String, nullable=False)
    status: Mapped[str] = mapped_column(String, nullable=False, default="pending")
    created_by_app_user_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        UUID(as_uuid=True), ForeignKey("app_users.id"), nullable=True
    )
    created_by: Mapped[Optional["AppUser"]] = relationship("AppUser")
    created_at: Mapped[TIMESTAMP] = mapped_column(
        TIMESTAMP(timezone=True), nullable=False, server_default=func.now()
    )
    updated_at: Mapped[TIMESTAMP] = mapped_column(
        TIMESTAMP(timezone=True),
        nullable=False,
        server_default=func.now(),
        onupdate=func.now(),
    )


class SyncJob(Base):
    __tablename__ = "sync_jobs"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    household_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("households.id"), nullable=False
    )
    pluggy_connection_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("pluggy_connections.id"), nullable=False
    )
    status: Mapped[str] = mapped_column(String, nullable=False, default="queued")
    created_at: Mapped[TIMESTAMP] = mapped_column(
        TIMESTAMP(timezone=True), nullable=False, server_default=func.now()
    )
    updated_at: Mapped[TIMESTAMP] = mapped_column(
        TIMESTAMP(timezone=True),
        nullable=False,
        server_default=func.now(),
        onupdate=func.now(),
    )
