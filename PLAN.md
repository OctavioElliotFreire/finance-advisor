# Family Finance — Updated Architecture Plan

## Product Goal

Family Finance is a multi-user financial application for web, Android, and iOS.

It connects to Brazilian financial institutions through Pluggy Open Finance, stores normalized financial data, and displays:

* Bank accounts
* Credit cards
* Transactions
* Investments
* Loans
* Cash flow
* Balance history
* Financial anomalies

The application supports multiple independent families. Each family can only access its own financial data.

---

## Local Machine Setup Status (2026-07-23, resolved)

All Milestone 1 prerequisite installs are now confirmed working.

* **Docker Desktop** — 29.6.2, engine running, `docker run hello-world` passes. Virtualization is enabled and the `docker-desktop` WSL2 distro is present.
* **WSL2** — present (`docker-desktop` distro).
* **Flutter SDK** — cloned at `C:\src\flutter` (3.44.7 stable), `flutter --version` runs. Added `C:\src\flutter\bin` to the permanent user PATH.

Proceeding with Milestone 1 (scaffold `frontend/`, `backend/`, `docker-compose.yml`).

---

## Transition From MVP (complete)

The repo originally kept the old Streamlit/SQLite MVP (`app.py`, `db.py`, `sync.py`, `llm/`, `pages/`) running in the repo root alongside the rewrite, per the plan below, until the first vertical slice worked end-to-end on the new stack.

That slice was verified 2026-07-28 (real Supabase login, real household, a real Pluggy sandbox connection synced through the real `sync_worker`, viewed on Flutter Web) — see "First Vertical Slice" below. The old MVP files were deleted at that point; `db.py`/`sync.py`/`llm/base.py`'s normalization and LLM-abstraction logic had already been ported into `backend/app/` during milestones 5-9.

---

## Selected Technology Stack

### Frontend

* Flutter
* Dart
* Flutter Web
* Flutter Android
* Flutter iOS

Flutter provides one frontend codebase for web and mobile.

### Backend

* Python
* FastAPI
* SQLAlchemy
* Alembic
* Pydantic

### Database

* Supabase-hosted PostgreSQL for shared environments
* Local PostgreSQL through Docker for development and testing
* PostgreSQL as the only database engine
* No SQLite dependency in the new application

### Authentication

* Supabase Auth initially
* Internal application-user records to reduce authentication-provider lock-in

### Background Processing

* Python sync worker
* Job queue
* Pluggy webhook handler
* User-triggered and scheduled synchronization

### External Services

* Pluggy Open Finance
* Anthropic or Gemini
* Supabase Auth
* Supabase PostgreSQL

### Development Infrastructure

* Docker
* Docker Compose
* Local PostgreSQL container
* Optional local worker and API containers
* Optional Redis container when a dedicated job queue is introduced

---

## High-Level Architecture

```text
Flutter Web / Android / iOS
              |
              | HTTPS and JSON
              v
        Python FastAPI
              |
      +-------+--------+
      |                |
      v                v
Supabase PostgreSQL   Job Queue
                       |
                       v
                Python Sync Worker
                       |
             +---------+---------+
             |                   |
             v                   v
         Pluggy API          LLM Provider
```

Flutter never connects directly to PostgreSQL, Pluggy, Anthropic, or Gemini.

Flutter communicates only with FastAPI.

FastAPI and the Python worker communicate with PostgreSQL through standard PostgreSQL connections.

---

## Local Development Architecture

During development:

```text
Flutter running locally
          |
          | HTTP
          v
FastAPI running locally or in Docker
          |
          v
PostgreSQL running in Docker
          ^
          |
Python worker running locally or in Docker
```

Docker is used primarily to run backend services consistently.

Flutter should normally run directly on the developer's computer because it needs access to:

* Android emulators
* iOS simulators
* Browsers
* Native build tools
* Device debugging

---

## Why Docker Is Included

Docker is not part of the product's business logic. It is a development and deployment tool.

Docker provides:

