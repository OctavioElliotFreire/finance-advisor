import uuid
from datetime import date, timedelta

import pytest

from app.database.session import SessionLocal
from app.models.account import Account
from app.models.anomaly import AnomalyFlag
from app.models.app_user import AppUser
from app.models.household import Household, HouseholdMember
from app.models.pluggy_connection import PluggyConnection
from app.models.transaction import Transaction
from app.services import anomaly_rules

TODAY = date(2026, 7, 27)


@pytest.fixture
def db():
    session = SessionLocal()
    yield session
    session.close()


@pytest.fixture
def household_and_account(db):
    household = Household(name="Anomaly Test Family")
    db.add(household)
    db.flush()
    connection = PluggyConnection(
        household_id=household.id, pluggy_item_id=f"item-{uuid.uuid4()}", status="pending"
    )
    db.add(connection)
    db.flush()
    account = Account(
        household_id=household.id,
        pluggy_connection_id=connection.id,
        pluggy_account_id=f"acc-{uuid.uuid4()}",
        name="Checking",
        type="BANK",
        balance=1000.0,
        currency_code="BRL",
    )
    db.add(account)
    db.commit()

    yield household, account

    db.query(AnomalyFlag).filter(AnomalyFlag.household_id == household.id).delete(
        synchronize_session=False
    )
    db.query(Transaction).filter(Transaction.household_id == household.id).delete(
        synchronize_session=False
    )
    db.query(Account).filter(Account.household_id == household.id).delete(
        synchronize_session=False
    )
    db.query(PluggyConnection).filter(
        PluggyConnection.household_id == household.id
    ).delete(synchronize_session=False)
    db.query(Household).filter(Household.id == household.id).delete(
        synchronize_session=False
    )
    db.commit()


@pytest.fixture
def household_with_two_banks(db):
    household = Household(name="Two Bank Family")
    db.add(household)
    db.flush()

    accounts = []
    for label in ("Bank A", "Bank B"):
        connection = PluggyConnection(
            household_id=household.id, pluggy_item_id=f"item-{uuid.uuid4()}", status="pending"
        )
        db.add(connection)
        db.flush()
        account = Account(
            household_id=household.id,
            pluggy_connection_id=connection.id,
            pluggy_account_id=f"acc-{uuid.uuid4()}",
            name=label,
            type="BANK",
            balance=1000.0,
            currency_code="BRL",
        )
        db.add(account)
        accounts.append(account)
    db.commit()

    yield household, accounts[0], accounts[1]

    db.query(AnomalyFlag).filter(AnomalyFlag.household_id == household.id).delete(
        synchronize_session=False
    )
    db.query(Transaction).filter(Transaction.household_id == household.id).delete(
        synchronize_session=False
    )
    db.query(Account).filter(Account.household_id == household.id).delete(
        synchronize_session=False
    )
    db.query(PluggyConnection).filter(
        PluggyConnection.household_id == household.id
    ).delete(synchronize_session=False)
    db.query(Household).filter(Household.id == household.id).delete(
        synchronize_session=False
    )
    db.commit()


