import requests
import json
import os
import datetime

CACHE_PATH = "/home/agony/GitHub/Bench/Weather/scripts/openmeteo_cache.json"
CACHE_TTL  = 12 * 60 * 60

CITY = "Itajai"
DAYS = 10

def cache_valido():
    if not os.path.exists(CACHE_PATH):
        return False
    idade = datetime.datetime.now().timestamp() - os.path.getmtime(CACHE_PATH)
    return idade < CACHE_TTL

def get_coords(city):
    geo = requests.get(
        "https://geocoding-api.open-meteo.com/v1/search",
        params={
            "name": city,
            "count": 1,
            "language": "pt",
            "format": "json"
        },
        timeout=10
    )
    geo.raise_for_status()
    data = geo.json()

    if "results" not in data or not data["results"]:
        raise Exception(f"Cidade não encontrada: {city}")

    result = data["results"][0]
    return {
        "name": result["name"],
        "latitude": result["latitude"],
        "longitude": result["longitude"],
        "timezone": result.get("timezone", "auto")
    }

def weather_code_to_text(code):
    mapping = {
        0: "Céu limpo",
        1: "Principalmente limpo",
        2: "Parcialmente nublado",
        3: "Nublado",
        45: "Névoa",
        48: "Névoa com geada",
        51: "Garoa leve",
        53: "Garoa moderada",
        55: "Garoa intensa",
        56: "Garoa congelante leve",
        57: "Garoa congelante intensa",
        61: "Chuva fraca",
        63: "Chuva moderada",
        65: "Chuva forte",
        66: "Chuva congelante leve",
        67: "Chuva congelante forte",
        71: "Neve fraca",
        73: "Neve moderada",
        75: "Neve forte",
        77: "Grãos de neve",
        80: "Pancadas fracas",
        81: "Pancadas moderadas",
        82: "Pancadas fortes",
        85: "Pancadas de neve fracas",
        86: "Pancadas de neve fortes",
        95: "Trovoada",
        96: "Trovoada com granizo fraco",
        99: "Trovoada com granizo forte",
    }
    return mapping.get(code, f"Código {code}")

if cache_valido():
    with open(CACHE_PATH, "r", encoding="utf-8") as f:
        print(f.read())
else:
    loc = get_coords(CITY)

    response = requests.get(
        "https://api.open-meteo.com/v1/forecast",
        params={
            "latitude": loc["latitude"],
            "longitude": loc["longitude"],
            "timezone": "auto",
            "forecast_days": DAYS,
            "current": [
                "temperature_2m",
                "apparent_temperature",
                "relative_humidity_2m",
                "wind_speed_10m",
                "weather_code"
            ],
            "hourly": [
                "temperature_2m",
                "precipitation_probability",
                "weather_code"
            ],
            "daily": [
                "weather_code",
                "temperature_2m_max",
                "temperature_2m_min",
                "precipitation_probability_max",
                "uv_index_max"
            ]
        },
        timeout=10
    )
    response.raise_for_status()
    data = response.json()

    current = data["current"]
    now_iso = current["time"]
    now_dt = datetime.datetime.fromisoformat(now_iso)

    hourly = []
    for i, time_str in enumerate(data["hourly"]["time"]):
        hour_dt = datetime.datetime.fromisoformat(time_str)
        if hour_dt >= now_dt:
            hourly.append({
                "time": hour_dt.strftime("%H:%M"),
                "temp": f"{round(data['hourly']['temperature_2m'][i])}°",
                "icon": weather_code_to_text(data["hourly"]["weather_code"][i]),
                "rain": data["hourly"]["precipitation_probability"][i] or 0
            })
        if len(hourly) >= 24:
            break

    day_names = ["Seg", "Ter", "Qua", "Qui", "Sex", "Sáb", "Dom"]
    weekly = []

    for i, date_str in enumerate(data["daily"]["time"]):
        d = datetime.date.fromisoformat(date_str)
        weekly.append({
            "day": day_names[d.weekday()],
            "cond": weather_code_to_text(data["daily"]["weather_code"][i]),
            "icon": weather_code_to_text(data["daily"]["weather_code"][i]),
            "hi": f"{round(data['daily']['temperature_2m_max'][i])}°",
            "lo": f"{round(data['daily']['temperature_2m_min'][i])}°",
            "rain": data["daily"]["precipitation_probability_max"][i] or 0,
            "uv": round(data["daily"]["uv_index_max"][i]) if data["daily"]["uv_index_max"][i] is not None else 0
        })

    result = {
        "city": loc["name"],
        "temp": f"{round(current['temperature_2m'])}°C",
        "condition": weather_code_to_text(current["weather_code"]),
        "feels_like": f"{round(current['apparent_temperature'])}°C",
        "humidity": f"{current['relative_humidity_2m']}%",
        "wind": f"{round(current['wind_speed_10m'])} km/h",
        "temp_min": weekly[0]["lo"],
        "temp_max": weekly[0]["hi"],
        "uv": str(weekly[0]["uv"]),
        "visibility": None,
        "hourly": hourly,
        "weekly": weekly
    }

    output = json.dumps(result, ensure_ascii=False)
    with open(CACHE_PATH, "w", encoding="utf-8") as f:
        f.write(output)
    print(output)