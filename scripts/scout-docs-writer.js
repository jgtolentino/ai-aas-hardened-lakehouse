#!/usr/bin/env node

/**
 * Scout Analytics Documentation Writer
 * Transforms neural-docs submodule into production-ready Scout documentation
 */

import fs from 'fs/promises';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.join(__dirname, '..');
const NEURAL_DOCS = path.join(ROOT, 'docs', 'neural-docs');
const SCOUT_DOCS = path.join(NEURAL_DOCS, 'scout-data-warehouse-docs');

// Scout Analytics actual tech stack
const SCOUT_TECH_STACK = {
  database: {
    primary: 'Supabase (PostgreSQL)',
    schemas: ['scout', 'hris', 'expense', 'service_desk', 'approval', 'analytics'],
    architecture: 'Medallion (Bronze/Silver/Gold/Platinum)'
  },
  backend: {
    runtime: 'Node.js + Deno Edge Functions',
    api: 'Supabase REST + RPC',
    auth: 'JWT + Row Level Security'
  },
  frontend: {
    framework: 'React + TypeScript',
    bundler: 'Vite',
    ui: 'Tailwind CSS + shadcn/ui',
    state: 'SWR + Zustand',
    charts: 'Recharts + D3.js'
  },
  infrastructure: {
    hosting: 'Vercel + Supabase Cloud',
    ci: 'GitHub Actions',
    monitoring: 'Supabase Logs + Sentry'
  },
  tools: {
    documentation: 'Docusaurus + draw.io',
    testing: 'Vitest + Playwright',
    linting: 'ESLint + Prettier'
  }
};

// Transform Mermaid diagrams to draw.io references
async function replaceMermaidWithDrawIO(content) {
  // Replace Mermaid code blocks with draw.io diagram references
  return content.replace(
    /```mermaid\n([\s\S]*?)```/g,
    (match, diagram) => {
      const diagramName = diagram.match(/graph\s+(\w+)|erDiagram/)?.[1] || 'diagram';
      return `![${diagramName} Diagram](/diagrams/${diagramName.toLowerCase()}.drawio.svg)\n\n> [Edit this diagram](https://app.diagrams.net/#Uhttps://raw.githubusercontent.com/scout-analytics/docs/main/diagrams/${diagramName.toLowerCase()}.drawio)`;
    }
  );
}

// Update ERD with actual Scout schema
async function updateERD() {
  const erdPath = path.join(SCOUT_DOCS, 'docs', 'erd.mdx');
  let content = await fs.readFile(erdPath, 'utf8');
  
  // Replace generic tables with actual Scout tables
  const scoutERD = `---
sidebar_position: 1
---

# Scout Analytics Data Model

## Overview
Scout Analytics uses a medallion architecture with Bronze, Silver, and Gold layers built on Supabase PostgreSQL.

## Architecture Diagram

![Scout Data Architecture](/diagrams/scout-architecture.drawio.svg)

> [Edit Architecture Diagram](https://app.diagrams.net/#Uhttps://raw.githubusercontent.com/scout-analytics/docs/main/diagrams/scout-architecture.drawio)

## Core Schemas

### 1. Scout Schema (Retail Analytics)
- **Fact Tables**
  - \`fact_transactions\` - POS transaction records
  - \`fact_transaction_items\` - Line item details
  - \`fact_inventory_movements\` - Stock movements
  
- **Dimension Tables**
  - \`dim_products\` - Product master with attributes
  - \`dim_stores\` - Store locations and metadata
  - \`dim_customers\` - Customer demographics
  - \`dim_time\` - Time dimension (minute grain)
  - \`dim_date\` - Calendar dimension

### 2. Gold Layer Views
${await getGoldViewsList()}

### 3. Edge Functions
- \`competitive-intelligence\` - Market analysis bundle
- \`brand-market-share\` - Brand performance metrics
- \`geo-performance\` - Geographic analytics
- \`persona-performance\` - Customer segment analysis
- \`monthly-churn\` - Churn cohort analysis

## Data Flow

![Data Flow Diagram](/diagrams/data-flow.drawio.svg)

> [Edit Data Flow](https://app.diagrams.net/#Uhttps://raw.githubusercontent.com/scout-analytics/docs/main/diagrams/data-flow.drawio)

## Tech Stack

${JSON.stringify(SCOUT_TECH_STACK, null, 2).replace(/"/g, '')}
`;
  
  await fs.writeFile(erdPath, scoutERD);
}

