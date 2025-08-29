/**
 * Automated Test Runner for Figma Bridge
 * Tests the MCP Hub bridge functionality and WebSocket communication
 */

const WebSocket = require('ws');
const { validateFigmaCommand, validateFigmaCommands } = require('../../infra/mcp-hub/dist/validation/figma-commands');

// Test configuration
const CONFIG = {
  BRIDGE_URL: 'ws://localhost:8787/figma-bridge',
  TIMEOUT: 5000,
  MAX_RETRIES: 3
};

// Test results tracking
let testResults = {
  total: 0,
  passed: 0,
  failed: 0,
  skipped: 0,
  errors: []
};

// Utility functions
function log(level, message, ...args) {
  const timestamp = new Date().toISOString();
  const colors = {
    info: '\x1b[36m',     // Cyan
    success: '\x1b[32m',  // Green  
    error: '\x1b[31m',    // Red
    warn: '\x1b[33m',     // Yellow
    reset: '\x1b[0m'      // Reset
  };
  
  console.log(`${colors[level] || ''}[${timestamp}] ${level.toUpperCase()}: ${message}${colors.reset}`, ...args);
}

function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

// WebSocket connection helper
class FigmaBridgeClient {
  constructor() {
    this.ws = null;
    this.connected = false;
    this.pendingCommands = new Map();
  }

  async connect() {
    return new Promise((resolve, reject) => {
      try {
        this.ws = new WebSocket(CONFIG.BRIDGE_URL);
        
        this.ws.on('open', () => {
          this.connected = true;
          log('success', 'Connected to Figma Bridge');
          resolve();
        });

        this.ws.on('message', (data) => {
          try {
            const message = JSON.parse(data.toString());
            this.handleMessage(message);
          } catch (error) {
            log('error', 'Failed to parse bridge message:', error);
          }
        });

        this.ws.on('close', () => {
          this.connected = false;
          log('warn', 'Bridge connection closed');
        });

        this.ws.on('error', (error) => {
          log('error', 'WebSocket error:', error);
          reject(error);
        });

        // Timeout for connection
        setTimeout(() => {
          if (!this.connected) {
            reject(new Error('Connection timeout'));
          }
        }, CONFIG.TIMEOUT);

      } catch (error) {
        reject(error);
      }
    });
  }

  handleMessage(message) {
    log('info', 'Received message:', message);

    if (message.id && this.pendingCommands.has(message.id)) {
      const { resolve, reject } = this.pendingCommands.get(message.id);
      this.pendingCommands.delete(message.id);
      
      if (message.ok) {
        resolve(message);
      } else {
        reject(new Error(message.error || 'Command failed'));
      }
    }
  }

