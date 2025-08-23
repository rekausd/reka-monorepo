export function Card({title, children}:{title:string, children:React.ReactNode}){
  return (
    <div className="card p-5">
      <div className="mb-3 text-sm text-gray-400">{title}</div>
      {children}
    </div>
  );
}
