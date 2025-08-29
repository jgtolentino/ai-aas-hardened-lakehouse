# PRD — Scout Analytics Dashboard v6.0 (Frontend/UI)

## 0) Meta

* **Doc ID:** PRD-SCOUT-UI-v6.0
* **Owner:** Jake / InsightPulseAI
* **Repo Paths:**
  * App: `apps/scout-dashboard` (Next.js 14, App Router)
  * UI Lib: `apps/scout-ui` (headless primitives + wrappers)
* **Design Baseline:** 12-col grid; faces: *pbi/tableau/superset* (CSS tokens).
* **Charts/Maps:** Recharts + Mapbox GL; optional ECharts adapter later.
* **AI:** Inline overlays per card + AI Chat panel; **MCP** to local router (no tokens in UI).
* **Out of scope:** Ingestion/ELT; non-Supabase backends; vendor authoring.

---

## 1) Objectives & Success Metrics

**Business**
* Reduce exec review prep time by **≥50%** (from ≥2h → ≤1h per weekly board).
* Increase live usage to **≥60 DAU** post-launch.
* Cut "insight request" backlog by **≥30%** via AI overlays.

**Product**
* One dashboard, **six tabs**, multi-face theming; feature parity with vendor embeds where needed.
* Global→module filter coherence with P95 **propagation < 120ms**.
* Export & share: PNG/SVG/PDF for any visual; deep-link with filters.

**Engineering**
* P95 **TTFB < 1.0s**; P95 RPC < **600ms** (post-cache).
* **WCAG 2.1 AA**; zero console warnings in CI.
* 90%+ card states covered (loading/empty/error/no-perm).

---

## 2) Personas & JTBD

* **Regional Manager:** Compare brands/categories by region; spot substitution and shifts.
* **Financial/Trade Analyst:** Track KPIs, basket, promo effect, Pareto.
* **Store Ops Lead:** Requests vs fulfillment, OOS, substitution chains.
* **Brand Lead:** Competitive lifts, cannibalization, demo skews.

---

## 3) Information Architecture

* **Tabs:** `Overview` | `Mix` | `Competitive` | `Geography` | `Consumers` | `AI`
* **Global filters (sticky):** DateRange, Region, Barangay, Category, Brand, Channel.
* **Context filters (per module):** Can extend/override globals; always persisted to URL.

---

## 4) Functional Requirements (by module)

### 4.1 Overview — Transaction Trends

**Visuals**
* KPI Row: Revenue, Transactions, Basket Size, Unique Shoppers.
* Line: Revenue trend (D/W/M).
* Heatmap: Hour × Weekday.
* Boxplot: Basket distribution.

**Interactions**
* Global filters apply; granularity toggle D/W/M.
* Tooltip shows value + YoY/period deltas if available.

**AI Overlay**
* "Where did change originate; top 3 drivers; next question" with confidence.

**RPCs**
* `scout_get_kpis(filters)` → `{ revenue, transactions, basket_size, unique_shoppers }`
* `scout_get_revenue_trend(filters)` → `[{ x, y }]`
* `scout_get_hour_weekday(filters)` → `[{ hour, weekday, value }]`
* `scout_get_basket_boxplot(filters)` → `{ min,q1,median,q3,max }`

---

### 4.2 Mix — Product Mix & SKUs

**Visuals**
* Pareto Top SKUs; Substitution Sankey; Stacked Category Mix; SKU Table.

**Toggles**
* Category, Brand, SKU depth, Substitution window (days).

**AI**
* "Which SKUs drive 80/20; expand/delist list."

**RPCs**
* `scout_get_pareto_skus(filters)` → `[{ sku, value, pctCume }]`
* `scout_get_substitution(filters, windowDays)` → `[{ source, target, value }]`
* `scout_get_category_mix(filters)` → `[{ category, share }]`
* `scout_list_skus(filters, paging)` → table rows

---

### 4.3 Competitive

**Visuals**
* Category Share Over Time (stacked); Positioning Matrix (price × share); Cannibalization chords (optional).

**Toggles**
* Brand set, Category, Region.

**AI**
* "Who gained share; probable driver; cannibalization pairs."

**RPCs**
* `scout_get_share_time(filters, brandSet)` → `[{ brand, x, share }]`
* `scout_get_positioning(filters, brandSet)` → `[{ brand, price, share }]`
* `scout_get_cannibalization(filters, brandSet)` → `[{ source, target, pct }]`

---

### 4.4 Geography

**Visuals**
* Choropleth (region/barangay); Hexbin hotspots; Drill Table sidecar.

