import QtQuick
import QtTest
import qs.Common
import "../../overlay/Modules/Coreflame"

// A control-centre menu comes out from under its switch and goes back in before it is destroyed.
Item {
    width: 400
    height: 400

    Component {
        id: menu
        Rectangle {
            implicitHeight: 120
        }
    }

    CcSlide {
        id: slide
        width: 300
        lay: "phainon"
        sourceComponent: menu
    }

    TestCase {
        name: "CcSlide"
        when: windowShown

        function cleanup() {
            slide.open = false;
            Motion.openMs = 300;
            slide.lay = "phainon";
            tryCompare(slide, "item", null, 2000);
        }

        function test_closed_menu_is_not_built() {
            compare(slide.item, null);
            compare(slide.height, 0);
        }

        function test_open_grows_to_the_menu_height() {
            slide.open = true;
            verify(slide.item !== null);
            tryVerify(() => slide.height === 120 && !slide.moving, 2000);
        }

        function test_close_keeps_the_menu_until_it_is_back_in() {
            slide.open = true;
            tryCompare(slide, "height", 120, 2000);
            tryVerify(() => slide.height === 120 && !slide.moving, 2000);
            slide.open = false;
            verify(slide.item !== null);
            verify(slide.height > 0);
            let lowest = 1;
            while (slide.item) {
                lowest = Math.min(lowest, slide.out);
                wait(10);
            }
            verify(lowest >= 0);
            compare(slide.height, 0);
        }

        function test_reduce_motion_opens_at_once() {
            Motion.openMs = 0;
            slide.open = true;
            compare(slide.duration, 0);
            tryCompare(slide, "height", 120, 100);
        }

        function test_reaver_moves_in_quarters() {
            slide.lay = "reaver";
            slide.open = true;
            tryVerify(() => slide.moving, 1000);
            while (slide.moving) {
                verify(Number.isInteger(slide.shown * 4));
                wait(10);
            }
            tryCompare(slide, "height", 120, 2000);
        }
    }
}
