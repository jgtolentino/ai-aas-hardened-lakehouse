# Scout v5.2 — Competitive & Geo Intelligence PRD Addendum

**Version**: 5.2.1  
**Status**: Ready for Implementation  
**Last Updated**: August 24, 2025  
**Integration**: Superset Dashboard  

---

## 1) Feature Map (Where Each v5.2 Capability Shows Up)

* **Transaction Trends**: time-of-day, barangay/region, weekday/weekend, category. Visuals: time-series, heatmap, boxplots.
* **Product Mix & SKU**: brand/category stacks, Pareto, *Top SKUs*, substitution flows (Sankey).
* **Consumer Behavior Signals**: branded vs unbranded requests, pointing vs verbal, acceptance of storeowner suggestion (funnel).
* **Consumer Profiling**: gender/age buckets (inferred), geo heatmap + donut trees.
* **AI Recommendation Panel**: persona/seasonality/health-lift aware bundle & upsell suggestions (overlay panel).

> These four modules + AI panel match the dashboard structure you already circulated; below we wire them to data + ML and add competitive/geo intelligence.

---

## 2) Competitive Intelligence (Gold + Platinum)

### **KPIs**

* Category/brand **market share** (units, revenue)
* **Switching & substitution**: A→B counts, rate, reasons (price/stock)
* **Promo lift** & **price elasticity** (by store cluster)
* **Client vs non-client** share (TBWA vs others)

### **Gold Datasets (Views)**

* `scout.gold_brand_competitive_30d(store_id, category, brand, units, revenue, share_units, share_revenue, price_idx, promo_flag, last_30d_growth)`
* `scout.gold_substitution_sankey_30d(category, from_brand, to_brand, count, pct, reason)`
* `scout.gold_price_elasticity(store_cluster, brand, elasticity, conf, sample_n)`

### **Platinum Features (for ML & the AI Panel)**

* `scout.feature_brand_switch_propensity(customer_key, brand_code, p_switch_30d)`
* `scout.feature_health_lift(category, condition, lift_pct)` (from your health rules)
* `scout.feature_seasonality(category, month, factor)`

### **UI (Superset Components)**

* Stacked bar (category → brand share)
* Pareto for top-N SKUs
* **Sankey** for A→B substitutions
* "Drivers" table: stockouts, price deltas, promo flags

---

## 3) Geographical Intelligence

### **Granularity**

* Region → Province → City/Muni → Barangay (PSGC backed)
* Store clustering (catchment buffers) for micro-trade areas

### **Gold Datasets**

* `scout.gold_region_choropleth(day, region_key, geom, txn_count, revenue, avg_ticket, active_stores, rev_per_capita)`
* `scout.gold_citymun_choropleth(day, citymun_psgc, geom, txn_count, revenue, client_share, top_brand)`
* `scout.gold_barangay_rollup(day, barangay, txn_count, revenue, top_categories)`

### **Visuals (Superset / deck.gl)**

* Choropleth (ADM1/ADM3 simplified geometries)
* Side-panel drill filters: Region > Province > City/Muni > Barangay
* Tooltip: rank, revenue growth, top-brand, client share

---

## 4) ML Outputs (What "MLQ Outputs" Surface in UI)

* **Demand Lift** = base × `feature_health_lift` × `feature_seasonality` × promo factor
* **Propensity** to switch (brand_switch_propensity) → fuels **AI Recommendation Panel**:

  * "Stock more **X** in **Hot Months** (+12% expected)"
  * "Place **Brand B** as fallback for **Brand A** (switch rate 31%)"
  * "In Barangay 770, push **bundle N**: noodles + cola (+₱18 ATP)"

---

## 5) Superset "Look & Feel" (Production)

### **Datasets**

* Point Superset to the `gold_*` and `mv_*` views; enable **row-level security** via PostgREST role.
* Use **Mapbox** token (already in repo) with deck.gl layers for maps.

### **Styling**

* Typeface: Inter or Source Sans (bundled)
* 8-column grid; spacing 16px; compact table density
* Color: neutral base; categories by hue, brands by shade
* Cross-filters ON; native filters on top bar (date, region, category)

### **Performance**

* Materialize heavy views (`mv_*`), refresh every 5–10 min
* GIST indexes on `geom`; numeric btree on date/store
* Dashboard P95 < 3s

---

## 6) Data Contracts: Sources → Gold

### **Bronze/Silver**

