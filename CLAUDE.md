# Family Finance — Agent Instructions

FastAPI/Postgres/Supabase backend in `backend/`, Flutter frontend (web/Android/iOS) in `frontend/`. See `PLAN.md` for architecture and milestone history.

The repo originally also kept an old Streamlit/SQLite MVP running at the repo root alongside this rewrite. It was retired 2026-07-28 once the new stack's first vertical slice was verified end-to-end against the real Pluggy sandbox API (see `PLAN.md`'s "First Vertical Slice" section) — don't re-create root-level `app.py`/`db.py`/`sync.py`/`llm/`/`pages/` files; that's dead architecture now.

## Verification Policy

Never mark a task or response as complete without validating the actual output in this session — not "should work" from reading the code, not a claim carried over from a previous turn.

- **When an automated test covers the change**: run it, in this session, and only report success after it actually passes. If it fails, fix it or say so — don't paper over a failure.
- **When no automated test covers the change**: say so explicitly, and describe the manual verification performed instead (a curl/TestClient call and its actual output, an import/smoke check, a migration up/down round-trip, a `flutter test`/manual click-through). Never silently skip verification.
- **Never claim something works without having executed it.** A passing type-check or successful import is not the same as a passing behavioral test — don't conflate them.

This is about agent behavior before declaring work done. It's distinct from `PLAN.md`'s "Testing Strategy" section, which describes what test *coverage the product* should eventually have — don't duplicate that here.

## Known test surfaces

| Surface | Command | Notes |
|---|---|---|
| `backend/` (FastAPI/Postgres) | `docker compose up -d db` then `cd backend && source .venv/Scripts/activate && python -m pytest tests/ -q` | Tests hit a real Postgres via `DATABASE_URL` and mutate rows directly (create/query/delete `app_users`, `households`, `household_members`). Default to local Docker Postgres, not the live Supabase project, so repeated runs don't mutate shared dev state. `.env`'s `DATABASE_URL` does not point at local Docker Postgres — override it explicitly on the command line (see Lessons Learned below), never edit `.env` to fix this. |
| Alembic migrations | Round-trip: `alembic upgrade head` → `alembic downgrade -1` → `alembic upgrade head`, against local Docker Postgres | Catches things autogenerate gets wrong that a single `upgrade` won't — e.g. a Postgres enum type created by `create_table` but not dropped by the generated `downgrade()`. Do this before considering any new migration correct. |
| `frontend/` (Flutter) | `flutter test` | Today only the stock `flutter create` placeholder (`widget_test.dart`) exists — a pass doesn't yet prove anything about the real app. Flag this explicitly rather than treating it as meaningful coverage until real widget tests are written. |

## Lessons Learned

Every time a mistake happens in this repo, add the rule that prevents it here — don't let the same error recur across sessions.

- **Never read, write, or edit any real `.env` file** (e.g. `backend/.env`). Only touch `.env.example` to document new setting placeholders — the user fills real secrets in themselves. (Happened: the assistant created `backend/.env` directly before this rule existed.)
- **Postgres passwords with special characters (`@`, `+`, `/`, etc.) break `DATABASE_URL` parsing.** A raw `@` in a Supabase DB password got misread as the user/host separator, silently mangling the hostname and failing DNS resolution. Percent-encode special characters in connection-string passwords, or — simpler — recommend an alphanumeric-only DB password for local/dev use to avoid the whole class of bug.
- **Supabase free-tier auth email sending is rate-limited project-wide, not per-address**, and repeatedly returns `429 over_email_send_rate_limit` on normal `POST /auth/v1/signup` calls during testing. Toggling "Confirm email" off in the dashboard does not necessarily clear an already-tripped limit. For any dev/test user creation, use the Admin API instead: `POST {SUPABASE_URL}/auth/v1/admin/users` with headers `apikey: <service_role_key>` and `Authorization: Bearer <service_role_key>`, body `{"email", "password", "email_confirm": true}` — creates an already-confirmed user with zero emails sent. Then sign in via `POST /auth/v1/token?grant_type=password` (anon key) for a real access token.
- **Alembic autogenerate creates a Postgres enum type via `create_table` but never drops it in the generated `downgrade()`.** A migration adding a `sa.Enum` column will fail on a second `upgrade` after a `downgrade` with "type already exists" unless fixed. Always add `sa.Enum(name='<enum_name>').drop(op.get_bind(), checkfirst=True)` to `downgrade()` for any migration that adds an enum column, and confirm with the upgrade → downgrade → upgrade round-trip described in Known Test Surfaces above.
- **`backend/.env`'s `DATABASE_URL` does not point at local Docker Postgres.** Running `alembic`/`pytest` with no override silently hits the wrong database or fails with a confusing connection error (looked like a resolved-to-a-remote-IPv6-address failure once). Always export `DATABASE_URL="postgresql+psycopg://finance_app:local-development-only@localhost:5432/family_finance"` explicitly for local commands instead of relying on or editing `.env`.
- **FastAPI backend had no CORS middleware** — any browser-hosted Flutter Web build got blocked talking to it from a different origin/port. Fixed by adding `CORSMiddleware` in `app/main.py` driven by `settings.cors_allowed_origin_regex` (defaults to any `localhost` port; override via `.env`'s `CORS_ALLOWED_ORIGIN_REGEX` in production). If real-browser testing of Flutter Web ever breaks again with a CORS console error, check this config before assuming it's a Flutter bug.
- **`flutter run -d web-server` hangs forever in a plain headless-Chromium session** (no Dart Debug Chrome extension installed) — it injects a DWDS debug client that waits on an extension handshake that never completes. Looks identical to a silent app-boot failure. For headless/Playwright verification, use `flutter build web` and serve `build/web` with a plain static server instead.

## Permission Boundaries

- **Autonomous** (no need to ask): `docker compose up -d db`; running migrations against local Docker Postgres; running the root/`backend/` test suites; read-only queries against the live Supabase Postgres; additive `alembic upgrade head` against the live Supabase project; creating and cleaning up throwaway Supabase Auth test users via the Admin API within the same session (per the Lessons Learned pattern above) — as long as no pre-existing real user is touched; normal source edits, still governed by the assistant's standing global git-safety rules.
- **Ask first**: `docker compose down -v` (deletes the local dev Postgres volume); `alembic downgrade` run against the live Supabase project; deleting, disabling, or modifying any real (not created this session) Supabase Auth user, table, or project setting; `git push` / force-push / branch deletion — this repo has no CI, so a bad push has no safety net catching it.
- Global hard-blocks (force-push to `main`, `--no-verify`, etc.) already apply and aren't repeated here.