@pytest.fixture
def household_with_two_members(db):
    household = Household(name="Two Member Family")
    db.add(household)
    db.flush()

    members = []
    accounts = []
    app_user_ids = []
    for label in ("Member A", "Member B"):
        app_user = AppUser(
            auth_provider="supabase",
            auth_provider_user_id=f"user-{uuid.uuid4()}",
            email=f"{label.lower().replace(' ', '')}@example.com",
        )
        db.add(app_user)
        db.flush()
        app_user_ids.append(app_user.id)

        household_member = HouseholdMember(
            household_id=household.id, app_user_id=app_user.id, role="member"
        )
        db.add(household_member)
        db.flush()

        connection = PluggyConnection(
            household_id=household.id,
            pluggy_item_id=f"item-{uuid.uuid4()}",
            status="pending",
            created_by_app_user_id=app_user.id,
        )
        db.add(connection)
        db.flush()
        account = Account(
            household_id=household.id,
            pluggy_connection_id=connection.id,
            pluggy_account_id=f"acc-{uuid.uuid4()}",
            name=label,
            type="BANK",
            balance=1000.0,
            currency_code="BRL",
        )
        db.add(account)
        db.flush()

        members.append(household_member)
        accounts.append(account)
    db.commit()

    yield household, members[0], accounts[0], members[1], accounts[1]

    db.query(AnomalyFlag).filter(AnomalyFlag.household_id == household.id).delete(
        synchronize_session=False
    )
    db.query(Transaction).filter(Transaction.household_id == household.id).delete(
        synchronize_session=False
    )
    db.query(Account).filter(Account.household_id == household.id).delete(
        synchronize_session=False
    )
    db.query(PluggyConnection).filter(
        PluggyConnection.household_id == household.id
    ).delete(synchronize_session=False)
    db.query(HouseholdMember).filter(
        HouseholdMember.household_id == household.id
    ).delete(synchronize_session=False)
    db.query(Household).filter(Household.id == household.id).delete(
        synchronize_session=False
    )
    db.query(AppUser).filter(AppUser.id.in_(app_user_ids)).delete(
        synchronize_session=False
    )
    db.commit()


def _add_txn(db, household, account, *, amount, day_offset, description, category=None):
    txn = Transaction(
        household_id=household.id,
        account_id=account.id,
        pluggy_transaction_id=f"txn-{uuid.uuid4()}",
        description=description,
        amount=amount,
        currency_code="BRL",
        transaction_date=TODAY - timedelta(days=day_offset),
        category=category,
    )
    db.add(txn)
    db.flush()
    return txn


def test_large_transaction_detected_with_enough_history(db, household_and_account):
    household, account = household_and_account
    for i in range(6):
        _add_txn(db, household, account, amount=-50.0, day_offset=10 + i, description="Groceries")
    big_txn = _add_txn(db, household, account, amount=-2000.0, day_offset=1, description="Big Purchase")
    db.commit()

    candidates = anomaly_rules.detect_large_transactions(db, household.id, as_of=TODAY)

    assert len(candidates) == 1
    assert candidates[0]["transaction_id"] == big_txn.id
    assert candidates[0]["rule"] == "large_transaction"


def test_large_transaction_not_flagged_without_enough_history(db, household_and_account):
    household, account = household_and_account
    for i in range(2):
        _add_txn(db, household, account, amount=-50.0, day_offset=10 + i, description="Groceries")
    _add_txn(db, household, account, amount=-2000.0, day_offset=1, description="Big Purchase")
    db.commit()

    candidates = anomaly_rules.detect_large_transactions(db, household.id, as_of=TODAY)

    assert candidates == []


def test_large_transaction_baseline_is_per_bank_not_household(db, household_with_two_banks):
    household, bank_a, bank_b = household_with_two_banks
    # Bank A has a high-spend history — a big Bank B charge must not be
    # judged "large" against Bank A's baseline, and vice versa.
    for i in range(6):
        _add_txn(db, household, bank_a, amount=-900.0, day_offset=10 + i, description="Rent")
    for i in range(6):
        _add_txn(db, household, bank_b, amount=-50.0, day_offset=10 + i, description="Groceries")
    bank_b_spike = _add_txn(
        db, household, bank_b, amount=-2000.0, day_offset=1, description="Big Purchase"
    )
    db.commit()

    candidates = anomaly_rules.detect_large_transactions(db, household.id, as_of=TODAY)

    assert len(candidates) == 1
    assert candidates[0]["transaction_id"] == bank_b_spike.id


