---
title: Gold Layer APIs
sidebar_label: Gold APIs
sidebar_position: 2
---

# Gold Layer API Reference

The Gold Layer provides 53 optimized endpoints for analytics and reporting. All endpoints follow RESTful conventions and return JSON responses.

## 🔑 Authentication

All Gold API endpoints require authentication via Supabase JWT:

```javascript
const headers = {
  'Authorization': `Bearer ${supabaseAnonKey}`,
  'Content-Type': 'application/json'
};
```

## 📊 Core Analytics Endpoints

### Brand Performance

#### `GET /api/gold/brand-share`

Returns market share data for brands within a category.

**Parameters:**
```typescript
{
  date_from: string;     // YYYY-MM-DD
  date_to: string;       // YYYY-MM-DD
  region_id?: number;    // Optional regional filter
  category_id?: number;  // Optional category filter
  limit?: number;        // Default: 100
}
```

**Response:**
```json
{
  "data": [
    {
      "brand_id": 101,
      "brand_name": "Lucky Me",
      "category_id": 5,
      "category_name": "Instant Noodles",
      "market_share_pct": 42.5,
      "sales_amount": 1250000.00,
      "units_sold": 45000,
      "trend": "up",
      "vs_last_period": 3.2
    }
  ],
  "metadata": {
    "total_records": 25,
    "period": "2025-01-01 to 2025-01-31"
  }
}
```

---

#### `GET /api/gold/brand-penetration`

Calculates brand reach across stores.

**Parameters:**
```typescript
{
  date_from: string;
  date_to: string;
  brand_id?: number;
  min_penetration?: number;  // Filter by minimum %
}
```

**Response:**
```json
{
  "data": [
    {
      "brand_id": 101,
      "brand_name": "Lucky Me",
      "total_stores": 5000,
      "stores_selling": 4250,
      "penetration_pct": 85.0,
      "avg_units_per_store": 120,
      "geographic_coverage": {
        "regions": 17,
        "cities": 145,
        "barangays": 2100
      }
    }
  ]
}
```

---

### Customer Analytics

#### `GET /api/gold/customer-segments`

Returns customer segmentation analysis.

**Parameters:**
```typescript
{
  date_from: string;
  date_to: string;
  store_id?: number;
  segment_type?: 'value' | 'frequency' | 'recency';
}
```

**Response:**
```json
{
  "data": [
    {
      "segment": "High Value",
      "customer_count": 1200,
      "avg_basket_size": 350.00,
      "avg_frequency": 8.5,
      "total_revenue": 420000.00,
      "pct_of_total": 35.5,
      "top_categories": ["Personal Care", "Snacks", "Beverages"]
    }
  ]
}
```

---

#### `GET /api/gold/customer-retention`

Analyzes customer retention and churn metrics.

**Parameters:**
```typescript
{
  cohort_month: string;  // YYYY-MM
  months_forward?: number;  // Default: 6
  region_id?: number;
}
```

**Response:**
```json
{
  "data": {
    "cohort_size": 5000,
    "retention_curve": [
      { "month": 0, "retained": 5000, "pct": 100.0 },
      { "month": 1, "retained": 4200, "pct": 84.0 },
      { "month": 2, "retained": 3800, "pct": 76.0 }
    ],
    "churn_rate": 24.0,
    "ltv_estimate": 2500.00
  }
}
```

---

### Product Analytics

#### `GET /api/gold/product-velocity`

Measures product sales velocity and trends.

**Parameters:**
```typescript
{
  date_from: string;
  date_to: string;
  category_id?: number;
  min_velocity?: number;
  sort_by?: 'velocity' | 'growth' | 'revenue';
}
```

**Response:**
```json
{
  "data": [
    {
      "product_id": 2001,
      "product_name": "C2 Green Tea 355ml",
      "sku": "C2-GT-355",
      "velocity": 250.5,  // units per day
      "growth_rate": 15.2,
      "days_of_supply": 3.5,
      "stockout_risk": "low"
    }
  ]
}
```

---

#### `GET /api/gold/product-affinity`

Identifies products frequently purchased together.

**Parameters:**
```typescript
{
  product_id: number;
  date_from: string;
  date_to: string;
  min_confidence?: number;  // Default: 0.3
}
```

**Response:**
```json
{
  "data": [
    {
      "product_a": "C2 Green Tea",
      "product_b": "Skyflakes Crackers",
      "support": 0.45,
      "confidence": 0.72,
      "lift": 2.1,
      "co_occurrence_count": 1250
    }
  ]
}
```

