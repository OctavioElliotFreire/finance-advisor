import uuid
from datetime import date, timedelta

import pytest

from app.database.session import SessionLocal
from app.models.account import Account
from app.models.anomaly import AnomalyFlag
from app.models.household import Household
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
