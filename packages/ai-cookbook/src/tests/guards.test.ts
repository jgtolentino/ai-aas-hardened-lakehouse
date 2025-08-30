import { describe, it, expect } from 'vitest';
import { guards } from '../guards';
import { createJSONGuard } from '../core';
import { z } from 'zod';

describe('JSON Guards', () => {
  describe('createJSONGuard', () => {
    const testSchema = z.object({
      name: z.string(),
      value: z.number(),
    });
    const guard = createJSONGuard(testSchema);

    it('should parse valid JSON', () => {
      const result = guard.validate({ name: 'test', value: 42 });
      expect(result).toEqual({ name: 'test', value: 42 });
    });

    it('should parse JSON from string', () => {
      const result = guard.validate('{"name": "test", "value": 42}');
      expect(result).toEqual({ name: 'test', value: 42 });
    });

    it('should extract JSON from prose', () => {
      const prose = 'Here is the JSON: {"name": "test", "value": 42} - this is the result';
      const result = guard.validate(prose);
      expect(result).toEqual({ name: 'test', value: 42 });
    });

    it('should add prefill to prompts', () => {
      const prompt = 'Generate a component';
      const result = guard.prefill(prompt);
      expect(result).toContain(prompt);
      expect(result).toContain('JSON only');
      expect(result).toContain('{');
    });

    it('should throw on invalid JSON', () => {
      expect(() => guard.validate('invalid json')).toThrow('Invalid JSON');
    });

    it('should throw on schema validation failure', () => {
      expect(() => guard.validate('{"name": 123, "value": "abc"}')).toThrow();
    });
  });

  describe('Pre-built guards', () => {
    it('should validate component generation', () => {
      const validComponent = {
        componentName: 'TestComponent',
        filePath: './TestComponent.tsx',
        imports: ['React'],
        props: {
          title: { type: 'string', required: true },
          count: { type: 'number', required: false, default: 0 },
        },
        jsx: '<div>{title}: {count}</div>',
        exports: ['TestComponent'],
      };

      const result = guards.component.validate(validComponent);
      expect(result).toEqual(validComponent);
    });

    it('should validate schema generation', () => {
      const validSchema = {
        tables: [
          {
            name: 'users',
            columns: [
              { name: 'id', type: 'uuid', nullable: false, primary_key: true },
              { name: 'name', type: 'text', nullable: false, primary_key: false },
            ],
            indexes: [
              { name: 'users_pkey', columns: ['id'], unique: true },
            ],
          },
        ],
        views: [
          { name: 'active_users', definition: 'SELECT * FROM users WHERE active = true' },
        ],
      };

      const result = guards.schema.validate(validSchema);
      expect(result).toEqual(validSchema);
    });

    it('should validate migration generation', () => {
      const validMigration = {
        name: 'add_user_table',
        statements: [
          'CREATE TABLE users (id UUID PRIMARY KEY, name TEXT NOT NULL)',
        ],
        rollback: [
          'DROP TABLE users',
        ],
        dependencies: [],
      };

      const result = guards.migration.validate(validMigration);
      expect(result).toEqual(validMigration);
    });

    it('should validate diagram generation', () => {
      const validDiagram = {
        type: 'mermaid' as const,
        content: 'graph TD; A-->B',
        title: 'Test Diagram',
        format: 'png' as const,
      };

      const result = guards.diagram.validate(validDiagram);
      expect(result).toEqual(validDiagram);
    });
  });
});