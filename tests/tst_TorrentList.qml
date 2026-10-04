import QtQuick
import QtTest
import ".."

TestCase {
    name: "TorrentListScrolling"
    width: 800
    height: 350
    when: windowShown

    TransmissionClient { id: client }
    TorrentStore { id: store; client: client }
    TorrentList {
        id: view
        store: store
        anchors.fill: parent
        onSelectionChanged: function(hash, hashes) {
            selectedHash = hash
            selectedHashes = hashes
        }
    }

    function init() {
        store.items = []
        store.searchText = ""
        store.selectFilter("status", "all")
        store.sortRole = "rate_download"
        store.sortAscending = true
        store.rebuildVisibleModel()
        view.selectedHash = ""
        view.selectedHashes = []
        view.selectionAnchorHash = ""
    }

    function torrents() {
        var values = []
        for (var index = 0; index < 100; ++index) {
            values.push({ id: index, hash_string: "hash" + index, name: "Torrent " + index,
                          total_size: 100, percent_complete: 0.5, status: 4,
                          rate_download: index, rate_upload: 0, upload_ratio: 0, eta: 10,
                          added_date: index + 1, error: 0, error_string: "" })
        }
        return values
    }

    function test_scrollPositionSurvivesReordering() {
        var values = torrents()
        store.items = values
        store.rebuildVisibleModel()
        var list = findChild(view, "torrentList")
        tryCompare(list, "count", 100)
        view.selectIndex(50, Qt.NoModifier, false)
        list.positionViewAtIndex(50, ListView.Beginning)
        wait(50)
        var before = list.contentY - list.originY
        verify(before > 0)
        values[0].rate_download = 1000
        store.items = values
        store.rebuildVisibleModel()
        wait(50)
        compare(list.contentY - list.originY, before)
        compare(store.model.get(99).hash_string, "hash0")
        compare(view.selectedHashes, ["hash50"])
    }
    function test_scrollPositionSurvivesRemovalAndInsertion() {
        var values = torrents()
        store.items = values
        store.rebuildVisibleModel()
        var list = findChild(view, "torrentList")
        tryCompare(list, "count", 100)
        view.selectIndex(50, Qt.NoModifier, false)
        list.positionViewAtIndex(50, ListView.Beginning)
        wait(50)
        var before = list.contentY - list.originY
        verify(before > 0)
        store.items = values.slice(20)
        store.rebuildVisibleModel()
        store.updated()
        tryCompare(list, "count", 80)
        wait(50)
        compare(list.contentY - list.originY, before)
        compare(view.selectedHashes, ["hash50"])
        store.items = values
        store.rebuildVisibleModel()
        tryCompare(list, "count", 100)
        wait(50)
        compare(list.contentY - list.originY, before)
        compare(view.selectedHashes, ["hash50"])
    }
}
