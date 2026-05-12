use rayon::prelude::*;
use std::cmp::Ordering;
use std::env;
use std::fs;
use std::io::{self, Write};
#[cfg(unix)]
use std::os::unix::fs::PermissionsExt;
use std::path::{Path, PathBuf};
use std::process::Command;
use std::time::UNIX_EPOCH;

#[derive(Clone)]
struct Entry {
    name: String,
    path: String,
    is_dir: bool,
    executable: bool,
    is_hidden: bool,
    size: u64,
    modified_ms: i64,
    kind: String,
    preview_url: String,
}

#[derive(Default, Clone)]
struct Device {
    name: String,
    path: String,
    dev_type: String,
    hotplug: bool,
    removable: bool,
    label: String,
    uuid: String,
    fstype: String,
    size: String,
    mountpoints: Vec<String>,
}

fn main() {
    if let Err(e) = run() {
        eprintln!("{e}");
        std::process::exit(1);
    }
}

fn run() -> Result<(), String> {
    let args: Vec<String> = env::args().collect();
    match args.get(1).map(String::as_str) {
        Some("list") => run_list(&args[2..]),
        Some("search") => run_search(&args[2..]),
        Some("devices") => run_devices(),
        Some("mount") => run_mount_cmd(&args[2..], "mount", "mounted"),
        Some("unmount") => run_mount_cmd(&args[2..], "unmount", "unmounted"),
        Some("remount") => run_remount_cmd(&args[2..]),
        Some("warm-thumbnails") => run_warm_thumbnails(&args[2..]),
        Some("install-appimage") => run_install_appimage(&args[2..]),
        Some("file-op") => run_file_op(&args[2..]),
        _ if args.len() >= 6 => run_list(&args[1..]),
        _ => Err("usage: explorer_backend list|search|devices|mount|unmount|remount|warm-thumbnails|install-appimage|file-op ...".into()),
    }
}

fn run_list(args: &[String]) -> Result<(), String> {
    let (dir, show_hidden, sort_field, sort_asc, folders_first) = parse_list_args(args)?;
    let mut entries = read_dir_parallel(dir, show_hidden)?;
    entries.sort_unstable_by(|a, b| sort_entries(a, b, sort_field, sort_asc, folders_first));
    println!("{}", to_json_array(&entries, entry_to_json));
    Ok(())
}

fn run_devices() -> Result<(), String> {
    let out = lsblk(None)?;
    let mut devices: Vec<Device> = out
        .lines()
        .filter_map(parse_lsblk_line)
        .filter(show_device)
        .collect();
    devices.sort_unstable_by(|a, b| {
        device_priority(a)
            .cmp(&device_priority(b))
            .then_with(|| icmp(&device_title(a), &device_title(b)))
            .then_with(|| icmp(&a.path, &b.path))
    });
    println!("{}", to_json_array(&devices, device_to_json));
    Ok(())
}

fn run_search(args: &[String]) -> Result<(), String> {
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
    entries.sort_unstable_by(|a, b| sort_entries(a, b, sort_field, sort_asc, folders_first));
    println!("{}", to_json_array(&entries, entry_to_json));
    Ok(())
}

fn run_mount_cmd(args: &[String], verb: &str, msg: &str) -> Result<(), String> {
    let path = args
        .first()
        .ok_or_else(|| format!("usage: explorer_backend {verb} <device_path>"))?;

    if verb == "mount" {
        if let Some(dev) = device_by_path(path)? {
            if let Some(existing) = primary_mount(&dev) {
                println!(
                    "{{\"ok\":true,\"mountPath\":\"{}\",\"message\":\"already-mounted\"}}",
                    escape(existing)
                );
                return Ok(());
            }
        }
    }

    let out = udisksctl(verb, path)?;

    let mount_path = if verb == "mount" {
        parse_udisks_path(&out)
            .or_else(|| {
                device_by_path(path)
                    .ok()
                    .flatten()
                    .and_then(|d| primary_mount(&d).map(str::to_string))
            })
            .unwrap_or_default()
    } else {
        String::new()
    };

    println!(
        "{{\"ok\":true,\"mountPath\":\"{}\",\"message\":\"{msg}\"}}",
        escape(&mount_path)
    );
    Ok(())
}

