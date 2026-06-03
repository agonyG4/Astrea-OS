use rayon::prelude::*;
use std::env;
use std::fs;
use std::path::{Path, PathBuf};
use std::process::Command;
use std::sync::OnceLock;

use crate::entries;
use crate::json;

const WARM_THUMBNAIL_THREADS: usize = 4;

static CACHE_DIR: OnceLock<Result<PathBuf, String>> = OnceLock::new();

pub fn run_warm(args: &[String]) -> Result<(), String> {
    let (dir, show_hidden, sort_field, sort_asc, folders_first) = entries::parse_list_args(args)?;
    let offset = args.get(5).and_then(|v| v.parse().ok()).unwrap_or(0usize);
    let limit = args.get(6).and_then(|v| v.parse().ok()).unwrap_or(24usize);

    if entries::path_uses_remote_listing(dir) {
        println!("0");
        return Ok(());
    }

    let cache = cache_dir()?;
    fs::create_dir_all(&cache).map_err(|e| format!("cache dir: {e}"))?;

    let entries =
        entries::read_sorted_entries(dir, show_hidden, sort_field, sort_asc, folders_first)?;
    let targets: Vec<_> = entries
        .into_iter()
        .skip(offset)
        .filter(|e| {
            let path = Path::new(&e.path);
            !e.is_dir && is_previewable(path) && !is_svg(path)
        })
        .take(limit)
        .collect();

    let pool = rayon::ThreadPoolBuilder::new()
        .num_threads(WARM_THUMBNAIL_THREADS)
        .build()
        .map_err(|e| format!("thumbnail worker pool: {e}"))?;
    let warmed = pool.install(|| {
        targets
            .into_par_iter()
            .filter(|e| {
                let p = PathBuf::from(&e.path);
                let out = cache.join(format!("{}.png", cache_key(&p, e.modified_ms)));
                out.exists() || gen_thumbnail(&p, &out).is_ok()
            })
            .count()
    });

    println!("{warmed}");
    Ok(())
}

pub fn preview_url(path: &Path, is_dir: bool, modified_ms: i64) -> String {
    let Some(media_type) = file_media_type(path) else {
        return String::new();
    };

    if is_dir {
        return String::new();
    }

    if is_svg(path) {
        return json::file_url(path);
    }

    if let Ok(p) = cache_dir().map(|d| d.join(format!("{}.png", cache_key(path, modified_ms)))) {
        if p.exists() {
            return json::file_url(&p);
        }
    }

    if media_type == "image" {
        return json::file_url(path);
    }

    String::new()
}

pub fn is_previewable(path: &Path) -> bool {
    file_media_type(path).is_some()
}

pub fn is_svg(path: &Path) -> bool {
    path.extension()
        .and_then(|e| e.to_str())
        .map(|e| e.eq_ignore_ascii_case("svg"))
        .unwrap_or(false)
}

fn cache_dir() -> Result<PathBuf, String> {
    CACHE_DIR
        .get_or_init(|| {
            Ok(PathBuf::from(env::var("HOME").map_err(|_| "HOME not set")?)
                .join(".cache/explorer/thumbnails"))
        })
        .clone()
}

fn cache_key(path: &Path, modified_ms: i64) -> String {
    let mut h: u64 = 0xcbf29ce484222325;
    for &b in format!("v3|{}|{modified_ms}", path.to_string_lossy()).as_bytes() {
        h ^= u64::from(b);
        h = h.wrapping_mul(0x100000001b3);
    }
    format!("{h:016x}")
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
        Some("image") if ext == "svg" => {
            let svg_params = svg_preview_params(input);
            Command::new("magick")
                .args(["-background", "none", "-density", svg_params.density])
                .arg(input)
                .args([
                    "-filter",
                    "Lanczos",
                    "-define",
                    &format!("filter:blur={}", svg_params.filter_blur),
                    "-resize",
                    svg_params.size,
                    "-alpha",
                    "Set",
                    "-strip",
                ])
                .arg(&tmp)
                .status()
        }
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

struct SvgPreviewParams {
    density: &'static str,
    size: &'static str,
    filter_blur: &'static str,
}

fn svg_preview_params(path: &Path) -> SvgPreviewParams {
    if is_small_svg(path) {
        SvgPreviewParams {
            density: "512",
            size: "768x768",
            filter_blur: "0.85",
        }
    } else {
        SvgPreviewParams {
            density: "384",
            size: "512x512",
            filter_blur: "0.92",
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;

    #[test]
    fn preview_url_percent_encodes_local_image_paths() {
        let root =
            std::env::temp_dir().join(format!("astrea-preview-url-test-{}", std::process::id()));
        let _ = fs::remove_dir_all(&root);
        fs::create_dir_all(&root).unwrap();
        let path = root.join("img # one.png");
        fs::write(&path, "x").unwrap();

        let url = preview_url(&path, false, 1);

        assert!(url.ends_with("img%20%23%20one.png"));
        assert!(!url.ends_with("img # one.png"));
        let _ = fs::remove_dir_all(root);
    }
}
