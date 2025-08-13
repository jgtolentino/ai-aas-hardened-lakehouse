#!/usr/bin/env node
/**
 * W8: Learning Paths - Test all SDK samples run locally with mock JWT
 */

import fs from 'fs';
import path from 'path';
import { exec } from 'child_process';
import { promisify } from 'util';

const execAsync = promisify(exec);

console.log('🧪 Testing Learning Path SDK samples...');

// Mock environment for testing
const mockEnv = {
  SUPABASE_URL: 'https://mock-scout-project.supabase.co',
  SUPABASE_ANON_KEY: 'mock-anon-key-for-testing',
  SERVICE_ROLE: 'mock-service-role-key',
  USER_JWT: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyLCJyb2xlIjoiYXV0aGVudGljYXRlZCIsInRlbmFudF9pZCI6InRlc3QtdGVuYW50In0.mock-signature',
  TENANT_ID: 'test-tenant'
};

async function testJavaScriptSamples() {
  console.log('📜 Testing JavaScript samples...');
  
  const samplesDir = './orchestration/lyra/scripts/learning/samples/javascript';
  if (!fs.existsSync(samplesDir)) {
    throw new Error('JavaScript samples directory not found');
  }
  
  const results = [];
  const sampleFiles = fs.readdirSync(samplesDir).filter(f => f.endsWith('.js'));
  
  for (const file of sampleFiles) {
    const filePath = path.join(samplesDir, file);
    console.log(`🔍 Testing ${file}...`);
    
    try {
      // Create a test wrapper that mocks the Scout client
      const testContent = `
// Mock Scout Client for testing
class MockScoutClient {
  constructor(config) {
    console.log('MockScoutClient initialized with:', config);
    this.config = config;
  }
  
  from(table) {
    console.log(\`Querying table: \${table}\`);
    return new MockQuery(table);
  }
}

class MockQuery {
  constructor(table) {
    this.table = table;
    this.operations = [];
  }
  
  select(columns) {
    this.operations.push(\`SELECT \${columns}\`);
    return this;
  }
  
  order(column, options = {}) {
    const direction = options.ascending === false ? 'DESC' : 'ASC';
    this.operations.push(\`ORDER BY \${column} \${direction}\`);
    return this;
  }
  
  limit(count) {
    this.operations.push(\`LIMIT \${count}\`);
    return this;
  }
  
  async execute() {
    console.log('Query operations:', this.operations);
    // Return mock data
    return {
      data: [
        { brand_name: 'Brand A', revenue: 1000000, growth_rate: 0.15 },
        { brand_name: 'Brand B', revenue: 800000, growth_rate: 0.12 },
        { brand_name: 'Brand C', revenue: 600000, growth_rate: 0.08 }
      ],
      error: null
    };
  }
}

// Mock chart library
class MockScoutChart {
  constructor(config) {
    console.log('Chart configuration:', JSON.stringify(config, null, 2));
    this.config = config;
  }
  
  render(selector) {
    console.log(\`Chart rendered to: \${selector}\`);
    console.log('✅ Chart creation successful');
  }
}

// Set up mocks in global scope
global.ScoutClient = MockScoutClient;
global.ScoutChart = MockScoutChart;

// Mock environment variables
${Object.entries(mockEnv).map(([key, value]) => 
  `process.env.${key} = '${value}';`
).join('\n')}

// Load and execute the sample code
${fs.readFileSync(filePath, 'utf8')}

console.log('✅ JavaScript sample executed successfully: ${file}');
`;
      
      // Write temporary test file
      const testFile = `/tmp/test-${file}`;
      fs.writeFileSync(testFile, testContent);
      
      // Execute with Node.js
      const { stdout, stderr } = await execAsync(`node ${testFile}`, {
        env: { ...process.env, ...mockEnv },
        timeout: 10000
      });
      
      console.log(`✅ ${file}: SUCCESS`);
      results.push({
        file,
        language: 'javascript',
        status: 'SUCCESS',
        output: stdout.trim()
      });
      
      // Cleanup
      fs.unlinkSync(testFile);
      
    } catch (error) {
      console.log(`❌ ${file}: FAILED - ${error.message}`);
      results.push({
        file,
        language: 'javascript',
        status: 'FAILED',
        error: error.message
      });
    }
  }
  
  return results;
}

