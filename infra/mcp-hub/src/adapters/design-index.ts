/**
 * Design Index Adapter - SQLite-based local design search
 * Enables Claude to find design candidates without Figma tokens
 */
import Database from "better-sqlite3";
import fs from "node:fs";
import path from "node:path";

const DB_PATH = process.env.DESIGN_INDEX_DB || ".cache/design-index.sqlite";

export type DesignRow = {
  id: string;                 // stable uid (e.g. fileKey:nodeId)
  file_key: string;
  node_id: string;
  title: string;
  kind: "dashboard"|"component"|"diagram"|"screen"|"template";
  tags: string[];             // ["kpi","12col","cards","finance"]
  preview: string | null;     // optional image url (if cached)
  metadata: Record<string, any>; // dimensions, colors, component count, etc.
  updated_at: string;         // ISO timestamp
  created_at: string;         // ISO timestamp
};

export type SearchQuery = {
  text?: string;
  tags?: string[];
  kind?: string;
  limit?: number;
  metadata?: Record<string, any>; // filter by dimensions, etc.
};

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

export function upsertDesigns(rows: DesignRow[]) {
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
  
  const transaction = db.transaction((items: DesignRow[]) => {
    items.forEach(item => {
      const now = new Date().toISOString();
      stmt.run({
        ...item,
        tags: JSON.stringify(item.tags),
        metadata: JSON.stringify(item.metadata),
        created_at: item.created_at || now
      });
    });
  });
  
  transaction(rows);
  console.log(`✅ Indexed ${rows.length} design items`);
}

