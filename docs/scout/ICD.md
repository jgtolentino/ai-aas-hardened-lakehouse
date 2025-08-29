# Interface Control Document (ICD)

**Version**: 1.4  
**Product**: Scout Dashboard  
**Last Updated**: 2025-01-26  
**Breaking Change Policy**: Major version bump required for breaking changes  

## API Contracts

### Executive Summary
```yaml
endpoint: /api/executive/summary
method: GET
version: 1.0.0
request:
  type: ExecutiveSummaryRequest
  schema:
    period:
      type: string
      enum: [today, week, month, quarter, year]
      required: true
response:
  type: ExecutiveSummaryResponse
  schema:
    revenue:
      type: number
      format: decimal(15,2)
    transactions:
      type: integer
      min: 0
    aov:
      type: number
      format: decimal(10,2)
    growth:
      type: number
      format: percentage
      min: -100
      max: null
    period:
      type: object
      properties:
        start: date-time
        end: date-time
errors:
  - code: 401
    type: Unauthorized
  - code: 404
    type: NotFound
  - code: 500
    type: InternalError
sla:
  p95: 200ms
  p99: 500ms
```

### Transaction Trends
```yaml
endpoint: /api/transactions/trends
method: POST
version: 1.2.0
request:
  type: TrendsRequest
  schema:
    granularity:
      type: string
      enum: [hour, day, week, month]
      required: true
    start_date:
      type: string
      format: date-time
      required: true
    end_date:
      type: string
      format: date-time
      required: true
    metrics:
      type: array
      items:
        type: string
        enum: [revenue, transactions, aov, items, customers]
      minItems: 1
      maxItems: 5
    filters:
      type: object
      properties:
        store_ids:
          type: array
          items: string
        product_categories:
          type: array
          items: string
        customer_segments:
          type: array
          items: string
response:
  type: TrendsResponse[]
  schema:
    - timestamp:
        type: string
        format: date-time
      metrics:
        type: object
        additionalProperties:
          type: number
      confidence:
        type: number
        min: 0
        max: 1
errors:
  - code: 400
    type: BadRequest
  - code: 401
    type: Unauthorized
  - code: 500
    type: InternalError
sla:
  p95: 500ms
  p99: 1000ms
```

### Product Mix
```yaml
endpoint: /api/products/mix
method: GET
version: 1.0.0
request:
  type: ProductMixRequest
  schema:
    store_id:
      type: string
      format: uuid
      required: false
    category:
      type: string
      required: false
    limit:
      type: integer
      min: 1
      max: 100
      default: 20
response:
  type: ProductMixResponse
  schema:
    products:
      type: array
      items:
        product_id: string
        product_name: string
        category: string
        units_sold: integer
        revenue: number
        rank: integer
        share: number
    metadata:
      total_products: integer
      total_revenue: number
      period: object
errors:
  - code: 401
    type: Unauthorized
  - code: 404
    type: NotFound
  - code: 500
    type: InternalError
sla:
  p95: 300ms
  p99: 600ms
```

### Geographic Regions
```yaml
endpoint: /api/geo/regions
method: GET
version: 1.3.0
request:
  type: GeoRegionRequest
  schema:
    level:
      type: integer
      enum: [1, 2, 3, 4]  # region, province, city, barangay
      required: true
    parent_id:
      type: string
      required: false
    bounds:
      type: object
      properties:
        north: number
        south: number
        east: number
        west: number
      required: false
response:
  type: GeoRegionResponse[]
  schema:
    - id: string
      name: string
      level: integer
      parent_id: string
      geometry:
        type: string
        enum: [Point, Polygon, MultiPolygon]
        coordinates: array
      metrics:
        stores: integer
        revenue: number
        transactions: integer
errors:
  - code: 401
    type: Unauthorized
  - code: 500
    type: InternalError
sla:
  p95: 400ms
  p99: 800ms
```

### AI Recommendations
```yaml
endpoint: /api/ai/recommendations
method: POST
version: 1.4.0
request:
  type: RecommendationRequest
  schema:
    context:
      type: string
      enum: [inventory, pricing, promotions, locations]
      required: true
    target:
      type: object
      properties:
        store_id: string
        product_id: string
        time_range: object
    parameters:
      type: object
      properties:
        confidence_threshold: number
        max_results: integer
        include_explanations: boolean
response:
  type: RecommendationResponse[]
  schema:
    - id: string
      type: string
      title: string
      description: string
      confidence: number
      impact:
        metric: string
        estimated_value: number
        timeframe: string
      actions:
        type: array
        items:
          action: string
          params: object
      explanation:
        type: string
        required: false
errors:
  - code: 401
    type: Unauthorized
  - code: 429
    type: RateLimited
  - code: 500
    type: InternalError
sla:
  p95: 1000ms
  p99: 2000ms
```

## Type Registry

### Shared Types
```typescript
// Money type - all monetary values
type Money = {
  amount: number;     // Decimal(15,2)
  currency: string;   // ISO 4217 code
};

// DateRange type - all period specifications
type DateRange = {
  start: ISO8601;
  end: ISO8601;
  timezone?: string;  // IANA timezone
};

// Percentage type - all percentage values
type Percentage = {
  value: number;      // -100 to +Infinity
  basis?: 'absolute' | 'relative';
};

// ISO8601 type - all timestamps
type ISO8601 = string; // Format: YYYY-MM-DDTHH:mm:ss.sssZ
```

## Version Compatibility Matrix

| Client Version | API Version | Status | Notes |
|---------------|-------------|--------|-------|
| 5.2.x | 1.4.x | ✅ Supported | Current |
| 5.1.x | 1.3.x | ✅ Supported | Security patches only |
| 5.0.x | 1.2.x | ⚠️ Deprecated | EOL 2025-03-01 |
| 4.x.x | 1.1.x | ❌ Unsupported | Migrate immediately |

## Breaking Change History

| Date | Old Version | New Version | Changes | Migration Guide |
|------|-------------|-------------|---------|-----------------|
| 2025-01-26 | 1.3.x | 1.4.0 | Added AI recommendations | No breaking changes |
| 2025-01-15 | 1.2.x | 1.3.0 | Geographic level 4 (barangay) | Update geo queries |
| 2025-01-01 | 1.1.x | 1.2.0 | Added confidence scores | Optional field, backward compatible |

## Contract Validation

### Automated Checks
```yaml
validation:
  request:
    - schema: OpenAPI 3.0
    - format: JSON Schema Draft 7
    - required_fields: enforced
    - type_checking: strict
  
  response:
    - schema: OpenAPI 3.0
    - format: JSON Schema Draft 7
    - backwards_compatible: true
    - deprecation_warnings: 90 days
  
  performance:
    - latency: measured per endpoint
    - size_limit: 1MB per response
    - rate_limit: 1000 req/min
```

### CI Integration
```bash
# Run in CI pipeline
npm run contracts:validate    # Check schema compatibility
npm run contracts:diff        # Show changes from main
npm run contracts:test        # Run contract tests
npm run contracts:generate    # Generate TypeScript types
```

## Change Management Process

1. **Propose Change**: Create PR with ICD update
2. **Review Impact**: Automated compatibility check
3. **Version Bump**: Follow semver rules
4. **Deprecation Notice**: 90-day warning for breaking changes
5. **Migration Guide**: Required for major versions
6. **Client Update**: Coordinated release with frontend/backend

---

**Validation Command**: `npm run icd:validate`  
**Type Generation**: `npm run icd:types`  
**Documentation**: `npm run icd:docs`
