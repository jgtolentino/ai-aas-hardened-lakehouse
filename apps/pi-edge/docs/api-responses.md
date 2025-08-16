# Scout Edge Ingest API Responses & Schemas

## API Endpoint
```
POST https://your-project.supabase.co/functions/v1/scout-edge-ingest
```

## Success Response

### HTTP Status: 200 OK

```json
{
  "ok": true
}
```

## Error Responses

### 1. Schema Validation Error (400 Bad Request)

```json
{
  "error": "schema",
  "details": [
    {
      "instancePath": "/items/0",
      "schemaPath": "#/properties/items/items/required",
      "keyword": "required",
      "params": {
        "missingProperty": "confidence"
      },
      "message": "must have required property 'confidence'"
    }
  ]
}
```

### 2. Unauthorized (401 Unauthorized)

```json
{
  "error": "Unauthorized"
}
```

### 3. Database Error (500 Internal Server Error)

```json
{
  "error": "duplicate key value violates unique constraint \"scout_gold_transactions_transaction_id_key\""
}
```

### 4. Method Not Allowed (405)

```json
{
  "error": "Method Not Allowed"
}
```

## Complete Request/Response Examples

### Example 1: Successful Transaction with Substitution

**Request:**
```json
{
  "transaction_id": "TXN-20250814-102-000456",
  "store": {
    "id": "STO00284",
    "tz_offset_min": 480
  },
  "geo": {
    "region_id": 13,
    "city_id": 1339,
    "barangay_id": 48291
  },
  "ts_utc": "2025-08-14T12:30:00Z",
  "tx_start_ts": "2025-08-14T12:29:50Z",
  "tx_end_ts": "2025-08-14T12:30:03Z",
  "request": {
    "request_type": "branded",
    "request_mode": "verbal",
    "payment_method": "cash",
    "gender": "male",
    "age_bracket": "25-34"
  },
  "items": [
    {
      "category_id": 21,
      "category_name": "Beverages",
      "brand_id": 2001,
      "brand_name": "Coca-Cola",
      "product_name": "Coke 1.5L",
      "qty": 2,
      "unit": "pc",
      "unit_price": 65.0,
      "total_price": 130.0,
      "detection_method": "hybrid",
      "confidence": 0.96
    },
    {
      "category_id": 7,
      "category_name": "Instant Noodles",
      "brand_id": 3101,
      "brand_name": "Lucky Me",
      "product_name": "Pancit Canton Original",
      "qty": 3,
      "unit": "pc",
      "unit_price": 10.0,
      "total_price": 30.0,
      "detection_method": "stt",
      "confidence": 0.93
    },
    {
      "category_id": 21,
      "category_name": "Ice",
      "brand_id": null,
      "brand_name": null,
      "product_name": "Ice",
      "local_name": "yelo",
      "qty": 3,
      "unit": "bag",
      "unit_price": 3.0,
      "total_price": 9.0,
      "detection_method": "stt",
      "confidence": 0.90
    }
  ],
  "suggestion": {
    "offered": true,
    "accepted": true
  },
  "substitution": {
    "asked_brand_id": 1201,
    "final_brand_id": 2001
  },
  "amounts": {
    "transaction_amount": 169.0,
    "price_source": "edge"
  },
  "decision_trace": {
    "vision": [
      {
        "box": [100, 120, 80, 40],
        "brand": "Coca-Cola",
        "s_logo": 0.89,
        "ocr_text": ["coke", "1.5l"],
        "ocr_score": 0.78
      }
    ],
    "stt": {
      "brand_hits": [
        {"token": "coke", "s_stt": 1.0},
        {"token": "pepsi", "s_stt": 1.0}
      ]
    },
    "fusion": {
      "alpha": 0.45,
      "beta": 0.35,
      "gamma": 0.20,
      "delta": 0.10,
      "T": 1.6,
      "raw": 0.872,
      "calibrated": 0.845
    }
  }
}
```

**Response:**
```json
{
  "ok": true
}
```

### Example 2: Minimal Valid Transaction

**Request:**
```json
{
  "transaction_id": "TXN-20250814-103-000789",
  "store": {
    "id": "STO00123",
    "tz_offset_min": 480
  },
  "geo": {},
  "ts_utc": "2025-08-14T13:45:00Z",
  "tx_start_ts": "2025-08-14T13:44:30Z",
  "tx_end_ts": "2025-08-14T13:45:00Z",
  "request": {
    "request_type": "unbranded",
    "request_mode": "pointing",
    "payment_method": "gcash"
  },
  "items": [
    {
      "category_name": "Snacks",
      "product_name": "Chips",
      "qty": 1,
      "detection_method": "vision",
      "confidence": 0.75
    }
  ]
}
```

**Response:**
```json
{
  "ok": true
}
```

### Example 3: Schema Validation Failure

**Request:**
```json
{
  "transaction_id": "TXN-20250814-104-000123",
  "store": {
    "id": "STO00456"
  },
  "items": []
}
```

**Response:**
```json
{
  "error": "schema",
  "details": [
    {
      "instancePath": "/store",
      "schemaPath": "#/properties/store/required",
      "keyword": "required",
      "params": {
        "missingProperty": "tz_offset_min"
      },
      "message": "must have required property 'tz_offset_min'"
    },
    {
      "instancePath": "",
      "schemaPath": "#/required",
      "keyword": "required",
      "params": {
        "missingProperty": "geo"
      },
      "message": "must have required property 'geo'"
    },
    {
      "instancePath": "/items",
      "schemaPath": "#/properties/items/minItems",
      "keyword": "minItems",
      "params": {
        "limit": 1
      },
      "message": "must NOT have fewer than 1 items"
    }
  ]
}
```