// Get Gold views from our migrations
async function getGoldViewsList() {
  try {
    const migrationPath = path.join(ROOT, 'platform', 'scout', 'migrations', '025_gold_analytics_views.sql');
    const content = await fs.readFile(migrationPath, 'utf8');
    
    // Extract view names
    const views = content.match(/CREATE OR REPLACE VIEW scout\.(\w+)/g)
      ?.map(match => match.replace('CREATE OR REPLACE VIEW scout.', ''))
      || [];
    
    return views.map(view => `- \`${view}\` - ${getViewDescription(view)}`).join('\n');
  } catch {
    return '- Gold views documentation pending';
  }
}

function getViewDescription(viewName) {
  const descriptions = {
    'gold_dashboard_kpis': 'Key performance indicators',
    'gold_top_products': 'Product performance rankings',
    'gold_customer_segments': 'Customer segmentation analysis',
    'gold_store_performance': 'Store-level metrics',
    'gold_sales_trends': 'Time-series sales analysis',
    'gold_inventory_status': 'Current inventory positions',
    'gold_campaign_effectiveness': 'Marketing campaign ROI',
    'gold_customer_lifetime_value': 'CLV calculations',
    'gold_market_basket_analysis': 'Product affinity analysis',
    'gold_geographic_performance': 'Regional performance metrics'
  };
  return descriptions[viewName] || 'Analytics view';
}

