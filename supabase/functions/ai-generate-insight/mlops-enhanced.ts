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

// Configuration with A/B testing support
const MODEL_CONFIGS = {
  control: {
    EMBEDDING_MODEL: 'text-embedding-3-small',
    CHAT_MODEL: 'gpt-4o-mini',
    TEMPERATURE: 0.3,
    MAX_TOKENS: 1500
  },
  treatment: {
    EMBEDDING_MODEL: 'text-embedding-3-small', 
    CHAT_MODEL: 'gpt-4o-mini',
    TEMPERATURE: 0.2, // Lower temperature for treatment
    MAX_TOKENS: 1200   // Fewer tokens for cost optimization
  }
}

const DEFAULT_CONFIDENCE_THRESHOLD = 0.3
const FUNCTION_NAME = 'ai-generate-insight'
const MODEL_VERSION = 'v1.1'

// =====================================================
// MLOPS INTERFACES
// =====================================================

interface MLOpsMetrics {
  requestId: string
  userId?: string
  startTime: number
  endTime?: number
  success: boolean
  latency: number
  inputTokens?: number
  outputTokens?: number
  estimatedCost?: number
  confidenceScore?: number
  experimentVariant?: 'control' | 'treatment'
  errorMessage?: string
}

interface ExperimentConfig {
  experimentId: string
  variant: 'control' | 'treatment'
  modelConfig: typeof MODEL_CONFIGS.control
}

// =====================================================
// MLOPS UTILITIES
// =====================================================

// Generate unique request ID
function generateRequestId(): string {
  return crypto.randomUUID()
}

// Get experiment assignment for user
async function getExperimentAssignment(userId?: string): Promise<ExperimentConfig> {
  if (!userId) {
    return {
      experimentId: 'default',
      variant: 'control',
      modelConfig: MODEL_CONFIGS.control
    }
  }

  try {
    // Call the database function to get assignment
    const { data, error } = await supabase.rpc('mlops.get_experiment_assignment', {
      p_experiment_id: 'insight-optimization-v1',
      p_user_id: userId
    })

    if (error) {
      console.warn('Experiment assignment failed:', error)
      return {
        experimentId: 'insight-optimization-v1',
        variant: 'control',
        modelConfig: MODEL_CONFIGS.control
      }
    }

    const variant = data as 'control' | 'treatment'
    return {
      experimentId: 'insight-optimization-v1',
      variant,
      modelConfig: MODEL_CONFIGS[variant]
    }
  } catch (error) {
    console.warn('Experiment assignment error:', error)
    return {
      experimentId: 'insight-optimization-v1',
      variant: 'control',
      modelConfig: MODEL_CONFIGS.control
    }
  }
}

// Calculate token costs (OpenAI pricing as of 2024)
function calculateCost(inputTokens: number, outputTokens: number, model: string): number {
  const pricing: Record<string, { input: number, output: number }> = {
    'gpt-4o-mini': { input: 0.00015, output: 0.0006 }, // per 1K tokens
    'text-embedding-3-small': { input: 0.00002, output: 0 }
  }

  const rates = pricing[model] || pricing['gpt-4o-mini']
  const inputCost = (inputTokens / 1000) * rates.input
  const outputCost = (outputTokens / 1000) * rates.output
  
  return inputCost + outputCost
}

