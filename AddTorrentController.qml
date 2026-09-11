import QtQuick
import QtCore

QtObject {
    id: root
    required property TransmissionClient client
    required property TorrentFilesStore draftStore
    required property ConnectionProfiles profiles
    required property var fileReader
    property string state: "editing"
    property string source: ""
    property string directory: ""
    property bool localFile: false
    property bool startRequested: true
    property string ownedHash: ""
    property int ownedId: -1
    property string errorMessage: ""
    property string readToken: ""
    property bool cancelRequested: false
    property string recoveryProfileId: ""
    property string recoveryHash: ""
    readonly property bool active: state !== "editing" && state !== "done"
    readonly property bool busy: ["reading", "preparing", "loading", "applying", "starting", "cancelling"].indexOf(state) >= 0

    signal finished(string hash)
    signal duplicateFound(string hash)

    property Settings recovery: Settings {
        location: StandardPaths.writableLocation(StandardPaths.ConfigLocation) + "/qml-transmission.ini"
        category: "draft"
    }

    Component.onCompleted: {
        recoveryProfileId = recovery.value("profileId", "")
        recoveryHash = recovery.value("hash", "")
    }

    property Connections readerConnections: Connections {
        target: root.fileReader
        function onFinished(token, base64, error) {
            if (token !== root.readToken || root.state !== "reading") return
            if (error) { root.fail(error); return }
            root.prepare(base64, true)
        }
    }

    property Connections clientConnections: Connections {
        target: root.client
        function onInvalidated() {
            if (root.active) {
                root.errorMessage = "Connection changed. The paused draft remains on its original server."
                root.state = root.ownedHash ? "choosing" : "editing"
            }
        }
    }

    function reset() {
        state = "editing"; source = ""; directory = ""; localFile = false
        startRequested = true; ownedHash = ""; ownedId = -1; errorMessage = ""
        cancelRequested = false
        draftStore.draftMode = true
        draftStore.torrentHash = ""
    }

    function begin(value, targetDirectory, shouldStart, isLocal) {
        if (busy || !client.connected) return
        source = String(value || "").trim()
        directory = String(targetDirectory || "").trim()
        startRequested = shouldStart
        localFile = isLocal
        errorMessage = ""
        if (!source) { fail("Choose a torrent file or enter a link"); return }
        if (!isLocal && /^magnet:/i.test(source)) {
            state = "preparing"
            client.addTorrent(source, directory, !shouldStart, false, function(result, error) {
                if (error) { root.fail(error.message); return }
                root.handleImmediateResult(result)
            })
            return
        }
        if (isLocal) {
            state = "reading"
            readToken = "torrent-" + Date.now()
            fileReader.read(readToken, source)
        } else {
            prepare(source, false)
        }
    }

    function handleImmediateResult(result) {
        var duplicate = result.torrent_duplicate
        var added = result.torrent_added
        if (duplicate) { state = "done"; duplicateFound(duplicate.hash_string || ""); return }
        if (!added) { fail("The server did not confirm that the torrent was added"); return }
        profiles.recordDirectory(client.profileId, directory)
        state = "done"
        finished(added.hash_string || "")
    }

    function prepare(payload, metainfo) {
        state = "preparing"
        client.addTorrent(payload, directory, true, metainfo, function(result, error) {
            if (error) {
                root.fail(error.kind === "timeout" ? error.message + ". Check the torrent list before trying again." : error.message)
                return
            }
            var duplicate = result.torrent_duplicate
            if (duplicate) { state = "done"; duplicateFound(duplicate.hash_string || ""); return }
            var added = result.torrent_added
            if (!added || !added.hash_string) { fail("The server did not confirm ownership of the paused draft"); return }
            ownedHash = added.hash_string
            ownedId = Number(added.id)
            recovery.setValue("profileId", client.profileId)
            recovery.setValue("hash", ownedHash)
            recoveryProfileId = client.profileId
            recoveryHash = ownedHash
            recovery.sync()
            if (cancelRequested) { cleanup(); return }
            loadFiles()
        })
    }

    function loadFiles() {
        state = "loading"
        var hash = ownedHash
        client.torrentFiles(hash, function(result, error) {
            if (hash !== ownedHash) return
            if (error) { fail(error.message); return }
            var values = result.torrents || []
            if (!values.length) { fail("The prepared torrent is no longer available"); return }
            var torrent = values[0]
            draftStore.loadDraft(hash, torrent.files || [], torrent.file_stats || [], torrent.metadata_percent_complete)
            state = "choosing"
            if (cancelRequested) cleanup()
        })
    }

    function apply() {
        if (state !== "choosing") return
        if (startRequested && draftStore.selectedCount === 0) {
            fail("Select at least one file before starting, or turn off Start when ready")
            return
        }
        state = "applying"
        var args = draftStore.draftArguments()
        client.setTorrentFiles(ownedHash, args.wanted, args.unwanted, args.priorities, function(result, error) {
            if (error) { root.fail("Could not apply file choices: " + error.message); return }
            if (root.startRequested) root.start()
            else root.complete()
        })
    }

    function start() {
        state = "starting"
        client.startTorrent(ownedHash, function(result, error) {
            if (error) { root.fail("File choices were saved, but the torrent could not start: " + error.message); return }
            root.complete()
        })
    }

    function complete() {
        profiles.recordDirectory(client.profileId, directory)
        var hash = ownedHash
        clearRecovery()
        state = "done"
        finished(hash)
    }

    function cancel() {
        if (state === "editing" || state === "done") { state = "done"; return }
        cancelRequested = true
        if (state === "reading") {
            fileReader.cancel(readToken)
            state = "done"
        } else if (ownedHash && !busy) cleanup()
    }

    function cleanup() {
        if (!ownedHash) { state = "done"; return }
        state = "cancelling"
        client.removeTorrent(ownedHash, function(result, error) {
            if (error) { root.fail("The paused torrent remains on the server: " + error.message); return }
            root.clearRecovery(); root.ownedHash = ""; root.state = "done"
        })
    }

    function leavePaused() { state = "done" }
    function clearRecovery() {
        recoveryProfileId = ""; recoveryHash = ""
        recovery.setValue("profileId", ""); recovery.setValue("hash", ""); recovery.sync()
    }
    function fail(message) { errorMessage = message; state = ownedHash ? "choosing" : "editing" }
}
