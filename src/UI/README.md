# UI

Canonical namespace for Astrea user interfaces.

- `shell` points to the resident Quickshell shell.
- `components` points to shared QML components.
- `assets` points to UI-specific static assets.

Prefer this namespace for new documentation and high-level references.
Keep existing direct imports working while live QML migrates gradually.
Resident shell surface enablement is configured through
`~/.config/AstreaOS/ui/components.json` and read by `Quickshell/runtime`.
