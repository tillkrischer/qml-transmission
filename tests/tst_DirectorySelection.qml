import QtQuick
import QtTest
import ".."

TestCase {
    name: "DirectorySelection"
    width: 800
    height: 650
    when: windowShown

    TransmissionClient { id: client }
    ConnectionProfiles { id: profiles; credentialBackend: null }
    TorrentFilesStore { id: files; client: client; draftMode: true }
    AddTorrentController {
        id: controller
        client: client
        profiles: profiles
        draftStore: files
        fileReader: null
    }
    TorrentStore { id: store; client: client }
    AddTorrentDialog { id: addDialog; controller: controller; profiles: profiles }
    SetDataLocationDialog { id: locationDialog; store: store }

    function cleanup() {
        addDialog.close()
        locationDialog.close()
        client.connected = false
    }

    function test_selectSavedDirectory_data() {
        return [
            { tag: "add-torrent", dialog: addDialog, fieldName: "addTorrentDirectory" },
            { tag: "set-location", dialog: locationDialog, fieldName: "locationDirectory" }
        ]
    }

    function test_selectSavedDirectory(data) {
        var field = findChild(data.dialog, data.fieldName)
        field.model = ["/downloads/game", "/downloads/other"]
        field.currentIndex = 0
        client.connected = true
        if (data.dialog === addDialog) {
            controller.directory = "/downloads/complete"
            addDialog.openRecovery()
        } else {
            store.items = [{ hash_string: "one", download_dir: "/downloads/complete" }]
            locationDialog.openForTorrents(["one"])
        }
        tryCompare(data.dialog, "opened", true)
        compare(field.editText, "/downloads/complete")
        compare(field.currentIndex, 0)

        // Selecting the existing index must replace independently initialized text.
        mouseClick(field, field.width - 10, field.height / 2)
        tryCompare(field.popup, "opened", true)
        var option = field.popup.contentItem.itemAtIndex(0)
        verify(option)
        mouseClick(option)
        tryCompare(field.popup, "visible", false)
        compare(field.editText, "/downloads/game")

        // Also restore the saved path after the user edits it manually.
        field.editText = "/typed/path"
        mouseClick(field, field.width - 10, field.height / 2)
        tryCompare(field.popup, "opened", true)
        mouseClick(field.popup.contentItem.itemAtIndex(0))
        tryCompare(field.popup, "visible", false)
        compare(field.editText, "/downloads/game")
    }
}
