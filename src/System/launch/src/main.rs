use astrea_launch::{
    LaunchRequest, config_path, default_config_text, ensure_default_config, history_path,
    launchd_socket_path, load_config, read_history, run_launch_via_daemon, serve_launchd,
};

fn main() {
    let mut args = std::env::args().skip(1);
    let result = match args.next().as_deref() {
        Some("--desktop") => args
            .next()
            .map(|id| run_launch_via_daemon(LaunchRequest::Desktop { id }))
            .unwrap_or_else(|| Err("--desktop requires an id".into())),
        Some("--command") => args
            .next()
            .map(|command| run_launch_via_daemon(LaunchRequest::Command { command }))
            .unwrap_or_else(|| Err("--command requires a command string".into())),
        Some("--file") => args
            .next()
            .map(|path| run_launch_via_daemon(LaunchRequest::File { path }))
            .unwrap_or_else(|| Err("--file requires a path".into())),
        Some("--url") => args
            .next()
            .map(|url| run_launch_via_daemon(LaunchRequest::Url { url }))
            .unwrap_or_else(|| Err("--url requires a URL".into())),
        Some("--steam") => args
            .next()
            .map(|uri| run_launch_via_daemon(LaunchRequest::Steam { uri }))
            .unwrap_or_else(|| Err("--steam requires a Steam URI".into())),
        Some("daemon") | Some("launchd") => serve_launchd().map(|_| empty_record()),
        Some("doctor") => {
            doctor();
            Ok(empty_record())
        }
        Some("history") => {
            for line in read_history(40) {
                println!("{line}");
            }
            Ok(empty_record())
        }
        _ => {
            usage();
            Err("invalid command".into())
        }
    };

    match result {
        Ok(record) if !record.kind.is_empty() => {
            println!(
                "{}",
                serde_json::to_string(&record).unwrap_or_else(|_| "{\"status\":\"ok\"}".into())
            );
        }
        Ok(_) => {}
        Err(err) => {
            eprintln!("astrea-launch: {err}");
            std::process::exit(1);
        }
    }
}

fn doctor() {
    let (config, warning) = load_config();
    println!("config: {}", config_path().display());
    if config_path().exists() {
        println!("config_status: present");
    } else {
        println!("config_status: missing, default follows");
        print!("{}", default_config_text());
        if let Err(err) = ensure_default_config() {
            println!("config_write: {err}");
        }
    }
    if let Some(warning) = warning {
        println!("config_warning: {warning}");
    }
    println!("history: {}", history_path().display());
    println!("launchd_socket: {}", launchd_socket_path().display());
    println!(
        "launchd_socket_status: {}",
        if launchd_socket_path().exists() {
            "present"
        } else {
            "missing"
        }
    );
    println!("latency_enabled: {}", config.latency.enabled);
    for socket in &config.latency.socket_paths {
        println!(
            "latency_socket: {} {}",
            socket,
            if std::path::Path::new(socket).exists() {
                "present"
            } else {
                "missing"
            }
        );
    }
    println!("rules: {}", config.rules.len());
}

fn usage() {
    eprintln!("Usage:");
    eprintln!("  astrea-launch --desktop <desktop-id>");
    eprintln!("  astrea-launch --command <cmd>");
    eprintln!("  astrea-launch --file <path>");
    eprintln!("  astrea-launch --url <url>");
    eprintln!("  astrea-launch --steam <steam-uri>");
    eprintln!("  astrea-launch daemon");
    eprintln!("  astrea-launch doctor");
    eprintln!("  astrea-launch history");
}

fn empty_record() -> astrea_launch::LaunchRecord {
    astrea_launch::LaunchRecord {
        timestamp_ms: 0,
        kind: String::new(),
        target: String::new(),
        argv: Vec::new(),
        pid: None,
        status: String::new(),
        detail: String::new(),
    }
}