**Toggles**
* Metric selector; Normalization (per capita/per store).

**AI**
* "Where to target promos; logistics hint."

**RPCs**
* `scout_geo_summary(filters, metric)` → `[{ geo_id, value }]`
* `scout_geo_drill(filters)` → table rows

---

### 4.5 Consumers

**Visuals**
* Funnel (request→purchase); Donuts (gender/age); Demographic × Category heatmap.

**Toggles**
* Request type (branded/unbranded), Age, Gender, Region.

**AI**
* "Upsell levers; conversion gaps."

**RPCs**
* `scout_request_to_purchase(filters)` → `[{ stage, value }]`
* `scout_demographic_mix(filters)` → `[{ group, metric }]`

---

### 4.6 AI (Dedicated Chat)

**Panel**
* Right dock or full page; history per session.

**Capabilities**
* NLQ that maps to filters + modules; returns short insight + deep link.
* Export annotated chart (PNG/SVG) with overlay notes.

**Plumbing**
* Calls **local MCP router** only; never sends secrets; leverages existing DAL.
* Tools: query presets, prompt templates, export helpers.

---

## 5) Visual Language & Grid

* **Grid:** Desktop 12×(≥88px) cols | Tablet 8 | Mobile 4; 16px gutters, 24px outer.
* **Cards:** header (title/info/AI spark), body (chart/table), footer (notes).
* **States:** `loading` skeleton; `empty` friendly; `error` retry+code; `no-perm` RLS hint.
* **Faces:** `pbi/tableau/superset` via CSS variables only (no vendor CSS).
* **Icons:** `@tabler/icons-react` via central shim; color = `currentColor`.

---

## 6) End-State JSON (Renderer Contract)

See `apps/scout-dashboard/dashboard.config.json` for the complete configuration.

---

## 7) API Contract (Frontend ↔ Supabase RPC)

Package: `packages/contracts/src/scout.ts`

**Inputs**: `filters` object `{ dateRange, region[], barangay[], category[], brand[], channel[] }`

**Types**:
```typescript
export type KpiSet = { revenue: number; transactions: number; basket_size: number; unique_shoppers: number };
export type TrendPoint = { x: string; y: number };
export type ParetoItem = { sku: string; value: number; pctCume: number };
export type SankeyLink = { source: string; target: string; value: number };
export type ShareTime = { brand: string; x: string; share: number };
export type Positioning = { brand: string; price: number; share: number };
export type GeoRow = { region: string; value: number };
export type FunnelRow = { stage: string; value: number };
export type DemographicRow = { group: string; metric: number };
```

**RPC names**: as listed in §4.
**Behavior**: all RPCs **fail closed under RLS**; empty arrays are valid responses.

---

## 8) Non-Functional Requirements

**Performance**
* P95 **TTFB < 1.0s**; P95 **RPC < 600ms** once warm.
* Inter-module filter propagation **< 120ms**.

**Security**
* **No secrets** in client.
* Supabase RLS on all fact tables; region-scoped policy.
* Token brokering (PBI/Tableau) via Edge Function only.

**Reliability**
* Each card implements `loading/empty/error/no-perm`.
* React Query retries=1; exponential backoff; toasts for fatal errors.

**A11y**
* WCAG 2.1 AA; keyboardable filters; SR summaries for charts.

**DX**
* Storybook for `apps/scout-ui`; Code Connect mappings; CI gates: lint/type/test/a11y/gitleaks/CodeConnect parse.

**Observability**
* Frontend metrics: RPC latency per module, error codes, cache hit ratio.
* Console warnings banned in CI.

---

## 9) Architecture & Dependencies

* **Frontend:** Next.js 14 App Router; Tailwind tokens; Zustand filter store; React Query DAL.
* **Backend:** Supabase (Postgres, pgvector, RLS, Realtime, Edge Functions).
* **Realtime:** broadcast channel `scout-filters`; optional DB change feeds for live KPIs.
* **MCP:** local servers (supabase, github, diagram-bridge) — no outbound secrets.
* **Embeds:** Power BI/Tableau/Superset behind flags (`NEXT_PUBLIC_ENABLE_*`).

---

## 10) Wireframes (ASCII)

Desktop 12-col, Tablet 8, Mobile 4; cards stack; filter bar sticky.

