# Scout Gold Data Access Layer (DAL) - ASCII Architecture

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                           SCOUT GOLD DATA ACCESS LAYER                          │
└─────────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────────┐
│                                CLIENT APPLICATIONS                              │
├─────────────────┬─────────────────┬─────────────────┬─────────────────────────┤
│ Scout Dashboard │   BI Tools      │  REST APIs      │   ML Pipelines          │
│   (React/TS)    │  (Superset)     │  (PostgREST)    │  (Python/DBT)           │
└────────┬────────┴────────┬────────┴────────┬────────┴────────┬────────────────┘
         │                 │                 │                 │
         ▼                 ▼                 ▼                 ▼
┌─────────────────────────────────────────────────────────────────────────────────┐
│                          DATA ACCESS LAYER (DAL)                                │
│  ┌─────────────────────────────────────────────────────────────────────────┐   │
│  │                         TypeScript DAL Service                           │   │
│  │  ┌─────────────┐  ┌──────────────┐  ┌─────────────┐  ┌──────────────┐ │   │
│  │  │ Query       │  │ Caching      │  │ RLS         │  │ Monitoring   │ │   │
│  │  │ Builder     │  │ Layer        │  │ Enforcement │  │ & Metrics    │ │   │
│  │  └─────────────┘  └──────────────┘  └─────────────┘  └──────────────┘ │   │
│  └─────────────────────────────────────────────────────────────────────────┘   │
└───────────────────────────────┬─────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────────────────────┐
│                               GOLD LAYER VIEWS                                  │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│  ┌──────────────────────┐     ┌──────────────────────┐    ┌─────────────────┐ │
│  │  v_gold_kpi_summary  │     │ v_gold_transactions  │    │ v_gold_products │ │
│  ├──────────────────────┤     ├──────────────────────┤    ├─────────────────┤ │
│  │ • Total Revenue      │     │ • Transaction ID     │    │ • Product ID    │ │
│  │ • Transaction Count  │     │ • Store Info         │    │ • Brand Name    │ │
│  │ • Active Stores      │     │ • Customer Data      │    │ • Category      │ │
│  │ • Avg Basket Size    │     │ • Line Items         │    │ • Price History │ │
│  └──────────────────────┘     └──────────────────────┘    └─────────────────┘ │
│                                                                                 │
│  ┌──────────────────────┐     ┌──────────────────────┐    ┌─────────────────┐ │
│  │ v_gold_store_metrics │     │v_gold_region_summary │    │v_gold_time_series│ │
│  ├──────────────────────┤     ├──────────────────────┤    ├─────────────────┤ │
│  │ • Store Performance  │     │ • Regional KPIs      │    │ • Daily Trends  │ │
│  │ • Product Mix        │     │ • Choropleth Data    │    │ • Weekly Rollups│ │
│  │ • Customer Segments  │     │ • Population Stats   │    │ • Monthly Aggs  │ │
│  │ • Revenue Trends     │     │ • Market Penetration │    │ • YoY Comparison│ │
│  └──────────────────────┘     └──────────────────────┘    └─────────────────┘ │
│                                                                                 │
└───────────────────────────────┬─────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────────────────────┐
│                            GOLD LAYER TABLES                                    │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│  ┌────────────────┐  ┌─────────────────────┐  ┌────────────────────────────┐  │
│  │     FACTS      │  │    DIMENSIONS       │  │      AGGREGATES            │  │
│  ├────────────────┤  ├─────────────────────┤  ├────────────────────────────┤  │
│  │                │  │                     │  │                            │  │
│  │ fact_trans     │──┤ dim_products        │  │ agg_daily_store_summary    │  │
│  │ fact_items     │  │ dim_stores          │  │ agg_product_performance    │  │
│  │ fact_payments  │  │ dim_customers       │  │ agg_regional_metrics       │  │
│  │                │  │ dim_time            │  │ agg_customer_segments      │  │
│  │                │  │ dim_geography       │  │                            │  │
│  └────────────────┘  └─────────────────────┘  └────────────────────────────┘  │
│         │                      │                           │                    │
└─────────┼──────────────────────┼───────────────────────────┼────────────────────┘
          │                      │                           │
          ▼                      ▼                           ▼