* A consistent PostgreSQL version
* Reproducible local setup
* Isolation from the operating system
* Disposable test databases
* Easier onboarding for new developers
* One command to start backend services
* A local environment similar to production
* Fewer configuration differences between computers

Without Docker, each developer would need to install and configure PostgreSQL manually.

---

## Initial Docker Strategy

Start by putting only PostgreSQL in Docker.

Run Flutter, FastAPI, and the Python worker directly on the development machine.

```text
Local installation:
- Flutter
- Python virtual environment
- FastAPI
- Sync worker

Docker:
- PostgreSQL
```

Later, containerize FastAPI and the worker as well:

```text
Local installation:
- Flutter

Docker:
- PostgreSQL
- FastAPI
- Sync worker
- Redis or another queue
```

This gradual approach avoids unnecessary complexity during the first stage.

---

## Docker Compose Development Environment

Initial `docker-compose.yml`:

```yaml
services:
  db:
    image: postgres:17
    environment:
      POSTGRES_DB: family_finance
      POSTGRES_USER: finance_app
      POSTGRES_PASSWORD: local-development-only
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test:
        - CMD-SHELL
        - pg_isready -U finance_app -d family_finance
      interval: 5s
      timeout: 5s
      retries: 10

volumes:
  postgres_data:
```

Start PostgreSQL:

```bash
docker compose up -d db
```

Stop PostgreSQL:

```bash
docker compose down
```

Remove the local database volume when a clean database is required:

```bash
docker compose down -v
```

This command deletes the local development data and should be used carefully.

---

## Expanded Docker Compose Environment

Later, Docker Compose may include:

```yaml
services:
  db:
    image: postgres:17
    environment:
      POSTGRES_DB: family_finance
      POSTGRES_USER: finance_app
      POSTGRES_PASSWORD: local-development-only
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test:
        - CMD-SHELL
        - pg_isready -U finance_app -d family_finance
      interval: 5s
      timeout: 5s
      retries: 10

  api:
    build:
      context: ./backend
    command:
      - uvicorn
      - app.main:app
      - --host
      - 0.0.0.0
      - --port
      - "8000"
      - --reload
    environment:
      DATABASE_URL: postgresql+psycopg://finance_app:local-development-only@db:5432/family_finance
    ports:
      - "8000:8000"
    volumes:
      - ./backend:/app
    depends_on:
      db:
        condition: service_healthy

  worker:
    build:
      context: ./backend
    command:
      - python
      - -m
      - app.workers.sync_worker
    environment:
      DATABASE_URL: postgresql+psycopg://finance_app:local-development-only@db:5432/family_finance
    volumes:
      - ./backend:/app
    depends_on:
      db:
        condition: service_healthy

volumes:
  postgres_data:
```

The API and worker use the same backend code but run as separate processes.

---

## Local Development Commands

Start PostgreSQL:

```bash
docker compose up -d db
```

Create and activate the Python environment:

```bash
cd backend
python -m venv .venv
```

macOS or Linux:

```bash
source .venv/bin/activate
```

Windows:

```bash
.venv\Scripts\activate
```

Install backend dependencies:

```bash
pip install -r requirements.txt
```

Apply database migrations:

```bash
alembic upgrade head
```

Run FastAPI:

```bash
uvicorn app.main:app --reload
```

Run the worker in another terminal:

```bash
python -m app.workers.sync_worker
```

Run Flutter:

```bash
cd frontend
flutter run
```

---

## Local API Addresses

Flutter Web:

```text
http://localhost:8000
```

iOS Simulator:

```text
http://localhost:8000
```

Android Emulator:

```text
http://10.0.2.2:8000
```

Physical mobile device:

```text
http://<development-computer-local-ip>:8000
```

For physical-device testing, FastAPI may need to listen on all local interfaces:

```bash
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

The computer firewall must allow access to port `8000` from the local network.

---

## Production Communication

Local development may use HTTP.

Production must use HTTPS:

```text
Flutter
   |
   | HTTPS
   v
