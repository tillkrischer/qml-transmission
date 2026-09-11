import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Dialog {
    id: root
    title: "Connection"
    modal: true
    standardButtons: Dialog.NoButton
    width: 620

    required property ConnectionProfiles profiles
    property bool profileSwitchingAllowed: true
    property bool passwordEdited: false
    signal connectRequested(string profileId, string endpoint, string username, string password)

    onOpened: {
        passwordEdited = false
        loadProfile()
        urlField.forceActiveFocus()
    }

    function loadProfile() {
        var value = profiles.activeProfile
        if (!value) return
        nameField.text = value.name
        urlField.text = value.endpoint
        userField.text = value.username
        rememberBox.checked = value.rememberPassword
        directoryField.text = value.defaultDirectory
        passwordField.text = profiles.passwordFor(value.id)
        if (value.rememberPassword) profiles.requestPassword(value.id)
    }

    Connections {
        target: root.profiles
        function onPasswordReady(profileId, password, error) {
            if (root.profiles.activeProfileId === profileId && !root.passwordEdited)
                passwordField.text = password
            credentialError.text = error ? "Saved password unavailable: " + error + ". Enter it manually." : ""
        }
    }

    ColumnLayout {
        width: parent.width
        spacing: 12

        Label {
            text: "Connect to a Transmission 4.1 or newer daemon."
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }
        RowLayout {
            Layout.fillWidth: true
            ComboBox {
                Layout.fillWidth: true
                model: root.profiles.profiles
                enabled: root.profileSwitchingAllowed
                textRole: "name"
                currentIndex: Math.max(0, root.profiles.profiles.findIndex(function(p) { return p.id === root.profiles.activeProfileId }))
                onActivated: function(index) { root.profiles.select(root.profiles.profiles[index].id); root.loadProfile() }
            }
            Button { text: "Add"; enabled: root.profileSwitchingAllowed; onClicked: { root.profiles.addProfile(); root.loadProfile() } }
            Button { text: "Delete"; enabled: root.profileSwitchingAllowed && root.profiles.profiles.length > 1; onClicked: { root.profiles.removeProfile(root.profiles.activeProfileId); root.loadProfile() } }
        }
        Label { text: "Profile name" }
        TextField { id: nameField; Layout.fillWidth: true; selectByMouse: true }
        Label { text: "RPC URL" }
        TextField {
            id: urlField
            Layout.fillWidth: true
            placeholderText: "http://localhost:9091/transmission/rpc"
            selectByMouse: true
        }
        Label { text: "Username (optional)" }
        TextField { id: userField; Layout.fillWidth: true; selectByMouse: true }
        Label { text: "Password" }
        TextField {
            id: passwordField
            Layout.fillWidth: true
            echoMode: TextInput.Password
            selectByMouse: true
            onTextEdited: root.passwordEdited = true
        }
        CheckBox { id: rememberBox; text: "Remember password in the desktop credential store" }
        Label { id: credentialError; Layout.fillWidth: true; wrapMode: Text.WordWrap; color: palette.brightText }
        Label { text: "Default download directory override (optional)" }
        TextField { id: directoryField; Layout.fillWidth: true; placeholderText: "Use server default"; selectByMouse: true }
        RowLayout {
            Layout.fillWidth: true
            Button { text: "Close"; onClicked: root.close() }
            Item { Layout.fillWidth: true }
            Button {
                text: "Save"
                onClicked: root.profiles.saveProfile(root.profiles.activeProfileId, nameField.text.trim(), urlField.text.trim(), userField.text, rememberBox.checked, directoryField.text.trim(), passwordField.text)
            }
            Button {
                text: "Save && Connect"
                highlighted: true
                onClicked: {
                    root.profiles.saveProfile(root.profiles.activeProfileId, nameField.text.trim(), urlField.text.trim(), userField.text, rememberBox.checked, directoryField.text.trim(), passwordField.text)
                    root.connectRequested(root.profiles.activeProfileId, urlField.text.trim(), userField.text, passwordField.text)
                    root.close()
                }
            }
        }
    }
}