def test_new_merchant_history_is_per_bank_not_household(db, household_with_two_banks):
    household, bank_a, bank_b = household_with_two_banks
    # Bank A has enough history to clear the cold-start window; Bank B was
    # just connected. A merchant seen in Bank A must not suppress the
    # "new merchant" flag for the same merchant name showing up in Bank B,
    # and Bank B's lack of history must not block detection once IT has
    # enough history either.
    for i in range(5):
        _add_txn(db, household, bank_a, amount=-30.0, day_offset=60 + i, description="Regular Store")
    for i in range(5):
        _add_txn(db, household, bank_b, amount=-30.0, day_offset=60 + i, description="Other Store")
    bank_b_new = _add_txn(
        db, household, bank_b, amount=-75.0, day_offset=1, description="Brand New Shop"
    )
    db.commit()

    candidates = anomaly_rules.detect_new_merchants(db, household.id)

    assert len(candidates) == 1
    assert candidates[0]["transaction_id"] == bank_b_new.id


def test_duplicate_transaction_detected(db, household_and_account):
    household, account = household_and_account
    _add_txn(db, household, account, amount=-89.9, day_offset=5, description="Netflix")
    dup = _add_txn(db, household, account, amount=-89.9, day_offset=4, description="Netflix")
    db.commit()

    candidates = anomaly_rules.detect_duplicate_transactions(db, household.id)

    assert len(candidates) == 1
    assert candidates[0]["transaction_id"] == dup.id


def test_duplicate_transaction_not_flagged_outside_window(db, household_and_account):
    household, account = household_and_account
    _add_txn(db, household, account, amount=-89.9, day_offset=20, description="Netflix")
    _add_txn(db, household, account, amount=-89.9, day_offset=1, description="Netflix")
    db.commit()

    candidates = anomaly_rules.detect_duplicate_transactions(db, household.id)

    assert candidates == []


def test_new_merchant_detected_after_enough_history(db, household_and_account):
    household, account = household_and_account
    for i in range(5):
        _add_txn(db, household, account, amount=-30.0, day_offset=60 + i, description="Regular Store")
    new_txn = _add_txn(db, household, account, amount=-75.0, day_offset=1, description="Brand New Shop")
    db.commit()

    candidates = anomaly_rules.detect_new_merchants(db, household.id)

    assert len(candidates) == 1
    assert candidates[0]["transaction_id"] == new_txn.id


def test_new_merchant_not_flagged_during_cold_start(db, household_and_account):
    household, account = household_and_account
    _add_txn(db, household, account, amount=-75.0, day_offset=1, description="Brand New Shop")
    _add_txn(db, household, account, amount=-75.0, day_offset=2, description="Another Shop")
    db.commit()

    candidates = anomaly_rules.detect_new_merchants(db, household.id)

    assert candidates == []


def test_recurring_payment_changed_detected(db, household_and_account):
    household, account = household_and_account
    for i in range(3):
        _add_txn(
            db, household, account,
            amount=-100.0, day_offset=90 - i * 30, description="Gym Membership",
        )
    changed = _add_txn(
        db, household, account, amount=-200.0, day_offset=1, description="Gym Membership"
    )
    db.commit()

    candidates = anomaly_rules.detect_recurring_payment_changes(db, household.id)

    assert len(candidates) == 1
    assert candidates[0]["transaction_id"] == changed.id


def test_recurring_payment_not_flagged_when_stable(db, household_and_account):
    household, account = household_and_account
    for i in range(4):
        _add_txn(
            db, household, account,
            amount=-100.0, day_offset=90 - i * 30, description="Gym Membership",
        )
    db.commit()

    candidates = anomaly_rules.detect_recurring_payment_changes(db, household.id)

    assert candidates == []


def test_category_deviation_detected(db, household_and_account):
    household, account = household_and_account
    _add_txn(db, household, account, amount=-100.0, day_offset=45, description="Groceries", category="Food")
    _add_txn(db, household, account, amount=-400.0, day_offset=5, description="Groceries", category="Food")
    db.commit()

    candidates = anomaly_rules.detect_category_deviations(db, household.id, as_of=TODAY)

    assert len(candidates) == 1
    assert candidates[0]["transaction_id"] is None
    assert candidates[0]["rule"] == "category_deviation"


