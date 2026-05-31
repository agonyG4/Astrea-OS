#!/usr/bin/env python3
import requests
import json
import os
import sys
import datetime
import argparse
import hashlib
import re
import subprocess
import time
import unicodedata
import tempfile
import fcntl
import shutil
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry

# ── Config ────────────────────────────────────────────────────────────────────
STATE_DIR = os.environ.get(
    "ASTREA_WEATHER_STATE_DIR",
    os.path.expanduser("~/.local/state/Astrea/weather"),
)
DEFAULT_CACHE_DIR = os.path.join(
    os.environ.get("XDG_CACHE_HOME", os.path.expanduser("~/.cache")),
    "weather",
)
CACHE_DIR = os.environ.get("ASTREA_WEATHER_CACHE_DIR", DEFAULT_CACHE_DIR)
_CACHE_READY = False
CACHE_TTL  = 30 * 60
STALE_CACHE_TTL = 24 * 60 * 60
COORDS_CACHE_TTL = 30 * 24 * 60 * 60
IP_LOCATION_CACHE_TTL = 6 * 60 * 60
SYSTEM_LOCATION_CACHE_TTL = 15 * 60
REVERSE_GEOCODE_CACHE_TTL = 30 * 24 * 60 * 60
HISTORY_CACHE_TTL = 24 * 60 * 60
HISTORY_CACHE_RETENTION = 3 * 24 * 60 * 60
FORECAST_CACHE_RETENTION = 2 * 24 * 60 * 60
LOCK_CACHE_RETENTION = 24 * 60 * 60
CACHE_PRUNE_INTERVAL = 6 * 60 * 60
DEFAULT_CITY = "Itajaí"
MAX_FORECAST_DAYS = 16
CACHE_VERSION = 10
INMET_ALERTS_URL = "https://apiprevmet3.inmet.gov.br/avisos/ativos"
HTTP_TIMEOUT = 10
USER_AGENT = "AstreaWeather/1.0 (+https://open-meteo.com/)"
NOTIFY_STATE_PATH = os.environ.get(
    "ASTREA_WEATHER_NOTIFY_STATE",
    os.path.join(STATE_DIR, "alerts-seen.json"),
)
SETTINGS_PATH = os.environ.get(
    "ASTREA_WEATHER_SETTINGS_STATE",
    os.path.join(STATE_DIR, "settings.json"),
)
SYSTEM_SETTINGS_PATH = os.environ.get(
    "ASTREA_SYSTEM_SETTINGS_PATH",
    os.path.expanduser("~/.config/AstreaOS/system/settings.json"),
)
ASTREA_NOTIFY_PATH = os.environ.get(
    "ASTREA_NOTIFY",
    os.path.expanduser("~/.local/share/Astrea/System/services/astrea_notify.py"),
)
NOTIFY_STATE_TTL = 14 * 24 * 60 * 60
STATE_TO_UF = {
    "Acre": "AC",
    "Alagoas": "AL",
    "Amapá": "AP",
    "Amazonas": "AM",
    "Bahia": "BA",
    "Ceará": "CE",
    "Distrito Federal": "DF",
    "Espírito Santo": "ES",
    "Goiás": "GO",
    "Maranhão": "MA",
    "Mato Grosso": "MT",
    "Mato Grosso do Sul": "MS",
    "Minas Gerais": "MG",
    "Pará": "PA",
    "Paraíba": "PB",
    "Paraná": "PR",
    "Pernambuco": "PE",
    "Piauí": "PI",
    "Rio de Janeiro": "RJ",
    "Rio Grande do Norte": "RN",
    "Rio Grande do Sul": "RS",
    "Rondônia": "RO",
    "Roraima": "RR",
    "Santa Catarina": "SC",
    "São Paulo": "SP",
    "Sergipe": "SE",
    "Tocantins": "TO",
}
COUNTRY_ALIASES = {
    "br": "BR",
    "bra": "BR",
    "brasil": "BR",
    "brazil": "BR",
    "eua": "US",
    "usa": "US",
    "us": "US",
    "united states": "US",
    "united states of america": "US",
    "estados unidos": "US",
    "fr": "FR",
    "fra": "FR",
    "france": "FR",
    "franca": "FR",
    "it": "IT",
    "italy": "IT",
    "italia": "IT",
    "pt": "PT",
    "portugal": "PT",
    "es": "ES",
    "spain": "ES",
    "espanha": "ES",
    "de": "DE",
    "germany": "DE",
    "alemanha": "DE",
    "gb": "GB",
    "uk": "GB",
    "united kingdom": "GB",
    "reino unido": "GB",
    "jp": "JP",
    "japan": "JP",
    "japao": "JP",
    "ca": "CA",
    "canada": "CA",
    "ar": "AR",
    "argentina": "AR",
    "cl": "CL",
    "chile": "CL",
    "uy": "UY",
    "uruguay": "UY",
}
COUNTRY_TIME_FORMAT_DEFAULTS = {
    "US": "12h",
    "CA": "12h",
    "PH": "12h",
    "AU": "12h",
    "NZ": "12h",
    "IN": "12h",
}


class WeatherError(Exception):
    """Erro controlado para mensagens amigáveis na CLI."""

# ── Helpers ───────────────────────────────────────────────────────────────────
def make_session() -> requests.Session:
    session = requests.Session()
    retries = Retry(
        total=2,
        connect=2,
        read=2,
        backoff_factor=0.35,
        status_forcelist=(429, 500, 502, 503, 504),
        allowed_methods=frozenset(["GET"]),
        raise_on_status=False,
    )
    adapter = HTTPAdapter(max_retries=retries)
    session.mount("https://", adapter)
    session.mount("http://", adapter)
    session.headers.update({
        "Accept": "application/json",
        "User-Agent": USER_AGENT,
    })
    return session


HTTP = make_session()


def cache_slug(city: str) -> str:
    slug = normalize_text(city).replace(" ", "_")
    slug = re.sub(r"[^a-z0-9_\-]", "", slug)
    return slug or "unknown"


