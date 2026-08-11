import asyncio
import logging
from datetime import datetime, timezone
from typing import Awaitable, Callable, TypeVar
from urllib.parse import parse_qs, urlparse

from sqlalchemy.orm import Session

from app.database.session import SessionLocal
from app.models.pluggy_connection import PluggyConnection, SyncJob
from app.services.anomaly_rules import run_anomaly_detection
from app.services.transfer_detection import detect_internal_transfers
from app.settings import settings
from app.sync.normalize import (
    snapshot_balances,
    upsert_accounts,
    upsert_credit_card_bills,
    upsert_investments,
    upsert_loans,
    upsert_transactions,
)
from app.sync.pluggy_client import PluggyClient

logger = logging.getLogger(__name__)

MAX_ATTEMPTS = 3
RETRY_BACKOFF_SECONDS = 2
POLL_INTERVAL_SECONDS = 5.0

T = TypeVar("T")


async def _call_with_retry(fn: Callable[..., Awaitable[T]], *args, **kwargs) -> T:
    last_exc: Exception | None = None
    for attempt in range(1, MAX_ATTEMPTS + 1):
        try:
            return await fn(*args, **kwargs)
        except Exception as exc:  # noqa: BLE001 - retried, then re-raised below
            last_exc = exc
            if attempt < MAX_ATTEMPTS:
                await asyncio.sleep(RETRY_BACKOFF_SECONDS * attempt)
    assert last_exc is not None
    raise last_exc


async def _paginate_transactions(client: PluggyClient, account_id: str) -> list[dict]:
    all_txns: list[dict] = []
    cursor = None
    while True:
        data = await client.get_transactions(account_id, cursor=cursor)
        all_txns.extend(data.get("results", []))
        next_link = data.get("next")
        if not next_link:
            break
        cursor = parse_qs(urlparse(next_link).query).get("after", [None])[0]
        if not cursor:
            break
    return all_txns


async def run_sync_job(db: Session, job: SyncJob, client: PluggyClient | None = None) -> None:
    """Runs one sync job to completion, updating its status as it goes.

    Never leaves a database transaction open while waiting on Pluggy: each
    network round trip happens outside of any pending `db.add`/flush, and the
    only commits are the small, synchronous status/data writes below.
    """
    connection = db.get(PluggyConnection, job.pluggy_connection_id)
    job.status = "running"
    db.commit()

    client = client or PluggyClient(settings.pluggy_client_id, settings.pluggy_client_secret)
    any_account_failed = False
    try:
        await _call_with_retry(client.authenticate)
        item = await _call_with_retry(client.get_item, connection.pluggy_item_id)
        connection.status = item.get("status", connection.status)

        accounts = await _call_with_retry(client.get_accounts, connection.pluggy_item_id)
        account_id_map = upsert_accounts(db, job.household_id, connection.id, accounts)
        db.commit()

        for account in accounts:
            try:
                txns = await _call_with_retry(_paginate_transactions, client, account["id"])
                upsert_transactions(db, job.household_id, account_id_map[account["id"]], txns)
                db.commit()
            except Exception:
                logger.exception(
                    "Failed to sync transactions for account %s (job %s)",
                    account["id"],
                    job.id,
                )
                any_account_failed = True
                db.rollback()

            if account.get("type") == "CREDIT":
                try:
                    bills = await _call_with_retry(client.get_bills, account["id"])
                    upsert_credit_card_bills(
                        db, job.household_id, account_id_map[account["id"]], bills
                    )
                    db.commit()
                except Exception:
                    logger.exception(
                        "Failed to sync credit card bills for account %s (job %s)",
                        account["id"],
                        job.id,
                    )
                    any_account_failed = True
                    db.rollback()

        try:
            account_balances = {
                account_id_map[account["id"]]: (
                    account.get("balance"),
                    account.get("currencyCode") or "BRL",
                )
                for account in accounts
                if account["id"] in account_id_map
            }
            snapshot_balances(
                db,
                job.household_id,
                account_balances,
                datetime.now(timezone.utc).date(),
            )
            db.commit()
        except Exception:
            logger.exception("Failed to snapshot balances (job %s)", job.id)
            any_account_failed = True
            db.rollback()

        try:
            investments = await _call_with_retry(
                client.get_investments, connection.pluggy_item_id
            )
            upsert_investments(db, job.household_id, connection.id, investments)
            db.commit()
        except Exception:
            logger.exception("Failed to sync investments (job %s)", job.id)
            any_account_failed = True
            db.rollback()

        try:
            loans = await _call_with_retry(client.get_loans, connection.pluggy_item_id)
            upsert_loans(db, job.household_id, connection.id, loans)
            db.commit()
        except Exception:
            logger.exception("Failed to sync loans (job %s)", job.id)
            any_account_failed = True
            db.rollback()

        try:
            run_anomaly_detection(db, job.household_id)
            db.commit()
        except Exception:
            logger.exception("Failed to run anomaly detection (job %s)", job.id)
            any_account_failed = True
            db.rollback()

        try:
            detect_internal_transfers(db, job.household_id)
            db.commit()
        except Exception:
            logger.exception("Failed to run internal-transfer detection (job %s)", job.id)
            any_account_failed = True
            db.rollback()

        job.status = "partially_completed" if any_account_failed else "completed"
    except Exception:
        logger.exception("Sync job %s failed", job.id)
        job.status = "failed"
    finally:
        db.commit()


async def process_queued_jobs(db: Session) -> int:
    jobs = db.query(SyncJob).filter(SyncJob.status == "queued").all()
    for job in jobs:
        await run_sync_job(db, job)
    return len(jobs)


async def _worker_loop(poll_interval: float = POLL_INTERVAL_SECONDS) -> None:
    logger.info("Sync worker started, polling every %ss", poll_interval)
    while True:
        db = SessionLocal()
        try:
            processed = await process_queued_jobs(db)
            if processed:
                logger.info("Processed %d sync job(s)", processed)
        finally:
            db.close()
        await asyncio.sleep(poll_interval)


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    asyncio.run(_worker_loop())
