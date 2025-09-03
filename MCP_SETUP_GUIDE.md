# Scout MCP Setup Options

## Option 1: Desktop Extension (DXT) - RECOMMENDED ✨

**What it is:** A one-click installable package for Claude Desktop

### Pros:
- ✅ **One-click installation** - No terminal, no config files
- ✅ **Automatic updates** - Extensions update automatically
- ✅ **Secure secrets** - Credentials stored in OS keychain automatically
- ✅ **User-friendly UI** - Configure through Claude Desktop settings
- ✅ **Built-in Node.js** - No need to install dependencies
- ✅ **Easy distribution** - Share a single .dxt file with team

### Installation:
```bash
# Create the DXT package
cd ~/ai-aas-hardened-lakehouse
chmod +x scripts/create-scout-dxt.sh
./scripts/create-scout-dxt.sh

# Then in Claude Desktop:
# Settings → Extensions → Install from file → Select scout-mcp.dxt
```

### File Structure:
```
scout-mcp.dxt (ZIP archive)
├── manifest.json         # Extension metadata
├── icon.png             # Extension icon
├── server/              # MCP server code
│   ├── dist/index.js    # Compiled server
│   └── package.json     # Dependencies
└── node_modules/        # Bundled dependencies
```

---

## Option 2: Manual MCP Server - ADVANCED 🔧

**What it is:** Traditional MCP server setup with manual configuration

### Pros:
- ✅ More control over configuration
- ✅ Can modify server code easily
- ✅ Good for development/debugging

### Cons:
- ❌ Manual JSON config editing
- ❌ Manage dependencies yourself
- ❌ Store credentials manually in Keychain
- ❌ No automatic updates
- ❌ Restart Claude Desktop after changes

### Installation:
```bash
# Run the finalization script
cd ~/ai-aas-hardened-lakehouse
./scripts/finalize-scout-mcp.sh

# Store DATABASE_URL in Keychain
DATABASE_URL='postgresql://...' \
KC_SERVICE=ai-aas-hardened-lakehouse.supabase \
~/.local/bin/kc-set-supabase.sh

# Edit Claude config manually
# ~/.claude/claude_desktop_config.json
```

---

## Comparison Table

| Feature | DXT (Desktop Extension) | Manual MCP |
|---------|-------------------------|------------|
| Installation | One-click | Manual setup |
| Configuration | UI in Claude Desktop | Edit JSON files |
| Credentials | Auto-stored in keychain | Manual keychain setup |
| Updates | Automatic | Manual rebuild |
| Distribution | Single .dxt file | Share scripts & docs |
| Node.js | Built-in | Must install |
| Debugging | Limited | Full access |
| Team sharing | ✅ Easy | ❌ Complex |

---

## Recommendation

**For most users:** Use the **DXT (Desktop Extension)** approach
- Easier to install and maintain
- Better user experience
- Secure by default
- Team-friendly

**For developers:** Start with DXT, use manual for debugging
- DXT for production use
- Manual setup for development
- Can have both installed

---

## Quick Start

```bash
# Create both options
cd ~/ai-aas-hardened-lakehouse

# Option 1: Create DXT (Recommended)
chmod +x scripts/create-scout-dxt.sh
./scripts/create-scout-dxt.sh

# Option 2: Manual setup (if needed)
chmod +x scripts/finalize-scout-mcp.sh
./scripts/finalize-scout-mcp.sh
```

Then install the DXT file in Claude Desktop for the best experience!
