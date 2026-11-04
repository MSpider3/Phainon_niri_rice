# Coreflame performance and stability notes

Findings from an audit of the shell (November 2026), ranked by how much they hurt, and what was
changed. Measured on a 4-thread laptop on battery under niri.

## Measured

| | Before | After |
|---|---|---|
| Idle CPU of the shell (90 s sample) | 1.6 %, bursts to 12 % | 0.35 % |
| Main-thread wakeups per second | about 28 | about 11 |
| Shell memory | 604–642 MB after an hour | 518–523 MB just after start |
| Theme builds (matugen) per login | 2 (light, then the real form) | 1 |
| Fresh start in a clean sandbox | 364 MB | 360 MB |

The memory "after" figure is taken just after a start; compare again after an hour of use. The
fresh-start figure is unchanged, as expected: the savings come from what no longer piles up during
a session.

## Stability: why each login brought a new bug

1. **The form was chosen after the shell started.** Settings load in pieces, so the shell first
   came up as Phainon (the default), then the schedule switched it about 2 s later over IPC. That
   one late switch caused most login bugs: a light theme build then a dark one, the wallpaper
   changing under the opening cinematic, the old wallpaper staying with the new form's cut-out,
   and a transformation toast and sound at every login.
   **Fixed:** `guard.sh preselect` runs just before DMS starts and writes this hour's form,
   wallpaper and light/dark into the settings, so the shell starts in the right form. Installed by
   `coreflame.sh arm`.
2. **Form side effects ran 3–4 times per login** (wallpaper, desktop files, sound), once for each
   intermediate form value. **Fixed:** they wait 300 ms for the form to stop changing and run once.
3. **The startup switch counted as a manual one** (island animation, toast, sound).
   **Fixed:** nothing reacts to form changes until the shell has settled (4 s).
4. **The fail-safe checked the backend at a single moment** and could drop to stock DMS when the
   backend was briefly slow. **Fixed:** it falls back only if the backend never connected.

## Performance and battery

1. **Panels never unloaded.** The dashboard, control panel, clipboard, process list, power menu
   and cinematic player stayed in memory after their first use, and hidden control-panel widgets
   kept polling (the network indicator every 2 s). **Fixed:** a closed panel is unloaded after a
   minute. The launcher and notepad stay loaded, so they open instantly.
2. **The lock-screen video kept decoding with the screen off**, and on battery it played the full
   1080p clip at full brightness. **Fixed:** it pauses while the screen is off. On battery it
   loops a 720p, 24 fps copy (`cinematics/lock-lite.mp4`; shell CPU about 3 % instead of 4.2 %,
   20–35 MB less memory), dims the laptop panel to 60 % until the next input, and does not start
   below 20 % battery. On mains it loops the full clip as before.
3. **The depth clock blurred the whole screen** to put a glow under a few lines of text.
   **Fixed:** only a box around the time and date is blurred.
4. **The Chimera mascot animated whenever CPU load passed 15 %**, including on battery and while
   locked. **Fixed:** it animates only on full motion and stops while locked.
5. **The edge dock rebuilt its window list on every window-title change**, even while hidden.
   **Fixed:** it builds only while visible.
6. **"Reduce motion" in DMS settings was ignored.** **Fixed:** it now means the still tier.

## The app-open animation

Under Power Saver the shell replaced your own niri window animation with a 150 ms linear fade
that looked like no animation at all. Otherwise it used the 650 ms eclipse shader, also on battery.
**Fixed:** the eclipse plays on mains outside Power Saver. On battery or under Power Saver the
shell adds no window animation, so niri plays the one from your own config. DMS's "reduce motion"
does not turn the eclipse off: DMS 2.0's settings migration switches it on from an old island-only toggle.

## After the per-form redesign

Measured on the live shell in the Flame Reaver form, idle, on mains, 4 November 2026.

| | Budget | Measured |
|---|---|---|
| Idle CPU of the shell (90 s sample) | 0.35 % | 0.10 % |
| Main-thread wakeups per second (90 s) | about 11 | 2.3 (16.9 across all threads) |
| Shell memory just after start | about 520 MB | 485–495 MB |
| Opening the dashboard, control centre, launcher or power menu | | +10 to +25 MB while open, back to 499 MB about a minute after closing |

The new looks follow the redesign's rules: the cracks, tides, shards, drapes and medallions are
static shapes drawn once; motion runs only while a panel opens; there is no blur in the new
pieces (the Khaslana lock mural and its blur are gone); and each panel builds only the open
form's layout, and only while it is shown.

## Not changed yet

- The opening cinematic still waits a fixed 2 s for the desktop instead of waiting for it to be
  ready, and a timed-out wait counts as played.
- If the schedule cannot switch forms after five tries, it gives up without a message.
- The stock bar can be created before settings finish loading (DMS behaviour).
- The niri layout file is rewritten even when unchanged (DMS behaviour).
- `wallpapers/phianon.png` in the repo is 5760×3120; decoding it costs memory on every wallpaper
  change. The installed copy can be scaled down (2880×1560 decodes in 0.28 s instead of 1.0 s);
  `install.sh` copies with `cp -n`, so it never overwrites a scaled copy.