def cache_dir_candidates() -> list[str]:
    candidates = [
        CACHE_DIR,
        os.path.join(STATE_DIR, "cache"),
        os.path.join(tempfile.gettempdir(), f"astrea-weather-{os.getuid()}"),
    ]
    unique: list[str] = []
    for path in candidates:
        if path and path not in unique:
            unique.append(path)
    return unique


def ensure_cache_dir() -> None:
    global CACHE_DIR, _CACHE_READY
    if _CACHE_READY:
        return

    last_error: OSError | None = None
    for candidate in cache_dir_candidates():
        try:
            os.makedirs(candidate, exist_ok=True)
            probe = os.path.join(candidate, f".write-test-{os.getpid()}")
            with open(probe, "w", encoding="utf-8") as f:
                f.write("")
            os.remove(probe)
            CACHE_DIR = candidate
            _CACHE_READY = True
            prune_weather_cache()
            return
        except OSError as exc:
            last_error = exc

    raise WeatherError(f"cache indisponivel: {last_error}") from last_error


def prune_weather_cache() -> None:
    marker = os.path.join(CACHE_DIR, ".last-prune")
    now = datetime.datetime.now().timestamp()
    marker_age = file_age(marker)
    if marker_age is not None and marker_age < CACHE_PRUNE_INTERVAL:
        return

    for name in os.listdir(CACHE_DIR):
        path = os.path.join(CACHE_DIR, name)
        if not os.path.isfile(path):
            continue
        age = now - os.path.getmtime(path)
        should_remove = (
            (name.startswith("history_") and age > HISTORY_CACHE_RETENTION)
            or (re.match(r"^[a-z0-9_\-]+_\d+d\.json$", name) and age > FORECAST_CACHE_RETENTION)
            or (name.startswith(".") and name.endswith(".lock") and age > LOCK_CACHE_RETENTION)
        )
        if should_remove:
            try:
                os.remove(path)
            except OSError:
                pass

    try:
        with open(marker, "w", encoding="utf-8") as f:
            f.write(str(int(now)))
    except OSError:
        pass


def cache_path(city: str, days: int) -> str:
    ensure_cache_dir()
    return os.path.join(CACHE_DIR, f"{cache_slug(city)}_{days}d.json")


def lock_path(city: str, days: int) -> str:
    ensure_cache_dir()
    return os.path.join(CACHE_DIR, f".{cache_slug(city)}_{days}d.lock")


def aux_cache_path(kind: str, key: str) -> str:
    ensure_cache_dir()
    return os.path.join(CACHE_DIR, f"{kind}_{cache_slug(key)}.json")


def normalize_text(value: str) -> str:
    normalized = unicodedata.normalize("NFKD", value or "")
    without_accents = "".join(ch for ch in normalized if not unicodedata.combining(ch))
    return re.sub(r"\s+", " ", without_accents).strip().lower()


def country_code_hint(value: str) -> str:
    key = normalize_text(value)
    if len(key) == 2 and key.isalpha():
        return key.upper()
    return COUNTRY_ALIASES.get(key, "")


def parse_location_query(city: str) -> tuple[str, str]:
    parts = [part.strip() for part in str(city or "").split(",") if part.strip()]
    if not parts:
        return DEFAULT_CITY, ""
    country = country_code_hint(parts[-1]) if len(parts) > 1 else ""
    city_name = parts[0] if country else str(city or "").strip()
    return city_name or DEFAULT_CITY, country


def file_age(path: str) -> float | None:
    if not os.path.exists(path):
        return None
    return datetime.datetime.now().timestamp() - os.path.getmtime(path)


def load_json(path: str) -> dict | None:
    try:
        with open(path, "r", encoding="utf-8") as f:
            return json.load(f)
    except (json.JSONDecodeError, OSError):
        return None


def write_json_atomic(path: str, payload: dict) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    fd, tmp = tempfile.mkstemp(
        dir=os.path.dirname(path),
        prefix=f".{os.path.basename(path)}.",
        suffix=".tmp"
    )
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            json.dump(payload, f, ensure_ascii=False)
        os.replace(tmp, path)
    finally:
        if os.path.exists(tmp):
            os.remove(tmp)


def normalize_country_code(value: str) -> str:
    code = str(value or "").strip().upper().replace("-", "_")
    return code if len(code) == 2 and code.isalpha() else "BR"


def load_region_preferences() -> dict:
    settings = load_json(SYSTEM_SETTINGS_PATH)
    region = settings.get("region", {}) if isinstance(settings, dict) else {}
    if not isinstance(region, dict):
        region = {}
    time_format = str(region.get("time_format") or "system").strip().lower()
    if time_format not in ("system", "24h", "12h"):
        time_format = "system"
    return {
        "country_code": normalize_country_code(region.get("country_code", "BR")),
        "time_format": time_format,
        "automatic_location": bool(region.get("automatic_location", True)),
    }


def automatic_location_enabled() -> bool:
    return bool(load_region_preferences().get("automatic_location", True))


def effective_time_format(region: dict | None = None) -> str:
    prefs = region or load_region_preferences()
    selected = str(prefs.get("time_format") or "system").lower()
    if selected in ("12h", "24h"):
        return selected
    country_code = normalize_country_code(prefs.get("country_code", "BR"))
    return COUNTRY_TIME_FORMAT_DEFAULTS.get(country_code, "24h")


def format_local_time(value: str, region: dict | None = None) -> str:
    try:
        dt = datetime.datetime.fromisoformat(value)
    except (TypeError, ValueError):
        return ""
    if effective_time_format(region) == "12h":
        hour = dt.hour % 12 or 12
        suffix = "AM" if dt.hour < 12 else "PM"
        return f"{hour}:{dt.minute:02d} {suffix}"
    return dt.strftime("%H:%M")


def load_weather_cache(city: str, days: int, max_age: int) -> dict | None:
    path = cache_path(city, days)
    age = file_age(path)
    if age is None or age >= max_age:
        return None
    cached = load_json(path)
    if not cached:
        return None
    if cached.get("schema_version") == CACHE_VERSION and len(cached.get("weekly", [])) >= days:
        return cached
    return None