* `bronze_transactions`, `bronze_events` → `silver_transactions`, `silver_line_items`
* STT: `stt_detections` (no audio saved) → join into silver_line_items (brand hint)
* Edge health/installation checks do **not** enter analytics layer

### **Gold Builders (Examples)**

* **Brand Share**

  ```sql
  CREATE OR REPLACE VIEW scout.gold_brand_competitive_30d AS
  SELECT
    d.category_name AS category,
    p.brand_name AS brand,
    s.store_id,
    SUM(i.quantity) AS units,
    SUM(i.line_amount) AS revenue,
    100.0 * SUM(i.quantity) / NULLIF(SUM(SUM(i.quantity)) OVER (PARTITION BY d.category_name, s.store_id), 0) AS share_units,
    100.0 * SUM(i.line_amount) / NULLIF(SUM(SUM(i.line_amount)) OVER (PARTITION BY d.category_name, s.store_id), 0) AS share_revenue
  FROM scout.fact_transaction_items i
  JOIN scout.dim_products p ON i.product_key = p.product_key AND p.is_current
  JOIN scout.dim_stores s ON i.transaction_id IN (SELECT transaction_id FROM scout.fact_transactions WHERE store_key = s.store_key)
  JOIN scout.dim_products d ON d.product_key = p.product_key
  WHERE (SELECT MAX(full_date) FROM scout.dim_date) - INTERVAL '30 days' <= NOW()
  GROUP BY 1, 2, 3;
  ```

* **Substitution Sankey**

  ```sql
  CREATE OR REPLACE VIEW scout.gold_substitution_sankey_30d AS
  SELECT 
    category, 
    detected_brand AS from_brand, 
    COALESCE(substitute_to, '(none)') AS to_brand,
    COUNT(*) AS count,
    100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY category) AS pct,
    COALESCE(reason, 'availability') AS reason
  FROM scout.fact_substitutions -- if not present, derive from basket + stt_detections
  WHERE detected_at >= NOW() - INTERVAL '30 days'
  GROUP BY 1, 2, 3, 5;
  ```

* **Region Choropleth** (already patterned in your repo)

---

## 7) UAT (What "Done" Looks Like)

### **Functional**

* [ ] Time, geo, category, weekend toggles filter **all** tiles consistently.
* [ ] Substitution Sankey updates with filters and matches counts in detail table.
* [ ] Choropleth drill: Region→Province→City/Muni in ≤1.5s P95.
* [ ] AI Panel cites reason codes (seasonality/health/switching).
* [ ] No audio/video artifacts present; STT table contains **text results only**.

### **Data Quality**

* [ ] Brand share sums ≈100% per (category, store, date range).
* [ ] Geo totals match transactional totals within 0.1%.
* [ ] Elasticity cards show conf-intervals & sample size gates.

### **Perf/SLO**

* [ ] Dashboard P95 < 3s; map tiles < 2.5s.
* [ ] MV refresh completes < 2m; recency banner shows "updated X min ago".

### **Security**

* [ ] RLS enforced by tenant/store; public views expose **no PII**.
* [ ] API keys rotated; CORS locked to dashboard host.

---

## 8) Wiring in the PDF's Layout

Your PDF already prescribes **modules, visuals, and toggles** (time-of-day, region/barangay, brand/category, request type, etc.). We've mapped those 1:1 above and added competitive & geo analytics + the AI panel to operationalize it as production Superset tiles. 

---

## 9) Go-Live Checklist (1 Sprint)

1. Create/refresh **gold views** above (+ materialized where needed).
2. Register views as **Superset datasets**; enable cross-filters.
3. Add **deck.gl Mapbox** charts for region & city/mun layers.
4. Drop **AI panel** as markdown + KPI tiles fed by platinum features.
5. Run UAT scenario pack; capture baselines; tune indexes/MV refresh.
6. Flip "Production" flag; enable SLO monitors.

If you want, I can also supply the Superset import bundle (charts + datasets + dashboard JSON) pre-wired to these view names so you can import and go.

---

## 10) Implementation Priority

### Sprint 1 (Week 1-2)
- [ ] Create competitive intelligence views
- [ ] Build geographical roll-up views
- [ ] Implement ML feature tables
- [ ] Test performance with indexes

### Sprint 2 (Week 3-4)
- [ ] Superset dataset configuration
- [ ] Build dashboard layouts
- [ ] Implement cross-filters
- [ ] Add AI recommendation panel

### Sprint 3 (Week 5-6)
- [ ] UAT testing
- [ ] Performance tuning
- [ ] Documentation
- [ ] Production deployment

---