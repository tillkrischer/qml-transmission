import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Dialog {
    id: root
    title: "Add torrent link"
    modal: true
    standardButtons: Dialog.Ok | Dialog.Cancel
    width: 580

    signal addRequested(string link, string directory, bool startImmediately)

    onOpened: {
        linkField.clear()
        linkField.forceActiveFocus()
    }
    onAccepted: addRequested(linkField.text.trim(), directoryField.text.trim(), startBox.checked)

    ColumnLayout {
        width: parent.width
        Label { text: "Magnet link or torrent URL" }
        TextField {
            id: linkField
            Layout.fillWidth: true
            placeholderText: "magnet:?xt=… or https://…/file.torrent"
            selectByMouse: true
        }
        Label { text: "Download directory on the server (optional)" }
        TextField {
            id: directoryField
            Layout.fillWidth: true
            placeholderText: "/server/path"
            selectByMouse: true
        }
        CheckBox { id: startBox; text: "Start immediately"; checked: true }
    }
}

