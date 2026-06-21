import json
import os
import sqlite3
from datetime import datetime, timezone

DB_PATH = os.getenv("DB_PATH", "finance.db")


def get_connection() -> sqlite3.Connection:
    conn = sqlite3.connect(DB_PATH)  # reads module-level DB_PATH — patchable in tests
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute("PRAGMA foreign_keys=ON")
    return conn


def init_schema() -> None:
    with get_connection() as conn:
        conn.executescript("""
            CREATE TABLE IF NOT EXISTS members (
                id   TEXT PRIMARY KEY,
                name TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS items (
                item_id        TEXT PRIMARY KEY,
                member_id      TEXT NOT NULL REFERENCES members(id),
                connector_id   INTEGER,
                connector_name TEXT,
                status         TEXT,
                last_synced_at TEXT
            );

            CREATE TABLE IF NOT EXISTS accounts (
                id                  TEXT PRIMARY KEY,
                item_id             TEXT NOT NULL REFERENCES items(item_id),
                member_id           TEXT NOT NULL REFERENCES members(id),
                name                TEXT,
                type                TEXT,
                subtype             TEXT,
                number              TEXT,
                balance             REAL,
                currency_code       TEXT,
                owner               TEXT,
                credit_limit        REAL,
                available_credit    REAL,
                balance_close_date  TEXT,
                balance_due_date    TEXT,
                minimum_payment     REAL,
                brand               TEXT,
                raw_json            TEXT
            );

            CREATE TABLE IF NOT EXISTS transactions (
                id                          TEXT PRIMARY KEY,
                account_id                  TEXT NOT NULL REFERENCES accounts(id),
                member_id                   TEXT NOT NULL REFERENCES members(id),
                description                 TEXT,
                description_raw             TEXT,
                amount                      REAL,
                amount_in_account_currency  REAL,
                currency_code               TEXT,
                date                        TEXT,
                type                        TEXT,
                operation_type              TEXT,
                category                    TEXT,
                category_id                 TEXT,
                status                      TEXT,
                balance_after               REAL,
                provider_code               TEXT,
                provider_id                 TEXT,
                merchant_name               TEXT,
                merchant_cnpj               TEXT,
                payment_data_json           TEXT,
                credit_card_metadata_json   TEXT,
                raw_json                    TEXT
            );

            CREATE INDEX IF NOT EXISTS idx_transactions_member_date
                ON transactions(member_id, date DESC);

            CREATE INDEX IF NOT EXISTS idx_transactions_account
                ON transactions(account_id);

            CREATE TABLE IF NOT EXISTS investments (
                id               TEXT PRIMARY KEY,
                item_id          TEXT NOT NULL REFERENCES items(item_id),
                member_id        TEXT NOT NULL REFERENCES members(id),
                name             TEXT,
                type             TEXT,
                subtype          TEXT,
                raw_type         TEXT,
                code             TEXT,
                isin_code        TEXT,
                value            REAL,
                quantity         REAL,
                balance          REAL,
                taxes            REAL,
                taxes2           REAL,
                currency_code    TEXT,
                date             TEXT,
                due_date         TEXT,
                annualized_rate  REAL,
                last_month_rate  REAL,
                last_12m_rate    REAL,
                issuer           TEXT,
                issuer_cnpj      TEXT,
                status           TEXT,
                number           TEXT,
                raw_json         TEXT
            );

            CREATE TABLE IF NOT EXISTS identity (
                id           TEXT PRIMARY KEY,
                item_id      TEXT NOT NULL REFERENCES items(item_id),
                member_id    TEXT NOT NULL REFERENCES members(id),
                full_name    TEXT,
                cpf_number   TEXT,
                birth_date   TEXT,
                phones_json  TEXT,
                emails_json  TEXT,
                addresses_json TEXT,
                raw_json     TEXT
            );

            CREATE TABLE IF NOT EXISTS credit_card_bills (
                id               TEXT PRIMARY KEY,
                account_id       TEXT NOT NULL REFERENCES accounts(id),
                member_id        TEXT NOT NULL REFERENCES members(id),
                due_date         TEXT,
                closing_date     TEXT,
                balance          REAL,
                previous_balance REAL,
                payment_amount   REAL,
                minimum_payment  REAL,
                currency_code    TEXT,
                raw_json         TEXT
            );

            CREATE TABLE IF NOT EXISTS loans (
                id                  TEXT PRIMARY KEY,
                item_id             TEXT NOT NULL REFERENCES items(item_id),
                member_id           TEXT NOT NULL REFERENCES members(id),
                number              TEXT,
                type                TEXT,
                status              TEXT,
                contract_amount     REAL,
                outstanding_balance REAL,
                installment_amount  REAL,
                installments_total  INTEGER,
                installments_paid   INTEGER,
                credit_date         TEXT,
                due_date            TEXT,
                interest_rate       REAL,
                currency_code       TEXT,
                raw_json            TEXT
            );

            CREATE TABLE IF NOT EXISTS llm_analyses (
                id            INTEGER PRIMARY KEY AUTOINCREMENT,
                member_id     TEXT NOT NULL REFERENCES members(id),
                created_at    TEXT NOT NULL,
                window_days   INTEGER,
                provider      TEXT,
                model         TEXT,
                response_json TEXT,
                flagged_count INTEGER
            );
        """)


