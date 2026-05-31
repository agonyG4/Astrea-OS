#!/usr/bin/env python3
import json
import os
import shutil
import sqlite3
import subprocess
import sys
import tempfile
import time
from pathlib import Path


HOME = Path.home()
CACHE_DB = HOME / ".cache/storagesense/metadata_cache.db"
STATE_DIR = HOME / ".local/state/Astrea"
REFRESH_LOCK = STATE_DIR / "storage-refresh.lock"
REFRESH_STATUS = STATE_DIR / "storage-refresh.json"
REFRESH_LOG = STATE_DIR / "storage-refresh.log"
AUTO_REFRESH_AFTER_SECONDS = int(os.environ.get("ASTREA_STORAGE_REFRESH_AFTER_SECONDS", "900"))
REFRESH_SCAN_TIMEOUT = int(os.environ.get("ASTREA_STORAGE_REFRESH_TIMEOUT", "3600"))
REFRESH_POLL_SECONDS = 5
COMPSIZE_CACHE = STATE_DIR / "storage-compsize.json"
COMPSIZE_CACHE_AFTER_SECONDS = int(os.environ.get("ASTREA_STORAGE_COMPSIZE_AFTER_SECONDS", "3600"))
SENSE_JSON_TIMEOUT = int(os.environ.get("ASTREA_STORAGE_JSON_TIMEOUT", "20"))
COMPSIZE_PATHS = [Path("/"), Path("/home")]
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
    "sys:pacman": "Pacman",
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
PACMAN_IDS = {"sys:pacman"}


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


def read_json(path: Path, default: dict) -> dict:
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
        return data if isinstance(data, dict) else default
    except (OSError, json.JSONDecodeError):
        return default


