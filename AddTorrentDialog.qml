pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

Dialog {
    id: root
    title: "Add torrent"
    modal: true
    standardButtons: Dialog.NoButton
    width: 760
    height: controller.state === "choosing" ? 600 : 390
    required property AddTorrentController controller
    required property ConnectionProfiles profiles

    onOpened: {
        if (!controller.active) controller.reset()
        var profile = profiles.activeProfile
        directoryField.editText = profile && profile.defaultDirectory
                ? profile.defaultDirectory : controller.client.defaultDownloadDirectory
    }

    FileDialog {
        id: fileDialog
        title: "Choose a torrent file"
        nameFilters: ["Torrent files (*.torrent)", "All files (*)"]
        onAccepted: sourceField.text = selectedFile
    }

    ColumnLayout {
        anchors.fill: parent
        TabBar {
            id: modeTabs
            Layout.fillWidth: true
            enabled: controller.state === "editing"
            TabButton { text: "File" }
            TabButton { text: "Link" }
        }
        Label {
            Layout.fillWidth: true; wrapMode: Text.WordWrap
            text: modeTabs.currentIndex === 0
                  ? "The file is uploaded and a paused torrent is created before you choose files."
                  : (/^magnet:/i.test(sourceField.text) ? "Magnet metadata may arrive later. Choose files from the Files tab after it becomes available." : "A paused torrent is created before you choose files.")
        }
        RowLayout {
            Layout.fillWidth: true
            TextField {
                id: sourceField; Layout.fillWidth: true; selectByMouse: true
                readOnly: controller.state !== "editing"
                placeholderText: modeTabs.currentIndex === 0 ? "Local .torrent file" : "Magnet link or torrent URL"
            }
            Button { visible: modeTabs.currentIndex === 0; text: "Browse…"; enabled: controller.state === "editing"; onClicked: fileDialog.open() }
        }
        Label { text: "Download directory on the server" }
        ComboBox {
            id: directoryField
            Layout.fillWidth: true; editable: true
            enabled: controller.state === "editing"
            model: profiles.activeProfile ? profiles.activeProfile.recentDirectories : []
        }
        CheckBox { id: startBox; text: "Start when file choices are applied"; checked: true; enabled: controller.state === "editing" || controller.state === "choosing" }
        TorrentFilesView {
            Layout.fillWidth: true; Layout.fillHeight: true
            visible: controller.state === "choosing"
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
                text: controller.ownedHash ? "Leave paused" : "Cancel"
                enabled: true
                onClicked: { controller.ownedHash ? controller.leavePaused() : controller.cancel(); root.close() }
            }
            Button {
                text: "Remove draft"
                visible: !!controller.ownedHash
                enabled: !controller.busy
                onClicked: controller.cleanup()
            }
            Item { Layout.fillWidth: true }
            BusyIndicator { running: controller.busy; implicitWidth: 28; implicitHeight: 28 }
            Button {
                text: controller.state === "choosing" ? "Add" : "Next: choose files"
                highlighted: true
                enabled: controller.state === "editing" || controller.state === "choosing"
                onClicked: {
                    controller.startRequested = startBox.checked
                    if (controller.state === "choosing") controller.apply()
                    else controller.begin(sourceField.text, directoryField.editText, startBox.checked, modeTabs.currentIndex === 0)
                }
            }
        }
    }

    Connections {
        target: root.controller
        function onFinished() { root.close() }
        function onDuplicateFound() { root.close() }
    }
}
