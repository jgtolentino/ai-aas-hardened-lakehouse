#!/usr/bin/env node
/**
 * W2: Docs Hub RAG - Embed chunks and store in Supabase
 * Usage: node embed-docs.js --in .chunks.jsonl --tenant null
 */

import fs from 'fs';
import crypto from 'crypto';

const args = process.argv.slice(2);
const inputFile = args[args.indexOf('--in') + 1] || '.chunks.jsonl';
const tenantId = args[args.indexOf('--tenant') + 1] || 'null';

console.log(`🧠 Embedding docs from ${inputFile} for tenant: ${tenantId}`);

// Mock embedding function (replace with actual OpenAI or local embedding)
function generateEmbedding(text) {
  // This is a mock - replace with actual embedding service
  // For testing, we'll create a deterministic "embedding" based on text hash
  const hash = crypto.createHash('sha256').update(text).digest('hex');
  const embedding = [];
  
  // Generate 1536-dimensional mock embedding (OpenAI text-embedding-3-small size)
  for (let i = 0; i < 1536; i++) {
    // Use hash to generate deterministic float values between -1 and 1
    const hashIndex = (i * 8) % hash.length;
    const hashChunk = hash.slice(hashIndex, hashIndex + 8);
    const value = (parseInt(hashChunk, 16) / 0xffffffff - 0.5) * 2;
    embedding.push(parseFloat(value.toFixed(6)));
  }
  
  // Normalize the vector
  const magnitude = Math.sqrt(embedding.reduce((sum, val) => sum + val * val, 0));
  return embedding.map(val => val / magnitude);
}

async function callOpenAIEmbedding(text) {
  const openaiKey = process.env.OPENAI_API_KEY;
  
  if (!openaiKey) {
    console.log('📝 No OPENAI_API_KEY found, using mock embeddings');
    return generateEmbedding(text);
  }
  
  try {
    const response = await fetch('https://api.openai.com/v1/embeddings', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${openaiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        input: text,
        model: 'text-embedding-3-small'
      })
    });
    
    if (!response.ok) {
      throw new Error(`OpenAI API error: ${response.status}`);
    }
    
    const data = await response.json();
    return data.data[0].embedding;
    
  } catch (error) {
    console.log(`⚠️  OpenAI embedding failed (${error.message}), using mock`);
    return generateEmbedding(text);
  }
}

async function storeInSupabase(chunk) {
  const supabaseUrl = process.env.SUPABASE_URL;
  const serviceRoleKey = process.env.SERVICE_ROLE || process.env.SUPABASE_SERVICE_ROLE_KEY;
  
  if (!supabaseUrl || !serviceRoleKey) {
    console.log('📝 Supabase credentials missing, simulating storage...');
    return { success: true, simulated: true };
  }
  
  try {
    const response = await fetch(`${supabaseUrl}/rest/v1/docs_chunks`, {
      method: 'POST',
      headers: {
        'apikey': serviceRoleKey,
        'Authorization': `Bearer ${serviceRoleKey}`,
        'Content-Type': 'application/json',
        'Prefer': 'resolution=merge-duplicates'
      },
      body: JSON.stringify({
        id: chunk.id,
        content: chunk.content,
        embedding: chunk.embedding,
        metadata: chunk.metadata,
        tenant_id: tenantId === 'null' ? null : tenantId,
        created_at: new Date().toISOString()
      })
    });
    
    if (!response.ok) {
      const error = await response.text();
      throw new Error(`Supabase error: ${response.status} ${error}`);
    }
    
    return { success: true };
    
  } catch (error) {
    console.error(`❌ Storage error for ${chunk.id}:`, error.message);
    return { success: false, error: error.message };
  }
}

async function main() {
  try {
    if (!fs.existsSync(inputFile)) {
      console.error(`❌ Input file does not exist: ${inputFile}`);
      process.exit(1);
    }
    
    const content = fs.readFileSync(inputFile, 'utf8');
    const chunks = content.split('\n').filter(line => line.trim()).map(line => JSON.parse(line));
    
    console.log(`📊 Processing ${chunks.length} chunks...`);
    
    let processed = 0;
    let stored = 0;
    let errors = 0;
    
    for (const chunk of chunks) {
      try {
        // Generate embedding
        console.log(`🧠 Embedding chunk ${processed + 1}/${chunks.length}: ${chunk.id}`);
        const embedding = await callOpenAIEmbedding(chunk.content);
        
        // Store in Supabase
        const result = await storeInSupabase({ ...chunk, embedding });
        
        if (result.success) {
          stored++;
          if (result.simulated) {
            console.log(`📝 Simulated storage: ${chunk.id}`);
          } else {
            console.log(`✅ Stored: ${chunk.id}`);
          }
        } else {
          errors++;
        }
        
        processed++;
        
        // Rate limiting for OpenAI API
        if (process.env.OPENAI_API_KEY && processed % 10 === 0) {
          console.log('⏳ Rate limiting pause...');
          await new Promise(resolve => setTimeout(resolve, 1000));
        }
        
      } catch (error) {
        console.error(`❌ Error processing ${chunk.id}:`, error.message);
        errors++;
        processed++;
      }
    }
    
    console.log(`✅ Embedding complete:`);
    console.log(`   🧩 Chunks processed: ${processed}`);
    console.log(`   💾 Successfully stored: ${stored}`);
    console.log(`   ❌ Errors: ${errors}`);
    
    if (errors > 0) {
      console.log(`⚠️  ${errors} chunks failed to embed/store`);
      process.exit(1);
    }
    
    process.exit(0);
    
  } catch (error) {
    console.error('❌ Embedding failed:', error.message);
    process.exit(1);
  }
}

main();