## Database Query Response Examples

### 1. Get Recent Transactions

```sql
SELECT * FROM scout_gold_transactions 
WHERE ts_utc > NOW() - INTERVAL '1 hour'
ORDER BY ts_utc DESC;
```

**Result:**
```json
[
  {
    "id": 1,
    "transaction_id": "TXN-20250814-102-000456",
    "store_id": "STO00284",
    "tz_offset_min": 480,
    "ts_utc": "2025-08-14T12:30:00Z",
    "tx_start_ts": "2025-08-14T12:29:50Z",
    "tx_end_ts": "2025-08-14T12:30:03Z",
    "request_type": "branded",
    "request_mode": "verbal",
    "payment_method": "cash",
    "gender": "male",
    "age_bracket": "25-34",
    "region_id": 13,
    "city_id": 1339,
    "barangay_id": 48291,
    "suggestion_offered": true,
    "suggestion_accepted": true,
    "asked_brand_id": 1201,
    "final_brand_id": 2001,
    "transaction_amount": 169.0,
    "price_source": "edge",
    "raw": {
      "transaction_id": "TXN-20250814-102-000456",
      "store": {"id": "STO00284", "tz_offset_min": 480},
      "geo": {"region_id": 13, "city_id": 1339, "barangay_id": 48291},
      "ts_utc": "2025-08-14T12:30:00Z",
      "tx_start_ts": "2025-08-14T12:29:50Z",
      "tx_end_ts": "2025-08-14T12:30:03Z",
      "request": {
        "request_type": "branded",
        "request_mode": "verbal",
        "payment_method": "cash",
        "gender": "male",
        "age_bracket": "25-34"
      },
      "items": [...]
    }
  }
]
```

### 2. Get Transaction Items

```sql
SELECT * FROM scout_gold_transaction_items 
WHERE transaction_id = 'TXN-20250814-102-000456';
```

**Result:**
```json
[
  {
    "id": 1,
    "transaction_id": "TXN-20250814-102-000456",
    "category_id": 21,
    "category_name": "Beverages",
    "brand_id": 2001,
    "brand_name": "Coca-Cola",
    "product_name": "Coke 1.5L",
    "local_name": null,
    "qty": 2,
    "unit": "pc",
    "unit_price": 65.0,
    "total_price": 130.0,
    "detection_method": "hybrid",
    "confidence": 0.96
  },
  {
    "id": 2,
    "transaction_id": "TXN-20250814-102-000456",
    "category_id": 7,
    "category_name": "Instant Noodles",
    "brand_id": 3101,
    "brand_name": "Lucky Me",
    "product_name": "Pancit Canton Original",
    "local_name": null,
    "qty": 3,
    "unit": "pc",
    "unit_price": 10.0,
    "total_price": 30.0,
    "detection_method": "stt",
    "confidence": 0.93
  },
  {
    "id": 3,
    "transaction_id": "TXN-20250814-102-000456",
    "category_id": 21,
    "category_name": "Ice",
    "brand_id": null,
    "brand_name": null,
    "product_name": "Ice",
    "local_name": "yelo",
    "qty": 3,
    "unit": "bag",
    "unit_price": 3.0,
    "total_price": 9.0,
    "detection_method": "stt",
    "confidence": 0.90
  }
]
```

### 3. Get Decision Trace (Debug)

```sql
SELECT * FROM edge_decision_trace 
WHERE transaction_id = 'TXN-20250814-102-000456';
```

**Result:**
```json
[
  {
    "id": 1,
    "transaction_id": "TXN-20250814-102-000456",
    "trace": {
      "vision": [
        {
          "box": [100, 120, 80, 40],
          "brand": "Coca-Cola",
          "s_logo": 0.89,
          "ocr_text": ["coke", "1.5l"],
          "ocr_score": 0.78
        }
      ],
      "stt": {
        "turns": [
          {"t": 0.0, "speaker": "cust", "text": "Ate, pabili Coke 1.5"},
          {"t": 2.3, "speaker": "owner", "text": "Ubos ang Coke, may Pepsi 1.5"}
        ],
        "brand_hits": [
          {"token": "coke", "s_stt": 1.0},
          {"token": "pepsi", "s_stt": 1.0}
        ]
      },
      "fusion": {
        "alpha": 0.45,
        "beta": 0.35,
        "gamma": 0.20,
        "delta": 0.10,
        "T": 1.6,
        "z": 1.92,
        "raw": 0.872,
        "calibrated": 0.845
      },
      "heuristics": [
        "suggestion_offered",
        "substitution_detected: coke→pepsi"
      ]
    },
    "created_at": "2025-08-14T12:30:01Z"
  }
]
```

## Enum Values Reference

### request_type
- `branded` - Customer asks for specific brand
- `unbranded` - Customer asks for category only
- `point` - Customer points at product
- `indirect` - Indirect request

### request_mode
- `verbal` - Spoken request
- `pointing` - Physical pointing
- `indirect` - Indirect indication

### payment_method
- `cash`
- `gcash`
- `maya`
- `credit`
- `other`

### gender
- `male`
- `female`
- `unknown`

### age_bracket
- `18-24`
- `25-34`
- `35-44`
- `45-54`
- `55+`
- `unknown`

### detection_method
- `stt` - Speech-to-text only
- `vision` - Computer vision only
- `ocr` - OCR text detection
- `hybrid` - Multiple methods combined

### price_source
- `edge` - Price from edge device
- `catalog` - Price from catalog lookup
- `pos` - Price from POS system
- `unknown` - Price source unknown