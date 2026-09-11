pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "js/Format.js" as Format

Item {
    id: root
    required property TorrentStore store
    property int selectedId: -1
    signal selectionChanged(int torrentId)

    function select(id) {
        selectedId = id
        selectionChanged(id)
    }

    Connections {
        target: root.store
        function onUpdated() {
            if (root.selectedId >= 0 && !root.store.torrentById(root.selectedId))
                root.select(-1)
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 34
            color: palette.alternateBase
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                spacing: 8
                Repeater {
                    model: [
                        { title: "Name", role: "name", width: 260 },
                        { title: "Size", role: "total_size", width: 82 },
                        { title: "Progress", role: "percent_complete", width: 92 },
                        { title: "Status", role: "status", width: 120 },
                        { title: "Down", role: "rate_download", width: 84 },
                        { title: "Up", role: "rate_upload", width: 84 },
                        { title: "Ratio", role: "upload_ratio", width: 62 },
                        { title: "ETA", role: "eta", width: 70 }
                    ]
                    Button {
                        required property var modelData
                        text: modelData.title + (root.store.sortRole === modelData.role ? (root.store.sortAscending ? "  ▲" : "  ▼") : "")
                        flat: true
                        Layout.fillWidth: modelData.role === "name"
                        Layout.preferredWidth: modelData.width
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
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: root.store.model
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar {}

            delegate: ItemDelegate {
                id: row
                required property int id
                required property string name
                required property real total_size
                required property real percent_complete
                required property int status
                required property real rate_download
                required property real rate_upload
                required property real upload_ratio
                required property real eta
                width: list.width
                height: 34
                highlighted: root.selectedId === id
                onClicked: root.select(id)

                contentItem: RowLayout {
                    spacing: 8
                    Label { text: row.name; elide: Text.ElideRight; Layout.fillWidth: true; Layout.minimumWidth: 180 }
                    Label { text: Format.bytes(row.total_size); horizontalAlignment: Text.AlignRight; Layout.preferredWidth: 82 }
                    ProgressBar { from: 0; to: 1; value: row.percent_complete; Layout.preferredWidth: 92; ToolTip.text: Math.round(row.percent_complete * 100) + "%"; ToolTip.visible: hovered }
                    Label { text: Format.status(row.status); Layout.preferredWidth: 120 }
                    Label { text: Format.speed(row.rate_download); horizontalAlignment: Text.AlignRight; Layout.preferredWidth: 84 }
                    Label { text: Format.speed(row.rate_upload); horizontalAlignment: Text.AlignRight; Layout.preferredWidth: 84 }
                    Label { text: Format.ratio(row.upload_ratio); horizontalAlignment: Text.AlignRight; Layout.preferredWidth: 62 }
                    Label { text: Format.duration(row.eta); horizontalAlignment: Text.AlignRight; Layout.preferredWidth: 70 }
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
}
