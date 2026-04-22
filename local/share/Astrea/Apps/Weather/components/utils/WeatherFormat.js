.pragma library

function icon(desc) {
    if (!desc) return "🌡️"
    var d = desc.toLowerCase()
    if (d.includes("trovoada")) return "⛈️"
    if (d.includes("granizo")) return "🌨️"
    if (d.includes("pancadas fortes")) return "🌧️"
    if (d.includes("pancadas")) return "🌦️"
    if (d.includes("neve")) return "❄️"
    if (d.includes("garoa")) return "🌦️"
    if (d.includes("chuva forte")) return "🌧️"
    if (d.includes("chuva")) return "🌧️"
    if (d.includes("névoa")) return "🌫️"
    if (d.includes("nublado")) return "☁️"
    if (d.includes("parcialmente")) return "⛅"
    if (d.includes("principalmente")) return "🌤️"
    if (d.includes("limpo")) return "☀️"
    if (d.includes("céu")) return "☀️"
    if (d.includes("ensolarado")) return "☀️"
    return "🌡️"
}

function temp(value) {
    return value === undefined || value === null ? "--°" : value + "°"
}

function percent(value) {
    return value === undefined || value === null ? "0%" : value + "%"
}

function wind(value) {
    return value === undefined || value === null ? "0 km/h" : value + " km/h"
}
