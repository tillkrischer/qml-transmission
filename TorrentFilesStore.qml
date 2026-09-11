import QtQuick
import "js/FileTree.js" as FileTree

QtObject {
    id: root
    required property TransmissionClient client
    property string torrentHash: ""
    property bool visible: false
    property bool draftMode: false
    property bool loading: false
    property bool busy: false
    property string errorMessage: ""
    property real metadataPercent: 0
    property var files: []
    property var stats: []
    property var rows: []
    property var expanded: ({})
    property int requestEpoch: 0
    readonly property int selectedCount: stats.filter(function(s) { return s.wanted }).length
    readonly property real selectedBytes: selectedSize()

    signal loaded()
    signal changed()

    property Timer pollTimer: Timer {
        interval: 2000
        repeat: true
        running: root.visible && !root.draftMode && !!root.torrentHash && root.client.connected
        onTriggered: root.refresh(false)
    }

    property Connections clientConnections: Connections {
        target: root.client
        function onInvalidated() { ++root.requestEpoch; root.loading = false; root.busy = false }
    }

    onTorrentHashChanged: {
        ++requestEpoch
        files = []
        stats = []
        rows = []
        errorMessage = ""
        metadataPercent = 0
        if (torrentHash && visible && !draftMode) refresh(true)
    }
    onVisibleChanged: if (visible && torrentHash && !draftMode) refresh(true)

    function loadDraft(hash, sourceFiles, sourceStats, metadata) {
        ++requestEpoch
        draftMode = true
        torrentHash = hash
        metadataPercent = Number(metadata) || 0
        files = sourceFiles || []
        stats = cloneStats(sourceStats, files.length)
        rebuild()
        loaded()
    }

    function cloneStats(values, count) {
        var answer = []
        for (var i = 0; i < count; ++i) {
            var value = values && values[i] ? values[i] : {}
            answer.push({ bytes_completed: Number(value.bytes_completed) || 0,
                wanted: value.wanted === undefined ? true : !!value.wanted,
                priority: Number(value.priority) || 0 })
        }
        return answer
    }

    function refresh(initial) {
        if (!client.connected || !torrentHash || busy || (loading && !initial)) return
        loading = true
        var epoch = requestEpoch
        var hash = torrentHash
        client.torrentFiles(hash, function(result, error) {
            if (epoch !== requestEpoch || hash !== torrentHash) return
            loading = false
            if (error) { errorMessage = error.message; return }
            var torrents = result.torrents || []
            if (!torrents.length) { errorMessage = "Torrent is no longer available"; return }
            var torrent = torrents[0]
            metadataPercent = Number(torrent.metadata_percent_complete) || 0
            if (metadataPercent < 1 && (!torrent.files || !torrent.files.length)) {
                files = []; stats = []; rows = []; errorMessage = "Metadata is not available yet"
                loaded(); return
            }
            files = torrent.files || []
            stats = cloneStats(torrent.file_stats, files.length)
            errorMessage = ""
            rebuild()
            loaded()
        })
    }

    function rebuild() {
        rows = FileTree.flatten(FileTree.build(files, stats), expanded)
        changed()
    }

    function toggleExpanded(key) {
        expanded[key] = !expanded[key]
        expanded = expanded
        rebuild()
    }

    function selectedSize() {
        var total = 0
        for (var i = 0; i < files.length; ++i)
            if (stats[i] && stats[i].wanted) total += Number(files[i].length) || 0
        return total
    }

    function indices(row) { return row && row.indices ? row.indices.slice() : [] }

    function setWanted(row, wanted) {
        var target = indices(row)
        if (!target.length) return
        if (draftMode) {
            var next = cloneStats(stats, files.length)
            for (var i = 0; i < target.length; ++i) next[target[i]].wanted = wanted
            stats = next; rebuild(); return
        }
        mutate(wanted ? target : [], wanted ? [] : target, null)
    }

    function setAllWanted(wanted) {
        var target = []
        for (var i = 0; i < files.length; ++i) target.push(i)
        setWanted({ indices: target }, wanted)
    }

    function setPriority(row, priority) {
        var target = indices(row)
        if (!target.length) return
        if (draftMode) {
            var next = cloneStats(stats, files.length)
            for (var i = 0; i < target.length; ++i) next[target[i]].priority = priority
            stats = next; rebuild(); return
        }
        var values = { low: [], normal: [], high: [] }
        values[priority < 0 ? "low" : (priority > 0 ? "high" : "normal")] = target
        mutate([], [], values)
    }

    function mutate(wanted, unwanted, priorities) {
        if (busy || !torrentHash) return
        busy = true
        var epoch = requestEpoch
        var hash = torrentHash
        client.setTorrentFiles(hash, wanted, unwanted, priorities, function(result, error) {
            if (epoch !== requestEpoch || hash !== torrentHash) return
            busy = false
            if (error) { errorMessage = error.message; rebuild(); return }
            errorMessage = ""
            refresh(true)
        })
    }

    function draftArguments() {
        var wanted = [], unwanted = [], low = [], normal = [], high = []
        for (var i = 0; i < stats.length; ++i) {
            (stats[i].wanted ? wanted : unwanted).push(i)
            if (stats[i].priority < 0) low.push(i)
            else if (stats[i].priority > 0) high.push(i)
            else normal.push(i)
        }
        return { wanted: wanted, unwanted: unwanted,
            priorities: { low: low, normal: normal, high: high } }
    }
}
