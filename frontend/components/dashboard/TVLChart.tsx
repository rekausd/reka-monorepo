"use client";
import { LineChart, Line, CartesianGrid, XAxis, YAxis, Tooltip, ResponsiveContainer } from "recharts";
import { useEffect, useState } from "react";

export function TVLChart(){
  const [data, setData] = useState<{t:number, tvl:number}[]>([]);
  useEffect(()=>{
    const now = Date.now(), day = 86_400_000;
    const pts = Array.from({length: 11}, (_,i)=>({ 
      t: now - (10-i)*day, 
      tvl: Math.max(0, 1000000 + Math.random()*200000) 
    }));
    setData(pts);
  },[]);
  return (
    <div style={{width:"100%", height:260}}>
      <ResponsiveContainer>
        <LineChart data={data}>
          <CartesianGrid strokeDasharray="3 3" stroke="#1e2830" />
          <XAxis dataKey="t" tickFormatter={(v)=>new Date(v).toLocaleDateString()} stroke="#8aa0af" />
          <YAxis stroke="#8aa0af" />
          <Tooltip 
            formatter={(v:any)=>[Number(v).toLocaleString(), "TVL"]} 
            contentStyle={{ backgroundColor: "#12171b", border: "1px solid #1e2830" }}
          />
          <Line dataKey="tvl" type="monotone" stroke="#14b8a6" dot={false} strokeWidth={2}/>
        </LineChart>
      </ResponsiveContainer>
    </div>
  );
}