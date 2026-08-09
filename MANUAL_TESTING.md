# Manual Testing Instructions — Family Finance

Every command below is meant to be pasted into `cmd.exe` (Windows). Where a
step needs its own long-running terminal window (Postgres, FastAPI, the sync
worker, Flutter), that is called out explicitly — open a new terminal for
each and leave it running.

All folder paths are relative to the repo root:
`C:\Users\octav\OneDrive\Documentos\Python\finance-advisor`

Conventions used below:
- `%DATABASE_URL%` is always the local Docker Postgres, set explicitly per
  `CLAUDE.md` — never rely on `backend\.env`'s value.
- `%TOKEN%` is a real Supabase access token, obtained once in Step 3 and
  reused in every backend request after that.
- `%HOUSEHOLD_ID%` is captured from the household-creation response in
  Step 5.
- Replace `curl` with `curl.exe` if your shell has an aliased/incompatible
  `curl` (PowerShell's alias to `Invoke-WebRequest`); the commands below
  assume `cmd.exe` + real curl, which ships with modern Windows 10/11.

**If you're actually in PowerShell (prompt shows `PS C:\...>`), not
cmd.exe:** every `set VAR=value` below must become
`$env:VAR = "value"` instead. In PowerShell, `set` is aliased to
`Set-Variable` — it silently creates a PowerShell variable, not an
environment variable, so the DB/token/etc override never reaches the
child process. This is exactly how the `DATABASE_URL` gotcha bites:
alembic/pytest fall back to `backend\.env`'s value (which points at the
live Supabase project) and fail with a confusing connection error — e.g.
`connection to server at "<ipv6 address>" ... Permission denied`. Confirm
the override actually took with `echo $env:VAR` before running the next
command, if anything here fails mysteriously.

The same cmd-vs-PowerShell split hits every multi-line `curl` block below
(A6, A8, A9, A12, A13, A14): `^` line continuation is cmd-only — PowerShell
needs `` ` `` (backtick) instead — and `%VAR%` doesn't expand in
PowerShell, needs `$env:VAR`.

**On the JSON body specifically, don't use `curl.exe -d` at all in
PowerShell — confirmed broken.** `curl.exe` is a native Windows binary; it
does its own low-level Win32 command-line parsing, separate from
PowerShell's own quoting. A single-quoted JSON body (`-d '{"email":"x"}'`)
looks clean in PowerShell source but the embedded double-quotes get eaten
by that native parsing layer once PowerShell hands the argument off,
producing exactly this failure (confirmed, not hypothetical):

```
{"code":400,"error_code":"bad_json","msg":"Could not parse request body as
JSON: invalid character 'e' looking for beginning of object key string"}
```

(the leading `{"` got silently stripped, so the body started mid-key at
`e` from `email`). The doc's original escaped-double-quote form
(`-d "{\"email\":\"x\"}"`) is the traditional Windows-native fix and *may*
work, but PowerShell's own re-quoting when forwarding to a native exe can
still double-escape it unpredictably. The reliable fix is to skip
`curl.exe` for any JSON-bodied call and use PowerShell's native
`Invoke-RestMethod` instead — no argv round-trip, no quoting minefield, and
it auto-parses the JSON response into a usable object.

Example translation of A6, in a **fresh terminal** (not the one running
uvicorn) — replace every `<<...>>` with the real value from
`backend\.env` before running, these are placeholders, not literal text:

```powershell
$env:SUPABASE_URL = "<<your SUPABASE_URL from backend\.env>>"
$env:SUPABASE_ANON_KEY = "<<your SUPABASE_ANON_KEY from backend\.env>>"
$env:SUPABASE_SERVICE_ROLE_KEY = "<<your SUPABASE_SERVICE_ROLE_KEY from backend\.env>>"

$body = @{ email = "manual-test@example.com"; password = "Test1234!"; email_confirm = $true } | ConvertTo-Json
Invoke-RestMethod -Method Post -Uri "$env:SUPABASE_URL/auth/v1/admin/users" `
  -Headers @{ apikey = $env:SUPABASE_SERVICE_ROLE_KEY; Authorization = "Bearer $env:SUPABASE_SERVICE_ROLE_KEY" } `
  -ContentType "application/json" -Body $body

$body = @{ email = "manual-test@example.com"; password = "Test1234!" } | ConvertTo-Json
$response = Invoke-RestMethod -Method Post -Uri "$env:SUPABASE_URL/auth/v1/token?grant_type=password" `
  -Headers @{ apikey = $env:SUPABASE_ANON_KEY } `
  -ContentType "application/json" -Body $body
$env:TOKEN = $response.access_token
```

`$response.access_token` gives you the token directly — no manual
copy-paste out of a raw JSON blob needed. Apply the same
`Invoke-RestMethod` pattern (rather than `curl.exe -d`) to any other
JSON-bodied call in A8/A9/A12/A13/A14 if run from PowerShell.

These `$env:` values live only in this one terminal window — they don't
persist, and they're separate from `backend\.env` (which only the uvicorn
process reads). Set them fresh in any new terminal before running curl
here.

Each step below has a **Why this step** blurb aimed at someone learning the
architecture by doing it, not just executing commands blind — it explains
the concept the step is exercising, not only the mechanics.

---

## Part A — Backend (FastAPI / Postgres / Supabase)

### A0. One-time setup (skip if already done)

