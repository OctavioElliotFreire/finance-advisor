import plotly.graph_objects as go
import streamlit as st

from components.formatting import format_currency, is_sensitive_hidden
from config.settings import CHART_PALETTE, PRIMARY_ACCENT


def _hex_to_rgba(hex_color: str, alpha: float) -> str:
    hex_color = hex_color.lstrip("#")
    r, g, b = (int(hex_color[i:i + 2], 16) for i in (0, 2, 4))
    return f"rgba({r},{g},{b},{alpha})"


def balance_evolution_chart(data: list[dict]) -> None:
    if not data:
        st.caption("Not enough transaction history to estimate a trend yet.")
        return

    months = [d["month"] for d in data]
    balances = [d["balance"] for d in data]
    hidden = is_sensitive_hidden()

    fig = go.Figure()
    fig.add_trace(go.Scatter(
        x=months,
        y=balances,
        mode="lines",
        line=dict(color=PRIMARY_ACCENT, width=2.5),
        fill="tozeroy",
        fillcolor=_hex_to_rgba(PRIMARY_ACCENT, 0.12),
        hovertemplate="%{x}<br>%{customdata}<extra></extra>" if not hidden else "%{x}<extra></extra>",
        customdata=[format_currency(b, hide_if_sensitive=False) for b in balances],
    ))

    tick_step = max(len(months) // 6, 1)
    fig.update_layout(
        margin=dict(l=0, r=0, t=10, b=0),
        height=280,
        plot_bgcolor="rgba(0,0,0,0)",
        paper_bgcolor="rgba(0,0,0,0)",
        showlegend=False,
        xaxis=dict(
            tickmode="array",
            tickvals=months[::tick_step],
            showgrid=False,
        ),
        yaxis=dict(showticklabels=not hidden, showgrid=False),
    )

    st.plotly_chart(fig, use_container_width=True, config={"displayModeBar": False})
    st.caption("Estimated from transaction history — Pluggy does not provide historical balance snapshots.")


def expense_category_bars(data: list[dict]) -> None:
    if not data:
        st.caption("No categorized expenses in this period.")
        return

    total = sum(d["total"] for d in data) or 1.0
    for i, d in enumerate(data):
        color = CHART_PALETTE[i % len(CHART_PALETTE)]
        pct = d["total"] / total * 100
        col1, col2 = st.columns([3, 1])
        with col1:
            st.markdown(
                f'<div class="fh-muted">{d["category"]}</div>'
                f'<div class="fh-progress-track"><div class="fh-progress-fill" '
                f'style="width:{pct}%;background-color:{color}"></div></div>',
                unsafe_allow_html=True,
            )
        with col2:
            st.markdown(f'<div class="fh-muted">{format_currency(d["total"])}</div>', unsafe_allow_html=True)


def allocation_bars(data: list[dict], label_key: str) -> None:
    if not data:
        st.caption("No data to show.")
        return

    for i, d in enumerate(data):
        color = CHART_PALETTE[i % len(CHART_PALETTE)]
        pct = d["pct_of_total"]
        col1, col2 = st.columns([3, 1])
        with col1:
            st.markdown(
                f'<div class="fh-muted">{d[label_key]}</div>'
                f'<div class="fh-progress-track"><div class="fh-progress-fill" '
                f'style="width:{pct}%;background-color:{color}"></div></div>',
                unsafe_allow_html=True,
            )
        with col2:
            st.markdown(f'<div class="fh-muted">{format_currency(d["value"])}</div>', unsafe_allow_html=True)
