use rayon::prelude::*;
use std::cmp::Ordering;
use std::env;
use std::fs;
#[cfg(unix)]
use std::os::unix::fs::PermissionsExt;
use std::path::{Path, PathBuf};
use std::sync::OnceLock;
use std::time::UNIX_EPOCH;

use crate::json;
use crate::thumbnails;

const SEARCH_MAX_DEPTH: usize = 8;
const SEARCH_MAX_RESULTS: usize = 2_000;

static MOUNTINFO_CACHE: OnceLock<Option<Vec<MountInfoEntry>>> = OnceLock::new();

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

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
enum PreviewMode {
    None,
    Cached,
    Full,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct ListingProfile {
    pub remote: bool,
    pub filesystem: String,
}

impl PreviewMode {
    fn parse(value: &str) -> Option<Self> {
        match value {
            "none" => Some(Self::None),
            "cached" => Some(Self::Cached),
            "full" => Some(Self::Full),
            _ => None,
        }
    }
}

#[derive(Clone, Debug, Eq, PartialEq)]
struct MountInfoEntry {
    mount_point: PathBuf,
    fs_type: String,
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
    let (dir, show_hidden, sort_field, sort_asc, folders_first, preview_mode) =
        parse_list_args_with_preview(args)?;
    let entries = read_sorted_entries_with_preview(
        dir,
        show_hidden,
        sort_field,
        sort_asc,
        folders_first,
        preview_mode,
    )?;
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
    let preview_mode = parse_preview_mode_arg(&args[6..])?;

