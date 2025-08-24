import { createClient } from '@supabase/supabase-js'

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL || 'https://cxzllzyxwpyptfretryc.supabase.co'
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImN4emxsenl4d3B5cHRmcmV0cnljIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTUyMDYzMzQsImV4cCI6MjA3MDc4MjMzNH0.adA0EO89jw5uPH4qdL_aox6EbDPvJ28NcXGYW7u33Ok'

export const supabase = createClient(supabaseUrl, supabaseAnonKey)

// Export config for other uses
export const supabaseConfig = {
  url: supabaseUrl,
  anonKey: supabaseAnonKey,
}
