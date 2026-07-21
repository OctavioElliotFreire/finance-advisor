"""Sticky top nav: branding, page links, member/institution/locale/theme/sensitive controls.

Composition order used by every data-bearing page: member switch -> institution
filter -> page-local filters (date/category/search/etc).
"""

from pathlib import Path

import streamlit as st

from config.settings import LOGO_TEXT, NAV_LABELS
from components.cached_data import get_all_members, get_items_for_member, get_all_items

CSS_PATH = Path(__file__).resolve().parent.parent / "styles" / "styles.css"

NAV_PAGES = [
    ("overview", NAV_LABELS["overview"], "pages/1_Overview.py"),
    ("cash_flow", NAV_LABELS["cash_flow"], "pages/2_Cash_Flow.py"),
    ("assets", NAV_LABELS["assets"], "pages/3_Assets.py"),
    ("connections", NAV_LABELS["connections"], "pages/4_Connections.py"),
]


def _inject_css() -> None:
    if st.session_state.get("_css_injected"):
        return
    css = CSS_PATH.read_text(encoding="utf-8")
    st.markdown(f"<style>{css}</style>", unsafe_allow_html=True)
    st.session_state["_css_injected"] = True


def init_session_state() -> None:
    st.session_state.setdefault("selected_member_id", None)
    st.session_state.setdefault("selected_member_name", "All")
    st.session_state.setdefault("institution_filter", [])
    st.session_state.setdefault("show_sensitive_values", True)
    st.session_state.setdefault("theme", "light")
    st.session_state.setdefault("locale", "pt-BR")


def _apply_theme() -> None:
    theme = st.session_state.get("theme", "light")
    st.markdown(
        f"<script>document.documentElement.setAttribute('data-theme', '{theme}');</script>",
        unsafe_allow_html=True,
    )


def _institution_options(member_id: str | None) -> list[str]:
    items = get_items_for_member(member_id) if member_id else get_all_items()
    return sorted({i.get("connector_name") or "Unknown Institution" for i in items})


def render_top_nav(active: str | None = None) -> None:
    init_session_state()
    _inject_css()
    _apply_theme()

    members = get_all_members()
    member_names = ["All"] + [m["name"] for m in members]

    with st.container(key="fh_topnav"):
        brand_col, *nav_cols, controls_col = st.columns([2] + [1] * len(NAV_PAGES) + [4])

        with brand_col:
            st.markdown(f'<span class="fh-brand">{LOGO_TEXT}</span>', unsafe_allow_html=True)

        for col, (key, label, path) in zip(nav_cols, NAV_PAGES):
            with col:
                if key == active:
                    st.markdown(f'<span class="fh-nav-item active">{label}</span>', unsafe_allow_html=True)
                else:
                    st.page_link(path, label=label)

        with controls_col:
            member_ctrl, inst_ctrl, locale_ctrl, sens_ctrl, theme_ctrl = st.columns(5)

            with member_ctrl:
                current_name = st.session_state["selected_member_name"]
                idx = member_names.index(current_name) if current_name in member_names else 0
                chosen = st.selectbox("Member", member_names, index=idx, key="member_select_widget", label_visibility="collapsed")
                if chosen == "All":
                    st.session_state["selected_member_id"] = None
                    st.session_state["selected_member_name"] = "All"
                else:
                    m = next(x for x in members if x["name"] == chosen)
                    st.session_state["selected_member_id"] = m["id"]
                    st.session_state["selected_member_name"] = m["name"]

            with inst_ctrl:
                options = _institution_options(st.session_state["selected_member_id"])
                valid_current = [v for v in st.session_state["institution_filter"] if v in options]
                selected = st.multiselect(
                    "Institutions", options=options, default=valid_current,
                    key="institution_filter_widget", label_visibility="collapsed",
                    placeholder="All institutions",
                )
                st.session_state["institution_filter"] = selected

            with locale_ctrl:
                locale_options = ["pt-BR", "en-US"]
                idx = locale_options.index(st.session_state["locale"]) if st.session_state["locale"] in locale_options else 0
                st.session_state["locale"] = st.selectbox(
                    "Locale", locale_options, index=idx, key="locale_widget", label_visibility="collapsed",
                )

            with sens_ctrl:
                st.session_state["show_sensitive_values"] = st.toggle(
                    "Show values", value=st.session_state["show_sensitive_values"], key="sensitive_widget",
                )

            with theme_ctrl:
                is_dark = st.toggle("Dark", value=(st.session_state["theme"] == "dark"), key="theme_widget")
                st.session_state["theme"] = "dark" if is_dark else "light"
