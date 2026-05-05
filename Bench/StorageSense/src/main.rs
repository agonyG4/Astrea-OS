use ahash::{AHashMap, AHashSet};
use anyhow::{Context, Result};
use rusqlite::{Connection, params};
use serde::Deserialize;
use std::os::unix::fs::MetadataExt;
use std::path::Path;
use std::time::Instant;
use walkdir::WalkDir;

// ─────────────────────────────────────────────
// Config structs
// ─────────────────────────────────────────────

#[derive(Debug, Deserialize)]
struct RulesFile {
    priority:           Vec<String>,
    rules:              serde_json::Map<String, serde_json::Value>,
    skip_prefixes:      Vec<String>,
    flush_interval:     usize,
    dir_flush_interval: usize,
    print_interval:     usize,
}

#[derive(Debug)]
struct CompiledRule {
    id:                 String,
    match_dir_segments: AHashSet<String>,
    path_prefixes:      Vec<String>,
    extensions:         AHashSet<String>,
}

// ─────────────────────────────────────────────
// Args
// ─────────────────────────────────────────────

struct Args {
    rules_path: String,
    db_path:    String,
    home:       String,
    quiet:      bool,
}

fn parse_args() -> Args {
    let mut it = std::env::args().skip(1);
    let mut rules_path = String::new();
    let mut db_path    = String::new();
    let mut home       = std::env::var("HOME").unwrap_or_else(|_| "/root".into());
    let mut quiet      = false;

    while let Some(arg) = it.next() {
        match arg.as_str() {
            "--rules"        => rules_path = it.next().expect("--rules requires a path"),
            "--db"           => db_path    = it.next().expect("--db requires a path"),
            "--home"         => home       = it.next().expect("--home requires a path"),
            "--quiet" | "-q" => quiet      = true,
            other            => eprintln!("Unknown argument: {other}"),
        }
    }

    if rules_path.is_empty() || db_path.is_empty() {
        eprintln!("Usage: scanner --rules <system_rules.json> --db <cache.db> [--home <path>] [--quiet]");
        std::process::exit(1);
    }
    Args { rules_path, db_path, home, quiet }
}

// ─────────────────────────────────────────────
// Rules
// ─────────────────────────────────────────────

fn load_rules(path: &str) -> Result<(Vec<CompiledRule>, Vec<String>, usize, usize, usize)> {
    let raw = std::fs::read_to_string(path)
        .with_context(|| format!("Cannot read rules file: {path}"))?;
    let rf: RulesFile = serde_json::from_str(&raw).context("Failed to parse system_rules.json")?;

    let mut compiled = Vec::with_capacity(rf.priority.len());
    for id in &rf.priority {
        let v = rf.rules.get(id)
            .with_context(|| format!("Rule '{id}' in priority but missing from rules"))?;

        compiled.push(CompiledRule {
            id: id.clone(),
            match_dir_segments: v["match_dir_segments"]
                .as_array().unwrap_or(&vec![])
                .iter().filter_map(|x| x.as_str()).map(|s| s.to_lowercase()).collect(),
            path_prefixes: v["path_prefixes"]
                .as_array().unwrap_or(&vec![])
                .iter().filter_map(|x| x.as_str()).map(|s| s.to_string()).collect(),
            extensions: v["extensions"]
                .as_array().unwrap_or(&vec![])
                .iter().filter_map(|x| x.as_str()).map(|s| s.to_lowercase()).collect(),
        });
    }
    Ok((compiled, rf.skip_prefixes, rf.flush_interval, rf.dir_flush_interval, rf.print_interval))
}

// ─────────────────────────────────────────────
// Home categories
// ─────────────────────────────────────────────

mod home {
    use ahash::AHashSet;
    use serde::Deserialize;
    use std::path::Path;

