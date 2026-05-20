use std::fs;
use std::io::{self, Write};
use std::path::{Path, PathBuf};
use std::process;
use std::time::{SystemTime, UNIX_EPOCH};

#[derive(Clone, Copy, Eq, PartialEq)]
enum OperationMode {
    Copy,
    Move,
}

impl OperationMode {
    fn as_str(self) -> &'static str {
        match self {
            Self::Copy => "copy",
            Self::Move => "move",
        }
    }
}

#[derive(Clone, Copy, Eq, PartialEq)]
enum ConflictPolicy {
    Skip,
    Overwrite,
    Rename,
    KeepBoth,
}

#[derive(Clone, Copy, Eq, PartialEq)]
enum EventFormat {
    Legacy,
    Jsonl,
}

pub fn run(args: &[String]) -> Result<(), String> {
    let (format, normalized_args) = parse_event_format(args);
    match run_inner(&normalized_args, format) {
        Ok(()) => Ok(()),
        Err(err) => Err(err),
    }
}

fn parse_event_format(args: &[String]) -> (EventFormat, Vec<String>) {
    if args.first().map(String::as_str) == Some("--json-events") {
        return (EventFormat::Jsonl, args[1..].to_vec());
    }
    (EventFormat::Legacy, args.to_vec())
}

fn run_inner(args: &[String], format: EventFormat) -> Result<(), String> {
    if args.len() < 5 {
        return Err("usage: explorer_backend file-op <copy|move|cut> <destination> <overwrite|skip|rename|keep-both> <rename> <paths...>".into());
    }

    let mode = parse_file_op_mode(&args[0])?;
    let destination = Path::new(&args[1]);
    let policy = parse_conflict_policy(&args[2])?;
    let rename = args[3].trim();
    let sources: Vec<PathBuf> = args[4..].iter().map(PathBuf::from).collect();

    validate_rename_policy(policy, rename, sources.len())?;

    if !destination.is_dir() {
        return Err(format!(
            "destination is not a directory: {}",
            destination.display()
        ));
    }

    emit_file_op_start(format, mode, destination, sources.len());

    let mut completed = 0usize;
    for source in &sources {
        let name = source
            .file_name()
            .and_then(|v| v.to_str())
            .ok_or_else(|| format!("invalid source path: {}", source.display()))?;
        let target_name = if policy == ConflictPolicy::Rename {
            rename
        } else {
            name
        };
        let initial_target = destination.join(target_name);

        if same_path(source, &initial_target) {
            completed += 1;
            emit_file_op_progress(format, mode, completed, sources.len(), source);
            continue;
        }

        let Some(target) = resolve_conflict_target(&initial_target, policy)? else {
            completed += 1;
            emit_file_op_progress(format, mode, completed, sources.len(), source);
            continue;
        };

        if let Some(parent) = target.parent() {
            fs::create_dir_all(parent).map_err(|e| format!("create {}: {e}", parent.display()))?;
        }

        if let Err(err) = run_operation(mode, source, &target, policy == ConflictPolicy::Overwrite) {
            emit_file_op_error(
                format,
                classify_error_code(&err),
                &err,
                Some(mode),
                Some(source),
            );
            return Err(err);
        }

        completed += 1;
        emit_file_op_progress(format, mode, completed, sources.len(), source);
    }

    emit_file_op_done(format, mode, destination, completed, sources.len());
    Ok(())
}

fn parse_file_op_mode(mode: &str) -> Result<OperationMode, String> {
    match mode {
        "copy" => Ok(OperationMode::Copy),
        "move" | "cut" => Ok(OperationMode::Move),
        other => Err(format!("unsupported file operation mode: {other}")),
    }
}

fn parse_conflict_policy(policy: &str) -> Result<ConflictPolicy, String> {
    match policy {
        "skip" => Ok(ConflictPolicy::Skip),
        "overwrite" => Ok(ConflictPolicy::Overwrite),
        "rename" => Ok(ConflictPolicy::Rename),
        "keep-both" => Ok(ConflictPolicy::KeepBoth),
        other => Err(format!("unsupported conflict policy: {other}")),
    }
}