# --- Upserts ---

def upsert_member(member_id: str, name: str) -> None:
    with get_connection() as conn:
        conn.execute(
            "INSERT OR REPLACE INTO members(id, name) VALUES (?, ?)",
            (member_id, name),
        )


def upsert_item(item: dict, member_id: str) -> None:
    connector = item.get("connector") or {}
    with get_connection() as conn:
        conn.execute(
            """INSERT OR REPLACE INTO items
               (item_id, member_id, connector_id, connector_name, status, last_synced_at)
               VALUES (?, ?, ?, ?, ?, ?)""",
            (
                item["id"], member_id,
                connector.get("id"), connector.get("name"),
                item.get("status"),
                datetime.now(timezone.utc).isoformat(),
            ),
        )


def upsert_accounts(accounts: list, item_id: str, member_id: str) -> None:
    with get_connection() as conn:
        for a in accounts:
            cd = a.get("creditData") or {}
            conn.execute(
                """INSERT OR REPLACE INTO accounts VALUES
                   (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)""",
                (
                    a["id"], item_id, member_id,
                    a.get("name"), a.get("type"), a.get("subtype"), a.get("number"),
                    a.get("balance"), a.get("currencyCode"), a.get("owner"),
                    cd.get("creditLimit"), cd.get("availableCreditLimit"),
                    cd.get("balanceCloseDate"), cd.get("balanceDueDate"),
                    cd.get("minimumTotalAmountDue"), cd.get("brand"),
                    json.dumps(a),
                ),
            )


def upsert_transactions(transactions: list, account_id: str, member_id: str) -> None:
    with get_connection() as conn:
        for t in transactions:
            merchant = t.get("merchant") or {}
            conn.execute(
                """INSERT OR REPLACE INTO transactions VALUES
                   (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)""",
                (
                    t["id"], account_id, member_id,
                    t.get("description"), t.get("descriptionRaw"),
                    t.get("amount"), t.get("amountInAccountCurrency"),
                    t.get("currencyCode"), t.get("date"),
                    t.get("type"), t.get("operationType"),
                    t.get("category"), t.get("categoryId"),
                    t.get("status"), t.get("balance"),
                    t.get("providerCode"), t.get("providerId"),
                    merchant.get("name"), merchant.get("cnpj"),
                    json.dumps(t.get("paymentData")),
                    json.dumps(t.get("creditCardMetadata")),
                    json.dumps(t),
                ),
            )


def upsert_investments(investments: list, item_id: str, member_id: str) -> None:
    with get_connection() as conn:
        for inv in investments:
            conn.execute(
                """INSERT OR REPLACE INTO investments VALUES
                   (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)""",
                (
                    inv["id"], item_id, member_id,
                    inv.get("name"), inv.get("type"), inv.get("subtype"),
                    inv.get("rawType"), inv.get("code"), inv.get("isinCode"),
                    inv.get("value"), inv.get("quantity"), inv.get("balance"),
                    inv.get("taxes"), inv.get("taxes2"), inv.get("currencyCode"),
                    inv.get("date"), inv.get("dueDate"),
                    inv.get("annualRate"), inv.get("lastMonthRate"),
                    inv.get("lastTwelveMonthsRate"),
                    inv.get("issuer"), inv.get("issuerCnpj"),
                    inv.get("status"), inv.get("number"),
                    json.dumps(inv),
                ),
            )


def upsert_identity(identity: dict, item_id: str, member_id: str) -> None:
    with get_connection() as conn:
        conn.execute(
            """INSERT OR REPLACE INTO identity VALUES (?,?,?,?,?,?,?,?,?,?)""",
            (
                identity["id"], item_id, member_id,
                identity.get("fullName"), identity.get("cpfNumber"),
                identity.get("birthDate"),
                json.dumps(identity.get("phoneNumbers")),
                json.dumps(identity.get("emails")),
                json.dumps(identity.get("addresses")),
                json.dumps(identity),
            ),
        )


