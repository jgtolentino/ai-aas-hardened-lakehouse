#!/usr/bin/env node
/**
 * W2: Docs Hub RAG - Chunk markdown files
 * Usage: node chunk-docs.js --src docs --out .chunks.jsonl
 */

import fs from 'fs';
import path from 'path';
// import { glob } from 'glob';
const glob = async (pattern, options = {}) => {
  const fs = await import('fs');
  const path = await import('path');
  
  // Simple glob implementation for testing
  function walkDir(dir, pattern) {
    let files = [];
    try {
      const items = fs.readdirSync(dir);
      for (const item of items) {
        const fullPath = path.join(dir, item);
        const stat = fs.statSync(fullPath);
        if (stat.isDirectory() && !item.startsWith('.') && item !== 'node_modules') {
          files = files.concat(walkDir(fullPath, pattern));
        } else if (pattern.includes('*') ? item.includes('.md') : item.match(pattern)) {
          files.push(fullPath);
        }
      }
    } catch (e) {
      // Ignore directory access errors
    }
    return files;
  }
  
  const basePath = pattern.split('**')[0] || '.';
  return walkDir(basePath, pattern);
};

const args = process.argv.slice(2);
const srcDir = args[args.indexOf('--src') + 1] || 'docs';
const outFile = args[args.indexOf('--out') + 1] || '.chunks.jsonl';

console.log(`📚 Chunking docs from ${srcDir} → ${outFile}`);

function chunkText(text, maxChunkSize = 1000, overlap = 100) {
  const chunks = [];
  const sentences = text.split(/[.!?]+/).filter(s => s.trim().length > 10);
  
  let currentChunk = '';
  let currentSize = 0;
  
  for (const sentence of sentences) {
    const sentenceSize = sentence.trim().length;
    
    if (currentSize + sentenceSize > maxChunkSize && currentChunk.length > 0) {
      chunks.push(currentChunk.trim());
      
      // Create overlap by keeping last few words
      const words = currentChunk.trim().split(' ');
      const overlapWords = words.slice(-Math.min(overlap / 8, 20));
      currentChunk = overlapWords.join(' ') + ' ' + sentence.trim();
      currentSize = currentChunk.length;
    } else {
      currentChunk += (currentChunk ? ' ' : '') + sentence.trim();
      currentSize += sentenceSize;
    }
  }
  
  if (currentChunk.trim().length > 0) {
    chunks.push(currentChunk.trim());
  }
  
  return chunks.filter(chunk => chunk.length > 50); // Filter very short chunks
}

function extractMetadata(filePath, content) {
  const relativePath = path.relative(process.cwd(), filePath);
  let title = path.basename(filePath, path.extname(filePath));
  let description = '';
  
  // Extract frontmatter if present
  const frontmatterMatch = content.match(/^---\n([\s\S]*?)\n---/);
  if (frontmatterMatch) {
    const frontmatter = frontmatterMatch[1];
    const titleMatch = frontmatter.match(/title:\s*["']?([^"'\n]+)["']?/);
    const descMatch = frontmatter.match(/description:\s*["']?([^"'\n]+)["']?/);
    
    if (titleMatch) title = titleMatch[1];
    if (descMatch) description = descMatch[1];
  }
  
  // Extract first heading if no title in frontmatter
  if (title === path.basename(filePath, path.extname(filePath))) {
    const headingMatch = content.match(/^#+\s+(.+)$/m);
    if (headingMatch) title = headingMatch[1];
  }
  
  return {
    file_path: relativePath,
    title,
    description,
    type: path.extname(filePath).slice(1) || 'md'
  };
}

async function processDocsDirectory(srcDir) {
  const pattern = path.join(srcDir, '**/*.{md,mdx,txt}');
  const files = await glob(pattern, { ignore: ['**/node_modules/**', '**/.git/**'] });
  
  const chunks = [];
  let totalFiles = 0;
  let totalChunks = 0;
  
  for (const filePath of files) {
    try {
      const content = fs.readFileSync(filePath, 'utf8');
      const metadata = extractMetadata(filePath, content);
      
      // Clean content (remove frontmatter, excessive whitespace)
      let cleanContent = content.replace(/^---\n[\s\S]*?\n---\n/, '');
      cleanContent = cleanContent.replace(/\s+/g, ' ').trim();
      
      if (cleanContent.length < 100) continue; // Skip very short files
      
      const fileChunks = chunkText(cleanContent);
      totalFiles++;
      totalChunks += fileChunks.length;
      
      fileChunks.forEach((chunk, index) => {
        chunks.push({
          id: `${metadata.file_path}#chunk-${index}`,
          content: chunk,
          metadata: {
            ...metadata,
            chunk_index: index,
            total_chunks: fileChunks.length,
            content_length: chunk.length,
            created_at: new Date().toISOString()
          },
          tenant_id: null // Global docs unless specified
        });
      });
      
      console.log(`📄 ${metadata.file_path}: ${fileChunks.length} chunks`);
      
    } catch (error) {
      console.error(`❌ Error processing ${filePath}:`, error.message);
    }
  }
  
  return { chunks, totalFiles, totalChunks };
}

async function main() {
  try {
    if (!fs.existsSync(srcDir)) {
      console.error(`❌ Source directory does not exist: ${srcDir}`);
      process.exit(1);
    }
    
    const { chunks, totalFiles, totalChunks } = await processDocsDirectory(srcDir);
    
    // Write JSONL format (one JSON object per line)
    const jsonlContent = chunks.map(chunk => JSON.stringify(chunk)).join('\n');
    fs.writeFileSync(outFile, jsonlContent);
    
    console.log(`✅ Chunking complete:`);
    console.log(`   📁 Files processed: ${totalFiles}`);
    console.log(`   🧩 Total chunks: ${totalChunks}`);
    console.log(`   📝 Output: ${outFile} (${(fs.statSync(outFile).size / 1024).toFixed(1)}KB)`);
    
    process.exit(0);
    
  } catch (error) {
    console.error('❌ Chunking failed:', error.message);
    process.exit(1);
  }
}

main();