# Family Finance

A multi-tenant family finance application: connects to Brazilian financial
institutions via the [Pluggy](https://pluggy.ai) open-finance API, syncs
accounts, transactions, investments, loans, and credit-card bills into
Postgres, and presents them through a FastAPI backend and a Flutter
frontend (web, Android, iOS). Includes deterministic anomaly detection with
LLM-generated explanations (Anthropic or Gemini).

See [`PLAN.md`](PLAN.md) for the full architecture, data model, and
milestone history.

## Directory structure

```
finance-advisor/
├── backend/              # FastAPI + SQLAlchemy + Alembic + Pluggy sync worker
│   ├── app/
│   │   ├── api/          # Route handlers (households, connections, dashboard,
│   │   │                 # extended finance, anomalies)
│   │   ├── auth/          # Supabase token verification, household authorization
│   │   ├── database/      # SQLAlchemy session/engine
│   │   ├── llm/           # LLM provider abstraction + redaction (anomaly explain)
│   │   ├── models/        # SQLAlchemy models
│   │   ├── schemas/       # Pydantic response/request schemas
│   │   ├── services/      # Business logic (deterministic anomaly rules)
│   │   ├── sync/          # Pluggy client + Postgres upsert/normalization
│   │   └── workers/       # Sync worker (polls queued sync jobs)
│   ├── migrations/        # Alembic migrations
│   └── tests/
├── frontend/              # Flutter app (web, Android, iOS)
│   └── lib/
│       ├── app/           # Routing
│       ├── core/          # Config, formatting, shared widgets
│       ├── data/          # Models, repositories, API service
│       └── ui/features/   # auth, households, connections, dashboard,
│                          # finances, anomalies
├── infrastructure/
├── docker-compose.yml     # Local Postgres for development/testing
└── PLAN.md
```

## Installation

Local Postgres via Docker:

```bash
docker compose up -d db
```

Backend:

```bash
cd backend
python -m venv .venv
.venv\Scripts\activate     # Windows
source .venv/bin/activate  # macOS/Linux

pip install -r requirements.txt
cp .env.example .env       # fill in real values — never commit .env
alembic upgrade head
```

Frontend:

```bash
cd frontend
flutter pub get
```

## Running

```bash
# Backend API
cd backend
uvicorn app.main:app --reload

# Sync worker (separate terminal)
cd backend
python -m app.workers.sync_worker

# Flutter (web, or a connected Android/iOS device)
cd frontend
flutter run -d chrome
```

By default the Flutter app talks to `http://localhost:8000`. Override with
`--dart-define=API_BASE_URL=...` for a different backend, and
`--dart-define=SUPABASE_URL=...`/`--dart-define=SUPABASE_ANON_KEY=...` for
Supabase Auth (both public client values, safe to embed in the built app).

## Testing

```bash
# Backend (needs local Docker Postgres running)
cd backend
python -m pytest tests/ -q

# Frontend
cd frontend
flutter test
flutter analyze
```

See `CLAUDE.md` for the full test-surface reference, including the Alembic
migration round-trip check.

## Operations

**Backups** are handled directly in the Supabase project dashboard
(Database → Backups), not in this codebase — enable/restore there, not
here. See `PLAN.md`'s Milestone 10 notes for what else production
readiness covers and what's actually been built vs. deferred.

**Restore verification**: `backend/scripts/verify_restore.sh` dumps a
database, restores it into a fresh throwaway database, and compares row
counts table-by-table — proof the restore path actually works, not just
that a backup file exists. Defaults to the local Docker Postgres used by
the test suite; run it with `MSYS_NO_PATHCONV=1 bash
backend/scripts/verify_restore.sh` after `docker compose up -d db`. To
verify against the real Supabase project, set `SOURCE_DATABASE_URL` to its
Session Pooler connection string (Project Settings → Database → Connection
pooling) — the direct `db.<ref>.supabase.co` host is IPv6-only and won't
resolve/connect on an IPv4-only network.

**Privacy**: what's collected and where it goes, plus each household's
controls — see `PLAN.md`'s Milestone 10 "Privacy controls" note for the
full breakdown (data collected, third parties it's shared with, retention,
and member-facing controls that already exist: `GET .../export`,
`DELETE /v1/households/{id}`).

## History

This app began as a single-user Streamlit/SQLite MVP. It was retired once
the current multi-tenant Flutter/FastAPI/Supabase stack's first vertical
slice — register, create a household, connect one real Pluggy institution,
sync real data, and view it on Flutter Web — was verified end-to-end
against the real Pluggy sandbox API. See `PLAN.md` for the milestone
history.
