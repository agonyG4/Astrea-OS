#!/usr/bin/env python3
"""
get-audio-info.py — Astrea Audio backend
Uso:
  get-audio-info.py info          → JSON com dispositivos, sample rate, latência, apps
  get-audio-info.py apply <json>  → aplica config via wpctl / wireplumber conf
  get-audio-info.py apps          → JSON só com apps (leve)
"""

import sys
import json
import subprocess
import re
from pathlib import Path

BRIDGE_DIR = Path(__file__).resolve().parents[1]
if str(BRIDGE_DIR) not in sys.path:
    sys.path.insert(0, str(BRIDGE_DIR))

from astrea_shared import atomic_write_json, atomic_write_text, read_json, resolve_icon_path

# ── WirePlumber config path ───────────────────────────────────────────────────
WP_CONF = Path.home() / ".config/wireplumber/wireplumber.conf.d/50-astrea-audio.conf"
ALIASES_CONF = Path.home() / ".local/share/Astrea/System/config/audio-aliases.json"

# ── Helpers ───────────────────────────────────────────────────────────────────
def run(cmd: list) -> str:
    try:
        return subprocess.check_output(cmd, stderr=subprocess.DEVNULL, text=True)
    except Exception:
        return ""

def eprint(msg):
    print(msg, file=sys.stderr)

def get_aliases():
    data = read_json(ALIASES_CONF, {})
    if not isinstance(data, dict):
        return {}
    aliases = {}
    for name, alias in data.items():
        try:
            name_s = validate_wp_string(str(name), field="device name")
            alias_s = validate_wp_string(str(alias), field="alias")
        except ValueError:
            continue
        aliases[name_s] = alias_s
    return aliases


def validate_wp_string(value: str, *, field: str) -> str:
    value = (value or "").strip()
    if not value:
        raise ValueError(f"{field} vazio")
    if len(value) > 256:
        raise ValueError(f"{field} muito longo")
    if any(ord(ch) < 32 or ord(ch) == 127 for ch in value):
        raise ValueError(f"{field} contem caracteres de controle")
    return value


def wp_quote(value: str) -> str:
    return json.dumps(validate_wp_string(value, field="WirePlumber string"), ensure_ascii=False)


def save_alias(name, custom_name):
    aliases = get_aliases()
    device_name = validate_wp_string(str(name), field="device name")
    alias = str(custom_name or "").strip()
    if alias == "":
        aliases.pop(device_name, None)
    else:
        aliases[device_name] = validate_wp_string(alias, field="alias")
    atomic_write_json(ALIASES_CONF, aliases, indent=None, sort_keys=True)
    update_wp_aliases_file()


def update_wp_aliases_file():
    aliases = get_aliases()
    conf = Path.home() / ".config/wireplumber/wireplumber.conf.d/51-astrea-aliases.conf"
    if not aliases:
        if conf.exists():
            conf.unlink()
        return

    rules = []
    for name, alias in sorted(aliases.items()):
        try:
            quoted_name = wp_quote(name)
            quoted_alias = wp_quote(alias)
        except ValueError as exc:
            eprint(f"[aliases] ignorando alias invalido: {exc}")
            continue
        rules.append(
            "  {\n"
            f"    matches = [ {{ node.name = {quoted_name} }} ]\n"
            f"    actions = {{ update-props = {{ node.description = {quoted_alias} }} }}\n"
            "  }"
        )
    if not rules:
        if conf.exists():
            conf.unlink()
        return
    rules_str = ",\n".join(rules)
    content = f"monitor.alsa.rules = [\n{rules_str}\n]\n\n"
    content += f"monitor.bluez.rules = [\n{rules_str}\n]\n\n"
    atomic_write_text(conf, content)

# ── Lê dispositivos via pactl ─────────────────────────────────────────────────
def get_default_sink() -> str:
    return run(["pactl", "get-default-sink"]).strip()

def get_sinks() -> list:
    raw = run(["pactl", "-f", "json", "list", "sinks"])
    try:
        sinks = json.loads(raw)
    except Exception:
        return []
    result = []
    aliases = get_aliases()
    for s in sinks:
        props = s.get("properties", {})
        desc  = (props.get("device.description")
                 or props.get("node.description")
                 or s.get("description")
                 or s.get("name", ""))
        name = s.get("name", "")
        if name in aliases:
            desc = aliases[name]
        result.append({
            "name":        name,
            "description": desc,
            "default":     False,
        })
    return result

