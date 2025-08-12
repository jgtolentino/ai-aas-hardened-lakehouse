#!/usr/bin/env node

import { Command } from 'commander';
import { scannerOrchestrator } from '../scanners/scanner-orchestrator';
import { policyEngine } from '../policies/policy-engine';
import { brunoExecutor } from '../../bruno/executor/bruno-executor';
import type { ScanRequest, SecurityScanResult } from '../scanners/types';
import { writeFileSync, mkdirSync, existsSync } from 'fs';
import { join } from 'path';
import chalk from 'chalk';

const program = new Command();

program
  .name('security')
  .description('AI-AAS Security Scanner CLI')
  .version('1.0.0');

// Scan command
program
  .command('scan <target>')
  .description('Run security scans on a target')
  .option('-s, --scanners <scanners...>', 'Specific scanners to use')
  .option('-t, --type <type>', 'Target type (auto, code, container, git)')
  .option('--severity <levels...>', 'Severity levels to report', ['critical', 'high', 'medium'])
  .option('--fail-on <level>', 'Fail if findings at or above this severity', 'critical')
  .option('-o, --output <file>', 'Output results to file')
  .option('--format <format>', 'Output format (json, markdown, sarif)', 'markdown')
  .option('--parallel', 'Run scanners in parallel', true)
  .option('--verify-secrets', 'Verify if detected secrets are active')
  .option('--policy <policies...>', 'Security policies to enforce')
  .option('--bruno', 'Execute scans through Bruno sandbox')
  .action(async (target, options) => {
    console.log(chalk.blue('🔍 Starting security scan...'));
    
    try {
      const request: ScanRequest = {
        id: `scan-${Date.now()}`,
        target,
        scanners: options.scanners,
        options: {
          severityThreshold: options.failOn,
          failOnFindings: true
        }
      };

      // Configure scanner options
      if (options.verifySecrets) {
        request.options!.verify = true;
      }

      let summary;
      
      if (options.bruno) {
        // Execute through Bruno for sandboxed scanning
        console.log(chalk.yellow('🔒 Executing through Bruno sandbox...'));
        
        const brunoJob = {
          id: request.id,
          type: 'script' as const,
          script: generateScanScript(request),
          permissions: ['network:connect', 'file:read', 'process:execute'],
          timeout: 1800000 // 30 minutes
        };

        const brunoResult = await brunoExecutor.execute(brunoJob);
        
        if (brunoResult.status !== 'success') {
          throw new Error(`Bruno execution failed: ${brunoResult.error}`);
        }

        summary = JSON.parse(brunoResult.stdout!);
      } else {
        // Direct execution
        summary = await scannerOrchestrator.scan(request);
      }

      // Apply security policies if specified
      let policyResults = null;
      if (options.policy && options.policy.length > 0) {
        console.log(chalk.blue('\n📋 Evaluating security policies...'));
        policyResults = await policyEngine.evaluate(summary.results, options.policy);
      }

      // Format output
      const output = formatOutput(summary, policyResults, options.format);
      
      // Save to file if requested
      if (options.output) {
        const outputPath = join(process.cwd(), options.output);
        const outputDir = join(outputPath, '..');
        
        if (!existsSync(outputDir)) {
          mkdirSync(outputDir, { recursive: true });
        }
        
        writeFileSync(outputPath, output);
        console.log(chalk.green(`\n✅ Results saved to: ${outputPath}`));
      } else {
        console.log('\n' + output);
      }

      // Check failure conditions
      const shouldFail = checkFailureConditions(summary, options.failOn, policyResults);
      
      if (shouldFail) {
        console.log(chalk.red('\n❌ Security scan failed - vulnerabilities found above threshold'));
        process.exit(1);
      } else {
        console.log(chalk.green('\n✅ Security scan completed successfully'));
      }
    } catch (error) {
      console.error(chalk.red(`\n❌ Scan failed: ${error}`));
      process.exit(1);
    }
  });

// List scanners command
program
  .command('list-scanners')
  .description('List available security scanners')
  .action(async () => {
    console.log(chalk.blue('Available Security Scanners:\n'));
    
    const scanners = scannerOrchestrator.listScanners();
    const status = await scannerOrchestrator.checkAllScanners();
    
    for (const scanner of scanners) {
      const info = await scannerOrchestrator.getScannerInfo(scanner);
      const available = status[scanner];
      
      console.log(`${available ? chalk.green('✓') : chalk.red('✗')} ${chalk.bold(scanner)}`);
      console.log(`   Type: ${info.type}`);
      console.log(`   Version: ${info.version}`);
      console.log(`   Status: ${available ? 'Available' : 'Not Available'}`);
      console.log('');
    }
  });

