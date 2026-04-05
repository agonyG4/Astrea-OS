#!/usr/bin/env python3
import sys
import json
import sqlite3
from pathlib import Path

BENCH_DIR = Path("/home/agony/GitHub/Bench/StorageSense")
try:
    with open(BENCH_DIR / "categories.json", "r") as f:
        categories = json.load(f)
except Exception:
    categories = {}

DB_PATH = Path.home() / ".cache" / "storagesense" / "metadata_cache.db"

def get_color(cat_name):
    cat_lower = cat_name.lower()
    if "jogo" in cat_lower or "game" in cat_lower:
        return "#007AFF" # azul
    elif "foto" in cat_lower or "image" in cat_lower:
        return "#FFCC00" # amarelo
    elif "vídeo" in cat_lower or "video" in cat_lower:
        return "#AF52DE"
    elif "música" in cat_lower or "music" in cat_lower:
        return "#FF2D55"
    elif "doc" in cat_lower:
        return "#FF9500"
    elif "cache" in cat_lower:
        return "#FF9500" # laranja (mesmo do doc/ios style)
    elif "código" in cat_lower or "code" in cat_lower:
        return "#34C759"
    elif "arquivo" in cat_lower or "archive" in cat_lower:
        return "#5856D6"
    elif "app" in cat_lower:
        return "#FF3B30"
    return "#555555" # cinza escuro (OS / Sistema)


if not DB_PATH.exists():
    print(json.dumps({"error": "No cache found", "data": []}))
    sys.exit(0)

try:
    conn = sqlite3.connect(DB_PATH)
    cats = conn.execute(
        "SELECT cat, COUNT(*), SUM(size) FROM files GROUP BY cat ORDER BY SUM(size) DESC"
    ).fetchall()
    total_size = conn.execute("SELECT SUM(size) FROM files").fetchone()[0] or 0
    conn.close()

    result = []
    for cat_id, count, sz in cats:
        if not cat_id or cat_id == "":
            cat_id_clean = "other"
            label = "💻 Sistema"
        else:
            cat_id_clean = cat_id
            label = categories.get(cat_id_clean, {}).get("label", cat_id_clean.capitalize())
        
        color = get_color(cat_id_clean)
        
        # Don't show empty categories
        if sz == 0:
            continue
            
        result.append({
            "id": cat_id_clean,
            "label": label,
            "count": count,
            "size": sz,
            "color": color
        })
        
    print(json.dumps({"total": total_size, "data": result}))
except Exception as e:
    print(json.dumps({"error": str(e), "data": []}))
