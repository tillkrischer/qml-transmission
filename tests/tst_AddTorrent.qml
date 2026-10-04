import QtQuick
import QtTest
import ".."

TestCase {
    name: "AddTorrent"
    TransmissionClient {
        id: client
        property var calls: []
        property bool duplicate: false
        property bool noMetadata: false
        function addTorrent(source, directory, paused, metainfo, callback) {
            calls.push({ kind: "add", source: source, directory: directory, paused: paused, metainfo: metainfo })
            callback(duplicate ? { torrent_duplicate: { hash_string: "existing" } }
                               : { torrent_added: { hash_string: source, name: source } }, null)
        }
        function torrentFiles(hash, callback) {
            callback({ torrents: [{ name: hash, files: noMetadata ? [] : [{ name: "a", length: 10 }, { name: "b", length: 20 }], file_stats: [] }] }, null)
        }
        function setTorrentLocation(hash, directory, callback) {
            calls.push({ kind: "location", hash: hash, directory: directory }); callback({}, null)
        }
        function setTorrentFiles(hash, wanted, unwanted, priorities, callback) {
            calls.push({ kind: "files", hash: hash, wanted: wanted, unwanted: unwanted, priorities: priorities }); callback({}, null)
        }
        function startTorrent(hashes, callback) {
            calls.push({ kind: "start", hashes: hashes }); callback({}, null)
        }
        function removeTorrent(hashes, callback, deleteData) {
            calls.push({ kind: "remove", hashes: hashes, deleteData: deleteData }); callback({}, null)
        }
    }
    QtObject {
        id: reader
        signal finished(string token, string base64, string error)
        function read(token, source) { finished(token, source, "") }
        function cancel(token) {}
    }
    ConnectionProfiles { id: profiles; credentialBackend: null }
    TorrentFilesStore { id: files; client: client; draftMode: true }
    AddTorrentController { id: controller; client: client; draftStore: files; profiles: profiles; fileReader: reader }
    AddTorrentDialog { id: dialog; controller: controller; profiles: profiles }
    function init() {
        controller.reset(); controller.clearRecovery()
        client.connected = true; client.calls = []; client.duplicate = false; client.noMetadata = false
        profiles.profiles = [profiles.normalizedProfile({ id: "first", defaultDirectory: "/default" }),
                             profiles.normalizedProfile({ id: "second", defaultDirectory: "/other-default" })]
        profiles.activeProfileId = "first"
        client.profileId = "first"
        client.defaultDownloadDirectory = "/server-default"
    }
    function cleanup() { dialog.pendingSources = []; dialog.close(); controller.clearRecovery() }
    function test_filesArePreparedOneAtATime() {
        dialog.openSources(["one", "two"], true)
        compare(controller.state, "choosing")
        compare(client.calls.length, 1)
        compare(client.calls[0].source, "one")
        compare(files.files.length, 2)
        files.setWanted({ indices: [1] }, false)
        controller.directory = "/first"
        controller.apply()
        compare(client.calls[1].directory, "/first")
        compare(client.calls[2].unwanted, [1])
        tryCompare(controller, "source", "two")
        compare(controller.state, "choosing")
        compare(files.selectedCount, 2)
        compare(controller.directory, "/first")
        compare(findChild(dialog, "addTorrentDirectory").editText, "/first")
        compare(client.calls[4].directory, "/first")
        controller.directory = "/second"
        controller.apply()
        compare(client.calls[5].directory, "/second")
        compare(client.calls[6].wanted, [0, 1])
    }
    function test_rememberedDirectoryIsPersistentAndPerConnection() {
        controller.begin("one", "/remembered", false, true)
        controller.apply()
        compare(controller.state, "done")
        profiles.initialize()
        compare(profiles.activeProfile.recentDirectories[0], "/remembered")

        profiles.select("second")
        client.profileId = "second"
        dialog.openSources(["two"], true)
        compare(controller.directory, "/other-default")
        controller.directory = "/other-remembered"
        controller.apply()
        wait(1)

        profiles.select("first")
        client.profileId = "first"
        dialog.openSources(["three"], true)
        compare(controller.directory, "/remembered")
        compare(findChild(dialog, "addTorrentDirectory").editText, "/remembered")
        compare(profiles.profile("second").recentDirectories[0], "/other-remembered")
    }
    function test_directoryFallsBackToServerDefault() {
        profiles.profiles = [profiles.normalizedProfile({ id: "first" })]
        dialog.openSources(["one"], true)
        compare(controller.directory, "/server-default")
        compare(findChild(dialog, "addTorrentDirectory").editText, "/server-default")
    }
    function test_magnetUsesOptionsBeforeStarting() {
        client.noMetadata = true
        controller.begin("magnet:?xt=urn:btih:example", "/data", true, false)
        compare(controller.state, "choosing")
        compare(client.calls.length, 1)
        verify(client.calls[0].paused)
        controller.apply()
        compare(controller.state, "done")
        compare(client.calls[3].kind, "start")
    }
    function test_cancelDoesNotPrepareRemainingFiles() {
        dialog.openSources(["one", "two"], true)
        dialog.pendingSources = []
        controller.cancel()
        compare(controller.state, "done")
        compare(client.calls[1].kind, "remove")
        compare(client.calls[1].hashes, "one")
        verify(client.calls[1].deleteData !== true)
        wait(1)
        compare(client.calls.length, 2)
    }
    function test_duplicateIsSkipped() {
        client.duplicate = true
        dialog.openSources(["one", "two"], true)
        tryVerify(function() { return client.calls.length === 2 })
        compare(controller.state, "done")
        compare(controller.ownedHash, "")
    }
    function test_emptySelectionCanBeCorrected() {
        controller.begin("one", "/data", true, true)
        files.setAllWanted(false)
        controller.apply()
        compare(controller.state, "choosing")
        verify(controller.errorMessage.length > 0)
        files.setAllWanted(true)
        controller.apply()
        compare(controller.state, "done")
    }
}
