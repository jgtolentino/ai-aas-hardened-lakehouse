import type { SecurityScanResult, SecurityFinding } from '../scanners/types';
import type { PolicyEvaluationResult } from '../policies/policy-engine';

export interface DashboardData {
  summary: {
    lastScan: Date;
    totalScans: number;
    riskTrend: 'improving' | 'stable' | 'declining';
    overallRiskScore: number;
  };
  metrics: {
    findingsBySeverity: Record<string, number>;
    findingsByType: Record<string, number>;
    findingsByScanner: Record<string, number>;
    topVulnerableFiles: Array<{ file: string; count: number }>;
  };
  compliance: {
    policiesEvaluated: number;
    policiesPassed: number;
    complianceRate: number;
  };
  trends: Array<{
    date: Date;
    findings: number;
    riskScore: number;
  }>;
}

/**
 * Creates dashboard data from scan results
 */
export function createSecurityDashboard(
  scanResults: SecurityScanResult[],
  policyResults?: PolicyEvaluationResult[],
  historicalData?: SecurityScanResult[][]
): DashboardData {
  const allFindings = scanResults.flatMap(r => r.findings);
  
  return {
    summary: createSummary(scanResults, historicalData),
    metrics: createMetrics(allFindings, scanResults),
    compliance: createComplianceMetrics(policyResults),
    trends: createTrends(historicalData || [scanResults])
  };
}

function createSummary(
  scanResults: SecurityScanResult[],
  historicalData?: SecurityScanResult[][]
): DashboardData['summary'] {
  const riskScore = calculateOverallRiskScore(scanResults);
  let riskTrend: 'improving' | 'stable' | 'declining' = 'stable';
  
  if (historicalData && historicalData.length > 1) {
    const previousScore = calculateOverallRiskScore(
      historicalData[historicalData.length - 2]
    );
    
    if (riskScore < previousScore - 5) {
      riskTrend = 'improving';
    } else if (riskScore > previousScore + 5) {
      riskTrend = 'declining';
    }
  }

  return {
    lastScan: new Date(),
    totalScans: (historicalData?.length || 0) + 1,
    riskTrend,
    overallRiskScore: riskScore
  };
}

function createMetrics(
  findings: SecurityFinding[],
  scanResults: SecurityScanResult[]
): DashboardData['metrics'] {
  // Count by severity
  const findingsBySeverity: Record<string, number> = {
    critical: 0,
    high: 0,
    medium: 0,
    low: 0,
    info: 0
  };
  
  for (const finding of findings) {
    findingsBySeverity[finding.severity]++;
  }

  // Count by type
  const findingsByType: Record<string, number> = {};
  for (const finding of findings) {
    findingsByType[finding.type] = (findingsByType[finding.type] || 0) + 1;
  }

  // Count by scanner
  const findingsByScanner: Record<string, number> = {};
  for (const result of scanResults) {
    findingsByScanner[result.scanner] = result.findings.length;
  }

  // Top vulnerable files
  const fileCount: Record<string, number> = {};
  for (const finding of findings) {
    if (finding.location?.file) {
      fileCount[finding.location.file] = (fileCount[finding.location.file] || 0) + 1;
    }
  }
  
  const topVulnerableFiles = Object.entries(fileCount)
    .sort((a, b) => b[1] - a[1])
    .slice(0, 10)
    .map(([file, count]) => ({ file, count }));

  return {
    findingsBySeverity,
    findingsByType,
    findingsByScanner,
    topVulnerableFiles
  };
}

function createComplianceMetrics(
  policyResults?: PolicyEvaluationResult[]
): DashboardData['compliance'] {
  if (!policyResults || policyResults.length === 0) {
    return {
      policiesEvaluated: 0,
      policiesPassed: 0,
      complianceRate: 0
    };
  }

  const passed = policyResults.filter(r => r.passed).length;
  
  return {
    policiesEvaluated: policyResults.length,
    policiesPassed: passed,
    complianceRate: Math.round((passed / policyResults.length) * 100)
  };
}

function createTrends(
  historicalData: SecurityScanResult[][]
): DashboardData['trends'] {
  return historicalData.map((scanResults, index) => {
    const findings = scanResults.reduce((sum, r) => sum + r.findings.length, 0);
    const riskScore = calculateOverallRiskScore(scanResults);
    
    return {
      date: new Date(Date.now() - (historicalData.length - index - 1) * 86400000), // Daily
      findings,
      riskScore
    };
  });
}

function calculateOverallRiskScore(scanResults: SecurityScanResult[]): number {
  const allFindings = scanResults.flatMap(r => r.findings);
  
  const weights = {
    critical: 10,
    high: 5,
    medium: 2,
    low: 0.5,
    info: 0.1
  };

  let score = 0;
  
  for (const finding of allFindings) {
    score += weights[finding.severity] || 0;
  }

  return Math.min(100, Math.round(score));
}

