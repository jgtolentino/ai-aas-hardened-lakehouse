import 'jsr:@supabase/functions-js/edge-runtime.d.ts'
import OpenAI from 'npm:@openai/openai@4.52.0'
import { createClient } from 'npm:@supabase/supabase-js@2.45.0'

// Initialize OpenAI client
const openai = new OpenAI({
  apiKey: Deno.env.get('OPENAI_API_KEY'),
})

// Initialize Supabase client
const supabaseUrl = Deno.env.get('SUPABASE_URL') || ''
const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || ''
const supabase = createClient(supabaseUrl, supabaseKey)

// Configuration
const EMBEDDING_MODEL = 'text-embedding-3-small'
const CHAT_MODEL = 'gpt-4o-mini'
const MAX_CONTEXT_TOKENS = 3000
const DEFAULT_CONFIDENCE_THRESHOLD = 0.3

interface InsightRequest {
  query: string
  context: Record<string, any>
  options?: {
    maxSources?: number
    includeActionItems?: boolean
    confidenceThreshold?: number
    priority?: 'low' | 'medium' | 'high' | 'critical'
  }
}

interface Source {
  title: string
  content: string
  url?: string
  relevance: number
}

interface Insight {
  id: string
  title: string
  summary: string
  fullExplanation?: string
  confidence: number
  priority: 'low' | 'medium' | 'high' | 'critical'
  category: string
  actionItems?: string[]
  sources?: Array<{
    title: string
    url?: string
    relevance: number
  }>
  metadata?: {
    generated_at: string
    model_version: string
    context_tokens: number
    query_embedding_time: number
    rag_retrieval_time: number
    llm_generation_time: number
  }
}

// Generate embedding for the query
async function generateQueryEmbedding(query: string): Promise<number[]> {
  const startTime = Date.now()
  
  try {
    const response = await openai.embeddings.create({
      model: EMBEDDING_MODEL,
      input: query.trim(),
      encoding_format: 'float'
    })
    
    return response.data[0].embedding
  } catch (error) {
    console.error('Embedding generation failed:', error)
    throw new Error(`Failed to generate query embedding: ${error.message}`)
  }
}

// Retrieve relevant context from knowledge base using RAG
async function retrieveRelevantContext(
  queryEmbedding: number[], 
  maxSources: number = 5,
  threshold: number = DEFAULT_CONFIDENCE_THRESHOLD
): Promise<{ sources: Source[]; retrievalTime: number }> {
  const startTime = Date.now()
  
  try {
    // Call the match_documents function to get relevant content
    const { data: documents, error } = await supabase.rpc('match_documents', {
      query_embedding: `[${queryEmbedding.join(',')}]`,
      match_threshold: threshold,
      match_count: maxSources
    })

    if (error) {
      console.error('RAG retrieval error:', error)
      throw new Error(`Knowledge base query failed: ${error.message}`)
    }

    const sources: Source[] = (documents || []).map((doc: any) => ({
      title: doc.title || 'Untitled Document',
      content: doc.content || '',
      url: doc.url,
      relevance: doc.similarity || 0
    }))

    const retrievalTime = Date.now() - startTime

    return { sources, retrievalTime }
    
  } catch (error) {
    console.error('Context retrieval failed:', error)
    throw new Error(`Failed to retrieve relevant context: ${error.message}`)
  }
}

// Generate insight using OpenAI with RAG context
async function generateInsightWithLLM(
  query: string,
  context: Record<string, any>,
  sources: Source[],
  options: InsightRequest['options'] = {}
): Promise<{ insight: Omit<Insight, 'metadata'>; generationTime: number }> {
  const startTime = Date.now()
  
  try {
    // Build context-aware prompt
    const systemPrompt = `You are a business intelligence expert analyzing data for Scout Dashboard. 
Your role is to provide actionable insights based on business metrics and knowledge base context.

Guidelines:
- Provide specific, actionable insights with clear explanations
- Focus on business impact and measurable outcomes
- Include confidence levels (0-100) based on data quality and completeness
- Categorize insights as: trend, alert, opportunity, recommendation, or analysis
- Prioritize insights as: low, medium, high, or critical based on business impact
- Generate 2-4 specific action items when requested
- Keep insights concise but comprehensive (2-3 sentences for summary)

Context format:
- Business metrics: ${JSON.stringify(context, null, 2)}
- Knowledge base context: Available below from relevant documents`

    const userPrompt = `Query: ${query}

Business Context:
${Object.entries(context).map(([key, value]) => `- ${key}: ${value}`).join('\n')}

Knowledge Base Context:
${sources.map((source, index) => 
  `Source ${index + 1} (relevance: ${(source.relevance * 100).toFixed(0)}%):
Title: ${source.title}
Content: ${source.content.slice(0, 800)}...`
).join('\n\n')}

Please provide a comprehensive business insight in this JSON format:
{
  "title": "Clear, actionable insight title",
  "summary": "2-3 sentence explanation of the key insight and its business impact",
  "fullExplanation": "Detailed explanation if needed",
  "confidence": 85,
  "priority": "high",
  "category": "trend|alert|opportunity|recommendation|analysis",
  "actionItems": ["Specific action 1", "Specific action 2", "Specific action 3"]
}`

    const completion = await openai.chat.completions.create({
      model: CHAT_MODEL,
      messages: [
        { role: 'system', content: systemPrompt },
        { role: 'user', content: userPrompt }
      ],
      temperature: 0.3,
      max_tokens: 1500,
      response_format: { type: 'json_object' }
    })

    const responseContent = completion.choices[0].message.content
    if (!responseContent) {
      throw new Error('Empty response from LLM')
    }

    const parsedInsight = JSON.parse(responseContent)
    
    // Validate and sanitize the response
    const insight: Omit<Insight, 'metadata'> = {
      id: crypto.randomUUID(),
      title: parsedInsight.title || 'Insight Analysis',
      summary: parsedInsight.summary || 'No summary available',
      fullExplanation: parsedInsight.fullExplanation,
      confidence: Math.max(0, Math.min(100, parsedInsight.confidence || 50)),
      priority: ['low', 'medium', 'high', 'critical'].includes(parsedInsight.priority) 
        ? parsedInsight.priority 
        : options.priority || 'medium',
      category: parsedInsight.category || 'analysis',
      actionItems: options.includeActionItems !== false 
        ? (parsedInsight.actionItems || []).slice(0, 5) 
        : undefined,
      sources: sources.length > 0 ? sources.map(s => ({
        title: s.title,
        url: s.url,
        relevance: s.relevance
      })) : undefined
    }

    const generationTime = Date.now() - startTime
    return { insight, generationTime }
    
  } catch (error) {
    console.error('LLM generation failed:', error)
    throw new Error(`Failed to generate insight: ${error.message}`)
  }
}

