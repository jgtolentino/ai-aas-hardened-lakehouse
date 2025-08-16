import React from 'react'
import ReactDOM from 'react-dom/client'
import ScoutDashboard from './components/ScoutDashboard'
import './index.css'

// Test Supabase configuration on app startup
import { getSupabaseConfig } from './lib/supabase'

try {
  const config = getSupabaseConfig()
  console.log('✅ Supabase configuration loaded:', {
    url: config.url,
    hasKey: !!config.key
  })
} catch (error) {
  console.error('❌ Supabase configuration error:', error)
}

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <ScoutDashboard />
  </React.StrictMode>,
)