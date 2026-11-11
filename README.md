# Phainon niri rice

A desktop for [niri](https://github.com/YaLTeR/niri) that wears one Honkai: Star Rail character in three forms. It sits on top of [DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell) (DMS), so you keep everything DMS already does well (settings, plugins, keybinds, lock screen) and only the look changes.

![The three forms side by side](screenshots/three-forms.jpg)

Pick a form and the whole desktop follows: colours, shapes, fonts, wallpaper, GTK apps, even the folder icons. Apps like Zed, Vesktop and Qt apps can follow too (see [SETUP.md](SETUP.md)).

| Form | Mood |
|---|---|
| **Phainon** | Light. Parchment, lapis blue and sun gold. Soft round corners, Greek-key bands and the sun's path across the sky. |
| **Khaslana** | Obsidian black, gold and blood red. Sharp cut corners, small golden-blood marks, the Black Tide dripping under every panel, a little glitchy on purpose. |
| **Flame Reaver** | Charcoal, bone and one violet. Quiet, lowercase, text-heavy, almost no animation; panels hang like his torn cloak. |

## What it looks like

### Phainon

![Phainon desktop](screenshots/phainon-desktop.jpg)

| Dashboard | Control panel |
|---|---|
| ![Phainon dashboard](screenshots/phainon-dashboard.jpg) | ![Phainon control panel](screenshots/phainon-control.jpg) |

| Launcher | Power menu |
|---|---|
| ![Phainon launcher](screenshots/phainon-launcher.jpg) | ![Phainon power menu](screenshots/phainon-power.jpg) |

The dashboard's full views (music, messages, screen time, network, wallpapers):

![Phainon dashboard views](screenshots/phainon-views.jpg)

### Khaslana

![Khaslana desktop](screenshots/khaslana-desktop.jpg)

| Dashboard | Control panel |
|---|---|
| ![Khaslana dashboard](screenshots/khaslana-dashboard.jpg) | ![Khaslana control panel](screenshots/khaslana-control.jpg) |

| Launcher | Power menu |
|---|---|
| ![Khaslana launcher](screenshots/khaslana-launcher.jpg) | ![Khaslana power menu](screenshots/khaslana-power.jpg) |

The dashboard's full views (music, messages, screen time, network, wallpapers):

![Khaslana dashboard views](screenshots/khaslana-views.jpg)

### Flame Reaver

![Flame Reaver desktop](screenshots/reaver-desktop.jpg)

| Dashboard | Control panel |
|---|---|
| ![Flame Reaver dashboard](screenshots/reaver-dashboard.jpg) | ![Flame Reaver control panel](screenshots/reaver-control.jpg) |

| Launcher | Power menu |
|---|---|
| ![Flame Reaver launcher](screenshots/reaver-launcher.jpg) | ![Flame Reaver power menu](screenshots/reaver-power.jpg) |

The dashboard's full views (music, messages, screen time, network, wallpapers):

![Flame Reaver dashboard views](screenshots/reaver-views.jpg)

## What you get

**On the desktop**

- **A clock set into the wallpaper.** A large clock stands behind each form's character: whatever is near in the picture (him, his cape, the tendrils) passes in front of it. Each form adds one quiet piece in the same layer: Phainon a sun path across the sky, Khaslana the twelve Flame-Chase embers, the Flame Reaver a three-line readout of weather, battery and what's playing.
- **No bar.** A dynamic island at the top centre (clock, date, weather, what's playing, notifications), with a small workspace tab on the left and a status tab on the right. In Khaslana the island wears a pair of small golden wings. Scroll on it to move between workspaces.
- **Island pop-ups.** Volume, brightness, caps lock, mic mute, touchpad and workspace changes show for a moment in the island instead of DMS's own pop-ups. Each one follows its on/off switch in DMS Settings. With Do not disturb set to end at a time, the island says until when ("Muted until 18:00").
- **Dock** at the bottom edge with the current workspace's windows. In Phainon the icons grow a little under the pointer; each form marks the focused app its own way.
- **A little Phainon chimera** in the corner that sleeps when your CPU is idle and runs faster the harder it works.

**Panels** (each form draws its own; the keybinds and what's inside stay the same)

- **Dashboard** that drops out of the island: clock, system load, calendar with your events, Flame-Chase, weather, notifications, music, network, screen time and wallpapers on one page, laid out as Phainon's temple front, Khaslana's obsidian mosaic held together with golden blood, or the Flame Reaver's shattered pane. Each card opens its own full view in the form's frame (Phainon's parchment sheet, Khaslana's gold-seamed blocks over the Black Tide, the Flame Reaver's shards). The clock opens a full time view: the date in full, a world clock on a small globe (add cities by searching), a timer and a stopwatch.
- **Notifications live in the dashboard.** The island bell and the notifications keybind open the dashboard's messages view. It lists the messages still open first, then the ones DMS saved to its history, grouped by app; "Clear all" clears both. A notification that arrives while a panel is open shows along that panel's top edge.
- **The Flame-Chase.** The twelve Titans' flames, earned one by one by things you do: start the shell, walk all three forms, let music play, open the system monitor, push the CPU past 90 %, and so on. Hover a Titan to see how to earn it.
- **Control panel** from the right corner: a scroll unrolled from the island (Phainon), the Black Tide over the whole screen (Khaslana), or a torn shard over the right half (Flame Reaver). It keeps the first page short (volume, brightness and mic, Wi-Fi, Bluetooth, sound output and input, battery and Do not disturb); every menu opens just under the switch it belongs to. Four sections hold the rest: Connectivity (Wi-Fi networks, Bluetooth devices, and a search for new ones to pair), Sound, Power and System (night mode, running apps, plugins, tray, clipboard, "Return to stock DMS").
- **Launcher** on the same keybind DMS already uses: an arch hanging from the island (Phainon), a drawer down the left edge with its sections numbered like acts (Khaslana), or a console along the bottom whose results grow upward (Flame Reaver). Everything stock DMS's launcher finds still shows up.
- **Clipboard history, notepad and system monitor** drop out of the island in one frame per form: a parchment sheet (Phainon), an obsidian plate (Khaslana), a torn shard (Flame Reaver). Copied pictures get a large preview in the clipboard history, and the monitor shows each process's CPU share in the form's own bars.
- **Power menu** with lock, sleep, log out, restart DMS ("Rekindle"), restart and shut down. Hibernate ("Slumber") shows up too when your swap and kernel settings allow it. The actions form a loop with the chosen one always in the middle: medallions riding the sun's path (Phainon), black cards over the Black Tide (Khaslana), shards around his point of impact (Flame Reaver). The arrow keys turn it, clicking a side option brings it to the middle, and every action but Lock needs a second press.
- **Every DMS window in the form's frame.** Settings, password and pairing prompts, questions, the keys sheet, the file browser, pickers and right-click menus sit on the form's parchment, obsidian plate or ash shard, with its own switches, fields, dropdowns, buttons and titles.
- **Lock screen** built around DMS's own password box: the time in a navy medallion inside a laurel wreath, with the sun on its path (Phainon); a stage with drapes, a playbill with the time and footlights for the Flame-Chase (Khaslana); shards with the cycle and a quote (Flame Reaver).

**Motion and sound**

- **Window animation:** windows open and close with a short black-and-red eclipse, the "Black Tide" from Phainon's technique, in every form and every power mode, on battery and Power Saver too.
- **Opening and closing cinematics** play at the first start after boot and before a restart or shut down. Esc or a click skips them.
- **Lock screen video.** After 15 seconds on the lock screen with no input, a muted video plays full screen. On battery it plays a lighter 720p copy, dims the screen, and stays off below 20 %. Any key or mouse move brings the password field back.
- **Sounds:** a short sound when the form changes and a glass chime when the battery runs low. They follow DMS's sounds switch.
- **Forms by the hour, or by the sun:** the form can change by itself at set times, or with Phainon at sunrise and Khaslana at sunset.

**Extras**

- **Your apps follow the form:** GTK apps, kitty, Fastfetch, btop, a Starship prompt with the cycle count, and (through DMS) Zed, Vesktop, Qt apps, Firefox and more. See [SETUP.md](SETUP.md).
- **GTK windows in the form's style,** including the file picker apps open for "Open" and "Save": parchment, lapis and round corners (Phainon), obsidian with a red title bar, gold seams and square corners (Khaslana), or ash with thin violet lines (Flame Reaver).
- **Boot splash** (optional, needs sudo): one form's splash, or the "Eternal Recurrence" cinematic with this boot's cycle number. See [SETUP.md](SETUP.md#5-boot-splash-optional-needs-sudo-and-login-screen).
- **Small nods to the story**, like the cycle counter that starts at 33,550,336 and goes up by one each boot.
- **A safety net.** If the shell ever fails to start, it puts stock DMS back by itself.
- **Light on a laptop.** The Flame Reaver form barely moves, battery mode trims animation, and nothing heavy runs on a timer. Measurements are in [PERFORMANCE.md](PERFORMANCE.md).

## Before you start

**This isn't a standalone shell.** To use it, niri has to be your compositor and DankMaterialShell has to be the shell you actually run every day. The rice swaps out stock DMS's interface for its own, while DMS keeps running underneath doing the real work (settings, plugins, notifications, network, and so on). Think of it as a theme, just one that changes the whole look instead of only the colours. No niri or no DMS means nothing for it to sit on.

You need:

- niri
- DankMaterialShell **2.0**, running as the usual `dms` systemd user service
- `git`, `rsync`, `python3`, `curl` and `tar`
- PipeWire's `pw-play` for the sounds (optional)

**Fair warning:** I built this for my own laptop (Fedora, niri, one 1080p screen) and that is the only machine it has been used on. It works for me; it might not work the same on yours. Different distro, screen size, DMS version or hardware can all trip it up, so treat it as something to try and tinker with, not a polished release.

This is built on the DMS 2.0 interface. On another DMS version it may not load. If that happens the safety net simply drops you back to stock DMS.

## Known issues

- **"Clear all" also wipes saved history.** In the messages view it dismisses the open notifications and deletes the ones DMS saved to its history. There is no undo.
- **Message bodies show one line.** Longer notifications are cut off in the messages view; open the app to read the rest.
- **Your location shows in two views.** The weather view names your city (DMS looks it up from your IP) and the time view shows your time zone. Mind that before you share screenshots.
- **Screen time colours leak into DMS Settings.** The weekly chart takes the form's colours, and DMS Settings' screen time page uses the same chart, so it shows them there too.
- **Not everything has been seen on screen.** The lock screen's golden-blood marks (Khaslana) were only checked in code, not on a real lock.
- **The sandbox can crash after many reloads.** The nested test copy (`dev/run-nested.sh`) crashed once after a long run of hot reloads and went blank. Close it and start it again.
- **GTK windows only go so far.** GTK can't draw cut corners or torn edges, so apps and file pickers get the form's colours, title font, borders and corners, not the shell's exact shapes. A GTK app that's already open keeps the old form's look until you reopen it. DMS's own file browser (used in DMS Settings) is the one drawn exactly like the mockup.
- **One machine only.** See the fair warning above: Fedora, niri, one 1080p laptop screen.

## Install

```sh
git clone https://github.com/MSpider3/Phainon_niri_rice.git
cd Phainon_niri_rice
sh install.sh
```

That copies the fonts, the three wallpapers (into `~/Pictures/Phainon`), the cinematics and art, the theme and a tiny form-switch plugin, then restarts DMS with the new look. [SETUP.md](SETUP.md) walks through every step and the optional extras. After a `git pull`, run `sh install.sh update`. Your bar will blink for a few seconds.

Want the matching icons, folders, cursors and GTK theme too? Run it like this instead (downloads about 185 MB: [Gruvbox Plus](https://github.com/SylEleuth/gruvbox-plus-icon-pack) icons, Bibata cursors and adw-gtk3). Add `--system-font` to make Coreflame Display the font of your other apps as well; `sh install.sh --help` lists every option.

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

Or let it change by itself with `dms ipc call formschedule on` (set times) or `dms ipc call formschedule sun on` (sunrise and sunset; needs DMS weather on).

Your keybinds don't change. Whatever opens the DMS launcher, clipboard, process list or power menu on your setup now opens the themed one.

## Going back

```sh
sh coreflame.sh off
```

Stock DMS comes back with the theme, wallpaper cycling and icons you had before. There is also a "Return to stock DMS" button in the control panel's System section (double-click it).

## Making it yours

- **Wallpapers:** replace the three pictures in `~/Pictures/Phainon` (keep the file names), or change the names in `overlay/Common/Form.qml`. The desktop clock's depth only fits the shipped pictures; with your own, the clock shows without the character in front.
- **Colours:** everything comes from `dms-config/theme/coreflame/theme.json`.
- **The interface:** all custom pieces live in `overlay/`. Edit, run `sh install.sh build`, and the shell picks it up.
- **Try changes safely:** `sh dev/run-nested.sh ~/.cache/cfn khaslana` opens a sandboxed copy in its own window, so you can break things without touching your real session.

A heads-up: while a form is active, DMS wallpaper cycling is switched off so the form's wallpaper stays put. It comes back when you leave.

## Credits

- [DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell) by Avenge Media, MIT. A copy of its 2.0 interface is in `vendor/` and this rice is a layer on top of it.
- [Gruvbox Plus icon pack](https://github.com/SylEleuth/gruvbox-plus-icon-pack) by SylEleuth, GPL-3.0. The folder artwork in `icons/` comes from it and stays under that licence.
- The desktop clock's depth masks were made with Depth Anything V2 Small (Apache-2.0) and anime-seg (Apache-2.0); no model ships with the rice. The world clock's land map comes from Natural Earth (public domain).
- Fonts in `fonts/`: Marcellus, Cinzel, Chakra Petch and Cormorant Garamond, all under the SIL Open Font License. Coreflame Display and Coreflame Numerals were drawn for this project by `tools/coreflame_font.py`.
- The sounds are made from Kenney's "Impact Sounds" and "RPG Audio" packs ([kenney.nl](https://kenney.nl)), CC0.
- The chimera sprite is from a fan-made Chimera Phainon desktop pet. The wallpapers are fan art. I didn't make either and all credit goes to their artists. If one of them is yours and you'd like credit or removal, open an issue.
- Phainon and Honkai: Star Rail belong to HoYoverse. This is a fan project and is not affiliated with them.

Everything written for this project is under the [MIT licence](LICENSE).