FastAPI
```

Example production endpoint:

```text
https://api.familyfinance.example
```

HTTPS protects:

* Authentication tokens
* Financial records
* Sync requests
* Dashboard responses
* User information
* Anomaly explanations

---

## Frontend Responsibilities

Flutter is responsible for:

* Login and registration screens
* Responsive web and mobile layouts
* Navigation
* Dashboard presentation
* Charts
* Tables
* Forms
* Transaction lists
* Investment views
* Connection-management screens
* Sync-status presentation
* Currency and date formatting
* Loading and error states
* Lightweight visual calculations

Flutter may perform presentation-only calculations such as:

* Chart percentages
* UI sorting of small datasets
* Positive or negative indicators
* Layout calculations
* Animation values
* Temporary form calculations

Flutter should not contain:

* Database credentials
* Supabase service-role keys
* Pluggy secrets
* LLM API keys
* PostgreSQL queries
* Tenant-isolation rules
* Official financial calculation rules
* LLM prompt construction
* Background synchronization logic

---

## Backend Responsibilities

FastAPI is the trusted application boundary.

It is responsible for:

* Validating authentication tokens
* Resolving users to internal application users
* Checking household membership
* Enforcing roles and permissions
* Querying PostgreSQL
* Running financial calculations
* Returning stable API responses
* Creating Pluggy connection tokens
* Receiving Pluggy webhooks
* Starting synchronization jobs
* Preparing LLM prompts
* Redacting sensitive information
* Applying rate limits
* Creating audit records
* Handling exports
* Handling data and account deletion

Every protected request must determine:

```text
Who is the user?
Which household can the user access?
Does the user have permission for this action?
```

---

## Calculation Responsibilities

### PostgreSQL

PostgreSQL performs efficient operations such as:

* Filtering
* Grouping
* Summing
* Counting
* Sorting
* Pagination
* Date-range queries
* Category aggregation

Example:

```sql
SELECT
    category,
    SUM(amount) AS total
FROM transactions
WHERE household_id = :household_id
  AND transaction_date >= :start_date
  AND transaction_date < :end_date
GROUP BY category;
```

### Python Backend

Python performs business logic such as:

* Total account balance
* Monthly income
* Monthly expenses
* Net cash flow
* Savings rate
* Credit-card exposure
* Investment allocation
* Debt totals
* Household summaries
* Anomaly detection
* Forecasting
* Prompt preparation

### Flutter

Flutter receives finalized values and displays them through:

* Cards
* Charts
* Tables
* Labels
* Progress indicators
* Responsive layouts

The backend remains the official source of financial truth.

---

## Supabase Usage

### Use Supabase For

* Managed PostgreSQL
* Supabase Auth
* Automated backups according to the selected plan
* Database monitoring
* Connection pooling
* Optional noncritical realtime updates

### Avoid Using Supabase For

* Core business logic
* Pluggy synchronization
* LLM processing
* Financial calculations
* Essential Edge Functions
* Direct Flutter access to financial tables
* Essential workflows that depend on Realtime
* Unabstracted file storage
* Privileged service-role operations from Flutter

---

## Migration Principle

Supabase should be treated mainly as:

> A managed PostgreSQL and authentication provider.

FastAPI must remain the permanent boundary between Flutter and financial data.

A future database migration should look like:

```text
Supabase PostgreSQL
        |
        | PostgreSQL export and restore
        v
Amazon RDS PostgreSQL
```

The application should then require primarily:

* A new database server
* Data export and restoration
* A changed `DATABASE_URL`
* Backend redeployment
* Migration validation

Flutter should continue using the same API endpoints.

---

## Authentication Design

Supabase Auth identifies the external authentication account.

The application maintains its own internal user record:

```text
Supabase Auth user
        |
        v
Application user
        |
        v
Household membership
        |
        v