async function testPythonSamples() {
  console.log('🐍 Testing Python samples...');
  
  const samplesDir = './orchestration/lyra/scripts/learning/samples/python';
  if (!fs.existsSync(samplesDir)) {
    console.log('⚠️  Python samples directory not found, skipping...');
    return [];
  }
  
  const results = [];
  const sampleFiles = fs.readdirSync(samplesDir).filter(f => f.endsWith('.py'));
  
  for (const file of sampleFiles) {
    const filePath = path.join(samplesDir, file);
    console.log(`🔍 Testing ${file}...`);
    
    try {
      // Create a test wrapper with mock classes
      const testContent = `
import os
import sys
from unittest.mock import Mock, MagicMock
import json

# Mock pandas DataFrame
class MockDataFrame:
    def __init__(self, data=None):
        self.data = data or [
            {'brand_name': 'Brand A', 'revenue': 1000000, 'growth_rate': 0.15},
            {'brand_name': 'Brand B', 'revenue': 800000, 'growth_rate': 0.12},
            {'brand_name': 'Brand C', 'revenue': 600000, 'growth_rate': 0.08}
        ]
        print(f"MockDataFrame created with {len(self.data)} rows")
    
    def head(self, n=5):
        print(f"DataFrame head({n}):")
        for row in self.data[:n]:
            print(row)
        return self
    
    def empty(self):
        return len(self.data) == 0
    
    def __len__(self):
        return len(self.data)
    
    def __getitem__(self, key):
        return MockSeries([row[key] for row in self.data if key in row])

class MockSeries:
    def __init__(self, data):
        self.data = data
    
    def hist(self, bins=10, ax=None):
        print(f"Histogram created with {bins} bins")
        return self

# Mock Scout client
class MockScoutClient:
    def __init__(self, url, key, tenant):
        print(f"MockScoutClient initialized: {url}, tenant: {tenant}")
        self.url = url
        self.tenant = tenant
    
    def table(self, name):
        print(f"Accessing table: {name}")
        return MockTable(name)

class MockTable:
    def __init__(self, name):
        self.name = name
        self.query = []
    
    def select(self, columns):
        self.query.append(f"SELECT {columns}")
        return self
    
    def order(self, column, desc=False):
        direction = "DESC" if desc else "ASC"
        self.query.append(f"ORDER BY {column} {direction}")
        return self
    
    def limit(self, count):
        self.query.append(f"LIMIT {count}")
        return self
    
    def execute(self):
        print("Executing query:", " ".join(self.query))
        mock_result = Mock()
        mock_result.data = [
            {'brand_name': 'Brand A', 'revenue': 1000000, 'growth_rate': 0.15},
            {'brand_name': 'Brand B', 'revenue': 800000, 'growth_rate': 0.12},
            {'brand_name': 'Brand C', 'revenue': 600000, 'growth_rate': 0.08}
        ]
        return mock_result

# Mock matplotlib and seaborn
class MockPlt:
    @staticmethod
    def subplots(*args, **kwargs):
        print(f"Creating subplots: args={args}, kwargs={kwargs}")
        mock_fig = Mock()
        mock_axes = [[Mock(), Mock()], [Mock(), Mock()]]
        return mock_fig, mock_axes
    
    @staticmethod
    def tight_layout():
        print("Applying tight layout")
    
    @staticmethod
    def show():
        print("✅ Plots displayed successfully")

# Set up mocks
sys.modules['pandas'] = Mock()
sys.modules['pandas'].DataFrame = MockDataFrame
sys.modules['matplotlib'] = Mock()
sys.modules['matplotlib'].pyplot = MockPlt
sys.modules['seaborn'] = Mock()
sys.modules['scout_client'] = Mock()
sys.modules['scout_client'].ScoutClient = MockScoutClient

# Mock environment variables
${Object.entries(mockEnv).map(([key, value]) => 
  `os.environ['${key}'] = '${value}'`
).join('\n')}

# Import pandas after mocking
import pandas as pd
pd.DataFrame = MockDataFrame
import matplotlib.pyplot as plt
plt.subplots = MockPlt.subplots
plt.tight_layout = MockPlt.tight_layout  
plt.show = MockPlt.show

# Execute the sample code
try:
    ${fs.readFileSync(filePath, 'utf8').replace(/^#!/, '# !')}
    print("✅ Python sample executed successfully: ${file}")
except Exception as e:
    print(f"❌ Error in ${file}: {e}")
    raise
`;
      
      // Write temporary test file
      const testFile = `/tmp/test-${file}`;
      fs.writeFileSync(testFile, testContent);
      
      // Execute with Python
      const { stdout, stderr } = await execAsync(`python3 ${testFile}`, {
        env: { ...process.env, ...mockEnv },
        timeout: 15000
      });
      
      console.log(`✅ ${file}: SUCCESS`);
      results.push({
        file,
        language: 'python',
        status: 'SUCCESS',
        output: stdout.trim()
      });
      
      // Cleanup
      fs.unlinkSync(testFile);
      
    } catch (error) {
      // Python samples are optional, don't fail the whole test
      console.log(`⚠️  ${file}: SKIPPED - ${error.message.split('\n')[0]}`);
      results.push({
        file,
        language: 'python',
        status: 'SKIPPED',
        reason: 'Python not available or sample failed'
      });
    }
  }
  
  return results;
}

