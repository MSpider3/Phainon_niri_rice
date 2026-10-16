pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The Flame-Chase: the twelve Titans' Coreflames, gathered one by one as things happen on this
// machine. Kept in ~/.config/coreflame/coreflames.json. Nothing here runs on a timer; a flame is
// earned when the shell reports the matching event.
Singleton {
    id: root

    // glyph name → [Titan, what earns it]
    readonly property var titans: ({
            "worldbearing": ["Kephale", "Bear the world: start the shell"],
            "passage": ["Janus", "Walk all three forms"],
            "time": ["Oronyx", "Stay awake six hours"],
            "law": ["Talanton", "Open the system monitor"],
            "earth": ["Georios", "Charge to full"],
            "ocean": ["Phagousa", "Let music play"],
            "sky": ["Aquila", "Read the forecast"],
            "strife": ["Nikador", "Push the CPU past 90 %"],
            "death": ["Thanatos", "Open the power menu"],
            "trickery": ["Zagreus", "Copy from the clipboard history"],
            "reason": ["Cerces", "Launch an app from the launcher"],
            "romance": ["Mnestia", "Receive a notification"]
        })
    readonly property var order: ["worldbearing", "passage", "time", "law", "earth", "ocean", "sky", "strife", "death", "trickery", "reason", "romance"]
    readonly property int count: order.filter(name => (store.earned ?? []).indexOf(name) >= 0).length

    signal gathered(string name)

    function has(name) {
        return (store.earned ?? []).indexOf(name) >= 0;
    }

    function earn(name) {
        if (!titans[name] || has(name))
            return;
        store.earned = (store.earned ?? []).concat([name]);
        file.setText(JSON.stringify({
            "earned": store.earned,
            "forms": store.forms
        }, null, 2) + "\n");
        gathered(name);
    }

    // Janus: counts the forms walked; the flame comes once all three have been seen.
    function sawForm(form) {
        if ((store.forms ?? []).indexOf(form) >= 0)
            return;
        store.forms = (store.forms ?? []).concat([form]);
        if (store.forms.length >= 3)
            earn("passage");
        else
            file.setText(JSON.stringify({
                "earned": store.earned,
                "forms": store.forms
            }, null, 2) + "\n");
    }

    FileView {
        id: file
        path: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/coreflame/coreflames.json"
        blockLoading: true
        printErrors: false

        JsonAdapter {
            id: store
            property var earned: []
            property var forms: []
        }
    }
}