fn run_remount_cmd(args: &[String]) -> Result<(), String> {
    let path = args
        .first()
        .ok_or_else(|| "usage: explorer_backend remount <device_path>".to_string())?;

    if let Some(dev) = device_by_path(path)? {
        if primary_mount(&dev).is_some() {
            udisksctl("unmount", path)?;
        }
    }

    let out = udisksctl("mount", path)?;
    let mount_path = parse_udisks_path(&out)
        .or_else(|| {
            device_by_path(path)
                .ok()
                .flatten()
                .and_then(|d| primary_mount(&d).map(str::to_string))
        })
        .unwrap_or_default();

    println!(
        "{{\"ok\":true,\"mountPath\":\"{}\",\"message\":\"remounted\"}}",
        escape(&mount_path)
    );
    Ok(())
}

fn run_warm_thumbnails(args: &[String]) -> Result<(), String> {
    let (dir, show_hidden, sort_field, sort_asc, folders_first) = parse_list_args(args)?;
    let offset = args.get(5).and_then(|v| v.parse().ok()).unwrap_or(0usize);
    let limit = args.get(6).and_then(|v| v.parse().ok()).unwrap_or(24usize);

    let cache = cache_dir()?;
    fs::create_dir_all(&cache).map_err(|e| format!("cache dir: {e}"))?;

    let mut entries = read_dir_parallel(dir, show_hidden)?;
    entries.sort_unstable_by(|a, b| sort_entries(a, b, sort_field, sort_asc, folders_first));

    let targets: Vec<_> = entries
        .into_iter()
        .skip(offset)
        .filter(|e| {
            let path = Path::new(&e.path);
            !e.is_dir && is_previewable(path) && !is_svg(path)
        })
        .take(limit)
        .collect();

    let warmed = targets
        .into_par_iter()
        .filter(|e| {
            let p = PathBuf::from(&e.path);
            let out = cache.join(format!("{}.png", cache_key(&p, e.modified_ms)));
            out.exists() || gen_thumbnail(&p, &out).is_ok()
        })
        .count();

    println!("{warmed}");
    Ok(())
}

fn run_install_appimage(args: &[String]) -> Result<(), String> {
    let source = args
        .first()
        .ok_or_else(|| "usage: explorer_backend install-appimage <path>".to_string())?;
    let source_path = Path::new(source);

    if !source_path.is_file() {
        return Err(format!("not a file: {}", source_path.display()));
    }
    if !source_path
        .extension()
        .and_then(|v| v.to_str())
        .map(|v| v.eq_ignore_ascii_case("AppImage"))
        .unwrap_or(false)
    {
        return Err("selected file is not an AppImage".into());
    }

    let home = env::var("HOME").map_err(|_| "HOME is not set".to_string())?;
    let bin_dir = Path::new(&home).join(".local/bin");
    let apps_dir = Path::new(&home).join(".local/share/applications");
    fs::create_dir_all(&bin_dir).map_err(|e| format!("create {}: {e}", bin_dir.display()))?;
    fs::create_dir_all(&apps_dir).map_err(|e| format!("create {}: {e}", apps_dir.display()))?;

    let file_name = source_path
        .file_name()
        .ok_or_else(|| "invalid AppImage path".to_string())?;
    let target_path = bin_dir.join(file_name);
    fs::copy(source_path, &target_path).map_err(|e| format!("copy AppImage: {e}"))?;

    #[cfg(unix)]
    {
        let mut perms = fs::metadata(&target_path)
            .map_err(|e| format!("metadata {}: {e}", target_path.display()))?
            .permissions();
        perms.set_mode(perms.mode() | 0o111);
        fs::set_permissions(&target_path, perms)
            .map_err(|e| format!("chmod {}: {e}", target_path.display()))?;
    }

    let app_name = source_path
        .file_stem()
        .and_then(|v| v.to_str())
        .map(str::trim)
        .filter(|v| !v.is_empty())
        .unwrap_or("AppImage");
    let desktop_path = apps_dir.join(format!("{}.desktop", desktop_id(app_name)));
    let desktop = format!(
        "[Desktop Entry]\nName={}\nExec={}\nIcon=application-x-executable\nType=Application\nCategories=Utility;\nTerminal=false\n",
        desktop_escape(app_name),
        desktop_escape(&target_path.to_string_lossy())
    );
    fs::write(&desktop_path, desktop)
        .map_err(|e| format!("write {}: {e}", desktop_path.display()))?;

    println!(
        "{{\"ok\":true,\"path\":\"{}\",\"desktop\":\"{}\"}}",
        escape(&target_path.to_string_lossy()),
        escape(&desktop_path.to_string_lossy())
    );
    Ok(())
}