```
┌─────────────────────────────────────────────────────────────┐
│ [Scout v6.0]  Overview | Mix | Competitive | Geo | Con | AI │
├─────────────────────────────────────────────────────────────┤
│ Filters: [DateRange▼] [Region▼] [Category▼] [Brand▼]       │
├─────────────────────────────────────────────────────────────┤
│ ┌───────┐ ┌───────┐ ┌───────┐ ┌───────┐                   │
│ │ KPI 1 │ │ KPI 2 │ │ KPI 3 │ │ KPI 4 │  (3 cols each)   │
│ └───────┘ └───────┘ └───────┘ └───────┘                   │
│ ┌───────────────────────┐ ┌─────────┐                     │
│ │   Revenue Trend       │ │ Heatmap │  (8 cols | 4 cols) │
│ └───────────────────────┘ └─────────┘                     │
└─────────────────────────────────────────────────────────────┘
```

---

## 11) Acceptance Criteria (UAT)

**Navigation & Layout**
1. Tab switching persists to URL; reload restores active tab.
2. Responsive at 3 breakpoints; no overflow/clip.

**Filters & Data**
3. Global filter change updates all modules <120ms; context override isolates module.
4. Basket sanity: `basket_size ≈ revenue/transactions ±5%`.
5. Pareto reaches ~80% by top N; renders both curve + table.

**AI**
6. Overlay on enabled cards returns non-generic rationale; hides on export.
7. AI Chat query → filtered deep link; no secret egress (network inspect).

**Perf/A11y**
8. P95 metrics meet targets in synthetic & staging tests.
9. SR navigation reads chart summaries; focus order logical; contrast ≥4.5:1.

**CI**
10. Lint/type/unit/a11y/gitleaks/CodeConnect parse all pass; zero console warnings.

---

## 12) Definition of Done (per module)

* Layout matches wireframes (3 breakpoints).
* RPC hooks typed; states covered; URL sync in place.
* AI overlay copy specific (names regions/brands, exact deltas).
* Storybook stories for states; Code Connect mapping present.
* Unit tests for hooks; visual snap optional.

---

## 13) Risks & Mitigations

* **RLS gaps** → Unauthorized data exposure. *Mitigation:* policy tests; staging red team.
* **Vendor auth drift** → Embed failures. *Mitigation:* Edge Function token broker; canary checks.
* **Realtime scale** → Broadcast storm. *Mitigation:* debounce + topic partitioning; cut over to presence if needed.
* **AI hallucination** → Misleading overlays. *Mitigation:* cite source metrics; show confidence; allow hide.

---

## 14) Constraints

* No vendor CSS; faces via CSS variables only.
* No secrets in client; Edge Functions for brokering.
* Draw.io: use CLI or viewer links; Kroki diagramsnet only if self-hosted.

---

## 15) Delivery Plan

**W1-2** Scaffold UI, global filters, Overview KPIs/trend.
**W3-4** Mix & Competitive + RPCs; exports; URL sync.
**W5** Geography + Consumers; Mapbox.
**W6** AI overlays + Chat (MCP).
**W7** Embeds (feature-flag), Realtime, perf pass.
**W8** A11y & UAT; docs; prod deploy.

---

## 16) Telemetry & Logging

Event names: `filter.change`, `rpc.ok`, `rpc.err`, `card.export`, `ai.overlay.shown`, `ai.chat.ask`.
Include `tab`, `module`, `rpc`, `duration_ms`, `rows`, `err_code`.

---

## 17) Feature Flags

`aiOverlay`, `aiChat`, `geoHexbin`, `vendorEmbeds` (pbi/tableau/superset individually), `face` default.

---

## 18) File/Package Layout (enforced)

```
apps/scout-dashboard/
  app/(routes)/{overview,mix,competitive,geography,consumers,ai}/page.tsx
  src/components/{filters,cards,charts,ai}
  src/data/{rpc.ts,hooks.ts,supabase.ts}
  src/store/useFilters.ts
  dashboard.config.json
apps/scout-ui/
  src/components/{Kpi,Layout,Chart,Map}/...
packages/contracts/src/scout.ts
docs/prd/PRD-SCOUT-UI-v6.0.md
```

---

## 19) Appendix — Test Matrix (abbrev)

* **Unit:** hooks (RPC success/empty/error), filter store ops, URL sync.
* **Integration:** tab render; filter propagation; export flows.
* **E2E (Playwright):** smoke per tab × face; screenshot diffs (per face).
* **A11y (axe):** violations = 0 (excluding known map aria roles with notes).

---

## 20) Approval

* **Prepared by:** Jake / InsightPulseAI
* **Reviewed by:** Product, Eng, DS
* **Approved by:** [Stakeholder]
* **Date:** 2025-01-29
