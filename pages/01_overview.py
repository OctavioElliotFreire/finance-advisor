import streamlit as st
import pandas as pd

from helpers import get_family_summary, get_member_summary, get_current_month

st.set_page_config(page_title="Overview", page_icon="📊", layout="wide")
st.header("Overview")

month = get_current_month()
selected_id = st.session_state.get("selected_member_id")

if selected_id:
    # Single-member view
    name = st.session_state.get("selected_member_name", selected_id)
    summary = get_member_summary(selected_id, month)

    col1, col2, col3, col4 = st.columns(4)
    col1.metric("Bank Balance", f"R$ {summary['bank_balance']:,.2f}")
    col2.metric("Monthly Spend", f"R$ {summary['monthly_spend']:,.2f}")
    col3.metric("Investments", f"R$ {summary['investments_value']:,.2f}")
    col4.metric("Credit Available", f"R$ {summary['credit_available']:,.2f}")

else:
    # Family-wide view
    data = get_family_summary(month)

    col1, col2, col3 = st.columns(3)
    col1.metric("Total Bank Balance", f"R$ {data['total_bank_balance']:,.2f}")
    col2.metric("Total Monthly Spend", f"R$ {data['total_monthly_spend']:,.2f}")
    col3.metric("Total Investments", f"R$ {data['total_investments_value']:,.2f}")

    st.subheader("Per-member breakdown")
    if data["per_member"]:
        rows = []
        for m in data["per_member"]:
            rows.append({
                "Member": m["name"],
                "Bank Balance (R$)": round(m["bank_balance"], 2),
                "Monthly Spend (R$)": round(m["monthly_spend"], 2),
                "Investments (R$)": round(m["investments_value"], 2),
                "Credit Available (R$)": round(m["credit_available"], 2),
            })
        df = pd.DataFrame(rows)
        st.dataframe(df, use_container_width=True, hide_index=True)
    else:
        st.info("No data yet. Sync from the sidebar.")
