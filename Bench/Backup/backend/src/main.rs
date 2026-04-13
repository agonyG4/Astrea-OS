use std::cmp::Ordering;
use std::env;
use std::fs;
use std::process::Command;
use std::path::{Path, PathBuf};
use std::time::UNIX_EPOCH;

#[derive(Clone)]
struct Entry {
    name: String,
    path: String,
    is_dir: bool,
    size: u64,
    modified_ms: i64,
    kind: String,
    preview_url: String,
}

fn main() {
    if let Err(message) = run() {
        eprintln!("{message}");
        std::process::exit(1);
    }
}

fn run() -> Result<(), String> {
    let args: Vec<String> = env::args().collect();
    if args.len() < 2 {
        return Err("usage: explorer_backend list <path> <show_hidden:0|1> <sort_field> <sort_asc:0|1> <folders_first:0|1> | warm-thumbnails <path> [limit]".into());
    }

    match args[1].as_str() {
        "list" => run_list(&args[2..]),
        "warm-thumbnails" => run_warm_thumbnails(&args[2..]),
        _ if args.len() >= 5 => run_list(&args[1..]), // backward-compatible
        _ => Err("usage: explorer_backend list <path> <show_hidden:0|1> <sort_field> <sort_asc:0|1> <folders_first:0|1> | warm-thumbnails <path> [limit]".into()),
    }
}

fn run_list(args: &[String]) -> Result<(), String> {
    if args.len() < 5 {
        return Err("usage: explorer_backend list <path> <show_hidden:0|1> <sort_field> <sort_asc:0|1> <folders_first:0|1>".into());
    }

    let dir = PathBuf::from(&args[0]);
    let show_hidden = args[1] == "1";
    let sort_field = args[2].as_str();
    let sort_asc = args[3] == "1";
    let folders_first = args[4] == "1";

    let mut entries: Vec<Entry> = fs::read_dir(&dir)
        .map_err(|err| format!("failed to read {}: {err}", dir.display()))?
        .filter_map(|item| item.ok())
        .filter_map(|item| entry_from_dir_entry(item).ok())
        .filter(|entry| show_hidden || !entry.name.starts_with('.'))
        .collect();

    entries.sort_by(|a, b| compare_entries(a, b, sort_field, sort_asc, folders_first));

    print!("[");
    for (index, entry) in entries.iter().enumerate() {
        if index > 0 {
            print!(",");
        }
        print!("{}", entry_to_json(entry));
    }
    println!("]");

    Ok(())
}

fn run_warm_thumbnails(args: &[String]) -> Result<(), String> {
    if args.len() < 6 {
        return Err("usage: explorer_backend warm-thumbnails <path> <show_hidden:0|1> <sort_field> <sort_asc:0|1> <folders_first:0|1> <offset> [limit]".into());
    }

    let dir = PathBuf::from(&args[0]);
    let show_hidden = args[1] == "1";
    let sort_field = args[2].as_str();
    let sort_asc = args[3] == "1";
    let folders_first = args[4] == "1";
    let offset = args[5].parse::<usize>().unwrap_or(0);
    let limit = args.get(6).and_then(|value| value.parse::<usize>().ok()).unwrap_or(24);
    let cache_dir = thumbnail_cache_dir()?;
    fs::create_dir_all(&cache_dir)
        .map_err(|err| format!("failed to create {}: {err}", cache_dir.display()))?;

    let mut entries: Vec<Entry> = fs::read_dir(&dir)
        .map_err(|err| format!("failed to read {}: {err}", dir.display()))?
        .filter_map(|item| item.ok())
        .filter_map(|item| entry_from_dir_entry(item).ok())
        .filter(|entry| show_hidden || !entry.name.starts_with('.'))
        .collect();
    entries.sort_by(|a, b| compare_entries(a, b, sort_field, sort_asc, folders_first));

    let mut warmed = 0usize;
    for entry in entries.into_iter().skip(offset) {
        if warmed >= limit {
            break;
        }

        let path = PathBuf::from(&entry.path);
        if entry.is_dir || !is_previewable_file(&path) {
            continue;
        }

        let output_path = cache_dir.join(format!("{}.png", thumbnail_cache_key(&path, entry.modified_ms)));

        if output_path.exists() {
            warmed += 1;
            continue;
        }

        if warm_thumbnail(&path, &output_path).is_ok() {
            warmed += 1;
        }
    }

    println!("{warmed}");
    Ok(())
}

