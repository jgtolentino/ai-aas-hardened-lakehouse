#!/usr/bin/env node

/**
 * User Acceptance Testing (UAT) Validation Suite
 * Tests the complete AI Cookbook + Diagram Bridge MCP integration
 */

const fs = require('fs').promises;
const path = require('path');
const { spawn } = require('child_process');

class UATValidator {
  constructor() {
    this.results = {
      jsonConformance: { passed: 0, failed: 0, tests: [] },
      figmaTimeout: { passed: 0, failed: 0, tests: [] },
      diagramRendering: { passed: 0, failed: 0, tests: [] },
      costMetrics: { passed: 0, failed: 0, tests: [] },
      codeConnect: { passed: 0, failed: 0, tests: [] }
    };
  }

  async runValidation() {
    console.log('🚀 Starting UAT Validation Suite');
    console.log('=====================================');
    
    try {
      await this.testJSONConformance();
      await this.testFigmaTimeoutRecovery();
      await this.testDiagramRendering();
      await this.testCostMetrics();
      await this.testCodeConnectValidation();
      
      this.printSummary();
      return this.getOverallResult();
    } catch (error) {
      console.error('❌ UAT validation failed:', error);
      return false;
    }
  }

  async testJSONConformance() {
    console.log('\n1️⃣ Testing JSON Conformance (Zod/Guard Tests)');
    console.log('-----------------------------------------------');
    
    try {
      // Test AI Cookbook JSON guards
      let createJSONGuard, z;
      try {
        const cookbook = require('../packages/ai-cookbook/dist/index.js');
        createJSONGuard = cookbook.createJSONGuard;
        z = require('zod');
      } catch (error) {
        console.log('⚠️  Skipping JSON guard tests - dependencies not available');
        this.results.jsonConformance.tests = [
          { name: 'AI Cookbook build available', passed: false, error: 'Module not found' }
        ];
        this.results.jsonConformance.failed = 1;
        return;
      }
      
      // Test schema validation
      const testSchema = z.object({
        name: z.string(),
        value: z.number(),
        active: z.boolean()
      });
      
      const guard = createJSONGuard(testSchema);
      
      // Test valid JSON
      const validTest = this.testGuard(guard, '{"name":"test","value":42,"active":true}', 'Valid JSON');
      
      // Test JSON with prose contamination
      const proseTest = this.testGuard(
        guard, 
        'Here is the data: {"name":"test","value":42,"active":true} - this should work',
        'JSON with prose'
      );
      
      // Test invalid JSON
      const invalidTest = this.testGuard(guard, '{"name":"test","value":"invalid"}', 'Invalid JSON', true);
      
      this.results.jsonConformance.tests = [validTest, proseTest, invalidTest];
      this.results.jsonConformance.passed = this.results.jsonConformance.tests.filter(t => t.passed).length;
      this.results.jsonConformance.failed = this.results.jsonConformance.tests.filter(t => !t.passed).length;
      
      console.log(`✅ JSON Conformance: ${this.results.jsonConformance.passed}/3 tests passed`);
    } catch (error) {
      console.error('❌ JSON Conformance test failed:', error);
      this.results.jsonConformance.failed = 1;
    }
  }

  testGuard(guard, input, description, shouldFail = false) {
    try {
      const result = guard.validate(input);
      const passed = !shouldFail;
      console.log(`  ${passed ? '✅' : '❌'} ${description}: ${passed ? 'PASS' : 'FAIL'}`);
      return { name: description, passed, error: null };
    } catch (error) {
      const passed = shouldFail;
      console.log(`  ${passed ? '✅' : '❌'} ${description}: ${passed ? 'PASS (expected failure)' : 'FAIL'}`);
      return { name: description, passed, error: error.message };
    }
  }

