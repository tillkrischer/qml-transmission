import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Dialog {
    id: root
    title: "Connection"
    modal: true
    standardButtons: Dialog.Ok | Dialog.Cancel
    width: 540

    property string endpoint: ""
    property string username: ""
    property string password: ""
    signal connectRequested(string endpoint, string username, string password)

    onOpened: {
        urlField.text = endpoint
        userField.text = username
        passwordField.text = password
        urlField.forceActiveFocus()
    }
    onAccepted: connectRequested(urlField.text.trim(), userField.text, passwordField.text)

    ColumnLayout {
        width: parent.width
        spacing: 12

        Label {
            text: "Connect to a Transmission 4.1 or newer daemon."
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }
        Label { text: "RPC URL" }
        TextField {
            id: urlField
            Layout.fillWidth: true
            placeholderText: "http://localhost:9091/transmission/rpc"
            selectByMouse: true
        }
        Label { text: "Username (optional)" }
        TextField { id: userField; Layout.fillWidth: true; selectByMouse: true }
        Label { text: "Password (kept in memory only)" }
        TextField {
            id: passwordField
            Layout.fillWidth: true
            echoMode: TextInput.Password
            selectByMouse: true
            onAccepted: root.accept()
        }
    }
}

