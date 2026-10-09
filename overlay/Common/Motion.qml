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

    // Reshapes one of Theme's duration tables for the current form and tier.
    function adjust(base) {
        if (!base || tier === "stock")
            return base;
        const factor = tier === "lean" ? 0.75 : (Form.khaslana ? 1.15 : 1.0);
        const out = {};
        for (const key in base) {
            const cap = !still ? Infinity : (key === "extraLong" ? 300 : 140);
            out[key] = Math.round(Math.min(base[key] * factor, cap));
        }
        return out;
    }
}
