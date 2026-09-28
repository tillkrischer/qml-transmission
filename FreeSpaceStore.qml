import QtQuick

QtObject {
    id: root
    required property TransmissionClient client
    property string path: ""
    property real sizeBytes: -1
    property bool loading: false
    property bool stale: true
    property string errorMessage: ""
    property int requestEpoch: 0
    property int pollInterval: 30000

    property Timer pollTimer: Timer {
        interval: root.pollInterval
        repeat: true
        running: root.client.connected && !!root.path
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

    onPathChanged: reset()

    function cancelRequest() {
        ++requestEpoch
        loading = false
        stale = true
    }

    function reset() {
        cancelRequest()
        sizeBytes = -1
        errorMessage = ""
        refresh()
    }

    function refresh() {
        if (!client.connected || !path || loading) return
        loading = true
        var epoch = requestEpoch
        var requestPath = path
        client.freeSpace(requestPath, function(result, error) {
            if (epoch !== requestEpoch || requestPath !== path) return
            loading = false
            if (error) {
                sizeBytes = -1
                stale = true
                errorMessage = error.message
                return
            }
            var size = result ? result.size_bytes : undefined
            if (!result || result.path !== requestPath || typeof size !== "number"
                    || !isFinite(size) || size < 0) {
                sizeBytes = -1
                stale = true
                errorMessage = "Free space is unavailable for this directory"
                return
            }
            sizeBytes = size
            stale = false
            errorMessage = ""
        })
    }
}
