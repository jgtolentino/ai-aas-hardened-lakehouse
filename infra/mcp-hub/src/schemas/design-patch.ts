/**
 * Design Patch Specification Schema
 * Unified system for bulk design modifications via Figma Bridge
 */

export type PatchTarget = {
  fileKey?: string;    // Target file (optional if operating on current file)
  nodeId?: string;     // Target node (optional if targeting entire file)
  selector?: NodeSelector; // Alternative to nodeId for pattern matching
};

export type NodeSelector = {
  name?: string | RegExp;           // Match by name pattern
  type?: string[];                  // Match by node types
  tags?: string[];                  // Match by custom tags
  layer?: string;                   // Match by layer name
  component?: string;               // Match by component name
  parent?: string;                  // Match by parent node name
};

export type PatchOperation = 
  | RenameOperation
  | ReplaceTextOperation  
  | SwapComponentOperation
  | ApplyTokensOperation
  | LayoutOperation
  | CreateFrameOperation
  | PlaceComponentOperation
  | ReplaceImageOperation
  | StyleOperation
  | DeleteOperation
  | DuplicateOperation
  | GroupOperation;

export interface RenameOperation {
  op: "rename";
  selector: NodeSelector;
  to: string;
}

export interface ReplaceTextOperation {
  op: "replaceText";
  selector: NodeSelector;
  find: string | RegExp;
  replace: string;
  all?: boolean;                    // Replace all occurrences vs first only
  preserveCase?: boolean;           // Preserve original casing
}

export interface SwapComponentOperation {
  op: "swapComponent";
  selector: NodeSelector;
  to: {
    componentKey: string;           // Figma component key
    variant?: Record<string, string>; // Variant properties if applicable
  };
}

export interface ApplyTokensOperation {
  op: "applyTokens";
  selector: NodeSelector;
  tokens: Record<string, string>;   // CSS custom properties or Figma variables
  mode?: "replace" | "merge";       // How to handle existing values
}

export interface LayoutOperation {
  op: "layout";
  selector?: NodeSelector;          // Apply to specific nodes or all
  grid?: "12col" | "auto" | "flex" | "none";
  gap?: number;                     // Gap between items
  columns?: number;                 // Number of columns
  direction?: "row" | "column";     // Flex direction
  align?: "start" | "center" | "end" | "stretch";
  justify?: "start" | "center" | "end" | "between" | "around";
  padding?: number | { top?: number; right?: number; bottom?: number; left?: number };
}

export interface CreateFrameOperation {
  op: "createFrame";
  name: string;
  size: { w: number; h: number };
  at?: { x: number; y: number };
  style?: {
    background?: string;
    border?: { color: string; width: number };
    cornerRadius?: number;
    opacity?: number;
  };
}

export interface PlaceComponentOperation {
  op: "placeComponent";
  from: { key: string };            // Component key from library
  at: { x: number; y: number };
  name?: string;                    // Name for the instance
  props?: Record<string, any>;      // Component properties
}

export interface ReplaceImageOperation {
  op: "replaceImage";
  selector: NodeSelector;
  url: string;                      // Image URL or base64 data
  fit?: "fill" | "fit" | "crop" | "tile";
}

export interface StyleOperation {
  op: "style";
  selector: NodeSelector;
  styles: {
    fill?: string | string[];       // Solid color or gradient stops
    stroke?: string;                // Border color
    strokeWeight?: number;          // Border width
    cornerRadius?: number;          // Border radius
    opacity?: number;               // Transparency
    blur?: number;                  // Background blur
    shadow?: {                      // Drop shadow
      color: string;
      x: number;
      y: number;
      blur: number;
      spread: number;
    };
  };
}

export interface DeleteOperation {
  op: "delete";
  selector: NodeSelector;
  confirm?: boolean;                // Safety flag for destructive operations
}

export interface DuplicateOperation {
  op: "duplicate";
  selector: NodeSelector;
  count?: number;                   // Number of copies
  offset?: { x: number; y: number }; // Offset for each copy
  name?: string;                    // Naming pattern with {n} placeholder
}

export interface GroupOperation {
  op: "group";
  selector: NodeSelector;
  name: string;
  type?: "group" | "frame";         // Group type
}

export interface PatchSpec {
  target: PatchTarget;
  operations: PatchOperation[];
  options?: {
    preview?: boolean;              // Generate preview before applying
    rollback?: boolean;             // Enable rollback on failure
    parallel?: boolean;             // Execute operations in parallel where possible
    timeout?: number;               // Timeout in milliseconds
  };
}

export interface PatchResult {
  success: boolean;
  operations_applied: number;
  operations_failed: number;
  errors?: string[];
  preview_url?: string;             // If preview was generated
  rollback_id?: string;             // For rollback operations
  affected_nodes: string[];         // List of modified node IDs
  execution_time: number;           // Milliseconds
}

