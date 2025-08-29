import 'jsr:@supabase/functions-js/edge-runtime.d.ts'
import OpenAI from 'npm:@openai/openai@4.52.0'
import { createClient } from 'npm:@supabase/supabase-js@2.45.0'
import { load } from 'npm:cheerio@1.0.0-rc.12'
import * as marked from 'npm:marked@12.0.2'
import TurndownService from 'npm:turndown@7.1.2'

// Initialize OpenAI client with modern model
const openai = new OpenAI({
  apiKey: Deno.env.get('OPENAI_API_KEY'),
})

// Initialize Supabase client
const supabaseUrl = Deno.env.get('SUPABASE_URL') || ''
const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || ''
const supabase = createClient(supabaseUrl, supabaseKey)

// Configuration
const EMBEDDING_MODEL = 'text-embedding-3-small' // Modern OpenAI model
const MAX_TOKENS_PER_CHUNK = 700
const OVERLAP_TOKENS = 80
const MAX_RETRIES = 4
const INITIAL_RETRY_DELAY = 300
const CONCURRENCY_LIMIT = 4

// Token-aware chunking that preserves semantic coherence
function splitBySentenceTokens(
  text: string, 
  { maxTokens = MAX_TOKENS_PER_CHUNK, overlapTokens = OVERLAP_TOKENS } = {}
): string[] {
  const sentences = text.split(/(?<=[\.\?\!])\s+/)
  const chunks: string[] = []
  let buffer: string[] = []
  let estimatedTokens = 0
  
  // Rough token estimation (1 token ≈ 4 characters)
  const estimateTokens = (text: string): number => Math.ceil(text.length / 4)

  for (const sentence of sentences) {
    const sentenceTokens = estimateTokens(sentence)
    
    // If adding this sentence would exceed the limit and we have content
    if (estimatedTokens + sentenceTokens > maxTokens && buffer.length > 0) {
      chunks.push(buffer.join(' '))
      
      // Maintain overlap by keeping the last few sentences
      const overlapBuffer: string[] = []
      let overlapTokenCount = 0
      let index = buffer.length - 1
      
      while (index >= 0 && overlapTokenCount < overlapTokens) {
        const sentence = buffer[index]
        const tokens = estimateTokens(sentence)
        if (overlapTokenCount + tokens <= overlapTokens) {
          overlapBuffer.unshift(sentence)
          overlapTokenCount += tokens
          index--
        } else {
          break
        }
      }
      
      buffer = overlapBuffer
      estimatedTokens = overlapTokenCount
    }
    
    buffer.push(sentence)
    estimatedTokens += sentenceTokens
  }
  
  // Add the final chunk if there's content
  if (buffer.length > 0) {
    chunks.push(buffer.join(' '))
  }
  
  return chunks.filter(chunk => chunk.trim().length > 0)
}

// Resilient embedding generation with exponential backoff
async function embedText(text: string): Promise<number[]> {
  let delay = INITIAL_RETRY_DELAY
  
  for (let attempt = 0; attempt < MAX_RETRIES; attempt++) {
    try {
      const response = await openai.embeddings.create({
        model: EMBEDDING_MODEL,
        input: text.trim(),
        encoding_format: 'float'
      })
      
      return response.data[0].embedding
    } catch (error) {
      console.error(`Embedding attempt ${attempt + 1} failed:`, error)
      
      // Don't retry on the last attempt
      if (attempt === MAX_RETRIES - 1) {
        throw new Error(`Failed to generate embedding after ${MAX_RETRIES} attempts: ${error.message}`)
      }
      
      // Check if it's a rate limit error and adjust delay
      if (error.status === 429) {
        delay = Math.min(delay * 3, 30000) // Cap at 30 seconds
      }
      
      // Wait before retrying with exponential backoff
      await new Promise(resolve => setTimeout(resolve, delay))
      delay *= 2
    }
  }
  
  throw new Error('Unreachable code path in embedText')
}

// Generate SHA-256 checksum for content deduplication
async function generateChecksum(content: string): Promise<string> {
  const encoder = new TextEncoder()
  const data = encoder.encode(content)
  const hashBuffer = await crypto.subtle.digest('SHA-256', data)
  const hashArray = Array.from(new Uint8Array(hashBuffer))
  return hashArray.map(b => b.toString(16).padStart(2, '0')).join('')
}

