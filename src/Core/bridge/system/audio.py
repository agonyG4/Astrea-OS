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

BRIDGE_DIR = Path(__file__).resolve().parents[1]


def _load_astrea_shared():
    import importlib.util
    spec = importlib.util.spec_from_file_location("astrea_shared_runtime", BRIDGE_DIR / "astrea_shared.py")
    module = importlib.util.module_from_spec(spec)
    assert spec and spec.loader
    spec.loader.exec_module(module)
    return module

ASTREA_SHARED = _load_astrea_shared()

# ── WirePlumber config path ───────────────────────────────────────────────────
WP_CONF = Path.home() / ".config/wireplumber/wireplumber.conf.d/50-astrea-audio.conf"
ALIASES_CONF = Path.home() / ".local/share/Astrea/System/config/audio-aliases.json"
HIDDEN_OUTPUTS_CONF = Path.home() / ".local/share/Astrea/System/config/audio-hidden-outputs.json"
SPATIAL_SINK = "effect_input.virtual-surround-7.1-hesuvi"
SPATIAL_OUTPUT_STREAM = "effect_output.virtual-surround-7.1-hesuvi"

# ── Helpers ───────────────────────────────────────────────────────────────────
def run(cmd: list) -> str:
    try:
        return subprocess.check_output(cmd, stderr=subprocess.DEVNULL, text=True)
    except Exception:
        return ""

def eprint(msg):
    print(msg, file=sys.stderr)

def read_json(path: Path, default):
    try:
        with Path(path).expanduser().open("r", encoding="utf-8") as handle:
            return json.load(handle)
    except (FileNotFoundError, json.JSONDecodeError, OSError):
        return default


def atomic_write_json(path: Path, payload, *, indent: int | None = 2, sort_keys: bool = False) -> None:
    ASTREA_SHARED.atomic_write_json(path, payload, indent=indent, sort_keys=sort_keys)


def atomic_write_text(path: Path, text: str) -> None:
    ASTREA_SHARED.atomic_write_text(path, text)


