import QtQuick

Item {
    id: root

    property real value: 0
    readonly property real position: Math.max(0, Math.min(1, value))
    readonly property bool hovered: hoverHandler.hovered

    implicitWidth: 200
    implicitHeight: 6

    SystemPalette { id: colors }

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: colors.mid
    }
    Rectangle {
        width: root.position * root.width
        height: root.height
        radius: height / 2
        color: colors.highlight
    }
    HoverHandler { id: hoverHandler }
}
