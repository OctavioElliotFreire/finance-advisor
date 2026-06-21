import json
import os
import tempfile
import pytest

import db
from db import (
    init_schema,
    upsert_member,
    upsert_item,
    upsert_accounts,
    upsert_transactions,
    upsert_investments,
    upsert_identity,
    upsert_credit_card_bills,
    upsert_loans,
    save_llm_analysis,
    get_all_members,
    get_accounts_for_member,
    get_transactions_for_member,
    get_investments_for_member,
    get_loans_for_member,
    get_identity_for_member,
    get_last_sync_time,
    get_latest_analysis,
)

MEMBER_ID = "dad"
ITEM_ID = "item-001"
ACCOUNT_ID = "acc-001"
CREDIT_ACCOUNT_ID = "acc-002"


@pytest.fixture(autouse=True)
def fresh_db(tmp_path):
    db_file = str(tmp_path / "test.db")
    db.DB_PATH = db_file
    init_schema()


# --- Schema ---

def test_schema_creates_all_tables():
    from db import get_connection
    with get_connection() as conn:
        tables = {r[0] for r in conn.execute(
            "SELECT name FROM sqlite_master WHERE type='table'"
        )}
    expected = {"members", "items", "accounts", "transactions", "investments",
                "identity", "credit_card_bills", "loans", "llm_analyses"}
    assert expected.issubset(tables)


# --- Members ---

def test_upsert_member():
    upsert_member(MEMBER_ID, "Dad")
    members = get_all_members()
    assert len(members) == 1
    assert members[0]["name"] == "Dad"


def test_upsert_member_replace():
    upsert_member(MEMBER_ID, "Dad")
    upsert_member(MEMBER_ID, "Papa")
    members = get_all_members()
    assert len(members) == 1
    assert members[0]["name"] == "Papa"


# --- Items ---

def test_upsert_item():
    upsert_member(MEMBER_ID, "Dad")
    item = {"id": ITEM_ID, "status": "UPDATED", "connector": {"id": 0, "name": "Pluggy Bank"}}
    upsert_item(item, MEMBER_ID)
    sync_time = get_last_sync_time(MEMBER_ID)
    assert sync_time is not None


# --- Accounts ---

def _setup_member_and_item():
    upsert_member(MEMBER_ID, "Dad")
    upsert_item({"id": ITEM_ID, "status": "UPDATED", "connector": {"id": 0, "name": "Pluggy Bank"}}, MEMBER_ID)


def test_upsert_bank_account():
    _setup_member_and_item()
    accounts = [{"id": ACCOUNT_ID, "name": "Conta Corrente", "type": "BANK",
                 "subtype": "CHECKING_ACCOUNT", "balance": 1000.0, "currencyCode": "BRL",
                 "owner": "John", "number": "12345", "creditData": None}]
    upsert_accounts(accounts, ITEM_ID, MEMBER_ID)
    result = get_accounts_for_member(MEMBER_ID)
    assert len(result) == 1
    assert result[0]["name"] == "Conta Corrente"
    assert result[0]["balance"] == 1000.0
    assert result[0]["type"] == "BANK"


def test_upsert_credit_account():
    _setup_member_and_item()
    accounts = [{"id": CREDIT_ACCOUNT_ID, "name": "Mastercard", "type": "CREDIT",
                 "subtype": "CREDIT_CARD", "balance": -200.0, "currencyCode": "BRL",
                 "owner": "John", "number": None,
                 "creditData": {"creditLimit": 5000, "availableCreditLimit": 4800,
                                "balanceCloseDate": "2026-07-01", "balanceDueDate": "2026-07-10",
                                "minimumTotalAmountDue": 50, "brand": "MASTERCARD"}}]
    upsert_accounts(accounts, ITEM_ID, MEMBER_ID)
    result = get_accounts_for_member(MEMBER_ID)
    assert result[0]["credit_limit"] == 5000
    assert result[0]["available_credit"] == 4800
    assert result[0]["brand"] == "MASTERCARD"


def test_account_raw_json_stored():
    _setup_member_and_item()
    acc = {"id": ACCOUNT_ID, "name": "Test", "type": "BANK", "subtype": None,
           "balance": 0, "currencyCode": "BRL", "owner": None, "number": None, "creditData": None}
    upsert_accounts([acc], ITEM_ID, MEMBER_ID)
    result = get_accounts_for_member(MEMBER_ID)
    raw = json.loads(result[0]["raw_json"])
    assert raw["id"] == ACCOUNT_ID


# --- Transactions ---

def _setup_with_account():
    _setup_member_and_item()
    upsert_accounts(
        [{"id": ACCOUNT_ID, "name": "Conta", "type": "BANK", "subtype": None,
          "balance": 0, "currencyCode": "BRL", "owner": None, "number": None, "creditData": None}],
        ITEM_ID, MEMBER_ID,
    )


def test_upsert_transactions():
    _setup_with_account()
    txns = [
        {"id": "t1", "description": "Supermercado", "descriptionRaw": "SUPERMERCADO SA",
         "amount": -50.0, "amountInAccountCurrency": -50.0, "currencyCode": "BRL",
         "date": "2026-06-01", "type": "DEBIT", "operationType": None,
         "category": "Food", "categoryId": "cat-1", "status": "POSTED",
         "balance": 950.0, "providerCode": None, "providerId": None,
         "merchant": {"name": "Mercado", "cnpj": "123"},
         "paymentData": None, "creditCardMetadata": None},
    ]
    upsert_transactions(txns, ACCOUNT_ID, MEMBER_ID)
    result = get_transactions_for_member(MEMBER_ID, days=90)
    assert len(result) == 1
    assert result[0]["description"] == "Supermercado"
    assert result[0]["merchant_name"] == "Mercado"


