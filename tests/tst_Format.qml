import QtQuick
import QtTest
import "../js/Format.js" as Format

TestCase {
    name: "Format"
    function test_bytes() {
        compare(Format.bytes(0), "0 B")
        compare(Format.bytes(1024), "1.0 KiB")
        compare(Format.bytes(10485760), "10 MiB")
    }
    function test_duration() {
        compare(Format.duration(-1), "—")
        compare(Format.duration(3660), "1h 1m")
    }
    function test_status() {
        compare(Format.status(0), "Stopped")
        compare(Format.status(4), "Downloading")
        compare(Format.status(6), "Seeding")
    }
    function test_dateTime() {
        compare(Format.dateTime(0), "—")
        compare(Format.dateTime(-2), "—")
        compare(Format.dateTime("bad"), "—")
        verify(Format.dateTime(1704067200).length > 3)
    }
}
