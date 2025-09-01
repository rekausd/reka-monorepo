"use client";
import { useEffect } from "react";
import { motion, useMotionValue, useTransform, animate } from "framer-motion";

export function AnimatedNumber({ value, decimals=2, className="" }:{
  value: number; decimals?: number; className?: string;
}) {
  const mv = useMotionValue(0);
  const rounded = useTransform(mv, (v)=> Number(v).toFixed(decimals));
  useEffect(()=>{
    const controls = animate(mv, value, { duration: 0.6, ease: "easeOut" });
    return () => controls.stop();
  }, [value, mv]);
  return <motion.span className={className}>{rounded}</motion.span>;
}