// Upsert document using the database function for idempotency
async function upsertDocument(
  title: string,
  content: string,
  url?: string,
  metadata?: Record<string, any>,
  embedding?: number[],
  checksum?: string
): Promise<{ id: number; status: 'inserted' | 'existing' }> {
  const { data, error } = await supabase.rpc('upsert_document', {
    title_param: title,
    content_param: content,
    url_param: url || null,
    metadata_param: metadata || {},
    embedding_param: embedding ? `[${embedding.join(',')}]` : null,
    checksum_param: checksum
  })
  
  if (error) {
    console.error('Database upsert error:', error)
    throw new Error(`Database error: ${error.message}`)
  }
  
  // Check if this is a new insert or existing document
  const isExisting = await supabase
    .from('documents')
    .select('id')
    .eq('id', data)
    .single()
  
  return {
    id: data,
    status: checksum ? 'existing' : 'inserted'
  }
}

// Process text document with token-aware chunking and concurrent processing
async function processTextDocument(document: {
  title?: string
  content: string
  url?: string
  metadata?: Record<string, any>
}) {
  const { title = 'Untitled', content, url, metadata = {} } = document
  
  // Generate checksum for idempotency
  const checksum = await generateChecksum(content)
  
  // Check if document already exists
  const { data: existingDoc } = await supabase
    .from('documents')
    .select('id')
    .eq('checksum', checksum)
    .maybeSingle()
  
  if (existingDoc) {
    return { 
      id: existingDoc.id, 
      status: 'unchanged',
      message: 'Document already exists with same content' 
    }
  }
  
  // Split content into semantic chunks
  const chunks = splitBySentenceTokens(content, { 
    maxTokens: MAX_TOKENS_PER_CHUNK, 
    overlapTokens: OVERLAP_TOKENS 
  })
  
  if (chunks.length === 0) {
    throw new Error('No valid chunks generated from content')
  }
  
  console.log(`Processing ${chunks.length} chunks for document: ${title}`)
  
  const results: number[] = []
  const errors: string[] = []
  
  // Process chunks with controlled concurrency
  let chunkIndex = 0
  
  async function processWorker(): Promise<void> {
    while (chunkIndex < chunks.length) {
      const currentIndex = chunkIndex++
      const chunk = chunks[currentIndex]
      
      try {
        // Generate embedding for chunk
        const embedding = await embedText(chunk)
        
        // Store chunk with embedding
        const result = await upsertDocument(
          `${title} (part ${currentIndex + 1}/${chunks.length})`,
          chunk,
          url,
          { 
            ...metadata, 
            chunk_index: currentIndex,
            total_chunks: chunks.length,
            parent_checksum: checksum
          },
          embedding,
          `${checksum}_chunk_${currentIndex}`
        )
        
        results.push(result.id)
        console.log(`Processed chunk ${currentIndex + 1}/${chunks.length}`)
        
      } catch (error) {
        const errorMsg = `Chunk ${currentIndex + 1}: ${error.message}`
        console.error(errorMsg)
        errors.push(errorMsg)
      }
    }
  }
  
  // Run workers with concurrency limit
  const workers = Array.from(
    { length: Math.min(CONCURRENCY_LIMIT, chunks.length) },
    processWorker
  )
  
  await Promise.all(workers)
  
  return {
    ids: results,
    status: 'processed',
    chunks: chunks.length,
    successful: results.length,
    errors: errors.length > 0 ? errors : undefined
  }
}

// Process HTML document by converting to markdown first
async function processHtmlDocument(document: {
  title?: string
  content: string
  url?: string
  metadata?: Record<string, any>
}) {
  const { content, ...rest } = document
  
  try {
    // Parse HTML and clean up
    const $ = load(content)
    
    // Remove non-content elements
    $('script, style, nav, footer, header, .nav, .navigation, .menu, .sidebar').remove()
    
    // Try to extract main content area
    let mainContent = $('main').html() || 
                     $('article').html() || 
                     $('#content, .content').html() || 
                     $('.article, .post').html() || 
                     $('body').html()
    
    if (!mainContent) {
      throw new Error('No content found in HTML')
    }
    
    // Convert HTML to Markdown using Turndown
    const turndownService = new TurndownService({
      headingStyle: 'atx',
      bulletListMarker: '-',
      codeBlockStyle: 'fenced'
    })
    
    // Configure Turndown to handle more elements
    turndownService.addRule('removeEmpty', {
      filter: (node) => {
        return node.nodeName === 'P' && !node.textContent?.trim()
      },
      replacement: () => ''
    })
    
    const markdown = turndownService.turndown(mainContent)
    
    // Convert markdown to plain text for embedding
    const html = await marked.parse(markdown)
    const plainText = load(html).text()
    
    return await processTextDocument({
      ...rest,
      content: plainText,
      metadata: {
        ...rest.metadata,
        original_format: 'html',
        converted_via: 'markdown'
      }
    })
    
  } catch (error) {
    console.error('HTML processing error:', error)
    throw new Error(`HTML processing failed: ${error.message}`)
  }
}

