.pragma library

function bytes(value) {
    var number = Number(value) || 0
    var units = ["B", "KiB", "MiB", "GiB", "TiB"]
    var unit = 0
    while (Math.abs(number) >= 1024 && unit < units.length - 1) {
        number /= 1024
        ++unit
    }
    return (unit === 0 ? Math.round(number) : number.toFixed(number < 10 ? 1 : 0)) + " " + units[unit]
}

function speed(value) {
    return bytes(value) + "/s"
}

function ratio(value) {
    value = Number(value)
    return value >= 0 && isFinite(value) ? value.toFixed(2) : "—"
}

function duration(seconds) {
    seconds = Number(seconds)
    if (seconds < 0 || !isFinite(seconds) || seconds > 315360000)
        return "—"
    seconds = Math.round(seconds)
    var days = Math.floor(seconds / 86400)
    var hours = Math.floor((seconds % 86400) / 3600)
    var minutes = Math.floor((seconds % 3600) / 60)
    if (days > 0)
        return days + "d " + hours + "h"
    if (hours > 0)
        return hours + "h " + minutes + "m"
    return minutes + "m"
}

function status(value) {
    return ["Stopped", "Queued to verify", "Verifying", "Queued to download",
            "Downloading", "Queued to seed", "Seeding"][Number(value)] || "Unknown"
}

