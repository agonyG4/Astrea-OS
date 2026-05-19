# Astrea Weather Daemon Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move Weather monitoring and notifications out of QML into an independent Rust user service.

**Architecture:** `Apps/Weather/backend` is a Rust workspace with `weather-core`, `weather-cli`, and `weatherd`. `Apps/Weather/ui` contains the QML app. The first cut keeps the existing Weather JSON contract intact so the QML app and Spotlight can keep rendering the same data while notification logic moves to the daemon.

**Tech Stack:** Rust 2024, `serde_json`, existing Open-Meteo/INMET Python bridge as a compatibility fetch provider, `System/services/astrea_notify.py`, Astrea's freedesktop notification daemon, and `systemd --user`.

---

### Tasks

- [x] Create `weather-core` with alert rules, settings, cache paths, atomic JSON writes, and duplicate tracking.
- [x] Create `weather-cli` with reusable `get`, `summary`, `settings`, `notify-test`, and `check-alerts` commands.
- [x] Create `weatherd` with a low-frequency loop, cache refresh, alert evaluation, notification delivery, and duplicate state.
- [x] Update `Apps/Weather/ui/state/WeatherState.qml` so QML only fetches/displays data and writes settings.
- [x] Register `astrea-weatherd.service` in `System/services/astrea-services.sh`.
- [x] Update Weather docs to describe the service-owned monitoring model.
- [ ] Revalidate with Rust tests, `cargo check`, service verification, QML smoke load, and CLI commands after future Weather changes.
