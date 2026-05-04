#!/usr/bin/env python3
"""
Home directory indexer for StorageSense.

Builds a SQLite database with file metadata plus an FTS5 index for fast
name/path search. It intentionally keeps a separate database from the storage
usage cache because the query patterns are different.
"""

from __future__ import annotations

import os
import re
import sqlite3
import stat
import time
from dataclasses import dataclass
from pathlib import Path


DEFAULT_DB_PATH = Path.home() / ".cache" / "storagesense" / "home_index.db"
DEFAULT_BATCH_SIZE = 5000
PRINT_INTERVAL = 50000


@dataclass(frozen=True)
class IndexStats:
    root: str
    db_path: str
    scanned: int
    files: int
    dirs: int
    symlinks: int
    other: int
    pruned: int
    errors: int
    elapsed_secs: float


def _connect(db_path: Path) -> sqlite3.Connection:
    db_path.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(db_path)
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute("PRAGMA synchronous=NORMAL")
    conn.execute("PRAGMA cache_size=-64000")
    conn.execute("PRAGMA temp_store=MEMORY")
    conn.execute("PRAGMA foreign_keys=ON")
    conn.executescript(
        """
        CREATE TABLE IF NOT EXISTS entries (
            id         INTEGER PRIMARY KEY,
            path       TEXT NOT NULL UNIQUE,
            parent     TEXT NOT NULL,
            name       TEXT NOT NULL,
            extension  TEXT NOT NULL,
            kind       TEXT NOT NULL,
            size       INTEGER NOT NULL,
            mtime_ns   INTEGER NOT NULL,
            ctime_ns   INTEGER NOT NULL,
            mode       INTEGER NOT NULL,
            uid        INTEGER NOT NULL,
            gid        INTEGER NOT NULL,
            inode      INTEGER NOT NULL,
            dev        INTEGER NOT NULL,
            hidden     INTEGER NOT NULL,
            depth      INTEGER NOT NULL,
            indexed_at REAL NOT NULL
        );

        CREATE INDEX IF NOT EXISTS idx_entries_parent ON entries(parent);
        CREATE INDEX IF NOT EXISTS idx_entries_name ON entries(name);
        CREATE INDEX IF NOT EXISTS idx_entries_extension ON entries(extension);
        CREATE INDEX IF NOT EXISTS idx_entries_kind ON entries(kind);
        CREATE INDEX IF NOT EXISTS idx_entries_mtime ON entries(mtime_ns);

        CREATE VIRTUAL TABLE IF NOT EXISTS entries_fts USING fts5(
            name,
            path,
            parent,
            content='entries',
            content_rowid='id',
            tokenize='unicode61 remove_diacritics 2'
        );

        CREATE TRIGGER IF NOT EXISTS entries_ai AFTER INSERT ON entries BEGIN
            INSERT INTO entries_fts(rowid, name, path, parent)
            VALUES (new.id, new.name, new.path, new.parent);
        END;

        CREATE TRIGGER IF NOT EXISTS entries_ad AFTER DELETE ON entries BEGIN
            INSERT INTO entries_fts(entries_fts, rowid, name, path, parent)
            VALUES ('delete', old.id, old.name, old.path, old.parent);
        END;

        CREATE TRIGGER IF NOT EXISTS entries_au AFTER UPDATE ON entries BEGIN
            INSERT INTO entries_fts(entries_fts, rowid, name, path, parent)
            VALUES ('delete', old.id, old.name, old.path, old.parent);
            INSERT INTO entries_fts(rowid, name, path, parent)
            VALUES (new.id, new.name, new.path, new.parent);
        END;

        CREATE TABLE IF NOT EXISTS runs (
            id           INTEGER PRIMARY KEY,
            root         TEXT NOT NULL,
            started_at   REAL NOT NULL,
            finished_at  REAL,
            scanned      INTEGER NOT NULL DEFAULT 0,
            files        INTEGER NOT NULL DEFAULT 0,
            dirs         INTEGER NOT NULL DEFAULT 0,
            symlinks     INTEGER NOT NULL DEFAULT 0,
            other        INTEGER NOT NULL DEFAULT 0,
            pruned       INTEGER NOT NULL DEFAULT 0,
            errors       INTEGER NOT NULL DEFAULT 0
        );
        """
    )
    conn.commit()
    return conn


def _kind_from_mode(mode: int) -> str:
    if stat.S_ISREG(mode):
        return "file"
    if stat.S_ISDIR(mode):
        return "dir"
    if stat.S_ISLNK(mode):
        return "symlink"
    return "other"


