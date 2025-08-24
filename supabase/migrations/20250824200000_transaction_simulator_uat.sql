-- =====================================================================
-- Scout v5.2 - Realistic Transaction Simulator for UAT
-- Generates continuous transaction flow for testing streaming pipeline
-- =====================================================================
SET search_path TO scout, public;

-- =====================================================================
-- REALISTIC TRANSACTION SIMULATOR
-- =====================================================================

-- Transaction simulation function with realistic data patterns
CREATE OR REPLACE FUNCTION scout.simulate_transaction_batch(
    p_batch_size INTEGER DEFAULT 25,
    p_store_variance BOOLEAN DEFAULT TRUE,
    p_time_variance BOOLEAN DEFAULT TRUE
)
RETURNS TABLE(
    transactions_created INTEGER,
    total_items INTEGER,
    total_amount NUMERIC,
    simulation_timestamp TIMESTAMPTZ
) 
LANGUAGE plpgsql AS $$
DECLARE
    v_transactions_created INTEGER := 0;
    v_total_items INTEGER := 0;
    v_total_amount NUMERIC := 0;
    v_sim_timestamp TIMESTAMPTZ := NOW();
    
    -- Realistic transaction patterns
    v_items_per_transaction INTEGER;
    v_transaction_base_amount NUMERIC;
    v_store_id TEXT;
    v_customer_segments TEXT[] := ARRAY['regular', 'premium', 'budget', 'family', 'student'];
    v_payment_methods TEXT[] := ARRAY['cash', 'card', 'mobile', 'gcash', 'grabpay'];
    
    -- Product categories with different price ranges
    v_category_weights JSONB := '{
        "beverages": {"weight": 0.25, "avg_price": 85.00, "items_per_tx": 2},
        "snacks": {"weight": 0.20, "avg_price": 45.00, "items_per_tx": 3},
        "personal_care": {"weight": 0.15, "avg_price": 125.00, "items_per_tx": 1},
        "household": {"weight": 0.15, "avg_price": 95.00, "items_per_tx": 2},
        "food": {"weight": 0.20, "avg_price": 165.00, "items_per_tx": 2},
        "tobacco": {"weight": 0.05, "avg_price": 125.00, "items_per_tx": 1}
    }';
    
    i INTEGER;
    v_category_name TEXT;
    v_category_data JSONB;
    v_product_record RECORD;
    v_transaction_items JSONB;
    v_customer_type TEXT;
    v_payment_method TEXT;
