"use client";
import { supabase } from "@/src/data/scout";

/** Broadcast current filters to other clients. */
export function makeFilterBus() {
  const ch = supabase.channel("scout-filters", { config: { broadcast: { ack: true } } });

  async function subscribe(onFilter: (payload: any)=>void) {
    await ch.subscribe((status) => {
      if (status === "SUBSCRIBED") {
        // ready
      }
    });
    ch.on("broadcast", { event: "filter" }, (p) => {
      if (p?.payload) onFilter(p.payload);
    });
    return () => { ch.unsubscribe(); };
  }

  async function publish(filters: any) {
    await ch.send({ type: "broadcast", event: "filter", payload: filters });
  }

  return { subscribe, publish };
}
