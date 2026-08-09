# Family Finance — Flutter frontend

Flutter client for Family Finance (web, Android, iOS — see repo root [`README.md`](../README.md) and [`PLAN.md`](../PLAN.md) for the full architecture). Talks to the FastAPI backend in `../backend/` and to Supabase Auth directly for login/session.

Structure (`lib/`):
- `app/` — routing (`go_router`)
- `core/` — config, formatting, theme tokens, shared widgets
- `data/` — models, repositories, `BackendApiService` (the HTTP client)
- `ui/features/` — one directory per screen area: `auth`, `households`, `invites`, `connections`, `dashboard`, `finances`, `anomalies`, `assistant`

## Running

```
flutter pub get
flutter build web --dart-define-from-file=.env
```

A plain `flutter run -d web-server` hangs in a headless/no-extension session — see `CLAUDE.md`'s Lessons Learned at the repo root before debugging that. Building against `.env` is required — a build with no `--dart-define-from-file` compiles empty Supabase config and every login silently fails.

## Testing

```
flutter test
```

See `../MANUAL_TESTING.md` for the manual QA checklist covering flows automated tests don't reach.
