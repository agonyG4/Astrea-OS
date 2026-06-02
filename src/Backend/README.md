# Backend

Canonical namespace for shared Astrea backend code.

- `bridge` points to shared Python/Rust bridge helpers.
- `services` points to long-running user services and service scripts.
- `portal` points to desktop portal integration.
- `auth` points to privileged/authentication helpers.

App-owned backends stay inside `Apps/<AppName>/backend`.
For example, Weather keeps its Rust workspace under `Apps/Weather/backend`,
while shared launch, portal, auth, and status services stay under Backend/System
compatibility paths.
