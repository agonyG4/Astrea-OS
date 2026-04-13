#!/usr/bin/env python3
"""
StorageSense — macOS-style storage analyzer.
Python handles: CLI, report rendering, JSON output, cache inspection.
Rust binary handles: filesystem walk, classification, SQLite caching.
"""

import os
import sys
import json
import shutil
import sqlite3
import argparse
import subprocess
from pathlib import Path
from collections import defaultdict

# ─────────────────────────────────────────────────────────────
# PATHS
# ─────────────────────────────────────────────────────────────

HOME       = str(Path.home())
SCRIPT_DIR = Path(__file__).resolve().parent

# Config files (next to sense.py)
CAT_FILE   = SCRIPT_DIR / "categories.json"
RULES_FILE = SCRIPT_DIR / "system_rules.json"

# Rust scanner binary (next to sense.py, or on PATH)
SCANNER_BIN = SCRIPT_DIR / "target" / "release" / "scanner"
if not SCANNER_BIN.exists():
    SCANNER_BIN = shutil.which("storagesense-scanner") or "scanner"

CACHE_DIR = Path(HOME) / ".cache" / "storagesense"
CACHE_DIR.mkdir(parents=True, exist_ok=True)
DB_PATH = CACHE_DIR / "metadata_cache.db"

W = 68  # report width

# ─────────────────────────────────────────────────────────────
# CATEGORY METADATA  (for labels / colors in reports)
# ─────────────────────────────────────────────────────────────

def load_home_meta() -> dict[str, tuple[str, str]]:
    """Returns {cat_id: (label, emoji)} for home categories."""
    if not CAT_FILE.exists():
        return {}
    try:
        with open(CAT_FILE, encoding="utf-8") as f:
            raw = json.load(f)
    except json.JSONDecodeError:
        return {}
    return {
        k: (v.get("label", k), v.get("emoji", ""))
        for k, v in raw.items()
        if not k.startswith("_")
    }


def load_sys_meta() -> dict[str, tuple[str, str]]:
    """Returns {rule_id: (label, color)} for system categories from system_rules.json."""
    if not RULES_FILE.exists():
        return {}
    try:
        with open(RULES_FILE, encoding="utf-8") as f:
            raw = json.load(f)
    except json.JSONDecodeError:
        return {}
    meta = {}
    for rule_id, rule in raw.get("rules", {}).items():
        meta[rule_id] = (rule.get("label", rule_id), rule.get("color", ""))
    meta["sys_other"] = ("Other (system)", "")
    return meta


def build_cat_meta() -> dict[str, tuple[str, str]]:
    meta = load_home_meta()
    meta.update(load_sys_meta())
    meta.setdefault("home_other", ("Other (Home)", ""))
    return meta


# ─────────────────────────────────────────────────────────────
# FORMATTING
# ─────────────────────────────────────────────────────────────

def format_size(size: float) -> str:
    for unit in ["B", "KB", "MB", "GB", "TB"]:
        if size < 1024:
            return f"{size:.1f} {unit}"
        size /= 1024
    return f"{size:.1f} PB"


def bar(fraction: float, width: int = 22) -> str:
    filled = round(fraction * width)
    return "#" * filled + "-" * (width - filled)


def sep(char: str = "-") -> None:
    print(char * W)


# ─────────────────────────────────────────────────────────────
# SCANNER INVOCATION
# ─────────────────────────────────────────────────────────────

