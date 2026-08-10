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

"Invite users" (added 2026-07-31, extended since) is implemented as `POST
/v1/households/{id}/members`, owner-only, by email. If the email already
has an `app_users` account, it's added directly. If not, it now creates a
`HouseholdInvite` row and sends an actual invite email via
`invite_sender.invite_user_by_email` (`backend/app/api/household_members.py`)
— the recipient accepts through `POST /v1/invites/{token}/accept`
(`backend/app/api/invites.py`) and the Flutter `/accept-invite` route
(`frontend/lib/ui/features/invites/views/accept_invite_view.dart`). The
"existing users only, 404 otherwise" behavior described in earlier drafts of
this doc no longer matches the code. Changing a member's role after invite
and removing a member are still explicitly deferred (no such endpoints
exist).

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
* Alerts — **log-only for now, no external notification channel.** See
  the dedicated note below; this needs revisiting once the app is
  actually deployed somewhere real and there's an obvious channel
  (email/Slack/webhook) and a real person to notify.
* Backups — **handled directly in the Supabase dashboard (Database →
  Backups), not in this codebase.** Deliberately not automated or
  scripted here; see `README.md`'s Operations section.
* Restore tests
* Export
* Deletion
* Privacy controls
* Security testing

**Rate limiting and audit logs (added 2026-08-06):**

