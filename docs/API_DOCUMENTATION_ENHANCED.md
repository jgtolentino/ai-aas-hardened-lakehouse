# 📡 Scout v5.2 API Documentation (Production-Ready)

**Complete REST API guide for Scout v5.2 with PostgREST, authentication, filtering, pagination, and error handling.**

## 🚀 Quick Start

### Base URL
```
https://cxzllzyxwpyptfretryc.supabase.co/rest/v1/
```

### Authentication Headers
```bash
# For all requests
curl -H "apikey: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..." \
     -H "Authorization: Bearer <user_jwt_token>" \
     -H "Content-Type: application/json"
```

**⚠️ Important**: Always include both `apikey` (anon key) and `Authorization` (user JWT) headers.

---

## 🔐 Authentication & Schema Headers

### Schema Headers Overview

PostgREST uses different headers for **reading** vs **writing** operations:

| Operation | Header | Purpose | Example |
|-----------|--------|---------|---------|
| **Read** (SELECT) | `Accept-Profile: scout` | Specify schema for reading data | `GET /dim_product` |
| **Write** (INSERT/UPDATE/DELETE) | `Content-Profile: scout` | Specify schema for writing data | `POST /fct_transactions` |

### Complete Header Examples

**Reading data (GET requests):**
```bash
curl -H "apikey: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..." \
     -H "Authorization: Bearer <user_jwt_token>" \
     -H "Accept-Profile: scout" \
     -H "Accept: application/json" \
     "https://cxzllzyxwpyptfretryc.supabase.co/rest/v1/dim_product"
```

**Writing data (POST/PATCH/DELETE requests):**
```bash
curl -H "apikey: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..." \
     -H "Authorization: Bearer <user_jwt_token>" \
     -H "Content-Profile: scout" \
     -H "Content-Type: application/json" \
     -X POST \
     -d '{"product_name": "New Product"}' \
     "https://cxzllzyxwpyptfretryc.supabase.co/rest/v1/dim_product"
```

### Authentication Flow

1. **Get user JWT token** from Supabase Auth
2. **Include both headers**: `apikey` (public) + `Authorization` (user-specific)
3. **Use schema headers**: `Accept-Profile` for reads, `Content-Profile` for writes

---

## 📊 Pagination & Count

### Range-Based Pagination

PostgREST uses **Range headers** for pagination (similar to HTTP byte ranges):

```bash
# Get items 0-9 (first 10 items)
curl -H "Range: 0-9" \
     -H "Accept-Profile: scout" \
     "https://cxzllzyxwpyptfretryc.supabase.co/rest/v1/fct_transactions"

# Get items 10-19 (next 10 items)
curl -H "Range: 10-19" \
     -H "Accept-Profile: scout" \
     "https://cxzllzyxwpyptfretryc.supabase.co/rest/v1/fct_transactions"
```

### Getting Total Count

**Option 1: Count with data (default)**
```bash
curl -H "Range: 0-9" \
     -H "Prefer: count=exact" \
     -H "Accept-Profile: scout" \
     "https://cxzllzyxwpyptfretryc.supabase.co/rest/v1/fct_transactions"

# Response headers include:
# Content-Range: 0-9/1543  (showing items 0-9 of 1543 total)
```

**Option 2: Count only (no data)**
```bash
curl -H "Range: 0-0" \
     -H "Prefer: count=exact" \
     -H "Accept-Profile: scout" \
     "https://cxzllzyxwpyptfretryc.supabase.co/rest/v1/fct_transactions?select=count"
```

**Option 3: Estimate count (faster)**
```bash
curl -H "Prefer: count=estimated" \
     -H "Accept-Profile: scout" \
     "https://cxzllzyxwpyptfretryc.supabase.co/rest/v1/fct_transactions?limit=1"
```

### Pagination Response Format

```http
HTTP/1.1 200 OK
Content-Range: 0-9/1543
Content-Type: application/json

[
  {"transaction_id": "...", "amount": 150.00},
  // ... 9 more items
]
```

**JavaScript Pagination Example:**
```javascript
async function getPaginatedData(page = 0, pageSize = 10) {
  const start = page * pageSize;
  const end = start + pageSize - 1;
  
  const response = await fetch(`${baseURL}/fct_transactions`, {
    headers: {
      'apikey': ANON_KEY,
      'Authorization': `Bearer ${userToken}`,
      'Accept-Profile': 'scout',
      'Range': `${start}-${end}`,
      'Prefer': 'count=exact'
    }
  });
  
  const data = await response.json();
  const contentRange = response.headers.get('Content-Range');
  const totalCount = parseInt(contentRange.split('/')[1]);
  
  return {
    data,
    totalCount,
    currentPage: page,
    hasNextPage: (start + pageSize) < totalCount
  };
}
```

