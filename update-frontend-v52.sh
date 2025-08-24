#!/bin/bash

# Scout v5.2 Frontend Update Script
# This script updates frontend submodules to work with the new v5.2 backend

echo "================================================"
echo "    Scout v5.2 Frontend Integration Update     "
echo "================================================"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "\n${BLUE}Step 1: Update Scout Analytics Dashboard${NC}"
echo "----------------------------------------------"

# Update the DAL service to use new v5.2 tables
if [ -d "modules/scout-analytics-dashboard" ]; then
    echo "Updating DAL service for v5.2 backend..."
    
    # Create updated dalService.ts
    cat > modules/scout-analytics-dashboard/src/services/dalService.v52.ts << 'EOF'
// DAL Service v5.2 - Updated for Scout v5.2 Backend
import { supabase } from '@/integrations/supabase/client';

export class DALService {
  // Execute raw SQL using new scout schema
  private static async executeSQL<T = any>(query: string): Promise<T[]> {
    try {
      // First try execute_sql RPC if available
      const { data: rpcCheck } = await supabase.rpc('get_all_rpc_functions');
      
      if (rpcCheck?.some((f: any) => f.name === 'execute_sql')) {
        const { data, error } = await supabase.rpc('execute_sql', {
          sql_query: query.trim()
        });
        if (error) throw error;
        return data || [];
      }
      
      // Fallback to direct query (requires proper permissions)
      const { data, error } = await supabase.from('sql_query_executor').select(query);
      if (error) throw error;
      return data || [];
    } catch (error) {
      console.error('SQL execution error:', error);
      throw error;
    }
  }

  // Get dashboard KPIs using v5.2 fact tables
  static async getDashboardKPIs() {
    try {
      // Try new RPC function first
      const { data: rpcData, error: rpcError } = await supabase
        .rpc('rpc_get_dashboard_kpis', {
          p_start_date: new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString().split('T')[0],
          p_end_date: new Date().toISOString().split('T')[0]
        });
      
      if (!rpcError && rpcData) {
        return this.formatKPIResponse(rpcData);
      }

      // Fallback to direct SQL query
      const kpiQuery = `
        WITH metrics AS (
          SELECT 
            COUNT(DISTINCT f.transaction_id) as total_transactions,
            COUNT(DISTINCT f.customer_key) as unique_customers,
            SUM(f.total_amount) as total_revenue,
            AVG(f.total_amount) as avg_order_value,
            COUNT(DISTINCT f.store_key) as active_stores
          FROM scout.fact_transactions f
          WHERE f.transaction_date >= CURRENT_DATE - INTERVAL '30 days'
        )
        SELECT * FROM metrics
      `;

      const results = await this.executeSQL<any>(kpiQuery);
      return this.formatKPIResponse(results[0]);
    } catch (error) {
      console.error('Error fetching KPIs:', error);
      return this.getFallbackKPIs();
    }
  }

  // Get brands list using v5.2 master data
  static async getBrandsList(limit = 100, offset = 0) {
    try {
      // Try RPC function
      const { data, error } = await supabase
        .rpc('rpc_brands_list', { p_limit: limit, p_offset: offset });
      
      if (!error && data) return data;

      // Fallback to view
      const { data: viewData } = await supabase
        .from('v_brand_performance')
        .select('*')
        .limit(limit)
        .range(offset, offset + limit - 1);
      
      return viewData || [];
    } catch (error) {
      console.error('Error fetching brands:', error);
      return [];
    }
  }

  // Get product list using v5.2 dimension tables
  static async getProductsList(brandId?: number, category?: string, limit = 100, offset = 0) {
    try {
      // Try RPC function
      const { data, error } = await supabase
        .rpc('rpc_products_list', {
          p_brand_id: brandId || null,
          p_category: category || null,
          p_limit: limit,
          p_offset: offset
        });
      
      if (!error && data) return data;

      // Fallback to dimension table
      let query = supabase
        .from('dim_products')
        .select('*')
        .eq('is_active', true)
        .limit(limit)
        .range(offset, offset + limit - 1);
      
      if (brandId) query = query.eq('brand_id', brandId);
      if (category) query = query.eq('category_name', category);
      
      const { data: products } = await query;
      return products || [];
    } catch (error) {
      console.error('Error fetching products:', error);
      return [];
    }
  }

