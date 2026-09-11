.pragma library

function build(files, stats) {
    var root = { key: "", name: "", folder: true, depth: -1, children: [], indices: [] }
    var folders = { "": root }
    files = files || []
    stats = stats || []
    for (var index = 0; index < files.length; ++index) {
        var file = files[index] || {}
        var parts = String(file.name || ("File " + (index + 1))).split("/")
        var parent = root
        var path = ""
        for (var p = 0; p < parts.length - 1; ++p) {
            path = path ? path + "/" + parts[p] : parts[p]
            if (!folders[path]) {
                folders[path] = { key: "d:" + path, name: parts[p], folder: true,
                    depth: p, children: [], indices: [] }
                parent.children.push(folders[path])
            }
            parent = folders[path]
        }
        var state = stats[index] || {}
        var leaf = { key: "f:" + index, name: parts[parts.length - 1], folder: false,
            depth: parts.length - 1, index: index, indices: [index], children: [],
            size: Number(file.length) || 0, completed: Number(state.bytes_completed) || 0,
            wanted: state.wanted === undefined ? true : !!state.wanted,
            priority: Number(state.priority) || 0 }
        parent.children.push(leaf)
        var cursor = root
        cursor.indices.push(index)
        path = ""
        for (p = 0; p < parts.length - 1; ++p) {
            path = path ? path + "/" + parts[p] : parts[p]
            cursor = folders[path]
            cursor.indices.push(index)
        }
    }
    aggregate(root)
    return root
}

function aggregate(node) {
    if (!node.folder) {
        node.leafCount = 1
        node.wantedCount = node.wanted ? 1 : 0
        return node
    }
    node.size = 0
    node.completed = 0
    var wantedCount = 0
    var leafCount = 0
    var firstPriority = null
    var mixedPriority = false
    for (var i = 0; i < node.children.length; ++i) {
        var child = aggregate(node.children[i])
        node.size += child.size
        node.completed += child.completed
        wantedCount += child.wantedCount
        leafCount += child.leafCount
        if (child.priority === -2) mixedPriority = true
        else if (firstPriority === null) firstPriority = child.priority
        else if (firstPriority !== child.priority) mixedPriority = true
    }
    node.leafCount = leafCount
    node.wantedCount = wantedCount
    node.wanted = wantedCount === 0 ? 0 : (wantedCount === leafCount ? 1 : 2)
    node.priority = mixedPriority ? -2 : (firstPriority === null ? 0 : firstPriority)
    return node
}

function flatten(tree, expanded) {
    var rows = []
    function appendChildren(node) {
        var children = node.children.slice().sort(function(a, b) {
            if (a.folder !== b.folder) return a.folder ? -1 : 1
            return a.name.localeCompare(b.name)
        })
        for (var i = 0; i < children.length; ++i) {
            var child = children[i]
            var row = {}
            for (var key in child) if (key !== "children") row[key] = child[key]
            row.expanded = child.folder && !!expanded[child.key]
            rows.push(row)
            if (row.expanded) appendChildren(child)
        }
    }
    appendChildren(tree)
    return rows
}