┌─────────────────────────────────────────────────────────────────────────────────┐
│                            SILVER LAYER (Source)                                │
├─────────────────────────────────────────────────────────────────────────────────┤
│  silver_transactions    silver_products    silver_stores    silver_customers    │
└─────────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────────┐
│                           DAL SERVICE FEATURES                                  │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│  Query Builder:                    Caching:                                     │
│  ┌─────────────┐                  ┌─────────────┐                             │
│  │ SELECT      │                  │ Redis/Memory│                             │
│  │ JOIN        │                  │ TTL Config  │                             │
│  │ WHERE       │                  │ Invalidation│                             │
│  │ GROUP BY    │                  └─────────────┘                             │
│  │ ORDER BY    │                                                              │
│  └─────────────┘                  Security:                                    │
│                                   ┌─────────────┐                             │
│  Filters:                         │ Row Level   │                             │
│  ┌─────────────┐                  │ Security    │                             │
│  │ Date Range  │                  │ User Context│                             │
│  │ Store IDs   │                  │ Role Based  │                             │
│  │ Product Cat │                  └─────────────┘                             │
│  │ Region      │                                                              │
│  └─────────────┘                                                              │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────────┐
│                              API ENDPOINTS                                      │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│  GET /api/gold/kpis              ──► Executive dashboard KPIs                  │
│  GET /api/gold/transactions      ──► Paginated transaction list               │
│  GET /api/gold/products          ──► Product catalog with metrics             │
│  GET /api/gold/stores/:id        ──► Store-specific analytics                 │
│  GET /api/gold/regions           ──► Regional performance data                │
│  GET /api/gold/timeseries        ──► Time-based analytics                     │
│  POST /api/gold/query            ──► Custom query interface                   │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────────┐
│                           PERFORMANCE OPTIMIZATIONS                             │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│  • Materialized Views refreshed every 15 minutes                               │
│  • Strategic indexes on all foreign keys and filter columns                    │
│  • Partitioning on transaction date (monthly)                                  │
│  • Query result caching with smart invalidation                                │
│  • Connection pooling (25 connections)                                         │
│  • Prepared statements for common queries                                      │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
```

## Scout Gold DAL Implementation Details

```
┌─────────────────────────────────────────────────────────────────┐
│                    TypeScript DAL Service                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  // Core DAL Interface                                          │
│  interface ScoutGoldDAL {                                       │
│    // KPI Methods                                               │
│    getKPISummary(filters?: FilterOptions): Promise<KPIData>    │
│    getStoreMetrics(storeId: string): Promise<StoreMetrics>     │
│    getRegionalData(): Promise<RegionalMetrics[]>               │
│                                                                 │
│    // Transaction Methods                                       │
│    getTransactions(params: QueryParams): Promise<PagedResult>  │
│    getTransactionDetails(id: string): Promise<Transaction>     │
│                                                                 │
│    // Analytics Methods                                         │
│    getTimeSeries(params: TimeSeriesParams): Promise<Series[]>  │
│    getProductPerformance(): Promise<ProductMetrics[]>          │
│                                                                 │
│    // Custom Query                                              │
│    executeQuery(sql: string, params: any[]): Promise<any[]>    │
│  }                                                              │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                       Data Flow Example                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Dashboard Request:                                             │
│  ┌─────────────┐                                               │
│  │   User      │ ──(1)──► "Show store performance"             │
│  └─────────────┘                                               │
│        │                                                        │
│        ▼                                                        │
│  ┌─────────────┐                                               │
│  │  React App  │ ──(2)──► dalService.getStoreMetrics('STR001') │
│  └─────────────┘                                               │
│        │                                                        │
│        ▼                                                        │
│  ┌─────────────┐                                               │
│  │  DAL Layer  │ ──(3)──► Check cache                          │
│  └─────────────┘          │                                    │
│        │                  ▼                                    │
│        │            Cache miss                                  │
│        ▼                  │                                    │
│  ┌─────────────┐          ▼                                    │
│  │  Gold View  │ ──(4)──► Query v_gold_store_metrics           │
│  └─────────────┘                                               │
│        │                                                        │
│        ▼                                                        │
│  ┌─────────────┐                                               │
│  │   Result    │ ──(5)──► Cache result                         │
│  └─────────────┘          Return to app                        │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```