**Why this step:** the backend is a normal Python project — a virtualenv
keeps its dependencies (FastAPI, SQLAlchemy, Alembic, etc.) isolated from
any other Python project or the system Python. Nothing architecturally
interesting happens here; it's just plumbing so later steps have the
right packages installed.

```cmd
cd backend
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
```

### A1. Start local Postgres

**Why this step:** the app talks to plain PostgreSQL — not to any
Supabase-specific API — so for local dev/test we run our own throwaway
Postgres in Docker instead of touching the live Supabase project. This
keeps test runs from mutating shared dev data and lets you nuke/recreate
the database freely. See `CLAUDE.md`'s Known Test Surfaces table and
`PLAN.md`'s "Why Docker Is Included" section for the full reasoning —
Docker is purely a dev/test tool here, production points at Supabase (or
later AWS RDS) instead, via the same code, just a different
`DATABASE_URL`.

**Prerequisite: Docker Desktop must already be running.** `docker compose up`
fails with `failed to connect to the docker API at
npipe:////./pipe/dockerDesktopLinuxEngine` if the Docker Desktop app isn't
open yet — starting the engine is not automatic. Launch it and wait for the
engine before proceeding:

```cmd
start "" "C:\Program Files\Docker\Docker\Docker Desktop.exe"
```

Then poll `docker info` (or just watch the Docker Desktop tray icon) until
it stops erroring — typically well under a minute.

Terminal 1 (leave running):

```cmd
cd C:\Users\octav\OneDrive\Documentos\Python\finance-advisor
docker compose up -d db
docker compose ps
```

What we're testing: the local dev database container starts and passes its
healthcheck (`STATUS` column should show `healthy`).

Recovery note: if you ever delete this container manually (Docker Desktop
UI or `docker rm`), rerunning `docker compose up -d db` recreates it from
`docker-compose.yml`. If only the container was deleted, your data survives
(it lives in a separate named volume) — you're done. If the volume was also
deleted (`docker compose down -v` or removing the volume directly), you get
a fresh empty Postgres and must redo **A2** (migrations) before anything
else works, then re-create test data via A6-A9.

### A2. Apply migrations

**Why this step:** Alembic is the single source of truth for the database
schema, and the same migration files run against local Docker Postgres,
the live Supabase project, and eventually a future production database —
there's no separate "Supabase version" of the schema. This step brings
your fresh/empty local Postgres up to the same table structure the app
code expects (`app_users`, `households`, `transactions`, etc.). Skipping
it is why you'd see errors like "relation does not exist" in later steps.

```cmd
cd backend
.venv\Scripts\activate
set DATABASE_URL=postgresql+psycopg://finance_app:local-development-only@localhost:5432/family_finance
alembic upgrade head
```

**If your prompt shows `(.venv) PS C:\...>` (PowerShell), the `set` line
above silently does nothing** — `set` in PowerShell is `Set-Variable`, not
an environment-variable assignment, so alembic never sees the override.
Confirmed twice in this repo: it falls back to `backend\.env`'s
Supabase `DATABASE_URL` and fails with

```
psycopg.OperationalError: connection failed: connection to server at
"<some ipv6 address>", port 5432 failed: Permission denied (0x0000271D/10013)
```

Use this instead, in PowerShell:

```powershell
$env:DATABASE_URL = "postgresql+psycopg://finance_app:local-development-only@localhost:5432/family_finance"
alembic upgrade head
```

Sanity-check before running alembic if you've been bitten by this before:

```powershell
echo $env:DATABASE_URL
```
Must print the `localhost:5432` string, not blank.

What we're testing: schema is current. Expect the final line to reference
the newest revision (`f08e50848c8c` at time of writing — check
`backend/migrations/versions/` for the current head if this drifts again).
If the DB is
already at head, `alembic upgrade head` prints nothing but two `INFO` lines
and no error — that's success, not a no-op failure. Confirm explicitly
with:

```cmd
alembic current
alembic heads
```

Both should print the same revision id, suffixed `(head)`.

Optional deeper check (migration round-trip, per `CLAUDE.md`):

```cmd
alembic downgrade -1
alembic upgrade head
```

This round-trip matters because Alembic's autogenerate has known blind
spots — e.g. it creates a Postgres enum type on `upgrade` but doesn't always
drop it on `downgrade`, which only shows up the *second* time you upgrade.
A single one-way `upgrade head` can look successful while hiding that bug.

### A3. Run the automated backend test suite

**Why this step:** this is the fastest feedback loop there is — automated
tests already assert most of the behavior the manual curl steps below
check by hand. Per `CLAUDE.md`'s Verification Policy, if a test covers a
change, we run it rather than eyeballing the code; the manual steps exist
mainly for the things automated tests can't easily cover yet (real Pluggy
sandbox data, real browser rendering, cross-service wiring).

```cmd
cd backend
.venv\Scripts\activate
set DATABASE_URL=postgresql+psycopg://finance_app:local-development-only@localhost:5432/family_finance
python -m pytest tests/ -q
```

In PowerShell, use `$env:DATABASE_URL = "..."` instead of `set` — see A2's
note above for why (`set` silently no-ops in PowerShell).

What we're testing: everything already covered by automated tests —
`/v1/me`, households, connections, dashboard, extended finance, anomalies,
CORS, Supabase auth, sync worker. This is the fastest way to catch a
regression before doing anything manual. All tests should pass before you
bother with the manual steps below.

