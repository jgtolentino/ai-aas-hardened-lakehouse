## **Scout Analytics Platform - Complete API Documentation**

### **Table of Contents**
1. [Authentication](#authentication)
2. [Edge Functions API](#edge-functions-api)
3. [Database REST API](#database-rest-api)
4. [Analytics Endpoints](#analytics-endpoints)
5. [Real-time Subscriptions](#real-time-subscriptions)
6. [Error Handling](#error-handling)

---

## **Authentication**

### **API Keys**
```typescript
// Public (Anonymous) Key - Client-side
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...

// Service Role Key - Server-side only
SUPABASE_SERVICE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

### **Headers Required**
```http
apikey: [SUPABASE_ANON_KEY]
Authorization: Bearer [SUPABASE_ANON_KEY]
Content-Type: application/json
```

---

## **Edge Functions API**

### **Base URL**
```
https://cxzllzyxwpyptfretryc.supabase.co/functions/v1
```

### **1. Ingest Transaction**
**POST** `/ingest-transaction`

Ingests a single transaction with validation and enrichment.

**Request Body:**
```json
{
  "id": "TXN-2024-001",
  "store_id": "S001",
  "timestamp": "2024-01-15T10:30:00Z",
  "location": {
    "barangay": "Poblacion",
    "city": "Makati",
    "province": "Metro Manila",
    "region": "NCR"
  },
  "product_category": "beverages",
  "brand_name": "Brand A",
  "sku": "SKU001",
  "units_per_transaction": 2,
  "peso_value": 150.00,
  "basket_size": 5,
  "combo_basket": [
    {"sku": "SKU001", "quantity": 2},
    {"sku": "SKU002", "quantity": 3}
  ],
  "request_mode": "verbal",
  "request_type": "branded",
  "suggestion_accepted": true,
  "gender": "female",
  "age_bracket": "25-34",
  "substitution_event": {
    "occurred": false
  },
  "duration_seconds": 45,
  "campaign_influenced": true,
  "handshake_score": 0.85,
  "is_tbwa_client": true,
  "payment_method": "gcash",
  "customer_type": "regular",
  "store_type": "urban_high",
  "economic_class": "B"
}
```

**Response:**
```json
{
  "success": true,
  "transaction_id": "TXN-2024-001",
  "message": "Transaction ingested successfully",
  "enrichments": {
    "time_of_day": "morning",
    "computed_peso_value": 150.00,
    "region_normalized": "Metro Manila"
  }
}
```

**Error Response:**
```json
{
  "success": false,
  "error": "Validation failed",
  "details": {
    "field": "store_id",
    "message": "Store ID not found in dim_store"
  }
}
```

### **2. Batch Embeddings**
**POST** `/embed-batch`

Generate embeddings for multiple text inputs.

**Request Body:**
```json
{
  "texts": [
    "High-performing store in urban area",
    "Customer prefers premium products"
  ],
  "model": "text-embedding-3-small"
}
```

**Response:**
```json
{
  "embeddings": [
    [0.123, 0.456, ...], // 1536 dimensions
    [0.789, 0.012, ...]
  ],
  "model": "text-embedding-3-small",
  "usage": {
    "prompt_tokens": 20,
    "total_tokens": 20
  }
}
```

### **3. Genie Query (Natural Language)**
**POST** `/genie-query`

Convert natural language to SQL and execute.

**Request Body:**
```json
{
  "query": "Show me top 5 stores by revenue last month",
  "include_explanation": true
}
```

**Response:**
```json
{
  "sql": "SELECT store_id, SUM(peso_value) as revenue FROM scout.silver_transactions WHERE date_key >= '2024-01-01' GROUP BY store_id ORDER BY revenue DESC LIMIT 5",
  "results": [
    {"store_id": "S001", "revenue": 1500000},
    {"store_id": "S002", "revenue": 1200000}
  ],
  "explanation": "This query aggregates transaction values by store for the last month",
  "execution_time_ms": 45
}
```

### **4. Document Ingestion**
**POST** `/ingest-doc`

Process and store documents with vector embeddings.

**Request Body:**
```json
{
  "title": "Q4 2024 Sales Report",
  "content": "Sales performance exceeded expectations...",
  "metadata": {
    "type": "report",
    "department": "sales",
    "quarter": "Q4-2024"
  },
  "generate_embedding": true
}
```

**Response:**
```json
{
  "document_id": "doc_abc123",
  "chunks_created": 5,
  "embedding_dimensions": 1536,
  "status": "indexed"
}
```

---

## **Database REST API (PostgREST)**

### **Base URL**
```
https://cxzllzyxwpyptfretryc.supabase.co/rest/v1
```

### **1. Transactions**

#### **Get Transactions**
**GET** `/silver_transactions`

**Query Parameters:**
- `limit` - Number of records (default: 100)
- `offset` - Skip records for pagination
- `order` - Sort order (e.g., `ts.desc`)
- `store_id` - Filter by store (e.g., `eq.S001`)
- `date_key` - Filter by date (e.g., `gte.2024-01-01`)

**Example Request:**
```http
GET /rest/v1/silver_transactions?limit=10&order=ts.desc&store_id=eq.S001
```

**Response:**
```json
[
  {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "transaction_id": "TXN-2024-001",
    "store_id": "S001",
    "ts": "2024-01-15T10:30:00Z",
    "total_amount": 150.00,
    "basket_size": 5,
    "customer_type": "regular"
  }
]
```

#### **Insert Transaction**
**POST** `/silver_transactions`

**Request Body:**
```json
{
  "transaction_id": "TXN-2024-002",
  "store_id": "S001",
  "ts": "2024-01-15T11:00:00Z",
  "total_amount": 200.00,
  "basket_size": 3
}
```

### **2. Stores**

#### **Get All Stores**
**GET** `/dim_store`

**Response:**
```json
[
  {
    "store_id": "S001",
    "store_name": "Store Makati CBD",
    "store_type": "urban_high",
    "city": "Makati",
    "province": "Metro Manila",
    "region": "NCR",
    "latitude": 14.5547,
    "longitude": 121.0244
  }
]
```

#### **Get Store Performance**
**GET** `/rpc/get_store_performance`

**Request Body:**
```json
{
  "store_id": "S001",
  "start_date": "2024-01-01",
  "end_date": "2024-01-31"
}
```

### **3. Products**

#### **Get Product Catalog**
**GET** `/dim_product`

**Query Parameters:**
- `category=eq.beverages` - Filter by category
- `is_active=eq.true` - Active products only

### **4. Customers**

#### **Get Customer Segments**
**GET** `/rpc/get_customer_segments`

**Response:**
```json
[
  {
    "segment": "VIP",
    "customer_count": 1234,
    "avg_transaction_value": 500.00,
    "total_revenue": 616700.00
  }
]
```

---

## **Analytics Endpoints**

### **1. Executive Dashboard KPIs**
**GET** `/rpc/get_executive_kpis`

**Request Body:**
```json
{
  "period": "last_30_days"
}
```

**Response:**
```json
{
  "total_revenue": 15000000.00,
  "transaction_count": 45000,
  "unique_customers": 12000,
  "avg_basket_size": 333.33,
  "growth_rate": 15.5
}
```

### **2. Revenue Trend**
**GET** `/rpc/get_revenue_trend`

**Request Body:**
```json
{
  "granularity": "daily",
  "days": 30
}
```

**Response:**
```json
[
  {"date": "2024-01-01", "revenue": 500000},
  {"date": "2024-01-02", "revenue": 520000}
]
```

### **3. Geographic Performance**
**GET** `/rpc/get_choropleth_data`

**Request Body:**
```json
{
  "level": "region",
  "metric": "revenue",
  "period": "last_30_days"
}
```

**Response:**
```json
[
  {
    "region_key": "NCR",
    "region_name": "Metro Manila",
    "metric_value": 5000000,
    "transaction_count": 15000,
    "geom": {"type": "MultiPolygon", "coordinates": [...]}
  }
]
```

### **4. Product Velocity**
**GET** `/rpc/get_product_velocity`

**Request Body:**
```json
{
  "limit": 10,
  "category": "beverages"
}
```

---

## **Real-time Subscriptions**

### **WebSocket Connection**
```javascript
import { createClient } from '@supabase/supabase-js'

const supabase = createClient(url, key)

// Subscribe to new transactions
const subscription = supabase
  .channel('transactions')
  .on(
    'postgres_changes',
    {
      event: 'INSERT',
      schema: 'scout',
      table: 'silver_transactions'
    },
    (payload) => {
      console.log('New transaction:', payload.new)
    }
  )
  .subscribe()

// Subscribe to store updates
const storeChannel = supabase
  .channel('stores')
  .on(
    'postgres_changes',
    {
      event: '*',
      schema: 'scout',
      table: 'dim_store',
      filter: 'store_id=eq.S001'
    },
    (payload) => {
      console.log('Store updated:', payload)
    }
  )
  .subscribe()
```

---

## **Error Handling**

### **Standard Error Response**
```json
{
  "error": {
    "code": "23505",
    "message": "Duplicate key violation",
    "details": "Key (transaction_id)=(TXN-001) already exists",
    "hint": "Use a unique transaction_id"
  }
}
```

### **HTTP Status Codes**
- `200` - Success
- `201` - Created
- `400` - Bad Request (validation error)
- `401` - Unauthorized
- `403` - Forbidden (RLS policy violation)
- `404` - Not Found
- `409` - Conflict (duplicate)
- `500` - Internal Server Error

---

## **Rate Limits**

| Endpoint Type | Rate Limit | Window |
|--------------|------------|--------|
| Edge Functions | 1000/hour | Rolling |
| Database API | 10000/hour | Rolling |
| Realtime | 100 concurrent | - |
| File Storage | 100MB/request | - |

---

## **SDK Examples**

### **JavaScript/TypeScript**
```typescript
import { createClient } from '@supabase/supabase-js'

const supabase = createClient(
  'https://cxzllzyxwpyptfretryc.supabase.co',
  'your-anon-key'
)

// Insert transaction
const { data, error } = await supabase
  .from('silver_transactions')
  .insert({
    transaction_id: 'TXN-001',
    store_id: 'S001',
    total_amount: 150.00
  })

// Call RPC function
const { data: kpis } = await supabase
  .rpc('get_executive_kpis', {
    period: 'last_30_days'
  })

// Call Edge Function
const { data: result } = await supabase.functions
  .invoke('ingest-transaction', {
    body: { /* transaction data */ }
  })
```

### **Python**
```python
from supabase import create_client

supabase = create_client(
    "https://cxzllzyxwpyptfretryc.supabase.co",
    "your-anon-key"
)

# Get transactions
response = supabase.table('silver_transactions') \
    .select("*") \
    .eq('store_id', 'S001') \
    .execute()

# Call RPC
kpis = supabase.rpc('get_executive_kpis', {
    'period': 'last_30_days'
}).execute()
```

### **cURL**
```bash
# Get transactions
curl -X GET \
  'https://cxzllzyxwpyptfretryc.supabase.co/rest/v1/silver_transactions?limit=10' \
  -H 'apikey: your-anon-key' \
  -H 'Authorization: Bearer your-anon-key'

# Call Edge Function
curl -X POST \
  'https://cxzllzyxwpyptfretryc.supabase.co/functions/v1/ingest-transaction' \
  -H 'Authorization: Bearer your-anon-key' \
  -H 'Content-Type: application/json' \
  -d '{"store_id": "S001", "total_amount": 150}'
```

---

## **Testing Endpoints**

### **Bruno Collection**
Import the Bruno collection from `platform/scout/bruno/` for complete API testing:

```bash
bruno run platform/scout/bruno --env production
```

### **Health Check**
**GET** `/functions/v1/health`

```json
{
  "status": "healthy",
  "timestamp": "2024-01-15T10:00:00Z",
  "services": {
    "database": "connected",
    "storage": "connected",
    "realtime": "connected"
  }
}
```

---

## **Migration Guide**

### **From v1 to v2 API**
```javascript
// Old (v1)
const data = await fetch('/api/transactions')

// New (v2)
const { data } = await supabase
  .from('silver_transactions')
  .select('*')
```

---

## **Support**

- **Documentation**: https://docs.supabase.com
- **Status Page**: https://status.supabase.com
- **GitHub Issues**: https://github.com/jgtolentino/ai-aas-hardened-lakehouse/issues

This documentation covers the complete Scout Analytics Platform API. Save it as `API_DOCUMENTATION.md` in your project root! 📚