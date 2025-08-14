# Scout Edge Makefile

# --- Configuration ---
PGURI ?= postgresql://user:pass@localhost:5432/postgres
PG_REST ?= http://localhost:54321/rest/v1
ISKO_URL ?= http://localhost:54321/functions/v1/isko-scraper
SUPABASE_ANON ?= replace-with-anon-key
SUPABASE_PROJECT_REF ?= your-project-ref

# --- Scout Scraper ---
migrate-scout:
	for f in platform/scout/migrations/*.sql; do psql "$(PGURI)" -f "$$f"; done

seed-sources:
	psql "$(PGURI)" -c "select scout.seed_jobs_from_sources(true);"

schedule-recrawl:
	psql "$(PGURI)" -c "select scout.schedule_recrawl();"

worker:
	cd packages/scout-scraper-worker && npm i && npm run build && PG_REST=$(PG_REST) ISKO_URL=$(ISKO_URL) SUPABASE_ANON=$(SUPABASE_ANON) node dist/worker.js

# --- Monitoring ---
scraper-status:
	@echo "=== Dashboard Snapshot ==="
	@psql "$(PGURI)" -c "select * from scout.dashboard_snapshot();"
	@echo ""
	@echo "=== Queue Pressure ==="
	@psql "$(PGURI)" -c "table scout.v_queue_pressure limit 10;"
	@echo ""
	@echo "=== Recent Items ==="
	@psql "$(PGURI)" -c "select brand_name, product_name, pack_size, list_price from scout.v_master_items_recent limit 10;"

scraper-health:
	@psql "$(PGURI)" -c "table scout.v_crawl_health_detailed;"

blocked-jobs:
	@psql "$(PGURI)" -c "table scout.v_blocked_jobs limit 20;"

domain-stats:
	@psql "$(PGURI)" -c "table scout.v_domain_performance;"

# --- Operations ---
throttle-domain:
	@echo "Usage: make throttle-domain DOMAIN=example.com RATE=60000"
	psql "$(PGURI)" -c "select scout.throttle_domain('$(DOMAIN)', $(RATE));"

quarantine-source:
	@echo "Usage: make quarantine-source SOURCE=uuid-here REASON='investigating'"
	psql "$(PGURI)" -c "select scout.quarantine_source('$(SOURCE)'::uuid, '$(REASON)');"

release-quarantine:
	@echo "Usage: make release-quarantine SOURCE=uuid-here"
	psql "$(PGURI)" -c "select scout.release_quarantine('$(SOURCE)'::uuid);"

emergency-stop:
	@echo "⚠️  EMERGENCY STOP - This will halt all scraping!"
	@read -p "Are you sure? [y/N] " confirm && [ "$$confirm" = "y" ] && psql "$(PGURI)" -c "select scout.emergency_stop();"

# --- Testing ---
test-scraper:
	psql "$(PGURI)" -c "select scout.generate_test_results(5);"
	@echo "Test data generated. Check results with: make scraper-status"

# --- Deployment ---
deploy-scraper:
	./scripts/deploy-scraper.sh

deploy-edge-function:
	supabase functions deploy isko-scraper --project-ref $(SUPABASE_PROJECT_REF)

# --- Utilities ---
inspect-job:
	@echo "Usage: make inspect-job JOB_ID=123"
	psql "$(PGURI)" -c "select * from scout.inspect_job($(JOB_ID));"

cleanup-old:
	psql "$(PGURI)" -c "select scout.cleanup_old_jobs();"

# --- Help ---
help:
	@echo "Scout Edge SKU Scraper Commands:"
	@echo ""
	@echo "Setup:"
	@echo "  make migrate-scout      - Run all database migrations"
	@echo "  make seed-sources       - Seed initial scraping jobs"
	@echo "  make deploy-scraper     - Full deployment script"
	@echo ""
	@echo "Operations:"
	@echo "  make worker            - Start a scraper worker"
	@echo "  make scraper-status    - View dashboard snapshot"
	@echo "  make scraper-health    - Detailed health metrics"
	@echo "  make blocked-jobs      - View quarantined jobs"
	@echo "  make domain-stats      - Domain performance stats"
	@echo ""
	@echo "Controls:"
	@echo "  make throttle-domain DOMAIN=x RATE=y  - Throttle domain"
	@echo "  make quarantine-source SOURCE=x       - Block source"
	@echo "  make release-quarantine SOURCE=x      - Unblock source"
	@echo "  make emergency-stop                   - STOP EVERYTHING"
	@echo ""
	@echo "Testing:"
	@echo "  make test-scraper      - Generate test data"
	@echo "  make inspect-job JOB_ID=x - Inspect specific job"

.PHONY: help migrate-scout seed-sources worker scraper-status scraper-health \
        blocked-jobs domain-stats throttle-domain quarantine-source \
        release-quarantine emergency-stop test-scraper deploy-scraper \
        deploy-edge-function inspect-job cleanup-old schedule-recrawl
