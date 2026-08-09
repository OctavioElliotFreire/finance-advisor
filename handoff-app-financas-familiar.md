# Design handoff — App de finanças familiares (PT-BR)

Version 1 · August 2026
Prose is in English; every user-facing string is PT-BR and marked as such.

---

## 1. Product

A household finance app for the Brazilian market. One person — the **responsável** — connects the family's accounts through an Open Finance aggregator and monitors where the household's money goes.

**Primary purpose: control over spending.** Everything else is context.

**Zero configuration.** There are no budgets and no manually-set limits. Every number in the app is derived from connected account data. Nothing requires setup, and nothing goes stale because someone forgot to update a target.

### Four principles

1. **One question per screen.** Início answers "estamos bem este mês?" Nothing competes with it.
2. **People before accounts.** Hierarchy is Família → Membro → Conta → Transação.
3. **Quiet by default, loud on exception.** Near-monochrome. Colour means *person* or *problem*, never decoration.
4. **Two taps to anything.** Four destinations, no nested menus.

### Two rules that govern every screen

- **The chart shows shape, the list shows values.** Charts degrade as series are added; lists don't. Never ask one element to do both jobs.
- **The tab shows shape, tapping shows the breakdown.** Every aggregate in the app is a drill target.

---

## 2. Design tokens

### Colour — light

| Token | Hex | Use |
|---|---|---|
| `surface-page` | `#F7F8F6` | App background |
| `surface-card` | `#FFFFFF` | Cards, sheets, nav bar |
| `surface-fill` | `#EDEFEC` | Segmented control active, track backgrounds, account subheaders |
| `border` | `#E2E5E0` | Hairline dividers (0.5px) |
| `border-strong` | `#CBCFC8` | Chip outlines, chart baseline, disabled dots |
| `ink` | `#191C19` | Primary text, spending line, bar fills |
| `ink-secondary` | `#565B55` | Supporting text, icons |
| `ink-muted` | `#878D86` | Labels, captions, committed segment, income bars |

### Colour — dark

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

**There is no positive/success colour.** Income is not green and a healthy month is not green. Money is reported in ink; colour is reserved for things that need attention. This is deliberate — a green number implies approval the app has no business giving.

### Member hues

Identity colours, assigned in join order and stable forever. Same hex in both themes.

| # | Hex | Name |
|---|---|---|
| 1 | `#6E63D2` | Roxo |
| 2 | `#0E8A86` | Teal |
| 3 | `#CE5528` | Laranja |
| 4 | `#B2497F` | Magenta |
| 5 | `#2F76B8` | Azul |
| 6 | `#8A7A1C` | Ocre |
| — | `#9AA098` | Outros (bucket) |

Six is the ceiling. Members beyond six fold into **Outros**; they still appear individually in lists, just not in charts.

### Typography

**Signature choice: money is set in mono, everything else in a humanist sans.**

Tabular alignment is a hard requirement in a ledger app. Rather than hide it behind a `font-variant-numeric` flag, make it visible — every monetary value, date, percentage and account number is set in a monospaced face. Money reads as data, columns align by construction, and the app looks unlike the rounded-friendly fintech house style.

- **UI / text:** Instrument Sans — 400, 500
- **Numerals:** Geist Mono — 400, 500 (fallback: IBM Plex Mono)

| Role | Size / line | Face | Weight |
|---|---|---|---|
| Money hero | 30 / 34 | mono | 500 |
| Money medium | 17 / 22 | mono | 500 |
| Money inline | 13 / 18 | mono | 400 |
| Screen title | 15 / 20 | sans | 500 |
| Body | 13 / 18 | sans | 400 |
| Label | 12 / 16 | sans | 400 |
| Caption | 11 / 15 | sans | 400 |
| Nav | 10 / 13 | sans | 400 |

No sizes between 13 and 17. The jump from label to money is the whole type hierarchy.

### Spacing, radius, elevation

- Base unit 4. Scale: `4, 8, 12, 14, 16, 20, 24, 32`
- Screen horizontal padding: `16`
- Radius: `2` bars · `8` buttons and pills · `12` inner cards · `16` screen cards and sheets · `20` chips
- Borders: `0.5px` hairline
- **No shadows, no gradients.** Depth comes from spacing and hairlines only.