    let profile = path_listing_profile(dir);
    let mut entries = if profile.remote {
        read_dir_sequential(dir, show_hidden, &profile)?
            .into_iter()
            .filter(|entry| query.is_empty() || entry.name.to_lowercase().contains(&query))
            .collect()
    } else {
        let mut local_entries = Vec::new();
        search_dir_recursive_with_preview(
            dir,
            dir,
            show_hidden,
            &query,
            0,
            preview_mode,
            &mut local_entries,
        )?;
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
    read_sorted_entries_with_preview(
        dir,
        show_hidden,
        sort_field,
        sort_asc,
        folders_first,
        PreviewMode::Full,
    )
}

fn read_sorted_entries_with_preview(
    dir: &Path,
    show_hidden: bool,
    sort_field: &str,
    sort_asc: bool,
    folders_first: bool,
    preview_mode: PreviewMode,
) -> Result<Vec<Entry>, String> {
    let profile = path_listing_profile(dir);
    let mut entries = if profile.remote {
        read_dir_sequential(dir, show_hidden, &profile)?
    } else {
        read_dir_parallel(dir, show_hidden, preview_mode)?
    };
    sort_entries_in_place(&mut entries, sort_field, sort_asc, folders_first);
    Ok(entries)
}

fn parse_list_args_with_preview(
    args: &[String],
) -> Result<(&Path, bool, &str, bool, bool, PreviewMode), String> {
    let (dir, show_hidden, sort_field, sort_asc, folders_first) = parse_list_args(args)?;
    let preview_mode = parse_preview_mode_arg(args.get(5..).unwrap_or(&[]))?;
    Ok((
        dir,
        show_hidden,
        sort_field,
        sort_asc,
        folders_first,
        preview_mode,
    ))
}

fn parse_preview_mode_arg(args: &[String]) -> Result<PreviewMode, String> {
    let mut mode = PreviewMode::Full;
    let mut i = 0;
    while i < args.len() {
        let arg = &args[i];
        if let Some(value) = arg.strip_prefix("--preview-mode=") {
            mode = PreviewMode::parse(value)
                .ok_or_else(|| format!("invalid --preview-mode: {value}"))?;
            i += 1;
        } else if arg == "--preview-mode" {
            let value = args
                .get(i + 1)
                .ok_or_else(|| "missing value for --preview-mode".to_string())?;
            mode = PreviewMode::parse(value)
                .ok_or_else(|| format!("invalid --preview-mode: {value}"))?;
            i += 2;
        } else {
            i += 1;
        }
    }
    Ok(mode)
}

fn read_dir_parallel(
    dir: &Path,
    show_hidden: bool,
    preview_mode: PreviewMode,
) -> Result<Vec<Entry>, String> {
    let raw: Vec<_> = fs::read_dir(dir)
        .map_err(|e| format!("failed to read {}: {e}", dir.display()))?
        .filter_map(|r| r.ok())
        .collect();

    Ok(raw
        .into_par_iter()
        .filter_map(|item| entry_from_dir_item(item, show_hidden, preview_mode))
        .collect())
}

fn entry_from_dir_item(
    item: fs::DirEntry,
    show_hidden: bool,
    preview_mode: PreviewMode,
) -> Option<Entry> {
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
        preview_mode,
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
    root: &Path,
    dir: &Path,
    show_hidden: bool,
    query: &str,
    depth: usize,
    out: &mut Vec<Entry>,
) -> Result<(), String> {
    search_dir_recursive_with_preview(root, dir, show_hidden, query, depth, PreviewMode::Full, out)
}

fn search_dir_recursive_with_preview(
    root: &Path,
    dir: &Path,
    show_hidden: bool,
    query: &str,
    depth: usize,
    preview_mode: PreviewMode,
    out: &mut Vec<Entry>,
) -> Result<(), String> {
    if depth > SEARCH_MAX_DEPTH || out.len() >= SEARCH_MAX_RESULTS {
        return Ok(());
    }

    let iter = match fs::read_dir(dir) {
        Ok(iter) => iter,
        Err(_) => return Ok(()),
    };

    for item in iter.filter_map(|r| r.ok()) {
        if out.len() >= SEARCH_MAX_RESULTS {
            break;
        }

        let path = item.path();
        let file_type = match item.file_type() {
            Ok(file_type) => file_type,
            Err(_) => continue,
        };
        let meta_result = if file_type.is_symlink() {
            fs::metadata(&path)
        } else {
            item.metadata()
        };
        let meta = match meta_result {
            Ok(meta) => meta,
            Err(_) => continue,
        };
        let is_dir = meta.is_dir();
        let should_descend = file_type.is_dir();
        let name = item.file_name().to_string_lossy().into_owned();
        let is_hidden = name.starts_with('.');

        if !show_hidden && is_hidden {
            continue;
        }

        if query.is_empty() || name.to_lowercase().contains(query) {
            out.push(entry_from_parts(
                name,
                &path,
                meta,
                is_dir,
                is_hidden,
                preview_mode,
            ));
        }

        if should_descend && depth < SEARCH_MAX_DEPTH && !should_prune_search_dir(root, &path) {
            let _ = search_dir_recursive_with_preview(
                root,
                &path,
                show_hidden,
                query,
                depth + 1,
                preview_mode,
                out,
            );
        }
    }

    Ok(())
}

fn should_prune_search_dir(root: &Path, path: &Path) -> bool {
    if path == root || path_is_compat_runtime_dir(root) {
        return false;
    }
    path_is_compat_runtime_dir(path)
}

fn path_is_compat_runtime_dir(path: &Path) -> bool {
    path_has_component_suffix(path, &["drive_c", "windows"])
        || (path_has_proton_runtime_hint(path)
            && (path_has_component_suffix(path, &["files", "lib", "wine"])
                || path_has_component_suffix(path, &["files", "share", "default_pfx"])))
}

fn path_has_component_suffix(path: &Path, suffix: &[&str]) -> bool {
    let components: Vec<_> = path
        .components()
        .filter_map(|component| component.as_os_str().to_str())
        .collect();
    components.len() >= suffix.len()
        && components[components.len() - suffix.len()..]
            .iter()
            .zip(suffix.iter())
            .all(|(component, expected)| component.eq_ignore_ascii_case(expected))
}

fn path_has_proton_runtime_hint(path: &Path) -> bool {
    path.components()
        .filter_map(|component| component.as_os_str().to_str())
        .any(|component| {
            let lower = component.to_ascii_lowercase();
            lower == "proton"
                || lower.starts_with("proton-")
                || lower.starts_with("ge-proton")
                || lower == "umu-default"
                || lower == "umu"
        })
}

fn entry_from_parts(
    name: String,
    path: &Path,
    meta: fs::Metadata,
    is_dir: bool,
    is_hidden: bool,
    preview_mode: PreviewMode,
) -> Entry {
    let modified_ms = meta
        .modified()
        .ok()
        .and_then(|t| t.duration_since(UNIX_EPOCH).ok())
        .map(|d| d.as_millis() as i64)
        .unwrap_or(0);

    Entry {
        kind: file_kind(path, is_dir),
        preview_url: preview_url_for_mode(path, is_dir, modified_ms, preview_mode),
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

fn preview_url_for_mode(path: &Path, is_dir: bool, modified_ms: i64, mode: PreviewMode) -> String {
    match mode {
        PreviewMode::None => String::new(),
        PreviewMode::Cached => cached_preview_url(path, is_dir, modified_ms),
        PreviewMode::Full => thumbnails::preview_url(path, is_dir, modified_ms),
    }
}

fn cached_preview_url(path: &Path, is_dir: bool, modified_ms: i64) -> String {
    if is_dir {
        return String::new();
    }
    if thumbnails::is_svg(path) {
        return json::file_url(path);
    }
    let Some(home) = env::var_os("HOME") else {
        return String::new();
    };
    let cached = PathBuf::from(home)
        .join(".cache/explorer/thumbnails")
        .join(format!("{}.png", thumbnail_cache_key(path, modified_ms)));
    if cached.exists() {
        json::file_url(&cached)
    } else {
        String::new()
    }
}

fn thumbnail_cache_key(path: &Path, modified_ms: i64) -> String {
    let mut h: u64 = 0xcbf29ce484222325;
    for &b in format!("v3|{}|{modified_ms}", path.to_string_lossy()).as_bytes() {
        h ^= u64::from(b);
        h = h.wrapping_mul(0x100000001b3);
    }
    format!("{h:016x}")
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
    let mut decorated: Vec<_> = entries
        .iter()
        .cloned()
        .map(|entry| SortEntry {
            name_lower: entry.name.to_lowercase(),
            kind_lower: entry.kind.to_lowercase(),
            entry,
        })
        .collect();
    decorated.sort_unstable_by(|a, b| sort_decorated_entries(a, b, field, asc, folders_first));
    for (target, sorted) in entries.iter_mut().zip(decorated) {
        *target = sorted.entry;
    }
}

struct SortEntry {
    entry: Entry,
    name_lower: String,
    kind_lower: String,
}

fn sort_decorated_entries(
    a: &SortEntry,
    b: &SortEntry,
    field: &str,
    asc: bool,
    folders_first: bool,
) -> Ordering {
    if folders_first && a.entry.is_dir != b.entry.is_dir {
        return if a.entry.is_dir {
            Ordering::Less
        } else {
            Ordering::Greater
        };
    }
    let ord = match field {
        "date" => a.entry.modified_ms.cmp(&b.entry.modified_ms),
        "size" => a.entry.size.cmp(&b.entry.size),
        "kind" => a.kind_lower.cmp(&b.kind_lower),
        _ => a.name_lower.cmp(&b.name_lower),
    }
    .then_with(|| a.name_lower.cmp(&b.name_lower));
    if asc {
        ord
    } else {
        ord.reverse()
    }
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
    let query = if path.as_os_str().is_empty() {
        Path::new("/")
    } else {
        path
    };
    filesystem_type_for_path_from_mounts(query, mountinfo_entries()?)
}

fn mountinfo_entries() -> Option<&'static [MountInfoEntry]> {
    MOUNTINFO_CACHE
        .get_or_init(|| {
            fs::read_to_string("/proc/self/mountinfo")
                .ok()
                .map(|mountinfo| parse_mountinfo_entries(&mountinfo))
        })
        .as_deref()
}

fn filesystem_type_for_path_from_mounts(query: &Path, mounts: &[MountInfoEntry]) -> Option<String> {
    let mut best_mount_len = 0usize;
    let mut best_fs_type = None;

    for mount in mounts {
        if query.starts_with(&mount.mount_point) {
            let mount_len = mount.mount_point.as_os_str().len();
            if mount_len >= best_mount_len {
                best_mount_len = mount_len;
                best_fs_type = Some(mount.fs_type.clone());
            }
        }
    }

    best_fs_type
}

fn parse_mountinfo_entries(mountinfo: &str) -> Vec<MountInfoEntry> {
    let mut entries = Vec::new();
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
        entries.push(MountInfoEntry {
            mount_point,
            fs_type: fs_type.to_string(),
        });
    }
    entries
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
        "sshfs"
            | "fuse.sshfs"
            | "davfs"
            | "davfs2"
            | "fuse.davfs"
            | "cifs"
            | "smb3"
            | "nfs"
            | "nfs4"
            | "9p"
            | "fuse.gvfsd-fuse"
            | "gvfsd-fuse"
            | "mtpfs"
            | "fuse.mtpfs"
            | "gphotofs"
            | "fuse.gphotofs"
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
        let root =
            std::env::temp_dir().join(format!("astrea-entry-url-test-{}", std::process::id()));
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
            PreviewMode::Full,
        );
        let body = entry_to_json(&entry);
        let raw_file_url = format!("\"fileUrl\":\"file://{}\"", path.to_string_lossy());

