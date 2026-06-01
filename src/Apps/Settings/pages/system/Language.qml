import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../AstreaComponents"
import "../../AstreaI18n" as AstreaI18n

ScrollPage {
    id: root
    maxWidth: 900

    readonly property color textPrimary: Theme.textPrimary
    readonly property color textSecondary: Theme.textSecondary
    readonly property color cardBg: Theme.cardBg
    readonly property color cardBorder: Theme.cardBorder
    readonly property color accent: Theme.accent
    readonly property color popupBg: Theme.popupBg
    readonly property color errorColor: Theme.errorColor
    readonly property color successColor: Theme.successColor

    readonly property string astreaRoot: Quickshell.env("ASTREA_ROOT") || ((Quickshell.env("HOME") || "") + "/.local/share/Astrea")
    readonly property string regionScript: astreaRoot + "/Core/bridge/system/region.py"
    property var languageValues: ["en_US", "pt_BR"]
    property var languageOptions: []
    property var countryData: [
        { code: "BR", name: "Brazil" },
        { code: "US", name: "United States" },
        { code: "PT", name: "Portugal" },
        { code: "GB", name: "United Kingdom" },
        { code: "FR", name: "France" },
        { code: "ES", name: "Spain" },
        { code: "DE", name: "Germany" },
        { code: "IT", name: "Italy" },
        { code: "CA", name: "Canada" },
        { code: "JP", name: "Japan" },
        { code: "AR", name: "Argentina" },
        { code: "CL", name: "Chile" },
        { code: "UY", name: "Uruguay" }
    ]
    property var countryValues: countryData.map(item => item.code)
    property var countryOptions: []
    property string countrySearchText: ""
    property var filteredCountryOptions: []
    property var filteredCountryIndexes: []
    property var timeFormatValues: ["system", "24h", "12h"]
    property var timeFormatOptions: []

    property bool loading: true
    property string errorMessage: ""
    property string saveMessage: ""
    property string _configBuf: ""
    property int selectedLanguage: 0
    property int selectedCountry: 0
    property int selectedTimeFormat: 0
    property string resolvedTimeFormat: "24h"
    property bool automaticLocation: true
    property string geolocationServiceState: ""
    property var settingsConfig: ({
        language: "en_US",
        region: {
            country_code: "BR",
            time_format: "system",
            automatic_location: true
        }
    })

    function t(key, fallback, params) { return AstreaI18n.I18n.tr(key, fallback, params) }

    function languageLabel(code) {
        var key = "settings.language.option." + code.toLowerCase()
        return t(key, code)
    }

    function countryLabel(code, fallback) {
        return t("settings.language.country." + String(code || "").toLowerCase(), fallback || code)
    }

    function countryDefaultTimeFormat(index) {
        var item = countryData[index >= 0 ? index : selectedCountry] || ({})
        return item.time_format === "12h" ? "12h" : "24h"
    }

    function resolvedTimeFormatLabel() {
        var value = root.countryDefaultTimeFormat(root.selectedCountry)
        return value === "12h"
            ? root.t("settings.language.time_format.12h", "12-hour")
            : root.t("settings.language.time_format.24h", "24-hour")
    }

    function timeFormatLabel(value) {
        if (value === "12h")
            return root.t("settings.language.time_format.12h", "12-hour")
        if (value === "24h")
            return root.t("settings.language.time_format.24h", "24-hour")
        return root.t("settings.language.time_format.system_with_value", "System default ({format})", {
            format: root.resolvedTimeFormatLabel()
        })
    }

    function rebuildLanguageOptions() {
        languageOptions = languageValues.map(languageLabel)
    }

    function rebuildCountryOptions() {
        countryOptions = countryData.map(item => root.countryLabel(item.code, item.name || item.code))
        rebuildFilteredCountryOptions()
    }

    function normalizedSearch(value) {
        return String(value || "").trim().toLowerCase()
    }

    function rebuildFilteredCountryOptions() {
        var query = normalizedSearch(root.countrySearchText)
        var labels = []
        var indexes = []
        for (var i = 0; i < root.countryData.length; i++) {
            var item = root.countryData[i] || ({})
            var label = root.countryOptions[i] || root.countryLabel(item.code, item.name || item.code)
            var haystack = normalizedSearch(label + " " + (item.name || "") + " " + (item.code || ""))
            if (query === "" || haystack.indexOf(query) >= 0) {
                labels.push(label)
                indexes.push(i)
            }
        }
        root.filteredCountryOptions = labels
        root.filteredCountryIndexes = indexes
    }

    function rebuildTimeFormatOptions() {
        timeFormatOptions = timeFormatValues.map(timeFormatLabel)
    }

    function indexFor(values, value, fallback) {
        var idx = values.indexOf(value)
        return idx >= 0 ? idx : fallback
    }

    function indexForLanguage(value) {
        return indexFor(root.languageValues, (value || "en_US").replace("-", "_"), 0)
    }

    function indexForCountry(value) {
        return indexFor(root.countryValues, (value || "BR").toUpperCase(), 0)
    }

    function indexForTimeFormat(value) {
        return indexFor(root.timeFormatValues, (value || "system").toLowerCase(), 0)
    }

    function normalizeConfig(cfg) {
        var next = Object.assign({}, root.settingsConfig, cfg || {})
        next.region = Object.assign({}, root.settingsConfig.region || {}, (cfg || {}).region || {})
        return next
    }

    function applyPayload(payload) {
        if (!payload)
            return
        if (payload.countries && payload.countries.length > 0) {
            root.countryData = payload.countries
            root.countryValues = payload.countries.map(item => item.code)
            root.rebuildCountryOptions()
        }
        if (payload.time_formats && payload.time_formats.length > 0) {
            var ordered = ["system", "24h", "12h"]
            root.timeFormatValues = ordered.filter(value => payload.time_formats.indexOf(value) >= 0)
        }
        root.settingsConfig = normalizeConfig(payload.config || {})
        root.selectedLanguage = root.indexForLanguage(root.settingsConfig.language || AstreaI18n.I18n.language)
        root.selectedCountry = root.indexForCountry((root.settingsConfig.region || {}).country_code)
        root.selectedTimeFormat = root.indexForTimeFormat((root.settingsConfig.region || {}).time_format)
        root.resolvedTimeFormat = payload.effective_time_format || root.countryDefaultTimeFormat(root.selectedCountry)
        root.automaticLocation = (root.settingsConfig.region || {}).automatic_location !== false
        if (payload.geolocation_service)
            root.geolocationServiceState = payload.geolocation_service.state || ""
        root.rebuildTimeFormatOptions()
    }

    onCountrySearchTextChanged: rebuildFilteredCountryOptions()

    function runSave(args) {
        if (saveConfigProc.running)
            return
        saveConfigProc.buffer = ""
        saveConfigProc.command = ["python3", root.regionScript, "set"].concat(args)
        saveConfigProc.running = true
    }

    function setLanguage(index) {
        if (index < 0 || index >= root.languageValues.length)
            return
        root.selectedLanguage = index
        runSave(["--language", root.languageValues[index]])
    }

    function setCountry(index) {
        if (index < 0 || index >= root.countryValues.length)
            return
        root.selectedCountry = index
        root.resolvedTimeFormat = root.countryDefaultTimeFormat(index)
        root.rebuildTimeFormatOptions()
        runSave(["--country-code", root.countryValues[index]])
    }

    function setTimeFormat(index) {
        if (index < 0 || index >= root.timeFormatValues.length)
            return
        root.selectedTimeFormat = index
        runSave(["--time-format", root.timeFormatValues[index]])
    }

    function setAutomaticLocation(enabled) {
        runSave(["--automatic-location", enabled ? "true" : "false"])
    }

    Component.onCompleted: {
        root.rebuildLanguageOptions()
        root.rebuildCountryOptions()
        root.rebuildTimeFormatOptions()
        listLanguagesProc.running = true
        loadConfigProc.running = true
    }

    Connections {
        target: AstreaI18n.I18n
        function onMessagesChanged() {
            root.rebuildLanguageOptions()
            root.rebuildCountryOptions()
            root.rebuildTimeFormatOptions()
        }
    }

    Process {
        id: listLanguagesProc
        command: ["python3", root.astreaRoot + "/System/i18n/i18n.py", "list-languages"]
        property string buffer: ""
        stdout: SplitParser { onRead: data => listLanguagesProc.buffer += data }
        onExited: code => {
            if (code === 0) {
                try {
                    var langs = JSON.parse(buffer || "[]")
                    if (langs.length > 0)
                        root.languageValues = langs
                } catch (e) {}
            }
            buffer = ""
            root.rebuildLanguageOptions()
            root.selectedLanguage = root.indexForLanguage(root.settingsConfig.language || AstreaI18n.I18n.language)
        }
    }

    Process {
        id: loadConfigProc
        command: ["python3", root.regionScript, "get"]
        stdout: SplitParser {
            onRead: line => root._configBuf += line
        }
        onExited: code => {
            if (code !== 0) {
                root.errorMessage = root.t("settings.language.error.load", "Could not read language and region settings.")
            } else {
                try {
                    root.applyPayload(JSON.parse(root._configBuf || "{}"))
                } catch (e) {
                    root.errorMessage = root.t("settings.language.error.parse", "Could not parse language settings: ") + e
                }
            }
            root._configBuf = ""
            root.loading = false
        }
    }

    Process {
        id: saveConfigProc
        command: []
        property string buffer: ""
        stdout: SplitParser { onRead: data => saveConfigProc.buffer += data }
        onExited: code => {
            if (code === 0) {
                try {
                    var payload = JSON.parse(saveConfigProc.buffer || "{}")
                    root.applyPayload(payload)
                    var service = payload.geolocation_service || {}
                    if (service.action === "disable" && service.ok === false) {
                        root.errorMessage = root.t("settings.language.error.geolocation_disable", "Region saved, but GeoClue could not be disabled: ") + (service.detail || "")
                    } else {
                        root.errorMessage = ""
                        root.saveMessage = root.t("settings.language.saved", "Language and region updated.")
                        saveMessageTimer.restart()
                    }
                } catch (e) {
                    root.errorMessage = root.t("settings.language.error.parse", "Could not parse language settings: ") + e
                }
                AstreaI18n.I18n.reload()
            } else {
                root.errorMessage = root.t("settings.language.error.save", "Could not save language and region settings.")
            }
            saveConfigProc.buffer = ""
        }
    }

    Timer {
        id: saveMessageTimer
        interval: 1800
        repeat: false
        onTriggered: root.saveMessage = ""
    }

    Item {
        Layout.alignment: Qt.AlignHCenter
        visible: root.loading
        width: 48
        height: 48

        BusyIndicator {
            anchors.fill: parent
            running: root.loading
        }
    }

    ColumnLayout {
        width: parent.width
        spacing: 0
        visible: !root.loading

        SectionHeader {
            text: root.t("settings.language.header", "LANGUAGE & REGION")
            textSecondary: root.textSecondary
            Layout.bottomMargin: 12
        }

        Text {
            visible: root.errorMessage !== ""
            text: root.errorMessage
            color: root.errorColor
            font.pixelSize: 12
            wrapMode: Text.Wrap
            Layout.fillWidth: true
            Layout.bottomMargin: 12
        }

        Text {
            visible: root.saveMessage !== ""
            text: root.saveMessage
            color: root.successColor
            font.pixelSize: 12
            wrapMode: Text.Wrap
            Layout.fillWidth: true
            Layout.bottomMargin: 12
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.bottomMargin: 28
            radius: 12
            color: root.cardBg
            border.width: 1
            border.color: root.cardBorder
            implicitHeight: languageCol.implicitHeight

            ColumnLayout {
                id: languageCol
                anchors { left: parent.left; right: parent.right }
                spacing: 0

                SettingRow {
                    label: root.t("settings.language.row.language", "Language")
                    sublabel: root.t("settings.language.row.language.description", "Choose the language used by AstreaOS apps and shell.")
                    textPrimary: root.textPrimary
                    textSecondary: root.textSecondary
                    cardBorder: root.cardBorder

                    SelectButton {
                        implicitWidth: 220
                        label: root.languageOptions[root.selectedLanguage] || ""
                        options: root.languageOptions
                        selectedIndex: root.selectedLanguage
                        accent: root.accent
                        textPrimary: root.textPrimary
                        textSecondary: root.textSecondary
                        popupBg: root.popupBg
                        onSelected: index => root.setLanguage(index)
                    }
                }

                SettingRow {
                    label: root.t("settings.language.row.country_search", "Search location")
                    sublabel: root.t("settings.language.row.country_search.description", "Type a country, region or country code to filter the list below.")
                    textPrimary: root.textPrimary
                    textSecondary: root.textSecondary
                    cardBorder: root.cardBorder

                    SearchField {
                        implicitWidth: 220
                        placeholderText: root.t("settings.language.search.country", "Search country")
                        text: root.countrySearchText
                        accent: root.accent
                        textPrimary: root.textPrimary
                        textSecondary: root.textSecondary
                        surfaceColor: root.popupBg
                        borderColor: root.cardBorder
                        controlHeight: 36
                        onTextEdited: value => root.countrySearchText = value
                        onCleared: root.countrySearchText = ""
                    }
                }

                SettingRow {
                    label: root.t("settings.language.row.country", "Country or region")
                    sublabel: root.filteredCountryOptions.length === 0
                        ? root.t("settings.language.row.country.no_results", "No locations match your search.")
                        : root.t("settings.language.row.country.description", "Used for weather providers, regional defaults and date/time formatting.")
                    textPrimary: root.textPrimary
                    textSecondary: root.filteredCountryOptions.length === 0 ? root.errorColor : root.textSecondary
                    cardBorder: root.cardBorder

                    SelectButton {
                        implicitWidth: 220
                        label: root.countryOptions[root.selectedCountry] || ""
                        options: root.filteredCountryOptions.length > 0 ? root.filteredCountryOptions : [root.t("settings.language.search.no_results", "No results")]
                        selectedIndex: root.filteredCountryIndexes.indexOf(root.selectedCountry)
                        accent: root.accent
                        textPrimary: root.textPrimary
                        textSecondary: root.textSecondary
                        popupBg: root.popupBg
                        onSelected: index => {
                            if (index >= 0 && index < root.filteredCountryIndexes.length)
                                root.setCountry(root.filteredCountryIndexes[index])
                        }
                    }
                }

                SettingRow {
                    label: root.t("settings.language.row.time_format", "Time format")
                    sublabel: root.t("settings.language.row.time_format.description", "Controls 24-hour or AM/PM time in apps and the top bar clock.")
                    textPrimary: root.textPrimary
                    textSecondary: root.textSecondary
                    cardBorder: root.cardBorder

                    SelectButton {
                        implicitWidth: 220
                        label: root.timeFormatOptions[root.selectedTimeFormat] || ""
                        options: root.timeFormatOptions
                        selectedIndex: root.selectedTimeFormat
                        accent: root.accent
                        textPrimary: root.textPrimary
                        textSecondary: root.textSecondary
                        popupBg: root.popupBg
                        onSelected: index => root.setTimeFormat(index)
                    }
                }

                SettingRow {
                    label: root.t("settings.language.row.automatic_location", "Automatic location")
                    sublabel: root.automaticLocation
                        ? root.t("settings.language.row.automatic_location.enabled", "Weather can use system location before falling back to IP.")
                        : root.t("settings.language.row.automatic_location.disabled", "System geolocation is disabled; Weather needs a city or cached data.")
                    isLast: true
                    textPrimary: root.textPrimary
                    textSecondary: root.textSecondary
                    cardBorder: root.cardBorder

                    ToggleSwitch {
                        checked: root.automaticLocation
                        onToggled: target => root.setAutomaticLocation(target)
                    }
                }
            }
        }
    }
}
