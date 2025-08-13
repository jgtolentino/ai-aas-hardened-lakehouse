import { brunoExecutor } from '../../bruno/executor/bruno-executor';
import { scannerOrchestrator } from '../scanners/scanner-orchestrator';
import { policyEngine } from '../policies/policy-engine';
import type { BrunoJob, BrunoResult } from '../../bruno/executor/types';
import type { ScanRequest, SecurityScanResult } from '../scanners/types';

/**
 * Integrates security scanning into Bruno execution pipeline
 */
export function integrateSecurity(): void {
  // Add pre-execution security checks
  brunoExecutor.on('job:pre-execute', async (job: BrunoJob) => {
    // Skip security checks for security scan jobs themselves
    if (job.metadata?.skipSecurityCheck) {
      return;
    }

    // Check if job involves code execution or file operations
    if (shouldRunSecurityCheck(job)) {
      const scanResult = await runPreExecutionScan(job);
      
      // Evaluate against policies
      const policyResults = await policyEngine.evaluate([scanResult]);
      
      // Block execution if critical issues found
      const blocked = policyResults.some(r => !r.passed && r.violations.some(v => v.finding.severity === 'critical'));
      
      if (blocked) {
        throw new Error('Security policy violation: Critical vulnerabilities detected');
      }
    }
  });

  // Add post-execution security audit
  brunoExecutor.on('job:post-execute', async (result: BrunoResult) => {
    // Log security-relevant events
    if (result.securityEvents && result.securityEvents.length > 0) {
      for (const event of result.securityEvents) {
        if (event.severity === 'high' || event.severity === 'critical') {
          console.warn(`Security Event [${event.severity}]: ${event.details}`);
        }
      }
    }
  });
}

/**
 * Determines if a job should trigger security checks
 */
function shouldRunSecurityCheck(job: BrunoJob): boolean {
  // Check job type
  const riskyTypes = ['script', 'file', 'api'];
  if (!riskyTypes.includes(job.type)) {
    return false;
  }

  // Check permissions
  const riskyPermissions = ['file:write', 'network:connect', 'database:write'];
  const hasRiskyPermission = job.permissions.some(p => 
    riskyPermissions.some(risky => p.startsWith(risky))
  );

  return hasRiskyPermission;
}

/**
 * Runs security scan on job content before execution
 */
async function runPreExecutionScan(job: BrunoJob): Promise<SecurityScanResult> {
  // Create temporary file with job content for scanning
  const tempFile = `/tmp/bruno-job-${job.id}.tmp`;
  
  // Prepare content for scanning
  let content = '';
  if (job.script) {
    content = job.script;
  } else if (job.command) {
    content = `#!/bin/bash\n${job.command}`;
  } else if (job.payload) {
    content = JSON.stringify(job.payload, null, 2);
  }

  // Write to temp file
  const fs = await import('fs');
  fs.writeFileSync(tempFile, content);

  try {
    // Run security scan
    const scanRequest: ScanRequest = {
      id: `bruno-prescan-${job.id}`,
      target: tempFile,
      scanners: ['semgrep', 'trufflehog'], // Fast scanners only
      options: {
        severityThreshold: 'high',
        failOnFindings: true
      }
    };

    const summary = await scannerOrchestrator.scan(scanRequest);
    
    // Return first result (should be only one for temp file)
    return summary.results[0] || {
      scanId: scanRequest.id,
      scanner: 'bruno-security',
      scanType: 'sast' as const,
      startTime: summary.startTime,
      endTime: summary.endTime,
      status: 'success' as const,
      findings: [],
      summary: {
        total: 0,
        critical: 0,
        high: 0,
        medium: 0,
        low: 0,
        info: 0
      }
    };
  } finally {
    // Clean up temp file
    try {
      fs.unlinkSync(tempFile);
    } catch {
      // Ignore cleanup errors
    }
  }
}

/**
 * Creates a Bruno job for running security scans
 */
export function createSecurityScanJob(
  target: string,
  options?: {
    scanners?: string[];
    severity?: string[];
    policies?: string[];
  }
): BrunoJob {
  return {
    id: `security-scan-${Date.now()}`,
    type: 'script',
    script: `
const { scannerOrchestrator } = require('./security/scanners/scanner-orchestrator');
const { policyEngine } = require('./security/policies/policy-engine');

async function runSecurityScan() {
  const request = {
    id: 'scan-${Date.now()}',
    target: '${target}',
    scanners: ${JSON.stringify(options?.scanners || [])},
    options: {
      severity: ${JSON.stringify(options?.severity || ['critical', 'high', 'medium'])}
    }
  };

  // Run scan
  const summary = await scannerOrchestrator.scan(request);
  
  // Apply policies if specified
  let policyResults = null;
  if (${JSON.stringify(options?.policies || [])}.length > 0) {
    policyResults = await policyEngine.evaluate(
      summary.results, 
      ${JSON.stringify(options?.policies || [])}
    );
  }

  // Output results
  console.log(JSON.stringify({
    summary,
    policyResults
  }, null, 2));

  // Check for failures
  const hasCritical = summary.findingsBySeverity.critical > 0;
  const policyFailed = policyResults && policyResults.some(r => !r.passed);
  
  if (hasCritical || policyFailed) {
    process.exit(1);
  }
}

runSecurityScan().catch(error => {
  console.error('Security scan failed:', error);
  process.exit(1);
});
    `,
    permissions: [
      'file:read',
      'process:execute',
      'network:connect'
    ],
    timeout: 1800000, // 30 minutes
    metadata: {
      skipSecurityCheck: true, // Don't scan the scanner itself
      type: 'security-scan'
    }
  };
}

/**
 * Wraps any Bruno job with security scanning
 */
export function wrapWithSecurity(job: BrunoJob): BrunoJob {
  return {
    ...job,
    script: `
// Security check wrapper
const { runPreExecutionScan } = require('./security/integration/bruno-security');

async function secureExecute() {
  // Run security scan first
  const scanResult = await runPreExecutionScan(${JSON.stringify(job)});
  
  if (scanResult.summary.critical > 0) {
    throw new Error('Critical security issues detected');
  }

  // Execute original job
  ${job.script || `require('child_process').execSync('${job.command}')`}
}

secureExecute().catch(error => {
  console.error('Secure execution failed:', error);
  process.exit(1);
});
    `,
    metadata: {
      ...job.metadata,
      securityWrapped: true
    }
  };
}