---

### Geographic Analytics

#### `GET /api/gold/geo-performance`

Regional and barangay-level performance metrics.

**Parameters:**
```typescript
{
  date_from: string;
  date_to: string;
  geo_level: 'region' | 'city' | 'barangay';
  metric?: 'revenue' | 'units' | 'stores' | 'growth';
}
```

**Response:**
```json
{
  "data": [
    {
      "geo_id": 13,
      "geo_name": "NCR",
      "geo_level": "region",
      "total_revenue": 5200000.00,
      "total_units": 185000,
      "active_stores": 2100,
      "growth_vs_ly": 12.5,
      "coordinates": {
        "lat": 14.5995,
        "lng": 120.9842
      }
    }
  ]
}
```

---

#### `GET /api/gold/geo-heatmap`

Returns data formatted for geographic visualization.

**Parameters:**
```typescript
{
  date: string;  // Single date
  metric: 'sales' | 'traffic' | 'growth';
  normalize?: boolean;  // Per-capita normalization
}
```

**Response:**
```json
{
  "type": "FeatureCollection",
  "features": [
    {
      "type": "Feature",
      "geometry": {
        "type": "Polygon",
        "coordinates": [[[120.9842, 14.5995]]]
      },
      "properties": {
        "region_id": 13,
        "region_name": "NCR",
        "value": 5200000.00,
        "color_intensity": 0.95
      }
    }
  ]
}
```

---

### Competitive Intelligence

#### `GET /api/gold/competitive-share`

Tracks competitive dynamics and market share shifts.

**Parameters:**
```typescript
{
  date_from: string;
  date_to: string;
  category_id: number;
  competitors?: number[];  // Brand IDs to compare
}
```

**Response:**
```json
{
  "data": {
    "market_size": 15000000.00,
    "competitors": [
      {
        "brand_id": 101,
        "brand_name": "Lucky Me",
        "share_pct": 42.5,
        "share_change": 2.1,
        "win_rate": 0.65,
        "switching_in": 1200,
        "switching_out": 800
      }
    ],
    "share_movements": [
      {
        "from_brand": "Nissin",
        "to_brand": "Lucky Me",
        "switch_count": 450,
        "revenue_impact": 45000.00
      }
    ]
  }
}
```

---

#### `GET /api/gold/substitution-matrix`

Analyzes product substitution patterns.

**Parameters:**
```typescript
{
  date_from: string;
  date_to: string;
  category_id?: number;
  min_substitution_score?: number;
}
```

**Response:**
```json
{
  "data": [
    {
      "primary_product": "Coke 1.5L",
      "substitute_product": "Pepsi 1.5L",
      "substitution_score": 0.78,
      "occasions": 320,
      "price_differential": -2.00,
      "availability_factor": 0.85
    }
  ]
}
```

---

### Time Series & Forecasting

#### `GET /api/gold/sales-forecast`

Returns ML-powered sales forecasts.

**Parameters:**
```typescript
{
  entity_type: 'product' | 'brand' | 'category' | 'store';
  entity_id: number;
  horizon_days?: number;  // Default: 30
  confidence_level?: number;  // Default: 0.95
}
```

**Response:**
```json
{
  "data": {
    "historical": [
      { "date": "2025-01-01", "actual": 45000.00 }
    ],
    "forecast": [
      {
        "date": "2025-02-01",
        "predicted": 48000.00,
        "lower_bound": 46000.00,
        "upper_bound": 50000.00,
        "confidence": 0.95
      }
    ],
    "model_metrics": {
      "mape": 5.2,
      "rmse": 2100.00,
      "model_type": "prophet"
    }
  }
}
```

---

#### `GET /api/gold/trend-analysis`

Identifies trends and seasonality patterns.

**Parameters:**
```typescript
{
  date_from: string;
  date_to: string;
  entity_type: string;
  entity_id: number;
  decompose?: boolean;  // Return trend/seasonal components
}
```

**Response:**
```json
{
  "data": {
    "trend_direction": "increasing",
    "trend_strength": 0.72,
    "seasonality": {
      "type": "weekly",
      "peak_days": ["Saturday", "Sunday"],
      "variation_pct": 35.0
    },
    "anomalies": [
      {
        "date": "2025-01-15",
        "value": 75000.00,
        "expected": 50000.00,
        "deviation_sigma": 3.2
      }
    ]
  }
}
```

---

