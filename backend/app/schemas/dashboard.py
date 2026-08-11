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
    credit_limit: float | None = None
    available_credit_limit: float | None = None
    connection_status: str | None = None
    owner_member_id: uuid.UUID | None = None
    number: str | None = None


class TransactionSplitItem(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    category: str
    amount: float
    description: str | None = None


class TransactionSplitsUpdate(BaseModel):
    splits: list[TransactionSplitItem]


class TransactionCategoryUpdate(BaseModel):
    category: str | None


class TransactionSummary(BaseModel):
    id: uuid.UUID
    account_id: uuid.UUID
    account_name: str | None
    description: str | None
    amount: float
    currency_code: str
    transaction_date: date
    category: str | None
    is_flagged: bool = False
    is_transfer: bool = False
    flag_id: uuid.UUID | None = None
    splits: list[TransactionSplitItem] = []


class MonthlyCashFlow(BaseModel):
    month: str
    income: float
    expenses: float
    net: float


class SyncStatus(BaseModel):
    status: str | None
    updated_at: datetime | None
    synced_connections: int = 0
    total_connections: int = 0


class DashboardResponse(BaseModel):
    household_name: str
    accounts: list[AccountSummary]
    total_balance: float
    recent_transactions: list[TransactionSummary]
    monthly_cash_flow: list[MonthlyCashFlow]
    sync_status: SyncStatus