fn entry_from_dir_entry(item: fs::DirEntry) -> Result<Entry, String> {
    let path = item.path();
    let metadata = item
        .metadata()
        .map_err(|err| format!("failed to read metadata for {}: {err}", path.display()))?;
    let is_dir = metadata.is_dir();
    let size = if is_dir { 0 } else { metadata.len() };
    let modified_ms = metadata
        .modified()
        .ok()
        .and_then(|time| time.duration_since(UNIX_EPOCH).ok())
        .map(|duration| duration.as_millis() as i64)
        .unwrap_or(0);

    Ok(Entry {
        name: item.file_name().to_string_lossy().into_owned(),
        path: path.to_string_lossy().into_owned(),
        is_dir,
        size,
        modified_ms,
        kind: file_kind(&path, is_dir),
        preview_url: preview_url(&path, is_dir, modified_ms),
    })
}

fn compare_entries(a: &Entry, b: &Entry, sort_field: &str, sort_asc: bool, folders_first: bool) -> Ordering {
    if folders_first && a.is_dir != b.is_dir {
        return if a.is_dir { Ordering::Less } else { Ordering::Greater };
    }

    let ordering = match sort_field {
        "date" => a.modified_ms.cmp(&b.modified_ms),
        "size" => a.size.cmp(&b.size),
        "kind" => cmp_case_insensitive(&a.kind, &b.kind),
        "name" => cmp_case_insensitive(&a.name, &b.name),
        _ => cmp_case_insensitive(&a.name, &b.name),
    };

    let ordering = if ordering == Ordering::Equal {
        cmp_case_insensitive(&a.name, &b.name)
    } else {
        ordering
    };

    if sort_asc {
        ordering
    } else {
        ordering.reverse()
    }
}

fn cmp_case_insensitive(a: &str, b: &str) -> Ordering {
    a.to_lowercase().cmp(&b.to_lowercase())
}

fn file_kind(path: &Path, is_dir: bool) -> String {
    if is_dir {
        return "Pasta".into();
    }

    match path.extension().and_then(|ext| ext.to_str()) {
        Some(ext) if !ext.is_empty() => ext.to_uppercase(),
        _ => "Arquivo".into(),
    }
}

fn is_image_file(path: &Path) -> bool {
    path.extension()
        .and_then(|ext| ext.to_str())
        .map(|ext| matches!(ext.to_ascii_lowercase().as_str(),
            "jpg" | "jpeg" | "png" | "gif" | "bmp" | "webp" | "svg"))
        .unwrap_or(false)
}

fn is_video_file(path: &Path) -> bool {
    path.extension()
        .and_then(|ext| ext.to_str())
        .map(|ext| matches!(ext.to_ascii_lowercase().as_str(),
            "mp4" | "mkv" | "avi" | "mov" | "webm" | "flv" | "wmv" | "m4v" | "ts" | "3gp"))
        .unwrap_or(false)
}

fn is_previewable_file(path: &Path) -> bool {
    is_image_file(path) || is_video_file(path)
}

fn thumbnail_cache_dir() -> Result<PathBuf, String> {
    let home = env::var("HOME").map_err(|_| "HOME is not set".to_string())?;
    Ok(PathBuf::from(home).join(".cache/explorer/thumbnails"))
}

fn thumbnail_cache_key(path: &Path, modified_ms: i64) -> String {
    fnv1a_hex(&format!("{}|{}", path.to_string_lossy(), modified_ms))
}

fn explorer_thumbnail_path(path: &Path, modified_ms: i64) -> Result<PathBuf, String> {
    Ok(thumbnail_cache_dir()?.join(format!("{}.png", thumbnail_cache_key(path, modified_ms))))
}

fn xdg_thumbnail_path(path: &Path, size: &str) -> Result<PathBuf, String> {
    let home = env::var("HOME").map_err(|_| "HOME is not set".to_string())?;
    let digest = format!("{:x}", md5::compute(format!("file://{}", path.to_string_lossy())));
    Ok(PathBuf::from(home).join(format!(".cache/thumbnails/{size}/{digest}.png")))
}

