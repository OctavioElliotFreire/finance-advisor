import uuid

from sqlalchemy import Date, ForeignKey, Integer, Numeric, String, UniqueConstraint, func
from sqlalchemy.dialects.postgresql import JSONB, TIMESTAMP, UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.database.session import Base


class CreditCardBill(Base):
    __tablename__ = "credit_card_bills"
    __table_args__ = (
        UniqueConstraint(
            "household_id", "pluggy_bill_id", name="uq_credit_card_bills_identity"
        ),
    )

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    household_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("households.id"), nullable=False
    )
    account_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("accounts.id"), nullable=False
    )
    pluggy_bill_id: Mapped[str] = mapped_column(String, nullable=False)
    due_date: Mapped[Date | None] = mapped_column(Date, nullable=True)
    closing_date: Mapped[Date | None] = mapped_column(Date, nullable=True)
    total_amount: Mapped[float | None] = mapped_column(Numeric(18, 2), nullable=True)
    minimum_payment: Mapped[float | None] = mapped_column(Numeric(18, 2), nullable=True)
    currency_code: Mapped[str] = mapped_column(String(3), nullable=False, default="BRL")
    raw_json: Mapped[dict | None] = mapped_column(JSONB, nullable=True)
    created_at: Mapped[TIMESTAMP] = mapped_column(
        TIMESTAMP(timezone=True), nullable=False, server_default=func.now()
    )
    updated_at: Mapped[TIMESTAMP] = mapped_column(
        TIMESTAMP(timezone=True),
        nullable=False,
        server_default=func.now(),
        onupdate=func.now(),
    )


class Investment(Base):
    __tablename__ = "investments"
    __table_args__ = (
        UniqueConstraint(
            "household_id", "pluggy_investment_id", name="uq_investments_identity"
        ),
    )

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    household_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("households.id"), nullable=False
    )
    pluggy_connection_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("pluggy_connections.id"), nullable=False
    )
    pluggy_investment_id: Mapped[str] = mapped_column(String, nullable=False)
    name: Mapped[str | None] = mapped_column(String, nullable=True)
    type: Mapped[str | None] = mapped_column(String, nullable=True)
    subtype: Mapped[str | None] = mapped_column(String, nullable=True)
    balance: Mapped[float | None] = mapped_column(Numeric(18, 2), nullable=True)
    value: Mapped[float | None] = mapped_column(Numeric(18, 2), nullable=True)
    quantity: Mapped[float | None] = mapped_column(Numeric(18, 6), nullable=True)
    currency_code: Mapped[str] = mapped_column(String(3), nullable=False, default="BRL")
    investment_date: Mapped[Date | None] = mapped_column(Date, nullable=True)
    raw_json: Mapped[dict | None] = mapped_column(JSONB, nullable=True)
    created_at: Mapped[TIMESTAMP] = mapped_column(
        TIMESTAMP(timezone=True), nullable=False, server_default=func.now()
    )
    updated_at: Mapped[TIMESTAMP] = mapped_column(
        TIMESTAMP(timezone=True),
        nullable=False,
        server_default=func.now(),
        onupdate=func.now(),
    )


class Loan(Base):
    __tablename__ = "loans"
    __table_args__ = (
        UniqueConstraint("household_id", "pluggy_loan_id", name="uq_loans_identity"),
    )

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    household_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("households.id"), nullable=False
    )
    pluggy_connection_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("pluggy_connections.id"), nullable=False
    )
    pluggy_loan_id: Mapped[str] = mapped_column(String, nullable=False)
    type: Mapped[str | None] = mapped_column(String, nullable=True)
    status: Mapped[str | None] = mapped_column(String, nullable=True)
    contract_amount: Mapped[float | None] = mapped_column(Numeric(18, 2), nullable=True)
    outstanding_balance: Mapped[float | None] = mapped_column(
        Numeric(18, 2), nullable=True
    )
    installment_amount: Mapped[float | None] = mapped_column(
        Numeric(18, 2), nullable=True
    )
    installments_total: Mapped[int | None] = mapped_column(Integer, nullable=True)
    installments_paid: Mapped[int | None] = mapped_column(Integer, nullable=True)
    due_date: Mapped[Date | None] = mapped_column(Date, nullable=True)
    interest_rate: Mapped[float | None] = mapped_column(Numeric(9, 4), nullable=True)
    currency_code: Mapped[str] = mapped_column(String(3), nullable=False, default="BRL")
    raw_json: Mapped[dict | None] = mapped_column(JSONB, nullable=True)
    created_at: Mapped[TIMESTAMP] = mapped_column(
        TIMESTAMP(timezone=True), nullable=False, server_default=func.now()
    )
    updated_at: Mapped[TIMESTAMP] = mapped_column(
        TIMESTAMP(timezone=True),
        nullable=False,
        server_default=func.now(),
        onupdate=func.now(),
    )


class BalanceSnapshot(Base):
    __tablename__ = "balance_snapshots"
    __table_args__ = (
        UniqueConstraint(
            "account_id", "snapshot_date", name="uq_balance_snapshots_identity"
        ),
    )

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    household_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("households.id"), nullable=False
    )
    account_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("accounts.id"), nullable=False
    )
    balance: Mapped[float | None] = mapped_column(Numeric(18, 2), nullable=True)
    currency_code: Mapped[str] = mapped_column(String(3), nullable=False, default="BRL")
    snapshot_date: Mapped[Date] = mapped_column(Date, nullable=False)
    created_at: Mapped[TIMESTAMP] = mapped_column(
        TIMESTAMP(timezone=True), nullable=False, server_default=func.now()
    )
