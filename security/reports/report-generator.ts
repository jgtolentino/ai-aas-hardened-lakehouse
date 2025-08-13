import type { 
  SecurityScanResult, 
  SecurityFinding,
  ComplianceReport 
} from '../scanners/types';
import type { PolicyEvaluationResult } from '../policies/policy-engine';
import { writeFileSync, mkdirSync, existsSync } from 'fs';
import { join } from 'path';

export interface SecurityReportOptions {
  format: 'html' | 'markdown' | 'json' | 'pdf';
  includePolicyResults?: boolean;
  includeRemediation?: boolean;
  groupByType?: boolean;
  outputPath?: string;
}

export interface SecurityReport {
  metadata: {
    reportId: string;
    generatedAt: Date;
    target: string;
    scanDuration: number;
  };
  executive: {
    totalFindings: number;
    criticalFindings: number;
    highFindings: number;
    riskScore: number;
    complianceStatus: string;
  };
  scanResults: SecurityScanResult[];
  policyResults?: PolicyEvaluationResult[];
  recommendations: string[];
}

/**
 * Generates comprehensive security report
 */
export async function generateSecurityReport(
  scanResults: SecurityScanResult[],
  policyResults?: PolicyEvaluationResult[],
  options: SecurityReportOptions = { format: 'markdown' }
): Promise<SecurityReport> {
  const report = createReport(scanResults, policyResults);
  
  // Format report based on requested format
  let formattedReport: string;
  
  switch (options.format) {
    case 'html':
      formattedReport = formatHTML(report, options);
      break;
    case 'json':
      formattedReport = JSON.stringify(report, null, 2);
      break;
    case 'pdf':
      formattedReport = await formatPDF(report, options);
      break;
    case 'markdown':
    default:
      formattedReport = formatMarkdown(report, options);
  }

  // Save to file if path provided
  if (options.outputPath) {
    saveReport(formattedReport, options.outputPath, options.format);
  }

  return report;
}

function createReport(
  scanResults: SecurityScanResult[],
  policyResults?: PolicyEvaluationResult[]
): SecurityReport {
  // Calculate metrics
  const allFindings = scanResults.flatMap(r => r.findings);
  const criticalCount = allFindings.filter(f => f.severity === 'critical').length;
  const highCount = allFindings.filter(f => f.severity === 'high').length;
  
  // Calculate risk score (0-100)
  const riskScore = calculateRiskScore(allFindings);
  
  // Determine compliance status
  const complianceStatus = determineComplianceStatus(policyResults);
  
  // Generate recommendations
  const recommendations = generateRecommendations(allFindings, policyResults);

  return {
    metadata: {
      reportId: `security-report-${Date.now()}`,
      generatedAt: new Date(),
      target: scanResults[0]?.metadata?.target || 'Unknown',
      scanDuration: calculateScanDuration(scanResults)
    },
    executive: {
      totalFindings: allFindings.length,
      criticalFindings: criticalCount,
      highFindings: highCount,
      riskScore,
      complianceStatus
    },
    scanResults,
    policyResults,
    recommendations
  };
}

function calculateRiskScore(findings: SecurityFinding[]): number {
  const weights = {
    critical: 10,
    high: 5,
    medium: 2,
    low: 0.5,
    info: 0.1
  };

  let score = 0;
  
  for (const finding of findings) {
    score += weights[finding.severity] || 0;
  }

  // Normalize to 0-100 scale
  return Math.min(100, Math.round(score));
}

function determineComplianceStatus(policyResults?: PolicyEvaluationResult[]): string {
  if (!policyResults || policyResults.length === 0) {
    return 'Not Evaluated';
  }

  const failed = policyResults.filter(r => !r.passed).length;
  
  if (failed === 0) {
    return 'Compliant';
  } else if (failed < policyResults.length / 2) {
    return 'Partially Compliant';
  } else {
    return 'Non-Compliant';
  }
}

function calculateScanDuration(scanResults: SecurityScanResult[]): number {
  if (scanResults.length === 0) return 0;
  
  const startTimes = scanResults.map(r => new Date(r.startTime).getTime());
  const endTimes = scanResults.map(r => new Date(r.endTime).getTime());
  
  const overallStart = Math.min(...startTimes);
  const overallEnd = Math.max(...endTimes);
  
  return (overallEnd - overallStart) / 1000; // seconds
}

