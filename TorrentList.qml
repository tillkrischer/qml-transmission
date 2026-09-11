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
    readonly property int tablePadding: 8
    readonly property int columnSpacing: 8
    readonly property int nameColumnWidth: tableWidth - (2 * tablePadding) - (8 * columnSpacing)
                                                   - 82 - 92 - 135 - 84 - 84 - 62 - 70 - 150
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
                highlighted: root.selectedHash === hash_string
                onClicked: root.select(hash_string)

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
}
