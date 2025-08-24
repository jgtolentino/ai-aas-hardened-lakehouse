-- ============================================================
-- SCOUT v5.2 SEED DATA LOADER (Development/Staging Only)
-- Loads reference data from Supabase Storage bucket
-- ============================================================

-- Load comprehensive seed data from storage bucket
SELECT scout.fn_seed_dev_data();