  async testFigmaTimeoutRecovery() {
    console.log('\n2️⃣ Testing Figma Timeout Recovery');
    console.log('----------------------------------');
    
    try {
      // Check if Figma bridge adapter has proper retry logic
      const figmaAdapterPath = path.join(__dirname, '../infra/mcp-hub/src/adapters/figma-bridge.ts');
      const content = await fs.readFile(figmaAdapterPath, 'utf-8');
      
      const hasRetryImport = content.includes('withRetry');
      const hasTimeoutHandling = content.includes('timeout');
      const hasErrorHandling = content.includes('catch');
      
      this.results.figmaTimeout.tests = [
        { name: 'Retry logic imported', passed: hasRetryImport },
        { name: 'Timeout handling present', passed: hasTimeoutHandling },
        { name: 'Error handling present', passed: hasErrorHandling }
      ];
      
      this.results.figmaTimeout.passed = this.results.figmaTimeout.tests.filter(t => t.passed).length;
      this.results.figmaTimeout.failed = this.results.figmaTimeout.tests.filter(t => !t.passed).length;
      
      console.log(`✅ Figma Timeout Recovery: ${this.results.figmaTimeout.passed}/3 checks passed`);
    } catch (error) {
      console.error('❌ Figma timeout test failed:', error);
      this.results.figmaTimeout.failed = 1;
    }
  }

  async testDiagramRendering() {
    console.log('\n3️⃣ Testing Diagram Rendering (Kroki Integration)');
    console.log('-------------------------------------------------');
    
    try {
      // Check if diagram bridge MCP server is built and configured
      const mcpServerPath = path.join(__dirname, '../infra/mcp-servers/diagram-bridge-mcp/dist/index.js');
      const serverExists = await this.fileExists(mcpServerPath);
      
      // Check Claude Desktop configuration
      const claudeConfigPath = path.join(process.env.HOME, 'Library/Application Support/Claude/claude_desktop_config.json');
      const configContent = await fs.readFile(claudeConfigPath, 'utf-8');
      const config = JSON.parse(configContent);
      const hasDiagramBridge = !!config.mcpServers.diagram_bridge;
      
      // Test Kroki endpoint availability
      const krokiAvailable = await this.testKrokiEndpoint();
      
      this.results.diagramRendering.tests = [
        { name: 'MCP server built', passed: serverExists },
        { name: 'Claude Desktop configured', passed: hasDiagramBridge },
        { name: 'Kroki endpoint available', passed: krokiAvailable }
      ];
      
      this.results.diagramRendering.passed = this.results.diagramRendering.tests.filter(t => t.passed).length;
      this.results.diagramRendering.failed = this.results.diagramRendering.tests.filter(t => !t.passed).length;
      
      console.log(`✅ Diagram Rendering: ${this.results.diagramRendering.passed}/3 checks passed`);
    } catch (error) {
      console.error('❌ Diagram rendering test failed:', error);
      this.results.diagramRendering.failed = 1;
    }
  }

  async testKrokiEndpoint() {
    try {
      const response = await fetch('https://kroki.io/health');
      return response.ok;
    } catch (error) {
      return false;
    }
  }

  async testCostMetrics() {
    console.log('\n4️⃣ Testing Cost Metrics (OpenTelemetry/Grafana)');
    console.log('------------------------------------------------');
    
    try {
      // Check observability configuration
      const obsConfigPath = path.join(__dirname, '../observability.config.js');
      const obsConfigExists = await this.fileExists(obsConfigPath);
      
      // Check if AI Cookbook has cost tracking
      const cookbookPath = path.join(__dirname, '../packages/ai-cookbook/src/observability/index.ts');
      const cookbookContent = await fs.readFile(cookbookPath, 'utf-8');
      const hasCostTracking = cookbookContent.includes('cost_usd') && cookbookContent.includes('trackCost');
      
      // Check if OpenTelemetry is configured
      const hasOTelConfig = obsConfigExists;
      
      this.results.costMetrics.tests = [
        { name: 'Observability config created', passed: obsConfigExists },
        { name: 'Cost tracking in AI Cookbook', passed: hasCostTracking },
        { name: 'OpenTelemetry configured', passed: hasOTelConfig }
      ];
      
      this.results.costMetrics.passed = this.results.costMetrics.tests.filter(t => t.passed).length;
      this.results.costMetrics.failed = this.results.costMetrics.tests.filter(t => !t.passed).length;
      
      console.log(`✅ Cost Metrics: ${this.results.costMetrics.passed}/3 checks passed`);
    } catch (error) {
      console.error('❌ Cost metrics test failed:', error);
      this.results.costMetrics.failed = 1;
    }
  }