---

## 3. Navigation

**Início · Contas · Análises · Família**

| Tab | Segments | Default |
|---|---|---|
| Início | — | — |
| Contas | `Saldos \| Extrato` | Extrato |
| Análises | `Gastos \| Fluxo \| Investimentos` | Gastos |
| Família | — | — |

Settings live behind the avatar in the Início header. Alerts (*cobranças incomuns*) are a card on Início and a filter in Extrato — not a tab, because some weeks there are none and an empty tab is dead weight.

---

## 4. Global scope

Exactly two scope controls. Adding a third turns the top of every screen into a control panel.

### Period — header

Pill in the centre of the header, flanked by ‹ › arrows.

**Arrows step by the length of the current range.** On *Este mês* they move month to month; on *Últimos 3 meses* they jump a quarter; on a custom 10-day range they shift 10 days.

Presets (PT-BR): `Este mês` · `Mês passado` · `Últimos 3 meses` · `Este ano` · `Últimos 12 meses` · `Período personalizado`

Toggle: **`Comparar com período anterior`** — global, not per chart. When on, every figure carries a delta and every chart gains a ghosted prior series.

Behaviour:
- **Resets to `Este mês` on cold launch.** Someone reviewing 2024 last week must not open the app to a stale year presented as current.
- **Hidden on Família.** Connection status isn't period-dependent, and a control that does nothing teaches people to ignore it.

### Members — chip row

Checkbox chips below the header. Persist across screens *and* sessions (no staleness risk).

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

---

## 5. Components

### Money value
Mono, right-aligned in lists. Negative uses a minus sign, never parentheses: `−R$ 142,30`. Accounting parentheses are misread by most people.

### Member chip
`[checkbox in member hue] Nome`. Unchecked: `border`, `ink-muted`. Checked: `border-strong`, `ink`.

### Progress track
Height 6 (4 in compact rows), radius 3, `surface-fill` background. Segments fill left to right, no gaps.

### Segmented control
Max 3 segments. Active: `surface-fill` + `ink` + weight 500. Inactive: transparent + `ink-muted`.
Four segments truncate at accessibility text sizes — verified, don't do it.

### List row
`[hue dot] Label — track — value — chevron`. Chevron present whenever the row drills.

### Button
Full width in sheets. Radius 8, height 40, `ink` fill with `surface-card` label. Secondary: `border-strong` outline, `ink` label.

### States required for every component
`default · pressed · disabled · loading (skeleton, never a spinner over content) · empty · error`

---

## 6. Screens

### 6.1 Início

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

**Income is the reference line, not a budget.** The bar measures spent + committed against money in. There is no target and nothing to configure.

**Credit framing:** on Início, lead with what is owed. `Limite disponível` in large type reads as money the family has; it is money they can borrow. Available credit is the supporting figure here and the leading figure in Contas · Saldos, where it answers "can I buy this."

### 6.2 Contas · Saldos

Grouped by member. Checking accounts show balance. Cards show the **fatura**, not a running balance.

```
Itaú Visa Infinite                      R$ 15.759,85
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Fatura R$ 6.240,15 · fecha 28/08 · vence 05/09
```

Utilization thresholds — the app's only built-in alarm, fully derived:

| Utilização | Treatment |
|---|---|
| < 30% | `ink` |
| 30–70% | `warning` |
| > 70% | `danger` |

Broken connection: `Sem sincronizar`, row in `ink-muted`.

### 6.3 Contas · Extrato

Filter pills: `Todos` · `Sinalizados` · `Parcelados` · `Entradas` · `Saídas`

Sticky account subheader with member dot, institution, and masked number. Row shape:

```
Mercado Pão de Açúcar                        −R$ 342,80
6 de ago · Mercado
```

- **Parcela counter inline in the description:** `Samsung 13/21`
- **Flag icon inline** on rows with an open alert
- Row tap opens a detail sheet: full merchant name, raw bank descriptor, recategorize, split, flag
- Export (CSV / PDF) lives in this header, not in settings

### 6.4 Análises · Gastos — default view

Full-height stacked bars by member, then top 5 categories, each drilling to *who spent it*.

Category names: `Mercado · Transporte · Restaurantes · Contas de casa · Compras · Saúde · Educação · Lazer · Outros`

