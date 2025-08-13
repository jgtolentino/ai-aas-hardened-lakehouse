import type { BrunoJob } from '../executor/types';

export const jobTemplates: Record<string, Partial<BrunoJob>> = {
  // Code generation templates
  'generate-react-component': {
    type: 'script',
    permissions: ['file:write', 'file:read'],
    timeout: 60000,
    script: `
      const { componentName, props = {} } = payload;
      const template = require('./templates/react-component');
      const code = template.generate(componentName, props);
      require('fs').writeFileSync(\`\${componentName}.tsx\`, code);
      console.log(JSON.stringify({ success: true, file: \`\${componentName}.tsx\` }));
    `
  },

  // Documentation templates
  'generate-readme': {
    type: 'script',
    permissions: ['file:write', 'file:read'],
    timeout: 30000,
    script: `
      const { projectName, description, features = [] } = payload;
      const readme = \`# \${projectName}
      
\${description}

## Features
\${features.map(f => '- ' + f).join('\\n')}

## Installation
\\\`\\\`\\\`bash
npm install
\\\`\\\`\\\`

## Usage
\\\`\\\`\\\`bash
npm start
\\\`\\\`\\\`
\`;
      require('fs').writeFileSync('README.md', readme);
      console.log(JSON.stringify({ success: true, file: 'README.md' }));
    `
  },

  // Security scanning templates
  'security-scan-npm': {
    type: 'shell',
    command: 'npm audit --json',
    permissions: ['file:read', 'process:execute'],
    timeout: 120000
  },

  'security-scan-dependencies': {
    type: 'shell',
    command: 'npx audit-ci --config audit-ci.json',
    permissions: ['file:read', 'process:execute', 'network'],
    timeout: 180000
  },

  // Testing templates
  'run-unit-tests': {
    type: 'shell',
    command: 'npm test -- --coverage --json',
    permissions: ['file:read', 'process:execute'],
    timeout: 300000
  },

  'run-e2e-tests': {
    type: 'shell',
    command: 'npm run test:e2e',
    permissions: ['file:read', 'process:execute', 'network'],
    timeout: 600000
  },

  // Build templates
  'build-typescript': {
    type: 'shell',
    command: 'tsc --noEmit',
    permissions: ['file:read'],
    timeout: 120000
  },

  'build-production': {
    type: 'shell',
    command: 'npm run build',
    permissions: ['file:read', 'file:write', 'process:execute'],
    timeout: 300000
  },

  // Database operations
  'database-migration': {
    type: 'script',
    permissions: ['database:write', 'file:read'],
    timeout: 120000,
    script: `
      // This would integrate with Supabase migrations
      console.log('Database migration template - integrate with Supabase');
      console.log(JSON.stringify({ success: false, error: 'Not implemented' }));
    `
  },

  // File operations
  'clean-workspace': {
    type: 'shell',
    command: 'rm -rf node_modules dist .next .turbo',
    permissions: ['file:write', 'file:delete'],
    timeout: 60000
  },

  'format-code': {
    type: 'shell',
    command: 'prettier --write "**/*.{ts,tsx,js,jsx,json,md}"',
    permissions: ['file:read', 'file:write'],
    timeout: 120000
  },

  // Git operations (safe)
  'git-status': {
    type: 'shell',
    command: 'git status --porcelain',
    permissions: ['file:read'],
    timeout: 10000
  },

  'git-diff': {
    type: 'shell',
    command: 'git diff --name-only',
    permissions: ['file:read'],
    timeout: 10000
  },

  // Environment setup
  'install-dependencies': {
    type: 'shell',
    command: 'npm ci',
    permissions: ['file:read', 'file:write', 'network', 'process:execute'],
    timeout: 300000
  },

  'setup-environment': {
    type: 'script',
    permissions: ['file:write'],
    timeout: 30000,
    script: `
      const envTemplate = \`
NODE_ENV=development
DATABASE_URL=postgresql://localhost:5432/dev
API_KEY=dev-key
\`;
      require('fs').writeFileSync('.env.local', envTemplate);
      console.log(JSON.stringify({ success: true, file: '.env.local' }));
    `
  }
};

/**
 * Get a job template by name
 */
export function getJobTemplate(templateName: string): Partial<BrunoJob> | undefined {
  return jobTemplates[templateName];
}

/**
 * Create a job from a template with overrides
 */
export function createJobFromTemplate(
  templateName: string, 
  overrides: Partial<BrunoJob>
): BrunoJob {
  const template = getJobTemplate(templateName);
  if (!template) {
    throw new Error(`Template ${templateName} not found`);
  }

  return {
    id: `template-${templateName}-${Date.now()}`,
    ...template,
    ...overrides,
    permissions: [...(template.permissions || []), ...(overrides.permissions || [])]
  } as BrunoJob;
}

/**
 * List all available templates
 */
export function listTemplates(): string[] {
  return Object.keys(jobTemplates);
}