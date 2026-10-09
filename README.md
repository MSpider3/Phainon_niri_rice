# Phainon niri rice

A desktop for [niri](https://github.com/YaLTeR/niri) that wears one Honkai: Star Rail character in three forms. It sits on top of [DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell) (DMS), so you keep everything DMS already does well (settings, plugins, keybinds, lock screen) and only the look changes.

![The three forms side by side](screenshots/three-forms.jpg)

Pick a form and the whole desktop follows: colours, shapes, fonts, wallpaper, GTK apps, even the folder icons.

| Form | Mood |
|---|---|
| **Phainon** | Light. Paper, lapis blue and a bit of sun gold. Soft round corners. |
| **Khaslana** | Navy-black and gold, sharp cut corners, a little glitchy on purpose. |
| **Flame Reaver** | Charcoal, bronze and one violet. Quiet, text-heavy, almost no animation. |

## What it looks like

### Phainon

![Phainon desktop](screenshots/phainon-desktop.jpg)

| Dashboard | Control panel |
|---|---|
| ![Phainon dashboard](screenshots/phainon-dashboard.jpg) | ![Phainon control panel](screenshots/phainon-control.jpg) |

| Launcher | Power menu |
|---|---|
| ![Phainon launcher](screenshots/phainon-launcher.jpg) | ![Phainon power menu](screenshots/phainon-power.jpg) |

### Khaslana

![Khaslana desktop](screenshots/khaslana-desktop.jpg)

| Dashboard | Control panel |
|---|---|
| ![Khaslana dashboard](screenshots/khaslana-dashboard.jpg) | ![Khaslana control panel](screenshots/khaslana-control.jpg) |

| Launcher | Power menu |
|---|---|
| ![Khaslana launcher](screenshots/khaslana-launcher.jpg) | ![Khaslana power menu](screenshots/khaslana-power.jpg) |

### Flame Reaver

![Flame Reaver desktop](screenshots/reaver-desktop.jpg)

| Control panel | Launcher |
|---|---|
| ![Flame Reaver control panel](screenshots/reaver-control.jpg) | ![Flame Reaver launcher](screenshots/reaver-launcher.jpg) |

## What you get

- **No bar.** A dynamic island at the top centre (clock, date, weather, what's playing, notifications), with a small workspace tab on the left and a status tab on the right.
- **Dashboard** that drops out of the island: clock, weather, calendar, music with cover art, timer, forecast and a wallpaper picker.
- **Control panel** from the right corner: volume, brightness, Wi-Fi, Bluetooth, sound output, battery details, your DMS plugins, tray and notifications in one tall panel.
- **Launcher, clipboard history, system monitor and power menu** in the same style, on the same keybinds DMS already uses.
- **A little Phainon chimera** in the corner that sleeps when your CPU is idle and runs faster the harder it works.
- **Scroll on the island** to move between workspaces.
- **Small nods to the story**, like the cycle counter that starts at 33,550,336 and goes up by one each boot.
- **A safety net.** If the shell ever fails to start, it puts stock DMS back by itself.

## Before you start

You need:

- niri
- DankMaterialShell **1.6.2**, running as the usual `dms` systemd user service
- `rsync`, `python3` and `git`

This is built on the DMS 1.6.2 interface. On another DMS version it may not load. If that happens the safety net simply drops you back to stock DMS.

## Install

```sh
git clone https://github.com/MSpider3/Phainon_niri_rice.git
cd Phainon_niri_rice
sh install.sh
```

That copies the fonts, the three wallpapers (into `~/Pictures/Phainon`), the theme and a tiny form-switch plugin, then restarts DMS with the new look. Your bar will blink for a few seconds.

Want the matching icons and folders too? Run it like this instead (downloads about 185 MB of [Gruvbox Plus](https://github.com/SylEleuth/gruvbox-plus-icon-pack) icons):

```sh
sh install.sh --icons
```

## Using it

Switch form from the buttons at the top of the control panel, or from a terminal:

```sh
dms ipc call form set phainon
dms ipc call form set khaslana
dms ipc call form set reaver
```

Your keybinds don't change. Whatever opens the DMS launcher, clipboard, process list or power menu on your setup now opens the themed one.

## Going back

```sh
sh coreflame.sh off
```

Stock DMS comes back with the theme, wallpaper cycling and icons you had before. There is also a "Return to stock DMS" button at the bottom of the control panel (double-click it).

## Making it yours

- **Wallpapers:** replace the three pictures in `~/Pictures/Phainon` (keep the file names), or change the names in `overlay/Common/Form.qml`.
- **Colours:** everything comes from `dms-config/theme/coreflame/theme.json`.
- **The interface:** all custom pieces live in `overlay/`. Edit, run `sh build.sh`, and the shell picks it up.
- **Try changes safely:** `sh dev/run-nested.sh ~/.cache/cfn khaslana` opens a sandboxed copy in its own window, so you can break things without touching your real session.

A heads-up: while a form is active, DMS wallpaper cycling is switched off so the form's wallpaper stays put. It comes back when you leave.

## Credits

- [DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell) by Avenge Media, MIT. A copy of its 1.6.2 interface is in `vendor/` and this rice is a layer on top of it.
- [Gruvbox Plus icon pack](https://github.com/SylEleuth/gruvbox-plus-icon-pack) by SylEleuth, GPL-3.0. The folder artwork in `icons/` comes from it and stays under that licence.
- Fonts in `fonts/`: Marcellus, Cinzel, Chakra Petch and Cormorant Garamond, all under the SIL Open Font License.
- The chimera sprite is from a fan-made Chimera Phainon desktop pet. The wallpapers are fan art. I didn't make either and all credit goes to their artists. If one of them is yours and you'd like credit or removal, open an issue.
- Phainon and Honkai: Star Rail belong to HoYoverse. This is a fan project and is not affiliated with them.

Everything written for this project is under the [MIT licence](LICENSE).
