import QtQuick
import QtTest
import ".."

TestCase {
    name: "Lifecycle"

    TransmissionClient { id: client }
    TorrentStore { id: store; client: client }
    TorrentFilesStore { id: files; client: client; draftMode: true }
    TorrentFilesView {
        id: fileView
        store: files
        detailsMode: true
        visible: false
    }
    TorrentList {
        id: torrentList
        store: store
        visible: false
        onSelectionChanged: function(torrentHash, torrentHashes) {
            torrentList.selectedHash = torrentHash
            torrentList.selectedHashes = torrentHashes
        }
    }
    SignalSpy { id: rowsInsertedSpy; target: store.model; signalName: "rowsInserted" }
    SignalSpy { id: rowsRemovedSpy; target: store.model; signalName: "rowsRemoved" }

    function init() {
        client.disconnectFromServer()
        store.activateProfile("one", false)
        store.items = []
        store.sortRole = "added_date"
        store.sortAscending = false
        store.refreshInFlight = false
        files.torrentHash = ""
        fileView.selectedKeys = []
        fileView.selectionAnchorKey = ""
        torrentList.selectedHash = ""
        torrentList.selectedHashes = []
        torrentList.selectionAnchorHash = ""
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

    function test_torrentListRangeAndToggleSelection() {
        store.sortRole = "name"
        store.sortAscending = true
        store.items = [
            { id: 1, hash_string: "one", name: "One" },
            { id: 2, hash_string: "two", name: "Two" },
            { id: 3, hash_string: "three", name: "Three" }
        ]
        store.rebuildVisibleModel()

        torrentList.selectIndex(0, Qt.NoModifier, false)
        compare(torrentList.selectedHashes.length, 1)
        compare(torrentList.selectedHashes[0], "one")

        torrentList.selectIndex(2, Qt.ShiftModifier, false)
        compare(torrentList.selectedHashes.length, 3)
        compare(torrentList.selectedHash, "two")

        torrentList.selectIndex(1, Qt.ControlModifier, false)
        compare(torrentList.selectedHashes.length, 2)
        verify(torrentList.selectedHashes.indexOf("three") < 0)
    }

    function test_torrentListContextClickPreservesSelection() {
        store.sortRole = "name"
        store.sortAscending = true
        store.items = [
            { id: 1, hash_string: "one", name: "One" },
            { id: 2, hash_string: "two", name: "Two" }
        ]
        store.rebuildVisibleModel()
        torrentList.selectedHash = "two"
        torrentList.selectedHashes = ["one", "two"]

        var targets = torrentList.selectIndex(1, Qt.NoModifier, true)
        compare(targets.length, 2)
        compare(torrentList.selectedHashes.length, 2)
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

    function test_fileViewRangeAndToggleSelection() {
        files.loadDraft("hash", [
            { name: "One", length: 10 },
            { name: "Two", length: 20 },
            { name: "Three", length: 30 }
        ], [], 1)

        fileView.selectIndex(0, Qt.NoModifier, false)
        compare(fileView.selectedKeys.length, 1)

        fileView.selectIndex(2, Qt.ShiftModifier, false)
        compare(fileView.selectedKeys.length, 3)

        fileView.selectIndex(1, Qt.ControlModifier, false)
        compare(fileView.selectedKeys.length, 2)
        verify(fileView.selectedKeys.indexOf(String(files.rows[1].key)) < 0)
    }

    function test_fileViewContextClickAndIndices() {
        files.loadDraft("hash", [
            { name: "folder/One", length: 10 },
            { name: "folder/Two", length: 20 }
        ], [], 1)
        files.toggleExpanded(files.rows[0].key)

        fileView.selectedKeys = [String(files.rows[0].key), String(files.rows[1].key)]
        var targets = fileView.selectIndex(1, Qt.NoModifier, true)
        compare(targets.length, 2)

        var indices = fileView.indicesForKeys(targets)
        compare(indices.length, 2)
        verify(indices.indexOf(0) >= 0)
        verify(indices.indexOf(1) >= 0)
    }
}
