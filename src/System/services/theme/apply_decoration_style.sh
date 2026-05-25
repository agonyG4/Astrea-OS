#!/usr/bin/env bash
set -euo pipefail

style="${1:-}"
conf="${HOME}/.config/hypr/ui/decoration.conf"
rules_conf="${HOME}/.config/hypr/system/rules/windowrules.conf"

if [[ ! -f "${conf}" ]]; then
    exit 0
fi

case "${style}" in
    0)
        blur_enabled="true"
        active_opacity="1.0"
        inactive_opacity="0.92"
        dim_strength="0.08"
        dim_note="  # subtle depth cue - clearly active vs inactive"
        blur_size="1"
        blur_size_note="    # compact radius for the Clear shell style"
        blur_passes="3"
        blur_passes_note="   # balanced passes for subtle blur"
        blur_noise="0.012"
        blur_contrast="1"
        blur_brightness="1"
        blur_vibrancy="1"
        blur_vibrancy_darkness="0"
        blur_popups_ignorealpha="0.05"
        quickshell_layer_xray="off"
        ;;
    1)
        blur_enabled="false"
        active_opacity="1.0"
        inactive_opacity="1.0"
        dim_strength="0.08"
        dim_note="  # default shell style keeps windows fully opaque"
        blur_size="3"
        blur_size_note="    # blur disabled for Default shell style"
        blur_passes="1"
        blur_passes_note="   # blur disabled for Default shell style"
        blur_noise="0"
        blur_contrast="1"
        blur_brightness="1"
        blur_vibrancy="0"
        blur_vibrancy_darkness="0"
        blur_popups_ignorealpha="0"
        quickshell_layer_xray="off"
        ;;
    2)
        blur_enabled="true"
        active_opacity="1.0"
        inactive_opacity="1.0"
        dim_strength="0"
        dim_note="  # Frosted keeps app windows opaque; topbar layer uses xray blur"
        blur_size="5"
        blur_size_note="    # Frosted radius; Quickshell topbar uses xray"
        blur_passes="4"
        blur_passes_note="   # extra passes keep the glass smooth"
        blur_noise="0.018"
        blur_contrast="1.08"
        blur_brightness="0.96"
        blur_vibrancy="0.35"
        blur_vibrancy_darkness="0.18"
        blur_popups_ignorealpha="0.02"
        quickshell_layer_xray="on"
        ;;
    *)
        exit 0
        ;;
esac

tmp="$(mktemp)"
awk \
    -v blur_enabled="${blur_enabled}" \
    -v active_opacity="${active_opacity}" \
    -v inactive_opacity="${inactive_opacity}" \
    -v dim_strength="${dim_strength}" \
    -v dim_note="${dim_note}" \
    -v blur_size="${blur_size}" \
    -v blur_size_note="${blur_size_note}" \
    -v blur_passes="${blur_passes}" \
    -v blur_passes_note="${blur_passes_note}" \
    -v blur_noise="${blur_noise}" \
    -v blur_contrast="${blur_contrast}" \
    -v blur_brightness="${blur_brightness}" \
    -v blur_vibrancy="${blur_vibrancy}" \
    -v blur_vibrancy_darkness="${blur_vibrancy_darkness}" \
    -v blur_popups_ignorealpha="${blur_popups_ignorealpha}" '
function set_value(line, key, value, note) {
    if (line ~ "^[[:space:]]*" key "[[:space:]]*=") {
        match(line, /^[[:space:]]*/)
        return substr(line, RSTART, RLENGTH) sprintf("%-18s = %s", key, value) note
    }
    return line
}

{
    line = $0
    line = set_value(line, "active_opacity", active_opacity, "")
    line = set_value(line, "inactive_opacity", inactive_opacity, "")
    line = set_value(line, "dim_strength", dim_strength, dim_note)

    if (line ~ "^[[:space:]]*blur[[:space:]]*[{]") {
        in_blur = 1
    } else if (in_blur && line ~ "^[[:space:]]*[}]") {
        in_blur = 0
    } else if (in_blur) {
        line = set_value(line, "enabled", blur_enabled, "")
        line = set_value(line, "size", blur_size, blur_size_note)
        line = set_value(line, "passes", blur_passes, blur_passes_note)
        line = set_value(line, "noise", blur_noise, "")
        line = set_value(line, "contrast", blur_contrast, "")
        line = set_value(line, "brightness", blur_brightness, "")
        line = set_value(line, "vibrancy", blur_vibrancy, "")
        line = set_value(line, "vibrancy_darkness", blur_vibrancy_darkness, "")
        line = set_value(line, "popups_ignorealpha", blur_popups_ignorealpha, "")
    }

    print line
}
' "${conf}" > "${tmp}"

install -m 0644 "${tmp}" "${conf}"
rm -f "${tmp}"

if [[ -f "${rules_conf}" ]]; then
    tmp="$(mktemp)"
    awk -v layer_xray="${quickshell_layer_xray}" '
    function topbar_blur_rule(namespace, spacing) {
        return "layerrule = blur on," spacing "match:namespace " namespace
    }
    function topbar_xray_rule(namespace, spacing) {
        if (layer_xray == "on") {
            return "layerrule = xray on," spacing "match:namespace " namespace
        }
        return ""
    }

    $0 ~ /^[[:space:]]*layerrule[[:space:]]*=[[:space:]]*xray[[:space:]]+on,.*match:namespace[[:space:]]+(astrea-bar|bar|topbar-popup|astrea-notifications|volume-osd)[[:space:]]*$/ {
        next
    }

    $0 ~ /^[[:space:]]*layerrule[[:space:]]*=[[:space:]]*blur[[:space:]]+on,.*match:namespace[[:space:]]+astrea-bar[[:space:]]*$/ {
        print topbar_blur_rule("astrea-bar", "  ")
        if (layer_xray == "on")
            print topbar_xray_rule("astrea-bar", "  ")
        next
    }

    $0 ~ /^[[:space:]]*layerrule[[:space:]]*=[[:space:]]*blur[[:space:]]+on,.*match:namespace[[:space:]]+bar[[:space:]]*$/ {
        print topbar_blur_rule("bar", "  ")
        if (layer_xray == "on")
            print topbar_xray_rule("bar", "  ")
        next
    }
    $0 ~ /^[[:space:]]*layerrule[[:space:]]*=[[:space:]]*blur[[:space:]]+on,.*match:namespace[[:space:]]+topbar-popup[[:space:]]*$/ {
        print topbar_blur_rule("topbar-popup", " ")
        next
    }
    $0 ~ /^[[:space:]]*layerrule[[:space:]]*=[[:space:]]*blur[[:space:]]+on,.*match:namespace[[:space:]]+astrea-notifications[[:space:]]*$/ {
        print topbar_blur_rule("astrea-notifications", " ")
        next
    }
    $0 ~ /^[[:space:]]*layerrule[[:space:]]*=[[:space:]]*blur[[:space:]]+on,.*match:namespace[[:space:]]+volume-osd[[:space:]]*$/ {
        print topbar_blur_rule("volume-osd", " ")
        next
    }
    $0 ~ /^[[:space:]]*layerrule[[:space:]]*=[[:space:]]*ignore_alpha[[:space:]]+[^,]+,.*match:namespace[[:space:]]+volume-osd[[:space:]]*$/ {
        print "layerrule = ignore_alpha 0.01, match:namespace volume-osd"
        next
    }
    { print }
    ' "${rules_conf}" > "${tmp}"
    install -m 0644 "${tmp}" "${rules_conf}"
    rm -f "${tmp}"
fi

hyprctl reload >/dev/null 2>&1 || true
