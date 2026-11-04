# Setting up the Phainon rice

This guide takes you from a working niri + DankMaterialShell desktop to the full rice: the shell, the three forms, icons, cursors, terminal looks, and (optionally) the boot splash.

> Built and tested on one laptop (Fedora 44, niri, a single 1080p screen, DMS 2.0). It should work on similar setups, but treat it as something to try, not a polished release. Every step can be undone; see [Going back](#going-back).

## 1. What you need first

| Needed | Why |
|---|---|
| **niri** | the compositor |
| **DankMaterialShell 2.0**, running as the `dms` systemd user service (the normal DMS install) | the rice is a new face for the DMS 2.0 interface; other DMS versions may not load it |
| `git`, `rsync`, `python3`, `curl`, `tar` | used by the scripts |
| PipeWire (`pw-play`) | the form-change sounds |

Optional, for the terminal touches: **kitty**, **fastfetch**, **starship**, **btop**.

Start DMS at least once before installing, so it has written its settings.

## 2. Install

```sh
git clone https://github.com/MSpider3/Phainon_niri_rice.git
cd Phainon_niri_rice
sh install.sh --icons
```

Leave out `--icons` if you don't want the icon, folder, cursor and GTK theme packs (about 185 MB download). Add `--system-font` to make Coreflame Display the font of your other apps too. `sh install.sh --help` lists everything.

`install.sh` does all of this, in order:

1. Copies the fonts to `~/.local/share/fonts/coreflame/`. These include Coreflame Display, the shell's clock and counter font (rebuild it with `python3 tools/coreflame_font.py`). With `--system-font` it also becomes your default system font (`fonts/60-coreflame-display.conf` goes into `~/.config/fontconfig/conf.d/`, and the GTK font is set to it). To use it only for numbers instead, copy `fonts/60-coreflame-numerals.conf` there by hand. Terminals and code keep their own font. To undo, delete the file and set the GTK font back (`gsettings set org.gnome.desktop.interface font-name '<your font> 11'`).
2. Copies the three wallpapers to `~/Pictures/Phainon/` and the opening and closing cinematics, the lock-screen video (plus a lighter 720p copy for battery) and two pieces of art (Phainon's tarot card beside the power menu's sun path, and the Khaslana mural, which the current lock screen no longer uses) to `~/.config/coreflame/cinematics/`. It never overwrites files already there.
3. Copies the Coreflame theme and the small form-switch plugin into `~/.config/dms/`.
4. With `--icons`, runs `tools/icons.sh`:
   - the Gruvbox Plus icons, plus three folder sets tinted per form;
   - the Bibata cursors;
   - the adw-gtk3 GTK theme.
5. Saves your current DMS theme setup to `~/.config/coreflame/before.json`, so you can go back exactly.
6. Keeps a copy of your Fastfetch config, and gives btop a config if it has none.
7. Switches DMS to the Coreflame theme, builds the shell into `~/.config/quickshell/coreflame/`, and restarts DMS with it.

Your bar blinks for a few seconds, then you're on the **Phainon** form. Your DMS settings, plugins and niri keybinds stay as they were.

## 3. Using it

**Switch form:** use the buttons at the top of the control panel (click the right-hand corner tab), or a terminal:

```sh
dms ipc call form set phainon     # or khaslana / reaver
```

**Forms by the hour:** in the control panel, click "Change form by the hour" to switch it on and set each form's start time. The default is Phainon 08:00, Khaslana 17:00, Flame Reaver 01:00. From a terminal:

```sh
dms ipc call formschedule on
dms ipc call formschedule set khaslana 17:30
dms ipc call formschedule status
```

**Forms by the sun:** turn on "Follow the sun" in the same place (or `dms ipc call formschedule sun on`). Phainon then starts at sunrise and Khaslana at sunset; Flame Reaver keeps its set time. The control panel shows today's sunrise and sunset. The times come from the location DMS weather uses, so weather has to be on; with no location it uses the set times and says so.

**Wallpapers:** each form uses its picture in `~/Pictures/Phainon/` (`phianon.png`, `khaslana.png`, `flame reaver.jpeg`). Replace those files and keep the names to use your own.

**Control panel:** each form lays it out its own way: a scroll unrolled from the island (Phainon), the Black Tide over the whole screen (Khaslana), a torn shard over the right half (Flame Reaver). The first page has the sliders, Wi-Fi, Bluetooth, sound devices, battery and Do not disturb. Menus (Wi-Fi networks, sound devices and so on) open just under the switch they belong to. Click Connectivity, Sound, Power or System to open the rest. Connectivity lists nearby Wi-Fi networks (click one to join) and your Bluetooth devices; "Search for new devices" lists unpaired ones nearby, and a click pairs them. The search stops when you close the section. `dms ipc call control-center openWith sound` opens it on a section (`connectivity`, `sound`, `power`, `system`).

**Island pop-ups:** volume, brightness, caps lock, mic mute, touchpad and workspace changes show for a moment in the island, in the form's style. Each follows its switch in DMS Settings (the on-screen display options). DMS ships the workspace one switched off; turn on its Workspace OSD to see it.

**Do not disturb with an end time:** the island shows until when, like "Muted until 18:00". The Coreflame panels only switch it on and off; set an end time from a terminal or a keybind with `dms ipc call notifications enableDoNotDisturbFor 60` (minutes). Without an end time nothing extra shows.

**Dashboard:** click the island to open it. The same cards are laid out per form: Phainon's temple front, Khaslana's obsidian mosaic, the Flame Reaver's shattered pane. Each card opens a full view in the form's frame (Phainon's parchment sheet, Khaslana's gold-seamed blocks over the Black Tide, the Flame Reaver's shards); the back arrow or Esc returns to the summary. The clock card opens Time: the time with seconds, the full date, week and day of the year, a world clock on a small globe (shaded for day and night), a timer and a stopwatch. Add a city by typing in "Add a city…" (this search needs the internet; the times themselves come from your system's time zone data). Up to five cities; hover one and click × to remove it. They are kept in `~/.config/coreflame/worldclock.json`. The Wallpapers card opens the wallpaper picker.

**Notifications:** they live in the dashboard now. The island bell or `dms ipc call notifications toggle` opens the dashboard's messages view, grouped by app: the messages still open first, then the ones DMS saved to its history. Each app has "clear app", each message an ×, and Do not disturb and Clear all sit at the bottom. Clear all also deletes the saved history, with no undo. A notification that arrives while a panel is open shows along that panel's top edge.

**Flame-Chase:** the twelve Titans' flames on the dashboard, earned one by one by things you do on the machine: start the shell, walk all three forms, stay awake six hours, charge to full, let music play, read the forecast, push the CPU past 90 %, receive a notification, and use the system monitor, power menu, clipboard history and launcher. Hover a Titan to see how to earn it. Progress is kept in `~/.config/coreflame/coreflames.json`.

**Power menu:** Lock, Sleep, Hibernate (Slumber), Log out, Restart DMS (Rekindle), Restart, Shut down. Hibernate only appears when your swap is at least as big as your RAM and `resume=` is on the kernel command line. Restart DMS restarts the shell, not the machine. The actions form a loop with the chosen one in the middle: the arrow keys turn it, a click on a side option brings it to the middle, and every action but Lock needs a second press (Enter or a click) to act. Phainon's actions ride the sun's path, Khaslana's are black cards over the Black Tide, the Flame Reaver's are shards.

**Window animation:** windows open and close with a short black-and-red eclipse, the same in every form, while on mains and outside the Power Saver profile. On battery or Power Saver the shell adds nothing, so niri plays the animation from your own config. DMS's "reduce motion" doesn't turn the eclipse off (DMS 2.0 switches that setting on from an older island-only toggle), but it does still the shell's own panels.

**The desktop clock:** a large clock set into the wallpaper, behind the form's character: whatever is near in the picture (him, his cape, the tendrils) passes in front of it. Each form adds one small piece in the same layer: Phainon a sun path across the sky (sunrise to sunset, the sun at the current time), Khaslana the twelve Flame-Chase embers, the Flame Reaver a three-line readout (weather, battery, what's playing). The depth comes from a mask per wallpaper made with Depth Anything V2 Small and anime-seg, so it only works on the three form wallpapers as shipped; on any other wallpaper the clock still shows, without the depth. It hides in the overview and sits under your windows.