Category detail sheet:

| Element | PT-BR |
|---|---|
| Header | `Restaurantes` · `R$ 1.520,00` · `+18% vs julho` |
| Sub | `Agosto 2026 · 14 cobranças` |
| Breakdown | `Quem gastou` |
| List | `Cobranças` |
| Action | `Avisar sobre gastos em Restaurantes` (toggle) |

### 6.5 Análises · Fluxo

**Income as bars (`ink-muted`), spending as a line (`ink`) drawn across them.** Same axis, same pixels-per-dollar. The headroom between line and bar tops is the net.

- Summary trio: `Entradas` · `Saídas` · `Resultado`
- **Crossover is the alarm.** Where the line rises above the bar tops, the household spent more than it earned — render that line segment in `danger`. No threshold, no configuration.
- Keep the vertex dots: a line between monthly aggregates implies interpolation that doesn't exist.
- Partial period needs **both** signals: dashed final line segment *and* a lighter final bar.
- No overlaid net line. The three figures in the header already state it; on a 300px chart the line is clutter.

Below: income list toggling `Por fonte | Por membro`. Sources: `Salário · Freelance · Dividendos · Aluguel · Outros`.

Footnote whenever something is suppressed: `R$ 1.200,00 em transferências entre contas da família foram excluídos.`

### 6.6 Análises · Investimentos

Value line plus allocation, grouped by `Classe | Instituição | Membro`.
Classes: `Renda fixa · Ações · Fundos · ETF · Cripto · Caixa`

**Allocation is never period-filtered.** "Renda fixa 62%" is a fact about today. Applying a date range to it produces a number nobody can interpret.

Do not use the progress-bar-against-target treatment here. A red number in Gastos means someone overspent; a red number in Investimentos means the market moved. Different meaning, different visual language — use a percentage delta.

### 6.7 Família

Members, what each one sees, and per connection **two** health facts: sync freshness *and* access expiry.

| State | Strings |
|---|---|
| Healthy | `Atualizado há 2h` · `Acesso renova em 12/03/2027` |
| Expiring | `Acesso expira em 18 dias · Ana precisa renovar` → `Pedir para Ana renovar` |
| Failed | `Falhou há 9 dias` · `Dados exibidos são de 30/07` → `Reconectar conta` |

Roles: `Responsável` · `Vê toda a família` · `Vê só os próprios dados` · `Convidado`

**`Pedir para Ana renovar`, never `Renovar`.** The responsável cannot renew someone else's consent — only the account holder can. A button implying otherwise leads to a dead end.

Warn at 30 days, escalate at 7. Earlier than that and people learn to ignore it.

Footer: `Cada membro pode desconectar suas contas quando quiser.`

---

## 6a. Web

Mobile and web are the same concept under a different constraint. Mobile's rule is *one thing visible*; web's rule is *one thing dominant* — hierarchy through size and position rather than through hiding. Tokens, hues, type scale, mono-for-money, no budgets, no success colour, every suppression disclosed: all identical. Nothing below overrides section 1–12; it only adds layout.

### Grid

- Max container `1280px`, page padding `24px`
- 12 columns, `24px` gutters
- Below `1024px`, collapse to the mobile single-column stack from section 6

### Navigation shifts to a top bar

Top bar replaces the bottom bar: brand mark · `Início · Contas · Análises · Família` inline · period pill · eye-off · theme toggle · avatar. The two scope controls stay exactly two — period lives in the header bar, the member chip row sits directly beneath it as its own strip. Web does not add a third scope control just because there's room; the discipline is the point.

### What relaxes

| Rule | Mobile | Web |
|---|---|---|
| Time buckets | ~12 max | 12–24 comfortably, chart is wider |
| Categories shown | Top 5 + `Outros` | All of them, in a taller list |
| Chart + breakdown | Stacked vertically, scroll required | Side by side, roughly 2:1 |
| Transaction rows | Two-line card | Six-column table: Data · Descrição · Membro · Conta · Categoria · Valor |
| Drill-down | Bottom sheet | Right-side panel — the list stays visible behind it |

### What does not relax

