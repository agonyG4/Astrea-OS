mod appimage;
mod devices;
mod entries;
mod file_ops;
mod json;
mod thumbnails;

use std::env;

fn main() {
    if let Err(e) = run() {
        eprintln!("{e}");
        std::process::exit(1);
    }
}

fn run() -> Result<(), String> {
    let args: Vec<String> = env::args().collect();
    match args.get(1).map(String::as_str) {
        Some("list") => entries::run_list(&args[2..]),
        Some("search") => entries::run_search(&args[2..]),
        Some("devices") => devices::run_devices(),
        Some("mount") => devices::run_mount(&args[2..], "mount", "mounted"),
        Some("unmount") => devices::run_mount(&args[2..], "unmount", "unmounted"),
        Some("remount") => devices::run_remount(&args[2..]),
        Some("warm-thumbnails") => thumbnails::run_warm(&args[2..]),
        Some("install-appimage") => appimage::run(&args[2..]),
        Some("file-op") => file_ops::run(&args[2..]),
        _ if args.len() >= 6 => entries::run_list(&args[1..]),
        _ => Err("usage: explorer_backend list|search|devices|mount|unmount|remount|warm-thumbnails|install-appimage|file-op ...".into()),
    }
}