Rate limiting is Postgres-backed (`rate_limit_hits` table + one shared
helper, `app/services/rate_limiting.py`'s `check_and_record_rate_limit`),
not in-memory — deliberately, so limits survive server restarts and hold
correctly if this ever runs with multiple worker processes, unlike a
per-process in-memory counter would. Each call site picks its own `scope`
string (typically `f"<action>:{household_id}"`) and its own
`max_calls`/`window`; there's no cross-endpoint default. Wired into every
endpoint that costs real external money/quota or was already a documented
abuse risk: `assistant/ask` (LLM, 20/hour — pre-existing, now goes through
the shared helper instead of its own hand-rolled `assistant_messages` count
query), `anomalies/{id}/explain` (LLM, 20/hour — previously *unlimited*),
`connections/token` and `connections` POST (Pluggy API, 10/hour each), and
`members` invite's email-sending path only (Supabase Auth invite email,
10/hour — see `CLAUDE.md`'s Supabase rate-limit lesson; the "existing user,
add directly" branch sends no email and isn't limited).

Audit logs are a new `audit_events` table (`household_id`,
`actor_app_user_id`, `action`, `target_type`, `target_id`, `metadata_json`)
written by `app/services/audit.py`'s `record_audit_event` and read via
`GET /v1/households/{id}/audit-events` (owner-only, newest first). Its FK
to `households` is deliberately **not** `ON DELETE CASCADE` — an audit
trail is supposed to survive the thing it audited being deleted, not
vanish with it (once household deletion exists at all, per Milestone 10's
"Deletion" line above, it should either archive audit rows or leave them
orphaned on purpose, not cascade them away). Actions currently recorded:
`connection.created`, `member.added`, `member.invited`, `invite.accepted`,
`member.access_updated` — i.e. every point where household admin data
(who has access to what) changes hands. Not yet recorded: member removal,
role changes, connection deletion (none of those exist as features yet).

**Export and household deletion (added 2026-08-06):** the API sketch above
already had `POST /v1/exports` and `DELETE /v1/account` as placeholders;
what actually got built is scoped narrower and differently-shaped:

- `GET /v1/households/{id}/export` — any member (not owner-only), scoped
  by the same `AccessScope` as every other read in this app. Returns one
  synchronous JSON body — no async job, no email-a-download-link, no
  separate export-storage table. That's deliberate: nothing else in this
  stack has async-job/email infra beyond the one-off Supabase invite
  email, and household data volumes here don't need it. `raw_json` is
  included (unlike `household_context.py`'s LLM export) because this is
  the member's own data going back to them, not a third-party prompt.
- `DELETE /v1/households/{id}` — owner-only, hard-deletes the household
  and every row scoped to it. **Account-level deletion (`DELETE /v1/me`,
  the other half of the original sketch) is deliberately deferred** — a
  user can own multiple households, and deleting their account while
  they're the sole owner of a household with other members raises an
  ownership-transfer question this repo hasn't decided yet. Household
  deletion needed no such decision, so it shipped first.

Deleting a household is exactly the scenario that motivated
`audit_events.household_id`'s `ON DELETE SET NULL` above: the endpoint
records a `household.deleted` audit event (with the household's name
in `metadata_json`, since `household_id` won't be resolvable afterward)
*before* deleting anything, and that row's `household_id` gets nulled out
by the same transaction rather than blocking the delete. One easy-to-miss
gotcha found by the regression test for exactly this: SQLAlchemy's bulk
`Query.delete(synchronize_session=False)` does **not** autoflush pending
ORM inserts first, so a pending audit-event `INSERT` sitting in the session
when a bulk `DELETE` on `households` runs gets flushed *after* it — in the
same uncommitted transaction, meaning its FK check fails because the
household is already gone as far as that transaction is concerned. Fixed
with an explicit `db.flush()` between recording the event and running the
cascade (see `app/api/households.py`'s `delete_household_endpoint`) — any
future write-then-bulk-delete-in-one-request needs the same explicit flush.

**Monitoring (added 2026-08-06):** `GET /health` now checks the database
(`SELECT 1` through the app's own engine) instead of always returning
`{"status": "ok"}` unconditionally — a broken DB connection now surfaces as
`503 {"status": "error", "database": "unreachable"}`, tested in
`backend/tests/test_health.py` (healthy path + simulated outage via a
monkeypatched engine). `app/main.py` also gained a request-logging
middleware (`logging.basicConfig` + one `INFO` line per request: method,
path, status, duration) — previously only `sync_worker.py` logged anything;
the API itself logged nothing. **Deliberately not built**: no
Prometheus/OpenTelemetry metrics endpoint, no Sentry/APM error tracking, no
log aggregation — same reasoning as Alerts above, there's no deployed
instance yet to point any of that at, and no vendor has been chosen. Revisit
once hosted somewhere real; at that point "Centralized logs" and
"Monitoring and alerts" (Production tier list above) mean wiring this
process's stdout logs and the `/health` check into whatever platform hosts
it, not adding more code here speculatively.

**Alerts (added 2026-08-06, deliberately log-only):** `GET /v1/households/
{id}/alerts` (owner-only) returns a "needs attention" list — failed
`SyncJob`s, plus `assistant.call_failed`/`anomaly_explain.call_failed`
audit events (both endpoints now record one of these and return a
consistent `503` instead of leaking the raw provider exception; anomaly
explain previously had no `try`/`except` around the LLM call at all and
would have 500'd instead). **This does not notify anyone** — no email, no
Slack, no webhook. That's a deliberate scope cut, not an oversight:
there's no deployed instance of this app yet, so there's no real channel
to send to and no on-call person to page. **Revisit this once the app is
actually deployed somewhere** — at that point "alerts" should mean an
owner (or an operator) gets pushed a notification, not just a queryable
list they have to remember to check.

**Security testing (added 2026-08-06):** two things, both new.

1. `backend/tests/test_security.py` — end-to-end HTTP tests that complement
   (not duplicate) the existing auth/access coverage in
   `test_supabase_auth.py`, `test_access_grants.py`, `test_households.py`,
   and `test_rate_limiting.py`: missing/malformed/garbage bearer tokens
   rejected on a real endpoint (not just at the token-verification unit
   level); cross-household 403s on `/members`, `/alerts`, and
   `/members/{id}/access` (endpoints that weren't yet covered by a
   cross-household test, even though every route already depended on
   `get_household_membership`/`require_role`/`get_access_scope` — grepped
   to confirm none skip it); and rate-limit *enforcement* exercised through
   a real endpoint (`connections/token`, 10 real calls then an 11th that
   gets `429`) rather than only the `check_and_record_rate_limit` service
   function in isolation.
2. `pip-audit` added to `requirements.txt` and run against it —
   **no known vulnerabilities** in current dependencies as of 2026-08-06.
   No `bandit`/SAST added: this repo's actual risk surface so far is
   access-control logic (covered above) and dependency CVEs (covered by
   pip-audit), not the kind of raw injection/SSRF patterns bandit is built
   to catch — revisit if that changes. Still no CI (per `CLAUDE.md`), so
   `pip-audit` and the test suite both have to be run manually before
   trusting a dependency bump or an access-control change.

**Restore tests (added 2026-08-06):** `backend/scripts/verify_restore.sh` —
dumps a database, restores it into a fresh throwaway database, and diffs
row counts table-by-table; fails loudly (non-zero exit) on any mismatch,
and always drops the throwaway database + dump file afterward. Run against
local Docker Postgres (`family_finance`, the same DB the test suite uses)
on 2026-08-06: all 18 tables matched after the round-trip (`accounts`,
`app_users`, `households`, `transactions`, etc. — see README.md's
Operations section for the full run). **Not yet run against the real
Supabase project**: its direct `db.<ref>.supabase.co` host is IPv6-only,
and this dev machine's network/firewall has no outbound IPv6 route (`pg_dump`
inside the local Docker container and a raw Python socket test from the
host both failed — `Network is unreachable` / `WinError 10013`). The script
supports pointing at Supabase directly via `SOURCE_DATABASE_URL` — it just
needs the project's Session Pooler connection string (IPv4-compatible),
not the direct host, to actually run from here. Revisit once that's in
hand; until then this validates the restore *mechanism*, not that today's
real Supabase data specifically restores cleanly.

**Privacy controls (added 2026-08-06):** what's collected, where it goes,
and what a household can already do about it.

- **Collected**: account/transaction/investment/loan/balance data from
  Pluggy (per the household's own bank connections); Supabase Auth
  email/password for login; free-text assistant questions and their
  answers (`assistant_messages`).
- **Shared with third parties**: Pluggy (to fetch the data above — the
  household explicitly authorizes each connection); an LLM provider
  (Gemini or Anthropic, whichever `LLM_PROVIDER` selects) for anomaly
  explanations and assistant answers — **only** through the two explicit
  allowlists in `app/llm/redaction.py` and
  `app/services/household_context.py`, never `raw_json`, ORM objects,
  Pluggy identifiers, or account numbers. Supabase itself (Auth + Postgres
  hosting) sees everything, as the infrastructure provider.
- **Found and fixed while reviewing this**: `build_household_context` (the
  data sent to the LLM for `/assistant/ask`) was joining `AppUser.email`
  into its `members` list — every question sent every household member's
  email address to the third-party LLM provider, contradicting its own
  docstring's "explicit allowlist, no PII" claim. Fixed by dropping the
  join and sending only `role`; regression test
  `test_ask_assistant_never_sends_member_emails_to_llm` in
  `backend/tests/test_assistant.py` asserts no `@`-containing string
  reaches the provider. `household_export.py`'s member emails are
  correctly left alone — that's the member's own data going back to them,
  not a third-party prompt.
- **Retention**: no separate retention policy or auto-expiry — data lives
  until a household deletes its own connection's data indirectly (no
  per-connection delete exists yet) or the household itself is deleted
  (`DELETE /v1/households/{id}`, hard-deletes everything, Milestone 10's
  Deletion note above). `audit_events` deliberately outlives a deleted
  household (`ON DELETE SET NULL`, see the Audit logs note above).
- **Member-facing controls that already exist**: data export
  (`GET /v1/households/{id}/export`, any member, scoped by their own
  access grants) and household deletion (`DELETE /v1/households/{id}`,
  owner-only). **Deliberately not built**: a consent-management flow or
  ToS/privacy-policy acceptance gate — there's no deployed instance with
  real end users yet to consent to anything; add this before any real
  signup flow goes live, not before.

### Milestone 11 — Migration Readiness Test

* Export Supabase PostgreSQL.
* Restore into Docker PostgreSQL.
* Run Alembic validation.
* Run FastAPI against the restored database.
* Run tenant-isolation tests.
* Confirm Flutter requires no database-related changes.
* Document the future AWS RDS migration procedure.

**Run log (2026-08-06):** the dump/restore/validate/test pipeline was run
end-to-end against local Docker Postgres — real Supabase export is still
blocked by the same IPv6 issue as Milestone 10's Restore tests note above,
so this exercises the full pipeline with local Postgres standing in for
Supabase on both ends.

- **Export + Restore into Postgres**: `pg_dump`'d `family_finance` (the
  same DB the backend test suite uses, so it has real rows across every
  table) into a fresh `family_finance_migration_check` database, same
  approach as `backend/scripts/verify_restore.sh`.
- **Alembic validation**: `alembic current` on the restored DB reported
  head (`f08e50848c8c`) immediately — the dump carries `alembic_version`
  along, so a restored DB is already in sync, no manual stamping needed.
  `alembic upgrade head` against it was a clean no-op. Went further than
  the usual round-trip check (which runs on an *empty* schema): ran
  `alembic downgrade -1` → `alembic upgrade head` against the *restored,
  populated* database — both migrations ran cleanly against real data
  (audit_events' nullable-FK migration), not just an empty table.
- **FastAPI + tenant-isolation tests against the restored database**: ran
  the full `backend/tests/` suite (137 tests) with `DATABASE_URL` pointed
  at `family_finance_migration_check` instead of `family_finance` — all
  137 passed, including every cross-household/access-scope test in
  `test_households.py`, `test_access_grants.py`, and `test_security.py`.
  Proves the app runs correctly, and tenant isolation holds, against a
  freshly-restored copy of the database, not just the original.
- **Flutter's database independence**: grepped `frontend/lib` for any
  direct Postgres/Supabase-table access (`Supabase.instance.client.from(...)`,
  raw `postgres`/`psql` usage) — none found. The only Supabase-flavored
  file is `supabase_auth_service.dart`, which talks to Supabase Auth only;
  every data read/write goes through `backend_api_service.dart` → FastAPI.
  Confirms the architectural claim in this doc's "Migration Readiness"
  intro ("Avoid direct Flutter queries to financial tables") is actually
  true in code, not just aspirational — migrating the Postgres database
  underneath FastAPI needs zero Flutter changes.
- Cleaned up: `family_finance_migration_check` and its dump file were
  dropped after the run, per the same throwaway-database pattern as
  `verify_restore.sh`.

**Documented AWS RDS migration procedure** (future use, not yet executed
against a real target):

1. Provision an RDS Postgres instance matching the source's major version
   (17, per this Docker image and Supabase's current default).
2. Get Supabase's Session Pooler connection string (Project Settings →
   Database → Connection pooling) — same IPv4 requirement as the Restore
   tests note above; the direct host won't be reachable from most
   networks/CI runners.
3. `pg_dump` the Supabase database via that pooler URL.
4. Restore into the new RDS instance (`psql -f` the dump, or `pg_restore`
   if dumped in custom format).
5. Run `alembic current` / `alembic upgrade head` against RDS to confirm
   it's at this repo's migration head — expect a no-op, as it was here.
6. Point a throwaway copy of the backend's `DATABASE_URL` at RDS and run
   the full `pytest` suite against it, exactly as done above against the
   local restored copy — don't skip this step just because the local dry
   run passed; RDS-specific config (SSL mode, parameter groups, extension
   availability) can still differ from Supabase or local Docker Postgres.
7. Only the app-data Postgres moves — Supabase Auth (`SUPABASE_URL`,
   JWT verification) is a separate system in this architecture and stays
   on Supabase regardless of where `DATABASE_URL` points; no Auth-side
   migration is needed.
8. Cut over by changing the deployed backend's `DATABASE_URL` to RDS and
   watching `/health`'s new database check (Milestone 10's Monitoring
   note) confirm connectivity immediately after.
9. Keep the Supabase Postgres instance paused (not deleted) for a rollback
   window before decommissioning it.

### Milestone 12 — Design System + Mockup-Driven Redesign (in progress)

* Shipped a first Flutter design system (2026-08-07, commit `6ddbca3`):
  theme tokens (`frontend/lib/core/theme/` — colors, typography, spacing,
  shape, chart palette) and shared widgets (`frontend/lib/ui/core/widgets/`
  — `StatusChip`/`SeverityChip`, `SummaryCard`, `SectionHeader`,
  `AppEmptyState`, `LoadingState`), applied across all existing screens.
  Added `PRODUCT.md` (product-schema doc for design work) alongside it.
* Started a full visual + IA redesign (2026-08-09), driven by a real
  HTML/CSS/SVG mockup (`web-mockups.html`, repo root) rather than the
  teal Material 3 look above. `design.md` (repo root) is the running spec:
  a flat palette, new chart styles (horizontal-bar category breakdown,
  combo bar+line cash flow), and a 4-tab navigation restructure
  (Início/Contas/Análises/Família) replacing today's
  Dashboard/Finances/Anomalies/Connections/Households routes. Also
  adopting pt-BR as the app's UI language (direct string/formatter swap,
  no l10n framework). A first theme-token code pass was started against
  this mockup-only extraction (`app_colors.dart`/`app_typography.dart`/
  `app_theme.dart`, plus a `google_fonts` dependency).
* A second, far more authoritative source arrived the same day:
  `handoff-app-financas-familiar.md` (repo root), a full written design
  handoff. It **corrected** several mockup-only guesses already in
  `design.md` and in the theme-token code above: the real UI/numeral
  typefaces are Instrument Sans/Geist Mono, not Inter/JetBrains Mono; the
  radius scale is 5-tier (2/8/12/16/20), not 3-tier; member identity
  colors are 6 + an "Outros" fallback, not 4; and there is **no
  success/positive color at all** (income renders `ink-muted`, never
  green — the theme code's green-income mapping was wrong). It also
  resolved prior Open Questions (per-member monthly stacking confirmed,
  dark palette now given, Investimentos tab now specified) and added
  net-new specs with no prior equivalent: a global period/member scope
  model, a data model section (internal-transfer netting, income
  classification, fatura/parcela/Pix/13º-salário rules), and a full
  alerts spec (6 named anomaly types, "Rotativo" — payment below the
  fatura — called out as the single highest-value alert in the Brazilian
  market). The theme-token code pass above is being corrected against
  this handoff doc before implementation continues, not built on top of
  as-is. Phased implementation plan lives in the assistant's plan-mode
  scratch file, not in this doc; `design.md`'s Changelog is the durable
  record of what's been decided and corrected.
* **Phase 1 implemented (2026-08-09)**: theme tokens corrected to match the
  handoff (Instrument Sans/Geist Mono via `google_fonts`, 5-tier radius,
  6+Outros member colors, no success color anywhere — `StatusTone.success`
  removed outright). Nav restructured to the 4-tab shell via
  `StatefulShellRoute` (`frontend/lib/app/household_shell.dart`,
  `router.dart`): new `home`/`accounts`/`analytics`/`family` feature
  directories, reusing existing repositories/view-models with **no backend
  changes** — `DashboardView` becomes the Início tab as-is; Contas/Análises
  are new segmented-control screens over the same dashboard/finance data;
  Família is a new grouped read-view over members+connections, with
  mutation flows (invite, connect, edit access) still routed to the
  existing standalone screens rather than rebuilt inline. 9 new shared/
  chart widgets added per `design.md`'s Component Patterns/Chart Style
  Guide. `flutter analyze` clean, `flutter test` 116/116 (99 prior + 17
  new). **Manual browser QA run 2026-08-09** against the built 4-tab shell
  at `:8901` (`expect` MCP) — found and fixed two real bugs unrelated to the
  design content itself: `AnomaliesViewModel.updateStatus()` wasn't calling
  `notifyListeners()` on success (Confirm/Dismiss silently didn't update the
  UI), and `InviteSender`'s unhandled Supabase rate-limit error surfaced to
  the browser as a bare CORS failure instead of a clean 503. Both fixed and
  re-verified live; see `CLAUDE.md`'s Lessons Learned and
  `MANUAL_TESTING.md`'s A13/A15b gotcha notes. Responsive layout (375/768/
  1440px), a11y audit, and perf trace all came back clean/expected. **Known
  gaps, still not done**: web's top-bar nav (vs. the bottom-nav shell built
  here) isn't implemented; Início/Contas real-spec strings, per-member
  grouping, and the global period/member scope controls are still
  Phase 2+ work per the phased plan.
* **Phase 2, part 1 — pt-BR localization (2026-08-09)**: direct string
  replacement across the whole app (no ARB/l10n framework, per `design.md`),
  including auth/invite screens even though their *visual* redesign is still
  out of scope. `Intl.defaultLocale`/`initializeDateFormatting` pinned to
  `pt_BR` in `main.dart`; `money.dart`'s `formatMoney` now emits `R$ 8.450,00`
  (confirmed via `flutter test` that the space is a real NBSP, not a plain
  space) with a leading minus sign for negatives; `formatShortDate` gives
  `dd/MM/yyyy`. `formatMonth` was first ported to the full `yMMM` pt-BR
  pattern ("abr. de 2026") but that overlapped neighboring labels on the
  dashboard/analytics charts' x-axis at mobile width — caught during the
  browser-QA pass, fixed by switching to a compact `MMM/yy` pattern
  ("abr./26"). Added `test/flutter_test_config.dart` so the whole test suite
  initializes `pt_BR` locale data once (any test exercising `DateFormat`
  otherwise throws `LocaleDataException`). New `roleLabel()` helper
  (`lib/ui/core/formatting/role_label.dart`) centralizes owner/member/viewer
  → Responsável/Membro/Visualizador across households, invites, and family
  screens. Pluggy Connect widget's `language` param switched from a
  hardcoded `'en'` override to `'pt'` (the package's own default — this app
  had been overriding it away from Portuguese). `flutter analyze` clean,
  `flutter test` 121/121 (116 prior + 5 new `money_test.dart` cases).
  Re-verified live end-to-end via `expect` MCP: login/register/household/
  dashboard/finances/anomalies/family all render correctly in Portuguese
  with correct currency/date formatting at mobile, tablet, and desktop
  widths. Backend-generated content (LLM anomaly explanations, transaction
  descriptions from bank feeds, category names from Pluggy) is intentionally
  untouched — out of scope for a frontend string-replacement pass. **Not
  done this pass**: Início/Contas real-spec content, per-member grouping,
  and the global period/member scope controls remain later Phase 2+ work.
* **Phase 2, part 2 — global period/member scope controls (2026-08-10)**:
  built `design.md`'s Global Scope section end-to-end. New
  `ScopeController` (`frontend/lib/data/scope_controller.dart`) holds the
  six period presets (`Este mês`/`Mês passado`/`Últimos 3 meses`/`Este
  ano`/`Últimos 12 meses`/custom range) plus member selection; member
  selection persists per-household via `shared_preferences`, period always
  resets to `Este mês` on cold launch per spec. `PeriodPill`
  (`frontend/lib/ui/core/widgets/period_pill.dart`) renders the ‹ pill ›
  arrow control and a bottom-sheet preset/custom-range/compare-previous
  picker. `HouseholdShell` now owns one `ScopeController` per household,
  exposes it to descendants via a `HouseholdScope` `InheritedNotifier`, and
  renders the period pill + member chips above the active tab per screen
  (Início: both; Contas·Saldos: members only; Contas·Extrato: both;
  Análises·Gastos/Fluxo: both; Análises·Investimentos: members only, value
  line never re-scopes the allocation snapshot; Família: neither) —
  matching `design.md`'s per-screen effect table exactly. Backend: new
  `resolve_member_ids()` (`backend/app/auth/access_scope.py`) narrows a
  viewer's own `connection_ids` down to connections created by the
  selected members; `start_date`/`end_date`/`member_ids` query params
  added to the dashboard endpoint and a new paginated
  `/v1/households/{id}/transactions` endpoint (Contas · Extrato, sharing
  the same scoping helper as the dashboard's teaser) plus the extended-
  finance category-breakdown endpoint. `flutter analyze` clean, backend
  142/142, `flutter test` 142/142 (121 prior + 21 new: `scope_controller_test.dart`,
  `period_pill_test.dart`, plus dashboard/analytics view tests for
  scope-driven refetching and per-screen pill visibility). **Manual browser
  QA run 2026-08-10** against the built shell at `:8901`/backend at `:8010`
  (`expect` MCP, `manual-test@example.com`/`manual-test-2@example.com` on
  the existing QA Test Household): stepped the period pill back a month
  and confirmed the dashboard refetched with the correct `start_date`/
  `end_date` and the cash-flow chart re-rendered for the new month;
  toggled the member chips down to a single member and confirmed the
  request carried the matching `member_ids` and the UI correctly showed
  that member's real (empty) data; confirmed the period pill's per-screen
  visibility (shown on Início/Contas·Extrato/Análises·Gastos, hidden on
  Contas·Saldos/Análises·Investimentos) matches the design spec exactly.
  No new bugs found — this pass was clean. Session note: this work had
  been left uncommitted mid-session when the dev machine froze; recovered
  by confirming both test suites and a fresh manual QA pass still pass
  against the untouched working tree before considering it done.
* **Monthly spend by member (2026-08-10)**: real per-member stacked bar
  for Análises · Gastos, replacing the single-series stand-in flagged in
  the Phase 1 entry above. New backend endpoint
  `GET /v1/households/{id}/spending-by-member`
  (`backend/app/api/extended_finance.py`) resolves each transaction's
  owning member via `PluggyConnection.created_by_app_user_id` (a small
  connection→member lookup kept separate from the SQL aggregation, mirroring
  `resolve_member_ids`'s own separation of concerns) and returns flat
  `(month, member_id, total)` rows — no folding server-side, same
  convention as `/categories`. `ScopeController` (not a new widget) now
  also owns the household's member roster (`members`/`setMembers()`),
  fed by `HouseholdShell`, so `AnalyticsView` gets it for free through the
  `HouseholdScope` it already reads. All of `design.md`'s density rulebook
  now lives in `monthly_spend_chart_data.dart`: "all selected" (empty or
  every box checked) always wins even over a 5+-member household →
  unstacked; an explicit 2-4-member subset → stacked, with Outros
  bucketing of unattributed/unknown-member rows, a global 3%-of-range fold,
  a legend cap at 3 named series when Outros is non-empty, and an *exact*
  4px-minimum-segment fold computed against a plot-height constant shared
  with the widget (not a layout-dependent approximation) — folded value is
  always added into that month's Outros, never dropped, and the legend
  total is computed from the same post-fold per-month values the bars
  actually draw, not a pre-fold estimate (caught and fixed a real
  legend/bar mismatch bug while unit-testing this). An explicit 5+-member
  subset refuses to stack and renders a plain ranked list instead. Backend
  142/142 → 146/146 (4 new: month/member grouping, `member_ids` filter, a
  named cross-household-fan-out regression guard, isolation). Frontend
  `flutter analyze` clean, `flutter test` 154/154 (12 new mapper tests
  covering every branch/threshold, 4 new widget tests per mode — two of
  the mapper tests initially failed because the test fixtures accidentally
  selected 100% of a household's roster while asserting the subset-only
  branches; the assertions themselves were correct and caught real,
  pre-existing-in-the-test-not-the-code bugs). **Manual browser QA run
  2026-08-10**: rebuilt web, and while restarting the local backend
  found `pkill -f "uvicorn app.main"` silently fails on this Windows/
  git-bash setup — the process survives and a second `uvicorn` instance
  simply fails to bind the port, so a `curl` success right after can still
  be hitting the *stale* pre-change process (this cost real debugging time
  chasing a phantom 404); confirmed via
  `Get-Process -Id (Get-NetTCPConnection -LocalPort <port> -State Listen).OwningProcess`
  and killed by PID with `Stop-Process -Force` instead. Once the real
  process was serving the new route: verified against the QA Test
  Household (2 real members) that the unstacked path renders correctly
  for both "all selected" and "single member selected", with the network
  request's `member_ids` param matching the actual selection and a 200
  response. This household only has 2 members, so the stacked/ranked-list
  paths couldn't be exercised live — those are covered by the mapper/
  widget unit tests above instead, which is disclosed here rather than
  silently skipped.
* **Real Início + Contas · Saldos content (2026-08-10)**: full rebuild of
  both screens per `design.md`'s §6.1/§6.2, closing the last remaining
  "still literally pre-redesign content" gap from Milestone 12 Phase 1.
  Backend: `AccountSummary` (`backend/app/schemas/dashboard.py`) gained
  `credit_limit`/`available_credit_limit` (existing `Account` columns,
  previously unexposed), `connection_status` (via a new
  `{connection_id: PluggyConnection.status}` map), and `owner_member_id`
  (via `connection_member_map()` — moved from `extended_finance.py`'s
  private `_connection_member_map` into `access_scope.py` alongside
  `resolve_member_ids` so `dashboard.py` could reuse it too, rather than
  duplicating the connection→member join); `SyncStatus` gained
  `synced_connections`/`total_connections` (latest `SyncJob` per
  connection in scope, `completed` vs. total). Frontend: `DashboardView`
  (Início) fully rebuilt — hero (`Gastos do mês`/`Entradas`/`Sobrou`,
  summed off `monthlyCashFlow`), credit block (`Limite disponível` summed
  across `CREDIT` accounts), a fatura-due warning (soonest upcoming bill
  across cards, shown only within a 7-day window — `CreditCardBillSummary`
  has no "paid" flag, so "soonest future due date" stands in for "current
  bill," a documented simplification), an alerts-count row (reusing the
  existing `AnomalyRepository`), a "Por membro" spend section (reusing
  `/spending-by-member`, no deviation-from-average sub-line — that stays
  backend-gated per `design.md`'s Alerts section, member-level deviation
  doesn't exist yet), and a sync footer (new `formatRelativeTime()` in
  `money.dart` — `há 2h`/`ontem`/weekday/date per the Localization
  section's own examples, nothing like it existed before). Pure
  calculations extracted into `dashboard_summary_data.dart`
  (`HeroSummary`, `CreditBlockSummary`, `currentBillsByAccount`,
  `pickFaturaWarning`, `memberSpendRows`) so they're unit-testable without
  pumping a widget. Contas · Saldos (`accounts_view.dart`'s
  `_BalancesList`) rebuilt to group accounts by `ownerMemberId` (join-order
  + `AppMemberColors`, unattributed accounts under "Outros"), show a
  credit card's `availableCreditLimit` as the headline figure instead of
  its balance (confirmed against `design.md`'s explicit note that
  available credit — not owed amount — is the leading figure specifically
  on this screen, the inverse of Início's framing) colored by utilization
  (`<30%` default / `30-70%` warning / `>70%` danger, reusing
  `ColorScheme.error` directly per `AppSemanticColors`'s own convention),
  the same fatura line as Início's warning when a current bill exists, and
  `Sem sincronizar` for a broken connection — reusing
  `StatusChip.connectionStatus(...).tone == StatusTone.negative` rather
  than re-deriving which Pluggy statuses count as broken. A real overflow
  bug (hero's Entradas/Sobrou row) was caught immediately by the first
  widget test run and fixed before it ever reached manual QA. Also caught
  before commit (re-reading the approved plan against what was actually
  built, while writing this changelog entry): the hero's `Realizado ·
  Comprometido` bar legend from `design.md`'s own table had been silently
  dropped during implementation — added a `committedTotal()` helper (sum
  of every card's current fatura, independent of the selected period,
  reusing `currentBillsByAccount`) and the missing line, with its own
  mapper tests and a re-run of the manual QA pass to confirm it renders
  (`R$ 0,00` for this household — no bill currently due — correctly, not
  a bug). No visual progress bar is drawn, just the two figures as text —
  a documented simplification, consistent with the category chart
  already accepting a plain list instead of a custom visualization
  elsewhere in this codebase. Backend 149/149, `flutter test` 172/172
  (dashboard_summary_data mapper tests, populated-content widget tests
  for both screens including exact utilization-color assertions, plus
  the pre-existing suite), `flutter analyze` clean. **Manual browser QA
  run 2026-08-10** against the QA Test Household: Início rendered
  `Gastos do mês R$ 177,80` / `Realizado · Comprometido R$ 0,00` /
  `Entradas R$ 25,00` / `Sobrou -R$ 152,80`, the credit block, `1
  cobrança incomum para revisar`, `Por membro` with a real member row,
  and `3 de 4 contas atualizadas ontem`; Saldos correctly grouped
  accounts under
  `manual-test@example.com` and an `Outros` bucket, and showed Mastercard
  Black's `R$ 300.000,00` available limit as the headline (not its
  negative balance) — confirming the inverted-framing decision above was
  correct. No fatura warning appeared on either screen because this
  household's card has no bill due within the 7-day window — expected,
  not a bug. Session note: hit the same stale-backend-process gotcha
  documented in `CLAUDE.md`'s Lessons Learned earlier this session
  (`pkill` doesn't reliably kill `uvicorn` here) — killed by PID via
  PowerShell before this pass's QA, per that entry.

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