def application_dirs() -> list[Path]:
    dirs = [Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share")).expanduser() / "applications"]
    for entry in os.environ.get("XDG_DATA_DIRS", "/usr/local/share:/usr/share").split(":"):
        if entry:
            dirs.append(Path(entry).expanduser() / "applications")
    deduped = []
    seen = set()
    for path in dirs:
        key = str(path)
        if key not in seen:
            seen.add(key)
            deduped.append(path)
    return deduped


def parse_desktop_file(path: Path, *, source: str = "", require_exec: bool = False):
    return ASTREA_SHARED.parse_desktop_file(path, source=source, require_exec=require_exec)


def resolve_icon_path(icon_name: str) -> str:
    return ASTREA_SHARED.resolve_icon_path(icon_name)

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


def get_hidden_outputs() -> set[str]:
    data = read_json(HIDDEN_OUTPUTS_CONF, [])
    if not isinstance(data, list):
        return set()
    hidden = set()
    for name in data:
        try:
            hidden.add(validate_wp_string(str(name), field="device name"))
        except ValueError:
            continue
    return hidden


def save_hidden_output(name: str, hidden: bool) -> None:
    device_name = validate_wp_string(str(name), field="device name")
    outputs = get_hidden_outputs()
    if hidden:
        outputs.add(device_name)
    else:
        outputs.discard(device_name)
    atomic_write_json(HIDDEN_OUTPUTS_CONF, sorted(outputs), indent=None)


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
        if str(desc).strip().lower() in {"", "(null)", "null", "none"}:
            desc = name
        if name in aliases:
            desc = aliases[name]
        result.append({
            "index":       s.get("index"),
            "name":        name,
            "description": desc,
            "virtual":     props.get("node.virtual") == "true" or name == SPATIAL_SINK,
            "default":     False,
        })
    return result


def get_sink_inputs() -> list:
    raw = run(["pactl", "-f", "json", "list", "sink-inputs"])
    try:
        inputs = json.loads(raw)
    except Exception:
        return []
    return inputs if isinstance(inputs, list) else []


def get_clients() -> dict[str, dict]:
    raw = run(["pactl", "-f", "json", "list", "clients"])
    try:
        clients = json.loads(raw)
    except Exception:
        return {}
    if not isinstance(clients, list):
        return {}
    result = {}
    for client in clients:
        index = client.get("index")
        if index is None:
            continue
        result[str(index)] = client.get("properties", {}) or {}
    return result


def merged_input_properties(inp: dict, clients: dict[str, dict]) -> dict:
    props = dict(clients.get(str(inp.get("client", "")), {}))
    props.update(inp.get("properties", {}) or {})
    return props


def _sink_name_by_index(sinks: list, index) -> str:
    for sink in sinks:
        if sink.get("index") == index:
            return sink.get("name", "")
    return ""


def _spatial_output_input(inputs: list) -> dict | None:
    for inp in inputs:
        props = inp.get("properties", {})
        if props.get("node.name") == SPATIAL_OUTPUT_STREAM:
            return inp
    return None


def spatial_state(sinks: list, inputs: list, default_sink: str) -> dict:
    spatial_sink = next((s for s in sinks if s.get("name") == SPATIAL_SINK), None)
    physical = [s for s in sinks if s.get("name") != SPATIAL_SINK and not s.get("virtual")]
    output_input = _spatial_output_input(inputs)
    target_name = _sink_name_by_index(sinks, output_input.get("sink")) if output_input else ""
    if not target_name and physical:
        target_name = physical[0].get("name", "")
    target = next((s for s in physical if s.get("name") == target_name), None)
    return {
        "available": spatial_sink is not None,
        "enabled": default_sink == SPATIAL_SINK,
        "sink": SPATIAL_SINK,
        "target_sink": target_name,
        "target_description": (target or {}).get("description", ""),
        "output_index": output_input.get("index") if output_input else None,
    }


def build_outputs_state(sinks: list, spatial: dict, default_sink: str, hidden_names=None) -> dict:
    hidden_names = set(hidden_names if hidden_names is not None else get_hidden_outputs())
    target_sink = spatial.get("target_sink", "")
    spatial_enabled = spatial.get("enabled") is True
    all_outputs = []
    visible_outputs = []
    hidden_outputs = []

    for sink in sinks:
        name = sink.get("name", "")
        if not name or name == SPATIAL_SINK or sink.get("virtual"):
            continue

        item = dict(sink)
        item["default"] = name == default_sink and not spatial_enabled
        item["spatial_target"] = spatial_enabled and name == target_sink
        item["spatial_enabled"] = item["spatial_target"]
        item["effective_default"] = item["default"] or item["spatial_target"]
        item["hidden"] = name in hidden_names
        all_outputs.append(item)

        if item["hidden"] and not item["effective_default"]:
            hidden_outputs.append(item)
        else:
            visible_outputs.append(item)

    return {
        "all": all_outputs,
        "visible": visible_outputs,
        "hidden": hidden_outputs,
        "hidden_names": sorted(hidden_names),
    }


def public_outputs(sinks: list, spatial: dict, default_sink: str) -> list:
    return build_outputs_state(sinks, spatial, default_sink)["visible"]


def hidden_output_items(sinks: list) -> list:
    return build_outputs_state(sinks, {}, "")["hidden"]

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


def _steam_roots() -> list[Path]:
    candidates = [
        Path.home() / ".local/share/Steam",
        Path.home() / ".steam/steam",
    ]
    return [path for path in candidates if path.exists()]


def _parse_steam_manifest(path: Path) -> dict[str, str]:
    try:
        text = path.read_text(encoding="utf-8", errors="ignore")
    except OSError:
        return {}
    fields = {}
    for key in ("appid", "name", "installdir"):
        match = re.search(rf'"{re.escape(key)}"\s+"([^"]+)"', text)
        if match:
            fields[key] = match.group(1)
    return fields


def _process_environ(pid: str) -> dict[str, str]:
    try:
        raw = Path(f"/proc/{int(pid)}/environ").read_bytes()
    except (OSError, ValueError):
        return {}
    result = {}
    for item in raw.split(b"\0"):
        if not item or b"=" not in item:
            continue
        key, value = item.split(b"=", 1)
        try:
            result[key.decode("utf-8", errors="ignore")] = value.decode("utf-8", errors="ignore")
        except UnicodeDecodeError:
            continue
    return result


def _steam_icon_for_appid(appid: str) -> str:
    appid = str(appid or "").strip()
    if not appid:
        return ""
    for root in _steam_roots():
        cache = root / "appcache/librarycache" / appid
        patterns = [
            "**/logo.png",
            "**/header.jpg",
            "**/library_header.jpg",
            "**/library_600x900.jpg",
        ]
        for pattern in patterns:
            matches = sorted(cache.glob(pattern))
            if matches:
                return str(matches[0])
    return ""


def _steam_appid_for_process(props: dict) -> str:
    pid = str(props.get("application.process.id", "")).strip()
    if not pid:
        return ""
    env = _process_environ(pid)
    return (env.get("SteamAppId")
            or env.get("SteamGameId")
            or env.get("STEAM_COMPAT_APP_ID")
            or env.get("SteamOverlayGameId")
            or "")


def _steam_icon_for_app(name: str, props: dict) -> str:
    icon = _steam_icon_for_appid(_steam_appid_for_process(props))
    if icon:
        return icon
    app_name = str(name or props.get("application.name", "")).strip().casefold()
    if not app_name:
        return ""
    for root in _steam_roots():
        for manifest in (root / "steamapps").glob("appmanifest_*.acf"):
            fields = _parse_steam_manifest(manifest)
            if fields.get("name", "").casefold() != app_name:
                continue
            appid = fields.get("appid", "")
            if not appid:
                continue
            icon = _steam_icon_for_appid(appid)
            if icon:
                return icon
    return ""


def _is_system_audio_stream(props: dict) -> bool:
    text = " ".join(str(props.get(key, "")) for key in (
        "application.name",
        "device.description",
        "media.name",
        "node.name",
        "module-stream-restore.id",
    )).lower()
    if props.get("node.virtual") == "true" or props.get("node.passive") == "true":
        return True
    if "astrea spatial audio" in text:
        return True
    if "virtual-surround" in text or "filter-chain" in text:
        return True
    return False


def _desktop_icon_for_app(name: str, props: dict) -> str:
    needles = {
        str(name or "").strip().lower(),
        str(props.get("application.process.binary", "")).strip().lower(),
        str(props.get("application.name", "")).strip().lower(),
        str(props.get("node.name", "")).strip().lower(),
    }
    needles = {n for n in needles if n}
    if not needles:
        return ""

    best_icon = ""
    best_score = 0
    for app_dir in application_dirs():
        try:
            entries = list(app_dir.glob("*.desktop"))
        except OSError:
            continue
        for path in entries:
            entry = parse_desktop_file(path, source=str(app_dir), require_exec=False)
            if not entry:
                continue
            hay = " ".join(str(entry.get(key, "")) for key in ("id", "name", "exec")).lower()
            score = 0
            for needle in needles:
                compact = needle.removesuffix("-bin")
                if needle and needle in hay:
                    score = max(score, 2)
                if compact and compact != needle and compact in hay:
                    score = max(score, 1)
            if score > best_score:
                best_score = score
                best_icon = entry.get("icon", "")
    return best_icon


def _app_group_key(name: str, props: dict, inp: dict) -> str:
    normalized = str(name or "").strip().casefold()
    process_id = str(props.get("application.process.id", "")).strip()
    if process_id and normalized:
        return f"pid:{process_id}:{normalized}"
    client_id = str(props.get("client.id") or inp.get("client") or "").strip()
    if client_id and normalized:
        return f"client:{client_id}:{normalized}"
    restore_id = str(props.get("module-stream-restore.id", "")).strip().casefold()
    if restore_id:
        return f"restore:{restore_id}"
    return f"input:{inp.get('index', 0)}"


def _resolve_app_icon(name: str, props: dict) -> tuple[str, str]:
    explicit_icon = str(props.get("application.icon-name")
                        or props.get("application.icon_name")
                        or props.get("media.icon-name")
                        or "").strip()
    if explicit_icon:
        icon_path = resolve_icon_path(explicit_icon)
        if icon_path:
            return explicit_icon, icon_path

    guessed_icon = _guess_icon(name)
    if guessed_icon != "audio-x-generic":
        icon_path = resolve_icon_path(guessed_icon)
        if icon_path:
            return guessed_icon, icon_path

    icon_path = _steam_icon_for_app(name, props)
    if icon_path:
        return explicit_icon or guessed_icon, icon_path

    desktop_icon = _desktop_icon_for_app(name, props)
    if desktop_icon:
        icon_path = resolve_icon_path(desktop_icon)
        if icon_path:
            return desktop_icon, icon_path

    icon_name = explicit_icon or guessed_icon or "audio-x-generic"
    icon_path = resolve_icon_path(icon_name) if icon_name else ""
    return icon_name, icon_path


def get_apps() -> list:
    inputs = get_sink_inputs()
    clients = get_clients()
    grouped = {}
    for inp in inputs:
        props = merged_input_properties(inp, clients)
        if _is_system_audio_stream(props):
            continue
        name  = (props.get("application.name")
                 or props.get("media.name")
                 or props.get("node.name")
                 or f"App #{inp.get('index', '?')}")
        key = _app_group_key(name, props, inp)
        volume = _avg_volume(inp.get("volume", {}))
        stream = {
            "index": inp.get("index", 0),
            "volume": volume,
            "muted": inp.get("mute", False),
        }
        icon_name, icon_path = _resolve_app_icon(name, props)
        if key not in grouped:
            grouped[key] = {
                "index": inp.get("index", 0),
                "indexes": [],
                "name": name,
                "icon": icon_path,
                "icon_name": icon_name,
                "volume_values": [],
                "muted_values": [],
                "streams": [],
            }
        item = grouped[key]
        if icon_path and not item["icon"]:
            item["icon"] = icon_path
        if icon_name and not item["icon_name"]:
            item["icon_name"] = icon_name
        item["indexes"].append(inp.get("index", 0))
        item["volume_values"].append(volume)
        item["muted_values"].append(bool(inp.get("mute", False)))
        item["streams"].append(stream)

    result = []
    for item in grouped.values():
        volumes = item.pop("volume_values", [])
        muted_values = item.pop("muted_values", [])
        streams = item.get("streams", [])
        result.append({
            "index": item["index"],
            "indexes": item["indexes"],
            "name":   item.get("name", ""),
            "icon":   item.get("icon", ""),
            "icon_name": item.get("icon_name", ""),
            "volume": round(sum(volumes) / len(volumes), 3) if volumes else 0.0,
            "muted":  bool(muted_values) and all(muted_values),
            "stream_count": len(streams),
        })
    return sorted(result, key=lambda app: str(app.get("name", "")).casefold())

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
    app_indexes = cfg.get("app_indexes")
    if app_indexes is None and "app_index" in cfg:
        app_indexes = [cfg["app_index"]]
    if isinstance(app_indexes, list) and "volume" in cfg:
        vol = max(0.0, min(1.5, float(cfg["volume"])))
        for app_index in app_indexes:
            run(["pactl", "set-sink-input-volume", str(app_index), f"{int(vol*100)}%"])
        return
    if isinstance(app_indexes, list) and "muted" in cfg:
        muted = "1" if cfg["muted"] else "0"
        for app_index in app_indexes:
            run(["pactl", "set-sink-input-mute", str(app_index), muted])
        return
    if "app_index" in cfg and "volume" in cfg:
        vol = max(0.0, min(1.5, float(cfg["volume"])))
        run(["pactl", "set-sink-input-volume", str(cfg["app_index"]), f"{int(vol*100)}%"])
    if "app_index" in cfg and "muted" in cfg:
        run(["pactl", "set-sink-input-mute", str(cfg["app_index"]),
             "1" if cfg["muted"] else "0"])
    if "card" in cfg and "profile" in cfg:
        run(["pactl", "set-card-profile", cfg["card"], cfg["profile"]])
    if "spatial_enabled" in cfg:
        if cfg["spatial_enabled"]:
            target = cfg.get("target_sink")
            if target:
                move_spatial_target(str(target))
            run(["pactl", "set-default-sink", SPATIAL_SINK])
        else:
            target = str(cfg.get("target_sink") or current_spatial_target() or first_physical_sink())
            if target:
                run(["pactl", "set-default-sink", target])
    if "set_default_sink" in cfg:
        target = str(cfg["set_default_sink"])
        if target == SPATIAL_SINK:
            run(["pactl", "set-default-sink", SPATIAL_SINK])
        elif get_default_sink() == SPATIAL_SINK:
            move_spatial_target(target)
            run(["pactl", "set-default-sink", SPATIAL_SINK])
        else:
            run(["pactl", "set-default-sink", target])
    if "rename" in cfg and "name" in cfg:
        save_alias(cfg["name"], cfg["rename"])
    if "hide_output" in cfg:
        save_hidden_output(cfg["hide_output"], True)
    if "show_output" in cfg:
        save_hidden_output(cfg["show_output"], False)
    if "sample_rate" in cfg or "buffer_size" in cfg:
        wp = get_wp_config()
        if "sample_rate" in cfg:
            wp["sample_rate"] = int(cfg["sample_rate"])
        if "buffer_size" in cfg:
            wp["buffer_size"] = int(cfg["buffer_size"])
        _write_wp_conf(wp)
        print("wp_restart_required: true")


def current_spatial_target() -> str:
    sinks = get_sinks()
    inputs = get_sink_inputs()
    return spatial_state(sinks, inputs, get_default_sink()).get("target_sink", "")


def first_physical_sink() -> str:
    for sink in get_sinks():
        name = sink.get("name", "")
        if name and name != SPATIAL_SINK:
            return name
    return ""


def move_spatial_target(target_sink: str) -> None:
    target_sink = validate_wp_string(target_sink, field="target sink")
    inputs = get_sink_inputs()
    spatial_output = _spatial_output_input(inputs)
    if not spatial_output:
        eprint("[spatial] output stream not found")
        return
    run(["pactl", "move-sink-input", str(spatial_output.get("index")), target_sink])

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
            "outputs": [],
            "apps":  [],
            "spatial": {"available": False, "enabled": False, "sink": SPATIAL_SINK, "target_sink": ""},
            "wp":    {"sample_rate": 48000, "buffer_size": 1024},
        }
        try:
            default_sink = get_default_sink()
            sinks = get_sinks()
            inputs = get_sink_inputs()
            for s in sinks:
                s["default"] = (s["name"] == default_sink)
            out["sinks"] = sinks
            out["spatial"] = spatial_state(sinks, inputs, default_sink)
            outputs_state = build_outputs_state(sinks, out["spatial"], default_sink)
            out["outputs_state"] = outputs_state
            out["outputs"] = outputs_state["visible"]
            out["hidden_outputs"] = outputs_state["hidden_names"]
            out["hidden_output_items"] = outputs_state["hidden"]
        except Exception as e:
            eprint(f"[sinks] {e}")
        try:
            # Apps/icons are loaded through the dedicated `apps` route so the
            # page can render device controls without waiting on desktop icon
            # lookup.
            out["apps"] = []
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