def test_category_deviation_not_flagged_below_floor(db, household_and_account):
    household, account = household_and_account
    _add_txn(db, household, account, amount=-10.0, day_offset=45, description="Coffee", category="Food")
    _add_txn(db, household, account, amount=-40.0, day_offset=5, description="Coffee", category="Food")
    db.commit()

    candidates = anomaly_rules.detect_category_deviations(db, household.id, as_of=TODAY)

    assert candidates == []


def test_member_deviation_detected(db, household_with_two_members):
    household, member_a, account_a, member_b, account_b = household_with_two_members
    # Member A: prior window low, current window high -> flagged.
    _add_txn(db, household, account_a, amount=-100.0, day_offset=45, description="Prior spend")
    _add_txn(db, household, account_a, amount=-400.0, day_offset=5, description="Current spend")
    # Member B: stays flat -> not flagged.
    _add_txn(db, household, account_b, amount=-150.0, day_offset=45, description="Prior spend B")
    _add_txn(db, household, account_b, amount=-150.0, day_offset=5, description="Current spend B")
    db.commit()

    candidates = anomaly_rules.detect_member_deviations(db, household.id, as_of=TODAY)

    assert len(candidates) == 1
    assert candidates[0]["household_member_id"] == member_a.id
    assert candidates[0]["transaction_id"] is None
    assert candidates[0]["rule"] == "member_deviation"


def test_member_deviation_not_flagged_below_floor(db, household_with_two_members):
    household, member_a, account_a, _, _ = household_with_two_members
    _add_txn(db, household, account_a, amount=-10.0, day_offset=45, description="Coffee")
    _add_txn(db, household, account_a, amount=-40.0, day_offset=5, description="Coffee")
    db.commit()

    candidates = anomaly_rules.detect_member_deviations(db, household.id, as_of=TODAY)

    assert candidates == []


def test_member_deviation_ignores_unattributed_connection(db, household_and_account):
    household, account = household_and_account
    _add_txn(db, household, account, amount=-100.0, day_offset=45, description="Prior spend")
    _add_txn(db, household, account, amount=-400.0, day_offset=5, description="Current spend")
    db.commit()

    candidates = anomaly_rules.detect_member_deviations(db, household.id, as_of=TODAY)

    assert candidates == []


def test_run_anomaly_detection_is_idempotent(db, household_and_account):
    household, account = household_and_account
    for i in range(6):
        _add_txn(db, household, account, amount=-50.0, day_offset=10 + i, description="Groceries")
    _add_txn(db, household, account, amount=-2000.0, day_offset=1, description="Big Purchase")
    db.commit()

    inserted_first = anomaly_rules.run_anomaly_detection(db, household.id)
    db.commit()
    inserted_second = anomaly_rules.run_anomaly_detection(db, household.id)
    db.commit()

    assert inserted_first > 0
    assert inserted_second == 0

    flags = db.query(AnomalyFlag).filter(AnomalyFlag.household_id == household.id).all()
    assert len(flags) == inserted_first


def test_dismissed_flag_survives_rerun(db, household_and_account):
    household, account = household_and_account
    for i in range(6):
        _add_txn(db, household, account, amount=-50.0, day_offset=10 + i, description="Groceries")
    _add_txn(db, household, account, amount=-2000.0, day_offset=1, description="Big Purchase")
    db.commit()

    anomaly_rules.run_anomaly_detection(db, household.id)
    db.commit()

    flag = (
        db.query(AnomalyFlag)
        .filter(AnomalyFlag.household_id == household.id, AnomalyFlag.rule == "large_transaction")
        .one()
    )
    flag.status = "dismissed"
    db.commit()

    anomaly_rules.run_anomaly_detection(db, household.id)
    db.commit()

    db.refresh(flag)
    assert flag.status == "dismissed"
    count = (
        db.query(AnomalyFlag)
        .filter(AnomalyFlag.household_id == household.id, AnomalyFlag.rule == "large_transaction")
        .count()
    )
    assert count == 1
