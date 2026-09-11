import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "js/Format.js" as Format

ScrollView {
    id: root
    required property var torrent
    clip: true

    GridLayout {
        width: root.availableWidth
        columns: 2
        columnSpacing: 18
        rowSpacing: 6

        Label { text: "Name"; font.bold: true }
        Label { text: root.torrent ? root.torrent.name : "No torrent selected"; Layout.fillWidth: true; wrapMode: Text.WrapAnywhere }
        Label { text: "Hash"; font.bold: true; visible: !!root.torrent }
        Label { text: root.torrent ? root.torrent.hash_string : ""; visible: !!root.torrent; Layout.fillWidth: true; wrapMode: Text.WrapAnywhere }
        Label { text: "Directory"; font.bold: true; visible: !!root.torrent }
        Label { text: root.torrent ? root.torrent.download_dir : ""; visible: !!root.torrent; Layout.fillWidth: true; wrapMode: Text.WrapAnywhere }
        Label { text: "Downloaded"; font.bold: true; visible: !!root.torrent }
        Label { text: root.torrent ? Format.bytes(root.torrent.downloaded_ever) : ""; visible: !!root.torrent }
        Label { text: "Uploaded"; font.bold: true; visible: !!root.torrent }
        Label { text: root.torrent ? Format.bytes(root.torrent.uploaded_ever) : ""; visible: !!root.torrent }
        Label { text: "Error"; font.bold: true; visible: !!root.torrent }
        Label {
            text: root.torrent && root.torrent.error_string ? root.torrent.error_string : "None"
            visible: !!root.torrent
            color: root.torrent && root.torrent.error_string ? palette.brightText : palette.text
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
        }
    }
}

