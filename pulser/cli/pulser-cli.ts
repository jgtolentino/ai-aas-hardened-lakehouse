#!/usr/bin/env node

import { Command } from 'commander';
import { pulser } from '../pulser';
import { agentRegistry } from '../registry/agent-registry';
import { agentLoader } from '../config/agent-loader';
import type { RoutingRequest } from '../routing/router';

const program = new Command();

program
  .name('pulser')
  .description('Pulser Agent Orchestration CLI')
  .version('1.0.0');

// Initialize command
program
  .command('init')
  .description('Initialize Pulser and load all agents')
  .action(async () => {
    try {
      console.log('Initializing Pulser...');
      await pulser.initialize();
      console.log('✓ Pulser initialized successfully');
    } catch (error) {
      console.error('✗ Failed to initialize:', error);
      process.exit(1);
    }
  });

// List agents
program
  .command('agents')
  .description('List all registered agents')
  .option('-t, --type <type>', 'Filter by agent type')
  .option('-s, --status <status>', 'Filter by status')
  .action(async (options) => {
    await pulser.initialize();
    
    const filter: any = {};
    if (options.type) filter.type = options.type;
    if (options.status) filter.status = options.status;
    
    const agents = agentRegistry.list(filter);
    
    if (agents.length === 0) {
      console.log('No agents found');
      return;
    }
    
    console.log('\nRegistered Agents:');
    console.log('==================');
    
    agents.forEach(agent => {
      console.log(`\n${agent.config.metadata.name} (${agent.config.metadata.id})`);
      console.log(`  Version: ${agent.config.metadata.version}`);
      console.log(`  Type: ${agent.config.type}`);
      console.log(`  Runtime: ${agent.config.runtime}`);
      console.log(`  Status: ${agent.config.metadata.status}`);
      console.log(`  State: ${agent.state}`);
      console.log(`  Capabilities: ${agent.config.capabilities.map(c => c.name).join(', ')}`);
      console.log(`  Success Rate: ${agent.metrics.successRate.toFixed(2)}%`);
    });
  });

// Execute task
program
  .command('execute <type>')
  .description('Execute a task through Pulser')
  .option('-p, --payload <json>', 'Task payload (JSON string)')
  .option('-c, --category <category>', 'Task category')
  .option('--priority <priority>', 'Priority level (low/medium/high/critical)')
  .option('--timeout <ms>', 'Timeout in milliseconds')
  .action(async (type, options) => {
    await pulser.initialize();
    
    try {
      const request: RoutingRequest = {
        type,
        category: options.category,
        payload: options.payload ? JSON.parse(options.payload) : {},
        context: {
          priority: options.priority,
          timeout: options.timeout ? parseInt(options.timeout) : undefined
        }
      };
      
      console.log(`\nExecuting ${type}...`);
      const result = await pulser.execute(request);
      
      console.log('\n✓ Execution completed:');
      console.log(JSON.stringify(result, null, 2));
    } catch (error) {
      console.error('\n✗ Execution failed:', error);
      process.exit(1);
    }
  });

// Reload agent
program
  .command('reload <agentId>')
  .description('Reload an agent configuration')
  .action(async (agentId) => {
    await pulser.initialize();
    
    try {
      await pulser.reloadAgent(agentId);
      console.log(`✓ Agent ${agentId} reloaded successfully`);
    } catch (error) {
      console.error(`✗ Failed to reload agent:`, error);
      process.exit(1);
    }
  });

// Health check
program
  .command('health [agentId]')
  .description('Check health of agents')
  .action(async (agentId) => {
    await pulser.initialize();
    
    if (agentId) {
      try {
        const healthy = await agentRegistry.healthCheck(agentId);
        const agent = agentRegistry.get(agentId);
        
        console.log(`\nAgent: ${agent?.config.metadata.name} (${agentId})`);
        console.log(`Status: ${healthy ? '✓ Healthy' : '✗ Unhealthy'}`);
        
        if (agent?.healthCheck) {
          console.log(`Last Check: ${agent.healthCheck.lastCheck}`);
          console.log(`Details: ${agent.healthCheck.details || 'N/A'}`);
        }
      } catch (error) {
        console.error(`✗ Health check failed:`, error);
        process.exit(1);
      }
    } else {
      // Check all agents
      const agents = agentRegistry.list();
      console.log('\nAgent Health Status:');
      console.log('===================');
      
      for (const agent of agents) {
        try {
          const healthy = await agentRegistry.healthCheck(agent.config.metadata.id);
          console.log(`${healthy ? '✓' : '✗'} ${agent.config.metadata.name} (${agent.config.metadata.id})`);
        } catch (error) {
          console.log(`✗ ${agent.config.metadata.name} (${agent.config.metadata.id}) - Error`);
        }
      }
    }
  });

// Metrics
program
  .command('metrics')
  .description('Display Pulser metrics')
  .action(async () => {
    await pulser.initialize();
    
    const metrics = pulser.getMetrics();
    
    console.log('\nPulser Metrics:');
    console.log('===============');
    console.log(`Total Jobs: ${metrics.totalJobs}`);
    console.log(`Active Jobs: ${metrics.activeJobs}`);
    console.log(`Queued Jobs: ${metrics.queuedJobs}`);
    
    console.log('\nAgent Metrics:');
    console.log('--------------');
    
    metrics.agents.forEach(agent => {
      console.log(`\n${agent.name} (${agent.id})`);
      console.log(`  State: ${agent.state}`);
      console.log(`  Total Executions: ${agent.metrics.totalExecutions}`);
      console.log(`  Success Rate: ${agent.metrics.successRate.toFixed(2)}%`);
      console.log(`  Avg Execution Time: ${agent.metrics.averageExecutionTime.toFixed(0)}ms`);
      console.log(`  Error Count: ${agent.metrics.errorCount}`);
    });
  });

// Jobs
program
  .command('jobs')
  .description('List jobs')
  .option('-s, --status <status>', 'Filter by status')
  .option('-l, --limit <n>', 'Limit results', '10')
  .action(async (options) => {
    await pulser.initialize();
    
    const filter: any = {};
    if (options.status) filter.status = options.status;
    
    const jobs = pulser.getJobs(filter);
    const limit = parseInt(options.limit);
    
    console.log(`\nJobs (showing ${Math.min(jobs.length, limit)} of ${jobs.length}):`);
    console.log('==================');
    
    jobs.slice(0, limit).forEach(job => {
      console.log(`\n${job.id}`);
      console.log(`  Type: ${job.request.type}`);
      console.log(`  Status: ${job.status}`);
      console.log(`  Agent: ${job.agentId || 'N/A'}`);
      console.log(`  Started: ${job.startTime}`);
      if (job.endTime) {
        console.log(`  Duration: ${job.endTime.getTime() - job.startTime.getTime()}ms`);
      }
      if (job.error) {
        console.log(`  Error: ${job.error}`);
      }
    });
  });

// Interactive mode
program
  .command('interactive')
  .description('Start interactive Pulser session')
  .action(async () => {
    await pulser.initialize();
    
    console.log('\nPulser Interactive Mode');
    console.log('Type "help" for commands, "exit" to quit\n');
    
    // This would integrate with a REPL interface
    console.log('Interactive mode not yet implemented');
  });

program.parse();