import uuid
from datetime import date

from pydantic import BaseModel, ConfigDict


class CreditCardBillSummary(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    account_id: uuid.UUID
    due_date: date | None
    closing_date: date | None
    total_amount: float | None
    minimum_payment: float | None
    currency_code: str


class InvestmentSummary(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    name: str | None
    type: str | None
    subtype: str | None
    balance: float | None
    value: float | None
    quantity: float | None
    currency_code: str
    investment_date: date | None


class LoanSummary(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    type: str | None
    status: str | None
    contract_amount: float | None
    outstanding_balance: float | None
    installment_amount: float | None
    installments_total: int | None
    installments_paid: int | None
    due_date: date | None
    interest_rate: float | None
    currency_code: str


class BalancePoint(BaseModel):
    snapshot_date: date
    total_balance: float


class CategoryBreakdownItem(BaseModel):
    category: str | None
    total: float
    previous_total: float | None = None


class MemberSpendItem(BaseModel):
    month: str
    member_id: uuid.UUID | None
    total: float
