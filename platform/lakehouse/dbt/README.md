# dbt Project for Scout Analytics

This dbt project transforms raw data in the lakehouse into analytics-ready datasets.

## Local Development

1. Install dbt:
   ```bash
   pip install dbt-trino==1.8.5
   ```

2. Configure profile:
   ```bash
   export DBT_PROFILES_DIR=./profiles
   ```

3. Install dependencies:
   ```bash
   dbt deps
   ```

4. Run models:
   ```bash
   dbt run --profile trino_profile --target cluster
   ```

## CI/CD Configuration

The project includes CI-specific profiles for GitHub Actions:

- `profiles/profiles.yml` - Main profile with cluster and CI targets
- `profiles/profiles-ci.yml` - Simplified CI profile for testing

In CI, we run a local Trino container:
```bash
docker run -d -p 8080:8080 trinodb/trino:latest
dbt compile --profile trino_profile --target ci
```

## Project Structure

```
models/
├── staging/          # Bronze → Silver transformations
├── intermediate/     # Silver → Gold transformations  
└── marts/           # Gold → Analytics marts

tests/               # Data quality tests
macros/              # Reusable SQL macros
```

## Profiles

- `cluster` - Production Kubernetes cluster (trino.aaas.svc.cluster.local)
- `ci` - GitHub Actions with local Trino container
- `test` - PostgreSQL fallback for unit testing