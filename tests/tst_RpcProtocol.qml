import QtQuick
import QtTest
import "../js/RpcProtocol.js" as Rpc

TestCase {
    name: "RpcProtocol"

    function verifyThrows(operation) {
        var didThrow = false
        try {
            operation()
        } catch (error) {
            didThrow = true
        }
        verify(didThrow)
    }

    function test_requestEnvelope() {
        var request = Rpc.createRequest("torrent_get", { fields: ["id", "name"] })
        compare(request.jsonrpc, "2.0")
        compare(request.method, "torrent_get")
        verify(request.id > 0)
        compare(request.params.fields[1], "name")
    }

    function test_parseResult() {
        var result = Rpc.parseResponse('{"jsonrpc":"2.0","result":{"version":"4.1.3"},"id":7}', 7)
        compare(result.version, "4.1.3")
    }

    function test_malformedAndWrongId() {
        verifyThrows(function() { Rpc.parseResponse("not json", 1) })
        verifyThrows(function() { Rpc.parseResponse('{"jsonrpc":"2.0","result":{},"id":2}', 1) })
    }

    function test_rpcError() {
        verifyThrows(function() {
            Rpc.parseResponse('{"jsonrpc":"2.0","error":{"code":3,"message":"bad","data":{"error_string":"details"}},"id":1}', 1)
        })
    }

    function test_supportedVersions() {
        verify(Rpc.isSupportedVersion("6.0.0"))
        verify(Rpc.isSupportedVersion("6.1.0"))
        verify(!Rpc.isSupportedVersion("5.3.0"))
        verify(!Rpc.isSupportedVersion("unknown"))
    }

    function test_base64Utf8() {
        compare(Rpc.base64Utf8("user:password"), "dXNlcjpwYXNzd29yZA==")
        compare(Rpc.base64Utf8("Jörg:🔑"), "SsO2cmc68J+UkQ==")
        compare(Rpc.base64Utf8(""), "")
    }
}
