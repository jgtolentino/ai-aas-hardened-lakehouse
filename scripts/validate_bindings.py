#!/usr/bin/env python3
import os, sys, json, requests

BASE = os.environ["SUPERSET_BASE"]
USER = os.environ["SUPERSET_USER"]
PASS = os.environ["SUPERSET_PASSWORD"]
EXPECT_DB = os.environ.get("SUPERSET_DB_NAME","Supabase (prod)")
EXPECT_SCHEMA = os.environ.get("SUPERSET_EXPECT_SCHEMA","scout")

def login():
    r = requests.post(f"{BASE}/api/v1/security/login", json={
        "username": USER, "password": PASS, "provider": "db", "refresh": True
    })
    r.raise_for_status()
    return r.json()["access_token"]

def get_datasets(tok):
    r = requests.get(f"{BASE}/api/v1/dataset/?q=%7B%22page_size%22:1000%7D",
                     headers={"Authorization": f"Bearer {tok}"})
    r.raise_for_status()
    return r.json()["result"]

if __name__ == "__main__":
    tok = login()
    bad = []
    for d in get_datasets(tok):
        db = (d.get("database") or {}).get("database_name")
        schema = d.get("schema")
        if db != EXPECT_DB or (schema and schema != EXPECT_SCHEMA and schema != "public"):
            bad.append((d["id"], d["table_name"], schema, db))
    if bad:
        print("✖ Dataset binding errors:")
        for row in bad:
            print(f" - id={row[0]} table={row[1]} schema={row[2]} db={row[3]}")
        sys.exit(1)
    print("✓ All datasets bound to expected DB/schema.")