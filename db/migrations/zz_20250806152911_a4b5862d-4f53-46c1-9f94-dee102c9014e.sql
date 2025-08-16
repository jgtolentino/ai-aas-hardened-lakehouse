-- Drop existing functions and recreate with v5.2 structure
DROP FUNCTION IF EXISTS scout.platinum_executive_dashboard_api();
DROP FUNCTION IF EXISTS scout.gold_campaign_effect_api();
DROP FUNCTION IF EXISTS scout.gold_customer_activity_api();
DROP FUNCTION IF EXISTS scout.gold_basket_analysis_api();
DROP FUNCTION IF EXISTS scout.deep_research_analyze_api(TEXT);

-- Create v5.2 API functions that match your frontend expectations

-- 1. Scout Gold Campaign Effect API
CREATE OR REPLACE FUNCTION scout.gold_campaign_effect_api()
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
BEGIN
  RETURN (
    SELECT json_build_object(
      'campaign_effectiveness', json_agg(
        json_build_object(
          'campaign_name', campaign_name,
          'brand', brand,
          'roi_multiplier', COALESCE(roi_multiplier, 0),
          'sales_uplift_percentage', COALESCE(sales_uplift_percentage, 0),
          'ces_score', COALESCE(ces_score, 0),
          'year', year,
          'award_status', award_status
        )
      ),
      'summary', json_build_object(
        'total_campaigns', COUNT(*),
        'avg_roi', ROUND(AVG(COALESCE(roi_multiplier, 0)), 2),
        'avg_ces_score', ROUND(AVG(COALESCE(ces_score, 0)), 2)
      )
    )
    FROM creative_campaigns
    WHERE roi_multiplier IS NOT NULL
  );
END;
$function$;

-- 2. Scout Platinum Executive Dashboard API
CREATE OR REPLACE FUNCTION scout.platinum_executive_dashboard_api()
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
BEGIN
  RETURN (
    SELECT json_build_object(
      'executive_summary', json_build_object(
        'total_revenue', COALESCE(total_revenue_millions, 0),
        'total_transactions', COALESCE(total_transactions, 0),
        'avg_spend_per_capita', COALESCE(avg_spend_per_capita, 0),
        'regions_covered', COALESCE(regions_covered, 0),
        'data_freshness', COALESCE(data_freshness, 'Unknown'),
        'last_updated', last_updated
      ),
      'kpis', json_build_object(
        'revenue_growth_rate', COALESCE(revenue_growth_rate, 0),
        'market_opportunity_score', COALESCE(market_opportunity_score, 0),
        'avg_brand_penetration', COALESCE(avg_brand_penetration, 0)
      )
    )
    FROM gold_executive_kpis
    ORDER BY last_updated DESC
    LIMIT 1
  );
END;
$function$;

-- 3. Scout Gold Customer Activity API
CREATE OR REPLACE FUNCTION scout.gold_customer_activity_api()
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
BEGIN
  RETURN (
    SELECT json_build_object(
      'customer_metrics', json_agg(
        json_build_object(
          'customer_id', customer_id,
          'full_name', full_name,
          'age_group', age_group,
          'gender', gender,
          'region', region,
          'city', city
        )
      ),
      'activity_summary', json_build_object(
        'total_customers', COUNT(*),
        'unique_regions', COUNT(DISTINCT region),
        'unique_cities', COUNT(DISTINCT city)
      )
    )
    FROM customers
    LIMIT 100
  );
END;
$function$;

-- 4. Scout Gold Basket Analysis API
CREATE OR REPLACE FUNCTION scout.gold_basket_analysis_api()
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
  result JSON;
BEGIN
  SELECT json_build_object(
    'basket_trends', json_agg(
      json_build_object(
        'date', DATE(timestamp),
        'avg_basket_size', AVG(basket_size),
        'total_transactions', COUNT(*)
      )
    )
  ) INTO result
  FROM (
    SELECT timestamp, basket_size 
    FROM scout_transactions 
    WHERE timestamp >= NOW() - INTERVAL '30 days'
  ) t
  GROUP BY DATE(timestamp)
  ORDER BY DATE(timestamp) DESC;
  
  RETURN COALESCE(result, '{"basket_trends": []}'::json);
END;
$function$;

-- 5. Scout Deep Research Analyze API
CREATE OR REPLACE FUNCTION scout.deep_research_analyze_api(query_text TEXT)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
BEGIN
  RETURN json_build_object(
    'analysis_type', 'deep_research',
    'query', query_text,
    'insights', json_build_array(
      json_build_object(
        'title', 'Market Analysis',
        'description', 'Deep dive into ' || query_text,
        'confidence_score', 85.5,
        'data_sources', json_build_array('scout_transactions', 'creative_campaigns')
      )
    ),
    'recommendations', json_build_array(
      json_build_object(
        'action', 'Analyze trends',
        'priority', 'high',
        'impact_score', 78.2
      )
    ),
    'generated_at', NOW()
  );
END;
$function$;

-- Grant necessary permissions
GRANT EXECUTE ON FUNCTION scout.gold_campaign_effect_api() TO authenticated, anon;
GRANT EXECUTE ON FUNCTION scout.platinum_executive_dashboard_api() TO authenticated, anon;
GRANT EXECUTE ON FUNCTION scout.gold_customer_activity_api() TO authenticated, anon;
GRANT EXECUTE ON FUNCTION scout.gold_basket_analysis_api() TO authenticated, anon;
GRANT EXECUTE ON FUNCTION scout.deep_research_analyze_api(TEXT) TO authenticated, anon;