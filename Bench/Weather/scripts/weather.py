#!/usr/bin/env python3
import requests
import json
import os
import sys
import datetime
import argparse
import re

# ── Config ────────────────────────────────────────────────────────────────────
CACHE_DIR  = os.path.expanduser("~/.cache/weather")
CACHE_TTL  = 12 * 60 * 60
DEFAULT_CITY = "Itajaí"
MAX_FORECAST_DAYS = 16


class WeatherError(Exception):
    """Erro controlado para mensagens amigáveis na CLI."""

# ── Helpers ───────────────────────────────────────────────────────────────────
def cache_slug(city: str) -> str:
    slug = re.sub(r"\s+", "_", city.strip().lower())
    slug = re.sub(r"[^a-z0-9_\-]", "", slug)
    return slug or "unknown"


def cache_path(city: str, days: int) -> str:
    os.makedirs(CACHE_DIR, exist_ok=True)
    return os.path.join(CACHE_DIR, f"{cache_slug(city)}_{days}d.json")


def cache_valido(city: str, days: int) -> bool:
    path = cache_path(city, days)
    if not os.path.exists(path):
        return False
    idade = datetime.datetime.now().timestamp() - os.path.getmtime(path)
    return idade < CACHE_TTL

def get_coords(city: str) -> dict:
    geo = requests.get(
        "https://geocoding-api.open-meteo.com/v1/search",
        params={"name": city, "count": 1, "language": "pt", "format": "json"},
        timeout=10
    )
    geo.raise_for_status()
    data = geo.json()
    if "results" not in data or not data["results"]:
        raise WeatherError(f"Cidade nao encontrada: {city}")
    r = data["results"][0]
    return {
        "name":      r["name"],
        "latitude":  r["latitude"],
        "longitude": r["longitude"],
        "timezone":  r.get("timezone", "auto")
    }

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

def fetch_weather(city: str, days: int = 10, force: bool = False) -> dict:
    """Busca dados (cache ou API). Retorna dict com tudo."""
    path = cache_path(city, days)
    if not force and cache_valido(city, days):
        try:
            with open(path, "r", encoding="utf-8") as f:
                cached = json.load(f)
            if len(cached.get("weekly", [])) >= days:
                return cached
        except (json.JSONDecodeError, OSError):
            pass

    loc = get_coords(city)
    response = requests.get(
        "https://api.open-meteo.com/v1/forecast",
        params={
            "latitude":     loc["latitude"],
            "longitude":    loc["longitude"],
            "timezone":     loc["timezone"],
            "forecast_days": days,
            "current": [
                "temperature_2m", "apparent_temperature",
                "relative_humidity_2m", "wind_speed_10m", "weather_code"
            ],
            "hourly": ["temperature_2m", "precipitation_probability", "weather_code"],
            "daily":  [
                "weather_code", "temperature_2m_max", "temperature_2m_min",
                "precipitation_probability_max", "uv_index_max"
            ]
        },
        timeout=10
    )
    response.raise_for_status()
    data = response.json()

    current = data["current"]
    now_dt  = datetime.datetime.fromisoformat(current["time"])

    hourly = []
    for i, t in enumerate(data["hourly"]["time"]):
        hour_dt = datetime.datetime.fromisoformat(t)
        if hour_dt >= now_dt:
            hourly.append({
                "time": hour_dt.strftime("%H:%M"),
                "temp": round(data["hourly"]["temperature_2m"][i]),
                "cond": weather_code_to_text(data["hourly"]["weather_code"][i]),
                "rain": data["hourly"]["precipitation_probability"][i] or 0
            })
        if len(hourly) >= 24:
            break

    day_names = ["Seg", "Ter", "Qua", "Qui", "Sex", "Sáb", "Dom"]
    weekly = []
    for i, date_str in enumerate(data["daily"]["time"]):
        d = datetime.date.fromisoformat(date_str)
        weekly.append({
            "day":  day_names[d.weekday()],
            "date": date_str,
            "cond": weather_code_to_text(data["daily"]["weather_code"][i]),
            "hi":   round(data["daily"]["temperature_2m_max"][i]),
            "lo":   round(data["daily"]["temperature_2m_min"][i]),
            "rain": data["daily"]["precipitation_probability_max"][i] or 0,
            "uv":   round(data["daily"]["uv_index_max"][i]) if data["daily"]["uv_index_max"][i] is not None else 0
        })

    result = {
        "city":      loc["name"],
        "timezone":  loc["timezone"],
        "temp":      round(current["temperature_2m"]),
        "condition": weather_code_to_text(current["weather_code"]),
        "feels_like": round(current["apparent_temperature"]),
        "humidity":  current["relative_humidity_2m"],
        "wind":      round(current["wind_speed_10m"]),
        "temp_min":  weekly[0]["lo"],
        "temp_max":  weekly[0]["hi"],
        "uv":        weekly[0]["uv"],
        "hourly":    hourly,
        "weekly":    weekly
    }

    with open(path, "w", encoding="utf-8") as f:
        json.dump(result, f, ensure_ascii=False)

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

# ── Comandos CLI ──────────────────────────────────────────────────────────────
def cmd_get(args):
    data = fetch_weather(args.city, force=args.force)
    if args.json:
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
        default=DEFAULT_CITY,
        help=f"Nome da cidade (padrão: {DEFAULT_CITY})"
    )

    sub = parser.add_subparsers(dest="cmd", required=True)

    # weather get [cidade]
    p_get = sub.add_parser("get", help="Tempo atual")
    p_get.add_argument("city", **city_kwargs)
    p_get.add_argument("-f", "--force", action="store_true", help="Ignora o cache")
    p_get.add_argument("--json", action="store_true", help="Saída em JSON")
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
