pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Dialog {
    id: root
    title: "Set data location"
    modal: true
    width: 580
    standardButtons: Dialog.Ok | Dialog.Cancel

    required property TorrentStore store
    property var recentDirectories: []
    property var targetHashes: []
    property int connectionGeneration: -1
    readonly property bool canSubmit: store.client.connected
                                      && store.client.generation === connectionGeneration
                                      && targetHashes.length > 0
                                      && directoryField.editText.trim().length > 0

    function openForTorrents(hashes) {
        if (!store.client.connected || !hashes.length) return
        targetHashes = hashes.slice()
        connectionGeneration = store.client.generation
        var torrent = store.torrentByHash(targetHashes[0])
        directoryField.editText = torrent ? torrent.download_dir || "" : ""
        moveData.checked = true
        open()
    }

    onOpened: {
        standardButton(Dialog.Ok).enabled = canSubmit
        directoryField.forceActiveFocus()
    }
    onCanSubmitChanged: if (visible) standardButton(Dialog.Ok).enabled = canSubmit
    onAccepted: {
        if (canSubmit)
            store.setLocation(targetHashes, directoryField.editText, moveData.checked)
    }
    onClosed: targetHashes = []

    Connections {
        target: root.store.client
        function onInvalidated() { root.reject() }
    }

    ColumnLayout {
        width: root.availableWidth
        Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: root.targetHashes.length > 1
                  ? "New location for " + root.targetHashes.length + " selected torrents on the server:"
                  : "New location for torrent data on the server:"
        }
        ComboBox {
            id: directoryField
            objectName: "locationDirectory"
            Layout.fillWidth: true
            editable: true
            model: root.recentDirectories
        }
        CheckBox {
            id: moveData
            objectName: "moveLocationData"
            text: "Move torrent data from current location to new location"
            checked: true
        }
        Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            visible: !moveData.checked
            text: "Use data already at the new location. Existing files will not be moved."
        }
    }
}
