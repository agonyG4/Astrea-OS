# Core

Core contains shared code used by apps, shell surfaces, and system-facing UI.

## Boundaries

- `components/`: shared QML UI primitives.
- `bridge/`: shared backend and bridge helpers.

App-specific backend code should stay inside its app directory when it belongs
to one app release unit. Shared backend code belongs in `bridge/`.

Generated files such as `__pycache__`, `target/`, and test caches should not
remain in this tree.
