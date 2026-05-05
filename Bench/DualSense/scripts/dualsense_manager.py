#!/usr/bin/env python3
import argparse
import json
import os
import shutil
import subprocess
import sys

CONFIG_PATH = os.path.expanduser("~/.config/AstreaOS/dualsense.json")


def clamp(value, low, high):
    return max(low, min(high, int(value)))


def dualsensectl_path():
    return shutil.which("dualsensectl")


def dualsense_rgb_led_path():
    root = "/sys/class/leds"
    try:
        names = os.listdir(root)
    except OSError:
        return ""

    for name in names:
        if not name.endswith(":rgb:indicator"):
            continue
        path = os.path.join(root, name)
        try:
            target = os.path.realpath(path)
        except OSError:
            target = path
        if "054C:0CE6" in target.upper() or "ps-controller" in target:
            return path
    return ""


def set_lightbar_sysfs(red, green, blue, brightness):
    path = dualsense_rgb_led_path()
    if not path:
        return {
            "ok": False,
            "code": 2,
            "stdout": "",
            "stderr": "DualSense RGB sysfs LED not found",
            "command": ["sysfs-lightbar"],
        }

    try:
        with open(os.path.join(path, "multi_intensity"), "w", encoding="utf-8") as handle:
            handle.write(f"{red} {green} {blue}\n")
        with open(os.path.join(path, "brightness"), "w", encoding="utf-8") as handle:
            handle.write(f"{brightness}\n")
    except OSError as exc:
        return {
            "ok": False,
            "code": 1,
            "stdout": "",
            "stderr": str(exc),
            "command": ["sysfs-lightbar", path],
        }

    return {
        "ok": True,
        "code": 0,
        "stdout": path,
        "stderr": "",
        "command": ["sysfs-lightbar", path],
    }


def run_ctl(args, device=None):
    binary = dualsensectl_path()
    if not binary:
        return {
            "ok": False,
            "code": 127,
            "stdout": "",
            "stderr": "dualsensectl not found in PATH",
            "command": ["dualsensectl", *args],
        }

    command = [binary]
    if device:
        command.extend(["-d", extract_device_arg(device)])
    command.extend([str(arg) for arg in args])

    proc = subprocess.run(command, text=True, capture_output=True)
    return {
        "ok": proc.returncode == 0,
        "code": proc.returncode,
        "stdout": proc.stdout.strip(),
        "stderr": proc.stderr.strip(),
        "command": command,
    }


def parse_devices(output):
    devices = []
    for raw_line in output.splitlines():
        line = raw_line.strip()
        if not line or line == "Devices:" or "No devices" in line:
            continue
        devices.append(line)
    return devices


def extract_device_arg(device):
    raw = str(device).strip()
    if " " in raw:
        raw = raw.split()[0]
    return raw


def status_payload(device=None):
    ctl = dualsensectl_path()
    payload = {
        "ok": True,
        "installed": bool(ctl),
        "binary": ctl or "",
        "devices": [],
        "device": device or "",
        "battery": "",
        "info": "",
        "message": "",
    }

    if not ctl:
        payload["ok"] = False
        payload["message"] = "dualsensectl not found"
        return payload

    listed = run_ctl(["-l"])
    payload["devices"] = parse_devices(listed["stdout"])

    if not payload["devices"]:
        payload["ok"] = False
        payload["message"] = listed["stderr"] or listed["stdout"] or "No devices found"
        return payload

    selected = device or payload["devices"][0]
    payload["device"] = selected

    battery = run_ctl(["battery"], selected)
    info = run_ctl(["info"], selected)
    payload["battery"] = battery["stdout"] or battery["stderr"]
    payload["info"] = info["stdout"] or info["stderr"]
    if not battery["ok"] or not info["ok"]:
        payload["ok"] = False
        payload["message"] = battery["stderr"] or info["stderr"] or "Device found, but hidraw access failed"
    else:
        payload["message"] = "Ready"
    return payload


def print_json(payload):
    print(json.dumps(payload, ensure_ascii=False))