## 🎯 Specialized Dashboards

### Executive KPIs

#### `GET /api/gold/executive-summary`

High-level KPIs for C-suite dashboard.

**Parameters:**
```typescript
{
  date: string;  // Snapshot date
  comparison_period?: 'day' | 'week' | 'month' | 'year';
}
```

**Response:**
```json
{
  "data": {
    "total_revenue": {
      "value": 15200000.00,
      "vs_target": 102.5,
      "vs_last_period": 8.2,
      "trend": "up"
    },
    "active_stores": {
      "value": 8500,
      "new_this_period": 120,
      "churn_this_period": 45
    },
    "market_share": {
      "value": 32.5,
      "change": 1.2,
      "rank": 2
    },
    "customer_satisfaction": {
      "nps_score": 72,
      "reviews": 1250,
      "avg_rating": 4.3
    }
  }
}
```

---

### Store Performance

#### `GET /api/gold/store-ranking`

Ranks stores by various performance metrics.

**Parameters:**
```typescript
{
  date_from: string;
  date_to: string;
  metric: 'revenue' | 'growth' | 'efficiency';
  limit?: number;
  region_id?: number;
}
```

**Response:**
```json
{
  "data": [
    {
      "rank": 1,
      "store_id": 1001,
      "store_name": "Aling Nena Sari-Sari",
      "region": "NCR",
      "city": "Quezon City",
      "metric_value": 125000.00,
      "percentile": 99.5,
      "badges": ["top_performer", "consistent_growth"]
    }
  ]
}
```

---

## 📈 Aggregation Endpoints

### Daily Rollups

#### `GET /api/gold/daily-summary`

Pre-aggregated daily metrics for performance.

**Parameters:**
```typescript
{
  date: string;
  aggregation_level?: 'company' | 'region' | 'store';
  entity_id?: number;
}
```

---

### Weekly Business Review

#### `GET /api/gold/weekly-business-review`

Comprehensive weekly performance packet.

**Parameters:**
```typescript
{
  week_ending: string;  // YYYY-MM-DD (Sunday)
  include_sections?: string[];  // Optional sections
}
```

---

## 🔄 Data Export Endpoints

#### `GET /api/gold/export`

Exports data in various formats.

**Parameters:**
```typescript
{
  query: string;  // Endpoint name
  params: object;  // Endpoint parameters
  format: 'json' | 'csv' | 'excel';
  compress?: boolean;
}
```

---

## ⚡ Performance Guidelines

### Pagination

All list endpoints support pagination:

```typescript
{
  limit: number;   // Max records (default: 100, max: 1000)
  offset: number;  // Skip records (default: 0)
}
```

### Caching

Responses include cache headers:

```http
Cache-Control: public, max-age=300
ETag: "686897696a7c876b7e"
Last-Modified: Mon, 23 Aug 2025 12:00:00 GMT
```

### Rate Limits

| Tier | Requests/Min | Requests/Hour | Concurrent |
|------|-------------|---------------|------------|
| Free | 10 | 100 | 2 |
| Pro | 60 | 3,600 | 10 |
| Enterprise | 600 | 36,000 | 100 |

---

## 🚨 Error Responses

All errors follow consistent format:

```json
{
  "error": {
    "code": "RESOURCE_NOT_FOUND",
    "message": "Brand with ID 999 not found",
    "details": {
      "resource": "brand",
      "id": 999
    },
    "timestamp": "2025-08-23T10:30:00Z"
  }
}
```

### Common Error Codes

| Code | HTTP Status | Description |
|------|------------|-------------|
| `AUTH_REQUIRED` | 401 | Missing or invalid JWT |
| `FORBIDDEN` | 403 | Insufficient permissions |
| `RESOURCE_NOT_FOUND` | 404 | Entity doesn't exist |
| `VALIDATION_ERROR` | 400 | Invalid parameters |
| `RATE_LIMIT_EXCEEDED` | 429 | Too many requests |
| `SERVER_ERROR` | 500 | Internal server error |

---

## 🧪 Testing Endpoints

Use the Supabase Dashboard or tools like Postman:

```bash
# Example cURL request
curl -X GET "https://your-project.supabase.co/rest/v1/rpc/get_gold_brand_share" \
  -H "apikey: YOUR_ANON_KEY" \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{"date_from": "2025-01-01", "date_to": "2025-01-31"}'
```

---

*For DAL implementation details, see [DAL Reference](/docs/dal/gold-fetchers)*
