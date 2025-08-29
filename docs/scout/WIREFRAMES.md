# Scout Dashboard Wireframes

**Owner**: @D-Chan  
**Figma File**: [Scout Dashboard v5.2](https://www.figma.com/file/ABC123DEF456/Scout-Dashboard-v5)  
**Last Updated**: 2025-01-26  
**Status**: In Development  

## Frame Mapping

| Screen | Figma Frame ID | Route | Component | Status |
|--------|---------------|-------|-----------|--------|
| Executive Overview | `ABC123:456` | `/dashboard` | `<ExecutiveDashboard />` | 🟡 In Progress |
| Transaction Trends | `ABC123:789` | `/dashboard/analytics` | `<TransactionTrends />` | ⬜️ Not Started |
| Product Mix | `ABC123:012` | `/dashboard/analytics#products` | `<ProductMix />` | ⬜️ Not Started |
| Geographic View | `DEF456:345` | `/dashboard/geographic` | `<GeographicChart />` | ⬜️ Not Started |
| Consumer Insights | `DEF456:678` | `/dashboard/consumer` | `<ConsumerDashboard />` | ⬜️ Not Started |
| AI Recommendations | `DEF456:901` | `/dashboard/ai` | `<RecommendationPanel />` | ⬜️ Not Started |
| Reports | `GHI789:234` | `/dashboard/reports` | `<ReportsView />` | ⬜️ Not Started |

## Component Hierarchy

```
Dashboard Layout
├── Header
│   ├── Logo
│   ├── Navigation
│   ├── User Menu
│   └── Search Bar
├── Sidebar
│   ├── Main Navigation
│   ├── Quick Filters
│   └── Help/Support
├── Main Content Area
│   ├── Page Header
│   │   ├── Title
│   │   ├── Breadcrumbs
│   │   └── Actions (Export, Filter, etc.)
│   ├── KPI Row
│   │   ├── Revenue Card
│   │   ├── Transactions Card
│   │   ├── AOV Card
│   │   └── Growth Card
│   ├── Charts Grid
│   │   ├── Primary Chart (60% width)
│   │   └── Secondary Charts (40% width)
│   └── Data Table
│       ├── Headers (sortable)
│       ├── Rows (selectable)
│       └── Pagination
└── Footer
    ├── Version Info
    ├── Last Updated
    └── Legal Links
```

## Responsive Breakpoints

| Breakpoint | Width | Layout Changes |
|------------|-------|----------------|
| Mobile | < 640px | Single column, collapsed sidebar, stacked KPIs |
| Tablet | 640-1024px | Two columns, collapsible sidebar, 2x2 KPI grid |
| Desktop | 1024-1280px | Three columns, fixed sidebar, horizontal KPI row |
| Wide | > 1280px | Four columns, expanded sidebar, additional chart space |

## Design Tokens Mapping

```yaml
# From Figma Variables
colors:
  primary: 
    value: "#1E40AF"
    figma: "Primary/500"
  secondary:
    value: "#7C3AED"
    figma: "Secondary/500"
  success:
    value: "#059669"
    figma: "Semantic/Success"
  warning:
    value: "#D97706"
    figma: "Semantic/Warning"
  error:
    value: "#DC2626"
    figma: "Semantic/Error"

spacing:
  xs: 
    value: "4px"
    figma: "Spacing/XS"
  sm:
    value: "8px"
    figma: "Spacing/SM"
  md:
    value: "16px"
    figma: "Spacing/MD"
  lg:
    value: "24px"
    figma: "Spacing/LG"
  xl:
    value: "32px"
    figma: "Spacing/XL"

typography:
  h1:
    figma: "Display/Large"
    size: "32px"
    weight: 700
  h2:
    figma: "Display/Medium"
    size: "24px"
    weight: 600
  body:
    figma: "Body/Regular"
    size: "14px"
    weight: 400
```

## Interaction States

| Component | Default | Hover | Active | Disabled | Loading |
|-----------|---------|-------|--------|----------|---------|
| Button | Background: Primary | Darken 10% | Darken 20% | Opacity 50% | Spinner |
| Card | Border: Gray-200 | Shadow-md | Shadow-lg | Opacity 60% | Skeleton |
| Input | Border: Gray-300 | Border: Primary | Border: Primary + Shadow | Background: Gray-100 | - |
| Table Row | Background: White | Background: Gray-50 | Background: Blue-50 | Opacity 50% | - |

## Animation Specifications

| Animation | Duration | Easing | Use Case |
|-----------|----------|---------|----------|
| Fade In | 200ms | ease-out | Page transitions |
| Slide | 300ms | cubic-bezier(0.4, 0, 0.2, 1) | Sidebar, modals |
| Scale | 150ms | ease-in-out | Cards, buttons |
| Skeleton | 1.5s | linear (infinite) | Loading states |

## Code Connect Mappings

```typescript
// Figma to React Component Map
export const FIGMA_COMPONENT_MAP = {
  // KPI Cards
  "ABC123:100": "components/kpi/RevenueCard",
  "ABC123:101": "components/kpi/TransactionCard",
  "ABC123:102": "components/kpi/AOVCard",
  "ABC123:103": "components/kpi/GrowthCard",
  
  // Charts
  "DEF456:200": "components/charts/TrendChart",
  "DEF456:201": "components/charts/BarChart",
  "DEF456:202": "components/charts/PieChart",
  "DEF456:203": "components/charts/MapChart",
  
  // UI Elements
  "GHI789:300": "components/ui/Button",
  "GHI789:301": "components/ui/Input",
  "GHI789:302": "components/ui/Select",
  "GHI789:303": "components/ui/DatePicker",
};
```

## Export Settings

| Asset Type | Format | Size | Naming Convention |
|------------|--------|------|-------------------|
| Icons | SVG | 24x24 | `icon-{name}-24.svg` |
| Logos | PNG + SVG | Various | `logo-{variant}-{size}.{ext}` |
| Illustrations | PNG | 2x | `illus-{name}@2x.png` |
| Component Screenshots | PNG | 1x | `comp-{name}.png` |

## Figma Sync Status

| Component | Last Synced | Changes | Action Required |
|-----------|-------------|---------|-----------------|
| KPI Cards | 2025-01-26 | None | ✅ Up to date |
| Navigation | 2025-01-25 | Minor spacing | 🟡 Review changes |
| Charts | 2025-01-20 | Color updates | 🔴 Needs sync |
| Forms | 2025-01-15 | New validation states | 🔴 Needs sync |

## How to Sync from Figma

1. **Via Claude Desktop MCP**:
   ```
   Select component in Figma Dev Mode
   Use Claude Desktop to export selection
   Commit to GitHub via MCP Hub
   ```

2. **Via MCP Hub API**:
   ```bash
   curl -H "X-API-Key: $HUB_API_KEY" \
        -d '{"server":"figma","tool":"file.exportJSON","args":{"fileKey":"ABC123DEF456"}}' \
        https://hub.example.com/mcp/run
   ```

3. **Manual Export**:
   - Open Figma file
   - Select frame
   - Export as JSON/SVG/PNG
   - Place in `assets/figma/`

## Notes

- All wireframes should follow 8px grid system
- Maintain 4.5:1 color contrast ratio for WCAG AA
- Test all interactions at each breakpoint
- Keep loading states under 3 seconds
- Ensure touch targets are minimum 44x44px on mobile
