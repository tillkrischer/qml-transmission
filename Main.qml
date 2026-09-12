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
    property var selectedHashes: []
    property var selectedTorrent: store.torrentByHash(selectedHash)
    property var pendingRemovalHashes: []
    property string transientMessage: ""
    property string pendingConnectProfileId: ""
    property bool startupComplete: false

    Component.onCompleted: {
        startupComplete = true
        connectActiveProfile()
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
        function onActiveProfileIdChanged() {
            if (window.startupComplete)
                window.connectActiveProfile()
        }
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
        selectedHashes = []
        selectedTorrent = null
        store.activateProfile(profile.id, false)
        client.activateProfile(profile.id, profile.endpoint, profile.username, password || "", connectNow)
    }

    function connectActiveProfile() {
        var profile = profiles.activeProfile
        if (!profile) return
        pendingConnectProfileId = profile.id
        profiles.requestPassword(profile.id)
    }

    function hasSelectedTorrentWithStoppedState(stopped) {
        for (var i = 0; i < selectedHashes.length; ++i) {
            var torrent = store.torrentByHash(selectedHashes[i])
            if (torrent && ((torrent.status === 0) === stopped))
                return true
        }
        return false
    }

    function confirmRemoval(hashes) {
        pendingRemovalHashes = hashes.slice()
        deleteDataCheck.checked = false
        removeDialog.open()
    }

    function folderName(path) {
        var normalized = String(path).replace(/\/+$/, "")
        var separator = normalized.lastIndexOf("/")
        return separator >= 0 ? normalized.slice(separator + 1) : normalized
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
                enabled: client.connected && window.hasSelectedTorrentWithStoppedState(true)
                onClicked: store.start(window.selectedHashes)
            }
            ToolButton {
                text: "Stop"
                icon.name: "media-playback-stop"
                icon.source: "icons/stop.svg"
                enabled: client.connected && window.hasSelectedTorrentWithStoppedState(false)
                onClicked: store.stop(window.selectedHashes)
            }
            ToolButton {
                text: "Remove"
                icon.name: "edit-delete"
                icon.source: "icons/remove.svg"
                enabled: client.connected && window.selectedHashes.length > 0
                onClicked: {
                    window.confirmRemoval(window.selectedHashes)
                }
            }
            Item { Layout.fillWidth: true }
            ComboBox {
                id: profileSelector
                Layout.preferredWidth: 180
                model: profiles.profiles
                textRole: "name"
                currentIndex: Math.max(0, profiles.profiles.findIndex(function(p) { return p.id === profiles.activeProfileId }))
                enabled: !addController.active
                onActivated: function(index) { profiles.select(profiles.profiles[index].id) }
            }
            ToolButton { text: "Profiles"; icon.name: "preferences-system-network"; icon.source: "icons/profiles.svg"; onClicked: connectionDialog.open() }
        }
    }

    SplitView {
        anchors.fill: parent
        orientation: Qt.Horizontal

        Frame {
            SplitView.preferredWidth: 220
            SplitView.minimumWidth: 180
            ColumnLayout {
                anchors.fill: parent
                ButtonGroup { id: filterGroup }
                RadioButton {
                    text: "All torrents"
                    checked: store.filterKind === "status" && store.filterValue === "all"
                    ButtonGroup.group: filterGroup
                    Layout.fillWidth: true
                    onClicked: store.selectFilter("status", "all")
                }
                Repeater {
                    model: [
                        { label: "Downloading", value: "downloading" },
                        { label: "Seeding", value: "seeding" },
                        { label: "Stopped", value: "stopped" }
                    ]
                    RadioButton {
                        required property var modelData
                        text: modelData.label
                        checked: store.filterKind === "status" && store.filterValue === modelData.value
                        ButtonGroup.group: filterGroup
                        Layout.fillWidth: true
                        onClicked: store.selectFilter("status", modelData.value)
                    }
                }
                Rectangle {
                    visible: store.downloadDirectories.length > 0
                    Layout.fillWidth: true
                    Layout.leftMargin: 4
                    Layout.rightMargin: 4
                    Layout.topMargin: 4
                    Layout.bottomMargin: 4
                    implicitHeight: 1
                    color: palette.mid
                }
                Repeater {
                    model: store.downloadDirectories
                    RadioButton {
                        required property string modelData
                        text: window.folderName(modelData)
                        checked: store.filterKind === "directory" && store.filterValue === modelData
                        ButtonGroup.group: filterGroup
                        Layout.fillWidth: true
                        hoverEnabled: true
                        ToolTip.text: modelData
                        ToolTip.visible: hovered && text !== modelData
                        onClicked: store.selectFilter("directory", modelData)
                    }
                }
                Rectangle {
                    visible: store.trackerDomains.length > 0
                    Layout.fillWidth: true
                    Layout.leftMargin: 4
                    Layout.rightMargin: 4
                    Layout.topMargin: 4
                    Layout.bottomMargin: 4
                    implicitHeight: 1
                    color: palette.mid
                }
                Repeater {
                    model: store.trackerDomains
                    RadioButton {
                        required property string modelData
                        text: modelData
                        checked: store.filterKind === "tracker" && store.filterValue === modelData
                        ButtonGroup.group: filterGroup
                        Layout.fillWidth: true
                        onClicked: store.selectFilter("tracker", modelData)
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
                        id: torrentList
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        store: store
                        selectedHash: window.selectedHash
                        selectedHashes: window.selectedHashes
                        onSelectionChanged: function(torrentHash, torrentHashes) {
                            window.selectedHash = torrentHash
                            window.selectedHashes = torrentHashes
                            window.selectedTorrent = store.torrentByHash(torrentHash)
                        }
                        onActionRequested: function(action, torrentHashes) {
                            if (action === "start")
                                store.start(torrentHashes)
                            else if (action === "stop")
                                store.stop(torrentHashes)
                            else if (action === "remove") {
                                window.confirmRemoval(torrentHashes)
                            }
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
                        TorrentFilesView { store: liveFiles; detailsMode: true }
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
        onProfileSaved: function(profileId, password) {
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
        ColumnLayout {
            width: removeDialog.availableWidth
            Label {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: window.pendingRemovalHashes.length === 1
                      ? "Remove “" + (store.torrentByHash(window.pendingRemovalHashes[0])
                                      ? store.torrentByHash(window.pendingRemovalHashes[0]).name : "")
                        + "” from Transmission?"
                      : "Remove " + window.pendingRemovalHashes.length + " torrents from Transmission?"
            }
            CheckBox {
                id: deleteDataCheck
                text: "Also delete downloaded files"
                Layout.fillWidth: true
            }
            Label {
                Layout.fillWidth: true
                visible: deleteDataCheck.checked
                wrapMode: Text.WordWrap
                color: palette.brightText
                text: "Downloaded files will be permanently deleted from the Transmission server."
            }
        }
        onAccepted: store.remove(window.pendingRemovalHashes, deleteDataCheck.checked)
        onClosed: window.pendingRemovalHashes = []
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
