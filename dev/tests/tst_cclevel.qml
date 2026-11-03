import QtQuick
import QtTest
import "../../overlay/Modules/Coreflame"

// Run: QT_QPA_PLATFORM=offscreen qmltestrunner -import dev/tests/stubs -input dev/tests
// Dragging a control-centre level reports the value under the pointer in every form's shape.
Item {
    width: 400
    height: 400

    QtObject {
        id: cc
        property string lay: "khaslana"
        property bool parch: true
        property string body: "Sans"
        property QtObject pal: QtObject {
            property color accent: "gold"
            property color rim: "tan"
            property color lapis: "navy"
            property color edge: "brown"
            property color ink: "black"
        }
    }

    CcLevel {
        id: lvl
        property real last: -1
        cc: cc
        width: 300
        onMoved: to => last = to
    }

    TestCase {
        name: "CcLevel"
        when: windowShown

        function init() {
            lvl.last = -1;
        }

        function test_meter_top_is_full() {
            cc.lay = "khaslana";
            // the meter is 250 px tall from y 0: a quarter down is 75 %
            mousePress(lvl, 150, 62.5);
            fuzzyCompare(lvl.last, 0.75, 0.01);
            mouseMove(lvl, 150, 250);
            fuzzyCompare(lvl.last, 0, 0.01);
            mouseRelease(lvl, 150, 250);
        }

        function test_reaver_bars() {
            cc.lay = "reaver";
            // bars start at x 30 and are 300 - 76 = 224 px wide
            mousePress(lvl, 30 + 56, 12);
            fuzzyCompare(lvl.last, 0.25, 0.01);
            mouseRelease(lvl, 30 + 56, 12);
        }

        function test_phainon_line_clamps() {
            cc.lay = "phainon";
            // the line starts at x 32 and is 300 - 88 = 212 px wide
            mousePress(lvl, 32 + 106, 12);
            fuzzyCompare(lvl.last, 0.5, 0.01);
            mouseMove(lvl, 299, 12);
            compare(lvl.last, 1);
            mouseRelease(lvl, 299, 12);
        }
    }
}
