import statistics
import uuid
from datetime import date, timedelta

from sqlalchemy import func
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.orm import Session

from app.models.account import Account
from app.models.anomaly import AnomalyFlag
from app.models.transaction import Transaction

LARGE_TXN_MIN_SAMPLE = 5
LARGE_TXN_WINDOW_DAYS = 180
LARGE_TXN_ZSCORE_HIGH = 5.0
LARGE_TXN_ZSCORE_MEDIUM = 3.0

DUPLICATE_WINDOW_DAYS = 3

NEW_MERCHANT_MIN_CONNECTION_HISTORY_DAYS = 30
NEW_MERCHANT_MIN_AMOUNT = 50.0

RECURRING_MIN_PRIOR_OCCURRENCES = 3
RECURRING_CHANGE_HIGH = 0.5
RECURRING_CHANGE_MEDIUM = 0.25

CATEGORY_DEVIATION_WINDOW_DAYS = 30
CATEGORY_DEVIATION_FLOOR = 200.0
CATEGORY_DEVIATION_HIGH_RATIO = 2.5
CATEGORY_DEVIATION_MEDIUM_RATIO = 1.5


def _severity(value: float, high: float, medium: float) -> str:
    if value >= high:
        return "high"
    if value >= medium:
        return "medium"
    return "low"


def _normalize_description(description: str | None) -> str:
    return (description or "").strip().lower()


def _household_debits(
    db: Session, household_id: uuid.UUID, since: date | None = None
) -> list[Transaction]:
    query = db.query(Transaction).filter(
        Transaction.household_id == household_id, Transaction.amount < 0
    )
    if since is not None:
        query = query.filter(Transaction.transaction_date >= since)
    return query.order_by(Transaction.transaction_date).all()


def _household_debits_by_connection(
    db: Session, household_id: uuid.UUID, since: date | None = None
) -> dict[uuid.UUID, list[Transaction]]:
    """Groups household debits by bank connection so statistical baselines
    (large-transaction z-score, new-merchant history) never mix spending
    patterns across unrelated banks — one high-volume bank would otherwise
    skew the "normal" baseline for a low-volume one. Accounts within the
    same bank connection (e.g. checking + savings) still share one baseline,
    which is the intended grain (see PLAN.md's household-roles discussion).
    """
    query = (
        db.query(Transaction, Account.pluggy_connection_id)
        .join(Account, Transaction.account_id == Account.id)
        .filter(Transaction.household_id == household_id, Transaction.amount < 0)
    )
    if since is not None:
        query = query.filter(Transaction.transaction_date >= since)
    rows = query.order_by(Transaction.transaction_date).all()

    by_connection: dict[uuid.UUID, list[Transaction]] = {}
    for txn, connection_id in rows:
        by_connection.setdefault(connection_id, []).append(txn)
    return by_connection


def detect_large_transactions(
    db: Session, household_id: uuid.UUID, as_of: date | None = None
) -> list[dict]:
    today = as_of or date.today()
    since = today - timedelta(days=LARGE_TXN_WINDOW_DAYS)
    by_connection = _household_debits_by_connection(db, household_id, since=since)

    candidates = []
    for debits in by_connection.values():
        for i, txn in enumerate(debits):
            prior = debits[:i]
            if len(prior) < LARGE_TXN_MIN_SAMPLE:
                continue
            amounts = [abs(float(p.amount)) for p in prior]
            avg = statistics.mean(amounts)
            stddev = statistics.pstdev(amounts) if len(amounts) > 1 else 0.0
            current = abs(float(txn.amount))
            z_score = (
                (current - avg) / stddev if stddev > 0 else (current / avg if avg > 0 else 0.0)
            )

            if current > avg + 3 * stddev and current > 2 * avg and z_score >= LARGE_TXN_ZSCORE_MEDIUM:
                candidates.append(
                    {
                        "transaction_id": txn.id,
                        "rule": "large_transaction",
                        "dedupe_key": str(txn.id),
                        "severity": _severity(z_score, LARGE_TXN_ZSCORE_HIGH, LARGE_TXN_ZSCORE_MEDIUM),
                        "score": round(z_score, 4),
                        "summary": (
                            f'R$ {current:.2f} for "{txn.description}" is {z_score:.1f} standard '
                            f"deviations above this bank's average debit of R$ {avg:.2f}"
                        ),
                        "raw_context": {"average": avg, "stddev": stddev, "sample_size": len(prior)},
                    }
                )
    return candidates


