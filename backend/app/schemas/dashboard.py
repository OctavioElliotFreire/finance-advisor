import uuid
from datetime import date, datetime

from pydantic import BaseModel, ConfigDict


class AccountSummary(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    name: str | None
    type: str | None
    subtype: str | None
    balance: float | None
    currency_code: str


class TransactionSummary(BaseModel):
    id: uuid.UUID
    account_name: str | None
    description: str | None
    amount: float
    currency_code: str
    transaction_date: date
    category: str | None


class MonthlyCashFlow(BaseModel):
    month: str
    income: float
    expenses: float
    net: float


class SyncStatus(BaseModel):
    status: str | None
    updated_at: datetime | None


class DashboardResponse(BaseModel):
    accounts: list[AccountSummary]
    total_balance: float
    recent_transactions: list[TransactionSummary]
    monthly_cash_flow: list[MonthlyCashFlow]
    sync_status: SyncStatus
