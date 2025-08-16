import json, math, sys
from pathlib import Path
xs, ys = [], []
for line in Path("fixtures/calibration/labels.jsonl").read_text().splitlines():
    r = json.loads(line); xs.append(float(r["confidence"])); ys.append(int(r["is_correct"]))
# Brier
brier = sum((x - y)**2 for x,y in zip(xs,ys))/len(xs)
# ECE (10-bin)
bins = [[] for _ in range(10)]
for x,y in zip(xs,ys):
    k = min(9, int(x*10)); bins[k].append((x,y))
ece = 0.0
for k,b in enumerate(bins):
    if not b: continue
    conf = sum(v[0] for v in b)/len(b)
    acc  = sum(v[1] for v in b)/len(b)
    ece += (len(b)/len(xs)) * abs(acc - conf)
print(f"Brier={brier:.4f}  ECE={ece:.4f}")
# simple gates (adjust to your targets)
import sys
sys.exit(0 if (brier<=0.12 and ece<=0.05) else 1)