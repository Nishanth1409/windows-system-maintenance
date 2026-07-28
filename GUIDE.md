# System Maintenance — Complete Guide

**Folder:** `C:\SystemMaintenance\`  
**Layout:** `scripts\` · `tools\` · `AppGroup\` · `app\` · `icons\` · `logs\`  
**(Chrome extensions and Windhawk are separate projects under `D:\Projects`.)**  
**Menu:** Desktop right-click → **Show more options** (Windows 11) → **System Maintenance**  
**Install menu:** `Install_Menu.bat`  
**Last updated:** 21 July 2026 (Alienware keyboard / AlienFX lighting facts)

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
14. [Windhawk mods & YouTube Music extension](#14-windhawk-mods--youtube-music-extension)

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
C:\SystemMaintenance\Install_Menu.bat
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
| 2 | Weekly — Quick Clean | User | `%TEMP%`, user/Windows temp, prefetch, recycle bin |
| 3 | Weekly — Update Windows | User | Windows Update scan + Settings |
| 4 | Monthly — Free Disk Space | User | C:\ root junk + deep Windows junk (no install caches) |
| 5 | Monthly — Update All Apps | Admin→User | Admin winget → User winget → Chocolatey |
| 5b | As needed — Update Spotify + Spicetify | User | Spotify from `download.scdn.co/SpotifySetup.exe`, then Spicetify `iwr \| iex` + re-apply |
| 6 | Monthly — Security Quick Scan | User | Defender quick scan (background) |
| 7 | Monthly — Startup Apps | User | Opens Startup settings |
| 8 | As needed — Fix Slow Explorer | User | Speed registry + extra large icons + safe restart (AWCC overlay suppressed) |
| 9 | As needed — RAM Map Empty | **Admin** | `RAMMap64.exe` — all 5 Empty actions in one click |
| 10 | 1-2 Months — Full Maintenance (Admin) | Admin→User | DISM/SFC + deepest junk + admin winget, then user tasks |

\* **Free Disk Space** — also run anytime `C:\` is below ~20 GB free.

### 3.1 RAM Map Empty — run order

**Script:** `System_EmptyRAM.bat` (menu launches directly; self-elevates via UAC)  
**Tool:** `C:\SystemMaintenance\app\RAMMap64.exe` (Sysinternals v1.63)  
**Log:** `C:\SystemMaintenance\logs\RAMMap_Empty.log`

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
| Update All Apps | `System_UpdateApps.ps1` → winget admin/user + Chocolatey |
| Update Spotify + Spicetify | `System_UpdateSpicetify.ps1` → official Spotify installer + Spicetify `iwr \| iex` + re-apply |
| Security Quick Scan | `System_SecurityScan.ps1` |
| Startup Apps | `System_StartupApps.ps1` |
| Fix Slow Explorer | `System_FixExplorer.ps1` → `System_RestartExplorerCore.ps1` + `System_AwccOverlayGuard.ps1` |
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
```

**Update Spicetify** (separate menu item): `System_UpdateSpicetify.ps1` — SpotifySetup.exe from scdn.co, then Spicetify official `iwr | iex`, then `spicetify backup apply`

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
              User winget + temp/prefetch cleanup
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
| Recycle bin | Yes |
| Clipboard history (Win+V) | **No** |
| Thumbnail/icon cache | **No** |

Quick Clean does **not** call `System_WindowsJunk.ps1`.

### 5.2 Windows junk levels (`System_WindowsJunk.ps1`)

**Never deleted in routine cleanup:** thumbnail/icon cache, `SoftwareDistribution\Download`.

| Level | Triggered by | Examples removed |
|-------|--------------|------------------|
| Deep | Free Disk Space, Full Maintenance (user) | Temp + prefetch (above), upgrade leftovers, old logs 30+ days, `Windows.old` if 14+ days |
| Admin | Full Maintenance (admin) | Minidumps, kernel reports, `Config.Msi`, DISM component cleanup |

**Never deleted:** installed apps, games, documents, project folders (`C:\xampp`, `C:\Apps`, etc.).

### 5.3 Performance rules — do NOT break

| Never delete in routine cleanup | Why |
|--------------------------------|-----|
| Thumbnail / icon cache | Slow File Explorer |
| SoftwareDistribution\Download | Slow Windows Update + app installs |
| Shell Bags (except Fix Explorer sets AllFolders only) | Slow every folder open |
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

