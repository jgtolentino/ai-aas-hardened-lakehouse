# Edge SUQI PIE Module Targets

.PHONY: edge-suqi-setup edge-suqi-test edge-suqi-migrate edge-suqi-api

## Edge SUQI PIE Setup
edge-suqi-setup:
	@echo "🔧 Setting up Edge SUQI PIE module..."
	cd edge-suqi-pie && npm install
	cd edge-suqi-pie/browser-automation && npm install

## Run Edge SUQI PIE Tests
edge-suqi-test:
	@echo "🧪 Running Edge SUQI PIE tests..."
	cd edge-suqi-pie && ./scripts/test-transaction-clustering.sh

## Apply Edge SUQI PIE Migrations
edge-suqi-migrate:
	@echo "🗄️  Applying Scout PI migrations..."
	psql $$DATABASE_URL -f edge-suqi-pie/sql/017_transaction_clustering.sql
	psql $$DATABASE_URL -f edge-suqi-pie/sql/018_batch_reclustering.sql

## Start Edge SUQI PIE API
edge-suqi-api:
	@echo "🚀 Starting Transcript API..."
	cd edge-suqi-pie && npm run api:start

## Export Scout PI Data for Tableau
edge-suqi-export:
	@echo "📊 Exporting Scout PI data..."
	cd edge-suqi-pie && ./scripts/export-for-tableau.sh

## Run Browser Automation Tests
edge-suqi-browser-test:
	@echo "🌐 Running browser automation tests..."
	cd edge-suqi-pie/browser-automation && npm run test