### A4. Start the API server

**Why this step:** FastAPI is the trust boundary of the whole system —
per `PLAN.md`, Flutter never talks to Postgres, Pluggy, or the LLM
directly, only to this API. Starting it here, in its own terminal, is what
every other Part A/B step (curl calls, Flutter) actually talks to.

Terminal 2 (leave running):

```cmd
cd backend
.venv\Scripts\activate
set DATABASE_URL=postgresql+psycopg://finance_app:local-development-only@localhost:5432/family_finance
uvicorn app.main:app --reload
```

PowerShell equivalent (prompt shows `PS C:\...>`):

```powershell
cd backend
.venv\Scripts\Activate.ps1
$env:DATABASE_URL = "postgresql+psycopg://finance_app:local-development-only@localhost:5432/family_finance"
uvicorn app.main:app --reload
```

If `Activate.ps1` is blocked by execution policy, run once per session first:
`Set-ExecutionPolicy -Scope Process -ExecutionPolicy RemoteSigned`.

Restart this (`Ctrl+C`, rerun) any time `backend\.env` changes — `settings.py`
loads `.env` once at process start, so a running server won't pick up edits.

What we're testing: server boots without error and listens on
`http://localhost:8000`.

### A5. Smoke-test the server is alive

**Why this step:** cheapest possible check that the process from A4 is
actually up and responding before spending time on anything that depends
on it (auth, households, sync).

```cmd
curl http://localhost:8000/health
```

Expected: `{"status":"ok","database":"ok"}` (a `503` with
`{"status":"error","database":"unreachable"}` means the DB check itself is
failing — see Milestone 10's Monitoring notes in `PLAN.md`).

### A6. Get a real Supabase access token

**Why this step:** Supabase's role here is narrowly scoped to
**authentication** — it issues the JWT that proves who you are. It is
*not* where the app's financial data lives (that's the local Postgres
from A1/A2). FastAPI validates this JWT's signature against the real
Supabase project's issuer/audience settings, so there's no way to fake a
token locally — every later authenticated call in Part A depends on a
real token minted here. See `CLAUDE.md`'s Lessons Learned for why we use
the Admin API instead of normal signup: Supabase's free-tier email sending
is rate-limited project-wide, and normal signup would trip it.

You need a real Supabase project's URL + anon key + service role key in
hand (from `backend\.env` — do not open/edit that file; just note the
values, or ask whoever set it up). Do **not** print the service role key to
chat/logs beyond this local shell.

Create a throwaway confirmed test user (per `CLAUDE.md` — avoids the
Supabase free-tier email rate limit):

```cmd
curl -X POST "%SUPABASE_URL%/auth/v1/admin/users" ^
  -H "apikey: %SUPABASE_SERVICE_ROLE_KEY%" ^
  -H "Authorization: Bearer %SUPABASE_SERVICE_ROLE_KEY%" ^
  -H "Content-Type: application/json" ^
  -d "{\"email\":\"manual-test@example.com\",\"password\":\"Test1234!\",\"email_confirm\":true}"
```

Sign in to get an access token:

```cmd
curl -X POST "%SUPABASE_URL%/auth/v1/token?grant_type=password" ^
  -H "apikey: %SUPABASE_ANON_KEY%" ^
  -H "Content-Type: application/json" ^
  -d "{\"email\":\"manual-test@example.com\",\"password\":\"Test1234!\"}"
```

Copy the `access_token` field from the response into an env var for the
rest of Part A:

```cmd
set TOKEN=paste-access-token-here
```

What we're testing: Supabase Auth issues a real JWT for a real user — this
is the credential every other backend call below depends on.

### A7. `GET /v1/me` — auth + auto-provisioning

**Why this step:** this exercises the two-layer identity model from
`PLAN.md`: Supabase Auth identifies the *external* account (the JWT), but
the app keeps its own internal `app_users` record keyed off that identity.
Decoupling the two means a future switch away from Supabase Auth wouldn't
require rewriting every household/financial relationship — only how the
identity gets resolved. This endpoint is where that internal record gets
created, lazily, on first authenticated call.

```cmd
curl http://localhost:8000/v1/me -H "Authorization: Bearer %TOKEN%"
```

What we're testing: FastAPI validates the Supabase JWT and auto-creates an
`app_users` row on first call. Expect a 200 with `id`, `email`. Run it twice
— second call should return the same `id` (no duplicate row).

Negative check — no/garbage token should be rejected:

```cmd
curl -i http://localhost:8000/v1/me -H "Authorization: Bearer garbage"
```

Expected: `401`.

### A8. Households — create, list, get, isolation

