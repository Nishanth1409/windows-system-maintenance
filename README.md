# Windows System Maintenance

Personal **Windows maintenance toolkit** by [Nishanth K R](https://github.com/Nishanth1409) — desktop context-menu launchers, PowerShell cleanup/update/security helpers, App Group utilities, and Chrome extension notes.

> Source maintained locally at `C:\SystemMaintenance`. This public repo is a **sanitized** publish of scripts and docs (no logs, portable binaries, or machine-only dumps).

## Quick start

1. Clone this repository (or keep using your local `C:\SystemMaintenance` folder).
2. Run `Install_Menu.bat` **as Administrator** to install the desktop right-click **System Maintenance** menu (Windows 11: *Show more options*).
3. Read [`GUIDE.md`](./GUIDE.md) for the full command reference.

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
