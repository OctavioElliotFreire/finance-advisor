import uuid
from datetime import date, timedelta

import pytest

from app.database.session import SessionLocal
from app.models.account import Account
from app.models.household import Household
from app.models.pluggy_connection import PluggyConnection
from app.models.transaction import Transaction
from app.services import transfer_detection

TODAY = date(2026, 7, 27)


@pytest.fixture
def db():
    session = SessionLocal()
    yield session
    session.close()


@pytest.fixture
def household_with_two_accounts(db):
    household = Household(name="Transfer Test Family")
    db.add(household)
    db.flush()

    accounts = []
    for label in ("Checking", "Savings"):
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


def _add_txn(db, household, account, *, amount, day_offset, description):
    txn = Transaction(
        household_id=household.id,
        account_id=account.id,
        pluggy_transaction_id=f"txn-{uuid.uuid4()}",
        description=description,
        amount=amount,
        currency_code="BRL",
        transaction_date=TODAY - timedelta(days=day_offset),
    )
    db.add(txn)
    db.flush()
    return txn


def test_matches_opposite_amounts_across_accounts(db, household_with_two_accounts):
    household, checking, savings = household_with_two_accounts
    debit = _add_txn(db, household, checking, amount=-500.0, day_offset=1, description="Transfer out")
    credit = _add_txn(db, household, savings, amount=500.0, day_offset=1, description="Transfer in")
    db.commit()

    matched = transfer_detection.detect_internal_transfers(db, household.id)
    db.commit()

    db.refresh(debit)
    db.refresh(credit)
    assert matched == 2
    assert debit.is_transfer is True
    assert credit.is_transfer is True


def test_does_not_match_same_account(db, household_with_two_accounts):
    household, checking, _savings = household_with_two_accounts
    debit = _add_txn(db, household, checking, amount=-200.0, day_offset=1, description="Debit")
    credit = _add_txn(db, household, checking, amount=200.0, day_offset=1, description="Credit")
    db.commit()

    matched = transfer_detection.detect_internal_transfers(db, household.id)
    db.commit()

    db.refresh(debit)
    db.refresh(credit)
    assert matched == 0
    assert debit.is_transfer is False
    assert credit.is_transfer is False


def test_does_not_match_outside_window(db, household_with_two_accounts):
    household, checking, savings = household_with_two_accounts
    debit = _add_txn(db, household, checking, amount=-500.0, day_offset=10, description="Old debit")
    credit = _add_txn(
        db,
        household,
        savings,
        amount=500.0,
        day_offset=10 - (transfer_detection.TRANSFER_MATCH_WINDOW_DAYS + 1),
        description="Unrelated later credit",
    )
    db.commit()

    matched = transfer_detection.detect_internal_transfers(db, household.id)
    db.commit()

    db.refresh(debit)
    db.refresh(credit)
    assert matched == 0
    assert debit.is_transfer is False
    assert credit.is_transfer is False


def test_idempotent_rerun(db, household_with_two_accounts):
    household, checking, savings = household_with_two_accounts
    _add_txn(db, household, checking, amount=-500.0, day_offset=1, description="Transfer out")
    _add_txn(db, household, savings, amount=500.0, day_offset=1, description="Transfer in")
    db.commit()

    first = transfer_detection.detect_internal_transfers(db, household.id)
    db.commit()
    second = transfer_detection.detect_internal_transfers(db, household.id)
    db.commit()

    assert first == 2
    assert second == 0
