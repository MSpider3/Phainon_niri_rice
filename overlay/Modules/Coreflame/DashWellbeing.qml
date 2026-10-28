import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.DDash
import qs.Modules.DDash.Wellbeing

// "Time · Wellbeing": today and the daily limit on a Coreflame card, then stock DMS 2.0's wellbeing
// tab (weekly chart, most-used apps, per-app limits), which already takes the form's colours.
Column {
    id: well

    function tx(text) {
        return Form.reaver ? String(text).toLowerCase() : text;
    }

    spacing: 12

    DashCard {
        width: well.width
        height: 66
        numeral: "I"
        glyph: "time"
        label: "Today"

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: WellbeingService.formatDuration(WellbeingService.today.active)
            font.family: Form.phainon ? Theme.fontFamily : Theme.monoFontFamily
            font.pixelSize: 22
            font.weight: Font.DemiBold
            color: SettingsData.wellbeingDailyLimit > 0 && WellbeingService.today.active >= SettingsData.wellbeingDailyLimit * 60 ? Theme.error : (Form.reaver ? Theme.live : Theme.primary)
        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 12

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: well.tx(SettingsData.wellbeingDailyLimit > 0 ? "Daily limit" : "Daily limit · off")
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.withAlpha(Theme.surfaceText, 0.7)
            }

            DurationSteppers {
                anchors.verticalCenter: parent.verticalCenter
                minutes: SettingsData.wellbeingDailyLimit
                onCommitted: next => SettingsData.set("wellbeingDailyLimit", next)
            }
        }
    }

    WellbeingTab {
        width: well.width
        height: 440
        // Created already open, so its own "became visible" refresh never fires.
        Component.onCompleted: refresh()
    }
}
