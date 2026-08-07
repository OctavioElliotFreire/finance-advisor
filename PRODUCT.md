# Product

<!-- impeccable:product-schema 1 -->

## Platform

web

## Users

Members of a Brazilian household managing shared family finances together. Each household is an independent tenant — members connect the family's bank accounts and see only their own household's data.

## Product Purpose

Family Finance connects to Brazilian financial institutions via Pluggy Open Finance, normalizes the data, and gives household members one combined view of their finances: accounts, credit cards, transactions, investments, loans, cash flow, balance history, and detected anomalies. An AI assistant answers free-text questions about the household's own data.

## Positioning

Automatic, multi-institution Open Finance sync (not manual entry) combined with per-household multi-tenant isolation and AI-assisted anomaly detection/explanation a spreadsheet or single-bank app can't offer.

## Operating Context

Household members log in via Supabase Auth, connect one or more real bank institutions through the Pluggy Connect flow, and a background sync worker keeps accounts/transactions/investments/loans up to date. Owners can invite other members and scope which connections each member can see. Currently verified end-to-end on Flutter Web against the real Pluggy sandbox; Android/iOS ship the same codebase but are not yet verified — mobile design/testing is explicitly deferred, not abandoned.

## Capabilities and Constraints

Multi-tenant household isolation is a hard constraint (every screen and every LLM prompt is scoped to the current household's access grants). Currency is BRL. No native iOS/Android design divergence — this is one Material Design product, not an adaptive per-OS one; "adaptive" work later would still start from this same Material system. Assistant/anomaly-explain features depend on an LLM provider (Gemini or Anthropic) and degrade to a clear error state when no API key is configured.

## Brand Commitments

None yet — no existing logo, marketing, or voice guide. Product name "Family Finance" and a teal (`Colors.teal`) accent are the only carried-over decisions; both are confirmed to keep, not open for reinterpretation in this pass.

## Evidence on Hand

No customer testimonials, case studies, or marketing assets exist — this is an internal/dev-stage product, not yet deployed for real users. Do not fabricate any.

## Product Principles

- Multi-tenant isolation is never compromised for visual convenience — every screen's data is household-scoped, and design changes must not blur that boundary (e.g. a shared/global-looking chrome must not read as cross-household).
- Trustworthy and precise over playful — this is where a family checks real account balances; legibility and correctness read louder than personality.
- Consistency over surprise across screens (Operate-mode default) — the same status/severity/loading/empty-state vocabulary everywhere, not per-screen invention.
- Real financial data, including negative/expense signage, must never be ambiguous — color and text both carry meaning, not color alone.

## Accessibility & Inclusion

Status/severity signaling must not rely on color alone (colorblind-safe) — confirmed as a requirement carried into the `StatusChip`/`SeverityChip` design (container-color + text, not just a colored dot).
