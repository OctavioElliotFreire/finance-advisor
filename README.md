# Family Finance

A local-first family finance dashboard: syncs real bank, credit card, and
investment data from Brazilian financial institutions via the [Pluggy](https://pluggy.ai)
open-finance API into a SQLite database, and presents it in a Streamlit
dashboard with LLM-powered anomaly detection on transactions.

## Directory structure

```
finance-advisor/
├── app.py                      # Entry point: init, top nav, Sync Now
├── pages/
│   ├── 1_Overview.py           # Accounts / Credit / Investments cards + balance chart
│   ├── 2_Cash_Flow.py          # Expenses, transaction history, LLM flagged transactions
│   ├── 3_Assets.py             # Investment portfolio + loans
│   └── 4_Connections.py        # Connected institutions, refresh
├── components/
│   ├── navigation.py           # Sticky top nav, session-state controls
│   ├── cards.py                # Presentational card renderers
│   ├── charts.py                # Plotly charts (balance evolution, category bars)
│   ├── analytics.py             # Pure aggregation functions (no DB/Streamlit)
│   ├── formatting.py            # Currency/date/percentage formatting
│   └── cached_data.py            # st.cache_data-wrapped DB reads
├── config/
│   └── settings.py              # Branding, currency, locale, design tokens
├── styles/
│   └── styles.css                # Design tokens, card/nav styling, light/dark theme
├── db.py                         # SQLite schema + all query/upsert helpers
├── helpers.py                     # Member/family summary aggregates
├── sync.py                       # Pluggy -> SQLite sync orchestration
├── pluggy_client.py               # Pluggy API client
├── llm/                          # Model-agnostic LLM layer (Anthropic / Gemini)
├── members.yaml                  # Family member -> Pluggy item_id config
└── requirements.txt
```

Real data only — there is no mock data module. Every card and chart reads
from the SQLite DB populated by `sync.py`.

## Installation

```bash
python -m venv .venv
source .venv/bin/activate        # macOS/Linux
.venv\Scripts\activate           # Windows

pip install -r requirements.txt
```

Copy `.env.example` to `.env` and fill in:

```
PLUGGY_CLIENT_ID=...
PLUGGY_CLIENT_SECRET=...
ANTHROPIC_API_KEY=...       # or GEMINI_API_KEY=...
LLM_PROVIDER=anthropic      # anthropic | gemini
```

## Running

```bash
python sync.py              # first sync: pulls real data into finance.db
streamlit run app.py        # open the dashboard, click "Sync Now" any time after
```

## Configuration

All branding, currency, locale, and design tokens live in `config/settings.py`
— no component hardcodes a color, symbol, or label.

- **Branding**: change `APP_NAME` / `LOGO_TEXT`.
- **Currency/locale**: change `CURRENCY_CODE`, `CURRENCY_SYMBOL`, `LOCALE`,
  `THOUSANDS_SEP`, `DECIMAL_SEP`. A locale selector in the top nav also lets
  users switch between presets (`pt-BR`/`en-US`) at runtime — see
  `components/formatting.py::LOCALE_PRESETS`.
- **Institution/asset-class display names**: add entries to
  `INSTITUTION_LABELS` / `ASSET_CLASS_LABELS` (keyed by the raw
  `connector_name` / investment `type` string from Pluggy) to override how
  they're displayed. Anything not listed passes through as-is.
- **Colors/typography**: `COLORS_LIGHT`, `COLORS_DARK`, `PRIMARY_ACCENT`,
  `CHART_PALETTE` in `config/settings.py`, mirrored as CSS custom properties
  in `styles/styles.css`.

## Extending

- **Add a family member**: add an entry to `members.yaml` with the member's
  Pluggy `item_ids`, then run Sync Now.
- **Add an institution**: connect a new item in Pluggy and add its
  `item_id` under the relevant member in `members.yaml` — no code changes
  needed, institution grouping (`components/analytics.py::group_accounts_by_institution`)
  picks it up automatically from `connector_name`.
- **Add an asset class**: nothing to configure — asset classes are derived
  live from each investment's `type` field. Add a friendly label override in
  `config/settings.py::ASSET_CLASS_LABELS` if the raw type isn't
  presentable as-is.
- **Replace the data source entirely**: all Streamlit pages read through
  `components/cached_data.py`, which wraps `db.py`/`helpers.py`. Point those
  wrappers at a different backend and the UI layer needs no changes.

## Known limitations

- **Balance Evolution chart** (`pages/1_Overview.py`) is reconstructed
  backward from the current balance plus transaction history, since Pluggy
  doesn't expose historical balance snapshots. It only covers BANK-type
  accounts (their DEBIT/CREDIT amount sign convention is reliable; credit
  card transactions' sign is not) and never fabricates months earlier than
  the oldest transaction actually observed.
- **Connections page**: only lists connections and supports Refresh.
  Disconnect and Add Connection are not implemented in this pass — real
  Brazilian bank connections require Pluggy's hosted Connect Widget
  (OAuth/MFA), which isn't wired up here.
- **Upcoming Expenses** primarily sources from credit card bill due dates
  (a reliable real field); Pluggy's `PENDING` transaction status is used as
  a secondary source but may be empty depending on the connected
  institution.
- **Sticky top nav** relies on `st.container(key=...)`'s stable
  `.st-key-*` CSS class (Streamlit >=1.35). If a future Streamlit version
  changes how that's rendered, the sticky positioning may need updating in
  `styles/styles.css`.

## Testing

```bash
python -m pytest -v
```
