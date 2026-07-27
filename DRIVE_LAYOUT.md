# PC drive layout (companion note)

## System Maintenance (your toolkit)

| Role | Path |
| :--- | :--- |
| **Live install** (real files, storage on D:) | `D:\Tools\SystemMaintenance` |
| **Registered path** (desktop menu / scripts / Windhawk) | `C:\SystemMaintenance` → junction to the live install |
| **GitHub project** (sanitized public repo) | `D:\STUDIS\project\windows-system-maintenance` → [Nishanth1409/windows-system-maintenance](https://github.com/Nishanth1409/windows-system-maintenance) |

Hardcoded paths still say `C:\SystemMaintenance` — that is correct. Windows follows the junction to **D:**, so storage grows on D:, not C:. Do **not** rewrite script paths unless you also re-import the desktop menu `.reg`.

Machine-only bits (`app/`, `logs/`, binaries, `_AgentSessionData.json`) stay in the **live** folder only; the GitHub repo stays sanitized.

## Classification

### System / OEM (leave on C:)

`Windows`, `Users`, `Program Files`, `Program Files (x86)`, `ProgramData`, `PerfLogs`, `Recovery`, `inetpub`, `Dell`, `XboxGames`, `OneDriveTemp`, recycle/system volume metadata, pagefile/swapfile.

### Junctions (path on C:, data on D:)

| Visible path | Real location |
| :--- | :--- |
| `C:\SystemMaintenance` | `D:\Tools\SystemMaintenance` |
| `C:\ffmpeg` | `D:\Tools\ffmpeg` |
| `C:\Riot Games` | `D:\Games\Riot Games` |

### D: categories

```
D:\Media\          Movies, Photography, Video
D:\Personal\       My_Details
D:\Dev\            protorev
D:\Cache\          app/cache leftovers
D:\Tools\          ffmpeg, SystemMaintenance (+ misc)
D:\Games\          Riot Games (+ XboxGames junction)
D:\STUDIS\         college / coding projects
```

Compat junctions on D: root (old names): `Movies`, `Photography`, `video`, `MY ditails`, `protorev`.

Live map on PC: `D:\Tools\DRIVE_LAYOUT.txt`.

## PATH

- User PATH uses `D:\Tools\ffmpeg\bin`.
- `C:\ffmpeg\bin` may still appear in Machine PATH; the `C:\ffmpeg` junction keeps those entries working.
