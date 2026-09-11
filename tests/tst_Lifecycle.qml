import QtQuick
import QtTest
import ".."

TestCase {
    name: "Lifecycle"

    TransmissionClient { id: client }
    TorrentStore { id: store; client: client }
    TorrentFilesStore { id: files; client: client; draftMode: true }
    SignalSpy { id: rowsInsertedSpy; target: store.model; signalName: "rowsInserted" }
    SignalSpy { id: rowsRemovedSpy; target: store.model; signalName: "rowsRemoved" }

    function init() {
        client.disconnectFromServer()
        store.activateProfile("one", false)
        store.items = []
        store.refreshInFlight = false
        files.torrentHash = ""
        rowsInsertedSpy.clear()
        rowsRemovedSpy.clear()
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

    function test_visibleRowsAreReconciledAcrossRefreshes() {
        store.items = [
            { id: 1, hash_string: "one", name: "Old name", added_date: 2 },
            { id: 2, hash_string: "two", name: "Two", added_date: 1 }
        ]
        store.rebuildVisibleModel()
        compare(store.model.count, 2)
        rowsInsertedSpy.clear()
        rowsRemovedSpy.clear()

        store.items = [
            { id: 1, hash_string: "one", name: "New name", added_date: 2 },
            { id: 2, hash_string: "two", name: "Two", added_date: 1 }
        ]
        store.rebuildVisibleModel()

        compare(store.model.count, 2)
        compare(store.model.get(0).hash_string, "one")
        compare(store.model.get(0).name, "New name")
        compare(store.model.get(1).hash_string, "two")
        compare(rowsInsertedSpy.count, 0)
        compare(rowsRemovedSpy.count, 0)
    }

    function test_visibleRowsHandleInsertRemoveAndReorder() {
        store.items = [
            { id: 1, hash_string: "one", name: "One", added_date: 2 },
            { id: 2, hash_string: "two", name: "Two", added_date: 1 }
        ]
        store.rebuildVisibleModel()

        store.items = [
            { id: 2, hash_string: "two", name: "Two", added_date: 3 },
            { id: 3, hash_string: "three", name: "Three", added_date: 2 }
        ]
        store.rebuildVisibleModel()

        compare(store.model.count, 2)
        compare(store.model.get(0).hash_string, "two")
        compare(store.model.get(1).hash_string, "three")
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