// Update implementation guide with actual deployment
async function updateImplementation() {
  const implPath = path.join(SCOUT_DOCS, 'docs', 'implementation.mdx');
  
  const content = `---
sidebar_position: 4
---

# Scout Analytics Implementation Guide

## Current Production Status

### ✅ Deployed Components

#### Supabase Backend
- **Project**: \`cxzllzyxwpyptfretryc\`
- **Database**: PostgreSQL with RLS enabled
- **Edge Functions**: 6 deployed and active
- **Gold Views**: 10 analytics views deployed

#### Frontend Applications
- **Scout Dashboard**: React + Vite + TypeScript
- **CI Client**: Hardened with Zod validation
- **URL**: http://localhost:8080 (development)

### 🚀 Quick Start

\`\`\`bash
# Clone with submodules
git clone --recursive https://github.com/your-org/ai-aas-hardened-lakehouse.git
cd ai-aas-hardened-lakehouse

# Install dependencies
npm install

# Set up environment
cp .env.example .env
# Add your Supabase credentials

# Start development
npm run dev
\`\`\`

### Environment Variables

\`\`\`env
# Required for all environments
VITE_SUPABASE_URL=https://cxzllzyxwpyptfretryc.supabase.co
VITE_SUPABASE_ANON_KEY=your_anon_key

# Edge Functions (server-side only)
SUPABASE_SERVICE_ROLE_KEY=your_service_role_key
\`\`\`

### Deployment Architecture

![Deployment Architecture](/diagrams/deployment.drawio.svg)

> [Edit Deployment Diagram](https://app.diagrams.net/#Uhttps://raw.githubusercontent.com/scout-analytics/docs/main/diagrams/deployment.drawio)

## Database Setup

### 1. Execute Migrations

\`\`\`sql
-- Run in Supabase SQL Editor
-- Path: platform/scout/migrations/

-- 001_initial_schema.sql
-- 002_dimensions.sql
-- 003_facts.sql
-- 025_gold_analytics_views.sql
\`\`\`

### 2. Create execute_sql Function

\`\`\`sql
CREATE OR REPLACE FUNCTION public.execute_sql(query text)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    result json;
BEGIN
    IF query IS NULL OR trim(query) = '' THEN
        RAISE EXCEPTION 'Query cannot be empty';
    END IF;
    
    EXECUTE format('SELECT array_to_json(array_agg(row_to_json(t))) FROM (%s) t', query) INTO result;
    RETURN COALESCE(result, '[]'::json);
    
EXCEPTION
    WHEN OTHERS THEN
        RETURN json_build_object(
            'error', SQLERRM,
            'state', SQLSTATE,
            'query', query
        );
END;
$$;
\`\`\`

## Edge Functions Deployment

\`\`\`bash
# Deploy all Edge Functions
cd ~/supabase/functions
supabase functions deploy competitive-intelligence
supabase functions deploy brand-market-share
supabase functions deploy brand-substitutions
supabase functions deploy geo-performance
supabase functions deploy persona-performance
supabase functions deploy monthly-churn
\`\`\`

## Frontend Integration

### Using the CI Client

\`\`\`typescript
import { makeCI } from './config/backend-integration';
import { useCompetitiveBundle } from './hooks/useCI';

// In your component
function Dashboard() {
  const { data, error, isLoading } = useCompetitiveBundle();
  
  if (isLoading) return <LoadingSpinner />;
  if (error) return <ErrorDisplay error={error} />;
  
  return <CompetitiveInsights data={data} />;
}
\`\`\`

## Monitoring & Debugging

### Check Edge Function Logs
\`\`\`bash
supabase functions logs competitive-intelligence --tail
\`\`\`

### Verify Gold Views
\`\`\`sql
-- Test KPI view
SELECT * FROM scout.gold_dashboard_kpis LIMIT 1;

-- Check data freshness
SELECT MAX(last_updated) FROM scout.gold_sales_trends;
\`\`\`

## Production Checklist

- [ ] Environment variables configured
- [ ] Database migrations applied
- [ ] execute_sql function created
- [ ] Edge Functions deployed
- [ ] Frontend build successful
- [ ] API endpoints responding
- [ ] Gold views returning data
- [ ] Authentication working
- [ ] Error tracking enabled
- [ ] Monitoring dashboards set up
`;

  await fs.writeFile(implPath, content);
}