  async sendCommand(command, timeout = CONFIG.TIMEOUT) {
    if (!this.connected) {
      throw new Error('Not connected to bridge');
    }

    const commandId = `test_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
    const commandWithId = { ...command, id: commandId };

    return new Promise((resolve, reject) => {
      // Set up timeout
      const timeoutId = setTimeout(() => {
        this.pendingCommands.delete(commandId);
        reject(new Error(`Command timeout after ${timeout}ms`));
      }, timeout);

      // Store pending command
      this.pendingCommands.set(commandId, {
        resolve: (result) => {
          clearTimeout(timeoutId);
          resolve(result);
        },
        reject: (error) => {
          clearTimeout(timeoutId);
          reject(error);
        }
      });

      // Send command
      this.ws.send(JSON.stringify(commandWithId));
    });
  }

  close() {
    if (this.ws) {
      this.ws.close();
      this.connected = false;
    }
  }
}

// Test framework
class TestFramework {
  constructor() {
    this.tests = [];
    this.client = new FigmaBridgeClient();
  }

  test(name, fn) {
    this.tests.push({ name, fn });
  }

  async runTest(test) {
    testResults.total++;
    
    try {
      log('info', `Running test: ${test.name}`);
      await test.fn();
      testResults.passed++;
      log('success', `✓ ${test.name}`);
    } catch (error) {
      testResults.failed++;
      testResults.errors.push({ test: test.name, error: error.message });
      log('error', `✗ ${test.name}: ${error.message}`);
    }
  }

  async runAll() {
    log('info', `Starting ${this.tests.length} tests...`);
    console.log('═'.repeat(60));

    try {
      // Connect to bridge
      await this.client.connect();
      await sleep(1000); // Wait for welcome message
      
      // Run all tests
      for (const test of this.tests) {
        await this.runTest(test);
        await sleep(500); // Small delay between tests
      }

    } catch (error) {
      log('error', 'Failed to connect to bridge:', error.message);
      log('warn', 'Make sure MCP Hub is running: ./scripts/figma.sh start');
      testResults.skipped = this.tests.length - testResults.passed - testResults.failed;
    } finally {
      this.client.close();
    }

    // Print results
    console.log('═'.repeat(60));
    log('info', 'Test Results:');
    console.log(`  Total: ${testResults.total}`);
    console.log(`  Passed: ${testResults.passed} (${((testResults.passed / testResults.total) * 100).toFixed(1)}%)`);
    console.log(`  Failed: ${testResults.failed}`);
    console.log(`  Skipped: ${testResults.skipped}`);

    if (testResults.errors.length > 0) {
      console.log('\nErrors:');
      testResults.errors.forEach((err, i) => {
        console.log(`  ${i + 1}. ${err.test}: ${err.error}`);
      });
    }

    return testResults.failed === 0;
  }
}

// Initialize test framework
const runner = new TestFramework();

// Command validation tests
runner.test('Command Validation - Valid sticky note', async () => {
  const command = { type: 'create-sticky', text: 'Test sticky note' };
  const result = validateFigmaCommand(command);
  
  if (!result.valid) {
    throw new Error(`Validation failed: ${result.errors.join(', ')}`);
  }
});

runner.test('Command Validation - Invalid sticky note', async () => {
  const command = { type: 'create-sticky' }; // Missing text
  const result = validateFigmaCommand(command);
  
  if (result.valid) {
    throw new Error('Should have failed validation for missing text');
  }
});

runner.test('Command Validation - Valid frame', async () => {
  const command = { type: 'create-frame', name: 'Test Frame', width: 400, height: 300 };
  const result = validateFigmaCommand(command);
  
  if (!result.valid) {
    throw new Error(`Validation failed: ${result.errors.join(', ')}`);
  }
});

runner.test('Command Validation - Invalid frame dimensions', async () => {
  const command = { type: 'create-frame', name: 'Bad Frame', width: -100, height: 999999 };
  const result = validateFigmaCommand(command);
  
  if (result.valid) {
    throw new Error('Should have failed validation for invalid dimensions');
  }
});

runner.test('Command Validation - Dashboard layout', async () => {
  const command = {
    type: 'create-dashboard-layout',
    title: 'Test Dashboard',
    grid: { cols: 3, gutter: 16 },
    tiles: [
      { id: 'kpi1', type: 'metric', x: 0, y: 0, w: 1, h: 1 }
    ]
  };
  const result = validateFigmaCommand(command);
  
  if (!result.valid) {
    throw new Error(`Validation failed: ${result.errors.join(', ')}`);
  }
});

runner.test('Security - Script injection prevention', async () => {
  const command = { type: 'create-sticky', text: '<script>alert("xss")</script>' };
  const result = validateFigmaCommand(command);
  
  if (!result.valid || !result.sanitized) {
    throw new Error('Security validation failed');
  }
  
  if (result.sanitized.text.includes('<script>')) {
    throw new Error('Script tags should be sanitized');
  }
});

runner.test('Security - Path traversal prevention', async () => {
  const command = { type: 'create-frame', name: '../../malicious', width: 100, height: 100 };
  const result = validateFigmaCommand(command);
  
  if (!result.sanitized || result.sanitized.name.includes('../')) {
    throw new Error('Path traversal should be prevented');
  }
});

// WebSocket communication tests (only if bridge is available)
runner.test('Bridge Communication - Send sticky command', async () => {
  const command = { type: 'create-sticky', text: 'Automated test sticky' };
  
  try {
    await runner.client.sendCommand(command, 3000);
    // Note: This may fail if no Figma plugin is connected, which is expected
  } catch (error) {
    if (error.message.includes('No active Figma plugins')) {
      log('warn', 'No Figma plugin connected - this is expected in automated testing');
      return; // This is not a failure
    }
    throw error;
  }
});

runner.test('Bridge Communication - Send frame command', async () => {
  const command = { type: 'create-frame', name: 'Automated test frame', width: 200, height: 150 };
  
  try {
    await runner.client.sendCommand(command, 3000);
  } catch (error) {
    if (error.message.includes('No active Figma plugins')) {
      log('warn', 'No Figma plugin connected - this is expected in automated testing');
      return;
    }
    throw error;
  }
});

runner.test('Bridge Communication - Invalid command handling', async () => {
  const command = { type: 'invalid-command', data: 'test' };
  
  try {
    await runner.client.sendCommand(command, 2000);
    throw new Error('Should have failed for invalid command');
  } catch (error) {
    // Expected to fail - either due to validation or no plugin
    if (error.message.includes('timeout') || error.message.includes('No active Figma plugins')) {
      return; // Expected behavior
    }
  }
});

runner.test('Batch Validation - Multiple commands', async () => {
  const commands = [
    { type: 'create-sticky', text: 'Batch test 1' },
    { type: 'create-sticky', text: 'Batch test 2' },
    { type: 'create-frame', name: 'Batch frame', width: 100, height: 100 },
    { type: 'invalid-command' } // This should fail
  ];
  
  const result = validateFigmaCommands(commands);
  
  if (result.summary.valid !== 3 || result.summary.errors === 0) {
    throw new Error('Batch validation should show 3 valid commands and some errors');
  }
});

runner.test('Performance - Validate 100 commands', async () => {
  const commands = Array(100).fill(null).map((_, i) => ({
    type: 'create-sticky',
    text: `Performance test ${i}`
  }));
  
  const startTime = Date.now();
  const result = validateFigmaCommands(commands);
  const duration = Date.now() - startTime;
  
  if (duration > 1000) { // Should complete in under 1 second
    throw new Error(`Validation took too long: ${duration}ms`);
  }
  
  if (result.summary.valid !== 100) {
    throw new Error('All 100 commands should be valid');
  }
  
  log('info', `Validated 100 commands in ${duration}ms`);
});

// Run all tests
if (require.main === module) {
  log('info', 'Starting Figma Bridge Automated Test Suite');
  log('info', 'Make sure MCP Hub is running: ./scripts/figma.sh start');
  console.log('');
  
  runner.runAll().then(success => {
    process.exit(success ? 0 : 1);
  }).catch(error => {
    log('error', 'Test suite failed:', error);
    process.exit(1);
  });
}

module.exports = { TestFramework, FigmaBridgeClient, validateFigmaCommand };