def cached_get_json(url: str, params: dict | None = None, timeout: int = HTTP_TIMEOUT) -> dict:
    response = HTTP.get(url, params=params or {}, timeout=timeout)
    response.raise_for_status()
    return response.json()


def safe_round(value, default: int = 0) -> int:
    try:
        if value is None:
            return default
        return round(value)
    except (TypeError, ValueError):
        return default


def safe_number(value, default=0):
    return default if value is None else value


def as_list(value) -> list:
    if isinstance(value, list):
        return value
    if value in (None, ""):
        return []
    return [str(value)]


def timestamp_now() -> str:
    return datetime.datetime.now(datetime.timezone.utc).isoformat(timespec="seconds")


def pick_geocode_result(results: list[dict], city: str) -> dict:
    city_name, country_hint = parse_location_query(city)
    city_key = normalize_text(city_name)
    known_states = {normalize_text(k) for k in STATE_TO_UF}

    def score(item: dict) -> tuple[int, int, int, int]:
        name = normalize_text(item.get("name", ""))
        country = item.get("country_code", "")
        admin1 = normalize_text(item.get("admin1", ""))
        exact_city = 0 if name == city_key else 1
        country_match = 0 if country_hint and country == country_hint else 1 if country_hint else 0
        known_state = 0 if admin1 in known_states else 1
        return (country_match, exact_city, known_state, -int(item.get("population") or 0))

    return sorted(results, key=score)[0]


def get_coords(city: str) -> dict:
    path = aux_cache_path("coords", city)
    age = file_age(path)
    cached = load_json(path) if age is not None and age < COORDS_CACHE_TTL else None
    if cached and "country_code" in cached:
        return cached

    city_name, country_hint = parse_location_query(city)
    params = {"name": city_name, "count": 10, "language": "pt", "format": "json"}
    if country_hint:
        params["countryCode"] = country_hint
    data = cached_get_json(
        "https://geocoding-api.open-meteo.com/v1/search",
        params
    )
    if "results" not in data or not data["results"]:
        raise WeatherError(f"Cidade nao encontrada: {city}")
    r = pick_geocode_result(data["results"], city)
    result = {
        "name":      r["name"],
        "admin1":    r.get("admin1", ""),
        "country":   r.get("country", ""),
        "country_code": r.get("country_code", ""),
        "latitude":  r["latitude"],
        "longitude": r["longitude"],
        "timezone":  r.get("timezone", "auto")
    }
    write_json_atomic(path, result)
    return result


def reverse_geocode_location(latitude, longitude, fallback_name: str = "") -> dict:
    key = f"{round(float(latitude), 3)}_{round(float(longitude), 3)}"
    path = aux_cache_path("reverse", key)
    age = file_age(path)
    cached = load_json(path) if age is not None and age < REVERSE_GEOCODE_CACHE_TTL else None
    if valid_location(cached):
        return cached

    try:
        payload = cached_get_json(
            "https://nominatim.openstreetmap.org/reverse",
            {
                "format": "jsonv2",
                "lat": latitude,
                "lon": longitude,
                "zoom": 10,
                "addressdetails": 1,
                "accept-language": "pt-BR,pt,en",
            },
            timeout=8,
        )
        address = payload.get("address", {}) if isinstance(payload, dict) else {}
        city = (
            address.get("city")
            or address.get("town")
            or address.get("village")
            or address.get("municipality")
            or fallback_name
            or "Current location"
        )
        result = {
            "name": str(city).strip(),
            "admin1": str(address.get("state") or "").strip(),
            "country": str(address.get("country") or "").strip(),
            "country_code": str(address.get("country_code") or "").upper(),
            "latitude": latitude,
            "longitude": longitude,
            "timezone": "auto",
            "location_source": "system",
        }
        if not result["country_code"]:
            result["country_code"] = load_region_preferences()["country_code"]
        write_json_atomic(path, result)
        return result
    except (requests.RequestException, WeatherError, TypeError, ValueError):
        prefs = load_region_preferences()
        return {
            "name": fallback_name or "Current location",
            "admin1": "",
            "country": "",
            "country_code": prefs["country_code"],
            "latitude": latitude,
            "longitude": longitude,
            "timezone": "auto",
            "location_source": "system",
        }


def gdbus_call(args: list[str], timeout: float = 5.0) -> str:
    if not shutil.which("gdbus"):
        raise WeatherError("GeoClue unavailable: gdbus not found")
    try:
        result = subprocess.run(
            ["gdbus", "call", "--system", "--dest", "org.freedesktop.GeoClue2", *args],
            capture_output=True,
            check=False,
            text=True,
            timeout=timeout,
        )
    except (OSError, subprocess.SubprocessError) as exc:
        raise WeatherError(f"GeoClue unavailable: {exc}") from exc
    if result.returncode != 0:
        detail = (result.stderr or result.stdout or "GeoClue call failed").strip()
        raise WeatherError(detail)
    return result.stdout.strip()


def extract_object_path(value: str) -> str:
    match = re.search(r"/org/freedesktop/GeoClue2/[A-Za-z0-9_/\-]+", value or "")
    if not match:
        raise WeatherError("GeoClue returned no object path")
    return match.group(0)


def extract_dbus_number(value: str) -> float:
    match = re.search(r"[-+]?\d+(?:\.\d+)?", value or "")
    if not match:
        raise WeatherError("GeoClue returned no numeric coordinate")
    return float(match.group(0))


def extract_dbus_string(value: str) -> str:
    match = re.search(r"'([^']*)'", value or "")
    return match.group(1) if match else ""