**Why this step:** households are the tenant boundary in this multi-family
app. Every sensitive table carries a `household_id`, and every request
path is supposed to go `token → app_user → household_membership →
household-scoped query` (per `PLAN.md`'s "Household Isolation" section).
The 403 check at the end is the first, simplest proof that boundary is
actually enforced server-side, not just hidden in the UI.

Create a household:

```cmd
curl -X POST http://localhost:8000/v1/households ^
  -H "Authorization: Bearer %TOKEN%" ^
  -H "Content-Type: application/json" ^
  -d "{\"name\":\"Manual Test Household\"}"
```

Copy the `id` from the response:

```cmd
set HOUSEHOLD_ID=paste-household-id-here
```

List households for the current user (should include the one just made,
with `role: owner`):

```cmd
curl http://localhost:8000/v1/households -H "Authorization: Bearer %TOKEN%"
```

Get one household by id:

```cmd
curl http://localhost:8000/v1/households/%HOUSEHOLD_ID% -H "Authorization: Bearer %TOKEN%"
```

Tenant-isolation check — a random UUID that isn't yours should be
forbidden, not leak data:

```cmd
curl -i http://localhost:8000/v1/households/00000000-0000-0000-0000-000000000000 -H "Authorization: Bearer %TOKEN%"
```

Expected: `403`.

### A9. Pluggy connections — real sandbox item

**Why this step:** Pluggy is the Brazilian open-finance provider the app
connects to for real bank data. This step deliberately uses the *real*
Pluggy sandbox API (not a mock), so what you see here is genuinely
representative of production behavior, just against a fake bank
(connector id `2`, "Pluggy Bank") with fixed sandbox credentials. The
"connect token" call is the same one Flutter's Pluggy Connect widget uses
in Part B5 — proving it works here first isolates backend Pluggy
integration issues from frontend widget issues.

This exercises the real Pluggy sandbox API (not fakes), reusing the pattern
already verified for this repo: connector id `2` ("Pluggy Bank"), sandbox
credentials `user-ok` / `password-ok`.

Get a Pluggy API key directly (needed only to create the sandbox item —
the app itself calls this internally too):

```cmd
curl -X POST https://api.pluggy.ai/auth ^
  -H "Content-Type: application/json" ^
  -d "{\"clientId\":\"%PLUGGY_CLIENT_ID%\",\"clientSecret\":\"%PLUGGY_CLIENT_SECRET%\"}"
```

Copy `apiKey` from the response:

```cmd
set PLUGGY_API_KEY=paste-api-key-here
```

Create the sandbox item:

```cmd
curl -X POST https://api.pluggy.ai/items ^
  -H "X-API-KEY: %PLUGGY_API_KEY%" ^
  -H "Content-Type: application/json" ^
  -d "{\"connectorId\":2,\"parameters\":{\"user\":\"user-ok\",\"password\":\"password-ok\"}}"
```

Copy the `id` field:

```cmd
set PLUGGY_ITEM_ID=paste-item-id-here
```

Poll until `status` is `UPDATED` (takes ~15-20s, re-run a few times):

```cmd
curl https://api.pluggy.ai/items/%PLUGGY_ITEM_ID% -H "X-API-KEY: %PLUGGY_API_KEY%"
```

Now exercise our own API. Create a connect token (what the Flutter widget
would use):

```cmd
curl -X POST http://localhost:8000/v1/households/%HOUSEHOLD_ID%/connections/token ^
  -H "Authorization: Bearer %TOKEN%"
```

What we're testing: our backend can talk to Pluggy and mint a connect
token. Expect 200 with `connect_token`.

Register the sandbox item against the household (this also auto-queues a
`SyncJob`):

```cmd
curl -X POST http://localhost:8000/v1/households/%HOUSEHOLD_ID%/connections ^
  -H "Authorization: Bearer %TOKEN%" ^
  -H "Content-Type: application/json" ^
  -d "{\"pluggy_item_id\":\"%PLUGGY_ITEM_ID%\"}"
```

Expected: 201 with connection `id` and `status`.

Duplicate-registration check (should now 409, not create a second row):

```cmd
curl -i -X POST http://localhost:8000/v1/households/%HOUSEHOLD_ID%/connections ^
  -H "Authorization: Bearer %TOKEN%" ^
  -H "Content-Type: application/json" ^
  -d "{\"pluggy_item_id\":\"%PLUGGY_ITEM_ID%\"}"
```

List connections:

```cmd
curl http://localhost:8000/v1/households/%HOUSEHOLD_ID%/connections -H "Authorization: Bearer %TOKEN%"
```

### A10. Run the sync worker (real Pluggy → Postgres)

**Why this step:** synchronization is deliberately a separate background
process, not something that happens inline during an API request — per
`PLAN.md`, the worker must never keep a request or DB transaction open
while waiting on a slow external call like Pluggy. This step is where the
`SyncJob` queued in A9 actually gets processed: real Pluggy data gets
pulled, normalized into the app's own schema, and upserted idempotently
(unique constraints on `pluggy_item_id`/`pluggy_account_id`/
`pluggy_transaction_id` mean re-running this is always safe, never
duplicates rows).

Terminal 3 (one-shot is fine, doesn't need to stay running unless you want
it to keep polling):

```cmd
cd backend
.venv\Scripts\activate
set DATABASE_URL=postgresql+psycopg://finance_app:local-development-only@localhost:5432/family_finance
python -m app.workers.sync_worker
```

In PowerShell, use `$env:DATABASE_URL = "..."` instead of `set` — see A2's
note above for why (`set` silently no-ops in PowerShell).

What we're testing: the worker picks up the `queued` `SyncJob` created in
A9, calls the real Pluggy API, normalizes accounts/transactions/investments/
loans, and upserts them into Postgres. Watch the terminal output for
completion; then confirm via the dashboard endpoint below that
`sync_status.status` is `completed`.

If it's a long-running/looping worker, `Ctrl+C` to stop it once you see it
finish processing the job (check logs), rather than leaving it running
indefinitely during manual testing.

### A11. Dashboard

**Why this step:** the dashboard endpoint is where raw synced data becomes
finished business logic — per `PLAN.md`'s "Calculation Responsibilities"
section, Python (not Postgres, not Flutter) computes things like total
balance and monthly cash flow. Flutter's dashboard screen (B6) just
renders whatever this endpoint returns; if something looks wrong in the
UI later, checking this curl response first tells you whether the bug is
in backend calculation or frontend rendering.

```cmd
curl http://localhost:8000/v1/households/%HOUSEHOLD_ID%/dashboard -H "Authorization: Bearer %TOKEN%"
```

What we're testing: accounts + `total_balance`, `recent_transactions`
(up to 10), `monthly_cash_flow` (up to 6 months), and `sync_status`.
`sync_status.status` should read `completed` after A10 finished. If you ran
the real Pluggy Bank sandbox connector, expect a checking account and a
credit card account with nonzero balances, and transactions like salary,
boleto, utility bills, Netflix/Spotify.

### A12. Extended finance endpoints

**Why this step:** these cover the finance data types beyond the core
dashboard (Milestone 8) — credit card bills, investments, loans, balance
history, category breakdowns. Same principle as A11: confirm the data is
correct at the API layer before blaming the Flutter finances screen (B7)
if something's missing.

```cmd
curl http://localhost:8000/v1/households/%HOUSEHOLD_ID%/credit-card-bills -H "Authorization: Bearer %TOKEN%"
curl http://localhost:8000/v1/households/%HOUSEHOLD_ID%/investments -H "Authorization: Bearer %TOKEN%"
curl http://localhost:8000/v1/households/%HOUSEHOLD_ID%/loans -H "Authorization: Bearer %TOKEN%"
curl http://localhost:8000/v1/households/%HOUSEHOLD_ID%/balance-history -H "Authorization: Bearer %TOKEN%"
curl http://localhost:8000/v1/households/%HOUSEHOLD_ID%/categories -H "Authorization: Bearer %TOKEN%"
```

What we're testing: each returns 200 with a list (non-empty for
investments/loans/credit-card-bills if the sandbox item produced that data
type — per the verified run, Pluggy Bank sandbox produces 7 investment
types and one loan).

