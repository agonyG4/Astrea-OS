fn main() {
    if let Err(error) = astrea_statusd::run() {
        eprintln!("astrea-statusd: {error}");
        std::process::exit(1);
    }
}