function generateRecommendations(
  findings: SecurityFinding[],
  policyResults?: PolicyEvaluationResult[]
): string[] {
  const recommendations: string[] = [];

  // Critical findings recommendations
  const criticalFindings = findings.filter(f => f.severity === 'critical');
  if (criticalFindings.length > 0) {
    recommendations.push(
      `🚨 **Immediate Action Required**: Address ${criticalFindings.length} critical security vulnerabilities immediately. These pose an immediate threat to system security.`
    );
    
    // Group critical findings by type
    const criticalTypes = new Set(criticalFindings.map(f => f.type));
    for (const type of criticalTypes) {
      const count = criticalFindings.filter(f => f.type === type).length;
      recommendations.push(getTypeSpecificRecommendation(type, count, 'critical'));
    }
  }

  // High severity recommendations
  const highFindings = findings.filter(f => f.severity === 'high');
  if (highFindings.length > 0) {
    recommendations.push(
      `⚠️ **High Priority**: Resolve ${highFindings.length} high-severity issues within the next sprint/release cycle.`
    );
  }

  // Secrets recommendations
  const secretFindings = findings.filter(f => f.type === 'secret');
  if (secretFindings.length > 0) {
    recommendations.push(
      `🔑 **Secrets Management**: ${secretFindings.length} secrets detected. Rotate all credentials immediately and implement proper secret management using environment variables or secret management tools.`
    );
  }

  // Policy compliance recommendations
  if (policyResults) {
    const failedPolicies = policyResults.filter(r => !r.passed);
    if (failedPolicies.length > 0) {
      recommendations.push(
        `📋 **Policy Compliance**: ${failedPolicies.length} security policies failed. Review and address policy violations to meet compliance requirements.`
      );
    }
  }

  // General recommendations
  if (findings.length > 50) {
    recommendations.push(
      `📊 **Technical Debt**: High number of security findings (${findings.length}) indicates significant security technical debt. Consider dedicating a sprint to security improvements.`
    );
  }

  return recommendations;
}

function getTypeSpecificRecommendation(type: string, count: number, severity: string): string {
  const recommendations: Record<string, string> = {
    'injection': `Fix ${count} ${severity} injection vulnerabilities by implementing parameterized queries and input validation.`,
    'xss': `Address ${count} ${severity} XSS vulnerabilities by implementing proper output encoding and Content Security Policy.`,
    'secret': `Remove ${count} exposed secrets/credentials and implement secure secret management.`,
    'vulnerability': `Update ${count} vulnerable dependencies to patched versions.`,
    'misconfiguration': `Fix ${count} security misconfigurations according to security best practices.`
  };

  return recommendations[type] || `Address ${count} ${severity} ${type} security issues.`;
}

function formatMarkdown(report: SecurityReport, options: SecurityReportOptions): string {
  let md = `# Security Scan Report\n\n`;
  md += `**Report ID:** ${report.metadata.reportId}\n`;
  md += `**Generated:** ${report.metadata.generatedAt.toISOString()}\n`;
  md += `**Target:** ${report.metadata.target}\n`;
  md += `**Scan Duration:** ${report.metadata.scanDuration}s\n\n`;

  // Executive Summary
  md += `## Executive Summary\n\n`;
  md += `### Risk Assessment\n`;
  md += `- **Risk Score:** ${report.executive.riskScore}/100 ${getRiskLevel(report.executive.riskScore)}\n`;
  md += `- **Total Findings:** ${report.executive.totalFindings}\n`;
  md += `- **Critical:** ${report.executive.criticalFindings}\n`;
  md += `- **High:** ${report.executive.highFindings}\n`;
  md += `- **Compliance Status:** ${report.executive.complianceStatus}\n\n`;

  // Recommendations
  md += `## Key Recommendations\n\n`;
  for (const rec of report.recommendations) {
    md += `- ${rec}\n`;
  }
  md += '\n';

  // Detailed Findings
  md += `## Detailed Findings\n\n`;
  
  if (options.groupByType) {
    md += formatFindingsByType(report.scanResults);
  } else {
    md += formatFindingsBySeverity(report.scanResults);
  }

  // Policy Results
  if (options.includePolicyResults && report.policyResults) {
    md += `## Policy Compliance\n\n`;
    md += formatPolicyResults(report.policyResults);
  }

  return md;
}

function formatHTML(report: SecurityReport, options: SecurityReportOptions): string {
  // HTML template with embedded CSS for styling
  return `<!DOCTYPE html>
<html>
<head>
  <title>Security Scan Report - ${report.metadata.reportId}</title>
  <style>
    body { font-family: Arial, sans-serif; margin: 40px; }
    .header { background: #f0f0f0; padding: 20px; border-radius: 5px; }
    .risk-score { font-size: 48px; font-weight: bold; }
    .critical { color: #d32f2f; }
    .high { color: #f57c00; }
    .medium { color: #fbc02d; }
    .low { color: #388e3c; }
    .finding { border: 1px solid #ddd; padding: 15px; margin: 10px 0; border-radius: 5px; }
    .recommendation { background: #e3f2fd; padding: 15px; margin: 10px 0; border-radius: 5px; }
  </style>
</head>
<body>
  <div class="header">
    <h1>Security Scan Report</h1>
    <p><strong>Report ID:</strong> ${report.metadata.reportId}</p>
    <p><strong>Generated:</strong> ${report.metadata.generatedAt.toISOString()}</p>
  </div>
  
  <h2>Executive Summary</h2>
  <div class="risk-score ${getRiskClass(report.executive.riskScore)}">
    Risk Score: ${report.executive.riskScore}/100
  </div>
  
  <h2>Recommendations</h2>
  ${report.recommendations.map(r => `<div class="recommendation">${r}</div>`).join('')}
  
  <h2>Findings</h2>
  ${formatHTMLFindings(report.scanResults)}
</body>
</html>`;
}

