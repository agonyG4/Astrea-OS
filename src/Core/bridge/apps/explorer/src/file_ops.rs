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

pub fn run(args: &[String]) -> Result<(), String> {
    match run_inner(args) {
        Ok(()) => Ok(()),
        Err(err) => {
            emit_file_op_event("ERROR", &[err.clone()]);
            Err(err)
        }
    }
}

fn run_inner(args: &[String]) -> Result<(), String> {
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

    emit_file_op_event(
        "START",
        &[
            mode.as_str().to_string(),
            destination.to_string_lossy().into_owned(),
            sources.len().to_string(),
        ],
    );

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

        run_operation(mode, source, &target, policy == ConflictPolicy::Overwrite)?;

        completed += 1;
        emit_file_op_progress(completed, sources.len(), source);
    }

    emit_file_op_event(
        "DONE",
        &[
            destination.to_string_lossy().into_owned(),
            completed.to_string(),
            sources.len().to_string(),
        ],
    );
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

fn emit_file_op_progress(done: usize, total: usize, source: &Path) {
    let percent = if total == 0 {
        100
    } else {
        done.saturating_mul(100) / total
    };
    let name = source
        .file_name()
        .and_then(|v| v.to_str())
        .unwrap_or_default()
        .to_string();
    emit_file_op_event(
        "PROGRESS",
        &[
            done.to_string(),
            total.to_string(),
            percent.to_string(),
            name,
        ],
    );
}

fn emit_file_op_event(event: &str, fields: &[String]) {
    let mut line = String::from(event);
    for field in fields {
        line.push('|');
        line.push_str(&sanitize_pipe_field(field));
    }
    println!("{line}");
    flush_stdout();
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