def get_system_location() -> dict:
    path = aux_cache_path("system_location", "current")
    age = file_age(path)
    cached = load_json(path) if age is not None and age < SYSTEM_LOCATION_CACHE_TTL else None
    if valid_location(cached):
        return cached

    client_out = gdbus_call([
        "--object-path", "/org/freedesktop/GeoClue2/Manager",
        "--method", "org.freedesktop.GeoClue2.Manager.CreateClient",
    ])
    client_path = extract_object_path(client_out)

    try:
        gdbus_call([
            "--object-path", client_path,
            "--method", "org.freedesktop.DBus.Properties.Set",
            "org.freedesktop.GeoClue2.Client",
            "DesktopId",
            "<'astrea-weather'>",
        ])
        gdbus_call([
            "--object-path", client_path,
            "--method", "org.freedesktop.DBus.Properties.Set",
            "org.freedesktop.GeoClue2.Client",
            "RequestedAccuracyLevel",
            "<uint32 4>",
        ])
    except WeatherError:
        pass

    gdbus_call([
        "--object-path", client_path,
        "--method", "org.freedesktop.GeoClue2.Client.Start",
    ], timeout=8)
    location_out = gdbus_call([
        "--object-path", client_path,
        "--method", "org.freedesktop.DBus.Properties.Get",
        "org.freedesktop.GeoClue2.Client",
        "Location",
    ], timeout=8)
    location_path = extract_object_path(location_out)
    lat = extract_dbus_number(gdbus_call([
        "--object-path", location_path,
        "--method", "org.freedesktop.DBus.Properties.Get",
        "org.freedesktop.GeoClue2.Location",
        "Latitude",
    ]))
    lon = extract_dbus_number(gdbus_call([
        "--object-path", location_path,
        "--method", "org.freedesktop.DBus.Properties.Get",
        "org.freedesktop.GeoClue2.Location",
        "Longitude",
    ]))
    description = extract_dbus_string(gdbus_call([
        "--object-path", location_path,
        "--method", "org.freedesktop.DBus.Properties.Get",
        "org.freedesktop.GeoClue2.Location",
        "Description",
    ]))
    result = reverse_geocode_location(lat, lon, description)
    write_json_atomic(path, result)
    return result


def valid_location(loc: dict | None) -> bool:
    if not isinstance(loc, dict):
        return False
    return (
        bool(str(loc.get("name") or "").strip())
        and loc.get("latitude") is not None
        and loc.get("longitude") is not None
    )


def ipapi_location(payload: dict) -> dict:
    if payload.get("error"):
        raise WeatherError(str(payload.get("reason") or "IP geolocation failed"))
    return {
        "name": str(payload.get("city") or "").strip(),
        "admin1": str(payload.get("region") or "").strip(),
        "country": str(payload.get("country_name") or "").strip(),
        "country_code": str(payload.get("country_code") or "").upper(),
        "latitude": payload.get("latitude"),
        "longitude": payload.get("longitude"),
        "timezone": payload.get("timezone") or "auto",
        "location_source": "ip",
    }


def ipwhois_location(payload: dict) -> dict:
    if payload.get("success") is False:
        raise WeatherError(str(payload.get("message") or "IP geolocation failed"))
    timezone = payload.get("timezone")
    timezone_id = timezone.get("id") if isinstance(timezone, dict) else timezone
    return {
        "name": str(payload.get("city") or "").strip(),
        "admin1": str(payload.get("region") or "").strip(),
        "country": str(payload.get("country") or "").strip(),
        "country_code": str(payload.get("country_code") or "").upper(),
        "latitude": payload.get("latitude"),
        "longitude": payload.get("longitude"),
        "timezone": timezone_id or "auto",
        "location_source": "ip",
    }


def get_ip_location() -> dict:
    path = aux_cache_path("ip_location", "current")
    age = file_age(path)
    cached = load_json(path) if age is not None and age < IP_LOCATION_CACHE_TTL else None
    if valid_location(cached):
        return cached

    providers = (
        ("https://ipapi.co/json/", ipapi_location),
        ("https://ipwho.is/", ipwhois_location),
    )
    errors: list[str] = []
    for url, parser in providers:
        try:
            loc = parser(cached_get_json(url, timeout=6))
            if not valid_location(loc):
                raise WeatherError("IP geolocation returned an incomplete location")
            write_json_atomic(path, loc)
            return loc
        except (requests.RequestException, WeatherError, TypeError, ValueError) as exc:
            errors.append(str(exc))

    raise WeatherError("; ".join(errors) or "nao foi possivel detectar localizacao por IP")


def resolve_location(city: str) -> dict:
    if str(city or "").strip():
        return get_coords(city)
    if not automatic_location_enabled():
        raise WeatherError("Localizacao automatica desativada. Escolha uma cidade nas configuracoes do Weather.")
    try:
        return get_system_location()
    except (requests.RequestException, WeatherError, TypeError, ValueError):
        pass
    try:
        return get_ip_location()
    except (requests.RequestException, WeatherError, TypeError, ValueError):
        fallback = get_coords(DEFAULT_CITY)
        fallback["location_source"] = "default"
        return fallback


def fetch_inmet_alerts(city: str, state: str = "") -> list[dict]:
    try:
        payload = cached_get_json(INMET_ALERTS_URL, timeout=8)
    except Exception:
        return []

    city_key = normalize_text(city)
    uf = STATE_TO_UF.get(state, "")
    city_with_uf = normalize_text(f"{city} - {uf}") if uf else ""
    matches: list[dict] = []
    seen_ids: set[str] = set()

    for group in payload.values() if isinstance(payload, dict) else []:
        if not isinstance(group, list):
            continue

        for item in group:
            if not isinstance(item, dict):
                continue

            municipios = normalize_text(item.get("municipios", ""))
            if city_with_uf and city_with_uf not in municipios:
                continue
            if not city_with_uf and city_key not in municipios:
                continue

            alert_id = str(item.get("id") or "")
            if alert_id and alert_id in seen_ids:
                continue
            if alert_id:
                seen_ids.add(alert_id)

            matches.append({
                "id": item.get("id"),
                "title": item.get("descricao", "Aviso meteorológico"),
                "severity": item.get("severidade", ""),
                "color": item.get("aviso_cor", "#F96602"),
                "start": item.get("inicio", ""),
                "end": item.get("fim", ""),
                "risks": as_list(item.get("riscos")),
                "instructions": as_list(item.get("instrucoes")),
                "source": "INMET",
            })

    return matches


