export function Card({title, children}:{title:string, children:React.ReactNode}){
  return (
    <div className="card p-6 rounded-2xl">
      <div className="mb-3 text-sm font-medium text-pendle-gray-400 uppercase tracking-wider">{title}</div>
      {children}
    </div>
  );
}