    #[derive(Debug, Deserialize, Default)]
    pub struct RawHomeCat {
        pub include_paths: Option<Vec<String>>,
        pub exclude_parts: Option<Vec<String>>,
        pub match_dirs:    Option<Vec<String>>,
        pub extensions:    Option<Vec<String>>,
    }

    pub struct Cat {
        pub id:      String,
        pub inc:     Vec<String>,
        pub exc:     AHashSet<String>,
        pub mdirs:   AHashSet<String>,
        pub exts:    AHashSet<String>,
    }

    pub fn load(json: &str, home: &str) -> Vec<Cat> {
        let Ok(raw): Result<serde_json::Map<String, serde_json::Value>, _>
            = serde_json::from_str(json) else { return vec![] };

        raw.iter()
            .filter(|(k, _)| !k.starts_with('_'))
            .map(|(id, v)| {
                let r: RawHomeCat = serde_json::from_value(v.clone()).unwrap_or_default();
                let inc = r.include_paths.unwrap_or_default().into_iter().map(|p| {
                    let e = p.replace("$HOME", home).replace('~', home);
                    let real = std::fs::canonicalize(&e).unwrap_or_else(|_| Path::new(&e).to_path_buf());
                    let mut s = real.to_string_lossy().into_owned();
                    if !s.ends_with('/') { s.push('/'); }
                    s
                }).collect();
                Cat {
                    id:    id.clone(),
                    inc,
                    exc:   r.exclude_parts.unwrap_or_default().into_iter().map(|s| s.to_lowercase()).collect(),
                    mdirs: r.match_dirs.unwrap_or_default().into_iter().map(|s| s.to_lowercase()).collect(),
                    exts:  r.extensions.unwrap_or_default().into_iter().map(|s| s.to_lowercase()).collect(),
                }
            })
            .collect()
    }

    pub fn resolve<'a>(path: &str, ext: &str, segs: &AHashSet<String>, cats: &'a [Cat]) -> &'a str {
        for c in cats {
            if !c.exc.is_empty()  && c.exc.iter().any(|p| segs.contains(p))              { continue; }
            if !c.inc.is_empty()  && !c.inc.iter().any(|p| path.starts_with(p.as_str())) { continue; }
            if !c.mdirs.is_empty() && c.mdirs.iter().any(|d| segs.contains(d))           { return &c.id; }
            if c.exts.is_empty()  || c.exts.contains(ext)                                { return &c.id; }
        }
        "home_other"
    }
}

// ─────────────────────────────────────────────
// Classification
// ─────────────────────────────────────────────

fn resolve_sys<'a>(path: &str, ext: &str, segs: &AHashSet<String>, rules: &'a [CompiledRule]) -> &'a str {
    for r in rules {
        if !r.match_dir_segments.is_empty() && r.match_dir_segments.iter().any(|s| segs.contains(s)) { return &r.id; }
        if !r.path_prefixes.is_empty()      && r.path_prefixes.iter().any(|p| path.starts_with(p.as_str())) { return &r.id; }
        if !r.extensions.is_empty()         && r.extensions.contains(ext) { return &r.id; }
    }
    "sys_other"
}

#[inline]
fn classify(path: &str, home_sep: &str, sys: &[CompiledRule], home: &[home::Cat]) -> String {
    let fname = path.rsplit_once('/').map(|(_, f)| f).unwrap_or(path);
    let ext   = fname.rfind('.').map(|i| fname[i..].to_lowercase()).unwrap_or_default();
    let dir   = path.rsplit_once('/').map(|(d, _)| d).unwrap_or("");
    let segs: AHashSet<String> = dir.split('/').filter(|s| !s.is_empty()).map(|s| s.to_lowercase()).collect();

    if path.starts_with(home_sep) {
        home::resolve(path, &ext, &segs, home).to_string()
    } else {
        resolve_sys(path, &ext, &segs, sys).to_string()
    }
}

// ─────────────────────────────────────────────
// SQLite
// ─────────────────────────────────────────────

