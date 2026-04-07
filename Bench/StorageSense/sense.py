#!/usr/bin/env python3
"""
StorageSense — analisador de disco estilo macOS.
Requer Python 3.10+
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

# ─────────────────────────────────────────
# CAMINHOS
# ─────────────────────────────────────────
HOME       = str(Path.home())
HOME_SEP   = HOME + "/"
SCRIPT_DIR = Path(__file__).resolve().parent
CAT_FILE   = SCRIPT_DIR / "categories.json"

CACHE_DIR = Path(HOME) / ".cache" / "storagesense"
CACHE_DIR.mkdir(parents=True, exist_ok=True)
DB_PATH = CACHE_DIR / "metadata_cache.db"

# Paths para pular completamente (não entrar)
SKIP_PREFIXES: tuple[str, ...] = (
    "/proc/", "/sys/", "/dev/", "/run/",
    "/snap/", "/boot/", "/mnt/", "/media/",
)

FLUSH_INTERVAL = 10_000
PRINT_INTERVAL = 100_000
DIR_FLUSH_INTERVAL = 1_000

# ─────────────────────────────────────────
# CATEGORIAS DE SISTEMA — fallback hardcoded
# Aplicadas apenas para arquivos FORA do home.
# ─────────────────────────────────────────
_IMG  = frozenset({".jpg",".jpeg",".png",".gif",".bmp",".tiff",".tif",".webp",".heic",".heif",".raw",".cr2",".nef",".arw",".svg",".avif",".dng",".psd",".xcf",".kra",".ico"})
_VID  = frozenset({".mp4",".mkv",".avi",".mov",".wmv",".flv",".webm",".m4v",".mpg",".mpeg",".ts",".m2ts",".vob",".3gp",".ogv",".rmvb"})
_AUD  = frozenset({".mp3",".flac",".aac",".ogg",".wav",".m4a",".wma",".opus",".aiff",".mid",".midi",".ape",".mka",".alac"})
_DOC  = frozenset({".pdf",".doc",".docx",".odt",".rtf",".tex",".md",".rst",".txt",".xls",".xlsx",".ods",".ppt",".pptx",".odp",".csv",".epub",".mobi",".djvu"})
_ARCH = frozenset({".zip",".tar",".gz",".bz2",".xz",".zst",".7z",".rar",".lz4",".lzma",".deb",".rpm",".pkg",".apk",".iso",".img",".dmg",".cab",".flatpak"})
_APP  = frozenset({".appimage",".exe",".msi",".bin",".run"})
_FONT = frozenset({".ttf",".otf",".woff",".woff2",".eot"})
_VM   = frozenset({".vmdk",".vdi",".vhd",".vhdx",".qcow2",".ova",".ovf"})
_CODE = frozenset({".py",".js",".ts",".rs",".go",".c",".cpp",".h",".java",".rb",".php",".lua",".sh",".toml",".yaml",".yml",".json",".xml",".html",".css",".sql"})

_GAME_SEGS  = frozenset({"steamapps","games","heroic","lutris","wine","proton","compatdata"})

# Prefixos que são claramente apps instalados
_APP_PREFIXES = ("/opt/",)

# Prefixos de sistema puro (libs, bins, config)
_SYS_PREFIXES = ("/usr/","/lib/","/lib64/","/bin/","/sbin/","/etc/","/snap/")
_TMP_PREFIXES = ("/tmp/","/var/tmp/","/var/cache/","/var/log/")

SYS_CAT_META: dict[str, tuple[str, str]] = {
    "sys:games":   ("Games (sistema)",  ""),
    "sys:vms":     ("Máq. Virtuais",    ""),
    "sys:archives house":("Arquivos",         ""),
    "sys:fonts":   ("Fontes",           ""),
    "sys:apps":    ("Aplicativos",      ""),
    "sys:images":  ("Imagens",          ""),
    "sys:videos":  ("Vídeos",           ""),
    "sys:audio":   ("Áudio",            ""),
    "sys:docs":    ("Documentos",       ""),
    "sys:code":    ("Código",           ""),
    "sys:tmp":     ("Temp Sistema",     ""),
    "sys:system":  ("Sistema",          ""),
    "sys:other":   ("Outros (sistema)", ""),
}


def resolve_system_category(path_str: str, ext: str, dir_parts: frozenset[str]) -> str:
    # Jogos têm prioridade máxima — podem estar em qualquer lugar
    if dir_parts & _GAME_SEGS:
        return "sys:games"

    # /opt/ → apps instalados manualmente (Discord, Zen, etc.)
    for p in _APP_PREFIXES:
        if path_str.startswith(p):
            return "sys:apps"

    # Extensões de tipo de arquivo
    if ext in _VM:   return "sys:vms"
    if ext in _ARCH: return "sys:archives"
    if ext in _FONT: return "sys:fonts"
    if ext in _APP:  return "sys:apps"
    if ext in _IMG:  return "sys:images"
    if ext in _VID:  return "sys:videos"
    if ext in _AUD:  return "sys:audio"
    if ext in _DOC:  return "sys:docs"
    if ext in _CODE: return "sys:code"

    # Temp/cache de sistema
    for p in _TMP_PREFIXES:
        if path_str.startswith(p):
            return "sys:tmp"

    # Sistema puro
    for p in _SYS_PREFIXES:
        if path_str.startswith(p):
            return "sys:system"

    return "sys:other"


# ─────────────────────────────────────────
# CARREGA E COMPILA CATEGORIES.JSON
# ─────────────────────────────────────────
def load_categories() -> dict:
    if not CAT_FILE.exists():
        print(f"Erro: {CAT_FILE} não encontrado.", file=sys.stderr)
        sys.exit(1)
    try:
        with open(CAT_FILE, encoding="utf-8") as f:
            raw = json.load(f)
    except json.JSONDecodeError as e:
        print(f"Erro ao ler categories.json: {e}", file=sys.stderr)
        sys.exit(1)
    return {k: v for k, v in raw.items() if not k.startswith("_")}


def compile_categories(categories: dict) -> dict:
    """Pré-computa prefixos absolutos e frozensets para lookup rápido."""
    compiled = {}
    for cat_id, cat in categories.items():
        inc_prefixes = []
        for p in cat.get("include_paths", []):
            abs_p = os.path.realpath(os.path.expandvars(os.path.expanduser(p)))
            inc_prefixes.append(abs_p + "/")

        compiled[cat_id] = {
            "label":            cat.get("label", cat_id),
            "emoji":            cat.get("emoji", "📁"),
            "include_prefixes": inc_prefixes,
            "exclude_parts":    frozenset(p.lower() for p in cat.get("exclude_parts", [])),
            "match_dirs":       frozenset(d.lower() for d in cat.get("match_dirs", [])),
            "extensions":       frozenset(e.lower() for e in cat.get("extensions", [])),
        }
    return compiled


# ─────────────────────────────────────────
# RESOLVE CATEGORIA
# ─────────────────────────────────────────
def resolve_category(path_str: str, ext: str, dir_parts: frozenset[str],
                     compiled: dict) -> str:
    """
    Percorre as categorias na ordem do JSON.
    A primeira que casar (path + extensão ou match_dir) vence.
    Categorias sem extensões definidas casam com qualquer arquivo
    dentro dos include_paths — útil para 'downloads' ser um catch-all.
    """
    if not path_str.startswith(HOME_SEP):
        return resolve_system_category(path_str, ext, dir_parts)

    for cat_id, cat in compiled.items():
        # Filtro de exclusão
        if cat["exclude_parts"] and (cat["exclude_parts"] & dir_parts):
            continue

        # Filtro de caminho
        inc = cat["include_prefixes"]
        if inc and not any(path_str.startswith(p) for p in inc):
            continue

        # Casamento por diretório especial
        if cat["match_dirs"] and (cat["match_dirs"] & dir_parts):
            return cat_id

        # Casamento por extensão (ou catch-all se lista vazia)
        if not cat["extensions"] or ext in cat["extensions"]:
            return cat_id

    return "home_other"


def build_cat_meta(compiled: dict) -> dict[str, tuple[str, str]]:
    meta = {cat_id: (cat["label"], "") for cat_id, cat in compiled.items()}
    meta["home_other"] = ("Outros (Home)", "")
    meta.update(SYS_CAT_META)
    return meta


# ─────────────────────────────────────────
# UTILITÁRIOS
# ─────────────────────────────────────────
def format_size(size: float) -> str:
    for unit in ["B", "KB", "MB", "GB", "TB"]:
        if size < 1024:
            return f"{size:.1f} {unit}"
        size /= 1024
    return f"{size:.1f} PB"


def bar(fraction: float, width: int = 22) -> str:
    filled = round(fraction * width)
    return "█" * filled + "░" * (width - filled)


# ─────────────────────────────────────────
# BANCO
# ─────────────────────────────────────────
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


def load_cache(conn: sqlite3.Connection) -> dict[str, tuple[int, float, str]]:
    cur = conn.execute("SELECT path, size, mtime, cat FROM files")
    return {row[0]: (row[1], row[2], row[3]) for row in cur}


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


# ─────────────────────────────────────────
# MOUNTINFO — dispositivos permitidos
# ─────────────────────────────────────────
def get_allowed_devs() -> set[int]:
    """Retorna o conjunto de st_dev das partições montadas no sistema de arquivos raiz."""
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


# ─────────────────────────────────────────
# SCAN
# ─────────────────────────────────────────
def _walk_and_classify(compiled: dict, allowed_devs: set[int],
                       quiet: bool) -> tuple[dict, set, int, int, int]:
    """
    Percorre o sistema de arquivos e classifica cada arquivo regular.
    Retorna (stats, scanned_paths, scanned_count, updated_count, error_count).
    """
    conn          = get_conn()
    cache         = load_cache(conn)
    dir_cache     = load_dir_cache(conn)
    stats: dict[str, int] = defaultdict(int)
    new_entries: list     = []
    new_dirs: list[tuple[str, float]] = []
    scanned_paths: set    = set()
    scanned = updated = errors = 0
    start = time.monotonic()

    for dirpath, dirnames, filenames in os.walk("/", followlinks=False):
        # Pula prefixos proibidos
        if any(dirpath == sp.rstrip("/") or dirpath.startswith(sp)
               for sp in SKIP_PREFIXES):
            dirnames[:] = []
            continue

        # Pula dispositivos externos
        try:
            dir_stat = os.stat(dirpath)
            if dir_stat.st_dev not in allowed_devs:
                dirnames[:] = []
                continue
        except OSError:
            continue

        dir_parts = frozenset(p.lower() for p in dirpath.split("/") if p)
        dirnames.sort()

        dir_mtime = dir_stat.st_mtime
        cached_dir_mtime = dir_cache.get(dirpath)

        # Se o diretório não mudou, ainda contamos os arquivos do cache
        # sem re-statar/reclassificar cada um.
        if cached_dir_mtime == dir_mtime:
            prefix = dirpath.rstrip("/") + "/"
            for path_str, (size, _mtime, cat) in cache.items():
                if path_str.startswith(prefix):
                    stats[cat] += size
                    scanned_paths.add(path_str)
                    scanned += 1
            continue

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
                    updated += 1

                stats[cat] += size
                scanned += 1

                if len(new_entries) >= FLUSH_INTERVAL:
                    flush(conn, new_entries)
                    new_entries.clear()

                if not quiet and scanned % PRINT_INTERVAL == 0:
                    elapsed = time.monotonic() - start
                    rate    = scanned / elapsed if elapsed > 0 else 0
                    print(f"  📂 {scanned:>10,} arquivos  |  {rate:,.0f} arq/s", end="\r")

            except OSError:
                errors += 1

        new_dirs.append((dirpath, dir_mtime))
        if len(new_dirs) >= DIR_FLUSH_INTERVAL:
            flush_dirs(conn, new_dirs)
            new_dirs.clear()

    flush(conn, new_entries)
    flush_dirs(conn, new_dirs)
    pruned = prune(conn, set(cache.keys()), scanned_paths)
    conn.close()
    return stats, scanned_paths, scanned, updated, errors, pruned


def scan_all(compiled: dict, quiet: bool) -> tuple:
    if not quiet:
        print(f"\n🔍  Varrendo /  —  cache em {DB_PATH}")

    allowed_devs = get_allowed_devs()
    start        = time.monotonic()

    stats, scanned_paths, scanned, updated, errors, pruned = \
        _walk_and_classify(compiled, allowed_devs, quiet)

    elapsed = time.monotonic() - start
    return stats, scanned, updated, pruned, errors, elapsed


# ─────────────────────────────────────────
# RELATÓRIO
# ─────────────────────────────────────────
W = 68


def sep(char: str = "─") -> None:
    print(char * W)


def _print_rows(rows: list[tuple[str, str, int]], total: int) -> None:
    for label, emoji, size in rows:
        frac = size / total
        name = f"{emoji} {label}"
        print(f"  {name:<24}  {format_size(size):>9}  {frac*100:>4.1f}%  {bar(frac)}")


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
        label, emoji = cat_meta.get(cat_id, (cat_id, "📁"))
        entry = (label, emoji, size)
        (sys_rows if cat_id.startswith("sys:") else home_rows).append(entry)

    home_rows.sort(key=lambda x: x[2], reverse=True)
    sys_rows.sort(key=lambda x: x[2], reverse=True)

    print()
    print("═" * W)
    print(f"  💾  STORAGE SENSE")
    print(f"  Arquivos: {scanned:,}   Tempo: {elapsed:.1f}s  ({rate:,.0f} arq/s)")
    print(f"  Atualizados: {updated:,}   Podados: {pruned:,}   Erros: {errors:,}")
    print("═" * W)
    print(f"  {'CATEGORIA':<24}  {'TAMANHO':>9}  {'%':>5}  BARRA")

    sep()
    print("  ~ HOME")
    sep()
    _print_rows(home_rows, total)

    sep()
    print("  / SISTEMA")
    sep()
    _print_rows(sys_rows, total)

    sep()
    print(f"  {'TOTAL':<24}  {format_size(total):>9}")
    print("═" * W)
    print()


# ─────────────────────────────────────────
# CACHE INFO
# ─────────────────────────────────────────
def print_cache_info(cat_meta: dict) -> None:
    if not DB_PATH.exists():
        print("ℹ️  Nenhum cache. Execute `storagesense scan`.")
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
    print("═" * W)
    print(f"  CACHE INFO  —  {DB_PATH}")
    sep()
    print(f"  Banco:         {format_size(db_size)}")
    print(f"  Arquivos:      {n_files:,}")
    print(f"  Volume total:  {format_size(vol)}")
    sep()
    print(f"  {'CATEGORIA':<24}  {'ARQUIVOS':>10}  {'TAMANHO':>10}")
    sep()
    for cat_id, count, sz in rows:
        label, emoji = cat_meta.get(cat_id, (cat_id or "(sem cat)", "📁"))
        name = f"{emoji} {label}"
        print(f"  {name:<24}  {count:>10,}  {format_size(sz or 0):>10}")
    print("═" * W)
    print()


# ─────────────────────────────────────────
# LIST
# ─────────────────────────────────────────
def print_list(compiled: dict) -> None:
    conn = get_conn()
    print()
    print("═" * W)
    print(f"  CATEGORIAS  ({CAT_FILE.name})")
    sep()
    print(f"  {'ID':<16}  {'LABEL':<22}  {'EXTS':>5}  {'NO CACHE':>10}")
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
    print("═" * W)
    print()


# ─────────────────────────────────────────
# JSON OUTPUT
# ─────────────────────────────────────────
def print_json(compiled: dict, cat_meta: dict) -> None:
    if not DB_PATH.exists():
        print(json.dumps({"error": "No cache found", "total": 0, "data": []}))
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
        # Apple SF Colors / macOS Palette
        if "jogo" in l or "game" in l: return "#007AFF"
        if "download" in l: return "#FFD426"
        if "foto" in l or "imagem" in l or "image" in l: return "#FF9F0A"
        if "vídeo" in l or "video" in l: return "#AF52DE"
        if "música" in l or "music" in l or "audio" in l: return "#FF2D55"
        if "doc" in l or "documento" in l: return "#FF9500"
        if "código" in l or "code" in l or "github" in l: return "#34C759"
        if "archive" in i or "arquivos" in l: return "#5856D6"
        if i == "unified_apps" or "app" in l or "flatpak" in i or "spotify" in i: return "#FF3B30"
        if "cache" in l or "tmp" in i or "sistema" in l or "system" in l or "config" in i: return "#AEAEB2"
        return "#636366"

    data_map = {}
    APP_IDS  = {"sys:apps", "flatpak", "spotify", "apps"}
    SYS_IDS  = {"sys:system", "sys:other", "sys:tmp", "sys:games", "sys:vms", "sys:archives", "sys:fonts", "sys:images", "sys:videos", "sys:audio", "sys:docs", "sys:code", "config", "cache"}

    for cat_id, count, sz in rows:
        if not sz:
            continue
        label, emoji = cat_meta.get(cat_id, (cat_id or "Outros", "📁"))

        target_id = cat_id
        target_label = label
        target_emoji = emoji
        is_system = cat_id.startswith("sys:")

        if cat_id in APP_IDS or "aplicativo" in label.lower() or "apps" in label.lower():
            target_id = "unified_apps"
            target_label = "Aplicativos"
            target_emoji = ""
            is_system = False

        elif is_system or cat_id in SYS_IDS or "sistema" in label.lower() or "cache" in label.lower():
            target_id = "sys:unified"
            target_label = "Sistema"
            target_emoji = ""
            is_system = True

        if target_id not in data_map:
            data_map[target_id] = {
                "id": target_id,
                "label": target_label,
                "emoji": target_emoji,
                "size": 0,
                "count": 0,
                "color": get_color(target_id, target_label),
                "is_system": is_system
            }

        data_map[target_id]["size"]  += sz
        data_map[target_id]["count"] += count

    categorized_total = sum(d["size"] for d in data_map.values())
    system_delta = disk_used - categorized_total
    if system_delta > 1024 * 1024:
        if "sys:unified" in data_map:
            data_map["sys:unified"]["size"] += system_delta
        else:
            data_map["sys:unified"] = {
                "id": "sys:unified",
                "label": "Sistema",
                "emoji": "⚙️",
                "size": system_delta,
                "count": 0,
                "color": get_color("sys:unified", "Sistema"),
                "is_system": True
            }

    final_data = sorted(data_map.values(), key=lambda x: x["size"], reverse=True)
    print(json.dumps({
        "disk_total": disk_total,
        "disk_used": disk_used,
        "scanned_total": total_scanned,
        "data": final_data
    }, ensure_ascii=False))


# ─────────────────────────────────────────
# CLI
# ─────────────────────────────────────────
def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        prog="storagesense",
        description="Analisador de armazenamento estilo macOS.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
exemplos:
  storagesense scan
  storagesense scan --quiet
  storagesense list
  storagesense info
  storagesense clear-cache
        """,
    )
    sub = p.add_subparsers(dest="command", metavar="<comando>")
    scan_p = sub.add_parser("scan", help="Varre o disco e exibe relatório")
    scan_p.add_argument("--quiet", "-q", action="store_true", help="Sem progresso")
    sub.add_parser("list",        help="Lista categorias do JSON")
    sub.add_parser("info",        help="Info do cache")
    sub.add_parser("json",        help="Saída em JSON para integração")
    sub.add_parser("clear-cache", help="Apaga o cache")
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
                print(f"✅  Cache removido: {DB_PATH}")
            else:
                print("ℹ️  Nenhum cache encontrado.")


if __name__ == "__main__":
    main()