def alert_sources_for_location(loc: dict) -> list[dict]:
    country_code = str(loc.get("country_code") or "").upper()
    if country_code == "BR":
        return [{"id": "inmet", "name": "INMET", "country_code": "BR"}]
    return []


def fetch_weather_alerts(loc: dict) -> list[dict]:
    alerts: list[dict] = []
    for source in alert_sources_for_location(loc):
        if source["id"] == "inmet":
            alerts.extend(fetch_inmet_alerts(loc.get("name", ""), loc.get("admin1", "")))
    return alerts


def alert_stable_id(alert: dict) -> str:
    for key in ("id", "identifier", "event_id"):
        value = alert.get(key)
        if value not in (None, ""):
            return str(value)

    fingerprint = {
        "title": alert.get("title", ""),
        "severity": alert.get("severity", ""),
        "start": alert.get("start", ""),
        "end": alert.get("end", ""),
        "risks": alert.get("risks", []),
        "instructions": alert.get("instructions", []),
        "source": alert.get("source", ""),
    }
    raw = json.dumps(fingerprint, ensure_ascii=False, sort_keys=True)
    return hashlib.sha1(raw.encode("utf-8")).hexdigest()


def alert_urgency(alert: dict) -> str:
    text = normalize_text(" ".join([
        str(alert.get("severity", "")),
        str(alert.get("title", "")),
        str(alert.get("color", "")),
    ]))
    if any(term in text for term in ("grande perigo", "vermelho", "red", "#ff0000")):
        return "critical"
    if any(term in text for term in ("perigo", "laranja", "orange", "#f96602")):
        return "normal"
    return "low"


def alert_notification_title(alert: dict) -> str:
    title = str(alert.get("title") or "Aviso meteorológico").strip()
    source = str(alert.get("source") or "INMET").strip()
    return f"{source}: {title}" if source else title


def compact_alert_text(value, limit: int = 220) -> str:
    if isinstance(value, list):
        text = " ".join(str(item).strip() for item in value if str(item).strip())
    else:
        text = str(value or "").strip()
    text = re.sub(r"\s+", " ", text)
    if len(text) <= limit:
        return text
    return text[: limit - 1].rstrip() + "…"


def alert_notification_body(alert: dict, city: str = "") -> str:
    parts: list[str] = []
    severity = str(alert.get("severity") or "").strip()
    if severity:
        parts.append(severity)

    start = str(alert.get("start") or "").strip()
    end = str(alert.get("end") or "").strip()
    if start and end:
        parts.append(f"{start} até {end}")

    risk_text = compact_alert_text(alert.get("risks"))
    if risk_text:
        parts.append(risk_text)

    if city:
        parts.insert(0, city)

    return compact_alert_text(" • ".join(parts), 260)


def load_notify_state() -> dict:
    state = load_json(NOTIFY_STATE_PATH)
    if not isinstance(state, dict):
        return {"schema_version": 1, "seen": {}}
    seen = state.get("seen")
    if not isinstance(seen, dict):
        state["seen"] = {}
    return state


def save_notify_state(state: dict) -> None:
    write_json_atomic(NOTIFY_STATE_PATH, state)


def load_weather_settings() -> dict:
    settings = load_json(SETTINGS_PATH)
    if not isinstance(settings, dict):
        settings = {}
    return {
        "schema_version": 1,
        "notifications_enabled": bool(settings.get("notifications_enabled", True)),
    }


def save_weather_settings(settings: dict) -> None:
    current = load_weather_settings()
    current.update(settings)
    current["schema_version"] = 1
    current["notifications_enabled"] = bool(current.get("notifications_enabled", True))
    write_json_atomic(SETTINGS_PATH, current)


def notify_inmet_alerts(alerts: list[dict], city: str = "") -> dict:
    if not load_weather_settings().get("notifications_enabled", True):
        return {
            "notified": 0,
            "skipped": len(alerts),
            "failed": 0,
            "disabled": True,
            "dry_run": os.environ.get("ASTREA_WEATHER_NOTIFY_DRY_RUN") == "1",
            "notifier_available": os.path.isfile(ASTREA_NOTIFY_PATH),
        }

    now = int(time.time())
    state = load_notify_state()
    seen = state.setdefault("seen", {})
    active_ids: set[str] = set()
    dry_run = os.environ.get("ASTREA_WEATHER_NOTIFY_DRY_RUN") == "1"
    notifier_available = os.path.isfile(ASTREA_NOTIFY_PATH)

    result = {
        "notified": 0,
        "skipped": 0,
        "failed": 0,
        "dry_run": dry_run,
        "notifier_available": notifier_available,
    }

    for alert in alerts:
        if not isinstance(alert, dict):
            result["skipped"] += 1
            continue

        alert_id = alert_stable_id(alert)
        active_ids.add(alert_id)
        if alert_id in seen:
            result["skipped"] += 1
            continue

        if dry_run:
            seen[alert_id] = now
            result["notified"] += 1
            continue

        if not notifier_available:
            result["failed"] += 1
            continue

        try:
            completed = subprocess.run(
                [
                    "python3",
                    ASTREA_NOTIFY_PATH,
                    "--app", "Astrea Weather",
                    "--urgency", alert_urgency(alert),
                    "--icon", "weather-severe-alert",
                    "--category", "weather.alert",
                    "--desktop-entry", "astrea-weather",
                    alert_notification_title(alert),
                    alert_notification_body(alert, city),
                ],
                check=False,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                timeout=5,
            )
        except subprocess.SubprocessError:
            result["failed"] += 1
            continue
        if completed.returncode == 0:
            seen[alert_id] = now
            result["notified"] += 1
        else:
            result["failed"] += 1

    cutoff = now - NOTIFY_STATE_TTL
    state["seen"] = {
        alert_id: ts
        for alert_id, ts in seen.items()
        if alert_id in active_ids or int(ts or 0) >= cutoff
    }
    if not dry_run:
        save_notify_state(state)
    return result


