#!/usr/bin/env node
import * as fs from 'fs';
import * as path from 'path';
import * as yaml from 'js-yaml';
import { marked } from 'marked';

const REPO_ROOT = path.resolve(process.cwd());
const DOCS_PATH = path.join(REPO_ROOT, 'docs');

/**
 * Parse claude-exec blocks from PRD and generate tasks/planning
 */
async function generateClaudeDocs() {
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

  const execConfig = yaml.load(claudeExecMatch[1]);
  
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

/**
 * Generate planning.md from config
 */
function generatePlanning(config, icdVersion) {
  const { product, goals, constraints } = config;
  
  return `# ${product} — 4-Week Execution Plan

**Generated**: ${new Date().toISOString().split('T')[0]}  
**Source**: docs/scout/PRD.md (ICD v${icdVersion})  
**Status**: Auto-generated from claude-exec block  

## Goals
${goals.map((g, i) => `${i + 1}. ${g}`).join('\n')}

## Constraints
${constraints.map(c => `- ${c}`).join('\n')}

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
${constraints.map(c => `- ✅ ${c}`).join('\n')}
- ✅ All ICD endpoints implemented and tested
- ✅ Zero critical/high security findings
- ✅ Documentation complete and reviewed
`;
}

/**
 * Generate tasks.md from config
 */
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
${Object.entries(rules).map(([k, v]) => `- **${k}**: ${v}`).join('\n')}

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

// Run generator
generateClaudeDocs().catch(console.error);
