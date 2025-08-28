#!/usr/bin/env python3
import subprocess, sys, shlex
from pathlib import Path
try:
  import yaml  # type: ignore
except Exception:
  subprocess.run([sys.executable, "-m", "pip", "install", "pyyaml"], check=True)
  import yaml  # type: ignore

p = Path('docs/PRD/backlog/SCOUT_UI_BACKLOG.yml')
if not p.exists():
  print("Backlog YAML not found at docs/PRD/backlog/SCOUT_UI_BACKLOG.yml"); sys.exit(1)

data = yaml.safe_load(p.read_text()) or {}
items = data.get('backlog_items', [])
def run(cmd):
    print("+", cmd)
    subprocess.run(cmd, shell=True, check=True)

for it in items:
    title = f"[FTR] {it.get('id','UNK')} — {it.get('title','Untitled')}"
    body = f"""**Type:** {it.get('type')}
**Layer:** {', '.join(it.get('layer',[]))}
**Area:** {it.get('area')}
**Priority:** {it.get('priority')}  **Risk:** {it.get('risk')}  **Readiness:** {it.get('readiness')}
**Status:** {it.get('status')}  **Target Release:** {it.get('target_release')}
**Flag:** `{it.get('flag','')}`

**Acceptance**
- """ + "\n- ".join(it.get('acceptance',[]) or ["TBD"]) + """

**Metrics**
- """ + "\n- ".join(it.get('metrics',[]) or ["TBD"]) + f"""

**Links**
- PRD: {it.get('links',{}).get('prd','')}
- RFC: {it.get('links',{}).get('rfc','')}
- Issues: {it.get('links',{}).get('issues',[])}
"""
    labels = [
        "feature",
        f"priority:{it.get('priority','P3')}",
        f"readiness:{it.get('readiness','R0')}",
        f"status:{it.get('status','Proposed')}",
        f"area:{it.get('area','Analytics')}",
    ]
    for layer in (it.get('layer') or []):
        labels.append(f"layer:{layer.replace('/','-')}")
    # Ensure labels exist gracefully
    label_args = " ".join([f"-l {shlex.quote(l)}" for l in labels])
    run(f'gh issue create -t {shlex.quote(title)} -b {shlex.quote(body)} {label_args}')