def weather_code_to_text(code: int) -> str:
    mapping = {
        0:  "Ensolarado",
        1:  "Principalmente limpo",
        2:  "Parcialmente nublado",
        3:  "Nublado",
        45: "Névoa",
        48: "Névoa com gelo",
        51: "Garoa leve",
        53: "Garoa",
        55: "Garoa forte",
        56: "Garoa gelada leve",
        57: "Garoa gelada",
        61: "Chuva leve",
        63: "Chuva",
        65: "Chuva forte",
        66: "Chuva gelada leve",
        67: "Chuva gelada",
        71: "Neve leve",
        73: "Neve",
        75: "Neve forte",
        77: "Neve granulada",
        80: "Chuva passageira leve",
        81: "Chuva passageira",
        82: "Chuva passageira forte",
        85: "Neve passageira leve",
        86: "Neve passageira",
        95: "Trovoada",
        96: "Trovoada com granizo leve",
        99: "Trovoada com granizo",
    }
    return mapping.get(code, f"Código {code}")


def hourly_condition_text(code: int, rain_chance: int | float | None) -> str:
    condition = weather_code_to_text(code)
    if code in (0, 1, 2, 3) and (rain_chance or 0) >= 40:
        return "Possibilidade de chuva"
    return condition

def fetch_weather(city: str, days: int = 10, force: bool = False) -> dict:
    """Busca dados (cache ou API). Retorna dict com tudo."""
    path = cache_path(city, days)
    if not force:
        cached = load_weather_cache(city, days, CACHE_TTL)
        if cached:
            return cached

    with open(lock_path(city, days), "w", encoding="utf-8") as lock_file:
        fcntl.flock(lock_file.fileno(), fcntl.LOCK_EX)
        if not force:
            cached = load_weather_cache(city, days, CACHE_TTL)
            if cached:
                return cached

        return fetch_weather_uncached(city, days, path)


def fetch_weather_uncached(city: str, days: int, path: str) -> dict:
    region = load_region_preferences()
    try:
        loc = resolve_location(city)
    except (requests.RequestException, WeatherError):
        stale = load_weather_cache(city, days, STALE_CACHE_TTL)
        if stale:
            stale = dict(stale)
            stale["stale"] = True
            stale["stale_reason"] = "location_unavailable"
            return stale
        raise
    try:
        data = cached_get_json(
            "https://api.open-meteo.com/v1/forecast",
            {
            "latitude":     loc["latitude"],
            "longitude":    loc["longitude"],
            "timezone":     loc["timezone"],
            "forecast_days": days,
            "current": [
                "temperature_2m", "apparent_temperature",
                "relative_humidity_2m", "wind_speed_10m", 
                "wind_direction_10m", "wind_gusts_10m", "weather_code"
            ],
            "hourly": [
                "temperature_2m", "apparent_temperature",
                "relative_humidity_2m", "wind_speed_10m",
                "precipitation_probability", "weather_code"
            ],
            "daily":  [
                "weather_code", "temperature_2m_max", "temperature_2m_min",
                "precipitation_probability_max", "uv_index_max", "sunrise", "sunset"
            ]
            }
        )
    except requests.RequestException:
        stale = load_weather_cache(city, days, STALE_CACHE_TTL)
        if stale:
            stale = dict(stale)
            stale["stale"] = True
            stale["stale_reason"] = "forecast_unavailable"
            return stale
        raise

    try:
        aq_data = cached_get_json(
            "https://air-quality-api.open-meteo.com/v1/air-quality",
            {
                "latitude":     loc["latitude"],
                "longitude":    loc["longitude"],
                "current":      ["us_aqi", "pm10", "pm2_5"],
                "timezone":     loc["timezone"]
            }
        )
    except requests.RequestException:
        aq_data = {}
    aqi = aq_data.get("current", {}).get("us_aqi")

    current = data["current"]
    now_dt  = datetime.datetime.fromisoformat(current["time"])

    # Historical Data (last 7 days)
    yesterday = (now_dt - datetime.timedelta(days=1)).date()
    seven_days_ago = (now_dt - datetime.timedelta(days=7)).date()
    
    hist_key = f"{loc['name']}_{loc['admin1']}_{seven_days_ago}_{yesterday}"
    hist_path = aux_cache_path("history", hist_key)
    hist_age = file_age(hist_path)
    hist_cache = load_json(hist_path) if hist_age is not None and hist_age < HISTORY_CACHE_TTL else None
    hist_avg = hist_cache.get("temp_history_avg") if hist_cache else None
    if hist_avg is None:
        try:
            hist_data = cached_get_json(
                "https://archive-api.open-meteo.com/v1/archive",
                {
                "latitude":     loc["latitude"],
                "longitude":    loc["longitude"],
                "start_date":   seven_days_ago.isoformat(),
                "end_date":     yesterday.isoformat(),
                "daily":        ["temperature_2m_mean"],
                "timezone":     loc["timezone"]
                }
            )
            means = hist_data.get("daily", {}).get("temperature_2m_mean", [])
            valid_means = [m for m in means if m is not None]
            if valid_means:
                hist_avg = round(sum(valid_means) / len(valid_means))
                write_json_atomic(hist_path, {"temp_history_avg": hist_avg})
        except requests.RequestException:
            pass

    def short_time(value: str) -> str:
        return format_local_time(value, region)

    future_hourly = []
    for i, t in enumerate(data["hourly"]["time"]):
        hour_dt = datetime.datetime.fromisoformat(t)
        if hour_dt >= now_dt:
            future_hourly.append({
                "iso_time": t,
                "date": hour_dt.date().isoformat(),
                "time": short_time(t),
                "temp": safe_round(data["hourly"]["temperature_2m"][i]),
                "feels_like": safe_round(data["hourly"]["apparent_temperature"][i]),
                "weather_code": safe_number(data["hourly"]["weather_code"][i]),
                "raw_cond": weather_code_to_text(safe_number(data["hourly"]["weather_code"][i])),
                "cond": hourly_condition_text(
                    safe_number(data["hourly"]["weather_code"][i]),
                    data["hourly"]["precipitation_probability"][i]
                ),
                "rain": data["hourly"]["precipitation_probability"][i] or 0,
                "humidity": data["hourly"]["relative_humidity_2m"][i] or 0,
                "wind": safe_round(data["hourly"]["wind_speed_10m"][i])
            })

    day_names = ["Seg", "Ter", "Qua", "Qui", "Sex", "Sáb", "Dom"]
    weekly = []
    for i, date_str in enumerate(data["daily"]["time"]):
        d = datetime.date.fromisoformat(date_str)
        day_condition = weather_code_to_text(safe_number(data["daily"]["weather_code"][i]))
        if d == now_dt.date():
            day_condition = weather_code_to_text(safe_number(current["weather_code"]))

        weekly.append({
            "day":  day_names[d.weekday()],
            "date": date_str,
            "cond": day_condition,
            "daily_cond": weather_code_to_text(safe_number(data["daily"]["weather_code"][i])),
            "hi":   safe_round(data["daily"]["temperature_2m_max"][i]),
            "lo":   safe_round(data["daily"]["temperature_2m_min"][i]),
            "rain": data["daily"]["precipitation_probability_max"][i] or 0,
            "uv":   safe_round(data["daily"]["uv_index_max"][i]),
            "sunrise": short_time(data["daily"]["sunrise"][i]),
            "sunset": short_time(data["daily"]["sunset"][i]),
            "hours": [h for h in future_hourly if h["date"] == date_str]
        })

    result = {
        "schema_version": CACHE_VERSION,
        "updated_at": timestamp_now(),
        "stale":     False,
        "city":      loc["name"],
        "state":     loc["admin1"],
        "country":   loc.get("country", ""),
        "country_code": loc.get("country_code", ""),
        "timezone":  loc["timezone"],
        "location_source": loc.get("location_source", "city"),
        "region_country_code": region["country_code"],
        "time_format": effective_time_format(region),
        "current_time": current.get("time", ""),
        "temp":      safe_round(current["temperature_2m"]),
        "condition": weather_code_to_text(safe_number(current["weather_code"])),
        "feels_like": safe_round(current["apparent_temperature"]),
        "humidity":  safe_number(current["relative_humidity_2m"]),
        "wind":      safe_round(current["wind_speed_10m"]),
        "wind_dir":  safe_number(current.get("wind_direction_10m")),
        "wind_gusts": safe_round(current.get("wind_gusts_10m")),
        "aqi":       aqi,
        "temp_history_avg": hist_avg,
        "pm10":      aq_data.get("current", {}).get("pm10"),
        "pm2_5":     aq_data.get("current", {}).get("pm2_5"),
        "temp_min":  weekly[0]["lo"],
        "temp_max":  weekly[0]["hi"],
        "sunrise":   weekly[0]["sunrise"],
        "sunset":    weekly[0]["sunset"],
        "uv":        weekly[0]["uv"],
        "hourly":    future_hourly[:24],
        "weekly":    weekly,
        "alerts":    fetch_weather_alerts(loc),
        "alert_sources": alert_sources_for_location(loc),
    }

    write_json_atomic(path, result)

    return result