BEGIN
    
    FOR i IN 1..p_batch_size LOOP
        -- Realistic transaction timing (add some variance)
        IF p_time_variance THEN
            v_sim_timestamp := NOW() + (RANDOM() - 0.5) * INTERVAL '300 seconds';
        ELSE 
            v_sim_timestamp := NOW();
        END IF;
        
        -- Select store (with geographical bias for realism)
        IF p_store_variance THEN
            SELECT store_id INTO v_store_id
            FROM scout.dim_store 
            WHERE is_active = TRUE
            ORDER BY RANDOM() * (CASE 
                WHEN region ILIKE '%metro manila%' THEN 2.0  -- Higher probability for Metro Manila
                WHEN region ILIKE '%cebu%' OR region ILIKE '%davao%' THEN 1.5  -- Higher for major cities
                ELSE 1.0 
            END)
            LIMIT 1;
        ELSE
            SELECT store_id INTO v_store_id
            FROM scout.dim_store 
            WHERE is_active = TRUE
            ORDER BY RANDOM()
            LIMIT 1;
        END IF;
        
        -- Customer and payment method selection
        v_customer_type := v_customer_segments[1 + FLOOR(RANDOM() * array_length(v_customer_segments, 1))];
        v_payment_method := v_payment_methods[1 + FLOOR(RANDOM() * array_length(v_payment_methods, 1))];
        
        -- Determine transaction size based on customer type
        CASE v_customer_type
            WHEN 'premium' THEN v_items_per_transaction := 2 + FLOOR(RANDOM() * 6); -- 2-7 items
            WHEN 'family' THEN v_items_per_transaction := 4 + FLOOR(RANDOM() * 8); -- 4-11 items  
            WHEN 'budget' THEN v_items_per_transaction := 1 + FLOOR(RANDOM() * 3); -- 1-3 items
            WHEN 'student' THEN v_items_per_transaction := 1 + FLOOR(RANDOM() * 2); -- 1-2 items
            ELSE v_items_per_transaction := 2 + FLOOR(RANDOM() * 4); -- 2-5 items (regular)
        END CASE;
        
        -- Build transaction items array
        v_transaction_items := '[]'::JSONB;
        v_transaction_base_amount := 0;
        
        -- Select products for this transaction
        FOR j IN 1..v_items_per_transaction LOOP
            -- Weighted category selection
            WITH category_selection AS (
                SELECT 
                    key as category,
                    value as data,
                    RANDOM() * (value->>'weight')::NUMERIC as weighted_random
                FROM jsonb_each(v_category_weights)
            )
            SELECT category, data INTO v_category_name, v_category_data
            FROM category_selection
            ORDER BY weighted_random DESC
            LIMIT 1;
            
            -- Select a product from the chosen category
            SELECT 
                product_id, product_name, brand, category,
                CASE 
                    WHEN v_customer_type = 'premium' THEN 
                        (v_category_data->>'avg_price')::NUMERIC * (0.8 + RANDOM() * 0.8)  -- 80%-160% of avg
                    WHEN v_customer_type = 'budget' THEN 
                        (v_category_data->>'avg_price')::NUMERIC * (0.5 + RANDOM() * 0.4)  -- 50%-90% of avg
                    ELSE 
                        (v_category_data->>'avg_price')::NUMERIC * (0.7 + RANDOM() * 0.6)  -- 70%-130% of avg
                END as calculated_price
            INTO v_product_record
            FROM scout.dim_product
            WHERE lower(category) LIKE '%' || v_category_name || '%' 
               OR lower(subcategory) LIKE '%' || v_category_name || '%'
            ORDER BY RANDOM()
            LIMIT 1;
            
            -- If no product found in category, use any random product
            IF v_product_record.product_id IS NULL THEN
                SELECT product_id, product_name, brand, category, 75.00 as calculated_price
                INTO v_product_record
                FROM scout.dim_product
                ORDER BY RANDOM()
                LIMIT 1;
            END IF;
            
            -- Add item to transaction
            v_transaction_items := v_transaction_items || jsonb_build_object(
                'product_id', v_product_record.product_id,
                'product_name', v_product_record.product_name,
                'brand', v_product_record.brand,
                'category', v_product_record.category,
                'qty', 1,
                'unit_price', ROUND(v_product_record.calculated_price, 2),
                'line_amount', ROUND(v_product_record.calculated_price, 2),
                'discount', CASE WHEN RANDOM() < 0.1 THEN ROUND(v_product_record.calculated_price * 0.05, 2) ELSE 0 END
            );
            
            v_transaction_base_amount := v_transaction_base_amount + v_product_record.calculated_price;
        END LOOP;
        
        -- Apply customer-specific transaction modifiers
        CASE v_customer_type
            WHEN 'premium' THEN v_transaction_base_amount := v_transaction_base_amount * 1.15; -- 15% premium
            WHEN 'budget' THEN v_transaction_base_amount := v_transaction_base_amount * 0.85;   -- 15% discount
            WHEN 'student' THEN v_transaction_base_amount := v_transaction_base_amount * 0.90;  -- 10% discount
            ELSE -- regular customers
                NULL; -- no modifier
        END CASE;
        
        -- Create the bronze event
        INSERT INTO scout.bronze_events (
            event_type, 
            event_data, 
            source_system,
            ingested_at,
            event_hash
        ) VALUES (
            'transaction.v1',
            jsonb_build_object(
                'transaction_id', 'SIM-' || TO_CHAR(v_sim_timestamp, 'YYYYMMDD-HH24MISS-') || LPAD(i::TEXT, 3, '0'),
                'store_id', v_store_id,
                'ts', v_sim_timestamp,
                'total_amount', ROUND(v_transaction_base_amount, 2),
                'net_amount', ROUND(v_transaction_base_amount * 0.95, 2), -- 5% tax/fees
                'customer_id', 'CUST-' || v_customer_type || '-' || FLOOR(RANDOM() * 10000),
                'payment_method', v_payment_method,
                'items', v_transaction_items,
                'metadata', jsonb_build_object(
                    'customer_type', v_customer_type,
                    'simulation', true,
                    'batch_id', EXTRACT(EPOCH FROM NOW())
                )
            ),
            'transaction_simulator',
            v_sim_timestamp,
            encode(sha256(('SIM-' || TO_CHAR(v_sim_timestamp, 'YYYYMMDD-HH24MISS-') || LPAD(i::TEXT, 3, '0'))::bytea), 'hex')
        );
        
        v_transactions_created := v_transactions_created + 1;
        v_total_items := v_total_items + v_items_per_transaction;
        v_total_amount := v_total_amount + v_transaction_base_amount;
        
    END LOOP;
    
    RETURN QUERY SELECT 
        v_transactions_created,
        v_total_items, 
        ROUND(v_total_amount, 2),
        NOW();
        
