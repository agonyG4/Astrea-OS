#!/usr/bin/env python3
"""
StorageSense -- macOS-style disk analyzer.
Requires Python 3.10+
"""

import os
import sys
import stat as stat_mod
import time
import json
import sqlite3
import argparse
from pathlib import Path
from collections import defaultdict

# -----------------------------------------
# PATHS
# -----------------------------------------
HOME       = str(Path.home())
HOME_SEP   = HOME + "/"
SCRIPT_DIR = Path(__file__).resolve().parent
CAT_FILE   = SCRIPT_DIR / "categories.json"

CACHE_DIR = Path(HOME) / ".cache" / "storagesense"
CACHE_DIR.mkdir(parents=True, exist_ok=True)
DB_PATH = CACHE_DIR / "metadata_cache.db"

# Paths to skip entirely (do not descend into)
SKIP_PREFIXES: tuple[str, ...] = (
    "/proc/", "/sys/", "/dev/", "/run/",
    "/snap/", "/boot/", "/mnt/", "/media/",
)

FLUSH_INTERVAL     = 10_000
PRINT_INTERVAL     = 100_000
DIR_FLUSH_INTERVAL = 1_000

# -----------------------------------------
# SYSTEM CATEGORIES -- hardcoded fallback
# Applied only to files OUTSIDE the home directory.
# -----------------------------------------
_IMG  = frozenset({".jpg",".jpeg",".png",".gif",".bmp",".tiff",".tif",".webp",".heic",".heif",".raw",".cr2",".nef",".arw",".svg",".avif",".dng",".psd",".xcf",".kra",".ico"})
_VID  = frozenset({".mp4",".mkv",".avi",".mov",".wmv",".flv",".webm",".m4v",".mpg",".mpeg",".ts",".m2ts",".vob",".3gp",".ogv",".rmvb"})
_AUD  = frozenset({".mp3",".flac",".aac",".ogg",".wav",".m4a",".wma",".opus",".aiff",".mid",".midi",".ape",".mka",".alac"})
_DOC  = frozenset({".pdf",".doc",".docx",".odt",".rtf",".tex",".md",".rst",".txt",".xls",".xlsx",".ods",".ppt",".pptx",".odp",".csv",".epub",".mobi",".djvu"})
_ARCH = frozenset({".zip",".tar",".gz",".bz2",".xz",".zst",".7z",".rar",".lz4",".lzma",".deb",".rpm",".pkg",".apk",".iso",".img",".dmg",".cab",".flatpak"})
_APP  = frozenset({".appimage",".exe",".msi",".bin",".run"})
_FONT = frozenset({".ttf",".otf",".woff",".woff2",".eot"})
_VM   = frozenset({".vmdk",".vdi",".vhd",".vhdx",".qcow2",".ova",".ovf"})
_CODE = frozenset({".py",".js",".ts",".rs",".go",".c",".cpp",".h",".java",".rb",".php",".lua",".sh",".toml",".yaml",".yml",".json",".xml",".html",".css",".sql",".qml"})

_GAME_SEGS = frozenset({"steamapps","games","heroic","lutris","wine","proton","compatdata"})

# Prefixes that clearly indicate manually installed apps
_APP_PREFIXES = ("/opt/",)

# Pure system prefixes (libs, bins, config)
_SYS_PREFIXES = ("/usr/","/lib/","/lib64/","/bin/","/sbin/","/etc/","/snap/")
_TMP_PREFIXES = ("/tmp/","/var/tmp/","/var/cache/","/var/log/")

SYS_CAT_META: dict[str, tuple[str, str]] = {
    "sys:games":    ("Games (system)",   ""),
    "sys:vms":      ("Virtual Machines", ""),
    "sys:archives": ("Archives",         ""),
    "sys:fonts":    ("Fonts",            ""),
    "sys:apps":     ("Applications",     ""),
    "sys:images":   ("Images",           ""),
    "sys:videos":   ("Videos",           ""),
    "sys:audio":    ("Audio",            ""),
    "sys:docs":     ("Documents",        ""),
    "sys:code":     ("Code",             ""),
    "sys:tmp":      ("System Temp",      ""),
    "sys:system":   ("System",           ""),
    "sys:other":    ("Other (system)",   ""),
}


