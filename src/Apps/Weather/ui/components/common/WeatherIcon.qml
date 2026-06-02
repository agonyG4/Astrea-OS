import QtQuick 2.15
import QtQuick.Layouts 1.15

Item {
    id: root

    property string condition: ""
    property string isoTime: ""
    property int iconSize: 32

    width: iconSize
    height: iconSize
    implicitWidth: iconSize
    implicitHeight: iconSize
    Layout.preferredWidth: iconSize
    Layout.preferredHeight: iconSize
    Layout.minimumWidth: iconSize
    Layout.minimumHeight: iconSize
    Layout.maximumWidth: iconSize
    Layout.maximumHeight: iconSize

    Image {
        anchors.fill: parent
        source: "../../../assets/icons/weather/" + root.iconFile(root.condition, root.isoTime)
        sourceSize: Qt.size(root.iconSize * 2, root.iconSize * 2)
        fillMode: Image.PreserveAspectFit
        smooth: true
        mipmap: false
        asynchronous: true
        retainWhileLoading: true
    }

    function isNight(value) {
        if (!value)
            return false

        var hour = Number(String(value).slice(11, 13))
        return !isNaN(hour) && (hour < 6 || hour >= 18)
    }

    function iconFile(desc, time) {
        if (!desc)
            return "clear.png"

        var d = desc.toLowerCase()
        var night = isNight(time)

        if (d.includes("pôr do sol") || d.includes("por do sol"))
            return "sunset.png"
        if (d.includes("vento"))
            return "breeze.png"
        if (d.includes("nascer do sol"))
            return "sunrise.png"
        if (d.includes("trovoada"))
            return "thunderstorm.png"
        if (d.includes("granizo"))
            return "freezing_rain.png"
        if (d.includes("neve forte"))
            return "intense_snow.png"
        if (d.includes("neve"))
            return "snow.png"
        if (d.includes("chuva gelada") || d.includes("garoa gelada"))
            return "freezing_rain.png"
        if (d.includes("pancadas fortes") || d.includes("chuva forte") || d.includes("garoa forte"))
            return "heavy_rain.png"
        if (d.includes("garoa") || d.includes("chuva leve") || d.includes("pancadas"))
            return night ? "light_rain_night.png" : "light_rain.png"
        if (d.includes("chuva"))
            return "rain.png"
        if (d.includes("névoa com gelo") || d.includes("nevoa com gelo"))
            return "fog.png"
        if (d.includes("névoa") || d.includes("nevoa"))
            return "mist.png"
        if (d.includes("principalmente limpo"))
            return night ? "clear_night.png" : "clear.png"
        if (d.includes("parcialmente"))
            return "partially_cloudy.png"
        if (d.includes("nublado"))
            return "cloudy.png"
        if (d.includes("principalmente"))
            return night ? "clear_night.png" : "clear.png"
        if (d.includes("limpo") || d.includes("céu") || d.includes("ceu") || d.includes("ensolarado"))
            return night ? "clear_night.png" : "clear.png"

        return "clear.png"
    }
}