def _entry_from_path(path: Path, st: os.stat_result, root: Path, indexed_at: float) -> tuple:
    path_s = str(path)
    name = path.name
    kind = _kind_from_mode(st.st_mode)
    extension = path.suffix.lower() if kind == "file" else ""
    try:
        depth = len(path.relative_to(root).parts)
    except ValueError:
        depth = len(path.parts)
    return (
        path_s,
        str(path.parent),
        name,
        extension,
        kind,
        int(st.st_size) if kind == "file" else 0,
        int(st.st_mtime_ns),
        int(st.st_ctime_ns),
        int(st.st_mode),
        int(st.st_uid),
        int(st.st_gid),
        int(st.st_ino),
        int(st.st_dev),
        1 if name.startswith(".") else 0,
        depth,
        indexed_at,
    )


def _flush_entries(conn: sqlite3.Connection, entries: list[tuple]) -> None:
    if not entries:
        return
    conn.executemany(
        """
        INSERT INTO entries (
            path, parent, name, extension, kind, size, mtime_ns, ctime_ns,
            mode, uid, gid, inode, dev, hidden, depth, indexed_at
        )
        VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
        ON CONFLICT(path) DO UPDATE SET
            parent=excluded.parent,
            name=excluded.name,
            extension=excluded.extension,
            kind=excluded.kind,
            size=excluded.size,
            mtime_ns=excluded.mtime_ns,
            ctime_ns=excluded.ctime_ns,
            mode=excluded.mode,
            uid=excluded.uid,
            gid=excluded.gid,
            inode=excluded.inode,
            dev=excluded.dev,
            hidden=excluded.hidden,
            depth=excluded.depth,
            indexed_at=excluded.indexed_at
        WHERE
            entries.parent != excluded.parent OR
            entries.name != excluded.name OR
            entries.extension != excluded.extension OR
            entries.kind != excluded.kind OR
            entries.size != excluded.size OR
            entries.mtime_ns != excluded.mtime_ns OR
            entries.ctime_ns != excluded.ctime_ns OR
            entries.mode != excluded.mode OR
            entries.uid != excluded.uid OR
            entries.gid != excluded.gid OR
            entries.inode != excluded.inode OR
            entries.dev != excluded.dev OR
            entries.hidden != excluded.hidden OR
            entries.depth != excluded.depth
        """,
        entries,
    )
    conn.commit()


def _flush_seen(conn: sqlite3.Connection, paths: list[str]) -> None:
    if not paths:
        return
    conn.executemany("INSERT OR IGNORE INTO seen(path) VALUES (?)", [(p,) for p in paths])
    conn.commit()


def _is_own_database(path: Path, db_path: Path) -> bool:
    path_s = str(path)
    db_s = str(db_path)
    return path_s == db_s or path_s in {f"{db_s}-wal", f"{db_s}-shm"}


def build_index(
    root: Path | str = Path.home(),
    db_path: Path | str = DEFAULT_DB_PATH,
    *,
    skip_hidden: bool = False,
    one_filesystem: bool = True,
    batch_size: int = DEFAULT_BATCH_SIZE,
    quiet: bool = False,
) -> IndexStats:
    root_path = Path(root).expanduser().resolve()
    index_path = Path(db_path).expanduser().resolve()
    start = time.monotonic()
    indexed_at = time.time()
    scanned = files = dirs = symlinks = other = errors = 0
    entries: list[tuple] = []
    seen: list[str] = []

    conn = _connect(index_path)
    conn.execute("CREATE TEMP TABLE seen(path TEXT PRIMARY KEY)")
    cur = conn.execute(
        "INSERT INTO runs(root, started_at) VALUES (?, ?)",
        (str(root_path), indexed_at),
    )
    run_id = cur.lastrowid
    conn.commit()

    try:
        root_dev = root_path.stat().st_dev
    except OSError as exc:
        conn.close()
        raise RuntimeError(f"Cannot stat index root {root_path}: {exc}") from exc

    stack = [root_path]
    while stack:
        current = stack.pop()
        try:
            st = current.lstat()
        except OSError:
            errors += 1
            continue

        if _is_own_database(current, index_path):
            continue
        if skip_hidden and current != root_path and current.name.startswith("."):
            continue
        if one_filesystem and st.st_dev != root_dev:
            continue

        kind = _kind_from_mode(st.st_mode)
        scanned += 1
        if kind == "file":
            files += 1
        elif kind == "dir":
            dirs += 1
        elif kind == "symlink":
            symlinks += 1
        else:
            other += 1

        path_s = str(current)
        entries.append(_entry_from_path(current, st, root_path, indexed_at))
        seen.append(path_s)

        if len(entries) >= batch_size:
            _flush_entries(conn, entries)
            entries.clear()
        if len(seen) >= batch_size:
            _flush_seen(conn, seen)
            seen.clear()
        if not quiet and scanned % PRINT_INTERVAL == 0:
            elapsed = time.monotonic() - start
            rate = scanned / elapsed if elapsed > 0 else 0
            print(f"  {scanned:>10,} entries  |  {rate:,.0f} entries/s", end="\r")

        if kind != "dir":
            continue

        try:
            children = sorted(os.scandir(current), key=lambda e: e.name, reverse=True)
        except OSError:
            errors += 1
            continue

        for child in children:
            stack.append(Path(child.path))

    _flush_entries(conn, entries)
    _flush_seen(conn, seen)

    prune_cur = conn.execute(
        "DELETE FROM entries WHERE path NOT IN (SELECT path FROM seen)"
    )
    pruned = prune_cur.rowcount
    prune_cur.close()
    finished_at = time.time()
    conn.execute(
        """
        UPDATE runs
        SET finished_at=?, scanned=?, files=?, dirs=?, symlinks=?, other=?,
            pruned=?, errors=?
        WHERE id=?
        """,
        (finished_at, scanned, files, dirs, symlinks, other, pruned, errors, run_id),
    )
    conn.commit()
    conn.execute("PRAGMA wal_checkpoint(TRUNCATE)")
    conn.close()

    if not quiet:
        print()

    return IndexStats(
        root=str(root_path),
        db_path=str(index_path),
        scanned=scanned,
        files=files,
        dirs=dirs,
        symlinks=symlinks,
        other=other,
        pruned=pruned,
        errors=errors,
        elapsed_secs=time.monotonic() - start,
    )


