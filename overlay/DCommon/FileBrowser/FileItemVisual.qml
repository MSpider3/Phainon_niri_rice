pragma ComponentBehavior: Bound

import QtQuick
import qs.DCommon.Common
import qs.DCommon.Widgets
import qs.Common as Shell
import qs.Widgets as Cf

Item {
    id: root

    property string iconName: ""
    property string thumbnail: ""
    property string path: ""
    property string mime: ""
    property bool isDir: false
    property bool isSymlink: false
    property bool symlinkBroken: false
    property bool untrusted: false
    property bool unreadable: false
    property bool hidden: false
    property bool cut: false
    property bool selected: false
    property int iconSize: Style.iconSize
    property color tint: Style.surfaceText

    readonly property real emblemSize: Math.max(FileBrowserMetrics.emblemMinSize, iconSize * FileBrowserMetrics.emblemRatio)
    readonly property string imageSource: root.thumbnail !== "" ? root.thumbnail : root.mime === "image/svg+xml" ? root.path : ""
    // Coreflame: folders and pictures drawn per form (see cfFolder / cfPicture); other files keep their icons
    readonly property string cfLook: !Shell.Form.active ? "" : imageSource !== "" ? "picture" : isDir ? "folder" : ""

    implicitWidth: iconSize
    implicitHeight: iconSize
    opacity: cut ? Style.pendingOpacity : hidden ? FileBrowserMetrics.hiddenOpacity : 1

    FileIcon {
        anchors.fill: parent
        visible: root.cfLook === ""
        iconName: root.iconName
        thumbnail: root.cfLook === "" ? root.imageSource : ""
        size: root.iconSize
        color: root.isDir && !root.selected ? Style.primary : root.tint
    }

    Loader {
        anchors.fill: parent
        active: root.cfLook !== ""
        sourceComponent: root.cfLook === "folder" ? cfFolder : cfPicture
    }

    // Phainon a parchment folder with a gold rim, rounder at the bottom; Khaslana a black folder
    // with a gold edge and the red offset; the Flame Reaver a violet-grey torn shard.
    Component {
        id: cfFolder

        Item {
            readonly property real s: root.iconSize / 60

            Rectangle {
                visible: Shell.Form.khaslana
                x: 3 * parent.s
                y: folder.y + 3 * parent.s
                width: folder.width
                height: folder.height
                color: "#8E1424"
            }

            Rectangle {
                id: folder
                visible: !Shell.Form.reaver
                width: parent.width
                height: parent.height * 46 / 60
                anchors.verticalCenter: parent.verticalCenter
                topLeftRadius: Shell.Form.phainon ? 6 * parent.s : 0
                topRightRadius: topLeftRadius
                bottomLeftRadius: Shell.Form.phainon ? 12 * parent.s : 0
                bottomRightRadius: bottomLeftRadius
                color: "#1A0F12"
                gradient: Shell.Form.phainon ? phFolderFill : null
                border.width: 1
                border.color: Shell.Form.khaslana ? "#E0B04A" : "#A87A22"
            }

            Gradient {
                id: phFolderFill
                GradientStop {
                    position: 0
                    color: "#EBDDB0"
                }
                GradientStop {
                    position: 1
                    color: "#D6BD78"
                }
            }

            Cf.CfQuad {
                visible: Shell.Form.reaver
                anchors.fill: folder
                points: [[0, 0.12], [0.4, 0], [1, 0.08], [0.96, 1], [0.04, 0.94]]
                fill: "#5C5478"
            }
        }
    }

    // Phainon a cream mat in a gold line; Khaslana a gold edge with the red offset; the Flame
    // Reaver bare and dimmed until picked.
    Component {
        id: cfPicture

        Item {
            readonly property real mat: Shell.Form.phainon ? 4 : Shell.Form.khaslana ? 1 : 0
            readonly property real pw: picture.paintedWidth + mat * 2
            readonly property real ph: picture.paintedHeight + mat * 2

            Rectangle {
                visible: Shell.Form.khaslana && picture.status === Image.Ready
                x: (parent.width - parent.pw) / 2 + 3
                y: (parent.height - parent.ph) / 2 + 3
                width: parent.pw
                height: parent.ph
                color: "#8E1424"
            }

            Rectangle {
                visible: !Shell.Form.reaver && picture.status === Image.Ready
                anchors.centerIn: parent
                width: parent.pw
                height: parent.ph
                radius: Shell.Form.phainon ? 10 : 0
                color: Shell.Form.phainon ? "#FBF9F3" : "#0B080B"
                border.width: 1
                border.color: Shell.Form.phainon ? "#A87A22" : "#E0B04A"
            }

            Image {
                id: picture
                anchors.fill: parent
                anchors.margins: parent.mat + (Shell.Form.khaslana ? 3 : 0)
                source: FilePaths.toFileUrl(root.imageSource)
                sourceSize.width: Style.iconRasterSize(root.iconSize * (Window.window?.devicePixelRatio ?? 1))
                sourceSize.height: sourceSize.width
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                cache: true
                smooth: true
                opacity: Shell.Form.reaver && !root.selected ? 0.6 : 1
            }
        }
    }

    component Emblem: Rectangle {
        property alias iconName: badge.name
        property alias iconColor: badge.color

        width: root.emblemSize
        height: root.emblemSize
        radius: Style.fullRadius(width, height)
        color: Style.surfaceContainerLowest

        DIcon {
            id: badge

            anchors.centerIn: parent
            size: parent.width - Style.spacingXS
        }
    }

    Loader {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        active: root.isSymlink
        sourceComponent: Emblem {
            iconName: root.symlinkBroken ? "link_off" : "link"
            iconColor: root.symlinkBroken ? Style.error : Style.surfaceVariantText
        }
    }

    Loader {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        active: root.untrusted || root.unreadable
        sourceComponent: Emblem {
            iconName: root.unreadable ? "lock" : "warning"
            iconColor: Style.error
        }
    }
}
