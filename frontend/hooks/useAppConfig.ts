"use client";
import { useEffect, useState } from "react";
import { AppConfig, envFallback } from "@/lib/appConfig";

let cachedConfig: AppConfig | null = null;

export function useAppConfig(): AppConfig | null {
  const [cfg, setCfg] = useState<AppConfig | null>(cachedConfig);
  
  useEffect(() => {
    // If already cached, use it
    if (cachedConfig) {
      setCfg(cachedConfig);
      return;
    }
    
    // Fetch runtime config
    fetch("/reka-config.json", { cache: "no-store" })
      .then(r => {
        if (!r.ok) throw new Error("Config not found");
        return r.json();
      })
      .then((json: AppConfig) => {
        // Validate that we have required fields
        if (json.kaiaRpc && json.permit2) {
          cachedConfig = json;
          setCfg(json);
        } else {
          throw new Error("Invalid config");
        }
      })
      .catch((err) => {
        console.warn("Using env fallback:", err.message);
        const fallback = envFallback();
        cachedConfig = fallback;
        setCfg(fallback);
      });
  }, []);
  
  return cfg;
}