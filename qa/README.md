# QA Browser-Use MCP + Google ADK

AI-powered browser automation framework for the Scout Analytics platform.

## Features

- ✅ **End-to-End Testing** – Automates flows (login, checkout, forms)
- ✅ **Regression Testing with AI Insights** – Detects functional and subtle performance changes
- ✅ **Price & Data Validation** – Compares live data to expected values
- ✅ **Cross-Browser Checks** – Chrome, Firefox, Edge support
- 📊 **Supabase Integration** – Results stored for dashboarding
- 🚀 **CI/CD Ready** – GitHub Actions with browser matrix

## Quick Start

### Local Development

1. **Install dependencies**:
   ```bash
   cd qa
   npm install
   ```

2. **Configure environment**:
   ```bash
   cp config/qa.env.example config/qa.env
   # Edit qa.env with your values
   ```

3. **Start MCP server** (in one terminal):
   ```bash
   npm run dev:mcp
   ```

4. **Run tests** (in another terminal):
   ```bash
   # Run all flows
   npm run run
   
   # Run specific flow
   npm run run flows/login_checkout.yaml
   ```

### Environment Variables

- `QA_BASE_URL` - Base URL of application under test
- `BROWSERS` - Comma-separated list (chrome,firefox)
- `SUPABASE_URL` - Supabase project URL
- `SUPABASE_SERVICE_KEY` - Service role key for results
- `MCP_BROWSER_USE_URL` - MCP server URL (default: http://127.0.0.1:5173)

## Writing Test Flows

Flows are defined in YAML format in the `flows/` directory:

```yaml
meta:
  id: unique_flow_id
  description: "What this flow tests"
  tags: [smoke, regression]
  
setup:
  baseUrl: "${QA_BASE_URL}"
  browserMatrix: "${BROWSERS}"
  
steps:
  - navigate: "/path"
  - waitFor: { selector: 'input[name="email"]' }
  - type: { selector: 'input[name="email"]', text: "user@example.com" }
  - click: { text: "Submit" }
  - assert: { condition: 'url.includes("/success")', message: "Should redirect" }
  - screenshot: "artifacts/success.png"
```

### Available Actions

- `navigate: "/path"` - Navigate to URL
- `click: { selector: "css" }` or `{ text: "Button Text" }` or `{ role: "button", name: "Submit" }`
- `type: { selector: "css", text: "value" }`
- `waitFor: { selector: "css" }` or `{ event: "load" }`
- `extract: { selector: "css", as: "variableName" }`
- `assert: { condition: "js expression", message: "error message" }`
- `screenshot: "path/to/save.png"`

### Assertions

Assertions use JavaScript expressions with helpers:
- `url` - Current page URL
- `innerText(selector)` - Get text content
- `document.*` - DOM access
- `ctx.variableName` - Access extracted values
- `normalizeCurrency(text)` - Strip non-numeric from prices

## CI/CD Integration

The framework includes GitHub Actions workflow that:
1. Runs tests in Chrome and Firefox
2. Uploads screenshots and reports as artifacts
3. Stores results in Supabase

To enable CI:
```bash
# Set GitHub secrets
gh secret set SUPABASE_URL --body "https://your-project.supabase.co"
gh secret set SUPABASE_SERVICE_KEY --body "your-service-key"

# Set variables
gh variable set QA_BASE_URL --body "https://staging.example.com"
```

## Results & Reporting

### Artifacts
- `artifacts/*.junit.xml` - JUnit format for CI
- `artifacts/*.report.json` - Detailed JSON results
- `artifacts/*.png` - Screenshots

### Supabase Tables
- `scout.qa_runs` - Test execution history
- `scout.qa_findings` - Issues found during tests
- `scout.vw_qa_summary` - Dashboard view with pass rates
- `scout.vw_qa_recent_failures` - Recent failures for triage

### Scout Dashboard Integration

Query results for dashboarding:
```sql
-- Pass rate by flow
SELECT * FROM scout.vw_qa_summary
ORDER BY pass_rate ASC, last_run DESC;

-- Recent failures
SELECT * FROM scout.vw_qa_recent_failures;
```

## Architecture

```
[YAML Flows] → [TypeScript Runner] → [MCP Client] → [Browser-Use MCP Server] → [Browser]
                                           ↓
                                    [Supabase Results]
```

## Best Practices

1. **Deterministic Tests**: Always use explicit assertions, not AI judgment
2. **Stable Selectors**: Prefer `data-test` attributes over CSS classes
3. **Error Handling**: Capture screenshots on failure
4. **Timeouts**: Set reasonable `waitFor` limits (5-10s)
5. **Test Data**: Use dedicated test accounts/data
6. **Browser Matrix**: Test critical flows in multiple browsers

## Troubleshooting

### MCP Server Not Starting
```bash
# Check if port is in use
lsof -i :5173

# Start with debug logging
DEBUG=* npm run dev:mcp
```

### Tests Failing Locally
```bash
# Run with headed browser for debugging
npx browser-use-mcp@latest --port 5173  # No --headless flag
```

### Supabase Connection Issues
```bash
# Test connection
npx supabase db remote list --project-ref your-project-ref
```

## Extending the Framework

### Add New Flow
1. Create `flows/your_flow.yaml`
2. Define steps using available actions
3. Run with `npm run run flows/your_flow.yaml`

### Add Custom Helper
Edit `runner/index.ts`:
```typescript
// Add to global helpers
(globalThis as any).yourHelper = (param: string) => {
  // Your logic
};
```

### Add Reporter
Create `runner/reporters/your-reporter.ts`:
```typescript
export async function reportResults(results: any[]) {
  // Your reporting logic
}
```

## License

Part of the Scout Analytics Platform