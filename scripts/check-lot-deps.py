#!/usr/bin/env python3
"""Check docs/LOTS.md: every lot dependency respects the module rules of docs/ARCHITECTURE.md."""
import re
import sys
from pathlib import Path

ALLOWED = {
    "HFRModels": {"HFRModels"},
    "HFRParsing": {"HFRModels", "HFRParsing"},
    "HFRNetwork": {"HFRModels", "HFRNetwork"},
    "HFRStorage": {"HFRModels", "HFRStorage"},
    "HFRClient": {"HFRModels", "HFRParsing", "HFRNetwork", "HFRClient"},
}
ENGINE = set(ALLOWED)

rows = [line for line in Path("docs/LOTS.md").read_text(encoding="utf-8").splitlines()
        if re.match(r"^\| LOT-\d{3}", line)]
lots = {}
for row in rows:
    cells = [c.strip() for c in row.strip("|").split("|")]
    lot_id = re.match(r"LOT-(\d{3})", cells[0]).group(1)
    lots[lot_id] = {"module": cells[2], "deps": re.findall(r"\b(\d{3})\b", cells[5])}

errors = []
for lot_id, lot in lots.items():
    for dep in lot["deps"]:
        if dep not in lots:
            errors.append(f"LOT-{lot_id}: depends on unknown LOT-{dep}")
            continue
        src, dst = lot["module"], lots[dep]["module"]
        if src in ENGINE and dst in ENGINE and dst not in ALLOWED[src]:
            errors.append(f"LOT-{lot_id} ({src}) depends on LOT-{dep} ({dst}): forbidden by the module rules")

for error in errors:
    print(f"::error file=docs/LOTS.md::{error}")
print(f"{len(lots)} lots checked, {len(errors)} violation(s)")
sys.exit(1 if errors else 0)
