/**
 * Figma Command Validation System
 * Ensures safe and valid operations before execution
 */

export interface ValidationResult {
  valid: boolean;
  errors: string[];
  warnings: string[];
  sanitized?: any;
}

export interface FigmaCommandValidation {
  type: string;
  validate: (command: any) => ValidationResult;
  sanitize?: (command: any) => any;
}

// Command size limits (pixels)
const LIMITS = {
  MIN_SIZE: 1,
  MAX_SIZE: 16000,
  MAX_TEXT_LENGTH: 5000,
  MAX_NAME_LENGTH: 255,
  MAX_TILES: 50,
  MAX_GRID_COLS: 12
};

// Safe colors for sticky notes
const SAFE_COLORS = ['yellow', 'blue', 'green', 'pink', 'red', 'purple', 'orange'];

// Validation helper functions
const isValidNumber = (value: any, min?: number, max?: number): boolean => {
  if (typeof value !== 'number' || isNaN(value)) return false;
  if (min !== undefined && value < min) return false;
  if (max !== undefined && value > max) return false;
  return true;
};

const isValidString = (value: any, maxLength?: number): boolean => {
  if (typeof value !== 'string') return false;
  if (maxLength && value.length > maxLength) return false;
  return value.trim().length > 0;
};

const sanitizeText = (text: string, maxLength: number = LIMITS.MAX_TEXT_LENGTH): string => {
  return text.trim().substring(0, maxLength);
};

