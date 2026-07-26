# Tray icon disappearing — root cause

**Mod:** `tray-audio-output` (Tray Audio Output)  
**Symptom:** Functions keep working (volume/mute/device callbacks), but the speaker tray icon vanishes or becomes a blank slot. It only comes back after disable → enable in Windhawk.

## What causes it

1. **Explorer notify-icon GUID slot goes stale**  
   The mod registers with `Shell_NotifyIconW` using `NIF_GUID` + a fixed `TRAY_AUDIO_GUID`. Windows Explorer can drop or blank that slot while the mod process is still alive (Explorer tray rebuild, other apps stressing the notify area, pin/overflow cache glitches). Audio COM callbacks still run, so the mod feels “alive,” but the visible icon is gone.

2. **Recovery only ran when `NIM_MODIFY` failed**  
   Older code did DELETE + ADD only if `Shell_NotifyIconW(NIM_MODIFY, …)` returned `FALSE`. In practice Explorer often returns `TRUE` for MODIFY even after the icon is already gone or blank. So the icon never self-healed.

3. **`RefreshTrayIconRect` polled forever and never re-added**  
   When `Shell_NotifyIconGetRect` failed (no real icon), a 200 ms timer kept retrying the rect only. That burned CPU for nothing and never called `NIM_ADD` again. Disable/enable worked only because uninit does `NIM_DELETE` and init does a fresh `NIM_ADD`.

4. **High update rate made the bug more visible**  
   Every volume notification posted `WM_UPDATE_TRAY`, which rebuilt overlays and called `NIM_MODIFY`. That is light work, but it increases chances of hitting a bad shell state and was unnecessary when tip/mute/volume had not changed.

## What is *not* the cause

- Missing `ddores.dll` icons on a normal Windows install (indices load fine).
- Chrome “owning” this mod’s GUID (different apps; Chrome can only stress the shared tray system).
- Audio/mirror logic itself — those paths do not delete the tray icon.

## Fix direction (implemented in source, v1.5.6)

- Coalesce tray tip updates (skip no-op MODIFY; debounce volume notifier bursts).
- If the icon rect stays empty, **re-ADD** the GUID icon (rate-limited), instead of polling every 200 ms forever.
- On `TaskbarCreated` / MODIFY failure, force DELETE + ADD + `NOTIFYICON_VERSION_4`.
- Sparse 12 s health timer: if the slot is gone → re-ADD; if the slot exists → soft MODIFY to heal blank bitmaps.
- Idle cost stays near zero (no busy 200 ms loop).
