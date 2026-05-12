use rayon::prelude::*;
use std::cmp::Ordering;
use std::fs;
#[cfg(unix)]
use std::os::unix::fs::PermissionsExt;
use std::path::Path;
use std::time::UNIX_EPOCH;

use crate::json;
use crate::thumbnails;

#[derive(Clone)]
pub struct Entry {
    pub name: String,
    pub path: String,
    pub is_dir: bool,
    pub executable: bool,
    pub is_hidden: bool,
    pub size: u64,
    pub modified_ms: i64,
    pub kind: String,
    pub preview_url: String,
}

pub fn run_list(args: &[String]) -> Result<(), String> {
    let (dir, show_hidden, sort_field, sort_asc, folders_first) = parse_list_args(args)?;
    let entries = read_sorted_entries(dir, show_hidden, sort_field, sort_asc, folders_first)?;
    println!("{}", json::array(&entries, entry_to_json));
    Ok(())
}

pub fn run_search(args: &[String]) -> Result<(), String> {
    if args.len() < 6 {
        return Err(
            "expected: <path> <query> <show_hidden> <sort_field> <sort_asc> <folders_first>".into(),
        );
    }

    let dir = Path::new(&args[0]);
    let query = args[1].trim().to_lowercase();
    let show_hidden = args[2] == "1";
    let sort_field = &args[3];
    let sort_asc = args[4] == "1";
    let folders_first = args[5] == "1";

    let mut entries = Vec::new();
    search_dir_recursive(dir, show_hidden, &query, &mut entries)?;
    sort_entries_in_place(&mut entries, sort_field, sort_asc, folders_first);
    println!("{}", json::array(&entries, entry_to_json));
    Ok(())
}

pub fn parse_list_args(args: &[String]) -> Result<(&Path, bool, &str, bool, bool), String> {
    if args.len() < 5 {
        return Err(
            "expected: <path> <show_hidden> <sort_field> <sort_asc> <folders_first>".into(),
        );
    }
    Ok((
        Path::new(&args[0]),
        args[1] == "1",
        &args[2],
        args[3] == "1",
        args[4] == "1",
    ))
}

pub fn read_sorted_entries(
    dir: &Path,
    show_hidden: bool,
    sort_field: &str,
    sort_asc: bool,
    folders_first: bool,
) -> Result<Vec<Entry>, String> {
    let mut entries = read_dir_parallel(dir, show_hidden)?;
    sort_entries_in_place(&mut entries, sort_field, sort_asc, folders_first);
    Ok(entries)
}

fn read_dir_parallel(dir: &Path, show_hidden: bool) -> Result<Vec<Entry>, String> {
    let raw: Vec<_> = fs::read_dir(dir)
        .map_err(|e| format!("failed to read {}: {e}", dir.display()))?
        .filter_map(|r| r.ok())
        .collect();

    Ok(raw
        .into_par_iter()
        .filter_map(|item| entry_from_dir_item(item, show_hidden))
        .collect())
}

fn entry_from_dir_item(item: fs::DirEntry, show_hidden: bool) -> Option<Entry> {
    let path = item.path();
    let meta = item.metadata().ok()?;
    let is_dir = meta.is_dir();
    let name = item.file_name().to_string_lossy().into_owned();
    let is_hidden = name.starts_with('.');
    if !show_hidden && is_hidden {
        return None;
    }
    Some(entry_from_parts(
        name,
        path.as_path(),
        meta,
        is_dir,
        is_hidden,
    ))
}

fn search_dir_recursive(
    dir: &Path,
    show_hidden: bool,
    query: &str,
    out: &mut Vec<Entry>,
) -> Result<(), String> {
    let iter = match fs::read_dir(dir) {
        Ok(iter) => iter,
        Err(_) => return Ok(()),
    };

    for item in iter.filter_map(|r| r.ok()) {
        let path = item.path();
        let meta = match item.metadata() {
            Ok(meta) => meta,
            Err(_) => continue,
        };
        let is_dir = meta.is_dir();
        let name = item.file_name().to_string_lossy().into_owned();
        let is_hidden = name.starts_with('.');

        if !show_hidden && is_hidden {
            continue;
        }

        if query.is_empty() || name.to_lowercase().contains(query) {
            out.push(entry_from_parts(name, &path, meta, is_dir, is_hidden));
        }

        if is_dir {
            let _ = search_dir_recursive(&path, show_hidden, query, out);
        }
    }

    Ok(())
}

fn entry_from_parts(
    name: String,
    path: &Path,
    meta: fs::Metadata,
    is_dir: bool,
    is_hidden: bool,
) -> Entry {
    let modified_ms = meta
        .modified()
        .ok()
        .and_then(|t| t.duration_since(UNIX_EPOCH).ok())
        .map(|d| d.as_millis() as i64)
        .unwrap_or(0);

    Entry {
        kind: file_kind(path, is_dir),
        preview_url: thumbnails::preview_url(path, is_dir, modified_ms),
        name,
        path: path.to_string_lossy().into_owned(),
        is_dir,
        executable: is_executable(&meta, is_dir),
        is_hidden,
        size: if is_dir { 0 } else { meta.len() },
        modified_ms,
    }
}

fn sort_entries_in_place(entries: &mut [Entry], field: &str, asc: bool, folders_first: bool) {
    entries.sort_unstable_by(|a, b| sort_entries(a, b, field, asc, folders_first));
}

fn sort_entries(a: &Entry, b: &Entry, field: &str, asc: bool, folders_first: bool) -> Ordering {
    if folders_first && a.is_dir != b.is_dir {
        return if a.is_dir {
            Ordering::Less
        } else {
            Ordering::Greater
        };
    }
    let ord = match field {
        "date" => a.modified_ms.cmp(&b.modified_ms),
        "size" => a.size.cmp(&b.size),
        "kind" => icmp(&a.kind, &b.kind),
        _ => icmp(&a.name, &b.name),
    }
    .then_with(|| icmp(&a.name, &b.name));
    if asc { ord } else { ord.reverse() }
}

fn icmp(a: &str, b: &str) -> Ordering {
    a.to_lowercase().cmp(&b.to_lowercase())
}

fn entry_to_json(e: &Entry) -> String {
    format!(
        "{{\"fileName\":\"{}\",\"filePath\":\"{}\",\"fileUrl\":\"file://{}\",\
         \"fileIsDir\":{},\"fileExecutable\":{},\"fileHidden\":{},\"fileSize\":{},\"fileModified\":{},\
         \"fileKind\":\"{}\",\"filePreviewUrl\":\"{}\"}}",
        json::escape(&e.name),
        json::escape(&e.path),
        json::escape(&e.path),
        e.is_dir,
        e.executable,
        e.is_hidden,
        e.size,
        e.modified_ms,
        json::escape(&e.kind),
        json::escape(&e.preview_url),
    )
}

fn is_executable(meta: &fs::Metadata, is_dir: bool) -> bool {
    if is_dir {
        return false;
    }
    #[cfg(unix)]
    {
        meta.permissions().mode() & 0o111 != 0
    }
    #[cfg(not(unix))]
    {
        false
    }
}

fn file_kind(path: &Path, is_dir: bool) -> String {
    if is_dir {
        return "Pasta".into();
    }
    match path.extension().and_then(|e| e.to_str()) {
        Some(e) if !e.is_empty() => e.to_uppercase(),
        _ => "Arquivo".into(),
    }
}