### A13. Anomalies (deterministic rules + LLM explain)

**Why this step:** anomaly detection is deliberately two-stage, per
`PLAN.md`'s "LLM Architecture" section — cheap deterministic rules (large
transaction, new merchant, etc.) run first during sync and flag
candidates; the LLM is only ever asked to *explain* an already-flagged
candidate, never to scan the full transaction history itself. This keeps
LLM usage cheap and bounded, and — just as important — the LLM only ever
sees a *redacted* context, never raw sensitive fields. If no
`ANTHROPIC_API_KEY`/`GEMINI_API_KEY` is configured, the explain call is
*expected* to fail; that's a config gap, not a bug.

List anomalies (deterministic rules should have already fired during sync
in A10 — e.g. `large_transaction`, `new_merchant`):

```cmd
curl http://localhost:8000/v1/households/%HOUSEHOLD_ID%/anomalies -H "Authorization: Bearer %TOKEN%"
```

Filter by status:

```cmd
curl "http://localhost:8000/v1/households/%HOUSEHOLD_ID%/anomalies?status_filter=open" -H "Authorization: Bearer %TOKEN%"
```

Copy an anomaly `id` from the list response:

```cmd
set ANOMALY_ID=paste-anomaly-id-here
```

Ask the LLM to explain it (requires `ANTHROPIC_API_KEY` or `GEMINI_API_KEY`
set in `backend\.env` — if neither key is configured, this call is expected
to fail/error; note that explicitly rather than treating it as a bug):

```cmd
curl -X POST http://localhost:8000/v1/households/%HOUSEHOLD_ID%/anomalies/%ANOMALY_ID%/explain -H "Authorization: Bearer %TOKEN%"
```

What we're testing: the explanation is generated from a *redacted* context
(per `CLAUDE.md`/PLAN.md — no raw sensitive fields sent to the LLM) and
`explanation` + `explained_at` get persisted. Re-`GET` the anomaly list to
confirm it stuck.

Update anomaly status (e.g. dismiss it):

```cmd
curl -X PATCH http://localhost:8000/v1/households/%HOUSEHOLD_ID%/anomalies/%ANOMALY_ID% ^
  -H "Authorization: Bearer %TOKEN%" ^
  -H "Content-Type: application/json" ^
  -d "{\"status\":\"dismissed\"}"
```

### A14. Tenant isolation (two households)

**Why this step:** A8's single 403 check only proves you can't access a
household ID that doesn't exist. This step proves the stronger,
security-critical guarantee — a *real* household belonging to a *real
other user* is still invisible to you. `PLAN.md` calls this out
explicitly as a "Critical Tenant-Isolation Test" that should block
deployment if it ever fails, since this is a multi-family app where a
leak here means Family A sees Family B's bank data.

Repeat A6 to create a **second** Supabase user (`manual-test-2@example.com`),
get its own `%TOKEN2%`, and repeat A8 to create a second household
`%HOUSEHOLD_ID_2%` owned by that user. Then confirm user 2 cannot see
user 1's data:

```cmd
curl -i http://localhost:8000/v1/households/%HOUSEHOLD_ID%/dashboard -H "Authorization: Bearer %TOKEN2%"
curl -i http://localhost:8000/v1/households/%HOUSEHOLD_ID%/anomalies -H "Authorization: Bearer %TOKEN2%"
```