Financial records
```

Recommended table:

```sql
CREATE TABLE app_users (
    id UUID PRIMARY KEY,
    auth_provider VARCHAR(50) NOT NULL,
    auth_provider_user_id TEXT NOT NULL,
    email TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    UNIQUE (auth_provider, auth_provider_user_id)
);
```

This allows a future move to another authentication provider without rewriting financial relationships.

---

## Multi-Tenant Data Model

Core tables:

```text
app_users
households
household_members
household_settings
pluggy_connections
accounts
transactions
sync_jobs
```

Later tables:

```text
credit_cards
credit_card_bills
investments
loans
balance_snapshots
anomaly_flags
audit_events
```

`pluggy_connections` carries a nullable `created_by_app_user_id` FK to
`app_users.id` (added 2026-07-30), attributing each bank connection to the
household member who created it — nullable so legacy rows created before
this column existed don't need a backfill. `GET/POST
/v1/households/{id}/connections` responses include a nested `created_by
{id, email}` object (`null` for unattributed legacy connections) so the
frontend can group a household's connections per member (e.g. "Member A:
Bank X, Bank Y" / "Member B: Bank Z") instead of a flat, unowned list.

Every sensitive financial table should contain:

```sql
household_id UUID NOT NULL
```

Example:

```sql
CREATE TABLE transactions (
    id UUID PRIMARY KEY,
    household_id UUID NOT NULL REFERENCES households(id),
    account_id UUID NOT NULL REFERENCES accounts(id),
    pluggy_transaction_id TEXT NOT NULL,
    description TEXT,
    amount NUMERIC(18, 2) NOT NULL,
    currency_code VARCHAR(3) NOT NULL DEFAULT 'BRL',
    transaction_date DATE NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    UNIQUE (household_id, pluggy_transaction_id)
);
```

---

## Household Isolation

The backend authorizes every household request.

Example flow:

```text
Flutter sends access token
        |
        v
FastAPI validates token
        |
        v
FastAPI finds application user
        |
        v
FastAPI checks household membership
        |
        v
Repository receives authorized household_id
        |
        v
PostgreSQL returns only household rows
```

A repository method should require tenant context:

```python
class TransactionRepository:
    def list_for_household(
        self,
        household_id,
        start_date,
        end_date,
    ):
        ...
```

Avoid unrestricted methods such as:

```python
list_all_transactions()
```

Recommended defense layers:

1. Supabase authentication
2. FastAPI authorization
3. Household-scoped repository methods
4. Database constraints
5. Optional PostgreSQL Row-Level Security
6. Tenant-isolation tests

---

## Household Roles

Initial roles:

```text
owner
member
viewer
```

Example permissions:

| Action           | Owner |   Member | Viewer |
| ---------------- | ----: | -------: | -----: |
| View dashboard   |   Yes |      Yes |    Yes |
| Trigger sync     |   Yes |      Yes |     No |
| Add connection   |   Yes | Optional |     No |
| Invite users     |   Yes |       No |     No |
| Delete household |   Yes |       No |     No |

Permissions must be enforced by FastAPI, not only hidden in Flutter.

"Invite users" (added 2026-07-31) is implemented as `POST
/v1/households/{id}/members`, owner-only, by email — **existing users
only**: if the email has no `app_users` account yet (no prior Supabase
login), the invite 404s with a message asking them to sign up first, rather
than creating a pending invite or sending an email itself. This sidesteps
Supabase's free-tier email-send rate limit (see `CLAUDE.md`) entirely for
this feature. Inviting someone with no account yet, changing a member's
role after invite, and removing a member are all explicitly deferred.

---

## API Design

Recommended initial endpoints:

```text
GET    /v1/me
GET    /v1/households
POST   /v1/households

GET    /v1/dashboard
GET    /v1/accounts
GET    /v1/transactions
GET    /v1/investments
GET    /v1/loans

GET    /v1/connections
POST   /v1/connections/token
POST   /v1/connections
DELETE /v1/connections/{connection_id}

POST   /v1/sync
GET    /v1/sync/{job_id}

GET    /v1/anomalies
POST   /v1/anomalies/{anomaly_id}/explain
PATCH  /v1/anomalies/{anomaly_id}

