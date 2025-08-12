#!/usr/bin/env node
/**
 * Report generation - Merge all gate results into final report
 */

import fs from 'fs';
import path from 'path';

console.log('📊 Merging gate results into final report...');

async function mergeGateResults() {
  const artifactsDir = './orchestration/lyra/artifacts';
  
  if (!fs.existsSync(artifactsDir)) {
    fs.mkdirSync(artifactsDir, { recursive: true });
  }
  
  // Gate result files to check
  const gateFiles = {
    design_system: 'design-system-report.json',
    docs_rag: 'docs-rag-report.json', 
    ask_scout_cache: 'ask-scout-cache-report.json',
    playground: 'playground-report.json',
    schema_explorer: 'schema-validation-report.json',
    api_explorer: 'rpc-test-report.json',
    live_metrics: 'kpi-validation-report.json',
    learning_paths: 'sample-test-report.json',
    cdn_caching: 'cdn-performance-report.json'
  };
  
  const gateResults = {};
  const reports = [];
  
  // Process each gate
  for (const [gateName, fileName] of Object.entries(gateFiles)) {
    const filePath = path.join(artifactsDir, fileName);
    
    if (fs.existsSync(filePath)) {
      try {
        const reportData = JSON.parse(fs.readFileSync(filePath, 'utf8'));
        
        // Determine gate status from report
        let status = 'fail';
        if (reportData.summary) {
          if (reportData.summary.pass_rate >= 80 || reportData.summary.success_rate >= 80) {
            status = 'pass';
          } else if (reportData.summary.passed === reportData.summary.total_tests) {
            status = 'pass';
          }
        } else if (reportData.success === true) {
          status = 'pass';
        }
        
        gateResults[gateName] = status;
        reports.push({
          gate: gateName,
          status,
          report_file: fileName,
          summary: reportData.summary || { message: 'Report available' }
        });
        
        console.log(`✅ ${gateName}: ${status.toUpperCase()}`);
        
      } catch (error) {
        console.log(`❌ ${gateName}: ERROR reading report - ${error.message}`);
        gateResults[gateName] = 'fail';
        reports.push({
          gate: gateName,
          status: 'fail',
          error: error.message
        });
      }
    } else {
      console.log(`⚠️  ${gateName}: No report found (${fileName})`);
      gateResults[gateName] = 'fail';
      reports.push({
        gate: gateName,
        status: 'fail',
        error: 'Report file not found'
      });
    }
  }
  
  // Calculate overall status
  const totalGates = Object.keys(gateResults).length;
  const passedGates = Object.values(gateResults).filter(status => status === 'pass').length;
  const passRate = totalGates > 0 ? (passedGates / totalGates * 100) : 0;
  
  const overallStatus = passRate >= 80 ? 'PASS' : 'FAIL';
  
  // Generate final report
  const finalReport = {
    timestamp: new Date().toISOString(),
    overall_status: overallStatus,
    summary: {
      total_gates: totalGates,
      passed_gates: passedGates,
      failed_gates: totalGates - passedGates,
      pass_rate: parseFloat(passRate.toFixed(1))
    },
    gate_results: gateResults,
    detailed_reports: reports,
    recommendations: generateRecommendations(gateResults),
    next_steps: generateNextSteps(overallStatus, gateResults)
  };
  
  // Generate markdown report
  const markdownReport = generateMarkdownReport(finalReport);
  
  // Save reports
  fs.writeFileSync(path.join(artifactsDir, 'gates.json'), JSON.stringify(gateResults, null, 2));
  fs.writeFileSync(path.join(artifactsDir, 'final-report.json'), JSON.stringify(finalReport, null, 2));
  
  console.log(`\n📋 Final Report Summary:`);
  console.log(`   Overall Status: ${overallStatus}`);
  console.log(`   Gates Passed: ${passedGates}/${totalGates} (${passRate.toFixed(1)}%)`);
  console.log(`   Report saved: artifacts/report.md`);
  
  return markdownReport;
}

