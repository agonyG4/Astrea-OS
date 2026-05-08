#!/usr/bin/env python3
import json
import os
import shutil
import sqlite3
import subprocess
import sys
import time
from pathlib import Path


HOME = Path.home()
CACHE_DB = HOME / ".cache/storagesense/metadata_cache.db"
SENSE_SCRIPT_CANDIDATES = [
    Path(os.environ["ASTREA_STORAGESENSE"])
    if os.environ.get("ASTREA_STORAGESENSE")
    else None,
    Path(__file__).resolve().parent / "storagesense/sense.py",
    HOME / "GitHub/Bench/StorageSense/sense.py",
    HOME / ".config/AstreaOS/test/Bench/StorageSense/sense.py",
]

DISPLAY_LABELS = {
    "games": "Games",
    "downloads": "Downloads",
    "images": "Imagens",
    "videos": "Videos",
    "music": "Musicas",
    "documents": "Documentos",
    "code": "Codigo / GitHub",
    "home_other": "Outros arquivos pessoais",
    "cache": "Cache / Temp",
    "tmp": "Arquivos temporarios",
    "flatpak": "Flatpaks",
    "spotify": "Spotify",
    "apps": "Apps (home)",
    "app_executables": "Executaveis avulsos",
    "config": "Configuracoes",
    "fonts": "Fontes",
    "sys:apps": "Applications",
    "sys:system": "Base do sistema",
    "sys:other": "Arquivos de sistema",
    "sys:games": "Jogos fora da pasta pessoal",
    "sys:vms": "Virtual Machines",
    "sys:archives": "Arquivos compactados do sistema",
    "sys:fonts": "Fontes do sistema",
    "sys:images": "Imagens do sistema",
    "sys:videos": "Videos do sistema",
    "sys:audio": "Audio do sistema",
    "sys:docs": "Documentos do sistema",
    "sys:code": "Codigo do sistema",
    "sys:tmp": "System Temp",
}

CAT_ALIASES = {
    "docs": "documents",
    "sys_docs": "sys:docs",
    "sys_other": "sys:other",
    "sys_system": "sys:system",
    "sys_games": "sys:games",
    "sys_archives": "sys:archives",
    "sys_fonts": "sys:fonts",
    "sys_code": "sys:code",
    "sys_tmp": "sys:tmp",
}

APP_IDS = {"sys:apps", "flatpak", "spotify", "apps", "app_executables"}
TEMP_IDS = {"tmp", "cache", "sys:tmp"}
SYSTEM_IDS = {
    "sys:system",
    "sys:other",
    "sys:games",
    "sys:vms",
    "sys:archives",
    "sys:fonts",
    "sys:images",
    "sys:videos",
    "sys:audio",
    "sys:docs",
    "sys:code",
    "config",
    "fonts",
}


def find_sense_script() -> Path | None:
    for candidate in SENSE_SCRIPT_CANDIDATES:
        if candidate and candidate.exists():
            return candidate
    return None


def cache_metadata() -> dict:
    if not CACHE_DB.exists():
        return {
            "cache_exists": False,
            "cache_path": str(CACHE_DB),
            "cache_updated_at": None,
            "cache_updated_ago_seconds": None,
            "cache_size": 0,
        }

    updated_at = CACHE_DB.stat().st_mtime
    return {
        "cache_exists": True,
        "cache_path": str(CACHE_DB),
        "cache_updated_at": updated_at,
        "cache_updated_ago_seconds": max(0, time.time() - updated_at),
        "cache_size": CACHE_DB.stat().st_size,
    }


def label_for(cat_id: str) -> str:
    if cat_id in DISPLAY_LABELS:
        return DISPLAY_LABELS[cat_id]
    raw = cat_id.replace("sys:", "").replace("_", " ").replace("-", " ").strip()
    return " ".join(word.capitalize() for word in raw.split()) or "Other"


def color_for(cat_id: str, label: str) -> str:
    label_lower = label.lower()
    cat_lower = cat_id.lower()
    if "game" in label_lower:
        return "#007AFF"
    if "download" in label_lower:
        return "#FFD426"
    if "image" in label_lower:
        return "#FF9F0A"
    if "video" in label_lower:
        return "#AF52DE"
    if "music" in label_lower or "audio" in label_lower:
        return "#FF2D55"
    if "doc" in label_lower:
        return "#FF9500"
    if "code" in label_lower or "github" in label_lower:
        return "#34C759"
    if "archive" in cat_lower or "archive" in label_lower:
        return "#5856D6"
    if cat_id == "unified_apps" or "app" in label_lower or "flatpak" in cat_lower:
        return "#FF3B30"
    if "cache" in label_lower or "tmp" in cat_lower or "system" in label_lower:
        return "#AEAEB2"
    return "#636366"


