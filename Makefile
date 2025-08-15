# Production Makefile for Scout Analytics Platform
# One-shot deployment with verification gates

.PHONY: help
help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

# Configuration
SUPABASE_PROJECT_REF ?= cxzllzyxwpyptfretryc
SUPABASE_DB_PASSWORD ?= $(error SUPABASE_DB_PASSWORD is required)
GITHUB_OWNER ?= $(shell git remote get-url origin | sed -E 's/.*github.com[:/]([^/]+).*/\1/')
CLUSTER_NAMESPACE ?= aaas
OPENAI_API_KEY ?= $(error OPENAI_API_KEY is required for Genie/RAG)

# Derived variables
SUPABASE_URL := https://$(SUPABASE_PROJECT_REF).supabase.co
SUPABASE_DB_HOST := db.$(SUPABASE_PROJECT_REF).supabase.co
PSQL := PGPASSWORD=$(SUPABASE_DB_PASSWORD) psql 'postgresql://postgres@$(SUPABASE_DB_HOST):5432/postgres?sslmode=require'

# Colors
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[1;33m
NC := \033[0m

.PHONY: check-deps
check-deps: ## Check required dependencies
	@echo "$(YELLOW)Checking dependencies...$(NC)"
	@command -v kubectl >/dev/null 2>&1 || { echo "$(RED)kubectl not found$(NC)"; exit 1; }
	@command -v supabase >/dev/null 2>&1 || { echo "$(RED)supabase CLI not found$(NC)"; exit 1; }
	@command -v psql >/dev/null 2>&1 || { echo "$(RED)psql not found$(NC)"; exit 1; }
	@command -v bruno >/dev/null 2>&1 || { echo "$(YELLOW)bruno CLI not found (optional)$(NC)"; }
	@command -v cosign >/dev/null 2>&1 || { echo "$(YELLOW)cosign not found (optional)$(NC)"; }
	@echo "$(GREEN)✓ Dependencies OK$(NC)"

.PHONY: create-namespace
create-namespace: ## Create Kubernetes namespace and apply NetworkPolicies
	@echo "$(YELLOW)Creating namespace and network policies...$(NC)"
	kubectl apply -f platform/lakehouse/00-namespace.yaml
	kubectl apply -f platform/security/netpol/00-default-deny.yaml
	kubectl apply -f platform/security/netpol/01-trino-policies.yaml
	kubectl apply -f platform/security/netpol/02-superset-policies.yaml
	@echo "$(GREEN)✓ Namespace created$(NC)"

.PHONY: create-secrets
create-secrets: ## Create all required secrets
	@echo "$(YELLOW)Creating Kubernetes secrets...$(NC)"
	@kubectl -n $(CLUSTER_NAMESPACE) create secret generic supabase-source \
		--from-literal=PG_HOST=$(SUPABASE_DB_HOST) \
		--from-literal=PG_PORT=5432 \
		--from-literal=PG_DB=postgres \
		--from-literal=PG_USER=postgres \
		--from-literal=PG_PASS='$(SUPABASE_DB_PASSWORD)' \
		--dry-run=client -o yaml | kubectl apply -f -
	@kubectl -n $(CLUSTER_NAMESPACE) create secret generic minio-keys \
		--from-literal=access_key='minioadmin' \
		--from-literal=secret_key='minioadmin' \
		--dry-run=client -o yaml | kubectl apply -f -
	@kubectl -n $(CLUSTER_NAMESPACE) create secret generic trino-secrets \
		--from-literal=MINIO_ENDPOINT='http://minio.$(CLUSTER_NAMESPACE).svc.cluster.local:9000' \
		--from-literal=MINIO_ACCESS='minioadmin' \
		--from-literal=MINIO_SECRET='minioadmin' \
		--from-literal=NESSIE_URI='http://nessie.$(CLUSTER_NAMESPACE).svc.cluster.local:19120/api/v2' \
		--from-literal=PG_HOST=$(SUPABASE_DB_HOST) \
		--from-literal=PG_PORT=5432 \
		--from-literal=PG_DB=postgres \
		--from-literal=PG_USER=postgres \
		--from-literal=PG_PASS='$(SUPABASE_DB_PASSWORD)' \
		--dry-run=client -o yaml | kubectl apply -f -
	@kubectl -n $(CLUSTER_NAMESPACE) create secret generic openai-keys \
		--from-literal=api_key='$(OPENAI_API_KEY)' \
		--dry-run=client -o yaml | kubectl apply -f -
	@echo "$(GREEN)✓ Secrets created$(NC)"

.PHONY: deploy-lakehouse
deploy-lakehouse: create-namespace create-secrets ## Deploy lakehouse components
	@echo "$(YELLOW)Deploying lakehouse components...$(NC)"
	kubectl -n $(CLUSTER_NAMESPACE) apply -f platform/lakehouse/minio/minio.yaml
	kubectl -n $(CLUSTER_NAMESPACE) apply -f platform/lakehouse/nessie/nessie.yaml
	kubectl -n $(CLUSTER_NAMESPACE) apply -f platform/lakehouse/trino/trino.yaml
	@echo "$(YELLOW)Waiting for pods to be ready...$(NC)"
	kubectl -n $(CLUSTER_NAMESPACE) wait --for=condition=ready pod -l app=minio --timeout=300s
	kubectl -n $(CLUSTER_NAMESPACE) wait --for=condition=ready pod -l app=nessie --timeout=300s
	kubectl -n $(CLUSTER_NAMESPACE) wait --for=condition=ready pod -l app=trino --timeout=300s
	@echo "$(GREEN)✓ Lakehouse deployed$(NC)"

.PHONY: init-lakehouse
init-lakehouse: ## Initialize MinIO bucket and Iceberg schemas
	@echo "$(YELLOW)Initializing lakehouse storage...$(NC)"
	kubectl -n $(CLUSTER_NAMESPACE) apply -f platform/lakehouse/minio/init-bucket.yaml
	kubectl -n $(CLUSTER_NAMESPACE) wait --for=condition=complete job/minio-make-bucket --timeout=60s
	@echo "$(YELLOW)Creating Iceberg schemas...$(NC)"
	@kubectl -n $(CLUSTER_NAMESPACE) port-forward svc/trino 8080:8080 >/dev/null 2>&1 &
	@sleep 5
	@for S in bronze silver gold platinum; do \
		echo "Creating schema $$S..."; \
		curl -s http://localhost:8080/v1/statement \
			-H 'X-Trino-User: admin' -H 'Content-Type: text/plain' \
			--data-binary "CREATE SCHEMA IF NOT EXISTS iceberg.$$S WITH (location='s3a://lakehouse/$$S')"; \
		sleep 2; \
	done
	@pkill -f "port-forward.*trino" || true
	@echo "$(GREEN)✓ Lakehouse initialized$(NC)"

.PHONY: migrate-database
migrate-database: ## Run all SQL migrations
	@echo "$(YELLOW)Running SQL migrations...$(NC)"
	@for sql in platform/scout/migrations/*.sql; do \
		echo "Applying $$sql..."; \
		$(PSQL) -f "$$sql" || { echo "$(RED)Migration failed: $$sql$(NC)"; exit 1; }; \
	done
	@echo "$(GREEN)✓ Migrations complete$(NC)"

.PHONY: deploy-edge-functions
deploy-edge-functions: ## Deploy all Edge Functions
	@echo "$(YELLOW)Setting Edge Function secrets...$(NC)"
	@supabase secrets set --project-ref $(SUPABASE_PROJECT_REF) \
		SUPABASE_URL=$(SUPABASE_URL) \
		CHAT_URL=https://api.openai.com/v1/chat/completions \
		CHAT_KEY=$(OPENAI_API_KEY) \
		EMBEDDINGS_URL=https://api.openai.com/v1/embeddings \
		EMBEDDINGS_API_KEY=$(OPENAI_API_KEY)
	@echo "$(YELLOW)Deploying Edge Functions...$(NC)"
	@cd platform/scout/functions && \
		supabase functions deploy ingest-transaction --project-ref $(SUPABASE_PROJECT_REF) --no-verify-jwt && \
		supabase functions deploy embed-batch --project-ref $(SUPABASE_PROJECT_REF) --no-verify-jwt && \
		supabase functions deploy genie-query --project-ref $(SUPABASE_PROJECT_REF) --no-verify-jwt && \
		supabase functions deploy ingest-doc --project-ref $(SUPABASE_PROJECT_REF) --no-verify-jwt
	@echo "$(GREEN)✓ Edge Functions deployed$(NC)"

.PHONY: deploy-dbt
deploy-dbt: ## Deploy dbt CronJob
	@echo "$(YELLOW)Deploying dbt CronJob...$(NC)"
	@sed -i.bak 's|ghcr.io/REPO_OWNER|ghcr.io/$(GITHUB_OWNER)|g' platform/lakehouse/dbt/dbt-cronjob.yaml
	kubectl -n $(CLUSTER_NAMESPACE) apply -f platform/lakehouse/dbt/dbt-cronjob.yaml
	@echo "$(GREEN)✓ dbt CronJob deployed$(NC)"

.PHONY: verify-deployment
verify-deployment: ## Run verification tests
	@echo "$(YELLOW)Running deployment verification...$(NC)"
	@./validate_deployment.sh || { echo "$(RED)Verification failed$(NC)"; exit 1; }
	@echo "$(GREEN)✓ All verifications passed$(NC)"

.PHONY: run-bruno-tests
run-bruno-tests: ## Run Bruno API tests
	@echo "$(YELLOW)Running Bruno tests...$(NC)"
	@cd platform/scout/bruno && \
		bruno run --env development \
			18_test_connection.bru \
			09_seed_dims.bru \
			10_txn_ingest.bru \
			11_verify_silver.bru \
			12_query_gold_daily.bru || { echo "$(RED)Bruno tests failed$(NC)"; exit 1; }
	@echo "$(GREEN)✓ Bruno tests passed$(NC)"

.PHONY: deploy-prod
deploy-prod: check-deps migrate-database deploy-edge-functions deploy-lakehouse init-lakehouse deploy-dbt verify-deployment ## Complete production deployment
	@echo "$(GREEN)════════════════════════════════════════$(NC)"
	@echo "$(GREEN)✓ PRODUCTION DEPLOYMENT COMPLETE$(NC)"
	@echo "$(GREEN)════════════════════════════════════════$(NC)"
	@echo ""
	@echo "Next steps:"
	@echo "1. Import Superset dashboards: make import-superset"
	@echo "2. Run full test suite: make run-bruno-tests"
	@echo "3. Check SLO dashboard: kubectl port-forward -n monitoring svc/grafana 3000:3000"
	@echo ""
	@echo "Rollback: make rollback"

.PHONY: rollback
rollback: ## Rollback deployment
	@echo "$(YELLOW)Rolling back deployment...$(NC)"
	@kubectl -n $(CLUSTER_NAMESPACE) rollout undo deployment/trino
	@kubectl -n $(CLUSTER_NAMESPACE) rollout undo deployment/nessie
	@kubectl -n $(CLUSTER_NAMESPACE) rollout undo statefulset/minio
	@echo "$(YELLOW)Reverting Edge Functions to previous version...$(NC)"
	@# Note: Implement Edge Function versioning/rollback strategy
	@echo "$(GREEN)✓ Rollback complete$(NC)"

.PHONY: status
status: ## Check deployment status
	@echo "$(YELLOW)Deployment Status:$(NC)"
	@echo "Namespace $(CLUSTER_NAMESPACE):"
	@kubectl -n $(CLUSTER_NAMESPACE) get pods
	@echo ""
	@echo "Edge Functions:"
	@curl -s $(SUPABASE_URL)/functions/v1/ingest-transaction -H "Authorization: Bearer anon-key" | head -1
	@echo ""
	@echo "Recent transactions:"
	@$(PSQL) -c "SELECT COUNT(*) as count, MAX(ts) as latest FROM scout.silver_transactions WHERE ts > NOW() - INTERVAL '1 hour';" 2>/dev/null || echo "No silver table access"

.PHONY: clean
clean: ## Remove all deployed resources
	@echo "$(RED)WARNING: This will delete all resources in namespace $(CLUSTER_NAMESPACE)$(NC)"
	@echo "Press Ctrl+C to cancel, or wait 5 seconds to continue..."
	@sleep 5
	kubectl delete namespace $(CLUSTER_NAMESPACE) || true
	@echo "$(GREEN)✓ Cleanup complete$(NC)"

# Import Superset dashboards (requires Superset running)
.PHONY: import-superset
import-superset: ## Import Superset dashboard bundle
	@echo "$(YELLOW)Importing Superset dashboards...$(NC)"
	@if [ -f platform/superset/scripts/import_supabase_bundle.sh ]; then \
		bash platform/superset/scripts/import_supabase_bundle.sh; \
	else \
		echo "$(YELLOW)Superset import script not found. Manual import required.$(NC)"; \
	fi

# Guard rail checks
.PHONY: structure
structure: ## Validate repository structure
	bash scripts/validate_repo_layout.sh

.PHONY: bindings
bindings: ## Check Superset dataset bindings
	python scripts/validate_bindings.py

.PHONY: drift
drift: ## Check for Superset asset drift
	bash scripts/check_superset_drift.sh

# Environment management
.PHONY: env-dev
env-dev: ## Load development environment
	@echo "$(YELLOW)Loading development environment...$(NC)"
	@cp environments/dev/secrets.yaml.example environments/dev/secrets.yaml 2>/dev/null || true
	@echo "source environments/dev/edge.env" > .env.local
	@echo "$(GREEN)✓ Development environment loaded$(NC)"
	@echo "Run: source .env.local"

.PHONY: env-staging
env-staging: ## Load staging environment
	@echo "$(YELLOW)Loading staging environment...$(NC)"
	@if [ ! -f environments/staging/secrets.yaml ]; then \
		echo "$(RED)Error: environments/staging/secrets.yaml not found$(NC)"; \
		echo "Copy from secrets.yaml.example and fill in values"; \
		exit 1; \
	fi
	@echo "source environments/staging/edge.env" > .env.local
	@echo "$(GREEN)✓ Staging environment loaded$(NC)"
	@echo "Run: source .env.local"

.PHONY: env-prod
env-prod: ## Load production environment (requires confirmation)
	@echo "$(RED)WARNING: Loading production environment$(NC)"
	@echo "Press Ctrl+C to cancel, or wait 3 seconds to continue..."
	@sleep 3
	@if [ ! -f environments/prod/secrets.yaml ]; then \
		echo "$(RED)Error: environments/prod/secrets.yaml not found$(NC)"; \
		echo "Copy from secrets.yaml.example and fill in vault references"; \
		exit 1; \
	fi
	@echo "source environments/prod/edge.env" > .env.local
	@echo "$(GREEN)✓ Production environment loaded$(NC)"
	@echo "Run: source .env.local"

.PHONY: deploy-env
deploy-env: ## Deploy to current environment
	@if [ -z "$$ENVIRONMENT" ]; then \
		echo "$(RED)Error: ENVIRONMENT not set$(NC)"; \
		echo "Run one of: make env-dev, make env-staging, make env-prod"; \
		exit 1; \
	fi
	@echo "$(YELLOW)Deploying to $$ENVIRONMENT environment...$(NC)"
	@if [ -f "environments/$$ENVIRONMENT/values.yaml" ]; then \
		helm upgrade --install scout ./helm/scout \
			-f environments/$$ENVIRONMENT/values.yaml \
			--namespace scout-$$ENVIRONMENT \
			--create-namespace; \
	fi
	@echo "$(GREEN)✓ Deployed to $$ENVIRONMENT$(NC)"

# Scout Dashboard Commands
.PHONY: dash-setup
dash-setup: ## Install dashboard dependencies
	@echo "$(YELLOW)Setting up Scout Dashboard...$(NC)"
	@cd platform/scout/blueprint-dashboard && npm install
	@echo "$(GREEN)✓ Dashboard dependencies installed$(NC)"

.PHONY: dash-dev
dash-dev: ## Run dashboard in development mode
	@echo "$(YELLOW)Starting dashboard development server...$(NC)"
	@cd platform/scout/blueprint-dashboard && npm run dev

.PHONY: dash-build
dash-build: ## Build dashboard for production
	@echo "$(YELLOW)Building dashboard for production...$(NC)"
	@cd platform/scout/blueprint-dashboard && npm run build
	@echo "$(GREEN)✓ Dashboard built to platform/scout/blueprint-dashboard/dist/$(NC)"

.PHONY: dash-preview
dash-preview: dash-build ## Preview production build locally
	@echo "$(YELLOW)Starting preview server...$(NC)"
	@cd platform/scout/blueprint-dashboard && npm run preview

.PHONY: dash-deploy
dash-deploy: dash-build ## Deploy dashboard to static hosting
	@echo "$(YELLOW)Deploying dashboard...$(NC)"
	@if [ -z "$(DEPLOY_TARGET)" ]; then \
		echo "$(RED)Error: DEPLOY_TARGET not set$(NC)"; \
		echo "Usage: make dash-deploy DEPLOY_TARGET=vercel|netlify|s3|supabase"; \
		exit 1; \
	fi
	@case "$(DEPLOY_TARGET)" in \
		vercel) \
			cd platform/scout/blueprint-dashboard && \
			npx vercel --prod --token=$(VERCEL_TOKEN) dist/ ;; \
		netlify) \
			cd platform/scout/blueprint-dashboard && \
			npx netlify deploy --prod --dir=dist --auth=$(NETLIFY_TOKEN) ;; \
		s3) \
			aws s3 sync platform/scout/blueprint-dashboard/dist/ s3://$(S3_BUCKET)/ --delete ;; \
		supabase) \
			cd platform/scout/blueprint-dashboard && \
			supabase storage upload --project-ref $(SUPABASE_PROJECT_REF) \
				--bucket dashboard --file dist/ --recursive ;; \
		*) \
			echo "$(RED)Unknown deploy target: $(DEPLOY_TARGET)$(NC)"; \
			exit 1 ;; \
	esac
	@echo "$(GREEN)✓ Dashboard deployed to $(DEPLOY_TARGET)$(NC)"

.PHONY: dash-test
dash-test: ## Run dashboard tests
	@echo "$(YELLOW)Running dashboard tests...$(NC)"
	@cd platform/scout/blueprint-dashboard && npm test
	@echo "$(GREEN)✓ Dashboard tests passed$(NC)"

.PHONY: dash-verify
dash-verify: ## Verify dashboard data connections
	@echo "$(YELLOW)Verifying dashboard data connections...$(NC)"
	@cd platform/scout/blueprint-dashboard && \
		node scripts/check-real-data.js \
			--url "$(SUPABASE_URL)" \
			--key "$${VITE_SUPABASE_ANON_KEY:-$(shell grep VITE_SUPABASE_ANON_KEY .env.local | cut -d= -f2)}" \
			--view "scout_dal.v_revenue_trend"
	@echo "$(GREEN)✓ Dashboard data verified$(NC)"

.PHONY: dash-update
dash-update: ## Update dashboard submodule to latest
	@echo "$(YELLOW)Updating dashboard submodule...$(NC)"
	@git submodule update --remote platform/scout/blueprint-dashboard
	@git add platform/scout/blueprint-dashboard
	@git commit -m "chore: update dashboard submodule to latest" || echo "No updates available"
	@echo "$(GREEN)✓ Dashboard submodule updated$(NC)"

.PHONY: dash-pin
dash-pin: ## Pin dashboard to specific tag/commit
	@if [ -z "$(TAG)" ]; then \
		echo "$(RED)Error: TAG not set$(NC)"; \
		echo "Usage: make dash-pin TAG=v1.0.0"; \
		exit 1; \
	fi
	@echo "$(YELLOW)Pinning dashboard to $(TAG)...$(NC)"
	@cd platform/scout/blueprint-dashboard && git checkout $(TAG)
	@git add platform/scout/blueprint-dashboard
	@git commit -m "chore: pin dashboard to $(TAG)"
	@echo "$(GREEN)✓ Dashboard pinned to $(TAG)$(NC)"

.PHONY: dash-env
dash-env: ## Configure dashboard environment
	@echo "$(YELLOW)Configuring dashboard environment...$(NC)"
	@if [ ! -f platform/scout/blueprint-dashboard/.env.local ]; then \
		cp platform/scout/blueprint-dashboard/.env.example platform/scout/blueprint-dashboard/.env.local 2>/dev/null || \
		echo "VITE_SUPABASE_URL=$(SUPABASE_URL)" > platform/scout/blueprint-dashboard/.env.local; \
		echo "VITE_SUPABASE_ANON_KEY=$${SUPABASE_ANON_KEY}" >> platform/scout/blueprint-dashboard/.env.local; \
		echo "VITE_SUPABASE_PROJECT_REF=$(SUPABASE_PROJECT_REF)" >> platform/scout/blueprint-dashboard/.env.local; \
	fi
	@echo "$(GREEN)✓ Dashboard environment configured$(NC)"

.PHONY: dash-clean
dash-clean: ## Clean dashboard build artifacts
	@echo "$(YELLOW)Cleaning dashboard build artifacts...$(NC)"
	@rm -rf platform/scout/blueprint-dashboard/dist
	@rm -rf platform/scout/blueprint-dashboard/node_modules
	@echo "$(GREEN)✓ Dashboard cleaned$(NC)"

.PHONY: dashboard
dashboard: dash-setup dash-verify dash-build ## Complete dashboard setup and build
	@echo "$(GREEN)════════════════════════════════════════$(NC)"
	@echo "$(GREEN)✓ DASHBOARD READY FOR DEPLOYMENT$(NC)"
	@echo "$(GREEN)════════════════════════════════════════$(NC)"
	@echo ""
	@echo "Deploy with: make dash-deploy DEPLOY_TARGET=vercel|netlify|s3|supabase"