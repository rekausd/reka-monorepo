"use client";
import liff from "@line/liff";
import { useState, useEffect } from "react";

let liffInitPromise: Promise<void> | null = null;
let liffReady = false;

export async function initMiniApp() {
  // Skip if using new LIFF/SDK integration
  if (process.env.NEXT_PUBLIC_LIFF_ID && process.env.NEXT_PUBLIC_DAPP_CLIENT_ID) {
    return;
  }

  if (!process.env.NEXT_PUBLIC_MINIAPP_APP_ID) {
    console.warn("Mini Dapp App ID not configured");
    return;
  }

  if (liffInitPromise) return liffInitPromise;
  
  liffInitPromise = liff.init({
    liffId: process.env.NEXT_PUBLIC_MINIAPP_APP_ID,
    withLoginOnExternalBrowser: false
  }).then(() => {
    liffReady = true;
  }).catch(err => {
    console.error("LIFF init failed:", err);
    liffReady = false;
  });
  
  return liffInitPromise;
}

export async function ready() {
  // Skip if using new LIFF/SDK integration
  if (process.env.NEXT_PUBLIC_LIFF_ID && process.env.NEXT_PUBLIC_DAPP_CLIENT_ID) {
    return true;
  }

  if (!process.env.NEXT_PUBLIC_MINIAPP_ENABLED || process.env.NEXT_PUBLIC_MINIAPP_ENABLED === "false") {
    return true;
  }
  await initMiniApp();
  return liffReady;
}

export function useMiniApp() {
  const [isReady, setIsReady] = useState(false);
  const [userId, setUserId] = useState<string | null>(null);
  const [language, setLanguage] = useState<string>("en");
  const [isInMiniApp, setIsInMiniApp] = useState(false);

  useEffect(() => {
    // Skip if using new LIFF/SDK integration
    if (process.env.NEXT_PUBLIC_LIFF_ID && process.env.NEXT_PUBLIC_DAPP_CLIENT_ID) {
      setIsReady(true);
      return;
    }

    if (!process.env.NEXT_PUBLIC_MINIAPP_ENABLED || process.env.NEXT_PUBLIC_MINIAPP_ENABLED === "false") {
      setIsReady(true);
      return;
    }
    
    initMiniApp().then(() => {
      setIsReady(liffReady);
      if (liffReady && liff.isInClient()) {
        setIsInMiniApp(true);
        const context = liff.getContext();
        setUserId(context?.userId || null);
        setLanguage(liff.getLanguage());
      }
    });
  }, []);
  
  return { ready: isReady, userId, language, isInMiniApp };
}