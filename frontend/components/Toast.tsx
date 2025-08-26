"use client";
import { useState } from "react";

export function useToast(){
  const [msg, setMsg] = useState<string>("");
  const [type, setType] = useState<"ok"|"err"|"">("");
  function showOk(m:string){ setType("ok"); setMsg(m); setTimeout(()=>setType(""), 4000); }
  function showErr(m:string){ setType("err"); setMsg(m); setTimeout(()=>setType(""), 5000); }
  const node = type ? (
    <div className={`fixed bottom-6 right-6 px-4 py-2 rounded z-50 ${type==="ok"?"bg-emerald-600":"bg-red-600"}`}>{msg}</div>
  ) : null;
  return { node, showOk, showErr };
}