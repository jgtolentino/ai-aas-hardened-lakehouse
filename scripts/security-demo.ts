#!/usr/bin/env tsx

/**
 * Security Integration Demo
 * 
 * This script demonstrates how the security module integrates with:
 * - Bruno (secure executor)
 * - Pulser (agent orchestration)
 * - MCP servers (data access)
 * 
 * Run with: tsx scripts/security-demo.ts
 */

import { brunoExecutor } from '../bruno/executor/bruno-executor';
import { scannerOrchestrator } from '../security/scanners/scanner-orchestrator';
import { policyEngine } from '../security/policies/policy-engine';
import { integrateSecurity, createSecurityScanJob } from '../security/integration/bruno-security';
import { generateSecurityReport } from '../security/reports/report-generator';
import { createSecurityDashboard, renderTerminalDashboard } from '../security/reports/dashboard';
import chalk from 'chalk';

async function main() {
  console.log(chalk.blue.bold('\n🔒 AI-AAS Security Integration Demo\n'));

  // Step 1: Enable security integration with Bruno
  console.log(chalk.yellow('Step 1: Enabling Bruno security integration...'));
  integrateSecurity();
  console.log(chalk.green('✓ Security checks enabled for all Bruno jobs\n'));

  // Step 2: Check available scanners
  console.log(chalk.yellow('Step 2: Checking available security scanners...'));
  const scannerStatus = await scannerOrchestrator.checkAllScanners();
  
  for (const [scanner, available] of Object.entries(scannerStatus)) {
    console.log(
      `  ${available ? chalk.green('✓') : chalk.red('✗')} ${scanner}: ${
        available ? 'Available' : 'Not Available (Docker image required)'
      }`
    );
  }
  console.log();

  // Step 3: Create a security scan job through Bruno
  console.log(chalk.yellow('Step 3: Creating security scan job...'));
  const scanJob = createSecurityScanJob('.', {
    scanners: ['semgrep', 'trufflehog'],
    severity: ['critical', 'high'],
    policies: ['owasp-top-10', 'no-secrets']
  });
  
  console.log(chalk.gray('  Job ID:', scanJob.id));
  console.log(chalk.gray('  Permissions:', scanJob.permissions.join(', ')));
  console.log();

  // Step 4: Demonstrate policy engine
  console.log(chalk.yellow('Step 4: Loading security policies...'));
  const policies = policyEngine.listPolicies();
  
  for (const policy of policies) {
    console.log(`  • ${chalk.bold(policy.name)}`);
    console.log(`    ID: ${policy.id}`);
    console.log(`    Rules: ${policy.rules.length}`);
    console.log(`    Enforcement: ${policy.enforcement}`);
  }
  console.log();

  // Step 5: Create mock scan results for demo
  console.log(chalk.yellow('Step 5: Simulating security scan results...'));
  
  const mockScanResults = [{
    scanId: 'demo-scan-1',
    scanner: 'semgrep',
    scanType: 'sast' as const,
    startTime: new Date(Date.now() - 60000),
    endTime: new Date(),
    status: 'success' as const,
    findings: [
      {
        id: 'sem-1',
        type: 'injection',
        severity: 'critical' as const,
        title: 'SQL Injection vulnerability',
        description: 'User input directly concatenated into SQL query',
        location: {
          file: 'src/api/users.ts',
          line: 42,
          column: 15
        },
        cwe: 'CWE-89',
        owasp: 'A03:2021',
        remediation: 'Use parameterized queries or prepared statements',
        references: ['https://owasp.org/www-community/attacks/SQL_Injection']
      },
      {
        id: 'sem-2',
        type: 'xss',
        severity: 'high' as const,
        title: 'Cross-Site Scripting (XSS)',
        description: 'Unescaped user input rendered in HTML',
        location: {
          file: 'src/components/UserProfile.tsx',
          line: 28
        },
        cwe: 'CWE-79',
        remediation: 'Escape HTML entities before rendering'
      }
    ],
    summary: {
      total: 2,
      critical: 1,
      high: 1,
      medium: 0,
      low: 0,
      info: 0
    }
  }, {
    scanId: 'demo-scan-2',
    scanner: 'trufflehog',
    scanType: 'secrets' as const,
    startTime: new Date(Date.now() - 45000),
    endTime: new Date(),
    status: 'success' as const,
    findings: [
      {
        id: 'th-1',
        type: 'secret',
        severity: 'critical' as const,
        title: 'AWS Access Key detected',
        description: 'AWS Access Key found in source code (VERIFIED - Active credential!)',
        location: {
          file: 'config/aws.js',
          line: 5
        },
        remediation: '1. Rotate the AWS access key immediately\n2. Check CloudTrail for unauthorized usage\n3. Remove from code and use AWS IAM roles or environment variables'
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

  // Step 6: Evaluate against policies
  console.log(chalk.yellow('\nStep 6: Evaluating findings against security policies...'));
  const policyResults = await policyEngine.evaluate(mockScanResults);
  
  for (const result of policyResults) {
    const policy = policyEngine.getPolicy(result.policyId);
    console.log(
      `  ${result.passed ? chalk.green('✓') : chalk.red('✗')} ${
        policy?.name || result.policyId
      }: ${result.passed ? 'PASSED' : 'FAILED'}`
    );
    if (!result.passed) {
      console.log(chalk.red(`    Violations: ${result.violations.length}`));
    }
  }
  console.log();

  // Step 7: Generate security dashboard
  console.log(chalk.yellow('Step 7: Generating security dashboard...'));
  const dashboardData = createSecurityDashboard(mockScanResults, policyResults);
  console.log(renderTerminalDashboard(dashboardData));

  // Step 8: Generate report
  console.log(chalk.yellow('\nStep 8: Generating security report...'));
  const report = await generateSecurityReport(
    mockScanResults,
    policyResults,
    {
      format: 'markdown',
      includePolicyResults: true,
      includeRemediation: true
    }
  );
  
  console.log(chalk.green('✓ Report generated'));
  console.log(chalk.gray(`  Total findings: ${report.executive.totalFindings}`));
  console.log(chalk.gray(`  Risk score: ${report.executive.riskScore}/100`));
  console.log(chalk.gray(`  Compliance: ${report.executive.complianceStatus}`));
  console.log();

  // Step 9: Demonstrate Bruno execution with security
  console.log(chalk.yellow('Step 9: Testing Bruno execution with security checks...'));
  
  const riskyJob = {
    id: 'demo-risky-job',
    type: 'script' as const,
    script: `
      // This script contains security issues for demo
      const password = "hardcoded-password-123";
      const query = "SELECT * FROM users WHERE id = " + userId;
    `,
    permissions: ['file:write', 'network:connect'],
    timeout: 5000
  };

  console.log(chalk.gray('  Attempting to execute job with security issues...'));
  console.log(chalk.blue('\n  [Note: In production, this would trigger pre-execution'));
  console.log(chalk.blue('   security scans and potentially block the execution]'));
  console.log();

  // Summary
  console.log(chalk.green.bold('✨ Demo Complete!\n'));
  console.log(chalk.white('The AI-AAS security system provides:'));
  console.log('  • Multiple security scanners (Trivy, Semgrep, TruffleHog)');
  console.log('  • Policy-based security enforcement');
  console.log('  • Integration with Bruno for secure execution');
  console.log('  • Comprehensive reporting and dashboards');
  console.log('  • Pre-execution security checks');
  console.log();
  
  console.log(chalk.cyan('Next steps:'));
  console.log('  1. Install Docker and pull scanner images');
  console.log('  2. Run: security scan <path> to scan your project');
  console.log('  3. Configure custom policies for your requirements');
  console.log('  4. Integrate with CI/CD pipeline');
  console.log();
}

// Run demo
main().catch(error => {
  console.error(chalk.red('\n❌ Demo failed:'), error);
  process.exit(1);
});