---
title: Regional Performance Analysis
sidebar_label: Regional Performance
sidebar_position: 1
---

# Regional Performance Analysis Playbook

This playbook walks through analyzing sales performance from national level down to individual barangays, helping you identify growth opportunities and underperforming areas.

## 🎯 Use Case

**Scenario**: You're a Regional Manager for an FMCG company and need to:
- Identify top and bottom performing regions
- Drill down to find specific problem areas
- Compare brand performance across geographies
- Plan field team deployment

## 📊 Step 1: National Overview

Start with the high-level national view to understand overall performance.

### Using the Dashboard

Navigate to **Regional Dashboard** → **National View**

### Using the DAL

```typescript
import { makeGoldDal } from '@/lib/gold-dal';

// Get national performance summary
const nationalData = await dal.geoSales({
  date_from: '2025-01-01',
  date_to: '2025-01-31',
  geo_level: 'region'
});

// Process for visualization
const regionSummary = nationalData.map(region => ({
  name: region.geo_name,
  revenue: region.total_revenue,
  growth: region.growth_vs_ly,
  stores: region.active_stores
}));
```

### Key Metrics to Review

| Metric | What to Look For | Action Trigger |
|--------|------------------|----------------|
| **Total Revenue** | Month-over-month trend | >5% decline = investigate |
| **Active Stores** | New vs churned stores | Net negative = urgent |
| **Average Basket** | Revenue per transaction | Declining = pricing issue |
| **Coverage** | % of barangays served | <70% = expansion opportunity |

### Visualization

Use a **choropleth map** for immediate visual impact:

```jsx
import { PhilippinesMap } from '@/components/maps';

<PhilippinesMap
  data={regionSummary}
  metric="revenue"
  colorScale={['#fee', '#f88', '#c00']}
  onRegionClick={handleDrillDown}
/>
```

---

## 🔍 Step 2: Regional Deep Dive

Once you identify regions of interest, drill down for details.

### Identifying Problem Regions

```typescript
// Find underperforming regions
const underperformers = nationalData.filter(region => 
  region.growth_vs_ly < 0 || 
  region.revenue < region.target * 0.9
);

// Get detailed metrics for problem region
const regionDetails = await dal.geoPerformanceDetails({
  region_id: underperformers[0].geo_id,
  date_from: '2025-01-01',
  date_to: '2025-01-31',
  include_cities: true
});
```

### Regional Analysis Matrix

Create a 2x2 matrix to categorize regions:

```
High Growth ↑
     │
  🌟 │ 🚀
Stars│Rising
─────┼─────
  💰 │ ⚠️ 
Cash │Risk
Cows │Zones
     │
     └────→ High Revenue
```

**Classification Logic:**

```typescript
function classifyRegion(region) {
  const medianRevenue = getMedian(allRegions, 'revenue');
  const medianGrowth = getMedian(allRegions, 'growth');
  
  if (region.revenue > medianRevenue) {
    return region.growth > medianGrowth ? 'STAR' : 'CASH_COW';
  } else {
    return region.growth > medianGrowth ? 'RISING' : 'RISK';
  }
}
```

### City-Level Analysis

For each underperforming region, examine city performance:

```typescript
// Get city-level breakdown
const cityPerformance = await dal.geoCityMetrics({
  region_id: selectedRegion,
  date_from: '2025-01-01',
  date_to: '2025-01-31',
  sort_by: 'revenue_desc'
});

// Identify concentration risk
const top3Cities = cityPerformance.slice(0, 3);
const concentrationRatio = 
  top3Cities.reduce((sum, city) => sum + city.revenue, 0) / 
  cityPerformance.reduce((sum, city) => sum + city.revenue, 0);

if (concentrationRatio > 0.7) {
  console.warn('High concentration risk - diversify distribution');
}
```

---

## 🏘️ Step 3: Barangay Drill-Down

Get granular insights at the barangay level.

### Barangay Heatmap

```typescript
// Fetch barangay-level data
const barangayData = await dal.geoBarangayMetrics({
  city_id: selectedCity,
  date_from: '2025-01-01',
  date_to: '2025-01-31'
});

// Create heatmap data
const heatmapData = barangayData.map(b => ({
  lat: b.latitude,
  lng: b.longitude,
  intensity: b.revenue / maxRevenue,
  tooltip: `${b.barangay_name}: ₱${b.revenue.toLocaleString()}`
}));
```