def get_sink_profiles(sink_name: str) -> dict:
    raw = run(["pactl", "list", "cards"])
    if not raw:
        return {"active": "", "profiles": [], "card": ""}
    sink_device = sink_name.replace("alsa_output.", "").replace("alsa_input.", "")
    sink_base   = ".".join(sink_device.split(".")[:-1]) if "." in sink_device else sink_device
    import re as _re
    cards = []
    current = None
    in_profiles = False
    for line in raw.splitlines():
        if _re.match(r'^Card #\d+', line):
            if current:
                cards.append(current)
            current = {"name": "", "active_profile": "", "profiles": {}}
            in_profiles = False
            continue
        if current is None:
            continue
        stripped = line.strip()
        if stripped.startswith("Name:"):
            current["name"] = stripped.split(":", 1)[1].strip()
            in_profiles = False
        elif stripped.startswith("Active Profile:"):
            current["active_profile"] = stripped.split(":", 1)[1].strip()
            in_profiles = False
        elif stripped == "Profiles:":
            in_profiles = True
        elif in_profiles:
            m = _re.match(r'^\s{2,}(\S+?):\s', line)
            if m:
                current["profiles"][m.group(1)] = True
            elif stripped and not line[0].isspace():
                in_profiles = False
    if current:
        cards.append(current)
    best = None
    for card in cards:
        cname_device = card.get("name", "").replace("alsa_card.", "")
        if cname_device == sink_base or sink_base.startswith(cname_device):
            best = card
            break
    if not best:
        return {"active": "", "profiles": [], "card": ""}
    skip = {"off", "pro-audio"}
    profiles = [p for p in best["profiles"] if p not in skip]
    return {
        "active":   best["active_profile"],
        "profiles": profiles,
        "card":     best["name"],
    }

# ── Lê apps (sink-inputs) via pactl ──────────────────────────────────────────
def _guess_icon(name: str) -> str:
    mapping = {
        "firefox":    "firefox",
        "chrome":     "google-chrome",
        "chromium":   "chromium",
        "spotify":    "spotify",
        "discord":    "discord",
        "telegram":   "telegram",
        "vlc":        "vlc",
        "mpv":        "mpv",
        "steam":      "steam",
        "obs":        "com.obsproject.Studio",
        "krita":      "krita",
        "gimp":       "gimp",
        "zen":        "zen-browser",
        "brave":      "brave-browser",
        "rhythmbox":  "rhythmbox",
        "amarok":     "amarok",
        "elisa":      "elisa",
        "clementine": "clementine",
    }
    lower = name.lower()
    for key, icon in mapping.items():
        if key in lower:
            return icon
    return "audio-x-generic"

def get_apps() -> list:
    raw = run(["pactl", "-f", "json", "list", "sink-inputs"])
    try:
        inputs = json.loads(raw)
    except Exception:
        return []
    result = []
    for inp in inputs:
        props = inp.get("properties", {})
        name  = (props.get("application.name")
                 or props.get("media.name")
                 or props.get("node.name")
                 or f"App #{inp.get('index', '?')}")
        icon_name = (props.get("application.icon-name")
                     or props.get("application.icon_name")
                     or props.get("media.icon-name")
                     or _guess_icon(name))
        icon_path = resolve_icon_path(icon_name)
        result.append({
            "index":  inp.get("index", 0),
            "name":   name,
            "icon":   icon_path,
            "volume": _avg_volume(inp.get("volume", {})),
            "muted":  inp.get("mute", False),
        })
    return result

# ── Lê config WirePlumber atual ───────────────────────────────────────────────
def get_wp_config() -> dict:
    defaults = {"sample_rate": 48000, "buffer_size": 1024}
    if not WP_CONF.exists():
        return defaults
    text = WP_CONF.read_text()
    sr  = re.search(r"default\.clock\.rate\s*=\s*(\d+)", text)
    buf = re.search(r"default\.clock\.quantum\s*=\s*(\d+)", text)
    return {
        "sample_rate": int(sr.group(1))  if sr  else defaults["sample_rate"],
        "buffer_size": int(buf.group(1)) if buf else defaults["buffer_size"],
    }

