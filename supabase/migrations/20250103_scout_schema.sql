-- Scout Schema Migration v1.0.0
-- Creates the core tables for the Scout system

-- Create Scout Schema
CREATE SCHEMA IF NOT EXISTS scout;

-- Session History Table for Memory Bridge
CREATE TABLE IF NOT EXISTS scout.session_history (
    id SERIAL PRIMARY KEY,
    session_id UUID DEFAULT gen_random_uuid(),
    user_id TEXT,
    timestamp TIMESTAMPTZ DEFAULT NOW(),
    message_type TEXT CHECK (message_type IN ('user', 'assistant', 'system')),
    content JSONB,
    metadata JSONB,
    embedding vector(1536),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Agents Registry Table
CREATE TABLE IF NOT EXISTS scout.agents (
    id SERIAL PRIMARY KEY,
    agent_id UUID DEFAULT gen_random_uuid(),
    name TEXT NOT NULL UNIQUE,
    type TEXT NOT NULL,
    capabilities JSONB,
    configuration JSONB,
    status TEXT DEFAULT 'active',
    version TEXT DEFAULT '0.1.0',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Scout Events Table
CREATE TABLE IF NOT EXISTS scout.events (
    id SERIAL PRIMARY KEY,
    event_id UUID DEFAULT gen_random_uuid(),
    event_type TEXT NOT NULL,
    source TEXT,
    payload JSONB,
    processed BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Knowledge Base Table
CREATE TABLE IF NOT EXISTS scout.knowledge_base (
    id SERIAL PRIMARY KEY,
    doc_id UUID DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    content TEXT,
    metadata JSONB,
    embedding vector(1536),
    source_url TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_session_history_session_id ON scout.session_history(session_id);
CREATE INDEX IF NOT EXISTS idx_session_history_user_id ON scout.session_history(user_id);
CREATE INDEX IF NOT EXISTS idx_session_history_timestamp ON scout.session_history(timestamp);
CREATE INDEX IF NOT EXISTS idx_agents_status ON scout.agents(status);
CREATE INDEX IF NOT EXISTS idx_events_processed ON scout.events(processed);
CREATE INDEX IF NOT EXISTS idx_events_type ON scout.events(event_type);
CREATE INDEX IF NOT EXISTS idx_knowledge_base_title ON scout.knowledge_base(title);

-- Enable RLS
ALTER TABLE scout.session_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE scout.agents ENABLE ROW LEVEL SECURITY;
ALTER TABLE scout.events ENABLE ROW LEVEL SECURITY;
ALTER TABLE scout.knowledge_base ENABLE ROW LEVEL SECURITY;

-- Create RLS Policies
CREATE POLICY "Enable all access for authenticated users" ON scout.session_history
    FOR ALL USING (auth.role() = 'authenticated');

CREATE POLICY "Enable all access for authenticated users" ON scout.agents
    FOR ALL USING (auth.role() = 'authenticated');

CREATE POLICY "Enable all access for authenticated users" ON scout.events
    FOR ALL USING (auth.role() = 'authenticated');

CREATE POLICY "Enable all access for authenticated users" ON scout.knowledge_base
    FOR ALL USING (auth.role() = 'authenticated');

-- Grant permissions
GRANT USAGE ON SCHEMA scout TO anon, authenticated, service_role;
GRANT ALL ON ALL TABLES IN SCHEMA scout TO service_role;
GRANT ALL ON ALL TABLES IN SCHEMA scout TO authenticated;
GRANT SELECT ON ALL TABLES IN SCHEMA scout TO anon;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA scout TO authenticated, service_role;

-- Insert initial agents
INSERT INTO scout.agents (name, type, capabilities, configuration, status) VALUES
('creative-studio', 'registry', '{"design": true, "ai": true}', '{"version": "0.1.0"}', 'active'),
('scout-scraper', 'scraper', '{"web": true, "api": true}', '{"version": "0.1.0"}', 'active'),
('memory-bridge', 'mcp', '{"session": true, "history": true}', '{"version": "0.1.0"}', 'active')
ON CONFLICT (name) DO NOTHING;