---

## 🔍 Filtering Cheatsheet

### Basic Operators

| Operator | SQL Equivalent | Example | Description |
|----------|----------------|---------|-------------|
| `eq` | `=` | `?amount=eq.100` | Equals |
| `neq` | `!=` | `?amount=neq.100` | Not equals |
| `gt` | `>` | `?amount=gt.100` | Greater than |
| `gte` | `>=` | `?amount=gte.100` | Greater than or equal |
| `lt` | `<` | `?amount=lt.100` | Less than |
| `lte` | `<=` | `?amount=lte.100` | Less than or equal |

### String Operators

| Operator | Description | Example | SQL Equivalent |
|----------|-------------|---------|----------------|
| `like` | Pattern matching (case-sensitive) | `?product_name=like.*Coca*` | `LIKE '%Coca%'` |
| `ilike` | Pattern matching (case-insensitive) | `?product_name=ilike.*coca*` | `ILIKE '%coca%'` |
| `match` | Regular expression | `?product_name=match.^[A-Z].*` | `~ '^[A-Z].*'` |
| `imatch` | Regex (case-insensitive) | `?product_name=imatch.^coca` | `~* '^coca'` |

### Array & JSON Operators

| Operator | Description | Example |
|----------|-------------|---------|
| `in` | Value in list | `?category_id=in.(cat1,cat2,cat3)` |
| `cs` | Contains (array/json) | `?tags=cs.{premium,organic}` |
| `cd` | Contained by | `?tags=cd.{premium,organic,local}` |
| `ov` | Overlaps | `?categories=ov.{food,beverage}` |

### Date/Time Filtering

```bash
# Today's transactions
?transaction_date=gte.2025-08-24&transaction_date=lt.2025-08-25

# This week (using functions)
?transaction_date=gte.2025-08-18&transaction_date=lt.2025-08-25

# Last 30 days
?created_at=gte.2025-07-25T00:00:00Z
```

### Complex Filtering Examples

**Multiple conditions (AND):**
```bash
?category_id=eq.cat001&amount=gte.50&store_id=eq.store123
```

**OR conditions:**
```bash
?or=(category_id.eq.cat001,category_id.eq.cat002)&amount=gte.50
```

**Nested conditions:**
```bash
?and=(category_id.in.(cat001,cat002),or(amount.gte.100,priority.eq.high))
```

**Filtering with joins:**
```bash
# Get transactions with product details where product name contains "Coke"
/fct_transactions?select=*,dim_product(product_name,category_id)&dim_product.product_name=ilike.*Coke*
```

---

## 🔄 RPC (Remote Procedure Calls)

### Uniform RPC Naming Convention

All Scout v5.2 RPC functions follow the pattern: `fn_<domain>_<action>`

#### Analytics Functions
```bash
# Business intelligence insights
POST /rpc/fn_analytics_get_kpis
POST /rpc/fn_analytics_trend_analysis
POST /rpc/fn_analytics_competitor_insights
POST /rpc/fn_analytics_customer_segments
```

#### Health Intelligence Functions
```bash
# Product health and category analysis
POST /rpc/fn_health_product_score
POST /rpc/fn_health_category_trends
POST /rpc/fn_health_seasonal_patterns
POST /rpc/fn_health_recommendation_engine
```

#### Scout Functions
```bash
# Core Scout functionality
POST /rpc/fn_scout_process_transaction
POST /rpc/fn_scout_inventory_alert
POST /rpc/fn_scout_price_optimization
POST /rpc/fn_scout_demand_forecast
```

### RPC Request Examples

**Get KPI Dashboard:**
```bash
curl -X POST \
     -H "apikey: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..." \
     -H "Authorization: Bearer <user_jwt_token>" \
     -H "Content-Profile: scout" \
     -H "Content-Type: application/json" \
     -d '{
       "store_id": "store123",
       "date_from": "2025-08-01",
       "date_to": "2025-08-24",
       "metrics": ["revenue", "transactions", "customer_count"]
     }' \
     "https://cxzllzyxwpyptfretryc.supabase.co/rest/v1/rpc/fn_analytics_get_kpis"
```