fn run_file_op(args: &[String]) -> Result<(), String> {
    match run_file_op_inner(args) {
        Ok(()) => Ok(()),
        Err(err) => {
            println!("ERROR|{}", err);
            flush_stdout();
            Err(err)
        }
    }
}

fn run_file_op_inner(args: &[String]) -> Result<(), String> {
    if args.len() < 5 {
        return Err("usage: explorer_backend file-op <copy|move|cut> <destination> <overwrite|skip|rename|keep-both> <rename> <paths...>".into());
    }

    let mode = normalize_file_op_mode(&args[0])?;
    let destination = Path::new(&args[1]);
    let policy = args[2].as_str();
    let rename = args[3].trim();
    let sources: Vec<PathBuf> = args[4..].iter().map(PathBuf::from).collect();

    if !destination.is_dir() {
        return Err(format!(
            "destination is not a directory: {}",
            destination.display()
        ));
    }

    println!(
        "START|{}|{}|{}",
        mode,
        destination.to_string_lossy(),
        sources.len()
    );
    flush_stdout();

    let mut completed = 0usize;
    for source in &sources {
        let name = source
            .file_name()
            .and_then(|v| v.to_str())
            .ok_or_else(|| format!("invalid source path: {}", source.display()))?;
        let target_name = if policy == "rename" && sources.len() == 1 && !rename.is_empty() {
            rename
        } else {
            name
        };
        let initial_target = destination.join(target_name);

        if same_path(source, &initial_target) {
            completed += 1;
            emit_file_op_progress(completed, sources.len(), source);
            continue;
        }

        let Some(target) = resolve_conflict_target(&initial_target, policy)? else {
            completed += 1;
            emit_file_op_progress(completed, sources.len(), source);
            continue;
        };

        if let Some(parent) = target.parent() {
            fs::create_dir_all(parent).map_err(|e| format!("create {}: {e}", parent.display()))?;
        }

        if mode == "move" {
            move_path(source, &target)?;
        } else {
            copy_path(source, &target)?;
        }

        completed += 1;
        emit_file_op_progress(completed, sources.len(), source);
    }

    println!(
        "DONE|{}|{}|{}",
        destination.to_string_lossy(),
        completed,
        sources.len()
    );
    flush_stdout();
    Ok(())
}

fn normalize_file_op_mode(mode: &str) -> Result<&'static str, String> {
    match mode {
        "copy" => Ok("copy"),
        "move" | "cut" => Ok("move"),
        other => Err(format!("unsupported file operation mode: {other}")),
    }
}

fn emit_file_op_progress(done: usize, total: usize, source: &Path) {
    let percent = if total == 0 {
        100
    } else {
        done.saturating_mul(100) / total
    };
    let name = source
        .file_name()
        .and_then(|v| v.to_str())
        .unwrap_or_default();
    println!("PROGRESS|{}|{}|{}|{}", done, total, percent, name);
    flush_stdout();
}

fn flush_stdout() {
    let _ = io::stdout().flush();
}

fn resolve_conflict_target(target: &Path, policy: &str) -> Result<Option<PathBuf>, String> {
    if !target.exists() {
        return Ok(Some(target.to_path_buf()));
    }

    match policy {
        "skip" => Ok(None),
        "overwrite" => {
            remove_existing(target)?;
            Ok(Some(target.to_path_buf()))
        }
        "rename" | "keep-both" => Ok(Some(unique_path(target))),
        other => Err(format!("unsupported conflict policy: {other}")),
    }
}

