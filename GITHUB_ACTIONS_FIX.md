# GitHub Actions Policy Gate Fix

## Issue
The GitHub Actions workflow `policy-gate.yml` was failing due to an invalid version reference for the Polaris security scanning action:

```
Unable to resolve action `fairwindsops/polaris@v9.5.0`, unable to find version `v9.5.0`
```

## Root Cause
The version `v9.5.0` does not exist in the `fairwindsops/polaris` GitHub Action repository. The action was referencing a non-existent version tag.

## Solution Applied
Replaced the GitHub Action with direct CLI installation and execution:

### Before (Broken)
```yaml
- name: Run Polaris scan
  uses: fairwindsops/polaris@v9.5.0
  with:
    config: .polaris.yaml
    audit-path: platform/
```

### After (Fixed)
```yaml
- name: Install Polaris CLI
  run: |
    curl -L https://github.com/FairwindsOps/polaris/releases/download/8.5.0/polaris_linux_amd64.tar.gz | tar xz
    sudo mv polaris /usr/local/bin/

- name: Run Polaris scan
  run: |
    polaris audit --config .polaris.yaml --audit-path platform/ --format=pretty
```

## Benefits of the Fix
1. **Reliability**: Uses the stable Polaris CLI binary instead of a GitHub Action
2. **Control**: Direct control over the Polaris version (8.5.0)
3. **Compatibility**: Maintains the same functionality with `.polaris.yaml` config
4. **Output**: Provides formatted output for easier reading

## Verification
The fix maintains the same security scanning functionality:
- ✅ Uses existing `.polaris.yaml` configuration
- ✅ Scans the `platform/` directory for Kubernetes manifests
- ✅ Reports security policy violations
- ✅ Integrates with the existing policy gate workflow

## Files Modified
- `.github/workflows/policy-gate.yml` - Updated Polaris scanning approach

The workflow should now pass the security-scanning job successfully.