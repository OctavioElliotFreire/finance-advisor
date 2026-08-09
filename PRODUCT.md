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

Multi-tenant household isolation is a hard constraint (every screen and every LLM prompt is scoped to the current household's access grants). Currency is BRL. No native iOS/Android design divergence — this is one Material Design product, not an adaptive per-OS one; "adaptive" work later would still start from this same Material system. Assistant/anomaly-explain features depend on an LLM provider (Gemini or Anthropic) and degrade to a clear error state when no API key is configured. UI language is moving to pt-BR (was English/locale-neutral) as part of the redesign in `design.md` — direct string/formatter swap, no multi-locale framework. **No success/positive color exists in the design system** — income and a healthy month are never rendered in green; color is reserved for things that need attention (warning/danger), never for approval. **Privacy is enforced via consent lifecycle, not a UI-only hide toggle** — an account holder can disconnect their own accounts at any time; hiding amounts behind an eye-off icon was considered and explicitly rejected (API returns everything regardless, so UI-only hiding would be theatre, not real privacy).

## Brand Commitments

No existing logo, marketing, or voice guide. Product name "Family Finance" stays. The teal (`Colors.teal`) accent is **no longer a fixed commitment** — a full visual redesign is underway (see `design.md`), driven by a real HTML/CSS mockup (`web-mockups.html`), replacing the teal seed with a flat, mostly-monochrome palette (member-identity accents + warning/danger semantic colors only). `design.md` is the current source of truth for palette/typography/spacing/shape, not this file's prior teal commitment. The mockup's "meu·lar" brand mark is a placeholder from the source design exercise — not adopted; product name is unaffected by the redesign.

## Evidence on Hand

No customer testimonials, case studies, or marketing assets exist — this is an internal/dev-stage product, not yet deployed for real users. Do not fabricate any.

## Product Principles

- Multi-tenant isolation is never compromised for visual convenience — every screen's data is household-scoped, and design changes must not blur that boundary (e.g. a shared/global-looking chrome must not read as cross-household).
- Trustworthy and precise over playful — this is where a family checks real account balances; legibility and correctness read louder than personality.
- Consistency over surprise across screens (Operate-mode default) — the same status/severity/loading/empty-state vocabulary everywhere, not per-screen invention.
- Real financial data, including negative/expense signage, must never be ambiguous — color and text both carry meaning, not color alone.
- **Zero configuration** — no budgets, no manually-set limits. Every number is derived from connected account data; nothing requires setup, nothing goes stale because a target wasn't updated (source: `handoff-app-financas-familiar.md`, folded into `design.md`).
- **One question per screen** — Início answers "are we okay this month?" and nothing on that screen competes with it.
- **People before accounts** — hierarchy is Família → Membro → Conta → Transação, not Household → Account → Transaction with members as an afterthought.
- **Quiet by default, loud on exception** — near-monochrome; color means *person* or *problem*, never decoration.
- **Two taps to anything** — four destinations (Início/Contas/Análises/Família), no nested menus.
- **Consequence worth preserving**: without budgets, the app never tells anyone they did something wrong — it reports, compares people to their own history, and flags anomalies, never a red "over budget" banner. Where one person is looking at another person's money, that's a meaningfully different relationship than a judgmental app, and probably the reason it stays installed.

## Accessibility & Inclusion

- Status/severity signaling must not rely on color alone (colorblind-safe) — confirmed as a requirement carried into the `StatusChip`/`SeverityChip` design (container-color + text, not just a colored dot).
- Segmented controls are capped at 3 segments — a 4th truncates at accessibility text sizes (verified during the design handoff; see `design.md`'s Component Patterns). Any new segmented control must respect this cap, not just the ones already speced.