Expected: `403` on both — this is the critical tenant-isolation guarantee
called out in `PLAN.md`.

### A15b. Member invites (existing user + new user), Assistant, audit/alerts/export, deletion

**Why this step:** Milestone 10 (and the invite flow extension noted in
`PLAN.md`) shipped these after this checklist was first written — they had
no coverage here at all. Not exhaustive, just enough to confirm each
endpoint responds sanely.

Invite an **existing** user (the second Supabase user from A14, if you ran
it — otherwise create one via A6 first) directly into the household:

```cmd
curl -i -X POST http://localhost:8000/v1/households/%HOUSEHOLD_ID%/members -H "Authorization: Bearer %TOKEN%" -H "Content-Type: application/json" -d "{\"email\":\"manual-test-2@example.com\",\"role\":\"member\"}"
```

Expected: `201`, membership added directly (no email sent — the account
already exists).

Invite a **new** email (no `app_users` row yet):

```cmd
curl -i -X POST http://localhost:8000/v1/households/%HOUSEHOLD_ID%/members -H "Authorization: Bearer %TOKEN%" -H "Content-Type: application/json" -d "{\"email\":\"manual-test-invite@example.com\",\"role\":\"member\"}"
```

Expected: `201` with a pending-invite result, and an invite email actually
sent (check the Supabase Auth logs / your inbox if using a real address).