The 4px minimum segment, the 3% `Outros` threshold, same pixels-per-dollar across a chart, and the four-legend-entry test. These are perceptual limits, not spatial ones — a 2px sliver is unreadable at any screen size, and a chart needing a fifth legend entry is still the wrong chart at 1280px.

### Table conventions (Contas · Extrato)

- Date gets its own column; the mobile date-group headers (`16 Domingo`) are a small-screen workaround and don't carry over
- Member column is always **dot + name**, never the dot alone — a dot with no name forces the reader to hold a legend in memory
- Category is a neutral pill (`surface-fill` background, `ink-secondary` text) — never coloured. Colour is reserved for member identity; a coloured category would collide with that system
- Internal transfers (Pix between family accounts, fatura payments) stay **visible but visibly muted** — `ink-muted` row, tagged `Interna` — rather than hidden as on mobile. Width affords showing the app's own filtering work
- Sticky table header on scroll; row hover uses `surface-fill`; row click opens the right-side panel, never a modal

### Screen inventory delivered

Início (dashboard with side-by-side cards) · Contas · Extrato (table) · Análises · Gastos (chart + category list side by side). Rebuilt in full, with markup, in the companion file `web-mockups.html`.

### Screen inventory still needed

Análises · Fluxo and · Investimentos on the web grid, Família, the right-side panel pattern itself, and the LGPD consent screen — all still open per section 13.

---

## 7. Chart rules

Density is the main failure mode. These are hard rules.

| Situation | Behaviour |
|---|---|
| All members selected | Neutral household bars — **no stacking** |
| 2–4 selected | Stacked by member |
| 5+ selected | Refuse to stack. Totals plus ranked list. |
| Series under 3% of total | Folds into `Outros` |
| Segment would draw under 4px | Goes into `Outros` — never render a sliver |
| Range over ~12 buckets | Auto-coarsen: diário → semanal → mensal → trimestral |

Plus:

- **Same pixels-per-dollar across an entire chart.** Never normalize halves or series independently.
- **Stacked bars can only be compared at the bottom segment and the total.** Middle segments float on a shifting baseline. Stack for *composition* questions only; *ranking* is what the list is for.
- **The four-entry test:** if a chart needs more than four legend entries, it is the wrong chart.

Complexity scales with the specificity of the question, not with the size of the family. Adding a seventh member never degrades the interface — detail moves from the chart into the list, which has room for it.

---

## 8. Data model

### Internal transfers
Match on amount, direction, and a short time window across linked accounts. **Net out both legs.** Without this, a household that moves money between its own accounts shows wildly inflated income and spending. This is the single most important correctness rule in the app, and it does not exist in single-user aggregators.

Pix between family members is this problem at high frequency.

### Credit classification
Raw credits are not income.

| Bucket | Income? |
|---|---|
| Salário, aposentadoria, benefício | Yes |
| Transferência entre contas da família | No — net out |
| Pagamento de fatura | No — same money moving |
| Estorno / reembolso | No — reduce the original expense |
| Resgate de investimento, dividendos | Separate bucket |
| Transferência de fora da família | Yes, flag for review |

### Fatura
A fatura is not a balance. Store `fechamento` and `vencimento` per card and assign each purchase to the fatura it lands in. Brazilians reason in monthly faturas, not running card balances.

### Parcelas
First-class. Store `parcela_atual / parcela_total` and forecast the remaining tail:

`Comprometido até março de 2027: R$ 14.820,00 em 6 parcelamentos`

No bank app surfaces this, and a household carrying six or seven open parcelamentos has no other way to see it.

### Pix
Enormous volume, frequently P2P, often with only a name as descriptor. Expect a large unclassified bucket. Let people tag a recurring counterparty once and have it stick.

### 13º salário
December income roughly doubles. The deviation signals and compare-to-previous logic must know about it, or the app spends every December crying wolf.

### VR / VA
Meal-voucher balances often sit outside Open Finance. If a chunk of grocery spending is invisible, say so rather than let the household believe they spend less on Mercado than they do.

### Disclosure rule
**Every suppression is stated in the UI.** Excluded transfers, hidden slivers, stale accounts, missing VR. Silent omission is how users conclude the numbers are wrong.

---

## 9. Alerts — *cobranças incomuns*

Three rules, non-negotiable:

