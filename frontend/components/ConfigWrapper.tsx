"use client";
import { useAppConfig } from "@/hooks/useAppConfig";
import type { AppConfig } from "@/lib/appConfig";

interface ConfigWrapperProps {
  children: (config: AppConfig) => React.ReactNode;
  loadingComponent?: React.ReactNode;
}

export function ConfigWrapper({ children, loadingComponent }: ConfigWrapperProps) {
  const config = useAppConfig();
  
  if (!config) {
    return (
      <>
        {loadingComponent || (
          <div className="flex items-center justify-center p-8">
            <div className="animate-pulse text-pendle-gray-400">Loading configuration...</div>
          </div>
        )}
      </>
    );
  }
  
  return <>{children(config)}</>;
}