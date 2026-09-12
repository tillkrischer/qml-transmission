import QtQuick

QtObject {
    id: root

    required property TransmissionClient client
    property alias model: visibleModel
    property string searchText: ""
    property string filterKind: "status"
    property string filterValue: "all"
    property bool filterChangeInProgress: false
    property var downloadDirectories: []
    property var trackerDomains: []
    property string sortRole: "added_date"
    property bool sortAscending: false
    property bool refreshInFlight: false
    property bool stale: !client.connected
    property string errorMessage: ""
    property real downloadSpeed: 0
    property real uploadSpeed: 0
    property var items: []
    property int generation: 0
    property string activeProfileId: ""

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
        function onInvalidated(newGeneration) {
            root.generation = newGeneration
            root.refreshInFlight = false
        }
    }

    onSearchTextChanged: rebuildVisibleModel()
    onFilterKindChanged: if (!filterChangeInProgress) rebuildVisibleModel()
    onFilterValueChanged: if (!filterChangeInProgress) rebuildVisibleModel()
    onSortRoleChanged: rebuildVisibleModel()
    onSortAscendingChanged: rebuildVisibleModel()

    function refresh() {
        if (!client.connected || refreshInFlight)
            return
        refreshInFlight = true
        var requestGeneration = generation
        var requestProfile = activeProfileId
        var torrentDone = false
        var statsDone = false
        var failed = false
        var nextItems = null
        var nextStats = null
        function complete() {
            if (requestGeneration !== generation || requestProfile !== activeProfileId)
                return
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
            , "error", "added_date", "trackers"
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
        updateFilterOptions()
        var query = searchText.trim().toLowerCase()
        var filtered = []
        for (var i = 0; i < items.length; ++i) {
            var torrent = items[i]
            if (query && String(torrent.name).toLowerCase().indexOf(query) < 0)
                continue
            if (filterKind === "status" && filterValue === "downloading"
                    && torrent.status !== 3 && torrent.status !== 4)
                continue
            if (filterKind === "status" && filterValue === "seeding"
                    && torrent.status !== 5 && torrent.status !== 6)
                continue
            if (filterKind === "status" && filterValue === "stopped" && torrent.status !== 0)
                continue
            if (filterKind === "directory"
                    && String(torrent.download_dir || "") !== filterValue)
                continue
            if (filterKind === "tracker"
                    && trackerDomainsForTorrent(torrent).indexOf(filterValue) < 0)
                continue
            filtered.push(torrent)
        }
        var role = sortRole
        var direction = sortAscending ? 1 : -1
        filtered.sort(function(a, b) {
            var left = a[role]
            var right = b[role]
            if (role === "added_date") {
                var leftMissing = !isFinite(Number(left)) || Number(left) <= 0
                var rightMissing = !isFinite(Number(right)) || Number(right) <= 0
                if (leftMissing !== rightMissing) return leftMissing ? 1 : -1
            }
            if (typeof left === "string") {
                left = left.toLowerCase()
                right = String(right).toLowerCase()
            }
            if (left < right) return -direction
            if (left > right) return direction
            return (Number(a.id) - Number(b.id)) * direction
        })
        reconcileVisibleModel(filtered)
    }

    function trackerDomain(url) {
        var match = String(url || "").match(/^[a-z][a-z0-9+.-]*:\/\/(?:[^@\/]+@)?(\[[^\]]+\]|[^:\/?#]+)/i)
        return match ? match[1].toLowerCase() : ""
    }

    function selectFilter(kind, value) {
        if (filterKind === kind && filterValue === value)
            return
        filterChangeInProgress = true
        filterKind = kind
        filterValue = value
        filterChangeInProgress = false
        rebuildVisibleModel()
    }

    function trackerDomainsForTorrent(torrent) {
        var result = []
        var trackers = torrent && Array.isArray(torrent.trackers) ? torrent.trackers : []
        for (var i = 0; i < trackers.length; ++i) {
            var domain = trackerDomain(trackers[i].announce)
            if (domain && result.indexOf(domain) < 0)
                result.push(domain)
        }
        return result
    }

    function updateFilterOptions() {
        var directories = []
        var domains = []
        for (var i = 0; i < items.length; ++i) {
            var directory = String(items[i].download_dir || "")
            if (directory && directories.indexOf(directory) < 0)
                directories.push(directory)
            var torrentDomains = trackerDomainsForTorrent(items[i])
            for (var j = 0; j < torrentDomains.length; ++j)
                if (domains.indexOf(torrentDomains[j]) < 0)
                    domains.push(torrentDomains[j])
        }
        directories.sort(function(a, b) { return a.localeCompare(b) })
        domains.sort(function(a, b) { return a.localeCompare(b) })
        if (!sameValues(downloadDirectories, directories))
            downloadDirectories = directories
        if (!sameValues(trackerDomains, domains))
            trackerDomains = domains
        if ((filterKind === "directory" && directories.indexOf(filterValue) < 0)
                || (filterKind === "tracker" && domains.indexOf(filterValue) < 0))
            selectFilter("status", "all")
    }

    function sameValues(left, right) {
        if (left.length !== right.length)
            return false
        for (var i = 0; i < left.length; ++i)
            if (left[i] !== right[i])
                return false
        return true
    }

    // Keep existing ListModel rows alive across polling refreshes. Rebuilding the
    // model with clear()/append() briefly makes the ListView's content empty and
    // causes Qt to clamp contentY, which shows up as a jump when wheel scrolling
    // ends. Match rows by the daemon-stable torrent hash, move them when sorting
    // changed, and update their values in place.
    function reconcileVisibleModel(filtered) {
        for (var i = 0; i < filtered.length; ++i) {
            var hash = String(filtered[i].hash_string)
            var existingIndex = -1
            for (var j = i; j < visibleModel.count; ++j) {
                if (String(visibleModel.get(j).hash_string) === hash) {
                    existingIndex = j
                    break
                }
            }

            if (existingIndex < 0)
                visibleModel.insert(i, filtered[i])
            else if (existingIndex !== i)
                visibleModel.move(existingIndex, i, 1)

            visibleModel.set(i, filtered[i])
        }

        if (visibleModel.count > filtered.length)
            visibleModel.remove(filtered.length, visibleModel.count - filtered.length)
    }

    function torrentById(id) {
        for (var i = 0; i < items.length; ++i)
            if (items[i].id === id)
                return items[i]
        return null
    }

    function torrentByHash(hash) {
        for (var i = 0; i < items.length; ++i)
            if (items[i].hash_string === hash)
                return items[i]
        return null
    }

    function activateProfile(profileId, preserveRows) {
        ++generation
        activeProfileId = profileId || ""
        refreshInFlight = false
        errorMessage = ""
        if (!preserveRows) {
            items = []
            downloadSpeed = 0
            uploadSpeed = 0
            rebuildVisibleModel()
            updated()
        }
    }

    function runMutation(label, operation) {
        if (!client.connected)
            return
        var mutationGeneration = generation
        var mutationProfile = activeProfileId
        operation(function(result, error) {
            if (mutationGeneration !== generation || mutationProfile !== activeProfileId)
                return
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
            client.addTorrent(link, directory, !startImmediately, false, function(result, error) {
                if (!error && result.torrent_duplicate)
                    error = { message: "That torrent is already present", kind: "duplicate", retryable: false }
                done(result, error)
            })
        })
    }

    function mutationLabel(count, singular, plural) {
        return count === 1 ? singular : String(count) + " " + plural
    }

    function start(hashes) {
        var ids = Array.isArray(hashes) ? hashes : [hashes]
        runMutation(mutationLabel(ids.length, "Torrent started", "torrents started"),
                    function(done) { client.startTorrent(ids, done) })
    }
    function stop(hashes) {
        var ids = Array.isArray(hashes) ? hashes : [hashes]
        runMutation(mutationLabel(ids.length, "Torrent stopped", "torrents stopped"),
                    function(done) { client.stopTorrent(ids, done) })
    }
    function remove(hashes, deleteLocalData) {
        var ids = Array.isArray(hashes) ? hashes : [hashes]
        var deleting = deleteLocalData === true
        var singular = deleting ? "Torrent and downloaded files removed"
                                : "Torrent removed (downloaded files preserved)"
        var plural = deleting ? "torrents and downloaded files removed"
                              : "torrents removed (downloaded files preserved)"
        runMutation(mutationLabel(ids.length, singular, plural),
                    function(done) { client.removeTorrent(ids, done, deleting) })
    }
}
