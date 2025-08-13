import { pulser } from '../../pulser/pulser';
import { scannerOrchestrator } from '../scanners/scanner-orchestrator';
import { policyEngine } from '../policies/policy-engine';
import { createSecurityScanJob } from './bruno-security';
import type { RoutingRequest } from '../../pulser/router';
import type { Agent } from '../../pulser/registry/types';

/**
 * Security Scanner Agent for Pulser
 */
export const securityScannerAgent: Agent = {
  id: 'security-scanner',
  name: 'Security Scanner',
  type: 'security',
  version: '1.0.0',
  status: 'ready',
  capabilities: [
    'security-scan',
    'vulnerability-detection',
    'secret-detection',
    'policy-evaluation',
    'compliance-check'
  ],
  metadata: {
    description: 'Comprehensive security scanning and vulnerability detection',
    author: 'AI-AAS Security Team',
    scanners: ['trivy', 'semgrep', 'trufflehog'],
    policies: ['owasp-top-10', 'no-secrets', 'container-security']
  },
  config: {
    endpoint: 'internal:security-scanner',
    timeout: 1800000, // 30 minutes
    retries: 1
  },
  execute: async (request: any) => {
    // Create a Bruno job for secure execution
    const scanJob = createSecurityScanJob(request.target || '.', {
      scanners: request.scanners,
      severity: request.severity,
      policies: request.policies
    });

    // Execute through Bruno (which will handle sandboxing)
    const brunoExecutor = await import('../../bruno/executor/bruno-executor')
      .then(m => m.brunoExecutor);
    
    return brunoExecutor.execute(scanJob);
  }
};

/**
 * Integrates security scanning into Pulser pipeline
 */
export function integratePulserSecurity(): void {
  // Register security scanner agent
  pulser.registry.registerAgent(securityScannerAgent);

  // Add pre-execution security check middleware
  pulser.on('request:pre-route', async (request: RoutingRequest) => {
    // Skip security checks for security scan requests
    if (request.capability === 'security-scan' || 
        request.metadata?.skipSecurityCheck) {
      return;
    }

    // Check if request involves code execution or sensitive operations
    const sensitiveCapabilities = [
      'code-generation',
      'code-execution',
      'file-modification',
      'database-access',
      'network-request'
    ];

    const needsSecurityCheck = sensitiveCapabilities.some(cap => 
      request.capability === cap
    );

    if (needsSecurityCheck && request.payload?.code) {
      // Run quick security scan on the code
      const scanRequest = {
        id: `pre-exec-scan-${request.id}`,
        target: 'inline-code',
        scanners: ['semgrep'], // Fast SAST only
        options: {
          code: request.payload.code,
          language: request.payload.language || 'javascript'
        }
      };

      try {
        const scanSummary = await scannerOrchestrator.scan(scanRequest);
        
        // Check for critical findings
        if (scanSummary.findingsBySeverity.critical > 0) {
          throw new Error(
            `Security check failed: ${scanSummary.findingsBySeverity.critical} critical vulnerabilities detected`
          );
        }

        // Add scan results to request metadata
        request.metadata = {
          ...request.metadata,
          securityScan: {
            performed: true,
            findings: scanSummary.totalFindings,
            passed: scanSummary.findingsBySeverity.critical === 0
          }
        };
      } catch (error) {
        console.warn('Pre-execution security scan failed:', error);
        // Decide whether to block or warn based on policy
        if (process.env.SECURITY_ENFORCEMENT === 'strict') {
          throw error;
        }
      }
    }
  });

  // Add post-execution security audit
  pulser.on('request:complete', async (request: RoutingRequest, result: any) => {
    // Log security-relevant events
    if (request.metadata?.securityScan) {
      console.log(
        `Security Audit - Request ${request.id}:`,
        `Findings: ${request.metadata.securityScan.findings},`,
        `Passed: ${request.metadata.securityScan.passed}`
      );
    }

    // If result contains generated code, scan it
    if (result?.code && request.capability === 'code-generation') {
      const postScanRequest = {
        id: `post-gen-scan-${request.id}`,
        target: 'generated-code',
        scanners: ['semgrep', 'trufflehog'],
        options: {
          code: result.code,
          language: result.language || 'javascript'
        }
      };

      try {
        const scanSummary = await scannerOrchestrator.scan(postScanRequest);
        
        if (scanSummary.totalFindings > 0) {
          console.warn(
            `Generated code contains ${scanSummary.totalFindings} security findings`
          );
          
          // Add warning to result
          result.securityWarnings = {
            findings: scanSummary.totalFindings,
            critical: scanSummary.findingsBySeverity.critical,
            high: scanSummary.findingsBySeverity.high
          };
        }
      } catch (error) {
        console.warn('Post-generation security scan failed:', error);
      }
    }
  });

  console.log('✓ Pulser security integration enabled');
}

/**
 * Security-focused routing strategy for Pulser
 */
export function createSecurityRoutingStrategy() {
  return {
    name: 'security-first',
    description: 'Routes security-sensitive requests through security checks',
    
    selectAgent: async (request: RoutingRequest, agents: Agent[]) => {
      // For security scan requests, always use security scanner
      if (request.capability === 'security-scan') {
        return agents.find(a => a.id === 'security-scanner');
      }

      // For sensitive operations, prefer agents with security capabilities
      const sensitiveOps = ['code-execution', 'database-access', 'file-modification'];
      if (sensitiveOps.includes(request.capability)) {
        // Prefer agents that also have security capabilities
        const secureAgents = agents.filter(a => 
          a.capabilities.includes(request.capability) &&
          a.capabilities.some(c => c.includes('security') || c.includes('safe'))
        );

        if (secureAgents.length > 0) {
          return secureAgents[0];
        }
      }

      // Default to capability-based selection
      return agents.find(a => a.capabilities.includes(request.capability));
    }
  };
}