**Health Score Analysis:**
```bash
curl -X POST \
     -H "apikey: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..." \
     -H "Authorization: Bearer <user_jwt_token>" \
     -H "Content-Profile: scout" \
     -H "Content-Type: application/json" \
     -d '{
       "product_id": "prod456",
       "analysis_type": "comprehensive",
       "include_predictions": true
     }' \
     "https://cxzllzyxwpyptfretryc.supabase.co/rest/v1/rpc/fn_health_product_score"
```

---

## ✏️ Write Operations

### INSERT Examples with Content-Profile

**Single record insert:**
```bash
curl -X POST \
     -H "apikey: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..." \
     -H "Authorization: Bearer <user_jwt_token>" \
     -H "Content-Profile: scout" \
     -H "Content-Type: application/json" \
     -H "Prefer: return=representation" \
     -d '{
       "product_name": "Coca-Cola 1.5L",
       "category_id": "cat001",
       "price": 65.00,
       "brand_id": "brand123"
     }' \
     "https://cxzllzyxwpyptfretryc.supabase.co/rest/v1/dim_product"
```

**Bulk insert:**
```bash
curl -X POST \
     -H "Content-Profile: scout" \
     -H "Content-Type: application/json" \
     -H "Prefer: return=representation" \
     -d '[
       {
         "transaction_id": "txn001",
         "amount": 150.00,
         "store_id": "store123",
         "product_id": "prod456"
       },
       {
         "transaction_id": "txn002", 
         "amount": 85.50,
         "store_id": "store123",
         "product_id": "prod789"
       }
     ]' \
     "https://cxzllzyxwpyptfretryc.supabase.co/rest/v1/fct_transactions"
```

### UPSERT Examples (INSERT + UPDATE)

**UPSERT with conflict resolution:**
```bash
curl -X POST \
     -H "Content-Profile: scout" \
     -H "Content-Type: application/json" \
     -H "Prefer: resolution=merge-duplicates,return=representation" \
     -d '{
       "product_id": "prod456",
       "product_name": "Updated Product Name",
       "price": 75.00,
       "last_updated": "2025-08-24T10:00:00Z"
     }' \
     "https://cxzllzyxwpyptfretryc.supabase.co/rest/v1/dim_product"
```

**UPSERT with ON CONFLICT specification:**
```bash
curl -X POST \
     -H "Content-Profile: scout" \
     -H "Content-Type: application/json" \
     -H "Prefer: resolution=merge-duplicates,return=representation" \
     -H "On-Conflict: product_id" \
     -d '[
       {
         "product_id": "prod123",
         "product_name": "Pepsi 1.5L",
         "price": 62.00
       },
       {
         "product_id": "prod124", 
         "product_name": "Sprite 1.5L",
         "price": 58.00
       }
     ]' \
     "https://cxzllzyxwpyptfretryc.supabase.co/rest/v1/dim_product"
```

### UPDATE Examples

**Single record update:**
```bash
curl -X PATCH \
     -H "Content-Profile: scout" \
     -H "Content-Type: application/json" \
     -H "Prefer: return=representation" \
     -d '{
       "price": 70.00,
       "last_updated": "2025-08-24T10:00:00Z"
     }' \
     "https://cxzllzyxwpyptfretryc.supabase.co/rest/v1/dim_product?product_id=eq.prod456"
```

**Bulk update with conditions:**
```bash
curl -X PATCH \
     -H "Content-Profile: scout" \
     -H "Content-Type: application/json" \
     -d '{
       "status": "inactive",
       "deactivated_at": "2025-08-24T10:00:00Z"
     }' \
     "https://cxzllzyxwpyptfretryc.supabase.co/rest/v1/dim_product?category_id=eq.cat999&status=eq.active"
```

---

## 🔄 Realtime Subscriptions

### Prerequisites

1. **Enable Realtime** on tables in Supabase dashboard
2. **Configure RLS policies** to allow realtime access
3. **Install Supabase JS client** for frontend applications

### JavaScript Subscription Examples

```javascript
import { createClient } from '@supabase/supabase-js'

const supabase = createClient(
  'https://cxzllzyxwpyptfretryc.supabase.co',
  'your-anon-key'
)

// Subscribe to new transactions
const subscription = supabase
  .channel('transactions_channel')
  .on(
    'postgres_changes',
    {
      event: 'INSERT',
      schema: 'scout',
      table: 'fct_transactions',
      filter: 'store_id=eq.store123'
    },
    (payload) => {
      console.log('New transaction:', payload.new)
      // Update UI with new transaction
    }
  )
  .on(
    'postgres_changes', 
    {
      event: 'UPDATE',
      schema: 'scout',
      table: 'dim_product',
      filter: 'category_id=eq.cat001'
    },
    (payload) => {
      console.log('Product updated:', payload.new)
      // Update product display
    }
  )
  .subscribe()

// Clean up subscription
const unsubscribe = () => {
  subscription.unsubscribe()
}
```