// Brand token presets for common rebranding operations
export const BRAND_TOKEN_PRESETS = {
  insightpulseai: {
    "--brand-primary": "#00CED1",
    "--brand-primary-weak": "#40E0D0", 
    "--brand-bg-dark": "#0A0A0A",
    "--brand-blue": "#1E3A5F",
    "--brand-steel": "#4A5568",
    "--brand-white": "#FFFFFF",
    "--brand-gray-50": "#F9FAFB",
    "--brand-gray-100": "#F3F4F6",
    "--brand-gray-200": "#E5E7EB",
    "--brand-gray-500": "#6B7280",
    "--brand-gray-900": "#111827"
  },
  
  scout_dashboard: {
    "--scout-primary": "#1E40AF",
    "--scout-secondary": "#7C3AED",
    "--scout-success": "#059669", 
    "--scout-warning": "#D97706",
    "--scout-error": "#DC2626",
    "--scout-bg": "#FFFFFF",
    "--scout-surface": "#F8FAFC",
    "--scout-border": "#E2E8F0",
    "--scout-text": "#1E293B"
  },

  tbwa: {
    "--tbwa-red": "#E10E00",
    "--tbwa-black": "#000000",
    "--tbwa-white": "#FFFFFF", 
    "--tbwa-gray-light": "#F5F5F5",
    "--tbwa-gray": "#808080",
    "--tbwa-gray-dark": "#333333"
  }
};

// Common layout presets for different dashboard types
export const LAYOUT_PRESETS = {
  dashboard_12col: {
    op: "layout" as const,
    grid: "12col" as const,
    gap: 16,
    columns: 12,
    padding: { top: 24, right: 24, bottom: 24, left: 24 }
  },
  
  kpi_row: {
    op: "layout" as const,
    grid: "flex" as const,
    direction: "row" as const,
    gap: 16,
    justify: "between" as const
  },
  
  chart_grid: {
    op: "layout" as const,
    grid: "auto" as const,
    columns: 2,
    gap: 20,
    align: "stretch" as const
  }
};

// Utility functions for common patch operations
export function createBrandPatch(
  target: PatchTarget, 
  brandPreset: keyof typeof BRAND_TOKEN_PRESETS,
  textReplacements?: Record<string, string>
): PatchSpec {
  const operations: PatchOperation[] = [
    {
      op: "applyTokens",
      selector: { name: /.*/ },
      tokens: BRAND_TOKEN_PRESETS[brandPreset]
    }
  ];
  
  // Add text replacements if provided
  if (textReplacements) {
    Object.entries(textReplacements).forEach(([find, replace]) => {
      operations.push({
        op: "replaceText",
        selector: { type: ["TEXT"] },
        find,
        replace,
        all: true
      });
    });
  }
  
  return { target, operations };
}

export function createLayoutPatch(
  target: PatchTarget,
  layoutPreset: keyof typeof LAYOUT_PRESETS
): PatchSpec {
  return {
    target,
    operations: [LAYOUT_PRESETS[layoutPreset]]
  };
}

export function createDashboardRefitPatch(
  target: PatchTarget,
  options: {
    brand: keyof typeof BRAND_TOKEN_PRESETS;
    layout?: keyof typeof LAYOUT_PRESETS;
    textReplacements?: Record<string, string>;
    logoComponent?: string;
  }
): PatchSpec {
  const operations: PatchOperation[] = [];
  
  // Apply brand tokens
  operations.push({
    op: "applyTokens",
    selector: { name: /.*/ },
    tokens: BRAND_TOKEN_PRESETS[options.brand]
  });
  
  // Apply layout if specified
  if (options.layout) {
    operations.push(LAYOUT_PRESETS[options.layout]);
  }
  
  // Apply text replacements
  if (options.textReplacements) {
    Object.entries(options.textReplacements).forEach(([find, replace]) => {
      operations.push({
        op: "replaceText",
        selector: { type: ["TEXT"] },
        find,
        replace,
        all: true
      });
    });
  }
  
  // Swap logo component if provided
  if (options.logoComponent) {
    operations.push({
      op: "swapComponent",
      selector: { name: /logo/i },
      to: { componentKey: options.logoComponent }
    });
  }
  
  return { target, operations };
}

// Validation schema for patch specifications
export function validatePatchSpec(spec: PatchSpec): { valid: boolean; errors: string[] } {
  const errors: string[] = [];
  
  // Validate target
  if (!spec.target.fileKey && !spec.target.nodeId && !spec.target.selector) {
    errors.push("Target must specify fileKey, nodeId, or selector");
  }
  
  // Validate operations
  if (!spec.operations || spec.operations.length === 0) {
    errors.push("At least one operation is required");
  }
  
  spec.operations.forEach((op, index) => {
    if (!op.op) {
      errors.push(`Operation ${index}: 'op' field is required`);
    }
    
    // Validate operation-specific requirements
    switch (op.op) {
      case "rename":
        if (!op.to) errors.push(`Operation ${index}: 'to' field required for rename`);
        break;
      case "replaceText":
        if (!op.find || op.replace === undefined) {
          errors.push(`Operation ${index}: 'find' and 'replace' fields required for replaceText`);
        }
        break;
      case "swapComponent":
        if (!op.to?.componentKey) {
          errors.push(`Operation ${index}: 'to.componentKey' required for swapComponent`);
        }
        break;
      case "createFrame":
        if (!op.name || !op.size) {
          errors.push(`Operation ${index}: 'name' and 'size' required for createFrame`);
        }
        break;
    }
  });
  
  return { valid: errors.length === 0, errors };
}