        assert!(body.contains("%20%23%20b%20%F0%9F%98%80.txt"));
        assert!(!body.contains(&raw_file_url));
        let _ = fs::remove_dir_all(root);
    }

    #[test]
    fn preview_mode_parser_defaults_to_full_and_accepts_flag_forms() {
        assert_eq!(parse_preview_mode_arg(&[]).unwrap(), PreviewMode::Full);
        assert_eq!(
            parse_preview_mode_arg(&["--preview-mode".into(), "none".into()]).unwrap(),
            PreviewMode::None
        );
        assert_eq!(
            parse_preview_mode_arg(&["--preview-mode=cached".into()]).unwrap(),
            PreviewMode::Cached
        );
        assert!(parse_preview_mode_arg(&["--preview-mode=bad".into()]).is_err());
    }

    #[test]
    fn preview_mode_none_keeps_schema_but_omits_preview_url() {
        let root = std::env::temp_dir().join(format!(
            "astrea-entry-preview-none-test-{}",
            std::process::id()
        ));
        let _ = fs::remove_dir_all(&root);
        fs::create_dir_all(&root).unwrap();
        let path = root.join("photo.png");
        fs::write(&path, "x").unwrap();
        let meta = fs::metadata(&path).unwrap();

        let entry = entry_from_parts(
            "photo.png".to_string(),
            &path,
            meta,
            false,
            false,
            PreviewMode::None,
        );
        let body = entry_to_json(&entry);

        assert_eq!(entry.preview_url, "");
        assert!(body.contains("\"filePreviewUrl\":\"\""));
        assert_eq!(entry.name, "photo.png");
        let _ = fs::remove_dir_all(root);
    }

