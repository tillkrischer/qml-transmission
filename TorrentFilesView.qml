pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "js/Format.js" as Format

Item {
    id: root
    required property TorrentFilesStore store
    property bool detailsMode: false
    property var selectedKeys: []
    property string selectionAnchorKey: ""
    readonly property real columnSpacing: 8
    readonly property real wantedColumnWidth: 64
    readonly property real progressColumnWidth: 140
    readonly property real sizeColumnWidth: 100
    readonly property real priorityColumnWidth: 120

    function containsKey(keys, key) {
        return keys.indexOf(key) >= 0
    }

    function modelIndexForKey(key) {
        for (var i = 0; i < store.rows.length; ++i) {
            if (String(store.rows[i].key) === key)
                return i
        }
        return -1
    }

    function selectIndex(index, modifiers, contextClick) {
        if (!detailsMode || index < 0 || index >= store.rows.length)
            return []

        var key = String(store.rows[index].key)
        var shift = (modifiers & Qt.ShiftModifier) !== 0
        var control = (modifiers & Qt.ControlModifier) !== 0

        if (contextClick && !shift && !control && containsKey(selectedKeys, key))
            return selectedKeys

        var next = []
        if (shift) {
            var anchorIndex = modelIndexForKey(selectionAnchorKey)
            if (anchorIndex < 0)
                anchorIndex = index
            if (control)
                next = selectedKeys.slice()
            var first = Math.min(anchorIndex, index)
            var last = Math.max(anchorIndex, index)
            for (var i = first; i <= last; ++i) {
                var rangeKey = String(store.rows[i].key)
                if (!containsKey(next, rangeKey))
                    next.push(rangeKey)
            }
        } else if (control) {
            next = selectedKeys.slice()
            var existing = next.indexOf(key)
            if (existing >= 0)
                next.splice(existing, 1)
            else
                next.push(key)
            selectionAnchorKey = key
        } else {
            next = [key]
            selectionAnchorKey = key
        }

        selectedKeys = next
        return next
    }

    function indicesForKeys(keys) {
        var result = []
        for (var i = 0; i < keys.length; ++i) {
            var rowIndex = modelIndexForKey(keys[i])
            if (rowIndex < 0)
                continue
            var indices = store.indices(store.rows[rowIndex])
            for (var j = 0; j < indices.length; ++j) {
                if (result.indexOf(indices[j]) < 0)
                    result.push(indices[j])
            }
        }
        return result
    }

    function reconcileSelection() {
        var valid = selectedKeys.filter(function(key) {
            return root.modelIndexForKey(key) >= 0
        })
        if (valid.length !== selectedKeys.length)
            selectedKeys = valid
        if (modelIndexForKey(selectionAnchorKey) < 0)
            selectionAnchorKey = valid.length ? valid[valid.length - 1] : ""
    }

    function priorityStatus(rowData) {
        if (rowData.wanted === 0)
            return "skip"
        if (rowData.wanted === 2 || rowData.priority === -2)
            return "mixed"
        return rowData.priority < 0 ? "low" : (rowData.priority > 0 ? "high" : "normal")
    }

    function priorityText(rowData) {
        var status = priorityStatus(rowData)
        return status === "mixed" ? "" : status.charAt(0).toUpperCase() + status.slice(1)
    }

    function priorityIcon(rowData) {
        var status = priorityStatus(rowData)
        if (status === "high") return "▲"
        if (status === "normal") return "●"
        if (status === "low") return "▼"
        if (status === "skip") return "✕"
        return ""
    }

    function priorityColor(rowData) {
        var status = priorityStatus(rowData)
        if (status === "high") return "#e64a3c"
        if (status === "normal") return "#3daee9"
        if (status === "low") return "#48a957"
        if (status === "skip") return "#d45b5b"
        return "transparent"
    }

    Connections {
        target: root.store
        function onChanged() { root.reconcileSelection() }
        function onTorrentHashChanged() {
            root.selectedKeys = []
            root.selectionAnchorKey = ""
        }
    }

    ColumnLayout {
        anchors.fill: parent
        RowLayout {
            visible: !root.detailsMode
            Layout.fillWidth: true
            Button { text: "Select all"; enabled: !root.store.busy && root.store.files.length > 0; onClicked: root.store.setAllWanted(true) }
            Button { text: "Select none"; enabled: !root.store.busy && root.store.files.length > 0; onClicked: root.store.setAllWanted(false) }
            Label { text: root.store.selectedCount + " files, " + Format.bytes(root.store.selectedBytes); Layout.fillWidth: true }
            BusyIndicator { running: root.store.loading || root.store.busy; implicitWidth: 24; implicitHeight: 24 }
        }
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 28
            color: palette.alternateBase
            Label {
                anchors.left: parent.left
                width: root.wantedColumnWidth
                height: parent.height
                text: "Wanted"
                verticalAlignment: Text.AlignVCenter
            }
            Label {
                anchors.left: parent.left
                anchors.leftMargin: root.wantedColumnWidth + root.columnSpacing
                anchors.right: root.detailsMode ? progressHeader.left : sizeHeader.left
                anchors.rightMargin: root.columnSpacing
                height: parent.height
                text: "File"
                verticalAlignment: Text.AlignVCenter
            }
            Label {
                id: progressHeader
                visible: root.detailsMode
                anchors.right: sizeHeader.left
                anchors.rightMargin: root.columnSpacing
                width: root.progressColumnWidth
                height: parent.height
                text: "Progress"
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            Label {
                id: sizeHeader
                anchors.right: root.detailsMode ? priorityHeader.left : parent.right
                anchors.rightMargin: root.detailsMode ? root.columnSpacing : 0
                width: root.sizeColumnWidth
                height: parent.height
                text: "Size"
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            Label {
                id: priorityHeader
                visible: root.detailsMode
                anchors.right: parent.right
                width: root.priorityColumnWidth
                height: parent.height
                text: "Priority"
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
        }
        ListView {
            id: list
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: root.store.rows
            ScrollBar.vertical: ScrollBar {}
            delegate: ItemDelegate {
                id: row
                required property int index
                required property var modelData
                width: list.width
                height: 40
                padding: 0
                enabled: !root.store.busy
                focusPolicy: Qt.NoFocus
                hoverEnabled: false
                highlighted: root.detailsMode && root.containsKey(root.selectedKeys, String(row.modelData.key))

                MouseArea {
                    anchors.fill: parent
                    z: 0
                    enabled: root.detailsMode
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: function(mouse) {
                        var contextClick = mouse.button === Qt.RightButton
                        var targetKeys = root.selectIndex(row.index, mouse.modifiers, contextClick)
                        if (contextClick) {
                            contextMenu.targetKeys = targetKeys.slice()
                            contextMenu.popup()
                        }
                    }
                }

                contentItem: Item {
                    id: rowContent
                    width: row.width
                    height: row.height
                    z: 1
                    CheckBox {
                        visible: !root.detailsMode
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: root.wantedColumnWidth
                        tristate: row.modelData.folder
                        enabled: !root.detailsMode
                        checkState: row.modelData.wanted === 2 ? Qt.PartiallyChecked : (row.modelData.wanted ? Qt.Checked : Qt.Unchecked)
                        onClicked: root.store.setWanted(row.modelData, checkState === Qt.Checked)
                    }
                    Label {
                        visible: root.detailsMode
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: root.wantedColumnWidth
                        text: row.modelData.wanted === 2 ? "–" : (row.modelData.wanted ? "✓" : "")
                        horizontalAlignment: Text.AlignHCenter
                    }
                    Item {
                        id: fileCell
                        anchors.left: parent.left
                        anchors.leftMargin: root.wantedColumnWidth + root.columnSpacing
                        anchors.right: root.detailsMode ? progressCell.left : sizeCell.left
                        anchors.rightMargin: root.columnSpacing
                        height: parent.height
                        ToolButton {
                            id: expandButton
                            visible: row.modelData.folder
                            focusPolicy: Qt.NoFocus
                            x: row.modelData.depth * 16
                            anchors.verticalCenter: parent.verticalCenter
                            width: 36
                            height: 36
                            text: row.modelData.expanded ? "▾" : "▸"
                            onClicked: root.store.toggleExpanded(row.modelData.key)
                        }
                        Label {
                            x: row.modelData.depth * 16 + 36
                            width: Math.max(0, parent.width - x)
                            height: parent.height
                            text: row.modelData.name
                            elide: Text.ElideMiddle
                            verticalAlignment: Text.AlignVCenter
                            font.bold: row.modelData.folder
                        }
                    }
                    Item {
                        id: progressCell
                        visible: root.detailsMode
                        anchors.right: sizeCell.left
                        anchors.rightMargin: root.columnSpacing
                        width: root.progressColumnWidth
                        height: parent.height
                        TorrentProgressBar {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            value: row.modelData.size ? row.modelData.completed / row.modelData.size : 0
                        }
                    }
                    Label {
                        id: sizeCell
                        anchors.right: root.detailsMode ? priorityCell.left : parent.right
                        anchors.rightMargin: root.detailsMode ? root.columnSpacing : 0
                        width: root.sizeColumnWidth
                        height: parent.height
                        text: Format.bytes(row.modelData.size)
                        horizontalAlignment: Text.AlignRight
                        verticalAlignment: Text.AlignVCenter
                    }
                    Item {
                        id: priorityCell
                        visible: root.detailsMode
                        anchors.right: parent.right
                        width: root.priorityColumnWidth
                        height: parent.height
                        Label {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            width: 14
                            text: root.priorityIcon(row.modelData)
                            color: root.priorityColor(row.modelData)
                            horizontalAlignment: Text.AlignHCenter
                        }
                        Label {
                            anchors.left: parent.left
                            anchors.leftMargin: 20
                            anchors.right: parent.right
                            height: parent.height
                            text: root.priorityText(row.modelData)
                            elide: Text.ElideRight
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }
            }
        }
    }

    Label {
        anchors.centerIn: parent
        visible: root.store.rows.length === 0 && !root.store.loading
        text: root.store.errorMessage || (!root.store.torrentHash ? "No torrent selected" : "No files")
        color: root.store.errorMessage ? palette.brightText : palette.placeholderText
        wrapMode: Text.WordWrap
    }

    Menu {
        id: contextMenu
        property var targetKeys: []
        readonly property var targetIndices: root.indicesForKeys(targetKeys)

        MenuItem {
            text: "Wanted"
            enabled: contextMenu.targetIndices.length > 0 && !root.store.busy
            onTriggered: root.store.setWanted({ indices: contextMenu.targetIndices }, true)
        }
        MenuItem {
            text: "Unwanted"
            enabled: contextMenu.targetIndices.length > 0 && !root.store.busy
            onTriggered: root.store.setWanted({ indices: contextMenu.targetIndices }, false)
        }
        MenuSeparator {}
        MenuItem {
            text: "Low priority"
            enabled: contextMenu.targetIndices.length > 0 && !root.store.busy
            onTriggered: root.store.setPriority({ indices: contextMenu.targetIndices }, -1)
        }
        MenuItem {
            text: "Normal priority"
            enabled: contextMenu.targetIndices.length > 0 && !root.store.busy
            onTriggered: root.store.setPriority({ indices: contextMenu.targetIndices }, 0)
        }
        MenuItem {
            text: "High priority"
            enabled: contextMenu.targetIndices.length > 0 && !root.store.busy
            onTriggered: root.store.setPriority({ indices: contextMenu.targetIndices }, 1)
        }
    }
}
