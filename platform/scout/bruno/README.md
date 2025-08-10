# Scout Bruno Test Collection

Complete API test suite for Scout sari-sari intelligence platform.

## Setup

1. **Install Bruno**: Download from [usebruno.com](https://www.usebruno.com/)

2. **Configure Environment**: Edit `environments.json` with your credentials:
   - `supabaseUrl`: Your Supabase project URL
   - `supabaseServiceRole`: Service role key (keep secure!)
   - `supabaseAnonKey`: Anonymous key for public operations
   - `supersetBase`: Superset URL (default: http://localhost:8088)
   - `supersetUser/Password`: Superset credentials
   - `dashboardUuid`: Your Scout dashboard UUID
   - `region`: Default region filter (e.g., "NCR")
   - `dateFrom/dateTo`: Date range for queries

3. **Select Environment**: Choose "development" or "production" in Bruno

## Test Sequence

### Core Flow (Required)
1. **18 Test Connection** - Verify Supabase connectivity
2. **09 Seed Dimensions** - Initialize dimension tables
3. **10 Transaction Ingest** - Submit a test transaction
4. **11 Verify Silver** - Check data in silver tables
5. **12 Query Gold Daily** - Query aggregated views

### Optional Tests
- **13 Refresh Gold** - Manually refresh materialized views
- **14 Genie Query** - Natural language to SQL (requires genie-query function)
- **15-17 Superset Flow** - Get guest token for dashboard embedding

## Running Tests

### Individual Test
1. Click on a test in Bruno
2. Click "Run" or press Ctrl+Enter

### Full Collection
1. Right-click on collection
2. Select "Run Collection"
3. Configure run settings
4. Review results

## Test Data

Each test includes realistic sample data:
- Multiple store locations (NCR, Cebu, Davao)
- Various product categories and SKUs
- Different transaction patterns
- Substitution events
- Demographic variations

## Troubleshooting

### Connection Issues
- Verify your Supabase URL and keys
- Check if PostgREST is exposing the `scout` schema
- Ensure Edge Functions are deployed

### Data Not Found
- Run tests in sequence (09 → 10 → 11 → 12)
- Check if migrations were applied
- Verify dimension data was seeded

### Superset Issues
- Ensure Superset is running locally
- Check CORS settings if embedding
- Verify dashboard UUID exists

## Security Notes

⚠️ **IMPORTANT**: 
- Never commit `environments.json` with real credentials
- Use service role key only in secure environments
- For production, use backend API with proper auth
- Enable RLS policies before production deployment

## Extending Tests

To add new tests:
1. Create new `.bru` file
2. Follow naming convention: `XX_test_name.bru`
3. Include proper assertions
4. Document expected preconditions
5. Add to this README

## Variables

Tests use these variables (set automatically):
- `{{timestamp}}`: Current timestamp
- `{{isoTimestamp}}`: ISO-8601 datetime
- `{{last_txn_id}}`: Last transaction ID
- `{{superset_access_token}}`: Superset auth token
- `{{superset_csrf_token}}`: CSRF token
- `{{superset_guest_token}}`: Guest embedding token