def add_group(data_map: dict, target_id: str, target_label: str, is_system: bool, row: dict) -> None:
    if target_id not in data_map:
        data_map[target_id] = {
            "id": target_id,
            "label": target_label,
            "size": 0,
            "count": 0,
            "color": color_for(target_id, target_label),
            "is_system": is_system,
            "breakdown": [],
        }
    data_map[target_id]["size"] += row["size"]
    data_map[target_id]["count"] += row["count"]
    data_map[target_id]["breakdown"].append(row)


def print_cached_json() -> int:
    meta = cache_metadata()
    if not CACHE_DB.exists():
        print(json.dumps({
            "error": "No cache found",
            "disk_total": 0,
            "disk_used": 0,
            "scanned_total": 0,
            "categorized_total": 0,
            "uncategorized_delta": 0,
            "data": [],
            **meta,
        }))
        return 0

    try:
        conn = sqlite3.connect(f"file:{CACHE_DB}?mode=ro", uri=True)
        rows = conn.execute(
            "SELECT cat, COUNT(*), SUM(size) FROM files GROUP BY cat ORDER BY SUM(size) DESC"
        ).fetchall()
        total_scanned = conn.execute("SELECT SUM(size) FROM files").fetchone()[0] or 0
        conn.close()
    except sqlite3.Error as err:
        print(json.dumps({"error": f"Could not read storage cache: {err}", "data": []}))
        return 0

    usage = shutil.disk_usage("/")
    data_map = {}

    for cat_id, count, size in rows:
        if not size:
            continue
        canonical = CAT_ALIASES.get(cat_id, cat_id)
        label = label_for(canonical)
        source_row = {
            "id": canonical,
            "label": label,
            "size": int(size),
            "count": int(count),
        }

        label_lower = label.lower()
        if canonical in APP_IDS or "application" in label_lower or "apps" in label_lower:
            add_group(data_map, "unified_apps", "Applications", False, source_row)
        elif canonical in TEMP_IDS or "temp" in label_lower or "cache" in label_lower:
            add_group(data_map, "sys:temp_files", "Arquivos temporarios", True, source_row)
        elif canonical.startswith("sys:") or canonical in SYSTEM_IDS or "system" in label_lower:
            add_group(data_map, "sys:unified", "System", True, source_row)
        elif canonical in {"archives", "sys:archives"}:
            add_group(data_map, "home_other", label_for("home_other"), False, source_row)
        else:
            add_group(data_map, canonical, label, False, source_row)

    categorized_total = sum(item["size"] for item in data_map.values())
    system_delta = max(0, usage.used - categorized_total)
    if system_delta > 1024 * 1024:
        add_group(data_map, "sys:unified", "System", True, {
            "id": "disk_gap",
            "label": "Espaco usado fora do indice",
            "size": int(system_delta),
            "count": 0,
        })

    for item in data_map.values():
        item["breakdown"].sort(key=lambda entry: entry["size"], reverse=True)
        item["breakdown"] = item["breakdown"][:6]
        if item["id"] == "sys:unified":
            item["details_summary"] = "Bibliotecas, arquivos base do sistema, fontes, configs e conteudo fora da pasta pessoal."
        elif item["id"] == "sys:temp_files":
            item["details_summary"] = "Caches, diretorios temporarios e logs que podem crescer com o uso."
        elif item["id"] == "home_other":
            item["details_summary"] = "Arquivos pessoais que nao entraram nas categorias principais."
        elif item["id"] == "unified_apps":
            item["details_summary"] = "Apps instalados no home, Flatpaks e executaveis."
        else:
            item["details_summary"] = ""

    print(json.dumps({
        "disk_total": usage.total,
        "disk_used": usage.used,
        "scanned_total": int(total_scanned),
        "categorized_total": int(categorized_total),
        "uncategorized_delta": int(system_delta),
        "data": sorted(data_map.values(), key=lambda item: item["size"], reverse=True),
        "backend_path": None,
        "backend_fallback": "cache",
        **meta,
    }, ensure_ascii=False))
    return 0


def main() -> int:
    sense_script = find_sense_script()
    if not sense_script:
        if sys.argv[1:2] == ["json"]:
            return print_cached_json()
        print(json.dumps({
            "error": "StorageSense backend not found",
            "data": [],
            **cache_metadata(),
        }))
        return 0

    command = [sys.executable, str(sense_script)] + sys.argv[1:]
    env = os.environ.copy()
    env["PYTHONPATH"] = str(sense_script.parent) + os.pathsep + env.get("PYTHONPATH", "")
    return subprocess.call(command, cwd=str(sense_script.parent), env=env)


if __name__ == "__main__":
    raise SystemExit(main())
