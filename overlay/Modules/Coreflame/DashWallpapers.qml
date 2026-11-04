import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell.Widgets
import qs.Common
import qs.Widgets
import Qt.labs.folderlistmodel

// "Worldbearing · Wallpapers": the current wallpaper's folder, twelve to a page; the wheel or the
// arrows turn pages, a click sets the wallpaper.
//   Phainon: rounded thumbnails on a parchment card, the current one ringed in lapis.
//   Khaslana: square slabs on a red offset, the current one edged in gold.
//   Flame Reaver: thumbnails cut as shards and greyed, the current one in colour with a violet edge.
DashSheet {
    id: walls

    readonly property string current: SessionData.wallpaperPath
    readonly property string folder: current.substring(0, current.lastIndexOf("/"))
    readonly property int perPage: 12
    readonly property int pages: Math.max(1, Math.ceil(files.count / perPage))
    property int page: 0
    readonly property int rows: Math.max(1, Math.min(3, Math.ceil(files.count / 4)))
    readonly property real gridHeight: rows * 100 + (rows - 1) * 10

    function turn(by) {
        page = Math.max(0, Math.min(pages - 1, page + by));
    }

    // the pager's ‹ and ›, faint at either end
    component Arrow: Text {
        id: arrow
        property bool on: false
        property int by: 0
        anchors.verticalCenter: parent.verticalCenter
        font.family: Form.reaver ? "Chakra Petch" : "Cinzel"
        font.pixelSize: Form.reaver ? 16 : 22
        color: Form.phainon ? "#334786" : (Form.khaslana ? "#F5D27A" : "#B9A8FF")
        opacity: on ? 1 : 0.25

        MouseArea {
            anchors.fill: parent
            anchors.margins: -6
            cursorShape: arrow.on ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: walls.turn(arrow.by)
        }
    }

    title: "Worldbearing · Wallpapers"
    glyph: "worldbearing"
    // the grid, the card's padding and the pager under it
    bodyHeight: gridHeight + (Form.reaver ? 76 : 68)
    blocks: Form.khaslana ? [[0, 0, bodyWidth, bodyHeight, false]] : []

    CfInk {
        id: ink
    }

    FolderListModel {
        id: files
        folder: walls.folder !== "" ? "file://" + walls.folder : ""
        nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.webp"]
        showDirs: false
        sortField: FolderListModel.Name
        onStatusChanged: {
            if (status !== FolderListModel.Ready)
                return;
            const at = indexOf("file://" + walls.current);
            if (at >= 0)
                walls.page = Math.floor(at / walls.perPage);
        }
    }

    DashCard {
        width: walls.bodyWidth
        height: walls.bodyHeight
        flute: false
        bare: Form.khaslana
        poly: [[0.02, 0.04], [1, 0], [0.97, 0.96], [0, 1]]

        Column {
            width: parent.width
            spacing: 12

            Grid {
                id: wallGrid
                readonly property real cellWidth: Math.floor((width - 3 * 10) / 4)
                width: parent.width
                height: walls.gridHeight
                columns: 4
                spacing: 10

                Repeater {
                    model: Math.max(0, Math.min(walls.perPage, files.count - walls.page * walls.perPage))

                    Item {
                        id: thumb
                        required property int index
                        readonly property int at: walls.page * walls.perPage + index
                        readonly property string path: files.get(at, "filePath") ?? ""
                        readonly property bool current: path === walls.current
                        readonly property bool lit: current || thumbMouse.containsMouse
                        width: wallGrid.cellWidth
                        height: 100

                        // Khaslana: square slabs on a hard red offset, deeper red under the current one
                        Rectangle {
                            visible: Form.khaslana
                            x: thumb.current ? 5 : 4
                            y: thumb.current ? 4 : 3
                            width: parent.width
                            height: parent.height
                            color: thumb.current ? "#8E1424" : "#3A0A12"
                        }

                        ClippingRectangle {
                            anchors.fill: parent
                            radius: Form.phainon ? 14 : 0
                            color: thumb.shard ? "transparent" : (Form.phainon ? "#EFE6CC" : "#140C0F")

                            Image {
                                id: picture
                                anchors.fill: parent
                                // The Flame Reaver draws it through his shard below instead
                                visible: !thumb.shard
                                source: files.get(thumb.at, "fileUrl") ?? ""
                                sourceSize: Qt.size(360, 200)
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                            }
                        }

                        // Flame Reaver: each thumbnail torn as a shard and greyed, the current one in
                        // full colour. Only while this view is open, so the layers come and go with it.
                        readonly property bool shard: Form.reaver
                        readonly property var outline: [Qt.point(width * 0.03, 0), Qt.point(width, height * 0.04), Qt.point(width * 0.97, height), Qt.point(0, height * 0.92), Qt.point(width * 0.03, 0)]

                        Shape {
                            id: shardMask
                            visible: false
                            anchors.fill: parent
                            layer.enabled: thumb.shard
                            preferredRendererType: Shape.CurveRenderer

                            ShapePath {
                                fillColor: "white"
                                strokeColor: "transparent"
                                PathPolyline {
                                    path: thumb.shard ? thumb.outline : []
                                }
                            }
                        }

                        MultiEffect {
                            visible: thumb.shard
                            anchors.fill: parent
                            source: thumb.shard ? picture : null
                            saturation: thumb.current ? 0 : -0.4
                            brightness: thumb.lit ? 0 : -0.15
                            maskEnabled: true
                            maskSource: shardMask
                        }

                        // the Reaver's violet edge down the left and along the bottom
                        Shape {
                            visible: thumb.shard && thumb.lit
                            anchors.fill: parent
                            preferredRendererType: Shape.CurveRenderer

                            ShapePath {
                                fillColor: "transparent"
                                strokeColor: thumb.current ? "#8F7BE0" : "#808F7BE0"
                                strokeWidth: 3
                                joinStyle: ShapePath.MiterJoin
                                PathPolyline {
                                    path: thumb.shard ? [thumb.outline[0], thumb.outline[3], thumb.outline[2]] : []
                                }
                            }
                        }

                        // Phainon's lapis ring, Khaslana's gold edge
                        Rectangle {
                            anchors.fill: parent
                            visible: !Form.reaver && thumb.lit
                            radius: Form.phainon ? 14 : 0
                            color: "transparent"
                            border.width: thumb.current ? 3 : (Form.phainon ? 2 : 1)
                            border.color: Form.phainon ? (thumb.current ? "#334786" : "#80334786") : (thumb.current ? "#F2C75C" : "#8A5A2B")
                        }

                        MouseArea {
                            id: thumbMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: SessionData.setWallpaper(thumb.path)
                            onWheel: wheel => walls.turn(wheel.angleDelta.y > 0 ? -1 : 1)
                        }
                    }
                }
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                height: 30
                spacing: 16

                Arrow {
                    text: Form.reaver ? "<" : "‹"
                    on: walls.page > 0
                    by: -1
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: ink.tx((walls.page + 1) + " / " + walls.pages + "  ·  " + files.count + " wallpapers")
                    font.family: Form.khaslana ? "Cinzel" : ink.font
                    font.pixelSize: Form.khaslana ? 12 : 14
                    font.weight: Form.khaslana ? Font.DemiBold : Font.Normal
                    font.letterSpacing: Form.khaslana ? 2.6 : 0
                    font.capitalization: Form.khaslana ? Font.AllUppercase : Font.MixedCase
                    color: Form.khaslana ? "#E0B04A" : ink.muted
                }

                Arrow {
                    text: Form.reaver ? ">" : "›"
                    on: walls.page < walls.pages - 1
                    by: 1
                }
            }
        }
    }
}
