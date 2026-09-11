.pragma library

var nextId = 1

function createRequest(method, params) {
    if (!method || typeof method !== "string")
        throw new Error("RPC method must be a non-empty string")

    return {
        jsonrpc: "2.0",
        params: params || {},
        method: method,
        id: nextId++
    }
}

function parseResponse(text, expectedId) {
    var response
    try {
        response = JSON.parse(text)
    } catch (error) {
        throw new Error("The server returned malformed JSON")
    }

    if (!response || response.jsonrpc !== "2.0")
        throw new Error("The server did not return a JSON-RPC 2.0 response")
    if (response.id !== expectedId)
        throw new Error("The server returned a response with an unexpected ID")
    if (response.error) {
        var message = response.error.message || "RPC request failed"
        if (response.error.data && response.error.data.error_string)
            message += ": " + response.error.data.error_string
        var rpcError = new Error(message)
        rpcError.code = response.error.code
        rpcError.data = response.error.data
        throw rpcError
    }
    if (response.result === undefined)
        throw new Error("The RPC response has no result")
    return response.result
}

function majorVersion(semver) {
    var match = String(semver || "").match(/^(\d+)\./)
    return match ? Number(match[1]) : -1
}

function isSupportedVersion(semver) {
    return majorVersion(semver) >= 6
}

function base64Utf8(value) {
    var encoded = encodeURIComponent(String(value))
    var bytes = []
    for (var i = 0; i < encoded.length; ++i) {
        if (encoded[i] === "%") {
            bytes.push(parseInt(encoded.slice(i + 1, i + 3), 16))
            i += 2
        } else {
            bytes.push(encoded.charCodeAt(i))
        }
    }

    var alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    var result = ""
    for (var offset = 0; offset < bytes.length; offset += 3) {
        var first = bytes[offset]
        var second = offset + 1 < bytes.length ? bytes[offset + 1] : 0
        var third = offset + 2 < bytes.length ? bytes[offset + 2] : 0
        var bits = (first << 16) | (second << 8) | third
        result += alphabet[(bits >> 18) & 63]
        result += alphabet[(bits >> 12) & 63]
        result += offset + 1 < bytes.length ? alphabet[(bits >> 6) & 63] : "="
        result += offset + 2 < bytes.length ? alphabet[bits & 63] : "="
    }
    return result
}
