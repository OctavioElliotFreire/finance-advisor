from datetime import datetime

import streamlit as st

from config.settings import CURRENCY_SYMBOL, DATE_FORMAT, DECIMAL_SEP, THOUSANDS_SEP

# Presets the locale selector (components/navigation.py) can switch between at
# runtime. Config defaults above remain the source of truth when no override
# is active in session state.
LOCALE_PRESETS = {
    "pt-BR": {"symbol": "R$", "thousands_sep": ".", "decimal_sep": ","},
    "en-US": {"symbol": "$", "thousands_sep": ",", "decimal_sep": "."},
}


def _active_locale() -> dict:
    override = st.session_state.get("locale")
    return LOCALE_PRESETS.get(override, {
        "symbol": CURRENCY_SYMBOL,
        "thousands_sep": THOUSANDS_SEP,
        "decimal_sep": DECIMAL_SEP,
    })


def _format_number(value: float, decimals: int = 2) -> str:
    locale = _active_locale()
    formatted = f"{value:,.{decimals}f}"
    return (
        formatted.replace(",", "\x00")
        .replace(".", locale["decimal_sep"])
        .replace("\x00", locale["thousands_sep"])
    )


def is_sensitive_hidden() -> bool:
    return not st.session_state.get("show_sensitive_values", True)


def format_currency(value: float | None, hide_if_sensitive: bool = True) -> str:
    if hide_if_sensitive and is_sensitive_hidden():
        return "••••••"
    value = value or 0.0
    symbol = _active_locale()["symbol"]
    return f"{symbol} {_format_number(value, 2)}"


def format_compact_number(value: float | None, hide_if_sensitive: bool = True) -> str:
    if hide_if_sensitive and is_sensitive_hidden():
        return "••••••"
    value = value or 0.0
    symbol = _active_locale()["symbol"]
    abs_value = abs(value)
    sign = "-" if value < 0 else ""
    if abs_value >= 1_000_000:
        return f"{sign}{symbol} {abs_value / 1_000_000:.1f}M"
    if abs_value >= 1_000:
        return f"{sign}{symbol} {abs_value / 1_000:.1f}k"
    return f"{sign}{symbol} {_format_number(abs_value, 2)}"


def format_percentage(value: float | None, decimals: int = 1) -> str:
    value = value or 0.0
    return f"{value:.{decimals}f}%"


def format_date(date_str: str | None) -> str:
    if not date_str:
        return "—"
    try:
        dt = datetime.fromisoformat(date_str[:19])
    except ValueError:
        return date_str
    return dt.strftime(DATE_FORMAT)


def positive_negative_class(value: float | None) -> str:
    value = value or 0.0
    if value > 0:
        return "fh-positive"
    if value < 0:
        return "fh-negative"
    return "fh-muted"


def mask_account_number(number: str | None) -> str:
    if not number:
        return "••••"
    digits = "".join(ch for ch in number if ch.isdigit())
    if len(digits) < 4:
        return "••••"
    return f"•••• {digits[-4:]}"
