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
    // The eclipse window animation (a GPU shader, 650 ms per open/close) on mains outside Power
    // Saver, in every form; otherwise niri's own animation from the user's config plays. Not tied
    // to "reduce motion": DMS 2.0's v39 migration turns that on from an old island-only toggle.
    readonly property bool richWindows: Form.active && !onBattery && !saver

    // How every island panel opens (its `reveal` follows `opening` through step()): Phainon grows
    // with an overshoot, Khaslana spills heavily, the Flame Reaver cracks open in four hard steps.
    // Reduce motion or Power Saver: no motion at all.
    readonly property int openMs: !Form.active ? Theme.mediumDuration : ((reduced || saver) ? 0 : (Form.reaver ? 200 : Theme.mediumDuration))
    readonly property int openEasing: !Form.active ? Easing.OutCubic : (Form.phainon ? Easing.OutBack : (Form.khaslana ? Easing.InOutCubic : Easing.Linear))
    function step(r) {
        return Form.reaver ? Math.ceil(r * 4) / 4 : r;
    }

    // Reshapes Theme's base animation duration (DMS 2.0 derives every other duration from it)
    // for the current form and tier. Still caps the longest animation at 140 ms.
    function base(ms) {
        if (tier === "stock")
            return ms;
        const factor = tier === "lean" ? 0.75 : (Form.khaslana ? 1.15 : 1.0);
        return Math.round(still ? Math.min(ms * factor, 140) : ms * factor);
    }
}
