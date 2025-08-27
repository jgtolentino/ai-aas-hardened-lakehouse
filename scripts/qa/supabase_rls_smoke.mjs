import { createClient } from "@supabase/supabase-js";

const url = process.env.NEXT_PUBLIC_SUPABASE_URL || process.env.VITE_SUPABASE_URL;
const anon = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY || process.env.VITE_SUPABASE_ANON_KEY;
if (!url || !anon) { console.error("Missing SUPABASE envs"); process.exit(2); }

const sb = createClient(url, anon);

async function mustFailRaw() {
  const { data, error } = await sb.from("fact_transactions").select("*").limit(1);
  if (!error) { console.error("RLS breach: fact_transactions readable", data); process.exit(1); }
}

async function mustPassGold() {
  const { data, error } = await sb.from("gold_daily_metrics").select("*").limit(1);
  if (error) { console.error("Gold view not readable", error); process.exit(1); }
}

await mustFailRaw();
await mustPassGold();
console.log("✅ RLS smoke OK: raw blocked, gold accessible");