def default_config():
    return {
        "lightbar": {
            "red": 0,
            "green": 122,
            "blue": 255,
            "brightness": 180,
            "state": "on",
        },
        "player_leds": 6,
        "led_brightness": 1,
        "attenuation": {
            "rumble": 0,
            "trigger": 0,
        },
        "audio": {
            "microphone": "on",
            "microphone_led": "on",
            "microphone_mode": "headset",
            "speaker": "on",
            "volume": 160,
        },
        "trigger": {
            "side": "both",
            "mode": "feedback",
            "position": 2,
            "start": 2,
            "stop": 8,
            "strength": 5,
            "snapforce": 5,
            "first_foot": 4,
            "second_foot": 7,
            "strength_a": 2,
            "strength_b": 7,
            "amplitude": 5,
            "frequency": 25,
            "period": 20,
        },
    }


def read_config():
    config = default_config()
    try:
        with open(CONFIG_PATH, "r", encoding="utf-8") as handle:
            loaded = json.load(handle)
        if isinstance(loaded, dict):
            for key, value in loaded.items():
                config[key] = value
    except FileNotFoundError:
        write_config(config)
    except (OSError, json.JSONDecodeError):
        pass
    return config


def write_config(config):
    os.makedirs(os.path.dirname(CONFIG_PATH), exist_ok=True)
    with open(CONFIG_PATH, "w", encoding="utf-8") as handle:
        json.dump(config, handle, ensure_ascii=False, indent=2)
        handle.write("\n")


def handle_config(args):
    if args.config_action == "get":
        return {"ok": True, "path": CONFIG_PATH, "config": read_config()}

    try:
        payload = json.loads(args.payload)
    except json.JSONDecodeError as exc:
        return {"ok": False, "path": CONFIG_PATH, "stderr": f"Invalid JSON: {exc}"}

    if not isinstance(payload, dict):
        return {"ok": False, "path": CONFIG_PATH, "stderr": "Config payload must be an object"}

    config = read_config()
    for key, value in payload.items():
        config[key] = value
    write_config(config)
    return {"ok": True, "path": CONFIG_PATH, "config": config}


def handle_apply(args):
    device = args.device or None
    action = args.action

    if action == "lightbar":
        red = clamp(args.red, 0, 255)
        green = clamp(args.green, 0, 255)
        blue = clamp(args.blue, 0, 255)
        brightness = clamp(args.brightness, 0, 255)
        sysfs_result = set_lightbar_sysfs(red, green, blue, brightness)
        if sysfs_result["ok"]:
            return sysfs_result
        if sysfs_result["code"] != 2:
            return sysfs_result
        return run_ctl([
            "lightbar",
            red,
            green,
            blue,
            brightness,
        ], device)

    if action == "lightbar-state":
        if args.state == "off":
            sysfs_result = set_lightbar_sysfs(0, 0, 0, 0)
        else:
            config = read_config().get("lightbar", {})
            sysfs_result = set_lightbar_sysfs(
                clamp(config.get("red", 0), 0, 255),
                clamp(config.get("green", 122), 0, 255),
                clamp(config.get("blue", 255), 0, 255),
                clamp(config.get("brightness", 180), 0, 255),
            )
        if sysfs_result["ok"]:
            return sysfs_result
        if sysfs_result["code"] != 2:
            return sysfs_result
        return run_ctl(["lightbar", args.state], device)

    if action == "led-brightness":
        return run_ctl(["led-brightness", clamp(args.value, 0, 2)], device)

    if action == "player-leds":
        command = ["player-leds", clamp(args.value, 0, 7)]
        if args.instant:
            command.append("instant")
        return run_ctl(command, device)

    if action == "microphone":
        return run_ctl(["microphone", args.state], device)

    if action == "microphone-led":
        return run_ctl(["microphone-led", args.state], device)

    if action == "microphone-mode":
        return run_ctl(["microphone-mode", args.state], device)

    if action == "speaker":
        return run_ctl(["speaker", args.state], device)

    if action == "volume":
        return run_ctl(["volume", clamp(args.value, 0, 255)], device)

    if action == "attenuation":
        return run_ctl([
            "attenuation",
            clamp(args.rumble, 0, 7),
            clamp(args.trigger, 0, 7),
        ], device)

    if action == "trigger":
        trigger = args.trigger_side
        mode = args.mode
        params = []

        if mode == "off":
            params = []
        elif mode == "feedback":
            params = [clamp(args.position, 0, 9), clamp(args.strength, 0, 8)]
        elif mode == "weapon":
            params = [clamp(args.start, 0, 9), clamp(args.stop, 0, 9), clamp(args.strength, 0, 8)]
        elif mode == "bow":
            params = [
                clamp(args.start, 0, 9),
                clamp(args.stop, 0, 9),
                clamp(args.strength, 0, 8),
                clamp(args.snapforce, 0, 8),
            ]
        elif mode == "galloping":
            params = [
                clamp(args.start, 0, 9),
                clamp(args.stop, 0, 9),
                clamp(args.first_foot, 0, 8),
                clamp(args.second_foot, 0, 8),
                clamp(args.frequency, 0, 255),
            ]
        elif mode == "machine":
            params = [
                clamp(args.start, 0, 9),
                clamp(args.stop, 0, 9),
                clamp(args.strength_a, 0, 8),
                clamp(args.strength_b, 0, 8),
                clamp(args.frequency, 0, 255),
                clamp(args.period, 0, 255),
            ]
        elif mode == "vibration":
            params = [clamp(args.position, 0, 9), clamp(args.amplitude, 0, 8), clamp(args.frequency, 0, 255)]
        else:
            return {"ok": False, "code": 2, "stdout": "", "stderr": f"Unknown trigger mode: {mode}", "command": []}

        return run_ctl(["trigger", trigger, mode, *params], device)

    if action == "power-off":
        return run_ctl(["power-off"], device)

    return {"ok": False, "code": 2, "stdout": "", "stderr": f"Unknown action: {action}", "command": []}