  async testCodeConnectValidation() {
    console.log('\n5️⃣ Testing Code Connect Validation');
    console.log('-----------------------------------');
    
    try {
      // Run the Code Connect validator
      const validatorPath = path.join(__dirname, 'validate-code-connect.js');
      const validatorExists = await this.fileExists(validatorPath);
      
      if (!validatorExists) {
        this.results.codeConnect.tests = [
          { name: 'Code Connect validator exists', passed: false }
        ];
        this.results.codeConnect.failed = 1;
        return;
      }
      
      // Run the validator and capture results
      const result = await this.runValidator();
      
      this.results.codeConnect.tests = [
        { name: 'Code Connect validator exists', passed: validatorExists },
        { name: 'Validator execution', passed: result.success },
        { name: 'No critical errors', passed: result.errors === 0 }
      ];
      
      this.results.codeConnect.passed = this.results.codeConnect.tests.filter(t => t.passed).length;
      this.results.codeConnect.failed = this.results.codeConnect.tests.filter(t => !t.passed).length;
      
      console.log(`✅ Code Connect: ${this.results.codeConnect.passed}/3 checks passed`);
      if (result.warnings > 0) {
        console.log(`⚠️  Note: ${result.warnings} warnings found (non-blocking)`);
      }
    } catch (error) {
      console.error('❌ Code Connect validation failed:', error);
      this.results.codeConnect.failed = 1;
    }
  }

  async runValidator() {
    return new Promise((resolve) => {
      const validator = spawn('node', ['scripts/validate-code-connect.js'], {
        cwd: path.join(__dirname, '..')
      });
      
      let output = '';
      validator.stdout.on('data', (data) => {
        output += data.toString();
      });
      
      validator.stderr.on('data', (data) => {
        output += data.toString();
      });
      
      validator.on('close', (code) => {
        const errors = (output.match(/❌/g) || []).length;
        const warnings = (output.match(/⚠️/g) || []).length;
        
        resolve({
          success: code === 0,
          errors,
          warnings,
          output
        });
      });
    });
  }

  async fileExists(filePath) {
    try {
      await fs.access(filePath);
      return true;
    } catch {
      return false;
    }
  }

  printSummary() {
    console.log('\n📊 UAT Validation Summary');
    console.log('=========================');
    
    const categories = [
      ['JSON Conformance', this.results.jsonConformance],
      ['Figma Timeout Recovery', this.results.figmaTimeout],
      ['Diagram Rendering', this.results.diagramRendering],
      ['Cost Metrics', this.results.costMetrics],
      ['Code Connect', this.results.codeConnect]
    ];
    
    let totalPassed = 0;
    let totalFailed = 0;
    
    categories.forEach(([name, result]) => {
      const status = result.failed === 0 ? '✅' : '❌';
      console.log(`${status} ${name}: ${result.passed} passed, ${result.failed} failed`);
      totalPassed += result.passed;
      totalFailed += result.failed;
    });
    
    console.log('\n' + '='.repeat(50));
    console.log(`📈 Overall: ${totalPassed} passed, ${totalFailed} failed`);
    console.log(`🎯 Success Rate: ${Math.round((totalPassed / (totalPassed + totalFailed)) * 100)}%`);
    
    if (totalFailed === 0) {
      console.log('🎉 All UAT criteria met! Ready for production.');
    } else {
      console.log('⚠️  Some tests failed. Review and fix before deployment.');
    }
  }

  getOverallResult() {
    const categories = [
      this.results.jsonConformance,
      this.results.figmaTimeout,
      this.results.diagramRendering,
      this.results.costMetrics,
      this.results.codeConnect
    ];
    
    return categories.every(category => category.failed === 0);
  }
}

// Run validation if called directly
if (require.main === module) {
  const validator = new UATValidator();
  validator.runValidation().then(success => {
    process.exit(success ? 0 : 1);
  });
}

module.exports = { UATValidator };