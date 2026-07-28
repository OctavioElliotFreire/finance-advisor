import uuid
from datetime import date, timedelta

import pytest

from app.database.session import SessionLocal
from app.models.account import Account
from app.models.anomaly import AnomalyFlag
from app.models.extended_finance import BalanceSnapshot, CreditCardBill, Investment, Loan
from app.models.household import Household
from app.models.pluggy_connection import PluggyConnection, SyncJob
from app.models.transaction import Transaction
from app.workers import sync_worker


class _FakePluggyClient:
    def __init__(
        self,
        accounts=None,
        transactions_by_account=None,
        item_status="UPDATED",
        get_item_failures=0,
        failing_account_ids=None,
        bills_by_account=None,
        investments=None,
        loans=None,
        fail_investments=False,
        fail_loans=False,
        fail_bills_for_account_ids=None,
    ):
        self._accounts = accounts if accounts is not None else []
        self._transactions_by_account = transactions_by_account or {}
        self._item_status = item_status
        self._get_item_failures = get_item_failures
        self._get_item_calls = 0
        self._failing_account_ids = failing_account_ids or set()
        self._bills_by_account = bills_by_account or {}
        self._investments = investments if investments is not None else []
        self._loans = loans if loans is not None else []
        self._fail_investments = fail_investments
        self._fail_loans = fail_loans
        self._fail_bills_for_account_ids = fail_bills_for_account_ids or set()
        self.authenticate_calls = 0

    async def authenticate(self):
        self.authenticate_calls += 1
        return "fake-api-key"

    async def get_item(self, item_id):
        self._get_item_calls += 1
        if self._get_item_calls <= self._get_item_failures:
            raise RuntimeError("transient pluggy error")
        return {"id": item_id, "status": self._item_status}

    async def get_accounts(self, item_id):
        return self._accounts

    async def get_transactions(self, account_id, cursor=None):
        if account_id in self._failing_account_ids:
            raise RuntimeError("transaction fetch failed")
        txns = self._transactions_by_account.get(account_id, [])
        if cursor is None and len(txns) > 1:
            return {
                "results": [txns[0]],
                "next": f"https://api.pluggy.ai/v2/transactions?after=page2",
            }
        if cursor == "page2":
            return {"results": txns[1:], "next": None}
        return {"results": txns, "next": None}

    async def get_bills(self, account_id):
        if account_id in self._fail_bills_for_account_ids:
            raise RuntimeError("bills fetch failed")
        return self._bills_by_account.get(account_id, [])

    async def get_investments(self, item_id):
        if self._fail_investments:
            raise RuntimeError("investments fetch failed")
        return self._investments

    async def get_loans(self, item_id):
        if self._fail_loans:
            raise RuntimeError("loans fetch failed")
        return self._loans


@pytest.fixture(autouse=True)
def no_retry_backoff(monkeypatch):
    monkeypatch.setattr(sync_worker, "RETRY_BACKOFF_SECONDS", 0)


@pytest.fixture
def db():
    session = SessionLocal()
    yield session
    session.close()


@pytest.fixture
def household_and_connection(db):
    household = Household(name="Sync Worker Family")
    db.add(household)
    db.flush()
    connection = PluggyConnection(
        household_id=household.id, pluggy_item_id=f"item-{uuid.uuid4()}", status="pending"
    )
    db.add(connection)
    db.commit()

    yield household, connection

    db.query(AnomalyFlag).filter(AnomalyFlag.household_id == household.id).delete(
        synchronize_session=False
    )
    db.query(BalanceSnapshot).filter(
        BalanceSnapshot.household_id == household.id
    ).delete(synchronize_session=False)
    db.query(CreditCardBill).filter(
        CreditCardBill.household_id == household.id
    ).delete(synchronize_session=False)
    db.query(Investment).filter(Investment.household_id == household.id).delete(
        synchronize_session=False
    )
    db.query(Loan).filter(Loan.household_id == household.id).delete(
        synchronize_session=False
    )
    db.query(Transaction).filter(Transaction.household_id == household.id).delete(
        synchronize_session=False
    )
    db.query(Account).filter(Account.household_id == household.id).delete(
        synchronize_session=False
    )
    db.query(SyncJob).filter(SyncJob.household_id == household.id).delete(
        synchronize_session=False
    )
    db.query(PluggyConnection).filter(
        PluggyConnection.household_id == household.id
    ).delete(synchronize_session=False)
    db.query(Household).filter(Household.id == household.id).delete(
        synchronize_session=False
    )
    db.commit()


