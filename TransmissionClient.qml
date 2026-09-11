pragma ComponentBehavior: Bound

import QtQuick
import "js/RpcProtocol.js" as Rpc

QtObject {
    id: root

    property string endpoint: "http://localhost:9091/transmission/rpc"
    property string username: ""
    property string password: ""
    property bool connected: false
    property bool connecting: false
    property bool desiredConnected: false
    property string connectionState: "Disconnected"
    property string errorMessage: ""
    property string serverVersion: ""
    property string rpcVersion: ""
    property string sessionId: ""
    property int requestTimeoutMs: 10000
    property int generation: 0
    property int reconnectAttempt: 0
    property var pending: ({})

    signal becameConnected()
    signal becameDisconnected()

    property Timer deadlineTimer: Timer {
        interval: 250
        repeat: true
        running: false
        onTriggered: root.checkDeadlines()
    }

    property Timer reconnectTimer: Timer {
        repeat: false
        onTriggered: root.openSession()
    }

    function configure(url, user, secret) {
        var normalized = String(url || "").trim()
        if (normalized && !/^https?:\/\//i.test(normalized))
            normalized = "http://" + normalized
        var changed = endpoint !== normalized || username !== user || password !== secret
        var reconnect = changed && desiredConnected
        if (changed) {
            reconnectTimer.stop()
            ++generation
            abortPending()
            connected = false
            connecting = false
            sessionId = ""
        }
        endpoint = normalized
        username = user || ""
        password = secret || ""
        if (reconnect)
            openSession()
    }

    function connectToServer() {
        desiredConnected = true
        reconnectAttempt = 0
        errorMessage = ""
        openSession()
    }

    function disconnectFromServer() {
        desiredConnected = false
        reconnectTimer.stop()
        ++generation
        abortPending()
        connecting = false
        connected = false
        connectionState = "Disconnected"
        sessionId = ""
        becameDisconnected()
    }

    function openSession() {
        if (!desiredConnected || connecting || !endpoint)
            return
        connecting = true
        connectionState = reconnectAttempt ? "Reconnecting…" : "Connecting…"
        request("session_get", { fields: ["version", "rpc_version_semver"] }, false,
                function(result, error) {
            connecting = false
            if (!desiredConnected)
                return
            if (error) {
                connected = false
                errorMessage = error.message
                connectionState = error.kind === "unsupported" ? "Unsupported server" : "Connection failed"
                if (error.retryable)
                    scheduleReconnect()
                return
            }
            var version = result.rpc_version_semver || ""
            if (!Rpc.isSupportedVersion(version)) {
                markUnsupported(version)
                return
            }
            serverVersion = result.version || "Transmission"
            rpcVersion = version
            reconnectAttempt = 0
            connected = true
            connectionState = "Connected to " + serverVersion
            errorMessage = ""
            becameConnected()
        })
    }

    function scheduleReconnect() {
        if (!desiredConnected || reconnectTimer.running)
            return
        var seconds = Math.min(30, Math.pow(2, reconnectAttempt))
        ++reconnectAttempt
        connectionState = "Reconnecting in " + seconds + "s…"
        reconnectTimer.interval = seconds * 1000
        reconnectTimer.start()
    }

    function markUnsupported(version) {
        connected = false
        connecting = false
        desiredConnected = false
        rpcVersion = version || "unknown"
        errorMessage = "Unsupported Transmission RPC version " + rpcVersion + ". Version 6.0.0 or newer is required."
        connectionState = "Unsupported server"
    }

    function transportFailed(message) {
        if (!desiredConnected)
            return
        var wasConnected = connected
        connected = false
        connecting = false
        errorMessage = message
        if (wasConnected)
            becameDisconnected()
        scheduleReconnect()
    }

    function request(method, params, mutation, callback) {
        if (!endpoint) {
            callback(null, makeError("Enter an RPC URL", "configuration", false))
            return
        }
        var envelope = Rpc.createRequest(method, params)
        send(envelope, mutation, callback, 0, generation)
    }

    function send(envelope, mutation, callback, sessionRetry, requestGeneration) {
        if (requestGeneration !== generation)
            return
        var xhr = new XMLHttpRequest()
        var key = String(envelope.id) + ":" + String(sessionRetry)
        pending[key] = { xhr: xhr, deadline: Date.now() + requestTimeoutMs,
                         callback: callback, mutation: mutation, generation: requestGeneration }
        pending = pending
        deadlineTimer.start()
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return
            var entry = pending[key]
            if (!entry)
                return
            delete pending[key]
            pending = pending
            if (Object.keys(pending).length === 0)
                deadlineTimer.stop()
            if (entry.generation !== generation)
                return
            if (xhr.status === 409) {
                var rpcHeader = xhr.getResponseHeader("X-Transmission-Rpc-Version")
                if (rpcHeader && !Rpc.isSupportedVersion(rpcHeader)) {
                    var unsupported = makeError("Unsupported Transmission RPC version " + rpcHeader, "unsupported", false)
                    callback(null, unsupported)
                    return
                }
                var newId = xhr.getResponseHeader("X-Transmission-Session-Id")
                if (newId && sessionRetry < 1) {
                    sessionId = newId
                    send(envelope, mutation, callback, sessionRetry + 1, requestGeneration)
                } else {
                    callback(null, makeError("Transmission rejected the session ID", "session", true))
                }
                return
            }
            if (xhr.status === 401 || xhr.status === 403) {
                var wasConnected = connected
                desiredConnected = false
                connected = false
                connectionState = "Authentication failed"
                if (wasConnected)
                    becameDisconnected()
                callback(null, makeError("Authentication failed. Check the username and password.", "authentication", false))
                return
            }
            if (xhr.status < 200 || xhr.status >= 300) {
                var httpError = makeError("HTTP " + xhr.status + (xhr.statusText ? ": " + xhr.statusText : ""), "network", xhr.status === 0 || xhr.status >= 500)
                if (httpError.retryable)
                    transportFailed(httpError.message)
                callback(null, httpError)
                return
            }
            try {
                callback(Rpc.parseResponse(xhr.responseText, envelope.id), null)
            } catch (error) {
                callback(null, makeError(error.message, error.code !== undefined ? "rpc" : "protocol", false))
            }
        }
        try {
            xhr.open("POST", endpoint, true)
            xhr.setRequestHeader("Content-Type", "application/json")
            if (sessionId)
                xhr.setRequestHeader("X-Transmission-Session-Id", sessionId)
            if (username)
                xhr.setRequestHeader("Authorization", "Basic " + Qt.btoa(username + ":" + password))
            xhr.send(JSON.stringify(envelope))
        } catch (error) {
            delete pending[key]
            pending = pending
            var sendError = makeError("Could not send request: " + error, "network", true)
            transportFailed(sendError.message)
            callback(null, sendError)
        }
    }

    function checkDeadlines() {
        var now = Date.now()
        var keys = Object.keys(pending)
        for (var i = 0; i < keys.length; ++i) {
            var key = keys[i]
            var entry = pending[key]
            if (entry.deadline > now)
                continue
            delete pending[key]
            try { entry.xhr.abort() } catch (ignored) {}
            if (entry.generation !== generation)
                continue
            var message = entry.mutation
                    ? "Request timed out. Its result is unknown; refreshing state."
                    : "Request timed out"
            var error = makeError(message, "timeout", true)
            transportFailed(message)
            entry.callback(null, error)
        }
        pending = pending
        if (Object.keys(pending).length === 0)
            deadlineTimer.stop()
    }

    function abortPending() {
        var keys = Object.keys(pending)
        for (var i = 0; i < keys.length; ++i) {
            try { pending[keys[i]].xhr.abort() } catch (ignored) {}
        }
        pending = ({})
        deadlineTimer.stop()
    }

    function makeError(message, kind, retryable) {
        return { message: message, kind: kind, retryable: retryable }
    }

    function addTorrent(link, directory, startImmediately, callback) {
        var params = { filename: link, paused: !startImmediately }
        if (directory)
            params.download_dir = directory
        request("torrent_add", params, true, callback)
    }

    function startTorrent(id, callback) {
        request("torrent_start", { ids: [id] }, true, callback)
    }

    function stopTorrent(id, callback) {
        request("torrent_stop", { ids: [id] }, true, callback)
    }

    function removeTorrent(id, callback) {
        request("torrent_remove", { ids: [id], delete_local_data: false }, true, callback)
    }
}
