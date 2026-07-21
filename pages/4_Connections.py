import streamlit as st
from dotenv import load_dotenv

load_dotenv()

from components.navigation import render_top_nav
from components.cards import connection_tile
from components.analytics import connection_status_bucket
from components.cached_data import get_items_for_member, get_all_items, get_accounts_for_member
from sync import sync_single_item
from config.settings import institution_label

st.set_page_config(page_title="Connections", page_icon="🔗", layout="wide")
render_top_nav(active="connections")

st.header("Connections")
st.caption("Manage your connected financial-data providers.")

member_id = st.session_state.get("selected_member_id")

if member_id:
    items = get_items_for_member(member_id)
    account_counts: dict[str, int] = {}
    for a in get_accounts_for_member(member_id):
        account_counts[a["item_id"]] = account_counts.get(a["item_id"], 0) + 1
else:
    items = get_all_items()
    account_counts = {}
    for i in items:
        for a in get_accounts_for_member(i["member_id"]):
            account_counts[a["item_id"]] = account_counts.get(a["item_id"], 0) + 1

search_col, status_col = st.columns([3, 1])
with search_col:
    search = st.text_input("Search", placeholder="Search institutions...", label_visibility="collapsed")
with status_col:
    status_options = ["All", "Connected", "Needs Attention", "Synchronizing", "Disconnected"]
    status_filter = st.selectbox("Status", status_options, label_visibility="collapsed")

filtered = items
if search:
    search_lower = search.lower()
    filtered = [i for i in filtered if search_lower in institution_label(i.get("connector_name")).lower()]
if status_filter != "All":
    filtered = [i for i in filtered if connection_status_bucket(i.get("status")) == status_filter]

if not filtered:
    st.info("No connections match your filters." if items else "No connections yet. Click **Sync Now** on the home page.")

cols_per_row = 3
for row_start in range(0, len(filtered), cols_per_row):
    row_items = filtered[row_start:row_start + cols_per_row]
    cols = st.columns(cols_per_row)
    for col, item in zip(cols, row_items):
        with col:
            connection_tile(item, account_counts.get(item["item_id"], 0))
            if st.button("Refresh", key=f"refresh_{item['item_id']}", use_container_width=True):
                with st.spinner(f"Refreshing {institution_label(item.get('connector_name'))}..."):
                    try:
                        sync_single_item(item["item_id"], item["member_id"])
                        st.cache_data.clear()
                        st.success("Refreshed.")
                        st.rerun()
                    except Exception as e:
                        st.error(f"Refresh failed: {e}")
