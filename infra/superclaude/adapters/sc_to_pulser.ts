import { enforceBrunoOnly, validateExecIntent } from "../guards/exec_guard";
import type { ExecIntent, SuperClaudeEvent } from "./types";

export async function handleSCCommand(evt: SuperClaudeEvent): Promise<ExecIntent> {
  // Validate input
  if (!evt.persona || !evt.task) {
    throw new Error("Invalid SuperClaude event: missing persona or task");
  }

  let intent: ExecIntent;

  switch (evt.persona) {
    case "System Architect":
      intent = {
        kind: "execute_via_bruno",
        job: "pulser:generate_prd",
        args: { 
          spec: evt.payload, 
          out: `PRD-${evt.context?.feature || 'unnamed'}.md`,
          template: "enterprise"
        }
      };
      break;

    case "Frontend Developer":
      intent = {
        kind: "execute_via_bruno",
        job: "dash:codegen_tsx",
        args: { 
          module: evt.payload.module, 
          into: evt.context?.workspace || "apps/scout-dashboard",
          components: evt.payload.components || []
        }
      };
      break;

    case "Security Engineer":
      intent = {
        kind: "execute_via_bruno",
        job: "sec:scan_repo",
        args: { 
          repo: ".", 
          tools: ["semgrep", "trivy", "gosec"], 
          output: "security/report.sarif",
          severity: "CRITICAL,HIGH,MEDIUM"
        }
      };
      break;

    case "Scribe":
      intent = { 
        kind: "route_to_agent", 
        agent: "maya", 
        args: { 
          doc: evt.payload,
          format: "mdx",
          target: "docs-site/docs"
        }
      };
      break;

    case "Data Engineer":
      intent = {
        kind: "execute_via_bruno",
        job: "pulser:data_pipeline",
        args: {
          schema: evt.payload.schema,
          transformations: evt.payload.transformations,
          output: evt.payload.output || "scout"
        }
      };
      break;

    case "DevOps Engineer":
      intent = {
        kind: "execute_via_bruno",
        job: "infra:deploy",
        args: {
          environment: evt.payload.environment || "staging",
          services: evt.payload.services,
          dryRun: true // Always dry-run first
        }
      };
      break;

    default:
      throw new Error(`Unknown persona: ${evt.persona}`);
  }

  // Add metadata
  intent.metadata = {
    requestId: crypto.randomUUID(),
    timestamp: new Date().toISOString(),
    source: `superclaude:${evt.persona}`
  };

  // Security validation
  validateExecIntent(intent);
  
  // Enforce Bruno-only execution
  if (intent.kind === "execute_via_bruno") {
    enforceBrunoOnly(intent);
  }

  return intent;
}

export async function routeToAgent(agentName: string, args: any): Promise<any> {
  // This would integrate with your Pulser agent registry
  console.log(`[ADAPTER] Routing to agent: ${agentName}`, args);
  
  // Placeholder for actual agent routing
  return {
    status: "routed",
    agent: agentName,
    timestamp: new Date().toISOString()
  };
}