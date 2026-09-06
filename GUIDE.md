# System Maintenance — Complete Guide

**Folder:** `D:\Projects\tools\SystemMaintenance\` — runs from anywhere; re-run `Install_Menu.bat` after moving it  
**Layout:** `scripts\` · `tools\` · `AppGroup\` · `app\` · `icons\` · `logs\`  
**(Chrome extensions and Windhawk are separate GitHub projects — not stored in this folder.)**  
**Menu:** Desktop right-click → **Show more options** (Windows 11) → **System Maintenance**  
**Install menu:** `Install_Menu.bat`  
**Last updated:** 6 September 2026 (OEM auto-detect + setup loop fix)

---

## Table of contents

1. [Quick start](#1-quick-start)
2. [Desktop menu layout](#2-desktop-menu-layout)
3. [System Maintenance submenu](#3-system-maintenance-submenu)
4. [Script flows and mapping](#4-script-flows-and-mapping)
5. [Cleanup and performance rules](#5-cleanup-and-performance-rules)
6. [Maintenance schedule](#6-maintenance-schedule)
7. [Troubleshooting — which button when](#7-troubleshooting--which-button-when)
8. [Software habits](#8-software-habits)
9. [Hardware care](#9-hardware-care)
10. [All files in this folder](#10-all-files-in-this-folder)
11. [Technical reference](#11-technical-reference)
12. [Change log](#12-change-log)
13. [App Group taskbar](#13-app-group-taskbar)
14. [Related projects (Windhawk / Chrome / VLC — not in this folder)](#14-windhawk-mods--youtube-music-extension)

---

## 1. Quick start

| Question | Answer |
|----------|--------|
| Is this enough for software upkeep? | **Yes** — cleanup, updates, security, startup, repairs, RAM purge. |
| Run everything daily? | **No** — light tasks weekly; Full Maintenance every 1–2 months. |
| Re-apply the desktop menu | Double-click `Install_Menu.bat` (UAC — admin required for registry) |
| Verify everything | `tools\_FinalCheck.ps1` or `tools\_ValidateScripts.ps1` |
| Need to download extra tools? | **No** — uses built-in Windows tools + `RAMMap64.exe` already here |
| Taskbar app groups? | **Yes** — 8 groups via [App Group](https://apps.microsoft.com) — see [§13](#13-app-group-taskbar) and `AppGroup\AppGroup_Plan.txt` |
| Refresh group docs after edits? | `tools\_SyncFromLiveAppGroup.ps1` (does not overwrite your live config) |

**Rule of thumb:** Light tasks **weekly**, deeper cleanup **monthly**, admin repair **every 1–2 months**.

```bat
D:\Projects\tools\SystemMaintenance\Install_Menu.bat
```

---

## 2. Desktop menu layout

### 2.1 Main menu (items 1–10)

| # | Button | Icon | Type |
|---|--------|------|------|
| 1 | View ▶ | Windows | Built-in |
| 2 | Sort by ▶ | Windows | Built-in |
| 3 | Refresh | Windows | Built-in |
| 4 | New ▶ | Windows | Built-in |
| 5 | Display | `display.dll` | Built-in |
| 6 | Personalize | `themecpl.dll` | Built-in |
| 7 | Installed Apps | `imageres.dll,-123` | Custom |
| 8 | NVIDIA ▶ | `icons\nvidia_app.ico` | Custom |
| 9 | System Maintenance ▶ | `imageres.dll,-140` | Custom |
| 10 | Power ▶ | `imageres.dll,-109` | Custom |

```
┌─────────────────────────────┐
│  1  View                 ▶  │
│  2  Sort by              ▶  │
│  3  Refresh                 │
│  4  New                  ▶  │
│  ─────────────────────────  │
│  5  Display                 │
│  6  Personalize             │
│  7  Installed Apps          │
│  8  NVIDIA               ▶  │
│  9  System Maintenance   ▶  │
│ 10  Power                ▶  │
└─────────────────────────────┘
```

### 2.2 NVIDIA submenu (#8)

| # | Item | Icon |
|---|------|------|
| 1 | NVIDIA App | `icons\nvidia_app.ico` |
| 2 | NVIDIA Control Panel | `icons\nvidia_controlpanel.ico` |

### 2.3 Power submenu (#10)

| # | Item | Icon | Action |
|---|------|------|--------|
| 1 | Restart | `shell32.dll,238` | Restart PC |
| 2 | Sleep | `imageres.dll,-101` | Sleep mode |
| 3 | Shut down | `shell32.dll,27` | Shut down PC |

### 2.4 Hidden / removed items

| Item | Reason |
|------|--------|
| Apps (top) | Replaced by Installed Apps (#7) |
| NVIDIA duplicates | Hidden by `System_HideNvidiaDesktopMenu.ps1` — use NVIDIA submenu (#8) only |
| Restart Explorer (standalone) | Replaced by Fix Slow Explorer |
| Restart / Shutdown (standalone) | Inside Power submenu (#10) |

**Shift + right-click** shows hidden Windows defaults.

---

## 3. System Maintenance submenu

Order: **Weekly → Monthly → As needed → Admin (heavy last)**  
Each label is prefixed with how often to run it.

| # | Menu label | Runs as | What it does |
|---|------------|---------|--------------|
| 1 | Weekly — Software Checkup (All) | User | Win Update + security scan + optional app update |
| 2 | Weekly — Quick Clean | User | Windows temp/prefetch + `D:\Cache` + recycle bin |
| 3 | Weekly — Update Windows | User | Windows Update scan + Settings |
| 4 | Monthly — Free Disk Space | User | C: system junk + approved D: package/project caches |
| 5 | Monthly — Update All Apps | Admin→User | Admin winget → User winget → Chocolatey → Spotify + Spicetify last |
| 6 | Monthly — Security Quick Scan | User | Defender quick scan (background) |
| 7 | Monthly — Startup Apps | User | Opens Startup settings |
| 8 | As needed — Fix Slow Explorer | User | Speed registry + extra large icons + safe restart (AWCC overlay suppressed) |
| 9 | As needed — RAM Map Empty | **Admin** | `RAMMap64.exe` — all 5 Empty actions in one click |
| 10 | 1-2 Months — Full Maintenance (Admin) | Admin→User | DISM/SFC + deepest junk + admin winget, then user tasks |

\* **Free Disk Space** — also run when C: is below ~20 GB free or D: is below ~15% free.

### 3.1 RAM Map Empty — run order

**Script:** `System_EmptyRAM.bat` (menu launches directly; self-elevates via UAC)  
**Tool:** `D:\Projects\tools\SystemMaintenance\app\RAMMap64.exe` (Sysinternals v1.63)  
**Log:** `D:\Projects\tools\SystemMaintenance\logs\RAMMap_Empty.log`

| Step | Flag | Action |
|------|------|--------|
| 1 | `-Ew` | Empty Working Sets |
| 2 | `-Es` | Empty System Working Set |
| 3 | `-E0` | Empty Priority 0 Standby List |
| 4 | `-Et` | Empty Standby List |
| 5 | `-Em` | Empty Modified Page List |

Shows a completion message when all 5 steps finish. Do not run constantly — Windows standby cache is normal.

---

## 4. Script flows and mapping

### 4.1 Menu → script

| Menu item | Script |
|-----------|--------|
| Software Checkup (All) | `System_SoftwareCheckup.ps1` |
| Quick Clean | `System_QuickClean.ps1` |
| Update Windows | `System_UpdateWindows.ps1` |
| Free Disk Space | `System_CleanDrive.ps1` → `System_WindowsJunk.ps1` (Deep) |
| Update All Apps | `System_UpdateApps.ps1` → winget admin/user + Chocolatey → Spotify + Spicetify last |
| Security Quick Scan | `System_SecurityScan.ps1` |
| Startup Apps | `System_StartupApps.ps1` |
| Fix Slow Explorer | `System_FixExplorer.ps1` → `System_ExplorerViewProfile.ps1` + `System_RestartExplorerCore.ps1` + `System_AwccOverlayGuard.ps1` |
| RAM Map Empty | `System_EmptyRAM.bat` |
| Full Maintenance (Admin) | `System_AllInOne.bat` → `System_Admin.bat` + `System_User.ps1` |

### 4.2 App update flow

```
Monthly — Update All Apps
        │
        ├─► [1] System_WingetAdmin.ps1     (UAC / Administrator / winget)
        │
        ├─► [2] System_WingetUser.ps1      (User PowerShell / winget)
        │
        ├─► [3] Chocolatey (all except nilesoft-shell)
        │
        ├─► [4] System_HideNvidiaDesktopMenu.ps1 — remove duplicate NVIDIA desktop entries
        │
        └─► [5] Spotify official installer → Spicetify update + theme re-apply (always last)
```

`System_UpdateSpicetify.ps1` remains as an internal/manual recovery wrapper, but it is no longer a separate menu item. Both app-update workflows call the same shared `Invoke-SpotifySpicetifyFullUpdate` operation.

**Winget:** scripts call `%LocalAppData%\Microsoft\WindowsApps\winget.exe` directly (works when the `winget` alias is broken).  
**NVIDIA menu:** driver/app updates re-add duplicate Control Panel entries — hidden automatically after Update All Apps and `Install_Menu.bat`.  
| **Update Spotify + Spicetify:** Spotify from scdn.co; Spicetify `iwr \| iex` (auto-Yes); then **`spicetify update` → `restore backup` → `backup` → `apply`** to fix version mismatch after Spotify updates.

### 4.3 Full Maintenance flow

```
1-2 Months — Full Maintenance (Admin)
        │
        ├─► System_Admin.bat (elevated)
        │     Windows junk (Admin) + DISM + SFC + DNS + winsock + Admin winget
        │
        └─► System_User.ps1 (normal user)
              User winget + Windows temp/prefetch + D:\Cache cleanup
              └─► Spotify + Spicetify update and theme re-apply (always last)