POST   /v1/exports
DELETE /v1/account
```

Flutter should depend on these endpoints, not on Supabase table names.

Actual connections responses (`GET`/`POST .../connections`) include a
nested `created_by {id, email}` object identifying which household member
created the connection — see Multi-Tenant Data Model above.

Also actually implemented, not in the sketch above:
`GET`/`POST /v1/households/{id}/members` — list/invite household members
(owner-only invite, existing-users-only, see Household Roles above).

**Pluggy web Connect widget (added 2026-08-05):** mobile has always used the
real `flutter_pluggy_connect` package; web previously showed a stub snackbar
("use the mobile app for now"). Web now uses Pluggy's own hosted Connect
Widget (`https://cdn.pluggy.ai/pluggy-connect/latest/pluggy-connect.js`,
the `pluggy-connect-sdk` package's vanilla-JS API) via a `dart:js_interop`
binding in `frontend/lib/core/web/open_pluggy_connect_web.dart`, gated
behind the same `dart.library.html` conditional-import pattern already used
for `invite_redirect_cleanup_web.dart`. `connections_view.dart`'s `_connect()`
calls it for web, the existing `PluggyConnectScreen` for mobile — both paths
converge on the same `_viewModel.registerConnection(itemId)` call, so the
backend needed zero changes for this feature itself. Verified end-to-end
with a real Pluggy sandbox connection (item created, listed in the app).

Two real bugs surfaced during that first browser verification, both fixed:
- `PluggyClient`'s `httpx.AsyncClient()` calls had no explicit timeout,
  defaulting to httpx's 5s. A real `/auth` call to Pluggy took 4.8-8s from
  this dev machine, intermittently exceeding it — the resulting unhandled
  500 has no CORS headers, which the browser reports as a misleading CORS
  error, masking the real cause (a timeout, not a cross-origin problem).
  Fixed by setting `REQUEST_TIMEOUT = 30.0` on every client call in
  `backend/app/sync/pluggy_client.py`. Affects mobile too, not just web.
- The widget's `includeSandbox` option (default `false` upstream, on both
  the web SDK and `flutter_pluggy_connect`) was never set on either
  platform, so only real/production connectors were offered — no sandbox
  "Pluggy Bank" test connector, and selecting the one real connector shown
  opened a genuine Auth0 login. Added `AppConfig.pluggyIncludeSandbox`
  (`frontend/lib/core/config/app_config.dart`, defaults `true` via
  `bool.fromEnvironment('PLUGGY_INCLUDE_SANDBOX', defaultValue: true)`) and
  wired it into both `PluggyConnectScreen` (mobile) and
  `open_pluggy_connect_web.dart` (web). **Must be set to `false` via `.env`
  before any real bank connectors go live in production** — until then this
  bug was silently hiding the entire sandbox catalog on both platforms.

---

## Synchronization Flow

```text
User presses Sync Now
        |
        v
Flutter sends POST /v1/sync
        |
        v
FastAPI validates access
        |
        v
FastAPI creates sync job
        |
        v
Job enters queue
        |
        v
Python worker calls Pluggy
        |
        v
Worker normalizes data
        |
        v
Worker upserts PostgreSQL records
        |
        v
Worker updates sync status
        |
        v
Flutter refreshes dashboard
```

Recommended statuses:

```text
queued
running
completed
failed
partially_completed
```

Synchronization must be idempotent.

Recommended unique constraints:

```sql
UNIQUE (household_id, pluggy_item_id)
UNIQUE (household_id, pluggy_account_id)
UNIQUE (household_id, pluggy_transaction_id)
```

The worker must never keep a database transaction open while waiting for Pluggy or an LLM response.

---

## Job Queue Strategy

For the first version, a simple database-backed queue may be sufficient.

Later, introduce:

* Redis with RQ, Celery, or Dramatiq
* Amazon SQS
* Another managed queue

Docker Compose can run Redis locally when it becomes necessary.

Example future service:

```yaml
redis:
  image: redis:7
  ports:
    - "6379:6379"
```

The queue separates heavy synchronization work from normal API requests.

---

## LLM Architecture

Flutter never calls the LLM provider directly.

