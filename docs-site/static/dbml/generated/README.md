# Scout v3 ERD Generated Files

## Files Generated

1. **scout-v3.sql** - PostgreSQL DDL (ready to deploy)
2. **scout-v3-erd.puml** - PlantUML diagram source
3. **scout-v3-for-dbdiagram.dbml** - DBML for dbdiagram.io
4. **scout-v3-summary.md** - Schema summary statistics

## View ERD Options

### Option 1: dbdiagram.io (Recommended - Interactive)
1. Go to https://dbdiagram.io/
2. Click "Import" → "From DBML"
3. Upload `scout-v3-for-dbdiagram.dbml`
4. Explore interactively, export as PNG/PDF

### Option 2: PlantUML (Local Generation)
```bash
# Install PlantUML if needed
brew install plantuml

# Generate PNG
plantuml scout-v3-erd.puml

# This creates scout-v3-erd.png
```

### Option 3: Online PlantUML
1. Go to http://www.plantuml.com/plantuml/uml
2. Copy contents of `scout-v3-erd.puml`
3. Paste and click "Submit"

### Option 4: VS Code Extension
1. Install "PlantUML" extension
2. Open `scout-v3-erd.puml`
3. Press Alt+D to preview
4. Right-click → Export as PNG

## Schema Statistics

- **Total Tables**: 51 base tables (+ 30 more in actual deployment)
- **Schemas**: scout, bronze, silver, gold, master_data, deep_research
- **Relationships**: 29 foreign key relationships
- **Analytics Views**: 120+ (not shown in ERD)

## Quick SQL Deployment
```bash
# Deploy to Supabase
psql "$SUPABASE_DB_URL" -f scout-v3.sql
```