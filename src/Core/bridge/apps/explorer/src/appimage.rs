use std::env;
use std::fs;
#[cfg(unix)]
use std::os::unix::fs::PermissionsExt;
use std::path::{Path, PathBuf};
use std::process;
use std::time::{SystemTime, UNIX_EPOCH};

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
    install_appimage_binary(source_path, &target_path)?;

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
        desktop_exec_value(&target_path.to_string_lossy())
    );
    write_staged(&desktop_path, desktop.as_bytes())?;

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

fn desktop_exec_value(value: &str) -> String {
    let mut out = String::from("\"");
    for c in value.chars() {
        match c {
            '\\' => out.push_str("\\\\"),
            '"' => out.push_str("\\\""),
            '$' => out.push_str("\\$"),
            '`' => out.push_str("\\`"),
            '\n' | '\r' => out.push(' '),
            c => out.push(c),
        }
    }
    out.push('"');
    out
}

fn install_appimage_binary(source: &Path, target: &Path) -> Result<(), String> {
    if same_file(source, target) {
        make_executable(target)?;
        return Ok(());
    }

    let temp = hidden_sibling(target, "install")?;
    if let Err(err) = fs::copy(source, &temp) {
        let _ = fs::remove_file(&temp);
        return Err(format!("copy AppImage: {err}"));
    }
    if let Err(err) = make_executable(&temp) {
        let _ = fs::remove_file(&temp);
        return Err(err);
    }
    if let Err(err) = fs::rename(&temp, target) {
        let _ = fs::remove_file(&temp);
        return Err(format!("publish AppImage {}: {err}", target.display()));
    }
    Ok(())
}

fn write_staged(target: &Path, contents: &[u8]) -> Result<(), String> {
    let temp = hidden_sibling(target, "desktop")?;
    if let Err(err) = fs::write(&temp, contents) {
        let _ = fs::remove_file(&temp);
        return Err(format!("write {}: {err}", temp.display()));
    }
    if let Err(err) = fs::rename(&temp, target) {
        let _ = fs::remove_file(&temp);
        return Err(format!("publish {}: {err}", target.display()));
    }
    Ok(())
}

fn hidden_sibling(path: &Path, label: &str) -> Result<PathBuf, String> {
    let parent = path
        .parent()
        .ok_or_else(|| format!("target has no parent: {}", path.display()))?;
    let file_name = path
        .file_name()
        .and_then(|v| v.to_str())
        .unwrap_or("appimage");
    Ok(parent.join(format!(
        ".{file_name}.astrea-{label}-{}-{}",
        process::id(),
        unix_millis()
    )))
}

fn unix_millis() -> u128 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_millis())
        .unwrap_or(0)
}

fn same_file(a: &Path, b: &Path) -> bool {
    match (fs::canonicalize(a), fs::canonicalize(b)) {
        (Ok(a), Ok(b)) => a == b,
        _ => false,
    }
}

fn make_executable(path: &Path) -> Result<(), String> {
    #[cfg(unix)]
    {
        let mut perms = fs::metadata(path)
            .map_err(|e| format!("metadata {}: {e}", path.display()))?
            .permissions();
        perms.set_mode(perms.mode() | 0o111);
        fs::set_permissions(path, perms)
            .map_err(|e| format!("chmod {}: {e}", path.display()))?;
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn desktop_exec_value_quotes_paths_with_spaces() {
        assert_eq!(
            desktop_exec_value("/tmp/My App.AppImage"),
            "\"/tmp/My App.AppImage\""
        );
        assert_eq!(
            desktop_exec_value("/tmp/Plain.AppImage"),
            "\"/tmp/Plain.AppImage\""
        );
    }

    #[test]
    fn desktop_exec_value_escapes_quotes_and_backslashes() {
        assert_eq!(
            desktop_exec_value("/tmp/A \"B\".AppImage"),
            "\"/tmp/A \\\"B\\\".AppImage\""
        );
    }
}
