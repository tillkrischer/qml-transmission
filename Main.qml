pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtCore
import "js/Format.js" as Format

ApplicationWindow {
    id: window
    visible: true
    title: "QML Transmission"
    minimumWidth: 820
    minimumHeight: 560
    width: Number(settings.value("width", 1100))
    height: Number(settings.value("height", 720))
    x: Number(settings.value("x", (Screen.width - width) / 2))
    y: Number(settings.value("y", (Screen.height - height) / 2))

    property int selectedId: -1
    property var selectedTorrent: store.torrentById(selectedId)
    property string transientMessage: ""

    Component.onCompleted: {
        Qt.application.name = "QML Transmission"
        Qt.application.organization = "qml-transmission"
        Qt.application.domain = "qml-transmission.local"
        client.endpoint = settings.value("endpoint", "http://localhost:9091/transmission/rpc")
        client.username = settings.value("username", "")
    }
    Component.onDestruction: {
        settings.setValue("width", width)
        settings.setValue("height", height)
        settings.setValue("x", x)
        settings.setValue("y", y)
        settings.sync()
    }

    Settings {
        id: settings
        location: StandardPaths.writableLocation(StandardPaths.ConfigLocation) + "/qml-transmission.ini"
        category: "main"
    }
    TransmissionClient { id: client }
    TorrentStore { id: store; client: client }

    Connections {
        target: store
        function onUpdated() { window.selectedTorrent = store.torrentById(window.selectedId) }
        function onMutationFinished(message, success) {
            window.transientMessage = message
            messageTimer.restart()
        }
    }
    Timer { id: messageTimer; interval: 5000; onTriggered: window.transientMessage = "" }

    header: ToolBar {
        RowLayout {
            anchors.fill: parent
            ToolButton { text: "Add link"; enabled: client.connected; onClicked: addDialog.open() }
            ToolSeparator {}
            ToolButton {
                text: "Start"
                enabled: client.connected && window.selectedTorrent && window.selectedTorrent.status === 0
                onClicked: store.start(window.selectedId)
            }
            ToolButton {
                text: "Stop"
                enabled: client.connected && window.selectedTorrent && window.selectedTorrent.status !== 0
                onClicked: store.stop(window.selectedId)
            }
            ToolButton { text: "Remove"; enabled: client.connected && window.selectedTorrent; onClicked: removeDialog.open() }
            Item { Layout.fillWidth: true }
            ToolButton {
                text: client.connected || client.connecting ? "Disconnect" : "Connection"
                onClicked: client.connected || client.connecting ? client.disconnectFromServer() : connectionDialog.open()
            }
        }
    }

    SplitView {
        anchors.fill: parent
        orientation: Qt.Horizontal

        Frame {
            SplitView.preferredWidth: 165
            SplitView.minimumWidth: 130
            ColumnLayout {
                anchors.fill: parent
                Label { text: "Show"; font.bold: true; Layout.leftMargin: 8 }
                ButtonGroup { id: filterGroup }
                Repeater {
                    model: [
                        { label: "All", value: "all" },
                        { label: "Downloading", value: "downloading" },
                        { label: "Seeding", value: "seeding" },
                        { label: "Stopped", value: "stopped" }
                    ]
                    RadioButton {
                        required property var modelData
                        text: modelData.label
                        checked: modelData.value === "all"
                        ButtonGroup.group: filterGroup
                        Layout.fillWidth: true
                        onClicked: store.statusFilter = modelData.value
                    }
                }
                Item { Layout.fillHeight: true }
            }
        }

        SplitView {
            orientation: Qt.Vertical
            SplitView.fillWidth: true

            Pane {
                SplitView.fillHeight: true
                SplitView.minimumHeight: 220
                ColumnLayout {
                    anchors.fill: parent
                    TextField {
                        Layout.fillWidth: true
                        placeholderText: "Search torrents…"
                        selectByMouse: true
                        onTextChanged: store.searchText = text
                    }
                    TorrentList {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        store: store
                        selectedId: window.selectedId
                        onSelectionChanged: function(torrentId) {
                            window.selectedId = torrentId
                            window.selectedTorrent = store.torrentById(torrentId)
                        }
                    }
                }
            }

            Frame {
                SplitView.preferredHeight: 190
                SplitView.minimumHeight: 110
                TorrentDetails { anchors.fill: parent; torrent: window.selectedTorrent }
            }
        }
    }

    footer: ToolBar {
        RowLayout {
            anchors.fill: parent
            Label {
                text: store.stale && store.items.length ? client.connectionState + " · data is stale" : client.connectionState
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
            Label { text: window.transientMessage || store.errorMessage || client.errorMessage; color: palette.brightText; elide: Text.ElideRight; Layout.maximumWidth: window.width * 0.45 }
            Label { text: "↓ " + Format.speed(store.downloadSpeed) + "   ↑ " + Format.speed(store.uploadSpeed) }
        }
    }

    ConnectionDialog {
        id: connectionDialog
        anchors.centerIn: Overlay.overlay
        endpoint: client.endpoint
        username: client.username
        password: client.password
        onConnectRequested: function(endpoint, username, password) {
            settings.setValue("endpoint", endpoint)
            settings.setValue("username", username)
            settings.sync()
            client.configure(endpoint, username, password)
            client.connectToServer()
        }
    }
    AddTorrentDialog {
        id: addDialog
        anchors.centerIn: Overlay.overlay
        onAddRequested: function(link, directory, startImmediately) {
            if (link)
                store.add(link, directory, startImmediately)
        }
    }
    Dialog {
        id: removeDialog
        title: "Remove torrent?"
        modal: true
        standardButtons: Dialog.Yes | Dialog.No
        anchors.centerIn: Overlay.overlay
        Label {
            width: 420
            wrapMode: Text.WordWrap
            text: "Remove “" + (window.selectedTorrent ? window.selectedTorrent.name : "") + "” from Transmission? Downloaded files will be preserved."
        }
        onAccepted: store.remove(window.selectedId)
    }
}
