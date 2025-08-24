# Branch Protection Rules for Production

## Main Branch Protection

Apply these settings to the `main` branch:

### Rules
- [x] **Require a pull request before merging**
  - [x] Require approvals: 2
  - [x] Dismiss stale pull request approvals when new commits are pushed
  - [x] Require review from CODEOWNERS
  - [x] Require approval of the most recent reviewable push

- [x] **Require status checks to pass before merging**
  - [x] Require branches to be up to date before merging
  - Required status checks:
    - `Production Readiness Gate / Security Scanning`
    - `Production Readiness Gate / Code Quality Checks`
    - `Production Readiness Gate / Build and Test`
    - `Production Readiness Gate / Gate Decision`

- [x] **Require conversation resolution before merging**

- [x] **Require signed commits**

- [x] **Require linear history**

- [x] **Include administrators**

- [x] **Restrict who can push to matching branches**
  - Teams/users with push access:
    - `@your-org/platform-team`
    - `@your-org/devops`

### Additional Settings
- [x] **Allow force pushes**: Disabled
- [x] **Allow deletions**: Disabled

## Production Branch Protection

Apply these settings to the `production` branch:

### Rules
- [x] **Require a pull request before merging**
  - [x] Require approvals: 3 (including at least 1 from DevOps)
  - [x] Dismiss stale pull request approvals when new commits are pushed
  - [x] Require review from CODEOWNERS
  - [x] Require approval of the most recent reviewable push

- [x] **Require status checks to pass before merging**
  - [x] Require branches to be up to date before merging
  - Required status checks:
    - All checks from main branch PLUS:
    - `Production Readiness Gate / Data Quality Checks`
    - `Production Readiness Gate / RLS Security Checks`
    - `Production Readiness Gate / Performance Testing`

- [x] **Require deployments to succeed before merge**
  - Required deployment environments:
    - `staging`

- [x] **Lock branch**: Only admins can push

### Additional Settings
- [x] **Restrict who can push to matching branches**
  - Teams/users with push access:
    - `@your-org/devops` (emergency hotfixes only)

## Staging Branch Protection

Apply these settings to the `staging` branch:

### Rules
- [x] **Require a pull request before merging**
  - [x] Require approvals: 1
  - [x] Require review from CODEOWNERS

- [x] **Require status checks to pass before merging**
  - Required status checks:
    - `Production Readiness Gate / Security Scanning`
    - `Production Readiness Gate / Build and Test`

## Environment Protection Rules

### Production Environment
- **Required reviewers**: 
  - `@your-org/platform-team`
  - `@your-org/devops`
- **Wait timer**: 10 minutes
- **Deployment branches**: Only `production` branch

### Staging Environment  
- **Required reviewers**: 
  - `@your-org/platform-team`
- **Wait timer**: 5 minutes
- **Deployment branches**: `staging` and `main` branches

## CODEOWNERS File

Create `.github/CODEOWNERS`:

```
# Global owners
* @your-org/platform-team

# Frontend
/platform/scout/blueprint-dashboard/ @your-org/frontend
/apps/web/ @your-org/frontend

# Backend
/services/ @your-org/backend
/apps/api/ @your-org/backend

# Infrastructure
/.github/ @your-org/devops
/k8s/ @your-org/devops
/scripts/ @your-org/devops @your-org/platform-team

# Database
/supabase/ @your-org/data-team
/scripts/sql/ @your-org/data-team

# Security-sensitive files
/.env* @your-org/security
/scripts/*security* @your-org/security
/scripts/*rls* @your-org/security
```

## Implementation Steps

1. Go to Settings → Branches in your GitHub repository
2. Add branch protection rules for `main`, `production`, and `staging`
3. Configure each rule according to the settings above
4. Create the CODEOWNERS file
5. Set up environments under Settings → Environments
6. Configure environment protection rules
7. Test by creating a PR and verifying all checks run

## Emergency Procedures

For emergency production fixes:
1. Create hotfix branch from `production`
2. Get emergency approval from DevOps lead
3. Deploy to staging for quick validation
4. Fast-track to production with abbreviated checks
5. Full post-mortem required within 48 hours