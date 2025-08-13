import { describe, it, expect, beforeEach } from '@jest/globals';
import { MCPSecurityGuard } from '../guards/mcp-security-guard';
import { MCPInterceptor } from '../middleware/mcp-interceptor';
import type { MCPRequest } from '../middleware/mcp-interceptor';

describe('MCP Security Tests', () => {
  let guard: MCPSecurityGuard;
  let interceptor: MCPInterceptor;

  beforeEach(() => {
    guard = new MCPSecurityGuard();
    interceptor = new MCPInterceptor();
  });

  describe('Server Access Control', () => {
    it('should allow whitelisted servers', () => {
      expect(guard.validateServerAccess('filesystem')).toBe(true);
      expect(guard.validateServerAccess('context7')).toBe(true);
      expect(guard.validateServerAccess('supabase_primary')).toBe(true);
    });

    it('should block unknown servers', () => {
      expect(guard.validateServerAccess('malicious_server')).toBe(false);
      expect(guard.validateServerAccess('random')).toBe(false);
    });
  });

  describe('Action Validation', () => {
    it('should block dangerous actions', () => {
      expect(guard.validateAction('any', 'drop')).toBe(false);
      expect(guard.validateAction('any', 'truncate')).toBe(false);
      expect(guard.validateAction('any', 'execute')).toBe(false);
    });

    it('should allow safe actions', () => {
      expect(guard.validateAction('any', 'select')).toBe(true);
      expect(guard.validateAction('any', 'read')).toBe(true);
      expect(guard.validateAction('any', 'list')).toBe(true);
    });
  });

  describe('Schema Protection', () => {
    it('should block sensitive schemas', () => {
      expect(guard.validateSchemaAccess('any', 'auth')).toBe(false);
      expect(guard.validateSchemaAccess('any', 'private')).toBe(false);
      expect(guard.validateSchemaAccess('any', 'secrets')).toBe(false);
    });

    it('should allow public schemas', () => {
      expect(guard.validateSchemaAccess('any', 'public')).toBe(true);
      expect(guard.validateSchemaAccess('any', 'scout')).toBe(true);
      expect(guard.validateSchemaAccess('any', 'analytics')).toBe(true);
    });
  });

  describe('Query Validation', () => {
    it('should block dangerous queries', () => {
      expect(guard.validateQuery('DROP TABLE users')).toBe(false);
      expect(guard.validateQuery('TRUNCATE TABLE orders')).toBe(false);
      expect(guard.validateQuery('DELETE FROM customers;')).toBe(false);
      expect(guard.validateQuery('UPDATE products SET price = 0;')).toBe(false);
    });

    it('should allow safe queries', () => {
      expect(guard.validateQuery('SELECT * FROM users WHERE id = 1')).toBe(true);
      expect(guard.validateQuery('INSERT INTO logs (message) VALUES (?)')).toBe(true);
      expect(guard.validateQuery('UPDATE users SET name = ? WHERE id = ?')).toBe(true);
      expect(guard.validateQuery('DELETE FROM sessions WHERE expired = true')).toBe(true);
    });
  });

  describe('Sensitive Data Detection', () => {
    it('should detect API keys', () => {
      const findings = guard.detectSensitiveData({ api_key: 'secret123' });
      expect(findings.length).toBeGreaterThan(0);
    });

    it('should detect passwords', () => {
      const findings = guard.detectSensitiveData({ password: 'mypass' });
      expect(findings.length).toBeGreaterThan(0);
    });

    it('should allow clean data', () => {
      const findings = guard.detectSensitiveData({ name: 'John', age: 30 });
      expect(findings.length).toBe(0);
    });
  });

  describe('Request Interception', () => {
    it('should intercept and validate requests', async () => {
      const request: MCPRequest = {
        server: 'filesystem',
        method: 'read',
        params: { path: '/test.txt' }
      };

      const response = await interceptor.intercept(request);
      expect(response.success).toBe(true);
    });

    it('should block unauthorized server access', async () => {
      const request: MCPRequest = {
        server: 'unknown_server',
        method: 'read',
        params: {}
      };

      const response = await interceptor.intercept(request);
      expect(response.success).toBe(false);
      expect(response.error).toContain('Access denied');
    });

    it('should block dangerous actions', async () => {
      const request: MCPRequest = {
        server: 'supabase_primary',
        method: 'drop',
        params: { table: 'users' }
      };

      const response = await interceptor.intercept(request);
      expect(response.success).toBe(false);
      expect(response.error).toContain('Action not allowed');
    });

    it('should validate SQL queries', async () => {
      const request: MCPRequest = {
        server: 'supabase_primary',
        method: 'execute_sql',
        params: { sql: 'DROP TABLE users;' }
      };

      const response = await interceptor.intercept(request);
      expect(response.success).toBe(false);
      expect(response.error).toContain('Dangerous query pattern');
    });
  });

  describe('Audit Logging', () => {
    it('should log all operations', () => {
      guard.validateServerAccess('test_server');
      guard.validateAction('test_server', 'read');
      
      const auditLog = guard.getAuditLog();
      expect(auditLog.length).toBe(2);
      expect(auditLog[0].server).toBe('test_server');
    });

    it('should generate security reports', () => {
      guard.validateServerAccess('unknown'); // Should fail
      guard.validateAction('test', 'drop'); // Should fail
      guard.validateSchemaAccess('test', 'auth'); // Should fail
      
      const report = guard.generateSecurityReport();
      expect(report).toContain('Blocked: 3');
      expect(report).toContain('unknown');
      expect(report).toContain('drop');
      expect(report).toContain('auth');
    });
  });
});