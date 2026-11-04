import QtQuick
import QtTest
import qs.Common
import "../../overlay/Widgets"

// Hovering a Titan names it and says how its Coreflame is taken, in the form's case.
Item {
    width: 800
    height: 200

    CfTitans {
        id: titans
    }

    Item {
        id: fakeTitan
        width: 40
        height: 40
        property var modelData: titans.rows[0]
    }

    TestCase {
        name: "CfTitansTip"
        when: windowShown

        function cleanup() {
            Form.form = "phainon";
        }

        function test_unlit_titan_gives_name_and_how() {
            compare(titans.tip(titans.rows[0]), ["Janus", "Walk all three forms"]);
        }

        function test_lit_titan_is_marked_taken() {
            compare(titans.tip(titans.rows[1]), ["Kephale", "Open the dashboard (taken)"]);
        }

        function test_hovering_shows_one_shared_tip() {
            verify(!titans.tipShown);
            titans.hover(fakeTitan, true);
            tryVerify(() => titans.tipShown, 1000);
            compare(titans.tipParts, ["Janus", "Walk all three forms"]);
            titans.hover(fakeTitan, false);
            tryVerify(() => !titans.tipShown, 1000);
        }

        function test_reaver_tip_is_lower_case() {
            Form.form = "reaver";
            compare(titans.tip(titans.rows[0]), ["janus", "walk all three forms"]);
        }
    }
}