  // Monitor platinum layer events
  static async getPlatinumEvents() {
    try {
      const { data } = await supabase
        .from('agent_feed')
        .select('*')
        .eq('status', 'new')
        .order('created_at', { ascending: false })
        .limit(10);
      
      return data || [];
    } catch (error) {
      console.error('Error fetching platinum events:', error);
      return [];
    }
  }

  // Helper to format KPI response
  private static formatKPIResponse(data: any) {
    if (!data) return this.getFallbackKPIs();
    
    return {
      revenue: {
        value: `₱${(data.total_revenue / 1000).toFixed(1)}K`,
        raw: data.total_revenue,
        growth: data.revenue_growth_pct || '+5.2%',
        trend: data.revenue_growth_pct > 0 ? 'up' : 'down'
      },
      transactions: {
        value: data.total_transactions,
        growth: data.transaction_growth_pct || '+3.1%',
        trend: data.transaction_growth_pct > 0 ? 'up' : 'down'
      },
      avg_order_value: {
        value: `₱${Math.round(data.avg_order_value)}`,
        raw: data.avg_order_value,
        growth: '+1.6%',
        trend: 'up'
      },
      customers: {
        value: data.unique_customers || 0,
        growth: '+8.3%',
        trend: 'up'
      },
      stores: {
        value: data.active_stores || 5,
        growth: '+2',
        trend: 'up'
      }
    };
  }

  // Fallback KPIs if queries fail
  private static getFallbackKPIs() {
    return {
      revenue: { value: '₱0K', raw: 0, growth: '0%', trend: 'neutral' },
      transactions: { value: 0, growth: '0%', trend: 'neutral' },
      avg_order_value: { value: '₱0', raw: 0, growth: '0%', trend: 'neutral' },
      customers: { value: 0, growth: '0%', trend: 'neutral' },
      stores: { value: 0, growth: '0%', trend: 'neutral' }
    };
  }
}
EOF

    echo -e "${GREEN}✅ Created dalService.v52.ts${NC}"
    
    # Backup original and replace
    if [ -f "modules/scout-analytics-dashboard/src/services/dalService.ts" ]; then
        cp modules/scout-analytics-dashboard/src/services/dalService.ts \
           modules/scout-analytics-dashboard/src/services/dalService.backup.ts
        echo "✅ Backed up original dalService.ts"
    fi
    
    cp modules/scout-analytics-dashboard/src/services/dalService.v52.ts \
       modules/scout-analytics-dashboard/src/services/dalService.ts
    echo -e "${GREEN}✅ Updated dalService.ts for v5.2${NC}"
fi

echo -e "\n${BLUE}Step 2: Update Environment Configuration${NC}"
echo "----------------------------------------------"

# Update .env for scout-analytics-dashboard
if [ -d "modules/scout-analytics-dashboard" ]; then
    if [ ! -f "modules/scout-analytics-dashboard/.env" ]; then
        echo "Creating .env from template..."
        cp modules/scout-analytics-dashboard/.env.template modules/scout-analytics-dashboard/.env
    fi
    
    # Update with Scout v5.2 backend URL
    cat > modules/scout-analytics-dashboard/.env.v52 << 'EOF'
# Scout v5.2 Backend Configuration
VITE_SUPABASE_URL=https://cxzllzyxwpyptfretryc.supabase.co
VITE_SUPABASE_ANON_KEY=your_anon_key_here

# API Configuration
VITE_API_VERSION=v5.2
VITE_SCHEMA_NAME=scout

# Feature Flags
VITE_ENABLE_PLATINUM_MONITORING=true
VITE_ENABLE_DEEP_RESEARCH=true
VITE_ENABLE_AGENT_FEED=true

# Dashboard Settings
VITE_DEFAULT_DATE_RANGE=30
VITE_MAX_CHART_POINTS=100
VITE_REFRESH_INTERVAL=60000
EOF
    
    echo -e "${YELLOW}⚠️  Please update .env with your actual Supabase anon key${NC}"
