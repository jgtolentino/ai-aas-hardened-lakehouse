// API types for Scout Analytics platform

export interface ApiResponse<T = any> {
  data: T
  success: boolean
  message?: string
  error?: string
}

export interface PaginatedResponse<T = any> {
  data: T[]
  pagination: {
    page: number
    limit: number
    total: number
    pages: number
  }
  success: boolean
}

// Consumer Segments
export interface ConsumerSegment {
  id: string
  segment_name: string
  description?: string
  created_at: string
  updated_at: string
}

// Regional Performance
export interface RegionalPerformance {
  id: string
  region: string
  performance_score: number
  created_at: string
  updated_at: string
}

// Competitive Intelligence
export interface CompetitiveIntelligence {
  id: string
  competitor_name: string
  market_share?: number
  analysis_data?: any
  created_at: string
  updated_at: string
}

// Behavioral Analytics
export interface BehavioralAnalytics {
  id: string
  behavior_type: string
  analytics_data: any
  user_segment?: string
  created_at: string
  updated_at: string
}

// API Endpoints
export interface ApiEndpoints {
  consumerSegments: string
  regionalPerformance: string
  competitiveIntelligence: string
  behavioralAnalytics: string
}

// Query Parameters
export interface QueryParams {
  limit?: number
  offset?: number
  orderBy?: string
  orderDirection?: 'asc' | 'desc'
  filters?: Record<string, any>
}

// Edge Function Types
export interface EdgeFunctionRequest<T = any> {
  data: T
  timestamp: string
  source?: string
}

export interface EdgeFunctionResponse<T = any> {
  success: boolean
  data?: T
  error?: {
    message: string
    code?: string
    details?: any
  }
  timestamp: string
}