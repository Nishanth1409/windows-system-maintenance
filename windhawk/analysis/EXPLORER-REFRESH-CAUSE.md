# File Explorer auto-refresh (blocks rename) — root cause

**Symptom:** Explorer folder view refreshes about once per second (like pressing F5). Rename is cancelled because the list reloads while you are editing the name.

**Checked:** 2026-07-17 on Windows 11 build **26200.8875** (July 2026 security updates).

## Is Tray Audio Output the cause?

**No.** `tray-audio-output` runs in a separate `windhawk.exe` tool process. It only uses `Shell_NotifyIconW` for the speaker tray icon. It does **not** hook `explorer.exe`, does not watch folders, and does not refresh File Explorer. See `tray-audio-output/ICON-DISAPPEAR-CAUSE.md` for the separate invisible-icon issue.

## Most likely cause (confirmed on this PC)

### Windhawk mod: **Explorer Details - Better File Sizes**

- **Loaded in explorer.exe:** yes (`explorer-details-better-file-sizes_1.5.1`)
- **Your saved setting** (`windhawk/analysis/explorer-details-better-file-sizes/explorer-details-better-file-sizes.json`):

```json
"calculateFolderSizes": "everything"
```

- **Everything.exe** is running (Voidtools indexer).
- With `"everything"`, the mod queries Everything for **folder sizes in the Details view** and clears its size cache every **1000 ms**. That makes Explorer repaint the file list repeatedly — exactly the “refresh every second” feeling and it breaks rename.

**Fix (recommended):** In Windhawk → **Explorer Details - Better File Sizes** → set **Calculate folder sizes** to:

- `disabled` (best for rename stability), or
- `withShiftKey` (sizes only while holding Shift)

Then restart Explorer once (Task Manager → restart `explorer.exe`).

## Other Explorer hooks on this PC (lower probability)

These are injected into `explorer.exe` but are less likely to cause a strict 1-second F5 loop:

| Mod | Risk | Why |
|-----|------|-----|
| explorer-treeitem-tweaker | Medium | Redraws nav tree on window events |
| explorer-treeline-killer | Medium | Heavy tree paint during navigation |
| windows-11-file-explorer-styler | Low–medium | XAML theme refresh |
| never-auto-expand-explorer-tree-items | Low | Hooks tree expand only |
| zen-desktop-toggle-icons | Low | 1s timer on **desktop** icons only, not normal folders |
| Nilesoft Shell (`shell.dll`) | Low–medium | Context menu shell; not a 1s poll |
| win32-ui-modernizer | N/A now | Installed but **not** loaded in explorer at time of check |

## Not from SystemMaintenance scripts

No script in `C:\SystemMaintenance` runs on a 1-second loop or watches folders while idle. `SystemMaintenance` files were not changing every second during testing.

## Windows July 2026 updates

Updates (KB5101650 → build **26200.8875**, .NET 8/9, Defender) can change Explorer + shell behavior. If disabling folder-size calculation does not help, temporarily disable Windhawk Explorer mods one by one — start with **treeitem-tweaker** and **treeline-killer**.

## Quick isolation test (5 minutes)

1. Windhawk: set **Calculate folder sizes** → `disabled` on Better File Sizes.
2. Restart Explorer.
3. Open any folder, switch to **Details**, try rename — should stay stable.
4. If still broken: disable **Explorer TreeItem Tweaker** + **Explorer TreeLine Killer**, restart Explorer, test again.

## Tray icon (separate issue)

Tray Audio Output **v1.5.6** includes auto icon recovery. In Windhawk: disable → enable **Tray Audio Output** once after recompiling so the new build loads.
