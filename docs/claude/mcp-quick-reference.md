# MCP Quick Reference Card 🚀

## 🔧 Essential Commands

```bash
# Validate Code Connect mappings
pnpm run figma:connect:validate

# Create new component stub
./scripts/agents/superclaude.sh figma:stub ComponentName

# Test publish (dry run)
pnpm run figma:connect:publish

# Check MCP server health
curl http://127.0.0.1:3845/health
```

## 🎨 For Designers

**✅ What works in Figma Preview:**
- Interactive Scout Dashboard
- Real component props and states
- Mock data (safe, no credentials needed)
- Error states handled gracefully

**🔗 Getting Component Links:**
1. Open Figma in **Dev Mode**
2. Navigate to your component
3. **Right sidebar** → "Copy link"
4. Extract `FILE_KEY` and `NODE_ID` from URL

## 👨‍💻 For Developers

**📁 Key File Locations:**
```
apps/scout-ui/src/components/
├── Kpi/
│   ├── KpiTile.tsx           # React component
│   └── KpiTile.figma.tsx     # Code Connect mapping
└── YourComponent/
    ├── YourComponent.tsx
    └── YourComponent.figma.tsx
```

**🔄 Workflow:**
1. Update React component
2. Update `.figma.tsx` mapping
3. Run `pnpm run figma:connect:validate`
4. Figma reflects changes automatically

## 🚨 Common Fixes

**SelectItem Empty Values:**
```typescript
// ❌ Don't do this
<SelectItem value="">All Items</SelectItem>

// ✅ Do this instead
<SelectItem value="all-items">All Items</SelectItem>
```

**Mock vs Live Data:**
```typescript
// Use conditional loading
const data = isFigmaPreview 
  ? mockScoutData 
  : await getScoutMetrics();
```

## 📍 Current Status

| Component | Status |
|-----------|---------|
| **MCP Server** | ✅ Active at `127.0.0.1:3845` |
| **Code Connect** | ✅ Token-free |
| **Figma Preview** | ✅ Mock data |
| **Repo RPCs** | ✅ Live Supabase |

## 🆘 Need Help?

- **MCP Issues**: Check `docs/claude/mcp-integration.md`
- **Code Connect**: Check `figma.config.json`
- **Component Errors**: Run `pnpm run figma:connect:validate`
- **Missing Props**: Update `.figma.tsx` mapping

---
💡 **Pro Tip**: Keep this tab open while working with Figma + Scout Dashboard