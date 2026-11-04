import QtQuick
import QtQuick.Shapes
import qs.DCommon.Common
import qs.Common as Shell

StyledButton {
    id: root

    property bool busy: false
    property string reserveText: ""
    property string shape: "round"
    property real maximumWidth: Infinity
    property bool wrapText: false
    property string iconName: ""
    property int iconSize: root.buttonHeight <= Style.buttonHeightS ? Style.iconSizeMedium : Style.iconSize
    property color backgroundColor: Style.buttonBg
    property color textColor: Style.buttonText
    property int buttonHeight: Style.buttonHeightS
    horizontalPadding: {
        if (buttonHeight <= Style.buttonHeightXS)
            return Style.spacingM;
        if (buttonHeight <= Style.buttonHeightS)
            return Style.spacingL;
        return Style.spacingXL;
    }
    property bool enableScaleAnimation: false
    property bool enableRipple: Style.enableRippleEffects
    property real minimumWidth: Style.buttonMinWidth
    property var tooltipText: null
    property string tooltipSide: "bottom"

    implicitWidth: Math.min(maximumWidth, Math.max(contentRow.implicitWidth + horizontalPadding * 2, minimumWidth))
    implicitHeight: wrapText ? Math.max(buttonHeight, contentRow.implicitHeight + Style.spacingS * 2) : buttonHeight
    readonly property color contentColor: cf ? cfDim(cfText) : enabled ? textColor : Style.onSurface_38
    readonly property real maximumLabelWidth: Math.max(0, maximumWidth - horizontalPadding * 2 - (busy || iconName ? iconSize + contentRow.spacing : 0))

    readonly property real restRadius: Style.buttonRadius(width, height, buttonHeight, false, shape === "round")
    readonly property real pressedRadius: Style.buttonRadius(width, height, buttonHeight, true, shape === "round")
    property real pressProgress: pressed ? 1 : 0
    radius: cf ? (Shell.Form.phainon ? height / 2 : 0) : restRadius + (pressedRadius - restRadius) * pressProgress
    // Coreflame: Phainon rimmed paper pills (filled lapis for the main action), Khaslana cut plates
    // (blood red for the main action), Reaver plain words. The main action is the one on the accent colour.
    readonly property bool cf: Shell.Form.active
    readonly property bool cfDanger: Qt.colorEqual(backgroundColor, Style.error)
    readonly property bool cfMain: cfDanger || Qt.colorEqual(backgroundColor, Style.buttonBg) || Qt.colorEqual(backgroundColor, Style.primary)
    readonly property color cfText: {
        if (Shell.Form.phainon)
            return cfMain ? "#F7F3E8" : "#334786";
        if (Shell.Form.khaslana)
            return cfMain ? "#F5D27A" : "#C9B89E";
        return cfDanger ? "#F07A85" : (cfMain ? "#B9A8FF" : "#A8A4BC");
    }
    readonly property color cfRim: {
        if (Shell.Form.phainon)
            return cfDanger ? "#A3343A" : (cfMain ? "#334786" : "#A87A22");
        return cfMain ? "#F2C75C" : "#8A5A2B";
    }
    readonly property color cfBack: {
        if (Shell.Form.phainon)
            return cfDanger ? "#A3343A" : (cfMain ? "#334786" : "#FBF9F3");
        if (Shell.Form.khaslana)
            return cfDanger ? "#C2252F" : (cfMain ? "#8E1424" : "#0B080B");
        return "transparent";
    }
    function cfDim(c) {
        return enabled ? c : Style.withAlpha(c, 0.4);
    }
    readonly property bool cfCut: Shell.Form.shape === "cut"
    readonly property color cfFill: cf ? cfDim(cfBack) : enabled ? backgroundColor : Style.onSurface_12
    color: cfCut ? "transparent" : cfFill
    border.width: cf && Shell.Form.phainon ? 1 : 0
    border.color: cfDim(cfRim)

    Shape {
        id: cfPlate
        readonly property real c: Math.min(8, height / 3)
        anchors.fill: parent
        z: -1
        visible: root.cfCut
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: root.cfFill
            strokeColor: root.cfDim(root.cfRim)
            strokeWidth: 1
            startX: cfPlate.c
            startY: 0

            PathLine {
                x: cfPlate.width
                y: 0
            }
            PathLine {
                x: cfPlate.width
                y: cfPlate.height - cfPlate.c
            }
            PathLine {
                x: cfPlate.width - cfPlate.c
                y: cfPlate.height
            }
            PathLine {
                x: 0
                y: cfPlate.height
            }
            PathLine {
                x: 0
                y: cfPlate.c
            }
            PathLine {
                x: cfPlate.c
                y: 0
            }
        }
    }
    scale: (enableScaleAnimation && pressed) ? Style.pressScale : 1.0
    Accessible.role: Accessible.Button
    Accessible.name: text || tooltipText || iconName

    FocusRing {
        visible: root.visualFocus
        radius: Math.max(0, parent.radius + Style.focusRingOffset)
    }

    Behavior on pressProgress {
        enabled: !Style.reduceMotion && Style.currentAnimationSpeed !== Style.AnimationSpeed.None
        DAnim {
            duration: Style.expressiveDurations.expressiveEffects
            easing.bezierCurve: Style.expressiveCurves.standard
        }
    }

    Behavior on scale {
        enabled: enableScaleAnimation && !Style.reduceMotion && Style.currentAnimationSpeed !== Style.AnimationSpeed.None
        DAnim {
            duration: Style.expressiveDurations.expressiveFastSpatial
            easing.bezierCurve: Style.expressiveCurves.expressiveFastSpatial
        }
    }

    StateLayer {
        id: stateLayer
        control: root
        enabled: root.enabled
        disabled: !root.enabled
        stateColor: root.cf ? root.cfText : root.textColor
        enableRipple: root.enableRipple
        transitionDuration: Style.expressiveDurations.expressiveEffects
        transitionCurve: Style.expressiveCurves.expressiveEffects
        tooltipText: root.tooltipText
        tooltipSide: root.tooltipSide
    }

    // TextMetrics.advanceWidth can differ from Text.implicitWidth by 1px for the same string, so measure with a Text.
    Loader {
        id: reservedLabel
        active: root.reserveText !== ""
        visible: false
        sourceComponent: StyledText {
            text: root.reserveText
            font.pixelSize: Style.fontSizeMedium
            font.weight: Style.fontWeightMedium
            wrapMode: Text.NoWrap
        }
    }

    Row {
        id: contentRow
        anchors.centerIn: parent
        spacing: {
            if (buttonHeight <= Style.buttonHeightXS) {
                return Style.spacingXS;
            } else if (buttonHeight <= Style.buttonHeightM) {
                return Style.spacingS;
            } else {
                return Style.spacingM;
            }
        }

        Item {
            width: root.iconSize
            height: root.iconSize
            visible: root.busy || root.iconName !== ""
            anchors.verticalCenter: parent.verticalCenter

            DIcon {
                name: root.iconName
                size: root.iconSize
                color: root.cf && Shell.Form.phainon && !root.cfMain ? root.cfDim("#A87A22") : root.contentColor
                visible: !root.busy
            }
            Loader {
                anchors.fill: parent
                active: root.busy
                sourceComponent: DSpinner {
                    size: root.iconSize
                    strokeWidth: Style.outlineWidthFocused
                    color: root.contentColor
                    running: root.busy && root.visible
                    Accessible.ignored: true
                }
            }
        }

        StyledText {
            width: Math.min(Math.max(implicitWidth, reservedLabel.item?.implicitWidth ?? 0), root.maximumLabelWidth)
            wrapMode: root.wrapText ? Text.WrapAtWordBoundaryOrAnywhere : Text.NoWrap
            elide: root.wrapText ? Text.ElideNone : Text.ElideRight
            text: root.cf && Shell.Form.reaver ? root.text.toLowerCase() : root.text
            font.pixelSize: !root.cf ? Style.fontSizeMedium : (Shell.Form.khaslana ? 13 : 14)
            font.weight: !root.cf ? Style.fontWeightMedium : (Shell.Form.phainon ? Font.Normal : (Shell.Form.khaslana || root.cfMain ? Font.DemiBold : Font.Medium))
            font.family: !root.cf ? resolvedFontFamily : (Shell.Form.phainon ? "Marcellus" : (Shell.Form.khaslana ? "Cinzel" : "Chakra Petch"))
            font.capitalization: root.cf && Shell.Form.khaslana ? Font.AllUppercase : Font.MixedCase
            font.letterSpacing: root.cf && Shell.Form.khaslana ? 13 * 0.14 : 0
            color: root.contentColor
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