# ── Formatadores ──────────────────────────────────────────────────────────────
def fmt_current(data: dict):
    print(f"\n{data['city']}")
    print(f"{data['temp']}C  (sensacao {data['feels_like']}C)  {data['condition']}")
    print(f"Umidade: {data['humidity']}%   Vento: {data['wind']} km/h")
    print(f"Max: {data['temp_max']}C   Min: {data['temp_min']}C   UV: {data['uv']}\n")

def fmt_hourly(data: dict, hours: int = 12):
    print(f"\nPrevisao por hora -- {data['city']}\n")
    print(f"  {'Hora':<6} {'Temp':>6} {'Chuva':>6}  Condicao")
    print("  " + "-" * 48)
    for h in data["hourly"][:hours]:
        print(f"  {h['time']:<6} {h['temp']:>4}C  {h['rain']:>4}%  {h['cond']}")
    print()

def fmt_weekly(data: dict):
    print(f"\nPrevisao semanal -- {data['city']}\n")
    print(f"  {'Dia':<5} {'Max':>5} {'Min':>5} {'Chuva':>6}  {'UV':>3}  Condicao")
    print("  " + "-" * 56)
    for d in data["weekly"]:
        print(f"  {d['day']:<5} {d['hi']:>4}C {d['lo']:>4}C  {d['rain']:>4}%   {d['uv']:>2}  {d['cond']}")
    print()

def fmt_json(data: dict):
    print(json.dumps(data, ensure_ascii=False, indent=2))


def fmt_summary_json(data: dict):
    summary = {
        "schema_version": data.get("schema_version"),
        "city": data.get("city", ""),
        "state": data.get("state", ""),
        "temp": data.get("temp", 0),
        "condition": data.get("condition", ""),
        "feels_like": data.get("feels_like", 0),
        "humidity": data.get("humidity", 0),
        "stale": data.get("stale", False),
    }
    print(json.dumps(summary, ensure_ascii=False, separators=(",", ":")))

# ── Comandos CLI ──────────────────────────────────────────────────────────────
def cmd_get(args):
    data = fetch_weather(args.city, force=args.force)
    if args.summary_json:
        fmt_summary_json(data)
    elif args.json:
        fmt_json(data)
    else:
        fmt_current(data)

def cmd_hourly(args):
    data = fetch_weather(args.city, force=args.force)
    if args.json:
        fmt_json({"city": data["city"], "hourly": data["hourly"][:args.hours]})
    else:
        fmt_hourly(data, args.hours)

def cmd_forecast(args):
    data = fetch_weather(args.city, days=args.days, force=args.force)
    if args.json:
        fmt_json({"city": data["city"], "weekly": data["weekly"]})
    else:
        fmt_weekly(data)

