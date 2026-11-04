import QtQuick
import qs.Common
import qs.DCommon.Widgets
import qs.Widgets

Rectangle {
    id: root

    property string iconName: ""
    property string title: ""
    property string hint: ""
    property string accent: ""
    property bool active: false
    property bool highlighted: false
    // Coreflame: Khaslana numbers the pages in Roman numerals
    property string numeral: ""
    property bool showHint: true
    readonly property bool cf: Form.active
    readonly property color cfIconColor: Form.phainon ? "#334786" : (Form.khaslana ? (active ? "#F5D27A" : "#E0B04A") : (active ? "#B9A8FF" : "#6E6A84"))

    signal clicked(bool keyboard)

    activeFocusOnTab: enabled
    Accessible.role: Accessible.Button
    Accessible.name: title
    Accessible.description: hint
    Accessible.onPressAction: clicked(true)

    Keys.onPressed: event => {
        switch (event.key) {
        case Qt.Key_Space:
        case Qt.Key_Return:
        case Qt.Key_Enter:
            root.clicked(true);
            event.accepted = true;
            break;
        }
    }

    readonly property var accentPair: Theme.accent(accent)
    readonly property color badgeColor: accentPair?.container ?? Theme.withAlpha(Theme.primary, Theme.tonalTintAlpha)
    readonly property color glyphColor: accentPair?.onContainer ?? Theme.primary
    property bool isFirstInGroup: true
    property bool isLastInGroup: true
    property real topRadius: cf ? (Form.phainon ? height / 2 : 0) : active || isFirstInGroup ? Theme.groupedListOuterRadius : Theme.groupedListInnerRadius
    property real bottomRadius: cf ? topRadius : active || isLastInGroup ? Theme.groupedListOuterRadius : Theme.groupedListInnerRadius

    Behavior on topRadius {
        enabled: Theme.currentAnimationSpeed !== SettingsData.AnimationSpeed.None
        NumberAnimation {
            duration: Theme.expressiveDurations.expressiveFastSpatial
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.expressiveCurves.expressiveFastSpatial
        }
    }

    Behavior on bottomRadius {
        enabled: Theme.currentAnimationSpeed !== SettingsData.AnimationSpeed.None
        NumberAnimation {
            duration: Theme.expressiveDurations.expressiveFastSpatial
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.expressiveCurves.expressiveFastSpatial
        }
    }

    width: parent?.width ?? 0
    height: cf ? textColumn.implicitHeight + (Form.reaver ? 8 : 12) : Math.max(SettingsMetrics.navItemMinHeight, textColumn.implicitHeight + Theme.spacingS * 2)
    topLeftRadius: topRadius
    topRightRadius: topRadius
    bottomLeftRadius: bottomRadius
    bottomRightRadius: bottomRadius
    color: cf ? (active && Form.reaver ? "#2E2650" : "transparent") : active ? SettingsMetrics.selectedRowColor : SettingsMetrics.sidebarRowColor
    border.width: cf ? (active && !Form.khaslana ? 1 : 0) : Theme.layerOutlineWidth
    border.color: cf ? (Form.phainon ? "#A87A22" : "#B9A8FF") : Theme.outlineMedium

    Behavior on color {
        enabled: Theme.currentAnimationSpeed !== SettingsData.AnimationSpeed.None
        ColorAnimation {
            duration: SettingsMetrics.fadeDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.expressiveCurves.expressiveEffects
        }
    }

    Rectangle {
        visible: root.cf && root.active && !Form.reaver
        anchors.fill: parent
        anchors.margins: root.border.width
        radius: Math.max(0, root.topRadius - root.border.width)
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop {
                position: 0
                color: Form.phainon ? Qt.rgba(241 / 255, 218 / 255, 79 / 255, 0.45) : "#8E1424"
            }
            GradientStop {
                position: Form.phainon ? 1 : 0.75
                color: Form.phainon ? Qt.rgba(241 / 255, 218 / 255, 79 / 255, 0.1) : "#3A0A12"
            }
        }

        Rectangle {
            visible: Form.khaslana
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 3
            color: "#F2C75C"
        }
    }

    Rectangle {
        anchors.fill: parent
        topLeftRadius: root.topRadius
        topRightRadius: root.topRadius
        bottomLeftRadius: root.bottomRadius
        bottomRightRadius: root.bottomRadius
        color: Theme.surfaceText
        opacity: mouseArea.pressed ? Theme.stateLayerPressed : focusRing.visible ? Theme.stateLayerFocus : (mouseArea.containsMouse || root.highlighted ? Theme.stateLayerHover : 0)

        Behavior on opacity {
            enabled: Theme.currentAnimationSpeed !== SettingsData.AnimationSpeed.None
            NumberAnimation {
                duration: SettingsMetrics.fadeDuration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.expressiveCurves.expressiveEffects
            }
        }
    }

    DRipple {
        id: ripple
        rippleColor: Theme.surfaceText
        topLeftRadius: root.topRadius
        topRightRadius: root.topRadius
        bottomLeftRadius: root.bottomRadius
        bottomRightRadius: root.bottomRadius
    }

    StyledText {
        id: numeralText
        visible: root.cf && Form.khaslana && root.numeral !== ""
        width: visible ? 30 : 0
        anchors.left: parent.left
        anchors.leftMargin: visible ? Theme.spacingS : 0
        anchors.verticalCenter: parent.verticalCenter
        horizontalAlignment: Text.AlignRight
        text: root.numeral
        font.family: "Cinzel"
        font.pixelSize: 11
        font.weight: Font.DemiBold
        color: root.active ? "#F5D27A" : "#B0824A"
    }

    Rectangle {
        id: iconCircle
        width: root.cf ? 17 : SettingsMetrics.navIconSize
        height: width
        radius: Theme.fullRadius(width, height)
        anchors.left: numeralText.visible ? numeralText.right : parent.left
        anchors.leftMargin: !root.cf ? Theme.spacingL : (numeralText.visible ? 10 : (Form.reaver ? 8 : 12))
        anchors.verticalCenter: parent.verticalCenter
        color: root.cf ? "transparent" : root.badgeColor

        Behavior on color {
            enabled: Theme.currentAnimationSpeed !== SettingsData.AnimationSpeed.None
            ColorAnimation {
                duration: SettingsMetrics.fadeDuration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.expressiveCurves.expressiveEffects
            }
        }

        DIcon {
            anchors.centerIn: parent
            name: root.iconName
            size: root.cf ? 17 : Theme.iconSizeMedium
            color: root.cf ? root.cfIconColor : root.glyphColor
            filled: root.active
        }
    }

    Column {
        id: textColumn
        anchors.left: iconCircle.right
        anchors.leftMargin: root.cf ? 10 : Theme.spacingM
        anchors.right: parent.right
        anchors.rightMargin: root.cf ? 12 : Theme.spacingL
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.spacingXXS

        StyledText {
            width: parent.width
            text: root.title
            font.pixelSize: root.cf ? 15 : Theme.fontSizeMedium
            font.weight: Theme.fontWeightMedium
            font.capitalization: root.cf && Form.reaver ? Font.AllLowercase : Font.MixedCase
            color: !root.cf ? (root.active ? Theme.onSelectedContainer : Theme.surfaceText) : (Form.phainon ? "#1E2752" : (Form.khaslana ? (root.active ? "#F5D27A" : "#F3E6CC") : "#E9E7F2"))
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignLeft
        }

        StyledText {
            width: parent.width
            text: root.hint
            font.pixelSize: Theme.fontSizeSmall
            font.capitalization: root.cf && Form.reaver ? Font.AllLowercase : Font.MixedCase
            color: !root.cf ? (root.active ? Theme.onSelectedContainer : Theme.surfaceVariantText) : (Form.phainon ? "#4A5484" : (Form.khaslana ? "#C9B89E" : "#A8A4BC"))
            wrapMode: Text.WordWrap
            visible: root.hint !== "" && root.showHint
            horizontalAlignment: Text.AlignLeft
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onPressed: mouse => {
            focusRing.pointerFocused = true;
            root.forceActiveFocus(Qt.MouseFocusReason);
            ripple.trigger(mouse.x, mouse.y);
        }
        onClicked: root.clicked(false)
    }

    FocusRing {
        id: focusRing
        anchors.margins: Theme.focusRingWidth / 2
        topLeftRadius: Math.max(0, root.topRadius - Theme.focusRingWidth / 2)
        topRightRadius: topLeftRadius
        bottomLeftRadius: Math.max(0, root.bottomRadius - Theme.focusRingWidth / 2)
        bottomRightRadius: bottomLeftRadius
    }
}
