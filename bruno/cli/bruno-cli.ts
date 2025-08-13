#!/usr/bin/env node

import { Command } from 'commander';
import { brunoExecutor } from '../executor/bruno-executor';
import { createJobFromTemplate, listTemplates } from '../templates/job-templates';
import type { BrunoJob } from '../executor/types';
import { readFileSync, existsSync } from 'fs';

const program = new Command();

program
  .name('bruno')
  .description('Bruno Secure Executor CLI')
  .version('1.0.0');

// Execute command
program
  .command('exec <type>')
  .description('Execute a job (shell, script, file, api, database)')
  .option('-c, --command <cmd>', 'Shell command to execute')
  .option('-s, --script <path>', 'Script file to execute')
  .option('-p, --payload <json>', 'Job payload (JSON string)')
  .option('--permissions <perms...>', 'Required permissions')
  .option('--timeout <ms>', 'Timeout in milliseconds')
  .option('--dry-run', 'Validate without executing')
  .action(async (type, options) => {
    try {
      const job: BrunoJob = {
        id: `cli-${Date.now()}`,
        type: type as BrunoJob['type'],
        permissions: options.permissions || []
      };

      // Set command or script
      if (options.command) {
        job.command = options.command;
      } else if (options.script) {
        if (!existsSync(options.script)) {
          console.error(`Script file not found: ${options.script}`);
          process.exit(1);
        }
        job.script = readFileSync(options.script, 'utf-8');
      }

      // Set payload
      if (options.payload) {
        try {
          job.payload = JSON.parse(options.payload);
        } catch (error) {
          console.error('Invalid JSON payload');
          process.exit(1);
        }
      }

      // Set timeout
      if (options.timeout) {
        job.timeout = parseInt(options.timeout);
      }

      if (options.dryRun) {
        console.log('Job validation:');
        console.log(JSON.stringify(job, null, 2));
        console.log('\n✓ Job is valid');
        return;
      }

      console.log(`Executing ${type} job...`);
      const result = await brunoExecutor.execute(job);
      
      if (result.status === 'success') {
        console.log('\n✓ Job completed successfully');
        if (result.stdout) {
          console.log('\nOutput:');
          console.log(result.stdout);
        }
        if (result.stderr) {
          console.log('\nErrors:');
          console.log(result.stderr);
        }
      } else {
        console.error(`\n✗ Job failed: ${result.error}`);
        if (result.securityEvents && result.securityEvents.length > 0) {
          console.error('\nSecurity events:');
          result.securityEvents.forEach(event => {
            console.error(`- [${event.severity}] ${event.details}`);
          });
        }
        process.exit(1);
      }
    } catch (error) {
      console.error('Execution failed:', error);
      process.exit(1);
    }
  });

// Template command
program
  .command('template <name>')
  .description('Execute a predefined job template')
  .option('-p, --payload <json>', 'Template payload (JSON string)')
  .option('--list', 'List available templates')
  .action(async (name, options) => {
    if (options.list || name === 'list') {
      console.log('Available templates:');
      listTemplates().forEach(template => {
        console.log(`- ${template}`);
      });
      return;
    }

    try {
      const overrides: Partial<BrunoJob> = {};
      
      if (options.payload) {
        overrides.payload = JSON.parse(options.payload);
      }

      const job = createJobFromTemplate(name, overrides);
      
      console.log(`Executing template: ${name}`);
      const result = await brunoExecutor.execute(job);
      
      if (result.status === 'success') {
        console.log('\n✓ Template executed successfully');
        if (result.stdout) {
          console.log(result.stdout);
        }
      } else {
        console.error(`\n✗ Template failed: ${result.error}`);
        process.exit(1);
      }
    } catch (error) {
      console.error('Template execution failed:', error);
      process.exit(1);
    }
  });

// Status command
program
  .command('status')
  .description('Show Bruno executor status')
  .action(() => {
    const activeJobs = brunoExecutor.getActiveJobs();
    const history = brunoExecutor.getJobHistory() as any[];
    
    console.log('Bruno Executor Status');
    console.log('====================');
    console.log(`Active Jobs: ${activeJobs.length}`);
    console.log(`Job History: ${history?.length || 0} jobs`);
    
    if (activeJobs.length > 0) {
      console.log('\nActive Jobs:');
      activeJobs.forEach(job => {
        console.log(`- ${job.jobId} (started: ${job.startTime})`);
      });
    }
    
    if (history && history.length > 0) {
      console.log('\nRecent Jobs:');
      history.slice(-5).forEach(job => {
        console.log(`- ${job.jobId}: ${job.status} (${job.duration}ms)`);
      });
    }
  });

// Security command
program
  .command('security')
  .description('Show security events and policies')
  .option('-l, --limit <n>', 'Number of events to show', '10')
  .action((options) => {
    const limit = parseInt(options.limit);
    const events = brunoExecutor.getSecurityEvents(limit);
    
    console.log('Security Events');
    console.log('===============');
    
    if (events.length === 0) {
      console.log('No security events recorded');
    } else {
      events.forEach(event => {
        console.log(`\n[${event.timestamp.toISOString()}] ${event.type}`);
        console.log(`Severity: ${event.severity}`);
        console.log(`Action: ${event.action}`);
        console.log(`Details: ${event.details}`);
      });
    }
  });

// Test command
program
  .command('test')
  .description('Run Bruno self-test')
  .action(async () => {
    console.log('Running Bruno self-test...\n');
    
    const tests = [
      {
        name: 'Basic echo command',
        job: {
          id: 'test-echo',
          type: 'shell' as const,
          command: 'echo "Bruno test"',
          permissions: ['process:execute']
        }
      },
      {
        name: 'File write test',
        job: {
          id: 'test-file',
          type: 'file' as const,
          permissions: ['file:write'],
          payload: {
            operation: 'write',
            path: 'test.txt',
            content: 'Bruno file test'
          }
        }
      },
      {
        name: 'Security policy test (should fail)',
        job: {
          id: 'test-security',
          type: 'shell' as const,
          command: 'rm -rf /',
          permissions: ['process:execute']
        }
      }
    ];
    
    for (const test of tests) {
      console.log(`Running: ${test.name}`);
      try {
        const result = await brunoExecutor.execute(test.job);
        if (test.name.includes('should fail') && result.status === 'failure') {
          console.log('✓ Failed as expected\n');
        } else if (result.status === 'success') {
          console.log('✓ Passed\n');
        } else {
          console.log(`✗ Failed: ${result.error}\n`);
        }
      } catch (error) {
        console.log(`✗ Error: ${error}\n`);
      }
    }
    
    console.log('Self-test complete');
  });

program.parse();