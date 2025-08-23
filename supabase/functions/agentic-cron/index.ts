// agentic-cron Edge Function
// Runs every 15 minutes to execute monitors, verify contracts, and enqueue Isko jobs

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3'
import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'

const supabaseUrl = Deno.env.get('SUPABASE_URL')!
const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

const supabase = createClient(supabaseUrl, supabaseServiceKey)

interface MonitorResult {
  monitor_name: string
  event_created: boolean
}

interface ContractResult {
  contract_name: string
  is_valid: boolean
  violation_message: string | null
}

serve(async (req) => {
  try {
    const authHeader = req.headers.get('Authorization')
    if (authHeader !== `Bearer ${supabaseServiceKey}`) {
      return new Response('Unauthorized', { status: 401 })
    }

    const results = {
      monitors: [] as MonitorResult[],
      contracts: [] as ContractResult[],
      isko_jobs: 0,
      timestamp: new Date().toISOString()
    }

    // 1. Run Monitors
    console.log('Running monitors...')
    const { data: monitorResults, error: monitorError } = await supabase
      .rpc('run_monitors')
    
    if (monitorError) {
      console.error('Monitor error:', monitorError)
    } else {
      results.monitors = monitorResults || []
      console.log(`Executed ${results.monitors.length} monitors`)
    }

    // 2. Verify Contracts
    console.log('Verifying contracts...')
    const { data: contractResults, error: contractError } = await supabase
      .rpc('verify_contracts')
    
    if (contractError) {
      console.error('Contract error:', contractError)
    } else {
      results.contracts = contractResults || []
      console.log(`Verified ${results.contracts.length} contracts`)
    }

    // 3. Enqueue Isko Jobs for Top Products without recent scraping
    console.log('Checking for Isko job requirements...')
    
    // Find products that need scraping (not scraped in last 7 days)
    const { data: productsToScrape, error: productError } = await supabase
      .from('dim_products')
      .select('sku, product_name, brand')
      .eq('is_active', true)
      .limit(5)
    
    if (!productError && productsToScrape) {
      for (const product of productsToScrape) {
        // Check if already scraped recently
        const { data: recentScrape } = await supabase
          .from('sku_summary')
          .select('summary_id')
          .eq('sku', product.sku)
          .gte('created_at', new Date(Date.now() - 7 * 24 * 60 * 60 * 1000).toISOString())
          .single()
        
        if (!recentScrape) {
          // Enqueue scraping job
          const { error: jobError } = await supabase
            .schema('deep_research')
            .from('sku_jobs')
            .insert({
              job_type: 'scrape',
              target_sku: product.sku,
              job_payload: {
                product_name: product.product_name,
                brand: product.brand,
                sources: ['shopee', 'lazada', 'puregold']
              }
            })
          
          if (!jobError) {
            results.isko_jobs++
          }
        }
      }
      console.log(`Enqueued ${results.isko_jobs} Isko jobs`)
    }

    // 4. Clean up old feed items (archive items older than 30 days)
    const { error: cleanupError } = await supabase
      .from('agent_feed')
      .update({ status: 'archived', archived_at: new Date().toISOString() })
      .eq('status', 'read')
      .lt('created_at', new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString())
    
    if (cleanupError) {
      console.error('Cleanup error:', cleanupError)
    }

    // 5. Create summary feed entry
    const summary = {
      monitors_triggered: results.monitors.filter(m => m.event_created).length,
      contracts_violated: results.contracts.filter(c => !c.is_valid).length,
      isko_jobs_created: results.isko_jobs
    }

    if (summary.monitors_triggered > 0 || summary.contracts_violated > 0) {
      await supabase
        .from('agent_feed')
        .insert({
          feed_type: 'system_alert',
          feed_source: 'agentic-cron',
          feed_title: 'Agentic Cron Summary',
          feed_content: `Monitors: ${summary.monitors_triggered} triggered, Contracts: ${summary.contracts_violated} violated, Isko: ${summary.isko_jobs_created} jobs`,
          feed_data: results,
          severity: summary.contracts_violated > 0 ? 'warning' : 'info'
        })
    }

    return new Response(JSON.stringify(results), {
      headers: { 'Content-Type': 'application/json' },
      status: 200
    })

  } catch (error) {
    console.error('Cron error:', error)
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { 'Content-Type': 'application/json' },
      status: 500
    })
  }
})
