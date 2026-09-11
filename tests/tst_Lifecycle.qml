import QtQuick
import QtTest
import ".."

TestCase {
    name: "Lifecycle"

    TransmissionClient { id: client }
    TorrentStore { id: store; client: client }
    TorrentFilesStore { id: files; client: client; draftMode: true }

    function init() {
        client.disconnectFromServer()
        store.activateProfile("one", false)
        store.items = []
        store.refreshInFlight = false
        files.torrentHash = ""
    }

    function test_invalidationReleasesRefresh() {
        store.refreshInFlight = true
        client.invalidated(42)
        compare(store.refreshInFlight, false)
        compare(store.generation, 42)
    }

    function test_profileSwitchClearsIdentity() {
        store.items = [{ id: 1, hash_string: "old", name: "Old" }]
        store.activateProfile("two", false)
        compare(store.items.length, 0)
        compare(store.torrentByHash("old"), null)
    }

    function test_draftArgumentsUseDaemonIndices() {
        files.loadDraft("hash", [
            { name: "z/first", length: 10 },
            { name: "a/second", length: 20 }
        ], [
            { wanted: true, priority: 0 },
            { wanted: true, priority: 0 }
        ], 1)
        var folderA = files.rows[0]
        compare(folderA.name, "a")
        files.setWanted(folderA, false)
        files.setPriority(folderA, 1)
        var args = files.draftArguments()
        compare(args.unwanted.length, 1)
        compare(args.unwanted[0], 1)
        compare(args.priorities.high[0], 1)
        compare(args.wanted[0], 0)
    }
}