// Main request handler
Deno.serve(async (req) => {
  // CORS headers
  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type'
  }
  
  // Handle preflight requests
  if (req.method === 'OPTIONS') {
    return new Response(null, { status: 200, headers: corsHeaders })
  }
  
  // Only allow POST requests
  if (req.method !== 'POST') {
    return new Response(JSON.stringify({ 
      error: 'Method not allowed',
      message: 'This endpoint only accepts POST requests'
    }), {
      status: 405,
      headers: { 'Content-Type': 'application/json', ...corsHeaders }
    })
  }

  try {
    const startTime = Date.now()
    const requestBody: InsightRequest = await req.json()
    const { query, context, options = {} } = requestBody

    if (!query || typeof query !== 'string') {
      return new Response(JSON.stringify({ 
        error: 'Invalid request',
        message: 'Query parameter is required and must be a string'
      }), {
        status: 400,
        headers: { 'Content-Type': 'application/json', ...corsHeaders }
      })
    }

    console.log(`Generating insight for query: "${query.slice(0, 100)}..."`)

    // Step 1: Generate embedding for the query
    const embeddingStartTime = Date.now()
    const queryEmbedding = await generateQueryEmbedding(query)
    const embeddingTime = Date.now() - embeddingStartTime

    // Step 2: Retrieve relevant context from knowledge base
    const { sources, retrievalTime } = await retrieveRelevantContext(
      queryEmbedding,
      options.maxSources || 5,
      options.confidenceThreshold || DEFAULT_CONFIDENCE_THRESHOLD
    )

    console.log(`Retrieved ${sources.length} relevant sources`)

    // Step 3: Generate insight using LLM with RAG context
    const { insight, generationTime } = await generateInsightWithLLM(
      query,
      context,
      sources,
      options
    )

    // Build complete response with metadata
    const completeInsight: Insight = {
      ...insight,
      metadata: {
        generated_at: new Date().toISOString(),
        model_version: CHAT_MODEL,
        context_tokens: sources.reduce((total, s) => total + s.content.length, 0),
        query_embedding_time: embeddingTime,
        rag_retrieval_time: retrievalTime,
        llm_generation_time: generationTime
      }
    }

    const totalTime = Date.now() - startTime

    const response = {
      insight: completeInsight,
      performance: {
        total_time: totalTime,
        embedding_time: embeddingTime,
        retrieval_time: retrievalTime,
        generation_time: generationTime,
        sources_retrieved: sources.length
      },
      debug: {
        query_length: query.length,
        context_keys: Object.keys(context),
        avg_source_relevance: sources.length > 0 
          ? sources.reduce((sum, s) => sum + s.relevance, 0) / sources.length 
          : 0
      }
    }

    console.log(`Insight generated successfully in ${totalTime}ms`)

    return new Response(JSON.stringify(response), {
      status: 200,
      headers: { 'Content-Type': 'application/json', ...corsHeaders }
    })
    
  } catch (error) {
    console.error('Insight generation failed:', error)
    
    const errorResponse = {
      error: 'Insight generation failed',
      message: error.message || 'An unexpected error occurred',
      timestamp: new Date().toISOString()
    }

    // Determine appropriate status code
    let statusCode = 500
    if (error.message.includes('unauthorized') || error.message.includes('authentication')) {
      statusCode = 401
    } else if (error.message.includes('not found') || error.message.includes('missing')) {
      statusCode = 404
    } else if (error.message.includes('invalid') || error.message.includes('bad request')) {
      statusCode = 400
    }

    return new Response(JSON.stringify(errorResponse), {
      status: statusCode,
      headers: { 'Content-Type': 'application/json', ...corsHeaders }
    })
  }
})