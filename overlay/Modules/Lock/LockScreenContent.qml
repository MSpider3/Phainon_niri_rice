pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Window
import qs.Common
import qs.Modals
import qs.Modules.Plugins
import qs.Services
import qs.DCommon.Session
import qs.Widgets

FocusScope {
    id: root
    readonly property var log: Log.scoped("LockScreenContent")

    property string passwordBuffer: ""
    property bool inputRevealed: false
    signal inputRevealRequested(bool revealed)

    function setInputRevealed(revealed) {
        inputRevealRequested(revealed);
    }
    property bool demoMode: false
    property bool greeterPreview: false
    property var pam: demoPam
    property string screenName: ""
    property bool unlocking: false
    property string pamState: ""
    property bool lockerReadySent: false
    property bool lockerReadyArmed: false
    property var sessionLock: null
    property Item authWidget: null
    readonly property Item backgroundItem: background
    readonly property bool backgroundReady: background.ready
    readonly property string backgroundKey: background.renderKey

    signal unlockRequested
    signal passwordEdited(string text)
    signal authFailed

    function resetLockState() {
        widgetLayer.refreshPlacement();
        lockerReadySent = false;
        lockerReadyArmed = true;
        unlocking = false;
        pamState = "";
        if (pam)
            pam.lockMessage = "";
    }

    function focusPasswordField() {
        if (demoMode)
            return;
        authWidget?.focusPasswordField();
    }

    function showPowerMenu() {
        if (demoMode)
            return;
        powerMenu.show();
    }

    function contentColor(mode, custom) {
        switch (mode) {
        case "primary":
            return Theme.primary;
        case "secondary":
            return Theme.secondary;
        case "custom":
            return custom;
        }
        return Theme.lockScreenContentColor;
    }

    Component.onCompleted: {
        WeatherService.addRef();
        UserInfoService.getUserInfo();

        lockerReadyArmed = true;
    }

    Component.onDestruction: {
        WeatherService.removeRef();
    }

    function sendLockerReadyOnce() {
        if (root.demoMode)
            return;
        if (lockerReadySent)
            return;
        if (root.unlocking)
            return;
        lockerReadySent = true;
        if (SessionService.loginctlAvailable && DMSService.apiVersion >= 2) {
            DMSService.sendRequest("loginctl.lockerReady", null, resp => {
                if (resp?.error)
                    log.warn("lockerReady failed:", resp.error);
                else
                    log.debug("lockerReady sent (afterAnimating/afterRendering)");
            });
        }
    }

    function maybeSend() {
        if (!lockerReadyArmed)
            return;
        if (root.unlocking)
            return;
        if (!root.visible || root.opacity <= 0)
            return;
        if (root.sessionLock && !root.sessionLock.secure)
            return;
        Qt.callLater(() => {
            if (root.visible && root.opacity > 0 && !root.unlocking)
                sendLockerReadyOnce();
        });
    }

    Connections {
        target: root.sessionLock
        enabled: target !== null
        function onSecureChanged() {
            root.maybeSend();
        }
    }

    Connections {
        target: root.Window.window
        enabled: target !== null

        function onAfterAnimating() {
            maybeSend();
        }
        function onAfterRendering() {
            maybeSend();
        }
    }

    onVisibleChanged: maybeSend()
    onOpacityChanged: maybeSend()

    LockScreenBackground {
        id: background
        anchors.fill: parent
        screenName: root.screenName
    }

    // Coreflame: each form's own lock screen, drawn between the wallpaper and DMS's widgets
    // (password box, notifications), which stay as they are.
    CfLockOrnament {
        anchors.fill: parent
        screenName: root.screenName
        backgroundKey: root.backgroundKey
    }

    // Coreflame: Phainon places its time where the wallpaper is clearest. DMS samples the wallpaper
    // before locking only while its own clock is auto-placed, so take the sample here when there is
    // none yet; it is cached per wallpaper, so this runs once, not on every lock.
    property string placementFailedKey: ""
    Loader {
        active: Form.phainon && root.screenName !== "" && background.ready && root.placementFailedKey !== root.backgroundKey && !LockPlacementService.hasSample(root.screenName, root.backgroundKey)
        sourceComponent: LockBackgroundSampler {
            sourceItem: background
            ready: background.ready
            renderKey: root.backgroundKey
            onFailed: root.placementFailedKey = root.backgroundKey
            onSampled: (luminances, sampleWidth, sampleHeight) => LockPlacementService.storeSample(root.screenName, root.backgroundKey, luminances, sampleWidth, sampleHeight)
        }
    }

    Keys.onPressed: event => {
        if (widgetLayer.handleKey(event)) {
            event.accepted = true;
            return;
        }
        if (event.key !== Qt.Key_Escape || !editorLoader.item)
            return;
        editorLoader.item.dismiss();
        event.accepted = true;
    }

    WidgetEditLayer {
        id: widgetLayer
        anchors.fill: parent
        focus: true
        screenName: root.screenName
        lockScreen: true
        greeter: root.greeterPreview
        lockHost: root
        editMode: root.demoMode
        bottomInset: editorLoader.item?.fabReserved ?? 0
        onFocusStolen: root.focusPasswordField()
        onOptionsRequested: instanceId => editorLoader.item?.showOptions(instanceId)
    }

    Pam {
        id: demoPam
        lockSecured: false
    }

    Connections {
        target: root.pam

        function onUnlockRequested() {
            root.unlocking = true;
            lockerReadyArmed = false;
            root.passwordEdited("");
            root.unlockRequested();
        }

        function onStateChanged() {
            root.pamState = root.pam.state;
            if (root.pam.state === "")
                return;
            root.unlocking = false;
            root.authFailed();
            placeholderDelay.restart();
            root.passwordEdited("");
        }

        function onUnlockInProgressChanged() {
            if (!root.pam.unlockInProgress && root.unlocking)
                root.unlocking = false;
        }
    }

    Timer {
        id: placeholderDelay

        interval: 4000
        onTriggered: root.pamState = ""
    }

    Loader {
        id: editorLoader
        anchors.fill: parent
        active: root.demoMode

        sourceComponent: WidgetEditorOverlay {
            editLayer: widgetLayer
            onFinished: root.unlockRequested()
        }
    }

    LockPowerMenu {
        id: powerMenu
        expressive: true
        showLogout: true
        onClosed: {
            if (!demoMode)
                Qt.callLater(() => root.focusPasswordField());
        }
        onSwitchUserRequested: {
            switchUserPicker.showFromLockScreen();
        }
    }

    SwitchUserModal {
        id: switchUserPicker
    }

    // Coreflame: the idle video, above everything; any input brings the lock screen back.
    CfLockVideo {
        anchors.fill: parent
        // Not while DMS has the monitors powered off: decoding a video nobody sees costs battery.
        armed: root.passwordBuffer === "" && !root.unlocking && !IdleService.monitorsOff
        onDismissed: root.focusPasswordField()
    }
}