fn open_db(db_path: &str) -> Result<Connection> {
    let conn = Connection::open(db_path)?;
    conn.execute_batch("
        PRAGMA journal_mode = WAL;
        PRAGMA synchronous  = NORMAL;
        PRAGMA cache_size   = -65536;
        PRAGMA temp_store   = MEMORY;
        PRAGMA mmap_size    = 536870912;

        CREATE TABLE IF NOT EXISTS files (
            path  TEXT PRIMARY KEY,
            size  INTEGER NOT NULL,
            mtime REAL    NOT NULL,
            cat   TEXT    NOT NULL
        );
        CREATE TABLE IF NOT EXISTS dirs (
            path  TEXT PRIMARY KEY,
            mtime REAL NOT NULL
        );
        CREATE INDEX IF NOT EXISTS idx_cat ON files(cat);

        CREATE TEMP TABLE seen (path TEXT PRIMARY KEY);
    ")?;
    Ok(conn)
}

// Cache entry: (size, mtime, cat) — size needed for cache-hit stat accumulation
fn load_cache(conn: &Connection) -> Result<(
    AHashMap<String, (i64, f64, String)>,  // path -> (size, mtime, cat)
    AHashMap<String, Vec<String>>,          // parent -> [children]
)> {
    let mut stmt = conn.prepare("SELECT path, size, mtime, cat FROM files")?;
    let mut cache:     AHashMap<String, (i64, f64, String)> = AHashMap::default();
    let mut dir_index: AHashMap<String, Vec<String>>        = AHashMap::default();

    let rows = stmt.query_map([], |r| Ok((
        r.get::<_, String>(0)?,
        r.get::<_, i64>(1)?,
        r.get::<_, f64>(2)?,
        r.get::<_, String>(3)?,
    )))?;

    for row in rows {
        let (path, size, mtime, cat) = row?;
        let parent = path.rsplit_once('/').map(|(p, _)| p).unwrap_or("").to_owned();
        dir_index.entry(parent).or_default().push(path.clone());
        cache.insert(path, (size, mtime, cat));
    }
    Ok((cache, dir_index))
}

fn load_dir_cache(conn: &Connection) -> Result<AHashMap<String, f64>> {
    let mut stmt = conn.prepare("SELECT path, mtime FROM dirs")?;
    let rows = stmt.query_map([], |r| Ok((r.get::<_, String>(0)?, r.get::<_, f64>(1)?)))?;
    let mut m = AHashMap::default();
    for row in rows { let (p, t) = row?; m.insert(p, t); }
    Ok(m)
}

fn tx_flush<T, F>(conn: &mut Connection, items: &[T], f: F) -> Result<()>
where F: Fn(&rusqlite::CachedStatement<'_>, &T) -> rusqlite::Result<()>
{
    if items.is_empty() { return Ok(()); }
    // We can't easily use prepare_cached across the tx boundary with a generic closure,
    // so we just commit in one shot.
    let _ = f; // unused in this version — see concrete impls below
    Ok(())
}

fn flush_files(conn: &mut Connection, entries: &[(String, i64, f64, String)]) -> Result<()> {
    if entries.is_empty() { return Ok(()); }
    let tx = conn.transaction()?;
    for (p, sz, mt, cat) in entries {
        tx.execute(
            "INSERT OR REPLACE INTO files (path, size, mtime, cat) VALUES (?1,?2,?3,?4)",
            params![p, sz, mt, cat],
        )?;
    }
    tx.commit()?;
    Ok(())
}

fn flush_dirs(conn: &mut Connection, entries: &[(String, f64)]) -> Result<()> {
    if entries.is_empty() { return Ok(()); }
    let tx = conn.transaction()?;
    for (p, mt) in entries {
        tx.execute("INSERT OR REPLACE INTO dirs (path, mtime) VALUES (?1,?2)", params![p, mt])?;
    }
    tx.commit()?;
    Ok(())
}

/// Insert a batch of paths into the TEMP seen table.
fn flush_seen(conn: &mut Connection, paths: &[String]) -> Result<()> {
    if paths.is_empty() { return Ok(()); }
    let tx = conn.transaction()?;
    for p in paths {
        tx.execute("INSERT OR IGNORE INTO seen (path) VALUES (?1)", params![p])?;
    }
    tx.commit()?;
    Ok(())
}

/// Pure-SQL prune: delete anything not seen this run. Zero RAM.
fn prune_sql(conn: &mut Connection) -> Result<u64> {
    let n = conn.execute("DELETE FROM files WHERE path NOT IN (SELECT path FROM seen)", [])?;
    conn.execute_batch("PRAGMA wal_checkpoint(TRUNCATE);")?;
    Ok(n as u64)
}

// ─────────────────────────────────────────────
// Allowed devices
// ─────────────────────────────────────────────

fn get_allowed_devs() -> AHashSet<u64> {
    let mut devs = AHashSet::default();
    if let Ok(s) = std::fs::read_to_string("/proc/self/mountinfo") {
        for line in s.lines() {
            if let Some(mp) = line.split_whitespace().nth(4) {
                if let Ok(m) = std::fs::metadata(mp) { devs.insert(m.dev()); }
            }
        }
    }
    if devs.is_empty() {
        if let Ok(m) = std::fs::metadata("/") { devs.insert(m.dev()); }
    }
    devs
}

// ─────────────────────────────────────────────
// Output
// ─────────────────────────────────────────────

#[derive(serde::Serialize)]
struct ScanOutput {
    scanned:      u64,
    updated:      u64,
    pruned:       u64,
    errors:       u64,
    elapsed_secs: f64,
    stats:        Vec<StatEntry>,
}
#[derive(serde::Serialize)]
struct StatEntry { cat: String, size: i64 }

// ─────────────────────────────────────────────
// Main
// ─────────────────────────────────────────────

fn main() -> Result<()> {
    let args = parse_args();

    let (sys_rules, skip_prefixes, flush_interval, dir_flush_interval, print_interval) =
        load_rules(&args.rules_path)?;

    let rules_dir = Path::new(&args.rules_path).parent().unwrap_or(Path::new("."));
    let home_cats: Vec<home::Cat> = {
        let p = rules_dir.join("categories.json");
        if p.exists() { home::load(&std::fs::read_to_string(p)?, &args.home) } else { vec![] }
    };

    let home_sep = { let mut s = args.home.clone(); if !s.ends_with('/') { s.push('/'); } s };

    let allowed_devs           = get_allowed_devs();
    let mut conn               = open_db(&args.db_path)?;
    let (cache, dir_index)     = load_cache(&conn)?;
    let dir_cache              = load_dir_cache(&conn)?;

    let mut stats:     AHashMap<String, i64>            = AHashMap::default();
    let mut new_files: Vec<(String, i64, f64, String)>  = Vec::new();
    let mut new_dirs:  Vec<(String, f64)>               = Vec::new();
    // seen_buf feeds the SQL temp table — replaces the old in-RAM AHashSet<String>
    let mut seen_buf:  Vec<String>                      = Vec::with_capacity(flush_interval);

    let mut scanned: u64 = 0;
    let mut updated: u64 = 0;
    let mut errors:  u64 = 0;

    let start = Instant::now();

    'walk: for entry_res in WalkDir::new("/").follow_links(false).same_file_system(false) {
        let entry = match entry_res { Ok(e) => e, Err(_) => { errors += 1; continue; } };

        let path   = entry.path();
        let path_s = path.to_string_lossy();
        let ps     = path_s.as_ref();

        // Skip forbidden prefixes
        for sp in &skip_prefixes {
            if ps == sp.trim_end_matches('/') || ps.starts_with(sp.as_str()) {
                continue 'walk;
            }
        }

        let ft = entry.file_type();

        // ── Directory ────────────────────────────────────────────────────
        if ft.is_dir() {
            let meta = match entry.metadata() { Ok(m) => m, Err(_) => { errors += 1; continue; } };
            if !allowed_devs.contains(&meta.dev()) { continue; }

            let dir_mtime = meta.mtime() as f64 + meta.mtime_nsec() as f64 / 1e9;

            // Cache hit: dir unchanged — reuse child sizes from in-RAM cache
            if dir_cache.get(ps) == Some(&dir_mtime) {
                if let Some(children) = dir_index.get(ps) {
                    for child in children {
                        if let Some(&(sz, _, ref cat)) = cache.get(child) {
                            *stats.entry(cat.clone()).or_default() += sz;
                            seen_buf.push(child.clone());
                            scanned += 1;
                        }
                    }
                }
            }

            new_dirs.push((ps.to_owned(), dir_mtime));
            if new_dirs.len() >= dir_flush_interval {
                flush_dirs(&mut conn, &new_dirs)?;
                new_dirs.clear();
            }
            continue;
        }

        // ── Regular file ─────────────────────────────────────────────────
        if !ft.is_file() { continue; }

        let meta = match entry.metadata() { Ok(m) => m, Err(_) => { errors += 1; continue; } };
        if !allowed_devs.contains(&meta.dev()) { continue; }

        let size  = meta.size() as i64;
        let mtime = meta.mtime() as f64 + meta.mtime_nsec() as f64 / 1e9;
        let path_owned = ps.to_owned();

        let cat = if let Some(&(_, cached_mtime, ref cached_cat)) = cache.get(&path_owned) {
            if (cached_mtime - mtime).abs() < 1e-6 {
                cached_cat.clone()
            } else {
                let cat = classify(&path_owned, &home_sep, &sys_rules, &home_cats);
                new_files.push((path_owned.clone(), size, mtime, cat.clone()));
                updated += 1;
                cat
            }
        } else {
            let cat = classify(&path_owned, &home_sep, &sys_rules, &home_cats);
            new_files.push((path_owned.clone(), size, mtime, cat.clone()));
            updated += 1;
            cat
        };

        *stats.entry(cat).or_default() += size;
        seen_buf.push(path_owned);
        scanned += 1;

        if new_files.len() >= flush_interval {
            flush_files(&mut conn, &new_files)?;
            new_files.clear();
        }
        if seen_buf.len() >= flush_interval {
            flush_seen(&mut conn, &seen_buf)?;
            seen_buf.clear();
        }

        if !args.quiet && scanned % (print_interval as u64) == 0 {
            let e = start.elapsed().as_secs_f64();
            eprint!("  {:>10} files  |  {:>8.0} files/s\r",
                scanned, if e > 0.0 { scanned as f64 / e } else { 0.0 });
        }
    }

    // Final flushes
    flush_files(&mut conn, &new_files)?;
    flush_dirs(&mut conn, &new_dirs)?;
    flush_seen(&mut conn, &seen_buf)?;

    // Prune: pure SQL DELETE — no in-RAM set, no giant Vec<String>
    let pruned = prune_sql(&mut conn)?;

    // Read final stats from DB (catches cache-hit files properly via stored sizes)
    let stat_rows = {
        let mut stmt = conn.prepare("SELECT cat, SUM(size) FROM files GROUP BY cat")?;
        let rows = stmt.query_map([], |r| Ok((r.get::<_, String>(0)?, r.get::<_, i64>(1)?)))?;
        rows.filter_map(|r| r.ok())
            .map(|(cat, size)| StatEntry { cat, size })
            .collect::<Vec<_>>()
    };

    let output = ScanOutput {
        scanned, updated, pruned, errors,
        elapsed_secs: start.elapsed().as_secs_f64(),
        stats: stat_rows,
    };

    if !args.quiet { eprintln!(); }
    println!("{}", serde_json::to_string(&output)?);
    Ok(())
}
