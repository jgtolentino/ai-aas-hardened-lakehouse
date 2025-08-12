/**
 * Scout Analytics Gold Views Integration Test
 * 
 * This script demonstrates how to use the Gold layer views
 * with the Scout Analytics DAL service in a submodule setup
 */

import { createClient } from '@supabase/supabase-js';

// Initialize Supabase client
const supabaseUrl = process.env.SUPABASE_URL || 'https://cxzllzyxwpyptfretryc.supabase.co';
const supabaseKey = process.env.SUPABASE_ANON_KEY || 'your-anon-key';
const supabase = createClient(supabaseUrl, supabaseKey);

/**
 * Simplified DAL Service using Gold Views
 */
class GoldViewsDAL {
  /**
   * Get executive dashboard KPIs
   */
  async getDashboardKPIs() {
    const { data, error } = await supabase
      .from('gold_dashboard_kpis')
      .select('*')
      .single();

    if (error) throw error;
    return data;
  }

  /**
   * Get top products by performance
   */
  async getTopProducts(limit = 10) {
    const { data, error } = await supabase
      .from('gold_product_performance')
      .select('*')
      .order('revenue_rank', { ascending: true })
      .limit(limit);

    if (error) throw error;
    return data;
  }

  /**
   * Get products by category
   */
  async getProductsByCategory(category: string, limit = 20) {
    const { data, error } = await supabase
      .from('gold_product_performance')
      .select('*')
      .eq('category_name', category)
      .order('revenue', { ascending: false })
      .limit(limit);

    if (error) throw error;
    return data;
  }

  /**
   * Get campaign effectiveness data
   */
  async getCampaignROI(minROI = 0) {
    const { data, error } = await supabase
      .from('gold_campaign_effectiveness')
      .select('*')
      .gte('roi_percentage', minROI)
      .order('roi_percentage', { ascending: false });

    if (error) throw error;
    return data;
  }

  /**
   * Get customer segments analysis
   */
  async getCustomerSegments(filters?: {
    segment?: string;
    tier?: string;
    recencyStatus?: string;
  }) {
    let query = supabase.from('gold_customer_segments').select('*');

    if (filters?.segment) {
      query = query.eq('customer_segment', filters.segment);
    }
    if (filters?.tier) {
      query = query.eq('customer_tier', filters.tier);
    }
    if (filters?.recencyStatus) {
      query = query.eq('recency_status', filters.recencyStatus);
    }

    const { data, error } = await query.order('total_spent', { ascending: false });

    if (error) throw error;
    return data;
  }

  /**
   * Get store performance by region
   */
  async getStorePerformance(region?: string) {
    let query = supabase
      .from('gold_store_performance')
      .select('*');

    if (region) {
      query = query.eq('region', region);
    }

    const { data, error } = await query.order('total_revenue', { ascending: false });

    if (error) throw error;
    return data;
  }

  /**
   * Get sales trends for date range
   */
  async getSalesTrends(days = 30) {
    const startDate = new Date();
    startDate.setDate(startDate.getDate() - days);

    const { data, error } = await supabase
      .from('gold_sales_trends')
      .select('*')
      .gte('sale_date', startDate.toISOString().split('T')[0])
      .order('sale_date', { ascending: false });

    if (error) throw error;
    return data;
  }

  /**
   * Get inventory items needing reorder
   */
  async getReorderAlerts() {
    const { data, error } = await supabase
      .from('gold_inventory_analysis')
      .select('*')
      .in('reorder_recommendation', ['Reorder Now', 'Reorder Soon'])
      .order('inventory_value', { ascending: false });

    if (error) throw error;
    return data;
  }

  /**
   * Get category insights
   */
  async getCategoryInsights(department?: string) {
    let query = supabase
      .from('gold_category_insights')
      .select('*');

    if (department) {
      query = query.eq('department', department);
    }

    const { data, error } = await query.order('revenue', { ascending: false });

    if (error) throw error;
    return data;
  }

  /**
   * Get geographic performance summary
   */
  async getGeographicSummary() {
    const { data, error } = await supabase
      .from('gold_geographic_summary')
      .select('*')
      .order('revenue_rank', { ascending: true });

    if (error) throw error;
    return data;
  }