```

### 4.4 Full flow diagram

```
Desktop right-click → System Maintenance
       │
       ├── Software Checkup (All) ───► System_SoftwareCheckup.ps1          [USER]  weekly
       ├── Quick Clean ──────────────► System_QuickClean.ps1              [USER]  weekly
       ├── Update Windows ───────────► System_UpdateWindows.ps1           [USER]  weekly
       ├── Free Disk Space ──────────► System_CleanDrive.ps1 + Deep junk  [USER]  monthly
       ├── Update All Apps ──────────► System_UpdateApps.ps1              [ADMIN→USER]  monthly
       ├── Security Quick Scan ──────► System_SecurityScan.ps1            [USER]  monthly
       ├── Startup Apps ─────────────► System_StartupApps.ps1             [USER]  monthly
       ├── Fix Slow Explorer ────────► System_FixExplorer.ps1             [USER]  as needed
       ├── RAM Map Empty ────────────► System_EmptyRAM.bat → RAMMap64.exe [ADMIN]  as needed
       └── Full Maintenance (Admin) ─► System_AllInOne.bat
                                              ├── System_Admin.bat  [ADMIN]
                                              └── System_User.ps1   [USER]
```

---

## 5. Cleanup and performance rules

### 5.1 What Quick Clean removes

Shared logic: `System_MaintenanceProtect.ps1` → `Invoke-MaintenanceStandardCleanup`

| Item | Removed? |
|------|----------|
| `%TEMP%` / `%LocalAppData%\Temp` | Yes |
| `C:\Windows\Temp` | Yes |
| `C:\Windows\Prefetch` | Yes (locked files skipped) |
| `D:\Cache` contents | Yes (the root folder is kept) |
| `D:\.pnpm-store` | **No** — monthly/deep cleanup only |
| Project build/dependency folders | **No** |
| Recycle bin | Yes |
| Clipboard history (Win+V) | **No** |
| Thumbnail/icon cache | **No** |
| File Explorer view / sort / group settings | **No** — verified and repaired after every clean |

Quick Clean does **not** call `System_WindowsJunk.ps1`.

### 5.1.1 File Explorer view profile is protected

`System_ExplorerViewProfile.ps1` holds the one saved view profile:

| Scope | View | Sort | Group |
|---|---|---|---|
| All normal folders | Extra large icons | Date modified, newest first | Date modified |
| This PC only | Tiles | Name, A→Z | Type |

Show options kept with it: hidden items, file extensions, item check boxes, compact view, Details pane.

Every cleanup routine runs `Invoke-MaintenanceStandardCleanup`, which ends with
`Protect-ExplorerViewSettings`. That compares the live registry with the profile and rewrites it
only when something drifted, so **cleaning caches can never change how folders look or sort**.
`%LocalAppData%\Microsoft\Windows\Explorer` and `UsrClass.dat` are also on the protected-path list,
so no cleaner can delete Explorer's own view state.

To reapply everything by hand (including folders you already opened) run **Fix Slow Explorer**;
it writes the profile to 400+ existing folder bags, backs up the old registry keys into `logs\`,
and restarts Explorer.

### 5.2 Windows junk levels (`System_WindowsJunk.ps1`)

**Never deleted in routine cleanup:** thumbnail/icon cache, `SoftwareDistribution\Download`.

| Level | Triggered by | Examples removed |
|-------|--------------|------------------|
| Deep | Free Disk Space, Full Maintenance | Temp + prefetch, upgrade leftovers, old logs, `Windows.old` if 14+ days, `D:\.pnpm-store`, and strictly allowlisted generated project caches |
| Admin | Full Maintenance (admin) | Minidumps, kernel reports, `Config.Msi`, DISM component cleanup |

**Never deleted:** Movies, Games, STUDIS, Personal, Dev, project source, `node_modules`, `.venv`, `dist`, `build`, installed apps, or documents.

### 5.2.1 D: cleanup safety boundary

The D: cleaner does not search for arbitrary “unwanted” files. It uses a strict allowlist:

| D: path/type | Policy |
|---|---|
| `D:\Cache` | Contents cleared by Quick Clean and deeper cleanup |
| `D:\.pnpm-store` | Cleared only by Free Disk Space / Deep / Full Maintenance; pnpm downloads packages again if needed |
| `.next\cache`, `__pycache__`, `.pytest_cache`, `.mypy_cache`, `.ruff_cache`, `.turbo`, `.cache` under `D:\Projects` | Cleared only by deep cleanup |
| Junctions/reparse points | Always skipped |
| `.git`, `node_modules`, `.venv`, `venv` trees | Never entered |
| `.next` itself, `dist`, `build` | Kept |

First verified run removed **1,488.2 MB** from approved D: caches with zero skipped items. All 725 `node_modules` folders and both virtual environments remained unchanged.

### 5.3 Performance rules — do NOT break

| Never delete in routine cleanup | Why |
|--------------------------------|-----|
| Thumbnail / icon cache | Slow File Explorer |
| SoftwareDistribution\Download | Slow Windows Update + app installs |
| Shell Bags (Fix Explorer rewrites the saved profile, never deletes bags) | Slow every folder open, and loses the sort/group profile |
| `%LocalAppData%\Microsoft\Windows\Explorer` and `UsrClass.dat` | Explorer's view state — deleting it resets every folder |
| Clipboard history (`%LocalAppData%\Microsoft\Windows\Clipboard`) | Win+V history — clear only in Clipboard UI (Win+V → Clear all) |
| winget pin reset every run | Slow updates; can unblock pinned packages unexpectedly |

### 5.4 Do not run too often (slows the PC)

| Menu item | Why not daily |
|-----------|----------------|
| RAM Map Empty | Clears standby RAM cache Windows uses for speed |
| Full Maintenance (Admin) | DISM/SFC take 30–60+ minutes |
| Free Disk Space | Deep junk scan — monthly or when disk is low |
| Update All Apps | Long winget/chocolatey pass — monthly is enough |

---

## 6. Maintenance schedule

### 6.1 At a glance

| Frequency | Software (desktop menu) | Hardware (manual) |
|-----------|-------------------------|-------------------|
| **Daily** | Close unused apps; charge before 20% if possible | — |
| **Weekly** | Software Checkup (All) or Quick Clean + Update Windows | Wipe keyboard / screen |
| **Monthly** | Update All Apps; Startup Apps; Security Scan; Free Disk Space if needed | Clean vents; CrystalDiskInfo |
| **As needed** | Fix Slow Explorer; RAM Map Empty | — |
| **Every 1–2 months** | Full Maintenance (Admin) | Inspect charger cable |
| **Every 3–6 months** | Review installed apps | Deep vent clean; laptop stand |
| **Yearly** | Back up files; uninstall unused software | Thermal paste only if overheating (advanced) |

### 6.2 Weekly checklist (~5 min)

```
[ ] System Maintenance → Software Checkup (All)
      (or: Quick Clean + Update Windows)