fn unique_path(path: &Path) -> PathBuf {
    if !path.exists() {
        return path.to_path_buf();
    }

    let parent = path.parent().unwrap_or_else(|| Path::new(""));
    let stem = path
        .file_stem()
        .and_then(|v| v.to_str())
        .filter(|v| !v.is_empty())
        .or_else(|| path.file_name().and_then(|v| v.to_str()))
        .unwrap_or("item");
    let extension = path.extension().and_then(|v| v.to_str()).unwrap_or("");

    for n in 2..10_000usize {
        let name = if extension.is_empty() {
            format!("{stem} {n}")
        } else {
            format!("{stem} {n}.{extension}")
        };
        let candidate = parent.join(name);
        if !candidate.exists() {
            return candidate;
        }
    }

    parent.join(format!("{stem} {}", unix_millis()))
}

fn unix_millis() -> u128 {
    std::time::SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_millis())
        .unwrap_or(0)
}

fn same_path(a: &Path, b: &Path) -> bool {
    if a == b {
        return true;
    }
    match (fs::canonicalize(a), fs::canonicalize(b)) {
        (Ok(a), Ok(b)) => a == b,
        _ => false,
    }
}

fn remove_existing(path: &Path) -> Result<(), String> {
    if path.is_dir() && !path.is_symlink() {
        fs::remove_dir_all(path).map_err(|e| format!("remove {}: {e}", path.display()))
    } else {
        fs::remove_file(path).map_err(|e| format!("remove {}: {e}", path.display()))
    }
}

fn move_path(source: &Path, target: &Path) -> Result<(), String> {
    match fs::rename(source, target) {
        Ok(()) => Ok(()),
        Err(rename_err) => {
            copy_path(source, target)?;
            remove_existing(source).map_err(|remove_err| {
                format!(
                    "move {} to {}: rename failed ({rename_err}); cleanup failed ({remove_err})",
                    source.display(),
                    target.display()
                )
            })
        }
    }
}

fn copy_path(source: &Path, target: &Path) -> Result<(), String> {
    let meta =
        fs::symlink_metadata(source).map_err(|e| format!("metadata {}: {e}", source.display()))?;
    if meta.file_type().is_symlink() {
        copy_symlink(source, target)
    } else if meta.is_dir() {
        copy_dir_recursive(source, target)
    } else if meta.is_file() {
        fs::copy(source, target)
            .map(|_| ())
            .map_err(|e| format!("copy {} to {}: {e}", source.display(), target.display()))
    } else {
        Err(format!("unsupported file type: {}", source.display()))
    }
}

#[cfg(unix)]
fn copy_symlink(source: &Path, target: &Path) -> Result<(), String> {
    use std::os::unix::fs::symlink;
    let link = fs::read_link(source).map_err(|e| format!("readlink {}: {e}", source.display()))?;
    symlink(&link, target).map_err(|e| format!("symlink {}: {e}", target.display()))
}

#[cfg(not(unix))]
fn copy_symlink(source: &Path, target: &Path) -> Result<(), String> {
    let link = fs::read_link(source).map_err(|e| format!("readlink {}: {e}", source.display()))?;
    if link.is_dir() {
        copy_dir_recursive(&link, target)
    } else {
        fs::copy(&link, target)
            .map(|_| ())
            .map_err(|e| format!("copy {} to {}: {e}", link.display(), target.display()))
    }
}

fn copy_dir_recursive(source: &Path, target: &Path) -> Result<(), String> {
    if target.starts_with(source) {
        return Err(format!(
            "refusing to copy directory into itself: {} -> {}",
            source.display(),
            target.display()
        ));
    }

    fs::create_dir_all(target).map_err(|e| format!("create {}: {e}", target.display()))?;
    let meta = fs::metadata(source).map_err(|e| format!("metadata {}: {e}", source.display()))?;
    let _ = fs::set_permissions(target, meta.permissions());

    for entry in fs::read_dir(source).map_err(|e| format!("read {}: {e}", source.display()))? {
        let entry = entry.map_err(|e| format!("read {}: {e}", source.display()))?;
        let child_source = entry.path();
        let child_target = target.join(entry.file_name());
        if child_target.exists() {
            remove_existing(&child_target)?;
        }
        copy_path(&child_source, &child_target)?;
    }
    Ok(())
}