/**
 * Generates ASCII dashboard for terminal display
 */
export function renderTerminalDashboard(data: DashboardData): string {
  let output = '\n';
  
  // Header
  output += '╔════════════════════════════════════════════════════════════════╗\n';
  output += '║                    SECURITY DASHBOARD                          ║\n';
  output += '╚════════════════════════════════════════════════════════════════╝\n\n';

  // Risk Score with visual indicator
  const riskBar = createRiskBar(data.summary.overallRiskScore);
  output += `Risk Score: ${data.summary.overallRiskScore}/100 ${riskBar}\n`;
  output += `Trend: ${getTrendIcon(data.summary.riskTrend)} ${data.summary.riskTrend}\n\n`;

  // Findings Summary
  output += '┌─ Findings by Severity ─────────────────┐\n';
  for (const [severity, count] of Object.entries(data.metrics.findingsBySeverity)) {
    const bar = createBar(count, 50);
    output += `│ ${severity.padEnd(8)} ${String(count).padStart(4)} ${bar} │\n`;
  }
  output += '└────────────────────────────────────────┘\n\n';

  // Compliance
  if (data.compliance.policiesEvaluated > 0) {
    output += '┌─ Policy Compliance ────────────────────┐\n';
    output += `│ Compliance Rate: ${data.compliance.complianceRate}%`.padEnd(41) + '│\n';
    output += `│ Policies Passed: ${data.compliance.policiesPassed}/${data.compliance.policiesEvaluated}`.padEnd(41) + '│\n';
    output += '└────────────────────────────────────────┘\n\n';
  }

  // Top Issues
  output += '┌─ Top Vulnerable Files ─────────────────┐\n';
  for (const file of data.metrics.topVulnerableFiles.slice(0, 5)) {
    const shortFile = file.file.length > 30 ? '...' + file.file.slice(-27) : file.file;
    output += `│ ${shortFile.padEnd(30)} ${String(file.count).padStart(6)} │\n`;
  }
  output += '└────────────────────────────────────────┘\n';

  return output;
}

function createRiskBar(score: number): string {
  const filled = Math.round(score / 5);
  const empty = 20 - filled;
  
  let color = '';
  if (score >= 80) color = '🔴';
  else if (score >= 60) color = '🟠';
  else if (score >= 40) color = '🟡';
  else color = '🟢';
  
  return color + ' [' + '█'.repeat(filled) + '░'.repeat(empty) + ']';
}

function createBar(value: number, maxValue: number): string {
  const percentage = Math.min(100, (value / maxValue) * 100);
  const filled = Math.round(percentage / 5);
  const empty = 20 - filled;
  
  return '▓'.repeat(filled) + '░'.repeat(empty);
}

function getTrendIcon(trend: string): string {
  switch (trend) {
    case 'improving': return '📈';
    case 'declining': return '📉';
    default: return '➡️';
  }
}

/**
 * Generates HTML dashboard
 */
export function renderHTMLDashboard(data: DashboardData): string {
  return `
<!DOCTYPE html>
<html>
<head>
  <title>Security Dashboard</title>
  <style>
    body { font-family: Arial, sans-serif; margin: 20px; background: #f5f5f5; }
    .container { max-width: 1200px; margin: 0 auto; }
    .card { background: white; border-radius: 8px; padding: 20px; margin: 10px 0; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
    .metric { display: inline-block; margin: 10px 20px; }
    .metric-value { font-size: 36px; font-weight: bold; }
    .metric-label { color: #666; }
    .risk-score { font-size: 48px; }
    .critical { color: #d32f2f; }
    .high { color: #f57c00; }
    .medium { color: #fbc02d; }
    .low { color: #388e3c; }
    .chart { height: 200px; margin: 20px 0; }
  </style>
</head>
<body>
  <div class="container">
    <h1>Security Dashboard</h1>
    
    <div class="card">
      <h2>Risk Overview</h2>
      <div class="risk-score ${getRiskColorClass(data.summary.overallRiskScore)}">
        ${data.summary.overallRiskScore}/100
      </div>
      <p>Trend: ${data.summary.riskTrend}</p>
    </div>
    
    <div class="card">
      <h2>Findings Summary</h2>
      ${Object.entries(data.metrics.findingsBySeverity).map(([sev, count]) => `
        <div class="metric">
          <div class="metric-value ${sev}">${count}</div>
          <div class="metric-label">${sev}</div>
        </div>
      `).join('')}
    </div>
    
    <div class="card">
      <h2>Compliance Status</h2>
      <div class="metric">
        <div class="metric-value">${data.compliance.complianceRate}%</div>
        <div class="metric-label">Compliance Rate</div>
      </div>
    </div>
  </div>
</body>
</html>
  `;
}

function getRiskColorClass(score: number): string {
  if (score >= 80) return 'critical';
  if (score >= 60) return 'high';
  if (score >= 40) return 'medium';
  return 'low';
}