  /**
   * Get peak hours analysis
   */
  async getPeakHours() {
    const { data, error } = await supabase
      .from('gold_time_series_metrics')
      .select('hour_of_day, hour_classification, AVG(revenue) as avg_revenue, AVG(transactions) as avg_transactions')
      .eq('hour_classification', 'Peak Hour')
      .order('hour_of_day');

    if (error) throw error;
    return data;
  }

  /**
   * Execute raw SQL for complex queries
   */
  async executeSQL(query: string) {
    const { data, error } = await supabase.rpc('execute_sql', { query });
    
    if (error) throw error;
    return data;
  }
}

// Example usage
async function demonstrateGoldViews() {
  const dal = new GoldViewsDAL();

  try {
    console.log('🚀 Scout Analytics Gold Views Integration Demo\n');

    // 1. Dashboard KPIs
    console.log('1. Executive Dashboard KPIs:');
    const kpis = await dal.getDashboardKPIs();
    console.log(`   Total Revenue: $${kpis.total_revenue?.toLocaleString()}`);
    console.log(`   Unique Customers: ${kpis.unique_customers?.toLocaleString()}`);
    console.log(`   Revenue Growth: ${kpis.revenue_growth_pct}%`);
    console.log(`   Low Stock Items: ${kpis.low_stock_items}\n`);

    // 2. Top Products
    console.log('2. Top 5 Products by Revenue:');
    const topProducts = await dal.getTopProducts(5);
    topProducts.forEach(product => {
      console.log(`   ${product.revenue_rank}. ${product.product_name} - $${product.revenue?.toLocaleString()}`);
    });
    console.log('');

    // 3. Campaign ROI
    console.log('3. High ROI Campaigns (>100%):');
    const campaigns = await dal.getCampaignROI(100);
    campaigns.slice(0, 3).forEach(campaign => {
      console.log(`   ${campaign.campaign_name}: ${campaign.roi_percentage}% ROI`);
    });
    console.log('');

    // 4. VIP Customers
    console.log('4. VIP Customer Segments:');
    const vipCustomers = await dal.getCustomerSegments({ tier: 'VIP' });
    console.log(`   Total VIP Customers: ${vipCustomers.length}`);
    console.log(`   Avg VIP Spend: $${(vipCustomers.reduce((sum, c) => sum + c.total_spent, 0) / vipCustomers.length).toFixed(2)}\n`);

    // 5. Regional Performance
    console.log('5. Store Performance by Region:');
    const stores = await dal.getStorePerformance();
    const regionSummary = stores.reduce((acc, store) => {
      if (!acc[store.region]) {
        acc[store.region] = { revenue: 0, stores: 0 };
      }
      acc[store.region].revenue += store.total_revenue;
      acc[store.region].stores += 1;
      return acc;
    }, {} as Record<string, { revenue: number; stores: number }>);

    Object.entries(regionSummary).forEach(([region, data]) => {
      console.log(`   ${region}: ${data.stores} stores, $${data.revenue.toLocaleString()} revenue`);
    });
    console.log('');

    // 6. Inventory Alerts
    console.log('6. Inventory Reorder Alerts:');
    const reorderItems = await dal.getReorderAlerts();
    console.log(`   Items needing reorder: ${reorderItems.length}`);
    console.log(`   Total value at risk: $${reorderItems.reduce((sum, item) => sum + item.inventory_value, 0).toLocaleString()}\n`);

    // 7. Sales Trends (Last 7 days)
    console.log('7. Sales Trend (Last 7 Days):');
    const trends = await dal.getSalesTrends(7);
    const weekTotal = trends.reduce((sum, day) => sum + day.revenue, 0);
    console.log(`   Week Total Revenue: $${weekTotal.toLocaleString()}`);
    console.log(`   Daily Average: $${(weekTotal / 7).toLocaleString()}\n`);

    console.log('✅ Gold Views integration test complete!');

  } catch (error) {
    console.error('❌ Error:', error);
  }
}

// Run the demo if this file is executed directly
if (require.main === module) {
  demonstrateGoldViews();
}

// Export for use as a module
export { GoldViewsDAL };
export default GoldViewsDAL;