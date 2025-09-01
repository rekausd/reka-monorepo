"use client";
import { motion } from "framer-motion";

export function ShimmerBar(){
  return (
    <div className="relative h-1 w-full overflow-hidden rounded">
      <div className="absolute inset-0 bg-white/10" />
      <motion.div
        initial={{ x: "-100%" }}
        animate={{ x: "100%" }}
        transition={{ duration: 1.2, repeat: Infinity, ease: "linear" }}
        className="absolute top-0 left-0 h-1 w-1/3 bg-white/40 rounded"
      />
    </div>
  );
}