[ ] Check C:\ free space (keep 15–20%+ free)
[ ] Wipe screen / keyboard
[ ] Power → Restart once if you only used Sleep all week
```

### 6.3 Monthly checklist (~20 min)

```
[ ] System Maintenance → Update All Apps
[ ] System Maintenance → Startup Apps (disable unneeded)
[ ] System Maintenance → Security Quick Scan
[ ] System Maintenance → Free Disk Space (if below ~20 GB free)
[ ] CrystalDiskInfo → status Good?
[ ] Clean vents with compressed air
[ ] Tidy Downloads folder
[ ] Back up important files
```

### 6.4 Every 1–2 months (~30–60 min)

```
[ ] System Maintenance → Full Maintenance (Admin)
[ ] Review installed apps — uninstall what you do not use
```

---

## 7. Troubleshooting — which button when

| Symptom | Try first |
|---------|-----------|
| Weekly tidy-up | Software Checkup (All) or Quick Clean |
| Disk getting full | Free Disk Space |
| Apps outdated | Update All Apps |
| PC slow at boot | Startup Apps |
| Slow folders in Explorer | Fix Slow Explorer |
| Stuck taskbar | Fix Slow Explorer |
| Alienware overlay pops on Fix Explorer | Fixed — AWCC auto-launch suppressed during restart |
| Keyboard RGB mostly off but a few keys stay lit | See [§11.13](#1113-alienware-keyboard--alienfx-lighting) — not a hardware failure |
| Want all keyboard lights off | `Fn+F7` to 0%, or AWCC lights-off / Go Dark — **not** Stealth Mode |
| NVIDIA Control Panel duplicate on desktop menu | Run Update All Apps or `Install_Menu.bat` |
| `winget` opens “Select an app” / times out | Scripts use direct path; in PowerShell: `& "$env:LOCALAPPDATA\Microsoft\WindowsApps\winget.exe" list` |
| High RAM / sluggish apps | RAM Map Empty |
| General slowness | Power → Restart |
| After Windows major update | Full Maintenance (Admin) |
| All sites slow / DNS stale | Full Maintenance (Admin), then **reboot** |
| **One site** times out (e.g. ERR_CONNECTION_TIMED_OUT) but Google works | **Not this folder** — mobile carrier/ISP block; use **VPN on the laptop** |
| Hot / loud fans | Vent cleaning |
| Drive warning in CrystalDiskInfo | Back up → replace SSD |

**Important:** this toolkit does **not** block websites. Cleanup scripts only touch temp files, recycle bin, and old Windows upgrade leftovers. If most sites work but one site times out on phone USB tethering, that is carrier filtering — maintenance cannot fix it.

---

## 8. Software habits

### 8.1 Built into Windows (enable once)

| Task | How | How often |
|------|-----|-----------|
| Storage Sense | Settings → System → Storage | Once, then automatic |
| Battery health | Settings → System → Power → Battery | Monthly |
| Full reboot | Power → Restart | Weekly or when sluggish |
| Back up files | OneDrive / external drive | Monthly |

Windows Update, virus scan, and startup control are in **System Maintenance** — use the menu instead of hunting through Settings.

### 8.2 Habits that keep Windows fast

1. Keep **15–20% free on `C:\`** — run Free Disk Space when below ~20 GB.
2. Do not fill Downloads — delete old installers monthly.
3. Limit startup programs — use Startup Apps menu item.
4. Update GPU drivers — NVIDIA desktop menu when needed.
5. Fewer browser extensions — each uses RAM.
6. Do not run Full Maintenance daily — DISM/SFC are heavy.
7. Do not run RAM Map Empty constantly — use when memory is genuinely high.

### 8.3 What scripts cannot do

| Gap | What to do |
|-----|------------|
| Malware / phishing | Windows Security + careful downloads |
| Failing hard drive | CrystalDiskInfo (below) |
| Overheating | Hardware care (Section 9) |
| Too little RAM | Close apps, RAM Map Empty, or upgrade RAM |
| Broken single app | Uninstall/reinstall that app |
| BIOS/firmware | Laptop maker support site |

### 8.4 CrystalDiskInfo (recommended — install manually)

| | |
|---|---|
| **Download** | https://crystalmark.info/en/software/crystaldiskinfo/ |
| **Why** | SSD/HDD health (SMART) — cleanup cannot detect a dying drive |
| **How often** | Monthly — status should be **Good** |
| **If bad** | Back up immediately; plan drive replacement |

Portable ZIP is fine. You do **not** need extra "PC cleaner" apps.

---

## 9. Hardware care

### 9.1 Weekly (2 min)

- Wipe screen and keyboard with microfiber cloth.
- Use laptop on hard flat surface (not bed blanket — blocks vents).

### 9.2 Monthly (10–15 min)

- Laptop **off** → compressed-air bursts into side/rear vents.
- Check charger cable for fraying.
- CrystalDiskInfo → Good?

### 9.3 Every 3–6 months

- Repeat vent cleaning if fans are loud.
- Avoid 100% charge 24/7 plugged in when possible.

### 9.4 Do not

- Open laptop during warranty unless you know the model.
- Use vacuum directly on vents (static risk).
- Ignore clicking drives or burning smell — shut down and get help.

---

## 10. All files in this folder

```
D:\Projects\tools\SystemMaintenance\
├── GUIDE.md                    # This document
├── Install_Menu.bat            # Re-apply desktop menu (UAC)
├── MAKE_PORTABLE_PACKAGE.bat   # Refresh USB/zip package
├── Add_Desktop_Menu.reg        # Registry source for context menu
├── System_AllInOne.bat         # Full Maintenance launcher
├── System_Admin.bat            # Admin tasks (UAC)
├── System_EmptyRAM.bat         # RAM Map Empty — 5-step purge
├── Apply_StartButton_Matter.bat
├── scripts\                    # Maintenance PowerShell (menu targets)
├── tools\                      # Internal helpers + audits (_*.ps1)
├── AppGroup\                   # Taskbar group plans + ungrouped lists
├── app\                        # RAMMap + portable shortcuts for App Group
├── icons\                      # NVIDIA, Start button, File Explorer icons
├── shell\                      # Nilesoft Shell icon override (see 11.6)
├── logs\                       # RAMMap_Empty.log
└── SETUP_NEW_PC.bat            # One-click install on another PC
```

`PortablePackage\` is **build output, not a stored folder** — `MAKE_PORTABLE_PACKAGE.bat` generates it on demand and it is deleted after transfer. Keeping it around means a second, silently drifting copy of every script.

**Not in this folder (separate projects):**
- Chrome extensions → [youtube-music-float-dock](https://github.com/Nishanth1409/youtube-music-float-dock)
- Windhawk → [windhawk-mods](https://github.com/Nishanth1409/windhawk-mods)
- VLC folder audio → [vlc-folder-audio](https://github.com/Nishanth1409/vlc-folder-audio)

| File / folder | Purpose |
|------|---------|
| `GUIDE.md` | **This document** — complete reference |
| `Install_Menu.bat` | Re-apply desktop menu (UAC) — icons, registry, NVIDIA hide, OEM guards |
| `SETUP_NEW_PC.bat` | One-click install on another PC (copy → `Install_Menu.bat` → OEM guards) |
| `Add_Desktop_Menu.reg` | Registry source for context menu |
| `tools\_FinalCheck.ps1` | Full health check (`_ValidateScripts` + `_AuditMenu`) |
| `scripts\System_OemProfile.ps1` | Detect manufacturer / family; gate NVIDIA + AWCC steps |
| `scripts\System_ApplyOemGuards.ps1` | Apply only NVIDIA / AWCC guards that match this PC |
| `scripts\Show_SetupComplete.ps1` | Setup finished MessageBox (safe newlines) |
| `scripts\System_MaintenanceProtect.ps1` | Clipboard protection + shared temp/prefetch cleanup |
| `scripts\System_HideNvidiaDesktopMenu.ps1` | Remove duplicate NVIDIA desktop context menu entries |
| `scripts\Install_NvidiaMenuGuard.ps1` | Register/remove the scheduled task that auto-runs the NVIDIA hide script |
| `scripts\System_LockScreenPrune.ps1` | Delete disposable wallpaper backup copies, keeping the active image + newest |
| `scripts\Install_LockScreenPruneGuard.ps1` | Register/remove the scheduled task that auto-runs the wallpaper prune |
| `scripts\System_LogiOptionsProtect.ps1` | Backup/restore Logi Options+ mouse settings around app updates; paths protected from cleanup |
| `scripts\System_HiddenLauncherCore.ps1` | Resolves/builds `SmRunHidden.exe` for the guard tasks |
| `tools\_SmRunHidden.cs` | Source of the windowless launcher (GUI subsystem, no console) |
| `tools\SmRunHidden.exe` | Built launcher — keeps scheduled tasks from flashing a console |
| `scripts\System_AwccOverlayGuard.ps1` | Suppress Alienware overlay during Explorer restart |
| `scripts\System_WingetHelpers.ps1` | Winget/chocolatey scans; direct `winget.exe` path |
| `scripts\System_WindowsJunk.ps1` | Old Windows file cleanup (Deep / Admin) |
| `scripts\System_QuickClean.ps1` | Quick Clean — temp + recycle bin only |
| `scripts\System_CleanDrive.ps1` | Free Disk Space menu |
| `scripts\System_UpdateWindows.ps1` | Update Windows menu |
| `scripts\System_UpdateApps.ps1` | Update All Apps — full chain |
| `scripts\System_WingetAdmin.ps1` | Admin winget upgrades |
| `scripts\System_WingetUser.ps1` | User winget upgrades |
| `scripts\System_SpotifySpicetifyCore.ps1` | Shared URLs + install/re-apply helpers |
| `scripts\System_UpdateSpicetify.ps1` | Internal/manual wrapper for the shared Spotify + Spicetify update |
| `scripts\System_InstallSpicetify.ps1` | Spicetify install (called by re-apply if missing) |
| `scripts\System_ReapplySpicetify.ps1` | Re-apply Spicetify after Spotify update |
| `scripts\System_SecurityScan.ps1` | Security Quick Scan menu |
| `scripts\System_StartupApps.ps1` | Startup Apps menu |
| `scripts\System_SoftwareCheckup.ps1` | Software Checkup (All) menu |
| `scripts\System_FixExplorer.ps1` | Fix Slow Explorer menu |
| `scripts\System_ExplorerViewProfile.ps1` | Saved Explorer view/sort/group profile — applied by Fix Explorer, verified after every cleanup |
| `scripts\System_RestartExplorerCore.ps1` | Safe Explorer restart (used by Fix Explorer) |
| `app\RAMMap64.exe` | Sysinternals RAMMap tool (used by RAM Map Empty) |
| `System_EmptyRAM.bat` | RAM Map Empty — 5-step deep purge |
| `System_AllInOne.bat` | Full Maintenance launcher |
| `MAKE_PORTABLE_PACKAGE.bat` | Refresh USB/zip package for another PC |
| `tools\_ValidateScripts.ps1` | Run full audit (syntax, menu, registry) |
| `System_Admin.bat` | Admin tasks (UAC) |
| `scripts\System_User.ps1` | User tasks after admin |
| `AppGroup\AppGroup_Plan.txt` | **Live taskbar group plan** — synced from `appgroups.json` |
| `AppGroup\Apps_Not_In_Groups.txt` | Full list of installed apps not in any group |
| `AppGroup\Apps_Not_In_Groups_Notable.txt` | Filtered list — real apps only (no runtimes) |
| `_AgentSessionData.json` | Agent scan snapshot — groups, paths, disk, ungrouped summary |
| `tools\_SyncFromLiveAppGroup.ps1` | Refresh App Group docs from live config (safe) |
| `tools\_UpdateAppGroupDocs.ps1` | Regenerate plan + ungrouped lists |
| `tools\_ApplyAppGroups.ps1` | Re-apply group config — **only when you ask** |
| `app\` | Portable shortcuts/exes used by App Group (WhatsApp, Telegram, Codex, DoubleHeadphones) |

---

## 11. Technical reference

### 11.1 Registry keys

```
HKEY_CLASSES_ROOT\DesktopBackground\Shell\Perz_03_SystemMaintenance   System Maintenance
HKEY_CLASSES_ROOT\DesktopBackground\Shell\Perz_01_Apps                Installed Apps
HKEY_CLASSES_ROOT\DesktopBackground\Shell\Perz_02_NVIDIA              NVIDIA submenu
HKEY_CLASSES_ROOT\DesktopBackground\Shell\Pwrz_04_Power               Power submenu
```

Source: `Add_Desktop_Menu.reg`

### 11.2 System Maintenance registry keys

```
01_SoftwareCheckup    Weekly — Software Checkup (All)
02_QuickClean         Weekly — Quick Clean
03_UpdateWindows      Weekly — Update Windows
04_FreeSpace          Monthly — Free Disk Space
05_UpdateApps         Monthly — Update All Apps
06_SecurityScan       Monthly — Security Quick Scan
07_StartupApps        Monthly — Startup Apps
08_FixExplorer        As needed — Fix Slow Explorer
09_RamEmpty           As needed — RAM Map Empty
10_FullMaintenance    1-2 Months — Full Maintenance (Admin)
```

### 11.3 Admin vs user tasks

| Admin (UAC required) | User (no UAC) |
|----------------------|---------------|
| Windows junk (Admin) + DISM component cleanup | Quick clean (temp + recycle) |
| DISM RestoreHealth, SFC, winsock reset | Deep Windows junk (upgrade leftovers) |
| Admin winget + NVIDIA duplicate hide | User winget + temp/prefetch cleanup |
| RAM Map Empty (`System_EmptyRAM.bat`) | Fix Slow Explorer (HKCU registry) |

**Removed from maintenance (was wrong):** `ipconfig /release` + `/renew` (disconnects internet) and weekly cache wipes.

### 11.4 Quick commands

```bat
:: Re-install desktop menu
D:\Projects\tools\SystemMaintenance\Install_Menu.bat