fn validate_rename_policy(
    policy: ConflictPolicy,
    rename: &str,
    source_count: usize,
) -> Result<(), String> {
    if policy == ConflictPolicy::Rename && (source_count != 1 || rename.is_empty()) {
        return Err(
            "rename conflict policy requires exactly one source and a non-empty renamed target"
                .into(),
        );
    }
    Ok(())
}

fn run_operation(
    mode: OperationMode,
    source: &Path,
    target: &Path,
    overwrite: bool,
) -> Result<(), String> {
    match mode {
        OperationMode::Copy => copy_path(source, target, overwrite),
        OperationMode::Move => move_path(source, target, overwrite),
    }
}

fn clamped_percent(done: usize, total: usize) -> usize {
    let raw = if total == 0 { 100 } else { done.saturating_mul(100) / total };
    raw.clamp(0, 100)
}

fn emit_file_op_progress(format: EventFormat, mode: OperationMode, done: usize, total: usize, source: &Path) {
    let percent = clamped_percent(done, total);
    let name = source
        .file_name()
        .and_then(|v| v.to_str())
        .unwrap_or_default()
        .to_string();
    let source_path = source.to_string_lossy().into_owned();
    match format {
        EventFormat::Legacy => emit_file_op_event(
            "PROGRESS",
            &[
                done.to_string(),
                total.to_string(),
                percent.to_string(),
                name,
            ],
        ),
        EventFormat::Jsonl => println!(
            "{}",
            json_progress_line(mode, done, total, percent, &source_path, &name)
        ),
    }
    flush_stdout();
}

fn emit_file_op_event(event: &str, fields: &[String]) {
    let mut line = String::from(event);
    for field in fields {
        line.push('|');
        line.push_str(&sanitize_pipe_field(field));
    }
    println!("{line}");
}

fn emit_file_op_start(format: EventFormat, mode: OperationMode, destination: &Path, total: usize) {
    let destination = destination.to_string_lossy().into_owned();
    match format {
        EventFormat::Legacy => emit_file_op_event("START", &[mode.as_str().to_string(), destination, total.to_string()]),
        EventFormat::Jsonl => println!(
            "{}",
            json_start_line(mode, &destination, total)
        ),
    }
    flush_stdout();
}

fn emit_file_op_done(format: EventFormat, mode: OperationMode, destination: &Path, done: usize, total: usize) {
    let destination = destination.to_string_lossy().into_owned();
    let percent = clamped_percent(done, total);
    match format {
        EventFormat::Legacy => emit_file_op_event("DONE", &[destination, done.to_string(), total.to_string()]),
        EventFormat::Jsonl => println!(
            "{}",
            json_done_line(mode, &destination, done, total, percent)
        ),
    }
    flush_stdout();
}

fn emit_file_op_error(format: EventFormat, code: &str, message: &str, mode: Option<OperationMode>, path: Option<&Path>) {
    match format {
        EventFormat::Legacy => emit_file_op_event("ERROR", &[message.to_string()]),
        EventFormat::Jsonl => {
            let mode_json = mode.map(|m| format!(",\"mode\":\"{}\"", m.as_str())).unwrap_or_default();
            let path_json = path.map(|p| format!(",\"path\":\"{}\"", escape_json(&p.to_string_lossy()))).unwrap_or_default();
            println!(
                "{}",
                json_error_line(mode_json, code, message, path_json)
            );
        }
    }
    flush_stdout();
}

