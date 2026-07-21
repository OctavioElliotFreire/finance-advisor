"""st.cache_data-wrapped DB/helpers reads, shared across pages.

Kept separate from db.py/helpers.py so those stay framework-agnostic and
testable without Streamlit. Invalidated via st.cache_data.clear() after any
sync (app.py's Sync Now, Connections page's Refresh).
"""

import streamlit as st

import db
import helpers

get_all_members = st.cache_data(db.get_all_members)
get_accounts_for_member = st.cache_data(db.get_accounts_for_member)
get_items_for_member = st.cache_data(db.get_items_for_member)
get_all_items = st.cache_data(db.get_all_items)
get_investments_for_member = st.cache_data(db.get_investments_for_member)
get_loans_for_member = st.cache_data(db.get_loans_for_member)
get_credit_card_bills_for_member = st.cache_data(db.get_credit_card_bills_for_member)
get_identity_for_member = st.cache_data(db.get_identity_for_member)
get_transactions_for_member = st.cache_data(db.get_transactions_for_member)
get_balance_evolution = st.cache_data(helpers.get_balance_evolution)