END;
$$;

-- Realistic store activity patterns (some stores more active than others)
CREATE OR REPLACE FUNCTION scout.simulate_realistic_store_activity(
    p_duration_minutes INTEGER DEFAULT 60
)
RETURNS TABLE(
    store_activity_summary JSONB
) 
LANGUAGE plpgsql AS $$
DECLARE
    v_store_record RECORD;
    v_activity_level NUMERIC;
    v_transactions_to_generate INTEGER;
    v_summary JSONB := '{}'::JSONB;
BEGIN
    -- Simulate different activity levels for different stores
    FOR v_store_record IN 
        SELECT store_id, store_name, region, is_active
        FROM scout.dim_store 
        WHERE is_active = TRUE
        ORDER BY RANDOM()
        LIMIT 20  -- Simulate activity for 20 stores
    LOOP
        -- Determine activity level based on region and random factors
        v_activity_level := CASE 
            WHEN v_store_record.region ILIKE '%metro manila%' THEN 0.7 + RANDOM() * 0.3  -- 70-100% activity
            WHEN v_store_record.region ILIKE '%cebu%' OR v_store_record.region ILIKE '%davao%' THEN 0.5 + RANDOM() * 0.4  -- 50-90% activity
            ELSE 0.2 + RANDOM() * 0.5  -- 20-70% activity for other regions
        END;
        
        -- Calculate transactions to generate (base rate: 1 transaction per 3 minutes for active stores)
        v_transactions_to_generate := FLOOR((p_duration_minutes / 3.0) * v_activity_level);
        
        IF v_transactions_to_generate > 0 THEN
            -- Generate transactions for this store
            PERFORM scout.simulate_transaction_batch(
                v_transactions_to_generate,
                FALSE,  -- Don't vary store since we're targeting specific store
                TRUE    -- Vary timing
            );
            
            -- Add to summary
            v_summary := v_summary || jsonb_build_object(
                v_store_record.store_id,
                jsonb_build_object(
                    'store_name', v_store_record.store_name,
                    'region', v_store_record.region,
                    'activity_level', ROUND(v_activity_level, 2),
                    'transactions_generated', v_transactions_to_generate
                )
            );
        END IF;
        
    END LOOP;
    
    RETURN QUERY SELECT v_summary;
END;
$$;

-- Peak hours simulation (morning, lunch, evening rushes)
CREATE OR REPLACE FUNCTION scout.simulate_peak_hours()
RETURNS TABLE(
    peak_period TEXT,
    transactions_generated INTEGER,
    period_start TIMESTAMPTZ
) 
LANGUAGE plpgsql AS $$
DECLARE
    v_current_hour INTEGER := EXTRACT(HOUR FROM NOW());
    v_peak_multiplier NUMERIC := 1.0;
    v_base_transactions INTEGER := 15;
    v_transactions INTEGER;
    v_period TEXT;
BEGIN
    -- Determine peak period and multiplier
    CASE 
        WHEN v_current_hour BETWEEN 7 AND 9 THEN   -- Morning rush
            v_peak_multiplier := 2.5;
            v_period := 'morning_rush';
        WHEN v_current_hour BETWEEN 12 AND 13 THEN  -- Lunch rush
            v_peak_multiplier := 3.0;
            v_period := 'lunch_rush';
        WHEN v_current_hour BETWEEN 17 AND 19 THEN  -- Evening rush
            v_peak_multiplier := 2.8;
            v_period := 'evening_rush';
        WHEN v_current_hour BETWEEN 20 AND 22 THEN  -- Night activity
            v_peak_multiplier := 1.8;
            v_period := 'night_activity';
        ELSE                                        -- Off-peak
            v_peak_multiplier := 0.8;
            v_period := 'off_peak';
    END CASE;
    
    v_transactions := FLOOR(v_base_transactions * v_peak_multiplier);
    
    -- Generate transactions for current peak period
    PERFORM scout.simulate_transaction_batch(
        v_transactions,
        TRUE,   -- Vary stores
        TRUE    -- Vary timing within the period
    );
    
    RETURN QUERY SELECT 
        v_period,
        v_transactions,
        NOW();
END;
$$;

-- =====================================================================
-- SCHEDULED SIMULATION JOBS
-- =====================================================================

-- Continuous realistic transaction flow (every minute during business hours)
SELECT cron.schedule(
    'realistic-transaction-simulation',
    '* 6-23 * * *',  -- Every minute from 6 AM to 11 PM
    'SELECT scout.simulate_peak_hours();'
);