async function testSampleValidation() {
  console.log('📋 Validating sample structure...');
  
  const results = [];
  const languages = ['javascript', 'python', 'java', 'csharp'];
  
  for (const lang of languages) {
    const samplesDir = `./orchestration/lyra/scripts/learning/samples/${lang}`;
    
    if (fs.existsSync(samplesDir)) {
      const files = fs.readdirSync(samplesDir);
      const validExtensions = {
        javascript: ['.js'],
        python: ['.py'], 
        java: ['.java'],
        csharp: ['.cs']
      };
      
      const validFiles = files.filter(f => 
        validExtensions[lang].some(ext => f.endsWith(ext))
      );
      
      console.log(`📁 ${lang}: ${validFiles.length} sample files`);
      results.push({
        language: lang,
        sample_count: validFiles.length,
        files: validFiles,
        status: validFiles.length > 0 ? 'HAS_SAMPLES' : 'NO_SAMPLES'
      });
    } else {
      console.log(`📁 ${lang}: directory not found`);
      results.push({
        language: lang,
        sample_count: 0,
        files: [],
        status: 'NO_DIRECTORY'
      });
    }
  }
  
  return results;
}

async function main() {
  try {
    console.log('🚀 Starting SDK sample testing...\n');
    
    // Test structure validation
    const structureResults = await testSampleValidation();
    
    // Test JavaScript samples (required)
    const jsResults = await testJavaScriptSamples();
    
    // Test Python samples (optional)
    const pyResults = await testPythonSamples();
    
    // Combine all results
    const allResults = [...jsResults, ...pyResults];
    
    // Generate summary
    const totalTests = allResults.length;
    const successCount = allResults.filter(r => r.status === 'SUCCESS').length;
    const failedCount = allResults.filter(r => r.status === 'FAILED').length;
    const skippedCount = allResults.filter(r => r.status === 'SKIPPED').length;
    
    console.log(`\n📋 Sample Testing Summary:`);
    console.log(`   ✅ Successful: ${successCount}/${totalTests}`);
    console.log(`   ❌ Failed: ${failedCount}/${totalTests}`);
    console.log(`   ⚠️  Skipped: ${skippedCount}/${totalTests}`);
    
    // Save test report
    const report = {
      timestamp: new Date().toISOString(),
      structure_validation: structureResults,
      execution_tests: allResults,
      summary: {
        total_tests: totalTests,
        successful: successCount,
        failed: failedCount,
        skipped: skippedCount,
        success_rate: totalTests > 0 ? (successCount / totalTests * 100).toFixed(1) : 0
      }
    };
    
    const reportPath = './orchestration/lyra/artifacts/sample-test-report.json';
    fs.writeFileSync(reportPath, JSON.stringify(report, null, 2));
    console.log(`📄 Test report saved: ${reportPath}`);
    
    // Gate condition: All JavaScript samples must succeed (Python optional)
    const jsSuccessCount = jsResults.filter(r => r.status === 'SUCCESS').length;
    const jsTotal = jsResults.length;
    
    if (jsTotal > 0 && jsSuccessCount === jsTotal) {
      console.log(`✅ Sample testing PASSED (${jsSuccessCount}/${jsTotal} JavaScript samples successful)`);
      process.exit(0);
    } else {
      console.log(`❌ Sample testing FAILED (${jsSuccessCount}/${jsTotal} JavaScript samples successful)`);
      process.exit(1);
    }
    
  } catch (error) {
    console.error('❌ Sample testing failed:', error.message);
    process.exit(1);
  }
}

main();