fn parse_list_args(args: &[String]) -> Result<(&Path, bool, &str, bool, bool), String> {
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

fn read_dir_parallel(dir: &Path, show_hidden: bool) -> Result<Vec<Entry>, String> {
    let raw: Vec<_> = fs::read_dir(dir)
        .map_err(|e| format!("failed to read {}: {e}", dir.display()))?
        .filter_map(|r| r.ok())
        .collect();

    Ok(raw
        .into_par_iter()
        .filter_map(|item| {
            let path = item.path();
            let meta = item.metadata().ok()?;
            let is_dir = meta.is_dir();
            let name = item.file_name().to_string_lossy().into_owned();
            let is_hidden = name.starts_with('.');
            if !show_hidden && is_hidden {
                return None;
            }
            let modified_ms = meta
                .modified()
                .ok()
                .and_then(|t| t.duration_since(UNIX_EPOCH).ok())
                .map(|d| d.as_millis() as i64)
                .unwrap_or(0);
            Some(Entry {
                kind: file_kind(&path, is_dir),
                preview_url: preview_url(&path, is_dir, modified_ms),
                name,
                path: path.to_string_lossy().into_owned(),
                is_dir,
                executable: is_executable(&meta, is_dir),
                is_hidden,
                size: if is_dir { 0 } else { meta.len() },
                modified_ms,
            })
        })
        .collect())
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

        let modified_ms = meta
            .modified()
            .ok()
            .and_then(|t| t.duration_since(UNIX_EPOCH).ok())
            .map(|d| d.as_millis() as i64)
            .unwrap_or(0);

        if query.is_empty() || name.to_lowercase().contains(query) {
            out.push(Entry {
                kind: file_kind(&path, is_dir),
                preview_url: preview_url(&path, is_dir, modified_ms),
                name,
                path: path.to_string_lossy().into_owned(),
                is_dir,
                executable: is_executable(&meta, is_dir),
                is_hidden,
                size: if is_dir { 0 } else { meta.len() },
                modified_ms,
            });
        }

        if is_dir {
            let _ = search_dir_recursive(&path, show_hidden, query, out);
        }
    }

    Ok(())
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

fn to_json_array<T>(items: &[T], f: fn(&T) -> String) -> String {
    let mut out = String::with_capacity(items.len() * 200);
    out.push('[');
    for (i, item) in items.iter().enumerate() {
        if i > 0 {
            out.push(',');
        }
        out.push_str(&f(item));
    }
    out.push(']');
    out
}

fn lsblk(device: Option<&str>) -> Result<String, String> {
    let mut cmd = Command::new("lsblk");
    cmd.args([
        "-P",
        "-o",
        "NAME,PATH,TYPE,HOTPLUG,RM,LABEL,UUID,FSTYPE,SIZE,MOUNTPOINTS",
    ]);
    if let Some(d) = device {
        cmd.arg(d);
    }
    let out = cmd.output().map_err(|e| format!("lsblk: {e}"))?;
    if !out.status.success() {
        return Err(String::from_utf8_lossy(&out.stderr).trim().to_string());
    }
    Ok(String::from_utf8_lossy(&out.stdout).into_owned())
}

fn device_by_path(path: &str) -> Result<Option<Device>, String> {
    Ok(lsblk(None)?
        .lines()
        .filter_map(parse_lsblk_line)
        .find(|d| d.path == path))
}

fn udisksctl(verb: &str, device: &str) -> Result<String, String> {
    let out = Command::new("udisksctl")
        .args([verb, "-b", device])
        .output()
        .map_err(|e| format!("udisksctl: {e}"))?;
    if !out.status.success() {
        let err = String::from_utf8_lossy(&out.stderr).trim().to_string();
        let stdout = String::from_utf8_lossy(&out.stdout).trim().to_string();
        let msg = if !err.is_empty() { err } else { stdout };
        return Err(if msg.is_empty() {
            format!("{verb} failed")
        } else {
            msg
        });
    }
    Ok(String::from_utf8_lossy(&out.stdout).into_owned())
}

fn parse_udisks_path(out: &str) -> Option<String> {
    out.lines()
        .find_map(|l| l.split(" at ").nth(1))
        .map(|s| s.trim().trim_end_matches('.').to_string())
}

fn parse_lsblk_line(line: &str) -> Option<Device> {
    let mut dev = Device::default();
    let mut chars = line.chars().peekable();

    loop {
        while chars.peek().map(|c| c.is_whitespace()).unwrap_or(false) {
            chars.next();
        }
        if chars.peek().is_none() {
            break;
        }

        let key: String = chars.by_ref().take_while(|&c| c != '=').collect();
        if chars.next() != Some('"') {
            break;
        }

        let mut val = String::new();
        loop {
            match chars.next() {
                Some('"') => break,
                Some('\\') => match chars.next() {
                    Some('x') => {
                        let (h, l) = (chars.next(), chars.next());
                        if let (Some(h), Some(l)) = (h, l) {
                            if let Ok(b) = u8::from_str_radix(&format!("{h}{l}"), 16) {
                                val.push(b as char);
                                continue;
                            }
                            val.push('x');
                            val.push(h);
                            val.push(l);
                        }
                    }
                    Some(c) => val.push(c),
                    None => break,
                },
                Some(c) => val.push(c),
                None => break,
            }
        }

        match key.as_str() {
            "NAME" => dev.name = val,
            "PATH" => dev.path = val,
            "TYPE" => dev.dev_type = val,
            "HOTPLUG" => dev.hotplug = val == "1",
            "RM" => dev.removable = val == "1",
            "LABEL" => dev.label = val,
            "UUID" => dev.uuid = val,
            "FSTYPE" => dev.fstype = val,
            "SIZE" => dev.size = val,
            "MOUNTPOINTS" => {
                dev.mountpoints = val
                    .split('\n')
                    .map(str::trim)
                    .filter(|m| !m.is_empty() && *m != "[SWAP]")
                    .map(str::to_string)
                    .collect()
            }
            _ => {}
        }
    }

    if dev.path.is_empty() { None } else { Some(dev) }
}

fn show_device(d: &Device) -> bool {
    !d.path.is_empty()
        && !d.fstype.eq_ignore_ascii_case("swap")
        && ((matches!(d.dev_type.as_str(), "part" | "disk" | "crypt" | "lvm")
            && !d.fstype.is_empty())
            || d.mountpoints.iter().any(|m| is_user_mount(m)))
        && !d.mountpoints.iter().any(|m| is_system_mount(m))
}

fn device_priority(d: &Device) -> i32 {
    if d.removable || d.hotplug {
        1
    } else if !d.mountpoints.is_empty() {
        0
    } else {
        2
    }
}

fn primary_mount(d: &Device) -> Option<&str> {
    d.mountpoints
        .iter()
        .find(|m| is_user_mount(m))
        .or_else(|| d.mountpoints.first())
        .map(String::as_str)
}

fn device_title(d: &Device) -> String {
    let label = d.label.trim();
    if !label.is_empty() {
        return label.to_string();
    }
    if let Some(m) = primary_mount(d) {
        if m == "/" {
            return "Sistema".into();
        }
        if let Some(n) = Path::new(m).file_name().and_then(|v| v.to_str()) {
            if !n.is_empty() {
                return n.to_string();
            }
        }
    }
    d.name.clone()
}

fn is_user_mount(m: &str) -> bool {
    m.starts_with("/run/media/") || m.starts_with("/media/") || m.starts_with("/mnt/")
}

fn desired_label_mount_path(d: &Device) -> Option<String> {
    let label = d.label.trim();
    let mount = primary_mount(d)?;
    if label.is_empty() || !(mount.starts_with("/run/media/") || mount.starts_with("/media/")) {
        return None;
    }

    let mount_path = Path::new(mount);
    let parent = mount_path.parent()?;
    let current_name = mount_path.file_name()?.to_str()?;
    if current_name == label {
        return None;
    }

    Some(parent.join(label).to_string_lossy().into_owned())
}

fn is_system_mount(m: &str) -> bool {
    matches!(m, "/" | "/boot" | "/boot/efi")
        || m.starts_with("/home/")
        || m.starts_with("/var/")
        || m.starts_with("/usr/")
        || m.starts_with("/etc/")
        || m.starts_with("/root")
        || m.starts_with("/srv/")
}

fn entry_to_json(e: &Entry) -> String {
    format!(
        "{{\"fileName\":\"{}\",\"filePath\":\"{}\",\"fileUrl\":\"file://{}\",\
         \"fileIsDir\":{},\"fileExecutable\":{},\"fileHidden\":{},\"fileSize\":{},\"fileModified\":{},\
         \"fileKind\":\"{}\",\"filePreviewUrl\":\"{}\"}}",
        escape(&e.name),
        escape(&e.path),
        escape(&e.path),
        e.is_dir,
        e.executable,
        e.is_hidden,
        e.size,
        e.modified_ms,
        escape(&e.kind),
        escape(&e.preview_url),
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

fn is_small_svg(path: &Path) -> bool {
    let ext = path
        .extension()
        .and_then(|e| e.to_str())
        .map(|e| e.to_ascii_lowercase())
        .unwrap_or_default();
    if ext != "svg" {
        return false;
    }

    let output = Command::new("magick")
        .args(["identify", "-format", "%w %h"])
        .arg(path)
        .output();

    let Ok(output) = output else {
        return false;
    };
    if !output.status.success() {
        return false;
    }

    let text = String::from_utf8_lossy(&output.stdout);
    let mut parts = text.split_whitespace();
    let width = parts
        .next()
        .and_then(|v| v.parse::<u32>().ok())
        .unwrap_or(0);
    let height = parts
        .next()
        .and_then(|v| v.parse::<u32>().ok())
        .unwrap_or(0);
    width > 0 && height > 0 && width <= 64 && height <= 64
}

fn is_svg(path: &Path) -> bool {
    path.extension()
        .and_then(|e| e.to_str())
        .map(|e| e.eq_ignore_ascii_case("svg"))
        .unwrap_or(false)
}

fn svg_preview_density(path: &Path) -> &'static str {
    if is_small_svg(path) { "512" } else { "384" }
}

fn svg_preview_size(path: &Path) -> &'static str {
    if is_small_svg(path) {
        "768x768"
    } else {
        "512x512"
    }
}

fn svg_filter_blur(path: &Path) -> &'static str {
    if is_small_svg(path) { "0.85" } else { "0.92" }
}

