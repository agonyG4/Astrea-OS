import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"

ShellRoot {
    id: root

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

    Variants {
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

            Rectangle {
                id: panel
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: parent.height * 0.25

                width: 600
                height: searchInput.text.length > 0 ? Math.min(contentCol.implicitHeight + 28, 450) : 58
                radius: 24

                color: '#80343434'
                border.color: "#33FFFFFF"
                border.width: 1
                clip: true

                scale: spotlight.open ? 1.0 : 0.98
                opacity: spotlight.open ? 1.0 : 0.0

                Behavior on height  { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                Behavior on scale   { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }
                Behavior on opacity { NumberAnimation { duration: 120 } }

                ColumnLayout {
                    id: contentCol
                    anchors { top: parent.top; left: parent.left; right: parent.right; margins: 14 }
                    spacing: 0

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 30
                        spacing: 12

                        Text {
                            text: "⌕"
                            font.family: spotlight.fontFamily
                            font.pixelSize: 24
                            color: "#99FFFFFF"
                            Layout.leftMargin: 8
                            Layout.alignment: Qt.AlignVCenter
                        }

                        TextField {
                            id: searchInput
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter

                            placeholderText: "Spotlight Search"
                            font.family: spotlight.fontFamily
                            font.pixelSize: 22
                            font.weight: Font.Light
                            color: "white"
                            placeholderTextColor: "#66FFFFFF"
                            background: null

                            topPadding: 0
                            bottomPadding: 0
                            leftPadding: 0

                            verticalAlignment: TextInput.AlignVCenter

                            onTextChanged: spotlight.scheduleResults(text)

                            Keys.onEscapePressed: spotlight.close()
                            Keys.onReturnPressed: if (resultList.count > 0) spotlight.launch(resultList.currentIndex)
                            Keys.onDownPressed: if (resultList.count > 0) resultList.currentIndex = (resultList.currentIndex + 1) % resultList.count
                            Keys.onUpPressed: if (resultList.count > 0) resultList.currentIndex = (resultList.currentIndex - 1 + resultList.count) % resultList.count

                            Component.onCompleted: forceActiveFocus()
                            onVisibleChanged: if (visible) { forceActiveFocus(); text = "" }
                        }

                        RowLayout {
                            Layout.maximumWidth: 68
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 1
                            visible: spotlight.weatherEnabled

                            Image {
                                Layout.preferredWidth: 20
                                Layout.preferredHeight: 20
                                Layout.alignment: Qt.AlignVCenter
                                source: spotlight.weatherIconSource
                                visible: spotlight.weatherReady
                                fillMode: Image.PreserveAspectFit
                                smooth: false
                                mipmap: true
                                opacity: 0.78
                            }

                            Text {
                                text: "○"
                                visible: !spotlight.weatherReady
                                font.pixelSize: 18
                                color: searchInput.placeholderTextColor
                                Layout.alignment: Qt.AlignVCenter
                            }

                            Text {
                                Layout.maximumWidth: 46
                                text: spotlight.weatherReady ? spotlight.weatherTemp + "°" : "--°"
                                font.family: spotlight.fontFamily
                                font.pixelSize: 18
                                font.weight: Font.Medium
                                color: searchInput.placeholderTextColor
                                elide: Text.ElideRight
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: searchInput.text.length > 0 && resultList.count > 0
                        spacing: 0

                        Rectangle {
                            Layout.fillWidth: true
                            height: 1; color: "#15FFFFFF"
                            Layout.topMargin: 12; Layout.bottomMargin: 8
                        }

                        ListView {
                            id: resultList
                            Layout.fillWidth: true
                            implicitHeight: Math.min(count, 6) * 50
                            model: spotlight.results
                            currentIndex: 0
                            interactive: false

                            delegate: Rectangle {
                                width: resultList.width
                                height: 50
                                radius: 7
                                color: resultList.currentIndex === index ? "#007AFF" : "transparent"

                                RowLayout {
                                    anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                                    spacing: 15

                                    AppIcon {
                                        Layout.preferredWidth: 30
                                        Layout.preferredHeight: 30
                                        entry: modelData
                                        fallbackRadius: 6
                                        fallbackColor: "#22FFFFFF"
                                    }

                                    Text {
                                        text: modelData ? modelData.name : ""
                                        font.family: spotlight.fontFamily
                                        font.pixelSize: 17
                                        color: "white"
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onEntered: resultList.currentIndex = index
                                    onClicked: spotlight.launch(index)
                                }
                            }
                        }
                    }
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
        readonly property string usageFilePath: Quickshell.env("HOME") + "/.local/state/Astrea/spotlight-usage.json"
        readonly property string configFilePath: Quickshell.env("HOME") + "/.config/AstreaOS/spotlight.json"
        readonly property string weatherCli: Quickshell.env("HOME") + "/.local/share/Astrea/Apps/Weather/backend/target/release/weather-cli"
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

        function toggle() {
            if (open) {
                close()
            } else {
                open = true
                maybeRefreshWeather()
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
            if (weatherEnabled) maybeRefreshWeather()
        }

        function maybeRefreshWeather() {
            if (!weatherEnabled || weatherLoading) return
            const now = Date.now()
            if (!weatherReady || weatherLastRefreshMs <= 0 || now - weatherLastRefreshMs >= weatherStaleMs) {
                refreshWeather()
            }
        }

        function refreshWeather() {
            if (!weatherEnabled || weatherLoading) return
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
            const assetRoot = "file://" + Quickshell.env("HOME") + "/.local/share/Astrea/Apps/Weather/assets/icons/weather/"

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

        function matchTier(searchableName, searchableExec, query, searchTerms) {
            if (searchableName.startsWith(query)) return 0
            if (searchTerms.every(term => searchableName.split(/[\s-]+/).some(part => part.startsWith(term)))) return 1
            if (searchTerms.every(term => searchableName.includes(term))) return 1
            if (searchableExec.startsWith(query)) return 2
            return 3
        }

        function persistUsage() {
            usageSaveProc.command = [
                "python3",
                "-c",
                "import json, os, sys, tempfile; path = sys.argv[1]; data = json.loads(sys.argv[2]); os.makedirs(os.path.dirname(path), exist_ok=True); fd, tmp = tempfile.mkstemp(dir=os.path.dirname(path), prefix='.spotlight-', suffix='.json'); os.close(fd); open(tmp, 'w', encoding='utf-8').write(json.dumps(data)); os.replace(tmp, path)",
                usageFilePath,
                JSON.stringify(usageCounts)
            ]
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
            const q = query.trim().toLowerCase()
            if (q === "") { results = []; return }

            let items = []
            if (typeof DesktopEntries !== "undefined") {
                let apps = DesktopEntries.applications.values
                let searchTerms = q.split(/[\s-]+/).filter(term => term.length > 0)
                let seenKeys = new Set()

                for (let entry of apps) {
                    if (!entry || entry.noDisplay) continue

                    let searchableName = (entry.name || "").trim().toLowerCase()
                    let key = entryKey(entry)
                    if (!searchableName || seenKeys.has(key)) continue

                    let searchableExec = (entry.exec || entry.execString || "").toLowerCase()
                    let matches = searchTerms.every(term =>
                        searchableName.includes(term) || searchableExec.includes(term)
                    )

                    if (!matches) continue

                    items.push({
                        entry,
                        name: searchableName,
                        exec: searchableExec,
                        tier: matchTier(searchableName, searchableExec, q, searchTerms),
                        usage: usageCountFor(entry)
                    })
                    seenKeys.add(key)
                }

                items.sort((a, b) => {
                    if (a.tier !== b.tier) return a.tier - b.tier
                    if (a.usage !== b.usage) return b.usage - a.usage
                    return a.name.localeCompare(b.name)
                })
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

            // entry.execute() é a forma correta — o Quickshell lança o app
            // completamente desacoplado, como um processo independente,
            // sem herdar nada do Quickshell
            Qt.callLater(() => {
                entry.execute()
                if (standalone && !usageSaveProc.running) Qt.quit()
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
            running: spotlight.weatherEnabled && spotlight.open
            onTriggered: spotlight.maybeRefreshWeather()
        }

        property var usageLoadProc: Process {
            id: usageLoadProc
            command: [
                "python3",
                "-c",
                "import json, os, sys; path = sys.argv[1]; print(json.dumps(json.load(open(path, encoding='utf-8'))) if os.path.exists(path) else '{}')",
                spotlight.usageFilePath
            ]
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

        property var configLoadProc: Process {
            id: configLoadProc
            command: [
                "python3",
                "-c",
                "import json, os, sys; path=sys.argv[1]; default={'weather': True}; os.makedirs(os.path.dirname(path), exist_ok=True); open(path, 'w', encoding='utf-8').write(json.dumps(default, indent=2)) if not os.path.exists(path) else None; print(open(path, encoding='utf-8').read())",
                spotlight.configFilePath
            ]
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
            command: ["/usr/bin/env", spotlight.weatherCli, "summary"]
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
