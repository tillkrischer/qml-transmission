import QtQuick
import "js/Format.js" as Format

Item {
    id: root

    property real value: 0
    readonly property real position: Math.max(0, Math.min(1, value))
    readonly property string percentageText: Format.percent(position)
    readonly property bool hovered: hoverHandler.hovered

    implicitWidth: 200
    implicitHeight: 20

    SystemPalette { id: colors }

    Rectangle {
        anchors.fill: parent
        radius: 2
        color: colors.base
        border.color: colors.mid
    }
    Rectangle {
        id: completed
        width: root.position * root.width
        height: root.height
        radius: 2
        color: colors.highlight
    }
    Text {
        width: root.width
        height: root.height
        text: root.percentageText
        color: colors.text
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }
    Item {
        width: completed.width
        height: root.height
        clip: true
        Text {
            width: root.width
            height: root.height
            text: root.percentageText
            color: colors.highlightedText
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
    }
    HoverHandler { id: hoverHandler }
}
