// Scout Analytics Data Contracts
// This package provides type-safe interfaces for all data operations

export * from './types/database.types';
export * from './types/api.types';

// Contract version - bump on breaking changes
export const CONTRACT_VERSION = '1.0.0';

// View names that are part of the stable API
export const STABLE_VIEWS = {
  GOLD_REGION_CHOROPLETH: 'scout.gold_region_choropleth',
  GOLD_TXN_DAILY: 'scout.gold_txn_daily',
  GOLD_SKU_PERFORMANCE: 'scout.gold_sku_performance',
  GOLD_STORE_SUMMARY: 'scout.gold_store_summary'
} as const;

// Edge function endpoints
export const EDGE_FUNCTIONS = {
  INGEST_TRANSACTION: '/functions/v1/ingest-transaction',
  GENIE_QUERY: '/functions/v1/genie-query',
  EMBED_BATCH: '/functions/v1/embed-batch',
  INGEST_DOC: '/functions/v1/ingest-doc'
} as const;