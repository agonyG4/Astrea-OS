.pragma library

const schemaVersion = 6

const defaultModules = [
    { "moduleId": "wifi", "kind": "wifi", "size": "small", "group": "", "slot": 0 },
    { "moduleId": "bluetooth", "kind": "bluetooth", "size": "small", "group": "", "slot": 1 },
    { "moduleId": "airdrop", "kind": "airdrop", "size": "small", "group": "", "slot": 2 },
    { "moduleId": "focus", "kind": "focus", "size": "small", "group": "", "slot": 3 },
    { "moduleId": "mirror", "kind": "mirror", "size": "small", "group": "", "slot": 4 },
    { "moduleId": "brightness", "kind": "brightness", "size": "small", "group": "", "slot": 8 },
    { "moduleId": "volume", "kind": "volume", "size": "small", "group": "", "slot": 12 },
    { "moduleId": "media", "kind": "media", "size": "medium", "group": "", "slot": 16 }
]

const widgetCatalog = [
    {
        "kind": "wifi",
        "icon": "󰖩",
        "label": "Wi-Fi",
        "summary": "Wireless network and current connection",
        "accent": "#34b7f1"
    },
    {
        "kind": "bluetooth",
        "icon": "󰂯",
        "label": "Bluetooth",
        "summary": "Bluetooth power and devices",
        "accent": "#4aa3ff"
    },
    {
        "kind": "airdrop",
        "icon": "󰀝",
        "label": "AirDrop",
        "summary": "Quick sharing",
        "accent": "#28c7fa"
    },
    {
        "kind": "focus",
        "icon": "󰘶",
        "label": "Focus",
        "summary": "Focus mode",
        "accent": "#9b8cff"
    },
    {
        "kind": "mirror",
        "icon": "󰍺",
        "label": "Mirror",
        "summary": "Screen mirroring",
        "accent": "#6bd6b7"
    },
    {
        "kind": "brightness",
        "icon": "󰃠",
        "label": "Display",
        "summary": "Monitor brightness slider",
        "accent": "#ffd166"
    },
    {
        "kind": "volume",
        "icon": "󰕾",
        "label": "Sound",
        "summary": "Main volume and mute",
        "accent": "#8bd450"
    },
    {
        "kind": "media",
        "icon": "󰝚",
        "label": "Now Playing",
        "summary": "Current media and playback controls",
        "accent": "#ff7ab6"
    }
]

const definitions = {
    "wifi": {
        "label": "Wi-Fi",
        "defaultSize": "small",
        "span": 1,
        "sizes": { "small": 74, "medium": 92, "large": 120 }
    },
    "bluetooth": {
        "label": "Bluetooth",
        "defaultSize": "small",
        "span": 1,
        "sizes": { "small": 74, "medium": 92, "large": 120 }
    },
    "airdrop": {
        "label": "AirDrop",
        "defaultSize": "small",
        "span": 1,
        "sizes": { "small": 74, "medium": 92, "large": 120 }
    },
    "focus": {
        "label": "Focus",
        "defaultSize": "small",
        "span": 1,
        "sizes": { "small": 74, "medium": 92, "large": 120 }
    },
    "mirror": {
        "label": "Mirror",
        "defaultSize": "small",
        "span": 1,
        "sizes": { "small": 74, "medium": 92, "large": 120 }
    },
    "brightness": {
        "label": "Display",
        "defaultSize": "small",
        "span": 4,
        "sizes": { "small": 68, "medium": 92, "large": 120 }
    },
    "volume": {
        "label": "Sound",
        "defaultSize": "small",
        "span": 4,
        "sizes": { "small": 68, "medium": 92, "large": 120 }
    },
    "media": {
        "label": "Now Playing",
        "defaultSize": "medium",
        "span": 4,
        "sizes": { "small": 68, "medium": 84, "large": 128 }
    }
}

const legacyExpansions = {
    "main": ["wifi", "bluetooth", "airdrop", "focus", "mirror"]
}

function hasModule(kind) {
    return definitions[kind] !== undefined
}

function moduleLabel(kind) {
    const def = definitions[kind]
    return def ? def.label : kind
}

function defaultSize(kind) {
    const def = definitions[kind]
    return def ? def.defaultSize : "small"
}

