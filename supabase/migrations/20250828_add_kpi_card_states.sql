-- Migration: Add KPI Cards States and Data
-- Generated: 2025-08-28
-- Component: KpiCard

-- Create scout schema if it doesn't exist
CREATE SCHEMA IF NOT EXISTS scout;

-- KPI Cards metadata table
CREATE TABLE IF NOT EXISTS scout.kpi_cards (
    id SERIAL PRIMARY KEY,
    card_key VARCHAR(50) UNIQUE NOT NULL,
    title VARCHAR(100) NOT NULL,
    description TEXT,
    icon_type VARCHAR(20),
    display_order INT DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- KPI Cards data table
CREATE TABLE IF NOT EXISTS scout.kpi_card_values (
    id SERIAL PRIMARY KEY,
    card_id INT NOT NULL REFERENCES scout.kpi_cards(id) ON DELETE CASCADE,
    value DECIMAL(20, 2),
    formatted_value VARCHAR(100),
    change_percentage DECIMAL(5, 2),
    change_type VARCHAR(10) CHECK (change_type IN ('increase', 'decrease', 'neutral')),
    prefix VARCHAR(10),
    suffix VARCHAR(10),
    period_start DATE,
    period_end DATE,
    state VARCHAR(20) DEFAULT 'ready' CHECK (state IN ('loading', 'empty', 'error', 'ready')),
    error_message TEXT,
    metadata JSONB,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- KPI Cards historical data for trending
CREATE TABLE IF NOT EXISTS scout.kpi_card_history (
    id SERIAL PRIMARY KEY,
    card_id INT NOT NULL REFERENCES scout.kpi_cards(id) ON DELETE CASCADE,
    value DECIMAL(20, 2),
    recorded_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    metadata JSONB
);

-- Insert default KPI cards based on Figma design
INSERT INTO scout.kpi_cards (card_key, title, icon_type, display_order) VALUES
    ('gmv', 'GMV', 'gmv', 1),
    ('transactions', 'Transactions', 'transactions', 2),
    ('avg_basket', 'Avg Basket', 'basket', 3),
    ('items_per_tx', 'Items/Tx', 'items', 4)
ON CONFLICT (card_key) DO NOTHING;

-- Insert mock data for testing (matching Figma values)
INSERT INTO scout.kpi_card_values (card_id, value, formatted_value, change_percentage, change_type, prefix, suffix, state)
SELECT 
    id,
    CASE 
        WHEN card_key = 'gmv' THEN 0
        WHEN card_key = 'transactions' THEN 0
        WHEN card_key = 'avg_basket' THEN 0
        WHEN card_key = 'items_per_tx' THEN 0
    END as value,
    CASE 
        WHEN card_key = 'gmv' THEN '₱0'
        WHEN card_key = 'transactions' THEN '0'
        WHEN card_key = 'avg_basket' THEN '₱0'
        WHEN card_key = 'items_per_tx' THEN '0'
    END as formatted_value,
    CASE 
        WHEN card_key = 'gmv' THEN 12.5
        WHEN card_key = 'transactions' THEN 6.3
        WHEN card_key = 'avg_basket' THEN 2.1
        WHEN card_key = 'items_per_tx' THEN 5.7
    END as change_percentage,
    CASE 
        WHEN card_key = 'avg_basket' THEN 'decrease'
        ELSE 'increase'
    END as change_type,
    CASE 
        WHEN card_key IN ('gmv', 'avg_basket') THEN '₱'
        ELSE NULL
    END as prefix,
    NULL as suffix,
    'ready' as state
FROM scout.kpi_cards;

-- Create function to update timestamps
CREATE OR REPLACE FUNCTION scout.update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Add update triggers
CREATE TRIGGER update_kpi_cards_updated_at
    BEFORE UPDATE ON scout.kpi_cards
    FOR EACH ROW
    EXECUTE FUNCTION scout.update_updated_at();

CREATE TRIGGER update_kpi_card_values_updated_at
    BEFORE UPDATE ON scout.kpi_card_values
    FOR EACH ROW
    EXECUTE FUNCTION scout.update_updated_at();

-- Create indexes for performance
CREATE INDEX idx_kpi_card_values_card_id ON scout.kpi_card_values(card_id);
CREATE INDEX idx_kpi_card_values_state ON scout.kpi_card_values(state);
CREATE INDEX idx_kpi_card_values_period ON scout.kpi_card_values(period_start, period_end);
CREATE INDEX idx_kpi_card_history_card_id ON scout.kpi_card_history(card_id);
CREATE INDEX idx_kpi_card_history_recorded_at ON scout.kpi_card_history(recorded_at);

-- Row Level Security (RLS)
ALTER TABLE scout.kpi_cards ENABLE ROW LEVEL SECURITY;
ALTER TABLE scout.kpi_card_values ENABLE ROW LEVEL SECURITY;
ALTER TABLE scout.kpi_card_history ENABLE ROW LEVEL SECURITY;

-- Create read-only policy for authenticated users
CREATE POLICY "Read access for authenticated users" ON scout.kpi_cards
    FOR SELECT
    USING (auth.role() = 'authenticated');

CREATE POLICY "Read access for authenticated users" ON scout.kpi_card_values
    FOR SELECT
    USING (auth.role() = 'authenticated');

CREATE POLICY "Read access for authenticated users" ON scout.kpi_card_history
    FOR SELECT
    USING (auth.role() = 'authenticated');

-- Create function to get latest KPI values
CREATE OR REPLACE FUNCTION scout.get_latest_kpi_values()
RETURNS TABLE (
    card_key VARCHAR,
    title VARCHAR,
    value DECIMAL,
    formatted_value VARCHAR,
    change_percentage DECIMAL,
    change_type VARCHAR,
    prefix VARCHAR,
    suffix VARCHAR,
    icon_type VARCHAR,
    state VARCHAR,
    error_message TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        kc.card_key,
        kc.title,
        kcv.value,
        kcv.formatted_value,
        kcv.change_percentage,
        kcv.change_type,
        kcv.prefix,
        kcv.suffix,
        kc.icon_type,
        kcv.state,
        kcv.error_message
    FROM scout.kpi_cards kc
    LEFT JOIN LATERAL (
        SELECT * FROM scout.kpi_card_values
        WHERE card_id = kc.id
        ORDER BY created_at DESC
        LIMIT 1
    ) kcv ON true
    WHERE kc.is_active = true
    ORDER BY kc.display_order;
END;
$$ LANGUAGE plpgsql;

-- Grant necessary permissions
GRANT USAGE ON SCHEMA scout TO authenticated;
GRANT SELECT ON ALL TABLES IN SCHEMA scout TO authenticated;
GRANT EXECUTE ON FUNCTION scout.get_latest_kpi_values() TO authenticated;