### Coverage Analysis

Identify unserved or underserved barangays:

```sql
-- Find barangays with no sales
SELECT 
  b.barangay_name,
  b.population,
  b.household_count,
  COALESCE(s.store_count, 0) as stores,
  COALESCE(g.revenue, 0) as revenue
FROM master_barangays b
LEFT JOIN (
  SELECT barangay_id, COUNT(*) as store_count 
  FROM dim_stores 
  WHERE is_active = true
  GROUP BY barangay_id
) s ON b.barangay_id = s.barangay_id
LEFT JOIN gold_geo_sales g ON b.barangay_id = g.barangay_id
WHERE b.city_id = :city_id
  AND COALESCE(g.revenue, 0) < 1000
ORDER BY b.population DESC;
```

### Opportunity Sizing

Calculate potential for underserved areas:

```typescript
function calculateOpportunity(barangay) {
  const avgRevenuePerHousehold = regionalAverage / regionHouseholds;
  const currentPenetration = barangay.revenue / 
    (barangay.households * avgRevenuePerHousehold);
  const targetPenetration = 0.7; // 70% target
  
  return {
    currentRevenue: barangay.revenue,
    potentialRevenue: barangay.households * 
      avgRevenuePerHousehold * targetPenetration,
    gap: (targetPenetration - currentPenetration) * 
      barangay.households * avgRevenuePerHousehold,
    priorityScore: (barangay.population * 
      (targetPenetration - currentPenetration)) / 1000
  };
}
```

---

## 📈 Step 4: Competitive Analysis by Region

Compare brand performance across different geographies.

### Brand Share by Region

```typescript
// Compare brand performance across regions
const brandComparison = await dal.brandShareByRegion({
  date_from: '2025-01-01',
  date_to: '2025-01-31',
  brand_ids: [myBrand, competitor1, competitor2],
  category_id: targetCategory
});

// Create regional battleground map
const battlegrounds = brandComparison.map(region => ({
  region_id: region.region_id,
  region_name: region.region_name,
  leader: region.brands[0].brand_name,
  our_share: region.brands.find(b => b.brand_id === myBrand).share,
  gap_to_leader: region.brands[0].share - our_share,
  classification: classifyBattleground(region)
}));
```

### Regional Strategy Matrix

```typescript
function classifyBattleground(region) {
  const ourShare = region.our_share;
  const marketSize = region.total_revenue;
  
  if (ourShare > 40) return 'DEFEND';      // We're winning
  if (ourShare > 25 && marketSize > medianSize) return 'INVEST';  // Worth fighting
  if (ourShare < 15 && marketSize < medianSize) return 'HARVEST'; // Not priority
  return 'ATTACK';  // Opportunity to gain
}
```

---

## 🎯 Step 5: Action Planning

Transform insights into executable actions.

### Priority Ranking

Create a weighted score for each barangay/region:

```typescript
function calculatePriorityScore(area) {
  const weights = {
    opportunity_size: 0.3,
    current_performance: 0.2,
    competitive_position: 0.2,
    accessibility: 0.15,
    store_density: 0.15
  };
  
  return (
    area.opportunity * weights.opportunity_size +
    area.growth_rate * weights.current_performance +
    area.market_share * weights.competitive_position +
    area.road_access * weights.accessibility +
    area.stores_per_1000 * weights.store_density
  );
}

// Rank and select top opportunities
const priorities = areas
  .map(area => ({
    ...area,
    score: calculatePriorityScore(area)
  }))
  .sort((a, b) => b.score - a.score)
  .slice(0, 20);  // Top 20 priorities
```

### Resource Allocation

```typescript
// Allocate field team based on opportunity
const fieldAllocation = priorities.map(area => ({
  area: area.name,
  current_revenue: area.revenue,
  potential: area.opportunity,
  recommended_visits: Math.ceil(area.opportunity / 50000), // 1 visit per 50K potential
  recommended_investment: area.opportunity * 0.05  // 5% of opportunity as investment
}));
```