**Gotcha found 2026-08-09:** if Supabase's free-tier email-send rate limit
(`over_email_send_rate_limit`, the same one called out elsewhere in
`CLAUDE.md`'s Lessons Learned) trips while inviting a **new** email, this
call used to fail as a bare `500 Internal Server Error` with no body — and
in the Flutter Web UI it showed up as a browser CORS error on the
`POST .../members` request (no `Access-Control-Allow-Origin` header, because
CORS middleware never gets to run on an unhandled exception — same failure
shape as the Pluggy-timeout CORS gotcha in `CLAUDE.md`). Root cause:
`InviteSender.invite_user_by_email` (`backend/app/auth/supabase_admin.py`)
called `resp.raise_for_status()` with no try/except, so any non-2xx from
Supabase's `/auth/v1/invite` propagated as an unhandled exception. Fixed by
wrapping that call in `household_members.py`'s `invite_member` and raising a
clean `503` with a friendly message instead (matching the pattern already
used by the anomaly-explain and assistant endpoints). If this endpoint ever
500s again with a CORS-looking error in the browser, check the actual
backend response via curl first — it's very unlikely to be a real CORS
config issue.

Accept it via the token from that invite:

```cmd
curl -i http://localhost:8000/v1/invites/%INVITE_ID%
curl -i -X POST http://localhost:8000/v1/invites/%INVITE_ID%/accept -H "Authorization: Bearer %TOKEN%"
```

Assistant — ask a question about the household's own data:

```cmd
curl -i -X POST http://localhost:8000/v1/households/%HOUSEHOLD_ID%/assistant/ask -H "Authorization: Bearer %TOKEN%" -H "Content-Type: application/json" -d "{\"question\":\"What did I spend the most on last month?\"}"
```

Expected: `200` with an answer, or a clear degraded-state error if no LLM
API key is configured (per `CLAUDE.md`) — not a raw 500.

Audit events, alerts, export:

```cmd
curl -i http://localhost:8000/v1/households/%HOUSEHOLD_ID%/audit-events -H "Authorization: Bearer %TOKEN%"
curl -i http://localhost:8000/v1/households/%HOUSEHOLD_ID%/alerts -H "Authorization: Bearer %TOKEN%"
curl -i http://localhost:8000/v1/households/%HOUSEHOLD_ID%/export -H "Authorization: Bearer %TOKEN%"
```

Expected: `200` on all three; audit-events should already list the invite
actions from above.

Household deletion — **destructive, only run this against a throwaway test
household**, e.g. the one from A14, not your main manual-test household:

```cmd
curl -i -X DELETE http://localhost:8000/v1/households/%HOUSEHOLD_ID_2% -H "Authorization: Bearer %TOKEN2%"
```

Expected: `204`, and a follow-up `GET` on that household returns `403`/`404`.

### A15. Cleanup (optional, avoids sandbox item buildup)

**Why this step:** Pluggy sandbox items accumulate under your Pluggy
project if never deleted. Cleaning up here keeps repeated manual-testing
passes tidy, but is optional — nothing product-critical depends on it.

```cmd
curl -X DELETE https://api.pluggy.ai/items/%PLUGGY_ITEM_ID% -H "X-API-KEY: %PLUGGY_API_KEY%"
```

Leave the two Supabase test users in place if you'll re-test soon, or
delete them via the Supabase dashboard / Admin API `DELETE
/auth/v1/admin/users/{id}` if you want a clean slate.

---

## Part B — Frontend (Flutter Web)

Backend must already be running (Part A, Terminal 2 — `uvicorn` on
`:8000`) since Flutter talks to it directly.

### B1. One-time setup

**Why this step:** Flutter needs its own copy of the Supabase URL/anon key
to talk to Supabase Auth directly (login/register happen client-side,
straight to Supabase — see B3). Per `PLAN.md`'s "Frontend Responsibilities"
section, Flutter is only ever handed the public anon key here, never a
service-role key or any Postgres/Pluggy/LLM credential — those stay
backend-only.

```cmd
cd frontend
copy .env.example .env
```

Edit `frontend\.env` and fill in `SUPABASE_URL` and `SUPABASE_ANON_KEY`
(same Supabase project as the backend). Leave `API_BASE_URL` as
`http://localhost:8000` for web.

```cmd
flutter pub get
```

### B2. Run on Flutter Web

**Why this step:** this is the first point where you see the actual
compiled UI, not just curl JSON. The headless/no-extension gotcha here is
purely a local-tooling quirk (DWDS debug client waiting on a Chrome
extension handshake that never happens) — it's not a sign the app itself
is broken, which is easy to mistake it for for.

Per `CLAUDE.md`'s lessons learned, `flutter run -d web-server` hangs in a
headless/no-extension session. If you have a real browser + the Dart Debug
Chrome extension, `flutter run -d chrome` is simplest and gives hot reload:

```cmd
cd frontend
flutter run -d chrome --dart-define-from-file=.env
```

What we're testing: app builds and opens in Chrome without compile errors.

If instead you're verifying headlessly (no interactive browser), build and
serve statically:

```cmd
cd frontend
flutter build web --dart-define-from-file=.env
cd build\web
python -m http.server 8080
```

Then open `http://localhost:8080` in a real browser.

### B3. Register / Login screen

**Why this step:** this confirms the client-side half of the auth model
from A6/A7 — Flutter talks to Supabase Auth *directly* for login/register
(not through FastAPI), then attaches the resulting token to every
subsequent FastAPI call. It's the only place in the whole system where
Flutter has a direct relationship with an external service other than the
backend.

In the running app:
1. Go to the registration screen, register a new user (or reuse the
   `manual-test@example.com` / `Test1234!` created in A6).
2. Log in.

What we're testing: `login_view.dart` / `register_view.dart` +
`auth_view_model.dart` talk to Supabase Auth directly, store the access
token, and the app navigates to the household/dashboard flow on success.
Also check the **error state**: try logging in with a wrong password and
confirm a visible error message appears (not a silent failure or crash).

### B4. Household list / creation

**Why this step:** same household concept as A8, now exercised through
the actual UI instead of curl — confirms the Flutter layer correctly
calls and renders the same `POST`/`GET /v1/households` endpoints, with no
separate frontend-side household logic (per `PLAN.md`, Flutter should
depend only on these API endpoints, never reimplement business rules).

1. If this is a fresh user, confirm the empty-state UI for "no households
   yet" is sensible (not a blank screen).
2. Create a household through the UI.
3. Confirm it appears in the household list with the "owner" role shown.

This exercises `household_list_view.dart` / `household_view_model.dart`
against `POST/GET /v1/households` from Part A.

### B5. Connections (Pluggy Connect widget)

**Why this step:** this is the real user-facing flow A9 was a stand-in
for — same connect-token endpoint, same sandbox connector, but now driven
by Pluggy's own hosted widget inside a Flutter web view instead of raw
curl calls. If A9 already passed for this household, you already know the
backend side works, so this step mainly validates the widget wiring
itself.

1. From the connections screen, start a new connection.
2. `pluggy_connect_screen.dart` should launch the Pluggy Connect widget
   (web view) using the connect token from `POST
   /v1/households/{id}/connections/token`.
3. In the widget, search for **Pluggy Bank** (sandbox connector) and log in
   with `user-ok` / `password-ok`.
4. Confirm the app registers the resulting item via `POST
   /v1/households/{id}/connections` and the new connection shows up in the
   connections list with a status.

If you already created/synced a sandbox item via curl in Part A9-A10 for
the same household, skip re-connecting and just confirm the existing
connection is listed correctly instead.

### B6. Dashboard screen

**Why this step:** confirms Flutter is a pure rendering layer over A11's
dashboard endpoint — no financial math should happen in Dart itself, only
formatting/layout (per `PLAN.md`'s calculation-responsibility split). If
a number here looks wrong, re-check A11's raw JSON first: if the JSON is
already wrong, it's a backend bug; if the JSON is right but the screen is
wrong, it's a frontend bug.

Open the dashboard for the household you just synced (via curl in A10, or
by triggering sync from the UI if there's a "Sync now" action).

What we're testing (`dashboard_view.dart` / `dashboard_view_model.dart`):
- Total balance renders with correct currency formatting (BRL).
- Account list shows checking + credit card accounts with balances.
- Recent transactions list (up to 10) shows description, amount, date —
  confirm income (positive) vs expense (negative) are visually
  distinguishable.
- Monthly cash flow chart/section shows up to 6 months.
- Sync status indicator shows `completed` (or whatever the last job's
  status was).
- Pull-to-refresh / manual refresh re-fetches from `/dashboard` and
  reflects any changes.

### B7. Finances screen (extended data)

**Why this step:** same rendering-layer check as B6, but for the extended
finance endpoints from A12. Empty categories (e.g. no loans in your
sandbox data) are expected and should degrade gracefully — a blank/error
screen there would be a real bug, an empty-state message would not.

Open the finances screen (`finances_view.dart` /
`finances_view_model.dart`).

What we're testing: credit card bills, investments, loans, balance history,
and category breakdown all render without error, matching what curl showed
in A12. If any category is empty (e.g. no loans in your sandbox data), the
UI should show a sensible empty state, not an error or blank crash.

### B8. Anomalies screen

**Why this step:** exercises the full anomaly lifecycle from the user's
perspective — list (A13's rules output), explain (A13's LLM call, same
"expected to fail without an API key" caveat applies here too), and status
update (A13's PATCH), all through the UI instead of curl.

Open the anomalies screen (`anomalies_view.dart` /
`anomalies_view_model.dart`).

What we're testing:
1. Anomalies detected during sync (A13) are listed with type/severity.
2. Tapping "explain" on one triggers `POST .../explain` and displays the
   returned LLM explanation in the UI (or a clear error state if no LLM API
   key is configured — see A13's note).
3. Changing status (e.g. dismiss) via the UI calls `PATCH .../{id}` and the
   item updates/disappears from the default filtered view accordingly.

**Gotcha found 2026-08-09:** Confirm/Dismiss looked like a no-op in the
browser — the PATCH returned `200` (checked via Network tab / curl) and the
status genuinely changed in Postgres, but the card's severity/status text
never updated on screen until some *other* action forced a rebuild (e.g.
switching filter tabs). Root cause:
`anomalies_view_model.dart`'s `updateStatus()` called `_replace(updated)` on
the success path but never called `notifyListeners()` there — only the two
error branches did. Fixed by adding `notifyListeners()` after `_replace()`
in the try block. If a future anomaly-status change ever looks stuck again
in the UI despite a `200` on the network tab, check for this exact
missing-notifyListeners pattern first.

### B9. Responsive layout check

**Why this step:** the whole point of choosing Flutter (per `PLAN.md`) was
one codebase for web, Android, and iOS — this step is the cheapest way to
sanity-check that the same widget tree actually adapts to wildly different
screen sizes rather than only ever having been tested at one desktop
window size.

Resize the browser window (or use Chrome DevTools device toolbar) between a
narrow mobile width (~375px) and a wide desktop width (~1440px) on the
dashboard and finances screens.

What we're testing: per `PLAN.md`'s "Responsive web and mobile layouts"
milestone goal — layouts should reflow (e.g. cards stacking vertically on
narrow width) rather than clipping, overflowing, or requiring horizontal
scroll.

### B9b. Members / access screens, invite-accept, Assistant

**Why this step:** these screens exist (`members_view.dart`,
`member_access_view.dart`, `accept_invite_view.dart`,
`assistant_view.dart`) but had no manual-QA coverage here — added
alongside A15b's backend coverage of the same features.

1. **Members** — from the household, open the members screen. Invite the
   existing second test user (A14) by email; confirm it's added directly.
   Invite a brand-new email; confirm a pending-invite state shows (not a
   silent no-op).
2. **Accept invite** — using the invite link/token from the step above,
   open `/accept-invite?...` as the invited user (a different browser
   profile or logged-out session). Confirm `accept_invite_view.dart` shows
   the household name and an accept action, and that accepting lands the
   user in that household's dashboard. This is the screen affected by the
   go_router web deep-link bug in `CLAUDE.md`'s Lessons Learned — if it
   throws `GoException: no routes for location: /access_token=...`, that's
   the known issue, check the fix is actually in place.
3. **Member access** — as the owner, open a member's access screen and
   toggle which connections they can see. Confirm the change persists
   (reload the screen) and — if you have a second logged-in session as
   that member — that their dashboard/finances actually reflect the new
   scope.
4. **Assistant** — open the assistant screen, ask a question about the
   household's data. Confirm a real answer renders, or a clear degraded
   error state if no LLM key is configured (same caveat as B8's explain
   feature) — not a blank screen or raw exception.

### B10. Automated Flutter tests

**Why this step:** real coverage now exists — repository/data-layer tests,
auth/household widget tests, and per-chart data-mapper + widget tests (see
`CLAUDE.md`'s Known Test Surfaces). A pass here is meaningful for what it
covers, but it's still not full end-to-end coverage (no integration test
drives a real login → sync → chart-render path, and newer features —
member invites, Assistant, audit/alerts/export — have no dedicated widget
tests yet), so keep pairing it with Parts B1-B9 above for anything crossing
that boundary.

```cmd
cd frontend
flutter test
```

---

## Running everything together (order matters)

For a full end-to-end manual pass, start services in this order, each in
its own terminal, and leave each running until you're done testing:

1. **Terminal 1** — `docker compose up -d db` (Part A1), then leave it (no
   need to keep the terminal open after the container starts, since it's
   detached — but keep it handy for `docker compose ps`/`logs` checks).
2. **Terminal 2** — backend API: Part A2 (migrations, one-time per schema
   change) then Part A4 (`uvicorn app.main:app --reload`). Leave running.
3. **Terminal 3** — sync worker: Part A10, run after you've registered a
   Pluggy connection (A9) so there's a queued job to process. Can be
   one-shot or left running depending on whether the worker loops.
4. **Terminal 4** — Flutter: Part B2 (`flutter run -d chrome
   --dart-define-from-file=.env`). Only start this once Terminal 2 is up,
   since the app calls the API immediately on load.

Shut down in reverse order when done: stop Flutter, `Ctrl+C` the worker if
still running, `Ctrl+C` uvicorn, then optionally `docker compose down` (add
`-v` only if you want to wipe local dev data — ask first per `CLAUDE.md`'s
permission boundaries).
