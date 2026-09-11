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

    property string selectedHash: ""
    property var selectedTorrent: store.torrentByHash(selectedHash)
    property string transientMessage: ""
    property string pendingConnectProfileId: ""

    Component.onCompleted: {
        var profile = profiles.activeProfile
        if (profile) {
            client.configure(profile.endpoint, profile.username, profiles.passwordFor(profile.id), profile.id)
            store.activateProfile(profile.id, false)
        }
    }
    onClosing: function(close) {
        if (addController.active) {
            close.accepted = false
            closeDraftDialog.open()
        }
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
    ConnectionProfiles { id: profiles; credentialBackend: credentialStore }
    TorrentFilesStore {
        id: liveFiles
        client: client
        torrentHash: window.selectedHash
        visible: detailTabs.currentIndex === 1
    }
    TorrentFilesStore { id: draftFiles; client: client; draftMode: true; visible: true }
    AddTorrentController { id: addController; client: client; draftStore: draftFiles; profiles: profiles; fileReader: torrentFileReader }

    Connections {
        target: store
        function onUpdated() { window.selectedTorrent = store.torrentByHash(window.selectedHash) }
        function onMutationFinished(message, success) {
            window.transientMessage = message
            messageTimer.restart()
        }
    }
    Connections {
        target: profiles
        function onPasswordReady(profileId, password, error) {
            if (window.pendingConnectProfileId !== profileId) return
            window.pendingConnectProfileId = ""
            var profile = profiles.profile(profileId)
            if (!profile) return
            window.activateProfile(profile, password, true)
            if (error) {
                window.transientMessage = "Saved password unavailable; enter it in connection settings"
                connectionDialog.open()
            }
        }
    }
    Connections {
        target: client
        function onBecameConnected() {
            if (addController.recoveryHash && addController.recoveryProfileId === client.profileId)
                recoveryDialog.open()
        }
    }
    Timer { id: messageTimer; interval: 5000; onTriggered: window.transientMessage = "" }

    function activateProfile(profile, password, connectNow) {
        if (!profile) return
        if (addController.active && client.profileId !== profile.id) {
            transientMessage = "Finish or leave the paused draft before switching profiles"
            return
        }
        selectedHash = ""
        selectedTorrent = null
        store.activateProfile(profile.id, false)
        client.activateProfile(profile.id, profile.endpoint, profile.username, password || "", connectNow)
    }

    function selectAndConnect(profileId) {
        var profile = profiles.profile(profileId)
        if (!profile) return
        profiles.select(profileId)
        pendingConnectProfileId = profileId
        profiles.requestPassword(profileId)
    }

    header: ToolBar {
        RowLayout {
            anchors.fill: parent
            ToolButton { text: "Add"; icon.name: "list-add"; icon.source: "icons/add.svg"; enabled: client.connected; onClicked: addDialog.open() }
            ToolSeparator {}
            ToolButton {
                text: "Start"
                icon.name: "media-playback-start"
                icon.source: "icons/start.svg"
                enabled: client.connected && window.selectedTorrent && window.selectedTorrent.status === 0
                onClicked: store.start(window.selectedHash)
            }
            ToolButton {
                text: "Stop"
                icon.name: "media-playback-stop"
                icon.source: "icons/stop.svg"
                enabled: client.connected && window.selectedTorrent && window.selectedTorrent.status !== 0
                onClicked: store.stop(window.selectedHash)
            }
            ToolButton { text: "Remove"; icon.name: "edit-delete"; icon.source: "icons/remove.svg"; enabled: client.connected && window.selectedTorrent; onClicked: removeDialog.open() }
            Item { Layout.fillWidth: true }
            ComboBox {
                id: profileSelector
                Layout.preferredWidth: 180
                model: profiles.profiles
                textRole: "name"
                currentIndex: Math.max(0, profiles.profiles.findIndex(function(p) { return p.id === profiles.activeProfileId }))
                enabled: !addController.active
                onActivated: function(index) { window.selectAndConnect(profiles.profiles[index].id) }
            }
            ToolButton { text: "Profiles"; icon.name: "preferences-system-network"; icon.source: "icons/profiles.svg"; onClicked: connectionDialog.open() }
            ToolButton {
                text: client.connected || client.connecting ? "Disconnect" : "Connection"
                icon.name: client.connected || client.connecting ? "network-disconnect" : "network-connect"
                icon.source: client.connected || client.connecting ? "icons/disconnect.svg" : "icons/connect.svg"
                onClicked: client.connected || client.connecting ? client.disconnectFromServer() : window.selectAndConnect(profiles.activeProfileId)
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
                        selectedHash: window.selectedHash
                        onSelectionChanged: function(torrentHash) {
                            window.selectedHash = torrentHash
                            window.selectedTorrent = store.torrentByHash(torrentHash)
                        }
                    }
                }
            }

            Frame {
                SplitView.preferredHeight: 250
                SplitView.minimumHeight: 110
                ColumnLayout {
                    anchors.fill: parent; spacing: 0
                    TabBar {
                        id: detailTabs
                        Layout.fillWidth: true
                        TabButton { text: "General" }
                        TabButton { text: "Files" }
                    }
                    StackLayout {
                        Layout.fillWidth: true; Layout.fillHeight: true
                        currentIndex: detailTabs.currentIndex
                        TorrentDetails { torrent: window.selectedTorrent }
                        TorrentFilesView { store: liveFiles }
                    }
                }
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
            Label { text: window.transientMessage || profiles.errorMessage || store.errorMessage || client.errorMessage; color: palette.brightText; elide: Text.ElideRight; Layout.maximumWidth: window.width * 0.45 }
            Label { text: "↓ " + Format.speed(store.downloadSpeed) + "   ↑ " + Format.speed(store.uploadSpeed) }
        }
    }

    ConnectionDialog {
        id: connectionDialog
        anchors.centerIn: Overlay.overlay
        profiles: profiles
        profileSwitchingAllowed: !addController.active
        onConnectRequested: function(profileId, endpoint, username, password) {
            var profile = profiles.profile(profileId)
            window.activateProfile(profile, password, true)
        }
    }
    AddTorrentDialog {
        id: addDialog
        anchors.centerIn: Overlay.overlay
        controller: addController
        profiles: profiles
    }
    Dialog {
        id: removeDialog
        title: "Remove torrent?"
        modal: true
        width: 500
        standardButtons: Dialog.Yes | Dialog.No
        anchors.centerIn: Overlay.overlay
        Label {
            width: removeDialog.availableWidth
            wrapMode: Text.WordWrap
            text: "Remove “" + (window.selectedTorrent ? window.selectedTorrent.name : "") + "” from Transmission? Downloaded files will be preserved."
        }
        onAccepted: store.remove(window.selectedHash)
    }
    Dialog {
        id: closeDraftDialog
        title: "Paused draft in progress"
        modal: true
        standardButtons: Dialog.NoButton
        anchors.centerIn: Overlay.overlay
        ColumnLayout {
            Label { text: "Remove the confirmed paused draft, or leave it on the server before closing?"; wrapMode: Text.WordWrap; Layout.preferredWidth: 460 }
            RowLayout {
                Button { text: "Keep working"; onClicked: closeDraftDialog.close() }
                Button { text: "Leave paused && close"; onClicked: { addController.leavePaused(); closeDraftDialog.close(); window.close() } }
                Button { text: "Remove draft"; enabled: !!addController.ownedHash && !addController.busy; onClicked: addController.cleanup() }
            }
        }
    }
    Dialog {
        id: recoveryDialog
        title: "Paused draft found"
        modal: true
        standardButtons: Dialog.NoButton
        anchors.centerIn: Overlay.overlay
        ColumnLayout {
            Label { text: "A confirmed paused draft from an earlier session is on this server."; Layout.preferredWidth: 440; wrapMode: Text.WordWrap }
            RowLayout {
                Button { text: "Keep"; onClicked: { addController.clearRecovery(); recoveryDialog.close() } }
                Button { text: "Resume"; onClicked: { addController.ownedHash = addController.recoveryHash; addController.loadFiles(); recoveryDialog.close(); addDialog.open() } }
                Button { text: "Remove"; onClicked: { addController.ownedHash = addController.recoveryHash; addController.cleanup(); recoveryDialog.close() } }
            }
        }
    }
}