### Realtime with Row Level Security

```javascript
// Authenticated realtime subscription
const authenticatedSubscription = supabase
  .channel('user_specific_data')
  .on(
    'postgres_changes',
    {
      event: '*', // All events
      schema: 'scout',
      table: 'fct_transactions',
      // RLS will automatically filter based on user's access
    },
    (payload) => {
      console.log('Change detected:', payload)
    }
  )
  .subscribe()
```

---

## ❌ Error Handling & Troubleshooting

### Common HTTP Status Codes

| Status | Description | Common Causes |
|--------|-------------|---------------|
| `200` | Success | Request completed successfully |
| `201` | Created | Resource created successfully |
| `400` | Bad Request | Invalid JSON, missing required fields |
| `401` | Unauthorized | Missing or invalid `Authorization` header |
| `403` | Forbidden | RLS policy blocks access |
| `404` | Not Found | Table/endpoint doesn't exist |
| `406` | Not Acceptable | Missing schema headers |
| `409` | Conflict | Unique constraint violation |
| `422` | Unprocessable | Data validation errors |
| `500` | Internal Error | Database error, function exception |

### Detailed Error Response Format

```json
{
  "code": "PGRST301",
  "details": "The result contains 0 rows",
  "hint": "Check your filters and ensure the data exists",
  "message": "JSON object requested, multiple (or no) rows returned"
}
```

### Common Error Scenarios & Solutions

#### 1. "Schema Not Found" (406 Error)
**Error:**
```json
{
  "code": "PGRST106",
  "message": "The schema must be one of the following: public"
}
```
**Solution:** Add schema headers
```bash
# Add this header to your request
-H "Accept-Profile: scout"  # for GET requests
-H "Content-Profile: scout" # for POST/PATCH requests
```

#### 2. "Authorization Required" (401 Error)
**Error:**
```json
{
  "message": "JWT expired"
}
```
**Solution:** Refresh JWT token and include both headers
```javascript
const { data: { session } } = await supabase.auth.getSession()
if (session) {
  headers['Authorization'] = `Bearer ${session.access_token}`
}
```

#### 3. "Row Level Security" (403 Error)  
**Error:**
```json
{
  "code": "42501",
  "message": "permission denied for table fct_transactions"
}
```
**Solution:** Check RLS policies and user permissions
```sql
-- Check if user has access to store data
SELECT * FROM scout.user_store_access WHERE user_id = auth.uid();
```

#### 4. "Unique Constraint Violation" (409 Error)
**Error:**
```json
{
  "code": "23505",
  "message": "duplicate key value violates unique constraint"
}
```
**Solution:** Use UPSERT or check existing records
```bash
# Use UPSERT instead of INSERT
-H "Prefer: resolution=merge-duplicates"
```

#### 5. "Invalid Range Header" (400 Error)
**Error:**
```json
{
  "message": "HTTP Range error"
}
```
**Solution:** Fix range syntax
```bash
# Correct format
-H "Range: 0-9"  # First 10 items

# Incorrect format  
-H "Range: 0,9"  # Don't use commas
```

### Debugging Checklist

**Before making requests:**
- ✅ Include `apikey` header (anon key)
- ✅ Include `Authorization` header (user JWT)
- ✅ Use correct schema headers (`Accept-Profile`/`Content-Profile`)
- ✅ Validate JSON syntax
- ✅ Check table/column names match database

**For pagination:**
- ✅ Use `Range: start-end` format
- ✅ Add `Prefer: count=exact` for total count
- ✅ Handle `Content-Range` response header

**For filtering:**
- ✅ Use correct operators (`eq`, `gte`, `ilike`, etc.)
- ✅ Encode URL parameters properly
- ✅ Test filters with simple cases first

**For realtime:**
- ✅ Enable Realtime on tables in dashboard
- ✅ Configure RLS policies for realtime access
- ✅ Subscribe to specific schema and table

### Error Logging Example

```javascript
async function apiRequest(endpoint, options = {}) {
  try {
    const response = await fetch(`${baseURL}/${endpoint}`, {
      headers: {
        'apikey': ANON_KEY,
        'Authorization': `Bearer ${userToken}`,
        'Accept-Profile': 'scout',
        'Content-Type': 'application/json',
        ...options.headers
      },
      ...options
    });

    if (!response.ok) {
      const error = await response.json();
      console.error('API Error:', {
        status: response.status,
        statusText: response.statusText,
        endpoint,
        error,
        headers: Object.fromEntries(response.headers.entries())
      });
      throw new Error(`API Error ${response.status}: ${error.message}`);
    }

    return await response.json();
  } catch (err) {
    console.error('Request failed:', err);
    throw err;
  }
}
```

