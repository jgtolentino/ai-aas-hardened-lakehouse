// Supabase configuration with scout schema as default
import { createClient } from '@supabase/supabase-js';

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL!;
const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!;

// Configure client with scout schema preference
export const supabase = createClient(supabaseUrl, supabaseAnonKey, {
  auth: {
    persistSession: true,
    autoRefreshToken: true,
  },
  db: {
    schema: 'public' // Default schema (scout views are accessed via RPC)
  },
  realtime: {
    params: {
      eventsPerSecond: 10,
    },
  },
});

// Helper to access scout schema directly
export const scoutSchema = {
  from: (table: string) => supabase.from(`${table}`),
  rpc: (fn: string, params?: any) => supabase.rpc(fn, params)
};

// Realtime subscription for filter broadcasting
export function subscribeToFilterChannel(
  onMessage: (payload: any) => void
) {
  const channel = supabase
    .channel('scout-filters')
    .on('broadcast', { event: 'filter-change' }, onMessage)
    .subscribe();

  return () => {
    supabase.removeChannel(channel);
  };
}

// Broadcast filter changes
export async function broadcastFilterChange(filters: any) {
  const channel = supabase.channel('scout-filters');
  await channel.send({
    type: 'broadcast',
    event: 'filter-change',
    payload: filters,
  });
}

// Test scout schema access
export async function testScoutSchema() {
  try {
    // Test executive KPIs
    const { data: kpis, error: kpiError } = await supabase
      .rpc('get_executive_summary');
    
    if (kpiError) {
      console.error('Scout schema error:', kpiError);
      return false;
    }
    
    console.log('✅ Scout schema accessible');
    console.log('KPIs:', kpis);
    return true;
  } catch (error) {
    console.error('Failed to access scout schema:', error);
    return false;
  }
}
