"use client";
import { useEffect, useState } from "react";
import { getVariant, headlineFor } from "@/lib/ab";
import { track } from "@/lib/analytics";

export function HeroSection() {
  const [variant, setVariant] = useState<"A" | "B">("A");
  
  useEffect(() => {
    const v = getVariant();
    setVariant(v);
    track("ab_impression", { variant: v });
  }, []);
  
  return (
    <div className="text-sm text-gray-300 text-center">
      {headlineFor(variant)}
    </div>
  );
}