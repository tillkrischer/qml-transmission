import QtQuick
import QtTest
import "../js/FileTree.js" as FileTree

TestCase {
    name: "FileTree"

    function test_indicesSurviveSorting() {
        var tree = FileTree.build([
            { name: "z/file.bin", length: 10 },
            { name: "a/file.bin", length: 20 },
            { name: "root.bin", length: 30 }
        ], [
            { wanted: true, priority: -1, bytes_completed: 2 },
            { wanted: false, priority: 1, bytes_completed: 3 },
            { wanted: true, priority: 0, bytes_completed: 30 }
        ])
        var rows = FileTree.flatten(tree, { "d:a": true, "d:z": true })
        compare(rows[0].name, "a")
        compare(rows[1].index, 1)
        compare(rows[2].name, "z")
        compare(rows[3].index, 0)
    }

    function test_folderAggregates() {
        var tree = FileTree.build([
            { name: "dir/a", length: 10 }, { name: "dir/b", length: 20 }
        ], [
            { wanted: true, priority: -1, bytes_completed: 10 },
            { wanted: false, priority: 1, bytes_completed: 5 }
        ])
        var folder = FileTree.flatten(tree, {})[0]
        compare(folder.wanted, 2)
        compare(folder.priority, -2)
        compare(folder.size, 30)
        compare(folder.completed, 15)
        compare(folder.indices[0], 0)
        compare(folder.indices[1], 1)
    }

    function test_largeTree() {
        var files = []
        var stats = []
        for (var i = 0; i < 10000; ++i) {
            files.push({ name: "folder" + (i % 100) + "/file" + i, length: i + 1 })
            stats.push({ wanted: i % 2 === 0, priority: 0, bytes_completed: i })
        }
        var tree = FileTree.build(files, stats)
        var rows = FileTree.flatten(tree, {})
        compare(tree.indices.length, 10000)
        compare(rows.length, 100)
        compare(rows[0].indices.length, 100)
    }
}
