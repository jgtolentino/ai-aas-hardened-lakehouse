"use client";
import { supabase } from "@/data/supabase";
import { useEffect, useState } from "react";

export type Role = "Executive"|"Manager"|"Analyst";
export type SessionInfo = {
  role: Role;
  email?: string;
  userId?: string;
  isAuthed: boolean;
};

export function useSessionInfo(): SessionInfo {
  const [state, set] = useState<SessionInfo>({ role: "Executive", isAuthed: false });
  useEffect(()=>{
    let mounted = true;
    supabase.auth.getSession().then(({ data })=>{
      if (!mounted) return;
      const sess = data.session ?? undefined;
      const user = sess?.user;
      const role = (user?.app_metadata?.role ?? user?.user_metadata?.role ?? "Executive") as Role;
      set({ role, email: user?.email ?? undefined, userId: user?.id ?? undefined, isAuthed: !!user });
    });
    const { data: sub } = supabase.auth.onAuthStateChange((_e, s)=>{
      const user = s?.user;
      const role = (user?.app_metadata?.role ?? user?.user_metadata?.role ?? "Executive") as Role;
      set({ role, email: user?.email ?? undefined, userId: user?.id ?? undefined, isAuthed: !!user });
    });
    return ()=> { mounted = false; sub?.subscription?.unsubscribe(); };
  }, []);
  return state;
}

export function usePageGuard(required: Role[] = ["Executive","Manager","Analyst"]) {
  const s = useSessionInfo();
  const allowed = required.includes(s.role);
  return { allowed, session: s };
}
