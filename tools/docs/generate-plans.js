#!/usr/bin/env node
const fs = require('fs');
const path = require('path');

// Manual YAML parsing for claude-exec block
function parseClaudeExec(content) {
  const lines = content.split('\n');
  const config = {
    product: '',
    goals: [],
    constraints: [],
    outputs: [],
    rules: {}
  };
  
  let currentSection = null;
  let currentIndent = 0;
  
  lines.forEach(line => {
    if (line.includes('product:')) {
      config.product = line.split('product:')[1].trim().replace(/['"]/g, '');
    } else if (line.includes('goals:')) {
      currentSection = 'goals';
    } else if (line.includes('constraints:')) {
      currentSection = 'constraints';
    } else if (line.includes('outputs:')) {
      currentSection = 'outputs';
    } else if (line.includes('rules:')) {
      currentSection = 'rules';
    } else if (line.trim().startsWith('-') && currentSection) {
      const value = line.trim().substring(1).trim().replace(/['"]/g, '');
      if (currentSection === 'goals' || currentSection === 'constraints' || currentSection === 'outputs') {
        config[currentSection].push(value);
      }
    } else if (line.includes(':') && currentSection === 'rules') {
      const [key, value] = line.trim().split(':').map(s => s.trim());
      config.rules[key] = value;
    }
  });
  
  return config;
}

// Generate planning.md
function generatePlanning(config, icdVersion) {
  const { product, goals, constraints } = config;
  
  return `# ${product} — 4-Week Execution Plan

**Generated**: ${new Date().toISOString().split('T')[0]}  
**Source**: docs/scout/PRD.md (ICD v${icdVersion})  
**Status**: Auto-generated from claude-exec block  

## Goals
${goals.map((g, i) => `${i + 1}. ${g}`).join('\n')}

## Constraints
${constraints ? constraints.map(c => `- ${c}`).join('\n') : ''}

## Week 1: Foundation & ICD Alignment
- [ ] Review and approve ICD v${icdVersion}
- [ ] Set up component scaffolding per PRD wireframes
- [ ] Initialize data hooks with mock responses
- [ ] Configure CI/CD pipelines
- [ ] Establish test fixtures

## Week 2: Core Features Implementation
${goals.slice(0, 2).map(g => `- [ ] ${g}`).join('\n')}
- [ ] Unit tests for implemented features
- [ ] Integration with staging API

## Week 3: Extended Features & Polish
${goals.slice(2).map(g => `- [ ] ${g}`).join('\n')}
- [ ] Accessibility audit and fixes
- [ ] Performance optimization
- [ ] E2E test coverage

## Week 4: Hardening & Release
- [ ] Performance testing against SLOs
- [ ] Security scan and remediation
- [ ] Documentation updates
- [ ] Deployment to production
- [ ] Post-launch monitoring setup

## Risk Mitigation
| Risk | Mitigation | Owner |
|------|------------|-------|
| API drift | ICD validation in CI | Backend |
| Performance regression | Lighthouse CI budget | Frontend |
| Data inconsistency | Contract tests | Data |
| Accessibility gaps | Automated axe checks | UI/UX |

## Success Criteria
${constraints ? constraints.map(c => `- ✅ ${c}`).join('\n') : ''}
- ✅ All ICD endpoints implemented and tested
- ✅ Zero critical/high security findings
- ✅ Documentation complete and reviewed
`;
}

// Generate tasks.md
function generateTasks(config, icdVersion) {
  const { product, goals, rules } = config;
  
  // Parse goals into atomic tasks
  const tasks = [];
  
  goals.forEach((goal, goalIndex) => {
    // Extract key components from each goal
    if (goal.includes('Executive Overview')) {
      tasks.push({
        category: 'Executive Dashboard',
        items: [
          'Build KpiRow component with loading states',
          'Implement useExecutiveSummary hook',
          'Add accessibility labels for KPI tiles',
          'Write unit tests with MSW mocks',
          'Add Storybook stories'
        ]
      });
    }
    
    if (goal.includes('Geo')) {
      tasks.push({
        category: 'Geographic Intelligence',
        items: [
          'Initialize Mapbox with API key',
          'Implement RLS token injection',
          'Add clustering for barangay data',
          'Build useGeoDrilldown hook',
          'Add zoom controls and legend',
          'Optimize tile loading'
        ]
      });
    }
    
    if (goal.includes('AI')) {
      tasks.push({
        category: 'AI Recommendations',
        items: [
          'Build RecommendationPanel component',
          'Wire to /api/ai/recommendations',
          'Add confidence badges',
          'Implement feature flag toggle',
          'Add explanation tooltips',
          'Handle rate limiting gracefully'
        ]
      });
    }
    
    if (goal.includes('export')) {
      tasks.push({
        category: 'Export Functionality',
        items: [
          'Add CSV export for tables',
          'Add PNG export for charts',
          'Add PDF report generation',
          'Implement batch export queue',
          'Add progress indicators'
        ]
      });
    }
  });

  // Generate markdown
  let content = `# Tasks — ${product}

**Generated**: ${new Date().toISOString().split('T')[0]}  
**ICD Version**: ${icdVersion}  
**Source**: Generated from PRD claude-exec block  

## Task Rules
${rules ? Object.entries(rules).map(([k, v]) => `- **${k}**: ${v}`).join('\n') : ''}

## Task Breakdown

`;

  tasks.forEach((category, index) => {
    content += `### ${index + 1}. ${category.category}\n\n`;
    content += `| # | Task | Estimate | Owner | Status |\n`;
    content += `|---|------|----------|-------|--------|\n`;
    
    category.items.forEach((item, i) => {
      const estimate = [1, 2, 3, 5, 8][Math.floor(Math.random() * 5)]; // Fibonacci
      content += `| ${index + 1}.${i + 1} | ${item} | ${estimate}h | TBD | ⬜️ |\n`;
    });
    
    content += '\n';
  });

  content += `## Acceptance Criteria

Each task must:
1. Pass automated tests (unit, integration, e2e as applicable)
2. Meet accessibility standards (WCAG 2.1 AA)
3. Stay within performance budget (Lighthouse > 90)
4. Have documentation (inline comments + README updates)
5. Pass code review (including security scan)

## Definition of Done

- [ ] Code complete and pushed to feature branch
- [ ] Tests written and passing
- [ ] Documentation updated
- [ ] Code reviewed and approved
- [ ] Merged to main
- [ ] Deployed to staging
- [ ] Verified in staging
- [ ] Released to production
`;

  return content;
}

// Main execution
async function generateClaudeDocs() {
  const REPO_ROOT = process.cwd();
  const DOCS_PATH = path.join(REPO_ROOT, 'docs');
  
  const prdPath = path.join(DOCS_PATH, 'scout', 'PRD.md');
  const icdPath = path.join(DOCS_PATH, 'scout', 'ICD.md');
  const planningPath = path.join(DOCS_PATH, 'claude', 'planning.md');
  const tasksPath = path.join(DOCS_PATH, 'claude', 'tasks.md');

  // Ensure output directory exists
  const claudeDir = path.join(DOCS_PATH, 'claude');
  if (!fs.existsSync(claudeDir)) {
    fs.mkdirSync(claudeDir, { recursive: true });
  }

  // Read PRD
  const prdContent = fs.readFileSync(prdPath, 'utf-8');
  
  // Extract claude-exec block
  const claudeExecMatch = prdContent.match(/```claude-exec\n([\s\S]*?)```/);
  if (!claudeExecMatch) {
    throw new Error('No claude-exec block found in PRD.md');
  }

  const execConfig = parseClaudeExec(claudeExecMatch[1]);
  
  // Read ICD for interface versions
  const icdContent = fs.readFileSync(icdPath, 'utf-8');
  const versionMatch = icdContent.match(/\*\*Version\*\*:\s*([\d.]+)/);
  const icdVersion = versionMatch ? versionMatch[1] : 'unknown';

  // Generate planning.md
  const planningContent = generatePlanning(execConfig, icdVersion);
  fs.writeFileSync(planningPath, planningContent);
  console.log(`✅ Generated ${planningPath}`);

  // Generate tasks.md
  const tasksContent = generateTasks(execConfig, icdVersion);
  fs.writeFileSync(tasksPath, tasksContent);
  console.log(`✅ Generated ${tasksPath}`);
}

// Run generator
generateClaudeDocs().catch(console.error);
