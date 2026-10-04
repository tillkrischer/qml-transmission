import QtQuick

QtObject {
    id: root
    required property TransmissionClient client
    property string torrentHash: ""
    property bool visible: false
    property bool loading: false
    property bool stale: true
    property string errorMessage: ""
    property int requestEpoch: 0
    property int pollInterval: 2000
    property string sortRole: "address"
    property bool sortAscending: true
    property var peers: []
    property alias model: peerModel

    property ListModel internalModel: ListModel { id: peerModel }
    property Timer pollTimer: Timer {
        interval: root.pollInterval
        repeat: true
        running: root.visible && !!root.torrentHash && root.client.connected
        onTriggered: root.refresh()
    }
    property Connections clientConnections: Connections {
        target: root.client
        function onInvalidated() { root.cancelRequest() }
        function onProfileIdChanged() { root.reset() }
        function onConnectedChanged() {
            if (root.client.connected) root.refresh()
            else root.cancelRequest()
        }
    }

    onTorrentHashChanged: reset()
    onVisibleChanged: {
        if (visible) refresh()
        else cancelRequest()
    }
    onSortRoleChanged: rebuild()
    onSortAscendingChanged: rebuild()

    function cancelRequest() {
        ++requestEpoch
        loading = false
        stale = true
    }

    function reset() {
        cancelRequest()
        peers = []
        peerModel.clear()
        errorMessage = ""
        refresh()
    }

    function refresh() {
        if (!visible || !client.connected || !torrentHash || loading) return
        loading = true
        var epoch = requestEpoch
        var hash = torrentHash
        client.torrentPeers(hash, function(result, error) {
            if (epoch !== requestEpoch || hash !== torrentHash) return
            loading = false
            if (error) {
                stale = true
                errorMessage = error.message
                return
            }
            var torrents = result && Array.isArray(result.torrents) ? result.torrents : []
            var torrent = torrents.find(function(t) { return t.hash_string === hash })
            if (!torrent) {
                peers = []
                rebuild()
                stale = false
                errorMessage = "Torrent is no longer available"
                return
            }
            peers = (Array.isArray(torrent.peers) ? torrent.peers : []).map(function(peer) {
                var address = String(peer.address || "")
                var port = Number(peer.port) || 0
                return { key: JSON.stringify([address, port]), address: address, port: port,
                    client_name: String(peer.client_name || ""),
                    progress: Math.max(0, Math.min(1, Number(peer.progress) || 0)),
                    rate_to_client: Math.max(0, Number(peer.rate_to_client) || 0),
                    rate_to_peer: Math.max(0, Number(peer.rate_to_peer) || 0),
                    flag_str: String(peer.flag_str || "") }
            })
            errorMessage = ""
            stale = false
            rebuild()
        })
    }

    function rebuild() {
        var role = sortRole
        var direction = sortAscending ? 1 : -1
        var sorted = peers.slice().sort(function(a, b) {
            var left = a[role], right = b[role]
            var order = typeof left === "number" ? left - right : String(left).localeCompare(String(right))
            return order ? order * direction : a.key.localeCompare(b.key)
        })
        for (var i = 0; i < sorted.length; ++i) {
            if (i < peerModel.count) peerModel.set(i, sorted[i])
            else peerModel.append(sorted[i])
        }
        if (peerModel.count > sorted.length)
            peerModel.remove(sorted.length, peerModel.count - sorted.length)
    }
}
