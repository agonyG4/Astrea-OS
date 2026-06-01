# Runtime

Canonical namespace for runtime wiring.

- `scripts` points to command helpers.
- `bin` points to installed runtime executables.
- `config` points to shipped runtime config defaults.
- `i18n` points to language resources and translation helpers.

Generated state should stay out of this tree when possible and prefer
`~/.local/state/Astrea`, `~/.cache/Astrea`, `~/.cache/weather`, `~/.config/AstreaOS`,
or durable user-library paths under `~/.local/share/AstreaOS`.
