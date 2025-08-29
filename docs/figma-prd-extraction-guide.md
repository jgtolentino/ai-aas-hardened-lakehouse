# Scout Dashboard v5.2 - PRD Extraction Guide

## Overview

This guide extracts Product Requirements Document (PRD) content from the Figma board and integrates it with existing Scout Dashboard specifications using our enterprise bridge architecture.

**Figma Board URL**: `https://www.figma.com/board/BLdSOtPdiUrIbmoNkyhmvF/Product-Requirements-Document--Copy-?node-id=0-1&t=YSULerIAGm2UlBrj-1`

**Related Specifications**:
- Scout Dashboard PRD: `docs/scout/PRD.md` 
- Wireframes: `docs/scout/WIREFRAMES.md`
- Implementation: `apps/scout-dashboard/README.md`

## Bridge Architecture for PRD Extraction

### Method 1: Automated Extraction (via Figma Bridge MCP)

If you have the Figma plugin installed and the bridge running:

```bash
# Start Figma Bridge
./scripts/figma-bridge.sh start

# Extract PRD content automatically
./scripts/figma-prd-extractor.sh "https://www.figma.com/board/BLdSOtPdiUrIbmoNkyhmvF/Product-Requirements-Document--Copy-"
```

### Method 2: Manual Extraction (for Private Boards)

Since the board requires authentication, follow this manual process:

## PRD Extraction Template

### 1. Product Overview
**Extracted from Figma Board + Scout Dashboard v5.2 Integration:**

#### Product Details
- **Product Name**: Scout Analytics Dashboard v5.2
- **Product Title**: Enterprise Analytics & Business Intelligence Platform
- **Version**: 1.4.0 (Last Updated: 2025-01-26)
- **Purpose**: Real-time retail analytics with AI-powered insights for executive decision making

#### Primary Personas
**Executive Persona:**
- **Demographics**: C-level executives, 35-55 years old, limited technical background
- **Behaviors**: Mobile-first consumption, needs quick insights, time-constrained
- **Attitude**: Results-oriented, strategic thinking, risk-averse
- **Needs/Challenges**: Quick access to KPIs, trend identification, strategic planning data
- **Goals**: 
  - Short-term: Daily performance monitoring, anomaly detection
  - Long-term: Strategic planning, growth optimization, competitive advantage
- **How we help**: Executive dashboard with KPI cards, AI recommendations, predictive insights

**Manager/Analyst Persona:**
- **Demographics**: Department heads, analysts, 25-45 years old, technically proficient
- **Behaviors**: Deep-dive analysis, regular dashboard usage, collaborative work
- **Attitude**: Detail-oriented, analytical, process-driven
- **Needs/Challenges**: Comprehensive analytics, geographic insights, performance tracking
- **Goals**: 
  - Short-term: Operational optimization, team performance tracking
  - Long-term: Process improvement, data-driven decision making
- **How we help**: Advanced analytics, geographic visualization, drill-down capabilities

#### Success Metrics (from Figma Board)
- **Business KPIs**: Revenue growth, transaction volume, AOV improvement, customer retention
- **Product KPIs**: >1000 DAU, <2s dashboard load time, 99.9% availability
- **Technical SLOs**: <500ms p95 API latency, Lighthouse score >90, WCAG 2.1 AA compliance

#### Value Proposition
"Unified analytics platform that transforms complex retail data into actionable insights, enabling executives to make strategic decisions and managers to optimize operations through real-time dashboards, AI-powered recommendations, and role-based intelligence." 

### 2. User Stories & Epics
**Look for user story cards/frames and extract:**

#### Epic 1: Executive Overview Dashboard
- **User Story 1**: As an Executive, I want to see KPI cards (revenue, transactions, AOV, growth) so that I can quickly assess business performance
  - **Acceptance Criteria**: 
    - [ ] Given executive access, when dashboard loads, then KPI cards display current metrics
    - [ ] Given stale data (>5min), when viewing KPIs, then refresh indicator appears
    - [ ] Given mobile device, when viewing dashboard, then KPIs stack vertically
  - **Priority**: High
  - **Story Points**: 8
  - **Dependencies**: Gold views materialization, RLS policies

- **User Story 2**: As an Executive, I want to see revenue trends over 14 days so that I can identify patterns
  - **Acceptance Criteria**: 
    - [ ] Given 14 days of data, when chart loads, then trend line displays with confidence scores
    - [ ] Given trend interaction, when hovering over data points, then tooltip shows exact values
  - **Priority**: High
  - **Story Points**: 5
  - **Dependencies**: Gold revenue trend view