// Policy commands
program
  .command('list-policies')
  .description('List security policies')
  .action(() => {
    console.log(chalk.blue('Security Policies:\n'));
    
    const policies = policyEngine.listPolicies();
    
    for (const policy of policies) {
      console.log(chalk.bold(policy.name));
      console.log(`  ID: ${policy.id}`);
      console.log(`  Description: ${policy.description}`);
      console.log(`  Enforcement: ${policy.enforcement}`);
      console.log(`  Rules: ${policy.rules.length}`);
      console.log('');
    }
  });

// Quick scan presets
program
  .command('quick-scan <preset> <target>')
  .description('Run a preset security scan (secrets, dependencies, containers, full)')
  .option('-o, --output <file>', 'Output results to file')
  .action(async (preset, target, options) => {
    const presets: Record<string, string[]> = {
      secrets: ['trufflehog'],
      dependencies: ['trivy'],
      sast: ['semgrep'],
      containers: ['trivy'],
      full: ['trivy', 'semgrep', 'trufflehog']
    };

    if (!presets[preset]) {
      console.error(chalk.red(`Unknown preset: ${preset}`));
      console.log('Available presets: ' + Object.keys(presets).join(', '));
      process.exit(1);
    }

    console.log(chalk.blue(`🚀 Running ${preset} scan on ${target}...`));
    
    // Execute scan with preset scanners
    await program.parse([
      ...process.argv.slice(0, 2),
      'scan',
      target,
      '--scanners', ...presets[preset],
      ...(options.output ? ['--output', options.output] : [])
    ]);
  });

// Self-test command
program
  .command('test')
  .description('Run security scanner self-test')
  .action(async () => {
    console.log(chalk.blue('Running security scanner self-test...\n'));
    
    const tests = [
      {
        name: 'Scanner Availability',
        test: async () => {
          const status = await scannerOrchestrator.checkAllScanners();
          const available = Object.values(status).filter(s => s).length;
          return {
            passed: available > 0,
            message: `${available}/${Object.keys(status).length} scanners available`
          };
        }
      },
      {
        name: 'Policy Engine',
        test: async () => {
          const policies = policyEngine.listPolicies();
          return {
            passed: policies.length > 0,
            message: `${policies.length} policies loaded`
          };
        }
      },
      {
        name: 'Bruno Integration',
        test: async () => {
          try {
            const result = await brunoExecutor.execute({
              id: 'test-security',
              type: 'shell',
              command: 'echo "Security test"',
              permissions: ['process:execute'],
              timeout: 5000
            });
            return {
              passed: result.status === 'success',
              message: 'Bruno executor working'
            };
          } catch {
            return {
              passed: false,
              message: 'Bruno executor not available'
            };
          }
        }
      }
    ];

    for (const test of tests) {
      process.stdout.write(`${test.name}... `);
      try {
        const result = await test.test();
        if (result.passed) {
          console.log(chalk.green(`✓ ${result.message}`));
        } else {
          console.log(chalk.red(`✗ ${result.message}`));
        }
      } catch (error) {
        console.log(chalk.red(`✗ Error: ${error}`));
      }
    }
  });

// Helper functions
function generateScanScript(request: ScanRequest): string {
  return `
const { scannerOrchestrator } = require('../scanners/scanner-orchestrator');

async function runScan() {
  const request = ${JSON.stringify(request)};
  const summary = await scannerOrchestrator.scan(request);
  console.log(JSON.stringify(summary));
}

runScan().catch(console.error);
  `;
}

function formatOutput(
  summary: any, 
  policyResults: any, 
  format: string
): string {
  switch (format) {
    case 'json':
      return JSON.stringify({ summary, policyResults }, null, 2);
    
    case 'sarif':
      return formatSARIF(summary);
    
    case 'markdown':
    default:
      return formatMarkdown(summary, policyResults);
  }
}