def run_scanner(quiet: bool) -> dict:
    """
    Calls the Rust scanner binary.
    Returns the parsed JSON output dict:
      { scanned, updated, pruned, errors, elapsed_secs, stats: [{cat, size}] }
    """
    if not Path(str(SCANNER_BIN)).exists():
        print(f"Error: scanner binary not found at {SCANNER_BIN}", file=sys.stderr)
        print("Build it with:  cd scanner && cargo build --release", file=sys.stderr)
        sys.exit(1)

    cmd = [
        str(SCANNER_BIN),
        "--rules", str(RULES_FILE),
        "--db",    str(DB_PATH),
        "--home",  HOME,
    ]
    if quiet:
        cmd.append("--quiet")

    if not quiet:
        print(f"\nScanning /  —  cache at {DB_PATH}")
        print(f"Scanner:   {SCANNER_BIN}\n")

    try:
        result = subprocess.run(
            cmd,
            stdout=subprocess.PIPE,
            stderr=None,   # let stderr (progress) pass through directly
            check=True,
        )
    except subprocess.CalledProcessError as e:
        print(f"Scanner exited with code {e.returncode}", file=sys.stderr)
        sys.exit(1)
    except FileNotFoundError:
        print(f"Scanner binary not found: {SCANNER_BIN}", file=sys.stderr)
        sys.exit(1)

    try:
        return json.loads(result.stdout)
    except json.JSONDecodeError as e:
        print(f"Failed to parse scanner output: {e}", file=sys.stderr)
        sys.exit(1)


# ─────────────────────────────────────────────────────────────
# SCAN REPORT
# ─────────────────────────────────────────────────────────────

def print_scan_report(scan: dict, cat_meta: dict) -> None:
    scanned  = scan["scanned"]
    updated  = scan["updated"]
    pruned   = scan["pruned"]
    errors   = scan["errors"]
    elapsed  = scan["elapsed_secs"]
    raw_stats = {s["cat"]: s["size"] for s in scan["stats"]}

    total = sum(raw_stats.values()) or 1
    rate  = scanned / elapsed if elapsed > 0 else 0

    home_rows: list[tuple[str, str, int]] = []
    sys_rows:  list[tuple[str, str, int]] = []

    for cat_id, size in raw_stats.items():
        if size == 0:
            continue
        label, extra = cat_meta.get(cat_id, (cat_id, ""))
        entry = (label, extra, size)
        if cat_id.startswith("sys"):
            sys_rows.append(entry)
        else:
            home_rows.append(entry)

    home_rows.sort(key=lambda x: x[2], reverse=True)
    sys_rows.sort(key=lambda x: x[2], reverse=True)

    print()
    print("=" * W)
    print("  STORAGE SENSE")
    print(f"  Files: {scanned:,}   Time: {elapsed:.1f}s  ({rate:,.0f} files/s)")
    print(f"  Updated: {updated:,}   Pruned: {pruned:,}   Errors: {errors:,}")
    print("=" * W)
    print(f"  {'CATEGORY':<26}  {'SIZE':>9}  {'%':>5}  BAR")

    sep()
    print("  ~ HOME")
    sep()
    for label, _, size in home_rows:
        frac = size / total
        print(f"  {label:<26}  {format_size(size):>9}  {frac*100:>4.1f}%  {bar(frac)}")

    sep()
    print("  / SYSTEM")
    sep()
    for label, _, size in sys_rows:
        frac = size / total
        print(f"  {label:<26}  {format_size(size):>9}  {frac*100:>4.1f}%  {bar(frac)}")

    sep()
    print(f"  {'TOTAL':<26}  {format_size(total):>9}")
    print("=" * W)
    print()


# ─────────────────────────────────────────────────────────────
# CACHE INFO  (reads SQLite directly — no scanner needed)
# ─────────────────────────────────────────────────────────────

def open_db() -> sqlite3.Connection:
    conn = sqlite3.connect(DB_PATH)
    conn.execute("PRAGMA journal_mode=WAL")
    return conn


def print_cache_info(cat_meta: dict) -> None:
    if not DB_PATH.exists():
        print("No cache found. Run `storagesense scan`.")
        return

    conn    = open_db()
    n_files = conn.execute("SELECT COUNT(*) FROM files").fetchone()[0]
    vol     = conn.execute("SELECT SUM(size) FROM files").fetchone()[0] or 0
    db_size = DB_PATH.stat().st_size
    rows    = conn.execute(
        "SELECT cat, COUNT(*), SUM(size) FROM files GROUP BY cat ORDER BY SUM(size) DESC"
    ).fetchall()
    conn.close()

    print()
    print("=" * W)
    print(f"  CACHE INFO  —  {DB_PATH}")
    sep()
    print(f"  Database:      {format_size(db_size)}")
    print(f"  Files:         {n_files:,}")
    print(f"  Total volume:  {format_size(vol)}")
    sep()
    print(f"  {'CATEGORY':<26}  {'FILES':>10}  {'SIZE':>10}")
    sep()
    for cat_id, count, sz in rows:
        label, _ = cat_meta.get(cat_id, (cat_id or "(no category)", ""))
        print(f"  {label:<26}  {count:>10,}  {format_size(sz or 0):>10}")
    print("=" * W)
    print()


