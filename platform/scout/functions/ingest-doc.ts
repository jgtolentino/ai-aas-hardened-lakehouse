// Document Ingestion Edge Function
// Processes documents for RAG with chunking and metadata extraction

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.0'

const supabaseUrl = Deno.env.get('SUPABASE_URL')!
const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

interface DocIngestRequest {
  title: string
  content: string
  doc_type: 'policy' | 'runbook' | 'guide' | 'report' | 'other'
  metadata?: Record<string, any>
  chunk_size?: number
  chunk_overlap?: number
}

function chunkText(text: string, chunkSize: number = 1000, overlap: number = 200): string[] {
  const chunks: string[] = []
  let start = 0
  
  while (start < text.length) {
    const end = start + chunkSize
    chunks.push(text.slice(start, end))
    start = end - overlap
  }
  
  return chunks
}

function extractMetadata(content: string, docType: string): Record<string, any> {
  const metadata: Record<string, any> = {
    doc_type: docType,
    char_count: content.length,
    word_count: content.split(/\s+/).length,
    line_count: content.split('\n').length,
  }
  
  // Extract sections/headers
  const headers = content.match(/^#{1,3}\s+(.+)$/gm) || []
  metadata.sections = headers.map(h => h.replace(/^#+\s+/, ''))
  
  // Extract key terms (simple approach)
  const keyTerms = new Set<string>()
  const terms = ['dashboard', 'api', 'rls', 'policy', 'supabase', 'scout', 'transaction', 'analytics']
  terms.forEach(term => {
    if (content.toLowerCase().includes(term)) {
      keyTerms.add(term)
    }
  })
  metadata.key_terms = Array.from(keyTerms)
  
  return metadata
}

serve(async (req) => {
  try {
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

    const { 
      title, 
      content, 
      doc_type, 
      metadata: userMetadata,
      chunk_size = 1000,
      chunk_overlap = 200
    }: DocIngestRequest = await req.json()

    // Validate inputs
    if (!title || !content || !doc_type) {
      return new Response(
        JSON.stringify({ error: 'title, content, and doc_type are required' }),
        { status: 400, headers: { 'Content-Type': 'application/json' } }
      )
    }

    if (content.length > 1000000) { // 1MB limit
      return new Response(
        JSON.stringify({ error: 'Content too large (max 1MB)' }),
        { status: 400, headers: { 'Content-Type': 'application/json' } }
      )
    }

    // Extract metadata
    const extractedMetadata = extractMetadata(content, doc_type)
    const finalMetadata = { ...extractedMetadata, ...userMetadata }

    // Create document record
    const { data: doc, error: docError } = await supabase
      .from('documents')
      .insert({
        title,
        doc_type,
        content,
        metadata: finalMetadata,
        created_at: new Date().toISOString()
      })
      .select()
      .single()

    if (docError) {
      throw new Error(`Failed to create document: ${docError.message}`)
    }

    // Chunk the content
    const chunks = chunkText(content, chunk_size, chunk_overlap)
    
    // Create chunk records
    const chunkRecords = chunks.map((chunk, idx) => ({
      doc_id: doc.id,
      chunk_index: idx,
      content: chunk,
      metadata: {
        chunk_size: chunk.length,
        position: idx + 1,
        total_chunks: chunks.length,
        ...finalMetadata
      }
    }))

    const { error: chunkError } = await supabase
      .from('doc_chunks')
      .insert(chunkRecords)

    if (chunkError) {
      // Rollback document creation
      await supabase.from('documents').delete().eq('id', doc.id)
      throw new Error(`Failed to create chunks: ${chunkError.message}`)
    }

    // Queue for embedding generation
    const { error: queueError } = await supabase
      .from('embedding_queue')
      .insert({
        doc_id: doc.id,
        status: 'pending',
        chunk_count: chunks.length
      })

    if (queueError) {
      console.error('Failed to queue for embeddings:', queueError)
    }

    return new Response(
      JSON.stringify({
        success: true,
        doc_id: doc.id,
        title: title,
        chunks_created: chunks.length,
        metadata: finalMetadata,
        queued_for_embedding: !queueError
      }),
      {
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
      }
    )
  } catch (error) {
    console.error('Document ingest error:', error)
    return new Response(
      JSON.stringify({ error: error.message }),
      {
        status: 500,
        headers: { 'Content-Type': 'application/json' },
      }
    )
  }
})