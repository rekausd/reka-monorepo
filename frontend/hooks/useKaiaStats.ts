"use client";
import useSWR from "swr";
import { useAppConfig } from "@/hooks/useAppConfig";
import { readTotals } from "@/lib/kaiaRead";
import type { AppConfig } from "@/lib/appConfig";

export function useKaiaTotals() {
  const cfg = useAppConfig();
  
  const { data: totals, error, mutate } = useSWR(
    cfg ? ["kaia-totals", cfg] : null,
    cfg ? () => readTotals(cfg) : null,
    {
      refreshInterval: 30000, // 30 seconds
      revalidateOnFocus: false,
      dedupingInterval: 5000
    }
  );
  
  return {
    totals,
    error,
    isLoading: !error && !totals && cfg,
    mutate
  };
}