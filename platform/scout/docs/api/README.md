# Scout Platform API Documentation

**Last Updated**: 2025-09-03 18:13:41  
**Auto-generated**: Schema sync system

## 🚀 Quick Start

The Scout Platform provides RESTful APIs for accessing Philippine retail analytics data through our Medallion Architecture.

### Base URLs
- **Production**: `https://api.scout.insightpulseai.com`
- **Staging**: `https://staging-api.scout.insightpulseai.com`
- **Development**: `http://localhost:54321`

### Authentication
All API endpoints require authentication via Supabase JWT tokens:

```bash
curl -H "Authorization: Bearer YOUR_JWT_TOKEN" \
     -H "apikey: YOUR_SUPABASE_ANON_KEY" \
     https://api.scout.insightpulseai.com/rest/v1/scout_gold/kpi_daily_summary
```

## 📊 Available Endpoints

### Gold Layer APIs (Public)

#### 📈 KPIs & Metrics
- **GET** `/rest/v1/scout_gold/kpi_daily_summary` - Daily business KPIs
- **GET** `/rest/v1/scout_gold/product_performance` - Product analytics
- **GET** `/rest/v1/scout_gold/customer_segments` - Customer behavior analysis
- **GET** `/rest/v1/scout_gold/store_performance` - Store operational metrics

#### 🛍️ Market Insights
- **GET** `/rest/v1/scout_gold/market_basket_analysis` - Product associations
- **GET** `/rest/v1/scout_gold/category_trends` - Category performance trends

### Platinum Layer APIs (Public)

#### 🤖 ML Predictions
- **GET** `/rest/v1/scout_platinum/demand_forecast` - Inventory demand predictions
- **GET** `/rest/v1/scout_platinum/price_optimization` - Dynamic pricing recommendations
- **GET** `/rest/v1/scout_platinum/customer_lifetime_value` - CLV predictions
- **GET** `/rest/v1/scout_platinum/anomaly_detection` - Automated anomaly alerts

### Edge Functions

#### 🔧 Business Logic
- **POST** `/functions/v1/scout-analytics` - Custom analytics queries
- **POST** `/functions/v1/scout-reports` - Generate business reports
- **POST** `/functions/v1/scout-insights` - AI-powered insights

## 🔒 Security & Access Control

### Row Level Security (RLS)
All public APIs are protected by RLS policies:

```sql
-- Example: Users can only access their organization's data
CREATE POLICY "org_isolation_policy" ON scout_gold.kpi_daily_summary
  FOR ALL TO authenticated
  USING (auth.jwt() ->> 'organization_id' = organization_id);
```

### Rate Limiting
- **Authenticated Users**: 1000 requests/hour
- **Anonymous Access**: Not permitted
- **Service Accounts**: Custom limits based on agreement

## 📝 Request/Response Examples

### Get Daily KPIs
```bash
curl -H "Authorization: Bearer $JWT_TOKEN" \
     -H "apikey: $SUPABASE_ANON_KEY" \
     "https://api.scout.insightpulseai.com/rest/v1/scout_gold/kpi_daily_summary?date=gte.2024-01-01&order=date.desc&limit=30"
```

**Response:**
```json
[
  {
    "id": "123e4567-e89b-12d3-a456-426614174000",
    "date": "2024-01-15",
    "store_id": "store-456",
    "total_revenue": 125000.50,
    "total_transactions": 450,
    "unique_customers": 320,
    "average_transaction_value": 277.78,
    "items_sold": 1250,
    "gross_margin": 45000.20
  }
]
```

### Get Product Performance
```bash
curl -H "Authorization: Bearer $JWT_TOKEN" \
     -H "apikey: $SUPABASE_ANON_KEY" \
     "https://api.scout.insightpulseai.com/rest/v1/scout_gold/product_performance?time_period=eq.MONTHLY&order=velocity_rank.asc&limit=50"
```

## 🌏 Philippine Market Features

### Geographic Filtering
Use PSGC codes for location-based queries:

```bash
# Get store performance for NCR region
curl "...scout_gold/store_performance?region=eq.NCR"

# Get KPIs for specific province
curl "...scout_gold/kpi_daily_summary?province=eq.Metro%20Manila"
```

### Multi-language Support
Include language preference in headers:

```bash
curl -H "Accept-Language: fil" ... # Filipino
curl -H "Accept-Language: ceb" ... # Cebuano
```

## 📚 Additional Resources

- **OpenAPI Spec**: `/docs/api/openapi.yaml` *(coming soon)*
- **Postman Collection**: `/docs/api/scout-platform.postman_collection.json` *(coming soon)*
- **GraphQL Schema**: `/graphql` *(coming soon)*
- **Database ERD**: `/docs/database/erd/README.md`

## 🆘 Support & Troubleshooting

### Common Issues
1. **401 Unauthorized**: Check JWT token validity and Supabase apikey
2. **403 Forbidden**: RLS policy restriction - verify organization access
3. **429 Too Many Requests**: Rate limit exceeded - implement exponential backoff

### Contact
- **Technical Support**: tech-support@insightpulseai.com
- **API Documentation**: api-docs@insightpulseai.com
- **Bug Reports**: Create issue in project repository

---

*This documentation is automatically maintained. Last schema sync: 2025-09-03 18:13:41*
