# Scout Platform MCP Configuration

## Overview
This document describes the Model Context Protocol (MCP) server configuration for the Scout Platform, enabling automated browser testing and AI reasoning tracking.

## MCP Servers Configured

### 1. Playwright MCP Server
Enables browser automation for testing Scout dashboards.

**Package**: `@playwright/mcp@latest`  
**Purpose**: Automated UI testing, screenshot verification, accessibility testing

**Configuration**:
```json
{
  "playwright": {
    "command": "npx",
    "args": [
      "-y",
      "@playwright/mcp@latest",
      "--browser", "chromium",
      "--headless"
    ],
    "env": {
      "VIEWPORT_WIDTH": "1280",
      "VIEWPORT_HEIGHT": "720"
    }
  }
}
```

### 2. Puppeteer MCP Server
Provides browser automation capabilities for Scout Platform testing.

**Package**: `@modelcontextprotocol/server-puppeteer@latest`  
**Purpose**: Web scraping, PDF generation, performance monitoring

**Configuration**:
```json
{
  "puppeteer": {
    "command": "npx",
    "args": [
      "-y",
      "@modelcontextprotocol/server-puppeteer@latest",
      "--url", "http://localhost:3000"
    ],
    "env": {
      "PUPPETEER_HEADLESS": "true",
      "PUPPETEER_EXECUTABLE_PATH": "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
    }
  }
}
```

### 3. Supabase MCP Server
Direct database access for Scout Platform data operations with full service role access.

**Package**: `@supabase/mcp-server-supabase@latest`  
**Purpose**: Database queries, migrations, real-time data access, edge functions, storage operations

**Configuration**:
```json
{
  "supabase_primary": {
    "command": "npx",
    "args": [
      "-y",
      "@supabase/mcp-server-supabase@latest",
      "--project-ref=cxzllzyxwpyptfretryc",
      "--feature-groups=database,projects,functions,storage,secrets"
    ],
    "env": {
      "SUPABASE_ACCESS_TOKEN": "sbp_05fcd9a214adbb2721dd54f2f39478e5efcbeffa",
      "SUPABASE_ROLE": "service_role"
    }
  },
  "supabase_alternate": {
    "command": "npx",
    "args": [
      "-y",
      "@supabase/mcp-server-supabase@latest",
      "--project-ref=texxwmlroefdisgxpszc",
      "--feature-groups=database,projects,functions,storage,secrets"
    ],
    "env": {
      "SUPABASE_ACCESS_TOKEN": "sbp_05fcd9a214adbb2721dd54f2f39478e5efcbeffa",
      "SUPABASE_ROLE": "service_role"
    }
  }
}
```

## Scout Databank Submodule

The scout-databank dashboard is integrated as a git submodule:

```bash
# Location
platform/scout/scout-databank/

# Repository
https://github.com/jgtolentino/scout-databank-isolated.git

# Update submodule
git submodule update --init --recursive

# Pull latest changes
cd platform/scout/scout-databank
git pull origin main
```

## AI Reasoning Tracking

The scout-databank includes comprehensive AI reasoning tracking:

### Features
- **Reasoning Chain Tracking**: Step-by-step AI decision logging
- **Model Performance Metrics**: Latency, confidence, accuracy tracking
- **Drift Detection**: Automatic detection of model behavior changes
- **Feedback Loops**: User feedback integration for model improvement
- **Confidence Calibration**: Alignment of predicted vs actual confidence

### Database Schema
```sql
-- AI reasoning chains
scout.ai_reasoning_chains
scout.ai_model_performance
scout.ai_confidence_calibration
scout.ai_model_drift
scout.ai_feedback
```

### Edge Functions
- `ai-reasoning-tracker`: Tracks and analyzes AI reasoning processes

### Monitoring Component
- `AIReasoningMonitor.tsx`: Real-time dashboard for AI metrics

## Testing with MCP Servers

### Playwright Testing
```javascript
// Example: Verify Scout dashboard deployment
const { chromium } = require('playwright');

async function verifyScoutDashboard() {
  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage();
  
  await page.goto('http://localhost:3000/dashboard');
  await page.waitForSelector('.scout-dashboard');
  
  const errors = [];
  page.on('console', msg => {
    if (msg.type() === 'error') errors.push(msg.text());
  });
  
  await page.screenshot({ path: 'scout-dashboard-verify.png' });
  
  console.log('Errors:', errors.length === 0 ? 'None' : errors);
  await browser.close();
}
```

### Puppeteer Testing
```javascript
// Example: Generate Scout dashboard PDF report
const puppeteer = require('puppeteer');

async function generateScoutReport() {
  const browser = await puppeteer.launch({ headless: true });
  const page = await browser.newPage();
  
  await page.goto('http://localhost:3000/dashboard', {
    waitUntil: 'networkidle0'
  });
  
  await page.pdf({ 
    path: 'scout-dashboard-report.pdf',
    format: 'A4',
    printBackground: true
  });
  
  await browser.close();
}
```

## Configuration Files

### Local MCP Configuration
Create `.mcp.json` in project root:
```bash
cp platform/scout/scout-databank/.mcp.json .mcp.json
```

### Claude Desktop Configuration
Add to `~/Library/Application Support/Claude/claude_desktop_config.json`:
```json
{
  "mcpServers": {
    // ... existing servers ...
    "scout_testing": {
      "command": "npx",
      "args": [
        "-y",
        "@playwright/mcp@latest",
        "--browser", "chromium",
        "--headless"
      ],
      "env": {
        "SCOUT_DASHBOARD_URL": "http://localhost:3000"
      }
    }
  }
}
```

## Usage in Claude

```
# Test Scout dashboard
Using scout_testing MCP server, verify the Scout dashboard is working correctly

# Generate performance report
Using puppeteer MCP server, generate a PDF report of Scout dashboard metrics

# Query Scout data
Using supabase_primary, show me the latest Scout platform metrics
```

## Maintenance

### Update MCP servers
```bash
# Update all MCP packages
npm update @playwright/mcp@latest
npm update @modelcontextprotocol/server-puppeteer@latest
npm update @supabase/mcp-server-supabase@latest
```

### Update scout-databank submodule
```bash
cd platform/scout/scout-databank
git checkout main
git pull origin main
cd ../../../
git add platform/scout/scout-databank
git commit -m "Update scout-databank submodule"
```

## Troubleshooting

### MCP server not starting
1. Check node/npm versions: `node -v` (should be 18+)
2. Clear npm cache: `npm cache clean --force`
3. Reinstall packages: `rm -rf node_modules && npm install`

### Browser automation fails
1. Ensure Chrome/Chromium is installed
2. Check executable path in configuration
3. Verify no other processes using the ports

### Supabase connection issues
1. Verify access token is valid
2. Check project reference is correct
3. Ensure network connectivity to Supabase

## Related Documentation

- [Scout Dashboard README](scout-databank/README.md)
- [AI Reasoning Tracking](scout-databank/docs/AI_REASONING_TRACKING.md)
- [Platform Integration Guide](DASHBOARD_INTEGRATION.md)