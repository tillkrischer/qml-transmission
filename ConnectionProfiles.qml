import QtQuick
import QtCore

QtObject {
    id: root

    required property var credentialBackend

    property var profiles: []
    property string activeProfileId: ""
    readonly property var activeProfile: profile(activeProfileId)
    property var passwords: ({})
    property var pendingReads: ({})
    property var deletionFailures: ({})
    property string errorMessage: ""

    signal changed()
    signal passwordReady(string profileId, string password, string error)
    signal credentialSaved(string profileId, string error)

    property Settings storage: Settings {
        location: StandardPaths.writableLocation(StandardPaths.ConfigLocation) + "/qml-transmission.ini"
        category: "main"
    }

    property Connections credentialConnections: Connections {
        target: root.credentialBackend
        function onReadFinished(requestId, profileId, password, error) {
            if (root.pendingReads[profileId] !== requestId)
                return
            delete root.pendingReads[profileId]
            root.pendingReads = root.pendingReads
            if (!error) {
                root.passwords[profileId] = password
                root.passwords = root.passwords
            }
            root.passwordReady(profileId, password, error)
        }
        function onWriteFinished(requestId, profileId, error) {
            root.errorMessage = error ? "Could not save password: " + error : ""
            root.credentialSaved(profileId, error)
        }
        function onRemoveFinished(requestId, profileId, error) {
            if (error) {
                var retained = root.deletionFailures[profileId] || {}
                retained.error = error
                root.deletionFailures[profileId] = retained
                root.deletionFailures = root.deletionFailures
                root.errorMessage = "Profile removed, but its saved password could not be deleted: " + error
            } else {
                delete root.deletionFailures[profileId]
                root.deletionFailures = root.deletionFailures
            }
        }
    }

    Component.onCompleted: initialize()

    function uuid() {
        if (credentialBackend && credentialBackend.generateUuid)
            return credentialBackend.generateUuid()
        return Date.now().toString(16) + "-" + Math.random().toString(16).slice(2)
    }

    function normalizedProfile(value) {
        return {
            id: String(value.id || uuid()),
            name: String(value.name || "Connection"),
            endpoint: String(value.endpoint || "http://localhost:9091/transmission/rpc"),
            username: String(value.username || ""),
            rememberPassword: !!value.rememberPassword,
            defaultDirectory: String(value.defaultDirectory || ""),
            recentDirectories: Array.isArray(value.recentDirectories) ? value.recentDirectories.slice(0, 10) : []
        }
    }

    function initialize() {
        var loaded = []
        try { loaded = JSON.parse(storage.value("profilesJson", "[]")) } catch (ignored) {}
        if (!Array.isArray(loaded)) loaded = []
        if (!storage.value("profilesMigrationComplete", false) && loaded.length === 0) {
            loaded.push(normalizedProfile({ name: "Default",
                endpoint: storage.value("endpoint", "http://localhost:9091/transmission/rpc"),
                username: storage.value("username", "") }))
            profiles = loaded
            activeProfileId = loaded[0].id
            storage.setValue("profilesJson", JSON.stringify(profiles))
            storage.setValue("profilesSchemaVersion", 1)
            storage.setValue("lastProfileId", activeProfileId)
            storage.sync()
            storage.setValue("profilesMigrationComplete", true)
            storage.sync()
        } else {
            profiles = loaded.map(normalizedProfile)
            if (!profiles.length)
                profiles = [normalizedProfile({ name: "Default" })]
            var lastId = storage.value("lastProfileId", "")
            activeProfileId = profile(lastId) ? lastId : profiles[0].id
            persist()
        }
    }

    function profile(id) {
        for (var i = 0; i < profiles.length; ++i)
            if (profiles[i].id === id) return profiles[i]
        return null
    }

    function persist() {
        storage.setValue("profilesJson", JSON.stringify(profiles))
        storage.setValue("profilesSchemaVersion", 1)
        storage.setValue("lastProfileId", activeProfileId)
        storage.sync()
        changed()
    }

    function select(id) {
        if (!profile(id) || id === activeProfileId) return
        activeProfileId = id
        storage.setValue("lastProfileId", id)
        storage.sync()
        changed()
    }

    function addProfile() {
        var value = normalizedProfile({ name: "New connection" })
        profiles = profiles.concat([value])
        select(value.id)
        persist()
        return value.id
    }

    function saveProfile(id, name, endpoint, username, remember, directory, password) {
        delete pendingReads[id]
        pendingReads = pendingReads
        var next = []
        for (var i = 0; i < profiles.length; ++i) {
            var old = profiles[i]
            next.push(old.id === id ? normalizedProfile({ id: id, name: name,
                endpoint: endpoint, username: username, rememberPassword: remember,
                defaultDirectory: directory, recentDirectories: old.recentDirectories }) : old)
        }
        profiles = next
        persist()
        passwords[id] = password || ""
        passwords = passwords
        var requestId = "write-" + id + "-" + Date.now()
        if (remember)
            credentialBackend.write(requestId, id, password || "")
        else
            credentialBackend.remove(requestId, id)
    }

    function removeProfile(id) {
        if (profiles.length <= 1) {
            errorMessage = "At least one profile is required"
            return false
        }
        var next = []
        for (var i = 0; i < profiles.length; ++i)
            if (profiles[i].id !== id) next.push(profiles[i])
        var removed = profile(id)
        profiles = next
        if (activeProfileId === id) activeProfileId = profiles[0].id
        persist()
        credentialBackend.remove("delete-" + id + "-" + Date.now(), id)
        delete passwords[id]
        passwords = passwords
        deletionFailures[id] = { profile: removed, error: "pending" }
        deletionFailures = deletionFailures
        return true
    }

    function passwordFor(id) { return passwords[id] || "" }

    function requestPassword(id) {
        var value = profile(id)
        if (!value || !value.rememberPassword) {
            passwordReady(id, passwordFor(id), "")
            return
        }
        var requestId = "read-" + id + "-" + Date.now()
        pendingReads[id] = requestId
        pendingReads = pendingReads
        credentialBackend.read(requestId, id)
    }

    function recordDirectory(id, directory) {
        directory = String(directory || "").trim()
        if (!directory) return
        var next = []
        for (var i = 0; i < profiles.length; ++i) {
            var value = profiles[i]
            if (value.id === id) {
                var recent = [directory]
                for (var j = 0; j < value.recentDirectories.length && recent.length < 10; ++j)
                    if (value.recentDirectories[j] !== directory) recent.push(value.recentDirectories[j])
                value = normalizedProfile({ id: value.id, name: value.name, endpoint: value.endpoint,
                    username: value.username, rememberPassword: value.rememberPassword,
                    defaultDirectory: value.defaultDirectory, recentDirectories: recent })
            }
            next.push(value)
        }
        profiles = next
        persist()
    }
}