def build_parser():
    parser = argparse.ArgumentParser(description="Small JSON bridge for DualSense Bench")
    parser.add_argument("--device", default="")

    subparsers = parser.add_subparsers(dest="command", required=True)
    subparsers.add_parser("status")

    config_parser = subparsers.add_parser("config")
    config_parser.add_argument("config_action", choices=["get", "set"])
    config_parser.add_argument("--payload", default="{}")

    apply_parser = subparsers.add_parser("apply")
    apply_parser.add_argument("action")
    apply_parser.add_argument("--state", default="on")
    apply_parser.add_argument("--value", type=int, default=0)
    apply_parser.add_argument("--red", type=int, default=0)
    apply_parser.add_argument("--green", type=int, default=122)
    apply_parser.add_argument("--blue", type=int, default=255)
    apply_parser.add_argument("--brightness", type=int, default=180)
    apply_parser.add_argument("--instant", action="store_true")
    apply_parser.add_argument("--rumble", type=int, default=0)
    apply_parser.add_argument("--trigger", type=int, default=0)
    apply_parser.add_argument("--trigger-side", default="both", choices=["left", "right", "both"])
    apply_parser.add_argument("--mode", default="off")
    apply_parser.add_argument("--position", type=int, default=2)
    apply_parser.add_argument("--start", type=int, default=2)
    apply_parser.add_argument("--stop", type=int, default=8)
    apply_parser.add_argument("--strength", type=int, default=5)
    apply_parser.add_argument("--snapforce", type=int, default=5)
    apply_parser.add_argument("--first-foot", type=int, default=4)
    apply_parser.add_argument("--second-foot", type=int, default=7)
    apply_parser.add_argument("--strength-a", type=int, default=2)
    apply_parser.add_argument("--strength-b", type=int, default=7)
    apply_parser.add_argument("--amplitude", type=int, default=5)
    apply_parser.add_argument("--frequency", type=int, default=25)
    apply_parser.add_argument("--period", type=int, default=20)
    return parser


def main():
    args = build_parser().parse_args()
    if args.command == "status":
        print_json(status_payload(args.device or None))
        return 0

    if args.command == "config":
        result = handle_config(args)
        print_json(result)
        return 0 if result.get("ok") else 1

    result = handle_apply(args)
    print_json(result)
    return 0 if result.get("ok") else int(result.get("code", 1) or 1)


if __name__ == "__main__":
    sys.exit(main())