**Important:** `C:\SystemMaintenance` does **not** block websites. Cleanup scripts only touch temp files, recycle bin, and old Windows upgrade leftovers. If most sites work but one site times out on phone USB tethering, that is carrier filtering — maintenance cannot fix it.

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
C:\SystemMaintenance\
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
├── chrome-extensions\          # Unpacked Chrome extensions
│   ├── google-one-image-tools\
│   └── youtube-music-audio-only\
├── windhawk\                   # Windhawk mod sources + docs
├── AppGroup\                   # Taskbar group plans + ungrouped lists
├── app\                        # Portable shortcuts/exes for App Group
├── icons\                      # NVIDIA, Start button, File Explorer icons
├── logs\                       # RAMMap_Empty.log
└── PortablePackage\            # Copy for another PC
```

| File / folder | Purpose |
|------|---------|
| `GUIDE.md` | **This document** — complete reference |
| `Install_Menu.bat` | Re-apply desktop menu (UAC) — icons, registry, NVIDIA hide |
| `Add_Desktop_Menu.reg` | Registry source for context menu |
| `tools\_FinalCheck.ps1` | Full health check (`_ValidateScripts` + `_AuditMenu`) |
| `scripts\System_MaintenanceProtect.ps1` | Clipboard protection + shared temp/prefetch cleanup |
| `scripts\System_HideNvidiaDesktopMenu.ps1` | Remove duplicate NVIDIA desktop context menu entries |
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
| `scripts\System_UpdateSpicetify.ps1` | Menu — Spotify + Spicetify full update |
| `scripts\System_InstallSpicetify.ps1` | Spicetify install (called by re-apply if missing) |
| `scripts\System_ReapplySpicetify.ps1` | Re-apply Spicetify after Spotify update |
| `scripts\System_SecurityScan.ps1` | Security Quick Scan menu |
| `scripts\System_StartupApps.ps1` | Startup Apps menu |
| `scripts\System_SoftwareCheckup.ps1` | Software Checkup (All) menu |
| `scripts\System_FixExplorer.ps1` | Fix Slow Explorer menu |
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
05b_UpdateSpicetify   As needed — Update Spotify + Spicetify
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

**Removed from maintenance (was wrong):** `ipconfig /release` + `/renew` (disconnects internet), weekly cache wipes, Spicetify download every run.

### 11.4 Quick commands

```bat
:: Re-install desktop menu
C:\SystemMaintenance\Install_Menu.bat

:: Apply registry manually
reg import "C:\SystemMaintenance\Add_Desktop_Menu.reg"

:: Run full maintenance
C:\SystemMaintenance\System_AllInOne.bat

