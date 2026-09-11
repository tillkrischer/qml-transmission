pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "js/Format.js" as Format

Item {
    id: root
    required property TorrentStore store
    property string selectedHash: ""
    readonly property int tableWidth: 1120
    signal selectionChanged(string torrentHash)

    function select(hash) {
        selectedHash = hash
        selectionChanged(hash)
    }

    Connections {
        target: root.store
        function onUpdated() {
            if (root.selectedHash && !root.store.torrentByHash(root.selectedHash))
                root.select("")
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
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                spacing: 8
                Repeater {
                    model: [
                        { title: "Name", role: "name", width: 260 },
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
            y: header.height
            width: root.tableWidth
            height: horizontal.height - header.height
            clip: true
            model: root.store.model
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar {}

            delegate: ItemDelegate {
                id: row
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
                highlighted: root.selectedHash === hash_string
                onClicked: root.select(hash_string)

                contentItem: RowLayout {
                    spacing: 8
                    Label { text: row.name; elide: Text.ElideRight; Layout.fillWidth: true; Layout.minimumWidth: 180 }
                    Label { text: Format.bytes(row.total_size); horizontalAlignment: Text.AlignRight; Layout.preferredWidth: 82 }
                    ProgressBar { from: 0; to: 1; value: row.percent_complete; Layout.preferredWidth: 92; ToolTip.text: Math.round(row.percent_complete * 100) + "%"; ToolTip.visible: hovered }
                    RowLayout {
                        spacing: 6; Layout.preferredWidth: 135
                        StatusIcon { status: row.status; error: row.error; errorText: row.error_string || (row.error ? "Torrent error" : "") }
                        Label { text: Format.status(row.status); elide: Text.ElideRight; Layout.fillWidth: true }
                    }
                    Label { text: Format.speed(row.rate_download); horizontalAlignment: Text.AlignRight; Layout.preferredWidth: 84 }
                    Label { text: Format.speed(row.rate_upload); horizontalAlignment: Text.AlignRight; Layout.preferredWidth: 84 }
                    Label { text: Format.ratio(row.upload_ratio); horizontalAlignment: Text.AlignRight; Layout.preferredWidth: 62 }
                    Label { text: Format.duration(row.eta); horizontalAlignment: Text.AlignRight; Layout.preferredWidth: 70 }
                    Label { text: Format.dateTime(row.added_date); Layout.preferredWidth: 150 }
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