**The dock:** move the pointer to the bottom edge of the screen. It shows the windows of the current workspace; scroll on it to move between columns. In Phainon the icons grow a little under the pointer (not on the Power Saver profile). The focused app gets a small pill in Phainon, a gold plate in Khaslana and a violet line in Flame Reaver.

**Clipboard:** copied pictures show a large preview in the clipboard history.

**Lock screen:** each form lays its own picture around DMS's password box and notifications, which stay as they are. Phainon keeps the sky open: the sun on its path at the hour, the time in a navy medallion inside a laurel wreath, the quote on a ribbon. Khaslana is a stage: valance, two drapes, a playbill with the time, the Black Tide on the stage floor and footlights for the Flame-Chase. The Flame Reaver has shards on his crack with the cycle and the quote. Nothing on it animates, and the clock updates once a minute.

**Opening and closing cinematics:** the opening plays full screen the first time the shell starts after a boot; the closing plays when you pick Restart or Shut down in the power menu, and the machine restarts or shuts down when it ends. Esc or a click skips either one. Preview them with `dms ipc call cinematic play opening` (or `closing`). They live in `~/.config/coreflame/cinematics/` as `opening.mkv` and `closing.mkv`: replace those files to use your own clips, or delete them to turn the cinematics off.

**Lock-screen video:** after 15 s on the lock screen with no input, `~/.config/coreflame/cinematics/lock.mp4` plays muted on a loop. On battery it plays the lighter `lock-lite.mp4` instead, dims the screen to 60 % until the next input, and doesn't start below 20 % battery. It pauses while the screen is off. Any key or mouse movement brings the lock screen back (that key isn't typed). Delete the files to turn it off.

