# Windows System Maintenance

Personal **Windows maintenance toolkit** by [Nishanth K R](https://github.com/Nishanth1409) — desktop context-menu launchers, PowerShell cleanup/update/security helpers, App Group utilities, and Chrome extension notes.

> Live toolkit path used by scripts/menu: `C:\SystemMaintenance` (junction → `D:\Tools\SystemMaintenance`, so files/storage sit on **D:**). This public repo is a **sanitized** publish (no logs, portable binaries, or machine-only dumps).

**Layout:** registered path stays `C:\SystemMaintenance`; real files + storage on D:. Details: [`DRIVE_LAYOUT.md`](./DRIVE_LAYOUT.md).

## Quick start

1. Clone this repository (example local clone path on this PC: `D:\STUDIS\project\tools\windows-system-maintenance`), **or** keep using the live install at `C:\SystemMaintenance`.
2. Run `Install_Menu.bat` **as Administrator** to install the desktop right-click **System Maintenance** menu (Windows 11: *Show more options*).
3. Read [`GUIDE.md`](./GUIDE.md) for the full command reference.

**Note:** Moving the clone folder on disk does **not** require cloning again. Git remotes stay the same; only the local path changes.

## Layout

| Path | Purpose |
| :--- | :--- |
| `scripts/` | PowerShell maintenance scripts (clean, update, security, Explorer fixes, Spicetify helpers, …) |
| `icons/` | Menu / UI icons |
| `AppGroup/` | App grouping helpers |
| `chrome-extensions/` | Extension-related helpers/docs |
| `windhawk/` | Windhawk notes / configs (optional) |
| `*.bat` / `*.reg` | Installers and desktop menu registration |
| `GUIDE.md` | Complete usage guide |

## Highlights

- Drive / junk cleanup and quick clean
- Windows + winget app updates
- Security scan helpers
- Explorer / widgets / lock-screen fixes
- NVIDIA / Alienware-related helpers (machine-specific — review before use)
- Spotify / Spicetify reapply helpers

## Safety

- Review any script before running on a new PC.
- Prefer running elevated only when the guide says so.
- This repo **does not** include third-party EXE redistributables (e.g. Sysinternals RAMMap). Download those from official vendors if needed.
- Paths inside scripts may assume `C:\SystemMaintenance` — adjust if you clone elsewhere.

## Contributing

Issues and PRs welcome for portable path fixes and documentation improvements.

## Author

**Nishanth K R** · [@Nishanth1409](https://github.com/Nishanth1409) · [nkrportfolio.vercel.app](https://nkrportfolio.vercel.app)