:: Run RAM Map Empty
C:\SystemMaintenance\System_EmptyRAM.bat
```

### 11.5 Downloads required?

| Component | Needed? |
|-----------|---------|
| PowerShell, winget, DISM, SFC, netsh | **No** — built into Windows |
| RAMMap64.exe | **No** — already in folder |
| Spicetify | **No** — use **Update Spicetify** menu item when needed |
| CrystalDiskInfo | **Optional** — recommended for drive health |

### 11.6 Nilesoft Shell (excluded — not maintained)

| Rule | Detail |
|------|--------|
| Install location | `C:\Program Files\Nilesoft Shell` — **never changed** by System Maintenance |
| App updates | Nilesoft.Shell / nilesoft-shell **skipped** in winget and Chocolatey scans only |
| No maintenance scripts | No backup, pin, theme sync, handler re-register, or restore |

Manage Nilesoft Shell yourself outside this menu.

### 11.7 Portable package (another laptop)

| Step | Where | Action |
|------|-------|--------|
| 1 | Your PC | Run `MAKE_PORTABLE_PACKAGE.bat` |
| 2 | USB / zip | Copy folder `PortablePackage\SystemMaintenance_Setup` |
| 3 | Friend's PC | Open folder → double-click `SETUP_NEW_PC.bat` → Yes on UAC |

Includes scripts, `RAMMap64.exe`, registry, icons, and this guide.

### 11.8 Final audit

```bat
powershell -NoProfile -ExecutionPolicy Bypass -File C:\SystemMaintenance\tools\_FinalCheck.ps1
```

Or separately:

```bat
powershell -NoProfile -ExecutionPolicy Bypass -File C:\SystemMaintenance\tools\_ValidateScripts.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File C:\SystemMaintenance\_AuditMenu.ps1
```

`tools\_FinalCheck.ps1` — runs both audits; exit 0 only if all pass.  
`tools\_ValidateScripts.ps1` — syntax, files, registry, winget path, NVIDIA duplicate check, live menu labels.  
`_AuditMenu.ps1` — quick desktop menu-only check.

### 11.9 NVIDIA desktop menu (no duplicates)

| Rule | Detail |
|------|--------|
| Your menu | `Perz_02_NVIDIA` submenu — App + Control Panel only |
| Blocked | `NvCplDesktopContext`, `NvAppDesktopContext` shellex handlers |
| After GPU/driver update | Run **Update All Apps** or `Install_Menu.bat` — auto-hides duplicates |

### 11.10 Fix Slow Explorer + Alienware (AWCC)

Restarting Explorer triggers Alienware Command Center overlay when `AutoRun` is enabled.  
`System_AwccOverlayGuard.ps1` temporarily disables overlay auto-launch, marks onboarding complete, and closes overlay windows during restart. In-game overlay (Ctrl+Shift+Y) still works afterward.

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
| Portable shortcuts | `C:\SystemMaintenance\app\` — WhatsApp, Telegram, Codex `.lnk` + `DoubleHeadphones.exe` |
| Refresh docs | `powershell -File C:\SystemMaintenance\tools\_SyncFromLiveAppGroup.ps1` |
| Re-apply config | `_ApplyAppGroups.ps1` — only when explicitly requested |

### 11.13 Alienware keyboard / AlienFX lighting

This PC is an **Alienware m16 R2**. Lighting is controlled by AWCC (AlienFX) + firmware shortcuts — not by anything in `C:\SystemMaintenance` (except overlay suppression in §11.10).

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
| Menu command | `"C:\SystemMaintenance\System_EmptyRAM.bat"` |
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
| Spicetify own menu item | **Update Spotify + Spicetify** — scdn.co installer + official Spicetify iwr\|iex |
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

Verify anytime:

```bat
powershell -NoProfile -ExecutionPolicy Bypass -File C:\SystemMaintenance\tools\_FinalCheck.ps1
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
powershell -NoProfile -ExecutionPolicy Bypass -File C:\SystemMaintenance\tools\_SyncFromLiveAppGroup.ps1
```

### 13.3 `app\` portable shortcuts

| File | Used in group |
|------|---------------|
| `app\WhatsApp.lnk` | Talk |
| `app\Telegram Desktop.lnk` | Talk |
| `app\Codex.lnk` | Mind AI |
| `app\DoubleHeadphones.exe` | Relax |
| `app\RAMMap64.exe` | Start Menu only (maintenance tool) |

Root `C:\SystemMaintenance\app\RAMMap64.exe` is the copy used by **RAM Map Empty** menu.

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
**Docs / local mods repo:** `D:\Projects\tools\windhawk-mods` (GitHub: [windhawk-mods](https://github.com/Nishanth1409/windhawk-mods)) → `analysis\` (40 installed mods).

Full inventory (names, folders, purpose): see that repo’s `README.md`. Windhawk is **not** stored inside System Maintenance.

**Layout:** one folder per installed mod under `windhawk\analysis\<mod-id>\` with current source (`.cpp` / `.wh.cpp`), settings JSON, and matching `.bak`. Examples: Tray Audio Output, Mic Tray Switch, Custom Menu Height, Taskbar Auto-Hide Peek, Lock Screen / Per-Monitor Wallpaper, stylers (Explorer / Start / Settings / Taskbar / Notification Center).

System Maintenance **does not** auto-update or reset Windhawk mods. Use **Fix Slow Explorer** after enabling Explorer mods.

### 14.2 YouTube Music Float Dock (separate project)

**Not part of System Maintenance.** Lives at:

- Local: `D:\Projects\extensions\youtube-music-float-dock`
- GitHub: [Nishanth1409/youtube-music-float-dock](https://github.com/Nishanth1409/youtube-music-float-dock)

**Version:** 1.21.9 — Chrome unpacked extension  
**Docs:** that folder’s `README.md` + `PRIVACY.md`

| Feature | Detail |
|---------|--------|
| Float dock | F11, maximize, minimize, PiP, random from local history |
| HQ mode | Highest quality playback; does not hide video |
| Install | Chrome → Extensions → Load unpacked → select `D:\Projects\extensions\youtube-music-float-dock` |
| App Group | YouTube Music PWA in **Relax** group |

Reload extension after folder changes; refresh `music.youtube.com` tab.

### 14.3 Other Chrome extensions

Additional Chrome extensions (if any) also belong under `D:\Projects\extensions\`, not inside System Maintenance.

---

**Healthy laptop = System Maintenance menu + App Group taskbar + Windhawk tweaks + this schedule + common sense.**
