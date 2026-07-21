import streamlit as st
from dotenv import load_dotenv

load_dotenv()

import db
from db import init_schema, get_all_members, get_last_sync_time
from sync import sync_all
from components.navigation import render_top_nav, init_session_state
from config.settings import APP_NAME

db.init_schema()

st.set_page_config(
    page_title=APP_NAME,
    page_icon="💰",
    layout="wide",
    initial_sidebar_state="collapsed",
)

init_session_state()
render_top_nav(active=None)

st.header(APP_NAME)
st.write("Select a page from the top navigation to get started.")

members = get_all_members()

if not members:
    st.info(
        "No members synced yet. Add your family members to `members.yaml` "
        "and click **Sync Now**."
    )

if members:
    last_sync = get_last_sync_time(members[0]["id"])
    if last_sync:
        st.caption(f"Last sync: {last_sync[:19].replace('T', ' ')} UTC")
    else:
        st.caption("Not synced yet")

if st.button("Sync Now", type="primary"):
    with st.spinner("Syncing..."):
        progress_box = st.empty()
        messages = []

        def on_progress(msg: str) -> None:
            messages.append(msg)
            progress_box.text("\n".join(messages[-6:]))

        try:
            result = sync_all(progress_callback=on_progress)
            st.cache_data.clear()
            st.success(
                f"Done: {result['members_synced']} member(s), "
                f"{result['items_synced']} item(s) synced."
            )
            st.rerun()
        except Exception as e:
            st.error(f"Sync failed: {e}")
