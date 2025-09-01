"use client";
export function Tip({text}:{text:string}){ 
  return <span title={text} className="ml-1 text-xs text-gray-400 cursor-help">ⓘ</span>; 
}