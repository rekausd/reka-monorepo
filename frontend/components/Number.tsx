export function NumberFmt({ v, decimals=2, suffix="" }:{v:number,decimals?:number,suffix?:string}){
  const n = isFinite(v) ? v : 0;
  return <span>{n.toLocaleString(undefined,{maximumFractionDigits:decimals})}{suffix}</span>;
}