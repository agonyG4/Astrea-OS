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
import os
from pathlib import Path

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
    if not ALIASES_CONF.exists():
        return {}
    try:
        c = ALIASES_CONF.read_text()
        return json.loads(c) if c else {}
    except Exception:
        return {}

def save_alias(name, custom_name):
    aliases = get_aliases()
    if custom_name.strip() == "":
        if name in aliases:
            del aliases[name]
    else:
        aliases[name] = custom_name.strip()
    ALIASES_CONF.parent.mkdir(parents=True, exist_ok=True)
    try:
        ALIASES_CONF.write_text(json.dumps(aliases, ensure_ascii=False))
    except Exception:
        pass
    update_wp_aliases_file()

def update_wp_aliases_file():
    aliases = get_aliases()
    conf = Path.home() / ".config/wireplumber/wireplumber.conf.d/51-astrea-aliases.conf"
    if not aliases:
        if conf.exists():
            conf.unlink()
        return

    out = []
    for k, v in aliases.items():
        out.append(f"""  {{
    matches = [ {{ node.name = "{k}" }} ]
    actions = {{ update-props = {{ node.description = "{v}" }} }}
  }}""")
    rules_str = ",\n".join(out)
    content = f"monitor.alsa.rules = [\n{rules_str}\n]\n\n"
    content += f"monitor.bluez.rules = [\n{rules_str}\n]\n\n"
    conf.parent.mkdir(parents=True, exist_ok=True)
    conf.write_text(content)

# ── Resolve path do ícone no tema ─────────────────────────────────────────────
def resolve_icon_path(icon_name: str) -> str:
    if not icon_name:
        return ""

    theme = "hicolor"
    try:
        gtk = subprocess.check_output(
            ["gsettings", "get", "org.gnome.desktop.interface", "icon-theme"],
            stderr=subprocess.DEVNULL, text=True
        ).strip().strip("'")
        if gtk:
            theme = gtk
    except Exception:
        pass

    # tenta o tema exato e variantes sem sufixo (-dark, -light)
    theme_variants = [theme]
    for suffix in ["-dark", "-light", "-Dark", "-Light"]:
        if theme.endswith(suffix):
            theme_variants.append(theme[:-len(suffix)])

    base_dirs = [os.path.expanduser("~/.local/share/icons"), "/usr/share/icons"]
    sizes = ["48x48", "64x64", "128x128", "256x256", "scalable", "32x32", "22x22", "16x16"]
    exts  = [".svg", ".png", ".xpm"]

    # estruturas de pasta que diferentes temas usam
    subpaths = [
        "{size}/apps/{name}{ext}",   # hicolor padrão
        "apps/{size}/{name}{ext}",   # Numix
        "apps/scalable/{name}{ext}", # WhiteSur (ignora size)
    ]

    for base in base_dirs:
        for t in theme_variants:
            theme_dir = os.path.join(base, t)
            if not os.path.isdir(theme_dir):
                continue
            for size in sizes:
                for subpath in subpaths:
                    for ext in exts:
                        path = os.path.join(
                            theme_dir,
                            subpath.format(size=size, name=icon_name, ext=ext)
                        )
                        if os.path.isfile(path):
                            return path

    # fallback: pixmaps
    for ext in exts:
        path = f"/usr/share/pixmaps/{icon_name}{ext}"
        if os.path.isfile(path):
            return path

    return ""

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
    WP_CONF.parent.mkdir(parents=True, exist_ok=True)
    WP_CONF.write_text(
        "# Astrea Audio Settings — gerado automaticamente\n"
        "wireplumber.settings = {\n"
        f"  default.clock.rate          = {cfg['sample_rate']}\n"
        f"  default.clock.quantum       = {cfg['buffer_size']}\n"
        f"  default.clock.min-quantum   = 32\n"
        f"  default.clock.max-quantum   = 8192\n"
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