    #[test]
    fn sorting_is_case_insensitive_without_touching_display_names() {
        let mut entries = vec![
            test_entry("banana.txt", false, "TXT", 10, 1),
            test_entry("Apricot.txt", false, "TXT", 10, 2),
            test_entry("apple.txt", true, "Pasta", 0, 3),
        ];

        sort_entries_in_place(&mut entries, "name", true, true);

        assert_eq!(entries[0].name, "apple.txt");
        assert_eq!(entries[1].name, "Apricot.txt");
        assert_eq!(entries[2].name, "banana.txt");
    }

    #[test]
    fn mountinfo_parser_selects_deepest_matching_mount_once_parsed() {
        let mounts = parse_mountinfo_entries(
            "1 0 0:1 / / rw - ext4 /dev/root rw\n\
             2 1 0:2 / /mnt/Remote\\040Drive rw - fuse.sshfs host rw\n\
             3 1 0:3 / /mnt/Remote\\040Drive/sub rw - nfs server rw\n",
        );

        assert_eq!(
            filesystem_type_for_path_from_mounts(Path::new("/mnt/Remote Drive/file"), &mounts),
            Some("fuse.sshfs".to_string())
        );
        assert_eq!(
            filesystem_type_for_path_from_mounts(Path::new("/mnt/Remote Drive/sub/file"), &mounts),
            Some("nfs".to_string())
        );
    }