function moduleHeight(kind, size) {
    const def = definitions[kind]
    if (!def)
        return 68

    const requestedSize = size && def.sizes[size] !== undefined ? size : def.defaultSize
    return def.sizes[requestedSize]
}

function moduleSpan(kind) {
    const def = definitions[kind]
    return def && def.span !== undefined ? def.span : 4
}

function cloneDefaultModules() {
    const modules = []
    for (let i = 0; i < defaultModules.length; i++)
        modules.push(normalizeModule(defaultModules[i]))
    return modules
}

function availableWidgets() {
    const widgets = []
    for (let i = 0; i < widgetCatalog.length; i++)
        widgets.push(widgetCatalog[i])
    return widgets
}

function createModule(kind) {
    if (!hasModule(kind))
        return null
    return normalizeModule({ "moduleId": kind, "kind": kind, "size": defaultSize(kind), "group": "", "slot": -1 })
}

function appendUnique(modules, seen, module) {
    const normalized = normalizeModule(module)
    if (normalized && !seen[normalized.moduleId]) {
        modules.push(normalized)
        seen[normalized.moduleId] = true
    }
}

function expandLegacyKind(kind, modules, seen) {
    const expansion = legacyExpansions[kind]
    if (!expansion)
        return false

    for (let i = 0; i < expansion.length; i++) {
        const childKind = expansion[i]
        appendUnique(modules, seen, { "moduleId": childKind, "kind": childKind, "size": defaultSize(childKind), "group": "", "slot": -1 })
    }

    return true
}

function normalizeModule(source) {
    const kind = source && source.kind ? source.kind : ""
    if (!hasModule(kind))
        return null

    const moduleId = source.moduleId && source.moduleId !== "" ? source.moduleId : kind
    const size = source.size && definitions[kind].sizes[source.size] !== undefined ? source.size : defaultSize(kind)
    const group = source.group ? source.group : ""
    const slot = source.slot !== undefined && source.slot >= 0 ? Math.floor(source.slot) : -1
    return { "moduleId": moduleId, "kind": kind, "size": size, "group": group, "slot": slot }
}

function canPlace(slot, span, used) {
    const columns = 4
    const col = slot % columns
    if (span >= columns && col !== 0)
        return false
    if (col + span > columns)
        return false

    for (let i = 0; i < span; i++) {
        if (used[slot + i])
            return false
    }
    return true
}

function markSlot(slot, span, used) {
    for (let i = 0; i < span; i++)
        used[slot + i] = true
}

function nextFreeSlot(span, used) {
    const columns = 4
    for (let slot = 0; slot < 128; slot++) {
        const candidate = span >= columns ? Math.ceil(slot / columns) * columns : slot
        if (canPlace(candidate, span, used))
            return candidate
    }
    return 0
}

function assignSlots(modules) {
    const used = {}
    for (let i = 0; i < modules.length; i++) {
        const module = modules[i]
        const span = moduleSpan(module.kind)
        let slot = module.slot
        if (slot < 0 || !canPlace(slot, span, used))
            slot = nextFreeSlot(span, used)
        module.slot = slot
        markSlot(slot, span, used)
    }
    return modules
}

function modulesFromLegacyOrder(order) {
    const modules = []
    const seen = {}

    if (order) {
        for (let i = 0; i < order.length; i++) {
            const kind = order[i]
            if (!expandLegacyKind(kind, modules, seen))
                appendUnique(modules, seen, { "moduleId": kind, "kind": kind, "size": defaultSize(kind), "group": "", "slot": -1 })
        }
    }

    for (let j = 0; j < defaultModules.length; j++) {
        const fallback = defaultModules[j]
        appendUnique(modules, seen, fallback)
    }

    return assignSlots(modules)
}

function migrateModules(savedModules) {
    const modules = []
    const seen = {}

    if (savedModules) {
        for (let i = 0; i < savedModules.length; i++) {
            const source = savedModules[i]
            const kind = source && source.kind ? source.kind : ""
            if (!expandLegacyKind(kind, modules, seen))
                appendUnique(modules, seen, source)
        }
    }

    if (modules.length === 0)
        return cloneDefaultModules()

    return assignSlots(modules)
}