def detect_duplicate_transactions(db: Session, household_id: uuid.UUID) -> list[dict]:
    debits = _household_debits(db, household_id)
    candidates = []
    for i, txn in enumerate(debits):
        for other in debits[:i]:
            if other.account_id != txn.account_id:
                continue
            if abs(abs(float(other.amount)) - abs(float(txn.amount))) > 0.01:
                continue
            if _normalize_description(other.description) != _normalize_description(txn.description):
                continue
            if abs((txn.transaction_date - other.transaction_date).days) > DUPLICATE_WINDOW_DAYS:
                continue

            candidates.append(
                {
                    "transaction_id": txn.id,
                    "rule": "duplicate_transaction",
                    "dedupe_key": str(txn.id),
                    "severity": "medium",
                    "score": None,
                    "summary": (
                        f'Possible duplicate of a R$ {abs(float(txn.amount)):.2f} charge '
                        f'"{txn.description}" within {DUPLICATE_WINDOW_DAYS} days'
                    ),
                    "raw_context": {"matched_transaction_id": str(other.id)},
                }
            )
            break
    return candidates


def detect_new_merchants(db: Session, household_id: uuid.UUID) -> list[dict]:
    by_connection = _household_debits_by_connection(db, household_id)

    candidates = []
    for debits in by_connection.values():
        if not debits:
            continue
        connection_min_date = debits[0].transaction_date
        seen_descriptions: set[str] = set()
        for txn in debits:
            desc = _normalize_description(txn.description)
            amount = abs(float(txn.amount))
            has_enough_history = (
                txn.transaction_date - connection_min_date
            ).days >= NEW_MERCHANT_MIN_CONNECTION_HISTORY_DAYS

            if desc and desc not in seen_descriptions and amount > NEW_MERCHANT_MIN_AMOUNT and has_enough_history:
                candidates.append(
                    {
                        "transaction_id": txn.id,
                        "rule": "new_merchant",
                        "dedupe_key": str(txn.id),
                        "severity": "low",
                        "score": None,
                        "summary": f'First transaction with "{txn.description}" for R$ {amount:.2f}',
                        "raw_context": {},
                    }
                )
            if desc:
                seen_descriptions.add(desc)
    return candidates


def detect_recurring_payment_changes(db: Session, household_id: uuid.UUID) -> list[dict]:
    debits = _household_debits(db, household_id)
    groups: dict[tuple, list[Transaction]] = {}
    for txn in debits:
        desc = _normalize_description(txn.description)
        if not desc:
            continue
        groups.setdefault((txn.account_id, desc), []).append(txn)

    candidates = []
    for group in groups.values():
        if len(group) < RECURRING_MIN_PRIOR_OCCURRENCES + 1:
            continue
        group_sorted = sorted(group, key=lambda t: t.transaction_date)
        prior, latest = group_sorted[:-1], group_sorted[-1]
        prior_amounts = [abs(float(p.amount)) for p in prior]
        avg_prior = statistics.mean(prior_amounts)
        if avg_prior <= 0:
            continue
        current = abs(float(latest.amount))
        pct_change = abs(current - avg_prior) / avg_prior

        if pct_change > RECURRING_CHANGE_MEDIUM:
            candidates.append(
                {
                    "transaction_id": latest.id,
                    "rule": "recurring_payment_changed",
                    "dedupe_key": str(latest.id),
                    "severity": _severity(pct_change, RECURRING_CHANGE_HIGH, RECURRING_CHANGE_MEDIUM),
                    "score": round(pct_change, 4),
                    "summary": (
                        f'"{latest.description}" is R$ {current:.2f}, {pct_change * 100:.0f}% '
                        f"different from its usual R$ {avg_prior:.2f}"
                    ),
                    "raw_context": {"average_prior": avg_prior, "prior_occurrences": len(prior)},
                }
            )
    return candidates