```text
Flutter requests explanation
        |
        v
FastAPI verifies household access
        |
        v
Backend loads relevant records
        |
        v
Backend removes sensitive fields
        |
        v
Backend constructs prompt
        |
        v
Backend calls Anthropic or Gemini
        |
        v
Explanation is stored or returned
```

Begin with deterministic anomaly rules:

* Unusually large transaction
* Duplicate transaction
* New merchant
* Unexpected recurring payment
* Large category deviation
* Spending outside normal behavior

The LLM should explain selected anomaly candidates rather than process a full financial history.

**Per-bank scoping (added 2026-08-05):** once a household can have multiple
Pluggy connections with restricted-access members (see Household Roles
above), the "unusually large transaction" and "new merchant" rules' baselines
are computed **per bank connection**, not household-wide — otherwise one
high-volume bank's history would skew what counts as "normal" for a
different bank in the same household. "Duplicate transaction" and
"unexpected recurring payment" were already scoped to a single account,
which is even finer-grained and needed no change. "Large category deviation"
intentionally stays household-wide (a spending category spans banks by
nature) and is already excluded entirely from restricted members' view at
the API layer (`app/api/anomalies.py`'s `_get_flag_or_404`/`list_anomalies` —
flags with no `transaction_id` can't be attributed to a connection). See
`app/services/anomaly_rules.py`'s `_household_debits_by_connection`.

---

## Repository Structure

```text
family-finance/
├── frontend/
│   ├── lib/
│   │   ├── app/
│   │   ├── core/
│   │   └── features/
│   ├── android/
│   ├── ios/
│   ├── web/
│   └── pubspec.yaml
│
├── backend/
│   ├── app/
│   │   ├── api/
│   │   ├── auth/
│   │   ├── database/
│   │   ├── models/
│   │   ├── schemas/
│   │   ├── repositories/
│   │   ├── services/
│   │   ├── sync/
│   │   ├── workers/
│   │   ├── llm/
│   │   ├── storage/
│   │   └── main.py
│   ├── migrations/
│   ├── tests/
│   ├── requirements.txt
│   └── Dockerfile
│
├── infrastructure/
│   ├── docker/
│   ├── supabase/
│   ├── scripts/
│   └── future-aws/
│
├── docker-compose.yml
├── .env.example
└── README.md
```

The old MVP files (`app.py`, `db.py`, `sync.py`, `llm/`, `pages/`, `finance.db`) have been removed — see "Transition From MVP" above.

---

## Environment Configuration

Local backend:

```env
DATABASE_URL=postgresql+psycopg://finance_app:local-development-only@localhost:5432/family_finance

AUTH_PROVIDER=supabase
SUPABASE_URL=...
SUPABASE_JWT_ISSUER=...
SUPABASE_JWT_AUDIENCE=...

PLUGGY_CLIENT_ID=...
PLUGGY_CLIENT_SECRET=...

LLM_PROVIDER=anthropic
ANTHROPIC_API_KEY=...
GEMINI_API_KEY=...
```

When FastAPI runs inside Docker, the database hostname changes from `localhost` to the Docker service name:

```env
DATABASE_URL=postgresql+psycopg://finance_app:local-development-only@db:5432/family_finance
```

Production uses the Supabase connection string.

---

## Database Migrations

Use Alembic for every schema change.

```text
backend/
└── migrations/
    └── versions/
        ├── 001_initial_schema.py
        ├── 002_add_sync_jobs.py
        ├── 003_add_balance_snapshots.py
        └── 004_add_anomaly_flags.py
```

The same migrations should work against:

* Docker PostgreSQL
* Test PostgreSQL
* Supabase development
* Supabase production
* Future AWS RDS

Do not manually alter production tables without creating a corresponding migration.

---

## Testing Strategy

### Flutter Tests

* Widget tests
* Responsive layout tests
* API-client tests
* Authentication-state tests
* Loading and error-state tests
* Mocked dashboard tests

### Backend Tests

* API endpoint tests
* Authentication tests
* Authorization tests
* Financial calculation tests
* Pluggy normalization tests
* Sync idempotency tests
* LLM-redaction tests
* Migration tests
* Repository tests against PostgreSQL

### Docker-Based Integration Tests

Docker should provide a clean PostgreSQL database for integration tests.

Example process:

```text
Start clean PostgreSQL container
        |
        v
Run Alembic migrations
        |
        v
Insert test households and users
        |
        v
Run backend tests
        |
        v
Destroy test database
```

### Critical Tenant-Isolation Tests

```text
Family A cannot read Family B's accounts.
Family A cannot read Family B's transactions.
Family A cannot sync Family B's connection.
Family A cannot access Family B's anomalies.
Family A cannot export Family B's data.
A viewer cannot modify restricted resources.
A removed user immediately loses access.
```

These tests should block deployment when they fail.

---

## Development, Test, and Production Databases

Use separate databases for every environment.

```text
Development:
Local PostgreSQL in Docker

Automated testing:
Temporary PostgreSQL database or container

Shared development:
Supabase development project

Production:
Separate Supabase production project
```

Never use production data for local development.

Use synthetic or sanitized data when testing.

---

## Backup and Recovery

For production:

* Enable Supabase backups.
* Keep periodic independent encrypted exports.
* Test restoration into clean PostgreSQL.
* Back up before destructive migrations.
* Document the recovery procedure.
* Keep credentials outside source control.
* Separate development and production projects.

Docker volumes are convenient for local persistence but are not a production backup strategy.

---

## Deployment Strategy

### Development

```text
Flutter locally
FastAPI locally
Worker locally
PostgreSQL in Docker
```

### Private Beta

```text
Flutter Web hosting
Android and iOS test builds
Hosted FastAPI
Hosted Python worker
Supabase PostgreSQL
Supabase Auth
Basic job queue
Daily backups
Basic monitoring
```

### Production

```text
Multiple API instances
Multiple workers
Managed job queue
Supabase PostgreSQL
HTTPS
Centralized logs
Monitoring and alerts
Rate limiting
Audit events
Backup and restore procedures
```

---

## Migration Readiness

To keep future migration simple:

* Use standard PostgreSQL.
* Use SQLAlchemy.
* Use Alembic.
* Keep FastAPI between Flutter and the database.
* Avoid direct Flutter queries to financial tables.
* Keep business logic outside Supabase.
* Keep authentication behind an interface.
* Keep file storage behind an interface.
* Make Realtime optional.
* Test PostgreSQL exports and restores regularly.
* Run the backend against local Docker PostgreSQL.

Periodically verify:

```text
Can the Supabase database be exported?
Can it be restored into Docker PostgreSQL?
Does FastAPI work by changing only DATABASE_URL?
Do all migrations run outside Supabase?
Does Flutter continue working without database-specific changes?
```

---

## Updated Milestones

### Milestone 1 — Local Development Foundation

* Create monorepo.
* Create Flutter project.
* Create FastAPI project.
* Add PostgreSQL to Docker Compose.
* Configure SQLAlchemy.
* Configure Alembic.
* Create `.env.example`.
* Confirm FastAPI connects to Docker PostgreSQL.

### Milestone 2 — Supabase Foundation

* Create Supabase development project.
* Enable Supabase Auth.
* Configure Supabase PostgreSQL.
* Run Alembic migrations against Supabase.
* Implement Supabase token validation.
* Create internal `app_users` records.

### Milestone 3 — Household Isolation

* Create households.
* Create household memberships.
* Add owner, member, and viewer roles.
* Add `household_id` to sensitive tables.
* Implement household authorization.
* Add tenant-isolation tests.

### Milestone 4 — Flutter Authentication

* Build registration.
* Build login.
* Store access tokens securely.
* Send tokens to FastAPI.
* Implement `GET /v1/me`.
* Implement household creation and selection.

### Milestone 5 — Pluggy Integration

* Port the Pluggy Python client.
* Create connection-token endpoint.
* Integrate Pluggy Connect Widget in Flutter.
* Store connections by household.
* Create initial sync jobs.

### Milestone 6 — Synchronization Worker

* Create Python worker process.
* Implement account synchronization.
* Implement transaction synchronization.
* Add batch upserts.
* Add retry handling.
* Add sync status.
* Confirm idempotency.

### Milestone 7 — Core Dashboard

* Build account overview.
* Build recent transactions.
* Build monthly cash flow.
* Build responsive mobile and web layouts.
* Add sync status.
* Add currency and locale formatting.

### Milestone 8 — Extended Finance Features

* Credit cards
* Credit-card bills
* Investments
* Loans
* Balance history
* Category breakdowns

### Milestone 9 — Anomaly Detection

* Deterministic anomaly rules
* Candidate scoring
* Sensitive-data redaction
* LLM provider abstraction
* Explanations and user feedback

### Milestone 10 — Production Readiness

* Rate limiting
* Audit logs
* Monitoring
* Alerts
* Backups
* Restore tests
* Export
* Deletion
* Privacy controls
* Security testing

### Milestone 11 — Migration Readiness Test

* Export Supabase PostgreSQL.
* Restore into Docker PostgreSQL.
* Run Alembic validation.
* Run FastAPI against the restored database.
* Run tenant-isolation tests.
* Confirm Flutter requires no database-related changes.
* Document the future AWS RDS migration procedure.

---

## First Vertical Slice (verified 2026-07-28)

The first complete feature should be:

```text
Register with Supabase Auth
        |
        v
FastAPI creates app_users record
        |
        v
User creates household
        |
        v
User connects one Pluggy institution
        |
        v
Python worker synchronizes accounts and transactions
        |
        v
Data is stored in PostgreSQL
        |
        v
FastAPI calculates dashboard summary
        |
        v
Flutter displays balance and recent transactions
```

Success criterion:

> An authenticated user can connect one institution, synchronize real financial data, and view only their household's information on Flutter Web and mobile.

**Verified 2026-07-28** against the real Pluggy sandbox API (not fakes): registered a real Supabase user, created a household, connected a real Pluggy sandbox item (connector `2`, "Pluggy Bank"), ran the real sync worker, and confirmed real accounts/transactions/investments/loans on Flutter Web. Mobile (Android/iOS) was not verified — no Android SDK/emulator/device or macOS/Xcode was available in that environment; the user explicitly accepted Web-only verification as sufficient rather than block on installing mobile tooling.

The old MVP (`app.py`, `db.py`, `sync.py`, `llm/`, `pages/`, `finance.db`) was retired at this point.

---

## Immediate Next Steps

1. Create the monorepo:

```text
frontend/
backend/
infrastructure/
```

2. Create the Flutter project.

3. Create the FastAPI project.

4. Add PostgreSQL to `docker-compose.yml`.

5. Start PostgreSQL with:

```bash
docker compose up -d db
```

6. Configure SQLAlchemy and Alembic.

7. Create the initial tables:

```text
app_users
households
household_members
pluggy_connections
accounts
transactions
sync_jobs
```

8. Create the Supabase development project.

9. Implement the authentication-provider interface.

10. Implement Supabase token validation.

11. Build:

```http
GET /v1/me
```

12. Build household creation and authorization.

13. Add the first tenant-isolation tests.

14. Port the Pluggy client into the Python backend, reusing normalization logic from the existing `db.py`/`sync.py`.

15. Implement the first account and transaction synchronization job.

---

## Final Architecture Decision

The initial system will use:

```text
Flutter for web and mobile
FastAPI for the backend API
Python for Pluggy synchronization and LLM processing
Supabase Auth for authentication
Supabase PostgreSQL for hosted data
Docker PostgreSQL for local development and testing
SQLAlchemy for database access
Alembic for schema migrations
A separate Python worker for synchronization
```

Docker supports the local backend environment but does not replace Supabase or Flutter.

FastAPI remains the permanent boundary between Flutter and financial data. Supabase accelerates the initial product, while standard PostgreSQL, Docker-based testing, stable APIs, and provider abstractions preserve a controlled migration path.
