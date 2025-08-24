module.exports = {
  docs: [
    // ============ INTRODUCTION ============
    {
      type: 'category',
      label: '📘 Introduction',
      collapsed: false,
      items: [
        'intro/index',
        'intro/principles',
        'intro/modules',
        'intro/release-notes',
      ],
    },
    
    // ============ SYSTEM ARCHITECTURE ============
    {
      type: 'category',
      label: '🔧 System Architecture',
      collapsed: false,
      items: [
        'system/architecture',
        'system/stack',
        'system/security-rls',
        'system/mcp-setup',
        'system/event-pipeline',
        'system/roles',
      ],
    },
    
    // ============ SCHEMA REFERENCE ============
    {
      type: 'category',
      label: '🗄️ Schema Reference',
      collapsed: true,
      items: [
        'schema/overview',
        'schema/bronze',
        'schema/silver',
        'schema/gold',
        'schema/platinum',
        'schema/views',
        'schema/schema-glossary',
      ],
    },
    
    // ============ API DOCUMENTATION ============
    {
      type: 'category',
      label: '🔌 API Documentation',
      collapsed: false,
      items: [
        'api/overview',
        'api/gold-apis',
        'api/platinum-apis',
        'api/rate-limits',
        'api/dal-reference',
        'api/openapi',
      ],
    },
    
    // ============ DATA ABSTRACTION LAYER ============
    {
      type: 'category',
      label: '🧱 DAL Guide',
      collapsed: true,
      items: [
        'dal/overview',
        'dal/usage',
        'dal/gold-fetchers',
        'dal/platinum-fetchers',
        'dal/migration-guide',
        'dal/best-practices',
      ],
    },
    
    // ============ AI AGENTS ============
    {
      type: 'category',
      label: '🤖 AI Agents',
      collapsed: false,
      items: [
        'ai-agents/overview',
        'ai-agents/suqi',
        'ai-agents/wrenai',
        'ai-agents/savage',
        'ai-agents/jason',
        'ai-agents/isko',
        'ai-agents/fully',
        'ai-agents/agent-schema',
        'ai-agents/custom-agents',
      ],
    },
    
    // ============ PLAYBOOKS ============
    {
      type: 'category',
      label: '📊 Playbooks',
      collapsed: false,
      items: [
        'playbooks/overview',
        'playbooks/quickstart',
        'playbooks/regional-performance',
        'playbooks/churn-analysis',
        'playbooks/competitive-dynamics',
        'playbooks/brand-substitution',
        'playbooks/revenue-forecasting',
        'playbooks/customer-segmentation',
        'playbooks/inventory-optimization',
        'playbooks/promotion-effectiveness',
      ],
    },
    
    // ============ INTEGRATION ============
    {
      type: 'category',
      label: '🔄 Integration',
      collapsed: true,
      items: [
        'integration/overview',
        'integration/supabase-edge-functions',
        'integration/ci-cd-vercel',
        'integration/secrets-env',
        'integration/external-ingestion',
        'integration/telemetry-observability',
        'integration/sso',
        'integration/webhooks',
      ],
    },
    
    // ============ OPERATIONS ============
    {
      type: 'category',
      label: '⚙️ Operations',
      collapsed: true,
      items: [
        'operations/monitoring',
        'operations/alerting',
        'operations/backup-recovery',
        'operations/performance-tuning',
        'operations/scaling',
        'operations/troubleshooting',
      ],
    },
    
    // ============ SECURITY ============
    {
      type: 'category',
      label: '🔒 Security',
      collapsed: true,
      items: [
        'security/hardening-guide',
        'security/authentication',
        'security/authorization',
        'security/encryption',
        'security/audit-logging',
        'security/compliance',
      ],
    },
    
    // ============ DATA GOVERNANCE ============
    {
      type: 'category',
      label: '📋 Data Governance',
      collapsed: true,
      items: [
        'governance/data-quality',
        'governance/data-contracts',
        'governance/lineage',
        'governance/privacy',
        'governance/retention',
      ],
    },
    
    // ============ REFERENCE ============
    {
      type: 'category',
      label: '📚 Reference',
      collapsed: true,
      items: [
        'reference/glossary',
        'reference/error-codes',
        'reference/sql-functions',
        'reference/data-dictionary',
        'reference/api-postman',
      ],
    },
    
    // ============ TUTORIALS ============
    {
      type: 'category',
      label: '🎓 Tutorials',
      collapsed: true,
      items: [
        'tutorials/quickstart',
        'tutorials/first-dashboard',
        'tutorials/custom-visualization',
        'tutorials/api-integration',
        'tutorials/agent-creation',
        'tutorials/data-upload',
      ],
    },
    
    // ============ FAQ ============
    {
      type: 'category',
      label: '❓ FAQ',
      collapsed: true,
      items: [
        'faq/common-issues',
        'faq/dashboard-loading',
        'faq/data-discrepancies',
        'faq/api-errors',
        'faq/performance',
        'faq/access-control',
      ],
    },
    
    // ============ VERSION HISTORY ============
    {
      type: 'category',
      label: '📅 Version History',
      collapsed: true,
      items: [
        'versions/current',
        'versions/v5-2',
        'versions/v5-1',
        'versions/v5-0',
        'versions/migration-guides',
        'versions/deprecations',
      ],
    },
  ],
  
  // ============ API REFERENCE SIDEBAR ============
  apiReference: [
    {
      type: 'category',
      label: 'Gold Layer APIs',
      items: [
        'api-reference/brand-performance',
        'api-reference/customer-analytics',
        'api-reference/product-analytics',
        'api-reference/geographic-analytics',
        'api-reference/competitive-intelligence',
        'api-reference/time-series',
      ],
    },
    {
      type: 'category',
      label: 'Platinum Layer APIs',
      items: [
        'api-reference/predictive-analytics',
        'api-reference/agent-actions',
        'api-reference/monitoring',
        'api-reference/contracts',
      ],
    },
    {
      type: 'category',
      label: 'Edge Functions',
      items: [
        'api-reference/edge-ingestion',
        'api-reference/edge-processing',
        'api-reference/edge-webhooks',
      ],
    },
  ],
  
  // ============ DEVELOPER GUIDE SIDEBAR ============
  developerGuide: [
    {
      type: 'category',
      label: 'Getting Started',
      items: [
        'dev/setup',
        'dev/local-development',
        'dev/testing',
        'dev/debugging',
      ],
    },
    {
      type: 'category',
      label: 'Contributing',
      items: [
        'dev/contribution-guide',
        'dev/code-style',
        'dev/pull-requests',
        'dev/documentation',
      ],
    },
    {
      type: 'category',
      label: 'Architecture',
      items: [
        'dev/design-patterns',
        'dev/database-design',
        'dev/api-design',
        'dev/frontend-architecture',
      ],
    },
  ],
};
