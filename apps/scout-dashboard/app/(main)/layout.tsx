import '../src/styles/app.css'
export default function Layout({ children }: { children: React.ReactNode }) {
  return <html data-face="tableau"><body>{children}</body></html>
}