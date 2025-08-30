import { describe, it, expect, vi, beforeEach } from 'vitest';
import { SupabaseAdapter, FigmaAdapter, DiagramAdapter } from '../adapters';

describe('MCP Adapters', () => {
  describe('SupabaseAdapter', () => {
    let mockMCPExecute: ReturnType<typeof vi.fn>;
    let adapter: SupabaseAdapter;

    beforeEach(() => {
      mockMCPExecute = vi.fn();
      adapter = new SupabaseAdapter('test-project', 'test-token', mockMCPExecute);
    });

    it('should execute SQL successfully', async () => {
      const mockResult = {
        data: [{ id: 1, name: 'test' }],
        error: null,
        count: 1,
        status: 200,
        statusText: 'OK',
      };
      mockMCPExecute.mockResolvedValue(mockResult);

      const result = await adapter.executeSQL('SELECT * FROM users');
      
      expect(mockMCPExecute).toHaveBeenCalledWith('mcp__supabase__execute_sql', {
        query: 'SELECT * FROM users',
        params: undefined,
      });
      expect(result).toEqual(mockResult);
    });

    it('should handle PostgreSQL errors gracefully', async () => {
      mockMCPExecute.mockRejectedValue({ code: '42P01', message: 'relation "users" does not exist' });

      await expect(adapter.executeSQL('SELECT * FROM users'))
        .rejects.toThrow('Table or view does not exist');
    });

    it('should retry on transient failures', async () => {
      mockMCPExecute
        .mockRejectedValueOnce({ code: 'ETIMEDOUT' })
        .mockRejectedValueOnce({ code: 'ETIMEDOUT' })
        .mockResolvedValue({ data: [], error: null, count: 0, status: 200, statusText: 'OK' });

      const result = await adapter.executeSQL('SELECT 1');
      
      expect(mockMCPExecute).toHaveBeenCalledTimes(3);
      expect(result.count).toBe(0);
    });

    it('should list tables with schema validation', async () => {
      const mockTables = [
        { table_name: 'users', table_schema: 'public', table_type: 'BASE TABLE' as const, is_insertable_into: 'YES' as const },
      ];
      mockMCPExecute.mockResolvedValue(mockTables);

      const result = await adapter.listTables('public');
      
      expect(result).toEqual(mockTables);
      expect(mockMCPExecute).toHaveBeenCalledWith('mcp__supabase__list_tables', { schema: 'public' });
    });
  });

  describe('FigmaAdapter', () => {
    let mockMCPExecute: ReturnType<typeof vi.fn>;
    let adapter: FigmaAdapter;

    beforeEach(() => {
      mockMCPExecute = vi.fn();
      adapter = new FigmaAdapter(mockMCPExecute);
    });

    it('should get Figma selection successfully', async () => {
      const mockSelection = {
        selection: [{ id: '1:23', name: 'Component', type: 'COMPONENT' }],
        fileKey: 'abc123',
        timestamp: Date.now(),
      };
      mockMCPExecute.mockResolvedValue(mockSelection);

      const result = await adapter.getSelection();
      
      expect(result).toEqual(mockSelection);
      expect(mockMCPExecute).toHaveBeenCalledWith('mcp__figma__get_selection', {});
    });

    it('should handle no selection gracefully', async () => {
      mockMCPExecute.mockRejectedValue(new Error('No selection timeout'));

      const result = await adapter.getSelection();
      
      expect(result).toHaveProperty('error');
      expect(result.error).toContain('No active Figma selection');
      expect(result.selection).toEqual([]);
    });

    it('should generate component from node', async () => {
      const mockComponent = {
        componentName: 'TestComponent',
        filePath: './TestComponent.tsx',
        props: { title: 'string' },
        imports: ['React'],
        codeConnectMapping: {
          figmaNode: '1:23',
          component: 'TestComponent',
        },
        jsx: '<div>{title}</div>',
      };
      mockMCPExecute.mockResolvedValue(mockComponent);

      const result = await adapter.generateComponent('1:23', 'TestComponent');
      
      expect(result).toEqual(mockComponent);
      expect(mockMCPExecute).toHaveBeenCalledWith('mcp__figma__generate_component', {
        nodeId: '1:23',
        componentName: 'TestComponent',
      });
    });
  });

  describe('DiagramAdapter', () => {
    let adapter: DiagramAdapter;
    let mockFetch: ReturnType<typeof vi.fn>;

    beforeEach(() => {
      adapter = new DiagramAdapter('https://test-kroki.io');
      mockFetch = vi.fn();
      global.fetch = mockFetch;
    });

    it('should generate diagram successfully', async () => {
      const mockResponse = {
        ok: true,
        arrayBuffer: () => Promise.resolve(new ArrayBuffer(8)),
      };
      mockFetch.mockResolvedValue(mockResponse);

      const result = await adapter.generateDiagram({
        type: 'mermaid',
        content: 'graph TD; A-->B',
        format: 'png',
      });

      expect(result).toHaveProperty('url');
      expect(result).toHaveProperty('cache_key');
      expect(result.format).toBe('png');
      expect(mockFetch).toHaveBeenCalledWith(
        'https://test-kroki.io/mermaid/png',
        expect.objectContaining({
          method: 'POST',
          body: 'graph TD; A-->B',
        })
      );
    });

    it('should handle Kroki API errors', async () => {
      mockFetch.mockResolvedValue({
        ok: false,
        status: 400,
        statusText: 'Bad Request',
        text: () => Promise.resolve('Syntax error'),
      });

      await expect(adapter.generateDiagram({
        type: 'mermaid',
        content: 'invalid syntax',
        format: 'png',
      })).rejects.toThrow('Kroki API error: 400 Bad Request');
    });
  });
});