fn main() {
    if let Err(error) = astrea_latencyd::run_cli() {
        eprintln!("astrea-latencyd: {error}");
        std::process::exit(1);
    }
}