def cmd_clear_cache(args):
    city = args.city
    if city:
        prefix = f"{cache_slug(city)}_"
        removed = 0
        if os.path.isdir(CACHE_DIR):
            for name in os.listdir(CACHE_DIR):
                full_path = os.path.join(CACHE_DIR, name)
                if os.path.isfile(full_path) and name.startswith(prefix):
                    os.remove(full_path)
                    removed += 1
        if removed:
            print(f"🗑  {removed} arquivo(s) de cache de '{city}' removido(s).")
        else:
            print(f"Nenhum cache encontrado para '{city}'.")
    else:
        if os.path.isdir(CACHE_DIR):
            for f in os.listdir(CACHE_DIR):
                full_path = os.path.join(CACHE_DIR, f)
                if os.path.isfile(full_path):
                    os.remove(full_path)
        print("🗑  Todo o cache removido.")


def cmd_notify_alerts(args):
    raw_alerts = args.alerts_json
    if not raw_alerts:
        raw_alerts = sys.stdin.read()

    try:
        alerts = json.loads(raw_alerts or "[]")
    except json.JSONDecodeError as e:
        raise WeatherError(f"JSON de alertas inválido: {e}") from e

    if not isinstance(alerts, list):
        raise WeatherError("JSON de alertas precisa ser uma lista")

    print(json.dumps(
        notify_inmet_alerts(alerts, args.city),
        ensure_ascii=False,
        separators=(",", ":"),
    ))


def parse_bool(value: str) -> bool:
    normalized = normalize_text(value)
    if normalized in ("1", "true", "yes", "on", "enable", "enabled", "sim", "ligado"):
        return True
    if normalized in ("0", "false", "no", "off", "disable", "disabled", "nao", "desligado"):
        return False
    raise WeatherError(f"valor booleano inválido: {value}")


def cmd_notifications_setting(args):
    if args.enabled is not None:
        save_weather_settings({"notifications_enabled": parse_bool(args.enabled)})
    print(json.dumps(
        load_weather_settings(),
        ensure_ascii=False,
        separators=(",", ":"),
    ))


def positive_int(value: str) -> int:
    ivalue = int(value)
    if ivalue <= 0:
        raise argparse.ArgumentTypeError("o valor deve ser maior que 0")
    return ivalue


def forecast_days(value: str) -> int:
    ivalue = positive_int(value)
    if ivalue > MAX_FORECAST_DAYS:
        raise argparse.ArgumentTypeError(
            f"o valor maximo para --days é {MAX_FORECAST_DAYS}"
        )
    return ivalue

# ── Main ──────────────────────────────────────────────────────────────────────
def main():
    parser = argparse.ArgumentParser(
        prog="weather",
        description="🌤 CLI de previsão do tempo via Open-Meteo"
    )

    # flag global de cidade
    city_kwargs = dict(
        metavar="CIDADE",
        nargs="?",
        default="",
        help="Nome da cidade (omitir = localização automática por IP)"
    )

    sub = parser.add_subparsers(dest="cmd", required=True)

    # weather get [cidade]
    p_get = sub.add_parser("get", help="Tempo atual")
    p_get.add_argument("city", **city_kwargs)
    p_get.add_argument("-f", "--force", action="store_true", help="Ignora o cache")
    p_get.add_argument("--json", action="store_true", help="Saída em JSON")
    p_get.add_argument("--summary-json", action="store_true", help="Saída JSON compacta")
    p_get.set_defaults(func=cmd_get)

    # weather hourly [cidade]
    p_hourly = sub.add_parser("hourly", help="Previsão hora a hora (próximas N horas)")
    p_hourly.add_argument("city", **city_kwargs)
    p_hourly.add_argument("-n", "--hours", type=positive_int, default=12, metavar="N",
                          help="Quantas horas mostrar (padrão: 12)")
    p_hourly.add_argument("-f", "--force", action="store_true", help="Ignora o cache")
    p_hourly.add_argument("--json", action="store_true", help="Saída em JSON")
    p_hourly.set_defaults(func=cmd_hourly)

    # weather forecast [cidade]
    p_fc = sub.add_parser("forecast", help="Previsão semanal")
    p_fc.add_argument("city", **city_kwargs)
    p_fc.add_argument("-d", "--days", type=forecast_days, default=7, metavar="N",
                      help="Quantos dias (máx 16, padrão: 7)")
    p_fc.add_argument("-f", "--force", action="store_true", help="Ignora o cache")
    p_fc.add_argument("--json", action="store_true", help="Saída em JSON")
    p_fc.set_defaults(func=cmd_forecast)

    # weather clear-cache [cidade]
    p_cc = sub.add_parser("clear-cache", help="Limpa o cache")
    p_cc.add_argument("city", metavar="CIDADE", nargs="?", default=None,
                      help="Cidade específica (omitir = limpa tudo)")
    p_cc.set_defaults(func=cmd_clear_cache)

    # weather notify-alerts '[...]'
    p_notify = sub.add_parser("notify-alerts", help="Envia notificações de alertas INMET")
    p_notify.add_argument("--city", default="", help="Nome exibido no corpo da notificação")
    p_notify.add_argument("alerts_json", nargs="?", default="", help="Lista JSON de alertas")
    p_notify.set_defaults(func=cmd_notify_alerts)

    # weather notifications-setting [true|false]
    p_notify_setting = sub.add_parser("notifications-setting", help="Lê ou altera notificações do Weather")
    p_notify_setting.add_argument("enabled", nargs="?", default=None, help="true/false")
    p_notify_setting.set_defaults(func=cmd_notifications_setting)

    args = parser.parse_args()
    try:
        args.func(args)
    except KeyboardInterrupt:
        print("\nAbortado.")
        sys.exit(0)
    except requests.RequestException as e:
        print(f"❌ Erro de rede: {e}", file=sys.stderr)
        sys.exit(1)
    except WeatherError as e:
        print(f"❌ {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()
