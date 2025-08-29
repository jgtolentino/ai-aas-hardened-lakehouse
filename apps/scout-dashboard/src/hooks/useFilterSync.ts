"use client";
import { useEffect } from "react";
import { makeFilterBus } from "@/src/realtime/filterBus";
import { useFilterStore } from "@/src/store/filters";

export function useFilterSync() {
  const { filters, setFilter, reset } = useFilterStore();
  useEffect(() => {
    const bus = makeFilterBus();
    let cancel: ()=>void;
    bus.subscribe((incoming) => {
      // naive merge; customize as needed
      if (!incoming) return;
      Object.entries(incoming).forEach(([k, v]) => setFilter(k as any, v as any));
    }).then(unsub => cancel = unsub);
    return () => { cancel?.(); };
  }, [setFilter, reset]);

  // publish on changes (debounce if you like)
  useEffect(() => {
    const bus = makeFilterBus();
    bus.publish(filters);
  }, [filters]);
}