// Log performance metrics to MLOps system
async function logMLOpsMetrics(metrics: MLOpsMetrics): Promise<void> {
  try {
    const { error } = await supabase.rpc('mlops.log_model_performance', {
      p_function_name: FUNCTION_NAME,
      p_model_version: MODEL_VERSION,
      p_request_id: metrics.requestId,
      p_latency_ms: metrics.latency,
      p_success: metrics.success,
      p_confidence_score: metrics.confidenceScore,
      p_input_tokens: metrics.inputTokens,
      p_output_tokens: metrics.outputTokens,
      p_estimated_cost: metrics.estimatedCost,
      p_user_id: metrics.userId,
      p_error_message: metrics.errorMessage
    })

    if (error) {
      console.error('Failed to log MLOps metrics:', error)
    }

    // Also log to cost tracking
    if (metrics.inputTokens && metrics.outputTokens && metrics.estimatedCost) {
      await supabase.from('mlops.cost_tracking').insert({
        function_name: FUNCTION_NAME,
        model_version: MODEL_VERSION,
        prompt_tokens: metrics.inputTokens,
        completion_tokens: metrics.outputTokens,
        prompt_cost: calculateCost(metrics.inputTokens, 0, 'gpt-4o-mini'),
        completion_cost: calculateCost(0, metrics.outputTokens, 'gpt-4o-mini'),
        request_id: metrics.requestId,
        user_id: metrics.userId
      })
    }
  } catch (error) {
    console.error('MLOps logging failed:', error)
    // Don't fail the request if logging fails
  }
}

// Check for alerts based on performance metrics
async function checkAlertThresholds(metrics: MLOpsMetrics): Promise<void> {
  try {
    // Check latency threshold (5 seconds)
    if (metrics.latency > 5000) {
      await supabase.from('mlops.alert_instances').insert({
        rule_id: (await supabase.from('mlops.alert_rules').select('id').eq('rule_name', 'High Latency Alert').single()).data?.id,
        alert_message: `High latency detected: ${metrics.latency}ms for request ${metrics.requestId}`,
        severity: 'high',
        metric_value: metrics.latency,
        threshold_value: 5000,
        function_name: FUNCTION_NAME
      })
    }

    // Check confidence score (if too low)
    if (metrics.confidenceScore && metrics.confidenceScore < 0.3) {
      await supabase.from('mlops.alert_instances').insert({
        rule_id: (await supabase.from('mlops.alert_rules').select('id').eq('rule_name', 'Low Confidence Alert').single()).data?.id,
        alert_message: `Low confidence insight: ${metrics.confidenceScore} for request ${metrics.requestId}`,
        severity: 'medium',
        metric_value: metrics.confidenceScore,
        threshold_value: 0.3,
        function_name: FUNCTION_NAME
      })
    }
  } catch (error) {
    console.error('Alert checking failed:', error)
  }
}

// =====================================================
// ENHANCED CORE FUNCTIONS
// =====================================================

// Generate embedding with MLOps tracking
async function generateQueryEmbedding(query: string, config: ExperimentConfig): Promise<number[]> {
  const startTime = Date.now()
  
  try {
    const response = await openai.embeddings.create({
      model: config.modelConfig.EMBEDDING_MODEL,
      input: query.trim(),
      encoding_format: 'float'
    })
    
    return response.data[0].embedding
  } catch (error) {
    console.error('Embedding generation failed:', error)
    throw new Error(`Failed to generate query embedding: ${error.message}`)
  }
}

