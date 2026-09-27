import QtQuick
import QtQuick.Controls
import QtTest
import ".."

TestCase {
    name: "SetDataLocation"
    width: 640
    height: 400
    when: windowShown

    TransmissionClient {
        id: client
        property var calls: []
        function request(method, params, mutation, callback) {
            if (mutation) calls.push({ method: method, params: params })
            callback(method === "torrent_get" ? { torrents: store.items } : {}, null)
        }
    }
    TorrentStore { id: store; client: client }
    SetDataLocationDialog { id: dialog; store: store }

    function init() {
        client.connected = true
        client.calls = []
        store.items = [{ hash_string: "one", name: "One", download_dir: "/old" },
                       { hash_string: "two", name: "Two", download_dir: "/other" }]
    }
    function cleanup() {
        dialog.close()
        client.connected = false
    }
    function test_moveSelected() {
        var hashes = ["one", "two"]
        dialog.openForTorrents(hashes)
        tryCompare(dialog, "opened", true)
        hashes.pop()
        var directory = findChild(dialog, "locationDirectory")
        compare(directory.editText, "/old")
        directory.editText = "  /new  "
        mouseClick(dialog.standardButton(Dialog.Ok))
        compare(client.calls.length, 1)
        compare(client.calls[0].method, "torrent_set_location")
        compare(client.calls[0].params.ids, ["one", "two"])
        compare(client.calls[0].params.location, "/new")
        compare(client.calls[0].params.move, true)
    }
    function test_useExistingDataAndValidation() {
        dialog.openForTorrents(["one"])
        tryCompare(dialog, "opened", true)
        var directory = findChild(dialog, "locationDirectory")
        directory.editText = "   "
        compare(dialog.standardButton(Dialog.Ok).enabled, false)
        directory.editText = "/existing"
        findChild(dialog, "moveLocationData").checked = false
        mouseClick(dialog.standardButton(Dialog.Ok))
        compare(client.calls.length, 1)
        compare(client.calls[0].params.move, false)
    }
    function test_cancelAndConnectionSwitch() {
        dialog.openForTorrents(["one"])
        tryCompare(dialog, "opened", true)
        mouseClick(dialog.standardButton(Dialog.Cancel))
        compare(client.calls.length, 0)
        dialog.openForTorrents(["one"])
        tryCompare(dialog, "opened", true)
        client.invalidate()
        tryCompare(dialog, "visible", false)
        compare(client.calls.length, 0)
    }
    function test_draftLocationStillPreservesData() {
        client.setTorrentLocation("one", "/draft", function() {})
        compare(client.calls[0].params.ids, ["one"])
        compare(client.calls[0].params.move, false)
    }
}
