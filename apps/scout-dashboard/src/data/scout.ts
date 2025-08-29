"use client";
import { supabase } from "./supabase";
import { ExecutiveKPIs, TrendPoint, TopBrand } from "./types";

/**
 * Reads KPI summary from:
 * 1) view: gold_executive_kpis (single row)
 * 2) fallback RPC: get_executive_summary
 */
export async function getExecutiveKPIs(): Promise<ExecutiveKPIs> {
  // VIEW first
  const v = await supabase.from("gold_executive_kpis").select("revenue,transactions,market_share,stores").maybeSingle();
  if (v.data) return v.data as ExecutiveKPIs;

  // RPC fallback
  const r = await supabase.rpc("get_executive_summary");
  if (r.data) return r.data as ExecutiveKPIs;

  // Mock safe fallback
  return { revenue: 1230000, transactions: 12457, market_share: 34.2, stores: 5 };
}

/**
 * 14d revenue trend from:
 * 1) view: gold_revenue_trend_14d (d,rev)
 * 2) fallback RPC: get_revenue_trend_14d
 */
export async function getRevenueTrend14d(): Promise<TrendPoint[]> {
  const t = await supabase.from("gold_revenue_trend_14d").select("d, rev").order("d",{ascending:true});
  if (t.data?.length) return t.data as TrendPoint[];

  const r = await supabase.rpc("get_revenue_trend_14d");
  if (Array.isArray(r.data) && r.data.length) return r.data as TrendPoint[];

  // Mock
  return Array.from({length:14}).map((_,i)=>({ d: `D${i+1}`, rev: 100 + Math.round(Math.random()*40) }));
}

/**
 * Top 5 brands from:
 * 1) view: gold_top_brands_5 (name,v)
 * 2) fallback RPC: get_top_brands_5
 */
export async function getTopBrands5(): Promise<TopBrand[]> {
  const q = await supabase.from("gold_top_brands_5").select("name,v").order("v",{ascending:false}).limit(5);
  if (q.data?.length) return q.data as TopBrand[];

  const r = await supabase.rpc("get_top_brands_5");
  if (Array.isArray(r.data) && r.data.length) return r.data as TopBrand[];

  return [
    { name: "Brand A", v: 420 }, { name: "Brand B", v: 390 },
    { name: "Brand C", v: 310 }, { name: "Brand D", v: 260 }, { name: "Brand E", v: 210 }
  ];
}
