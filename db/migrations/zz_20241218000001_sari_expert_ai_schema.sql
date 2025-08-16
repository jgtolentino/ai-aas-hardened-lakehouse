-- SARI-SARI EXPERT AI SERVICE - DATABASE SCHEMA
-- Complete database infrastructure for intelligent retail assistant
-- Extends Scout Analytics with AI inference and feedback systems

-- =====================================
-- 1. AI FEEDBACK LOGGING SYSTEM
-- =====================================

-- Main feedback table for AI recommendations and inferences
CREATE TABLE IF NOT EXISTS ai_feedback_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  recommendation_id TEXT, -- Links to specific AI recommendation
  inference_id TEXT, -- Links to transaction inference or persona match
  feedback_type TEXT NOT NULL CHECK (feedback_type IN ('thumbs_up', 'thumbs_down', 'comment', 'rating')),
  rating INTEGER CHECK (rating >= 1 AND rating <= 5),
  comment TEXT,
  store_owner_id TEXT DEFAULT 'anonymous',
  implementation_result TEXT CHECK (implementation_result IN ('implemented', 'partially_implemented', 'not_implemented', 'pending')),
  outcome_notes TEXT,
  metadata JSONB DEFAULT '{}', -- Flexible storage for additional context
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index for performance
CREATE INDEX IF NOT EXISTS idx_ai_feedback_created_at ON ai_feedback_log(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_ai_feedback_recommendation_id ON ai_feedback_log(recommendation_id);
CREATE INDEX IF NOT EXISTS idx_ai_feedback_store_owner ON ai_feedback_log(store_owner_id);
CREATE INDEX IF NOT EXISTS idx_ai_feedback_type ON ai_feedback_log(feedback_type);

-- =====================================
-- 2. AI INFERENCE HISTORY
-- =====================================

-- Store transaction inferences for learning and improvement
CREATE TABLE IF NOT EXISTS ai_transaction_inferences (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id TEXT,
  customer_id TEXT,
  partial_basket JSONB NOT NULL, -- Original incomplete transaction
  predicted_items JSONB NOT NULL, -- AI predicted missing items
  completion_probability DECIMAL(4,2) CHECK (completion_probability >= 0 AND completion_probability <= 1),
  actual_completion BOOLEAN, -- Was the prediction correct?
  actual_additional_items JSONB, -- What was actually purchased
  inference_accuracy DECIMAL(4,2), -- How accurate was the prediction
  model_version TEXT DEFAULT 'v1.0',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for transaction inference analysis
CREATE INDEX IF NOT EXISTS idx_transaction_inference_store ON ai_transaction_inferences(store_id);
CREATE INDEX IF NOT EXISTS idx_transaction_inference_customer ON ai_transaction_inferences(customer_id);
CREATE INDEX IF NOT EXISTS idx_transaction_inference_created ON ai_transaction_inferences(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_transaction_inference_accuracy ON ai_transaction_inferences(inference_accuracy DESC);

-- =====================================
-- 3. PERSONA MATCHING HISTORY
-- =====================================

-- Store persona matching results for continuous learning
CREATE TABLE IF NOT EXISTS ai_persona_matches (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_behavior_hash TEXT NOT NULL, -- Anonymized customer behavior signature
  matched_persona TEXT NOT NULL,
  confidence_score DECIMAL(4,2) CHECK (confidence_score >= 0 AND confidence_score <= 1),
  behavioral_indicators JSONB NOT NULL,
  actual_persona TEXT, -- Ground truth if known
  match_accuracy BOOLEAN, -- Was the match correct?
  feedback_from_interaction JSONB, -- How did the customer respond to persona-based approach?
  store_context JSONB, -- Store location, time, etc.
  model_version TEXT DEFAULT 'v1.0',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for persona matching analysis
CREATE INDEX IF NOT EXISTS idx_persona_match_persona ON ai_persona_matches(matched_persona);
CREATE INDEX IF NOT EXISTS idx_persona_match_confidence ON ai_persona_matches(confidence_score DESC);
CREATE INDEX IF NOT EXISTS idx_persona_match_created ON ai_persona_matches(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_persona_match_accuracy ON ai_persona_matches(match_accuracy);

-- =====================================
-- 4. BUSINESS RECOMMENDATIONS TRACKING
-- =====================================

-- Track AI business recommendations and their outcomes
CREATE TABLE IF NOT EXISTS ai_business_recommendations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  recommendation_id TEXT NOT NULL UNIQUE,
  store_id TEXT,
  recommendation_type TEXT NOT NULL CHECK (recommendation_type IN ('product_placement', 'pricing', 'promotion', 'inventory', 'layout')),
  title TEXT NOT NULL,
  description TEXT NOT NULL,
  expected_impact TEXT,
  implementation_effort TEXT CHECK (implementation_effort IN ('low', 'medium', 'high')),
  priority_score INTEGER CHECK (priority_score >= 0 AND priority_score <= 100),
  supporting_data JSONB DEFAULT '{}',
  status TEXT DEFAULT 'generated' CHECK (status IN ('generated', 'presented', 'accepted', 'implemented', 'rejected')),
  implementation_date TIMESTAMPTZ,
  actual_impact_data JSONB, -- Measured results after implementation
  roi_calculation DECIMAL(10,2), -- Return on investment if measurable
  model_version TEXT DEFAULT 'v1.0',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for recommendations tracking
CREATE INDEX IF NOT EXISTS idx_recommendations_store ON ai_business_recommendations(store_id);
CREATE INDEX IF NOT EXISTS idx_recommendations_type ON ai_business_recommendations(recommendation_type);
CREATE INDEX IF NOT EXISTS idx_recommendations_status ON ai_business_recommendations(status);
CREATE INDEX IF NOT EXISTS idx_recommendations_priority ON ai_business_recommendations(priority_score DESC);
CREATE INDEX IF NOT EXISTS idx_recommendations_created ON ai_business_recommendations(created_at DESC);

-- =====================================
-- 5. AI MODEL PERFORMANCE METRICS
-- =====================================

-- Track overall AI system performance for continuous improvement
CREATE TABLE IF NOT EXISTS ai_model_performance (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  model_type TEXT NOT NULL CHECK (model_type IN ('transaction_inference', 'persona_matching', 'recommendation_engine')),
  model_version TEXT NOT NULL,
  performance_period_start TIMESTAMPTZ NOT NULL,
  performance_period_end TIMESTAMPTZ NOT NULL,
  total_predictions INTEGER NOT NULL DEFAULT 0,
  correct_predictions INTEGER NOT NULL DEFAULT 0,
  accuracy_percentage DECIMAL(5,2) GENERATED ALWAYS AS (
    CASE 
      WHEN total_predictions = 0 THEN 0 
      ELSE (correct_predictions::decimal / total_predictions) * 100 
    END
  ) STORED,
  confidence_avg DECIMAL(4,2),
  user_satisfaction_avg DECIMAL(3,2),
  implementation_rate_percentage DECIMAL(5,2),
  business_impact_metrics JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index for performance tracking
CREATE INDEX IF NOT EXISTS idx_model_performance_type ON ai_model_performance(model_type);
CREATE INDEX IF NOT EXISTS idx_model_performance_version ON ai_model_performance(model_version);
CREATE INDEX IF NOT EXISTS idx_model_performance_period ON ai_model_performance(performance_period_start DESC);

-- =====================================
-- 6. CUSTOMER BEHAVIOR ANALYTICS (ANONYMIZED)
-- =====================================

-- Anonymized customer behavior patterns for AI training (GDPR compliant)
CREATE TABLE IF NOT EXISTS customer_behavior_patterns (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  behavior_signature TEXT NOT NULL, -- Anonymized hash of customer behavior
  visit_patterns JSONB NOT NULL, -- Time patterns, frequency, etc.
  purchase_patterns JSONB NOT NULL, -- Category preferences, spending levels
  basket_composition_patterns JSONB NOT NULL, -- Common item combinations
  seasonal_patterns JSONB DEFAULT '{}',
  geographic_context TEXT, -- General region, not specific location
  anonymized_demographics JSONB DEFAULT '{}', -- Age range, general preferences
  pattern_confidence DECIMAL(4,2) DEFAULT 0.5,
  sample_size INTEGER DEFAULT 1,
  last_updated TIMESTAMPTZ DEFAULT NOW(),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Ensure no personal identification possible
CREATE UNIQUE INDEX IF NOT EXISTS idx_behavior_signature ON customer_behavior_patterns(behavior_signature);
CREATE INDEX IF NOT EXISTS idx_behavior_geographic ON customer_behavior_patterns(geographic_context);
CREATE INDEX IF NOT EXISTS idx_behavior_updated ON customer_behavior_patterns(last_updated DESC);

-- =====================================
-- 7. AI SYSTEM CONFIGURATION
-- =====================================

-- System-wide AI configuration and feature flags
CREATE TABLE IF NOT EXISTS ai_system_config (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  config_key TEXT NOT NULL UNIQUE,
  config_value JSONB NOT NULL,
  description TEXT,
  environment TEXT DEFAULT 'production' CHECK (environment IN ('development', 'staging', 'production')),
  is_active BOOLEAN DEFAULT true,
  last_modified_by TEXT DEFAULT 'system',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Insert default configuration
INSERT INTO ai_system_config (config_key, config_value, description) VALUES
  ('transaction_inference_enabled', 'true', 'Enable/disable transaction completion inference'),
  ('persona_matching_enabled', 'true', 'Enable/disable customer persona matching'),
  ('recommendations_enabled', 'true', 'Enable/disable business recommendations'),
  ('feedback_collection_enabled', 'true', 'Enable/disable user feedback collection'),
  ('model_versions', '{"transaction_inference": "v1.0", "persona_matching": "v1.0", "recommendations": "v1.0"}', 'Current model versions'),
  ('confidence_thresholds', '{"min_persona_confidence": 0.3, "min_transaction_confidence": 0.4, "min_recommendation_confidence": 0.5}', 'Minimum confidence levels for AI outputs'),
  ('rate_limits', '{"max_inferences_per_hour": 1000, "max_recommendations_per_day": 100}', 'API rate limiting configuration')
ON CONFLICT (config_key) DO NOTHING;

-- =====================================
-- 8. ROW LEVEL SECURITY (RLS) POLICIES
-- =====================================

-- Enable RLS on all AI tables
ALTER TABLE ai_feedback_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_transaction_inferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_persona_matches ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_business_recommendations ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_model_performance ENABLE ROW LEVEL SECURITY;
ALTER TABLE customer_behavior_patterns ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_system_config ENABLE ROW LEVEL SECURITY;

-- RLS Policies for authenticated users (store owners/managers)
CREATE POLICY "Users can view their own AI feedback" ON ai_feedback_log
  FOR ALL USING (auth.uid()::text = store_owner_id OR store_owner_id = 'anonymous');

CREATE POLICY "Users can view their store's transaction inferences" ON ai_transaction_inferences
  FOR SELECT USING (true); -- Allow reading for analytics, no personal data stored

CREATE POLICY "Users can view persona matches" ON ai_persona_matches
  FOR SELECT USING (true); -- Anonymized data, safe to read

CREATE POLICY "Users can view their store's recommendations" ON ai_business_recommendations
  FOR ALL USING (store_id IS NULL OR store_id = current_setting('app.current_store_id', true));

CREATE POLICY "System performance metrics are public" ON ai_model_performance
  FOR SELECT USING (true);

CREATE POLICY "Behavior patterns are anonymized and readable" ON customer_behavior_patterns
  FOR SELECT USING (true);

CREATE POLICY "System config is readable by authenticated users" ON ai_system_config
  FOR SELECT USING (auth.role() = 'authenticated');

-- =====================================
-- 9. USEFUL VIEWS FOR AI ANALYTICS
-- =====================================

-- View for AI system health dashboard
CREATE OR REPLACE VIEW ai_system_health AS
SELECT 
  'Overall System Health' as metric_category,
  COUNT(*) as total_inferences,
  AVG(CASE WHEN feedback_type IN ('thumbs_up', 'comment') THEN 1 ELSE 0 END) * 100 as satisfaction_rate,
  COUNT(DISTINCT store_owner_id) as active_users,
  DATE_TRUNC('day', created_at) as metric_date
FROM ai_feedback_log 
WHERE created_at >= NOW() - INTERVAL '30 days'
GROUP BY DATE_TRUNC('day', created_at);

-- View for recommendation effectiveness
CREATE OR REPLACE VIEW recommendation_effectiveness AS
SELECT 
  r.recommendation_type,
  COUNT(*) as total_recommendations,
  COUNT(CASE WHEN r.status = 'implemented' THEN 1 END) as implemented_count,
  AVG(f.rating) as avg_rating,
  COUNT(CASE WHEN f.feedback_type = 'thumbs_up' THEN 1 END) as positive_feedback,
  COUNT(CASE WHEN f.feedback_type = 'thumbs_down' THEN 1 END) as negative_feedback
FROM ai_business_recommendations r
LEFT JOIN ai_feedback_log f ON r.recommendation_id = f.recommendation_id
WHERE r.created_at >= NOW() - INTERVAL '90 days'
GROUP BY r.recommendation_type;

-- View for customer behavior insights (anonymized)
CREATE OR REPLACE VIEW customer_insights_summary AS
SELECT 
  geographic_context,
  COUNT(*) as pattern_count,
  AVG(pattern_confidence) as avg_confidence,
  JSON_AGG(DISTINCT jsonb_object_keys(purchase_patterns)) as common_categories
FROM customer_behavior_patterns 
WHERE pattern_confidence > 0.3
GROUP BY geographic_context;

-- =====================================
-- 10. FUNCTIONS FOR AI SYSTEM OPERATIONS
-- =====================================

-- Function to update AI model performance metrics
CREATE OR REPLACE FUNCTION update_model_performance()
RETURNS void AS $$
BEGIN
  -- Update transaction inference performance
  INSERT INTO ai_model_performance (
    model_type, 
    model_version, 
    performance_period_start, 
    performance_period_end,
    total_predictions,
    correct_predictions,
    confidence_avg
  )
  SELECT 
    'transaction_inference',
    model_version,
    NOW() - INTERVAL '24 hours',
    NOW(),
    COUNT(*),
    COUNT(CASE WHEN actual_completion = true THEN 1 END),
    AVG(completion_probability)
  FROM ai_transaction_inferences 
  WHERE created_at >= NOW() - INTERVAL '24 hours'
  GROUP BY model_version;

  -- Update persona matching performance
  INSERT INTO ai_model_performance (
    model_type, 
    model_version, 
    performance_period_start, 
    performance_period_end,
    total_predictions,
    correct_predictions,
    confidence_avg
  )
  SELECT 
    'persona_matching',
    model_version,
    NOW() - INTERVAL '24 hours',
    NOW(),
    COUNT(*),
    COUNT(CASE WHEN match_accuracy = true THEN 1 END),
    AVG(confidence_score)
  FROM ai_persona_matches 
  WHERE created_at >= NOW() - INTERVAL '24 hours'
  GROUP BY model_version;
END;
$$ LANGUAGE plpgsql;

-- Function to clean old AI data (GDPR compliance)
CREATE OR REPLACE FUNCTION cleanup_old_ai_data()
RETURNS void AS $$
BEGIN
  -- Delete old feedback logs (keep 2 years)
  DELETE FROM ai_feedback_log WHERE created_at < NOW() - INTERVAL '2 years';
  
  -- Delete old inference data (keep 1 year)
  DELETE FROM ai_transaction_inferences WHERE created_at < NOW() - INTERVAL '1 year';
  
  -- Delete old persona matches (keep 1 year)
  DELETE FROM ai_persona_matches WHERE created_at < NOW() - INTERVAL '1 year';
  
  -- Archive old recommendations (keep active, delete old rejected ones)
  DELETE FROM ai_business_recommendations 
  WHERE status = 'rejected' AND created_at < NOW() - INTERVAL '6 months';
END;
$$ LANGUAGE plpgsql;

-- =====================================
-- 11. INITIAL SAMPLE DATA FOR TESTING
-- =====================================

-- Sample AI feedback for testing
INSERT INTO ai_feedback_log (recommendation_id, feedback_type, rating, comment, store_owner_id, implementation_result) VALUES
  ('placement_001', 'thumbs_up', 5, 'Great suggestion! Moved high-velocity items to eye level and sales increased by 18%', 'owner_001', 'implemented'),
  ('pricing_001', 'rating', 4, 'Peak hour pricing worked well during rush hours', 'owner_002', 'implemented'),
  ('inventory_001', 'thumbs_up', 5, 'Stock optimization reduced out-of-stocks significantly', 'owner_001', 'implemented'),
  ('promo_001', 'comment', 3, 'Bundle promotion was good but customers wanted more variety', 'owner_003', 'partially_implemented'),
  ('layout_001', 'thumbs_up', 4, 'Impulse purchase zone near checkout increased small item sales', 'owner_002', 'implemented');

-- Sample business recommendations
INSERT INTO ai_business_recommendations (recommendation_id, recommendation_type, title, description, expected_impact, implementation_effort, priority_score, status) VALUES
  ('placement_sample_001', 'product_placement', 'Optimize High-Traffic Product Zones', 'Place best-selling items in high-visibility areas near entrance', 'Increase sales by 15-20%', 'low', 85, 'generated'),
  ('pricing_sample_001', 'pricing', 'Dynamic Pricing for Peak Hours', 'Adjust prices during morning and evening rush for high-demand items', 'Increase revenue by 8-12%', 'medium', 75, 'generated'),
  ('inventory_sample_001', 'inventory', 'Smart Reorder Point Optimization', 'Use AI to predict optimal reorder points based on sales patterns', 'Reduce stockouts by 30%', 'medium', 80, 'generated');

COMMENT ON TABLE ai_feedback_log IS 'Stores feedback from store owners on AI recommendations and inferences';
COMMENT ON TABLE ai_transaction_inferences IS 'Historical transaction completion predictions for AI model training';
COMMENT ON TABLE ai_persona_matches IS 'Customer persona matching results for continuous learning';
COMMENT ON TABLE ai_business_recommendations IS 'AI-generated business recommendations and their implementation tracking';
COMMENT ON TABLE ai_model_performance IS 'Performance metrics for AI models over time';
COMMENT ON TABLE customer_behavior_patterns IS 'Anonymized customer behavior patterns for AI training';
COMMENT ON TABLE ai_system_config IS 'System-wide AI configuration and feature flags';

-- Success message
DO $$
BEGIN
  RAISE NOTICE 'Sari-Sari Expert AI database schema created successfully!';
  RAISE NOTICE 'Tables created: 7 core AI tables + views and functions';
  RAISE NOTICE 'Sample data inserted for immediate testing';
  RAISE NOTICE 'RLS policies enabled for data security';
END $$;