#### Epic 2: Analytics & Geographic Views
- **User Story 3**: As a Manager/Analyst, I want geographic visualization with Mapbox so that I can analyze regional performance
  - **Acceptance Criteria**: 
    - [ ] Given geographic data, when map loads, then choropleth displays regional metrics
    - [ ] Given region selection, when clicking area, then drill-down to barangay level
    - [ ] Given heatmap overlay, when toggling, then performance density visualization appears
  - **Priority**: Medium
  - **Story Points**: 13
  - **Dependencies**: Mapbox integration, geographic gold views

#### Epic 3: AI Recommendations
- **User Story 4**: As any role, I want AI-powered recommendations so that I can optimize business decisions
  - **Acceptance Criteria**: 
    - [ ] Given current performance data, when AI panel loads, then recommendations appear with confidence scores
    - [ ] Given anomaly detection, when unusual patterns occur, then alerts display in real-time
    - [ ] Given prediction requests, when forecast generated, then predictive insights show with accuracy metrics
  - **Priority**: Medium
  - **Story Points**: 21
  - **Dependencies**: AI recommendation RPC, anomaly detection algorithm

### 3. Functional Requirements
**Extract all functional requirements:**
- **FR001**: Role-based navigation system that filters menu items based on user role (Executive/Manager/Analyst) from Supabase JWT claims
- **FR002**: Real-time data integration with automatic fallback from gold views to RPC functions when views are unavailable
- **FR003**: Interactive charts using Recharts with hover tooltips, zoom capabilities, and export functionality
- **FR004**: Responsive design with mobile-first approach using Tailwind CSS breakpoints (640px, 768px, 1024px, 1280px)
- **FR005**: Live data updates with React Query caching and 5-minute stale-time configuration
- **FR006**: Geographic visualization with Mapbox integration supporting choropleth maps and drill-down to barangay level
- **FR007**: AI recommendation panel with confidence scores, anomaly detection alerts, and predictive insights
- **FR008**: Executive KPI dashboard with revenue, transactions, AOV, and growth metrics from materialized views
- **FR009**: WCAG 2.1 AA accessibility compliance with keyboard navigation and ARIA labels
- **FR010**: Performance monitoring with Lighthouse scores >90 and API response times <500ms p95

### 4. Non-Functional Requirements

#### Performance Requirements
- **Response Time**: API response time p95 < 500ms, dashboard load time < 2s
- **Throughput**: Handle 1000+ daily active users with React Query caching
- **Concurrent Users**: Support concurrent access with materialized view refresh every 5 minutes
- **Availability**: 99.9% SLA (43.2 min/month downtime allowance)

#### Security Requirements
- **Authentication**: Supabase Auth with JWT tokens, 60-minute refresh cycle
- **Authorization**: Row Level Security (RLS) policies with role-based access (viewer/analyst/admin)
- **Data Protection**: JWT claims validation, rate limiting 1000 req/min per user
- **Compliance**: WCAG 2.1 AA accessibility standards, secure token handling

#### Usability Requirements
- **Accessibility**: WCAG 2.1 AA compliance, 4.5:1 color contrast ratio, keyboard navigation
- **Mobile Responsiveness**: Mobile-first design with breakpoints at 640px, 768px, 1024px, 1280px
- **Browser Support**: Modern browsers with JavaScript enabled, Progressive Web App capabilities 

### 5. User Flows & Journeys
**Extract user flow diagrams:**

#### Primary User Flow
1. **Entry Point**: [How user enters the system]
2. **Navigation Path**: [Step-by-step user actions]
3. **Decision Points**: [Where users make choices]
4. **Success Outcome**: [What success looks like]
5. **Error Handling**: [What happens when things go wrong]

#### Secondary Flows
- Continue pattern for additional flows...

### 6. Wireframes & UI Specifications

#### Screen 1: [Name]
- **Purpose**: [What this screen accomplishes]
- **Key Components**: 
  - Navigation elements
  - Content areas
  - Interactive elements
  - Data inputs/outputs
- **Responsive Behavior**: [How it adapts to different screen sizes]

#### Screen 2: [Name]
- Continue pattern...

### 7. Technical Specifications

