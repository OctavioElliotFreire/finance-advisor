from components.analytics import (
    group_accounts_by_institution,
    credit_utilization,
    group_investments_by_type,
    group_investments_by_institution,
    group_expenses_by_category,
    upcoming_expenses,
    filter_by_institution,
    connection_status_bucket,
)

ITEMS = [
    {"item_id": "item-1", "connector_name": "Bank A"},
    {"item_id": "item-2", "connector_name": "Bank B"},
]


# --- group_accounts_by_institution ---

def test_group_accounts_by_institution_sums_and_percentages():
    accounts = [
        {"item_id": "item-1", "balance": 600.0},
        {"item_id": "item-1", "balance": 400.0},
        {"item_id": "item-2", "balance": 1000.0},
    ]
    result = group_accounts_by_institution(accounts, ITEMS)
    print(f"result: {result}")
    by_name = {r["name"]: r for r in result}
    assert by_name["Bank A"]["balance"] == 1000.0
    assert by_name["Bank A"]["account_count"] == 2
    assert by_name["Bank A"]["pct_of_total"] == 50.0
    assert by_name["Bank B"]["pct_of_total"] == 50.0


def test_group_accounts_by_institution_unknown_item():
    accounts = [{"item_id": "missing-item", "balance": 100.0}]
    result = group_accounts_by_institution(accounts, ITEMS)
    print(f"result: {result}")
    assert result[0]["name"] == "Unknown Institution"


def test_group_accounts_by_institution_empty_list_no_div_by_zero():
    result = group_accounts_by_institution([], ITEMS)
    print(f"result: {result}")
    assert result == []


# --- credit_utilization ---

def test_credit_utilization_computes_outstanding_and_pct():
    accounts = [
        {"credit_limit": 5000.0, "available_credit": 4000.0},
        {"credit_limit": 3000.0, "available_credit": 1000.0},
    ]
    result = credit_utilization(accounts)
    print(f"result: {result}")
    assert result["total_limit"] == 8000.0
    assert result["total_balance_outstanding"] == 3000.0
    assert result["utilization_pct"] == 37.5


def test_credit_utilization_no_accounts_no_div_by_zero():
    result = credit_utilization([])
    print(f"result: {result}")
    assert result == {"total_balance_outstanding": 0.0, "total_limit": 0.0, "utilization_pct": 0.0}


# --- group_investments_by_type ---

def test_group_investments_by_type_excludes_total_withdrawal():
    investments = [
        {"type": "FIXED_INCOME", "balance": 600.0, "status": "ACTIVE"},
        {"type": "FIXED_INCOME", "balance": 400.0, "status": "ACTIVE"},
        {"type": "EQUITY", "balance": 1000.0, "status": "TOTAL_WITHDRAWAL"},
    ]
    result = group_investments_by_type(investments)
    print(f"result: {result}")
    assert len(result) == 1
    assert result[0]["type"] == "FIXED_INCOME"
    assert result[0]["value"] == 1000.0
    assert result[0]["pct_of_total"] == 100.0


def test_group_investments_by_type_uses_balance_not_value():
    # `value` is a per-unit/rate figure, not the position's worth -- must not be summed
    investments = [{"type": "FIXED_INCOME", "value": 3.6, "balance": 950.0, "status": "ACTIVE"}]
    result = group_investments_by_type(investments)
    print(f"result: {result}")
    assert result[0]["value"] == 950.0


def test_group_investments_by_type_missing_type_falls_back_to_other():
    investments = [{"type": None, "balance": 100.0, "status": "ACTIVE"}]
    result = group_investments_by_type(investments)
    print(f"result: {result}")
    assert result[0]["type"] == "Other"


# --- group_investments_by_institution ---

def test_group_investments_by_institution():
    investments = [
        {"item_id": "item-1", "balance": 300.0, "status": "ACTIVE"},
        {"item_id": "item-2", "balance": 700.0, "status": "ACTIVE"},
    ]
    result = group_investments_by_institution(investments, ITEMS)
    print(f"result: {result}")
    by_name = {r["name"]: r for r in result}
    assert by_name["Bank A"]["value"] == 300.0
    assert by_name["Bank B"]["value"] == 700.0
    assert by_name["Bank B"]["pct_of_total"] == 70.0


