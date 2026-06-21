"""
Tests for data layer used by pages/02_member.py.
Covers accounts/transactions/investments/loans query correctness.
"""
import pytest

import db
from db import (
    init_schema, upsert_member, upsert_item, upsert_accounts,
    upsert_transactions, upsert_investments, upsert_loans,
    get_accounts_for_member, get_transactions_for_member,
    get_investments_for_member, get_loans_for_member,
    get_identity_for_member,
)

ITEM = {"id": "item-1", "status": "UPDATED", "connector": {"id": 0, "name": "Sandbox"}}

BANK = {
    "id": "acc-bank", "name": "Checking", "type": "BANK", "subtype": "CHECKING_ACCOUNT",
    "number": "001", "balance": 2500.0, "currencyCode": "BRL", "owner": "Dad",
    "creditData": {},
}
CREDIT = {
    "id": "acc-credit", "name": "Visa", "type": "CREDIT", "subtype": "CREDIT_CARD",
    "number": "002", "balance": 0.0, "currencyCode": "BRL", "owner": "Dad",
    "creditData": {"creditLimit": 10000.0, "availableCreditLimit": 7000.0,
                   "balanceCloseDate": None, "balanceDueDate": None,
                   "minimumTotalAmountDue": None, "brand": "VISA"},
}

TXN_DEBIT = {
    "id": "t1", "description": "Market", "descriptionRaw": "MKT",
    "amount": 150.0, "amountInAccountCurrency": 150.0, "currencyCode": "BRL",
    "date": "2026-06-10T00:00:00.000Z", "type": "DEBIT", "operationType": None,
    "category": "Food", "categoryId": None, "status": "POSTED", "balance": None,
    "providerCode": None, "providerId": None,
    "merchant": {"name": "Supermarket", "cnpj": None},
    "paymentData": None, "creditCardMetadata": None,
}
TXN_CREDIT = {
    "id": "t2", "description": "Salary", "descriptionRaw": "SAL",
    "amount": 8000.0, "amountInAccountCurrency": 8000.0, "currencyCode": "BRL",
    "date": "2026-06-01T00:00:00.000Z", "type": "CREDIT", "operationType": None,
    "category": "Income", "categoryId": None, "status": "POSTED", "balance": None,
    "providerCode": None, "providerId": None,
    "merchant": None, "paymentData": None, "creditCardMetadata": None,
}
TXN_OLD = {
    "id": "t3", "description": "Old payment", "descriptionRaw": "OLD",
    "amount": 50.0, "amountInAccountCurrency": 50.0, "currencyCode": "BRL",
    "date": "2020-01-15T00:00:00.000Z", "type": "DEBIT", "operationType": None,
    "category": "Other", "categoryId": None, "status": "POSTED", "balance": None,
    "providerCode": None, "providerId": None,
    "merchant": None, "paymentData": None, "creditCardMetadata": None,
}

INV_ACTIVE = {
    "id": "inv-1", "name": "Tesouro", "type": "FIXED_INCOME", "subtype": "TREASURY",
    "rawType": "TD", "code": None, "isinCode": None, "value": 5000.0, "quantity": 1.0,
    "balance": 5000.0, "taxes": 0.0, "taxes2": 0.0, "currencyCode": "BRL",
    "date": "2026-01-01", "dueDate": "2027-01-01", "annualRate": 0.13,
    "lastMonthRate": None, "lastTwelveMonthsRate": None,
    "issuer": "Tesouro Nacional", "issuerCnpj": None, "status": "ACTIVE", "number": None,
}
INV_WITHDRAWN = {**INV_ACTIVE, "id": "inv-2", "name": "Old Fund", "status": "TOTAL_WITHDRAWAL", "value": 1000.0}

LOAN_ACTIVE = {
    "id": "loan-1", "number": "L001", "type": "PERSONAL_CREDIT", "status": "ACTIVE",
    "contractedAmount": 20000.0, "outstandingBalance": 15000.0, "installmentAmount": 500.0,
    "totalInstallments": 48, "paidInstallments": 10, "creditDate": "2025-01-01",
    "dueDate": "2029-01-01", "interestRate": 0.019, "currencyCode": "BRL",
}
LOAN_SETTLED = {**LOAN_ACTIVE, "id": "loan-2", "status": "SETTLED"}


