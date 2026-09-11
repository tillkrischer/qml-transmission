import QtQuick
import QtQuick.Controls

Rectangle {
    id: root
    property int status: 0
    property int error: 0
    property string errorText: ""
    readonly property color statusColor: error ? "#d32f2f"
        : status === 4 ? "#1976d2"
        : status === 6 ? "#2e7d32"
        : (status === 2 ? "#f9a825" : (status === 1 || status === 3 || status === 5 ? "#78909c" : "#757575"))
    width: 14; height: 14; radius: status === 2 ? 2 : 7
    color: statusColor
    border.color: Qt.lighter(statusColor, 1.35)
    ToolTip.visible: mouse.containsMouse && !!errorText
    ToolTip.text: errorText
    MouseArea { id: mouse; anchors.fill: parent; hoverEnabled: true }
}
