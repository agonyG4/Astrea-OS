# Astrea Structure

The runtime tree is being organized by responsibility while preserving old paths.

## UI

Shell surfaces, shared visual primitives, and UI assets live under the `UI/`
namespace. The current live shell still loads from `Quickshell/`, so `UI/shell`
is a compatibility pointer instead of a hard move.

## Backend

Shared system backends live under the `Backend/` namespace. These are bridge
scripts, background services, portal helpers, and auth helpers that are not owned
by one app.

App-owned backends are not extracted. For example, `Apps/Weather/backend` stays
with Weather because it is part of that app's implementation and release unit.

## Runtime

Executables, scripts, config defaults, and translations live under the
`Runtime/` namespace. The older `bin/` and `System/` locations remain valid
while services and QML imports still refer to them.

## Compatibility

This refactor is intentionally reversible. New namespace directories are links
to the current working implementation. Existing imports and launchers keep using
the paths they already know until they can be migrated safely.

Run `python3 Tools/structure/astrea_structure_check.py` after structural edits.
