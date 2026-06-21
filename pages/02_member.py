import json

import pandas as pd
import streamlit as st

from db import (
    get_accounts_for_member,
    get_transactions_for_member,
    get_investments_for_member,
    get_loans_for_member,
    get_identity_for_member,
)

st.set_page_config(page_title="Member Detail", page_icon="👤", layout="wide")

member_id = st.session_state.get("selected_member_id")
member_name = st.session_state.get("selected_member_name", "")

if not member_id:
    st.info("Select a specific member from the sidebar.")
    st.stop()

st.header(f"{member_name}")

# --- Identity ---
identity = get_identity_for_member(member_id)
if identity and identity.get("full_name"):
    st.caption(f"CPF: {identity['cpf_number'] or '—'}  |  DOB: {identity['birth_date'] or '—'}")

# --- Accounts ---
accounts = get_accounts_for_member(member_id)
bank_accounts = [a for a in accounts if a["type"] == "BANK"]
credit_accounts = [a for a in accounts if a["type"] == "CREDIT"]

col_bank, col_credit = st.columns(2)

with col_bank:
    st.subheader("Bank Accounts")
    if bank_accounts:
        for a in bank_accounts:
            bal = a["balance"] or 0.0
            st.metric(
                label=f"{a['name']} ({a['subtype'] or '—'})",
                value=f"R$ {bal:,.2f}",
                help=f"Account #{a['number'] or '—'} | Owner: {a['owner'] or '—'}",
            )
    else:
        st.caption("No bank accounts.")

with col_credit:
    st.subheader("Credit Cards")
    if credit_accounts:
        for a in credit_accounts:
            limit = a["credit_limit"] or 0.0
            avail = a["available_credit"] or 0.0
            used = limit - avail
            st.metric(
                label=f"{a['name']} ({a.get('brand') or a['subtype'] or '—'})",
                value=f"R$ {avail:,.2f} available",
                delta=f"R$ {used:,.2f} used",
                delta_color="inverse",
                help=f"Limit: R$ {limit:,.2f}",
            )
    else:
        st.caption("No credit cards.")

st.divider()

# --- Transactions ---
st.subheader("Transactions")

days_options = {30: "Last 30 days", 60: "Last 60 days", 90: "Last 90 days", 365: "Last 12 months"}
days = st.selectbox("Period", options=list(days_options.keys()), format_func=lambda d: days_options[d])

txns = get_transactions_for_member(member_id, days=days)

if txns:
    rows = []
    for t in txns:
        rows.append({
            "Date": t["date"][:10] if t["date"] else "",
            "Description": t["description"] or "",
            "Amount (R$)": round(t["amount"] or 0.0, 2),
            "Type": t["type"] or "",
            "Category": t["category"] or "",
            "Merchant": t["merchant_name"] or "",
            "Status": t["status"] or "",
        })
    df = pd.DataFrame(rows)
    df["Date"] = pd.to_datetime(df["Date"])

    # colour DEBIT rows red, CREDIT green
    def _style(row):
        colour = "#ffcccc" if row["Type"] == "DEBIT" else "#ccffcc"
        return [f"background-color: {colour}"] * len(row)

    st.dataframe(
        df.style.apply(_style, axis=1),
        use_container_width=True,
        hide_index=True,
    )
    st.caption(f"{len(txns)} transaction(s)")
else:
    st.info("No transactions in this period.")

st.divider()

# --- Investments ---
st.subheader("Investments")

investments = get_investments_for_member(member_id)
active_inv = [i for i in investments if i["status"] != "TOTAL_WITHDRAWAL"]

if active_inv:
    by_type: dict[str, list] = {}
    for inv in active_inv:
        t = inv["type"] or "OTHER"
        by_type.setdefault(t, []).append(inv)

    for inv_type, items in sorted(by_type.items()):
        total = sum(i["value"] or 0.0 for i in items)
        with st.expander(f"{inv_type} — R$ {total:,.2f}", expanded=True):
            rows = []
            for i in items:
                rows.append({
                    "Name": i["name"] or "",
                    "Value (R$)": round(i["value"] or 0.0, 2),
                    "Annual Rate": f"{(i['annualized_rate'] or 0)*100:.2f}%" if i["annualized_rate"] else "—",
                    "Due Date": i["due_date"] or "—",
                    "Status": i["status"] or "",
                })
            st.dataframe(pd.DataFrame(rows), use_container_width=True, hide_index=True)
else:
    st.info("No active investments.")

st.divider()

# --- Loans ---
st.subheader("Loans")

loans = get_loans_for_member(member_id)
active_loans = [l for l in loans if l["status"] not in ("SETTLED", "CANCELLED")]

if active_loans:
    rows = []
    for l in active_loans:
        rows.append({
            "Type": l["type"] or "",
            "Outstanding (R$)": round(l["outstanding_balance"] or 0.0, 2),
            "Installment (R$)": round(l["installment_amount"] or 0.0, 2),
            "Paid / Total": f"{l['installments_paid'] or 0} / {l['installments_total'] or 0}",
            "Rate": f"{(l['interest_rate'] or 0)*100:.2f}%" if l["interest_rate"] else "—",
            "Due Date": l["due_date"] or "—",
            "Status": l["status"] or "",
        })
    st.dataframe(pd.DataFrame(rows), use_container_width=True, hide_index=True)
else:
    st.info("No active loans.")