def resolve_system_category(path_str: str, ext: str, dir_parts: frozenset[str]) -> str:
    # Games take top priority -- can live anywhere
    if dir_parts & _GAME_SEGS:
        return "sys:games"

    # /opt/ -> manually installed apps (Discord, etc.)
    for p in _APP_PREFIXES:
        if path_str.startswith(p):
            return "sys:apps"

    # File-type extensions
    if ext in _VM:   return "sys:vms"
    if ext in _ARCH: return "sys:archives"
    if ext in _FONT: return "sys:fonts"
    if ext in _APP:  return "sys:apps"
    if ext in _IMG:  return "sys:images"
    if ext in _VID:  return "sys:videos"
    if ext in _AUD:  return "sys:audio"
    if ext in _DOC:  return "sys:docs"
    if ext in _CODE: return "sys:code"

    # System temp/cache
    for p in _TMP_PREFIXES:
        if path_str.startswith(p):
            return "sys:tmp"

    # Pure system paths
    for p in _SYS_PREFIXES:
        if path_str.startswith(p):
            return "sys:system"

    return "sys:other"


# -----------------------------------------
# LOAD AND COMPILE CATEGORIES.JSON
# -----------------------------------------
def load_categories() -> dict:
    if not CAT_FILE.exists():
        print(f"Error: {CAT_FILE} not found.", file=sys.stderr)
        sys.exit(1)
    try:
        with open(CAT_FILE, encoding="utf-8") as f:
            raw = json.load(f)
    except json.JSONDecodeError as e:
        print(f"Error reading categories.json: {e}", file=sys.stderr)
        sys.exit(1)
    return {k: v for k, v in raw.items() if not k.startswith("_")}


def compile_categories(categories: dict) -> dict:
    """Pre-compute absolute prefixes and frozensets for fast lookup."""
    compiled = {}
    for cat_id, cat in categories.items():
        inc_prefixes = []
        for p in cat.get("include_paths", []):
            abs_p = os.path.realpath(os.path.expandvars(os.path.expanduser(p)))
            inc_prefixes.append(abs_p + "/")

        compiled[cat_id] = {
            "label":            cat.get("label", cat_id),
            "emoji":            cat.get("emoji", ""),
            "include_prefixes": inc_prefixes,
            "exclude_parts":    frozenset(p.lower() for p in cat.get("exclude_parts", [])),
            "match_dirs":       frozenset(d.lower() for d in cat.get("match_dirs", [])),
            "extensions":       frozenset(e.lower() for e in cat.get("extensions", [])),
        }
    return compiled


# -----------------------------------------
# RESOLVE CATEGORY
# -----------------------------------------
def resolve_category(path_str: str, ext: str, dir_parts: frozenset[str],
                     compiled: dict) -> str:
    """
    Iterates categories in JSON order; the first match wins.
    Categories without defined extensions match any file inside
    their include_paths -- useful for 'downloads' as a catch-all.
    """
    if not path_str.startswith(HOME_SEP):
        return resolve_system_category(path_str, ext, dir_parts)

    for cat_id, cat in compiled.items():
        # Exclusion filter
        if cat["exclude_parts"] and (cat["exclude_parts"] & dir_parts):
            continue

        # Path filter
        inc = cat["include_prefixes"]
        if inc and not any(path_str.startswith(p) for p in inc):
            continue

        # Match by special directory name
        if cat["match_dirs"] and (cat["match_dirs"] & dir_parts):
            return cat_id

        # Match by extension (or catch-all if list is empty)
        if not cat["extensions"] or ext in cat["extensions"]:
            return cat_id

    return "home_other"


def build_cat_meta(compiled: dict) -> dict[str, tuple[str, str]]:
    meta = {cat_id: (cat["label"], "") for cat_id, cat in compiled.items()}
    meta["home_other"] = ("Other (Home)", "")
    meta.update(SYS_CAT_META)
    return meta


CAT_ALIASES: dict[str, str] = {
    "sys_other": "sys:other",
    "sys_games": "sys:games",
    "sys_vms": "sys:vms",
    "sys_archives": "sys:archives",
    "sys_fonts": "sys:fonts",
    "sys_images": "sys:images",
    "sys_videos": "sys:videos",
    "sys_audio": "sys:audio",
    "sys_docs": "sys:docs",
    "sys_code": "sys:code",
    "sys_tmp": "sys:tmp",
    "sys_system": "sys:system",
    "docs": "documents",
}