export function searchDesigns(query: SearchQuery): DesignRow[] {
  const db = ensureDatabase();
  const { text = "", kind = "", limit = 20, metadata = {} } = query;
  const tags = query.tags?.map(t => t.toLowerCase()) ?? [];
  
  let sql = "SELECT * FROM design_items WHERE 1=1";
  const params: any[] = [];
  
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
  const rows = db.prepare(sql).all(...params) as any[];
  
  // Parse JSON fields and apply additional filters
  const results = rows
    .map(row => ({
      ...row,
      tags: JSON.parse(row.tags || "[]"),
      metadata: JSON.parse(row.metadata || "{}")
    }))
    // Filter by tags (client-side for flexibility)
    .filter(row => tags.length === 0 || tags.every(tag => 
      row.tags.some((t: string) => t.toLowerCase().includes(tag))
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

export function getDesignById(id: string): DesignRow | null {
  const db = ensureDatabase();
  const row = db.prepare("SELECT * FROM design_items WHERE id = ?").get(id) as any;
  
  if (!row) return null;
  
  return {
    ...row,
    tags: JSON.parse(row.tags || "[]"),
    metadata: JSON.parse(row.metadata || "{}")
  };
}

export function deleteDesign(id: string): boolean {
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
  `).get() as any;
  
  const kindBreakdown = db.prepare(`
    SELECT kind, COUNT(*) as count 
    FROM design_items 
    GROUP BY kind 
    ORDER BY count DESC
  `).all() as any[];
  
  return {
    ...stats,
    kinds: kindBreakdown
  };
}

export function indexFileFromFigma(fileKey: string, pages: any[]): DesignRow[] {
  const designs: DesignRow[] = [];
  const now = new Date().toISOString();
  
  pages.forEach(page => {
    if (page.children) {
      page.children.forEach((frame: any) => {
        // Extract design metadata
        const metadata = {
          width: frame.absoluteBoundingBox?.width || 0,
          height: frame.absoluteBoundingBox?.height || 0,
          x: frame.absoluteBoundingBox?.x || 0,
          y: frame.absoluteBoundingBox?.y || 0,
          background: frame.background?.[0]?.color || null,
          componentCount: countComponents(frame),
          textCount: countTextNodes(frame)
        };
        
        // Classify design type based on name and structure
        const kind = classifyDesign(frame.name, frame);
        
        // Extract tags from name and structure
        const tags = extractTags(frame.name, frame);
        
        designs.push({
          id: `${fileKey}:${frame.id}`,
          file_key: fileKey,
          node_id: frame.id,
          title: frame.name,
          kind,
          tags,
          preview: null, // Will be populated by separate export operation
          metadata,
          updated_at: now,
          created_at: now
        });
      });
    }
  });
  
  return designs;
}

function classifyDesign(name: string, node: any): DesignRow['kind'] {
  const lowerName = name.toLowerCase();
  
  if (lowerName.includes('dashboard') || lowerName.includes('kpi')) {
    return 'dashboard';
  }
  if (lowerName.includes('component') || lowerName.includes('button') || lowerName.includes('card')) {
    return 'component';
  }
  if (lowerName.includes('diagram') || lowerName.includes('flow') || lowerName.includes('architecture')) {
    return 'diagram';
  }
  if (lowerName.includes('screen') || lowerName.includes('page') || lowerName.includes('view')) {
    return 'screen';
  }
  if (lowerName.includes('template') || lowerName.includes('starter')) {
    return 'template';
  }
  
  // Default classification based on structure
  const componentCount = countComponents(node);
  const textCount = countTextNodes(node);
  
  if (componentCount > 5) return 'dashboard';
  if (componentCount > 0) return 'component';
  if (textCount > 10) return 'screen';
  
  return 'component';
}

function extractTags(name: string, node: any): string[] {
  const tags: string[] = [];
  const lowerName = name.toLowerCase();
  
  // Common UI patterns
  if (lowerName.includes('12col') || lowerName.includes('12-col')) tags.push('12col');
  if (lowerName.includes('grid')) tags.push('grid');
  if (lowerName.includes('kpi')) tags.push('kpi');
  if (lowerName.includes('chart')) tags.push('chart');
  if (lowerName.includes('card')) tags.push('card');
  if (lowerName.includes('table')) tags.push('table');
  if (lowerName.includes('form')) tags.push('form');
  if (lowerName.includes('nav')) tags.push('navigation');
  if (lowerName.includes('header')) tags.push('header');
  if (lowerName.includes('footer')) tags.push('footer');
  if (lowerName.includes('sidebar')) tags.push('sidebar');
  if (lowerName.includes('modal')) tags.push('modal');
  if (lowerName.includes('dropdown')) tags.push('dropdown');
  
  // Domain tags
  if (lowerName.includes('finance') || lowerName.includes('financial')) tags.push('finance');
  if (lowerName.includes('hr') || lowerName.includes('human')) tags.push('hr');
  if (lowerName.includes('scout')) tags.push('scout');
  if (lowerName.includes('executive')) tags.push('executive');
  if (lowerName.includes('analytics')) tags.push('analytics');
  if (lowerName.includes('dashboard')) tags.push('dashboard');
  
  // Size-based tags
  const width = node.absoluteBoundingBox?.width || 0;
  if (width > 1200) tags.push('large');
  else if (width > 800) tags.push('medium');
  else tags.push('small');
  
  // Responsive tags
  if (width <= 768) tags.push('mobile');
  else if (width <= 1024) tags.push('tablet');
  else tags.push('desktop');
  
  return [...new Set(tags)]; // Remove duplicates
}

function countComponents(node: any): number {
  let count = 0;
  if (node.type === 'COMPONENT' || node.type === 'INSTANCE') count++;
  if (node.children) {
    node.children.forEach((child: any) => {
      count += countComponents(child);
    });
  }
  return count;
}

function countTextNodes(node: any): number {
  let count = 0;
  if (node.type === 'TEXT') count++;
  if (node.children) {
    node.children.forEach((child: any) => {
      count += countTextNodes(child);
    });
  }
  return count;
}

// Export for MCP tools
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
    handler: async (params: any) => searchDesigns(params)
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
    handler: async (params: any) => getDesignById(params.id)
  },
  
  get_index_stats: {
    description: 'Get statistics about the design index',
    parameters: { type: 'object', properties: {} },
    handler: async () => getIndexStats()
  }
};