// Retrieve relevant context with enhanced caching
async function retrieveRelevantContext(
  queryEmbedding: number[], 
  maxSources: number = 5,
  threshold: number = DEFAULT_CONFIDENCE_THRESHOLD
): Promise<{ sources: any[], retrievalTime: number }> {
  const startTime = Date.now()
  
  try {
    // Check cache first (simple implementation)
    const cacheKey = queryEmbedding.slice(0, 10).join(',') // Use first 10 dimensions as key
    
    const { data: documents, error } = await supabase.rpc('match_documents', {
      query_embedding: `[${queryEmbedding.join(',')}]`,
      match_threshold: threshold,
      match_count: maxSources
    })

    if (error) {
      throw new Error(`Knowledge base query failed: ${error.message}`)
    }

    const sources = (documents || []).map((doc: any) => ({
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

// Generate insight with A/B testing and enhanced prompting
async function generateInsightWithLLM(
  query: string,
  context: Record<string, any>,
  sources: any[],
  config: ExperimentConfig,
  options: any = {}
): Promise<{ insight: any; generationTime: number; tokenUsage: { prompt: number, completion: number } }> {
  const startTime = Date.now()
  
  try {
    // Enhanced system prompt based on variant
    const systemPromptBase = `You are a business intelligence expert analyzing data for Scout Dashboard. 
Your role is to provide actionable insights based on business metrics and knowledge base context.

Guidelines:
- Provide specific, actionable insights with clear explanations
- Focus on business impact and measurable outcomes  
- Include confidence levels (0-100) based on data quality and completeness
- Categorize insights as: trend, alert, opportunity, recommendation, or analysis
- Prioritize insights as: low, medium, high, or critical based on business impact`

    const systemPrompt = config.variant === 'treatment' 
      ? systemPromptBase + `\n- Be more concise and cost-efficient in responses
- Focus on the top 2-3 most important insights only
- Use structured bullet points for clarity`
      : systemPromptBase + `\n- Generate 2-4 specific action items when requested
- Keep insights comprehensive but accessible (2-3 sentences for summary)
- Provide detailed explanations when helpful`

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
      model: config.modelConfig.CHAT_MODEL,
      messages: [
        { role: 'system', content: systemPrompt },
        { role: 'user', content: userPrompt }
      ],
      temperature: config.modelConfig.TEMPERATURE,
      max_tokens: config.modelConfig.MAX_TOKENS,
      response_format: { type: 'json_object' }
    })

    const responseContent = completion.choices[0].message.content
    if (!responseContent) {
      throw new Error('Empty response from LLM')
    }

    const tokenUsage = {
      prompt: completion.usage?.prompt_tokens || 0,
      completion: completion.usage?.completion_tokens || 0
    }

    const parsedInsight = JSON.parse(responseContent)
    
    // Validate and sanitize the response
    const insight = {
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
      })) : undefined,
      // MLOps metadata
      experimentVariant: config.variant,
      experimentId: config.experimentId,
      modelVersion: MODEL_VERSION
    }

    const generationTime = Date.now() - startTime
    return { insight, generationTime, tokenUsage }
    
  } catch (error) {
    console.error('LLM generation failed:', error)
    throw new Error(`Failed to generate insight: ${error.message}`)
  }
}

// =====================================================
// MAIN REQUEST HANDLER WITH MLOPS
// =====================================================

