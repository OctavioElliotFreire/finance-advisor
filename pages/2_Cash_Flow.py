import json
import os

import streamlit as st
from dotenv import load_dotenv

load_dotenv()

import db
from llm.base import get_provider
from components.navigation import render_top_nav
from components.cards import flagged_transaction_expander
from components.charts import expense_category_bars
from components.analytics import group_expenses_by_category, upcoming_expenses
from components.cached_data import (
    get_all_members,
    get_accounts_for_member,
    get_items_for_member,
    get_all_items,
    get_transactions_for_member,
    get_credit_card_bills_for_member,
)
from components.formatting import format_currency, format_date, positive_negative_class
from helpers import get_current_month, shift_month

st.set_page_config(page_title="Cash Flow", page_icon="💸", layout="wide")
render_top_nav(active="cash_flow")

st.header("Cash Flow")
st.caption("Expenses, income, and account activity.")

member_id = st.session_state.get("selected_member_id")
institution_filter = st.session_state.get("institution_filter", [])
st.session_state.setdefault("cash_flow_month", get_current_month())

if member_id:
    member_ids = [member_id]
    items = get_items_for_member(member_id)
else:
    member_ids = [m["id"] for m in get_all_members()]
    items = get_all_items()

accounts = [a for mid in member_ids for a in get_accounts_for_member(mid)]
account_to_item = {a["id"]: a["item_id"] for a in accounts}
account_names = {a["id"]: a["name"] for a in accounts}

allowed_item_ids = None
if institution_filter:
    allowed_item_ids = {
        i["item_id"] for i in items
        if (i.get("connector_name") or "Unknown Institution") in institution_filter
    }

all_txns = [t for mid in member_ids for t in get_transactions_for_member(mid, days=400)]
if allowed_item_ids is not None:
    all_txns = [t for t in all_txns if account_to_item.get(t["account_id"]) in allowed_item_ids]

bills = [b for mid in member_ids for b in get_credit_card_bills_for_member(mid)]

# --- Expenses / Upcoming Expenses cards ---

month_txns = [t for t in all_txns if (t["date"] or "")[:7] == st.session_state["cash_flow_month"]]

col1, col2 = st.columns(2)
with col1:
    with st.container(border=True):
        st.markdown('<div class="fh-card-title">Expenses</div>', unsafe_allow_html=True)
        by_category = group_expenses_by_category(month_txns)
        total_expenses = sum(c["total"] for c in by_category)
        st.markdown(f"## {format_currency(total_expenses)}")
        expense_category_bars(by_category)

with col2:
    with st.container(border=True):
        st.markdown('<div class="fh-card-title">Upcoming Expenses</div>', unsafe_allow_html=True)
        upcoming = upcoming_expenses(bills, all_txns)
        total_upcoming = sum(u["amount"] for u in upcoming)
        st.markdown(f"## {format_currency(total_upcoming)}")
        if not upcoming:
            st.caption("No upcoming expenses.")
        for u in upcoming[:10]:
            st.write(f"{u['description']} — {format_currency(u['amount'])} due {format_date(u['due_date'])}")

st.divider()

# --- Transaction history panel ---

st.subheader("Transactions")

nav_col1, nav_col2, nav_col3 = st.columns([1, 2, 1])
with nav_col1:
    if st.button("← Previous month"):
        st.session_state["cash_flow_month"] = shift_month(st.session_state["cash_flow_month"], -1)
        st.rerun()
with nav_col2:
    st.markdown(f"<div style='text-align:center'>{st.session_state['cash_flow_month']}</div>", unsafe_allow_html=True)
with nav_col3:
    if st.button("Next month →"):
        st.session_state["cash_flow_month"] = shift_month(st.session_state["cash_flow_month"], 1)
        st.rerun()

total_income = sum(t["amount"] or 0.0 for t in month_txns if t["type"] == "CREDIT")
total_month_expenses = sum(abs(t["amount"] or 0.0) for t in month_txns if t["type"] == "DEBIT")
income_col, expense_col = st.columns(2)
income_col.metric("Total Income", format_currency(total_income))
expense_col.metric("Total Expenses", format_currency(total_month_expenses))

search_col, filter_col = st.columns([3, 1])
with search_col:
    search = st.text_input("Search", placeholder="Search transactions...", label_visibility="collapsed")
with filter_col:
    type_filter = st.selectbox("Type", ["All", "Income", "Expenses"], label_visibility="collapsed")

visible_txns = month_txns
if search:
    s = search.lower()
    visible_txns = [t for t in visible_txns if s in (t.get("description") or "").lower()]
if type_filter == "Income":
    visible_txns = [t for t in visible_txns if t["type"] == "CREDIT"]
elif type_filter == "Expenses":
    visible_txns = [t for t in visible_txns if t["type"] == "DEBIT"]

if not visible_txns:
    st.info("No transactions match your filters for this month.")

by_date: dict[str, list] = {}
for t in visible_txns:
    day = (t["date"] or "")[:10]
    by_date.setdefault(day, []).append(t)

with st.container(height=400):
    for day in sorted(by_date, reverse=True):
        st.markdown(f"**{day}**")
        for t in by_date[day]:
            icon = "⬇" if t["type"] == "DEBIT" else "⬆"
            amount = t["amount"] if t["type"] == "CREDIT" else -abs(t["amount"] or 0.0)
            css_class = positive_negative_class(amount)
            row_col1, row_col2 = st.columns([4, 1])
            with row_col1:
                st.write(f"{icon} {t.get('description') or ''} · {account_names.get(t['account_id'], '—')} · {t.get('category') or 'Uncategorized'}")
            with row_col2:
                st.markdown(f'<span class="{css_class}">{format_currency(amount)}</span>', unsafe_allow_html=True)

st.divider()

# --- Flagged Transactions (LLM) ---

st.subheader("Flagged Transactions")

if not member_id:
    st.info("Select a member to run anomaly analysis.")
else:
    member_name = st.session_state.get("selected_member_name", member_id)
    if st.button("Run Analysis"):
        with st.spinner("Analyzing transactions..."):
            try:
                analysis_txns = get_transactions_for_member(member_id, days=90)
                provider = get_provider()
                result = provider.analyze_transactions(member_name, analysis_txns)
                flagged = result.get("flagged", [])
                provider_name = os.getenv("LLM_PROVIDER", "anthropic")
                db.save_llm_analysis(member_id, 90, provider_name, provider.model, result, len(flagged))
                st.success(f"Analysis complete: {len(flagged)} flagged.")
                st.rerun()
            except Exception as e:
                st.error(f"Analysis failed: {e}")

    latest = db.get_latest_analysis(member_id)
    if latest:
        response = json.loads(latest["response_json"])
        flagged = response.get("flagged", [])
        st.caption(f"Last run: {format_date(latest['created_at'])} — {latest['flagged_count']} flagged ({latest['provider']}/{latest['model']})")
        recent_txns = get_transactions_for_member(member_id, days=90)
        txns_by_id = {t["id"]: t for t in recent_txns}
        flagged_transaction_expander(flagged, txns_by_id)
    else:
        st.caption("No analysis run yet.")
