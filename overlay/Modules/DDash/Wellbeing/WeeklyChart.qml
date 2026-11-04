pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import qs.Common
import qs.Services
import qs.DCommon.Widgets
import qs.Widgets
import qs.Modules.DDash
import "Wellbeing.js" as Wellbeing
import "../../../DCommon/Common/WheelInput.js" as WheelInput

DCard {
    id: root

    property var days: []
    property date today: new Date()
    property int firstDayOfWeek: 1
    property real limitSeconds: 0
    property bool showTitle: true
    // Coreflame's dashboard: no card of its own (the view's card holds it), no axis, the form's ink
    property bool bare: false
    property int hoverPage: -1
    property int hoverIndex: -1
    property real wheelDistance: 0
    property real dragStartX: 0

    readonly property var weeks: Wellbeing.weeksBack(days, today, firstDayOfWeek)
    readonly property int pageCount: weeks.length
    property int page: pageCount - 1
    readonly property int currentPage: pager.width > 0 ? Math.max(0, Math.min(pageCount - 1, Math.round(pager.contentX / pager.width))) : page
    readonly property int weekOffset: page - (pageCount - 1)
    readonly property var week: weeks[page] ?? []
    readonly property var hoverDay: hoverIndex >= 0 ? (weeks[hoverPage] ?? [])[hoverIndex] ?? null : null
    readonly property real total: Wellbeing.totalSeconds(week)
    readonly property real peak: Math.max(limitSeconds, ...week.map(day => day.active))
    readonly property var axis: Wellbeing.axis(peak)
    readonly property real columnWidth: pager.width / Wellbeing.weekLength
    readonly property real barWidth: bare ? columnWidth - (Form.phainon ? 14 : 10) : columnWidth * WellbeingMetrics.barWidthRatio
    readonly property real dayLabelHeight: Theme.fontSizeSmall + Theme.spacingXS
    readonly property color pastColor: Theme.primaryContainer
    readonly property color todayColor: Theme.primary
    readonly property color overColor: bare ? ink.danger : Theme.error
    readonly property string rangeText: week.length > 0 ? rangeDate(week[0].date) + " – " + rangeDate(week[week.length - 1].date) : ""

    function rangeDate(key) {
        return Wellbeing.parseKey(key).toLocaleDateString(I18n.locale(), Wellbeing.monthDayFormat(I18n.locale().dateFormat(Locale.ShortFormat)));
    }

    function barColor(day) {
        if (limitSeconds > 0 && day.active > limitSeconds)
            return overColor;
        // Coreflame: Phainon lapis with a gold today, Khaslana red blocks with gold, the Flame Reaver violet with an ember
        if (Form.phainon)
            return day.today ? "#A87A22" : "#334786";
        if (Form.khaslana)
            return day.today ? "#E0B04A" : "#C2252F";
        if (Form.reaver)
            return day.today ? "#F07A85" : "#8F7BE0";
        return day.today ? todayColor : pastColor;
    }

    function yFor(seconds) {
        return plot.height * (1 - Math.min(1, seconds / axis.top));
    }

    function dayLabel(day) {
        return I18n.locale().dayName(day.weekday === 0 ? Wellbeing.weekLength : day.weekday, Locale.ShortFormat);
    }

    // Under the bars: Phainon's short names and "Today", Khaslana's initials, the Reaver's ">t"
    function barLabel(day) {
        if (!bare)
            return dayLabel(day);
        if (Form.phainon)
            return day.today ? I18n.tr("Today") : dayLabel(day);
        const initial = dayLabel(day).charAt(0);
        return Form.reaver ? (day.today ? ">" : "") + initial.toLowerCase() : initial.toUpperCase();
    }

    function snapTo(index, animate) {
        snapAnim.stop();
        page = Math.max(0, Math.min(pageCount - 1, index));
        const target = page * pager.width;
        if (!animate || !DashMetrics.animationsEnabled) {
            pager.contentX = target;
            return;
        }
        snapAnim.to = target;
        snapAnim.start();
    }

    function showCurrentWeek() {
        snapTo(pageCount - 1, false);
    }

    onPageCountChanged: showCurrentWeek()

    restRadius: DashMetrics.cardRadius
    pad: bare ? 0 : Theme.spacingL
    color: bare ? "transparent" : surfaceColor
    Accessible.role: Accessible.Chart
    Accessible.name: I18n.tr("Weekly screen time", "chart title, screen time per day over the week")

    NumberAnimation {
        id: snapAnim

        readonly property bool atEdge: root.page === 0 || root.page === root.pageCount - 1

        target: pager
        property: "contentX"
        duration: Theme.expressiveDurations.expressiveDefaultSpatial
        easing.type: Easing.BezierSpline
        easing.bezierCurve: atEdge ? Theme.expressiveCurves.expressiveEffects : Theme.expressiveCurves.expressiveDefaultSpatial
    }

    Binding {
        target: root.border
        property: "width"
        value: 0
        when: root.bare
    }

    CfInk {
        id: ink
    }

    Timer {
        id: settleTimer
        interval: WellbeingMetrics.settleDelay
        onTriggered: root.snapTo(root.currentPage, true)
    }

    Column {
        anchors.fill: parent
        spacing: Theme.spacingS

        StyledText {
            width: parent.width
            visible: root.showTitle
            text: I18n.tr("Weekly screen time", "chart title, screen time per day over the week")
            font.pixelSize: Theme.fontSizeLarge
            font.weight: Theme.fontWeightMedium
            color: root.contentColor
            elide: Text.ElideRight
        }

        Row {
            width: parent.width
            spacing: Theme.spacingS

            StyledText {
                id: totalLabel
                anchors.baseline: caption.baseline
                text: WellbeingService.formatDuration(root.hoverDay ? root.hoverDay.active : root.total)
                font.family: root.bare ? Form.numerals : resolvedFontFamily
                font.pixelSize: Theme.fontSizeXLarge
                font.weight: root.bare ? Font.Normal : Theme.fontWeightBold
                font.features: ({
                        "tnum": 1
                    })
                color: root.bare ? ink.accent : root.accentColor
            }

            StyledText {
                id: caption
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Theme.spacingXXS
                text: root.hoverDay ? root.dayLabel(root.hoverDay) : I18n.tr("Total")
                font.family: root.bare ? ink.headFont : resolvedFontFamily
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Theme.fontWeightMedium
                font.capitalization: root.bare && Form.reaver ? Font.AllLowercase : Font.AllUppercase
                color: root.bare ? ink.muted : root.mutedColor
            }

            Item {
                width: parent.width - x
                height: totalLabel.height

                DActionButton {
                    anchors.right: rangeLabel.left
                    anchors.verticalCenter: parent.verticalCenter
                    buttonSize: Theme.buttonHeightXS
                    iconName: "chevron_left"
                    iconColor: root.bare ? ink.icon : root.mutedColor
                    enabled: root.page > 0
                    Accessible.name: I18n.tr("Previous")
                    onClicked: root.snapTo(root.page - 1, true)
                }

                StyledText {
                    id: rangeLabel
                    anchors.right: nextButton.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: WellbeingMetrics.rangeLabelWidth
                    horizontalAlignment: Text.AlignHCenter
                    text: root.bare ? ink.tx(root.rangeText) : root.rangeText
                    font.family: root.bare ? ink.font : resolvedFontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Theme.fontWeightMedium
                    font.features: ({
                            "tnum": 1
                        })
                    color: root.bare ? (root.weekOffset === 0 ? ink.accent : ink.muted) : (root.weekOffset === 0 ? root.accentColor : root.contentColor)
                    elide: Text.ElideRight
                }

                DActionButton {
                    id: nextButton
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    buttonSize: Theme.buttonHeightXS
                    iconName: "chevron_right"
                    iconColor: root.bare ? ink.icon : root.mutedColor
                    enabled: root.weekOffset < 0
                    Accessible.name: I18n.tr("Next")
                    onClicked: root.snapTo(root.page + 1, true)
                }
            }
        }

        Item {
            width: parent.width
            height: parent.height - y
            LayoutMirroring.enabled: false
            LayoutMirroring.childrenInherit: true

            Item {
                id: plot
                anchors.left: parent.left
                anchors.right: axisLabels.left
                anchors.rightMargin: root.bare ? 0 : Theme.spacingS
                anchors.top: parent.top
                anchors.topMargin: Theme.spacingS
                anchors.bottom: parent.bottom
                anchors.bottomMargin: root.dayLabelHeight + Theme.spacingXS

                Repeater {
                    model: root.bare ? [] : root.axis.ticks

                    Rectangle {
                        required property int modelData
                        width: plot.width
                        height: Theme.dividerWidth
                        y: root.yFor(modelData * Wellbeing.secondsPerHour) - height / 2
                        color: Theme.outlineVariant
                    }
                }
            }

            DFlickable {
                id: pager
                anchors.left: plot.left
                anchors.right: plot.right
                anchors.top: plot.top
                anchors.bottom: parent.bottom
                contentWidth: width * root.pageCount
                contentHeight: height
                flickableDirection: Flickable.HorizontalFlick
                wheelEnabled: false
                showScrollBar: false
                clip: true

                onWidthChanged: {
                    snapAnim.stop();
                    contentX = root.page * width;
                }
                onDragStarted: {
                    snapAnim.stop();
                    settleTimer.stop();
                    root.dragStartX = contentX;
                }
                onFlickStarted: {
                    const forward = contentX > root.dragStartX;
                    cancelFlick();
                    root.snapTo(forward ? Math.ceil(contentX / width) : Math.floor(contentX / width), true);
                }
                onMovementEnded: {
                    if (!snapAnim.running)
                        root.snapTo(root.currentPage, true);
                }

                Repeater {
                    model: root.weeks

                    Item {
                        id: page

                        required property var modelData
                        required property int index

                        x: index * pager.width
                        width: pager.width
                        height: pager.height

                        Repeater {
                            model: page.modelData

                            Rectangle {
                                id: bar
                                required property var modelData
                                required property int index
                                readonly property color tone: root.barColor(modelData)
                                // Khaslana and the Flame Reaver draw the bar from pieces below
                                readonly property bool pieces: Form.khaslana || Form.reaver
                                x: index * root.columnWidth + (root.columnWidth - width) / 2
                                y: plot.height - height
                                width: root.barWidth
                                height: Math.max(0, plot.height - root.yFor(modelData.active))
                                visible: !modelData.future && modelData.active > 0
                                topLeftRadius: Form.phainon ? 6 : Theme.cornerRadiusS
                                topRightRadius: Form.phainon ? 6 : Theme.cornerRadiusS
                                color: pieces ? "transparent" : tone
                                // Flame Reaver: the whole bar leans 12° about its middle
                                readonly property real lean: Form.reaver ? -0.2126 : 0
                                transform: Matrix4x4 {
                                    matrix: Qt.matrix4x4(1, bar.lean, 0, -bar.lean * bar.height / 2, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
                                }
                                opacity: root.hoverIndex === -1 || (root.hoverPage === page.index && root.hoverIndex === index) ? 1 : WellbeingMetrics.dimmedBarOpacity

                                // Khaslana: a 3 px gold cap over 10 px red blocks with 2 px gaps
                                Rectangle {
                                    visible: Form.khaslana
                                    width: bar.width
                                    height: Math.min(3, bar.height)
                                    color: "#F2C75C"
                                }

                                Repeater {
                                    model: Form.khaslana ? Math.ceil(Math.max(0, bar.height - 3) / 12) : 0

                                    Rectangle {
                                        required property int index
                                        y: 3 + index * 12
                                        width: bar.width
                                        height: Math.min(10, bar.height - y)
                                        color: bar.tone
                                    }
                                }

                                // Flame Reaver: 8 px scratches with 3 px gaps
                                Repeater {
                                    model: Form.reaver ? Math.ceil(bar.height / 11) : 0

                                    Rectangle {
                                        required property int index
                                        y: index * 11
                                        width: bar.width
                                        height: Math.min(8, bar.height - y)
                                        color: bar.tone
                                    }
                                }

                                Behavior on height {
                                    enabled: DashMetrics.animationsEnabled
                                    NumberAnimation {
                                        duration: DashMetrics.meterDuration
                                        easing.type: Easing.BezierSpline
                                        easing.bezierCurve: Theme.expressiveCurves.standard
                                    }
                                }
                            }
                        }

                        Row {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            height: root.dayLabelHeight

                            Repeater {
                                model: page.modelData

                                StyledText {
                                    required property var modelData
                                    width: root.columnWidth
                                    horizontalAlignment: Text.AlignHCenter
                                    text: root.barLabel(modelData)
                                    font.family: root.bare ? ink.font : resolvedFontFamily
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.weight: modelData.today ? Theme.fontWeightBold : Theme.fontWeightMedium
                                    color: root.bare ? (modelData.today && !Form.phainon ? (Form.khaslana ? "#F5D27A" : "#B9A8FF") : ink.muted) : (modelData.today ? root.accentColor : root.mutedColor)
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.NoButton
                            hoverEnabled: true
                            onPositionChanged: mouse => {
                                if (page.index !== root.page || root.columnWidth <= 0)
                                    return;
                                root.hoverPage = page.index;
                                root.hoverIndex = Math.floor(mouse.x / root.columnWidth);
                            }
                            onExited: root.hoverIndex = -1
                        }
                    }
                }
            }

            Shape {
                anchors.fill: plot
                visible: root.limitSeconds > 0
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    strokeColor: root.overColor
                    strokeWidth: Theme.outlineWidthFocused
                    strokeStyle: ShapePath.DashLine
                    dashPattern: [3, 3]
                    fillColor: "transparent"
                    capStyle: ShapePath.FlatCap
                    startX: 0
                    startY: root.yFor(root.limitSeconds)

                    PathLine {
                        x: plot.width
                        y: root.yFor(root.limitSeconds)
                    }
                }
            }

            StyledText {
                anchors.right: plot.right
                y: plot.y + root.yFor(root.limitSeconds) - height - Theme.spacingXXS
                visible: root.limitSeconds > 0
                text: I18n.tr("Limit", "label on the daily screen time limit line of a chart")
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Theme.fontWeightBold
                font.capitalization: Font.AllUppercase
                color: root.overColor
            }

            MouseArea {
                anchors.fill: pager
                acceptedButtons: Qt.NoButton
                onWheel: wheel => {
                    if (wheel.angleDelta.x === 0 && wheel.pixelDelta.x === 0) {
                        wheel.accepted = false;
                        return;
                    }
                    snapAnim.stop();
                    if (WheelInput.isTouchpad(wheel)) {
                        pager.contentX = Math.max(0, Math.min(pager.contentWidth - pager.width, pager.contentX - wheel.pixelDelta.x));
                        settleTimer.restart();
                        return;
                    }
                    root.wheelDistance += wheel.angleDelta.x;
                    if (Math.abs(root.wheelDistance) < WellbeingMetrics.wheelNotch)
                        return;
                    const step = root.wheelDistance > 0 ? -1 : 1;
                    root.wheelDistance = 0;
                    root.snapTo(root.page + step, true);
                }
            }

            Item {
                id: axisLabels
                anchors.right: parent.right
                anchors.top: plot.top
                anchors.bottom: plot.bottom
                width: root.bare ? 0 : WellbeingMetrics.axisLabelWidth

                Repeater {
                    model: root.bare ? [] : root.axis.ticks

                    StyledText {
                        required property int modelData
                        anchors.right: axisLabels.right
                        y: root.yFor(modelData * Wellbeing.secondsPerHour) - height / 2
                        text: I18n.tr("%1h", "hours abbreviation, %1 is a number").arg(modelData)
                        font.pixelSize: Theme.fontSizeSmall
                        font.features: ({
                                "tnum": 1
                            })
                        color: root.mutedColor
                    }
                }
            }
        }
    }
}