Deno.serve(async (req) => {
  // CORS headers
  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-user-id'
  }
  
  if (req.method === 'OPTIONS') {
    return new Response(null, { status: 200, headers: corsHeaders })
  }
  
  if (req.method !== 'POST') {
    return new Response(JSON.stringify({ 
      error: 'Method not allowed',
      message: 'This endpoint only accepts POST requests'
    }), {
      status: 405,
      headers: { 'Content-Type': 'application/json', ...corsHeaders }
    })
  }

  // Initialize MLOps tracking
  const requestId = generateRequestId()
  const startTime = Date.now()
  let mlopsMetrics: MLOpsMetrics = {
    requestId,
    startTime,
    success: false,
    latency: 0
  }

  try {
    const requestBody = await req.json()
    const { query, context, options = {} } = requestBody
    const userId = req.headers.get('x-user-id') || undefined

    mlopsMetrics.userId = userId

    if (!query || typeof query !== 'string') {
      mlopsMetrics.success = false
      mlopsMetrics.errorMessage = 'Invalid query parameter'
      mlopsMetrics.latency = Date.now() - startTime
      await logMLOpsMetrics(mlopsMetrics)
      
      return new Response(JSON.stringify({ 
        error: 'Invalid request',
        message: 'Query parameter is required and must be a string'
      }), {
        status: 400,
        headers: { 'Content-Type': 'application/json', ...corsHeaders }
      })
    }

    console.log(`[${requestId}] Generating insight for query: "${query.slice(0, 100)}..."`)

    // Get experiment assignment
    const experimentConfig = await getExperimentAssignment(userId)
    mlopsMetrics.experimentVariant = experimentConfig.variant
    
    console.log(`[${requestId}] Experiment: ${experimentConfig.experimentId}, Variant: ${experimentConfig.variant}`)

    // Step 1: Generate embedding
    const embeddingStartTime = Date.now()
    const queryEmbedding = await generateQueryEmbedding(query, experimentConfig)
    const embeddingTime = Date.now() - embeddingStartTime

    // Step 2: Retrieve context
    const { sources, retrievalTime } = await retrieveRelevantContext(
      queryEmbedding,
      options.maxSources || 5,
      options.confidenceThreshold || DEFAULT_CONFIDENCE_THRESHOLD
    )

    console.log(`[${requestId}] Retrieved ${sources.length} relevant sources`)

    // Step 3: Generate insight
    const { insight, generationTime, tokenUsage } = await generateInsightWithLLM(
      query,
      context,
      sources,
      experimentConfig,
      options
    )

    // Calculate costs
    const estimatedCost = calculateCost(tokenUsage.prompt, tokenUsage.completion, experimentConfig.modelConfig.CHAT_MODEL)

    // Update MLOps metrics
    mlopsMetrics.success = true
    mlopsMetrics.latency = Date.now() - startTime
    mlopsMetrics.inputTokens = tokenUsage.prompt
    mlopsMetrics.outputTokens = tokenUsage.completion
    mlopsMetrics.estimatedCost = estimatedCost
    mlopsMetrics.confidenceScore = insight.confidence / 100

    // Build complete response
    const completeInsight = {
      ...insight,
      metadata: {
        generated_at: new Date().toISOString(),
        model_version: experimentConfig.modelConfig.CHAT_MODEL,
        experiment_variant: experimentConfig.variant,
        experiment_id: experimentConfig.experimentId,
        request_id: requestId,
        context_tokens: sources.reduce((total, s) => total + s.content.length, 0),
        query_embedding_time: embeddingTime,
        rag_retrieval_time: retrievalTime,
        llm_generation_time: generationTime,
        total_cost_usd: estimatedCost,
        token_usage: tokenUsage
      }
    }

    const response = {
      insight: completeInsight,
      performance: {
        total_time: mlopsMetrics.latency,
        embedding_time: embeddingTime,
        retrieval_time: retrievalTime,
        generation_time: generationTime,
        sources_retrieved: sources.length,
        estimated_cost: estimatedCost,
        experiment_variant: experimentConfig.variant
      },
      debug: {
        request_id: requestId,
        query_length: query.length,
        context_keys: Object.keys(context),
        avg_source_relevance: sources.length > 0 
          ? sources.reduce((sum, s) => sum + s.relevance, 0) / sources.length 
          : 0
      }
    }

    // Log MLOps metrics
    await logMLOpsMetrics(mlopsMetrics)
    
    // Check alert thresholds
    await checkAlertThresholds(mlopsMetrics)

    console.log(`[${requestId}] Insight generated successfully in ${mlopsMetrics.latency}ms (${experimentConfig.variant})`)

    return new Response(JSON.stringify(response), {
      status: 200,
      headers: { 
        'Content-Type': 'application/json', 
        'X-Request-ID': requestId,
        'X-Experiment-Variant': experimentConfig.variant,
        ...corsHeaders 
      }
    })
    
  } catch (error) {
    console.error(`[${requestId}] Insight generation failed:`, error)
    
    // Update MLOps metrics for error
    mlopsMetrics.success = false
    mlopsMetrics.latency = Date.now() - startTime
    mlopsMetrics.errorMessage = error.message || 'Unknown error'
    
    await logMLOpsMetrics(mlopsMetrics)

    const errorResponse = {
      error: 'Insight generation failed',
      message: error.message || 'An unexpected error occurred',
      request_id: requestId,
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
      headers: { 
        'Content-Type': 'application/json',
        'X-Request-ID': requestId,
        ...corsHeaders 
      }
    })
  }
})