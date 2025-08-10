// Scout Transaction Ingestion Edge Function
// Production-grade validation and processing

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.0'
import { z } from 'https://deno.land/x/zod@v3.22.4/mod.ts'

// Environment
const supabaseUrl = Deno.env.get('SUPABASE_URL')!
const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

// Data contract schema (exact match to dictionary)
const TransactionSchema = z.object({
  // Core identifiers
  id: z.string().min(1),
  store_id: z.string().min(1),
  timestamp: z.string().datetime(), // ISO-8601 UTC
  
  // Location object
  location: z.object({
    barangay: z.string().min(1),
    city: z.string().min(1),
    province: z.string().min(1),
    region: z.string().min(1),
  }),
  
  // Product details
  product_category: z.string().min(1),
  brand_name: z.string().min(1),
  sku: z.string().min(1),
  units_per_transaction: z.number().int().positive(),
  peso_value: z.number().nonnegative().optional(), // Can be computed
  basket_size: z.number().int().positive(),
  combo_basket: z.array(z.object({
    sku: z.string().min(1),
    quantity: z.number().int().positive().default(1)
  })),
  
  // Counter interaction
  request_mode: z.enum(['verbal', 'pointing', 'indirect']),
  request_type: z.enum(['branded', 'unbranded', 'point', 'indirect']),
  suggestion_accepted: z.boolean(),
  
  // Demographics
  gender: z.enum(['male', 'female', 'unknown']),
  age_bracket: z.enum(['18-24', '25-34', '35-44', '45-54', '55+', 'unknown']),
  
  // Transaction dynamics
  substitution_event: z.object({
    occurred: z.boolean(),
    from_sku: z.string().optional(),
    to_sku: z.string().optional(),
    reason: z.enum(['stockout', 'suggestion', 'unknown']).optional()
  }),
  duration_seconds: z.number().int().nonnegative(),
  campaign_influenced: z.boolean(),
  handshake_score: z.number().min(0).max(1),
  is_tbwa_client: z.boolean(),
  
  // Commerce context
  payment_method: z.enum(['cash', 'gcash', 'maya', 'credit', 'other']),
  customer_type: z.enum(['regular', 'occasional', 'new', 'unknown']),
  store_type: z.enum(['urban_high', 'urban_medium', 'residential', 'rural', 'transport', 'other']),
  economic_class: z.enum(['A', 'B', 'C', 'D', 'E', 'unknown'])
})

type Transaction = z.infer<typeof TransactionSchema>

// Utility functions
function getTimeOfDay(timestamp: string): string {
  const hour = new Date(timestamp).getUTCHours() + 8 // Convert to PHT
  if (hour >= 6 && hour < 12) return 'morning'
  if (hour >= 12 && hour < 18) return 'afternoon'
  if (hour >= 18 && hour < 22) return 'evening'
  return 'night'
}

async function computePesoValue(
  supabase: any, 
  sku: string, 
  units: number, 
  providedValue?: number
): Promise<number> {
  if (providedValue && providedValue > 0) return providedValue
  
  try {
    const { data: skuData, error } = await supabase
      .from('scout.dim_sku')
      .select('unit_price')
      .eq('sku', sku)
      .single()
    
    if (error) {
      console.error('SKU lookup failed:', error)
      return providedValue || 0  // Fallback to provided value or 0
    }
    
    return skuData?.unit_price ? skuData.unit_price * units : (providedValue || 0)
  } catch (err) {
    console.error('Database error in computePesoValue:', err)
    return providedValue || 0  // Fallback on any error
  }
}

async function upsertDimensions(supabase: any, txn: Transaction) {
  // Upsert store
  await supabase.from('scout.dim_store').upsert({
    store_id: txn.store_id,
    store_name: txn.store_id, // Default, should be enriched
    store_type: txn.store_type,
    barangay: txn.location.barangay,
    city: txn.location.city,
    province: txn.location.province,
    region: txn.location.region,
    economic_class: txn.economic_class
  }, { onConflict: 'store_id', ignoreDuplicates: true })
  
  // Upsert brand
  await supabase.from('scout.dim_brand').upsert({
    brand_name: txn.brand_name,
    is_tbwa_client: txn.is_tbwa_client
  }, { onConflict: 'brand_name', ignoreDuplicates: true })
  
  // Upsert main SKU
  await supabase.from('scout.dim_sku').upsert({
    sku: txn.sku,
    product_name: txn.sku, // Default, should be enriched
    brand_name: txn.brand_name,
    category: txn.product_category,
    unit_price: 0 // Should be enriched
  }, { onConflict: 'sku', ignoreDuplicates: true })
  
  // Upsert combo basket SKUs
  for (const item of txn.combo_basket) {
    await supabase.from('scout.dim_sku').upsert({
      sku: item.sku,
      product_name: item.sku,
      brand_name: 'UNKNOWN', // Should be enriched
      category: txn.product_category,
      unit_price: 0
    }, { onConflict: 'sku', ignoreDuplicates: true })
  }
}