def _make_job(db, household, connection):
    job = SyncJob(
        household_id=household.id, pluggy_connection_id=connection.id, status="queued"
    )
    db.add(job)
    db.commit()
    return job


async def _run(db, job, client):
    await sync_worker.run_sync_job(db, job, client=client)


@pytest.mark.anyio
async def test_run_sync_job_creates_accounts_and_transactions(db, household_and_connection):
    household, connection = household_and_connection
    job = _make_job(db, household, connection)
    client = _FakePluggyClient(
        accounts=[{"id": "acc-1", "name": "Checking", "type": "BANK", "balance": 100.0}],
        transactions_by_account={
            "acc-1": [
                {"id": "txn-1", "description": "Coffee", "amount": -5.5, "date": "2026-07-01T00:00:00.000Z"},
                {"id": "txn-2", "description": "Salary", "amount": 2000.0, "date": "2026-07-02T00:00:00.000Z"},
            ]
        },
    )

    await _run(db, job, client)

    db.refresh(job)
    assert job.status == "completed"

    accounts = db.query(Account).filter(Account.household_id == household.id).all()
    assert len(accounts) == 1
    assert accounts[0].pluggy_account_id == "acc-1"
    assert accounts[0].balance == 100.0

    txns = db.query(Transaction).filter(Transaction.household_id == household.id).all()
    assert {t.pluggy_transaction_id for t in txns} == {"txn-1", "txn-2"}


@pytest.mark.anyio
async def test_run_sync_job_is_idempotent(db, household_and_connection):
    household, connection = household_and_connection
    job = _make_job(db, household, connection)
    client = _FakePluggyClient(
        accounts=[{"id": "acc-1", "name": "Checking", "type": "BANK", "balance": 100.0}],
        transactions_by_account={
            "acc-1": [{"id": "txn-1", "description": "Coffee", "amount": -5.5, "date": "2026-07-01T00:00:00.000Z"}]
        },
    )

    await _run(db, job, client)
    await _run(db, job, _FakePluggyClient(
        accounts=[{"id": "acc-1", "name": "Checking", "type": "BANK", "balance": 150.0}],
        transactions_by_account={
            "acc-1": [{"id": "txn-1", "description": "Coffee", "amount": -5.5, "date": "2026-07-01T00:00:00.000Z"}]
        },
    ))

    accounts = db.query(Account).filter(Account.household_id == household.id).all()
    assert len(accounts) == 1
    assert accounts[0].balance == 150.0  # updated in place, not duplicated

    txns = db.query(Transaction).filter(Transaction.household_id == household.id).all()
    assert len(txns) == 1


@pytest.mark.anyio
async def test_run_sync_job_retries_transient_get_item_failure_then_succeeds(
    db, household_and_connection
):
    household, connection = household_and_connection
    job = _make_job(db, household, connection)
    client = _FakePluggyClient(accounts=[], get_item_failures=2)

    await _run(db, job, client)

    db.refresh(job)
    assert job.status == "completed"
    assert client._get_item_calls == 3


@pytest.mark.anyio
async def test_run_sync_job_marks_failed_after_exhausting_retries(
    db, household_and_connection
):
    household, connection = household_and_connection
    job = _make_job(db, household, connection)
    client = _FakePluggyClient(accounts=[], get_item_failures=99)

    await _run(db, job, client)

    db.refresh(job)
    assert job.status == "failed"