const sanitizeName = (name: string): string => {
  return name.trim().substring(0, LIMITS.MAX_NAME_LENGTH).replace(/[<>:"/\\|?*]/g, '_');
};

// Command validators
export const FIGMA_COMMAND_VALIDATORS: Record<string, FigmaCommandValidation> = {
  'create-sticky': {
    type: 'create-sticky',
    validate: (command: any): ValidationResult => {
      const errors: string[] = [];
      const warnings: string[] = [];

      // Required fields
      if (!isValidString(command.text)) {
        errors.push('Text is required and must be a non-empty string');
      } else if (command.text.length > LIMITS.MAX_TEXT_LENGTH) {
        warnings.push(`Text truncated to ${LIMITS.MAX_TEXT_LENGTH} characters`);
      }

      // Optional position validation
      if (command.x !== undefined && !isValidNumber(command.x, -50000, 50000)) {
        errors.push('X position must be a number between -50000 and 50000');
      }

      if (command.y !== undefined && !isValidNumber(command.y, -50000, 50000)) {
        errors.push('Y position must be a number between -50000 and 50000');
      }

      // Color validation
      if (command.color && !SAFE_COLORS.includes(command.color.toLowerCase())) {
        warnings.push(`Invalid color "${command.color}", using default yellow. Valid colors: ${SAFE_COLORS.join(', ')}`);
      }

      return {
        valid: errors.length === 0,
        errors,
        warnings,
        sanitized: {
          ...command,
          text: sanitizeText(command.text),
          color: SAFE_COLORS.includes(command.color?.toLowerCase()) ? command.color.toLowerCase() : 'yellow'
        }
      };
    }
  },

  'create-frame': {
    type: 'create-frame',
    validate: (command: any): ValidationResult => {
      const errors: string[] = [];
      const warnings: string[] = [];

      // Required fields
      if (!isValidString(command.name)) {
        errors.push('Frame name is required');
      } else if (command.name.length > LIMITS.MAX_NAME_LENGTH) {
        warnings.push(`Frame name truncated to ${LIMITS.MAX_NAME_LENGTH} characters`);
      }

      if (!isValidNumber(command.width, LIMITS.MIN_SIZE, LIMITS.MAX_SIZE)) {
        errors.push(`Width must be between ${LIMITS.MIN_SIZE} and ${LIMITS.MAX_SIZE} pixels`);
      }

      if (!isValidNumber(command.height, LIMITS.MIN_SIZE, LIMITS.MAX_SIZE)) {
        errors.push(`Height must be between ${LIMITS.MIN_SIZE} and ${LIMITS.MAX_SIZE} pixels`);
      }

      // Optional position validation
      if (command.x !== undefined && !isValidNumber(command.x, -50000, 50000)) {
        errors.push('X position must be between -50000 and 50000');
      }

      if (command.y !== undefined && !isValidNumber(command.y, -50000, 50000)) {
        errors.push('Y position must be between -50000 and 50000');
      }

      return {
        valid: errors.length === 0,
        errors,
        warnings,
        sanitized: {
          ...command,
          name: sanitizeName(command.name),
          width: Math.max(LIMITS.MIN_SIZE, Math.min(LIMITS.MAX_SIZE, command.width)),
          height: Math.max(LIMITS.MIN_SIZE, Math.min(LIMITS.MAX_SIZE, command.height))
        }
      };
    }
  },

  'create-component': {
    type: 'create-component',
    validate: (command: any): ValidationResult => {
      const errors: string[] = [];
      const warnings: string[] = [];

      if (!isValidString(command.name)) {
        errors.push('Component name is required');
      } else if (command.name.length > LIMITS.MAX_NAME_LENGTH) {
        warnings.push(`Component name truncated to ${LIMITS.MAX_NAME_LENGTH} characters`);
      }

      if (!isValidNumber(command.width, LIMITS.MIN_SIZE, LIMITS.MAX_SIZE)) {
        errors.push(`Width must be between ${LIMITS.MIN_SIZE} and ${LIMITS.MAX_SIZE} pixels`);
      }

      if (!isValidNumber(command.height, LIMITS.MIN_SIZE, LIMITS.MAX_SIZE)) {
        errors.push(`Height must be between ${LIMITS.MIN_SIZE} and ${LIMITS.MAX_SIZE} pixels`);
      }

      return {
        valid: errors.length === 0,
        errors,
        warnings,
        sanitized: {
          ...command,
          name: sanitizeName(command.name),
          width: Math.max(LIMITS.MIN_SIZE, Math.min(LIMITS.MAX_SIZE, command.width)),
          height: Math.max(LIMITS.MIN_SIZE, Math.min(LIMITS.MAX_SIZE, command.height))
        }
      };
    }
  },

  'rename-selection': {
    type: 'rename-selection',
    validate: (command: any): ValidationResult => {
      const errors: string[] = [];
      const warnings: string[] = [];

      if (!isValidString(command.name)) {
        errors.push('New name is required');
      } else if (command.name.length > LIMITS.MAX_NAME_LENGTH) {
        warnings.push(`Name truncated to ${LIMITS.MAX_NAME_LENGTH} characters`);
      }

      return {
        valid: errors.length === 0,
        errors,
        warnings,
        sanitized: {
          ...command,
          name: sanitizeName(command.name)
        }
      };
    }
  },

  'place-component': {
    type: 'place-component',
    validate: (command: any): ValidationResult => {
      const errors: string[] = [];
      const warnings: string[] = [];

      // Component key validation (Figma component keys are typically 32+ chars)
      if (!isValidString(command.key) || command.key.length < 10) {
        errors.push('Valid component key is required (minimum 10 characters)');
      }

      // Optional name validation
      if (command.name && command.name.length > LIMITS.MAX_NAME_LENGTH) {
        warnings.push(`Instance name truncated to ${LIMITS.MAX_NAME_LENGTH} characters`);
      }

      // Position validation
      if (command.x !== undefined && !isValidNumber(command.x, -50000, 50000)) {
        errors.push('X position must be between -50000 and 50000');
      }

      if (command.y !== undefined && !isValidNumber(command.y, -50000, 50000)) {
        errors.push('Y position must be between -50000 and 50000');
      }

      return {
        valid: errors.length === 0,
        errors,
        warnings,
        sanitized: {
          ...command,
          key: command.key.trim(),
          name: command.name ? sanitizeName(command.name) : undefined
        }
      };
    }
  },

  'create-dashboard-layout': {
    type: 'create-dashboard-layout',
    validate: (command: any): ValidationResult => {
      const errors: string[] = [];
      const warnings: string[] = [];

      // Title validation
      if (!isValidString(command.title)) {
        errors.push('Dashboard title is required');
      } else if (command.title.length > LIMITS.MAX_NAME_LENGTH) {
        warnings.push(`Title truncated to ${LIMITS.MAX_NAME_LENGTH} characters`);
      }

      // Grid validation
      if (!command.grid || typeof command.grid !== 'object') {
        errors.push('Grid configuration is required');
      } else {
        if (!isValidNumber(command.grid.cols, 1, LIMITS.MAX_GRID_COLS)) {
          errors.push(`Grid columns must be between 1 and ${LIMITS.MAX_GRID_COLS}`);
        }

        if (!isValidNumber(command.grid.gutter, 0, 200)) {
          errors.push('Grid gutter must be between 0 and 200 pixels');
        }
      }

      // Tiles validation
      if (!Array.isArray(command.tiles)) {
        errors.push('Tiles must be an array');
      } else if (command.tiles.length === 0) {
        warnings.push('No tiles provided - creating empty dashboard');
      } else if (command.tiles.length > LIMITS.MAX_TILES) {
        warnings.push(`Too many tiles (${command.tiles.length}), limiting to ${LIMITS.MAX_TILES}`);
      } else {
        // Validate each tile
        for (let i = 0; i < Math.min(command.tiles.length, LIMITS.MAX_TILES); i++) {
          const tile = command.tiles[i];
          
          if (!tile.id || typeof tile.id !== 'string') {
            errors.push(`Tile ${i + 1}: ID is required`);
          }
          
          if (!isValidNumber(tile.x, 0, command.grid?.cols - 1)) {
            errors.push(`Tile ${i + 1}: X position must be between 0 and ${(command.grid?.cols || 1) - 1}`);
          }
          
          if (!isValidNumber(tile.y, 0, 50)) {
            errors.push(`Tile ${i + 1}: Y position must be between 0 and 50`);
          }
          
          if (!isValidNumber(tile.w, 1, command.grid?.cols)) {
            errors.push(`Tile ${i + 1}: Width must be between 1 and ${command.grid?.cols || 1}`);
          }
          
          if (!isValidNumber(tile.h, 1, 20)) {
            errors.push(`Tile ${i + 1}: Height must be between 1 and 20`);
          }
        }
      }

      return {
        valid: errors.length === 0,
        errors,
        warnings,
        sanitized: {
          ...command,
          title: sanitizeName(command.title),
          grid: {
            cols: Math.max(1, Math.min(LIMITS.MAX_GRID_COLS, command.grid?.cols || 4)),
            gutter: Math.max(0, Math.min(200, command.grid?.gutter || 16))
          },
          tiles: command.tiles?.slice(0, LIMITS.MAX_TILES).map((tile: any, i: number) => ({
            id: tile.id || `tile_${i}`,
            type: tile.type || 'metric',
            x: Math.max(0, Math.min((command.grid?.cols || 4) - 1, tile.x || 0)),
            y: Math.max(0, Math.min(50, tile.y || 0)),
            w: Math.max(1, Math.min(command.grid?.cols || 4, tile.w || 1)),
            h: Math.max(1, Math.min(20, tile.h || 1))
          })) || []
        }
      };
    }
  },

  'apply-brand-tokens': {
    type: 'apply-brand-tokens',
    validate: (command: any): ValidationResult => {
      const errors: string[] = [];
      const warnings: string[] = [];

      if (!command.tokens || typeof command.tokens !== 'object') {
        errors.push('Brand tokens object is required');
      } else {
        const tokenCount = Object.keys(command.tokens).length;
        if (tokenCount === 0) {
          warnings.push('No tokens provided');
        } else if (tokenCount > 100) {
          warnings.push('Large number of tokens may impact performance');
        }

        // Validate color tokens if present
        if (command.tokens.colors) {
          for (const [key, value] of Object.entries(command.tokens.colors)) {
            if (typeof value === 'string' && !/^#[0-9A-Fa-f]{6}$/.test(value as string)) {
              warnings.push(`Invalid color format for "${key}": ${value}. Expected hex format like #FF0000`);
            }
          }
        }
      }

      return {
        valid: errors.length === 0,
        errors,
        warnings,
        sanitized: {
          ...command,
          tokens: command.tokens || {}
        }
      };
    }
  }
};

/**
 * Validate a Figma command
 */
export function validateFigmaCommand(command: any): ValidationResult {
  if (!command || typeof command !== 'object') {
    return {
      valid: false,
      errors: ['Command must be an object'],
      warnings: []
    };
  }

  if (!command.type || typeof command.type !== 'string') {
    return {
      valid: false,
      errors: ['Command type is required'],
      warnings: []
    };
  }

  const validator = FIGMA_COMMAND_VALIDATORS[command.type];
  if (!validator) {
    return {
      valid: false,
      errors: [`Unknown command type: ${command.type}. Supported types: ${Object.keys(FIGMA_COMMAND_VALIDATORS).join(', ')}`],
      warnings: []
    };
  }

  return validator.validate(command);
}

/**
 * Batch validate multiple commands
 */
export function validateFigmaCommands(commands: any[]): {
  valid: boolean;
  results: Array<ValidationResult & { command: any; index: number }>;
  summary: {
    total: number;
    valid: number;
    errors: number;
    warnings: number;
  };
} {
  const results = commands.map((command, index) => ({
    ...validateFigmaCommand(command),
    command,
    index
  }));

  const summary = {
    total: results.length,
    valid: results.filter(r => r.valid).length,
    errors: results.reduce((sum, r) => sum + r.errors.length, 0),
    warnings: results.reduce((sum, r) => sum + r.warnings.length, 0)
  };

  return {
    valid: summary.valid === summary.total && summary.errors === 0,
    results,
    summary
  };
}

/**
 * Security check for potentially malicious commands
 */
export function securityCheck(command: any): { safe: boolean; issues: string[] } {
  const issues: string[] = [];

  // Check for suspicious patterns
  const commandStr = JSON.stringify(command);
  
  // Check for script injection attempts
  if (/<script|javascript:|data:|vbscript:/i.test(commandStr)) {
    issues.push('Potential script injection detected');
  }

  // Check for excessive resource usage
  if (command.width > 20000 || command.height > 20000) {
    issues.push('Excessive size detected (potential DoS attempt)');
  }

  // Check for path traversal attempts
  if (/\.\.\/|\.\.\\|%2e%2e/i.test(commandStr)) {
    issues.push('Path traversal attempt detected');
  }

  // Check for suspicious URLs or external references
  if (/https?:\/\/(?!localhost|127\.0\.0\.1)/i.test(commandStr)) {
    issues.push('External URL references not allowed');
  }

  return {
    safe: issues.length === 0,
    issues
  };
}