def write_json(path: Path, payload: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp_name = tempfile.mkstemp(
        prefix=f".{path.name}.",
        suffix=".tmp",
        dir=str(path.parent),
        text=True,
    )
    tmp = Path(tmp_name)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            handle.write(json.dumps(payload, ensure_ascii=False))
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(tmp, path)
    except Exception:
        tmp.unlink(missing_ok=True)
        raise


def parse_compsize_size(value: str) -> int:
    value = value.strip()
    if not value:
        return 0
    suffix = value[-1].upper()
    multiplier = 1
    number = value
    if suffix in {"K", "M", "G", "T", "P"}:
        multiplier = {
            "K": 1_000,
            "M": 1_000_000,
            "G": 1_000_000_000,
            "T": 1_000_000_000_000,
            "P": 1_000_000_000_000_000,
        }[suffix]
        number = value[:-1]
    return int(float(number) * multiplier)


def parse_compsize_output(output: str) -> dict:
    stats = {
        "exact": False,
        "compressed_saved": 0,
        "compressed_total": 0,
        "zstd_disk_usage": 0,
        "zstd_saved": 0,
        "by_algorithm": {},
    }
    for raw_line in output.splitlines():
        line = raw_line.strip()
        if not line or line.startswith("Processed") or line.startswith("Type"):
            continue
        parts = line.split()
        if len(parts) < 5:
            continue
        alg = parts[0]
        try:
            disk_usage = parse_compsize_size(parts[2])
            uncompressed = parse_compsize_size(parts[3])
        except ValueError:
            continue
        saved = max(0, uncompressed - disk_usage)
        if alg == "TOTAL":
            stats["compressed_saved"] += saved
            stats["exact"] = True
        else:
            current = stats["by_algorithm"].setdefault(alg, {
                "disk_usage": 0,
                "uncompressed": 0,
                "compressed_saved": 0,
            })
            current.update({
                "disk_usage": current["disk_usage"] + disk_usage,
                "uncompressed": current["uncompressed"] + uncompressed,
                "compressed_saved": current["compressed_saved"] + saved,
            })
            if alg == "zstd":
                stats["compressed_total"] += uncompressed
                stats["zstd_disk_usage"] += disk_usage
                stats["zstd_saved"] += saved
    return stats


def is_separate_mount_or_subvolume(path: Path, parent: Path) -> bool:
    try:
        if path.is_mount():
            return True
    except OSError:
        pass
    try:
        return path.stat().st_dev != parent.stat().st_dev
    except OSError:
        return False


def default_compsize_paths() -> list[Path]:

    paths = []
    seen = set()
    for path in COMPSIZE_PATHS:
        try:
            resolved = path.resolve()
        except OSError:
            resolved = path
        key = str(resolved)
        if not path.exists() or key in seen:
            continue
        skip = False
        for kept in paths:
            try:
                path.relative_to(kept)
            except ValueError:
                continue
            if not is_separate_mount_or_subvolume(path, kept):
                skip = True
            break
        if not skip:
            paths.append(path)
            seen.add(key)
    return paths


def parse_compsize_bytes(output: str) -> dict:
    return parse_compsize_output(output)


def cached_compsize_stats(allow_stale: bool = False) -> dict:
    cached = read_json(COMPSIZE_CACHE, {})
    updated_at = cached.get("updated_at")
    if not updated_at:
        return {}
    age = time.time() - float(updated_at)
    if age > COMPSIZE_CACHE_AFTER_SECONDS and not allow_stale:
        return {}
    cached["stale"] = age > COMPSIZE_CACHE_AFTER_SECONDS
    cached["age_seconds"] = max(0, age)
    return cached


def compsize_stats(paths: list[Path]) -> dict:
    cached = cached_compsize_stats()
    if cached:
        return cached
    stale_cached = cached_compsize_stats(allow_stale=True)
    binary = shutil.which("compsize")
    if not binary:
        if stale_cached:
            stale_cached["error"] = "compsize not installed"
            return stale_cached
        return {"exact": False, "error": "compsize not installed", "source": "unavailable"}
    command = [binary, "-b", "-x"] + [str(path) for path in paths if path.exists()]
    if len(command) <= 3:
        if stale_cached:
            stale_cached["error"] = "no compsize paths"
            return stale_cached
        return {"exact": False, "error": "no compsize paths", "source": "unavailable"}
    try:
        result = subprocess.run(command, capture_output=True, text=True, timeout=8)
    except (OSError, subprocess.TimeoutExpired) as err:
        if stale_cached:
            stale_cached["error"] = str(err)
            return stale_cached
        return {"exact": False, "error": str(err), "source": "compsize"}
    if result.returncode != 0:
        if stale_cached:
            stale_cached["error"] = (result.stderr or result.stdout or "compsize failed").strip()
            return stale_cached
        return {
            "exact": False,
            "error": (result.stderr or result.stdout or "compsize failed").strip(),
            "source": "compsize",
        }
    stats = parse_compsize_output(result.stdout)
    stats.update({
        "source": "compsize",
        "updated_at": time.time(),
        "paths": [str(path) for path in paths if path.exists()],
    })
    try:
        write_json(COMPSIZE_CACHE, stats)
    except OSError:
        pass
    return stats


def import_compsize_cache(output: str, source: str = "manual-compsize") -> dict:
    stats = parse_compsize_output(output)
    stats.update({
        "source": source,
        "updated_at": time.time(),
        "paths": [str(path) for path in default_compsize_paths()],
    })
    write_json(COMPSIZE_CACHE, stats)
    return stats


def process_alive(pid: int) -> bool:
    if pid <= 0:
        return False
    try:
        os.kill(pid, 0)
        return True
    except ProcessLookupError:
        return False
    except PermissionError:
        return True


def process_is_refresh_worker(pid: int) -> bool:
    try:
        raw = Path(f"/proc/{pid}/cmdline").read_bytes()
    except OSError:
        return False
    parts = [part.decode("utf-8", errors="ignore") for part in raw.split(b"\0") if part]
    return any(part.endswith("storage.py") for part in parts) and "refresh-background" in parts


def refresh_status() -> dict:
    status = read_json(REFRESH_STATUS, {})
    pid = int(status.get("pid") or 0)
    running = process_alive(pid) and process_is_refresh_worker(pid)
    if not running and REFRESH_LOCK.exists():
        try:
            REFRESH_LOCK.unlink()
        except OSError:
            pass
    if status.get("running") and not running:
        status["running"] = False
        status["updated_at"] = time.time()
        try:
            write_json(REFRESH_STATUS, status)
        except OSError:
            pass
    status["running"] = running
    return status


def refresh_running() -> bool:
    return bool(refresh_status().get("running"))


def cache_needs_auto_refresh(meta: dict) -> bool:
    if not meta.get("cache_exists"):
        return True
    age = meta.get("cache_updated_ago_seconds")
    return age is None or age > AUTO_REFRESH_AFTER_SECONDS


def start_auto_refresh(sense_script: Path, reason: str) -> bool:
    if refresh_running():
        return False
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    command = [sys.executable, str(Path(__file__).resolve()), "refresh-background", str(sense_script), reason]
    with REFRESH_LOG.open("ab") as log:
        proc = subprocess.Popen(
            command,
            stdout=log,
            stderr=subprocess.STDOUT,
            stdin=subprocess.DEVNULL,
            start_new_session=True,
            close_fds=True,
        )
    write_json(REFRESH_STATUS, {
        "pid": proc.pid,
        "running": True,
        "reason": reason,
        "started_at": time.time(),
        "updated_at": time.time(),
        "log": str(REFRESH_LOG),
    })
    return True


def enrich_refresh_metadata(payload: dict, sense_script: Path | None = None) -> dict:
    meta = cache_metadata()
    status = refresh_status()
    compression_missing = payload.get("compression_index_ready") is False
    stale = cache_needs_auto_refresh(meta) or compression_missing
    started = False
    if sense_script and stale and not status.get("running"):
        reason = "missing-cache" if not meta.get("cache_exists") else "compression-metadata" if compression_missing else "stale-cache"
        started = start_auto_refresh(sense_script, reason)
        status = refresh_status()

    payload.update({
        "refresh_running": bool(status.get("running")),
        "refresh_started": started,
        "refresh_reason": status.get("reason", ""),
        "refresh_started_at": status.get("started_at"),
        "refresh_updated_at": status.get("updated_at"),
        "refresh_log": status.get("log", str(REFRESH_LOG)),
        "cache_stale": stale,
        "cache_refresh_after_seconds": AUTO_REFRESH_AFTER_SECONDS,
        "refresh_poll_seconds": REFRESH_POLL_SECONDS,
    })
    return payload


def run_refresh_background(sense_script: Path, reason: str) -> int:
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    try:
        fd = os.open(REFRESH_LOCK, os.O_CREAT | os.O_EXCL | os.O_WRONLY)
        os.write(fd, str(os.getpid()).encode("ascii"))
        os.close(fd)
    except FileExistsError:
        if refresh_running():
            return 0
        try:
            REFRESH_LOCK.unlink()
        except OSError:
            pass

    started = time.time()
    write_json(REFRESH_STATUS, {
        "pid": os.getpid(),
        "running": True,
        "reason": reason,
        "started_at": started,
        "updated_at": started,
        "log": str(REFRESH_LOG),
    })
    exit_code = 0
    try:
        command_base = [sys.executable, str(sense_script)]
        env = os.environ.copy()
        env["PYTHONPATH"] = str(sense_script.parent) + os.pathsep + env.get("PYTHONPATH", "")
        try:
            result = subprocess.run(
                command_base + ["scan", "--quiet"],
                cwd=str(sense_script.parent),
                env=env,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.PIPE,
                text=True,
                timeout=REFRESH_SCAN_TIMEOUT,
            )
        except subprocess.TimeoutExpired as exc:
            exit_code = 124
            write_json(REFRESH_STATUS, {
                "pid": os.getpid(),
                "running": False,
                "reason": reason,
                "started_at": started,
                "finished_at": time.time(),
                "updated_at": time.time(),
                "ok": False,
                "error": f"refresh timed out after {REFRESH_SCAN_TIMEOUT}s",
                "log": str(REFRESH_LOG),
            })
            return exit_code
        if result.returncode != 0:
            exit_code = result.returncode
            write_json(REFRESH_STATUS, {
                "pid": os.getpid(),
                "running": False,
                "reason": reason,
                "started_at": started,
                "finished_at": time.time(),
                "updated_at": time.time(),
                "ok": False,
                "error": (result.stderr or "refresh failed").strip(),
                "log": str(REFRESH_LOG),
            })
            return exit_code
        write_json(REFRESH_STATUS, {
            "pid": os.getpid(),
            "running": False,
            "reason": reason,
            "started_at": started,
            "finished_at": time.time(),
            "updated_at": time.time(),
            "ok": True,
            "log": str(REFRESH_LOG),
        })
        return 0
    finally:
        try:
            REFRESH_LOCK.unlink()
        except OSError:
            pass


def label_for(cat_id: str) -> str:
    if cat_id in DISPLAY_LABELS:
        return DISPLAY_LABELS[cat_id]
    raw = cat_id.replace("sys:", "").replace("_", " ").replace("-", " ").strip()
    return " ".join(word.capitalize() for word in raw.split()) or "Other"


def color_for(cat_id: str, label: str) -> str:
    label_lower = label.lower()
    cat_lower = cat_id.lower()
    apple_colors = {
        "games": "#007AFF",
        "downloads": "#FF9500",
        "sys:temp_files": "#8E8E93",
        "sys:pacman": "#FFD60A",
        "sys:unified": "#AEAEB2",
        "home_other": "#636366",
        "unified_apps": "#FF3B30",
        "images": "#FF9F0A",
        "code": "#34C759",
        "documents": "#5856D6",
    }
    if cat_id in apple_colors:
        return apple_colors[cat_id]
    if "game" in label_lower:
        return "#007AFF"
    if "download" in label_lower:
        return "#FF9500"
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
    if "pacman" in label_lower:
        return "#FFD60A"
    if "cache" in label_lower or "tmp" in cat_lower or "system" in label_lower:
        return "#AEAEB2"
    return "#636366"


def add_group(data_map: dict, target_id: str, target_label: str, is_system: bool, row: dict) -> None:
    if target_id not in data_map:
        data_map[target_id] = {
            "id": target_id,
            "label": target_label,
            "size": 0,
            "disk_size": 0,
            "compressed_saved": 0,
            "count": 0,
            "color": color_for(target_id, target_label),
            "is_system": is_system,
            "breakdown": [],
        }
    data_map[target_id]["size"] += row["size"]
    data_map[target_id]["disk_size"] += row.get("disk_size", row["size"])
    data_map[target_id]["compressed_saved"] += row.get("compressed_saved", 0)
    data_map[target_id]["count"] += row["count"]
    data_map[target_id]["breakdown"].append(row)


def print_cached_json() -> int:
    meta = cache_metadata()
    if not CACHE_DB.exists():
        print(json.dumps(enrich_refresh_metadata({
            "error": "No cache found",
            "disk_total": 0,
            "disk_used": 0,
            "scanned_total": 0,
            "categorized_total": 0,
            "uncategorized_delta": 0,
            "data": [],
            **meta,
        }, None)))
        return 0

    try:
        conn = sqlite3.connect(f"file:{CACHE_DB}?mode=ro", uri=True)
        columns = {row[1] for row in conn.execute("PRAGMA table_info(files)")}
        if "disk_size" in columns and "disk_ready" in columns:
            physical_expr = "CASE WHEN disk_ready = 1 THEN disk_size ELSE size END"
            compressed_expr = "CASE WHEN disk_ready = 1 AND size > disk_size THEN size - disk_size ELSE 0 END"
            compression_missing_expr = "CASE WHEN disk_ready = 1 THEN 0 ELSE 1 END"
        elif "disk_size" in columns:
            physical_expr = "size"
            compressed_expr = "0"
            compression_missing_expr = "1"
        else:
            physical_expr = "size"
            compressed_expr = "0"
            compression_missing_expr = "1"
        rows = conn.execute(
            f"""
            SELECT cat,
                   COUNT(*),
                   SUM(size),
                   SUM({physical_expr}),
                   SUM({compressed_expr})
            FROM files
            GROUP BY cat
            ORDER BY SUM(size) DESC
            """
        ).fetchall()
        total_scanned, total_physical, total_saved, compression_missing = conn.execute(
            f"""
            SELECT
                SUM(size),
                SUM({physical_expr}),
                SUM({compressed_expr}),
                SUM({compression_missing_expr})
            FROM files
            """
        ).fetchone()
        total_scanned = total_scanned or 0
        total_physical = total_physical or 0
        total_saved = total_saved or 0
        compression_missing = compression_missing or 0
        conn.close()
    except sqlite3.Error as err:
        print(json.dumps(enrich_refresh_metadata({"error": f"Could not read storage cache: {err}", "data": []}, None)))
        return 0

    usage = shutil.disk_usage("/")
    data_map = {}

    for cat_id, count, size, disk_size, saved in rows:
        if not size:
            continue
        disk_size = int(disk_size or 0)
        saved = int(saved or 0)
        canonical = CAT_ALIASES.get(cat_id, cat_id)
        label = label_for(canonical)
        source_row = {
            "id": canonical,
            "label": label,
            "size": int(size),
            "disk_size": disk_size,
            "compressed_saved": saved,
            "count": int(count),
        }

        label_lower = label.lower()
        if canonical in APP_IDS or "application" in label_lower or "apps" in label_lower:
            add_group(data_map, "unified_apps", "Applications", False, source_row)
        elif canonical in TEMP_IDS or "temp" in label_lower or "cache" in label_lower:
            add_group(data_map, "sys:temp_files", "Arquivos temporarios", True, source_row)
        elif canonical in PACMAN_IDS:
            add_group(data_map, "sys:pacman", "Pacman", False, source_row)
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
            "disk_size": int(system_delta),
            "compressed_saved": 0,
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
        elif item["id"] == "sys:pacman":
            item["details_summary"] = "Arquivos instalados pelo gerenciador de pacotes do sistema."
        else:
            item["details_summary"] = ""

    print(json.dumps(enrich_refresh_metadata({
        "disk_total": usage.total,
        "disk_used": usage.used,
        "scanned_total": int(total_scanned),
        "physical_scanned_total": int(total_physical),
        "compressed_total": 0,
        "compressed_saved": int(total_saved),
        "compressed_source": "allocated-estimate",
        "compressed_exact": False,
        "compression_index_ready": compression_missing == 0,
        "compression_missing_count": int(compression_missing),
        "categorized_total": int(categorized_total),
        "uncategorized_delta": int(system_delta),
        "data": sorted(data_map.values(), key=lambda item: item["size"], reverse=True),
        "backend_path": None,
        "backend_fallback": "cache",
        **meta,
    }, None), ensure_ascii=False))
    return 0


def print_sense_json(sense_script: Path) -> int:
    command = [sys.executable, str(sense_script), "json"]
    env = os.environ.copy()
    env["PYTHONPATH"] = str(sense_script.parent) + os.pathsep + env.get("PYTHONPATH", "")
    try:
        result = subprocess.run(
            command,
            cwd=str(sense_script.parent),
            env=env,
            capture_output=True,
            text=True,
            timeout=SENSE_JSON_TIMEOUT,
        )
    except subprocess.TimeoutExpired as err:
        payload = {
            "error": f"StorageSense json timed out after {SENSE_JSON_TIMEOUT}s",
            "data": [],
            **cache_metadata(),
        }
        print(json.dumps(enrich_refresh_metadata(payload, sense_script), ensure_ascii=False))
        return 1
    if result.returncode != 0:
        payload = {
            "error": (result.stderr or result.stdout or "StorageSense json failed").strip(),
            "data": [],
            **cache_metadata(),
        }
    else:
        try:
            payload = json.loads(result.stdout or "{}")
            if not isinstance(payload, dict):
                payload = {"error": "Invalid StorageSense JSON", "data": []}
            payload = {**cache_metadata(), **payload}
        except json.JSONDecodeError as err:
            payload = {"error": f"Could not parse StorageSense JSON: {err}", "data": []}
    if not payload.get("refresh_running"):
        exact = compsize_stats(default_compsize_paths())
        if exact.get("exact"):
            payload["compressed_total"] = int(exact.get("compressed_total") or 0)
            payload["compressed_saved"] = int(exact.get("zstd_saved") or exact.get("compressed_saved") or 0)
            payload["zstd_disk_usage"] = int(exact.get("zstd_disk_usage") or 0)
            payload["compressed_source"] = exact.get("source") or "compsize"
            payload["compressed_exact"] = True
            payload["compressed_stale"] = bool(exact.get("stale"))
            payload["compressed_updated_at"] = exact.get("updated_at")
            payload["compressed_algorithms"] = exact.get("by_algorithm", {})
            if exact.get("error"):
                payload["compressed_error"] = exact["error"]
        else:
            payload.setdefault("compressed_source", "allocated-estimate")
            payload.setdefault("compressed_exact", False)
            if exact.get("error"):
                payload["compressed_error"] = exact["error"]
    print(json.dumps(enrich_refresh_metadata(payload, sense_script), ensure_ascii=False))
    return 0


def main() -> int:
    if sys.argv[1:2] == ["refresh-background"]:
        if len(sys.argv) < 3:
            print(json.dumps({"error": "sense script path missing"}))
            return 1
        reason = sys.argv[3] if len(sys.argv) > 3 else "manual"
        return run_refresh_background(Path(sys.argv[2]), reason)

    if sys.argv[1:2] == ["import-compsize"]:
        stats = import_compsize_cache(sys.stdin.read())
        print(json.dumps(stats, ensure_ascii=False))
        return 0

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

    if sys.argv[1:2] == ["json"]:
        return print_sense_json(sense_script)

    command = [sys.executable, str(sense_script)] + sys.argv[1:]
    env = os.environ.copy()
    env["PYTHONPATH"] = str(sense_script.parent) + os.pathsep + env.get("PYTHONPATH", "")
    return subprocess.call(command, cwd=str(sense_script.parent), env=env)


if __name__ == "__main__":
    raise SystemExit(main())
