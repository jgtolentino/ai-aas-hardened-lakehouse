export default function ErrorState({message="Something went wrong"}:{message?:string}){
  return <div className="text-sm text-red-600">{message}</div>;
}
