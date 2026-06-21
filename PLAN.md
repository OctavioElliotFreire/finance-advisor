# Plan: Family Finance Dashboard MVP

## Context
Existing MVP proves Pluggy sandbox works (auth, accounts, transactions, investments all tested).
Now building a real app on top: family expense monitor where a father tracks all family members'
bank accounts, credit cards, investments, identity and loans — with Claude (or any LLM) flagging
suspicious charges. Local-first SQLite MVP with a path to mobile.

Stack chosen for simplicity + easy future replacement:
- **Streamlit** → works in mobile browser now; swap to React Native / Flutter later with zero backend rework
- **SQLite** → swap to Postgres later
- **members.yaml** → replace with DB UI later
- **Model-agnostic LLM layer** → start with Claude Haiku, swap provider via env var

---

## Mobile feasibility note
Streamlit renders responsively in mobile browser — good enough for personal MVP.
For native mobile later: `db.py` + `sync.py` + `llm.py` are pure Python with no Streamlit dependency.
Adding a FastAPI layer in front of them requires **zero rework** of the data logic — just new routes.
So mobile is feasible without rewriting the core when the time comes.

---

## File Structure

```
finance-advisor/
├── pluggy_client.py        ← unchanged
├── members.yaml            ← family config
├── db.py                   ← SQLite schema + all query helpers
├── sync.py                 ← Pluggy → SQLite orchestration
├── llm/
│   ├── __init__.py
│   ├── base.py             ← abstract LLMProvider + factory
│   └── providers/
│       └── anthropic.py    ← Claude implementation
├── app.py                  ← Streamlit shell + sidebar
├── pages/
│   ├── 01_overview.py      ← family summary
│   ├── 02_member.py        ← per-member detail
│   └── 03_analysis.py      ← LLM flagged expenses
└── requirements.txt
```

---

## members.yaml Schema

```yaml
members:
  - id: dad
    name: Dad
    item_ids:
      - bd934bf2-c78e-499b-9393-c7a8017ae8d5
  - id: mom
    name: Mom
    item_ids:
      - some-item-uuid
```

---

## DB Schema (`db.py`) — store everything Pluggy returns

### `members`
| Column | Type |
|---|---|
| id | TEXT PK |
| name | TEXT |

### `items`
| Column | Type |
|---|---|
| item_id | TEXT PK |
| member_id | TEXT FK |
| connector_id | INTEGER |
| connector_name | TEXT |
| status | TEXT |
| last_synced_at | TEXT |

### `accounts`
| Column | Type |
|---|---|
| id | TEXT PK |
| item_id | TEXT FK |
| member_id | TEXT FK |
| name | TEXT |
| type | TEXT |
| subtype | TEXT |
| number | TEXT |
| balance | REAL |
| currency_code | TEXT |
| owner | TEXT |
| credit_limit | REAL |
| available_credit | REAL |
| balance_close_date | TEXT |
| balance_due_date | TEXT |
| minimum_payment | REAL |
| brand | TEXT |
| raw_json | TEXT |

### `transactions`
| Column | Type |
|---|---|
| id | TEXT PK |
| account_id | TEXT FK |
| member_id | TEXT FK |
| description | TEXT |
| description_raw | TEXT |
| amount | REAL |
| amount_in_account_currency | REAL |
| currency_code | TEXT |
| date | TEXT |
| type | TEXT |
| operation_type | TEXT |
| category | TEXT |
| category_id | TEXT |
| status | TEXT |
| balance_after | REAL |
| provider_code | TEXT |
| provider_id | TEXT |
| merchant_name | TEXT |
| merchant_cnpj | TEXT |
| payment_data_json | TEXT |
| credit_card_metadata_json | TEXT |
| raw_json | TEXT |

### `investments`
| Column | Type |
|---|---|
| id | TEXT PK |
| item_id | TEXT FK |
| member_id | TEXT FK |
| name | TEXT |
| type | TEXT |
| subtype | TEXT |
| raw_type | TEXT |
| code | TEXT |
| isin_code | TEXT |
| value | REAL |
| quantity | REAL |
| balance | REAL |
| taxes | REAL |
| taxes2 | REAL |
| currency_code | TEXT |
| date | TEXT |
| due_date | TEXT |
| annualized_rate | REAL |
| last_month_rate | REAL |
| last_12m_rate | REAL |
| issuer | TEXT |
| issuer_cnpj | TEXT |
| status | TEXT |
| number | TEXT |
| raw_json | TEXT |

### `identity`
| Column | Type |
|---|---|
| id | TEXT PK |
| item_id | TEXT FK |
| member_id | TEXT FK |
| full_name | TEXT |
| cpf_number | TEXT |
| birth_date | TEXT |
| phones_json | TEXT |
| emails_json | TEXT |
| addresses_json | TEXT |
| raw_json | TEXT |

