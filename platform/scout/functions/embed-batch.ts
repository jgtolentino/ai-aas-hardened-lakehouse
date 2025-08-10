// Batch Embedding Edge Function
// Generates embeddings for RAG using OpenAI-compatible endpoint

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.0'

const supabaseUrl = Deno.env.get('SUPABASE_URL')!
const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
const embeddingsUrl = Deno.env.get('EMBEDDINGS_URL') || 'https://api.openai.com/v1/embeddings'
const embeddingsApiKey = Deno.env.get('EMBEDDINGS_API_KEY')!

interface EmbedRequest {
  texts: string[]
  model?: string
  doc_ids?: string[]
  metadata?: Record<string, any>[]
}

async function generateEmbeddings(texts: string[], model: string = 'text-embedding-ada-002') {
  const response = await fetch(embeddingsUrl, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${embeddingsApiKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      input: texts,
      model: model,
    }),
  })

  if (!response.ok) {
    throw new Error(`Embeddings API error: ${response.status} ${await response.text()}`)
  }

  const data = await response.json()
  return data.data.map((item: any) => item.embedding)
}

serve(async (req) => {
  try {
    // CORS
    if (req.method === 'OPTIONS') {
      return new Response('ok', {
        headers: {
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
        },
      })
    }

    const supabase = createClient(supabaseUrl, supabaseServiceKey, {
      auth: { persistSession: false }
    })

    const { texts, model, doc_ids, metadata }: EmbedRequest = await req.json()

    if (!texts || !Array.isArray(texts) || texts.length === 0) {
      return new Response(
        JSON.stringify({ error: 'texts array is required' }),
        { status: 400, headers: { 'Content-Type': 'application/json' } }
      )
    }

    // Batch size limit
    if (texts.length > 100) {
      return new Response(
        JSON.stringify({ error: 'Maximum 100 texts per batch' }),
        { status: 400, headers: { 'Content-Type': 'application/json' } }
      )
    }

    // Generate embeddings
    const embeddings = await generateEmbeddings(texts, model)

    // Store if doc_ids provided
    if (doc_ids && doc_ids.length === texts.length) {
      const embeddingRecords = texts.map((text, idx) => ({
        doc_id: doc_ids[idx],
        content: text,
        embedding: embeddings[idx],
        metadata: metadata?.[idx] || {},
        created_at: new Date().toISOString()
      }))

      const { error: insertError } = await supabase
        .from('embeddings')
        .upsert(embeddingRecords, { onConflict: 'doc_id' })

      if (insertError) {
        console.error('Failed to store embeddings:', insertError)
      }
    }

    return new Response(
      JSON.stringify({
        embeddings: embeddings,
        count: embeddings.length,
        model: model || 'text-embedding-ada-002',
        stored: !!doc_ids
      }),
      {
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
      }
    )
  } catch (error) {
    console.error('Embed batch error:', error)
    return new Response(
      JSON.stringify({ error: error.message }),
      {
        status: 500,
        headers: { 'Content-Type': 'application/json' },
      }
    )
  }
})