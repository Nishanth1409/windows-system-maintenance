# Windows System Maintenance

Desktop **right-click menu** + PowerShell helpers for Windows cleanup, updates, security scans, Explorer fixes, Spicetify, and related PC care.

**Author:** [Nishanth K R](https://github.com/Nishanth1409) · [Portfolio](https://nkrportfolio.vercel.app)

**Related (separate repos):**
- [windhawk-mods](https://github.com/Nishanth1409/windhawk-mods) — Windhawk mods  
- [youtube-music-float-dock](https://github.com/Nishanth1409/youtube-music-float-dock) — Chrome extension  
- [vlc-folder-audio](https://github.com/Nishanth1409/vlc-folder-audio) — VLC helper  

---

## What this is

| Level | You get |
| :--- | :--- |
| **Beginner** | One desktop menu: clean, update, free space, security |
| **Intermediate** | Admin + user maintenance scripts, Spicetify reapply |
| **Pro** | App Groups, portable package, custom icons, full `GUIDE.md` |

Scripts assume an install folder named **`SystemMaintenance`** at the drive root used in the `.reg` menu (default: `C:\SystemMaintenance`). If you clone elsewhere, edit paths in `Add_Desktop_Menu.reg` before importing.

---

## Install from scratch

### 1. Requirements
- Windows 10/11
- PowerShell 5+ (built-in)
- Admin rights for menu install and some scripts

### 2. Get the files
```bash
git clone https://github.com/Nishanth1409/windows-system-maintenance.git SystemMaintenance
```
Place/rename the folder so menu paths match (recommended: `C:\SystemMaintenance`).

### 3. Install the desktop menu
1. Right-click `Install_Menu.bat` → **Run as administrator**  
   (or: `reg import Add_Desktop_Menu.reg` as admin)
2. On Windows 11: desktop → right-click → **Show more options** → **System Maintenance**

### 4. Optional tools
- **Empty RAM** menu item needs Sysinternals **RAMMap** as `app\RAMMap64.exe` (download from Microsoft; not redistributed here).

---

## How to run (daily)

| Goal | Action |
| :--- | :--- |
| Quick clean | Menu → Quick Clean |
| Free disk space | Menu → Free Space / Clean Drive |
| Windows update | Menu → Update Windows |
| App updates (winget) | Menu → Update Apps |
| Full pass | Menu → Full Maintenance (`System_AllInOne.bat`) |
| Empty standby RAM | Menu → RAM Empty (`System_EmptyRAM.bat`) |

Or run scripts directly:
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\System_QuickClean.ps1
```

---

## Layout

| Path | Purpose |
| :--- | :--- |
| `Add_Desktop_Menu.reg` / `Install_Menu.bat` | Context menu |
| `System_*.bat` | Menu launchers |
| `scripts\` | PowerShell maintenance |
| `icons\` | Menu icons |
| `AppGroup\` | Taskbar app-group plans |
| `GUIDE.md` | Full reference |

---

## Pro tips

1. Read **`GUIDE.md`** before changing admin scripts.  
2. Re-run `Install_Menu.bat` after editing the `.reg`.  
3. Keep machine-only binaries and logs out of git (`app\`, `logs\` are ignored).  
4. Build a USB copy with `MAKE_PORTABLE_PACKAGE.bat` for another PC.

---

## Safety

- Review scripts before running on a new machine.  
- Elevate only when the guide/menu says so.  
- No third-party EXE redistributables in this repo.

## License

Use for personal / portfolio purposes. Review before commercial reuse.
