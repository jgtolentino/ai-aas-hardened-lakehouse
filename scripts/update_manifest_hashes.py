#!/usr/bin/env python3
"""Update manifest.yaml with computed hashes"""

import yaml
import sys
from pathlib import Path

def update_manifest(hash_file, manifest_file):
    # Read hashes
    hashes = {}
    with open(hash_file, 'r') as f:
        for line in f:
            if line.strip():
                filename, filepath, hash_value = line.strip().split('|')
                hashes[filename] = {
                    'path': filepath,
                    'hash': hash_value
                }
    
    # Read manifest
    with open(manifest_file, 'r') as f:
        manifest = yaml.safe_load(f)
    
    # Update hashes
    updated = 0
    for migration in manifest.get('migrations', []):
        filename = migration.get('file')
        if filename in hashes:
            migration['sha256'] = hashes[filename]['hash']
            if migration['sha256'] == 'pending_calculation':
                updated += 1
    
    # Write updated manifest
    with open(manifest_file, 'w') as f:
        yaml.dump(manifest, f, default_flow_style=False, sort_keys=False)
    
    print(f"Updated {updated} migration hashes in manifest")

if __name__ == "__main__":
    script_dir = Path(__file__).parent
    base_dir = script_dir.parent
    
    hash_file = base_dir / "migrations" / "migration_hashes.txt"
    manifest_file = base_dir / "migrations" / "manifest.yaml"
    
    if hash_file.exists() and manifest_file.exists():
        update_manifest(hash_file, manifest_file)
    else:
        print("Error: Required files not found")
        sys.exit(1)
