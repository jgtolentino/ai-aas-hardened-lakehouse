# Scout Edge Makefile

# --- Scout Scraper ---
PGURI ?= postgresql://user:pass@localhost:5432/postgres
PG_REST ?= http://localhost:54321/rest/v1
ISKO_URL ?= http://localhost:54321/functions/v1/isko-scraper
SUPABASE_ANON ?= replace-with-anon-key

migrate-scout:
	for f in platform/scout/migrations/*.sql; do psql "$(PGURI)" -f "$$f"; done

seed-sources:
	psql "$(PGURI)" -c "select scout.seed_jobs_from_sources(true);"

schedule-recrawl:
	psql "$(PGURI)" -c "select scout.schedule_recrawl();"

worker:
	cd packages/scout-scraper-worker && npm i && npm run build && PG_REST=$(PG_REST) ISKO_URL=$(ISKO_URL) SUPABASE_ANON=$(SUPABASE_ANON) node dist/worker.js

scraper-status:
	@echo "Queue Pressure:"
	@psql "$(PGURI)" -c "table scout.v_queue_pressure limit 10;"
	@echo ""
	@echo "Crawl Health:"
	@psql "$(PGURI)" -c "table scout.v_crawl_health;"