# ─────────────────────────────────────────────────────────────
# LIST
# ─────────────────────────────────────────────────────────────

def print_list(cat_meta: dict) -> None:
    if not DB_PATH.exists():
        conn = None
    else:
        conn = open_db()

    print()
    print("=" * W)
    print(f"  CATEGORIES")
    sep()
    print(f"  {'ID':<20}  {'LABEL':<22}  {'IN CACHE':>10}")
    sep()

    for cat_id, (label, _) in sorted(cat_meta.items()):
        count = 0
        if conn:
            count = conn.execute(
                "SELECT COUNT(*) FROM files WHERE cat=?", (cat_id,)
            ).fetchone()[0]
        print(f"  {cat_id:<20}  {label:<22}  {count:>10,}")

    if conn:
        conn.close()
    print("=" * W)
    print()


# ─────────────────────────────────────────────────────────────
# JSON OUTPUT  (for frontend / Astrea integration)
# ─────────────────────────────────────────────────────────────

def _get_color(cat_id: str, label: str) -> str:
    """Map category to an Apple-palette color."""
    l = label.lower()
    i = cat_id.lower()
    if "game"    in l:                                                    return "#007AFF"
    if "download" in l:                                                   return "#FFD426"
    if "image"   in l or "photo" in l:                                    return "#FF9F0A"
    if "video"   in l:                                                    return "#AF52DE"
    if "music"   in l or "audio" in l:                                    return "#FF2D55"
    if "doc"     in l:                                                    return "#FF9500"
    if "code"    in l or "github" in l:                                   return "#34C759"
    if "archive" in i or "archive" in l:                                  return "#5856D6"
    if i == "unified_apps" or "app" in l or "flatpak" in i:               return "#FF3B30"
    if "cache"   in l or "tmp" in i or "system" in l or "config" in i:   return "#AEAEB2"
    return "#636366"


def print_json_output(cat_meta: dict) -> None:
    if not DB_PATH.exists():
        print(json.dumps({"error": "No cache found", "total": 0, "data": []}))
        return

    du         = shutil.disk_usage("/")
    disk_total = du.total
    disk_used  = du.used

    conn           = open_db()
    total_scanned  = conn.execute("SELECT SUM(size) FROM files").fetchone()[0] or 0
    rows           = conn.execute(
        "SELECT cat, COUNT(*), SUM(size) FROM files GROUP BY cat ORDER BY SUM(size) DESC"
    ).fetchall()
    conn.close()

    APP_IDS = {"sys:apps", "apps", "app_executables", "flatpak", "spotify"}
    SYS_IDS = {
        "sys_system", "sys_other", "sys_tmp", "sys_games", "sys_vms",
        "sys_archives", "sys_fonts", "sys_images", "sys_videos",
        "sys_audio", "sys_docs", "sys_code", "config", "cache",
        "system", "tmp", "games", "vms", "archives", "fonts",
        "images", "videos", "audio", "docs", "code",
    }

    data_map: dict[str, dict] = {}

    for cat_id, count, sz in rows:
        if not sz:
            continue
        label, _ = cat_meta.get(cat_id, (cat_id or "Other", ""))

        target_id    = cat_id
        target_label = label
        is_system    = cat_id.startswith("sys")

        if (cat_id in APP_IDS
                or "application" in label.lower()
                or "apps" in label.lower()):
            target_id    = "unified_apps"
            target_label = "Applications"
            is_system    = False
        elif (is_system or cat_id in SYS_IDS
              or "system" in label.lower()
              or "cache" in label.lower()):
            target_id    = "sys_unified"
            target_label = "System"
            is_system    = True

        if target_id not in data_map:
            data_map[target_id] = {
                "id":        target_id,
                "label":     target_label,
                "size":      0,
                "count":     0,
                "color":     _get_color(target_id, target_label),
                "is_system": is_system,
            }

        data_map[target_id]["size"]  += sz
        data_map[target_id]["count"] += count

    # Absorb unaccounted disk usage into System
    categorized_total = sum(d["size"] for d in data_map.values())
    delta = disk_used - categorized_total
    if delta > 1024 * 1024:
        if "sys_unified" in data_map:
            data_map["sys_unified"]["size"] += delta
        else:
            data_map["sys_unified"] = {
                "id": "sys_unified", "label": "System", "size": delta,
                "count": 0, "color": _get_color("sys_unified", "System"),
                "is_system": True,
            }

    final_data = sorted(data_map.values(), key=lambda x: x["size"], reverse=True)
    print(json.dumps({
        "disk_total":    disk_total,
        "disk_used":     disk_used,
        "scanned_total": total_scanned,
        "data":          final_data,
    }, ensure_ascii=False))