@pytest.mark.anyio
async def test_run_sync_job_marks_partially_completed_when_one_account_fails(
    db, household_and_connection
):
    household, connection = household_and_connection
    job = _make_job(db, household, connection)
    client = _FakePluggyClient(
        accounts=[
            {"id": "acc-ok", "name": "Checking", "type": "BANK", "balance": 10.0},
            {"id": "acc-bad", "name": "Savings", "type": "BANK", "balance": 20.0},
        ],
        transactions_by_account={
            "acc-ok": [{"id": "txn-ok", "description": "Rent", "amount": -900.0, "date": "2026-07-01T00:00:00.000Z"}]
        },
        failing_account_ids={"acc-bad"},
    )

    await _run(db, job, client)

    db.refresh(job)
    assert job.status == "partially_completed"

    accounts = db.query(Account).filter(Account.household_id == household.id).all()
    assert len(accounts) == 2  # both accounts still upserted

    txns = db.query(Transaction).filter(Transaction.household_id == household.id).all()
    assert len(txns) == 1  # only the healthy account's transactions synced


@pytest.mark.anyio
async def test_run_sync_job_paginates_transactions(db, household_and_connection):
    household, connection = household_and_connection
    job = _make_job(db, household, connection)
    client = _FakePluggyClient(
        accounts=[{"id": "acc-1", "name": "Checking", "type": "BANK", "balance": 0.0}],
        transactions_by_account={
            "acc-1": [
                {"id": "txn-1", "description": "One", "amount": -1.0, "date": "2026-07-01T00:00:00.000Z"},
                {"id": "txn-2", "description": "Two", "amount": -2.0, "date": "2026-07-02T00:00:00.000Z"},
            ]
        },
    )

    await _run(db, job, client)

    txns = db.query(Transaction).filter(Transaction.household_id == household.id).all()
    assert {t.pluggy_transaction_id for t in txns} == {"txn-1", "txn-2"}


@pytest.mark.anyio
async def test_run_sync_job_syncs_credit_card_bills_for_credit_accounts(
    db, household_and_connection
):
    household, connection = household_and_connection
    job = _make_job(db, household, connection)
    client = _FakePluggyClient(
        accounts=[
            {"id": "acc-credit", "name": "Card", "type": "CREDIT", "balance": -200.0},
            {"id": "acc-bank", "name": "Checking", "type": "BANK", "balance": 100.0},
        ],
        bills_by_account={
            "acc-credit": [
                {"id": "bill-1", "dueDate": "2026-08-05", "closingDate": "2026-07-28", "balance": 200.0, "minimumPayment": 50.0, "currencyCode": "BRL"}
            ]
        },
    )

    await _run(db, job, client)

    db.refresh(job)
    assert job.status == "completed"

    bills = db.query(CreditCardBill).filter(CreditCardBill.household_id == household.id).all()
    assert len(bills) == 1
    assert bills[0].pluggy_bill_id == "bill-1"
    assert bills[0].total_amount == 200.0


@pytest.mark.anyio
async def test_run_sync_job_syncs_investments_and_loans(db, household_and_connection):
    household, connection = household_and_connection
    job = _make_job(db, household, connection)
    client = _FakePluggyClient(
        accounts=[],
        investments=[
            {"id": "inv-1", "name": "CDB", "type": "FIXED_INCOME", "balance": 1000.0, "value": 1000.0, "quantity": 1, "currencyCode": "BRL", "date": "2026-07-01T00:00:00.000Z"}
        ],
        loans=[
            {"id": "loan-1", "type": "PERSONAL", "status": "ACTIVE", "contractedAmount": 5000.0, "outstandingBalance": 4000.0, "installmentAmount": 500.0, "totalInstallments": 10, "paidInstallments": 2, "dueDate": "2026-09-01", "interestRate": 1.5, "currencyCode": "BRL"}
        ],
    )

    await _run(db, job, client)

    db.refresh(job)
    assert job.status == "completed"

    investments = db.query(Investment).filter(Investment.household_id == household.id).all()
    assert len(investments) == 1
    assert investments[0].pluggy_investment_id == "inv-1"

    loans = db.query(Loan).filter(Loan.household_id == household.id).all()
    assert len(loans) == 1
    assert loans[0].pluggy_loan_id == "loan-1"
    assert loans[0].outstanding_balance == 4000.0