### `credit_card_bills`
| Column | Type |
|---|---|
| id | TEXT PK |
| account_id | TEXT FK |
| member_id | TEXT FK |
| due_date | TEXT |
| closing_date | TEXT |
| balance | REAL |
| previous_balance | REAL |
| payment_amount | REAL |
| minimum_payment | REAL |
| currency_code | TEXT |
| raw_json | TEXT |

### `loans`
| Column | Type |
|---|---|
| id | TEXT PK |
| item_id | TEXT FK |
| member_id | TEXT FK |
| number | TEXT |
| type | TEXT |
| status | TEXT |
| contract_amount | REAL |
| outstanding_balance | REAL |
| installment_amount | REAL |
| installments_total | INTEGER |
| installments_paid | INTEGER |
| credit_date | TEXT |
| due_date | TEXT |
| interest_rate | REAL |
| currency_code | TEXT |
| raw_json | TEXT |

### `llm_analyses`
| Column | Type |
|---|---|
| id | INTEGER PK AUTOINCREMENT |
| member_id | TEXT FK |
| created_at | TEXT |
| window_days | INTEGER |
| provider | TEXT |
| model | TEXT |
| response_json | TEXT |
| flagged_count | INTEGER |

---

## LLM Layer (`llm/`) — model-agnostic

**`llm/base.py`**
```python
class LLMProvider(ABC):
    @abstractmethod
    def analyze_transactions(self, member_name: str, transactions: list[dict]) -> dict:
        ...

def get_provider() -> LLMProvider:
    provider = os.getenv("LLM_PROVIDER", "anthropic")
    if provider == "anthropic":
        from llm.providers.anthropic import AnthropicProvider
        return AnthropicProvider()
    raise ValueError(f"Unknown LLM_PROVIDER: {provider}")
```

**`llm/providers/anthropic.py`** — implements `analyze_transactions()` using `anthropic` SDK.

To add OpenAI later: create `llm/providers/openai.py`, set `LLM_PROVIDER=openai` in `.env`.

**Prompt design:**
- System: flag unusual bank fees, unknown recipients, atypical amounts, near-duplicates. Skip routine (supermarkets, subscriptions, salary). JSON only.
- User: member name + last N days DEBIT transactions (id, date, description, amount, currency, category, merchant). Cap at 200.
- Response: `{"flagged": [{"transaction_id": "...", "reason": "..."}]}`

**`.env` additions:**
```
ANTHROPIC_API_KEY=...
LLM_PROVIDER=anthropic
LLM_MODEL=claude-haiku-4-5-20251001
DB_PATH=finance.db
MEMBERS_YAML=members.yaml
```

---

## sync.py

- `load_members_yaml()` → parses config
- `sync_item(client, item_id, member_id)` → upserts accounts, investments, transactions (paginated), identity, bills, loans
- `paginate_transactions(client, account_id)` → follows `next` cursor to exhaustion
- `sync_all(progress_callback=None)` → authenticates once, iterates all members → all items

---

## Streamlit Layout

**`app.py`** — persistent sidebar: member radio, last sync time, Sync Now button

**`pages/01_overview.py`**
- `st.metric` row: total family balance | monthly spend | flagged items
- Per-member summary table

**`pages/02_member.py`**
- Bank accounts + credit cards (with limits)
- 30-day transactions dataframe (sortable, filterable)
- Investments grouped by type
- Loans summary if any

**`pages/03_analysis.py`**
- Shows last cached analysis with timestamp
- "Run Analysis" button → calls LLM, stores in DB
- Flagged items in `st.expander` (description | amount | reason)

---

## requirements.txt Additions

```
streamlit>=1.35.0
anthropic>=0.28.0
pyyaml>=6.0
pandas>=2.0.0
```

---

## Build Order

0. `PLAN.md` — copy this plan into the project directory for future reference
1. `members.yaml` + `db.py` — full schema, verify with `sqlite3` CLI
2. `sync.py` — verify all tables populate from sandbox
3. `app.py` + `pages/01_overview.py` — working UI with sync, no LLM
4. `pages/02_member.py` — full member detail
5. `llm/base.py` + `llm/providers/anthropic.py` — test standalone
6. `pages/03_analysis.py` — wire LLM into UI
7. Polish — empty states, None guards, currency formatting

---

## Verification

```bash
pip install -r requirements.txt
# fill members.yaml with real item IDs + .env with API keys
python sync.py               # verify DB populates
streamlit run app.py         # open browser, check all 3 pages
# on mobile: open browser → same URL on local network
```
