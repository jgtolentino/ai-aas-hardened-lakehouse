// Data Abstraction Layer (DAL) for Scout v5.2
// All functions MUST only query from gold_* or platinum_* layers

import { createClient } from '@supabase/supabase-js';

const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
);

// ==================================
// GOLD LAYER FUNCTIONS
// ==================================

export async function getGoldAnalytics(filters?: any) {
  const { data, error } = await supabase
    .from('gold_analytics')
    .select('*')
    .match(filters || {});
  
  if (error) throw new Error(`Gold Analytics Error: ${error.message}`);
  return data;
}

export async function getGoldBasket(filters?: any) {
  const { data, error } = await supabase
    .from('gold_basket')
    .select('*')
    .match(filters || {});
  
  if (error) throw new Error(`Gold Basket Error: ${error.message}`);
  return data;
}

export async function getGoldBrandShare(filters?: any) {
  const { data, error } = await supabase
    .from('gold_brand_share')
    .select('*')
    .match(filters || {});
  
  if (error) throw new Error(`Gold Brand Share Error: ${error.message}`);
  return data;
}

export async function getGoldCategoryBrand(filters?: any) {
  const { data, error } = await supabase
    .from('gold_category_brand')
    .select('*')
    .match(filters || {});
  
  if (error) throw new Error(`Gold Category Brand Error: ${error.message}`);
  return data;
}

export async function getGoldChannelActivity(filters?: any) {
  const { data, error } = await supabase
    .from('gold_channel_activity')
    .select('*')
    .match(filters || {});
  
  if (error) throw new Error(`Gold Channel Activity Error: ${error.message}`);
  return data;
}

export async function getGoldCompetitiveShare(filters?: any) {
  const { data, error } = await supabase
    .from('gold_competitive_share_daily')
    .select('*')
    .match(filters || {});
  
  if (error) throw new Error(`Gold Competitive Share Error: ${error.message}`);
  return data;
}

export async function getGoldConsumerSignals(filters?: any) {
  const { data, error } = await supabase
    .from('gold_consumer_signals')
    .select('*')
    .match(filters || {});
  
  if (error) throw new Error(`Gold Consumer Signals Error: ${error.message}`);
  return data;
}

export async function getGoldCustomerActivity(filters?: any) {
  const { data, error } = await supabase
    .from('gold_customer_activity')
    .select('*')
    .match(filters || {});
  
  if (error) throw new Error(`Gold Customer Activity Error: ${error.message}`);
  return data;
}

export async function getGoldCustomerSegments(filters?: any) {
  const { data, error } = await supabase
    .from('gold_customer_segments')
    .select('*')
    .match(filters || {});
  
  if (error) throw new Error(`Gold Customer Segments Error: ${error.message}`);
  return data;
}

export async function getGoldDemographics(filters?: any) {
  const { data, error } = await supabase
    .from('gold_demographics')
    .select('*')
    .match(filters || {});
  
  if (error) throw new Error(`Gold Demographics Error: ${error.message}`);
  return data;
}

export async function getGoldExecutiveKPIs(filters?: any) {
  const { data, error } = await supabase
    .from('gold_executive_kpis')
    .select('*')
    .match(filters || {});
  
  if (error) throw new Error(`Gold Executive KPIs Error: ${error.message}`);
  return data;
}

export async function getGoldGeo(filters?: any) {
  const { data, error } = await supabase
    .from('gold_geo')
    .select('*')
    .match(filters || {});
  
  if (error) throw new Error(`Gold Geo Error: ${error.message}`);
  return data;
}

export async function getGoldGeoChoropleth(filters?: any) {
  const { data, error } = await supabase
    .from('gold_geo_choropleth_latest')
    .select('*')
    .match(filters || {});
  
  if (error) throw new Error(`Gold Geo Choropleth Error: ${error.message}`);
  return data;
}

export async function getGoldKPIDaily(filters?: any) {
  const { data, error } = await supabase
    .from('gold_kpi_daily')
    .select('*')
    .match(filters || {});
  
  if (error) throw new Error(`Gold KPI Daily Error: ${error.message}`);
  return data;
}

export async function getGoldMonthlyChurn(filters?: any) {
  const { data, error } = await supabase
    .from('gold_monthly_churn_metrics')
    .select('*')
    .match(filters || {});
  
  if (error) throw new Error(`Gold Monthly Churn Error: ${error.message}`);
  return data;
}

export async function getGoldNLCustomerSummary(filters?: any) {
  const { data, error } = await supabase
    .from('gold_nl_customer_summary')
    .select('*')
    .match(filters || {});
  
  if (error) throw new Error(`Gold NL Customer Summary Error: ${error.message}`);
  return data;
}

export async function getGoldOverviewKPIs(filters?: any) {
  const { data, error } = await supabase
    .from('gold_overview_kpis')
    .select('*')
    .match(filters || {});
  
  if (error) throw new Error(`Gold Overview KPIs Error: ${error.message}`);
  return data;
}

export async function getGoldPersonaRegion(filters?: any) {
  const { data, error } = await supabase
    .from('gold_persona_region_metrics')
    .select('*')
    .match(filters || {});
  
  if (error) throw new Error(`Gold Persona Region Error: ${error.message}`);
  return data;
}

export async function getGoldPersonaTrajectory(filters?: any) {
  const { data, error } = await supabase
    .from('gold_persona_trajectory_timelines')
    .select('*')
    .match(filters || {});
  
  if (error) throw new Error(`Gold Persona Trajectory Error: ${error.message}`);
  return data;
}

