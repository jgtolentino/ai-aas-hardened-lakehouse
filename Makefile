SHELL := /bin/bash

.PHONY: sec audit rls mcp-check dev-next dev-vite deploy-next story preflight hub hub-dev hub-openapi hub-tunnel sb-push sb-diff

preflight: sec audit rls

sb-push:
	SUPABASE_ACCESS_TOKEN=$$SUPABASE_ACCESS_TOKEN SUPABASE_PROJECT_REF=$$SUPABASE_PROJECT_REF bash scripts/supabase/db_push.sh

sb-diff:
	SUPABASE_ACCESS_TOKEN=$$SUPABASE_ACCESS_TOKEN SUPABASE_PROJECT_REF=$$SUPABASE_PROJECT_REF SUPABASE_DB_URL=$$SUPABASE_DB_URL bash scripts/supabase/db_diff_commit.sh

hub:
	cd infra/mcp-hub && pnpm i && pnpm start

hub-dev:
	cd infra/mcp-hub && pnpm i && pnpm dev

hub-openapi:
	cd infra/mcp-hub && pnpm i && pnpm openapi:print

hub-tunnel:
	cloudflared tunnel run mcp-hub

sec:
	scripts/security/scan_secrets.sh

audit:
	scripts/security/pre_deploy_audit.sh

rls:
	node scripts/qa/supabase_rls_smoke.mjs

mcp-check:
	scripts/mcp/full_stack_check.sh

dev-next:
	pnpm --filter ./apps/scout-dashboard dev

dev-vite:
	pnpm --filter ./apps/scout-ui dev

deploy-next:
	cd apps/scout-dashboard && vercel --prod

story:
	pnpm --filter ./apps/scout-ui storybook