---

## 🎯 Production-Ready Examples

### Complete Transaction Processing

```javascript
async function processTransaction(transactionData) {
  try {
    // 1. Validate inventory
    const { data: product } = await supabase
      .from('dim_product')
      .select('stock_quantity, price')
      .eq('product_id', transactionData.product_id)
      .single();

    if (product.stock_quantity < transactionData.quantity) {
      throw new Error('Insufficient stock');
    }

    // 2. Create transaction
    const { data: transaction } = await supabase
      .from('fct_transactions') 
      .insert({
        transaction_id: generateTransactionId(),
        store_id: transactionData.store_id,
        product_id: transactionData.product_id,
        quantity: transactionData.quantity,
        unit_price: product.price,
        total_amount: product.price * transactionData.quantity,
        transaction_date: new Date().toISOString()
      })
      .select()
      .single();

    // 3. Update inventory
    await supabase
      .from('dim_product')
      .update({ 
        stock_quantity: product.stock_quantity - transactionData.quantity,
        last_updated: new Date().toISOString()
      })
      .eq('product_id', transactionData.product_id);

    // 4. Log to analytics
    await supabase.rpc('fn_analytics_log_transaction', {
      transaction_id: transaction.transaction_id,
      store_id: transactionData.store_id
    });

    return transaction;
  } catch (error) {
    console.error('Transaction failed:', error);
    throw error;
  }
}
```

### Real-time Inventory Dashboard

```javascript
class InventoryDashboard {
  constructor() {
    this.subscriptions = [];
    this.setupRealtimeSubscriptions();
  }

  setupRealtimeSubscriptions() {
    // Low stock alerts
    const lowStockSub = supabase
      .channel('low_stock_alerts')
      .on(
        'postgres_changes',
        {
          event: 'UPDATE',
          schema: 'scout', 
          table: 'dim_product',
          filter: 'stock_quantity=lt.10'
        },
        this.handleLowStock.bind(this)
      )
      .subscribe();

    // New transactions
    const transactionSub = supabase
      .channel('new_transactions')
      .on(
        'postgres_changes',
        {
          event: 'INSERT',
          schema: 'scout',
          table: 'fct_transactions'
        },
        this.handleNewTransaction.bind(this)
      )
      .subscribe();

    this.subscriptions.push(lowStockSub, transactionSub);
  }

  handleLowStock(payload) {
    const product = payload.new;
    this.showNotification(`Low stock alert: ${product.product_name} (${product.stock_quantity} remaining)`);
    this.updateProductDisplay(product);
  }

  handleNewTransaction(payload) {
    const transaction = payload.new;
    this.updateSalesCounter(transaction.total_amount);
    this.refreshTopProducts();
  }

  cleanup() {
    this.subscriptions.forEach(sub => sub.unsubscribe());
  }
}
```

---

## 📋 Quick Reference

### Essential Headers
```bash
# Always required
apikey: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
Authorization: Bearer <user_jwt_token>

# For reads
Accept-Profile: scout

# For writes  
Content-Profile: scout
Content-Type: application/json

# For pagination
Range: 0-9
Prefer: count=exact

# For upserts
Prefer: resolution=merge-duplicates,return=representation
```

### URL Patterns
```bash
# Basic queries
GET  /dim_product
POST /dim_product
PATCH /dim_product?product_id=eq.123

# With filters
GET /fct_transactions?store_id=eq.store123&amount=gte.100

# With select/joins
GET /fct_transactions?select=*,dim_product(product_name)

# RPC calls
POST /rpc/fn_analytics_get_kpis
```

### Filter Operators
```bash
eq neq gt gte lt lte        # Comparison
like ilike match imatch     # Text matching  
in cs cd ov                 # Array/JSON
is isnot                    # NULL checks
and or not                  # Logic operators
```

---

**🎉 You're now ready to build production-grade applications with Scout v5.2 API!**

For additional support:
- 📊 **Dashboard**: https://app.supabase.com/project/cxzllzyxwpyptfretryc
- 📖 **PostgREST Docs**: https://postgrest.org/en/stable/
- 🔄 **Realtime Guide**: https://supabase.com/docs/guides/realtime