def test_transactions_date_filter():
    _setup_with_account()
    txns = [
        {"id": "t-old", "description": "Old", "descriptionRaw": None, "amount": -10,
         "amountInAccountCurrency": -10, "currencyCode": "BRL", "date": "2020-01-01",
         "type": "DEBIT", "operationType": None, "category": None, "categoryId": None,
         "status": None, "balance": None, "providerCode": None, "providerId": None,
         "merchant": None, "paymentData": None, "creditCardMetadata": None},
        {"id": "t-new", "description": "New", "descriptionRaw": None, "amount": -20,
         "amountInAccountCurrency": -20, "currencyCode": "BRL", "date": "2026-06-15",
         "type": "DEBIT", "operationType": None, "category": None, "categoryId": None,
         "status": None, "balance": None, "providerCode": None, "providerId": None,
         "merchant": None, "paymentData": None, "creditCardMetadata": None},
    ]
    upsert_transactions(txns, ACCOUNT_ID, MEMBER_ID)
    result = get_transactions_for_member(MEMBER_ID, days=30)
    ids = [r["id"] for r in result]
    assert "t-new" in ids
    assert "t-old" not in ids


# --- Investments ---

def test_upsert_investments():
    _setup_member_and_item()
    investments = [
        {"id": "inv-1", "name": "FCI Premium", "type": "MUTUAL_FUND", "subtype": None,
         "rawType": None, "code": None, "isinCode": None, "value": 1000.0,
         "quantity": None, "balance": None, "taxes": None, "taxes2": None,
         "currencyCode": "BRL", "date": None, "dueDate": None, "annualRate": None,
         "lastMonthRate": None, "lastTwelveMonthsRate": None, "issuer": None,
         "issuerCnpj": None, "status": "ACTIVE", "number": None},
    ]
    upsert_investments(investments, ITEM_ID, MEMBER_ID)
    result = get_investments_for_member(MEMBER_ID)
    assert len(result) == 1
    assert result[0]["name"] == "FCI Premium"
    assert result[0]["value"] == 1000.0


# --- Identity ---

def test_upsert_identity():
    _setup_member_and_item()
    identity = {"id": "id-001", "fullName": "John Doe", "cpfNumber": "123.456.789-00",
                "birthDate": "1980-01-01", "phoneNumbers": ["+55 11 99999-9999"],
                "emails": ["john@example.com"], "addresses": []}
    upsert_identity(identity, ITEM_ID, MEMBER_ID)
    result = get_identity_for_member(MEMBER_ID)
    assert result is not None
    assert result["full_name"] == "John Doe"
    assert result["cpf_number"] == "123.456.789-00"


# --- Credit Card Bills ---

def test_upsert_credit_card_bills():
    _setup_member_and_item()
    upsert_accounts(
        [{"id": CREDIT_ACCOUNT_ID, "name": "Card", "type": "CREDIT", "subtype": None,
          "balance": 0, "currencyCode": "BRL", "owner": None, "number": None, "creditData": None}],
        ITEM_ID, MEMBER_ID,
    )
    bills = [{"id": "bill-1", "dueDate": "2026-07-10", "closingDate": "2026-07-01",
              "balance": 500.0, "previousBalance": 400.0, "paymentAmount": 400.0,
              "minimumPayment": 50.0, "currencyCode": "BRL"}]
    upsert_credit_card_bills(bills, CREDIT_ACCOUNT_ID, MEMBER_ID)
    from db import get_connection
    with get_connection() as conn:
        rows = conn.execute("SELECT * FROM credit_card_bills WHERE member_id = ?", (MEMBER_ID,)).fetchall()
    assert len(rows) == 1
    assert rows[0]["balance"] == 500.0


# --- Loans ---

def test_upsert_loans():
    _setup_member_and_item()
    loans = [{"id": "loan-1", "number": "L001", "type": "PERSONAL_CREDIT",
              "status": "ACTIVE", "contractedAmount": 10000.0, "outstandingBalance": 8000.0,
              "installmentAmount": 500.0, "totalInstallments": 24, "paidInstallments": 4,
              "creditDate": "2025-01-01", "dueDate": "2027-01-01",
              "interestRate": 0.015, "currencyCode": "BRL"}]
    upsert_loans(loans, ITEM_ID, MEMBER_ID)
    result = get_loans_for_member(MEMBER_ID)
    assert len(result) == 1
    assert result[0]["contract_amount"] == 10000.0
    assert result[0]["outstanding_balance"] == 8000.0


# --- LLM Analyses ---

def test_save_and_retrieve_llm_analysis():
    upsert_member(MEMBER_ID, "Dad")
    response = {"flagged": [{"transaction_id": "t1", "reason": "Unexpected fee"}]}
    save_llm_analysis(MEMBER_ID, 30, "anthropic", "claude-haiku-4-5-20251001", response, 1)
    result = get_latest_analysis(MEMBER_ID)
    assert result is not None
    assert result["flagged_count"] == 1
    assert result["provider"] == "anthropic"
    parsed = json.loads(result["response_json"])
    assert parsed["flagged"][0]["transaction_id"] == "t1"


def test_latest_analysis_returns_most_recent():
    upsert_member(MEMBER_ID, "Dad")
    save_llm_analysis(MEMBER_ID, 30, "anthropic", "model-a", {"flagged": []}, 0)
    save_llm_analysis(MEMBER_ID, 30, "anthropic", "model-b", {"flagged": [{"transaction_id": "x", "reason": "fee"}]}, 1)
    result = get_latest_analysis(MEMBER_ID)
    assert result["model"] == "model-b"
