-- ============================================================
-- Function: get_relevant_insights - Wire AI panel for Superset
-- Returns contextual AI insights based on user role and filters
-- ============================================================

CREATE OR REPLACE FUNCTION scout.get_relevant_insights(
  user_role TEXT DEFAULT 'analyst',
  filter_context JSONB DEFAULT NULL,
  limit_results INTEGER DEFAULT 5
)
RETURNS TABLE (
  insight_id UUID,
  insight_type TEXT,
  title TEXT,
  description TEXT,
  confidence_score NUMERIC,
  business_impact_score NUMERIC,
  recommended_actions JSONB,
  data_sources TEXT[],
  generated_at TIMESTAMP,
  expires_at TIMESTAMP
) AS $$
BEGIN
  RETURN QUERY
  WITH contextual_insights AS (
    -- Get AI insights relevant to user role and context
    SELECT 
      ai.insight_id,
      ai.insight_type,
      ai.title,
      ai.description,
      ai.confidence_score,
      ai.business_impact_score,
      ai.recommended_actions,
      ai.data_sources,
      ai.generated_at,
      ai.expires_at,
      -- Relevance scoring based on role and context
      CASE user_role
        WHEN 'brand_manager' THEN
          CASE 
            WHEN ai.insight_type IN ('brand_performance', 'competitive_analysis', 'substitution_patterns') THEN 1.0
            WHEN ai.insight_type IN ('market_trends', 'category_analysis') THEN 0.8
            ELSE 0.5
          END
        WHEN 'store_manager' THEN
          CASE 
            WHEN ai.insight_type IN ('store_performance', 'inventory_optimization', 'customer_behavior') THEN 1.0
            WHEN ai.insight_type IN ('product_recommendations', 'pricing_analysis') THEN 0.8
            ELSE 0.4
          END
        WHEN 'executive' THEN
          CASE 
            WHEN ai.insight_type IN ('business_summary', 'strategic_recommendations', 'market_opportunities') THEN 1.0
            WHEN ai.insight_type IN ('competitive_analysis', 'performance_trends') THEN 0.9
            ELSE 0.7
          END
        ELSE 0.6
      END * ai.business_impact_score AS relevance_score,
      -- Context matching
      CASE 
        WHEN filter_context IS NULL THEN 1.0
        WHEN filter_context ? 'category' AND ai.data_sources::TEXT ILIKE '%' || (filter_context->>'category') || '%' THEN 1.2
        WHEN filter_context ? 'brand' AND ai.data_sources::TEXT ILIKE '%' || (filter_context->>'brand') || '%' THEN 1.2
        WHEN filter_context ? 'region' AND ai.data_sources::TEXT ILIKE '%' || (filter_context->>'region') || '%' THEN 1.1
        ELSE 0.8
      END AS context_bonus
    FROM scout.platinum_ai_insights ai
    WHERE ai.generated_at >= NOW() - INTERVAL '24 hours'
      AND (ai.expires_at IS NULL OR ai.expires_at > NOW())
      AND ai.confidence_score >= 0.6
  ),
  -- Fallback insights if no AI insights available
  synthetic_insights AS (
    SELECT 
      gen_random_uuid() as insight_id,
      'performance_alert' as insight_type,
      'Performance Alert: ' || category as title,
      format('Category %s showing %s%% change in last 7 days vs previous week', 
             category, ROUND((current_week - prev_week) / prev_week * 100, 1)) as description,
      0.85 as confidence_score,
      CASE 
        WHEN ABS(current_week - prev_week) / prev_week > 0.2 THEN 0.9
        WHEN ABS(current_week - prev_week) / prev_week > 0.1 THEN 0.7
        ELSE 0.5
      END as business_impact_score,
      jsonb_build_object(
        'investigate', 'Review category performance drivers',
        'action', CASE 
          WHEN current_week > prev_week THEN 'Consider expanding successful strategies'
          ELSE 'Investigate potential issues and implement corrective measures'
        END
      ) as recommended_actions,
      ARRAY['fact_transactions', 'dim_categories'] as data_sources,
      NOW() as generated_at,
      NOW() + INTERVAL '7 days' as expires_at,
      CASE 
        WHEN ABS(current_week - prev_week) / prev_week > 0.2 THEN 1.0
        WHEN ABS(current_week - prev_week) / prev_week > 0.1 THEN 0.8
        ELSE 0.6
      END as relevance_score,
      1.0 as context_bonus
    FROM (
      SELECT 
        c.category_name as category,
        COALESCE(curr.weekly_revenue, 0) as current_week,
        COALESCE(prev.weekly_revenue, 0) as prev_week
      FROM scout.dim_categories c
      LEFT JOIN (
        SELECT 
          dc.category_name,
          SUM(ft.total_amount) as weekly_revenue
        FROM scout.fact_transactions ft
        JOIN scout.dim_stores ds ON ft.store_key = ds.store_key
        JOIN scout.dim_categories dc ON ft.category_id = dc.category_id
        WHERE ft.transaction_date >= CURRENT_DATE - INTERVAL '7 days'
        GROUP BY dc.category_name
      ) curr ON c.category_name = curr.category_name
      LEFT JOIN (
        SELECT 
          dc.category_name,
          SUM(ft.total_amount) as weekly_revenue
        FROM scout.fact_transactions ft
        JOIN scout.dim_stores ds ON ft.store_key = ds.store_key
        JOIN scout.dim_categories dc ON ft.category_id = dc.category_id
        WHERE ft.transaction_date >= CURRENT_DATE - INTERVAL '14 days'
          AND ft.transaction_date < CURRENT_DATE - INTERVAL '7 days'
        GROUP BY dc.category_name
      ) prev ON c.category_name = prev.category_name
      WHERE COALESCE(curr.weekly_revenue, 0) != COALESCE(prev.weekly_revenue, 0)
        AND COALESCE(prev.weekly_revenue, 0) > 0
    ) perf_changes
    WHERE ABS(current_week - prev_week) / prev_week > 0.05
  )
  -- Return prioritized insights
  SELECT 
    ci.insight_id,
    ci.insight_type,
    ci.title,
    ci.description,
    ci.confidence_score,
    ci.business_impact_score,
    ci.recommended_actions,
    ci.data_sources,
    ci.generated_at,
    ci.expires_at
  FROM contextual_insights ci
  WHERE ci.relevance_score * ci.context_bonus >= 0.5
  
  UNION ALL
  
  -- Add synthetic insights if needed to reach limit
  SELECT 
    si.insight_id,
    si.insight_type,
    si.title,
    si.description,
    si.confidence_score,
    si.business_impact_score,
    si.recommended_actions,
    si.data_sources,
    si.generated_at,
    si.expires_at
  FROM synthetic_insights si
  WHERE NOT EXISTS (
    SELECT 1 FROM contextual_insights 
    WHERE relevance_score * context_bonus >= 0.5
  )
  
  ORDER BY business_impact_score DESC, confidence_score DESC
  LIMIT limit_results;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create supporting view for Superset AI panel dataset
CREATE OR REPLACE VIEW scout.v_ai_panel_insights AS
SELECT 
  insight_id,
  insight_type,
  title,
  description,
  confidence_score,
  business_impact_score,
  recommended_actions,
  data_sources,
  generated_at,
  expires_at
FROM scout.get_relevant_insights('analyst', NULL, 10);

-- Grant permissions
GRANT EXECUTE ON FUNCTION scout.get_relevant_insights(TEXT, JSONB, INTEGER) TO authenticated;
GRANT SELECT ON scout.v_ai_panel_insights TO authenticated;

-- Test the function
DO $$
DECLARE
  insight_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO insight_count 
  FROM scout.get_relevant_insights('brand_manager', '{"category": "Beverages"}'::jsonb, 5);
  
  RAISE NOTICE 'AI Insights function test: % insights returned', insight_count;
END $$;