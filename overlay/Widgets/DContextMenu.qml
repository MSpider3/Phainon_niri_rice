pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Services
import qs.DCommon.Widgets
import qs.Widgets

Item {
    id: root

    visible: false
    width: 0
    height: 0

    property var menuItems: []
    property Component customContent: null
    property real customContentWidth: 0
    property string layerNamespace: "dms:context-menu"
    property real menuMargin: Theme.spacingS
    property real minMenuWidth: Theme.fieldDefaultWidth
    property real itemHeight: Theme.menuItemHeight
    property real itemFontSize: Theme.fontSizeSmall
    property bool keyboardNavigable: false
    property var transientSurfaceTracker: null
    property var targetScreen: null
    property real anchorX: 0
    property real anchorY: 0
    property real originX: 0
    property real originY: 0
    property string menuEdge: "top"
    property bool openState: false
    property bool renderActive: false
    property int selectedMenuIndex: -1
    property bool keyboardNavigation: false
    readonly property alias contextWindow: menuWindow
    readonly property alias customContentItem: customContentLoader.item
    // Coreflame: the form's own menu plate replaces the stock card; its shape is not a rounded rect, so no blur under it.
    readonly property bool cfPlate: Form.active
    readonly property bool blurActive: renderActive && openState && BlurService.enabled && !cfPlate
    // Coreflame: an optional title row over the items (the app or window the menu is about).
    property string headerText: ""
    readonly property real headerHeight: cfPlate && headerText !== "" ? 26 + Theme.groupedListGap : 0

    readonly property real maxMenuWidth: Math.max(0, (targetScreen?.width ?? Theme.launcherWidthMicro) - menuMargin * 2)
    readonly property real maxMenuHeight: Math.max(0, (targetScreen?.height ?? Theme.launcherHeightDefault) - menuMargin * 2)
    readonly property string longestMenuText: {
        let longest = "";
        for (const menuItem of menuItems) {
            const text = menuItem.text || "";
            if (text.length > longest.length)
                longest = text;
        }
        return longest;
    }
    readonly property bool hasTrailingIcons: menuItems.some(menuItem => !!menuItem.trailingIcon)
    readonly property real naturalMenuWidth: customContent ? Math.max(minMenuWidth, customContentWidth) : Math.max(minMenuWidth, menuTextMetrics.width + Theme.iconSize + Theme.spacingS * 5 + (hasTrailingIcons ? Theme.iconSizeMedium + Theme.spacingS : 0))
    readonly property real effectiveMenuWidth: Math.max(0, Math.min(maxMenuWidth, naturalMenuWidth))
    readonly property real naturalMenuHeight: headerHeight + (customContent ? customContentLoader.implicitHeight : menuItemsHeight()) + Theme.spacingS * 2
    readonly property real effectiveMenuHeight: Math.min(maxMenuHeight, naturalMenuHeight)
    readonly property bool menuScrolls: naturalMenuHeight > effectiveMenuHeight + 0.5
    readonly property int visibleItemCount: menuItems.filter(menuItem => isSelectable(menuItem)).length

    signal backdropRightClicked(real x, real y)

    onRenderActiveChanged: transientSurfaceTracker?.setActive(root, renderActive, contextWindow)
    Component.onDestruction: transientSurfaceTracker?.unregister(root)

    Connections {
        target: root.transientSurfaceTracker
        ignoreUnknownSignals: true

        function onCloseRequested() {
            root.hide();
        }
    }

    StyledTextMetrics {
        id: menuTextMetrics
        text: root.longestMenuText
        font.pixelSize: root.itemFontSize
    }

    function menuItemsHeight() {
        const shown = menuItems.filter(menuItem => !menuItem.hidden);
        let h = 0;
        for (const menuItem of shown)
            h += itemHeightFor(menuItem);
        if (shown.length > 1)
            h += (shown.length - 1) * Theme.groupedListGap;
        return h;
    }

    function isSelectable(menuItem) {
        return menuItem.type === "item" && !menuItem.hidden;
    }

    function itemHeightFor(menuItem) {
        if (menuItem.hidden)
            return 0;
        switch (menuItem.type) {
        case "separator":
            return Theme.spacingXS + Theme.dividerWidth;
        case "component":
            return menuItem.height ?? 0;
        default:
            return itemHeight;
        }
    }

    function open(screen, x, y, fromKeyboard) {
        targetScreen = screen;
        anchorX = x;
        anchorY = y;
        originX = x;
        originY = y;
        selectedMenuIndex = fromKeyboard ? 0 : -1;
        keyboardNavigation = !!fromKeyboard;
        renderActive = true;
        openState = true;
        Qt.callLater(() => {
            menuFlickable.contentY = 0;
            if (keyboardNavigable)
                keyboardHandler.forceActiveFocus();
            ensureSelectedVisible();
        });
    }

    function openFromBar(anchor) {
        if (!anchor?.screen)
            return;
        targetScreen = anchor.screen;
        let x = anchor.x - effectiveMenuWidth / 2;
        let y = anchor.edge === "bottom" ? anchor.y - effectiveMenuHeight : anchor.y;
        if (anchor.isVertical) {
            x = anchor.edge === "left" ? anchor.x : anchor.x - effectiveMenuWidth;
            y = anchor.y - effectiveMenuHeight / 2;
        }
        open(anchor.screen, x, y, false);
        originX = anchor.x;
        originY = anchor.y;
    }

    function hide() {
        if (!renderActive)
            return;
        openState = false;
        // The fullscreen window grabs input until renderActive drops; never leave that to an animation that may not run.
        if (!closeFade.running)
            renderActive = false;
    }

    function activate(menuItem) {
        if (menuItem?.enabled === false)
            return;
        if (typeof menuItem?.action === "function")
            menuItem.action();
        if (!menuItem.keepOpen)
            hide();
    }

    function selectNext() {
        if (visibleItemCount === 0)
            return;
        keyboardNavigation = true;
        for (let step = 0; step < visibleItemCount; step++) {
            selectedMenuIndex = (selectedMenuIndex + 1) % visibleItemCount;
            if (menuItems[selectedDelegateIndex()]?.enabled !== false)
                break;
        }
        ensureSelectedVisible();
    }

    function selectPrevious() {
        if (visibleItemCount === 0)
            return;
        keyboardNavigation = true;
        for (let step = 0; step < visibleItemCount; step++) {
            selectedMenuIndex = (selectedMenuIndex - 1 + visibleItemCount) % visibleItemCount;
            if (menuItems[selectedDelegateIndex()]?.enabled !== false)
                break;
        }
        ensureSelectedVisible();
    }

    function selectedDelegateIndex() {
        let itemIndex = 0;
        for (let i = 0; i < menuItems.length; i++) {
            if (!isSelectable(menuItems[i]))
                continue;
            if (itemIndex === selectedMenuIndex)
                return i;
            itemIndex++;
        }
        return -1;
    }

    function ensureSelectedVisible() {
        Qt.callLater(() => {
            const delegate = menuRepeater.itemAt(selectedDelegateIndex());
            if (!delegate)
                return;
            const top = delegate.y;
            const bottom = top + delegate.height;
            const viewTop = menuFlickable.contentY;
            const viewBottom = viewTop + menuFlickable.height;
            if (top < viewTop) {
                menuFlickable.contentY = Math.max(0, top);
                return;
            }
            if (bottom > viewBottom)
                menuFlickable.contentY = Math.min(Math.max(0, menuFlickable.contentHeight - menuFlickable.height), bottom - menuFlickable.height);
        });
    }

    function activateSelected() {
        const index = selectedDelegateIndex();
        if (index >= 0)
            activate(menuItems[index]);
    }

    PanelWindow {
        id: menuWindow

        screen: root.targetScreen
        visible: root.renderActive
        color: "transparent"

        WlrLayershell.namespace: root.layerNamespace
        WlrLayershell.layer: WlrLayershell.Overlay
        WlrLayershell.exclusiveZone: -1

        WlrLayershell.keyboardFocus: {
            if (!root.keyboardNavigable || !root.renderActive)
                return WlrKeyboardFocus.None;
            if (PopoutManager.screenshotActive || CompositorService.useHyprlandFocusGrab)
                return WlrKeyboardFocus.None;
            return WlrKeyboardFocus.Exclusive;
        }

        anchors {
            top: true
            left: true
            right: true
            bottom: true
        }

        WindowBlur {
            targetWindow: menuWindow
            surfaceColor: menuContainer.color
            blurX: root.blurActive ? menuContainer.x + openScaleTransform.origin.x * (1 - menuContainer.openScale) : 0
            blurY: root.blurActive ? menuContainer.y + openScaleTransform.origin.y * (1 - menuContainer.openScale) : 0
            blurWidth: root.blurActive ? menuContainer.width * menuContainer.openScale : 0
            blurHeight: root.blurActive ? menuContainer.height * menuContainer.openScale : 0
            blurRadius: Theme.windowRadius * menuContainer.openScale
        }

        MouseArea {
            anchors.fill: parent
            z: -1
            enabled: root.renderActive
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: mouse => {
                if (mouse.button === Qt.RightButton) {
                    root.backdropRightClicked(mouse.x, mouse.y);
                    return;
                }
                root.hide();
            }
        }

        Item {
            id: keyboardHandler
            anchors.fill: parent
            focus: root.keyboardNavigable && root.openState

            Keys.onPressed: event => {
                switch (event.key) {
                case Qt.Key_Down:
                    root.selectNext();
                    event.accepted = true;
                    return;
                case Qt.Key_Up:
                    root.selectPrevious();
                    event.accepted = true;
                    return;
                case Qt.Key_Return:
                case Qt.Key_Enter:
                    root.activateSelected();
                    event.accepted = true;
                    return;
                case Qt.Key_Escape:
                case Qt.Key_Left:
                    root.hide();
                    event.accepted = true;
                    return;
                }
            }

            Rectangle {
                id: menuContainer
                x: {
                    if (root.menuEdge === "right")
                        return Math.max(root.menuMargin, Math.min(menuWindow.width - width - root.menuMargin, root.anchorX - width));
                    return Math.max(root.menuMargin, Math.min(menuWindow.width - width - root.menuMargin, root.anchorX));
                }
                y: {
                    if (root.menuEdge === "bottom")
                        return Math.max(root.menuMargin, Math.min(menuWindow.height - height - root.menuMargin, root.anchorY - height));
                    if (root.menuEdge === "left" || root.menuEdge === "right")
                        return Math.max(root.menuMargin, Math.min(menuWindow.height - height - root.menuMargin, root.anchorY - height / 2));
                    return Math.max(root.menuMargin, Math.min(menuWindow.height - height - root.menuMargin, root.anchorY));
                }
                width: root.effectiveMenuWidth
                height: root.effectiveMenuHeight
                color: root.cfPlate ? "transparent" : Theme.readableSurface
                radius: Theme.windowRadius
                border.color: BlurService.borderColor
                border.width: root.cfPlate ? 0 : BlurService.borderWidth
                opacity: root.openState ? 1 : 0
                transform: Scale {
                    id: openScaleTransform
                    origin.x: root.originX - menuContainer.x
                    origin.y: root.originY - menuContainer.y
                    xScale: menuContainer.openScale
                    yScale: menuContainer.openScale
                }

                property real openScale: root.openState ? 1 : Theme.effectScaleCollapsed

                Behavior on openScale {
                    NumberAnimation {
                        duration: SettingsData.reduceMotion ? 0 : Theme.expressiveDurations.expressiveFastSpatial
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Theme.expressiveCurves.expressiveDefaultSpatial
                    }
                }

                Behavior on height {
                    enabled: root.openState
                    NumberAnimation {
                        duration: SettingsData.reduceMotion ? 0 : Theme.expressiveDurations.expressiveFastSpatial
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Theme.expressiveCurves.emphasizedDecel
                    }
                }

                // Fade out only; a fade-in shows the blur through an empty card.
                Behavior on opacity {
                    enabled: menuContainer.opacity > 0
                    NumberAnimation {
                        id: closeFade
                        duration: SettingsData.reduceMotion ? 0 : Theme.shortDuration
                        easing.type: Theme.emphasizedEasing
                        onRunningChanged: {
                            if (!running && !root.openState)
                                root.renderActive = false;
                        }
                    }
                }

                ElevationShadow {
                    anchors.fill: parent
                    z: -1
                    visible: !root.cfPlate
                    level: Theme.elevationLevel2
                    targetRadius: parent.radius
                    targetColor: "transparent"
                    shadowEnabled: Theme.elevationEnabled
                }

                Loader {
                    anchors.fill: parent
                    z: -1
                    active: root.cfPlate
                    sourceComponent: CfMenuPlate {}
                }

                CfInk {
                    id: ink
                }

                DFlickable {
                    id: menuFlickable
                    anchors.fill: parent
                    anchors.margins: Theme.spacingS
                    clip: true
                    contentWidth: width
                    contentHeight: menuColumn.implicitHeight
                    boundsBehavior: Flickable.StopAtBounds
                    interactive: root.menuScrolls

                    Column {
                        id: menuColumn
                        width: menuFlickable.width
                        spacing: Theme.groupedListGap

                        StyledText {
                            visible: root.headerHeight > 0
                            width: menuColumn.width
                            height: 26
                            leftPadding: 12
                            rightPadding: 12
                            verticalAlignment: Text.AlignVCenter
                            text: ink.header(root.headerText)
                            color: ink.head
                            font.family: ink.headFont
                            font.pixelSize: ink.headSize
                            font.weight: Font.DemiBold
                            font.letterSpacing: ink.headSpacing
                            elide: Text.ElideRight
                        }

                        Loader {
                            id: customContentLoader
                            width: menuColumn.width
                            active: root.customContent !== null
                            visible: active
                            sourceComponent: root.customContent
                        }

                        Repeater {
                            id: menuRepeater
                            model: root.customContent ? [] : root.menuItems

                            Item {
                                id: menuItemDelegate
                                required property var modelData
                                required property int index

                                readonly property bool isSeparator: modelData.type === "separator"
                                readonly property bool isComponent: modelData.type === "component"
                                readonly property int itemIndex: root.menuItems.slice(0, index).filter(menuItem => root.isSelectable(menuItem)).length

                                width: menuColumn.width
                                height: root.itemHeightFor(modelData)
                                visible: !modelData.hidden

                                Loader {
                                    anchors.fill: parent
                                    active: menuItemDelegate.isComponent && root.renderActive
                                    sourceComponent: menuItemDelegate.modelData.component ?? null
                                }

                                Rectangle {
                                    visible: menuItemDelegate.isSeparator
                                    width: parent.width - (root.cfPlate ? 16 : Theme.spacingS * 2)
                                    height: root.cfPlate ? 1 : Theme.outlineWidth
                                    anchors.centerIn: parent
                                    color: root.cfPlate ? ink.rule : Theme.outlineHeavy
                                }

                                Rectangle {
                                    id: menuRow
                                    readonly property bool selected: root.keyboardNavigation && root.selectedMenuIndex === menuItemDelegate.itemIndex
                                    readonly property bool destructive: menuItemDelegate.modelData?.isDestructive ?? false
                                    readonly property bool itemEnabled: menuItemDelegate.modelData?.enabled !== false
                                    readonly property bool lit: itemEnabled && (selected || itemMouseArea.containsMouse)
                                    readonly property color contentColor: {
                                        if (!itemEnabled)
                                            return root.cfPlate ? Theme.withAlpha(ink.muted, 0.5) : Theme.onSurface_38;
                                        if (destructive)
                                            return root.cfPlate ? ink.danger : Theme.error;
                                        if (root.cfPlate)
                                            return lit ? ink.selText : ink.text;
                                        return selected ? Theme.onSelectedContainer : Theme.onSurface;
                                    }
                                    readonly property color iconColor: !root.cfPlate || !itemEnabled || destructive ? contentColor : (lit ? ink.selIcon : ink.icon)
                                    visible: !menuItemDelegate.isSeparator && !menuItemDelegate.isComponent
                                    anchors.fill: parent
                                    radius: root.cfPlate ? (Form.phainon ? height / 2 : 0) : Theme.cornerRadiusS
                                    color: {
                                        if (root.cfPlate)
                                            return "transparent";
                                        if (!itemEnabled)
                                            return "transparent";
                                        if (destructive)
                                            return selected ? Theme.errorSelected : itemMouseArea.containsMouse ? Theme.errorHover : "transparent";
                                        return selected ? Theme.selectedContainer : itemMouseArea.pressed ? Theme.withAlpha(Theme.onSurface, Theme.stateLayerPressed) : itemMouseArea.containsMouse ? Theme.withAlpha(Theme.onSurface, Theme.stateLayerHover) : "transparent";
                                    }

                                    CfPick {
                                        anchors.fill: parent
                                        visible: root.cfPlate && menuRow.lit
                                    }

                                    Row {
                                        anchors.left: parent.left
                                        anchors.leftMargin: Theme.spacingS
                                        anchors.right: parent.right
                                        anchors.rightMargin: Theme.spacingS
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: Theme.spacingS

                                        DIcon {
                                            name: menuItemDelegate.modelData?.icon ?? ""
                                            size: Theme.iconSizeMedium
                                            color: menuRow.iconColor
                                            anchors.verticalCenter: parent.verticalCenter
                                        }

                                        StyledText {
                                            text: root.cfPlate ? ink.tx(menuItemDelegate.modelData.text || "") : (menuItemDelegate.modelData.text || "")
                                            font.pixelSize: root.cfPlate ? 14 : root.itemFontSize
                                            font.family: root.cfPlate ? ink.font : resolvedFontFamily
                                            color: menuRow.contentColor
                                            font.weight: root.cfPlate && Form.reaver ? Font.Medium : Theme.fontWeight
                                            anchors.verticalCenter: parent.verticalCenter
                                            elide: Text.ElideRight
                                            width: parent.width - (Theme.iconSizeMedium + Theme.spacingS) * (trailingIcon.visible ? 2 : 1)
                                        }
                                    }

                                    DIcon {
                                        id: trailingIcon
                                        visible: name !== ""
                                        name: menuItemDelegate.modelData?.trailingIcon ?? ""
                                        size: Theme.iconSizeMedium
                                        color: menuRow.iconColor
                                        anchors.right: parent.right
                                        anchors.rightMargin: Theme.spacingS
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    DRipple {
                                        id: menuItemRipple
                                        rippleColor: menuRow.contentColor
                                        cornerRadius: menuRow.radius
                                    }

                                    MouseArea {
                                        id: itemMouseArea
                                        anchors.fill: parent
                                        enabled: menuRow.itemEnabled
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onEntered: {
                                            root.keyboardNavigation = false;
                                            root.selectedMenuIndex = menuItemDelegate.itemIndex;
                                        }
                                        onPressed: mouse => menuItemRipple.trigger(mouse.x, mouse.y)
                                        onClicked: root.activate(menuItemDelegate.modelData)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
