import os

import streamlit as st
from dotenv import load_dotenv

load_dotenv()

import db
from db import init_schema, get_all_members, get_last_sync_time
from sync import sync_all

db.init_schema()

st.set_page_config(
    page_title="Family Finance",
    page_icon="💰",
    layout="wide",
    initial_sidebar_state="expanded",
)

# --- Sidebar ---
with st.sidebar:
    st.title("Family Finance")

    members = get_all_members()
    member_names = ["All"] + [m["name"] for m in members]
    selected_name = st.radio("Member", member_names, index=0)

    if selected_name == "All":
        st.session_state["selected_member_id"] = None
        st.session_state["selected_member_name"] = "All"
    else:
        m = next(x for x in members if x["name"] == selected_name)
        st.session_state["selected_member_id"] = m["id"]
        st.session_state["selected_member_name"] = m["name"]

    # Last sync time
    if members:
        last_sync = get_last_sync_time(members[0]["id"])
        if last_sync:
            ts = last_sync[:19].replace("T", " ")
            st.caption(f"Last sync: {ts} UTC")
        else:
            st.caption("Not synced yet")

    st.divider()

    if st.button("Sync Now", use_container_width=True, type="primary"):
        with st.spinner("Syncing..."):
            progress_box = st.empty()
            messages = []

            def on_progress(msg: str) -> None:
                messages.append(msg)
                progress_box.text("\n".join(messages[-6:]))

            try:
                result = sync_all(progress_callback=on_progress)
                st.success(
                    f"Done: {result['members_synced']} member(s), "
                    f"{result['items_synced']} item(s) synced."
                )
                st.rerun()
            except Exception as e:
                st.error(f"Sync failed: {e}")

# --- Default landing ---
st.header("Family Finance Dashboard")
st.write("Select a page from the left navigation to get started.")

if not members:
    st.info(
        "No members synced yet. Add your family members to `members.yaml` "
        "and click **Sync Now**."
    )
