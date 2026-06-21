import pytest

import db
from db import (
    init_schema, upsert_member, upsert_item, upsert_accounts,
    upsert_transactions, upsert_investments,
)
from helpers import (
    get_monthly_spend, get_total_bank_balance, get_total_investments_value,
    get_credit_available, get_member_summary, get_family_summary,
)

FAKE_ITEM = {
    "id": "item-1", "status": "UPDATED",
    "connector": {"id": 0, "name": "Sandbox"},
}

BANK_ACCOUNT = {
    "id": "acc-bank", "name": "Checking", "type": "BANK",
    "subtype": "CHECKING_ACCOUNT", "number": "0001",
    "balance": 1000.0, "currencyCode": "BRL", "owner": "Dad",
    "creditData": {},
}

CREDIT_ACCOUNT = {
    "id": "acc-credit", "name": "Visa", "type": "CREDIT",
    "subtype": "CREDIT_CARD", "number": "0002",
    "balance": 0.0, "currencyCode": "BRL", "owner": "Dad",
    "creditData": {
        "creditLimit": 5000.0, "availableCreditLimit": 3500.0,
        "balanceCloseDate": None, "balanceDueDate": None,
        "minimumTotalAmountDue": None, "brand": "VISA",
    },
}

DEBIT_TXN = {
    "id": "txn-debit-1", "description": "Supermarket", "descriptionRaw": "SUPER",
    "amount": 200.0, "amountInAccountCurrency": 200.0,
    "currencyCode": "BRL", "date": "2026-06-15T00:00:00.000Z",
    "type": "DEBIT", "operationType": None, "category": "Food",
    "categoryId": None, "status": "POSTED", "balance": 800.0,
    "providerCode": None, "providerId": None,
    "merchant": {"name": "Market", "cnpj": None},
    "paymentData": None, "creditCardMetadata": None,
}

CREDIT_TXN = {
    "id": "txn-credit-1", "description": "Salary", "descriptionRaw": "SALARY",
    "amount": 5000.0, "amountInAccountCurrency": 5000.0,
    "currencyCode": "BRL", "date": "2026-06-01T00:00:00.000Z",
    "type": "CREDIT", "operationType": None, "category": "Income",
    "categoryId": None, "status": "POSTED", "balance": 5000.0,
    "providerCode": None, "providerId": None,
    "merchant": None, "paymentData": None, "creditCardMetadata": None,
}

INVESTMENT = {
    "id": "inv-1", "name": "Tesouro Direto", "type": "FIXED_INCOME",
    "subtype": "TREASURY", "rawType": "TD", "code": "TD001",
    "isinCode": None, "value": 3000.0, "quantity": 1.0, "balance": 3000.0,
    "taxes": 0.0, "taxes2": 0.0, "currencyCode": "BRL",
    "date": "2026-06-01", "dueDate": "2027-01-01",
    "annualRate": 0.13, "lastMonthRate": None, "lastTwelveMonthsRate": None,
    "issuer": "Tesouro Nacional", "issuerCnpj": None, "status": "ACTIVE",
    "number": None,
}


@pytest.fixture(autouse=True)
def fresh_db(tmp_path):
    db.DB_PATH = str(tmp_path / "test.db")
    init_schema()


@pytest.fixture()
def seeded_member():
    upsert_member("dad", "Dad")
    upsert_item(FAKE_ITEM, "dad")
    upsert_accounts([BANK_ACCOUNT, CREDIT_ACCOUNT], "item-1", "dad")
    upsert_transactions([DEBIT_TXN, CREDIT_TXN], "acc-bank", "dad")
    upsert_investments([INVESTMENT], "item-1", "dad")


# --- get_total_bank_balance ---

def test_bank_balance_empty():
    upsert_member("dad", "Dad")
    assert get_total_bank_balance("dad") == 0.0


def test_bank_balance_sums_bank_accounts(seeded_member):
    assert get_total_bank_balance("dad") == 1000.0


def test_bank_balance_excludes_credit(seeded_member):
    assert get_total_bank_balance("dad") == 1000.0  # credit balance excluded


# --- get_monthly_spend ---

def test_monthly_spend_empty():
    upsert_member("dad", "Dad")
    assert get_monthly_spend("dad", "2026-06") == 0.0


def test_monthly_spend_only_debits(seeded_member):
    spend = get_monthly_spend("dad", "2026-06")
    assert spend == 200.0


def test_monthly_spend_excludes_credits(seeded_member):
    spend = get_monthly_spend("dad", "2026-06")
    assert spend == 200.0  # 5000 credit txn not counted


def test_monthly_spend_different_month(seeded_member):
    spend = get_monthly_spend("dad", "2025-01")
    assert spend == 0.0


# --- get_total_investments_value ---

def test_investments_empty():
    upsert_member("dad", "Dad")
    assert get_total_investments_value("dad") == 0.0


def test_investments_value(seeded_member):
    assert get_total_investments_value("dad") == 3000.0


def test_investments_excludes_total_withdrawal(seeded_member):
    withdrawn = {**INVESTMENT, "id": "inv-withdrawn", "status": "TOTAL_WITHDRAWAL"}
    upsert_investments([withdrawn], "item-1", "dad")
    assert get_total_investments_value("dad") == 3000.0  # only ACTIVE counted


# --- get_credit_available ---

def test_credit_available_empty():
    upsert_member("dad", "Dad")
    assert get_credit_available("dad") == 0.0


def test_credit_available(seeded_member):
    assert get_credit_available("dad") == 3500.0


# --- get_member_summary ---

def test_member_summary_shape(seeded_member):
    s = get_member_summary("dad", "2026-06")
    assert "bank_balance" in s
    assert "monthly_spend" in s
    assert "investments_value" in s
    assert "credit_available" in s


def test_member_summary_values(seeded_member):
    s = get_member_summary("dad", "2026-06")
    assert s["bank_balance"] == 1000.0
    assert s["monthly_spend"] == 200.0
    assert s["investments_value"] == 3000.0
    assert s["credit_available"] == 3500.0


# --- get_family_summary ---

def test_family_summary_empty():
    result = get_family_summary("2026-06")
    assert result["total_bank_balance"] == 0.0
    assert result["per_member"] == []


def test_family_summary_aggregates(seeded_member):
    result = get_family_summary("2026-06")
    assert result["total_bank_balance"] == 1000.0
    assert result["total_monthly_spend"] == 200.0
    assert result["total_investments_value"] == 3000.0
    assert len(result["per_member"]) == 1
    assert result["per_member"][0]["name"] == "Dad"


def test_family_summary_multiple_members(seeded_member, tmp_path):
    upsert_member("mom", "Mom")
    upsert_item({**FAKE_ITEM, "id": "item-2"}, "mom")
    mom_bank = {**BANK_ACCOUNT, "id": "acc-mom-bank", "balance": 500.0}
    upsert_accounts([mom_bank], "item-2", "mom")

    result = get_family_summary("2026-06")
    assert result["total_bank_balance"] == 1500.0
    assert len(result["per_member"]) == 2
