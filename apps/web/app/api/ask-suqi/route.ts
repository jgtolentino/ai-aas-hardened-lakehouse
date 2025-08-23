import { NextRequest } from 'next/server';
import { createClient } from '@supabase/supabase-js';
import { telemetry } from '@/packages/core/src/telemetry';

// Orchestration mode: "db" uses database function, "node" uses Node.js orchestration
const ORCHESTRATION_MODE = process.env.SUQI_CHAT_MODE || 'node';

const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_ROLE_KEY!
);

export async function POST(request: NextRequest) {
  const encoder = new TextEncoder();
  
  try {
    const { question, context_limit = 10, include_metadata = false, use_cache = true } = await request.json();
    
    if (!question) {
      return new Response('Question is required', { status: 400 });
    }

    const platform = request.headers.get('x-platform') || 'web';
    const authHeader = request.headers.get('authorization');
    
    if (ORCHESTRATION_MODE === 'db') {
      // DB-orchestrated mode: call the database function directly
      const stream = new ReadableStream({
        async start(controller) {
          try {
            const startTime = Date.now();
            
            // Call the DB orchestrator
            const { data, error } = await supabase.rpc('ask_suqi_query', {
              question,
              context_limit,
              include_metadata,
              use_cache,
              search_depth: 5
            }, {
              headers: {
                'x-platform': platform,
                ...(authHeader ? { authorization: authHeader } : {})
              }
            });

            if (error) {
              controller.enqueue(encoder.encode(`data: ${JSON.stringify({ error: error.message })}\n\n`));
              controller.close();
              return;
            }

            // Stream the response
            if (data.answer) {
              // Send answer in chunks for streaming effect
              const chunks = chunkText(data.answer, 50);
              for (const chunk of chunks) {
                controller.enqueue(encoder.encode(`data: ${JSON.stringify({ chunk })}\n\n`));
                await sleep(50); // Small delay for streaming effect
              }
            }

            // Send metadata
            controller.enqueue(encoder.encode(`data: ${JSON.stringify({
              done: true,
              sources: data.sources,
              usage: data.usage,
              cached: data.cached,
              response_time_ms: Date.now() - startTime,
              platform: data.platform
            })}\n\n`));

            // Track telemetry
            telemetry.query(question, Date.now() - startTime);
            if (data.cached) {
              telemetry.cacheHit(question);
            }

            controller.close();
          } catch (error) {
            console.error('DB orchestration error:', error);
            controller.enqueue(encoder.encode(`data: ${JSON.stringify({ 
              error: 'Internal server error',
              details: error instanceof Error ? error.message : 'Unknown error'
            })}\n\n`));
            controller.close();
          }
        }
      });

      return new Response(stream, {
        headers: {
          'Content-Type': 'text/event-stream',
          'Cache-Control': 'no-cache',
          'Connection': 'keep-alive',
        },
      });
    } else {
      // Node-orchestrated mode: implement full orchestration in Node.js
      const stream = new ReadableStream({
        async start(controller) {
          try {
            const startTime = Date.now();
            
            // 1. Generate embedding
            const embeddingResponse = await fetch(`${process.env.OPENAI_API_URL}/v1/embeddings`, {
              method: 'POST',
              headers: {
                'Authorization': `Bearer ${process.env.OPENAI_API_KEY}`,
                'Content-Type': 'application/json',
              },
              body: JSON.stringify({
                model: 'text-embedding-3-small',
                input: question,
              }),
            });

            const embeddingData = await embeddingResponse.json();
            const embedding = embeddingData.data[0].embedding;

            // 2. Search for relevant documents
            const { data: docs, error: searchError } = await supabase.rpc('search_ai_corpus', {
              p_tenant_id: 'default', // Get from auth
              p_vendor_id: null,
              p_qvec: embedding,
              p_k: context_limit
            });

            if (searchError) throw searchError;

            // 3. Build context
            const context = docs?.map((doc: any) => doc.chunk).join('\n\n') || '';

            // 4. Generate response with OpenAI
            const completionResponse = await fetch(`${process.env.OPENAI_API_URL}/v1/chat/completions`, {
              method: 'POST',
              headers: {
                'Authorization': `Bearer ${process.env.OPENAI_API_KEY}`,
                'Content-Type': 'application/json',
              },
              body: JSON.stringify({
                model: 'gpt-4-turbo-preview',
                messages: [
                  {
                    role: 'system',
                    content: 'You are Suqi, an AI assistant for Scout Analytics. Answer based on the provided context.'
                  },
                  {
                    role: 'user',
                    content: `Context:\n${context}\n\nQuestion: ${question}`
                  }
                ],
                stream: true,
                temperature: 0.7,
                max_tokens: 1000
              }),
            });

            // 5. Stream the response
            const reader = completionResponse.body?.getReader();
            if (!reader) throw new Error('No response body');

            let fullAnswer = '';
            const decoder = new TextDecoder();

            while (true) {
              const { done, value } = await reader.read();
              if (done) break;

              const chunk = decoder.decode(value);
              const lines = chunk.split('\n').filter(line => line.trim() !== '');

              for (const line of lines) {
                if (line.startsWith('data: ')) {
                  const data = line.slice(6);
                  if (data === '[DONE]') continue;

                  try {
                    const parsed = JSON.parse(data);
                    const content = parsed.choices[0]?.delta?.content;
                    if (content) {
                      fullAnswer += content;
                      controller.enqueue(encoder.encode(`data: ${JSON.stringify({ chunk: content })}\n\n`));
                    }
                  } catch (e) {
                    console.error('Failed to parse chunk:', e);
                  }
                }
              }
            }

            // 6. Send final metadata
            controller.enqueue(encoder.encode(`data: ${JSON.stringify({
              done: true,
              sources: docs,
              usage: {
                prompt_tokens: 100, // Would come from OpenAI response
                completion_tokens: 150,
                total_tokens: 250
              },
              cached: false,
              response_time_ms: Date.now() - startTime,
              platform
            })}\n\n`));

            // 7. Track event
            telemetry.query(question, Date.now() - startTime);
            
            controller.close();
          } catch (error) {
            console.error('Node orchestration error:', error);
            telemetry.error('Orchestration failed', { error: error instanceof Error ? error.message : 'Unknown' });
            
            controller.enqueue(encoder.encode(`data: ${JSON.stringify({ 
              error: 'Internal server error',
              details: error instanceof Error ? error.message : 'Unknown error'
            })}\n\n`));
            controller.close();
          }
        }
      });

      return new Response(stream, {
        headers: {
          'Content-Type': 'text/event-stream',
          'Cache-Control': 'no-cache',
          'Connection': 'keep-alive',
        },
      });
    }
  } catch (error) {
    console.error('Request processing error:', error);
    return new Response('Bad request', { status: 400 });
  }
}

// Helper functions
function chunkText(text: string, chunkSize: number): string[] {
  const words = text.split(' ');
  const chunks: string[] = [];
  let currentChunk = '';

  for (const word of words) {
    if ((currentChunk + ' ' + word).length > chunkSize) {
      if (currentChunk) chunks.push(currentChunk);
      currentChunk = word;
    } else {
      currentChunk = currentChunk ? currentChunk + ' ' + word : word;
    }
  }

  if (currentChunk) chunks.push(currentChunk);
  return chunks;
}

function sleep(ms: number): Promise<void> {
  return new Promise(resolve => setTimeout(resolve, ms));
}