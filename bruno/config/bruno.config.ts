export interface BrunoConfig {
  executor: {
    maxConcurrentJobs: number;
    defaultTimeout: number;
    maxRetries: number;
    retryDelay: number;
  };
  security: {
    defaultPolicy: 'strict' | 'permissive' | 'audit';
    enableNetworkAccess: boolean;
    enableFileSystemAccess: boolean;
    maxPayloadSize: number;
    trustedHosts: string[];
    forbiddenCommands: string[];
  };
  sandbox: {
    type: 'docker' | 'vm' | 'process' | 'auto';
    dockerImage: string;
    resources: {
      cpuPercent: number;
      memoryMB: number;
      diskMB: number;
      networkBandwidthMbps: number;
    };
    cleanup: {
      onSuccess: boolean;
      onFailure: boolean;
      retentionMinutes: number;
    };
  };
  logging: {
    level: 'debug' | 'info' | 'warn' | 'error';
    auditLog: boolean;
    securityLog: boolean;
    performanceLog: boolean;
    logPath: string;
  };
  integrations: {
    pulser: {
      enabled: boolean;
      endpoint: string;
    };
    supabase: {
      enabled: boolean;
      projectRef?: string;
      anonKey?: string;
    };
    mcp: {
      enabled: boolean;
      servers: string[];
    };
  };
}

const defaultConfig: BrunoConfig = {
  executor: {
    maxConcurrentJobs: 10,
    defaultTimeout: 300000, // 5 minutes
    maxRetries: 3,
    retryDelay: 1000
  },
  security: {
    defaultPolicy: 'strict',
    enableNetworkAccess: false,
    enableFileSystemAccess: true,
    maxPayloadSize: 10 * 1024 * 1024, // 10MB
    trustedHosts: ['localhost', '127.0.0.1'],
    forbiddenCommands: [
      'rm -rf /',
      'dd if=/dev/zero',
      ':(){ :|:& };:',
      'sudo',
      'su'
    ]
  },
  sandbox: {
    type: 'auto',
    dockerImage: 'node:18-alpine',
    resources: {
      cpuPercent: 50,
      memoryMB: 512,
      diskMB: 1024,
      networkBandwidthMbps: 10
    },
    cleanup: {
      onSuccess: true,
      onFailure: false,
      retentionMinutes: 60
    }
  },
  logging: {
    level: 'info',
    auditLog: true,
    securityLog: true,
    performanceLog: true,
    logPath: './bruno/logs'
  },
  integrations: {
    pulser: {
      enabled: true,
      endpoint: 'http://localhost:3000/pulser'
    },
    supabase: {
      enabled: false
    },
    mcp: {
      enabled: true,
      servers: ['filesystem', 'supabase_primary']
    }
  }
};

// Load environment-specific overrides
export function loadConfig(): BrunoConfig {
  const env = process.env.NODE_ENV || 'development';
  let config = { ...defaultConfig };

  // Environment-specific overrides
  switch (env) {
    case 'production':
      config.security.defaultPolicy = 'strict';
      config.sandbox.type = 'docker';
      config.logging.level = 'warn';
      break;
    
    case 'development':
      config.security.defaultPolicy = 'permissive';
      config.sandbox.type = 'process';
      config.logging.level = 'debug';
      break;
    
    case 'test':
      config.executor.maxConcurrentJobs = 1;
      config.logging.auditLog = false;
      config.sandbox.cleanup.onSuccess = true;
      break;
  }

  // Load from config file if exists
  try {
    const configFile = process.env.BRUNO_CONFIG || './bruno.config.json';
    if (require('fs').existsSync(configFile)) {
      const fileConfig = JSON.parse(require('fs').readFileSync(configFile, 'utf-8'));
      config = deepMerge(config, fileConfig);
    }
  } catch (error) {
    console.warn('[Bruno] Failed to load config file:', error);
  }

  return config;
}

function deepMerge(target: any, source: any): any {
  const output = { ...target };
  
  if (isObject(target) && isObject(source)) {
    Object.keys(source).forEach(key => {
      if (isObject(source[key])) {
        if (!(key in target)) {
          Object.assign(output, { [key]: source[key] });
        } else {
          output[key] = deepMerge(target[key], source[key]);
        }
      } else {
        Object.assign(output, { [key]: source[key] });
      }
    });
  }
  
  return output;
}

function isObject(item: any): boolean {
  return item && typeof item === 'object' && !Array.isArray(item);
}

export const brunoConfig = loadConfig();