DISPLAY_LABELS: dict[str, str] = {
    "home_other": "Outros arquivos pessoais",
    "documents": "Documentos",
    "images": "Imagens",
    "videos": "Vídeos",
    "music": "Músicas",
    "code": "Código / GitHub",
    "archives": "Arquivos compactados",
    "tmp": "Arquivos temporários",
    "fonts": "Fontes",
    "config": "Configurações",
    "app_executables": "Executáveis avulsos",
    "unified_apps": "Applications",
    "sys:unified": "System",
    "sys:temp_files": "Arquivos temporários",
    "sys:other": "Arquivos de sistema",
    "sys:system": "Base do sistema",
    "sys:games": "Jogos fora da pasta pessoal",
    "sys:archives": "Arquivos compactados do sistema",
    "sys:fonts": "Fontes do sistema",
    "sys:code": "Código do sistema",
    "sys:docs": "Documentos do sistema",
    "sys:images": "Imagens do sistema",
    "sys:videos": "Vídeos do sistema",
    "sys:audio": "Áudio do sistema",
}

HIDDEN_CATEGORY_IDS: set[str] = {
    "archives",
    "sys:archives",
}


def canonical_category_id(cat_id: str) -> str:
    return CAT_ALIASES.get(cat_id, cat_id)


def humanize_category_id(cat_id: str) -> str:
    if cat_id in DISPLAY_LABELS:
        return DISPLAY_LABELS[cat_id]
    raw = cat_id.replace("sys:", "").replace("_", " ").replace("-", " ").strip()
    if not raw:
        return "Other"
    words = raw.split()
    return " ".join(word.capitalize() for word in words)


def display_label(cat_id: str, fallback: str = "") -> str:
    if cat_id in DISPLAY_LABELS:
        return DISPLAY_LABELS[cat_id]
    if fallback:
        return fallback
    return humanize_category_id(cat_id)


def get_cache_metadata() -> dict[str, object]:
    if not DB_PATH.exists():
        return {
            "cache_exists": False,
            "cache_path": str(DB_PATH),
            "cache_updated_at": None,
            "cache_updated_ago_seconds": None,
            "cache_size": 0,
        }

    updated_at = DB_PATH.stat().st_mtime
    return {
        "cache_exists": True,
        "cache_path": str(DB_PATH),
        "cache_updated_at": updated_at,
        "cache_updated_ago_seconds": max(0, time.time() - updated_at),
        "cache_size": DB_PATH.stat().st_size,
    }


# -----------------------------------------
# UTILITIES
# -----------------------------------------
def format_size(size: float) -> str:
    for unit in ["B", "KB", "MB", "GB", "TB"]:
        if size < 1024:
            return f"{size:.1f} {unit}"
        size /= 1024
    return f"{size:.1f} PB"


def bar(fraction: float, width: int = 22) -> str:
    filled = round(fraction * width)
    return "#" * filled + "-" * (width - filled)


# -----------------------------------------
# DATABASE
# -----------------------------------------
def get_conn() -> sqlite3.Connection:
    conn = sqlite3.connect(DB_PATH)
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute("PRAGMA synchronous=NORMAL")
    conn.execute("PRAGMA cache_size=-32000")
    conn.execute("""
        CREATE TABLE IF NOT EXISTS files (
            path  TEXT PRIMARY KEY,
            size  INTEGER NOT NULL,
            mtime REAL    NOT NULL,
            cat   TEXT    NOT NULL
        )
    """)
    conn.execute("""
        CREATE TABLE IF NOT EXISTS dirs (
            path  TEXT PRIMARY KEY,
            mtime REAL    NOT NULL
        )
    """)
    conn.execute("CREATE INDEX IF NOT EXISTS idx_cat ON files(cat)")
    conn.commit()
    return conn


def load_cache(
    conn: sqlite3.Connection,
) -> tuple[dict[str, tuple[int, float, str]], dict[str, list[str]]]:
    """
    Returns:
      cache     -- {path: (size, mtime, cat)}
      dir_index -- {dirpath: [path, ...]}  (direct children only, not recursive)

    The dir_index allows directory cache lookups in O(1) without a full
    linear scan, and without accidentally including files from subdirectories.
    """
    cur = conn.execute("SELECT path, size, mtime, cat FROM files")
    cache: dict[str, tuple[int, float, str]] = {}
    dir_index: dict[str, list[str]] = defaultdict(list)

    for path, size, mtime, cat in cur:
        cache[path] = (size, mtime, cat)
        # Use the immediate parent directory -- not a recursive prefix
        parent = str(Path(path).parent)
        dir_index[parent].append(path)

    return cache, dir_index