def _fts_query(query: str) -> str:
    tokens = re.findall(r"[A-Za-z0-9_]+", query)
    return " ".join(f"{token}*" for token in tokens)


def search_index(
    query: str,
    db_path: Path | str = DEFAULT_DB_PATH,
    *,
    limit: int = 50,
) -> list[dict[str, object]]:
    index_path = Path(db_path).expanduser()
    if not index_path.exists():
        raise FileNotFoundError(f"Index database not found: {index_path}")

    conn = sqlite3.connect(index_path)
    conn.row_factory = sqlite3.Row
    match = _fts_query(query)
    if match:
        rows = conn.execute(
            """
            SELECT e.path, e.name, e.parent, e.kind, e.size, e.mtime_ns,
                   e.extension, bm25(entries_fts) AS rank
            FROM entries_fts
            JOIN entries e ON e.id = entries_fts.rowid
            WHERE entries_fts MATCH ?
            ORDER BY rank
            LIMIT ?
            """,
            (match, limit),
        ).fetchall()
    else:
        like = f"%{query}%"
        rows = conn.execute(
            """
            SELECT path, name, parent, kind, size, mtime_ns, extension, 0.0 AS rank
            FROM entries
            WHERE name LIKE ? OR path LIKE ?
            ORDER BY mtime_ns DESC
            LIMIT ?
            """,
            (like, like, limit),
        ).fetchall()
    conn.close()
    return [dict(row) for row in rows]


def index_info(db_path: Path | str = DEFAULT_DB_PATH) -> dict[str, object]:
    index_path = Path(db_path).expanduser()
    if not index_path.exists():
        return {
            "exists": False,
            "db_path": str(index_path),
            "entries": 0,
            "files": 0,
            "dirs": 0,
            "symlinks": 0,
            "other": 0,
            "size": 0,
            "last_run": None,
        }

    conn = sqlite3.connect(index_path)
    counts = dict(conn.execute(
        "SELECT kind, COUNT(*) FROM entries GROUP BY kind"
    ).fetchall())
    total = conn.execute("SELECT COUNT(*) FROM entries").fetchone()[0]
    last_run = conn.execute(
        """
        SELECT root, started_at, finished_at, scanned, files, dirs, symlinks,
               other, pruned, errors
        FROM runs
        ORDER BY id DESC
        LIMIT 1
        """
    ).fetchone()
    conn.close()
    keys = ["root", "started_at", "finished_at", "scanned", "files", "dirs",
            "symlinks", "other", "pruned", "errors"]
    return {
        "exists": True,
        "db_path": str(index_path),
        "entries": total,
        "files": counts.get("file", 0),
        "dirs": counts.get("dir", 0),
        "symlinks": counts.get("symlink", 0),
        "other": counts.get("other", 0),
        "size": index_path.stat().st_size,
        "last_run": dict(zip(keys, last_run)) if last_run else None,
    }
