// Auto-generated database types for Scout Analytics
// Generated from Supabase schema

export interface Database {
  public: {
    Tables: {
      consumer_segments: {
        Row: {
          id: string
          segment_name: string
          description: string | null
          created_at: string
          updated_at: string
        }
        Insert: {
          id?: string
          segment_name: string
          description?: string | null
          created_at?: string
          updated_at?: string
        }
        Update: {
          id?: string
          segment_name?: string
          description?: string | null
          created_at?: string
          updated_at?: string
        }
      }
      regional_performance: {
        Row: {
          id: string
          region: string
          performance_score: number
          created_at: string
          updated_at: string
        }
        Insert: {
          id?: string
          region: string
          performance_score: number
          created_at?: string
          updated_at?: string
        }
        Update: {
          id?: string
          region?: string
          performance_score?: number
          created_at?: string
          updated_at?: string
        }
      }
      competitive_intelligence: {
        Row: {
          id: string
          competitor_name: string
          market_share: number | null
          analysis_data: any | null
          created_at: string
          updated_at: string
        }
        Insert: {
          id?: string
          competitor_name: string
          market_share?: number | null
          analysis_data?: any | null
          created_at?: string
          updated_at?: string
        }
        Update: {
          id?: string
          competitor_name?: string
          market_share?: number | null
          analysis_data?: any | null
          created_at?: string
          updated_at?: string
        }
      }
      behavioral_analytics: {
        Row: {
          id: string
          behavior_type: string
          analytics_data: any
          user_segment: string | null
          created_at: string
          updated_at: string
        }
        Insert: {
          id?: string
          behavior_type: string
          analytics_data: any
          user_segment?: string | null
          created_at?: string
          updated_at?: string
        }
        Update: {
          id?: string
          behavior_type?: string
          analytics_data?: any
          user_segment?: string | null
          created_at?: string
          updated_at?: string
        }
      }
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      [_ in never]: never
    }
    Enums: {
      [_ in never]: never
    }
  }
}