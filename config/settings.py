"""Central configuration: branding, currency/locale, design tokens, labels.

Change values here to re-brand, re-currency, or re-locale the dashboard —
no component code should ever hardcode a color, currency symbol, or label.
"""

APP_NAME = "Family Finance"
LOGO_TEXT = "Family Finance"

CURRENCY_CODE = "BRL"
CURRENCY_SYMBOL = "R$"
LOCALE = "pt-BR"
DATE_FORMAT = "%d/%m/%Y"
# pt-BR uses '.' as thousands separator and ',' as decimal separator
THOUSANDS_SEP = "."
DECIMAL_SEP = ","

NAV_LABELS = {
    "overview": "Overview",
    "cash_flow": "Cash Flow",
    "assets": "Assets",
    "connections": "Connections",
}

# Optional display-name overrides, keyed by raw value from the DB
# (connector_name, investments.type). Anything not listed passes through as-is.
INSTITUTION_LABELS: dict[str, str] = {}
ASSET_CLASS_LABELS: dict[str, str] = {}

# --- Design tokens ---

COLORS_LIGHT = {
    "page_bg": "#FAFAFA",
    "card_bg": "#FFFFFF",
    "text_primary": "#111111",
    "text_secondary": "#737373",
    "border": "#E5E5E5",
}

COLORS_DARK = {
    "page_bg": "#121212",
    "card_bg": "#1C1C1E",
    "text_primary": "#F5F5F5",
    "text_secondary": "#A3A3A3",
    "border": "#2E2E2E",
}

PRIMARY_ACCENT = "#FF3158"
POSITIVE = "#2FBF71"
WARNING = "#F4B942"
NEGATIVE = "#E5484D"

CARD_RADIUS_PX = 16

# Reusable palette for category bars / chart series (accent first, then a
# spread of distinguishable hues).
CHART_PALETTE = [
    PRIMARY_ACCENT,
    "#3B82F6",
    "#F4B942",
    "#2FBF71",
    "#8B5CF6",
    "#EC4899",
    "#14B8A6",
    "#F97316",
]


def institution_label(raw_name: str | None) -> str:
    if not raw_name:
        return "Unknown Institution"
    return INSTITUTION_LABELS.get(raw_name, raw_name)


def asset_class_label(raw_type: str | None) -> str:
    if not raw_type:
        return "Other"
    return ASSET_CLASS_LABELS.get(raw_type, raw_type)
