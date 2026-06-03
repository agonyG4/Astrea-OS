# Explorer Backend Performance And Hardening

Date: 2026-06-02
Target repo: `/home/agony/GitHub/Astrea-Dev`
Runtime source: `/home/agony/.local/share/Astrea`

## Summary

Synced the current Explorer/Finder backend performance fixes from the live Astrea runtime into `Astrea-Dev/src/Core/bridge/apps/explorer`. The patch focuses on safer recursive search, lower thumbnail warm-up pressure, cheaper device lookup, and fewer tiny allocations while preserving the existing CLI contract.

## Changes

### Search Safety

- `entries.rs` now caps recursive search with `SEARCH_MAX_DEPTH = 8` and `SEARCH_MAX_RESULTS = 2_000`.
- Recursive local search uses `DirEntry::file_type()` to decide whether to descend, avoiding directory symlink traversal and preventing symlink loops or unexpected tree expansion.
- Directory symlinks can still be returned as directory entries for navigation/icon behavior, but are not descended into during search.
- Added `recursive_search_skips_directory_symlinks` and `recursive_search_keeps_directory_symlink_classification` regression coverage.

### Thumbnail Warm-Up Efficiency

- `thumbnails.rs` caches the thumbnail cache directory with `OnceLock`, avoiding repeated `HOME` lookup and path construction per preview lookup.
- `warm-thumbnails` now uses a dedicated Rayon thread pool capped at 4 workers so `ffmpeg`/`magick` subprocesses do not fan out across all CPU threads.
- SVG thumbnail generation now computes `is_small_svg()` once through `SvgPreviewParams` instead of calling the expensive `magick identify` path up to three times.

### Device Lookup Efficiency

- `devices.rs` now tries `lsblk(Some(path))` for known-device lookup before falling back to the full `lsblk(None)` listing.

### File URL Encoding

- `json.rs` replaces per-byte `format!("%{byte:02X}")` percent encoding with `push_percent_encoded_byte`, writing hex digits directly into the output string.

## Validation

- `cargo test --manifest-path src/Core/bridge/apps/explorer/Cargo.toml` — 24 passed, 0 failed.
- `cargo build --release --manifest-path src/Core/bridge/apps/explorer/Cargo.toml` — passed.
- Smoke-tested release backend commands:
  - `explorer_backend list /home/agony 0 name 1 1`
  - `explorer_backend search /home/agony Astrea 0 name 1 1`
  - `explorer_backend devices`

## Suggested Commit Title

```text
Optimize Explorer backend search and thumbnails
```
