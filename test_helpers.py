from datetime import datetime, timedelta

import pytest

import db
from db import init_schema, upsert_member, upsert_item, upsert_accounts, upsert_transactions, upsert_investments
from helpers import shift_month, get_balance_evolution, get_current_month, get_total_investments_value

MEMBER_ID = "dad"
ITEM_ID = "item-001"
BANK_ACCOUNT_ID = "acc-bank-001"


@pytest.fixture(autouse=True)
def fresh_db(tmp_path):
    db_file = str(tmp_path / "test.db")
    db.DB_PATH = db_file
    init_schema()


def _setup_bank_account():
    upsert_member(MEMBER_ID, "Dad")
    upsert_item({"id": ITEM_ID, "status": "UPDATED", "connector": {"id": 0, "name": "Pluggy Bank"}}, MEMBER_ID)
    upsert_accounts(
        [{"id": BANK_ACCOUNT_ID, "name": "Conta", "type": "BANK", "subtype": None,
          "balance": 1000.0, "currencyCode": "BRL", "owner": None, "number": None, "creditData": None}],
        ITEM_ID, MEMBER_ID,
    )


def _txn(id_, amount, txn_type, days_ago):
    d = (datetime.now() - timedelta(days=days_ago)).strftime("%Y-%m-%d")
    return {"id": id_, "description": "x", "descriptionRaw": None, "amount": amount,
            "amountInAccountCurrency": amount, "currencyCode": "BRL", "date": d,
            "type": txn_type, "operationType": None, "category": None, "categoryId": None,
            "status": None, "balance": None, "providerCode": None, "providerId": None,
            "merchant": None, "paymentData": None, "creditCardMetadata": None}


# --- shift_month ---

def test_shift_month_forward():
    print(shift_month("2026-07", 1))
    assert shift_month("2026-07", 1) == "2026-08"


def test_shift_month_backward():
    print(shift_month("2026-07", -1))
    assert shift_month("2026-07", -1) == "2026-06"


def test_shift_month_crosses_year_boundary():
    print(shift_month("2026-01", -1), shift_month("2026-12", 1))
    assert shift_month("2026-01", -1) == "2025-12"
    assert shift_month("2026-12", 1) == "2027-01"


# --- get_balance_evolution ---

def test_balance_evolution_no_bank_accounts_returns_current_month_only():
    upsert_member(MEMBER_ID, "Dad")
    result = get_balance_evolution(MEMBER_ID)
    print(f"result: {result}")
    assert result == [{"month": get_current_month(), "balance": 0.0}]


def test_balance_evolution_no_transactions_returns_current_balance_only():
    _setup_bank_account()
    result = get_balance_evolution(MEMBER_ID)
    print(f"result: {result}")
    assert result == [{"month": get_current_month(), "balance": 1000.0}]


def test_balance_evolution_reconstructs_prior_month_balance():
    _setup_bank_account()
    # current balance is 1000.0; a +200 CREDIT happened 5 days ago (this month),
    # so last month's end-of-month balance should be 1000 - 200 = 800.
    # A second, older txn (~40 days ago) establishes 2-month coverage so the
    # algorithm doesn't stop at the current month for lack of earlier data.
    upsert_transactions(
        [_txn("t1", 200.0, "CREDIT", 5), _txn("t2", -10.0, "DEBIT", 40)],
        BANK_ACCOUNT_ID, MEMBER_ID,
    )
    result = get_balance_evolution(MEMBER_ID, months=3)
    print(f"result: {result}")
    by_month = {r["month"]: r["balance"] for r in result}
    current_month = get_current_month()
    assert by_month[current_month] == 1000.0
    prior_month = shift_month(current_month, -1)
    assert by_month[prior_month] == 800.0


def test_balance_evolution_stops_at_oldest_transaction_month():
    _setup_bank_account()
    upsert_transactions([_txn("t1", -50.0, "DEBIT", 20)], BANK_ACCOUNT_ID, MEMBER_ID)
    result = get_balance_evolution(MEMBER_ID, months=24)
    months = [r["month"] for r in result]
    print(f"months returned: {months}")
    # only 24 months were requested but data is thin -- must not fabricate
    # months before the oldest transaction's month
    oldest_txn_month = (datetime.now() - timedelta(days=20)).strftime("%Y-%m")
    assert min(months) == oldest_txn_month


def test_get_total_investments_value_sums_balance_not_value():
    # `value` is a per-unit/rate figure (e.g. quota price); `balance` is the
    # investment's true total current position value -- confirmed against
    # real synced Pluggy data where these differ substantially.
    upsert_member(MEMBER_ID, "Dad")
    upsert_item({"id": ITEM_ID, "status": "UPDATED", "connector": {"id": 0, "name": "Pluggy Bank"}}, MEMBER_ID)
    investments = [{"id": "inv-1", "name": "Fund", "type": "MUTUAL_FUND", "subtype": None,
                    "rawType": None, "code": None, "isinCode": None, "value": 3.6,
                    "quantity": None, "balance": 950.0, "taxes": None, "taxes2": None,
                    "currencyCode": "BRL", "date": None, "dueDate": None, "annualRate": None,
                    "lastMonthRate": None, "lastTwelveMonthsRate": None, "issuer": None,
                    "issuerCnpj": None, "status": "ACTIVE", "number": None}]
    upsert_investments(investments, ITEM_ID, MEMBER_ID)
    result = get_total_investments_value(MEMBER_ID)
    print(f"result: {result}")
    assert result == 950.0


def test_balance_evolution_all_members_sums_balances():
    _setup_bank_account()
    upsert_member("mom", "Mom")
    upsert_item({"id": "item-mom", "status": "UPDATED", "connector": {"id": 1, "name": "Other Bank"}}, "mom")
    upsert_accounts(
        [{"id": "acc-mom", "name": "Conta Mom", "type": "BANK", "subtype": None,
          "balance": 500.0, "currencyCode": "BRL", "owner": None, "number": None, "creditData": None}],
        "item-mom", "mom",
    )
    result = get_balance_evolution(None)
    print(f"result: {result}")
    assert result == [{"month": get_current_month(), "balance": 1500.0}]
