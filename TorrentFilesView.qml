pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "js/Format.js" as Format

Item {
    id: root
    required property TorrentFilesStore store

    ColumnLayout {
        anchors.fill: parent
        RowLayout {
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
            RowLayout {
                anchors.fill: parent; spacing: 8
                Label { text: "Wanted"; Layout.preferredWidth: 64 }
                Label { text: "File"; Layout.fillWidth: true }
                Label { text: "Progress"; Layout.preferredWidth: 100 }
                Label { text: "Size"; Layout.preferredWidth: 80 }
                Label { text: "Priority"; Layout.preferredWidth: 92 }
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
                required property var modelData
                width: list.width; height: 32
                enabled: !root.store.busy
                contentItem: RowLayout {
                    spacing: 8
                    CheckBox {
                        Layout.preferredWidth: 64
                        tristate: row.modelData.folder
                        checkState: row.modelData.wanted === 2 ? Qt.PartiallyChecked : (row.modelData.wanted ? Qt.Checked : Qt.Unchecked)
                        onClicked: root.store.setWanted(row.modelData, checkState === Qt.Checked)
                    }
                    ToolButton {
                        visible: row.modelData.folder
                        text: row.modelData.expanded ? "▾" : "▸"
                        Layout.leftMargin: row.modelData.depth * 16
                        onClicked: root.store.toggleExpanded(row.modelData.key)
                    }
                    Item { visible: !row.modelData.folder; Layout.preferredWidth: row.modelData.depth * 16 + 36 }
                    Label { text: row.modelData.name; elide: Text.ElideMiddle; Layout.fillWidth: true; font.bold: row.modelData.folder }
                    TorrentProgressBar {
                        Layout.preferredWidth: 100
                        value: row.modelData.size ? row.modelData.completed / row.modelData.size : 0
                    }
                    Label { text: Format.bytes(row.modelData.size); horizontalAlignment: Text.AlignRight; Layout.preferredWidth: 80 }
                    ComboBox {
                        Layout.preferredWidth: 92
                        model: ["Low", "Normal", "High"]
                        currentIndex: row.modelData.priority === -2 ? -1 : row.modelData.priority + 1
                        displayText: row.modelData.priority === -2 ? "Mixed" : currentText
                        onActivated: function(index) { root.store.setPriority(row.modelData, index - 1) }
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
}
