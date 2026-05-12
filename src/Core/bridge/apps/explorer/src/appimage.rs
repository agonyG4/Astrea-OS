use std::env;
use std::fs;
#[cfg(unix)]
use std::os::unix::fs::PermissionsExt;
use std::path::Path;

use crate::json;

pub fn run(args: &[String]) -> Result<(), String> {
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
        json::escape(&target_path.to_string_lossy()),
        json::escape(&desktop_path.to_string_lossy())
    );
    Ok(())
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
