import streamlit as st
from dotenv import load_dotenv

load_dotenv()

from components.navigation import render_top_nav
from components.cards import accounts_card, credit_card, investments_card
from components.charts import balance_evolution_chart
from components.analytics import filter_by_institution
from components.cached_data import (
    get_all_members,
    get_accounts_for_member,
    get_items_for_member,
    get_all_items,
    get_investments_for_member,
    get_identity_for_member,
    get_balance_evolution,
)

st.set_page_config(page_title="Overview", page_icon="📊", layout="wide")
render_top_nav(active="overview")

st.header("Overview")
st.caption("A complete view of your financial data.")

member_id = st.session_state.get("selected_member_id")
institution_filter = st.session_state.get("institution_filter", [])

if member_id:
    identity = get_identity_for_member(member_id)
    if identity and identity.get("full_name"):
        st.caption(f"CPF: {identity['cpf_number'] or '—'}  |  DOB: {identity['birth_date'] or '—'}")

if member_id:
    member_ids = [member_id]
    items = get_items_for_member(member_id)
else:
    member_ids = [m["id"] for m in get_all_members()]
    items = get_all_items()

accounts = [a for mid in member_ids for a in get_accounts_for_member(mid)]
investments = [i for mid in member_ids for i in get_investments_for_member(mid)]

accounts = filter_by_institution(accounts, items, institution_filter)
investments = filter_by_institution(investments, items, institution_filter)

col1, col2, col3 = st.columns(3)
with col1:
    accounts_card(accounts, items)
with col2:
    credit_card(accounts)
with col3:
    investments_card(investments, items)

with st.container(border=True):
    st.markdown('<div class="fh-card-title">Balance Evolution</div>', unsafe_allow_html=True)
    balance_data = get_balance_evolution(member_id, months=24)
    balance_evolution_chart(balance_data)
