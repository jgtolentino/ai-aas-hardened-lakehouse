"use client";
import { useQuery } from "@tanstack/react-query";
import { getExecutiveKPIs, getRevenueTrend14d, getTopBrands5 } from "@/data/scout";

export function useExecutiveKPIs(){
  return useQuery({ queryKey: ["exec","kpis"], queryFn: getExecutiveKPIs });
}
export function useRevenueTrend(){
  return useQuery({ queryKey: ["exec","revTrend14d"], queryFn: getRevenueTrend14d });
}
export function useTopBrands(){
  return useQuery({ queryKey: ["exec","topBrands5"], queryFn: getTopBrands5 });
}
