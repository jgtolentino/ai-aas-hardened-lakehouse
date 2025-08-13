export interface PulserConfig {
  registry: {
    dataPath: string;
    autoSave: boolean;
    backupEnabled: boolean;
    backupInterval: number;
  };
  routing: {
    defaultStrategy: string;
    fallbackStrategies: string[];
    timeoutMs: number;
    retryAttempts: number;
  };
  execution: {
    defaultExecutor: string;
    sandboxMode: boolean;
    maxConcurrentJobs: number;
    jobQueueSize: number;
  };
  security: {
    enforcePermissions: boolean;
    auditLogging: boolean;
    secretsProvider: 'env' | 'vault' | 'aws-secrets';
    allowedNetworkHosts: string[];
  };
  monitoring: {
    metricsEnabled: boolean;
    metricsPort: number;
    healthCheckInterval: number;
    alertingEnabled: boolean;
  };
  integrations: {
    bruno: {
      enabled: boolean;
      endpoint: string;
      apiKey?: string;
    };
    supabase: {
      enabled: boolean;
      projectRef?: string;
      serviceRole?: string;
    };
    mcp: {
      enabled: boolean;
      configPath: string;
    };
  };
}

const defaultConfig: PulserConfig = {
  registry: {
    dataPath: './pulser/registry/data',
    autoSave: true,
    backupEnabled: true,
    backupInterval: 3600000 // 1 hour
  },
  routing: {
    defaultStrategy: 'capability-based',
    fallbackStrategies: ['type-based', 'load-balancing'],
    timeoutMs: 30000,
    retryAttempts: 3
  },
  execution: {
    defaultExecutor: 'bruno',
    sandboxMode: true,
    maxConcurrentJobs: 10,
    jobQueueSize: 100
  },
  security: {
    enforcePermissions: true,
    auditLogging: true,
    secretsProvider: 'env',
    allowedNetworkHosts: [
      'localhost',
      '127.0.0.1',
      'api.github.com',
      'registry.npmjs.org'
    ]
  },
  monitoring: {
    metricsEnabled: true,
    metricsPort: 9090,
    healthCheckInterval: 60000, // 1 minute
    alertingEnabled: true
  },
  integrations: {
    bruno: {
      enabled: true,
      endpoint: process.env.BRUNO_ENDPOINT || 'http://localhost:8080'
    },
    supabase: {
      enabled: false,
      projectRef: process.env.SUPABASE_PROJECT_REF,
      serviceRole: process.env.SUPABASE_SERVICE_ROLE
    },
    mcp: {
      enabled: true,
      configPath: './mcp/config/mcp-servers.json'
    }
  }
};

// Load environment-specific overrides
function loadConfig(): PulserConfig {
  const env = process.env.NODE_ENV || 'development';
  let config = { ...defaultConfig };

  // Environment-specific overrides
  switch (env) {
    case 'production':
      config.security.sandboxMode = true;
      config.security.enforcePermissions = true;
      config.monitoring.alertingEnabled = true;
      break;
    
    case 'development':
      config.security.sandboxMode = false;
      config.monitoring.alertingEnabled = false;
      break;
    
    case 'test':
      config.registry.autoSave = false;
      config.monitoring.metricsEnabled = false;
      break;
  }

  // Load from config file if exists
  try {
    const configFile = process.env.PULSER_CONFIG || './pulser.config.json';
    if (require('fs').existsSync(configFile)) {
      const fileConfig = JSON.parse(require('fs').readFileSync(configFile, 'utf-8'));
      config = deepMerge(config, fileConfig);
    }
  } catch (error) {
    console.warn('[Pulser] Failed to load config file:', error);
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

export const pulserConfig = loadConfig();