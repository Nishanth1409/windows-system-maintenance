# PC drive layout

Updated: 2026-07-27

## D: top-level (category folders)

| Folder | What |
| :--- | :--- |
| `D:\Projects` | Personal work (this map’s focus) |
| `D:\STUDIS` | Studies only (JAIN, PESITM) |
| `D:\Media` | Movies, Photography, Video |
| `D:\Personal` | My_Details |
| `D:\Dev` | protorev |
| `D:\Games` | Riot Games; XboxGames → junction to `D:\XboxGames` |
| `D:\Cache` | CacheClip (temp/cache leftovers) |
| `D:\Tools` | Optional local tools slot (keep empty of project trees) |

Old root names kept as junctions for compatibility:

| Junction | Target |
| :--- | :--- |
| `D:\Movies` | `D:\Media\Movies` |
| `D:\Photography` | `D:\Media\Photography` |
| `D:\video` | `D:\Media\Video` |
| `D:\MY ditails` | `D:\Personal\My_Details` |
| `D:\protorev` | `D:\Dev\protorev` |

## Projects root

`D:\Projects` — personal work (not under `D:\STUDIS` studies).

| Folder | What |
| :--- | :--- |
| `portfolio/` | Portfolio site (`Nkr`) |
| `business/` | Home Business (arecanut-market, Areca ERP) |
| `apps/` | Product apps (HappyJourney, nyayasakhi-ai) |
| `learning/` | Small practice projects |
| `academic/` | College docs / reports |
| `tools/` | System Maintenance, Windhawk, ffmpeg, misc |

## System Maintenance (single copy)

| Role | Path |
| :--- | :--- |
| Live + GitHub working tree | `D:\Projects\tools\SystemMaintenance` |
| Registered | `C:\SystemMaintenance` → junction |
| GitHub | https://github.com/Nishanth1409/windows-system-maintenance |

No second `windows-system-maintenance` folder. No Windhawk files inside this repo.

## Windhawk (single copy)

| Role | Path |
| :--- | :--- |
| Local + GitHub | `D:\Projects\tools\windhawk-mods` |
| GitHub | https://github.com/Nishanth1409/windhawk-mods |

## Other

| Item | Path |
| :--- | :--- |
| ffmpeg | `D:\Projects\tools\ffmpeg` (`C:\ffmpeg` junction) |
| misc helpers | `D:\Projects\tools\misc` (e.g. `mpicc.bat`) |
| Studies | `D:\STUDIS` (JAIN, PESITM only) |
| Riot | `D:\Games\Riot Games` (`C:\Riot Games` junction) |

## Doc index

| File | Role |
| :--- | :--- |
| `D:\Projects\PROJECT_LAYOUT.md` | Quick Projects map |
| `D:\Projects\tools\DRIVE_LAYOUT.txt` | Same map (tools copy) |
| `D:\Projects\tools\SystemMaintenance\DRIVE_LAYOUT.md` | This file |
| `D:\Projects\tools\CLEANUP_REPORT.txt` | Safe cleanup log |
| `D:\Projects\tools\_reorg_log.txt` | D: category move log |