# ─────────────────────────────────────────────────────────────
# GET  (query a specific category from cache)
# ─────────────────────────────────────────────────────────────

def cmd_get(cat_id: str, cat_meta: dict, limit: int) -> None:
    if not DB_PATH.exists():
        print("No cache found. Run `storagesense scan`.")
        return

    conn  = open_db()
    label, _ = cat_meta.get(cat_id, (cat_id, ""))
    rows  = conn.execute(
        "SELECT path, size FROM files WHERE cat=? ORDER BY size DESC LIMIT ?",
        (cat_id, limit)
    ).fetchall()
    total = conn.execute(
        "SELECT SUM(size), COUNT(*) FROM files WHERE cat=?", (cat_id,)
    ).fetchone()
    conn.close()

    print()
    print("=" * W)
    print(f"  {label}  [{cat_id}]  —  {format_size(total[0] or 0)}  ({total[1]:,} files)")
    sep()
    for path, size in rows:
        short = path.replace(HOME, "~")
        print(f"  {format_size(size):>9}  {short}")
    print("=" * W)
    print()


# ─────────────────────────────────────────────────────────────
# CLI
# ─────────────────────────────────────────────────────────────

def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        prog="storagesense",
        description="macOS-style storage analyzer (Rust-powered scanner).",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
examples:
  storagesense scan
  storagesense scan --quiet
  storagesense list
  storagesense info
  storagesense get downloads --limit 20
  storagesense json
  storagesense clear-cache
        """,
    )
    sub = p.add_subparsers(dest="command", metavar="<command>")

    scan_p = sub.add_parser("scan", help="Scan the disk and display a report")
    scan_p.add_argument("--quiet", "-q", action="store_true", help="Suppress progress output")

    sub.add_parser("list",        help="List all known categories")
    sub.add_parser("info",        help="Show cache statistics")
    sub.add_parser("json",        help="Output results as JSON for frontend integration")
    sub.add_parser("clear-cache", help="Delete the SQLite cache")

    get_p = sub.add_parser("get", help="Show largest files in a category")
    get_p.add_argument("category",        help="Category ID (e.g. downloads, code, games)")
    get_p.add_argument("--limit", "-n", type=int, default=30, help="Max files to show (default 30)")

    return p


def main() -> None:
    parser = build_parser()
    args   = parser.parse_args()

    if args.command is None:
        parser.print_help()
        sys.exit(0)

    cat_meta = build_cat_meta()

    match args.command:
        case "scan":
            scan = run_scanner(args.quiet)
            print_scan_report(scan, cat_meta)

        case "list":
            print_list(cat_meta)

        case "info":
            print_cache_info(cat_meta)

        case "json":
            print_json_output(cat_meta)

        case "get":
            cmd_get(args.category, cat_meta, args.limit)

        case "clear-cache":
            if DB_PATH.exists():
                DB_PATH.unlink()
                print(f"Cache removed: {DB_PATH}")
            else:
                print("No cache found.")


if __name__ == "__main__":
    main()