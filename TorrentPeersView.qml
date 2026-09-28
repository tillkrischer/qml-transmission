pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Basic as Basic
import QtQuick.Layouts
import "js/Format.js" as Format

Item {
    id: root
    required property TorrentPeersStore store
    readonly property real rowHeight: Math.max(28, metrics.height + 8)
    readonly property real tableWidth: Math.max(930, horizontal.width)
    readonly property var columns: [
        { title: "Address", role: "address", width: root.tableWidth - 690 },
        { title: "Port", role: "port", width: 70 },
        { title: "Client", role: "client_name", width: 190 },
        { title: "Flags", role: "flag_str", width: 100 },
        { title: "Progress", role: "progress", width: 100 },
        { title: "Up", role: "rate_to_peer", width: 115 },
        { title: "Down", role: "rate_to_client", width: 115 }
    ]
    FontMetrics { id: metrics; font: status.font }

    function cellText(peer, role) {
        if (role === "progress") return (peer.progress * 100).toFixed(1) + "%"
        if (role === "rate_to_client" || role === "rate_to_peer") return Format.speed(peer[role])
        return String(peer[role])
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0
        Label {
            id: status
            Layout.fillWidth: true
            visible: root.store.model.count > 0 && (!!root.store.errorMessage || root.store.stale)
            text: (root.store.errorMessage || (root.store.client.connected ? "Refreshing…" : "Disconnected"))
                  + " · data is stale"
            color: root.store.errorMessage ? palette.brightText : palette.placeholderText
            elide: Text.ElideRight
        }
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            id: table
            Flickable {
                id: horizontal
                anchors.fill: parent
                anchors.rightMargin: verticalBar.visible ? verticalBar.implicitWidth : 0
                anchors.bottomMargin: horizontalBar.visible ? horizontalBar.implicitHeight : 0
                contentWidth: root.tableWidth
                contentHeight: height
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                flickableDirection: Flickable.HorizontalFlick
                ScrollBar.horizontal: ScrollBar {
                    id: horizontalBar
                    parent: table
                    visible: size < 1
                    y: table.height - height
                    width: horizontal.width
                }
                Row {
                    id: header
                    height: root.rowHeight
                    Repeater {
                        model: root.columns
                        Basic.Button {
                            id: heading
                            required property var modelData
                            width: modelData.width
                            height: header.height
                            text: modelData.title + (root.store.sortRole === modelData.role
                                  ? (root.store.sortAscending ? " ▲" : " ▼") : "")
                            padding: 6
                            topPadding: 0
                            bottomPadding: 0
                            background: Rectangle {
                                color: heading.down ? heading.palette.mid : heading.palette.alternateBase
                                border.width: heading.visualFocus ? 1 : 0
                                border.color: heading.palette.highlight
                            }
                            contentItem: Label {
                                text: heading.text
                                elide: Text.ElideRight
                                verticalAlignment: Text.AlignVCenter
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
                ListView {
                    id: list
                    objectName: "peerList"
                    y: header.height
                    width: root.tableWidth
                    height: Math.max(0, horizontal.height - header.height)
                    clip: true
                    model: root.store.model
                    boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.vertical: ScrollBar {
                        id: verticalBar
                        parent: table
                        visible: size < 1
                        x: table.width - width
                        y: header.height
                        height: list.height
                    }
                    delegate: Rectangle {
                        id: row
                        required property int index
                        required property var model
                        width: list.width
                        height: root.rowHeight
                        color: index % 2 ? palette.alternateBase : palette.base
                        Row {
                            anchors.fill: parent
                            Repeater {
                                model: root.columns
                                Label {
                                    id: cell
                                    required property var modelData
                                    width: modelData.width
                                    height: row.height
                                    leftPadding: 6
                                    rightPadding: 6
                                    text: root.cellText(row.model, modelData.role)
                                    elide: Text.ElideRight
                                    verticalAlignment: Text.AlignVCenter
                                    horizontalAlignment: ["port", "progress", "rate_to_client", "rate_to_peer"].indexOf(modelData.role) >= 0
                                                         ? Text.AlignRight : Text.AlignLeft
                                    HoverHandler { id: cellHover }
                                    ToolTip.visible: cellHover.hovered && cell.truncated
                                    ToolTip.text: text
                                }
                            }
                        }
                    }
                }
            }
            Label {
                anchors.centerIn: parent
                width: Math.max(0, parent.width - 24)
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                visible: root.store.model.count === 0
                text: !root.store.torrentHash ? "No torrent selected"
                      : root.store.errorMessage ? root.store.errorMessage
                      : !root.store.client.connected ? "Disconnected"
                      : root.store.loading ? "Loading peers…" : "No connected peers"
                color: root.store.errorMessage ? palette.brightText : palette.placeholderText
            }
        }
    }
}