def load_dir_cache(conn: sqlite3.Connection) -> dict[str, float]:
    cur = conn.execute("SELECT path, mtime FROM dirs")
    return {row[0]: row[1] for row in cur}


def flush(conn: sqlite3.Connection, entries: list) -> None:
    if entries:
        conn.executemany("INSERT OR REPLACE INTO files VALUES (?,?,?,?)", entries)
        conn.commit()


def flush_dirs(conn: sqlite3.Connection, entries: list[tuple[str, float]]) -> None:
    if entries:
        conn.executemany("INSERT OR REPLACE INTO dirs VALUES (?,?)", entries)
        conn.commit()


def prune(conn: sqlite3.Connection, old: set, current: set) -> int:
    stale = old - current
    if stale:
        conn.executemany("DELETE FROM files WHERE path=?", [(p,) for p in stale])
        conn.commit()
    return len(stale)


# -----------------------------------------
# MOUNTINFO -- allowed devices
# -----------------------------------------
def get_allowed_devs() -> set[int]:
    """Returns the set of st_dev values for partitions mounted on the root filesystem."""
    devs: set[int] = set()
    try:
        with open("/proc/self/mountinfo") as f:
            for line in f:
                try:
                    devs.add(os.stat(line.split()[4]).st_dev)
                except OSError:
                    pass
    except OSError:
        devs.add(os.stat("/").st_dev)
    return devs


# -----------------------------------------
# SCAN
# -----------------------------------------
def _walk_and_classify(
    compiled: dict,
    allowed_devs: set[int],
    quiet: bool,
) -> tuple[dict, set, int, int, int, int]:
    """
    Walks the filesystem and classifies every regular file.
    Returns (stats, scanned_paths, scanned_count, updated_count, error_count, pruned_count).
    """
    conn                = get_conn()
    cache, dir_index    = load_cache(conn)
    dir_cache           = load_dir_cache(conn)
    stats: dict[str, int]             = defaultdict(int)
    new_entries: list                 = []
    new_dirs: list[tuple[str, float]] = []
    scanned_paths: set                = set()
    scanned = updated = errors = 0
    start = time.monotonic()

    for dirpath, dirnames, filenames in os.walk("/", followlinks=False):
        # Skip forbidden prefixes
        if any(dirpath == sp.rstrip("/") or dirpath.startswith(sp)
               for sp in SKIP_PREFIXES):
            dirnames[:] = []
            continue

        # Skip external devices
        try:
            dir_stat = os.stat(dirpath)
        except OSError:
            dirnames[:] = []
            continue

        if dir_stat.st_dev not in allowed_devs:
            dirnames[:] = []
            continue

        dir_mtime        = dir_stat.st_mtime
        cached_dir_mtime = dir_cache.get(dirpath)

        # -- Cache hit: directory unchanged since last scan ------------------
        # Uses dir_index to access only the direct children of this directory,
        # avoiding both an O(n) scan of the full cache and double-counting
        # files that belong to modified subdirectories.
        if cached_dir_mtime == dir_mtime:
            for path_str in dir_index.get(dirpath, []):
                cached = cache.get(path_str)
                if not cached:
                    continue
                size, _mtime, cat = cached
                stats[cat] += size
                scanned_paths.add(path_str)
                scanned += 1
            continue

        # -- Cache miss: process files individually --------------------------
        dir_parts = frozenset(p.lower() for p in dirpath.split("/") if p)
        dirnames.sort()

        for filename in filenames:
            path_str = dirpath.rstrip("/") + "/" + filename
            try:
                st = os.stat(path_str, follow_symlinks=False)
                if not stat_mod.S_ISREG(st.st_mode):
                    continue

                size  = st.st_size
                mtime = st.st_mtime
                scanned_paths.add(path_str)

                cached = cache.get(path_str)
                if cached and cached[1] == mtime:
                    cat = cached[2]
                else:
                    dot = filename.rfind(".")
                    ext = filename[dot:].lower() if dot > 0 else ""
                    cat = resolve_category(path_str, ext, dir_parts, compiled)
                    new_entries.append((path_str, size, mtime, cat))
                    cache[path_str] = (size, mtime, cat)
                    parent = dirpath
                    if path_str not in dir_index[parent]:
                        dir_index[parent].append(path_str)
                    updated += 1

                stats[cat] += size
                scanned += 1

                if len(new_entries) >= FLUSH_INTERVAL:
                    flush(conn, new_entries)
                    new_entries.clear()

                if not quiet and scanned % PRINT_INTERVAL == 0:
                    elapsed = time.monotonic() - start
                    rate    = scanned / elapsed if elapsed > 0 else 0
                    print(f"  {scanned:>10,} files  |  {rate:,.0f} files/s", end="\r")

            except OSError:
                errors += 1

        # Record directory mtime only after successful processing
        new_dirs.append((dirpath, dir_mtime))
        if len(new_dirs) >= DIR_FLUSH_INTERVAL:
            flush_dirs(conn, new_dirs)
            new_dirs.clear()

    flush(conn, new_entries)
    flush_dirs(conn, new_dirs)
    pruned = prune(conn, set(cache.keys()), scanned_paths)
    conn.close()
    return stats, scanned_paths, scanned, updated, errors, pruned