#### API Requirements
**Scout Dashboard v5.2 RPC Endpoints:**
```
GET /api/executive/summary
- Purpose: Executive KPI metrics (revenue, transactions, AOV, growth)
- Parameters: {period: string} // '7d', '30d', '90d'
- Response: ExecutiveSummary interface
- Authentication: JWT with executive role
- SLA: 200ms p95

POST /api/transactions/trends
- Purpose: Transaction trend analysis with confidence scores
- Payload: TrendsRequest (granularity, date range, metrics, filters)
- Response: TrendsResponse[] with timestamps and confidence
- Validation: Date range max 1 year, valid granularity
- SLA: 500ms p95

GET /api/products/mix
- Purpose: Product performance and category analysis
- Parameters: {store_id?: string}
- Response: ProductMix with rankings and revenue
- Authentication: JWT with analyst+ role
- SLA: 300ms p95

GET /api/geo/regions
- Purpose: Geographic performance data for choropleth maps
- Parameters: {level: number} // 1=region, 2=city, 3=barangay
- Response: GeoRegion[] with coordinates and metrics
- Authentication: JWT with manager+ role
- SLA: 400ms p95

POST /api/ai/recommendations
- Purpose: AI-powered business recommendations and anomaly detection
- Payload: RecommendationRequest with context and preferences
- Response: Recommendation[] with confidence scores
- Authentication: JWT with any role
- SLA: 1s p95
```

#### Database Schema
**Scout Dashboard v5.2 Gold Views (Materialized):**
```sql
-- Executive metrics (refreshed hourly)
CREATE MATERIALIZED VIEW gold.executive_summary AS
SELECT
  date_trunc('day', created_at) as date,
  SUM(amount) as revenue,
  COUNT(*) as transactions,
  AVG(amount) as aov,
  LAG(SUM(amount)) OVER (ORDER BY date_trunc('day', created_at)) as prev_revenue
FROM silver.transactions
WHERE status = 'completed'
GROUP BY 1;

-- Revenue trend (14-day window, refreshed every 5 minutes)
CREATE MATERIALIZED VIEW gold.revenue_trend_14d AS
SELECT
  date_trunc('hour', created_at) as timestamp,
  SUM(amount) as revenue,
  COUNT(*) as transaction_count,
  CASE 
    WHEN stddev(amount) > 0 THEN 0.95 
    ELSE 0.8 
  END as confidence
FROM silver.transactions
WHERE created_at >= NOW() - INTERVAL '14 days'
  AND status = 'completed'
GROUP BY 1
ORDER BY 1;

-- Product performance (refreshed daily)
CREATE MATERIALIZED VIEW gold.product_mix AS
SELECT
  product_id,
  product_name,
  category,
  SUM(quantity) as units_sold,
  SUM(revenue) as total_revenue,
  ROW_NUMBER() OVER (ORDER BY SUM(revenue) DESC) as rank
FROM silver.order_items oi
JOIN silver.products p ON oi.product_id = p.id
WHERE oi.created_at >= NOW() - INTERVAL '30 days'
GROUP BY 1, 2, 3
ORDER BY total_revenue DESC
LIMIT 20;

-- Geographic aggregations (indexed for performance)
CREATE INDEX idx_geo_region ON gold.geographic_metrics(region_id, period);
CREATE INDEX idx_geo_city ON gold.geographic_metrics(city_id, period);
```

#### Third-Party Integrations
- **Supabase**: Backend-as-a-Service for authentication, database, and real-time subscriptions via PostgreSQL connection
- **Mapbox**: Geographic visualization and choropleth mapping via REST API and GL JS SDK
- **React Query**: Client-side data caching and synchronization with 5-minute stale-time configuration  
- **Recharts**: Chart visualization library for revenue trends, KPI cards, and interactive analytics
- **Tailwind CSS**: Utility-first CSS framework for responsive design and design token implementation

### 8. Design System & Tokens

#### Colors (Scout Dashboard v5.2 Design Tokens)
- **Primary**: #1E40AF (Blue-700) - Navigation, CTAs, primary actions
- **Secondary**: #7C3AED (Violet-600) - Secondary actions, highlights  
- **Success**: #059669 (Emerald-600) - Positive KPIs, success states
- **Warning**: #D97706 (Amber-600) - Caution indicators, moderate alerts
- **Error**: #DC2626 (Red-600) - Error states, critical alerts

#### Typography (System UI Stack)
- **H1**: System-ui, sans-serif, 32px, 700 weight, 1.2 line-height (Display/Large)
- **H2**: System-ui, sans-serif, 24px, 600 weight, 1.3 line-height (Display/Medium)
- **Body**: System-ui, sans-serif, 14px, 400 weight, 1.5 line-height (Body/Regular)
- **Caption**: System-ui, sans-serif, 12px, 400 weight, 1.4 line-height (Caption/Regular)

#### Spacing (8px Grid System)
- **xs**: 4px - Tight spacing, form elements
- **sm**: 8px - Component padding, small gaps
- **md**: 16px - Card padding, section spacing
- **lg**: 24px - Page margins, large gaps
- **xl**: 32px - Section dividers, hero spacing

