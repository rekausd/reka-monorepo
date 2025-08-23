"use client";
import { LineChart, Line, CartesianGrid, XAxis, YAxis, Tooltip, ResponsiveContainer } from "recharts";
import { useEffect, useState } from "react";
import { ethers } from "ethers";
import { addr, prov, StrategyABI } from "@/lib/contracts";

type P = { t:number, tvl:number };

export function TVLChart(){
  const [data, setData] = useState<P[]>([]);
  useEffect(()=>{
    (async()=>{
      try{
        const s = new ethers.Contract(addr.strategy, StrategyABI, prov("eth"));
        const now = Date.now(); const day = 86_400_000;
        const pts:P[] = [];
        for (let i=10;i>=0;i--){
          const ts = now - i*day;
          const tvl = Number(await s.totalUSDTEquivalent())/1e6;
          pts.push({ t: ts, tvl });
        }
        setData(pts);
      }catch{}
    })();
  },[]);
  return (
    <div style={{width:"100%", height:280}}>
      <ResponsiveContainer>
        <LineChart data={data}>
          <CartesianGrid strokeDasharray="3 3" />
          <XAxis dataKey="t" tickFormatter={(v)=>new Date(v).toLocaleDateString()} />
          <YAxis />
          <Tooltip formatter={(v)=>[Number(v).toLocaleString(), "TVL"]} />
          <Line dataKey="tvl" type="monotone" stroke="#16a34a" dot={false}/>
        </LineChart>
      </ResponsiveContainer>
    </div>
  );
}
