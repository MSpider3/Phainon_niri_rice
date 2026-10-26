# Setting up the Phainon rice

This guide takes you from a working niri + DankMaterialShell desktop to the full rice: the shell, the three forms, icons, cursors, terminal looks, and (optionally) the boot splash.

> Built and tested on one laptop (Fedora 44, niri, a single 1080p screen, DMS 1.6.2). It should work on similar setups, but treat it as something to try, not a polished release. Every step can be undone; see [Going back](#going-back).

## 1. What you need first

| Needed | Why |
|---|---|
| **niri** | the compositor |
| **DankMaterialShell 1.6.2**, running as the `dms` systemd user service (the normal DMS install) | the rice is a new face for the DMS 1.6.2 interface; other DMS versions may not load it |
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

Leave out `--icons` if you don't want the icon, folder, cursor and GTK theme packs (about 185 MB download).

`install.sh` does all of this, in order:

1. Copies the fonts to `~/.local/share/fonts/coreflame/`.
2. Copies the three wallpapers to `~/Pictures/Phainon/` and the opening and closing cinematics to `~/.config/coreflame/cinematics/` (it never overwrites files already there).
3. Copies the Coreflame theme and the small form-switch plugin into `~/.config/DankMaterialShell/`.
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

**Wallpapers:** each form uses its picture in `~/Pictures/Phainon/` (`phianon.png`, `khaslana.png`, `flame reaver.jpeg`). Replace those files and keep the names to use your own.

**The dock:** move the pointer to the bottom edge of the screen. It shows the windows of the current workspace; scroll on it to move between columns.

**Opening and closing cinematics:** the opening plays full screen the first time the shell starts after a boot; the closing plays when you pick Restart or Shut down in the power menu, and the machine restarts or shuts down when it ends. Esc or a click skips either one. Preview them with `dms ipc call cinematic play opening` (or `closing`). They live in `~/.config/coreflame/cinematics/` as `opening.mkv` and `closing.mkv`: replace those files to use your own clips, or delete them to turn the cinematics off.

**Keybinds are unchanged.** Whatever opens the DMS launcher, clipboard, process list, power menu or control centre on your setup now opens the Coreflame version.

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

## 5. Boot splash (optional, needs sudo) and login screen

**Boot splash (Plymouth):** pick one form, since it's fixed at boot. It rebuilds the initramfs, which takes about a minute.

```sh
sudo sh plymouth/install.sh khaslana     # or phainon / reaver
sudo sh plymouth/install.sh revert       # back to your previous splash
```

**Login screen (dms-greeter):** nothing to install. DMS's login screen reads your live DMS settings, so after you log out it shows the form you were using, in that form's colours and wallpaper. (If your wallpaper or fonts live somewhere the login screen can't read, it falls back to a plain colour or a default font.)

## 6. Updating

```sh
git pull
sh build.sh
systemctl --user restart dms.service
```

`build.sh` assembles the shell from `vendor/` (the stock DMS 1.6.2 interface) plus `overlay/` (everything the rice changes), straight into the live folder.

If you tinker with `overlay/`, try changes in a sandboxed copy first; it opens in its own window and doesn't touch your session:

```sh
sh build.sh ~/.cache/coreflame-test
COREFLAME_DIR=~/.cache/coreflame-test sh dev/run-nested.sh ~/.cache/cfn khaslana
```

## Going back

Any of these returns you to stock DMS with the theme, wallpaper cycling, icons, cursor and GTK settings you had before:

- double-click **Return to stock DMS** at the bottom of the control panel
- run `sh coreflame.sh off`
- pick another theme in DMS Settings

**Safety net:** if the rice's shell ever fails to start or loses its backend, it switches back to stock DMS by itself and notes why in `~/.config/coreflame/fallback.log`. `sh coreflame.sh selftest` proves this works (run it while on stock DMS).

## Troubleshooting

| Problem | Try |
|---|---|
| Not sure which shell is running | `sh coreflame.sh status` |
| It went back to stock on its own | read `~/.config/coreflame/fallback.log` |
| Something looks wrong after an edit | `journalctl --user -u dms.service -b \| grep -i "error\|TypeError"` |
| Forms don't switch by the hour | `dms ipc call formschedule status`; it has to say `on` |
| GTK apps in the wrong colours | close and reopen the app; `--icons` must have installed adw-gtk3 |

## What's where

| Path | What it is |
|---|---|
| `install.sh` | one-step install (start here) |
| `coreflame.sh` | `on`, `off`, `status`, `selftest` |
| `build.sh` | builds the shell from `vendor/` + `overlay/` |
| `overlay/` | everything the rice adds or changes in the DMS interface |
| `vendor/dms-1.6.2/` | untouched stock DMS interface it builds on |
| `dms-config/` | the Coreflame theme and form-switch plugin |
| `tools/icons.sh` | icon, folder, cursor and GTK theme packs |
| `tools/guard.sh` | the safety net (installed to `~/.config/coreflame/`) |
| `plymouth/` | boot splash themes and their installer |
| `fonts/`, `wallpapers/`, `cinematics/` | copied in by `install.sh` |
| `dev/` | the sandbox for testing changes |

The character art used by Fastfetch and the boot splash, and the footage in the cinematics, are official Honkai: Star Rail material owned by HoYoverse; this is a fan project.