    fn test_entry(name: &str, is_dir: bool, kind: &str, size: i64, modified_ms: i64) -> Entry {
        Entry {
            name: name.to_string(),
            path: format!("/tmp/{name}"),
            is_dir,
            executable: false,
            is_hidden: false,
            size,
            modified_ms,
            kind: kind.to_string(),
            preview_url: String::new(),
            remote: false,
            metadata_limited: false,
            filesystem: String::new(),
        }
    }

    #[test]
    fn rclone_and_network_filesystems_use_remote_listing_profile() {
        for fs_type in [
            "fuse.rclone",
            "rclone",
            "fuse.sshfs",
            "davfs",
            "cifs",
            "nfs4",
        ] {
            assert!(
                filesystem_type_is_remote(fs_type),
                "{fs_type} should be remote"
            );
        }

        for fs_type in ["ext4", "btrfs", "xfs", "tmpfs"] {
            assert!(
                !filesystem_type_is_remote(fs_type),
                "{fs_type} should stay local"
            );
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

    #[test]
    #[cfg(unix)]
    fn recursive_search_skips_directory_symlinks() {
        use std::os::unix::fs::symlink;

        let root =
            std::env::temp_dir().join(format!("astrea-search-symlink-test-{}", std::process::id()));
        let _ = fs::remove_dir_all(&root);
        fs::create_dir_all(root.join("real_dir")).unwrap();
        fs::write(root.join("real_dir/hidden_match.txt"), "x").unwrap();
        symlink(root.join("real_dir"), root.join("dir_link")).unwrap();

        let mut entries = Vec::new();
        search_dir_recursive(&root, &root, true, "hidden_match", 0, &mut entries).unwrap();

        assert_eq!(entries.len(), 1);
        assert!(entries[0].path.ends_with("real_dir/hidden_match.txt"));
        let _ = fs::remove_dir_all(root);
    }

    #[test]
    #[cfg(unix)]
    fn recursive_search_keeps_directory_symlink_classification() {
        use std::os::unix::fs::symlink;

        let root = std::env::temp_dir().join(format!(
            "astrea-search-symlink-classification-test-{}",
            std::process::id()
        ));
        let _ = fs::remove_dir_all(&root);
        fs::create_dir_all(root.join("real_dir")).unwrap();
        symlink(root.join("real_dir"), root.join("dir_link")).unwrap();

        let mut entries = Vec::new();
        search_dir_recursive(&root, &root, true, "dir_link", 0, &mut entries).unwrap();

        assert_eq!(entries.len(), 1);
        assert!(entries[0].is_dir);
        let _ = fs::remove_dir_all(root);
    }

    #[test]
    fn recursive_search_prunes_compat_runtime_noise_from_parent_search() {
        let root = std::env::temp_dir().join(format!(
            "astrea-search-compat-prune-test-{}",
            std::process::id()
        ));
        let _ = fs::remove_dir_all(&root);
        let real = root.join("Steam");
        let compat_system32 = root.join("Games/Proton/drive_c/windows/system32");
        let compat_wine = root.join("Downloads/GE-Proton/files/lib/wine/x86_64-windows");
        let compat_default_pfx =
            root.join("Downloads/GE-Proton/files/share/default_pfx/drive_c/windows/system32");
        fs::create_dir_all(&real).unwrap();
        fs::create_dir_all(&compat_system32).unwrap();
        fs::create_dir_all(&compat_wine).unwrap();
        fs::create_dir_all(&compat_default_pfx).unwrap();
        fs::write(real.join("steam.exe"), "real").unwrap();
        fs::write(compat_system32.join("steam.exe"), "compat").unwrap();
        fs::write(compat_wine.join("steam.exe"), "compat").unwrap();
        fs::write(compat_default_pfx.join("steam.exe"), "compat").unwrap();

        let mut entries = Vec::new();
        search_dir_recursive(&root, &root, true, "steam.exe", 0, &mut entries).unwrap();

        assert_eq!(entries.len(), 1);
        assert!(entries[0].path.ends_with("Steam/steam.exe"));
        let _ = fs::remove_dir_all(root);
    }

    #[test]
    fn recursive_search_does_not_prune_generic_files_lib_wine_project() {
        let root = std::env::temp_dir().join(format!(
            "astrea-search-generic-wine-test-{}",
            std::process::id()
        ));
        let generic_wine = root.join("project/files/lib/wine");
        let _ = fs::remove_dir_all(&root);
        fs::create_dir_all(&generic_wine).unwrap();
        fs::write(generic_wine.join("steam.exe"), "source").unwrap();

        let mut entries = Vec::new();
        search_dir_recursive(&root, &root, true, "steam.exe", 0, &mut entries).unwrap();

        assert_eq!(entries.len(), 1);
        assert!(entries[0]
            .path
            .ends_with("project/files/lib/wine/steam.exe"));
        let _ = fs::remove_dir_all(root);
    }

    #[test]
    fn recursive_search_does_not_prune_proton_named_non_runtime_project() {
        let root = std::env::temp_dir().join(format!(
            "astrea-search-protonmail-project-test-{}",
            std::process::id()
        ));
        let project_wine = root.join("protonmail-tool/files/lib/wine");
        let project_pfx = root.join("protonmail-tool/files/share/default_pfx");
        let _ = fs::remove_dir_all(&root);
        fs::create_dir_all(&project_wine).unwrap();
        fs::create_dir_all(&project_pfx).unwrap();
        fs::write(project_wine.join("steam.exe"), "source").unwrap();
        fs::write(project_pfx.join("steam-helper.exe"), "source").unwrap();

        let mut entries = Vec::new();
        search_dir_recursive(&root, &root, true, "steam", 0, &mut entries).unwrap();

        assert_eq!(entries.len(), 2);
        assert!(entries.iter().any(|entry| {
            entry
                .path
                .ends_with("protonmail-tool/files/lib/wine/steam.exe")
        }));
        assert!(entries.iter().any(|entry| {
            entry
                .path
                .ends_with("protonmail-tool/files/share/default_pfx/steam-helper.exe")
        }));
        let _ = fs::remove_dir_all(root);
    }

    #[test]
    fn recursive_search_allows_explicit_compat_runtime_root() {
        let root = std::env::temp_dir().join(format!(
            "astrea-search-compat-explicit-test-{}",
            std::process::id()
        ));
        let compat_root = root.join("Games/Proton/drive_c/windows");
        let compat_system32 = compat_root.join("system32");
        let _ = fs::remove_dir_all(&root);
        fs::create_dir_all(&compat_system32).unwrap();
        fs::write(compat_system32.join("steam.exe"), "compat").unwrap();

        let mut entries = Vec::new();
        search_dir_recursive(
            &compat_root,
            &compat_root,
            true,
            "steam.exe",
            0,
            &mut entries,
        )
        .unwrap();

        assert_eq!(entries.len(), 1);
        assert!(entries[0].path.ends_with("system32/steam.exe"));
        let _ = fs::remove_dir_all(root);
    }
}