def scan_all(compiled: dict, quiet: bool) -> tuple[dict[str, int], int, int, int, int, float]:
    if not quiet:
        print(f"\nScanning /  --  cache at {DB_PATH}")

    allowed_devs = get_allowed_devs()
    start        = time.monotonic()

    stats, scanned_paths, scanned, updated, errors, pruned = \
        _walk_and_classify(compiled, allowed_devs, quiet)

    elapsed = time.monotonic() - start
    return stats, scanned, updated, pruned, errors, elapsed


# -----------------------------------------
# REPORT
# -----------------------------------------
W = 68


def sep(char: str = "-") -> None:
    print(char * W)


def _print_rows(rows: list[tuple[str, str, int]], total: int) -> None:
    for label, _emoji, size in rows:
        frac = size / total
        print(f"  {label:<26}  {format_size(size):>9}  {frac*100:>4.1f}%  {bar(frac)}")


def print_scan_report(stats: dict, cat_meta: dict,
                      scanned: int, updated: int, pruned: int,
                      errors: int, elapsed: float) -> None:
    total = sum(stats.values()) or 1
    rate  = scanned / elapsed if elapsed > 0 else 0

    home_rows: list[tuple[str, str, int]] = []
    sys_rows:  list[tuple[str, str, int]] = []

    for cat_id, size in stats.items():
        if size == 0:
            continue
        label, emoji = cat_meta.get(cat_id, (cat_id, ""))
        entry = (label, emoji, size)
        (sys_rows if cat_id.startswith("sys:") else home_rows).append(entry)

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
    _print_rows(home_rows, total)

    sep()
    print("  / SYSTEM")
    sep()
    _print_rows(sys_rows, total)

    sep()
    print(f"  {'TOTAL':<26}  {format_size(total):>9}")
    print("=" * W)
    print()


# -----------------------------------------
# CACHE INFO
# -----------------------------------------
def print_cache_info(cat_meta: dict) -> None:
    if not DB_PATH.exists():
        print("No cache found. Run `storagesense scan`.")
        return

    conn    = get_conn()
    n_files = conn.execute("SELECT COUNT(*) FROM files").fetchone()[0]
    vol     = conn.execute("SELECT SUM(size) FROM files").fetchone()[0] or 0
    db_size = DB_PATH.stat().st_size
    rows    = conn.execute(
        "SELECT cat, COUNT(*), SUM(size) FROM files GROUP BY cat ORDER BY SUM(size) DESC"
    ).fetchall()
    conn.close()

    print()
    print("=" * W)
    print(f"  CACHE INFO  --  {DB_PATH}")
    sep()
    print(f"  Database:      {format_size(db_size)}")
    print(f"  Files:         {n_files:,}")
    print(f"  Total volume:  {format_size(vol)}")
    sep()
    print(f"  {'CATEGORY':<26}  {'FILES':>10}  {'SIZE':>10}")
    sep()
    for cat_id, count, sz in rows:
        label, _emoji = cat_meta.get(cat_id, (cat_id or "(no category)", ""))
        print(f"  {label:<26}  {count:>10,}  {format_size(sz or 0):>10}")
    print("=" * W)
    print()


