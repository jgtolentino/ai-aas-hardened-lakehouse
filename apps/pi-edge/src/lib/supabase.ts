// Scout Analytics - Supabase Client Configuration
import { createClient } from '@supabase/supabase-js';

// Configuration fallback function to handle multiple environments
function readMeta(name: string): string | null {
  if (typeof document === 'undefined') return null;
  const el = document.querySelector(`meta[name="${name}"]`);
  return el?.getAttribute('content') ?? null;
}

export function getSupabaseConfig() {
  // Vite environment variables
  const v = (typeof import.meta !== 'undefined' ? (import.meta as any).env : {}) || {};
  const viteUrl = v?.VITE_SUPABASE_URL;
  const viteKey = v?.VITE_SUPABASE_ANON_KEY;

  // Next.js environment variables
  const nextUrl = process?.env?.NEXT_PUBLIC_SUPABASE_URL;
  const nextKey = process?.env?.NEXT_PUBLIC_SUPABASE_ANON_KEY;

  // Runtime window variables (for static hosting)
  const win: any = (typeof window !== 'undefined' ? (window as any) : {});
  const rtUrl = win.__ENV__?.SUPABASE_URL;
  const rtKey = win.__ENV__?.SUPABASE_ANON_KEY;

  // Meta tags fallback
  const metaUrl = readMeta('supabase-url');
  const metaKey = readMeta('supabase-anon-key');

  // Production values for Scout Analytics
  const url =
    viteUrl || 
    nextUrl || 
    rtUrl || 
    process.env.SUPABASE_URL || 
    metaUrl || 
    'https://cxzllzyxwpyptfretryc.supabase.co';
    
  const key =
    viteKey || 
    nextKey || 
    rtKey || 
    process.env.SUPABASE_ANON_KEY || 
    metaKey || 
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImN4emxsenlvd3B5cHRmcmV0cnljIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzI5OTA5NjAsImV4cCI6MjA0ODU2Njk2MH0.L1KoNq-I8gI1g-f79PdNfN7kzNajH9gI6MMCpyGNrWE';

  if (!url) throw new Error('Supabase URL missing. Set VITE_SUPABASE_URL / NEXT_PUBLIC_SUPABASE_URL or window.__ENV__.SUPABASE_URL.');
  if (!key) throw new Error('Supabase Anon Key missing. Set VITE_SUPABASE_ANON_KEY / NEXT_PUBLIC_SUPABASE_ANON_KEY or window.__ENV__.SUPABASE_ANON_KEY.');

  return { url, key };
}

// Initialize Supabase client
const { url, key } = getSupabaseConfig();

export const supabase = createClient(url, key, {
  auth: { 
    persistSession: false,
    autoRefreshToken: true,
    detectSessionInUrl: true
  },
  db: {
    schema: 'scout' // Use scout schema by default
  }
});

// Helper function to check connection
export async function checkSupabaseConnection() {
  try {
    const { data, error } = await supabase
      .from('file_ingestion_queue')
      .select('count')
      .limit(1);
    
    if (error) {
      console.error('Supabase connection error:', error);
      return false;
    }
    
    console.log('✅ Supabase connected successfully');
    return true;
  } catch (err) {
    console.error('Failed to connect to Supabase:', err);
    return false;
  }
}