fn device_to_json(d: &Device) -> String {
    let mount = primary_mount(d).unwrap_or("");
    let desired_mount = desired_label_mount_path(d).unwrap_or_default();
    let can_remount = !desired_mount.is_empty();
    let id = if !d.uuid.is_empty() {
        format!("uuid:{}", d.uuid)
    } else {
        format!("path:{}", d.path)
    };
    let subtitle = {
        let mut p = Vec::<String>::with_capacity(4);
        if !d.size.is_empty() {
            p.push(d.size.clone());
        }
        if !d.fstype.is_empty() {
            p.push(d.fstype.to_uppercase());
        }
        p.push(if d.removable || d.hotplug {
            "Removível".into()
        } else {
            "Interno".into()
        });
        if !mount.is_empty() {
            p.push(mount.to_string());
        }
        p.join(" · ")
    };
    format!(
        "{{\"id\":\"{}\",\"devicePath\":\"{}\",\"title\":\"{}\",\"subtitle\":\"{}\",\
         \"mountPath\":\"{}\",\"desiredMountPath\":\"{}\",\"mounted\":{},\"canMount\":{},\"canUnmount\":{},\"canRemount\":{},\
         \"removable\":{},\"icon\":\"{}\"}}",
        escape(&id),
        escape(&d.path),
        escape(&device_title(d)),
        escape(&subtitle),
        escape(mount),
        escape(&desired_mount),
        !mount.is_empty(),
        mount.is_empty(),
        !mount.is_empty() && is_user_mount(mount),
        can_remount,
        d.removable || d.hotplug,
        if d.removable || d.hotplug {
            "drive-removable-media"
        } else {
            "drive-harddisk"
        },
    )
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

fn file_media_type(path: &Path) -> Option<&'static str> {
    match path.extension()?.to_str()?.to_ascii_lowercase().as_str() {
        "jpg" | "jpeg" | "png" | "gif" | "bmp" | "webp" | "svg" | "avif" | "heic" | "heif"
        | "tiff" | "tif" | "tga" | "ico" | "psd" | "jxl" | "exr" | "dds" | "ppm" | "pbm"
        | "pgm" => Some("image"),
        "mp4" | "mkv" | "avi" | "mov" | "webm" | "flv" | "wmv" | "m4v" | "ts" | "3gp" | "ogv"
        | "rm" | "rmvb" | "vob" | "divx" | "f4v" | "m2ts" | "mts" | "mpg" | "mpeg" | "asf"
        | "m2v" | "h264" | "h265" | "hevc" => Some("video"),
        _ => None,
    }
}