def upsert_credit_card_bills(bills: list, account_id: str, member_id: str) -> None:
    with get_connection() as conn:
        for b in bills:
            conn.execute(
                """INSERT OR REPLACE INTO credit_card_bills VALUES
                   (?,?,?,?,?,?,?,?,?,?,?)""",
                (
                    b["id"], account_id, member_id,
                    b.get("dueDate"), b.get("closingDate"),
                    b.get("balance"), b.get("previousBalance"),
                    b.get("paymentAmount"), b.get("minimumPayment"),
                    b.get("currencyCode"), json.dumps(b),
                ),
            )


def upsert_loans(loans: list, item_id: str, member_id: str) -> None:
    with get_connection() as conn:
        for loan in loans:
            conn.execute(
                """INSERT OR REPLACE INTO loans VALUES
                   (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)""",
                (
                    loan["id"], item_id, member_id,
                    loan.get("number"), loan.get("type"), loan.get("status"),
                    loan.get("contractedAmount"), loan.get("outstandingBalance"),
                    loan.get("installmentAmount"), loan.get("totalInstallments"),
                    loan.get("paidInstallments"), loan.get("creditDate"),
                    loan.get("dueDate"), loan.get("interestRate"),
                    loan.get("currencyCode"), json.dumps(loan),
                ),
            )


def save_llm_analysis(member_id: str, window_days: int, provider: str, model: str,
                      response: dict, flagged_count: int) -> None:
    with get_connection() as conn:
        conn.execute(
            """INSERT INTO llm_analyses
               (member_id, created_at, window_days, provider, model, response_json, flagged_count)
               VALUES (?, ?, ?, ?, ?, ?, ?)""",
            (
                member_id,
                datetime.now(timezone.utc).isoformat(),
                window_days, provider, model,
                json.dumps(response), flagged_count,
            ),
        )


# --- Queries ---

def get_all_members() -> list[dict]:
    with get_connection() as conn:
        return [dict(r) for r in conn.execute("SELECT * FROM members ORDER BY name")]


def get_accounts_for_member(member_id: str) -> list[dict]:
    with get_connection() as conn:
        return [dict(r) for r in conn.execute(
            "SELECT * FROM accounts WHERE member_id = ? ORDER BY type, name",
            (member_id,),
        )]


def get_transactions_for_member(member_id: str, days: int = 30) -> list[dict]:
    with get_connection() as conn:
        return [dict(r) for r in conn.execute(
            """SELECT * FROM transactions
               WHERE member_id = ?
                 AND date >= date('now', ? || ' days')
               ORDER BY date DESC""",
            (member_id, f"-{days}"),
        )]


def get_investments_for_member(member_id: str) -> list[dict]:
    with get_connection() as conn:
        return [dict(r) for r in conn.execute(
            "SELECT * FROM investments WHERE member_id = ? ORDER BY type, name",
            (member_id,),
        )]


def get_loans_for_member(member_id: str) -> list[dict]:
    with get_connection() as conn:
        return [dict(r) for r in conn.execute(
            "SELECT * FROM loans WHERE member_id = ? ORDER BY due_date",
            (member_id,),
        )]


def get_identity_for_member(member_id: str) -> dict | None:
    with get_connection() as conn:
        row = conn.execute(
            "SELECT * FROM identity WHERE member_id = ? LIMIT 1",
            (member_id,),
        ).fetchone()
        return dict(row) if row else None


def get_last_sync_time(member_id: str) -> str | None:
    with get_connection() as conn:
        row = conn.execute(
            "SELECT MAX(last_synced_at) FROM items WHERE member_id = ?",
            (member_id,),
        ).fetchone()
        return row[0] if row else None


def get_latest_analysis(member_id: str) -> dict | None:
    with get_connection() as conn:
        row = conn.execute(
            """SELECT * FROM llm_analyses WHERE member_id = ?
               ORDER BY created_at DESC LIMIT 1""",
            (member_id,),
        ).fetchone()
        return dict(row) if row else None


if __name__ == "__main__":
    init_schema()
    print(f"Schema initialised at: {DB_PATH}")
    with get_connection() as conn:
        tables = conn.execute(
            "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name"
        ).fetchall()
        print("Tables:", [t[0] for t in tables])
