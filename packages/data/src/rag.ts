import { createClient } from '@supabase/supabase-js';
import type { Database } from '@/types/supabase';

const supabase = createClient<Database>(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
);

export interface RAGDocument {
  id: string;
  title: string;
  chunk: string;
  score?: number;
}

export async function retrieveDocs(
  tenantId: string,
  vendorId: string | undefined,
  qvec: number[],
  k = 6
): Promise<RAGDocument[]> {
  try {
    // Try canonical function first
    const { data, error } = await supabase.rpc('search_ai_corpus', {
      p_tenant_id: tenantId,
      p_vendor_id: vendorId ?? null,
      p_qvec: qvec,
      p_k: k
    });

    if (error) throw error;
    return data || [];
  } catch (primaryError) {
    console.warn('Primary search_ai_corpus failed, trying legacy function:', primaryError);
    
    // Fallback to legacy function name
    try {
      const { data, error } = await supabase.rpc('vector_search_ai_corpus', {
        p_tenant_id: tenantId,
        p_vendor_id: vendorId ?? null,
        p_qvec: qvec,
        p_k: k
      });

      if (error) throw error;
      return data || [];
    } catch (fallbackError) {
      console.error('Both search functions failed:', fallbackError);
      throw fallbackError;
    }
  }
}

export async function generateEmbedding(text: string): Promise<number[]> {
  // This would call your embedding service
  // For now, returning a mock embedding
  const mockEmbedding = new Array(1536).fill(0).map(() => Math.random() - 0.5);
  return mockEmbedding;
}

export async function indexDocument(
  tenantId: string,
  vendorId: string | undefined,
  title: string,
  content: string,
  metadata?: Record<string, any>
): Promise<void> {
  const embedding = await generateEmbedding(content);
  
  const { error } = await supabase
    .from('ai_corpus')
    .insert({
      tenant_id: tenantId,
      vendor_id: vendorId,
      title,
      chunk: content,
      embedding,
      metadata: metadata || {}
    });

  if (error) throw error;
}