fn classify_error_code(message: &str) -> &'static str {
    let m = message.to_ascii_lowercase();
    if m.contains("permission denied") {
        "permission_denied"
    } else if m.contains("not found") || m.contains("no such file") {
        "not_found"
    } else if m.contains("already exists") {
        "already_exists"
    } else if m.contains("invalid") {
        "invalid_path"
    } else {
        "operation_failed"
    }
}
fn json_start_line(mode: OperationMode, destination: &str, total: usize) -> String {
    format!(
        "{{\"event\":\"start\",\"mode\":\"{}\",\"destination\":\"{}\",\"total\":{}}}",
        mode.as_str(),
        escape_json(destination),
        total
    )
}
fn json_progress_line(mode: OperationMode, done: usize, total: usize, percent: usize, path: &str, name: &str) -> String {
    format!(
        "{{\"event\":\"progress\",\"mode\":\"{}\",\"done\":{},\"total\":{},\"percent\":{},\"path\":\"{}\",\"name\":\"{}\"}}",
        mode.as_str(),
        done,
        total,
        percent.clamp(0, 100),
        escape_json(path),
        escape_json(name)
    )
}
fn json_done_line(mode: OperationMode, destination: &str, done: usize, total: usize, percent: usize) -> String {
    format!(
        "{{\"event\":\"done\",\"mode\":\"{}\",\"destination\":\"{}\",\"done\":{},\"total\":{},\"percent\":{}}}",
        mode.as_str(),
        escape_json(destination),
        done,
        total,
        percent.clamp(0, 100)
    )
}
fn json_error_line(mode_json: String, code: &str, message: &str, path_json: String) -> String {
    format!(
        "{{\"event\":\"error\"{},\"code\":\"{}\",\"message\":\"{}\"{}}}",
        mode_json,
        escape_json(code),
        escape_json(message),
        path_json
    )
}

fn escape_json(value: &str) -> String {
    let mut out = String::with_capacity(value.len() + 8);
    for c in value.chars() {
        match c {
            '"' => out.push_str("\\\""),
            '\\' => out.push_str("\\\\"),
            '\n' => out.push_str("\\n"),
            '\r' => out.push_str("\\r"),
            '\t' => out.push_str("\\t"),
            c if c.is_control() => out.push_str(&format!("\\u{:04x}", c as u32)),
            c => out.push(c),
        }
    }
    out
}

fn flush_stdout() {
    let _ = io::stdout().flush();
}

fn sanitize_pipe_field(value: &str) -> String {
    value
        .chars()
        .map(|c| match c {
            '|' | '\n' | '\r' => ' ',
            c => c,
        })
        .collect()
}

fn resolve_conflict_target(
    target: &Path,
    policy: ConflictPolicy,
) -> Result<Option<PathBuf>, String> {
    if !target.exists() {
        return Ok(Some(target.to_path_buf()));
    }

    match policy {
        ConflictPolicy::Skip => Ok(None),
        ConflictPolicy::Overwrite => Ok(Some(target.to_path_buf())),
        ConflictPolicy::Rename => Err(format!(
            "renamed target already exists: {}",
            target.display()
        )),
        ConflictPolicy::KeepBoth => Ok(Some(unique_path(target))),
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
    SystemTime::now()
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

fn move_path(source: &Path, target: &Path, overwrite: bool) -> Result<(), String> {
    let target_existed_before_copy = target.exists();
    if overwrite && target.exists() && (source.is_dir() || target.is_dir()) {
        // Directory overwrite is intentionally non-atomic in this scoped fix. File overwrites use
        // a temporary sibling in copy_file(), but full atomic directory replacement would require
        // a larger staging/rename strategy that is outside this PR.
        remove_existing(target)?;
    }

    match fs::rename(source, target) {
        Ok(()) => Ok(()),
        Err(rename_err) => {
            if let Err(copy_err) = copy_path(source, target, overwrite) {
                if !target_existed_before_copy && target.exists() {
                    let _ = remove_existing(target);
                }
                return Err(format!(
                    "move {} to {}: rename failed ({rename_err}); copy fallback failed ({copy_err})",
                    source.display(),
                    target.display()
                ));
            }
            remove_existing(source).map_err(|remove_err| {
                format!(
                    "move partially completed: copied to target but failed to remove source: {} -> {}: {remove_err}",
                    source.display(),
                    target.display()
                )
            })
        }
    }
}

fn copy_path(source: &Path, target: &Path, overwrite: bool) -> Result<(), String> {
    let meta =
        fs::symlink_metadata(source).map_err(|e| format!("metadata {}: {e}", source.display()))?;
    if meta.file_type().is_symlink() {
        if overwrite && target.exists() {
            remove_existing(target)?;
        }
        copy_symlink(source, target)
    } else if meta.is_dir() {
        if overwrite && target.exists() {
            // Directory overwrite remains non-atomic; see the move_path() comment for why this is
            // intentionally limited to preserving regular files safely in this PR.
            remove_existing(target)?;
        }
        copy_dir_recursive(source, target)
    } else if meta.is_file() {
        copy_file(source, target, overwrite)
    } else {
        Err(format!("unsupported file type: {}", source.display()))
    }
}

fn copy_file(source: &Path, target: &Path, overwrite: bool) -> Result<(), String> {
    if overwrite && target.exists() {
        if target.is_file() || target.is_symlink() {
            return copy_file_via_temp(source, target);
        }
        remove_existing(target)?;
    }
    fs::copy(source, target)
        .map(|_| ())
        .map_err(|e| format!("copy {} to {}: {e}", source.display(), target.display()))
}

fn copy_file_via_temp(source: &Path, target: &Path) -> Result<(), String> {
    let parent = target
        .parent()
        .ok_or_else(|| format!("target has no parent: {}", target.display()))?;
    let file_name = target
        .file_name()
        .and_then(|v| v.to_str())
        .unwrap_or("file");
    let temp = parent.join(format!(
        ".{file_name}.astrea-copy-{}-{}.tmp",
        process::id(),
        unix_millis()
    ));

    if let Err(err) = fs::copy(source, &temp) {
        let _ = fs::remove_file(&temp);
        return Err(format!(
            "copy {} to temporary {}: {err}",
            source.display(),
            temp.display()
        ));
    }

    if let Err(err) = fs::rename(&temp, target) {
        let _ = fs::remove_file(&temp);
        return Err(format!(
            "replace {} with temporary {}: {err}",
            target.display(),
            temp.display()
        ));
    }
    Ok(())
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
        copy_file(&link, target, false)
    }
}

fn copy_dir_recursive(source: &Path, target: &Path) -> Result<(), String> {
    if is_self_or_descendant_target(source, target) {
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
            // Recursive directory conflict handling remains non-atomic for nested entries.
            remove_existing(&child_target)?;
        }
        copy_path(&child_source, &child_target, false)?;
    }
    Ok(())
}