// Update queries with actual Scout queries
async function updateQueries() {
  const queriesPath = path.join(SCOUT_DOCS, 'docs', 'queries.mdx');
  
  const content = `---
sidebar_position: 3
---

# Scout Analytics Query Library

## Dashboard KPIs

### Overall Performance Metrics
\`\`\`sql
-- Get current KPIs with trends
SELECT 
    total_revenue,
    unique_customers,
    transaction_count,
    revenue_growth_pct,
    customer_growth_pct,
    avg_transaction_value,
    total_inventory_value,
    low_stock_items
FROM scout.gold_dashboard_kpis;
\`\`\`

### Top Products Analysis
\`\`\`sql
-- Top 10 products by revenue
SELECT 
    product_name,
    brand,
    category_name,
    revenue,
    units_sold,
    revenue_rank,
    current_stock,
    days_of_supply
FROM scout.gold_top_products
ORDER BY revenue_rank
LIMIT 10;
\`\`\`

## Customer Analytics

### Customer Segmentation
\`\`\`sql
-- VIP customer identification
SELECT 
    customer_name,
    customer_segment,
    customer_tier,
    total_spent,
    transaction_count,
    avg_transaction_value,
    recency_status,
    days_since_last_purchase
FROM scout.gold_customer_segments
WHERE customer_tier = 'VIP'
ORDER BY total_spent DESC;
\`\`\`

### Customer Lifetime Value
\`\`\`sql
-- CLV by segment
SELECT 
    customer_segment,
    COUNT(*) as customer_count,
    AVG(lifetime_value) as avg_clv,
    SUM(lifetime_value) as total_clv,
    AVG(purchase_frequency) as avg_frequency
FROM scout.gold_customer_lifetime_value
GROUP BY customer_segment
ORDER BY avg_clv DESC;
\`\`\`

## Store Performance

### Regional Analysis
\`\`\`sql
-- Store performance by region
SELECT 
    region,
    COUNT(DISTINCT store_id) as store_count,
    SUM(total_revenue) as regional_revenue,
    AVG(revenue_per_sqft) as avg_revenue_per_sqft,
    AVG(inventory_turnover) as avg_turnover
FROM scout.gold_store_performance
GROUP BY region
ORDER BY regional_revenue DESC;
\`\`\`

## Competitive Intelligence

### Market Share Analysis
\`\`\`sql
-- Call Edge Function for market share
SELECT * FROM rpc('execute_sql', 
  'SELECT * FROM competitive_intelligence_bundle($1, $2)',
  '2024-01-01'::date,
  '2024-12-31'::date
);
\`\`\`

## Advanced Analytics

### Market Basket Analysis
\`\`\`sql
-- Product affinity matrix
SELECT 
    product_a,
    product_b,
    support,
    confidence,
    lift,
    transaction_count
FROM scout.gold_market_basket_analysis
WHERE lift > 1.5
ORDER BY lift DESC
LIMIT 20;
\`\`\`

### Inventory Optimization
\`\`\`sql
-- Products needing reorder
SELECT 
    product_name,
    store_name,
    current_stock,
    reorder_point,
    reorder_quantity,
    days_until_stockout,
    supplier_lead_time
FROM scout.gold_inventory_status
WHERE current_stock <= reorder_point
ORDER BY days_until_stockout;
\`\`\`

## Time Series Analysis

### Daily Sales Trends
\`\`\`sql
-- 30-day rolling average
WITH daily_sales AS (
    SELECT 
        date,
        daily_revenue,
        AVG(daily_revenue) OVER (
            ORDER BY date 
            ROWS BETWEEN 29 PRECEDING AND CURRENT ROW
        ) as rolling_30d_avg
    FROM scout.gold_sales_trends
    WHERE date >= CURRENT_DATE - INTERVAL '90 days'
)
SELECT 
    date,
    daily_revenue,
    rolling_30d_avg,
    (daily_revenue - rolling_30d_avg) / rolling_30d_avg * 100 as pct_vs_avg
FROM daily_sales
ORDER BY date DESC;
\`\`\`

## Campaign Effectiveness

### ROI Analysis
\`\`\`sql
-- Campaign performance metrics
SELECT 
    campaign_name,
    campaign_type,
    start_date,
    end_date,
    total_cost,
    attributed_revenue,
    roi_percentage,
    customers_reached,
    conversion_rate
FROM scout.gold_campaign_effectiveness
WHERE end_date >= CURRENT_DATE - INTERVAL '30 days'
ORDER BY roi_percentage DESC;
\`\`\`
`;

  await fs.writeFile(queriesPath, content);
}

// Create draw.io diagram templates
async function createDiagramTemplates() {
  const diagramsDir = path.join(SCOUT_DOCS, 'static', 'diagrams');
  await fs.mkdir(diagramsDir, { recursive: true });
  
  // Create placeholder for diagrams
  const diagramInfo = `# Scout Analytics Diagrams

This directory contains draw.io diagrams for Scout Analytics documentation.

## Diagrams:

1. **scout-architecture.drawio** - Overall system architecture
2. **data-flow.drawio** - Data pipeline flow (Bronze → Silver → Gold)
3. **deployment.drawio** - Deployment infrastructure
4. **erd.drawio** - Entity relationship diagram

## How to Edit:

1. Go to [draw.io](https://app.diagrams.net)
2. Open from GitHub URL
3. Make changes
4. Export as SVG to this directory

## Naming Convention:

- Use kebab-case for filenames
- Always export as .drawio.svg for web viewing
- Keep source .drawio files for editing
`;

  await fs.writeFile(path.join(diagramsDir, 'README.md'), diagramInfo);
}