# -----------------------------------------
# LIST
# -----------------------------------------
def print_list(compiled: dict) -> None:
    conn = get_conn()
    print()
    print("=" * W)
    print(f"  CATEGORIES  ({CAT_FILE.name})")
    sep()
    print(f"  {'ID':<16}  {'LABEL':<22}  {'EXTS':>5}  {'IN CACHE':>10}")
    sep()
    for cat_id, cat in compiled.items():
        label = cat["label"]
        exts  = len(cat["extensions"])
        count = conn.execute(
            "SELECT COUNT(*) FROM files WHERE cat=?", (cat_id,)
        ).fetchone()[0]
        catch = "  (catch-all)" if not cat["extensions"] else ""
        print(f"  {cat_id:<16}  {label:<22}  {exts:>5}  {count:>10,}{catch}")
    conn.close()
    print("=" * W)
    print()


# -----------------------------------------
# JSON OUTPUT
# -----------------------------------------
def print_json(compiled: dict, cat_meta: dict) -> None:
    cache_meta = get_cache_metadata()
    if not DB_PATH.exists():
        print(json.dumps({
            "error": "No cache found",
            "disk_total": 0,
            "disk_used": 0,
            "scanned_total": 0,
            "categorized_total": 0,
            "uncategorized_delta": 0,
            "data": [],
            **cache_meta,
        }))
        return

    import shutil
    du = shutil.disk_usage("/")
    disk_total = du.total
    disk_used  = du.used

    conn = get_conn()
    total_scanned = conn.execute("SELECT SUM(size) FROM files").fetchone()[0] or 0
    rows = conn.execute(
        "SELECT cat, COUNT(*), SUM(size) FROM files GROUP BY cat ORDER BY SUM(size) DESC"
    ).fetchall()
    conn.close()

    def get_color(cat_id: str, label: str) -> str:
        l = label.lower()
        i = cat_id.lower()
        # Apple SF Colors / macOS palette
        if "game" in l:                                                   return "#007AFF"
        if "download" in l:                                               return "#FFD426"
        if "image" in l or "photo" in l:                                  return "#FF9F0A"
        if "video" in l:                                                  return "#AF52DE"
        if "music" in l or "audio" in l:                                  return "#FF2D55"
        if "doc" in l:                                                    return "#FF9500"
        if "code" in l or "github" in l:                                  return "#34C759"
        if "archive" in i or "archive" in l:                              return "#5856D6"
        if i == "unified_apps" or "app" in l or "flatpak" in i:           return "#FF3B30"
        if "cache" in l or "tmp" in i or "system" in l or "config" in i:  return "#AEAEB2"
        return "#636366"

    data_map = {}
    APP_IDS = {"sys:apps", "flatpak", "spotify", "apps", "app_executables"}
    TEMP_IDS = {"tmp", "cache", "sys:tmp"}
    SYS_IDS = {
        "sys:system", "sys:other", "sys:games", "sys:vms",
        "sys:archives", "sys:fonts", "sys:images", "sys:videos",
        "sys:audio", "sys:docs", "sys:code", "config", "fonts",
    }

    for cat_id, count, sz in rows:
        if not sz:
            continue
        canonical_id = canonical_category_id(cat_id)
        source_label, _emoji = cat_meta.get(
            canonical_id,
            cat_meta.get(cat_id, (humanize_category_id(canonical_id or "Other"), "")),
        )
        label = display_label(canonical_id, source_label)

        target_id    = canonical_id
        target_label = label
        is_system    = canonical_id.startswith("sys:")

        label_lower = label.lower()

        if canonical_id in HIDDEN_CATEGORY_IDS:
            if canonical_id.startswith("sys:"):
                target_id = "sys:unified"
                target_label = "System"
                is_system = True
            else:
                target_id = "home_other"
                target_label = display_label("home_other")
                is_system = False

        elif canonical_id in APP_IDS or "application" in label_lower or "apps" in label_lower:
            target_id    = "unified_apps"
            target_label = "Applications"
            is_system    = False

        elif canonical_id in TEMP_IDS or "temp" in label_lower or "cache" in label_lower:
            target_id    = "sys:temp_files"
            target_label = "Arquivos temporários"
            is_system    = True

        elif (
            is_system
            or canonical_id in SYS_IDS
            or "system" in label_lower
            or "font" in label_lower
        ):
            target_id    = "sys:unified"
            target_label = "System"
            is_system    = True

        if target_id not in data_map:
            data_map[target_id] = {
                "id":        target_id,
                "label":     target_label,
                "size":      0,
                "count":     0,
                "color":     get_color(target_id, target_label),
                "is_system": is_system,
                "breakdown": [],
            }

        data_map[target_id]["size"]  += sz
        data_map[target_id]["count"] += count
        data_map[target_id]["breakdown"].append({
            "id": canonical_id,
            "label": label,
            "size": sz,
            "count": count,
        })

    categorized_total = sum(d["size"] for d in data_map.values())
    system_delta = max(0, disk_used - categorized_total)
    if system_delta > 1024 * 1024:
        if "sys:unified" in data_map:
            data_map["sys:unified"]["size"] += system_delta
            data_map["sys:unified"]["breakdown"].append({
                "id": "disk_gap",
                "label": "Espaço usado fora do índice",
                "size": system_delta,
                "count": 0,
            })
        else:
            data_map["sys:unified"] = {
                "id":        "sys:unified",
                "label":     "System",
                "size":      system_delta,
                "count":     0,
                "color":     get_color("sys:unified", "System"),
                "is_system": True,
                "breakdown": [{
                    "id": "disk_gap",
                    "label": "Espaço usado fora do índice",
                    "size": system_delta,
                    "count": 0,
                }],
            }

    for item in data_map.values():
        item["breakdown"].sort(key=lambda x: x["size"], reverse=True)
        item["breakdown"] = [
            entry for entry in item["breakdown"]
            if entry["id"] not in HIDDEN_CATEGORY_IDS
        ]
        item["breakdown"] = item["breakdown"][:6]
        if item["id"] == "sys:unified":
            item["details_summary"] = "Bibliotecas, arquivos base do sistema, fontes, configs e conteúdo fora da pasta pessoal."
        elif item["id"] == "sys:temp_files":
            item["details_summary"] = "Caches, diretórios temporários e logs que podem crescer com o uso."
        elif item["id"] == "home_other":
            item["details_summary"] = "Arquivos pessoais que não entraram nas categorias principais."
        elif item["id"] == "unified_apps":
            item["details_summary"] = "Apps instalados no home, Flatpaks e executáveis."
        else:
            item["details_summary"] = ""

    final_data = sorted(data_map.values(), key=lambda x: x["size"], reverse=True)
    print(json.dumps({
        "disk_total":    disk_total,
        "disk_used":     disk_used,
        "scanned_total": total_scanned,
        "categorized_total": categorized_total,
        "uncategorized_delta": system_delta,
        "data":          final_data,
        **cache_meta,
    }, ensure_ascii=False))