fn is_self_or_descendant_target(source: &Path, target: &Path) -> bool {
    if target.starts_with(source) {
        return true;
    }

    let Ok(source_canon) = fs::canonicalize(source) else {
        return false;
    };

    if let Ok(target_canon) = fs::canonicalize(target) {
        return target_canon == source_canon || target_canon.starts_with(&source_canon);
    }

    let Some(parent) = target.parent() else {
        return false;
    };
    let Ok(parent_canon) = fs::canonicalize(parent) else {
        return false;
    };
    let target_canon = match target.file_name() {
        Some(name) => parent_canon.join(name),
        None => parent_canon,
    };

    target_canon == source_canon || target_canon.starts_with(&source_canon)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn json_lines_escape_special_names() {
        let name = "a|b \"ç\" 😀\nline.txt";
        let line = json_progress_line(OperationMode::Copy, 1, 3, 33, "/tmp/a|b\nx", name);
        assert!(line.contains("\"event\":\"progress\""));
        assert!(line.contains("\\n"));
        assert!(line.contains("\\\"ç\\\""));
        assert!(line.contains("😀"));
    }

    #[test]
    fn percent_is_clamped() {
        assert_eq!(clamped_percent(300, 1), 100);
        let line = json_done_line(OperationMode::Move, "/tmp", 3, 2, 150);
        assert!(line.contains("\"percent\":100"));
    }

    #[test]
    fn error_event_shape_contains_code_and_message() {
        let line = json_error_line(",\"mode\":\"copy\"".to_string(), "permission_denied", "denied", ",\"path\":\"/tmp/x\"".to_string());
        assert!(line.contains("\"event\":\"error\""));
        assert!(line.contains("\"code\":\"permission_denied\""));
        assert!(line.contains("\"message\":\"denied\""));
        assert!(line.contains("\"path\":\"/tmp/x\""));
    }

    #[test]
    fn classify_error_code_maps_common_errors() {
        assert_eq!(classify_error_code("Permission denied: /tmp/a"), "permission_denied");
        assert_eq!(classify_error_code("No such file or directory"), "not_found");
        assert_eq!(classify_error_code("already exists"), "already_exists");
        assert_eq!(classify_error_code("invalid source path"), "invalid_path");
        assert_eq!(classify_error_code("something else"), "operation_failed");
    }
}