function formatMarkdown(summary: any, policyResults: any): string {
  let output = `# Security Scan Report\n\n`;
  output += `**Target:** ${summary.target}\n`;
  output += `**Date:** ${new Date().toISOString()}\n`;
  output += `**Duration:** ${(summary.endTime - summary.startTime) / 1000}s\n\n`;

  // Summary
  output += `## Summary\n`;
  output += `- **Total Findings:** ${summary.totalFindings}\n`;
  output += `- **Critical:** ${summary.findingsBySeverity.critical || 0}\n`;
  output += `- **High:** ${summary.findingsBySeverity.high || 0}\n`;
  output += `- **Medium:** ${summary.findingsBySeverity.medium || 0}\n`;
  output += `- **Low:** ${summary.findingsBySeverity.low || 0}\n`;
  output += `- **Info:** ${summary.findingsBySeverity.info || 0}\n\n`;

  // Scanner Results
  output += `## Scanner Results\n`;
  for (const [scanner, count] of Object.entries(summary.findingsByScanner)) {
    output += `- **${scanner}:** ${count} findings\n`;
  }
  
  if (summary.failedScanners.length > 0) {
    output += `\n### Failed Scanners\n`;
    for (const scanner of summary.failedScanners) {
      output += `- ${scanner}\n`;
    }
  }

  // Detailed Findings
  output += `\n## Findings\n`;
  
  const allFindings = summary.results.flatMap((r: any) => r.findings || []);
  const criticalFindings = allFindings.filter((f: any) => f.severity === 'critical');
  const highFindings = allFindings.filter((f: any) => f.severity === 'high');
  
  if (criticalFindings.length > 0) {
    output += `\n### Critical Findings\n`;
    for (const finding of criticalFindings) {
      output += formatFinding(finding);
    }
  }
  
  if (highFindings.length > 0) {
    output += `\n### High Severity Findings\n`;
    for (const finding of highFindings) {
      output += formatFinding(finding);
    }
  }

  // Policy Results
  if (policyResults) {
    output += `\n## Policy Evaluation\n`;
    output += policyEngine.generateReport(policyResults);
  }

  return output;
}

function formatFinding(finding: any): string {
  let output = `\n#### ${finding.title}\n`;
  output += `- **Severity:** ${finding.severity}\n`;
  output += `- **Type:** ${finding.type}\n`;
  
  if (finding.location?.file) {
    output += `- **Location:** ${finding.location.file}`;
    if (finding.location.line) {
      output += `:${finding.location.line}`;
    }
    output += `\n`;
  }
  
  output += `- **Description:** ${finding.description}\n`;
  
  if (finding.cve) {
    output += `- **CVE:** ${finding.cve}\n`;
  }
  
  if (finding.remediation) {
    output += `- **Remediation:** ${finding.remediation}\n`;
  }
  
  return output;
}

function formatSARIF(summary: any): string {
  // SARIF 2.1.0 format for integration with GitHub, VS Code, etc.
  const sarif = {
    $schema: 'https://json.schemastore.org/sarif-2.1.0.json',
    version: '2.1.0',
    runs: summary.results.map((result: any) => ({
      tool: {
        driver: {
          name: result.scanner,
          version: '1.0.0',
          rules: []
        }
      },
      results: result.findings.map((finding: any) => ({
        ruleId: finding.id,
        level: mapSeverityToSARIF(finding.severity),
        message: {
          text: finding.description
        },
        locations: finding.location ? [{
          physicalLocation: {
            artifactLocation: {
              uri: finding.location.file
            },
            region: {
              startLine: finding.location.line || 1,
              startColumn: finding.location.column || 1
            }
          }
        }] : []
      }))
    }))
  };
  
  return JSON.stringify(sarif, null, 2);
}

function mapSeverityToSARIF(severity: string): string {
  const map: Record<string, string> = {
    critical: 'error',
    high: 'error',
    medium: 'warning',
    low: 'note',
    info: 'note'
  };
  return map[severity] || 'note';
}

function checkFailureConditions(
  summary: any, 
  threshold: string,
  policyResults: any
): boolean {
  // Check severity threshold
  const severityOrder = ['info', 'low', 'medium', 'high', 'critical'];
  const thresholdIndex = severityOrder.indexOf(threshold);
  
  for (let i = thresholdIndex; i < severityOrder.length; i++) {
    const severity = severityOrder[i];
    if (summary.findingsBySeverity[severity] > 0) {
      return true;
    }
  }

  // Check policy failures
  if (policyResults) {
    const failedPolicies = policyResults.filter((r: any) => !r.passed);
    if (failedPolicies.length > 0) {
      return true;
    }
  }

  return false;
}

// Parse command line arguments
program.parse();