export async function getGoldProductCatalog(filters?: any) {
  const { data, error } = await supabase
    .from('gold_product_catalog')
    .select('*')
    .match(filters || {});
  
  if (error) throw new Error(`Gold Product Catalog Error: ${error.message}`);
  return data;
}

export async function getGoldProductPerformance(filters?: any) {
  const { data, error } = await supabase
    .from('gold_product_performance')
    .select('*')
    .match(filters || {});
  
  if (error) throw new Error(`Gold Product Performance Error: ${error.message}`);
  return data;
}

export async function getGoldSalesByBrand(filters?: any) {
  const { data, error } = await supabase
    .from('gold_sales_by_brand')
    .select('*')
    .match(filters || {});
  
  if (error) throw new Error(`Gold Sales by Brand Error: ${error.message}`);
  return data;
}

export async function getGoldSalesByRegion(filters?: any) {
  const { data, error } = await supabase
    .from('gold_sales_by_region_city_barangay')
    .select('*')
    .match(filters || {});
  
  if (error) throw new Error(`Gold Sales by Region Error: ${error.message}`);
  return data;
}

export async function getGoldSalesByStore(filters?: any) {
  const { data, error } = await supabase
    .from('gold_sales_by_store')
    .select('*')
    .match(filters || {});
  
  if (error) throw new Error(`Gold Sales by Store Error: ${error.message}`);
  return data;
}

export async function getGoldStorePerformance(filters?: any) {
  const { data, error } = await supabase
    .from('gold_store_performance')
    .select('*')
    .match(filters || {});
  
  if (error) throw new Error(`Gold Store Performance Error: ${error.message}`);
  return data;
}

export async function getGoldStoresHeatmap(filters?: any) {
  const { data, error } = await supabase
    .from('gold_stores_heatmap')
    .select('*')
    .match(filters || {});
  
  if (error) throw new Error(`Gold Stores Heatmap Error: ${error.message}`);
  return data;
}

export async function getGoldTransactionDuration(filters?: any) {
  const { data, error } = await supabase
    .from('gold_transaction_duration')
    .select('*')
    .match(filters || {});
  
  if (error) throw new Error(`Gold Transaction Duration Error: ${error.message}`);
  return data;
}

// ==================================
// PLATINUM LAYER FUNCTIONS
// ==================================

export async function getPlatinumPredictions(filters?: any) {
  const { data, error } = await supabase
    .from('platinum_predictions')
    .select('*')
    .match(filters || {});
  
  if (error) throw new Error(`Platinum Predictions Error: ${error.message}`);
  return data;
}

export async function getPlatinumBasketCombos(filters?: any) {
  const { data, error } = await supabase
    .from('platinum_basket_combos')
    .select('*')
    .match(filters || {});
  
  if (error) throw new Error(`Platinum Basket Combos Error: ${error.message}`);
  return data;
}

export async function getPlatinumExpertInsights(filters?: any) {
  const { data, error } = await supabase
    .from('platinum_expert_insights')
    .select('*')
    .match(filters || {});
  
  if (error) throw new Error(`Platinum Expert Insights Error: ${error.message}`);
  return data;
}

export async function getPlatinumPersonaInsights(filters?: any) {
  const { data, error } = await supabase
    .from('platinum_persona_insights')
    .select('*')
    .match(filters || {});
  
  if (error) throw new Error(`Platinum Persona Insights Error: ${error.message}`);
  return data;
}

export async function getPlatinumRecommendations(filters?: any) {
  const { data, error } = await supabase
    .from('platinum_recommendations')
    .select('*')
    .match(filters || {});
  
  if (error) throw new Error(`Platinum Recommendations Error: ${error.message}`);
  return data;
}

// ==================================
// MODULAR INTERFACE
// ==================================

export const gold = {
  analytics: { fetch: getGoldAnalytics },
  basket: { fetch: getGoldBasket },
  brandShare: { fetch: getGoldBrandShare },
  categoryBrand: { fetch: getGoldCategoryBrand },
  channelActivity: { fetch: getGoldChannelActivity },
  competitiveShare: { fetch: getGoldCompetitiveShare },
  consumerSignals: { fetch: getGoldConsumerSignals },
  customerActivity: { fetch: getGoldCustomerActivity },
  customerSegments: { fetch: getGoldCustomerSegments },
  demographics: { fetch: getGoldDemographics },
  executiveKPIs: { fetch: getGoldExecutiveKPIs },
  geo: { fetch: getGoldGeo },
  geoChoropleth: { fetch: getGoldGeoChoropleth },
  kpiDaily: { fetch: getGoldKPIDaily },
  monthlyChurn: { fetch: getGoldMonthlyChurn },
  nlCustomerSummary: { fetch: getGoldNLCustomerSummary },
  overviewKPIs: { fetch: getGoldOverviewKPIs },
  personaRegion: { fetch: getGoldPersonaRegion },
  personaTrajectory: { fetch: getGoldPersonaTrajectory },
  productCatalog: { fetch: getGoldProductCatalog },
  productPerformance: { fetch: getGoldProductPerformance },
  salesByBrand: { fetch: getGoldSalesByBrand },
  salesByRegion: { fetch: getGoldSalesByRegion },
  salesByStore: { fetch: getGoldSalesByStore },
  storePerformance: { fetch: getGoldStorePerformance },
  storesHeatmap: { fetch: getGoldStoresHeatmap },
  transactionDuration: { fetch: getGoldTransactionDuration }
};

export const platinum = {
  predictions: { fetch: getPlatinumPredictions },
  basketCombos: { fetch: getPlatinumBasketCombos },
  expertInsights: { fetch: getPlatinumExpertInsights },
  personaInsights: { fetch: getPlatinumPersonaInsights },
  recommendations: { fetch: getPlatinumRecommendations }
};