// Update Docusaurus config
async function updateDocusaurusConfig() {
  const configPath = path.join(SCOUT_DOCS, 'docusaurus.config.ts');
  
  const newConfig = `import {themes as prismThemes} from 'prism-react-renderer';
import type {Config} from '@docusaurus/types';
import type * as Preset from '@docusaurus/preset-classic';

const config: Config = {
  title: 'Scout Analytics',
  tagline: 'Enterprise Retail Analytics Platform Documentation',
  favicon: 'img/favicon.ico',

  url: 'https://scout-analytics.vercel.app',
  baseUrl: '/',

  organizationName: 'scout-analytics',
  projectName: 'scout-docs',

  onBrokenLinks: 'throw',
  onBrokenMarkdownLinks: 'warn',

  i18n: {
    defaultLocale: 'en',
    locales: ['en'],
  },

  presets: [
    [
      'classic',
      {
        docs: {
          sidebarPath: './sidebars.ts',
          editUrl: 'https://github.com/scout-analytics/neural-docs/tree/main/scout-data-warehouse-docs/',
        },
        blog: false,
        theme: {
          customCss: './src/css/custom.css',
        },
      } satisfies Preset.Options,
    ],
  ],

  themeConfig: {
    image: 'img/scout-social-card.jpg',
    navbar: {
      title: 'Scout Analytics',
      logo: {
        alt: 'Scout Logo',
        src: 'img/logo.svg',
      },
      items: [
        {
          type: 'docSidebar',
          sidebarId: 'tutorialSidebar',
          position: 'left',
          label: 'Documentation',
        },
        {
          href: 'https://github.com/scout-analytics/ai-aas-hardened-lakehouse',
          label: 'GitHub',
          position: 'right',
        },
      ],
    },
    footer: {
      style: 'dark',
      links: [
        {
          title: 'Documentation',
          items: [
            {
              label: 'Data Model',
              to: '/docs/erd',
            },
            {
              label: 'Query Library',
              to: '/docs/queries',
            },
            {
              label: 'Implementation Guide',
              to: '/docs/implementation',
            },
          ],
        },
        {
          title: 'Resources',
          items: [
            {
              label: 'API Reference',
              href: 'https://supabase.com/docs',
            },
            {
              label: 'Edge Functions',
              to: '/docs/edge-functions',
            },
          ],
        },
        {
          title: 'Community',
          items: [
            {
              label: 'GitHub',
              href: 'https://github.com/scout-analytics',
            },
            {
              label: 'Discord',
              href: 'https://discord.gg/scout-analytics',
            },
          ],
        },
      ],
      copyright: \`Copyright © \${new Date().getFullYear()} Scout Analytics. Built with Docusaurus.\`,
    },
    prism: {
      theme: prismThemes.github,
      darkTheme: prismThemes.dracula,
      additionalLanguages: ['sql', 'bash', 'typescript'],
    },
  } satisfies Preset.ThemeConfig,
};

export default config;`;

  await fs.writeFile(configPath, newConfig);
}

// Main execution
async function main() {
  console.log('🚀 Scout Analytics Documentation Writer');
  console.log('=====================================\n');

  try {
    console.log('📝 Updating ERD with Scout schema...');
    await updateERD();
    
    console.log('🔧 Updating implementation guide...');
    await updateImplementation();
    
    console.log('🔍 Updating query library...');
    await updateQueries();
    
    console.log('🎨 Creating diagram templates...');
    await createDiagramTemplates();
    
    console.log('⚙️  Updating Docusaurus config...');
    await updateDocusaurusConfig();
    
    console.log('\n✅ Scout documentation transformation complete!');
    console.log('\nNext steps:');
    console.log('1. cd docs/neural-docs/scout-data-warehouse-docs');
    console.log('2. npm install');
    console.log('3. npm run dev');
    console.log('4. Create draw.io diagrams in static/diagrams/');
    
  } catch (error) {
    console.error('❌ Error:', error);
    process.exit(1);
  }
}

main();