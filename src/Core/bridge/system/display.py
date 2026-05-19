#!/usr/bin/env python3
import json
import subprocess
import sys
import os

AVAILABLE_SCALES    = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]
AVAILABLE_BITDEPTHS = [6, 8, 10]
DEFAULT_SATURATION = 93
MAX_SATURATION = 100
MAX_NVIBRANT_SATURATION = 1023
DEFAULT_NIGHT_SHIFT_STRENGTH = 35
DEFAULT_NIGHT_SHIFT_START = "20:00"
DEFAULT_NIGHT_SHIFT_END = "07:00"

CONF_PATH = os.path.expanduser(
    "~/.local/share/Astrea/System/config/display/monitor-settings.conf"
)


def get_monitors() -> list[dict]:
    try:
        result = subprocess.run(
            ["hyprctl", "monitors", "-j"],
            capture_output=True, text=True, timeout=3
        )
        if result.returncode != 0:
            raise RuntimeError(f"hyprctl error: {result.stderr.strip()}")
        return json.loads(result.stdout)
    except FileNotFoundError:
        raise RuntimeError("hyprctl not found — is Hyprland running?")
    except json.JSONDecodeError:
        raise RuntimeError("Failed to parse hyprctl output")


def read_conf() -> dict:
    saved = {}
    if not os.path.exists(CONF_PATH):
        return saved
    try:
        with open(CONF_PATH) as f:
            for line in f:
                line = line.strip()
                if "=" in line and not line.startswith("#"):
                    k, _, v = line.partition("=")
                    saved[k.strip()] = v.strip()
    except OSError:
        pass
    return saved


def valid_time(value: str, fallback: str) -> str:
    try:
        hour_s, minute_s = str(value).split(":", 1)
        hour = max(0, min(23, int(hour_s)))
        minute = max(0, min(59, int(minute_s)))
        return f"{hour:02d}:{minute:02d}"
    except (ValueError, TypeError):
        return fallback


def saturation_to_percent(value: str | int) -> int:
    try:
        saturation = int(value)
    except (ValueError, TypeError):
        return DEFAULT_SATURATION

    if saturation > MAX_SATURATION:
        saturation = round(max(0, min(MAX_NVIBRANT_SATURATION, saturation)) * 100 / MAX_NVIBRANT_SATURATION)

    return max(0, min(MAX_SATURATION, saturation))


def parse_mode(mode: str) -> tuple[str, float]:
    res, rest = mode.split("@")
    hz = float(rest.replace("Hz", ""))
    return res, hz


def detect_vrr_support(raw: dict, refresh_map: dict[str, list[int]]) -> bool:
    explicit_state = raw.get("vrr")
    if isinstance(explicit_state, bool) and explicit_state:
        return True

    if raw.get("disabled", False):
        return False

    connector = str(raw.get("name", "")).upper()
    active = str(raw.get("dpmsStatus", True)).lower() not in ("false", "0")
    multi_rate = any(len(rates) > 1 for rates in refresh_map.values())
    max_rate = max((max(rates) for rates in refresh_map.values() if rates), default=0)

    connector_likely_vrr = (
        connector.startswith("DP-")
        or connector.startswith("EDP-")
        or connector.startswith("HDMI-A-")
    )

    return active and connector_likely_vrr and multi_rate and max_rate > 60


