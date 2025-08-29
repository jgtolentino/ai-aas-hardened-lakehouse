/**
 * Design Index Adapter - SQLite-based local design search
 * Enables Claude to find design candidates without Figma tokens
 */
import Database from "better-sqlite3";
import fs from "node:fs";
import path from "node:path";

const DB_PATH = process.env.DESIGN_INDEX_DB || ".cache/design-index.sqlite";

export function ensureDatabase() {
  // Create cache directory if it doesn't exist
  const cacheDir = path.dirname(DB_PATH);
  fs.mkdirSync(cacheDir, { recursive: true });
  
  const db = new Database(DB_PATH);
  
  // Create tables with indexes for performance
  db.exec(`
    CREATE TABLE IF NOT EXISTS design_items (
      id TEXT PRIMARY KEY,
      file_key TEXT NOT NULL,
      node_id TEXT NOT NULL,
      title TEXT NOT NULL,
      kind TEXT NOT NULL,
      tags TEXT NOT NULL,
      preview TEXT,
      metadata TEXT,
      updated_at TEXT NOT NULL,
      created_at TEXT NOT NULL
    );
    
    CREATE INDEX IF NOT EXISTS idx_design_kind ON design_items(kind);
    CREATE INDEX IF NOT EXISTS idx_design_title ON design_items(title);
    CREATE INDEX IF NOT EXISTS idx_design_file ON design_items(file_key);
    CREATE INDEX IF NOT EXISTS idx_design_updated ON design_items(updated_at);
  `);
  
  return db;
}

export function upsertDesigns(rows) {
  const db = ensureDatabase();
  
  const stmt = db.prepare(`
    INSERT INTO design_items(
      id, file_key, node_id, title, kind, tags, preview, metadata, updated_at, created_at
    ) VALUES(
      @id, @file_key, @node_id, @title, @kind, @tags, @preview, @metadata, @updated_at, @created_at
    ) ON CONFLICT(id) DO UPDATE SET
      title = excluded.title,
      kind = excluded.kind,
      tags = excluded.tags,
      preview = excluded.preview,
      metadata = excluded.metadata,
      updated_at = excluded.updated_at
  `);
  
  const transaction = db.transaction((items) => {
    items.forEach(item => {
      const now = new Date().toISOString();
      stmt.run({
        ...item,
        tags: JSON.stringify(item.tags || []),
        metadata: JSON.stringify(item.metadata || {}),
        created_at: item.created_at || now
      });
    });
  });
  
  transaction(rows);
  console.log(`✅ Indexed ${rows.length} design items`);
}

export function searchDesigns(query) {
  const db = ensureDatabase();
  const { text = "", kind = "", limit = 20, metadata = {} } = query;
  const tags = query.tags?.map(t => t.toLowerCase()) ?? [];
  
  let sql = "SELECT * FROM design_items WHERE 1=1";
  const params = [];
  
  // Text search in title and id
  if (text.trim()) {
    sql += " AND (title LIKE ? OR id LIKE ? OR file_key LIKE ?)";
    const searchTerm = `%${text}%`;
    params.push(searchTerm, searchTerm, searchTerm);
  }
  
  // Filter by design kind
  if (kind) {
    sql += " AND kind = ?";
    params.push(kind);
  }
  
  // Order by updated_at desc for freshness
  sql += " ORDER BY updated_at DESC";
  
  // Execute query
  const rows = db.prepare(sql).all(...params);
  
  // Parse JSON fields and apply additional filters
  const results = rows
    .map(row => ({
      ...row,
      tags: JSON.parse(row.tags || "[]"),
      metadata: JSON.parse(row.metadata || "{}")
    }))
    // Filter by tags (client-side for flexibility)
    .filter(row => tags.length === 0 || tags.every(tag => 
      row.tags.some(t => t.toLowerCase().includes(tag))
    ))
    // Filter by metadata criteria
    .filter(row => {
      if (Object.keys(metadata).length === 0) return true;
      return Object.entries(metadata).every(([key, value]) => 
        row.metadata[key] === value
      );
    })
    .slice(0, limit);
  
  console.log(`🔍 Found ${results.length} design matches for query:`, query);
  return results;
}

export function getDesignById(id) {
  const db = ensureDatabase();
  const row = db.prepare("SELECT * FROM design_items WHERE id = ?").get(id);
  
  if (!row) return null;
  
  return {
    ...row,
    tags: JSON.parse(row.tags || "[]"),
    metadata: JSON.parse(row.metadata || "{}")
  };
}

export function deleteDesign(id) {
  const db = ensureDatabase();
  const result = db.prepare("DELETE FROM design_items WHERE id = ?").run(id);
  return result.changes > 0;
}

export function getIndexStats() {
  const db = ensureDatabase();
  const stats = db.prepare(`
    SELECT 
      COUNT(*) as total,
      COUNT(DISTINCT file_key) as unique_files,
      COUNT(DISTINCT kind) as unique_kinds,
      MAX(updated_at) as last_updated
    FROM design_items
  `).get();
  
  const kindBreakdown = db.prepare(`
    SELECT kind, COUNT(*) as count 
    FROM design_items 
    GROUP BY kind 
    ORDER BY count DESC
  `).all();
  
  return {
    ...stats,
    kinds: kindBreakdown
  };
}

// MCP Tools for Claude integration
export const designIndexTools = {
  search_designs: {
    description: 'Search for design templates and components in the local index',
    parameters: {
      type: 'object',
      properties: {
        text: { type: 'string', description: 'Search text for title and file names' },
        tags: { type: 'array', items: { type: 'string' }, description: 'Filter by tags' },
        kind: { type: 'string', enum: ['dashboard', 'component', 'diagram', 'screen', 'template'] },
        limit: { type: 'number', default: 20, description: 'Maximum number of results' },
        metadata: { type: 'object', description: 'Filter by metadata properties' }
      }
    },
    handler: async (params) => searchDesigns(params)
  },
  
  get_design_by_id: {
    description: 'Get design details by ID',
    parameters: {
      type: 'object',
      properties: {
        id: { type: 'string', description: 'Design ID (fileKey:nodeId format)' }
      },
      required: ['id']
    },
    handler: async (params) => getDesignById(params.id)
  },
  
  get_index_stats: {
    description: 'Get statistics about the design index',
    parameters: { type: 'object', properties: {} },
    handler: async () => getIndexStats()
  }
};