pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.UPower

// How much animation the machine can afford right now.
// full: on mains. lean: on battery. still: Power Saver, or the Flame Reaver form.
Singleton {
    id: root

    readonly property bool onBattery: UPower.onBattery
    readonly property bool saver: PowerProfiles.profile === PowerProfile.PowerSaver
    readonly property string tier: !Form.active ? "stock" : ((Form.reaver || saver) ? "still" : (onBattery ? "lean" : "full"))
    readonly property bool still: tier === "still"

    // Reshapes Theme's base animation duration (DMS 2.0 derives every other duration from it)
    // for the current form and tier. Still caps the longest animation at 140 ms.
    function base(ms) {
        if (tier === "stock")
            return ms;
        const factor = tier === "lean" ? 0.75 : (Form.khaslana ? 1.15 : 1.0);
        return Math.round(still ? Math.min(ms * factor, 140) : ms * factor);
    }
}