:: Apply registry manually
reg import "D:\Projects\tools\SystemMaintenance\Add_Desktop_Menu.reg"

:: Run full maintenance
D:\Projects\tools\SystemMaintenance\System_AllInOne.bat

:: Run RAM Map Empty
D:\Projects\tools\SystemMaintenance\System_EmptyRAM.bat
```

### 11.5 Downloads required?

| Component | Needed? |
|-----------|---------|
| PowerShell, winget, DISM, SFC, netsh | **No** — built into Windows |
| RAMMap64.exe | **No** — already in folder |
| Spicetify | **No** — Update All Apps and Full Maintenance update it automatically as their final step |
| CrystalDiskInfo | **Optional** — recommended for drive health |

### 11.6 Nilesoft Shell (excluded — not maintained)

| Rule | Detail |
|------|--------|
| Install location | `C:\Program Files\Nilesoft Shell` |
| App updates | Nilesoft.Shell / nilesoft-shell **skipped** in winget and Chocolatey scans only |
| No maintenance scripts | No backup, pin, theme sync, handler re-register, or restore |

Manage Nilesoft Shell yourself outside this menu. Its theme, settings and menu
entries are never touched.

**The one exception — menu icons.** Nilesoft Shell draws the desktop context
menu itself, and it replaces the icon of any item whose title matches one of its
built-in glyphs. The glyph is filled with the current theme colours, so our
`NVIDIA` parent item was drawn white/blue instead of NVIDIA green even though
the registry pointed at `icons\nvidia_app.ico`. The submenu entries were
unaffected because their titles do not match a glyph name.

`Install_Menu.bat` therefore installs a single override:

| File | Written by | Purpose |
|------|-----------|---------|
| `imports\systemmaintenance.nss` | `scripts\Install_NilesoftMenuIcons.ps1` | `modify(...)` rule pinning the NVIDIA item to our `.ico` |
| `shell.nss` | same script | One `import 'imports/systemmaintenance.nss'` line |

The original `shell.nss` is copied to `shell.nss.sm-backup` before the first
edit. The rule is scoped with `where=str.equals(this.name, 'NVIDIA')` so it
matches the parent item only — `find` alone would also catch
"NVIDIA Control Panel" and give it the wrong icon. The icon path is rewritten
for wherever this toolkit lives, exactly like `Add_Desktop_Menu.reg`.

A Nilesoft Shell update rewrites `shell.nss` and drops third-party lines. If the
NVIDIA icon turns white/blue again, re-run `Install_Menu.bat` as admin. If
Nilesoft is not installed, the script does nothing and Explorer uses the
registry icons directly.

### 11.7 Portable package (another laptop)

| Step | Where | Action |
|------|-------|--------|
| 1 | Your PC | Run `MAKE_PORTABLE_PACKAGE.bat` — builds `PortablePackage\SystemMaintenance_Setup` |
| 2 | USB / zip | Copy that folder off |
| 3 | Friend's PC | Open folder → double-click `SETUP_NEW_PC.bat` → Yes on UAC |
| 4 | Your PC | Delete `PortablePackage\` — rebuild next time instead of letting it go stale |

**OEM auto-detect.** Setup prints manufacturer / model / family (`Alienware`, `ASUS`, `Dell`, …) via `scripts\System_OemProfile.ps1`. NVIDIA duplicate hide runs only when an NVIDIA GPU is present. AWCC Welcome/overlay guards run only on Alienware (or when AWCC is installed). ASUS TUF / MyASUS / Armoury Crate are left alone — no Alienware steps.

**“Open File - Security Warning” / Run Cancel loop.** If the package came from a ZIP, USB, or browser download, Windows marks `.bat` / `.ps1` as *from the Internet*. Clicking **Run** does **not** clear that mark. `Install_Menu.bat` / `SETUP_NEW_PC.bat` then re-launch themselves for Administrator approval, so Windows shows the **same** Run/Cancel dialog again — that is the “loop.”

Fix once on the PC:

1. Double-click `Unblock_Here.bat` in the toolkit folder, **or** run:
   ```powershell
   Get-ChildItem C:\SystemMaintenance -Recurse -Force | Unblock-File
   ```
2. Then run `Install_Menu.bat` / `SETUP_NEW_PC.bat` again — you should only get **UAC (Yes)**, not Run/Cancel again.

`SETUP_NEW_PC.bat` and `Install_Menu.bat` now unblock **before** they elevate, so a fresh package should not loop.

**CMD `tlocal` / `tle` / `errorlevel` spam + Ctrl+C to stop.** That was a separate bug: `::` comments containing parentheses broke `cmd` parsing inside `(...)` blocks, so lines like `setlocal` / `title` / `color` were eaten and the elevate path misbehaved. Fixed September 2026 — comments use `REM` with no parentheses. Replace the old `Install_Menu.bat` / `SETUP_NEW_PC.bat` on the other PC (re-copy the portable package), then re-run setup.

Includes scripts, `RAMMap64.exe`, registry, icons, and this guide.

`SETUP_NEW_PC.bat` lives in the source root so the package is fully regenerable. On the target PC it copies to `C:\SystemMaintenance` (a real folder there), then calls `Install_Menu.bat` rather than repeating its steps, so the NVIDIA de-duplicate and the guard task are set up too. `Install_Menu.bat` generates the menu registry for whatever path it lands in, so the destination is not fixed. If the source and destination resolve to the same folder, the script skips the copy instead of overwriting its own source.

### 11.8 Final audit

```bat
powershell -NoProfile -ExecutionPolicy Bypass -File D:\Projects\tools\SystemMaintenance\tools\_FinalCheck.ps1
```

Or separately:

```bat
powershell -NoProfile -ExecutionPolicy Bypass -File D:\Projects\tools\SystemMaintenance\tools\_ValidateScripts.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File D:\Projects\tools\SystemMaintenance\tools\_AuditMenu.ps1
```

`tools\_FinalCheck.ps1` — runs both audits; exit 0 only if all pass.  
`tools\_ValidateScripts.ps1` — syntax, files, registry, winget path, NVIDIA duplicate check, live menu labels.  
`_AuditMenu.ps1` — quick desktop menu-only check.

### 11.9 NVIDIA desktop menu (no duplicates)

| Rule | Detail |
|------|--------|
| Your menu | `Perz_02_NVIDIA` submenu — App + Control Panel only |
| Blocked | `NvCplDesktopContext`, `NvAppDesktopContext`, `NvGpuShExtDesktopContext`, other `Nv*` shellex / Shell entries (keeps `Perz_02_NVIDIA`) |
| After GPU/driver / NVIDIA App update | Guard task re-hides; or run `Install_Menu.bat` once |
| Manual fallback | Admin PowerShell: `System_HideNvidiaDesktopMenu.ps1` then `Install_NvidiaMenuGuard.ps1` |

**Guard task.** NVIDIA app self-updates (scheduled task `NVIDIA App SelfUpdate_{...}`) re-create `NvCplDesktopContext`, which puts a second **NVIDIA Control Panel** entry on the desktop menu outside your submenu. Every removal trigger used to be manual, so the duplicate survived until you happened to run a script.

`scripts\Install_NvidiaMenuGuard.ps1` registers `\SystemMaintenance\HideNvidiaDesktopMenu` to close that gap:

| Setting | Value |
|------|--------|
| Triggers | At logon (2 min delay) + every 6 hours |
| Runs as | Interactive user, **Run with highest privileges** |
| Action | `tools\SmRunHidden.exe powershell.exe … System_HideNvidiaDesktopMenu.ps1 -Silent -Elevated` |

Run as the interactive user, not SYSTEM — `Restart-ExplorerSafe` must relaunch Explorer into the user's session, and a SYSTEM task would put it in session 0. `-Elevated` is safe here because the task is already elevated; it just skips the UAC prompt path. The `SmRunHidden.exe` wrapper is what keeps the run invisible — see §11.14.

```powershell
# install / re-install
powershell -ExecutionPolicy Bypass -File D:\Projects\tools\SystemMaintenance\scripts\Install_NvidiaMenuGuard.ps1
# uninstall
powershell -ExecutionPolicy Bypass -File D:\Projects\tools\SystemMaintenance\scripts\Install_NvidiaMenuGuard.ps1 -Remove
```

The task is a no-op when nothing is present; Explorer is restarted only when an entry was actually removed.

### 11.10 Fix Slow Explorer + Alienware (AWCC)

Restarting Explorer triggers Alienware Command Center overlay when `AutoRun` is enabled.  
`System_AwccOverlayGuard.ps1` temporarily disables overlay auto-launch, marks onboarding complete, and closes overlay windows during restart. In-game overlay (Ctrl+Shift+Y) still works afterward.

**Welcome wizard every open / reboot.** That is the full `AWCC.exe` app (dark **Welcome!** card with Start Now / Don't Show Again), not the overlay. On current AWCC builds the flag is inverted from its name:

| `OnBoardScreen` value | Effect |
|------|--------|
| `"True"` | Welcome **hidden** (completed) |
| `"False"` | Welcome **shown** every open |

File: `%LocalAppData%\Alienware\Alienware Command Center\Common\UserSetting.json`.

An older revision of `System_AwccOverlayGuard.ps1` wrote `"False"` (thinking that meant dismissed) and that made Welcome appear on every open — including after Fix Slow Explorer. The guard now writes `"True"`. If Welcome returns after an AWCC update, run Fix Slow Explorer once, or set `OnBoardScreen` to `"True"` and reopen AWCC.

### 11.11 WinGet on this PC

| Item | Detail |
|------|--------|
| Direct path | `%LocalAppData%\Microsoft\WindowsApps\winget.exe` |
| Broken alias | “Select an app to open winget” — maintenance scripts bypass this |
| PowerShell 7 | Installed at `C:\Program Files\PowerShell\7\pwsh.exe` (7.6.x); menu scripts still use `powershell.exe` 5.1 |
| Winget list vs MSI | Winget may show older version if PowerShell was installed via MSI — trust `pwsh -Command '$PSVersionTable.PSVersion'` |

### 11.12 App Group (summary)

Full detail: `AppGroup\AppGroup_Plan.txt` and [§13](#13-app-group-taskbar).

| Item | Detail |
|------|--------|
| Software | App Group 1.5.0 — `C:\Program Files\App Group\AppGroup.exe` |
| Live config | `%LocalAppData%\AppGroup\appgroups.json` — **user-edited; scripts do not overwrite on scan** |
| Taskbar groups | 8 icons: Browse, Talk, Design, Desk, Code, Mind AI, Relax, Arena |
| Grouped apps | 31 (as of July 2026 scan) |
| Portable shortcuts | `D:\Projects\tools\SystemMaintenance\app\` — WhatsApp, Telegram, Codex `.lnk` + `DoubleHeadphones.exe` |
| Refresh docs | `powershell -File D:\Projects\tools\SystemMaintenance\tools\_SyncFromLiveAppGroup.ps1` |
| Re-apply config | `_ApplyAppGroups.ps1` — only when explicitly requested |

### 11.13 Alienware keyboard / AlienFX lighting

This PC is an **Alienware m16 R2**. Lighting is controlled by AWCC (AlienFX) + firmware shortcuts — not by anything in this toolkit (except overlay suppression in §11.10).

Ignore web “AI Mode” write-ups that mix Acer Helios / Reddit folklore with Dell steps. Use Dell’s behavior below.

#### Shortcuts (m16 R2)

| Keys | Effect |
|------|--------|
| **F2** or **Fn+F2** | **Stealth Mode** — AlienFX zones off, Quiet thermals. Keyboard stays **white static** (or keeps prior on/off). **Not** a full blackout. |
| **Fn+F7** | Keyboard backlight steps (**0% / 50% / 100%** on per-key RGB). Best hardware way to kill keyboard light. |
| Function Key Behavior | BIOS setting decides whether F-keys need **Fn**. Try both F2 and Fn+F2 if Stealth does not toggle. |

Dell Stealth reference: [KB 000224247](https://www.dell.com/support/kbdoc/en-us/000224247/unable-to-change-lighting-status-and-user-selectable-thermal-tables-when-stealth-mode-enabled).

#### Want lights **off**

1. Press **Fn+F7** until brightness is **0%**.
2. In AWCC → **FX**: use **Go Dark** if shown (needs AWCC **6.6.14+**; older 6.0.x hid it — update AWCC).
3. Or create a lights-off preset: all zones **Static**, RGB **0,0,0** *and* brightness **0%**. Bind it for **system default** *and* any **game** profiles that otherwise re-light the board.
4. Optional: Windows Settings → Personalization → **Dynamic Lighting** → Off (avoids Windows fighting AWCC).
5. Optional hard off: BIOS → Keyboard Illumination → **Disabled**.

Dell lights-off / Go Dark reference: [KB 000211659](https://www.dell.com/support/kbdoc/en-us/000211659/alienware-command-center-not-showing-go-dark-and-go-dim-commands).

#### Want full RGB **back**

1. Toggle Stealth **off** (F2 / Fn+F2).
2. **Fn+F7** up from 0%.
3. AWCC → FX: active theme, all zones colored; turn **Go Dim / Go Dark** off.
4. If dead after an AWCC update: Dell Support → m16 R2 → keyboard firmware + latest BIOS (Dell has a specific AWCC/keyboard-firmware recovery path).

#### Myths to skip

| Myth | Fact |
|------|------|
| “Black color keeps ESC/F1/TAB/CAPS lit on purpose as firmware tags” | Overstated. **Caps Lock** (and similar) can have a separate status LED. Green/orange leftover keys are usually a **partial theme**, game-bound preset, brightness not at 0%, or AWCC glitch — not intentional “operational tags” on ESC/TAB. |
| “Never use Black; only Go Dark works” | Dell documents **both** Go Dark **and** an all-black / 0% brightness preset. |
| “Fn+F2 turns everything dark” | Stealth turns AlienFX off but leaves keyboard **white** (by design). Wrong tool for blackout. |
| “Delete `%AppData%\Alienware` profiles” | Risky. On this PC AWCC lives under `%LocalAppData%\Alienware\Alienware Command Center\`. Prefer AWCC UI reset, AWCC reinstall from Dell, or BIOS/keyboard firmware — not blind folder deletes. |
| Acer Helios / other brands in the same AI answer | Wrong product — ignore. |

### 11.14 Windowless scheduled tasks (`SmRunHidden.exe`)

Both guard tasks repeat on a timer while you are using the PC, so they must run
without drawing anything on screen.

`powershell.exe -WindowStyle Hidden` is **not** enough. Windows creates the
console window first and PowerShell only hides it once it has started, so a
console appears for a fraction of a second on every run. Measured directly by
counting visible `ConsoleWindowClass` windows during a run:

| Launch method | Visible console windows |
|------|--------|
| `powershell.exe -WindowStyle Hidden` | **1** (flashes) |
| `SmRunHidden.exe powershell.exe …` | **0** |

Task Scheduler can only suppress the console by running the task in session 0
("run whether user is logged on or not"), which is not an option here:
`Restart-ExplorerSafe` must relaunch Explorer into the interactive session.

`tools\_SmRunHidden.cs` is therefore compiled with `/target:winexe`, putting it
in the **GUI subsystem** so no console is ever allocated for it, and it starts
the real command with `CREATE_NO_WINDOW`. The child's exit code is passed
through, so Task Scheduler still reports success or failure correctly.

`scripts\System_HiddenLauncherCore.ps1` exposes `Resolve-HiddenLauncher`, which
builds the exe on first use with the `csc.exe` that ships with .NET Framework 4
(always present on Windows 10/11) and rebuilds it whenever the `.cs` file is
newer. Both installers call it, so a fresh `SETUP_NEW_PC.bat` needs no extra
steps and no external toolchain.

---

## 12. Change log

**Former folder name:** `C:\SystemScripts` (renamed to `C:\SystemMaintenance`)

### Before → after

| Item | Old | Current |
|------|-----|---------|
| Desktop menu | Single flat "Run System Maintenance" | 11-item submenu with frequency labels |
| Quick Clean | Deleted icon/thumb cache weekly | Temp + prefetch + recycle bin (not icon/thumb cache) |
| Admin script | winget + ipconfig release/renew | DISM, SFC, DNS, winsock, admin winget only |
| User script | winget + Spicetify every run | User winget + Spicetify (user PS only) |
| RAM / memory | No option | RAM Map Empty via `RAMMap64.exe` |
| Explorer fix | Restart Explorer standalone | Fix Slow Explorer (registry + safe restart) |
| C:\ drive | ~687 MB junk left | Cleaned; repeatable via Free Disk Space |

### June 2026 — performance fixes

| Change | Reason |
|--------|--------|
| Quick Clean: temp + recycle only | Stopped weekly cache wipes slowing Explorer |
| WindowsJunk: skip thumb/icon/SoftwareDistribution | Keeps Explorer and installs fast; prefetch cleared via maintenance cleanup only |
| Fix Explorer: no Shell Bag mass delete | Folders keep learned layout |
| Fix Explorer: `SeparateProcess=0` | Less RAM on laptops |
| RAM Map Empty: `System_EmptyRAM.bat` | PowerShell elevation chain failed silently from context menu |

### June 2026 — RAM Map Empty

| Item | Detail |
|------|--------|
| Menu command | `"D:\Projects\tools\SystemMaintenance\System_EmptyRAM.bat"` |
| Elevation | Batch self-elevates via `net session` + UAC |
| Tool | `app\RAMMap64.exe` |
| Order | Ew → Es → E0 → Et → Em |
| Log | `RAMMap_Empty.log` |

### June 2026 — App updates keep your data (Chrome fix)

| Change | Reason |
|--------|--------|
| Removed winget `--uninstall-previous` and `--force` | Chrome and other apps were fully removed and reinstalled — extensions and shortcuts were lost |
| Removed Chocolatey `--force` on upgrades | Same — in-place upgrade only, no reinstall wipe |

### June 2026 — Winget PowerShell stuck update

| Change | Reason |
|--------|--------|
| Auto-repair stale **machine-wide** PowerShell 7.5.x MSI | Winget cannot in-place upgrade when installer technology changed; user copy 7.6.x is kept |
| Per-app winget uses `--exact --name` + silent `-h` | `--id` alone failed for `PowerShell 7.5.3.0-x64` display name |

### June 2026 — Clipboard history protected

| Change | Reason |
|--------|--------|
| `System_MaintenanceProtect.ps1` | Clipboard history folder never deleted by cleanup |
| Quick Clean / Windows junk skip `%LocalAppData%\Microsoft\Windows\Clipboard` | Win+V history survives maintenance and reboot |
| Clear clipboard only via Win+V UI | User controls when history is cleared |

### June 2026 — Nilesoft Shell left alone

| Change | Reason |
|--------|--------|
| Removed all Nilesoft theme/backup/sync scripts | User manages `C:\Program Files\Nilesoft Shell` separately |
| Nilesoft still skipped in app update scans only | Updates must not touch the app; no pins or restores |
| `tools\_ValidateScripts.ps1` full menu audit | One command to verify entire setup |

### June 2026 — Disk + network troubleshooting finalized

| Item | Detail |
|------|--------|
| Disk cleanup scope | Final — temp, recycle bin, upgrade leftovers only; install caches kept |
| C:\ free space check | Healthy when 15–20% free (~134 GB free / ~27% on this PC, July 2026) |
| Site timeout on mobile data | Carrier/ISP block — **not** caused by this folder; use VPN on laptop |
| Full Maintenance network steps | DNS flush + winsock reset only; **reboot required** after winsock reset |
| Removed harmful steps | `ipconfig /release` + `/renew` stay removed (they disconnect internet) |

### June 2026 — Cleanup, winget, NVIDIA, AWCC

| Change | Reason |
|--------|--------|
| Shared temp/prefetch cleanup in `System_MaintenanceProtect.ps1` | `%TEMP%`, Windows Temp, Prefetch on Quick Clean, Free Disk Space, Full Maintenance user step |
| Full Maintenance user order | App updates first, temp cleanup last |
| Winget direct `WindowsApps\winget.exe` path | Broken `winget` alias / timeout on this PC |
| `System_HideNvidiaDesktopMenu.ps1` | NVIDIA driver updates re-add duplicate desktop Control Panel entry |
| `Install_Menu.bat` auto-elevates + step 3 (NVIDIA hide) | Registry import needs admin; removes NvCpl duplicate after driver/repair |
| `tools\_FinalCheck.ps1` | One-command full audit |
| Spicetify after Spotify update | Immediate re-apply; better detection (version + winget results) |
| `System_AwccOverlayGuard.ps1` | Fix Slow Explorer no longer opens Alienware overlay onboarding |
| Post-repair cleanup | Removed Share hide/restore scripts (root cause was Windhawk Dynamic Island, not Windows) |
| Removed Win11Debloat-master | Folder and desktop menu item removed from System Maintenance |
| Spotify + Spicetify integration | Runs last in Update All Apps and Full Maintenance; manual wrapper retained |
| Upgrade scan snapshot | `%LocalAppData%\SystemMaintenance\PreScan.clixml` (not deleted with temp cleanup) |

### July 2026 — App Group taskbar + scan data

| Change | Detail |
|--------|--------|
| 8 taskbar groups | Browse, Talk, Design, Desk, Code, Mind AI, Relax, Arena — 31 apps grouped |
| `app\` folder | WhatsApp, Telegram, Codex shortcuts + DoubleHeadphones.exe for App Group paths |
| `AppGroup\` docs | `AppGroup_Plan.txt`, ungrouped lists — refreshed via `tools\_SyncFromLiveAppGroup.ps1` |
| `_AgentSessionData.json` | Machine snapshot for agents — data only, no script changes |
| Live config rule | `appgroups.json` is edited in App Group app; maintenance scans **read** it, do not overwrite |
| Notable ungrouped | 114 real apps without a group yet — see `Apps_Not_In_Groups_Notable.txt` |
| Excluded | JoisApp — uninstall with Revo Uninstaller when ready |
| Windhawk + YTM docs | `windhawk\README.md`, `chrome-extensions\youtube-music-audio-only\README.md` updated July 2026 |

### July 2026 — Folder layout (dedicated subfolders)

| Change | Detail |
|--------|--------|
| `scripts\` | All `System_*.ps1` maintenance scripts + NVIDIA/icon helpers |
| `tools\` | Internal `_*.ps1` audits, App Group sync, icon builders |
| `chrome-extensions\` | `google-one-image-tools` + `youtube-music-audio-only` |
| `windhawk\` | Renamed from `WINdhawkmod` — mod sources unchanged |
| `logs\` | `RAMMap_Empty.log` |
| Root | Entry points only: `Install_Menu.bat`, `System_*.bat`, `GUIDE.md`, registry |
| Desktop menu | Re-import `Add_Desktop_Menu.reg` — paths now use `scripts\` |

### July 2026 evening — Windhawk + YTM policy check

| Change | Detail |
|--------|--------|
| `tray-audio-output.wh.cpp` | **NEW** Tray Audio Output **v1.5.4** — tray menu, mute, scroll, WASAPI multi-speaker |
| `taskbar-always-visible-fullscreen.wh.cpp` | **NEW** Auto-hide peek in fullscreen **v1.2.3** — Riot Games excluded by default |
| Settings backup | `taskbar-always-visible-fullscreen.json` |
| YouTube Music Float Dock | Manifest bumped **1.20.0 → 1.21.9** (dock / PiP / HQ scripts iterated same day) |
| Docs synced | Windhawk README versions, GUIDE §14, YTM README + PRIVACY |

### July 2026 — Alienware keyboard / AlienFX (AI Mode corrections)

| Change | Detail |
|--------|--------|
| New `GUIDE.md` §11.13 | m16 R2 lighting facts from Dell KBs — Stealth, Fn+F7, Go Dark, lights-off preset |
| Troubleshooting §7 | Rows for “few keys stay lit” and “want all lights off” |
| Corrected myths | Black≠useless; Stealth≠blackout; don’t delete `%AppData%\Alienware` blindly; ignore Acer Helios AI junk |

### July 2026 — NVIDIA duplicate menu auto-guard

An NVIDIA app update restored `NvCplDesktopContext`, putting a stray **NVIDIA Control Panel** entry on the desktop menu next to the `Perz_02_NVIDIA` submenu.

| Change | Detail |
|--------|--------|
| `scripts\Install_NvidiaMenuGuard.ps1` | New — registers `\SystemMaintenance\HideNvidiaDesktopMenu` (logon + every 6 h) so the duplicate is removed without waiting for a manual script run |
| `System_HideNvidiaDesktopMenu.ps1` — `Removed` list fixed | The elevated pass runs in a child process, so the parent's second removal pass always found nothing and reported `Removed = {}`. It now diffs a before/after snapshot. This silently suppressed the NVIDIA note in **Update All Apps**, which gates on `Removed.Count` |
| `System_HideNvidiaDesktopMenu.ps1` — `-NoExplorerRestart` | Added so the elevated child skips the restart and the parent performs exactly one, now that the parent correctly sees the removals |

### September 2026 — OEM adapt + setup loop fix

Brother’s ASUS TUF (not Alienware) hit a broken setup: CMD printed `tlocal` / `tle` / `errorlevel`, needed Ctrl+C, MessageBox showed literal `\n`, and NVIDIA App updates left a stray desktop menu entry.

| Change | Reason |
|--------|--------|
| `Install_Menu.bat` / `SETUP_NEW_PC.bat` rewrite | `::` comments with parentheses corrupted `cmd` blocks; REM + no paren comments; `-NoPause` when called from setup |
| `Show_SetupComplete.ps1` | MessageBox text without bat-escaped backticks |
| `System_OemProfile.ps1` + `System_ApplyOemGuards.ps1` | Auto-detect Alienware / ASUS / Dell / …; skip AWCC on non-Alienware; NVIDIA hide only if GPU present |
| `System_AwccOverlayGuard.ps1` early exit | No AWCC folder → run Explorer restart action unchanged |
| `System_HideNvidiaDesktopMenu.ps1` | Extra handler names + Directory\Background + WOW6432Node roots after NVIDIA App updates |
| GUIDE §11.7 | Document OEM adapt + both loop types (MOTW vs bat parse) |

### July 2026 — Duplicate file cleanup (single source of truth)

Audited all 139 files by hash. 38 of 39 same-name groups were `PortablePackage\SystemMaintenance_Setup` — a stored snapshot of the whole toolkit, 13 of them already drifted behind the live scripts.

| Change | Reason |
|--------|--------|
| Deleted `PortablePackage\` | Build output, not a folder to keep. It was a June-era copy still using the old flat layout, so edits to `scripts\` never reached it |
| `SETUP_NEW_PC.bat` moved to source root | It existed **only** inside the package. `MAKE_PORTABLE_PACKAGE.bat` builds from the source tree, so deleting the package would have destroyed it with no way to regenerate |
| `SETUP_NEW_PC.bat` now calls `Install_Menu.bat` | It duplicated the icon/registry steps and had drifted to the pre-July flat layout (`%DEST%\Extract_NVIDIA_Icons.ps1`). Delegating means new PCs also get the NVIDIA de-duplicate and guard task |
| Same-folder guard in `SETUP_NEW_PC.bat` | At the time, `C:\SystemMaintenance` was a junction to the source, so an unguarded copy would overwrite its own source |
| Deleted superseded `DRIVE_LAYOUT` drafts under `tools\` | Local machine maps stay gitignored; do not publish personal drive maps |
| `_ValidateScripts.ps1` required-files list | It demanded `windhawk\README.md` and two `chrome-extensions` manifests that `.gitignore` forbids storing here — 3 permanent failures. Replaced with a check that those second copies are **absent** |

### July 2026 — No fixed install path (junction removed)

An old install pattern used a drive-root junction (for example `C:\SystemMaintenance`) that pointed at the real toolkit folder elsewhere. That made the toolkit appear in two places and broke anything that still assumed the junction after it was removed. **There is one real toolkit folder now** — wherever you cloned or copied it.

The toolkit is self-locating and runs from any drive or folder:

| Change | Detail |
|--------|--------|
| `scripts\Build_DesktopMenuReg.ps1` | New. Rewrites `Add_Desktop_Menu.reg` so all menu commands point at wherever the folder actually is. `Install_Menu.bat` runs it, imports the generated file, then deletes it |
| `Add_Desktop_Menu.reg` | Keeps `C:\SystemMaintenance` as a **placeholder**, so it stays valid for a fresh PC that really does install there |
| `.bat` files | Use `%~dp0` instead of a fixed root |
| `.ps1` / `.py` helpers | Derive the root from `$PSScriptRoot` / `__file__` |
| `_Root.ps1` | Dropped the hard-coded `C:\SystemMaintenance` fallback |
| `_ValidateScripts.ps1` | Checks live menu commands resolve to this folder |

**If you move this folder, re-run `Install_Menu.bat`.** Also re-run the optional icon scripts (`Extract_FileExplorer_Icon.ps1`, `Apply_StartButton_Matter.ps1`) so shortcuts and Windhawk styles keep matching the new location.

`SETUP_NEW_PC.bat` still installs to `C:\SystemMaintenance` on a *different* PC. That is a real folder there, not a junction.

### July 2026 — No C:→D: app junctions

Game/tool installs that lived on another drive were previously linked from `C:\` with junctions. Those links are gone: each app has **one real folder**, and launchers/registry/config were repointed before removing the links. After relocating a game, update any Windhawk **excluded folder** settings (for example the taskbar fullscreen-peek mod) to the new path.

### July 2026 — Custom File Explorer icon

`scripts\Extract_FileExplorer_Icon.ps1` builds `icons\file_explorer.ico` from `icons\file_explorer_256.png` (or a source PNG/SVG) and applies it to File Explorer shortcuts (taskbar pin, Start Menu, desktop). It also refreshes the Windows icon cache. Re-run after moving the toolkit folder.

### July 2026 — Spotify + Spicetify integrated into update workflows

The separate context-menu button was removed. `Invoke-SpotifySpicetifyFullUpdate` now holds the existing
official Spotify installer → Spicetify CLI update → theme re-apply sequence in one shared operation.
**Update All Apps** calls it after winget, Chocolatey, verification, and NVIDIA menu cleanup. **Full
Maintenance** calls it after its admin work, user winget, and cleanup. Software Checkup inherits the
same behavior when its Update All Apps prompt is accepted. A Spotify/Spicetify failure is reported in
the final summary and does not undo or hide the app updates that already completed.

`System_UpdateSpicetify.ps1` remains as an internal/manual wrapper around the same shared operation,
so direct automation and recovery use are preserved without a duplicate menu entry.

### July 2026 — Set image as lock screen

Image files have a **Set as lock screen** right-click action. It calls
`scripts\System_SetLockScreen.ps1`, which uses Microsoft's current-user
`Windows.System.UserProfile.LockScreen.SetImageFileAsync` API. It applies to a
single selected image, does not replace **Set as background**, and does not
require administrator rights. The wallpaper is applied silently — only a failure
raises a dialog.

The preferred location was directly beside **Set as background** in File
Explorer's command bar, but Windows does not provide a supported extension
point there. Microsoft's `IExplorerCommand` API extends context menus instead.
The toolkit therefore uses the safe image-file right-click verb and does not
inject code into `explorer.exe`.

### July 2026 — Personalization pages fixed + wallpaper backup prune

**Symptom.** Settings → Personalization → **Background** and **Lock screen** would
not open; clicking them did nothing.

**Root cause.** `SystemSettings.exe` was crashing (`Application Error`, faulting
module `Windows.UI.Xaml.dll`, exception `0xc000027b` — a stowed XAML exception).
A Windows build update (`10.0.26100.8737` → `.8972`) changed the XAML tree that the
Windhawk **Windows 11 Settings Styler** mod (`windows-11-settings-styler`, v1.0.1)
hooks. Only those two preview pages crash; every other Settings page works. The
crash is in the mod's core injection, not in its style rules — verified by
stripping the entire mod config (all `controlStyles`, `themeResourceVariables`, and
`styleConstants`) and reproducing the crash. v1.0.1 is already the latest release,
so there is no config change or update that lets the mod coexist with these pages
right now.

**Fix.** The styler mod is left **disabled** (its full config is preserved so it
can be re-enabled once the author ships a build-compatible update). With it off,
both pages open normally. The trade-off is the stock Settings look instead of the
custom narrow icon-rail / acrylic theme.

**Lock screen persistence.** The lock screen is driven by the custom
`local@lock-screen-wallpaper` Windhawk mod, which re-applies the image at boot
(inside `LogonUI.exe`), on unlock, and on a timer via the Creative registry keys —
persistence does **not** depend on Windows policy. A stale forced policy at
`HKLM\SOFTWARE\Policies\Microsoft\Windows\Personalization\LockScreenImage` pointed
at a missing `C:\Windows\Web\Screen\wall.jpg` (risking the default-blue lock screen
and a "managed by your organization" state); it was backed up and removed. The mod
does not re-add it because the staged image exists.

**Wallpaper backup prune.** That mod stages a fresh timestamped copy
(`lockscreen_YYYYMMDD_HHMMSS.jpg`) into `C:\ProgramData\WindhawkLockScreen` on every
boot/unlock/sign-in and never deletes the old ones — they had reached **285 files /
1.55 GB**, all byte-identical to the active `lockscreen.jpg`. Those were deleted,
and `scripts\System_LockScreenPrune.ps1` now keeps only the active image plus the
single newest copy (and trims the Windows theme wallpaper cache the same way). It
never touches your original picture files.

`scripts\Install_LockScreenPruneGuard.ps1` registers
`\SystemMaintenance\LockScreenBackupPrune` (runs at logon and every hour):

```powershell
# install / re-register
powershell -ExecutionPolicy Bypass -File D:\Projects\tools\SystemMaintenance\scripts\Install_LockScreenPruneGuard.ps1
# remove
powershell -ExecutionPolicy Bypass -File D:\Projects\tools\SystemMaintenance\scripts\Install_LockScreenPruneGuard.ps1 -Remove
```

To re-enable the Settings look later (only after a mod update): set `Disabled=0`
under `HKLM\SOFTWARE\Windhawk\Engine\Mods\windows-11-settings-styler`, or toggle it
in the Windhawk UI.

### July 2026 — Flashing PowerShell window every ~25 seconds (Intel SUR)

**Symptom.** A PowerShell console window flashed open and closed repeatedly a short
while after every boot or restart, in bursts, then again after 30–60 seconds.

**Root cause.** Not a scheduled task and not this toolkit. A process monitor showed
Intel's `esrv_svc` spawning a `powershell.exe` (each with its own `conhost.exe` — the
visible window) exactly every 25 seconds:

```
12:05:10  parent=esrv_svc  powershell.exe
12:05:35  parent=esrv_svc  powershell.exe
12:06:00  parent=esrv_svc  powershell.exe
12:06:25  parent=esrv_svc  powershell.exe
```

That is **Intel SUR (System Usage Report)** — Intel's telemetry stack, installed
under `C:\Program Files\Intel\SUR\QUEENCREEK`. It is not required by the Intel
graphics/chipset drivers, the CPU, or power management; it only reports usage data
to Intel. No `\SystemMaintenance\` task repeated faster than 20 minutes, so nothing
in this toolkit could account for a 25-second cycle. (The toolkit's own tasks *did*
flash on their slower schedule — `-WindowStyle Hidden` does not prevent it. Fixed
separately below.)

**Fix.** Three services were stopped and set to **Disabled** (prior state saved to
`assets\intel_sur_services_before.txt`):

| Service | Display name |
| --- | --- |
| `ESRV_SVC_QUEENCREEK` | Energy Server Service queencreek |
| `SystemUsageReportSvc_QUEENCREEK` | Intel(R) System Usage Report Service |
| `USER_ESRV_SVC_QUEENCREEK` | User Energy Server Service queencreek |

Verified over a 150-second monitor afterwards: zero `esrv_svc` spawns. Disabling
telemetry slightly reduces background load rather than affecting performance.

To revert (restores Intel telemetry and the flashing window):

```powershell
Set-Service ESRV_SVC_QUEENCREEK -StartupType Automatic
Set-Service SystemUsageReportSvc_QUEENCREEK -StartupType Automatic
Start-Service SystemUsageReportSvc_QUEENCREEK, ESRV_SVC_QUEENCREEK
```

**Related repair.** The `local@lock-screen-wallpaper` mod was configured to use
`C:\Users\nisha\Downloads\beast-of-reincarnation-vo.jpg`, which had been deleted. Its
fallback resolved to the staged image itself, so every 15-second apply cycle failed
on a copy-onto-itself and the mod could no longer restore the lock screen if Windows
reset it. The applied image was copied to a stable location,
`C:\Users\nisha\Pictures\LockScreen\lockscreen.jpg` (byte-identical, so the lock
screen looks unchanged), and the mod now points there. Keep that file in place.

### August 2026 — Settings-safe updates for ALL apps

Rule: System Maintenance **updates** apps; it must **not erase** their settings/data.

| Layer | Policy |
| --- | --- |
| Winget | `upgrade` only. `--force`, `--uninstall-previous`, and purge flags are **blocked** by `Assert-SettingsSafePackageArgs`. Bulk tokens always start with `upgrade`. |
| Chocolatey | `choco upgrade` only — never `--force`, never uninstall in the update path. |
| Cleanup | May only clear Temp / Prefetch / `D:\Cache` (+ allowlisted project caches). `Clear-MaintenanceFolderContents` refuses any other root (AppData, Program Files, etc.). |
| Logi Options+ | Extra backup/restore around updates (mouse profiles are brittle); same “update OK, settings stay” rule as every other app. |

Exception: machine-scope **PowerShell** MSI technology-mismatch repair may uninstall that one stale MSI, then install the current PowerShell — not a general-app path.

### August 2026 — Logi Options+ mouse settings protected

**Symptom.** Saved Logitech mouse button / Options+ settings sometimes reset.

**Analysis.** Quick Clean / Free Disk Space / Full Maintenance cleanup only touch
`%TEMP%`, Windows Prefetch, and `D:\Cache`. They never delete
`%LocalAppData%\LogiOptionsPlus\settings.db` (your mouse profiles live there since
May 2024). No System Maintenance script referenced Logi/Logitech.

The realistic risk path was **Update All Apps** upgrading `Logitech.OptionsPlus`
via winget — installers can replace app files and occasionally empty the profile
DB. Separately, Windows Installer often “reconfigures” **Logi Plugin Service** on
its own (seen many times in Event Log); that is Logitech’s updater, not this toolkit.

**Fix (per user: app updates OK, settings must not be deleted).**

| Change | Detail |
| --- | --- |
| `System_LogiOptionsProtect.ps1` | Snapshot settings/macros/Flow before updates; restore if `settings.db` missing/emptied; keep last 10 backups |
| Protected paths | `LogiOptionsPlus` Local/Roaming + `ProgramData\Logishrd\LogiOptionsPlus` + backup folder |
| Wired into | **Update All Apps**, Full Maintenance user step |

Baseline backup taken on this PC:
`%LocalAppData%\SystemMaintenance\Backups\LogiOptionsPlus\`.

### August 2026 — AWCC Welcome wizard every open (inverted OnBoardScreen)

**Symptom.** Dark **Welcome!** card on every close/open of `AWCC.exe` (and after reboot if AWCC reopens).

**Root cause.** `UserSetting.json` → `OnBoardScreen`. UIA A/B on this PC proved the polarity is the opposite of the property name:

- `"True"` → Welcome **not** shown  
- `"False"` → Welcome **is** shown  

`System_AwccOverlayGuard.ps1` (used by Fix Slow Explorer) previously wrote `"False"` to “complete” onboarding, which forced Welcome every launch. That is how System Maintenance was involved.

**Fix.** Restored `OnBoardScreen` to `"True"`, corrected the guard to write `"True"`, verified close→reopen with UIA: `Welcome visible: False` both times. Per-area `ReadyToLaunch` tours remain marked `Completed`.

### July 2026 — Toolkit's own tasks no longer flash a console

**Symptom.** After the Intel SUR fix a console still flashed, but far less often —
minutes apart instead of every 25 seconds.

**Root cause.** This toolkit, not Intel. `\SystemMaintenance\LockScreenBackupPrune`
repeated **every 20 minutes**, and the flash timestamps matched its run times
exactly. A full scan confirmed it was the only sub-hourly console task on the
machine.

The earlier assumption that `-WindowStyle Hidden` prevented this was wrong. Windows
creates the console window before PowerShell can hide it, so a window is drawn for
an instant on every run. An A/B measurement counting visible `ConsoleWindowClass`
windows during an identical payload:

| Launch method | Visible console windows |
| --- | --- |
| `powershell.exe -WindowStyle Hidden` | **1** |
| `SmRunHidden.exe powershell.exe …` | **0** |

**Fix.** Added `tools\_SmRunHidden.cs` → `tools\SmRunHidden.exe`, a GUI-subsystem
launcher that starts the real command with `CREATE_NO_WINDOW` and passes the exit
code through (§11.14). Both installers now register their task through it, and
`scripts\System_HiddenLauncherCore.ps1` builds it automatically on first use.

Session 0 ("run whether user is logged on or not") would also have hidden the
window, but was rejected: `Restart-ExplorerSafe` must relaunch Explorer into the
interactive session.

| Task | Before | After |
| --- | --- | --- |
| `LockScreenBackupPrune` | every 20 min, flashed | every **60 min**, invisible |
| `HideNvidiaDesktopMenu` | every 6 h, flashed | every 6 h, invisible |

The prune interval was relaxed to hourly because backups are only created on boot,
unlock and sign-in, so a 20-minute cycle was needless wakeups. Both tasks were
triggered manually afterwards and observed with a 15 ms poll: zero visible windows,
`LastTaskResult = 0x0`, and the prune still left only the active image plus one
backup.

### July 2026 — NVIDIA menu icon no longer replaced by a theme glyph

The NVIDIA submenu entries showed the green NVIDIA mark, but the parent **NVIDIA**
button that opens them was drawn white/blue. Both point at the same
`icons\nvidia_app.ico`, and every frame in that file was verified green, so the
registry was never the problem.

The cause is Nilesoft Shell, which renders the desktop menu and substitutes its
built-in `@nvidia` glyph for any item titled NVIDIA. The glyph takes its colours
from the active theme, which produced the white/blue eye.

`scripts\Install_NilesoftMenuIcons.ps1` now pins the icon in Nilesoft's own
config, and `Install_Menu.bat` runs it as its final step. See section 11.6 for
what it writes and how to recover after a Nilesoft update. Explorer's icon cache
and the extracted `.ico` files were not the cause and were left as they were.

### July 2026 — Spotify + Spicetify icon asset removed

The former separate **Update Spotify + Spicetify** menu entry used a custom
`icons\spotify_spicetify.ico`. After that operation became the automatic final
step of Update All Apps and Full Maintenance, the menu entry was removed and the
unused icon assets (`spotify_spicetify.ico`, `spotify_spicetify_256.png`), their
build script, and source PNGs were deleted.

### July 2026 — Explorer view profile survives cleaning

Cleaning caches used to be able to change how File Explorer looked: `System_FixExplorer.ps1` wrote
its own icon-only defaults over `Bags\AllFolders`, dropping the saved sort and group choices.

| Change | Detail |
|---|---|
| `scripts\System_ExplorerViewProfile.ps1` | New. The one definition of the view profile — Extra large icons / Date modified (desc) / grouped by Date modified for folders, Tiles / Name (asc) / grouped by Type for This PC, plus hidden items, extensions, check boxes, compact mode, Details pane |
| `System_FixExplorer.ps1` | Applies that profile (including 400+ existing folder bags and This PC) instead of its own partial values; backs up the old keys to `logs\` first |
| `System_MaintenanceProtect.ps1` | `Invoke-MaintenanceStandardCleanup` now ends with `Protect-ExplorerViewSettings`, which rewrites the profile only when it has drifted |
| Protected paths | `%LocalAppData%\Microsoft\Windows\Explorer` and `UsrClass.dat*` added, so no cleaner can delete Explorer's view state |

Every cleanup entry point (Quick Clean, Free Disk Space, Windows junk Deep/Admin, User maintenance)
goes through that shared function, so the sort/view settings are checked after each run.

### July 2026 — Safe secondary-drive cache cleanup

Routine cleanup was system-drive-centric. Secondary-drive cleanup is now integrated without treating personal data as junk:

| Trigger | Secondary-drive action |
|---|---|
| Quick Clean / user cleanup | Clears only an allowlisted cache folder (default name `Cache` on the data drive) |
| Free Disk Space / Deep / Admin | Also clears allowlisted package/project generated caches |
| Every cleanup | Skips junctions, Git/dependency/environment trees, media, games, study folders, and other non-allowlisted data |

Verify anytime:

```bat
powershell -NoProfile -ExecutionPolicy Bypass -File D:\Projects\tools\SystemMaintenance\tools\_FinalCheck.ps1
```

---

## 13. App Group taskbar

**Software:** [App Group](https://apps.microsoft.com) 1.5.0  
**Goal:** Pin **8 group icons** on the taskbar instead of 30+ individual apps.

### 13.1 Current groups (July 2026)

| Group | Apps | Purpose |
|-------|------|---------|
| **Browse** | Chrome, Gmail, Edge | Daily web |
| **Talk** | WhatsApp, Telegram, Meet, Zoom (+ Gmail) | Chat and calls |
| **Design** | Canva, Figma, DaVinci Resolve, Affinity | Design and video |
| **Desk** | Word, Excel, PowerPoint, PDFgear | Office docs |
| **Code** | Cursor, VS Code, Antigravity, GitHub, GitHub Desktop | Dev tools |
| **Mind AI** | ChatGPT, Gemini, Codex, Claude | AI assistants |
| **Relax** | YouTube, YouTube Music, Spotify, DoubleHeadphones, JioHotstar | Media |
| **Arena** | Riot Client | Gaming launcher |

### 13.2 Files and commands

| File / command | What it does |
|----------------|--------------|
| `AppGroup\AppGroup_Plan.txt` | Human-readable plan — auto-generated from live config |
| `AppGroup\Apps_Not_In_Groups.txt` | Every installed app not in a group (210 apps) |
| `AppGroup\Apps_Not_In_Groups_Notable.txt` | Real apps only — no .NET/VC++ runtimes (114 apps) |
| `_AgentSessionData.json` | Full scan snapshot for Cursor agents |
| `tools\_SyncFromLiveAppGroup.ps1` | **Safe refresh** — updates docs only |
| `_ApplyAppGroups.ps1` | Re-writes `appgroups.json` — use only when you want to reset groups |

```bat
powershell -NoProfile -ExecutionPolicy Bypass -File D:\Projects\tools\SystemMaintenance\tools\_SyncFromLiveAppGroup.ps1
```

### 13.3 `app\` portable shortcuts

| File | Used in group |
|------|---------------|
| `app\WhatsApp.lnk` | Talk |
| `app\Telegram Desktop.lnk` | Talk |
| `app\Codex.lnk` | Mind AI |
| `app\DoubleHeadphones.exe` | Relax |
| `app\RAMMap64.exe` | Start Menu only (maintenance tool) |

Root `D:\Projects\tools\SystemMaintenance\app\RAMMap64.exe` is the copy used by **RAM Map Empty** menu.

### 13.4 Chrome profiles

| Profile folder | Display name |
|----------------|--------------|
| Default | Person 1 |
| Profile 1 | Srushti |
| Profile 2 | Your Chrome |
| Profile 3 | Nkr |

No profile named **Vijender**. School apps (Classroom, Meet, Gmail) are in **Browse** / **Talk** or as Chrome PWAs.

### 13.5 Notable apps still ungrouped

Examples: Discord, VLC, NVIDIA App, PowerToys, Windhawk, WinRAR, Proton VPN, Twinkle Tray, EarTrumpet, Google Classroom, Google Drive.

Add any of these in the App Group app, then run `tools\_SyncFromLiveAppGroup.ps1` to refresh docs.

---

## 14. Windhawk mods & YouTube Music extension

### 14.1 Windhawk (`windhawk\`)

**App:** Windhawk — `C:\Program Files\Windhawk\windhawk.exe`  
**Live data:** `C:\ProgramData\Windhawk` (ModsSource + `HKLM\SOFTWARE\Windhawk\Engine\Mods`)  
**Docs / mods repo:** [windhawk-mods](https://github.com/Nishanth1409/windhawk-mods) → `analysis\` (curated mod sources).

Full inventory: see that repo’s `README.md`. Windhawk sources / repair helpers are **not** stored inside System Maintenance (one-off Aug 2026 taskbar repair scripts were removed from this folder on purpose).

**Layout:** one folder per curated mod under that repo’s `analysis\<mod-id>\` (source, settings JSON, `.bak`). Matter taskbar Styler JSON: `analysis\taskbar-styler-matter\`.

**In this toolkit only:** `scripts\Apply_StartButton_Matter.ps1` + `icons\Start.png` for the custom Start button. After a Windows taskbar update, re-run that script (and re-import the Matter JSON from windhawk-mods if the theme itself reset).

System Maintenance **does not** auto-update or reset Windhawk mods. Use **Fix Slow Explorer** after enabling Explorer mods.

### 14.2 YouTube Music Float Dock (separate project)

**Not part of System Maintenance.** See the dedicated repo:

- GitHub: [Nishanth1409/youtube-music-float-dock](https://github.com/Nishanth1409/youtube-music-float-dock)

Clone that repo and **Load unpacked** in Chrome from the folder that contains `manifest.json`.

| Feature | Detail |
|---------|--------|
| Float dock | F11, maximize, minimize, PiP, random from local history |
| HQ mode | Highest quality playback; does not hide video |
| App Group | Optional: put YouTube Music PWA in a Relax/focus group |

Reload the extension after code changes; refresh the Music tab.

### 14.3 Other Chrome extensions

Additional Chrome extensions belong in their own repos / folders — not inside System Maintenance.

---

**Healthy laptop = System Maintenance menu + App Group taskbar + Windhawk tweaks + this schedule + common sense.**
