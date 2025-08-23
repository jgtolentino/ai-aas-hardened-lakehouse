# 🏗️ AI-AAS-Hardened-Lakehouse Architecture & Sync

## 🎯 Complete System Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                     AI-AAS-HARDENED-LAKEHOUSE                       │
│                   (Main Enterprise Repository)                       │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌─────────────────┐    ┌─────────────────┐    ┌────────────────┐ │
│  │   SUPABASE DB   │    │    FRONTEND     │    │   BACKEND      │ │
│  │                 │    │                 │    │                │ │
│  │ • Scout Schema  │◄───┤ • Dashboard UI  │◄───┤ • API Service  │ │
│  │ • Analytics     │    │ • Scout Module  │    │ • Worker Jobs  │ │
│  │ • Warehouse     │    │ • Admin Panel   │    │ • ETL Process  │ │
│  └────────┬────────┘    └────────┬────────┘    └───────┬────────┘ │
│           │                      │                      │          │
│           └──────────────────────┴──────────────────────┘          │
│                                 │                                   │
│                          [.env.local]                               │
│                     Central Configuration                           │
└─────────────────────────────────────────────────────────────────────┘

                                 ▼
                        [Sync Scripts]
                    ./scripts/sync-supabase.sh
```

## 📁 Directory Structure & Purpose

```
ai-aas-hardened-lakehouse/
│
├── 📄 .env.local                    # ← SINGLE SOURCE OF TRUTH
│   └── All Supabase credentials
│
├── 📁 supabase/                     # Database Configuration
│   ├── migrations/                  # Schema changes
│   ├── functions/                   # Edge Functions
│   └── config.toml                  # Supabase config
│
├── 📁 platform/scout/               # Scout Analytics Platform
│   ├── scout-databank/             # 🔗 SUBMODULE (Next.js)
│   │   └── Full Scout Dashboard UI
│   └── migrations/                  # Scout-specific migrations
│
├── 📁 services/                     # Microservices
│   ├── dashboard/                   # Main Dashboard (Vite+React)
│   │   ├── src/config/supabase.ts  # Auto-generated config
│   │   └── .env                    # Vite-specific env
│   ├── api/                        # Backend API (Node.js)
│   │   └── .env                    # API env (synced)
│   └── worker/                     # Background Jobs (Python)
│       └── .env                    # Worker env (synced)
│
└── 📁 scripts/                      # Automation
    └── sync-supabase.sh            # Master sync script
```

## 🔄 Sync Flow Diagram

```
1. MANUAL UPDATE
   └─> Update scout-databank-new/.env.local
       └─> Run: ./scripts/rotate-supabase-token.sh

2. SYNC TO LAKEHOUSE
   └─> cd ai-aas-hardened-lakehouse
       └─> ./scripts/sync-supabase.sh
           ├─> Copies .env.local from scout-databank-new
           ├─> Distributes to all services/
           ├─> Updates frontend configs
           └─> Verifies connectivity

3. DEVELOPMENT
   └─> npm run dev
       ├─> Starts API on :3000
       ├─> Starts Dashboard on :5173
       └─> All using same Supabase instance
```

## 🚀 Quick Commands

### Full System Sync & Start
```bash
cd ~/Documents/GitHub/ai-aas-hardened-lakehouse
./scripts/sync-supabase.sh
npm install
npm run dev
```

### Individual Service Commands
```bash
# Dashboard only
npm run dev:dashboard
# → http://localhost:5173

# API only  
npm run dev:api
# → http://localhost:3000

# Scout submodule
npm run dev:scout
# → http://localhost:3001
```

### Database Operations
```bash
# Apply migrations
npm run migrate

# Deploy Edge Functions
npm run deploy:functions

# Check database status
npx supabase db remote status
```

## 🔐 Environment Variables Flow

```
~/.zshrc (Shell Environment)
    ├─> SUPABASE_ACCESS_TOKEN
    ├─> SUPABASE_PROJECT_REF
    └─> SUPABASE_URL
         │
         ▼
scout-databank-new/.env.local
         │
         ▼ (sync-supabase.sh)
         │
ai-aas-hardened-lakehouse/.env.local
         │
         ├─> services/dashboard/.env (VITE_ prefixed)
         ├─> services/api/.env
         ├─> services/worker/.env
         └─> platform/scout/scout-databank/.env.local
```

## 📊 Supabase Data Flow

```
Supabase Cloud (cxzllzyxwpyptfretryc)
         │
         ├─> REST API (PostgREST)
         │   └─> Consumed by all frontends
         │
         ├─> Realtime (WebSockets)
         │   └─> Live updates to dashboards
         │
         └─> Edge Functions
             └─> Business logic & AI processing
```

## 🛠️ Troubleshooting

### Issue: Submodule not updating
```bash
git submodule update --init --recursive --remote
cd platform/scout/scout-databank && git pull origin main
```

### Issue: Environment variables not loading
```bash
# Verify .env.local exists
cat .env.local | grep SUPABASE

# Re-run sync
./scripts/sync-supabase.sh
```

### Issue: Frontend can't connect to Supabase
```bash
# Check CORS settings in Supabase Dashboard
# Project Settings → API → Allowed Origins
# Add: http://localhost:5173, http://localhost:3001
```

## 🎯 Best Practices

1. **Always sync after token rotation**
   ```bash
   cd scout-databank-new
   ./scripts/rotate-supabase-token.sh sbp_new_token_here
   cd ../ai-aas-hardened-lakehouse
   ./scripts/sync-supabase.sh
   ```

2. **Keep submodules updated**
   ```bash
   git submodule update --remote --merge
   ```

3. **Test connectivity after sync**
   ```bash
   curl -H "apikey: $SUPABASE_ANON_KEY" $SUPABASE_URL/rest/v1/
   ```

4. **Use unified commands**
   ```bash
   npm run sync     # Sync everything
   npm run dev      # Start all services
   npm run build:all # Build all frontends
   ```

---

**Remember**: The lakehouse is your enterprise platform. Keep it synced! 🚀