/**
 * AI Components
 * Export all AI-related components for the Scout Dashboard
 */

export { RecommendationPanel } from './RecommendationPanel';
export { FeatureFlagToggle } from './FeatureFlagToggle';
export { ExplanationTooltip } from './ExplanationTooltip';
export type { Recommendation } from './RecommendationPanel';

// Re-export hooks
export { useRecommendations, useRecommendationFeatures } from '../../hooks/useRecommendations';

// Re-export utilities
export { 
  RecommendationsAPI,
  RecommendationUtils,
  RateLimiter,
  recommendationsAPI,
  rateLimiter
} from '../../lib/ai/recommendations';

// Re-export CSV export utilities
export {
  csvExporter,
  exportRecommendationsToCSV
} from '../../lib/exports/csvExporter';

export {
  ExportButton,
  RecommendationExportButton
} from '../ui/export-button';

export type {
  RecommendationAPIResponse,
  RecommendationFilters,
  ActionExecutionRequest,
  ActionExecutionResponse,
  RecommendationsError,
  RateLimitError
} from '../../lib/ai/recommendations';