use std::fs;
use std::io::{self, Read, Write};
use std::path::{Component, Path, PathBuf};
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

struct FileOpRequest {
    mode: OperationMode,
    destination: PathBuf,
    policy: ConflictPolicy,
    rename: String,
    sources: Vec<PathBuf>,
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
    let request = parse_file_op_request(args)?;
    let mode = request.mode;
    let destination = request.destination.as_path();
    let policy = request.policy;
    let rename = request.rename.as_str();
    let sources = request.sources;

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

        if let Err(err) = run_operation_with_progress(
            format,
            mode,
            source,
            &target,
            policy == ConflictPolicy::Overwrite,
            completed,
            sources.len(),
        ) {
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

fn file_op_usage() -> &'static str {
    "usage: explorer_backend file-op <copy|move|cut> <destination> <merge|overwrite|skip|rename|keep-both> [--rename <name>] <paths...>"
}

fn parse_file_op_request(args: &[String]) -> Result<FileOpRequest, String> {
    if args.len() < 4 {
        return Err(file_op_usage().into());
    }

    let mode = parse_file_op_mode(&args[0])?;
    let destination = PathBuf::from(&args[1]);
    let policy = parse_conflict_policy(&args[2])?;
    let mut rename = String::new();
    let mut source_start = 3usize;

    if args[3] == "--rename" {
        if args.len() < 6 {
            return Err(file_op_usage().into());
        }
        rename = args[4].trim().to_string();
        source_start = 5;
    } else if policy == ConflictPolicy::Rename {
        if args.len() < 5 {
            return Err(file_op_usage().into());
        }
        rename = args[3].trim().to_string();
        source_start = 4;
    } else if args[3].is_empty() && args.len() >= 5 {
        // Backward compatibility with the legacy positional rename placeholder.
        source_start = 4;
    }

    let sources: Vec<PathBuf> = args[source_start..].iter().map(PathBuf::from).collect();
    if sources.is_empty() {
        return Err(file_op_usage().into());
    }

    Ok(FileOpRequest {
        mode,
        destination,
        policy,
        rename,
        sources,
    })
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
        "merge" => Ok(ConflictPolicy::Overwrite), // merge directories; replaces files only when collisions occur
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
    if policy == ConflictPolicy::Rename && !is_safe_child_name(rename) {
        return Err(format!("invalid renamed target: {rename}"));
    }
    Ok(())
}

fn is_safe_child_name(name: &str) -> bool {
    let mut components = Path::new(name).components();
    matches!(components.next(), Some(Component::Normal(_))) && components.next().is_none()
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

fn run_operation_with_progress(
    format: EventFormat,
    mode: OperationMode,
    source: &Path,
    target: &Path,
    overwrite: bool,
    completed: usize,
    total: usize,
) -> Result<(), String> {
    if mode == OperationMode::Copy {
        if let Ok(meta) = fs::symlink_metadata(source) {
            if meta.is_file() {
                return copy_regular_file_with_progress(
                    source,
                    target,
                    overwrite,
                    format,
                    mode,
                    completed,
                    total,
                );
            }
        }
    }
    run_operation(mode, source, target, overwrite)
}

fn clamped_percent(done: usize, total: usize) -> usize {
    let raw = if total == 0 { 100 } else { done.saturating_mul(100) / total };
    raw.clamp(0, 100)
}

fn emit_file_op_progress(format: EventFormat, mode: OperationMode, done: usize, total: usize, source: &Path) {
    let percent = clamped_percent(done, total);
    emit_file_op_progress_percent(format, mode, done, total, percent, source)
}

fn emit_file_op_progress_percent(
    format: EventFormat,
    mode: OperationMode,
    done: usize,
    total: usize,
    percent: usize,
    source: &Path,
) {
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
    if !path_exists_or_symlink(target) {
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
    if !path_exists_or_symlink(path) {
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
        if !path_exists_or_symlink(&candidate) {
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

fn path_exists_or_symlink(path: &Path) -> bool {
    path.exists() || path.is_symlink()
}

fn remove_existing(path: &Path) -> Result<(), String> {
    if path.is_dir() && !path.is_symlink() {
        fs::remove_dir_all(path).map_err(|e| format!("remove {}: {e}", path.display()))
    } else {
        fs::remove_file(path).map_err(|e| format!("remove {}: {e}", path.display()))
    }
}

fn remove_existing_if_present(path: &Path) -> Result<(), String> {
    if path.exists() || path.is_symlink() {
        remove_existing(path)
    } else {
        Ok(())
    }
}

fn hidden_sibling(path: &Path, label: &str) -> Result<PathBuf, String> {
    let parent = path
        .parent()
        .ok_or_else(|| format!("target has no parent: {}", path.display()))?;
    let file_name = path
        .file_name()
        .and_then(|v| v.to_str())
        .unwrap_or("item");
    Ok(unique_path(&parent.join(format!(
        ".{file_name}.astrea-{label}-{}-{}",
        process::id(),
        unix_millis()
    ))))
}

fn move_existing_aside(target: &Path) -> Result<Option<PathBuf>, String> {
    if !target.exists() && !target.is_symlink() {
        return Ok(None);
    }
    let backup = hidden_sibling(target, "overwrite-backup")?;
    fs::rename(target, &backup).map_err(|e| {
        format!(
            "move existing {} to backup {}: {e}",
            target.display(),
            backup.display()
        )
    })?;
    Ok(Some(backup))
}

fn restore_backup(target: &Path, backup: Option<&Path>) {
    if let Some(backup_path) = backup {
        let _ = remove_existing_if_present(target);
        let _ = fs::rename(backup_path, target);
    }
}

fn discard_backup(backup: Option<PathBuf>) -> Result<(), String> {
    if let Some(backup_path) = backup {
        remove_existing_if_present(&backup_path)?;
    }
    Ok(())
}

fn publish_staged_path(staged: &Path, target: &Path) -> Result<(), String> {
    let backup = move_existing_aside(target)?;
    match fs::rename(staged, target) {
        Ok(()) => discard_backup(backup),
        Err(err) => {
            restore_backup(target, backup.as_deref());
            let _ = remove_existing_if_present(staged);
            Err(format!(
                "publish temporary {} to {}: {err}",
                staged.display(),
                target.display()
            ))
        }
    }
}

fn move_path(source: &Path, target: &Path, overwrite: bool) -> Result<(), String> {
    if source.is_dir() && !source.is_symlink() && is_self_or_descendant_target(source, target) {
        return Err(format!(
            "refusing to move directory into itself: {} -> {}",
            source.display(),
            target.display()
        ));
    }

    if overwrite && source.is_dir() && !source.is_symlink() && target.is_dir() && !target.is_symlink() {
        return move_dir_recursive_overwrite(source, target);
    }

    let backup = if overwrite {
        move_existing_aside(target)?
    } else {
        None
    };

    match fs::rename(source, target) {
        Ok(()) => discard_backup(backup),
        Err(rename_err) => {
            if let Err(copy_err) = copy_path(source, target, false) {
                restore_backup(target, backup.as_deref());
                return Err(format!(
                    "move {} to {}: rename failed ({rename_err}); copy fallback failed ({copy_err})",
                    source.display(),
                    target.display()
                ));
            }
            if let Err(remove_err) = remove_existing(source) {
                let _ = remove_existing_if_present(target);
                restore_backup(target, backup.as_deref());
                return Err(format!(
                    "move failed after copy because source could not be removed: {} -> {}: {remove_err}",
                    source.display(),
                    target.display()
                ));
            }
            discard_backup(backup)
        }
    }
}

fn copy_path(source: &Path, target: &Path, overwrite: bool) -> Result<(), String> {
    let meta =
        fs::symlink_metadata(source).map_err(|e| format!("metadata {}: {e}", source.display()))?;
    if overwrite && meta.is_dir() && target.is_dir() && !target.is_symlink() {
        return copy_dir_recursive_overwrite(source, target);
    }
    if overwrite && (target.exists() || target.is_symlink()) {
        let staged = hidden_sibling(target, "copy")?;
        if let Err(err) = copy_path(source, &staged, false) {
            let _ = remove_existing_if_present(&staged);
            return Err(err);
        }
        return publish_staged_path(&staged, target);
    }
    if meta.file_type().is_symlink() {
        copy_symlink(source, target)
    } else if meta.is_dir() {
        copy_dir_recursive(source, target)
    } else if meta.is_file() {
        copy_file(source, target, overwrite)
    } else {
        Err(format!("unsupported file type: {}", source.display()))
    }
}

fn copy_file(source: &Path, target: &Path, overwrite: bool) -> Result<(), String> {
    if path_exists_or_symlink(target) {
        if !overwrite {
            return Err(format!("target already exists: {}", target.display()));
        }
        if target.is_file() || target.is_symlink() {
            return copy_file_via_temp(source, target);
        }
        remove_existing(target)?;
    }
    fs::copy(source, target)
        .map(|_| ())
        .map_err(|e| format!("copy {} to {}: {e}", source.display(), target.display()))?;
    preserve_file_times(source, target)?;
    Ok(())
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
    if let Err(err) = preserve_file_times(source, &temp) {
        let _ = fs::remove_file(&temp);
        return Err(err);
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

fn copy_regular_file_with_progress(
    source: &Path,
    target: &Path,
    overwrite: bool,
    format: EventFormat,
    mode: OperationMode,
    completed: usize,
    total: usize,
) -> Result<(), String> {
    if path_exists_or_symlink(target) && !overwrite {
        return Err(format!("target already exists: {}", target.display()));
    }
    let staged = hidden_sibling(target, "copy")?;
    if let Err(err) = copy_file_stream_with_progress(
        source,
        &staged,
        format,
        mode,
        completed,
        total,
    ) {
        let _ = remove_existing_if_present(&staged);
        return Err(err);
    }
    if path_exists_or_symlink(target) {
        publish_staged_path(&staged, target)
    } else {
        match fs::rename(&staged, target) {
            Ok(()) => Ok(()),
            Err(err) => {
                let _ = remove_existing_if_present(&staged);
                Err(format!(
                    "publish temporary {} to {}: {err}",
                    staged.display(),
                    target.display()
                ))
            }
        }
    }
}

fn copy_file_stream_with_progress(
    source: &Path,
    target: &Path,
    format: EventFormat,
    mode: OperationMode,
    completed: usize,
    total: usize,
) -> Result<(), String> {
    let meta =
        fs::metadata(source).map_err(|e| format!("metadata {}: {e}", source.display()))?;
    let total_bytes = meta.len();
    let mut input = fs::File::open(source)
        .map_err(|e| format!("open {}: {e}", source.display()))?;
    let mut output = fs::File::create(target)
        .map_err(|e| format!("create {}: {e}", target.display()))?;
    let _ = output.set_permissions(meta.permissions());
    let mut copied = 0u64;
    let mut last_percent = 0usize;
    let mut buffer = vec![0u8; 1024 * 1024];

    loop {
        let read = input
            .read(&mut buffer)
            .map_err(|e| format!("read {}: {e}", source.display()))?;
        if read == 0 {
            break;
        }
        output
            .write_all(&buffer[..read])
            .map_err(|e| format!("write {}: {e}", target.display()))?;
        copied = copied.saturating_add(read as u64);
        let percent = if total_bytes == 0 {
            99
        } else {
            ((copied.saturating_mul(100) / total_bytes).min(99)) as usize
        };
        if percent > last_percent {
            emit_file_op_progress_percent(format, mode, completed, total, percent, source);
            last_percent = percent;
        }
    }
    output
        .sync_all()
        .map_err(|e| format!("flush {}: {e}", target.display()))?;
    preserve_file_times(source, target)?;
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

#[cfg(unix)]
fn preserve_file_times(source: &Path, target: &Path) -> Result<(), String> {
    use std::ffi::CString;
    use std::os::unix::ffi::OsStrExt;
    use std::os::unix::fs::MetadataExt;

    #[repr(C)]
    struct Timespec {
        tv_sec: i64,
        tv_nsec: i64,
    }

    unsafe extern "C" {
        fn utimensat(
            dirfd: i32,
            pathname: *const std::os::raw::c_char,
            times: *const Timespec,
            flags: i32,
        ) -> i32;
    }

    const AT_FDCWD: i32 = -100;

    let meta =
        fs::metadata(source).map_err(|e| format!("metadata {}: {e}", source.display()))?;
    let path = CString::new(target.as_os_str().as_bytes())
        .map_err(|_| format!("target path contains NUL: {}", target.display()))?;
    let times = [
        Timespec {
            tv_sec: meta.atime(),
            tv_nsec: meta.atime_nsec(),
        },
        Timespec {
            tv_sec: meta.mtime(),
            tv_nsec: meta.mtime_nsec(),
        },
    ];
    let rc = unsafe { utimensat(AT_FDCWD, path.as_ptr(), times.as_ptr(), 0) };
    if rc == 0 {
        Ok(())
    } else {
        Err(format!(
            "preserve timestamps {} -> {}: {}",
            source.display(),
            target.display(),
            io::Error::last_os_error()
        ))
    }
}

#[cfg(not(unix))]
fn preserve_file_times(_source: &Path, _target: &Path) -> Result<(), String> {
    Ok(())
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
        if path_exists_or_symlink(&child_target) {
            // Recursive directory conflict handling remains non-atomic for nested entries.
            remove_existing(&child_target)?;
        }
        copy_path(&child_source, &child_target, false)?;
    }
    Ok(())
}

fn copy_dir_recursive_overwrite(source: &Path, target: &Path) -> Result<(), String> {
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
        copy_path(&child_source, &child_target, true)?;
    }
    Ok(())
}

fn move_dir_recursive_overwrite(source: &Path, target: &Path) -> Result<(), String> {
    if is_self_or_descendant_target(source, target) {
        return Err(format!(
            "refusing to move directory into itself: {} -> {}",
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
        move_path(&child_source, &child_target, true)?;
    }

    fs::remove_dir(source).map_err(|e| format!("remove merged source {}: {e}", source.display()))
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
    use std::fs;

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

    #[test]
    fn rename_policy_rejects_paths_outside_destination() {
        assert!(validate_rename_policy(ConflictPolicy::Rename, "../escape.txt", 1).is_err());
        assert!(validate_rename_policy(ConflictPolicy::Rename, "/tmp/escape.txt", 1).is_err());
        assert!(validate_rename_policy(ConflictPolicy::Rename, "safe.txt", 1).is_ok());
    }

    #[test]
    fn non_rename_policy_accepts_paths_without_placeholder() {
        let root = std::env::temp_dir().join(format!(
            "astrea-file-op-multi-source-new-cli-test-{}",
            unix_millis()
        ));
        let source_dir = root.join("src");
        let dest = root.join("dest");
        fs::create_dir_all(&source_dir).unwrap();
        fs::create_dir_all(&dest).unwrap();
        let first = source_dir.join("first.txt");
        let second = source_dir.join("second.txt");
        fs::write(&first, "first").unwrap();
        fs::write(&second, "second").unwrap();

        run_inner(
            &vec![
                "move".into(),
                dest.to_string_lossy().into_owned(),
                "keep-both".into(),
                first.to_string_lossy().into_owned(),
                second.to_string_lossy().into_owned(),
            ],
            EventFormat::Jsonl,
        )
        .unwrap();

        assert!(!first.exists());
        assert!(!second.exists());
        assert_eq!(fs::read_to_string(dest.join("first.txt")).unwrap(), "first");
        assert_eq!(fs::read_to_string(dest.join("second.txt")).unwrap(), "second");
        let _ = fs::remove_dir_all(root);
    }

    #[test]
    fn non_rename_policy_keeps_legacy_empty_placeholder_compatibility() {
        let args = vec![
            "copy".into(),
            "/tmp".into(),
            "keep-both".into(),
            "".into(),
            "/tmp/a.txt".into(),
            "/tmp/b.txt".into(),
        ];
        let request = parse_file_op_request(&args).unwrap();
        assert_eq!(request.sources.len(), 2);
        assert_eq!(request.rename, "");
        assert_eq!(request.sources[0], PathBuf::from("/tmp/a.txt"));
        assert_eq!(request.sources[1], PathBuf::from("/tmp/b.txt"));
    }

    #[test]
    fn rename_policy_accepts_named_flag() {
        let args = vec![
            "copy".into(),
            "/tmp".into(),
            "rename".into(),
            "--rename".into(),
            "safe.txt".into(),
            "/tmp/source.txt".into(),
        ];
        let request = parse_file_op_request(&args).unwrap();
        assert_eq!(request.rename, "safe.txt");
        assert_eq!(request.sources, vec![PathBuf::from("/tmp/source.txt")]);
    }

    #[cfg(unix)]
    #[test]
    fn keep_both_does_not_follow_broken_destination_symlink() {
        use std::os::unix::fs::symlink;

        let root = std::env::temp_dir().join(format!(
            "astrea-file-op-broken-link-test-{}",
            unix_millis()
        ));
        let source_dir = root.join("src");
        let dest = root.join("dest");
        fs::create_dir_all(&source_dir).unwrap();
        fs::create_dir_all(&dest).unwrap();
        let source = source_dir.join("victim.txt");
        fs::write(&source, "new").unwrap();
        let outside = root.join("outside.txt");
        symlink(&outside, dest.join("victim.txt")).unwrap();

        run_inner(
            &vec![
                "copy".into(),
                dest.to_string_lossy().into_owned(),
                "keep-both".into(),
                "".into(),
                source.to_string_lossy().into_owned(),
            ],
            EventFormat::Jsonl,
        )
        .unwrap();

        assert!(!outside.exists());
        assert!(dest.join("victim.txt").is_symlink());
        assert_eq!(fs::read_to_string(dest.join("victim 2.txt")).unwrap(), "new");
        let _ = fs::remove_dir_all(root);
    }

    #[cfg(unix)]
    #[test]
    fn skip_policy_treats_broken_destination_symlink_as_existing() {
        use std::os::unix::fs::symlink;

        let root = std::env::temp_dir().join(format!(
            "astrea-file-op-skip-broken-link-test-{}",
            unix_millis()
        ));
        let source_dir = root.join("src");
        let dest = root.join("dest");
        fs::create_dir_all(&source_dir).unwrap();
        fs::create_dir_all(&dest).unwrap();
        let source = source_dir.join("victim.txt");
        fs::write(&source, "new").unwrap();
        let outside = root.join("outside.txt");
        symlink(&outside, dest.join("victim.txt")).unwrap();

        run_inner(
            &vec![
                "copy".into(),
                dest.to_string_lossy().into_owned(),
                "skip".into(),
                "".into(),
                source.to_string_lossy().into_owned(),
            ],
            EventFormat::Jsonl,
        )
        .unwrap();

        assert!(!outside.exists());
        assert!(dest.join("victim.txt").is_symlink());
        assert!(!dest.join("victim 2.txt").exists());
        let _ = fs::remove_dir_all(root);
    }

    #[test]
    fn copy_preserves_source_modified_time() {
        let root = std::env::temp_dir().join(format!(
            "astrea-file-op-mtime-test-{}",
            unix_millis()
        ));
        let source_dir = root.join("src");
        let dest = root.join("dest");
        fs::create_dir_all(&source_dir).unwrap();
        fs::create_dir_all(&dest).unwrap();
        let source = source_dir.join("file.txt");
        fs::write(&source, "new").unwrap();
        let _ = std::process::Command::new("touch")
            .args(["-d", "2020-01-02 03:04:05"])
            .arg(&source)
            .status();

        copy_path(&source, &dest.join("file.txt"), false).unwrap();

        let src_modified = fs::metadata(&source).unwrap().modified().unwrap();
        let dst_modified = fs::metadata(dest.join("file.txt")).unwrap().modified().unwrap();
        assert_eq!(src_modified, dst_modified);
        let _ = fs::remove_dir_all(root);
    }

    #[test]
    fn failed_move_overwrite_restores_existing_directory() {
        let root = std::env::temp_dir().join(format!(
            "astrea-file-op-test-{}",
            unix_millis()
        ));
        let source = root.join("source");
        let target = source.join("child/source");
        fs::create_dir_all(&target).unwrap();
        fs::write(target.join("keep.txt"), "old").unwrap();

        let result = move_path(&source, &target, true);

        assert!(result.is_err());
        assert_eq!(fs::read_to_string(target.join("keep.txt")).unwrap(), "old");
        let _ = fs::remove_dir_all(root);
    }

    #[test]
    fn copy_overwrite_existing_directory_merges_contents() {
        let root = std::env::temp_dir().join(format!(
            "astrea-file-op-copy-merge-test-{}",
            unix_millis()
        ));
        let source = root.join("source");
        let target = root.join("target");
        fs::create_dir_all(source.join("nested")).unwrap();
        fs::create_dir_all(target.join("nested")).unwrap();
        fs::write(source.join("same.txt"), "new").unwrap();
        fs::write(source.join("nested/same.txt"), "nested-new").unwrap();
        fs::write(source.join("only-source.txt"), "source").unwrap();
        fs::write(target.join("same.txt"), "old").unwrap();
        fs::write(target.join("nested/same.txt"), "nested-old").unwrap();
        fs::write(target.join("only-target.txt"), "target").unwrap();
        fs::write(target.join("nested/only-target.txt"), "nested-target").unwrap();

        copy_path(&source, &target, true).unwrap();

        assert_eq!(fs::read_to_string(target.join("same.txt")).unwrap(), "new");
        assert_eq!(
            fs::read_to_string(target.join("nested/same.txt")).unwrap(),
            "nested-new"
        );
        assert_eq!(
            fs::read_to_string(target.join("only-source.txt")).unwrap(),
            "source"
        );
        assert_eq!(
            fs::read_to_string(target.join("only-target.txt")).unwrap(),
            "target"
        );
        assert_eq!(
            fs::read_to_string(target.join("nested/only-target.txt")).unwrap(),
            "nested-target"
        );
        let _ = fs::remove_dir_all(root);
    }

    #[test]
    fn move_overwrite_existing_directory_merges_contents() {
        let root = std::env::temp_dir().join(format!(
            "astrea-file-op-move-merge-test-{}",
            unix_millis()
        ));
        let source = root.join("source");
        let target = root.join("target");
        fs::create_dir_all(source.join("nested")).unwrap();
        fs::create_dir_all(target.join("nested")).unwrap();
        fs::write(source.join("same.txt"), "new").unwrap();
        fs::write(source.join("nested/same.txt"), "nested-new").unwrap();
        fs::write(source.join("only-source.txt"), "source").unwrap();
        fs::write(target.join("same.txt"), "old").unwrap();
        fs::write(target.join("nested/same.txt"), "nested-old").unwrap();
        fs::write(target.join("only-target.txt"), "target").unwrap();
        fs::write(target.join("nested/only-target.txt"), "nested-target").unwrap();

        move_path(&source, &target, true).unwrap();

        assert!(!source.exists());
        assert_eq!(fs::read_to_string(target.join("same.txt")).unwrap(), "new");
        assert_eq!(
            fs::read_to_string(target.join("nested/same.txt")).unwrap(),
            "nested-new"
        );
        assert_eq!(
            fs::read_to_string(target.join("only-source.txt")).unwrap(),
            "source"
        );
        assert_eq!(
            fs::read_to_string(target.join("only-target.txt")).unwrap(),
            "target"
        );
        assert_eq!(
            fs::read_to_string(target.join("nested/only-target.txt")).unwrap(),
            "nested-target"
        );
        let _ = fs::remove_dir_all(root);
    }
}
