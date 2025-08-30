import type { Metadata } from 'next'
import './globals.css'

export const metadata: Metadata = {
  title: 'Finebank Dashboard - Financial Intelligence Platform',
  description: 'Comprehensive financial management dashboard with consumer and geographical intelligence',
}

export default function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <html lang="en">
      <body className="bg-[#0b0d12] text-[#e6e9f2]">{children}</body>
    </html>
  )
}