**Launcher, clipboard, notepad and system monitor:** the launcher is an arch hanging from the island in Phainon, a drawer down the left edge in Khaslana and a console along the bottom in the Flame Reaver; everything stock DMS's launcher finds still shows. The clipboard history, notepad and system monitor drop out of the island in one frame per form (a parchment sheet, an obsidian plate, a torn shard).

**DMS's own windows:** Settings, password and pairing prompts, questions, the keys sheet, the file browser, pickers and right-click menus take the form's frame, switches, fields and buttons.

**Sounds:** a short sound when the form changes and a glass chime when the battery runs low, played with `pw-play`. They follow the sounds switch in DMS Settings.

**Keybinds are unchanged.** Whatever opens the DMS launcher, clipboard, notepad, process list, power menu or control centre on your setup now opens the Coreflame version.

## 4. Terminal touches (optional)

These follow the form by themselves once set up.

- **kitty:** DMS writes the colours to `~/.config/kitty/dank-theme.conf`. Make sure your `kitty.conf` has:
  ```
  include dank-theme.conf
  ```
- **Fastfetch:** nothing to do. On every form change the shell points `~/.config/fastfetch/config.jsonc` at that form's layout and picture. Your own config was saved to `~/.config/coreflame/fastfetch-config.jsonc.before` and comes back when you leave the rice.
- **btop:** pick the theme named `coreflame` (`color_theme = "coreflame"` in `~/.config/btop/btop.conf`; `install.sh` sets this if you had no btop config).
- **Starship:** add this to `~/.config/starship.toml` to start your prompt with the cycle count in the form's colour:
  ```toml
  format = "${custom.cycle}$all"

  [custom.cycle]
  command = "cat ~/.config/coreflame/prompt"
  when = "test -f ~/.config/coreflame/prompt"
  shell = ["sh"]
  unsafe_no_escape = true
  format = "$output "
  ```

