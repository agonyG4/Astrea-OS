#!/usr/bin/env python3
import json
import subprocess
import sys
import os

AVAILABLE_SCALES    = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]
AVAILABLE_BITDEPTHS = [6, 8, 10]

CONF_PATH = os.path.expanduser(
    "~/.local/share/Astrea/Apps/Settings/components/visual/monitor-settings.conf"
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


def parse_mode(mode: str) -> tuple[str, float]:
    res, rest = mode.split("@")
    hz = float(rest.replace("Hz", ""))
    return res, hz


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
    current_scale = raw.get("scale", 1.0)
    transform     = raw.get("transform", 0)

    raw_w = round(raw["width"]  * current_scale)
    raw_h = round(raw["height"] * current_scale)

    if transform in (1, 3, 5, 7):
        raw_w, raw_h = raw_h, raw_w

    current_res = f"{raw_w}x{raw_h}"

    if current_res not in res_hz_map and sorted_resolutions:
        current_res = sorted_resolutions[-1]

    current_hz = round(raw.get("refreshRate", 60))

    if saved.get("monitor") == mon_name:
        try:
            current_bpc = int(saved["bitdepth"])
        except (KeyError, ValueError):
            current_bpc = raw.get("bitDepth", 8)
        try:
            current_vrr = int(saved.get("vrr", 0)) == 1
        except (ValueError, TypeError):
            current_vrr = False
    else:
        current_bpc = raw.get("bitDepth", 8)
        current_vrr = False

    return {
        "name":        mon_name,
        "description": raw.get("description", ""),
        "vrrSupported": raw.get("vrr", False),
        "current": {
            "resolution":  current_res,
            "refreshRate": current_hz,
            "bitdepth":    current_bpc,
            "scale":       current_scale,
            "vrr":         current_vrr,
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