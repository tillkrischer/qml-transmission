pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "js/Format.js" as Format

Item {
    id: root
    required property TorrentStore store
    property string selectedHash: ""
    property var selectedHashes: []
    property string selectionAnchorHash: ""
    readonly property int tableWidth: 1120
    readonly property int tablePadding: 8
    readonly property int columnSpacing: 8
    readonly property int nameColumnWidth: tableWidth - (2 * tablePadding) - (8 * columnSpacing)
                                                   - 82 - 92 - 135 - 84 - 84 - 62 - 70 - 150
    signal selectionChanged(string torrentHash, var torrentHashes)
    signal actionRequested(string action, var torrentHashes)

    function containsHash(hashes, hash) {
        return hashes.indexOf(hash) >= 0
    }

    function modelIndexForHash(hash) {
        for (var i = 0; i < store.model.count; ++i) {
            if (String(store.model.get(i).hash_string) === hash)
                return i
        }
        return -1
    }

    function hasTorrentWithStoppedState(hashes, stopped) {
        for (var i = 0; i < hashes.length; ++i) {
            var torrent = store.torrentByHash(hashes[i])
            if (torrent && ((torrent.status === 0) === stopped))
                return true
        }
        return false
    }

    function selectIndex(index, modifiers, contextClick) {
        if (index < 0 || index >= store.model.count)
            return []

        var hash = String(store.model.get(index).hash_string)
        var shift = (modifiers & Qt.ShiftModifier) !== 0
        var control = (modifiers & Qt.ControlModifier) !== 0

        // A context click inside the current selection operates on the whole
        // selection, matching conventional desktop list behaviour.
        if (contextClick && !shift && !control && containsHash(selectedHashes, hash))
            return selectedHashes

        var next = []
        if (shift) {
            var anchorIndex = modelIndexForHash(selectionAnchorHash)
            if (anchorIndex < 0)
                anchorIndex = index
            if (control)
                next = selectedHashes.slice()
            var first = Math.min(anchorIndex, index)
            var last = Math.max(anchorIndex, index)
            for (var i = first; i <= last; ++i) {
                var rangeHash = String(store.model.get(i).hash_string)
                if (!containsHash(next, rangeHash))
                    next.push(rangeHash)
            }
        } else if (control) {
            next = selectedHashes.slice()
            var existing = next.indexOf(hash)
            if (existing >= 0)
                next.splice(existing, 1)
            else
                next.push(hash)
            selectionAnchorHash = hash
        } else {
            next = [hash]
            selectionAnchorHash = hash
        }

        var primary = containsHash(next, hash) ? hash : (next.length ? next[next.length - 1] : "")
        selectionChanged(primary, next)
        return next
    }

    Connections {
        target: root.store
        function onUpdated() {
            var valid = root.selectedHashes.filter(function(hash) {
                return !!root.store.torrentByHash(hash)
            })
            if (valid.length !== root.selectedHashes.length) {
                var primary = root.containsHash(valid, root.selectedHash)
                            ? root.selectedHash : (valid.length ? valid[valid.length - 1] : "")
                root.selectionChanged(primary, valid)
            }
        }
    }

    Flickable {
        id: horizontal
        anchors.fill: parent
        contentWidth: root.tableWidth
        contentHeight: height
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.HorizontalFlick
        ScrollBar.horizontal: ScrollBar {}

        Rectangle {
            id: header
            width: root.tableWidth
            height: 34
            color: palette.alternateBase
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: root.tablePadding
                anchors.rightMargin: root.tablePadding
                spacing: root.columnSpacing
                Repeater {
                    model: [
                        { title: "Name", role: "name", width: root.nameColumnWidth },
                        { title: "Size", role: "total_size", width: 82 },
                        { title: "Progress", role: "percent_complete", width: 92 },
                        { title: "Status", role: "status", width: 135 },
                        { title: "Down", role: "rate_download", width: 84 },
                        { title: "Up", role: "rate_upload", width: 84 },
                        { title: "Ratio", role: "upload_ratio", width: 62 },
                        { title: "ETA", role: "eta", width: 70 },
                        { title: "Added on", role: "added_date", width: 150 }
                    ]
                    Button {
                        required property var modelData
                        text: modelData.title + (root.store.sortRole === modelData.role ? (root.store.sortAscending ? "  ▲" : "  ▼") : "")
                        flat: true
                        leftPadding: 0
                        rightPadding: 0
                        Layout.minimumWidth: modelData.width
                        Layout.preferredWidth: modelData.width
                        Layout.maximumWidth: modelData.width
                        contentItem: Label {
                            text: parent.text
                            horizontalAlignment: Text.AlignLeft
                            verticalAlignment: Text.AlignVCenter
                            elide: Text.ElideRight
                        }
                        onClicked: {
                            if (root.store.sortRole === modelData.role)
                                root.store.sortAscending = !root.store.sortAscending
                            else {
                                root.store.sortRole = modelData.role
                                root.store.sortAscending = true
                            }
                        }
                    }
                }
            }
        }

        ListView {
            id: list
            y: header.height
            width: root.tableWidth
            height: horizontal.height - header.height
            clip: true
            model: root.store.model
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar {}

            delegate: ItemDelegate {
                id: row
                required property int index
                required property int id
                required property string hash_string
                required property string name
                required property real total_size
                required property real percent_complete
                required property int status
                required property real rate_download
                required property real rate_upload
                required property real upload_ratio
                required property real eta
                required property real added_date
                required property int error
                required property string error_string
                width: list.width
                height: 34
                leftPadding: root.tablePadding
                rightPadding: root.tablePadding
                topPadding: 0
                bottomPadding: 0
                highlighted: root.containsHash(root.selectedHashes, hash_string)

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: function(mouse) {
                        var contextClick = mouse.button === Qt.RightButton
                        var targetHashes = root.selectIndex(row.index, mouse.modifiers, contextClick)
                        if (contextClick) {
                            contextMenu.targetHashes = targetHashes.slice()
                            contextMenu.popup()
                        }
                    }
                }

                contentItem: Row {
                    spacing: root.columnSpacing
                    Label { width: root.nameColumnWidth; height: parent.height; text: row.name; elide: Text.ElideRight; verticalAlignment: Text.AlignVCenter }
                    Label { width: 82; height: parent.height; text: Format.bytes(row.total_size); horizontalAlignment: Text.AlignRight; verticalAlignment: Text.AlignVCenter }
                    Item {
                        width: 92
                        height: parent.height
                        TorrentProgressBar {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width
                            value: row.percent_complete
                            ToolTip.text: Math.round(row.percent_complete * 100) + "%"
                            ToolTip.visible: hovered
                        }
                    }
                    RowLayout {
                        width: 135; height: parent.height; spacing: 6
                        StatusIcon { status: row.status; error: row.error; errorText: row.error_string || (row.error ? "Torrent error" : "") }
                        Label { text: Format.status(row.status); elide: Text.ElideRight; Layout.fillWidth: true }
                    }
                    Label { width: 84; height: parent.height; text: Format.speed(row.rate_download); horizontalAlignment: Text.AlignRight; verticalAlignment: Text.AlignVCenter }
                    Label { width: 84; height: parent.height; text: Format.speed(row.rate_upload); horizontalAlignment: Text.AlignRight; verticalAlignment: Text.AlignVCenter }
                    Label { width: 62; height: parent.height; text: Format.ratio(row.upload_ratio); horizontalAlignment: Text.AlignRight; verticalAlignment: Text.AlignVCenter }
                    Label { width: 70; height: parent.height; text: Format.duration(row.eta); horizontalAlignment: Text.AlignRight; verticalAlignment: Text.AlignVCenter }
                    Label { width: 150; height: parent.height; text: Format.dateTime(row.added_date); verticalAlignment: Text.AlignVCenter }
                }
            }
        }
    }

    Label {
        anchors.centerIn: parent
        visible: list.count === 0
        text: root.store.items.length === 0 ? "No torrents" : "No matching torrents"
        color: palette.placeholderText
    }

    Menu {
        id: contextMenu
        property var targetHashes: []
        MenuItem {
            text: contextMenu.targetHashes.length > 1 ? "Start selected" : "Start"
            enabled: root.store.client.connected
                     && root.hasTorrentWithStoppedState(contextMenu.targetHashes, true)
            onTriggered: root.actionRequested("start", contextMenu.targetHashes.slice())
        }
        MenuItem {
            text: contextMenu.targetHashes.length > 1 ? "Stop selected" : "Stop"
            enabled: root.store.client.connected
                     && root.hasTorrentWithStoppedState(contextMenu.targetHashes, false)
            onTriggered: root.actionRequested("stop", contextMenu.targetHashes.slice())
        }
        MenuSeparator {}
        MenuItem {
            text: contextMenu.targetHashes.length > 1 ? "Remove selected…" : "Remove…"
            enabled: contextMenu.targetHashes.length > 0 && root.store.client.connected
            onTriggered: root.actionRequested("remove", contextMenu.targetHashes.slice())
        }
    }
}
