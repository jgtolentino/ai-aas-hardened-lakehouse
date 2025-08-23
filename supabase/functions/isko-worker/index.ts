// isko-worker Edge Function
// Processes SKU scraping jobs from the queue

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3'
import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'

const supabaseUrl = Deno.env.get('SUPABASE_URL')!
const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

const supabase = createClient(supabaseUrl, supabaseServiceKey)

// Mock scraper function (replace with actual scraping logic)
async function scrapeSKU(source: string, sku: string, productName: string): Promise<any> {
  // Simulate scraping delay
  await new Promise(resolve => setTimeout(resolve, 1000))
  
  // Mock data based on source
  const mockPrices: Record<string, number> = {
    'shopee': Math.floor(Math.random() * 500) + 50,
    'lazada': Math.floor(Math.random() * 500) + 55,
    'puregold': Math.floor(Math.random() * 500) + 60
  }
  
  const mockAvailability = ['in_stock', 'out_of_stock', 'limited'][Math.floor(Math.random() * 3)]
  
  return {
    sku,
    product_name: productName,
    price: mockPrices[source] || 100,
    availability: mockAvailability,
    source_url: `https://${source}.com/product/${sku}`,
    image_url: `https://${source}.com/images/${sku}.jpg`,
    scraped_at: new Date().toISOString(),
    source
  }
}

serve(async (req) => {
  try {
    const authHeader = req.headers.get('Authorization')
    if (authHeader !== `Bearer ${supabaseServiceKey}`) {
      return new Response('Unauthorized', { status: 401 })
    }

    const results = {
      processed: 0,
      succeeded: 0,
      failed: 0,
      timestamp: new Date().toISOString()
    }

    // Get queued jobs
    const { data: jobs, error: fetchError } = await supabase
      .schema('deep_research')
      .from('sku_jobs')
      .select('*')
      .eq('job_status', 'queued')
      .lt('retry_count', 3)
      .limit(10)
    
    if (fetchError) {
      console.error('Error fetching jobs:', fetchError)
      return new Response(JSON.stringify({ error: fetchError.message }), {
        headers: { 'Content-Type': 'application/json' },
        status: 500
      })
    }

    for (const job of jobs || []) {
      results.processed++
      
      try {
        // Update job status to running
        await supabase
          .schema('deep_research')
          .from('sku_jobs')
          .update({ 
            job_status: 'running',
            started_at: new Date().toISOString()
          })
          .eq('job_id', job.job_id)
        
        // Process based on job type
        if (job.job_type === 'scrape') {
          const sources = job.job_payload?.sources || ['shopee']
          const scrapedData = []
          
          for (const source of sources) {
            try {
              const data = await scrapeSKU(
                source,
                job.target_sku,
                job.job_payload?.product_name || job.target_sku
              )
              scrapedData.push(data)
            } catch (scrapeError) {
              console.error(`Scraping error for ${source}:`, scrapeError)
            }
          }
          
          if (scrapedData.length > 0) {
            // Find best price
            const bestPrice = scrapedData.reduce((best, current) => 
              current.price < best.price ? current : best
            )
            
            // Insert into SKU summary
            const { error: insertError } = await supabase
              .schema('deep_research')
              .from('sku_summary')
              .insert({
                job_id: job.job_id,
                sku: job.target_sku,
                product_name: job.job_payload?.product_name,
                brand_name: job.job_payload?.brand,
                brand_id: job.brand_id,
                pack_size: job.job_payload?.pack_size,
                unit_price: bestPrice.price,
                availability: bestPrice.availability,
                image_url: bestPrice.image_url,
                source_url: bestPrice.source_url,
                source_name: bestPrice.source,
                scraped_data: { all_sources: scrapedData },
                confidence_score: 0.85
              })
            
            if (insertError) {
              throw insertError
            }
            
            // Update job as success
            await supabase
              .schema('deep_research')
              .from('sku_jobs')
              .update({
                job_status: 'success',
                completed_at: new Date().toISOString(),
                job_result: { scraped_count: scrapedData.length, best_price: bestPrice.price }
              })
              .eq('job_id', job.job_id)
            
            results.succeeded++
            
            // Add to agent feed
            await supabase
              .from('agent_feed')
              .insert({
                feed_type: 'sku_update',
                feed_source: 'isko-worker',
                feed_title: `SKU Scraped: ${job.target_sku}`,
                feed_content: `Found best price PHP ${bestPrice.price} from ${bestPrice.source}`,
                feed_data: bestPrice,
                severity: 'info'
              })
          } else {
            throw new Error('No data scraped from any source')
          }
        }
        
      } catch (jobError: any) {
        console.error(`Job ${job.job_id} failed:`, jobError)
        results.failed++
        
        // Update job as failed or retry
        const newRetryCount = job.retry_count + 1
        const newStatus = newRetryCount >= job.max_retries ? 'failed' : 'queued'
        
        await supabase
          .schema('deep_research')
          .from('sku_jobs')
          .update({
            job_status: newStatus,
            retry_count: newRetryCount,
            error_message: jobError.message,
            completed_at: newStatus === 'failed' ? new Date().toISOString() : null
          })
          .eq('job_id', job.job_id)
      }
    }

    return new Response(JSON.stringify(results), {
      headers: { 'Content-Type': 'application/json' },
      status: 200
    })

  } catch (error: any) {
    console.error('Worker error:', error)
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { 'Content-Type': 'application/json' },
      status: 500
    })
  }
})