### KPI Targets

Set specific targets for each area:

```typescript
const targets = {
  region: {
    revenue_growth: 15,  // %
    new_stores: 50,
    penetration_increase: 10  // percentage points
  },
  city: {
    revenue_growth: 20,
    new_stores: 10,
    avg_basket_increase: 5
  },
  barangay: {
    stores_activated: 5,
    weekly_visits: 2,
    sku_availability: 90  // %
  }
};
```

---

## 📱 Step 6: Monitoring & Alerts

Set up automated monitoring for your focus areas.

### Create Regional Monitors

```sql
-- Insert monitor for underperforming region
INSERT INTO platinum_monitors (
  monitor_name,
  monitor_type,
  monitor_sql,
  threshold_value,
  comparison_operator,
  schedule_interval
) VALUES (
  'Region 13 Daily Revenue',
  'threshold',
  'SELECT SUM(revenue) FROM gold_geo_sales WHERE region_id = 13 AND date = CURRENT_DATE',
  100000,
  '<',
  '1 hour'
);
```

### Alert Configuration

```typescript
// Configure alerts for critical metrics
const alerts = [
  {
    metric: 'daily_revenue',
    threshold: lastWeekAvg * 0.9,
    channel: 'email',
    recipients: ['regional.manager@company.com']
  },
  {
    metric: 'new_store_activation',
    threshold: 2,  // minimum per day
    channel: 'slack',
    webhook: process.env.SLACK_WEBHOOK
  }
];
```

---

## 🎨 Visualization Templates

### Regional Dashboard Layout

```jsx
<Dashboard>
  <Row>
    <KPICard title="Total Revenue" value={totalRevenue} trend={revenueTrend} />
    <KPICard title="Active Regions" value={activeRegions} />
    <KPICard title="YoY Growth" value={yoyGrowth} format="percentage" />
    <KPICard title="Coverage" value={coveragePercent} format="percentage" />
  </Row>
  
  <Row>
    <Col span={16}>
      <PhilippinesMap data={regionData} onSelect={handleRegionSelect} />
    </Col>
    <Col span={8}>
      <TopPerformers data={topRegions} />
      <BottomPerformers data={bottomRegions} />
    </Col>
  </Row>
  
  <Row>
    <Col span={12}>
      <BarChart 
        data={regionComparison} 
        xKey="region_name" 
        yKey="revenue"
        title="Revenue by Region"
      />
    </Col>
    <Col span={12}>
      <LineChart
        data={trendData}
        xKey="date"
        yKey="revenue"
        groupBy="region"
        title="30-Day Trend"
      />
    </Col>
  </Row>
</Dashboard>
```

---

## 🚀 Best Practices

1. **Start Broad, Then Narrow**
   - National → Regional → City → Barangay
   - Don't skip levels - context matters

2. **Compare Apples to Apples**
   - Normalize by population when comparing areas
   - Account for seasonality in growth calculations
   - Consider urban vs rural differences

3. **Combine Metrics**
   - Revenue alone isn't enough
   - Look at penetration, frequency, and basket size
   - Balance growth with profitability

4. **Set Realistic Targets**
   - Use historical performance as baseline
   - Account for local market conditions
   - Phase rollouts (pilot → scale)

5. **Monitor Continuously**
   - Daily checks for focus areas
   - Weekly business reviews
   - Monthly strategic assessments

---

## 🔗 Related Resources

- [API Documentation - Geographic Endpoints](/docs/api/gold-apis#geographic-analytics)
- [DAL Guide - Geo Functions](/docs/dal/gold-fetchers#geo-functions)
- [Competitive Analysis Playbook](/docs/playbooks/competitive-dynamics)
- [Field Team Optimization](/docs/playbooks/field-optimization)

---

## 💡 Quick Tips

- **Mobile Access**: Regional dashboard is mobile-optimized for field visits
- **Offline Maps**: Download region data for offline access
- **Export Reports**: Generate PDF reports for management reviews
- **Collaborative Planning**: Share dashboard links with team members

---

*Need help? Contact scout-support@insightpulse.ai or check our [FAQ](/docs/faq/regional-analysis)*
