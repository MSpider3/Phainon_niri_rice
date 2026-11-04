import QtQuick
import QtTest
import "../../overlay/Modules/Coreflame/PowerLoop.js" as Loop

// The power menu's loop: the chosen action sits at 0, the rest wrap round both sides.
TestCase {
    name: "PowerLoop"

    function test_wrap_keeps_seven_around_the_middle() {
        compare(Loop.wrap(0, 7), 0);
        compare(Loop.wrap(3, 7), 3);
        compare(Loop.wrap(4, 7), -3);
        compare(Loop.wrap(-4, 7), 3);
        compare(Loop.wrap(-7, 7), 0);
        compare(Loop.wrap(15, 7), 1);
    }

    function test_index_loops_both_ways() {
        compare(Loop.index(0, 7), 0);
        compare(Loop.index(7, 7), 0);
        compare(Loop.index(-1, 7), 6);
        compare(Loop.index(9, 7), 2);
        compare(Loop.index(3, 0), 0);
    }

    function test_turn_to_takes_the_short_way() {
        // From Lock (0), Shut down (6) is one step left, Sleep (1) one step right
        compare(Loop.turnTo(6, 0, 7), -1);
        compare(Loop.turnTo(1, 0, 7), 1);
        // After many turns the loop position is large; still one step
        compare(Loop.turnTo(2, 15, 7), 1);
    }

    function test_ends_stay_and_seam_sinks() {
        compare(Loop.sink(3, 7), 0);
        compare(Loop.fade(3, 7), 1);
        compare(Loop.sink(3.5, 7), 0.5);
        compare(Loop.fade(3.5, 7), 0);
    }
}