@pytest.fixture(autouse=True)
def fresh_db(tmp_path):
    db.DB_PATH = str(tmp_path / "test.db")
    init_schema()


@pytest.fixture()
def dad():
    upsert_member("dad", "Dad")
    upsert_item(ITEM, "dad")
    upsert_accounts([BANK, CREDIT], "item-1", "dad")
    upsert_transactions([TXN_DEBIT, TXN_CREDIT, TXN_OLD], "acc-bank", "dad")
    upsert_investments([INV_ACTIVE, INV_WITHDRAWN], "item-1", "dad")
    upsert_loans([LOAN_ACTIVE, LOAN_SETTLED], "item-1", "dad")


# --- accounts ---

def test_get_accounts_returns_both_types(dad):
    accounts = get_accounts_for_member("dad")
    types = {a["type"] for a in accounts}
    assert "BANK" in types
    assert "CREDIT" in types


def test_get_accounts_bank_balance(dad):
    bank = next(a for a in get_accounts_for_member("dad") if a["type"] == "BANK")
    assert bank["balance"] == 2500.0


def test_get_accounts_credit_fields(dad):
    credit = next(a for a in get_accounts_for_member("dad") if a["type"] == "CREDIT")
    assert credit["credit_limit"] == 10000.0
    assert credit["available_credit"] == 7000.0


def test_get_accounts_empty_member():
    upsert_member("nobody", "Nobody")
    assert get_accounts_for_member("nobody") == []


# --- transactions ---

def test_get_transactions_last_30_days(dad):
    txns = get_transactions_for_member("dad", days=30)
    ids = {t["id"] for t in txns}
    assert "t1" in ids
    assert "t2" in ids
    assert "t3" not in ids  # 2020 txn excluded


def test_get_transactions_all_time(dad):
    txns = get_transactions_for_member("dad", days=3650)
    ids = {t["id"] for t in txns}
    assert "t3" in ids


def test_get_transactions_ordered_desc(dad):
    txns = get_transactions_for_member("dad", days=3650)
    dates = [t["date"][:10] for t in txns]
    assert dates == sorted(dates, reverse=True)


def test_get_transactions_has_merchant(dad):
    txns = get_transactions_for_member("dad", days=30)
    debit = next(t for t in txns if t["id"] == "t1")
    assert debit["merchant_name"] == "Supermarket"


def test_get_transactions_empty_member():
    upsert_member("nobody", "Nobody")
    assert get_transactions_for_member("nobody") == []


# --- investments ---

def test_get_investments_returns_all(dad):
    investments = get_investments_for_member("dad")
    assert len(investments) == 2


def test_get_investments_active_filter_in_page(dad):
    investments = get_investments_for_member("dad")
    active = [i for i in investments if i["status"] != "TOTAL_WITHDRAWAL"]
    assert len(active) == 1
    assert active[0]["name"] == "Tesouro"


def test_get_investments_value(dad):
    investments = get_investments_for_member("dad")
    active = [i for i in investments if i["status"] == "ACTIVE"]
    assert active[0]["value"] == 5000.0


def test_get_investments_empty_member():
    upsert_member("nobody", "Nobody")
    assert get_investments_for_member("nobody") == []


# --- loans ---

def test_get_loans_returns_all(dad):
    loans = get_loans_for_member("dad")
    assert len(loans) == 2


def test_get_loans_active_filter(dad):
    loans = get_loans_for_member("dad")
    active = [l for l in loans if l["status"] not in ("SETTLED", "CANCELLED")]
    assert len(active) == 1
    assert active[0]["outstanding_balance"] == 15000.0


def test_get_loans_empty_member():
    upsert_member("nobody", "Nobody")
    assert get_loans_for_member("nobody") == []


# --- identity ---

def test_get_identity_none_when_missing():
    upsert_member("dad", "Dad")
    assert get_identity_for_member("dad") is None
