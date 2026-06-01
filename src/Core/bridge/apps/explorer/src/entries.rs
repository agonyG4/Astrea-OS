use rayon::prelude::*;
use std::cmp::Ordering;
use std::env;
use std::fs;
#[cfg(unix)]
use std::os::unix::fs::PermissionsExt;
use std::path::{Path, PathBuf};
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
    pub size: i64,
    pub modified_ms: i64,
    pub kind: String,
    pub preview_url: String,
    pub remote: bool,
    pub metadata_limited: bool,
    pub filesystem: String,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct ListingProfile {
    pub remote: bool,
    pub filesystem: String,
}

impl ListingProfile {
    fn local(filesystem: String) -> Self {
        Self {
            remote: false,
            filesystem,
        }
    }

    fn remote(filesystem: String) -> Self {
        Self {
            remote: true,
            filesystem,
        }
    }
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

    let profile = path_listing_profile(dir);
    let mut entries = if profile.remote {
        read_dir_sequential(dir, show_hidden, &profile)?
            .into_iter()
            .filter(|entry| query.is_empty() || entry.name.to_lowercase().contains(&query))
            .collect()
    } else {
        let mut local_entries = Vec::new();
        search_dir_recursive(dir, show_hidden, &query, &mut local_entries)?;
        local_entries
    };
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
    let profile = path_listing_profile(dir);
    let mut entries = if profile.remote {
        read_dir_sequential(dir, show_hidden, &profile)?
    } else {
        read_dir_parallel(dir, show_hidden)?
    };
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

fn read_dir_sequential(
    dir: &Path,
    show_hidden: bool,
    profile: &ListingProfile,
) -> Result<Vec<Entry>, String> {
    let iter = fs::read_dir(dir).map_err(|e| format!("failed to read {}: {e}", dir.display()))?;
    let mut entries = Vec::new();
    for item in iter.filter_map(|r| r.ok()) {
        if let Some(entry) = entry_from_remote_dir_item(item, show_hidden, profile) {
            entries.push(entry);
        }
    }
    Ok(entries)
}

fn entry_from_remote_dir_item(
    item: fs::DirEntry,
    show_hidden: bool,
    profile: &ListingProfile,
) -> Option<Entry> {
    let name = item.file_name().to_string_lossy().into_owned();
    let is_hidden = name.starts_with('.');
    if !show_hidden && is_hidden {
        return None;
    }
    let is_dir = item.file_type().map(|kind| kind.is_dir()).unwrap_or(false);
    Some(entry_from_remote_parts(
        name,
        item.path().as_path(),
        is_dir,
        is_hidden,
        profile,
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
        size: if is_dir { 0 } else { meta.len() as i64 },
        modified_ms,
        remote: false,
        metadata_limited: false,
        filesystem: String::new(),
    }
}

fn entry_from_remote_parts(
    name: String,
    path: &Path,
    is_dir: bool,
    is_hidden: bool,
    profile: &ListingProfile,
) -> Entry {
    Entry {
        kind: file_kind(path, is_dir),
        preview_url: String::new(),
        name,
        path: path.to_string_lossy().into_owned(),
        is_dir,
        executable: false,
        is_hidden,
        size: if is_dir { 0 } else { -1 },
        modified_ms: 0,
        remote: true,
        metadata_limited: true,
        filesystem: profile.filesystem.clone(),
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
    let file_url = json::file_url(Path::new(&e.path));
    format!(
        "{{\"fileName\":\"{}\",\"filePath\":\"{}\",\"fileUrl\":\"{}\",\
         \"fileIsDir\":{},\"fileExecutable\":{},\"fileHidden\":{},\"fileSize\":{},\"fileModified\":{},\
         \"fileKind\":\"{}\",\"filePreviewUrl\":\"{}\",\
         \"fileRemote\":{},\"fileMetadataLimited\":{},\"fileFilesystem\":\"{}\"}}",
        json::escape(&e.name),
        json::escape(&e.path),
        json::escape(&file_url),
        e.is_dir,
        e.executable,
        e.is_hidden,
        e.size,
        e.modified_ms,
        json::escape(&e.kind),
        json::escape(&e.preview_url),
        e.remote,
        e.metadata_limited,
        json::escape(&e.filesystem),
    )
}

pub fn path_uses_remote_listing(path: &Path) -> bool {
    path_listing_profile(path).remote
}

fn path_listing_profile(path: &Path) -> ListingProfile {
    if path_has_remote_prefix_hint(path) {
        return ListingProfile::remote("path-hint".to_string());
    }

    let Some(fs_type) = filesystem_type_for_path(path) else {
        return ListingProfile::local(String::new());
    };

    if filesystem_type_is_remote(&fs_type) {
        ListingProfile::remote(fs_type)
    } else {
        ListingProfile::local(fs_type)
    }
}

fn path_has_remote_prefix_hint(path: &Path) -> bool {
    let runtime_dir = env::var("XDG_RUNTIME_DIR")
        .map(PathBuf::from)
        .unwrap_or_else(|_| PathBuf::from(format!("/run/user/{}", current_uid())));
    if path.starts_with(runtime_dir.join("gvfs")) {
        return true;
    }

    let prefixes = env::var("ASTREA_EXPLORER_REMOTE_PREFIXES").unwrap_or_default();
    path_matches_remote_prefixes(path, &prefixes)
}

fn path_matches_remote_prefixes(path: &Path, prefixes: &str) -> bool {
    prefixes
        .split(':')
        .map(str::trim)
        .filter(|value| !value.is_empty())
        .any(|prefix| path.starts_with(Path::new(prefix)))
}

#[cfg(unix)]
fn current_uid() -> u32 {
    unsafe extern "C" {
        fn getuid() -> u32;
    }
    unsafe { getuid() }
}

#[cfg(not(unix))]
fn current_uid() -> u32 {
    0
}

fn filesystem_type_for_path(path: &Path) -> Option<String> {
    let mountinfo = fs::read_to_string("/proc/self/mountinfo").ok()?;
    let query = if path.as_os_str().is_empty() {
        Path::new("/")
    } else {
        path
    };
    let mut best_mount_len = 0usize;
    let mut best_fs_type = None;

    for line in mountinfo.lines() {
        let Some((left, right)) = line.split_once(" - ") else {
            continue;
        };
        let Some(mount_point_raw) = left.split_whitespace().nth(4) else {
            continue;
        };
        let Some(fs_type) = right.split_whitespace().next() else {
            continue;
        };

        let mount_point = PathBuf::from(decode_mountinfo_field(mount_point_raw));
        if query.starts_with(&mount_point) {
            let mount_len = mount_point.as_os_str().len();
            if mount_len >= best_mount_len {
                best_mount_len = mount_len;
                best_fs_type = Some(fs_type.to_string());
            }
        }
    }

    best_fs_type
}

fn decode_mountinfo_field(value: &str) -> String {
    let mut out = String::with_capacity(value.len());
    let mut chars = value.chars().peekable();
    while let Some(ch) = chars.next() {
        if ch != '\\' {
            out.push(ch);
            continue;
        }

        let mut octal = String::new();
        for _ in 0..3 {
            if let Some(next) = chars.peek().copied() {
                if ('0'..='7').contains(&next) {
                    octal.push(next);
                    chars.next();
                }
            }
        }
        if octal.len() == 3 {
            if let Ok(byte) = u8::from_str_radix(&octal, 8) {
                out.push(byte as char);
                continue;
            }
        }
        out.push('\\');
        out.push_str(&octal);
    }
    out
}

fn filesystem_type_is_remote(fs_type: &str) -> bool {
    let fs = fs_type.trim().to_ascii_lowercase();
    if fs.is_empty() {
        return false;
    }
    if fs == "rclone" || fs.contains("rclone") {
        return true;
    }
    matches!(
        fs.as_str(),
        "sshfs" | "fuse.sshfs" | "davfs" | "davfs2" | "fuse.davfs" | "cifs" | "smb3"
            | "nfs" | "nfs4" | "9p" | "fuse.gvfsd-fuse" | "gvfsd-fuse" | "mtpfs"
            | "fuse.mtpfs" | "gphotofs" | "fuse.gphotofs"
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

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;

    #[test]
    fn entry_json_uses_encoded_file_url() {
        let root = std::env::temp_dir().join(format!(
            "astrea-entry-url-test-{}",
            std::process::id()
        ));
        let _ = fs::remove_dir_all(&root);
        fs::create_dir_all(&root).unwrap();
        let path = root.join("a # b 😀.txt");
        fs::write(&path, "x").unwrap();
        let meta = fs::metadata(&path).unwrap();
        let entry = entry_from_parts(
            "a # b 😀.txt".to_string(),
            &path,
            meta,
            false,
            false,
        );
        let body = entry_to_json(&entry);
        let raw_file_url = format!("\"fileUrl\":\"file://{}\"", path.to_string_lossy());

        assert!(body.contains("%20%23%20b%20%F0%9F%98%80.txt"));
        assert!(!body.contains(&raw_file_url));
        let _ = fs::remove_dir_all(root);
    }

    #[test]
    fn rclone_and_network_filesystems_use_remote_listing_profile() {
        for fs_type in ["fuse.rclone", "rclone", "fuse.sshfs", "davfs", "cifs", "nfs4"] {
            assert!(filesystem_type_is_remote(fs_type), "{fs_type} should be remote");
        }

        for fs_type in ["ext4", "btrfs", "xfs", "tmpfs"] {
            assert!(!filesystem_type_is_remote(fs_type), "{fs_type} should stay local");
        }
    }

    #[test]
    fn remote_entries_avoid_preview_and_expensive_metadata_fields() {
        let root = std::env::temp_dir().join(format!(
            "astrea-entry-remote-profile-test-{}",
            std::process::id()
        ));
        let _ = fs::remove_dir_all(&root);
        fs::create_dir_all(&root).unwrap();
        let path = root.join("photo.png");
        fs::write(&path, "x").unwrap();

        let profile = ListingProfile::remote("fuse.rclone".to_string());
        let entry = entry_from_remote_parts("photo.png".to_string(), &path, false, false, &profile);
        let body = entry_to_json(&entry);

        assert!(entry.remote);
        assert!(entry.metadata_limited);
        assert_eq!(entry.size, -1);
        assert_eq!(entry.modified_ms, 0);
        assert_eq!(entry.preview_url, "");
        assert!(body.contains("\"fileRemote\":true"));
        assert!(body.contains("\"fileMetadataLimited\":true"));
        assert!(body.contains("\"fileFilesystem\":\"fuse.rclone\""));
        let _ = fs::remove_dir_all(root);
    }

    #[test]
    fn remote_prefix_hint_respects_path_boundaries() {
        assert!(path_matches_remote_prefixes(
            Path::new("/tmp/astrea-cloud/file.txt"),
            "/tmp/astrea-cloud"
        ));
        assert!(path_matches_remote_prefixes(
            Path::new("/tmp/astrea-cloud"),
            "/tmp/astrea-cloud"
        ));
        assert!(!path_matches_remote_prefixes(
            Path::new("/tmp/astrea-cloud-old/file.txt"),
            "/tmp/astrea-cloud"
        ));
    }
}