#### Components (Scout Dashboard Component System)
- **Button Variants**: Primary (bg-blue-700), Secondary (border-violet-600), Ghost (hover:bg-gray-50)
- **Form Elements**: Input (focus:border-primary), Select (chevron-down icon), DatePicker (calendar widget)
- **Navigation**: Header with logo, Sidebar with role-based filtering, Breadcrumbs with "/" separators
- **Feedback**: Alert cards (success/warning/error), Modal overlays, Toast notifications (top-right)
- **KPI Cards**: Revenue/Transactions/AOV/Growth with trend indicators and loading skeletons
- **Charts**: Recharts integration with responsive tooltips, zoom controls, and export functionality

### 9. Acceptance Criteria & Definition of Done

#### General DoD
- [ ] All user stories have acceptance criteria
- [ ] Design system tokens are applied
- [ ] Responsive design implemented
- [ ] Accessibility standards met (WCAG 2.1 AA)
- [ ] Performance requirements met
- [ ] Security requirements implemented
- [ ] Unit tests written and passing
- [ ] Integration tests written and passing
- [ ] Code review completed
- [ ] Documentation updated

#### Feature-Specific Acceptance Criteria
**Extract from each user story in the Figma board**

### 10. Constraints & Assumptions

#### Technical Constraints
- [Browser support requirements]
- [Device support requirements]
- [Performance constraints]
- [Security constraints]

#### Business Constraints
- [Budget limitations]
- [Timeline constraints]
- [Resource limitations]
- [Regulatory requirements]

#### Assumptions
- [User behavior assumptions]
- [Technical assumptions]
- [Business assumptions]

## Bridge Integration Points

Once you've extracted the PRD content, our bridge architecture can help with:

### 1. Design Implementation (Figma Bridge)
```typescript
// Create Figma components from PRD specs
await figmaBridge.createComponent('UserCard', 320, 120);
await figmaBridge.applyBrandTokens(designTokens);
```

### 2. Data Structure Creation (ChatGPT Database Bridge)
```sql
-- Generate database schema from requirements
CREATE SCHEMA product_features;
-- Tables based on extracted requirements
```

### 3. BI Dashboard Creation (PowerBI/Tableau Bridge)
```typescript
// Create dashboards for product metrics
await biBridge.createDashboard('Product Analytics', requirements);
```

## Automation Scripts

### PRD to Implementation Pipeline
```bash
# 1. Extract PRD
./scripts/figma-prd-extractor.sh "$FIGMA_URL"

# 2. Generate database schema
./scripts/generate-schema-from-prd.sh docs/product-requirements.md

# 3. Create Figma components
./scripts/create-components-from-prd.sh docs/product-requirements.md

# 4. Set up analytics dashboard
./scripts/create-analytics-dashboard.sh docs/product-requirements.md
```

## Validation Checklist

### PRD Completeness
- [ ] All user stories extracted with acceptance criteria
- [ ] Functional requirements clearly defined
- [ ] Non-functional requirements specified
- [ ] User flows documented with decision points
- [ ] Wireframes captured with component details
- [ ] Technical specifications include API and database requirements
- [ ] Design system tokens documented
- [ ] Success metrics and KPIs defined

### Technical Readiness
- [ ] Requirements are testable and measurable
- [ ] Dependencies are clearly identified
- [ ] Constraints and assumptions documented
- [ ] Integration points with existing systems identified
- [ ] Security and compliance requirements specified

### Stakeholder Alignment
- [ ] Product owner has reviewed and approved
- [ ] Engineering team has reviewed technical feasibility
- [ ] Design team has reviewed UI/UX requirements
- [ ] QA team has reviewed acceptance criteria
- [ ] Business stakeholders have reviewed business requirements

## Next Steps After Extraction

1. **Validate with Stakeholders**: Review extracted content with product owner and team
2. **Technical Planning**: Break down into implementation tasks
3. **Design Implementation**: Use Figma Bridge to create design components
4. **Database Design**: Use database bridge to create schema
5. **Analytics Setup**: Use BI bridge to create monitoring dashboards
6. **Development Sprint Planning**: Organize into development cycles

## Tools and Resources

### Figma Plugin Requirements
For automated extraction, install the Figma plugin that connects to our bridge:
- Plugin supports text extraction
- Frame structure analysis
- Component identification
- Design token extraction

### Bridge Status Check
```bash
# Check if bridges are running
./scripts/figma-bridge.sh status
./scripts/chatgpt-bridge.sh status  
./scripts/bi-bridge.sh status
```

### Documentation Generation
After extraction, generate implementation docs:
```bash
# Generate API documentation
./scripts/generate-api-docs.sh docs/product-requirements.md

# Generate database migration scripts  
./scripts/generate-migrations.sh docs/product-requirements.md

# Generate test specifications
./scripts/generate-test-specs.sh docs/product-requirements.md
```

This comprehensive extraction process ensures that all product requirements are captured and can be efficiently implemented using our enterprise bridge architecture.