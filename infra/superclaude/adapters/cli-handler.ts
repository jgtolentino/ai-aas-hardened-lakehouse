#!/usr/bin/env tsx

import { handleSCCommand } from './sc_to_pulser';
import type { SuperClaudeEvent } from './types';

/**
 * CLI handler for SuperClaude commands in Claude Code
 * Usage: /sc <persona> <task> [payload]
 */
async function main() {
  const args = process.argv.slice(2);
  
  if (args.length < 2) {
    console.error('Usage: /sc <persona> <task> [payload]');
    console.error('\nAvailable personas:');
    console.error('  - System Architect');
    console.error('  - Frontend Developer');
    console.error('  - Security Engineer');
    console.error('  - Scribe');
    console.error('  - Data Engineer');
    console.error('  - DevOps Engineer');
    process.exit(1);
  }

  const [persona, ...taskParts] = args;
  const taskAndPayload = taskParts.join(' ');
  
  // Simple parsing: everything after task is considered payload
  const taskMatch = taskAndPayload.match(/^(\w+(?:\s+\w+)*)\s*(.*)?$/);
  const task = taskMatch?.[1] || taskAndPayload;
  const payloadStr = taskMatch?.[2] || '{}';
  
  let payload: any;
  try {
    // Try to parse as JSON first
    payload = JSON.parse(payloadStr);
  } catch {
    // If not JSON, treat as simple object with 'input' field
    payload = { input: payloadStr };
  }

  const event: SuperClaudeEvent = {
    persona,
    task,
    payload,
    context: {
      workspace: process.cwd(),
      projectRef: process.env.SUPABASE_PROJECT_REF
    }
  };

  try {
    console.log(`[SuperClaude] Processing: ${persona} - ${task}`);
    const result = await handleSCCommand(event);
    
    console.log('[SuperClaude] Intent generated:');
    console.log(JSON.stringify(result, null, 2));
    
    // In real integration, this would be passed to Bruno
    if (result.kind === 'execute_via_bruno') {
      console.log(`\n[Next Step] Execute via Bruno: ${result.job}`);
      console.log('[Bruno Command] bruno run', result.job, ...Object.entries(result.args).flatMap(([k, v]) => [`--${k}`, String(v)]));
    } else if (result.kind === 'route_to_agent') {
      console.log(`\n[Next Step] Route to agent: ${result.agent}`);
    }
    
    process.exit(0);
  } catch (error) {
    console.error('[SuperClaude] Error:', error instanceof Error ? error.message : error);
    process.exit(1);
  }
}

// Run if called directly
if (require.main === module) {
  main().catch(console.error);
}

export { main as superClaudeHandler };