def detect_category_deviations(
    db: Session, household_id: uuid.UUID, as_of: date | None = None
) -> list[dict]:
    today = as_of or date.today()
    window_start = today - timedelta(days=CATEGORY_DEVIATION_WINDOW_DAYS)
    prior_start = window_start - timedelta(days=CATEGORY_DEVIATION_WINDOW_DAYS)

    current_rows = (
        db.query(Transaction.category, func.sum(-Transaction.amount))
        .filter(
            Transaction.household_id == household_id,
            Transaction.amount < 0,
            Transaction.transaction_date >= window_start,
            Transaction.transaction_date <= today,
        )
        .group_by(Transaction.category)
        .all()
    )
    prior_rows = (
        db.query(Transaction.category, func.sum(-Transaction.amount))
        .filter(
            Transaction.household_id == household_id,
            Transaction.amount < 0,
            Transaction.transaction_date >= prior_start,
            Transaction.transaction_date < window_start,
        )
        .group_by(Transaction.category)
        .all()
    )
    prior_totals = {category: float(total or 0) for category, total in prior_rows}

    candidates = []
    for category, total in current_rows:
        current_total = float(total or 0)
        prior_total = prior_totals.get(category, 0.0)
        if current_total < CATEGORY_DEVIATION_FLOOR or prior_total <= 0:
            continue
        ratio = current_total / prior_total
        if ratio >= CATEGORY_DEVIATION_MEDIUM_RATIO:
            label = category or "Uncategorized"
            candidates.append(
                {
                    "transaction_id": None,
                    "rule": "category_deviation",
                    "dedupe_key": f"{label}:{today.isoformat()}",
                    "severity": _severity(
                        ratio, CATEGORY_DEVIATION_HIGH_RATIO, CATEGORY_DEVIATION_MEDIUM_RATIO
                    ),
                    "score": round(ratio, 4),
                    "summary": (
                        f'Spending in "{label}" over the last {CATEGORY_DEVIATION_WINDOW_DAYS} days '
                        f"(R$ {current_total:.2f}) is {ratio:.1f}x the prior period (R$ {prior_total:.2f})"
                    ),
                    "raw_context": {
                        "current_total": current_total,
                        "prior_total": prior_total,
                        "window_start": window_start.isoformat(),
                        "prior_start": prior_start.isoformat(),
                    },
                }
            )
    return candidates


RULES = (
    detect_large_transactions,
    detect_duplicate_transactions,
    detect_new_merchants,
    detect_recurring_payment_changes,
    detect_category_deviations,
)


def run_anomaly_detection(db: Session, household_id: uuid.UUID) -> int:
    """Runs every deterministic rule and upserts new candidates as AnomalyFlag
    rows. Uses ON CONFLICT DO NOTHING on (household_id, rule, dedupe_key) so a
    flag the user already reviewed (status changed via the feedback endpoint)
    is never resurrected or overwritten by a later sync.
    """
    candidates: list[dict] = []
    for rule_fn in RULES:
        candidates.extend(rule_fn(db, household_id))

    if not candidates:
        return 0

    rows = [
        {
            "id": uuid.uuid4(),
            "household_id": household_id,
            "transaction_id": c["transaction_id"],
            "rule": c["rule"],
            "dedupe_key": c["dedupe_key"],
            "severity": c["severity"],
            "score": c["score"],
            "summary": c["summary"],
            "raw_context": c["raw_context"],
        }
        for c in candidates
    ]

    stmt = pg_insert(AnomalyFlag).values(rows)
    stmt = stmt.on_conflict_do_nothing(
        index_elements=["household_id", "rule", "dedupe_key"]
    ).returning(AnomalyFlag.id)
    result = db.execute(stmt)
    return len(result.fetchall())
