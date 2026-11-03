pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.UPower

// How much animation the machine can afford right now.
// full: on mains. lean: on battery. still: Power Saver, "reduce motion", or the Flame Reaver form.
Singleton {
    id: root

    readonly property bool onBattery: UPower.onBattery
    readonly property bool saver: PowerProfiles.profile === PowerProfile.PowerSaver
    readonly property bool reduced: typeof SettingsData !== "undefined" && SettingsData.reduceMotion
    readonly property string tier: !Form.active ? "stock" : ((Form.reaver || saver || reduced) ? "still" : (onBattery ? "lean" : "full"))
    readonly property bool still: tier === "still"
    // The eclipse window animation (a GPU shader, 650 ms per open/close) only on mains with full
    // motion allowed, in every form; otherwise niri's own animation from the user's config plays.
    readonly property bool richWindows: Form.active && !onBattery && !saver && !reduced

    // Reshapes Theme's base animation duration (DMS 2.0 derives every other duration from it)
    // for the current form and tier. Still caps the longest animation at 140 ms.
    function base(ms) {
        if (tier === "stock")
            return ms;
        const factor = tier === "lean" ? 0.75 : (Form.khaslana ? 1.15 : 1.0);
        return Math.round(still ? Math.min(ms * factor, 140) : ms * factor);
    }
}