@pytest.mark.anyio
async def test_run_sync_job_creates_balance_snapshot_and_is_idempotent_same_day(
    db, household_and_connection
):
    household, connection = household_and_connection
    job = _make_job(db, household, connection)
    client = _FakePluggyClient(
        accounts=[{"id": "acc-1", "name": "Checking", "type": "BANK", "balance": 100.0}],
    )

    await _run(db, job, client)

    snapshots = db.query(BalanceSnapshot).filter(BalanceSnapshot.household_id == household.id).all()
    assert len(snapshots) == 1
    assert snapshots[0].balance == 100.0

    job2 = _make_job(db, household, connection)
    client2 = _FakePluggyClient(
        accounts=[{"id": "acc-1", "name": "Checking", "type": "BANK", "balance": 250.0}],
    )
    await _run(db, job2, client2)

    snapshots = db.query(BalanceSnapshot).filter(BalanceSnapshot.household_id == household.id).all()
    assert len(snapshots) == 1  # same day: updated in place, not duplicated
    assert snapshots[0].balance == 250.0


@pytest.mark.anyio
async def test_run_sync_job_marks_partially_completed_when_investments_fetch_fails(
    db, household_and_connection
):
    household, connection = household_and_connection
    job = _make_job(db, household, connection)
    client = _FakePluggyClient(accounts=[], fail_investments=True)

    await _run(db, job, client)

    db.refresh(job)
    assert job.status == "partially_completed"


@pytest.mark.anyio
async def test_run_sync_job_creates_anomaly_flag_for_large_transaction(
    db, household_and_connection
):
    household, connection = household_and_connection
    job = _make_job(db, household, connection)

    def _iso(day_offset):
        return (date.today() - timedelta(days=day_offset)).isoformat() + "T00:00:00.000Z"

    small_txns = [
        {"id": f"txn-small-{i}", "description": "Groceries", "amount": -50.0, "date": _iso(10 + i)}
        for i in range(6)
    ]
    big_txn = {"id": "txn-big", "description": "Big Purchase", "amount": -2000.0, "date": _iso(1)}

    client = _FakePluggyClient(
        accounts=[{"id": "acc-1", "name": "Checking", "type": "BANK", "balance": 100.0}],
        transactions_by_account={"acc-1": small_txns + [big_txn]},
    )

    await _run(db, job, client)

    db.refresh(job)
    assert job.status == "completed"

    flags = db.query(AnomalyFlag).filter(AnomalyFlag.household_id == household.id).all()
    assert any(f.rule == "large_transaction" for f in flags)


@pytest.mark.anyio
async def test_process_queued_jobs_skips_non_queued_jobs(db, household_and_connection):
    household, connection = household_and_connection
    queued_job = _make_job(db, household, connection)
    other_job = SyncJob(
        household_id=household.id,
        pluggy_connection_id=connection.id,
        status="completed",
    )
    db.add(other_job)
    db.commit()

    monkeypatch_calls = []

    async def fake_run(db_arg, job_arg, client=None):
        monkeypatch_calls.append(job_arg.id)
        job_arg.status = "completed"
        db_arg.commit()

    original = sync_worker.run_sync_job
    sync_worker.run_sync_job = fake_run
    try:
        processed = await sync_worker.process_queued_jobs(db)
    finally:
        sync_worker.run_sync_job = original

    assert processed == 1
    assert monkeypatch_calls == [queued_job.id]
