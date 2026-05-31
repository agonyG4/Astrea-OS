import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick
import "./ui" as Ui

ShellRoot {
    id: root
    property bool performancePaused: false

    onPerformancePausedChanged: {
        if (performancePaused && weatherProc.running) {
            weatherProc.running = false
            spotlight.weatherLoading = false
        }
    }

    HyprlandFocusGrab {
        id: focusGrab
        active: spotlight.open
        onActiveChanged: {
            if (active) {
                spotlight.hadFocusGrab = true
            } else if (spotlight.hadFocusGrab && spotlight.open) {
                spotlight.close()
            }
        }
    }

    GlobalShortcut {
        name: "spotlight_toggle"
        onPressed: spotlight.toggle()
    }

    Loader {
        active: spotlight.open
        asynchronous: true
        sourceComponent: Variants {
            model: Quickshell.screens
            delegate: PanelWindow {
                id: win
                required property var modelData
                screen: modelData
                WlrLayershell.namespace: "spotlight"

                anchors.top: true
                anchors.left: true
                anchors.right: true
                anchors.bottom: true

                color: "transparent"
                visible: spotlight.open && modelData === Quickshell.screens[0]

                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

                MouseArea {
                    anchors.fill: parent
                    onClicked: spotlight.close()
                }

                Ui.SpotlightPanel {
                    controller: spotlight
                }
            }
        }
    }

    QtObject {
        id: spotlight
        readonly property bool standalone: Quickshell.env("ASTREA_SPOTLIGHT_STANDALONE") === "1"
        property bool open: standalone
        readonly property string fontFamily: "SF Pro Display"
        property bool hadFocusGrab: false
        property bool quitAfterUsageSave: false
        property bool usageSavePending: false
        property var results: []
        property var usageCounts: ({})
        readonly property string astreaRoot: (Quickshell.env("ASTREA_ROOT") || (Quickshell.env("HOME") + "/.local/share/Astrea")) + ""
        readonly property string astreaLaunch: astreaRoot + "/bin/astrea-launch"
        readonly property string weatherCli: astreaRoot + "/bin/weather-cli"
        readonly property string spotlightCli: astreaRoot + "/System/scripts/astrea-spotlight"
        property string usageLoadBuffer: ""
        property string configLoadBuffer: ""
        property string weatherBuffer: ""
        property bool weatherEnabled: true
        property bool weatherReady: false
        property bool weatherLoading: false
        property string weatherCity: ""
        property string weatherCondition: ""
        property int weatherTemp: 0
        property string weatherStatusText: "Atualizando"
        readonly property string weatherIconSource: weatherReady ? weatherAssetForCondition(weatherCondition) : ""
        readonly property int weatherStaleMs: 1800000
        property double weatherLastRefreshMs: 0
        property string pendingQuery: ""
        property var pendingLaunchEntry: null
        property string execArgvBuffer: ""
        readonly property bool performancePaused: root.performancePaused

        function toggle() {
            if (open) {
                close()
            } else {
                open = true
                maybeRefreshWeather(true)
            }
        }

        function close() {
            open = false
            hadFocusGrab = false
            pendingQuery = ""
            results = []
            resultDebounce.stop()
            if (weatherProc.running) {
                weatherProc.running = false
                weatherLoading = false
            }
            if (standalone) Qt.callLater(Qt.quit)
        }

        function entryKey(entry) {
            return entry.desktopId || entry.id || entry.fileName || [entry.name || "", entry.exec || entry.execString || ""].join("|")
        }

        function desktopIdForEntry(entry) {
            if (!entry) return ""
            return entry.desktopId || entry.id || entry.fileName || ""
        }

        function usageCountFor(entry) {
            const key = entryKey(entry)
            return Number(usageCounts[key] || 0)
        }

        function bumpUsage(entry) {
            const key = entryKey(entry)
            usageCounts = Object.assign({}, usageCounts, {
                [key]: usageCountFor(entry) + 1
            })
            persistUsage()
        }

        function scheduleResults(query) {
            pendingQuery = query
            resultDebounce.restart()
        }

        function ensureConfig() {
            configLoadBuffer = ""
            configLoadProc.running = false
            configLoadProc.running = true
        }

        function applyConfig(config) {
            weatherEnabled = config.weather === undefined || config.weather === null ? true : !!config.weather
            if (weatherEnabled) maybeRefreshWeather(open)
        }

        function maybeRefreshWeather(allowPaused) {
            if ((performancePaused && !allowPaused) || !weatherEnabled || weatherLoading) return
            const now = Date.now()
            if (!weatherReady || weatherLastRefreshMs <= 0 || now - weatherLastRefreshMs >= weatherStaleMs) {
                refreshWeather(allowPaused)
            }
        }

        function refreshWeather(allowPaused) {
            if ((performancePaused && !allowPaused) || !weatherEnabled || weatherLoading) return
            weatherLoading = true
            weatherStatusText = weatherReady ? "Atualizando" : "Carregando"
            weatherBuffer = ""
            weatherProc.running = false
            weatherProc.running = true
        }

        function applyWeather(payload) {
            if (!payload || payload.error) {
                weatherStatusText = payload && payload.error ? payload.error : "Indisponível"
                weatherReady = false
                return
            }

            weatherCity = payload.city || ""
            weatherCondition = payload.condition || ""
            weatherTemp = Number(payload.temp || 0)
            weatherStatusText = ""
            weatherReady = true
            weatherLastRefreshMs = Date.now()
        }

        function weatherAssetForCondition(condition) {
            const text = (condition || "").toLowerCase()
            const assetRoot = "file://" + spotlight.astreaRoot + "/Apps/Weather/assets/icons/weather/"

            if (text.indexOf("trovoada") >= 0) return assetRoot + "thunderstorm.png"
            if (text.indexOf("chuva gelada") >= 0 || text.indexOf("garoa gelada") >= 0) return assetRoot + "freezing_rain.png"
            if (text.indexOf("chuva forte") >= 0 || text.indexOf("garoa forte") >= 0 || text.indexOf("pancadas fortes") >= 0) return assetRoot + "heavy_rain.png"
            if (text.indexOf("garoa") >= 0 || text.indexOf("chuva leve") >= 0 || text.indexOf("pancadas") >= 0) return assetRoot + "light_rain.png"
            if (text.indexOf("chuva") >= 0) return assetRoot + "rain.png"
            if (text.indexOf("névoa") >= 0 || text.indexOf("nevoa") >= 0) return assetRoot + "mist.png"
            if (text.indexOf("nublado") >= 0) return assetRoot + "cloudy.png"
            if (text.indexOf("parcialmente") >= 0 || text.indexOf("principalmente") >= 0) return assetRoot + "partially_cloudy.png"
            if (text.indexOf("limpo") >= 0 || text.indexOf("céu") >= 0 || text.indexOf("ceu") >= 0 || text.indexOf("ensolarado") >= 0) return assetRoot + "clear.png"
            return assetRoot + "clear.png"
        }

        function searchString(value) {
            if (value === undefined || value === null) return ""
            if (Array.isArray(value)) return value.join(" ")
            return String(value)
        }

        function normalizeSearch(value) {
            let text = searchString(value).toLowerCase()
            try {
                text = text.normalize("NFD").replace(/[\u0300-\u036f]/g, "")
            } catch (e) {}
            return text
        }

        function searchTokens(value) {
            return normalizeSearch(value).split(/[\s._:/\\-]+/).filter(part => part.length > 0)
        }

        function acronymForTokens(tokens) {
            return tokens.map(part => part[0]).join("")
        }

        function aliasesForName(name) {
            const tokens = searchTokens(name)
            let aliases = []
            if (tokens.length === 0) return aliases

            aliases.push(tokens.join(""))
            aliases.push(acronymForTokens(tokens))
            if (tokens.length >= 2)
                aliases.push(tokens.slice(0, -1).map(part => part[0]).join("") + tokens[tokens.length - 1])

            return aliases
        }

        function isSubsequence(needle, haystack) {
            if (needle.length === 0) return true
            let at = 0
            for (let i = 0; i < haystack.length && at < needle.length; i++) {
                if (haystack[i] === needle[at]) at++
            }
            return at === needle.length
        }

        function scoreText(value, query, searchTerms, baseScore, allowFuzzy) {
            const text = normalizeSearch(value)
            if (!text) return -1

            const parts = text.split(/[\s._:/\\-]+/).filter(part => part.length > 0)
            if (text === query) return baseScore
            if (text.startsWith(query)) return baseScore + 2
            if (parts.some(part => part.startsWith(query))) return baseScore + 5
            if (parts.some(part => query.startsWith(part) && part.length >= 4 && query.length - part.length <= 2)) return baseScore + 7
            if (searchTerms.length > 1 && searchTerms.every(term => parts.some(part => part.startsWith(term)))) return baseScore + 8
            if (searchTerms.every(term => text.includes(term))) return baseScore + 14
            if (allowFuzzy && query.length >= 3 && isSubsequence(query, text)) return baseScore + 34 + Math.max(0, text.length - query.length)
            return -1
        }

        function entrySearchScore(entry, query, searchTerms) {
            const name = entry.name || ""
            const aliases = aliasesForName(name)
            let best = scoreText(name, query, searchTerms, 0, true)

            for (let alias of aliases) {
                const aliasScore = scoreText(alias, query, searchTerms, 1, false)
                if (aliasScore >= 0 && (best < 0 || aliasScore < best)) best = aliasScore
            }

            const metadata = [
                entry.keywords,
                entry.keyword,
                entry.genericName,
                entry.generic,
                entry.comment,
                entry.categories,
                entry.category
            ].map(searchString).filter(value => value.length > 0).join(" ")
            const metadataScore = scoreText(metadata, query, searchTerms, 12, false)
            if (metadataScore >= 0 && (best < 0 || metadataScore < best)) best = metadataScore

            const identifiers = [
                entry.desktopId,
                entry.id,
                entry.fileName,
                entry.startupWmClass,
                entry.wmClass,
                entry.exec,
                entry.execString
            ].map(searchString).filter(value => value.length > 0).join(" ")
            const identifierScore = scoreText(identifiers, query, searchTerms, 24, false)
            if (identifierScore >= 0 && (best < 0 || identifierScore < best)) best = identifierScore

            return best
        }

        function persistUsage() {
            usageSaveProc.command = [spotlightCli, "usage-save", JSON.stringify(usageCounts)]
            if (usageSaveProc.running) {
                usageSavePending = true
                return
            }
            usageSaveProc.running = false
            usageSaveProc.running = true
        }

        function loadUsage() {
            usageLoadBuffer = ""
            usageLoadProc.running = false
            usageLoadProc.running = true
        }

        function updateResults(query) {
            const q = normalizeSearch(query.trim())
            if (q === "") { results = []; return }

            let items = []
            if (typeof DesktopEntries !== "undefined") {
                let apps = DesktopEntries.applications.values
                let searchTerms = searchTokens(q)
                let seenKeys = new Set()

                for (let entry of apps) {
                    if (!entry || entry.noDisplay) continue

                    let searchableName = normalizeSearch((entry.name || "").trim())
                    let key = entryKey(entry)
                    if (!searchableName || seenKeys.has(key)) continue

                    let score = entrySearchScore(entry, q, searchTerms)
                    if (score < 0) continue

                    items.push({
                        entry,
                        name: searchableName,
                        score,
                        usage: usageCountFor(entry)
                    })
                    seenKeys.add(key)
                }

                items.sort((a, b) => {
                    if (a.score !== b.score) return a.score - b.score
                    if (a.usage !== b.usage) return b.usage - a.usage
                    return a.name.localeCompare(b.name)
                })

                if (items.some(item => item.score < 12))
                    items = items.filter(item => item.score < 12)
            }
            results = items.slice(0, 6).map(item => item.entry)
        }

        function launch(index) {
            if (index < 0 || index >= results.length) return
            let entry = results[index]
            quitAfterUsageSave = standalone
            bumpUsage(entry)

            // Fecha primeiro para liberar o foco do Wayland
            open = false
            hadFocusGrab = false
            results = []

            Qt.callLater(() => {
                var desktopId = desktopIdForEntry(entry)
                if (desktopId) {
                    launchProc.command = [astreaLaunch, "--desktop", desktopId]
                    launchProc.running = false
                    launchProc.running = true
                } else {
                    var commandText = entry.exec || entry.execString || ""
                    if (!commandText) {
                        if (standalone && !usageSaveProc.running)
                            Qt.quit()
                        return
                    }
                    pendingLaunchEntry = entry
                    execArgvBuffer = ""
                    execArgvProc.command = [spotlightCli, "exec-argv", commandText]
                    execArgvProc.running = false
                    execArgvProc.running = true
                }
            })
        }

        Component.onCompleted: {
            loadUsage()
            ensureConfig()
        }

        property var resultDebounce: Timer {
            id: resultDebounce
            interval: 35
            repeat: false
            onTriggered: spotlight.updateResults(spotlight.pendingQuery)
        }

        property var weatherRefreshTimer: Timer {
            interval: 1800000
            repeat: true
            running: !spotlight.performancePaused && spotlight.weatherEnabled && spotlight.open
            onTriggered: spotlight.maybeRefreshWeather()
        }

        property var usageLoadProc: Process {
            id: usageLoadProc
            command: [spotlight.spotlightCli, "usage-load"]
            running: false
            stdout: SplitParser {
                onRead: data => spotlight.usageLoadBuffer += data
            }
            onExited: (code, _) => {
                if (code !== 0) return
                try {
                    spotlight.usageCounts = JSON.parse(spotlight.usageLoadBuffer || "{}")
                } catch (e) {
                    spotlight.usageCounts = ({})
                }
            }
        }

        property var usageSaveProc: Process {
            id: usageSaveProc
            command: []
            running: false
            onExited: {
                if (spotlight.usageSavePending) {
                    spotlight.usageSavePending = false
                    spotlight.persistUsage()
                    return
                }
                if (!spotlight.quitAfterUsageSave) return
                spotlight.quitAfterUsageSave = false
                Qt.quit()
            }
        }

        property var execArgvProc: Process {
            id: execArgvProc
            command: []
            running: false
            stdout: SplitParser {
                onRead: data => spotlight.execArgvBuffer += data
            }
            onExited: (code, _) => {
                if (code !== 0) {
                    if (spotlight.standalone && !spotlight.usageSaveProc.running)
                        Qt.quit()
                    return
                }
                try {
                    var argv = JSON.parse(spotlight.execArgvBuffer || "[]")
                    launchProc.command = Array.isArray(argv) && argv.length > 0 ? [spotlight.astreaLaunch, "--argv-json", JSON.stringify(argv)] : []
                } catch (e) {
                    launchProc.command = []
                }
                spotlight.pendingLaunchEntry = null
                spotlight.execArgvBuffer = ""
                if (launchProc.command.length > 0) {
                    launchProc.running = false
                    launchProc.running = true
                } else if (spotlight.standalone && !spotlight.usageSaveProc.running) {
                    Qt.quit()
                }
            }
        }

        property var launchProc: Process {
            id: launchProc
            command: []
            running: false
            onExited: {
                if (spotlight.standalone && !spotlight.usageSaveProc.running)
                    Qt.quit()
            }
        }

        property var configLoadProc: Process {
            id: configLoadProc
            command: [spotlight.spotlightCli, "config"]
            running: false
            stdout: SplitParser {
                onRead: data => spotlight.configLoadBuffer += data
            }
            onExited: (code, _) => {
                if (code !== 0) {
                    spotlight.applyConfig({})
                    return
                }
                try {
                    spotlight.applyConfig(JSON.parse(spotlight.configLoadBuffer || "{}"))
                } catch (e) {
                    spotlight.applyConfig({})
                }
            }
        }

        property var weatherProc: Process {
            id: weatherProc
            command: [spotlight.weatherCli, "summary"]
            running: false
            stdout: SplitParser {
                onRead: data => spotlight.weatherBuffer += data
            }
            onExited: (code, _) => {
                spotlight.weatherLoading = false
                if (code !== 0) {
                    spotlight.applyWeather({ "error": "Sem dados" })
                    return
                }
                try {
                    spotlight.applyWeather(JSON.parse(spotlight.weatherBuffer || "{}"))
                } catch (e) {
                    spotlight.applyWeather({ "error": "JSON inválido" })
                }
            }
        }

    }
}