# ── Aplica config ─────────────────────────────────────────────────────────────
def apply_config(cfg: dict):
    if "app_index" in cfg and "volume" in cfg:
        vol = max(0.0, min(1.5, float(cfg["volume"])))
        run(["pactl", "set-sink-input-volume", str(cfg["app_index"]), f"{int(vol*100)}%"])
    if "app_index" in cfg and "muted" in cfg:
        run(["pactl", "set-sink-input-mute", str(cfg["app_index"]),
             "1" if cfg["muted"] else "0"])
    if "card" in cfg and "profile" in cfg:
        run(["pactl", "set-card-profile", cfg["card"], cfg["profile"]])
    if "set_default_sink" in cfg:
        run(["pactl", "set-default-sink", cfg["set_default_sink"]])
    if "rename" in cfg and "name" in cfg:
        save_alias(cfg["name"], cfg["rename"])
    if "sample_rate" in cfg or "buffer_size" in cfg:
        wp = get_wp_config()
        if "sample_rate" in cfg:
            wp["sample_rate"] = int(cfg["sample_rate"])
        if "buffer_size" in cfg:
            wp["buffer_size"] = int(cfg["buffer_size"])
        _write_wp_conf(wp)
        print("wp_restart_required: true")

def _write_wp_conf(cfg: dict):
    sample_rate = int(cfg.get("sample_rate", 48000))
    buffer_size = int(cfg.get("buffer_size", 1024))
    if sample_rate < 8000 or sample_rate > 384000:
        raise ValueError("sample_rate fora do intervalo seguro")
    if buffer_size < 32 or buffer_size > 8192:
        raise ValueError("buffer_size fora do intervalo seguro")
    atomic_write_text(
        WP_CONF,
        "# Astrea Audio Settings — gerado automaticamente\n"
        "wireplumber.settings = {\n"
        f"  default.clock.rate          = {sample_rate}\n"
        f"  default.clock.quantum       = {buffer_size}\n"
        "  default.clock.min-quantum   = 32\n"
        "  default.clock.max-quantum   = 8192\n"
        "}\n"
    )

# ── Parse helpers ─────────────────────────────────────────────────────────────
def _avg_volume(vol_obj) -> float:
    if not isinstance(vol_obj, dict):
        return 0.0
    vals = []
    for v in vol_obj.values():
        if isinstance(v, dict):
            raw = v.get("value_percent", 0)
        else:
            raw = v
        if isinstance(raw, str):
            raw = raw.replace("%", "").strip()
        try:
            vals.append(float(raw))
        except (ValueError, TypeError):
            vals.append(0.0)
    return round(sum(vals) / len(vals) / 100, 3) if vals else 0.0

# ── Main ──────────────────────────────────────────────────────────────────────
def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else "info"

    if mode == "info":
        out = {
            "sinks": [],
            "apps":  [],
            "wp":    {"sample_rate": 48000, "buffer_size": 1024},
        }
        try:
            default_sink = get_default_sink()
            sinks = get_sinks()
            for s in sinks:
                s["default"] = (s["name"] == default_sink)
            out["sinks"] = sinks
        except Exception as e:
            eprint(f"[sinks] {e}")
        try:
            out["apps"] = get_apps()
        except Exception as e:
            eprint(f"[apps] {e}")
        try:
            out["wp"] = get_wp_config()
        except Exception as e:
            eprint(f"[wp] {e}")
        print(json.dumps(out, ensure_ascii=False))

    elif mode == "apps":
        out = {"apps": []}
        try:
            out["apps"] = get_apps()
        except Exception as e:
            eprint(f"[apps] {e}")
        print(json.dumps(out, ensure_ascii=False))

    elif mode == "apply":
        if len(sys.argv) < 3:
            eprint("Uso: get-audio-info.py apply '<json>'")
            sys.exit(1)
        try:
            cfg = json.loads(sys.argv[2])
        except Exception as e:
            eprint(f"JSON inválido: {e}")
            sys.exit(1)
        apply_config(cfg)

    else:
        eprint(f"Modo desconhecido: {mode}")
        sys.exit(1)

if __name__ == "__main__":
    main()
