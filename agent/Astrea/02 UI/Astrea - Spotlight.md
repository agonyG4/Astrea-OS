# Astrea - Spotlight

Related notes: [[Astrea - Quickshell Runtime]], [[Astrea - Weather Bridge]]

## File
`Quickshell/spotlight/Spotlight.qml`

## Responsibility
Spotlight is an app launcher/search surface.

It handles:
- app search
- result ranking
- app launch
- usage tracking
- optional weather summary

## Data Sources
- Quickshell application entries.
- Usage file:
  - `~/.local/state/Astrea/spotlight-usage.json`
- Config file:
  - `~/.config/AstreaOS/spotlight.json`
- Weather summary:
  - [[Astrea - Weather Bridge]]

## Background Work
Spotlight is resident for instant open, but it should not keep weather refresh work alive while hidden.

Weather refresh is on-demand:
- opening Spotlight refreshes when no summary exists or when the summary is stale.
- the periodic weather timer runs only while Spotlight is open.
- shell startup loads config and usage, then performs one lightweight summary warmup when weather is enabled so the first visible open does not depend on a cold network fetch.
- closing Spotlight stops pending search debounce work and cancels an in-flight weather summary process.

## Launch Flow
1. User opens Spotlight.
2. Spotlight loads usage counts and config.
3. User types a query.
4. QML filters app entries.
5. User selects an app.
6. Spotlight calls `entry.execute()`.
7. Usage count is persisted.

## Important Boundary
Spotlight is resident inside `Quickshell/shell.qml`. A quit call inside resident Spotlight would affect the shell process, so standalone and resident behavior matter.
