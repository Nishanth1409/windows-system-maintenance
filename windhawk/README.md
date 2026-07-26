# Windhawk Mods — `C:\SystemMaintenance\windhawk`

**Last updated:** 25 July 2026  
**Windhawk install:** `C:\Program Files\Windhawk\windhawk.exe` (ungrouped — not managed by System Maintenance scripts)  
**Live sources/settings:** `C:\ProgramData\Windhawk` (ModsSource + registry `HKLM\SOFTWARE\Windhawk\Engine\Mods`)

Local **source (`.cpp`)** and **settings backups (`.json`)** for each **currently installed** mod live under **`analysis/`** — one folder per mod. Each source also has a matching `*.bak` snapshot. There is no separate `analysis - Backup` tree.

```
windhawk/
  README.md
  analysis/
    <mod-id>/
      <mod-id>.cpp / *.wh.cpp       — current source (from Windhawk ModsSource)
      <mod-id>.cpp.bak / *.wh.cpp.bak — backup snapshot (same as current after sync)
      <mod-id>.json / *.wh.json     — settings backup (from Windhawk registry)
```

---

## Mods in use (40)

Synced from the installed Windhawk profile on this PC.

| Mod | Folder | Purpose |
|-----|--------|---------|
| Alt+Tab per monitor | [analysis/alt-tab-per-monitor](analysis/alt-tab-per-monitor) | Pressing Alt+Tab shows all open windows on the primary display. This mod shows only the windows on the monito… |
| Better file sizes in Explorer details | [analysis/explorer-details-better-file-sizes](analysis/explorer-details-better-file-sizes) | Enhances file size display in Explorer details with folder sizes, human-readable units (MB/GB), and optional… |
| Classic context menu on Windows 11 | [analysis/explorer-context-menu-classic](analysis/explorer-context-menu-classic) | Always show the classic context menu without having to select "Show More Options" or hold Shift |
| Cursor Motion Blur | [analysis/cursor-motion-blur](analysis/cursor-motion-blur) | Adds high-speed cartoon motion blur to your mouse pointer. |
| Custom Menu Height | [analysis/custom-menu-height](analysis/custom-menu-height) | Control the height of Win32 context menu items and menu bars |
| Customize Windows notifications placement | [analysis/notifications-placement](analysis/notifications-placement) | Move notifications to another monitor or another corner of the screen |
| Dark mode context menus | [analysis/dark-menus](analysis/dark-menus) | Enables dark mode for all win32 menus. |
| Expanded Clipboard (Win+V) | [analysis/expanded-clipboard](analysis/expanded-clipboard) | Raises the 25-item cap of Windows clipboard history (Win+V) and lifts the per-item / total buffer size limit… |
| Explorer TreeItem Tweaker | [analysis/explorer-treeitem-tweaker](analysis/explorer-treeitem-tweaker) | Custom backgrounds and text colors for Explorer TreeView |
| Explorer TreeLine Killer | [analysis/explorer-treeline-killer](analysis/explorer-treeline-killer) | Hide navigation pane separator lines and control upper/lower spacing in Explorer |
| Lock Screen Wallpaper | [analysis/lock-screen-wallpaper](analysis/lock-screen-wallpaper) | Force a custom lock screen image and keep it after restart, sleep, and sign-out |
| Logon, Logoff & Shutdown Sounds Restored | [analysis/logon-logoff-shutdown-sounds](analysis/logon-logoff-shutdown-sounds) | Restores the logon, logoff and shutdown sounds from earlier versions of Windows |
| Mic Tray Switch & Control | [analysis/mic-tray-switch](analysis/mic-tray-switch) | Microphone counterpart of Tray Audio Output: live input list with % gain, one-click default, mute, scroll-to-… |
| Monitor Rounded Edges | [analysis/monitor-rounded-edges](analysis/monitor-rounded-edges) | Applies smooth, anti-aliased rounded corners to all monitors via Direct2D. Supports circular and squircle (su… |
| Never Auto-Expand Explorer Tree Items | [analysis/never-auto-expand-explorer-tree-items](analysis/never-auto-expand-explorer-tree-items) | Stops the unwanted auto-expansion of navigation pane items even if the "Expand to current folder" option is o… |
| Nilesoft Shell Animator | [analysis/nilesoft-shell-animator](analysis/nilesoft-shell-animator) | Adds customizable animations to Nilesoft Shell. |
| Nilesoft Text Shrinker | [analysis/nilesoft-text-shrinker](analysis/nilesoft-text-shrinker) | Forces menu text to be small regardless of icon size. |
| NoFlashWindow | [analysis/no-flash-window](analysis/no-flash-window) | Prevent programs from flashing their windows on the taskbar |
| Per-Monitor Wallpaper | [analysis/per-monitor-wallpaper](analysis/per-monitor-wallpaper) | Set and persist wallpapers on extended/external monitors only (primary display is never changed) |
| Perform Speed Test Redirect | [analysis/perform-speedtest-redirect](analysis/perform-speedtest-redirect) | Redirects the "Perform speed test" link in the taskbar network right-click menu from the default Microsoft pa… |
| Primary taskbar on secondary monitor | [analysis/taskbar-primary-on-secondary-monitor](analysis/taskbar-primary-on-secondary-monitor) | Move the primary taskbar, including the tray icons, notifications, action center, etc. to another monitor |
| Taskbar Auto-Hide Peek in Fullscreen | [analysis/taskbar-always-visible-fullscreen](analysis/taskbar-always-visible-fullscreen) | Auto-hide edge peek (mouse to bottom) works in fullscreen apps — same as a normal window |
| Taskbar auto-hide when maximized | [analysis/taskbar-auto-hide-when-maximized](analysis/taskbar-auto-hide-when-maximized) | Makes the taskbar auto-hide only when a window is maximized or intersects the taskbar |
| Taskbar Desktop Indicator | [analysis/taskbar-desktop-indicator](analysis/taskbar-desktop-indicator) | Displays the current virtual desktop as a number or marker in the Windows 11 taskbar clock area |
| Taskbar Dock Animation Plus | [analysis/taskbar-dock-animation-plus](analysis/taskbar-dock-animation-plus) | Animates taskbar icons on mouse hover like in macOS (updated fork with support for all taskbar positions and… |
| Taskbar height and icon size | [analysis/taskbar-icon-size](analysis/taskbar-icon-size) | Control the taskbar height and icon size, improve icon quality (Windows 11 only) |
| Taskbar Labels for Windows 11 | [analysis/taskbar-labels](analysis/taskbar-labels) | Customize text labels and combining for running programs on the taskbar (Windows 11 only) |
| Taskbar Thumbnail Reorder | [analysis/taskbar-thumbnail-reorder](analysis/taskbar-thumbnail-reorder) | Reorder taskbar thumbnails with the left mouse button |
| Taskbar tray auto-hide (show on hover) | [analysis/taskbar-tray-show-on-hover](analysis/taskbar-tray-show-on-hover) | Hide the taskbar tray area when not in use, and show it when hovering the mouse over it |
| Taskbar tray system icon tweaks | [analysis/taskbar-tray-system-icon-tweaks](analysis/taskbar-tray-system-icon-tweaks) | Allows hiding system icons: volume, network, battery, microphone, location/GPS, Studio Effects, Recall, langu… |
| Taskbar Volume Control Per-App | [analysis/taskbar-volume-control-per-app](analysis/taskbar-volume-control-per-app) | Control the per-app volume by scrolling over taskbar buttons |
| Translucent Windows | [analysis/translucent-windows](analysis/translucent-windows) | Enables native translucent effects in Windows 11 |
| Tray Audio Output | [analysis/tray-audio-output](analysis/tray-audio-output) | System tray audio: pick output, volume, scroll to switch, share to multiple speakers (WASAPI mirror). Auto de… |
| Virtual Desktop Preserve Taskbar Order | [analysis/virtual-desktop-taskbar-order](analysis/virtual-desktop-taskbar-order) | The order on the taskbar isn't preserved between virtual desktop switches, this mod fixes it |
| Windows 11 File Explorer Styler | [analysis/windows-11-file-explorer-styler](analysis/windows-11-file-explorer-styler) | Customize the File Explorer with themes contributed by others or create your own |
| Windows 11 Notification Center Styler | [analysis/windows-11-notification-center-styler](analysis/windows-11-notification-center-styler) | Customize the Notification Center and Action Center with themes contributed by others or create your own |
| Windows 11 Settings Styler | [analysis/windows-11-settings-styler](analysis/windows-11-settings-styler) | Customize the Windows Settings app with themes contributed by others or create your own |
| Windows 11 Start Menu Styler | [analysis/windows-11-start-menu-styler](analysis/windows-11-start-menu-styler) | Customize the Start menu with themes contributed by others or create your own |
| Windows 11 Taskbar Styler | [analysis/windows-11-taskbar-styler](analysis/windows-11-taskbar-styler) | Customize the taskbar with themes contributed by others or create your own |
| ZenDesktop: Desktop Icon Toggle and Auto-Hide | [analysis/zen-desktop-toggle-icons](analysis/zen-desktop-toggle-icons) | Native C++ Windhawk mod to hide/show desktop icons by double-clicking, with optional inactivity-based auto-hi… |

---

## Local files layout

Each mod folder under `analysis/` contains:

| File type | Role |
|-----------|------|
| `*.cpp` / `*.wh.cpp` | Mod source (paste/import into Windhawk → Compile) |
| `*.cpp.bak` / `*.wh.cpp.bak` | Source backup snapshot (updated when you sync from Windhawk) |
| `*.json` / `*.wh.json` | Settings backup for that mod |

**Apply Matter Start button** (if used with Taskbar Styler): `C:\SystemMaintenance\Apply_StartButton_Matter.bat`  
**Restore default Start:** `scripts\Apply_StartButton_Matter.ps1 -Restore`

---

## Taskbar auto-hide peek in fullscreen

Settings: [`analysis/taskbar-always-visible-fullscreen/taskbar-always-visible-fullscreen.wh.json`](analysis/taskbar-always-visible-fullscreen/taskbar-always-visible-fullscreen.wh.json)

| Setting (JSON) | Meaning |
|----------------|---------|
| `forceOnTopWhilePeeking` | Keep peeked bar above fullscreen |
| `edgeTriggerPixels` | Bottom-edge hit zone |
| `peekCheckIntervalMs` | Poll rate while auto-hide is on |
| `excludedFolders[n]` | No peek while those folders' apps are foreground |
| `oldTaskbarOnWin11` | ExplorerPatcher / Win10-style bar only |

Requires **Automatically hide the taskbar**. Compile → enable → restart Explorer once.

---

## Tray audio output

Source/settings: [`analysis/tray-audio-output`](analysis/tray-audio-output)

- **Left click** — speaker menu (default + multi-output share)
- **Right click** — mute / unmute
- **Scroll** — cycle devices; single device → volume step
- **Multi-output** — WASAPI mirror; wired unlimited; **one Bluetooth** per adapter

Runs as a Windhawk **tool mod** (`@include windhawk.exe`). Check hidden tray icons (chevron).

---

## Workflow

1. Edit the mod’s `.cpp` or settings `.json` under `analysis/<mod-id>/`.
2. Windhawk → import/paste → **Compile** (`Ctrl+B`) → enable.
3. Restart Explorer if the mod targets the shell.
4. Re-sync from `C:\ProgramData\Windhawk` after changing settings in the Windhawk UI so JSON/bak stay current.

---

## Troubleshooting

| Issue | Try |
|-------|-----|
| Start button wrong | Re-run `Apply_StartButton_Matter.bat` or `-Restore` |
| Mod not applying | Enabled in Windhawk? Explorer restarted? |
| Tray speaker missing | Tray Audio Output enabled? Expand hidden icons |
| Settings / Start not styled | Check the matching styler folder under `analysis/` and re-import JSON |

---

## Related System Maintenance

| Item | Location |
|------|----------|
| Full PC guide | `C:\SystemMaintenance\GUIDE.md` §14 |
| Windhawk app | Ungrouped — pin via App Group **Tools** if desired |
| Explorer restart | System Maintenance → **Fix Slow Explorer** |

*Do not run maintenance scripts against Windhawk settings unless you know what they change.*