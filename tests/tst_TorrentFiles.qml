import QtQuick
import QtTest
import ".."

TestCase {
    name: "TorrentFiles"
    width: 800
    height: 350
    when: windowShown

    TransmissionClient {
        id: client
        property var calls: []
        function request(method, params, mutation, callback) {
            calls.push({ callback: callback })
        }
    }
    TorrentFilesStore { id: files; client: client }
    TorrentFilesView { id: view; store: files; detailsMode: true; anchors.fill: parent }

    function init() {
        client.invalidate()
        files.visible = false
        files.torrentHash = ""
        files.draftMode = false
        files.expanded = ({})
        client.calls = []
        client.connected = true
    }

    function cleanup() { client.invalidate() }

    function reply(call, completed) {
        var sourceFiles = []
        var sourceStats = []
        for (var index = 0; index < 100; ++index) {
            sourceFiles.push({ name: "folder/file" + index, length: 100 })
            sourceStats.push({ wanted: true, priority: 0, bytes_completed: completed })
        }
        call.callback({ torrents: [{ files: sourceFiles, file_stats: sourceStats,
                                    metadata_percent_complete: 1 }] }, null)
    }

    function test_scrollPositionSurvivesRefresh() {
        files.torrentHash = "one"
        files.visible = true
        reply(client.calls[0], 0)
        files.toggleExpanded("d:folder")
        var list = findChild(view, "fileList")
        tryCompare(list, "count", 101)
        list.positionViewAtIndex(50, ListView.Beginning)
        wait(50)
        var before = list.contentY
        verify(before > 0)
        var selectedKey = files.rows[50].key
        view.selectIndex(50, Qt.NoModifier, false)
        for (var refresh = 1; refresh <= 3; ++refresh) {
            files.refresh(false)
            reply(client.calls[refresh], refresh * 10)
            wait(50)
            compare(list.contentY, before)
            compare(files.model.get(50).rowData.completed, refresh * 10)
            compare(files.model.get(0).rowData.completed, refresh * 1000)
            compare(view.selectedKeys, [selectedKey])
            verify(files.model.get(0).rowData.expanded)
        }
        files.torrentHash = "two"
        tryCompare(list, "count", 0)
        compare(view.selectedKeys.length, 0)
        reply(client.calls[4], 0)
        tryCompare(list, "count", 101)
        wait(50)
        compare(list.contentY, list.originY)
    }

    function test_draftUpdatesAndFolderExpansion() {
        files.loadDraft("draft", [
            { name: "dir/first", length: 10 },
            { name: "dir/second", length: 20 },
            { name: "root", length: 30 }
        ], [], 1)
        compare(files.model.count, 2)
        files.toggleExpanded("d:dir")
        compare(files.model.count, 4)
        compare(files.model.get(1).rowData.key, "f:0")
        compare(files.model.get(2).rowData.key, "f:1")
        files.setWanted(files.rows[0], false)
        compare(files.model.get(0).rowData.wanted, 0)
        compare(files.model.get(1).rowData.wanted, false)
        compare(files.selectedCount, 1)
        files.setPriority(files.rows[1], 1)
        compare(files.model.get(1).rowData.priority, 1)
        compare(files.model.get(0).rowData.priority, -2)
        files.toggleExpanded("d:dir")
        compare(files.model.count, 2)
        compare(files.model.get(1).rowData.key, "f:2")
        files.toggleExpanded("d:dir")
        compare(files.model.count, 4)
        compare(files.indices(files.model.get(0).rowData), [0, 1])
    }
}
