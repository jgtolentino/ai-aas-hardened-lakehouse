import { createClient } from '@supabase/supabase-js';

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL!;
const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!;

export const supabase = createClient(supabaseUrl, supabaseAnonKey, {
  auth: {
    persistSession: true,
    autoRefreshToken: true,
  },
  realtime: {
    params: {
      eventsPerSecond: 10,
    },
  },
});

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
