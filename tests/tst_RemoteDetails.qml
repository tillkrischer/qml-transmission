import QtQuick
import QtTest
import ".."

TestCase {
    name: "RemoteDetails"
    width: 800
    height: 350
    when: windowShown

    TransmissionClient {
        id: client
        property var calls: []
        function request(method, params, mutation, callback) {
            calls.push({ method: method, params: params, mutation: mutation, callback: callback })
        }
    }
    FreeSpaceStore { id: space; client: client }
    TorrentPeersStore { id: peers; client: client }
    TorrentPeersView { id: view; store: peers; anchors.fill: parent }

    function init() {
        client.invalidate()
        client.profileId = "first"
        space.path = ""
        space.reset()
        peers.visible = false
        peers.torrentHash = ""
        peers.reset()
        peers.sortRole = "address"
        peers.sortAscending = true
        space.pollInterval = 30000
        peers.pollInterval = 2000
        client.calls = []
        client.connected = true
    }
    function cleanup() { client.invalidate() }
    function replySpace(call, bytes) {
        call.callback({ path: call.params.path, size_bytes: bytes }, null)
    }
    function replyPeers(call, values) {
        call.callback({ torrents: [{ hash_string: call.params.ids[0], peers: values }] }, null)
    }
    function showPeers() {
        peers.torrentHash = "one"
        peers.visible = true
    }
    function peer(address, port, speed) {
        return { address: address, port: port, client_name: "Transmission", progress: 0.5,
                 rate_to_client: speed, rate_to_peer: 12, flag_str: "DE" }
    }
    function test_freeSpaceZeroErrorsAndRecovery() {
        space.path = "/downloads"
        compare(client.calls[0].method, "free_space")
        compare(client.calls[0].mutation, false)
        replySpace(client.calls[0], 0)
        compare(space.sizeBytes, 0)
        compare(space.stale, false)
        space.refresh()
        client.calls[1].callback(null, { message: "No such directory" })
        compare(space.sizeBytes, -1)
        compare(space.errorMessage, "No such directory")
        space.refresh()
        replySpace(client.calls[2], 1024 * 1024 * 1024 * 5)
        compare(space.sizeBytes, 5368709120)
        compare(space.errorMessage, "")
    }
    function test_freeSpaceInvalidReplies_data() {
        return [ { tag: "missing", value: {} }, { tag: "negative", value: { path: "/a", size_bytes: -1 } },
                 { tag: "wrong path", value: { path: "/b", size_bytes: 10 } },
                 { tag: "null", value: { path: "/a", size_bytes: null } } ]
    }
    function test_freeSpaceInvalidReplies(data) {
        space.path = "/a"
        client.calls[0].callback(data.value, null)
        compare(space.sizeBytes, -1)
        verify(space.errorMessage.length > 0)
    }
    function test_freeSpaceSwitchingAndReconnect() {
        space.path = "/a"
        var old = client.calls[0]
        space.path = "/b"
        replySpace(old, 20)
        compare(space.sizeBytes, -1)
        compare(space.loading, true)
        replySpace(client.calls[1], 40)
        client.connected = false
        compare(space.sizeBytes, 40)
        compare(space.stale, true)
        client.connected = true
        compare(client.calls.length, 3)
        var previousProfile = client.calls[2]
        client.activateProfile("second", "http://unused", "", "", false)
        compare(space.sizeBytes, -1)
        client.connected = true
        replySpace(previousProfile, 100)
        compare(space.sizeBytes, -1)
        replySpace(client.calls[3], 200)
        compare(space.sizeBytes, 200)
    }
    function test_freeSpacePollingDoesNotOverlap() {
        space.pollInterval = 30
        space.path = "/a"
        wait(100)
        compare(client.calls.length, 1)
        replySpace(client.calls[0], 5)
        tryVerify(function() { return client.calls.length === 2 })
        client.connected = false
        wait(100)
        compare(client.calls.length, 2)
        replySpace(client.calls[1], 10)
        compare(space.sizeBytes, 5)
        verify(space.stale)
    }
    function test_peersVisibilityAndLateReplies() {
        peers.torrentHash = "one"
        compare(client.calls.length, 0)
        peers.visible = true
        compare(client.calls[0].method, "torrent_get")
        compare(client.calls[0].params.ids, ["one"])
        compare(client.calls[0].params.fields, ["hash_string", "peers"])
        compare(client.calls[0].mutation, false)
        peers.refresh()
        compare(client.calls.length, 1)
        peers.torrentHash = "two"
        replyPeers(client.calls[0], [peer("old", 1, 0)])
        compare(peers.model.count, 0)
        verify(peers.loading)
        replyPeers(client.calls[1], [peer("new", 1, 0)])
        compare(peers.model.get(0).address, "new")
        peers.refresh()
        peers.visible = false
        replyPeers(client.calls[2], [peer("hidden", 1, 0)])
        compare(peers.model.get(0).address, "new")
        peers.visible = true
        compare(client.calls.length, 4)
        peers.torrentHash = ""
        replyPeers(client.calls[3], [peer("late", 1, 0)])
        compare(peers.model.count, 0)
    }
    function test_peersReconnectAndProfileChange() {
        showPeers()
        replyPeers(client.calls[0], [peer("one", 1, 0)])
        peers.refresh()
        var old = client.calls[1]
        client.connected = false
        verify(peers.stale)
        compare(peers.model.count, 1)
        client.connected = true
        compare(client.calls.length, 3)
        replyPeers(old, [peer("late", 1, 0)])
        compare(peers.model.get(0).address, "one")
        verify(peers.loading)
        client.activateProfile("second", "http://unused", "", "", false)
        compare(peers.model.count, 0)
        client.connected = true
        replyPeers(client.calls[2], [peer("wrong server", 1, 0)])
        compare(peers.model.count, 0)
        replyPeers(client.calls[3], [peer("second server", 1, 0)])
        compare(peers.model.get(0).address, "second server")
    }
    function test_peersSortingUpdatesAndErrors() {
        showPeers()
        replyPeers(client.calls[0], [peer("::1", 20, 90), peer("::1", 3, 100)])
        peers.sortRole = "port"
        compare(peers.model.get(0).port, 3)
        peers.sortRole = "rate_to_client"
        compare(peers.model.get(0).port, 20)
        peers.sortAscending = false
        compare(peers.model.get(0).port, 3)
        peers.refresh()
        replyPeers(client.calls[1], [peer("::1", 20, 150), peer("::2", 40, 5)])
        compare(peers.model.count, 2)
        compare(peers.model.get(0).rate_to_client, 150)
        compare(peers.model.get(1).address, "::2")
        peers.refresh()
        client.calls[2].callback(null, { message: "Peer request failed" })
        compare(peers.model.count, 2)
        verify(peers.stale)
        compare(peers.errorMessage, "Peer request failed")
        peers.refresh()
        replyPeers(client.calls[3], [])
        compare(peers.model.count, 0)
        compare(peers.errorMessage, "")
        verify(!peers.stale)
        peers.refresh()
        client.calls[4].callback({ torrents: [] }, null)
        compare(peers.errorMessage, "Torrent is no longer available")
    }
    function test_peersPollingStopsWhenHidden() {
        peers.pollInterval = 30
        showPeers()
        wait(100)
        compare(client.calls.length, 1)
        replyPeers(client.calls[0], [])
        tryVerify(function() { return client.calls.length === 2 })
        peers.visible = false
        wait(100)
        compare(client.calls.length, 2)
    }
    function test_peerScrollPositionSurvivesRefresh() {
        showPeers()
        var values = []
        for (var i = 0; i < 100; ++i) values.push(peer("peer" + i, i, i))
        replyPeers(client.calls[0], values)
        var list = findChild(view, "peerList")
        tryCompare(list, "count", 100)
        list.positionViewAtIndex(50, ListView.Beginning)
        wait(50)
        var before = list.contentY
        verify(before > 0)
        peers.refresh()
        values[0].rate_to_client = 1000
        replyPeers(client.calls[1], values)
        wait(50)
        compare(list.contentY, before)
        compare(peers.model.get(0).rate_to_client, 1000)
    }
}