GTK apps: new windows open in the current form's colours. An app that's already open keeps the colours it started with until you close and reopen it (that's how GTK4 works). Apps left running in the background, like Files, are restarted for you after a form change.

**More apps:** DMS can write the form's colours into other apps too. `sh coreflame.sh on` (and so `install.sh`) switches this on for the ones you have installed; on an existing install run `sh coreflame.sh apps` once. `sh coreflame.sh off` puts those DMS settings back. The colours are rewritten on every form change. A few apps need you to pick the theme once:

| App | What DMS writes | What to do once |
|---|---|---|
| Zed | `~/.config/zed/themes/dank-zed-theme.json` | pick the theme **DankShell Light** or **DankShell Dark** |
| Vesktop, Vencord, Equibop | `themes/dank-discord.css` in the app's config folder | turn that theme on in the app's Themes settings |
| KDE / Qt apps | `~/.local/share/color-schemes/DankMatugen.colors`, `qt5ct`/`qt6ct` `colors/matugen.conf` | pick **DankMatugen** (KDE colours, or qt5ct / qt6ct) |
| Alacritty | `~/.config/alacritty/dank-theme.toml` | `import = ["dank-theme.toml"]` under `[general]` |
| foot | `~/.config/foot/dank-colors.ini` | `include=~/.config/foot/dank-colors.ini` |
| Ghostty | `~/.config/ghostty/themes/dankcolors` | `theme = dankcolors` |
| WezTerm | `~/.config/wezterm/colors/dank-theme.toml` | `config.color_scheme = "dank-theme"` |
| Firefox, Zen | `~/.config/dms/firefox.css`, `zen.css` | `@import` it from your profile's `userChrome.css` (or use Pywalfox, which DMS updates itself) |
| Neovim | `~/.config/nvim/colors/dms.lua` | `:colorscheme dms` |
| dgop, fcitx5, Emacs, VS Code | their own theme files | nothing, or pick the `dms` / `dank` theme in the app |

Only apps found on your machine get turned on; anything you install later is picked up by running `sh coreflame.sh apps` again.

GTK, kitty and niri are left as they are: the steps above already cover them.

## 5. Boot splash (optional, needs sudo) and login screen

**Boot splash (Plymouth):** pick one form, since it's fixed at boot. It rebuilds the initramfs, which takes about a minute.

```sh
sudo sh plymouth/install.sh khaslana     # or phainon / reaver
sudo sh plymouth/install.sh recurrence   # the Eternal Recurrence cinematic
sudo sh plymouth/install.sh revert       # back to your previous splash
```

`recurrence` plays `cinematics/boot.mp4` while the machine boots. At its end it shows this boot's cycle number (the same one the shell counts) with "Eternal Recurrence / Booting into the Simulation". A small service, `coreflame-recurrence.service`, sends the number once your disk is mounted; if it's late, the two lines still show. Shutdown and restart hold that last shot, still, with the number and "Eternal Recurrence / Closing the Simulation". There's no sound. It needs ffmpeg with H.264 (on Fedora, ffmpeg from RPM Fusion), and adds about 30 MB to the initramfs. To use your own clip: `sudo sh plymouth/install.sh recurrence /path/to/video.mp4`. The number's place and timing are set at the top of `plymouth/coreflame-recurrence/coreflame-recurrence.script`, and its digits and lines are drawn by `python3 tools/recurrence_splash.py`.

**Login screen (dms-greeter):** nothing to install. DMS's login screen reads your live DMS settings, so after you log out it shows the form you were using, in that form's colours and wallpaper. (If your wallpaper or fonts live somewhere the login screen can't read, it falls back to a plain colour or a default font.)

## 6. Updating

```sh
git pull
sh install.sh update
```

`update` refreshes the fonts, theme and plugin, assembles the shell from `vendor/` (the stock DMS 2.0 interface) plus `overlay/` (everything the rice changes) into the live folder, and restarts DMS. `sh install.sh build` does only the assembling.

If you tinker with `overlay/`, try changes in a sandboxed copy first; it opens in its own window and doesn't touch your session:

```sh
sh install.sh build ~/.cache/coreflame-test
COREFLAME_DIR=~/.cache/coreflame-test sh dev/run-nested.sh ~/.cache/cfn khaslana
```

## Going back

Any of these returns you to stock DMS with the theme, wallpaper cycling, icons, cursor and GTK settings you had before:

- double-click **Return to stock DMS** in the control panel's System section
- run `sh coreflame.sh off`
- pick another theme in DMS Settings (the app colour settings from `coreflame.sh apps` stay on until you run `sh coreflame.sh off`)

`off` puts the app colour settings back, but the theme files DMS already wrote for those apps (for example Zed's "DankShell" theme) stay where they are, frozen in the last form's colours. If you picked one of them inside an app, pick your old theme there again.

**Safety net:** if the rice's shell ever fails to start or loses its backend, it switches back to stock DMS by itself and notes why in `~/.config/coreflame/fallback.log`. `sh coreflame.sh selftest` proves this works (run it while on stock DMS).

## Troubleshooting

| Problem | Try |
|---|---|
| Not sure which shell is running | `sh coreflame.sh status` |
| It went back to stock on its own | read `~/.config/coreflame/fallback.log` |
| Something looks wrong after an edit | `journalctl --user -u dms.service -b \| grep -i "error\|TypeError"` |
| Forms don't switch by the hour | `dms ipc call formschedule status`; it has to say `on` |
| Forms don't follow the sun | `formschedule status` says "no location known": turn on weather in DMS Settings |
| No workspace pop-up in the island | turn on the Workspace OSD in DMS Settings (off by default) |
| GTK apps in the wrong colours | close and reopen the app; `--icons` must have installed adw-gtk3 |

## What's where

| Path | What it is |
|---|---|
| `install.sh` | install (start here), `update`, and `build` (assemble the shell from `vendor/` + `overlay/`) |
| `coreflame.sh` | `on`, `off`, `status`, `apps`, `selftest` |
| `overlay/` | everything the rice adds or changes in the DMS interface |
| `vendor/dms-2.0.0/` | untouched stock DMS interface it builds on |
| `dms-config/` | the Coreflame theme and form-switch plugin |
| `tools/icons.sh` | icon, folder, cursor and GTK theme packs |
| `tools/guard.sh` | the safety net (installed to `~/.config/coreflame/`) |
| `tools/coreflame_font.py` | builds the Coreflame Display and Numerals fonts |
| `PERFORMANCE.md` | measured CPU, memory and battery notes |
| `plymouth/` | boot splash themes and their installer |
| `fonts/`, `wallpapers/`, `cinematics/` | copied in by `install.sh` |
| `overlay/assets/coreflame/depth/` | the desktop clock's depth masks, one per form wallpaper |
| `dev/` | the sandbox for testing changes (`run-nested.sh`) and the tests |

The character art used by Fastfetch and the boot splash, and the footage in the cinematics, are official Honkai: Star Rail material owned by HoYoverse; this is a fan project. The depth masks were made from the three wallpapers with [Depth Anything V2 Small](https://huggingface.co/onnx-community/depth-anything-v2-small) and [anime-seg](https://github.com/SkyTNT/anime-segmentation); the land map on the world clock's globe is drawn from [Natural Earth](https://www.naturalearthdata.com/) (public domain).
