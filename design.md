# Design Spec — Mockup + Handoff-Driven Redesign

Working spec for a full UI/visualization redesign, IA restructure, and pt-BR localization. `handoff-app-financas-familiar.md` (repo root) is now the **primary, most authoritative source** — a full written design handoff, richer and more precise than `web-mockups.html`'s markup alone. Where the two disagree, the handoff doc wins (see Changelog). This file supersedes current theme tokens (`frontend/lib/core/theme/*`) where it conflicts with them — treat this file, not the current code, as the source of truth going forward.

**Resolved 2026-08-09 (Phase 1):** the theme-token code (`app_colors.dart`, `app_typography.dart`, `app_theme.dart`, `pubspec.yaml`'s `google_fonts` addition) was originally written against the raw-mockup-only extraction, before the handoff doc arrived, and was wrong in the ways described below. It has since been corrected to match this doc: Instrument Sans + IBM Plex Mono (Geist Mono isn't in the pinned `google_fonts` catalog — see `app_typography.dart`'s doc comment), no success/positive color anywhere, 6 member accents + an `outros` fallback. See `PLAN.md`'s Milestone 12 "Phase 1 implemented" entry for the full list of what landed. Below is still the source of truth for anything Phase 2+ hasn't touched yet (dark-mode application, real Início/Contas content) — pt-BR strings (Phase 2 part 1), global scope controls (Phase 2 part 2), and per-member monthly-spend grouping are now implemented, see Changelog.

## Changelog

| Date | Source | Sections touched | Notes |
|---|---|---|---|
| 2026-08-08 | — | scaffold created | Empty scaffold, no reference yet. |
| 2026-08-09 | `web-mockups.html` (repo root) | Palette, Typography, Spacing/Layout, Shape, Chart Style Guide, Component Patterns, Screen-by-Screen (4-tab IA), Localization, Chart Library Decision | First real design source. Scope decisions: adopt 4-tab nav restructure, adopt pt-BR, ignore "meu·lar" brand mark. |
| 2026-08-09 | Phase 2 implementation | Localization | pt-BR direct-string-replacement pass implemented across the whole app (including auth/invite screens, which the screen-by-screen spec below still defers visually) — see `PLAN.md`'s Milestone 12 "Phase 2, part 1" entry for what landed, including a mobile-width chart-label overlap caught and fixed during browser QA (compact `MMM/yy` month format instead of the spec section's implied full month name). |
| 2026-08-09 | `handoff-app-financas-familiar.md` (repo root) | Nearly everything — see note above | Far more authoritative written handoff, superseding several raw-mockup-only guesses: **typography corrected** (Instrument Sans/Geist Mono, not Inter/JetBrains Mono, with a real explicit type scale), **radius corrected** (5-tier: 2/8/12/16/20, not 8/12/20), **member hues corrected** (6 colors + "Outros" bucket, not 4), **no success/positive color at all** (income renders `ink-muted`, never green — corrects this session's earlier green-income mapping), **dark palette now given** (was an Open Question), **per-member monthly stacking confirmed** (was an Open Question) with real density rules attached, **Investimentos tab now specified** (was "no mockup frame yet"). Added net-new sections with no prior equivalent: Global Scope (period+member controls), Data Model (transfer netting, income classification, fatura/parcela/Pix/13º-salário/VR-VA rules), Alerts (6 named anomaly types), Chart density rulebook, Empty/Loading/Error copy, Decisions Made and Reversed log. Two tensions resolved with the user: (1) `web-mockups.html`'s eye-off privacy-toggle icon vs. the handoff's explicit "cut, replaced by consent-lifecycle" decision → **handoff wins, icon dropped**; (2) connection-expiry is now a fully-specified requirement but Pluggy consent-expiry data was never confirmed to exist → **still deferred**, documented as a real spec target, not built yet. |
| 2026-08-10 | Phase 2, part 2 implementation | Global Scope | Period pill + member filter chips implemented and wired end-to-end (`ScopeController`, `PeriodPill`, `HouseholdShell`'s `HouseholdScope`), including the per-screen visibility table above (period shown on Início/Contas·Extrato/Análises·Gastos·Fluxo, hidden on Contas·Saldos/Análises·Investimentos, both hidden on Família) and backend `member_ids`/`start_date`/`end_date` scoping on the dashboard, transactions, and category-breakdown endpoints. See `PLAN.md`'s Milestone 12 "Phase 2, part 2" entry for what landed and the manual QA pass that confirmed it live. |
| 2026-08-10 | Monthly spend by member implementation | Chart Style Guide (Monthly spend by member, Density rulebook) | Real per-member stacked bar for Análises · Gastos implemented end-to-end — new `/spending-by-member` backend endpoint, and the full density rulebook (unstacked/stacked/ranked-list mode selection, 3%-of-range fold, four-entry legend cap, exact 4px-minimum-segment fold) implemented in the chart's data mapper. See `PLAN.md`'s Milestone 12 "Monthly spend by member" entry for what landed and the manual QA pass. |

## Vision & Principles

*(Handoff §1, §12)*

A household finance app for the Brazilian market. One person — the **responsável** — connects the family's accounts through Open Finance and monitors where the household's money goes. **Primary purpose: control over spending.** Everything else is context.

**Zero configuration.** No budgets, no manually-set limits. Every number is derived from connected account data — nothing requires setup, nothing goes stale because a target wasn't updated.

Four principles, in order:
1. **One question per screen.** Início answers "estamos bem este mês?" ("are we okay this month?"). Nothing competes with it.
2. **People before accounts.** Hierarchy is Família → Membro → Conta → Transação.
3. **Quiet by default, loud on exception.** Near-monochrome. Color means *person* or *problem*, never decoration.
4. **Two taps to anything.** Four destinations, no nested menus.

Two rules governing every screen:
- **The chart shows shape, the list shows values.** Charts degrade as series are added; lists don't. Never ask one element to do both jobs.
- **The tab shows shape, tapping shows the breakdown.** Every aggregate is a drill target.

**Consequence worth preserving** (handoff §12): without budgets, the app never tells anyone they did something wrong. It reports, compares people to their own history, and flags anomalies — no red "over budget" banner. Where one person is looking at another person's money, that's a meaningfully different relationship, and probably why the app stays installed.

## Localization

- App UI language is pt-BR (was English/locale-neutral). Direct string replacement — no ARB/l10n framework (no multi-locale toggle requested).
- Currency: `R$ 8.450,00` — space after `R$`, `.` thousands separator, `,` decimals. Negative: **minus sign, never parentheses** — `−R$ 142,30` (accounting parentheses are misread by most people). Test formatting with `R$ 1.234.567,89` — mono numerals don't remove the need for correct separator handling.
- Dates: `28/08` · `28/08/2026` · `6 de ago`. Relative time in lists: `há 2h`, `ontem`, `terça`.
- **Sentence case everywhere. No ALL CAPS labels.**
- Flutter: `NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$')`, pt-BR `DateFormat`.

## Color Palette

Current (`app_colors.dart`, as of this session — **known wrong**, see top-of-file note): Material 3 teal seed, plus an in-progress `AppPalette`/`AppMemberColors` pass that has the light tokens roughly right but the member-hue count and income-color mapping wrong. **Below supersedes all of it.**

### Light
| Token | Hex | Use |
|---|---|---|
| `surface-page` | `#F7F8F6` | App background |
| `surface-card` | `#FFFFFF` | Cards, sheets, nav bar |
| `surface-fill` | `#EDEFEC` | Segmented control active, track backgrounds, account subheaders |
| `border` | `#E2E5E0` | Hairline dividers (0.5px) |
| `border-strong` | `#CBCFC8` | Chip outlines, chart baseline, disabled dots |
| `ink` | `#191C19` | Primary text, spending line, bar fills |
| `ink-secondary` | `#565B55` | Supporting text, icons |
| `ink-muted` | `#878D86` | Labels, captions, committed segment, **income bars** |

### Dark
| Token | Hex |
|---|---|
| `surface-page` | `#131513` |
| `surface-card` | `#1B1E1B` |
| `surface-fill` | `#242723` |
| `border` | `#2C302C` |
| `border-strong` | `#3D423C` |
| `ink` | `#E9EBE8` |
| `ink-secondary` | `#A2A8A0` |
| `ink-muted` | `#767C75` |

### Semantic — state only
| Token | Light | Dark |
|---|---|---|
| `warning-text` | `#8A5B14` | `#E0B45C` |
| `warning-bg` | `#FCF2DF` | `#302716` |
| `danger-text` | `#A63229` | `#E58A7E` |
| `danger-bg` | `#FBEAE7` | `#34201D` |

**There is no positive/success color.** Income is not green and a healthy month is not green — money is reported in `ink`; color is reserved for things that need attention. This directly corrects this session's earlier `AppSemanticColors`/`AppChartColors.income()` mapping to a green success color — that mapping must be removed. Income bars/values render `ink-muted`, not green.

### Member hues
Identity colors, assigned in join order, stable forever, same hex in both themes. **Six is the ceiling** — members beyond six fold into **Outros** for charting purposes; they still appear individually in lists, just not as a unique chart color.

| # | Hex | Name |
|---|---|---|
| 1 | `#6E63D2` | Roxo |
| 2 | `#0E8A86` | Teal |
| 3 | `#CE5528` | Laranja |
| 4 | `#B2497F` | Magenta |
| 5 | `#2F76B8` | Azul |
| 6 | `#8A7A1C` | Ocre |
| — | `#9AA098` | Outros (bucket, 7th+ member) |

This corrects this session's `AppMemberColors` (currently only 4 accents) — needs a 7th "Outros" fallback color and 2 more accents.

## Typography

**Corrected this round** — this session's `app_typography.dart` used Inter + JetBrains Mono, a reasonable guess from the raw mockup's generic CSS font stack (`ui-monospace`/SF Mono/Menlo/Consolas). The handoff doc gives the real answer:

- **UI / text face: Instrument Sans** — weights 400, 500.
- **Numerals face: Geist Mono** — weights 400, 500 (fallback: IBM Plex Mono).

**Signature choice**: money is set in mono, everything else in the humanist sans. Tabular alignment is a hard requirement in a ledger app — rather than hide it behind a `font-variant-numeric` flag, it's made visible: every monetary value, date, percentage, and account number is set in the monospaced face. Money reads as data; columns align by construction.

Real explicit type scale (not a guess — this replaces the assumption that the old Material scale carries over unchanged):

| Role | Size / line (px) | Face | Weight |
|---|---|---|---|
| Money hero | 30 / 34 | mono | 500 |
| Money medium | 17 / 22 | mono | 500 |
| Money inline | 13 / 18 | mono | 400 |
| Screen title | 15 / 20 | sans | 500 |
| Body | 13 / 18 | sans | 400 |
| Label | 12 / 16 | sans | 400 |
| Caption | 11 / 15 | sans | 400 |
| Nav | 10 / 13 | sans | 400 |

**No sizes between 13 and 17.** The jump from label to money is the whole type hierarchy — don't reintroduce a Material-style dense multi-step scale.

## Spacing / Shape

Current `app_spacing.dart` (base-4, `xs`(4)…`xxl`(32) + semantic aliases) is mostly compatible — handoff's spacing scale is `4, 8, 12, 14, 16, 20, 24, 32` (note the `14` — check whether `AppSpacing` needs a new token for it, or whether it's only used in one specific place not worth a named token). Screen horizontal padding: `16`.

**Radius — corrected, 5 tiers** (this session's `app_shape.dart`/`AppRadius` only has 3: `sm`(8)/`md`(12)/`lg`(20) — needs a 4th/5th tier):
| Radius | Use |
|---|---|
| `2` | Bars (progress tracks) |
| `8` | Buttons and pills |
| `12` | Inner cards |
| `16` | Screen cards and sheets |
| `20` | Chips |

Borders: `0.5px` hairline everywhere. **No shadows, no gradients** — depth comes from spacing and hairlines only.

## Global Scope

*(Handoff §4 — net-new section, no prior equivalent.)*

Exactly two scope controls, everywhere. Adding a third turns the top of every screen into a control panel.

### Period — header
Pill in the center of the header, flanked by ‹ › arrows. **Arrows step by the length of the current range** — on "Este mês" they move month to month; on "Últimos 3 meses" they jump a quarter; on a custom 10-day range they shift 10 days.

Presets: `Este mês` · `Mês passado` · `Últimos 3 meses` · `Este ano` · `Últimos 12 meses` · `Período personalizado`.

Toggle: **`Comparar com período anterior`** — global, not per-chart. When on, every figure carries a delta and every chart gains a ghosted prior series.

- **Resets to `Este mês` on cold launch.** Someone reviewing 2024 last week must not open the app to a stale year presented as current.
- **Hidden on Família.** Connection status isn't period-dependent.

### Members — chip row
Checkbox chips below the header. **Persist across screens *and* sessions** (no staleness risk — unlike the period picker).

Per-screen effect:
| Screen | Period | Members |
|---|---|---|
| Início | ✓ | ✓ |
| Contas · Saldos | — | ✓ |
| Contas · Extrato | ✓ | ✓ |
| Análises · Gastos | ✓ | ✓ |
| Análises · Fluxo | ✓ | ✓ |
| Análises · Investimentos | Value line only — **never** the allocation, which is always today's snapshot | ✓ |
| Família | — | — |

## Chart Style Guide

### Density rulebook (governs every chart, not just one type)
*(Handoff §7 — net-new.)*
- All members selected → neutral household bars, **no stacking**.
- 2-4 members selected → stacked by member.
- 5+ selected → **refuse to stack**. Show totals plus a ranked list instead.
- A series under 3% of total folds into `Outros`.
- A segment that would draw under 4px goes into `Outros` — never render a sliver.
- Range over ~12 buckets auto-coarsens: diário → semanal → mensal → trimestral.
- **Same pixels-per-dollar across an entire chart** — never normalize halves or series independently.
- Stacked bars are only comparable at the bottom segment and the total — middle segments float on a shifting baseline. Stack for *composition*, use the list for *ranking*.
- **Four-entry test**: if a chart needs more than four legend entries, it's the wrong chart.

### Category breakdown (Análises → Gastos tab)
Horizontal bar list, not a pie/donut (`web-mockups.html:196-200` mobile, `:489-496` web) — row = label + track bar + right-aligned mono amount. Not really an `fl_chart` chart — plain `Row`/`Container` list. Top 5 categories + "Outros," each drilling to "quem gastou" (who spent it).

### Monthly spend by member (Análises → Gastos tab, monthly chart)
**Implemented (2026-08-10)** — per-member stacked bar (handoff §6.4: "full-height stacked bars by member"), subject to the density rulebook above (unstacked at all-selected, stacked at 2-4, ranked-list-only at 5+), including the 3%/4px Outros folds and the four-entry legend cap. Backend `GET /v1/households/{id}/spending-by-member` (`backend/app/api/extended_finance.py`) and the mode/fold logic in `frontend/lib/ui/features/analytics/widgets/monthly_spend_chart_data.dart`. See `PLAN.md`'s Milestone 12 "Monthly spend by member" entry for what landed.

### Cash flow (Análises → Fluxo tab)
**Income as bars (`ink-muted`), spending as a line (`ink`) drawn across them** — same axis, same pixels-per-dollar. The headroom between line and bar tops is the net.
- Summary trio above the chart: `Entradas` · `Saídas` · `Resultado`.
- **Crossover is the alarm**: where the spending line rises above the income bar tops, render that line *segment* in `danger` color. No threshold, no configuration.
- Keep vertex dots — a line between monthly aggregates implies interpolation that doesn't exist.
- Partial period needs **both** signals: a dashed final line segment *and* a lighter final bar.
- **No overlaid net line** — the three header figures already state it; on a ~300px chart a net line is clutter.
- Below the chart: income list toggling `Por fonte | Por membro`. Sources: `Salário · Freelance · Dividendos · Aluguel · Outros`.
- Footnote whenever transfers are excluded: `R$ 1.200,00 em transferências entre contas da família foram excluídos.`

### Investimentos (Análises → Investimentos tab)
**Now specified** (previously "no mockup frame given"). Value line plus allocation, grouped by `Classe | Instituição | Membro`. Classes: `Renda fixa · Ações · Fundos · ETF · Cripto · Caixa`.
- **Allocation is never period-filtered** — "Renda fixa 62%" is a fact about today; a date range on it is uninterpretable.
- **Do not use the progress-bar-against-target treatment here.** A red number in Gastos means overspending; a red number in Investimentos means the market moved — different meaning, different visual language. Use a percentage delta instead.

### Balance history / Loan payoff / Credit-card bill timeline / Anomaly severity-trend
No dedicated mockup/handoff coverage — Contas·Saldos shows balances as a plain list (checking accounts) or fatura preview (cards), not a chart. Leave as-is until referenced.

## Component Patterns

- **Money value**: mono, right-aligned in lists. Negative uses a minus sign, never parentheses.
- **Member chip**: `[checkbox in member hue] Nome`. Unchecked: `border` outline, `ink-muted` text. Checked: `border-strong` outline, `ink` text.
- **Progress track**: height 6 (4 in compact rows), radius 3, `surface-fill` background. Segments fill left-to-right, no gaps.
- **Segmented control**: **max 3 segments** — 4 truncates at accessibility text sizes (verified, don't do it). Active: `surface-fill` background + `ink` text + weight 500. Inactive: transparent + `ink-muted`.
- **List row**: `[hue dot] Label — track — value — chevron`. Chevron present whenever the row drills to a detail sheet/panel.
- **Button**: full width in sheets. Radius 8, height 40, `ink` fill with `surface-card` label. Secondary: `border-strong` outline, `ink` label.
- **Alert row** (`AppAlertRow`, heavier than a chip): icon + title + subtext, full tinted background (`warning-bg`/`danger-bg`) — used for the anomalies teaser on Início.
- **Connection health row**: dot (member hue, or recolored to warning/danger state) + label + trailing status text — see Família below.
- **Transactions table** (web "Extrato"): search + filter pills + summary row + six-column table (Data · Descrição · Membro · Conta · Categoria · Valor). Flagged rows tinted, parcela badge inline in the description (`Samsung 13/21`), internal transfers visible-but-muted (`ink-muted` row, tagged `Interna`).
- **Required states for every component**: `default · pressed · disabled · loading (skeleton, never a spinner over content) · empty · error`.

## Data Model

*(Handoff §8 — net-new; cross-references the backend gaps identified in the phased implementation plan's Phase 2-4.)*

- **Internal transfers**: match on amount, direction, and a short time window across linked accounts; **net out both legs**. Without this, moving money between the household's own accounts inflates both income and spending. Pix between family members hits this at high frequency. This is the single most important correctness rule in the app.
- **Credit classification** — raw credits are not automatically income:
  | Bucket | Income? |
  |---|---|
  | Salário, aposentadoria, benefício | Yes |
  | Transferência entre contas da família | No — net out |
  | Pagamento de fatura | No — same money moving |
  | Estorno / reembolso | No — reduce the original expense |
  | Resgate de investimento, dividendos | Separate bucket |
  | Transferência de fora da família | Yes, flag for review |
- **Fatura**: not a balance. Store `fechamento` and `vencimento` per card, assign each purchase to the fatura it lands in — Brazilians reason in monthly faturas, not running card balances. (`CreditCardBill.due_date`/`total_amount`/`minimum_payment` already exist on the backend — `fechamento` may not yet.)
- **Parcelas**: first-class. Store `parcela_atual/parcela_total` per transaction and forecast the remaining tail: `Comprometido até março de 2027: R$ 14.820,00 em 6 parcelamentos`. No bank app surfaces this.
- **Pix**: large volume, often P2P with only a name as descriptor — expect a large unclassified bucket. Let people tag a recurring counterparty once and have it stick.
- **13º salário**: December income roughly doubles — deviation/compare-to-previous logic must know this or the app cries wolf every December.
- **VR/VA**: meal-voucher balances often sit outside Open Finance. If grocery spending looks artificially low, say so rather than let the household believe they spend less than they do.
- **Disclosure rule**: every suppression is stated in the UI — excluded transfers, hidden slivers, stale accounts, missing VR. Silent omission is how users conclude the numbers are wrong.

## Alerts — *cobranças incomuns*

*(Handoff §9 — net-new.)*

Three non-negotiable rules:
1. **Never state a conclusion the model can't support** — "Possível cobrança duplicada," not "Cobrança duplicada detectada."
2. **Always show the evidence inline** — the user verifies without leaving the card.
3. **Dismissal is one tap and permanent for that pattern** — an unsilenceable flag becomes noise within a week.

| Type | PT-BR headline | Backend rule status |
|---|---|---|
| Duplicate | `Possível cobrança duplicada` | Exists — `detect_duplicate_transactions` |
| Subscription price change | `Assinatura mudou de valor` | Likely maps to existing `detect_recurring_payment_changes` |
| First-time merchant over threshold | `Primeira compra neste estabelecimento` | Likely maps to existing `detect_new_merchants` |
| Unmatched tax or fee | `Taxa sem cobrança correspondente` | **Missing** — no equivalent rule |
| Deviation from own average | `Gasto acima da média` | Exists at category level (`detect_category_deviations`); a *member*-level version (Início's "40% acima da média dela") is separate, backend-gated work (see phased plan Phase 3) |
| **Rotativo** (payment below fatura) | `Pagamento abaixo do valor da fatura` | **Missing** — planned as a new rule (phased plan Phase 4) |

**Rotativo is the highest-value alert in the Brazilian market** — paying less than the full fatura rolls the remainder into revolving credit at rates that dwarf everything else in the household's finances. Give it the loudest treatment available; worth more than every category chart combined.

Card anatomy: icon · headline · one-line explanation · member badge · evidence block (the transactions side by side) · context line (e.g. "Esta assinatura costuma ser cobrada uma vez por mês, no dia 1º") · two actions (`Não é duplicada` / `Ver cobrança`).

## Empty, Loading, and Error Copy

*(Handoff §11 — net-new.)* Errors explain what happened and how to fix it. Empty screens invite action. Neither apologizes.

| State | PT-BR |
|---|---|
| No accounts | `Conecte a primeira conta para começar` |
| No transactions in period | `Nenhuma movimentação em agosto` |
| No alerts | `Nada fora do comum este mês` |
| Connection failed | `Não conseguimos atualizar esta conta. Reconecte para ver os dados de agosto.` |
| Loading | Skeleton rows at final dimensions — never a spinner over existing content |
| Partial data | `Mostrando 3 de 4 contas` |

## Screen-by-Screen Notes

Navigation: **Início · Contas · Análises · Família**, replacing today's Dashboard/Finances(5-tab)/Anomalies/Connections/Households routes.

| Tab | Segments | Default |
|---|---|---|
| Início | — | — |
| Contas | `Saldos \| Extrato` | Extrato |
| Análises | `Gastos \| Fluxo \| Investimentos` | Gastos |
| Família | — | — |

Settings live behind the avatar in the Início header. Alerts are a card on Início and a filter in Extrato — not a tab (some weeks there are none; an empty tab is dead weight).

### 6.1 Início — supersedes `dashboard_view.dart`
Answers one question: are we okay this month?

| Element | PT-BR |
|---|---|
| Hero label | `Gastos do mês` |
| Hero value | `R$ 8.450,00` (mono 30) |
| Bar legend | `Realizado` / `Comprometido R$ 3.120,00` |
| Reference line | `Entradas` `R$ 14.200,00` |
| Result | `Sobrou` `R$ 2.630,00` |
| Credit block | `Limite disponível` · `R$ 14.890,00 de R$ 42.000,00 · 3 cartões` |
| Fatura warning | `Fatura do C6 vence em 3 dias · R$ 5.760,00` |
| Alerts row | `2 cobranças incomuns para revisar` |
| Member section | `Por membro` |
| Member sub-line, normal | `Dentro da média` |
| Member sub-line, deviation | `40% acima da média dela` |
| Sync footer | `3 de 4 contas atualizadas há 2h` |

**Income is the reference line, not a budget.** The bar measures spent+committed against money in — no target, nothing to configure. **Credit framing**: lead with what's owed; `Limite disponível` in large type reads as money the family can borrow (available credit is the supporting figure here, the leading figure in Contas·Saldos).

### 6.2 Contas · Saldos — supersedes part of `dashboard_view.dart`'s account list
Grouped by member. Checking accounts show balance; cards show the **fatura**, not a running balance:
```
Itaú Visa Infinite                      R$ 15.759,85
Fatura R$ 6.240,15 · fecha 28/08 · vence 05/09
```
Utilization thresholds — the app's only built-in alarm, fully derived:
| Utilização | Treatment |
|---|---|
| < 30% | `ink` |
| 30-70% | `warning` |
| > 70% | `danger` |

Broken connection: `Sem sincronizar`, row in `ink-muted`.

### 6.3 Contas · Extrato — supersedes today's transaction list
Filter pills: `Todos` · `Sinalizados` · `Parcelados` · `Entradas` · `Saídas`. Sticky account subheader (member dot, institution, masked number). Row shape:
```
Mercado Pão de Açúcar                        −R$ 342,80
6 de ago · Mercado
```
- Parcela counter inline in the description: `Samsung 13/21`.
- Flag icon inline on rows with an open alert.
- Row tap opens a detail sheet (mobile) / right-side panel (web): full merchant name, raw bank descriptor, recategorize, split, flag.
- Export (CSV/PDF) lives in this header, not in settings.

### 6.4 Análises · Gastos (default view) — supersedes `finances_view.dart`'s Categories tab
Full-height stacked bars by member (density rulebook above), then top-5 categories + Outros, each drilling to "quem gastou." Category names: `Mercado · Transporte · Restaurantes · Contas de casa · Compras · Saúde · Educação · Lazer · Outros`.

Category detail sheet:
| Element | PT-BR |
|---|---|
| Header | `Restaurantes` · `R$ 1.520,00` · `+18% vs julho` |
| Sub | `Agosto 2026 · 14 cobranças` |
| Breakdown | `Quem gastou` |
| List | `Cobranças` |
| Action | `Avisar sobre gastos em Restaurantes` (toggle) |

### 6.5 Análises · Fluxo — supersedes `finances_view.dart`'s Balance History tab (partially)
See Chart Style Guide's Cash Flow entry above for the chart itself. Screen also has: income list toggling `Por fonte | Por membro`, the transfer-exclusion footnote.

### 6.6 Análises · Investimentos — supersedes `finances_view.dart`'s Investments tab
See Chart Style Guide's Investimentos entry above.

### 6.7 Família — supersedes `households/`, `members_view.dart`, `member_access_view.dart`, `connections_view.dart` (merged)
Members, what each one sees, and per-connection **two** health facts: sync freshness *and* access expiry.

| State | Strings |
|---|---|
| Healthy | `Atualizado há 2h` · `Acesso renova em 12/03/2027` |
| Expiring | `Acesso expira em 18 dias · Ana precisa renovar` → `Pedir para Ana renovar` |
| Failed | `Falhou há 9 dias` · `Dados exibidos são de 30/07` → `Reconectar conta` |

Roles: `Responsável` · `Vê toda a família` · `Vê só os próprios dados` · `Convidado`. **`Pedir para Ana renovar`, never `Renovar`** — the responsável can't renew someone else's consent, only the account holder can. Warn at 30 days, escalate at 7.

Footer: `Cada membro pode desconectar suas contas quando quiser.`

**Deferred, not built**: the expiry/renewal mechanics above need Pluggy consent-expiry data that was never confirmed to exist on this app's backend — documented here as the real spec target, but still explicitly out of scope until a future pass researches Pluggy's actual API fields (see the phased implementation plan's "Parked" section).

### Anomalies detail, Assistant — unchanged entry points
Anomalies teaser card on Início pushes the existing `anomalies_view.dart` (kept as-is). Assistant reached via a header icon pushing the existing `assistant_view.dart` (kept as-is). Neither is one of the 4 tabs.

### Untouched by this batch
Auth screens (login/register/invite) — not in scope. Onboarding/account-linking, member-detail screen, transaction-detail sheet's exact layout, LGPD consent screen, dark-mode *application* (values now exist, not yet applied), notifications, and "approvals" are all explicitly **not yet designed**, per the handoff doc's own §13 — don't invent specs for these, wait for a future batch.

## 6a. Web

Mobile and web are the same concept under a different constraint: mobile's rule is *one thing visible*, web's is *one thing dominant* — hierarchy through size/position, not hiding. Tokens, hues, type scale, mono-for-money, no budgets, no success color, every suppression disclosed: all identical between platforms.

### Grid
Max container `1280px`, page padding `24px`, 12 columns, `24px` gutters. Below `1024px`, collapse to the mobile single-column stack.

### Navigation shifts to a top bar
Top bar replaces the bottom bar: brand mark · `Início · Contas · Análises · Família` inline · period pill · theme toggle · avatar. (No eye-off icon — dropped per this session's decision, see Changelog.) The two scope controls stay exactly two — period in the header bar, member chips in their own strip directly beneath it. Web doesn't add a third control just because there's room.

### What relaxes
| Rule | Mobile | Web |
|---|---|---|
| Time buckets | ~12 max | 12-24 comfortably, wider chart |
| Categories shown | Top 5 + Outros | All of them, taller list |
| Chart + breakdown | Stacked vertically, scroll required | Side by side, ~2:1 |
| Transaction rows | Two-line card | Six-column table: Data · Descrição · Membro · Conta · Categoria · Valor |
| Drill-down | Bottom sheet | Right-side panel — list stays visible behind it |

### What does not relax
4px minimum segment, 3% Outros threshold, same pixels-per-dollar, four-legend-entry test — perceptual limits, not spatial ones.

### Table conventions (Contas · Extrato)
- Date gets its own column; mobile's date-group headers (`16 Domingo`) don't carry over.
- Member column is always **dot + name**, never the dot alone.
- Category is a neutral pill (`surface-fill` bg, `ink-secondary` text) — never colored (color is reserved for member identity).
- Internal transfers stay **visible but visibly muted** (`ink-muted` row, tagged `Interna`) rather than hidden, unlike mobile — width affords showing the app's own filtering work.
- Sticky table header on scroll; row hover uses `surface-fill`; row click opens the right-side panel, never a modal.

### Screen inventory — delivered vs. still needed
**Delivered** (per the handoff doc, rebuilt in `web-mockups.html`): Início (dashboard, side-by-side cards), Contas·Extrato (table), Análises·Gastos (chart+category list side by side).
**Still needed**: Análises·Fluxo and ·Investimentos on the web grid, Família, the right-side panel pattern itself, the LGPD consent screen.

## Chart Library Decision — **Resolved: stay on `fl_chart`**

Every chart style specified (horizontal bar list, combo bar+line with crossover coloring, member-stacked bar with density-rule fallback to a list, investment value line) is achievable with `fl_chart`'s `BarChart`/`LineChart` primitives composed via `Stack`, plus plain-widget list fallbacks for the non-chart cases (category bar list, 5+-member ranked list). No need for `syncfusion_flutter_charts`/`graphic`.

## Open Questions

- **Connection expiry backend feasibility** (deferred, not blocking): the handoff fully specs the Família expiry/renewal UI, but Pluggy consent-expiry data was never confirmed to exist in what this app's backend stores. Documented as a real spec target; still explicitly out of scope until researched.
- **Notifications** (handoff §13, undesigned): priority order given as rotativo, fatura vencendo, connection failed, first-time merchant over threshold, deviation from average — but no screen/mechanism designed yet.
- **Approvals** (handoff §13, undesigned): the only mechanism that could act *before* money moves — the handoff doc itself questions whether it's worth building without a real blocking mechanism or social convention behind it.
- **LGPD consent screen** (handoff §13, undesigned): one adult seeing another adult's financial data needs a lawful basis; the connection-time consent moment needs real design attention, not a checkbox.
- **Dark mode application**: values now exist (see Color Palette above) but haven't been applied to theme code yet — that's next-implementation-pass work, not a design question.
- **Transaction detail sheet, member detail, onboarding/account-linking**: all explicitly not yet designed per the handoff's own open list.
- **General categorical palette for non-member charts**: member hues (6+Outros) cover member-identity charts; category-based charts (Gastos by category) still have no explicit color spec beyond "bars use member hues when stacked by member" — category-bar-list rows don't obviously need per-category color at all (it's a ranked list, not a chart), so this may be moot; revisit if a future mockup batch shows category-colored bars.