fn is_previewable(path: &Path) -> bool {
    file_media_type(path).is_some()
}

fn cache_dir() -> Result<PathBuf, String> {
    Ok(PathBuf::from(env::var("HOME").map_err(|_| "HOME not set")?)
        .join(".cache/explorer/thumbnails"))
}

fn cache_key(path: &Path, modified_ms: i64) -> String {
    let mut h: u64 = 0xcbf29ce484222325;
    for &b in format!("v3|{}|{modified_ms}", path.to_string_lossy()).as_bytes() {
        h ^= u64::from(b);
        h = h.wrapping_mul(0x100000001b3);
    }
    format!("{h:016x}")
}

fn preview_url(path: &Path, is_dir: bool, modified_ms: i64) -> String {
    if is_dir || file_media_type(path).is_none() {
        return String::new();
    }

    if is_svg(path) {
        return format!("file://{}", path.to_string_lossy());
    }

    if let Ok(p) = cache_dir().map(|d| d.join(format!("{}.png", cache_key(path, modified_ms)))) {
        if p.exists() {
            return format!("file://{}", p.to_string_lossy());
        }
    }
    String::new()
}

fn gen_thumbnail(input: &Path, out: &Path) -> Result<(), String> {
    let tmp = out.with_extension("tmp.png");
    let ext = input
        .extension()
        .and_then(|e| e.to_str())
        .map(|e| e.to_ascii_lowercase())
        .unwrap_or_default();
    let status = match file_media_type(input) {
        Some("video") => Command::new("ffmpeg")
            .args(["-y", "-ss", "00:00:01", "-i"])
            .arg(input)
            .args([
                "-vframes",
                "1",
                "-vf",
                "scale=256:256:force_original_aspect_ratio=decrease",
            ])
            .arg(&tmp)
            .status(),
        Some("image") if ext == "svg" => Command::new("magick")
            .args([
                "-background",
                "none",
                "-density",
                svg_preview_density(input),
            ])
            .arg(input)
            .args([
                "-filter",
                "Lanczos",
                "-define",
                &format!("filter:blur={}", svg_filter_blur(input)),
                "-resize",
                svg_preview_size(input),
                "-alpha",
                "Set",
                "-strip",
            ])
            .arg(&tmp)
            .status(),
        _ => Command::new("magick")
            .arg(input)
            .args([
                "-auto-orient",
                "-strip",
                "-filter",
                "Lanczos",
                "-define",
                "filter:blur=0.92",
                "-thumbnail",
                "512x512>",
            ])
            .arg(&tmp)
            .status(),
    }
    .map_err(|e| format!("{e}"))?;

    if !status.success() {
        let _ = fs::remove_file(&tmp);
        return Err(format!("thumbnail failed: {}", input.display()));
    }
    fs::rename(&tmp, out).map_err(|e| format!("{e}"))
}

fn desktop_id(name: &str) -> String {
    let mut out = String::with_capacity(name.len());
    let mut last_dash = false;
    for c in name.chars().flat_map(|c| c.to_lowercase()) {
        if c.is_ascii_alphanumeric() {
            out.push(c);
            last_dash = false;
        } else if !last_dash {
            out.push('-');
            last_dash = true;
        }
    }
    let trimmed = out.trim_matches('-').to_string();
    if trimmed.is_empty() {
        "appimage".into()
    } else {
        trimmed
    }
}

fn desktop_escape(value: &str) -> String {
    value.replace('\\', "\\\\").replace('\n', " ")
}

fn escape(s: &str) -> String {
    let mut out = String::with_capacity(s.len() + 8);
    for c in s.chars() {
        match c {
            '\\' => out.push_str("\\\\"),
            '"' => out.push_str("\\\""),
            '\n' => out.push_str("\\n"),
            '\r' => out.push_str("\\r"),
            '\t' => out.push_str("\\t"),
            c if (c as u32) < 0x20 => out.push_str(&format!("\\u{:04x}", c as u32)),
            c => out.push(c),
        }
    }
    out
}
