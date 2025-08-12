import type { ExecIntent } from "../adapters/types";

export function enforceBrunoOnly(i: ExecIntent) {
  if (i.kind !== "execute_via_bruno") {
    throw new Error(`[SECURITY] Direct execution blocked. All operations must go through Bruno. Attempted: ${i.kind}`);
  }
  return i;
}

export function validateExecIntent(intent: ExecIntent): void {
  // Ensure no sensitive data in payload
  const sensitivePatterns = [
    /api[_-]?key/i,
    /password/i,
    /secret/i,
    /token/i,
    /credential/i
  ];
  
  const payload = JSON.stringify(intent);
  for (const pattern of sensitivePatterns) {
    if (pattern.test(payload)) {
      throw new Error(`[SECURITY] Potential sensitive data detected in execution intent`);
    }
  }
}