fn warm_thumbnail(input_path: &Path, output_path: &Path) -> Result<(), String> {
    if is_video_file(input_path) {
        warm_video_thumbnail(input_path, output_path)
    } else {
        warm_image_thumbnail(input_path, output_path)
    }
}

fn warm_image_thumbnail(input_path: &Path, output_path: &Path) -> Result<(), String> {
    let temp_path = output_path.with_extension("tmp.png");
    let status = Command::new("magick")
        .arg(input_path)
        .args(["-auto-orient", "-strip", "-thumbnail", "256x256"])
        .arg(&temp_path)
        .status()
        .map_err(|err| format!("failed to run magick for {}: {err}", input_path.display()))?;

    if !status.success() {
        let _ = fs::remove_file(&temp_path);
        return Err(format!("magick failed for {}", input_path.display()));
    }

    fs::rename(&temp_path, output_path)
        .map_err(|err| format!("failed to save {}: {err}", output_path.display()))?;
    Ok(())
}

fn warm_video_thumbnail(input_path: &Path, output_path: &Path) -> Result<(), String> {
    let temp_path = output_path.with_extension("tmp.png");
    // Extract a frame at 10% into the video (or 00:00:01 as fallback via -ss)
    let status = Command::new("ffmpeg")
        .args(["-y", "-ss", "00:00:01"])
        .arg("-i")
        .arg(input_path)
        .args(["-vframes", "1", "-vf", "scale=256:256:force_original_aspect_ratio=decrease"])
        .arg(&temp_path)
        .status()
        .map_err(|err| format!("failed to run ffmpeg for {}: {err}", input_path.display()))?;

    if !status.success() {
        let _ = fs::remove_file(&temp_path);
        return Err(format!("ffmpeg failed for {}", input_path.display()));
    }

    fs::rename(&temp_path, output_path)
        .map_err(|err| format!("failed to save {}: {err}", output_path.display()))?;
    Ok(())
}

fn fnv1a_hex(value: &str) -> String {
    let mut hash: u64 = 0xcbf29ce484222325;
    for byte in value.as_bytes() {
        hash ^= u64::from(*byte);
        hash = hash.wrapping_mul(0x100000001b3);
    }
    format!("{hash:016x}")
}

fn entry_to_json(entry: &Entry) -> String {
    format!(
        "{{\"fileName\":\"{}\",\"filePath\":\"{}\",\"fileUrl\":\"{}\",\"fileIsDir\":{},\"fileSize\":{},\"fileModified\":{},\"fileKind\":\"{}\",\"filePreviewUrl\":\"{}\"}}",
        json_escape(&entry.name),
        json_escape(&entry.path),
        json_escape(&format!("file://{}", entry.path)),
        if entry.is_dir { "true" } else { "false" },
        entry.size,
        entry.modified_ms,
        json_escape(&entry.kind),
        json_escape(&entry.preview_url)
    )
}

fn preview_url(path: &Path, is_dir: bool, modified_ms: i64) -> String {
    if is_dir || !is_previewable_file(path) {
        return String::new();
    }

    if let Ok(explorer_thumb) = explorer_thumbnail_path(path, modified_ms) {
        if explorer_thumb.exists() {
            return format!("file://{}", explorer_thumb.to_string_lossy());
        }
    }

    for size in ["large", "normal"] {
        if let Ok(xdg_thumb) = xdg_thumbnail_path(path, size) {
            if xdg_thumb.exists() {
                return format!("file://{}", xdg_thumb.to_string_lossy());
            }
        }
    }

    String::new()
}

fn json_escape(value: &str) -> String {
    let mut escaped = String::with_capacity(value.len());
    for ch in value.chars() {
        match ch {
            '\\' => escaped.push_str("\\\\"),
            '"' => escaped.push_str("\\\""),
            '\n' => escaped.push_str("\\n"),
            '\r' => escaped.push_str("\\r"),
            '\t' => escaped.push_str("\\t"),
            c if c.is_control() => escaped.push_str(&format!("\\u{:04x}", c as u32)),
            c => escaped.push(c),
        }
    }
    escaped
}