// Process Markdown document
async function processMarkdownDocument(document: {
  title?: string
  content: string
  url?: string
  metadata?: Record<string, any>
}) {
  try {
    // Convert Markdown to HTML then to plain text
    const html = await marked.parse(document.content)
    const $ = load(html)
    const plainText = $.text()
    
    return await processTextDocument({
      ...document,
      content: plainText,
      metadata: {
        ...document.metadata,
        original_format: 'markdown'
      }
    })
    
  } catch (error) {
    console.error('Markdown processing error:', error)
    throw new Error(`Markdown processing failed: ${error.message}`)
  }
}

// Main request handler
Deno.serve(async (req) => {
  // CORS headers for development
  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type'
  }
  
  // Handle preflight requests
  if (req.method === 'OPTIONS') {
    return new Response(null, { 
      status: 200,
      headers: corsHeaders 
    })
  }
  
  // Only allow POST requests
  if (req.method !== 'POST') {
    return new Response(JSON.stringify({ 
      error: 'Method not allowed',
      message: 'This endpoint only accepts POST requests'
    }), {
      status: 405,
      headers: { 
        'Content-Type': 'application/json',
        ...corsHeaders
      }
    })
  }
  
  try {
    const requestBody = await req.json()
    const { documents } = requestBody
    
    if (!Array.isArray(documents)) {
      return new Response(JSON.stringify({ 
        error: 'Invalid request format',
        message: 'Expected "documents" array in request body'
      }), {
        status: 400,
        headers: { 
          'Content-Type': 'application/json',
          ...corsHeaders
        }
      })
    }
    
    if (documents.length === 0) {
      return new Response(JSON.stringify({ 
        error: 'Empty request',
        message: 'No documents provided for processing'
      }), {
        status: 400,
        headers: { 
          'Content-Type': 'application/json',
          ...corsHeaders
        }
      })
    }
    
    console.log(`Processing ${documents.length} document(s)`)
    
    const results: Array<{
      document: string
      result?: any
      error?: string
      processingTime?: number
    }> = []
    
    // Process documents sequentially to avoid overwhelming the system
    for (const [index, document] of documents.entries()) {
      const startTime = Date.now()
      const documentId = document.title || document.url || `document_${index + 1}`
      
      try {
        console.log(`Processing document ${index + 1}/${documents.length}: ${documentId}`)
        
        let result
        const docType = document.type?.toLowerCase() || 'text'
        
        switch (docType) {
          case 'html':
            result = await processHtmlDocument(document)
            break
          case 'markdown':
          case 'md':
            result = await processMarkdownDocument(document)
            break
          default:
            result = await processTextDocument(document)
        }
        
        const processingTime = Date.now() - startTime
        
        results.push({
          document: documentId,
          result,
          processingTime
        })
        
        console.log(`Completed document ${index + 1}/${documents.length} in ${processingTime}ms`)
        
      } catch (error) {
        const processingTime = Date.now() - startTime
        const errorMessage = error.message || 'Unknown error occurred'
        
        console.error(`Error processing document ${index + 1}/${documents.length}: ${documentId}`, error)
        
        results.push({
          document: documentId,
          error: errorMessage,
          processingTime
        })
      }
    }
    
    // Calculate summary statistics
    const successful = results.filter(r => !r.error).length
    const failed = results.filter(r => r.error).length
    const totalProcessingTime = results.reduce((sum, r) => sum + (r.processingTime || 0), 0)
    
    const response = {
      summary: {
        total: documents.length,
        successful,
        failed,
        totalProcessingTime,
        averageProcessingTime: Math.round(totalProcessingTime / documents.length)
      },
      results,
      metadata: {
        timestamp: new Date().toISOString(),
        embeddingModel: EMBEDDING_MODEL,
        maxTokensPerChunk: MAX_TOKENS_PER_CHUNK,
        overlapTokens: OVERLAP_TOKENS
      }
    }
    
    return new Response(JSON.stringify(response), {
      status: 200,
      headers: { 
        'Content-Type': 'application/json',
        ...corsHeaders
      }
    })
    
  } catch (error) {
    console.error('Request processing error:', error)
    
    const errorResponse = {
      error: 'Internal server error',
      message: error.message || 'An unexpected error occurred',
      timestamp: new Date().toISOString()
    }
    
    return new Response(JSON.stringify(errorResponse), {
      status: 500,
      headers: { 
        'Content-Type': 'application/json',
        ...corsHeaders
      }
    })
  }
})