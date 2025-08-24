# Scout Layer Alignment Package

## Overview
This package enforces strict data layer access policies for Scout v5.2, ensuring all dashboards and APIs only access gold and platinum layers.

## Data Layer Policy
- **Bronze/Silver:** ❌ BLOCKED - No public access
- **Gold:** ✅ PUBLIC - Primary dashboard data (57 views)
- **Platinum:** ✅ PUBLIC - AI/ML insights (10 views)

## Quick Start
```bash
# Install dependencies
npm install

# Run compliance audit
npm run audit

# Apply RLS enforcement
npm run enforce

# Generate API routes
npm run generate-apis
```

## API Endpoints

### Gold Layer (57 endpoints)
```
/api/gold/analytics
/api/gold/customer-activity
/api/gold/product-performance
/api/gold/monthly-churn
/api/gold/persona-trajectory
... (52 more)
```

### Platinum Layer (10 endpoints)
```
/api/platinum/predictions
/api/platinum/basket-combos
/api/platinum/expert-insights
/api/platinum/persona-insights
/api/platinum/recommendations
... (5 more)
```

## DAL Usage
```typescript
import { gold, platinum } from '@scout/layer-alignment';

// Fetch gold layer data
const customers = await gold.customerActivity.fetch();
const performance = await gold.productPerformance.fetch();

// Fetch platinum layer insights
const predictions = await platinum.predictions.fetch();
const recommendations = await platinum.recommendations.fetch();
```

## Files
- `dal.ts` - Data Abstraction Layer functions
- `api-routes.ts` - API route templates
- `audit-layers.ts` - Compliance audit script
- `enforce-layer-access.sql` - RLS enforcement SQL

## Compliance Status
- ✅ 57 Gold views compliant
- ✅ 10 Platinum views compliant
- ❌ 0 Bronze/Silver exposed
- ✅ 100% API naming convention compliance

## Documentation
See `/SCOUT_V5_2_LAYER_ALIGNMENT_COMPLETE.md` for full implementation details.

## Version
v5.2.1 - Production Ready
