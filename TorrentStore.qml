import QtQuick

QtObject {
    id: root

    required property TransmissionClient client
    property alias model: visibleModel
    property string searchText: ""
    property string statusFilter: "all"
    property string sortRole: "name"
    property bool sortAscending: true
    property bool refreshInFlight: false
    property bool stale: !client.connected
    property string errorMessage: ""
    property real downloadSpeed: 0
    property real uploadSpeed: 0
    property var items: []

    signal updated()
    signal mutationFinished(string message, bool success)

    property ListModel internalVisibleModel: ListModel {
        id: visibleModel
        dynamicRoles: true
    }

    property Timer pollTimer: Timer {
        interval: 2000
        repeat: true
        running: root.client.connected
        onTriggered: root.refresh()
    }

    property Connections clientConnections: Connections {
        target: root.client
        function onBecameConnected() { root.stale = false; root.refresh() }
        function onBecameDisconnected() { root.stale = true }
        function onConnectedChanged() { if (!root.client.connected) root.stale = true }
    }

    onSearchTextChanged: rebuildVisibleModel()
    onStatusFilterChanged: rebuildVisibleModel()
    onSortRoleChanged: rebuildVisibleModel()
    onSortAscendingChanged: rebuildVisibleModel()

    function refresh() {
        if (!client.connected || refreshInFlight)
            return
        refreshInFlight = true
        var torrentDone = false
        var statsDone = false
        var failed = false
        var nextItems = null
        var nextStats = null
        function complete() {
            if (!torrentDone || !statsDone)
                return
            refreshInFlight = false
            if (failed)
                return
            items = nextItems
            downloadSpeed = Number(nextStats.download_speed) || 0
            uploadSpeed = Number(nextStats.upload_speed) || 0
            stale = false
            errorMessage = ""
            rebuildVisibleModel()
            updated()
        }
        client.request("torrent_get", { fields: [
            "id", "name", "hash_string", "download_dir", "total_size",
            "percent_complete", "status", "rate_download", "rate_upload",
            "upload_ratio", "eta", "downloaded_ever", "uploaded_ever", "error_string"
        ] }, false, function(result, error) {
            torrentDone = true
            if (error) {
                failed = true
                stale = true
                errorMessage = error.message
            } else {
                nextItems = result.torrents || []
            }
            complete()
        })
        client.request("session_stats", {}, false, function(result, error) {
            statsDone = true
            if (error) {
                failed = true
                stale = true
                errorMessage = error.message
            } else {
                nextStats = result
            }
            complete()
        })
    }

    function rebuildVisibleModel() {
        var query = searchText.trim().toLowerCase()
        var filtered = []
        for (var i = 0; i < items.length; ++i) {
            var torrent = items[i]
            if (query && String(torrent.name).toLowerCase().indexOf(query) < 0)
                continue
            if (statusFilter === "downloading" && torrent.status !== 3 && torrent.status !== 4)
                continue
            if (statusFilter === "seeding" && torrent.status !== 5 && torrent.status !== 6)
                continue
            if (statusFilter === "stopped" && torrent.status !== 0)
                continue
            filtered.push(torrent)
        }
        var role = sortRole
        var direction = sortAscending ? 1 : -1
        filtered.sort(function(a, b) {
            var left = a[role]
            var right = b[role]
            if (typeof left === "string") {
                left = left.toLowerCase()
                right = String(right).toLowerCase()
            }
            if (left < right) return -direction
            if (left > right) return direction
            return (Number(a.id) - Number(b.id)) * direction
        })
        visibleModel.clear()
        for (i = 0; i < filtered.length; ++i)
            visibleModel.append(filtered[i])
    }

    function torrentById(id) {
        for (var i = 0; i < items.length; ++i)
            if (items[i].id === id)
                return items[i]
        return null
    }

    function runMutation(label, operation) {
        if (!client.connected)
            return
        operation(function(result, error) {
            if (error) {
                errorMessage = error.message
                mutationFinished(error.message, false)
                if (error.kind === "timeout")
                    refresh()
                return
            }
            errorMessage = ""
            mutationFinished(label, true)
            refresh()
        })
    }

    function add(link, directory, startImmediately) {
        runMutation("Torrent added", function(done) {
            client.addTorrent(link, directory, startImmediately, function(result, error) {
                if (!error && result.torrent_duplicate)
                    error = { message: "That torrent is already present", kind: "duplicate", retryable: false }
                done(result, error)
            })
        })
    }

    function start(id) { runMutation("Torrent started", function(done) { client.startTorrent(id, done) }) }
    function stop(id) { runMutation("Torrent stopped", function(done) { client.stopTorrent(id, done) }) }
    function remove(id) { runMutation("Torrent removed (downloaded files preserved)", function(done) { client.removeTorrent(id, done) }) }
}
