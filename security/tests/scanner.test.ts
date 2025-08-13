import { BaseScanner } from '../scanners/base-scanner';
import { TrivyScanner } from '../scanners/trivy-scanner';
import { SemgrepScanner } from '../scanners/semgrep-scanner';
import { TruffleHogScanner } from '../scanners/trufflehog-scanner';
import { scannerOrchestrator } from '../scanners/scanner-orchestrator';
import { policyEngine } from '../policies/policy-engine';
import type { ScannerConfig, SecurityFinding } from '../scanners/types';

// Mock scanner for testing
class MockScanner extends BaseScanner {
  constructor(config?: Partial<ScannerConfig>) {
    super({
      name: 'mock-scanner',
      type: 'sast',
      enabled: true,
      ...config
    });
  }

  async scan(target: string): Promise<any> {
    const findings: SecurityFinding[] = [
      {
        id: 'mock-1',
        type: 'vulnerability',
        severity: 'high',
        title: 'Mock vulnerability',
        description: 'This is a mock finding for testing',
        location: {
          file: target,
          line: 10
        },
        remediation: 'Fix the mock issue'
      }
    ];

    return this.createScanResult(
      'mock-scanner',
      'sast',
      findings,
      'success'
    );
  }

  async isAvailable(): Promise<boolean> {
    return true;
  }

  async getVersion(): Promise<string> {
    return '1.0.0-mock';
  }
}

describe('Security Scanner Tests', () => {
  describe('BaseScanner', () => {
    test('should create scanner instance', () => {
      const scanner = new MockScanner();
      expect(scanner.name).toBe('mock-scanner');
      expect(scanner.type).toBe('sast');
    });

    test('should check availability', async () => {
      const scanner = new MockScanner();
      const available = await scanner.isAvailable();
      expect(available).toBe(true);
    });

    test('should filter findings by severity', () => {
      const scanner = new MockScanner({
        severity: ['critical', 'high']
      });

      const findings: SecurityFinding[] = [
        { 
          id: '1', 
          type: 'vuln', 
          severity: 'critical', 
          title: 'Critical', 
          description: 'test' 
        },
        { 
          id: '2', 
          type: 'vuln', 
          severity: 'medium', 
          title: 'Medium', 
          description: 'test' 
        }
      ];

      // @ts-ignore - accessing protected method for testing
      const filtered = scanner.filterBySeverity(findings);
      expect(filtered).toHaveLength(1);
      expect(filtered[0].severity).toBe('critical');
    });
  });

  describe('Scanner Implementations', () => {
    test('should create Trivy scanner', () => {
      const scanner = new TrivyScanner();
      expect(scanner.name).toBe('trivy');
      expect(scanner.type).toBe('container');
    });

    test('should create Semgrep scanner', () => {
      const scanner = new SemgrepScanner();
      expect(scanner.name).toBe('semgrep');
      expect(scanner.type).toBe('sast');
    });

    test('should create TruffleHog scanner', () => {
      const scanner = new TruffleHogScanner();
      expect(scanner.name).toBe('trufflehog');
      expect(scanner.type).toBe('secrets');
    });
  });

  describe('Scanner Orchestrator', () => {
    test('should list available scanners', () => {
      const scanners = scannerOrchestrator.listScanners();
      expect(scanners).toContain('trivy');
      expect(scanners).toContain('semgrep');
      expect(scanners).toContain('trufflehog');
    });

    test('should register custom scanner', () => {
      const mockScanner = new MockScanner();
      scannerOrchestrator.registerScanner(mockScanner);
      
      const scanners = scannerOrchestrator.listScanners();
      expect(scanners).toContain('mock-scanner');
      
      // Cleanup
      scannerOrchestrator.unregisterScanner('mock-scanner');
    });

    test('should deduplicate findings', () => {
      const results = [
        {
          scanId: '1',
          scanner: 'scanner1',
          scanType: 'sast' as const,
          startTime: new Date(),
          endTime: new Date(),
          status: 'success' as const,
          findings: [
            {
              id: '1',
              type: 'vuln',
              severity: 'high' as const,
              title: 'SQL Injection',
              description: 'test',
              location: { file: 'app.js', line: 10 }
            }
          ],
          summary: {
            total: 1,
            critical: 0,
            high: 1,
            medium: 0,
            low: 0,
            info: 0
          }
        },
        {
          scanId: '2',
          scanner: 'scanner2',
          scanType: 'sast' as const,
          startTime: new Date(),
          endTime: new Date(),
          status: 'success' as const,
          findings: [
            {
              id: '2',
              type: 'vuln',
              severity: 'medium' as const,
              title: 'SQL Injection',
              description: 'test',
              location: { file: 'app.js', line: 10 }
            }
          ],
          summary: {
            total: 1,
            critical: 0,
            high: 0,
            medium: 1,
            low: 0,
            info: 0
          }
        }
      ];

      const deduplicated = scannerOrchestrator.deduplicateFindings(results);
      expect(deduplicated).toHaveLength(1);
      expect(deduplicated[0].severity).toBe('high'); // Should keep higher severity
    });
  });

  describe('Policy Engine', () => {
    test('should list default policies', () => {
      const policies = policyEngine.listPolicies();
      expect(policies.length).toBeGreaterThan(0);
      
      const policyIds = policies.map(p => p.id);
      expect(policyIds).toContain('owasp-top-10');
      expect(policyIds).toContain('no-secrets');
    });

    test('should evaluate findings against policies', async () => {
      const mockResults = [{
        scanId: 'test',
        scanner: 'test',
        scanType: 'sast' as const,
        startTime: new Date(),
        endTime: new Date(),
        status: 'success' as const,
        findings: [
          {
            id: '1',
            type: 'injection',
            severity: 'critical' as const,
            title: 'SQL Injection detected',
            description: 'SQL injection vulnerability found',
            location: { file: 'db.js', line: 42 }
          }
        ],
        summary: {
          total: 1,
          critical: 1,
          high: 0,
          medium: 0,
          low: 0,
          info: 0
        }
      }];

      const results = await policyEngine.evaluate(mockResults, ['owasp-top-10']);
      expect(results).toHaveLength(1);
      expect(results[0].policyId).toBe('owasp-top-10');
      expect(results[0].passed).toBe(false);
      expect(results[0].violations).toHaveLength(1);
    });

    test('should add custom policy', () => {
      const customPolicy = {
        id: 'test-policy',
        name: 'Test Policy',
        description: 'Test policy for unit tests',
        enforcement: 'warn' as const,
        rules: [
          {
            id: 'test-rule',
            severity: 'high' as const,
            pattern: 'test-pattern',
            message: 'Test violation',
            remediation: 'Fix test issue'
          }
        ]
      };

      policyEngine.addPolicy(customPolicy);
      const policy = policyEngine.getPolicy('test-policy');
      expect(policy).toBeDefined();
      expect(policy?.name).toBe('Test Policy');
      
      // Cleanup
      policyEngine.removePolicy('test-policy');
    });
  });
});