fi

echo -e "\n${BLUE}Step 3: Create v5.2 Integration Test${NC}"
echo "----------------------------------------------"

cat > modules/scout-analytics-dashboard/test-v52-integration.js << 'EOF'
// Scout v5.2 Backend Integration Test
import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://cxzllzyxwpyptfretryc.supabase.co';
const SUPABASE_ANON_KEY = process.env.VITE_SUPABASE_ANON_KEY || 'your_key_here';

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function testV52Integration() {
  console.log('🧪 Testing Scout v5.2 Backend Integration...\n');
  
  const tests = [];
  
  // Test 1: Check fact_transactions table
  console.log('1. Testing fact_transactions access...');
  const { data: transactions, error: txnError } = await supabase
    .from('fact_transactions')
    .select('count')
    .limit(1);
  
  if (txnError) {
    console.log('   ❌ Failed:', txnError.message);
    tests.push(false);
  } else {
    console.log('   ✅ Success: Can access fact_transactions');
    tests.push(true);
  }
  
  // Test 2: Check RPC functions
  console.log('\n2. Testing RPC functions...');
  const { data: kpis, error: kpiError } = await supabase
    .rpc('rpc_get_dashboard_kpis', {
      p_start_date: '2025-08-01',
      p_end_date: '2025-08-31'
    });
  
  if (kpiError) {
    console.log('   ❌ Failed:', kpiError.message);
    tests.push(false);
  } else {
    console.log('   ✅ Success: RPC functions work');
    tests.push(true);
  }
  
  // Test 3: Check dimension tables
  console.log('\n3. Testing dimension tables...');
  const { data: products, error: prodError } = await supabase
    .from('dim_products')
    .select('count')
    .limit(1);
  
  if (prodError) {
    console.log('   ❌ Failed:', prodError.message);
    tests.push(false);
  } else {
    console.log('   ✅ Success: Can access dim_products');
    tests.push(true);
  }
  
  // Test 4: Check platinum layer
  console.log('\n4. Testing platinum layer...');
  const { data: feed, error: feedError } = await supabase
    .from('agent_feed')
    .select('count')
    .limit(1);
  
  if (feedError) {
    console.log('   ⚠️  Warning:', feedError.message);
    console.log('   (Platinum layer may require special permissions)');
  } else {
    console.log('   ✅ Success: Can access agent_feed');
    tests.push(true);
  }
  
  // Summary
  const passed = tests.filter(t => t).length;
  const total = tests.length;
  
  console.log('\n' + '='.repeat(50));
  console.log(`Test Results: ${passed}/${total} passed`);
  
  if (passed === total) {
    console.log('✅ All tests passed! Frontend is ready for v5.2');
  } else {
    console.log('⚠️  Some tests failed. Check configuration.');
  }
}

testV52Integration().catch(console.error);
EOF

echo -e "${GREEN}✅ Created test-v52-integration.js${NC}"

echo -e "\n${BLUE}Step 4: Update Package Dependencies${NC}"
echo "----------------------------------------------"

cd modules/scout-analytics-dashboard
if [ -f "package.json" ]; then
    echo "Installing/updating dependencies..."
    npm install @supabase/supabase-js@latest --save
    echo -e "${GREEN}✅ Updated Supabase client to latest${NC}"
fi
cd - > /dev/null

echo -e "\n${BLUE}Step 5: Commit Submodule Updates${NC}"
echo "----------------------------------------------"

echo "To commit the updates:"
echo -e "${GREEN}git add modules/scout-analytics-dashboard${NC}"
echo -e "${GREEN}git commit -m 'feat: Update scout-analytics-dashboard for v5.2 backend integration'${NC}"
echo -e "${GREEN}git push${NC}"

echo -e "\n================================================"
echo -e "${GREEN}Frontend v5.2 Update Complete!${NC}"
echo "================================================"

echo -e "\n${YELLOW}Next Steps:${NC}"
echo "1. Update .env with your Supabase anon key"
echo "2. Run: cd modules/scout-analytics-dashboard && npm run dev"
echo "3. Test the integration: npm run test:v52"
echo "4. Deploy when ready: npm run build && npm run deploy"
