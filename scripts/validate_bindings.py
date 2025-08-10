#!/usr/bin/env python3
"""
Validate Superset dataset bindings are correctly pointing to production database
"""
import os
import sys
import json
import requests
from typing import Dict, List, Tuple

def get_superset_token(base_url: str, username: str, password: str) -> str:
    """Authenticate with Superset and get access token"""
    login_url = f"{base_url}/api/v1/security/login"
    payload = {
        "username": username,
        "password": password,
        "provider": "db",
        "refresh": True
    }
    
    response = requests.post(login_url, json=payload)
    if response.status_code != 200:
        print(f"❌ Authentication failed: {response.status_code}")
        sys.exit(1)
    
    return response.json()["access_token"]

def check_dataset_bindings(base_url: str, token: str, expected_db_name: str) -> Tuple[List[Dict], List[Dict]]:
    """Check all datasets and return (correct, incorrect) bindings"""
    headers = {"Authorization": f"Bearer {token}"}
    datasets_url = f"{base_url}/api/v1/dataset/?q=%7B%22page_size%22:1000%7D"
    
    response = requests.get(datasets_url, headers=headers)
    if response.status_code != 200:
        print(f"❌ Failed to fetch datasets: {response.status_code}")
        sys.exit(1)
    
    datasets = response.json()["result"]
    correct_bindings = []
    incorrect_bindings = []
    
    for dataset in datasets:
        db_name = dataset.get("database", {}).get("database_name", "")
        schema = dataset.get("schema", "")
        table = dataset.get("table_name", "")
        
        # Check if pointing to example/test databases
        if any(bad in db_name.lower() for bad in ["example", "sqlite", "test", "demo"]):
            incorrect_bindings.append({
                "id": dataset["id"],
                "table": table,
                "schema": schema,
                "database": db_name,
                "issue": "Using example/test database"
            })
        elif schema == "scout" and db_name != expected_db_name:
            incorrect_bindings.append({
                "id": dataset["id"],
                "table": table,
                "schema": schema,
                "database": db_name,
                "issue": f"Expected '{expected_db_name}', got '{db_name}'"
            })
        elif schema == "scout":
            correct_bindings.append({
                "id": dataset["id"],
                "table": table,
                "schema": schema,
                "database": db_name
            })
    
    return correct_bindings, incorrect_bindings

def main():
    """Main validation logic"""
    # Get environment variables
    base_url = os.environ.get("SUPERSET_BASE", "").rstrip("/")
    username = os.environ.get("SUPERSET_USER", "")
    password = os.environ.get("SUPERSET_PASSWORD", "")
    expected_db = os.environ.get("SUPERSET_DB_NAME", "Scout Analytics")
    
    if not all([base_url, username, password]):
        print("❌ Missing required environment variables:")
        print("   SUPERSET_BASE, SUPERSET_USER, SUPERSET_PASSWORD")
        sys.exit(1)
    
    print("=== Superset Dataset Binding Validation ===")
    print(f"Target: {base_url}")
    print(f"Expected DB: {expected_db}")
    print()
    
    # Authenticate
    print("🔐 Authenticating...")
    token = get_superset_token(base_url, username, password)
    print("✅ Authentication successful")
    print()
    
    # Check bindings
    print("🔍 Checking dataset bindings...")
    correct, incorrect = check_dataset_bindings(base_url, token, expected_db)
    
    # Report results
    print(f"\n📊 Results:")
    print(f"   ✅ Correct bindings: {len(correct)}")
    print(f"   ❌ Incorrect bindings: {len(incorrect)}")
    
    if correct:
        print(f"\n✅ Correctly bound datasets:")
        for ds in correct[:5]:  # Show first 5
            print(f"   - {ds['table']} → {ds['database']}")
        if len(correct) > 5:
            print(f"   ... and {len(correct) - 5} more")
    
    if incorrect:
        print(f"\n❌ Incorrectly bound datasets:")
        for ds in incorrect:
            print(f"   - {ds['table']} → {ds['database']} ({ds['issue']})")
        print(f"\n❌ VALIDATION FAILED: {len(incorrect)} datasets have incorrect bindings")
        sys.exit(1)
    else:
        print(f"\n✅ All Scout datasets correctly bound to '{expected_db}'")
        sys.exit(0)

if __name__ == "__main__":
    main()