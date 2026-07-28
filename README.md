# Windows System Maintenance

Personal **Windows PC maintenance toolkit** by [Nishanth K R](https://github.com/Nishanth1409) — **desktop right-click menu**, cleanup/update/security scripts, App Groups, and related PC helpers.

> **Live path:** `D:\Projects\tools\SystemMaintenance`  
> **Registered:** `C:\SystemMaintenance` (junction → live path)

## What belongs here (keep)

| Item | Why |
| :--- | :--- |
| `Add_Desktop_Menu.reg` / `Install_Menu.bat` | Desktop right-click menu |
| `System_*.bat` / `scripts\System_*.ps1` | Menu commands (clean, update, security, Explorer, Spicetify, …) |
| `icons\` | Menu / NVIDIA / Start-button icons used by `.reg` |
| `AppGroup\` + `tools\_ApplyAppGroups*.ps1` | Taskbar app-group helpers used with this PC setup |
| `app\RAMMap64.exe` | Used by **Empty RAM** menu action |
| `PortablePackage\` | Portable installer of this toolkit |
| `GUIDE.md` / `README.md` | Docs for this toolkit |

## What does **not** belong here (separate projects)

| Project | Where |
| :--- | :--- |
| Chrome extensions | `D:\Projects\extensions\` → [youtube-music-float-dock](https://github.com/Nishanth1409/youtube-music-float-dock) |
| Windhawk mods | `D:\Projects\tools\windhawk-mods` → [windhawk-mods](https://github.com/Nishanth1409/windhawk-mods) |
| VLC folder-audio | `D:\Projects\tools\vlc-folder-audio` → [vlc-folder-audio](https://github.com/Nishanth1409/vlc-folder-audio) |

## Quick start

1. Use live folder or clone to `D:\Projects\tools\SystemMaintenance`.
2. Run `Install_Menu.bat` **as Administrator** (Windows 11: *Show more options*).
3. Read [`GUIDE.md`](./GUIDE.md).

## Author

**Nishanth K R** · [@Nishanth1409](https://github.com/Nishanth1409) · [nkrportfolio.vercel.app](https://nkrportfolio.vercel.app)