async function validateDataQuality(
  supabase: any, 
  txn: Transaction,
  ingestId: number
): Promise<{ valid: boolean; issues: any[] }> {
  const issues: any[] = []
  
  // Check basket size consistency
  if (txn.basket_size !== txn.combo_basket.length) {
    issues.push({
      ingest_id: ingestId,
      transaction_id: txn.id,
      issue_type: 'basket_size_mismatch',
      field_name: 'basket_size',
      field_value: txn.basket_size.toString(),
      expected_value: txn.combo_basket.length.toString(),
      severity: 'warning'
    })
  }
  
  // Check substitution consistency
  if (txn.substitution_event.occurred) {
    if (!txn.substitution_event.from_sku || !txn.substitution_event.to_sku || !txn.substitution_event.reason) {
      issues.push({
        ingest_id: ingestId,
        transaction_id: txn.id,
        issue_type: 'incomplete_substitution',
        field_name: 'substitution_event',
        field_value: JSON.stringify(txn.substitution_event),
        expected_value: 'Complete substitution details required when occurred=true',
        severity: 'error'
      })
    }
  }
  
  // Check peso value reasonableness
  const minExpectedValue = txn.units_per_transaction * 5 // Assume min 5 peso per unit
  if (txn.peso_value && txn.peso_value < minExpectedValue) {
    issues.push({
      ingest_id: ingestId,
      transaction_id: txn.id,
      issue_type: 'low_peso_value',
      field_name: 'peso_value',
      field_value: txn.peso_value.toString(),
      expected_value: `>= ${minExpectedValue}`,
      severity: 'warning'
    })
  }
  
  // Log all issues
  if (issues.length > 0) {
    await supabase.from('scout.data_quality_issues').insert(issues)
  }
  
  // Transaction is valid if no errors (warnings are OK)
  const hasErrors = issues.some(i => i.severity === 'error')
  return { valid: !hasErrors, issues }
}

async function processTransaction(supabase: any, txn: Transaction, ingestId: number) {
  // 1. Upsert dimensions
  await upsertDimensions(supabase, txn)
  
  // 2. Compute derived fields
  const timeOfDay = getTimeOfDay(txn.timestamp)
  const pesoValue = await computePesoValue(supabase, txn.sku, txn.units_per_transaction, txn.peso_value)
  
  // 3. Validate data quality
  const { valid, issues } = await validateDataQuality(supabase, txn, ingestId)
  if (!valid) {
    throw new Error(`Data quality validation failed: ${issues.filter(i => i.severity === 'error').map(i => i.issue_type).join(', ')}`)
  }
  
  // 4. Insert into silver layer
  await supabase.rpc('transaction', async (tx: any) => {
    // Insert main transaction
    await tx.from('scout.silver_transactions').insert({
      id: txn.id,
      store_id: txn.store_id,
      ts: txn.timestamp,
      time_of_day: timeOfDay,
      barangay: txn.location.barangay,
      city: txn.location.city,
      province: txn.location.province,
      region: txn.location.region,
      product_category: txn.product_category,
      brand_name: txn.brand_name,
      sku: txn.sku,
      units_per_transaction: txn.units_per_transaction,
      peso_value: pesoValue,
      basket_size: txn.basket_size,
      request_mode: txn.request_mode,
      request_type: txn.request_type,
      suggestion_accepted: txn.suggestion_accepted,
      gender: txn.gender,
      age_bracket: txn.age_bracket,
      duration_seconds: txn.duration_seconds,
      campaign_influenced: txn.campaign_influenced,
      handshake_score: txn.handshake_score,
      is_tbwa_client: txn.is_tbwa_client,
      payment_method: txn.payment_method,
      customer_type: txn.customer_type,
      store_type: txn.store_type,
      economic_class: txn.economic_class
    })
    
    // Insert combo items
    const comboItems = txn.combo_basket.map((item, idx) => ({
      id: txn.id,
      position: idx + 1,
      sku: item.sku,
      quantity: item.quantity || 1
    }))
    await tx.from('scout.silver_combo_items').insert(comboItems)
    
    // Insert substitution if occurred
    if (txn.substitution_event.occurred) {
      await tx.from('scout.silver_substitutions').insert({
        id: txn.id,
        occurred: true,
        from_sku: txn.substitution_event.from_sku,
        to_sku: txn.substitution_event.to_sku,
        reason: txn.substitution_event.reason
      })
    } else {
      await tx.from('scout.silver_substitutions').insert({
        id: txn.id,
        occurred: false
      })
    }
    
    // Mark bronze record as processed
    await tx.from('scout.bronze_transactions_raw')
      .update({ processed: true })
      .eq('ingest_id', ingestId)
  })
}

serve(async (req) => {
  try {
    // CORS headers
    if (req.method === 'OPTIONS') {
      return new Response('ok', {
        headers: {
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
        },
      })
    }
    
    // Initialize Supabase client
    const supabase = createClient(supabaseUrl, supabaseServiceKey, {
      auth: { persistSession: false }
    })
    
    // Parse request
    const { transactions, source_id = 'api' } = await req.json()
    const txnArray = Array.isArray(transactions) ? transactions : [transactions]
    
    const results = []
    const errors = []
    
    for (const rawTxn of txnArray) {
      try {
        // 1. Validate against schema
        const txn = TransactionSchema.parse(rawTxn)
        
        // 2. Store in bronze layer
        const { data: bronze, error: bronzeError } = await supabase
          .from('scout.bronze_transactions_raw')
          .insert({
            payload: rawTxn,
            source_id: source_id
          })
          .select('ingest_id')
          .single()
        
        if (bronzeError) throw bronzeError
        
        // 3. Process to silver layer
        await processTransaction(supabase, txn, bronze.ingest_id)
        
        results.push({
          id: txn.id,
          status: 'success',
          ingest_id: bronze.ingest_id
        })
        
      } catch (error) {
        errors.push({
          id: rawTxn.id || 'unknown',
          status: 'error',
          error: error.message,
          details: error.issues || error
        })
      }
    }
    
    return new Response(
      JSON.stringify({
        processed: results.length,
        errors: errors.length,
        results,
        errors
      }),
      {
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
        status: errors.length > 0 && results.length === 0 ? 400 : 200
      }
    )
    
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      {
        headers: { 'Content-Type': 'application/json' },
        status: 400
      }
    )
  }
})