def build_monitor_info(raw: dict, saved: dict) -> dict:
    modes = raw.get("availableModes", [])

    res_hz_map: dict[str, list[int]] = {}
    for mode in modes:
        try:
            res, hz = parse_mode(mode)
            hz_int = round(hz)
            res_hz_map.setdefault(res, [])
            if hz_int not in res_hz_map[res]:
                res_hz_map[res].append(hz_int)
        except (ValueError, IndexError):
            continue

    def res_pixels(r: str) -> int:
        try:
            w, h = r.split("x")
            return int(w) * int(h)
        except ValueError:
            return 0

    sorted_resolutions = sorted(res_hz_map.keys(), key=res_pixels)
    for res in res_hz_map:
        res_hz_map[res] = sorted(res_hz_map[res])

    mon_name      = raw.get("name", "")
    mon_id        = raw.get("id", 0)
    current_scale = raw.get("scale", 1.0)
    transform     = raw.get("transform", 0)
    position_x    = raw.get("x", 0)
    position_y    = raw.get("y", 0)

    raw_w = round(raw["width"]  * current_scale)
    raw_h = round(raw["height"] * current_scale)

    rotated = transform in (1, 3, 5, 7)
    if rotated:
        raw_w, raw_h = raw_h, raw_w

    current_res = f"{raw_w}x{raw_h}"

    if current_res not in res_hz_map and sorted_resolutions:
        current_res = sorted_resolutions[-1]

    current_hz = round(raw.get("refreshRate", 60))

    current_vrr_state = bool(raw.get("vrr", False))

    if saved.get("monitor") == mon_name:
        try:
            current_bpc = int(saved["bitdepth"])
        except (KeyError, ValueError):
            current_bpc = raw.get("bitDepth", 8)
        try:
            current_vrr_mode = int(saved.get("vrr", 0))
        except (ValueError, TypeError):
            current_vrr_mode = 1 if current_vrr_state else 0
        current_vrr_mode = max(0, min(2, current_vrr_mode))
        try:
            current_saturation = saturation_to_percent(saved.get("saturation", DEFAULT_SATURATION))
        except (ValueError, TypeError):
            current_saturation = DEFAULT_SATURATION
        try:
            current_night_shift = int(saved.get("night_shift", 0)) == 1
        except (ValueError, TypeError):
            current_night_shift = False
        try:
            current_night_shift_strength = int(
                saved.get("night_shift_strength", DEFAULT_NIGHT_SHIFT_STRENGTH)
            )
        except (ValueError, TypeError):
            current_night_shift_strength = DEFAULT_NIGHT_SHIFT_STRENGTH
        try:
            current_night_shift_schedule = int(saved.get("night_shift_schedule", 0)) == 1
        except (ValueError, TypeError):
            current_night_shift_schedule = False
        current_night_shift_start = valid_time(
            saved.get("night_shift_start", DEFAULT_NIGHT_SHIFT_START),
            DEFAULT_NIGHT_SHIFT_START
        )
        current_night_shift_end = valid_time(
            saved.get("night_shift_end", DEFAULT_NIGHT_SHIFT_END),
            DEFAULT_NIGHT_SHIFT_END
        )
    else:
        current_bpc = raw.get("bitDepth", 8)
        current_vrr_mode = 1 if current_vrr_state else 0
        current_saturation = DEFAULT_SATURATION
        current_night_shift = False
        current_night_shift_strength = DEFAULT_NIGHT_SHIFT_STRENGTH
        current_night_shift_schedule = False
        current_night_shift_start = DEFAULT_NIGHT_SHIFT_START
        current_night_shift_end = DEFAULT_NIGHT_SHIFT_END

    return {
        "id":          mon_id,
        "name":        mon_name,
        "description": raw.get("description", ""),
        "make":        raw.get("make", ""),
        "model":       raw.get("model", ""),
        "vrrSupported": detect_vrr_support(raw, res_hz_map),
        "current": {
            "resolution":  current_res,
            "refreshRate": current_hz,
            "bitdepth":    current_bpc,
            "scale":       current_scale,
            "vrr":         current_vrr_mode > 0,
            "vrrMode":     current_vrr_mode,
            "saturation":  current_saturation,
            "nightShift":  current_night_shift,
            "nightShiftStrength": current_night_shift_strength,
            "nightShiftSchedule": current_night_shift_schedule,
            "nightShiftStart": current_night_shift_start,
            "nightShiftEnd": current_night_shift_end,
        },
        "geometry": {
            "x": position_x,
            "y": position_y,
            "width": raw_w,
            "height": raw_h,
            "transform": transform,
            "rotated": rotated,
            "scale": current_scale,
            "physicalWidth": raw.get("physicalWidth", 0),
            "physicalHeight": raw.get("physicalHeight", 0),
        },
        "resolutions":  sorted_resolutions,
        "refreshRates": res_hz_map,
        "bitdepths":    AVAILABLE_BITDEPTHS,
        "scales":       AVAILABLE_SCALES,
    }


def main():
    try:
        raw_monitors = get_monitors()
        if not raw_monitors:
            raise RuntimeError("No monitors reported by hyprctl")

        saved    = read_conf()
        monitors = [build_monitor_info(m, saved) for m in raw_monitors]

        active = next(
            (m["name"] for m, r in zip(monitors, raw_monitors) if r.get("focused")),
            monitors[0]["name"]
        )

        print(json.dumps({
            "monitors":      monitors,
            "activeMonitor": active,
        }))

    except RuntimeError as e:
        print(json.dumps({"error": str(e)}))
        sys.exit(1)


if __name__ == "__main__":
    main()
