"""Presentational card renderers. Take pre-fetched data only -- never call db.py."""

import json

import streamlit as st

from components.analytics import (
    group_accounts_by_institution,
    credit_utilization,
    group_investments_by_type,
    group_investments_by_institution,
    connection_status_bucket,
)
from components.charts import allocation_bars
from components.formatting import format_currency, format_percentage, format_date, mask_account_number
from config.settings import institution_label, asset_class_label


def accounts_card(accounts: list[dict], items: list[dict]) -> None:
    bank_accounts = [a for a in accounts if a["type"] == "BANK"]
    total = sum(a["balance"] or 0.0 for a in bank_accounts)
    groups = group_accounts_by_institution(bank_accounts, items)

    with st.container(border=True):
        st.markdown('<div class="fh-card-title">Accounts</div>', unsafe_allow_html=True)
        st.markdown(f"## {format_currency(total)}")
        if not groups:
            st.caption("No bank accounts connected.")
        for g in groups:
            with st.expander(f"{g['name']} — {g['account_count']} account(s) — {format_currency(g['balance'])}"):
                st.write(f"Share of total balance: {format_percentage(g['pct_of_total'])}")


def credit_card(accounts: list[dict]) -> None:
    credit_accounts = [a for a in accounts if a["type"] == "CREDIT"]
    util = credit_utilization(credit_accounts)
    pct = min(util["utilization_pct"], 100.0)

    with st.container(border=True):
        st.markdown('<div class="fh-card-title">Credit & Cards</div>', unsafe_allow_html=True)
        st.markdown(f"## {format_currency(util['total_balance_outstanding'])}")
        st.caption(
            f"Outstanding of {format_currency(util['total_limit'])} limit — "
            f"{format_percentage(util['utilization_pct'])} utilization"
        )
        st.markdown(
            f'<div class="fh-progress-track"><div class="fh-progress-fill" style="width:{pct}%"></div></div>',
            unsafe_allow_html=True,
        )
        if not credit_accounts:
            st.caption("No credit cards connected.")
        for a in credit_accounts:
            limit = a["credit_limit"] or 0.0
            available = a["available_credit"] or 0.0
            used = limit - available
            label = f"{a['name']} ({a.get('brand') or a['subtype'] or '—'}) {mask_account_number(a['number'])}"
            st.write(f"**{label}** — {format_currency(used)} used of {format_currency(limit)}")


def investments_card(investments: list[dict], items: list[dict]) -> None:
    active = [i for i in investments if i.get("status") != "TOTAL_WITHDRAWAL"]
    total = sum(i["balance"] or 0.0 for i in active)
    by_type = group_investments_by_type(investments)
    by_institution = group_investments_by_institution(investments, items)

    with st.container(border=True):
        st.markdown('<div class="fh-card-title">Investments</div>', unsafe_allow_html=True)
        st.markdown(f"## {format_currency(total)}")
        st.caption(f"{len(by_type)} asset class(es) — {len(active)} asset(s)")
        tab1, tab2 = st.tabs(["Asset Classes", "Institutions"])
        with tab1:
            allocation_bars(by_type, label_key="type")
        with tab2:
            allocation_bars(by_institution, label_key="name")


def portfolio_row(investment: dict, institution_name: str) -> None:
    raw = json.loads(investment.get("raw_json") or "{}")
    current_value = investment.get("balance") or 0.0
    invested = raw.get("amount")
    profit = raw.get("amountProfit")
    return_pct = (profit / invested * 100) if invested and profit is not None else None
    purchase_date = raw.get("purchaseDate") or investment.get("date")

    header = f"{investment.get('name') or 'Unnamed asset'} — {format_currency(current_value)}"
    with st.expander(header):
        st.caption(f"{institution_label(institution_name)} — {asset_class_label(investment.get('type'))}")
        col1, col2, col3 = st.columns(3)
        col1.metric("Current Value", format_currency(current_value))
        if invested is not None:
            col2.metric("Invested", format_currency(invested))
        if profit is not None:
            col3.metric(
                "Profit/Loss",
                format_currency(profit),
                delta=format_percentage(return_pct) if return_pct is not None else None,
            )
        st.caption(f"Purchase date: {format_date(purchase_date)}")
        if investment.get("due_date"):
            st.caption(f"Maturity date: {format_date(investment['due_date'])}")
        identifier = investment.get("code") or investment.get("isin_code")
        if identifier:
            st.caption(f"Identifier: {identifier}")


_BUCKET_STYLE = {
    "Connected": "fh-positive",
    "Needs Attention": "fh-negative",
    "Synchronizing": "fh-warning",
    "Disconnected": "fh-muted",
}


def connection_tile(item: dict, account_count: int) -> None:
    label = connection_status_bucket(item.get("status"))
    css_class = _BUCKET_STYLE[label]

    with st.container(border=True):
        st.markdown(f"**{institution_label(item.get('connector_name'))}**")
        st.markdown(f'<span class="{css_class}">{label}</span>', unsafe_allow_html=True)
        st.caption(f"{account_count} account(s)")
        last_sync = item.get("last_synced_at")
        st.caption(f"Last sync: {format_date(last_sync)}" if last_sync else "Never synced")


def flagged_transaction_expander(flagged: list[dict], transactions_by_id: dict[str, dict]) -> None:
    if not flagged:
        st.caption("No flagged transactions.")
        return
    for f in flagged:
        txn = transactions_by_id.get(f.get("transaction_id"))
        title = txn["description"] if txn else f.get("transaction_id", "Unknown transaction")
        amount = format_currency(txn["amount"]) if txn else "—"
        with st.expander(f"{title} — {amount}"):
            st.write(f.get("reason", ""))
