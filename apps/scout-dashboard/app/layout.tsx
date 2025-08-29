import './src/styles/app.css'
import type { Metadata } from 'next'

export const metadata: Metadata = {
  title: 'Scout Dashboard',
  description: 'TBWA Financial Intelligence Platform',
}

export default function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <html lang="en" data-face="tableau">
      <body className="bg-bg text-text">
        {children}
      </body>
    </html>
  )
}