-- Store activity simulation (every 10 minutes)
SELECT cron.schedule(
    'store-activity-simulation', 
    '*/10 * * * *',
    'SELECT scout.simulate_realistic_store_activity(10);'
);

-- Weekend burst simulation (higher activity on weekends)
SELECT cron.schedule(
    'weekend-burst-simulation',
    '*/5 * * * 0,6',  -- Every 5 minutes on Saturday(6) and Sunday(0)
    'SELECT scout.simulate_transaction_batch(35, TRUE, TRUE);'
);

-- =====================================================================
-- SIMULATION CONTROL & MONITORING
-- =====================================================================

-- Function to start/stop simulation
CREATE OR REPLACE FUNCTION scout.control_simulation(
    p_action TEXT DEFAULT 'status'  -- 'start', 'stop', 'status'
)
RETURNS TABLE(
    action TEXT,
    simulation_jobs_active INTEGER,
    message TEXT
) 
LANGUAGE plpgsql AS $$
DECLARE
    v_active_jobs INTEGER;
BEGIN
    -- Count active simulation jobs
    SELECT COUNT(*) INTO v_active_jobs
    FROM cron.job
    WHERE jobname LIKE '%-simulation' AND active = TRUE;
    
    CASE p_action
        WHEN 'start' THEN
            -- Enable simulation jobs
            UPDATE cron.job 
            SET active = TRUE 
            WHERE jobname LIKE '%-simulation';
            
            RETURN QUERY SELECT 
                'start'::TEXT,
                v_active_jobs,
                'Transaction simulation started'::TEXT;
                
        WHEN 'stop' THEN
            -- Disable simulation jobs
            UPDATE cron.job 
            SET active = FALSE 
            WHERE jobname LIKE '%-simulation';
            
            RETURN QUERY SELECT 
                'stop'::TEXT,
                0,
                'Transaction simulation stopped'::TEXT;
                
        ELSE -- 'status'
            RETURN QUERY SELECT 
                'status'::TEXT,
                v_active_jobs,
                CASE 
                    WHEN v_active_jobs > 0 THEN 'Simulation is running'
                    ELSE 'Simulation is stopped'
                END::TEXT;
    END CASE;
END;
$$;

-- Simulation performance monitoring
CREATE OR REPLACE VIEW scout.v_simulation_performance AS
SELECT
    date_trunc('hour', ingested_at) AS hour,
    COUNT(*) AS simulated_transactions,
    COUNT(DISTINCT event_data->>'store_id') AS active_stores,
    AVG(jsonb_array_length(event_data->'items'))::NUMERIC(5,2) AS avg_items_per_transaction,
    AVG((event_data->>'total_amount')::NUMERIC)::NUMERIC(10,2) AS avg_transaction_amount,
    STRING_AGG(DISTINCT event_data->'metadata'->>'customer_type', ', ') AS customer_types_seen
FROM scout.bronze_events
WHERE source_system = 'transaction_simulator'
  AND ingested_at > NOW() - INTERVAL '24 hours'
GROUP BY date_trunc('hour', ingested_at)
ORDER BY hour DESC;

-- Simulation vs Real Transaction Comparison
CREATE OR REPLACE VIEW scout.v_simulation_vs_real AS
SELECT
    'Simulated' AS source_type,
    COUNT(*) AS transaction_count,
    AVG((event_data->>'total_amount')::NUMERIC)::NUMERIC(10,2) AS avg_amount,
    COUNT(DISTINCT event_data->>'store_id') AS unique_stores
FROM scout.bronze_events
WHERE source_system = 'transaction_simulator'
  AND ingested_at > NOW() - INTERVAL '24 hours'

UNION ALL

SELECT
    'Real' AS source_type,
    COUNT(*) AS transaction_count,
    AVG((event_data->>'total_amount')::NUMERIC)::NUMERIC(10,2) AS avg_amount,
    COUNT(DISTINCT event_data->>'store_id') AS unique_stores
FROM scout.bronze_events
WHERE source_system != 'transaction_simulator'
  AND source_system IS NOT NULL
  AND ingested_at > NOW() - INTERVAL '24 hours';

-- =====================================================================
-- DEPLOYMENT VERIFICATION
-- =====================================================================

SELECT 
    '🎮 Transaction Simulator Deployed!'::TEXT AS status,
    'Realistic transaction generation active for UAT testing'::TEXT AS description;

-- Show simulation control status
SELECT * FROM scout.control_simulation('status');

-- Show scheduled simulation jobs
SELECT 
    jobname, 
    schedule, 
    active,
    CASE WHEN active THEN '✅ Active' ELSE '⏸️ Inactive' END AS status
FROM cron.job 
WHERE jobname LIKE '%-simulation'
ORDER BY jobname;