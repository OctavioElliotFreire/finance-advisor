import streamlit as st
from dotenv import load_dotenv

load_dotenv()

from components.navigation import render_top_nav
from components.cards import portfolio_row
from components.analytics import filter_by_institution
from components.cached_data import (
    get_all_members,
    get_items_for_member,
    get_all_items,
    get_investments_for_member,
    get_loans_for_member,
)
from components.formatting import format_currency
from config.settings import asset_class_label, institution_label

st.set_page_config(page_title="Assets", page_icon="📈", layout="wide")
render_top_nav(active="assets")

st.header("Assets")
st.caption("Your investments and portfolio activity.")

member_id = st.session_state.get("selected_member_id")
institution_filter = st.session_state.get("institution_filter", [])

if member_id:
    member_ids = [member_id]
    items = get_items_for_member(member_id)
else:
    member_ids = [m["id"] for m in get_all_members()]
    items = get_all_items()

investments = [i for mid in member_ids for i in get_investments_for_member(mid)]
loans = [l for mid in member_ids for l in get_loans_for_member(mid)]

investments = filter_by_institution(investments, items, institution_filter)
active_investments = [i for i in investments if i.get("status") != "TOTAL_WITHDRAWAL"]
item_to_institution = {i["item_id"]: i.get("connector_name") for i in items}

with st.container(border=True):
    header_col, total_col = st.columns([3, 1])
    with header_col:
        st.markdown('<div class="fh-card-title">Portfolio</div>', unsafe_allow_html=True)
        st.caption(f"{len(active_investments)} asset(s)")
    with total_col:
        total_value = sum(i.get("balance") or 0.0 for i in active_investments)
        st.markdown(f"### {format_currency(total_value)}")

    asset_class_options = sorted({asset_class_label(i.get("type")) for i in active_investments})
    institution_options = sorted({institution_label(item_to_institution.get(i["item_id"])) for i in active_investments})

    filter_col1, filter_col2 = st.columns(2)
    with filter_col1:
        selected_classes = st.multiselect("Asset class", asset_class_options, key="assets_class_filter")
    with filter_col2:
        selected_institutions = st.multiselect("Institution", institution_options, key="assets_institution_filter")

    visible = active_investments
    if selected_classes:
        visible = [i for i in visible if asset_class_label(i.get("type")) in selected_classes]
    if selected_institutions:
        visible = [i for i in visible if institution_label(item_to_institution.get(i["item_id"])) in selected_institutions]

    if not visible:
        st.info("No assets match your filters." if active_investments else "No investments synced yet.")

    by_class: dict[str, list] = {}
    for i in visible:
        by_class.setdefault(asset_class_label(i.get("type")), []).append(i)

    for asset_class, group in sorted(by_class.items()):
        st.subheader(asset_class)
        for inv in group:
            portfolio_row(inv, item_to_institution.get(inv["item_id"]))

st.divider()
st.subheader("Loans")

active_loans = [l for l in loans if l["status"] not in ("SETTLED", "CANCELLED")]
if active_loans:
    for l in active_loans:
        with st.expander(f"{l['type'] or 'Loan'} — {format_currency(l['outstanding_balance'])} outstanding"):
            st.write(f"Installment: {format_currency(l['installment_amount'])}")
            st.write(f"Paid / Total: {l['installments_paid'] or 0} / {l['installments_total'] or 0}")
            st.write(f"Due date: {l['due_date'] or '—'}")
else:
    st.caption("No active loans.")