function generateRecommendations(gateResults) {
  const recommendations = [];
  
  Object.entries(gateResults).forEach(([gate, status]) => {
    if (status === 'fail') {
      switch (gate) {
        case 'design_system':
          recommendations.push('Review Azure Design System integration and ensure all components are properly themed');
          break;
        case 'docs_rag':
          recommendations.push('Check RAG document chunking and embedding process, verify OpenAI API connectivity');
          break;
        case 'ask_scout_cache':
          recommendations.push('Debug Ask Scout caching mechanism and validate cache hit rates');
          break;
        case 'playground':
          recommendations.push('Fix SQL Playground security restrictions and saved query functionality');
          break;
        case 'schema_explorer':
          recommendations.push('Validate schema introspection queries and ensure proper RLS visibility');
          break;
        case 'api_explorer':
          recommendations.push('Check API endpoint accessibility and PostgREST configuration');
          break;
        case 'live_metrics':
          recommendations.push('Verify gold view data quality and choropleth map rendering');
          break;
        case 'learning_paths':
          recommendations.push('Test SDK samples locally and ensure all code examples are runnable');
          break;
        case 'cdn_caching':
          recommendations.push('Optimize Vercel configuration and validate Core Web Vitals performance');
          break;
      }
    }
  });
  
  return recommendations;
}

function generateNextSteps(overallStatus, gateResults) {
  if (overallStatus === 'PASS') {
    return [
      'All gates passed - ready for production deployment',
      'Run final smoke tests on staging environment',
      'Schedule production release window',
      'Prepare rollback plan and monitoring alerts'
    ];
  } else {
    const failedGates = Object.entries(gateResults)
      .filter(([_, status]) => status === 'fail')
      .map(([gate, _]) => gate);
    
    return [
      `Fix failing gates: ${failedGates.join(', ')}`,
      'Re-run Lyra orchestration after fixes',
      'Validate all gate conditions are met',
      'Consider partial deployment if critical gates pass'
    ];
  }
}

function generateMarkdownReport(finalReport) {
  const { overall_status, summary, gate_results, detailed_reports, recommendations, next_steps } = finalReport;
  
  const statusEmoji = overall_status === 'PASS' ? '✅' : '❌';
  
  return `# Scout v5 Parallel Improvements - Final Report

${statusEmoji} **Overall Status: ${overall_status}**

Generated: ${new Date(finalReport.timestamp).toLocaleString()}

## Summary

- **Total Gates**: ${summary.total_gates}
- **Passed**: ${summary.passed_gates}
- **Failed**: ${summary.failed_gates}  
- **Pass Rate**: ${summary.pass_rate}%

## Gate Results

| Gate | Status | Description |
|------|--------|-------------|
${Object.entries(gate_results).map(([gate, status]) => {
  const emoji = status === 'pass' ? '✅' : '❌';
  const description = getGateDescription(gate);
  return `| ${gate.replace(/_/g, ' ').replace(/\b\w/g, l => l.toUpperCase())} | ${emoji} ${status.toUpperCase()} | ${description} |`;
}).join('\n')}

## Detailed Results

${detailed_reports.map(report => {
  const emoji = report.status === 'pass' ? '✅' : '❌';
  return `### ${emoji} ${report.gate.replace(/_/g, ' ').replace(/\b\w/g, l => l.toUpperCase())}

**Status**: ${report.status.toUpperCase()}
${report.error ? `**Error**: ${report.error}` : ''}
${report.summary?.message ? `**Summary**: ${report.summary.message}` : ''}
${report.report_file ? `**Report File**: \`${report.report_file}\`` : ''}
`;
}).join('\n')}

${recommendations.length > 0 ? `## Recommendations

${recommendations.map(rec => `- ${rec}`).join('\n')}
` : ''}

## Next Steps

${next_steps.map(step => `- ${step}`).join('\n')}

## Artifacts

- \`gates.json\` - Gate results in JSON format
- \`final-report.json\` - Complete report data
- Individual gate reports in \`artifacts/\` directory

---

Generated by Lyra Orchestration System
`;
}

function getGateDescription(gate) {
  const descriptions = {
    design_system: 'Azure Design System integration and theming',
    docs_rag: 'Documentation RAG hydration and search',
    ask_scout_cache: 'Ask Scout caching and response optimization', 
    playground: 'SQL Playground v1.1 with saved queries',
    schema_explorer: 'Database schema visualization and exploration',
    api_explorer: 'API endpoint catalog and testing',
    live_metrics: 'Live KPI metrics and choropleth visualization',
    learning_paths: 'Multi-language SDK samples and tutorials',
    cdn_caching: 'CDN configuration and performance optimization'
  };
  
  return descriptions[gate] || 'No description available';
}

// Main execution
mergeGateResults()
  .then(markdownReport => {
    console.log(markdownReport);
  })
  .catch(error => {
    console.error('❌ Report generation failed:', error.message);
    process.exit(1);
  });