1. **Never state a conclusion the model can't support.** `Possível cobrança duplicada`, not `Cobrança duplicada detectada`.
2. **Always show the evidence inline** — the user verifies without leaving the card.
3. **Dismissal is one tap and permanent for that pattern.** An unsilenceable flag becomes noise within a week.

| Type | PT-BR headline |
|---|---|
| Duplicate | `Possível cobrança duplicada` |
| Subscription price change | `Assinatura mudou de valor` |
| First-time merchant over threshold | `Primeira compra neste estabelecimento` |
| Unmatched tax or fee | `Taxa sem cobrança correspondente` |
| Deviation from own average | `Gasto acima da média` |
| **Rotativo** | `Pagamento abaixo do valor da fatura` |

**Rotativo is the highest-value alert in the Brazilian market.** When someone pays less than the full fatura, the remainder rolls into revolving credit at rates that dwarf everything else in the household's finances. For an app about controlling spending, this single alert is worth more than every category chart combined. Give it the loudest treatment available.

Card anatomy: icon · headline · one-line explanation · member badge · **evidence block** (the two transactions, side by side) · **context line** (`Esta assinatura costuma ser cobrada uma vez por mês, no dia 1º`) · two actions (`Não é duplicada` / `Ver cobrança`).

---

## 10. Localization

- Currency: `R$ 8.450,00` — space after `R$`, `.` thousands, `,` decimals
- Negative: `−R$ 142,30`
- Dates: `28/08` · `28/08/2026` · `6 de ago`
- Relative time in lists: `há 2h`, `ontem`, `terça`
- Sentence case everywhere. No ALL CAPS labels.
- Mono numerals do not remove the need for correct separator handling — test with `R$ 1.234.567,89`

---

## 11. Empty, loading and error copy

Errors explain what happened and how to fix it. Empty screens invite action. Neither apologizes.

| State | PT-BR |
|---|---|
| No accounts | `Conecte a primeira conta para começar` |
| No transactions in period | `Nenhuma movimentação em agosto` |
| No alerts | `Nada fora do comum este mês` |
| Connection failed | `Não conseguimos atualizar esta conta. Reconecte para ver os dados de agosto.` |
| Loading | Skeleton rows at final dimensions — never a spinner over existing content |
| Partial data | `Mostrando 3 de 4 contas` |

---

## 12. Decisions made and reversed

Recorded so they don't get re-litigated.

| Cut | Reason | Replaced by |
|---|---|---|
| Budgets | Required setup most users never do; the app then shows an empty shell | Income as the reference line |
| Per-member limits | Same problem, smaller scale | `40% acima da média dela` — derived from history |
| Income privacy toggle | API returns everything; UI-only hiding is theatre and a liability | Consent lifecycle — the account holder can disconnect, which is real and enforceable |
| Separate Income tab | Overlapped with Fluxo; content was one flat bar | Drill-down from the Fluxo income bars |
| Mirrored stacked cash flow chart | Halved vertical space, produced slivers at three members | Bars plus spending line |
| Four segments in Análises | Truncates at accessibility text sizes | Three, with income as a drill |
| Limites tab | Belongs per-person | Member detail inside Família |

**Consequence worth preserving:** without budgets, the app never tells anyone they did something wrong. It reports, compares people to their own history, and flags anomalies. Where one person is looking at another person's money, that is a meaningfully different relationship than a red "over budget" banner — and probably the reason the app stays installed.

---

## 13. Open

1. **Platform.** Mobile-first or responsive web-first. Every mockup so far is mobile; the Pluggy reference is desktop. This changes segment counts and layout density.
2. **Notifications.** Control that requires opening the app is weak control. Priority order: rotativo, fatura vencendo, connection failed, first-time merchant over threshold, deviation from average.
3. **Approvals.** The only mechanism in the design that acts *before* money moves. Worth building only if a card can actually be blocked or there's a real social convention behind the request — otherwise the honest version is a fast notification plus a conversation, and the copy should say so.
4. **Not yet designed:** transaction detail sheet, member detail, onboarding and account linking, the LGPD consent screen, dark mode pass.
5. **LGPD.** One adult seeing another adult's financial data needs a lawful basis. The consent moment at account connection is where it's established — that screen deserves real design attention, not a checkbox.
