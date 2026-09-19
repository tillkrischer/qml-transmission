pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Dialog {
    id: root
    title: controller.torrentName ? "Add torrent — " + controller.torrentName : "Add torrent"
    modal: true
    closePolicy: Popup.NoAutoClose
    standardButtons: Dialog.NoButton
    width: 760
    height: 600
    required property AddTorrentController controller
    required property ConnectionProfiles profiles

    property var pendingSources: []
    property bool localSources: true

    function openSources(sources, localFile) {
        pendingSources = Array.from(sources)
        localSources = localFile
        openNext()
    }

    function openRecovery() {
        pendingSources = []
        directoryField.editText = controller.directory || controller.client.defaultDownloadDirectory
        startBox.checked = controller.startRequested
        open()
    }

    function openNext() {
        if (!pendingSources.length) return
        var source = pendingSources[0]
        pendingSources = pendingSources.slice(1)
        controller.reset()
        var profile = profiles.activeProfile
        directoryField.editText = profile && profile.defaultDirectory
                ? profile.defaultDirectory : controller.client.defaultDownloadDirectory
        startBox.checked = true
        open()
        controller.begin(source, directoryField.editText, true, localSources)
    }

    ColumnLayout {
        anchors.fill: parent
        Label { text: "Download directory on the server" }
        ComboBox {
            id: directoryField
            Layout.fillWidth: true; editable: true
            enabled: !controller.busy
            model: profiles.activeProfile ? profiles.activeProfile.recentDirectories : []
        }
        CheckBox { id: startBox; text: "Start when ready"; checked: true; enabled: !controller.busy }
        Label {
            Layout.fillWidth: true; wrapMode: Text.WordWrap
            visible: controller.state === "choosing" && !controller.draftStore.files.length
            text: "Magnet metadata is not available yet. You can choose files in the Files tab once metadata arrives."
        }
        TorrentFilesView {
            Layout.fillWidth: true; Layout.fillHeight: true
            enabled: controller.state === "choosing"
            store: controller.draftStore
        }
        Label {
            visible: !!controller.errorMessage
            text: controller.errorMessage; color: palette.brightText
            Layout.fillWidth: true; wrapMode: Text.WordWrap
        }
        RowLayout {
            Layout.fillWidth: true
            Button {
                text: "Cancel"
                enabled: controller.state !== "applying" && controller.state !== "starting" && controller.state !== "cancelling"
                onClicked: { root.pendingSources = []; controller.cancel() }
            }
            Button {
                text: "Leave paused"
                visible: !!controller.ownedHash
                enabled: !controller.busy
                onClicked: { root.pendingSources = []; controller.leavePaused(); root.close() }
            }
            Item { Layout.fillWidth: true }
            BusyIndicator { running: controller.busy; implicitWidth: 28; implicitHeight: 28 }
            Button {
                text: controller.state === "editing" ? "Retry" : "Add"
                highlighted: true
                enabled: (controller.state === "choosing" || controller.state === "editing") && controller.client.connected
                onClicked: {
                    controller.directory = directoryField.editText.trim()
                    controller.startRequested = startBox.checked
                    if (controller.state === "editing")
                        controller.begin(controller.source, controller.directory, startBox.checked, controller.localFile)
                    else controller.apply()
                }
            }
        }
    }
    Connections {
        target: root.controller
        function onFinished() { Qt.callLater(root.openNext) }
        function onDuplicateFound() { Qt.callLater(root.openNext) }
        function onStateChanged() { if (root.controller.state === "done") root.close() }
    }
}