async function formatPDF(report: SecurityReport, options: SecurityReportOptions): Promise<string> {
  // For PDF generation, we'd typically use a library like puppeteer or pdfkit
  // For now, return markdown that can be converted to PDF
  return formatMarkdown(report, options);
}

function formatFindingsBySeverity(scanResults: SecurityScanResult[]): string {
  const allFindings = scanResults.flatMap(r => r.findings);
  const severities = ['critical', 'high', 'medium', 'low', 'info'];
  let output = '';

  for (const severity of severities) {
    const findings = allFindings.filter(f => f.severity === severity);
    if (findings.length === 0) continue;

    output += `### ${severity.toUpperCase()} (${findings.length})\n\n`;
    
    for (const finding of findings.slice(0, 10)) { // Limit to 10 per severity
      output += formatFinding(finding);
    }
    
    if (findings.length > 10) {
      output += `\n_... and ${findings.length - 10} more ${severity} findings_\n\n`;
    }
  }

  return output;
}

function formatFindingsByType(scanResults: SecurityScanResult[]): string {
  const allFindings = scanResults.flatMap(r => r.findings);
  const types = [...new Set(allFindings.map(f => f.type))];
  let output = '';

  for (const type of types) {
    const findings = allFindings.filter(f => f.type === type);
    output += `### ${type} (${findings.length})\n\n`;
    
    for (const finding of findings.slice(0, 10)) {
      output += formatFinding(finding);
    }
  }

  return output;
}

function formatFinding(finding: SecurityFinding): string {
  let output = `#### ${finding.title}\n`;
  output += `- **Severity:** ${finding.severity}\n`;
  output += `- **Type:** ${finding.type}\n`;
  
  if (finding.location?.file) {
    output += `- **Location:** ${finding.location.file}`;
    if (finding.location.line) {
      output += `:${finding.location.line}`;
    }
    output += '\n';
  }
  
  output += `- **Description:** ${finding.description}\n`;
  
  if (finding.cve) {
    output += `- **CVE:** ${finding.cve}\n`;
  }
  
  if (finding.remediation) {
    output += `- **Remediation:** ${finding.remediation}\n`;
  }
  
  output += '\n';
  return output;
}

function formatPolicyResults(policyResults: PolicyEvaluationResult[]): string {
  let output = '';
  
  for (const result of policyResults) {
    output += `### ${result.policyId}\n`;
    output += `- **Status:** ${result.passed ? '✅ PASSED' : '❌ FAILED'}\n`;
    output += `- **Violations:** ${result.violations.length}\n`;
    output += `- **Exceptions:** ${result.exceptions.length}\n\n`;
    
    if (result.violations.length > 0) {
      output += '**Violations:**\n';
      for (const violation of result.violations.slice(0, 5)) {
        output += `- ${violation.message}\n`;
      }
      output += '\n';
    }
  }
  
  return output;
}

function formatHTMLFindings(scanResults: SecurityScanResult[]): string {
  const allFindings = scanResults.flatMap(r => r.findings);
  
  return allFindings.slice(0, 20).map(finding => `
    <div class="finding ${finding.severity}">
      <h3>${finding.title}</h3>
      <p><strong>Severity:</strong> ${finding.severity}</p>
      <p><strong>Type:</strong> ${finding.type}</p>
      ${finding.location?.file ? `<p><strong>Location:</strong> ${finding.location.file}:${finding.location.line || ''}</p>` : ''}
      <p>${finding.description}</p>
      ${finding.remediation ? `<p><strong>Fix:</strong> ${finding.remediation}</p>` : ''}
    </div>
  `).join('');
}

function getRiskLevel(score: number): string {
  if (score >= 80) return '🔴 CRITICAL';
  if (score >= 60) return '🟠 HIGH';
  if (score >= 40) return '🟡 MEDIUM';
  if (score >= 20) return '🟢 LOW';
  return '⚪ MINIMAL';
}

function getRiskClass(score: number): string {
  if (score >= 80) return 'critical';
  if (score >= 60) return 'high';
  if (score >= 40) return 'medium';
  return 'low';
}

function saveReport(content: string, path: string, format: string): void {
  const dir = join(path, '..');
  if (!existsSync(dir)) {
    mkdirSync(dir, { recursive: true });
  }
  
  const extension = format === 'html' ? '.html' : format === 'json' ? '.json' : '.md';
  const fullPath = path.endsWith(extension) ? path : `${path}${extension}`;
  
  writeFileSync(fullPath, content);
}