# --- group_expenses_by_category ---

def test_group_expenses_by_category_only_debits_and_sorted_desc():
    transactions = [
        {"type": "DEBIT", "category": "Food", "amount": -50.0},
        {"type": "DEBIT", "category": "Food", "amount": -30.0},
        {"type": "DEBIT", "category": "Transport", "amount": -200.0},
        {"type": "CREDIT", "category": "Income", "amount": 8000.0},
    ]
    result = group_expenses_by_category(transactions)
    print(f"result: {result}")
    assert result[0] == {"category": "Transport", "total": 200.0}
    assert result[1] == {"category": "Food", "total": 80.0}
    assert len(result) == 2


def test_group_expenses_by_category_missing_category_uncategorized():
    transactions = [{"type": "DEBIT", "category": None, "amount": -10.0}]
    result = group_expenses_by_category(transactions)
    print(f"result: {result}")
    assert result[0]["category"] == "Uncategorized"


# --- upcoming_expenses ---

def test_upcoming_expenses_future_bill_included_past_excluded():
    bills = [
        {"due_date": "2099-01-01", "balance": 500.0},
        {"due_date": "2000-01-01", "balance": 999.0},
    ]
    result = upcoming_expenses(bills, [])
    print(f"result: {result}")
    assert len(result) == 1
    assert result[0]["amount"] == 500.0
    assert result[0]["source"] == "credit_card_bill"


def test_upcoming_expenses_includes_pending_transactions():
    transactions = [
        {"status": "PENDING", "description": "Amazon", "amount": -80.0, "date": "2099-02-01"},
        {"status": "POSTED", "description": "Settled", "amount": -20.0, "date": "2099-02-01"},
    ]
    result = upcoming_expenses([], transactions)
    print(f"result: {result}")
    assert len(result) == 1
    assert result[0]["description"] == "Amazon"
    assert result[0]["amount"] == 80.0
    assert result[0]["source"] == "pending_transaction"


def test_upcoming_expenses_sorted_by_due_date():
    bills = [{"due_date": "2099-05-01", "balance": 100.0}]
    transactions = [{"status": "PENDING", "description": "Early", "amount": -10.0, "date": "2099-01-01"}]
    result = upcoming_expenses(bills, transactions)
    print(f"result: {result}")
    assert result[0]["description"] == "Early"
    assert result[1]["source"] == "credit_card_bill"


def test_upcoming_expenses_empty_when_nothing_pending():
    result = upcoming_expenses([], [])
    print(f"result: {result}")
    assert result == []


# --- filter_by_institution ---

def test_filter_by_institution_empty_selection_returns_all():
    rows = [{"item_id": "item-1"}, {"item_id": "item-2"}]
    result = filter_by_institution(rows, ITEMS, [])
    print(f"result: {result}")
    assert result == rows


def test_filter_by_institution_narrows_to_selected():
    rows = [{"item_id": "item-1"}, {"item_id": "item-2"}]
    result = filter_by_institution(rows, ITEMS, ["Bank A"])
    print(f"result: {result}")
    assert result == [{"item_id": "item-1"}]


def test_filter_by_institution_unknown_institution_matches_missing_connector():
    rows = [{"item_id": "item-x"}]
    items = [{"item_id": "item-x", "connector_name": None}]
    result = filter_by_institution(rows, items, ["Unknown Institution"])
    print(f"result: {result}")
    assert result == rows


# --- connection_status_bucket ---

def test_connection_status_bucket_known_statuses():
    print(connection_status_bucket("UPDATED"), connection_status_bucket("LOGIN_ERROR"), connection_status_bucket("UPDATING"))
    assert connection_status_bucket("UPDATED") == "Connected"
    assert connection_status_bucket("LOGIN_ERROR") == "Needs Attention"
    assert connection_status_bucket("OUTDATED") == "Needs Attention"
    assert connection_status_bucket("WAITING_USER_INPUT") == "Needs Attention"
    assert connection_status_bucket("UPDATING") == "Synchronizing"


def test_connection_status_bucket_unknown_falls_back_to_disconnected():
    print(connection_status_bucket("SOMETHING_NEW"), connection_status_bucket(None))
    assert connection_status_bucket("SOMETHING_NEW") == "Disconnected"
    assert connection_status_bucket(None) == "Disconnected"
