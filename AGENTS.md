# Repository Guidelines

## Project Structure & Module Organization

Astrea source lives under `src/`. Major areas are `src/Apps` for QML apps, `src/Core` for shared components and bridge helpers, `src/System` for services, portal, auth, and scripts, and `src/Quickshell` for the desktop shell. Rust backends are app- or feature-owned, for example `src/Apps/Weather/backend`, `src/Core/bridge/apps/explorer`, and `src/Core/bridge/audio/music_bars`. Agent-facing architecture notes live in `agent/Astrea`; experiments and prototypes live in `Bench`. The installed live runtime is usually `~/.local/share/Astrea`, but repository changes should be made in `src/` unless explicitly working on live-only debugging.

## Build, Test, and Development Commands

- `scripts/run_refactor_checks.sh`: runs core i18n, JSON state, desktop index, Explorer helper, and Explorer Rust tests.
- `python3 -m unittest discover -s src/Core/bridge -p 'test_*.py' -v`: runs bridge unit tests.
- `python3 -m unittest discover -s src/System/services -p 'test_*.py' -v`: runs service tests.
- `cargo test --manifest-path src/Apps/Weather/backend/Cargo.toml --workspace`: tests Weather Rust crates.
- `cargo test --manifest-path src/Core/bridge/apps/explorer/Cargo.toml`: tests the Explorer backend.
- `qmllint <file.qml>`: checks changed QML files.
- `update/sync-runtime.sh --rolling`: syncs `src/` into `~/.local/share/Astrea-Rolling` for runtime validation.

## Coding Style & Naming Conventions

Use Python 3 with 4-space indentation, `pathlib` for paths, JSON payloads for QML bridges, and explicit subprocess timeouts. Keep QML components PascalCase and state/helper files named for their owned behavior, such as `NavigationState.qml` or `FileOperationsState.qml`. Prefer shared controls in `src/Core/components` over one-off UI widgets. Rust code should stay formatted with `cargo fmt`.

## Testing Guidelines

Tests use Python `unittest`, Rust `cargo test`, and targeted `qmllint`/Quickshell smoke checks. Name Python tests `test_*.py` and keep regression tests near the module they protect. For service changes, also run the relevant `astrea-services.sh verify <scope>` in the synced runtime when possible.

## Commit & Pull Request Guidelines

Recent commits use concise imperative summaries, for example `Fix Explorer file selection focus` or `sync astrea rolling runtime`. Keep commits scoped and mention runtime syncs separately from source changes. PRs should describe user-visible behavior, touched modules, validation commands, and include screenshots or short screen recordings for UI changes.

## Agent-Specific Instructions

Before editing, confirm whether the task targets `src/` or the live runtime. Do not store user data inside the installed runtime; durable user data belongs under `~/.local/share/AstreaOS` or `~/.config/AstreaOS` as appropriate.
