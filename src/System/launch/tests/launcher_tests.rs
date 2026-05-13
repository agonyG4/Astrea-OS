use std::fs;
use std::path::Path;

use astrea_launch::{
    LaunchConfig, LaunchRequest, Rule, command_from_desktop_file, extract_steam_appid,
    matching_rule, parse_exec_line,
};

#[test]
fn parses_desktop_exec_without_field_codes() {
    let args = parse_exec_line(r#"env FOO=bar "my app" --open %U --literal %% --name=%c"#)
        .expect("exec line should parse");

    assert_eq!(
        args,
        vec!["env", "FOO=bar", "my app", "--open", "--literal", "%"]
    );
}

#[test]
fn resolves_desktop_file_to_command_and_working_dir() {
    let dir = std::env::temp_dir().join(format!("astrea-launch-test-{}", std::process::id()));
    let desktop = dir.join("example.desktop");
    fs::create_dir_all(&dir).unwrap();
    fs::write(
        &desktop,
        "[Desktop Entry]\nType=Application\nName=Example\nExec=/usr/bin/example --flag %U\nPath=/tmp\n",
    )
    .unwrap();

    let command = command_from_desktop_file(&desktop).expect("desktop command");

    assert_eq!(command.argv, vec!["/usr/bin/example", "--flag"]);
    assert_eq!(command.working_dir.as_deref(), Some(Path::new("/tmp")));

    let _ = fs::remove_dir_all(dir);
}

#[test]
fn matches_rules_by_desktop_executable_command_and_steam_appid() {
    let config = LaunchConfig {
        rules: vec![
            Rule {
                desktop_id: Some("steam.desktop".into()),
                env: vec![("STEAM_FORCE_DESKTOPUI_SCALING".into(), "1".into())],
                ..Rule::default()
            },
            Rule {
                executable: Some("heroic".into()),
                working_dir: Some("/games".into()),
                ..Rule::default()
            },
            Rule {
                command_substring: Some("--profile gaming".into()),
                launch_boost_ms: Some(1200),
                ..Rule::default()
            },
            Rule {
                steam_appid: Some("264710".into()),
                game_mode_preset: Some("gamemode".into()),
                ..Rule::default()
            },
        ],
        ..LaunchConfig::default()
    };

    assert_eq!(
        matching_rule(
            &config,
            &LaunchRequest::Desktop {
                id: "steam.desktop".into()
            },
            Some("steam"),
            ""
        )
        .unwrap()
        .env[0]
            .0,
        "STEAM_FORCE_DESKTOPUI_SCALING"
    );
    assert_eq!(
        matching_rule(
            &config,
            &LaunchRequest::Command {
                command: "heroic --profile gaming".into()
            },
            Some("/usr/bin/heroic"),
            "heroic --profile gaming"
        )
        .unwrap()
        .working_dir
        .as_deref(),
        Some("/games")
    );
    assert_eq!(
        matching_rule(
            &config,
            &LaunchRequest::Steam {
                uri: "steam://rungameid/264710".into()
            },
            Some("steam"),
            ""
        )
        .unwrap()
        .game_mode_preset
        .as_deref(),
        Some("gamemode")
    );
}

#[test]
fn extracts_steam_appid_from_supported_urls() {
    assert_eq!(
        extract_steam_appid("steam://rungameid/264710").as_deref(),
        Some("264710")
    );
    assert_eq!(
        extract_steam_appid("https://store.steampowered.com/app/413150/Stardew_Valley/").as_deref(),
        Some("413150")
    );
}

#[test]
fn serializes_launch_requests_for_daemon_protocol() {
    let request = LaunchRequest::Desktop {
        id: "org.gnome.Nautilus".into(),
    };
    let text = serde_json::to_string(&request).expect("request json");

    assert_eq!(text, r#"{"kind":"desktop","id":"org.gnome.Nautilus"}"#);
    assert_eq!(
        serde_json::from_str::<LaunchRequest>(&text).expect("request parse"),
        request
    );
}