# -----------------------------------------
# CLI
# -----------------------------------------
def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        prog="storagesense",
        description="macOS-style storage analyzer.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
examples:
  storagesense scan
  storagesense scan --quiet
  storagesense list
  storagesense info
  storagesense clear-cache
        """,
    )
    sub = p.add_subparsers(dest="command", metavar="<command>")
    scan_p = sub.add_parser("scan", help="Scan the disk and display a report")
    scan_p.add_argument("--quiet", "-q", action="store_true", help="No progress output")
    sub.add_parser("list",        help="List categories from the JSON file")
    sub.add_parser("info",        help="Show cache info")
    sub.add_parser("json",        help="Output results as JSON for integration")
    sub.add_parser("clear-cache", help="Delete the cache")
    return p


def main() -> None:
    parser = build_parser()
    args   = parser.parse_args()

    if args.command is None:
        parser.print_help()
        sys.exit(0)

    categories = load_categories()
    compiled   = compile_categories(categories)
    cat_meta   = build_cat_meta(compiled)

    match args.command:
        case "scan":
            stats, scanned, updated, pruned, errors, elapsed = scan_all(compiled, args.quiet)
            print_scan_report(stats, cat_meta, scanned, updated, pruned, errors, elapsed)
        case "list":
            print_list(compiled)
        case "info":
            print_cache_info(cat_meta)
        case "json":
            print_json(compiled, cat_meta)
        case "clear-cache":
            if DB_PATH.exists():
                DB_PATH.unlink()
                print(f"Cache removed: {DB_PATH}")
            else:
                print("No cache found.")


if __name__ == "__main__":
    main()
