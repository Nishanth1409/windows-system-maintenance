// ==WindhawkMod==
// @id              per-monitor-wallpaper
// @name            Per-Monitor Wallpaper
// @description     Set and persist wallpapers on extended/external monitors only (primary display is never changed)
// @version         1.6
// @author          You
// @include         explorer.exe
// @architecture    x86-64
// @compilerOptions -lole32 -loleaut32 -lcomdlg32 -lgdi32 -DUNICODE -D_UNICODE -D_WIN32_WINNT=0x0A00 -DNTDDI_VERSION=0x0A000008
// @license         MIT
// ==/WindhawkMod==

// ==WindhawkModReadme==
/*
# Per-Monitor Wallpaper

Windows 11 often resets per-monitor wallpapers after sleep, display changes, or
explorer restarts. This mod keeps your chosen wallpaper on each monitor by
re-applying it automatically.

## Quick setup

1. Compile the mod (Ctrl+B) and **enable** it in Windhawk.
2. Restart Explorer once (Task Manager → Windows Explorer → Restart) after first
   enable, so the mod loads into the desktop process.
3. Set **Extended monitor 1**, **2**, etc. for each external / extended display.
   - The **main (primary) display is never changed** — use Windows Settings for that.
   - Use **location** to pick which physical screen gets each wallpaper.
   - Monitors are numbered **1 = leftmost**, **2 = second from left**, and so on.
4. For a **5th monitor or more**, use **Extended monitor 5–8** or **Additional
   monitors** (add as many entries as you need).
5. **Browse images** — set **Open image browser** to `1` and save settings. A
   window opens with **Browse...** buttons for JPG, PNG, GIF, BMP, and WEBP files.
6. You can still type paths manually in the text fields if you prefer.

## Tips

- Supported formats: JPG, PNG, BMP, GIF, and other formats Windows supports.
- Enable **Disable slideshow** if Windows slideshow keeps overriding your images.
- Enable mod logs to see the **Extended Wallpaper Status** table after each check.
  With no external monitor connected, the table shows `NO EXTENDED DISPLAYS` and
  the mod stays idle (your main wallpaper is untouched).
*/
// ==/WindhawkModReadme==

// ==WindhawkModSettings==
/*
- enabled: true
  $name: Enable mod
  $description: When disabled, wallpapers are not changed or enforced.
- disableSlideshow: true
  $name: Disable slideshow
  $description: >-
    Disables the Windows wallpaper slideshow while this mod is active, which
    helps prevent Windows from resetting per-monitor wallpapers.
- fillMode: fill
  $name: Wallpaper fill mode
  $description: How images are scaled on the desktop.
  $options:
    - fill: Fill
    - fit: Fit
    - stretch: Stretch
    - center: Center
    - tile: Tile
    - span: Span (single image across all monitors — not recommended; affects primary display)
- extendedMonitor1Wallpaper: ""
  $name: Extended monitor 1 wallpaper
  $description: Full image path for the first extended screen (not the primary display).
- extendedMonitor1Position: auto
  $name: Extended monitor 1 location
  $options:
    - auto: Auto (1st extended screen, left to right)
    - leftmost: Leftmost screen
    - rightmost: Rightmost screen
    - monitor1: Monitor 1 (left to right)
    - monitor2: Monitor 2 (left to right)
    - monitor3: Monitor 3 (left to right)
    - monitor4: Monitor 4 (left to right)
    - monitor5: Monitor 5 (left to right)
    - monitor6: Monitor 6 (left to right)
    - monitor7: Monitor 7 (left to right)
    - monitor8: Monitor 8 (left to right)
    - monitor9: Monitor 9 (left to right)
    - monitor10: Monitor 10 (left to right)
    - monitor11: Monitor 11 (left to right)
    - monitor12: Monitor 12 (left to right)
- extendedMonitor2Wallpaper: ""
  $name: Extended monitor 2 wallpaper
- extendedMonitor2Position: auto
  $name: Extended monitor 2 location
  $options:
    - auto: Auto (2nd extended screen, left to right)
    - leftmost: Leftmost screen
    - rightmost: Rightmost screen
    - monitor1: Monitor 1 (left to right)
    - monitor2: Monitor 2 (left to right)
    - monitor3: Monitor 3 (left to right)
    - monitor4: Monitor 4 (left to right)
    - monitor5: Monitor 5 (left to right)
    - monitor6: Monitor 6 (left to right)
    - monitor7: Monitor 7 (left to right)
    - monitor8: Monitor 8 (left to right)
    - monitor9: Monitor 9 (left to right)
    - monitor10: Monitor 10 (left to right)
    - monitor11: Monitor 11 (left to right)
    - monitor12: Monitor 12 (left to right)
- extendedMonitor3Wallpaper: ""
  $name: Extended monitor 3 wallpaper
- extendedMonitor3Position: auto
  $name: Extended monitor 3 location
  $options:
    - auto: Auto (3rd extended screen, left to right)
    - leftmost: Leftmost screen
    - rightmost: Rightmost screen
    - monitor1: Monitor 1 (left to right)
    - monitor2: Monitor 2 (left to right)
    - monitor3: Monitor 3 (left to right)
    - monitor4: Monitor 4 (left to right)
    - monitor5: Monitor 5 (left to right)
    - monitor6: Monitor 6 (left to right)
    - monitor7: Monitor 7 (left to right)
    - monitor8: Monitor 8 (left to right)
    - monitor9: Monitor 9 (left to right)
    - monitor10: Monitor 10 (left to right)
    - monitor11: Monitor 11 (left to right)
    - monitor12: Monitor 12 (left to right)
- extendedMonitor4Wallpaper: ""
  $name: Extended monitor 4 wallpaper
- extendedMonitor4Position: auto
  $name: Extended monitor 4 location
  $options:
    - auto: Auto (4th extended screen, left to right)
    - leftmost: Leftmost screen
    - rightmost: Rightmost screen
    - monitor1: Monitor 1 (left to right)
    - monitor2: Monitor 2 (left to right)
    - monitor3: Monitor 3 (left to right)
    - monitor4: Monitor 4 (left to right)
    - monitor5: Monitor 5 (left to right)
    - monitor6: Monitor 6 (left to right)
    - monitor7: Monitor 7 (left to right)
    - monitor8: Monitor 8 (left to right)
    - monitor9: Monitor 9 (left to right)
    - monitor10: Monitor 10 (left to right)
    - monitor11: Monitor 11 (left to right)
    - monitor12: Monitor 12 (left to right)
- extendedMonitor5Wallpaper: ""
  $name: Extended monitor 5 wallpaper
- extendedMonitor5Position: auto
  $name: Extended monitor 5 location
  $options:
    - auto: Auto (5th extended screen, left to right)
    - leftmost: Leftmost screen
    - rightmost: Rightmost screen
    - monitor1: Monitor 1 (left to right)
    - monitor2: Monitor 2 (left to right)
    - monitor3: Monitor 3 (left to right)
    - monitor4: Monitor 4 (left to right)
    - monitor5: Monitor 5 (left to right)
    - monitor6: Monitor 6 (left to right)
    - monitor7: Monitor 7 (left to right)
    - monitor8: Monitor 8 (left to right)
    - monitor9: Monitor 9 (left to right)
    - monitor10: Monitor 10 (left to right)
    - monitor11: Monitor 11 (left to right)
    - monitor12: Monitor 12 (left to right)
- extendedMonitor6Wallpaper: ""
  $name: Extended monitor 6 wallpaper
- extendedMonitor6Position: auto
  $name: Extended monitor 6 location
  $options:
    - auto: Auto (6th extended screen, left to right)
    - leftmost: Leftmost screen
    - rightmost: Rightmost screen
    - monitor1: Monitor 1 (left to right)
    - monitor2: Monitor 2 (left to right)
    - monitor3: Monitor 3 (left to right)
    - monitor4: Monitor 4 (left to right)
    - monitor5: Monitor 5 (left to right)
    - monitor6: Monitor 6 (left to right)
    - monitor7: Monitor 7 (left to right)
    - monitor8: Monitor 8 (left to right)
    - monitor9: Monitor 9 (left to right)
    - monitor10: Monitor 10 (left to right)
    - monitor11: Monitor 11 (left to right)
    - monitor12: Monitor 12 (left to right)
- extendedMonitor7Wallpaper: ""
  $name: Extended monitor 7 wallpaper
- extendedMonitor7Position: auto
  $name: Extended monitor 7 location
  $options:
    - auto: Auto (7th extended screen, left to right)
    - leftmost: Leftmost screen
    - rightmost: Rightmost screen
    - monitor1: Monitor 1 (left to right)
    - monitor2: Monitor 2 (left to right)
    - monitor3: Monitor 3 (left to right)
    - monitor4: Monitor 4 (left to right)
    - monitor5: Monitor 5 (left to right)
    - monitor6: Monitor 6 (left to right)
    - monitor7: Monitor 7 (left to right)
    - monitor8: Monitor 8 (left to right)
    - monitor9: Monitor 9 (left to right)
    - monitor10: Monitor 10 (left to right)
    - monitor11: Monitor 11 (left to right)
    - monitor12: Monitor 12 (left to right)
- extendedMonitor8Wallpaper: ""
  $name: Extended monitor 8 wallpaper
- extendedMonitor8Position: auto
  $name: Extended monitor 8 location
  $options:
    - auto: Auto (8th extended screen, left to right)
    - leftmost: Leftmost screen
    - rightmost: Rightmost screen
    - monitor1: Monitor 1 (left to right)
    - monitor2: Monitor 2 (left to right)
    - monitor3: Monitor 3 (left to right)
    - monitor4: Monitor 4 (left to right)
    - monitor5: Monitor 5 (left to right)
    - monitor6: Monitor 6 (left to right)
    - monitor7: Monitor 7 (left to right)
    - monitor8: Monitor 8 (left to right)
    - monitor9: Monitor 9 (left to right)
    - monitor10: Monitor 10 (left to right)
    - monitor11: Monitor 11 (left to right)
    - monitor12: Monitor 12 (left to right)
- extraMonitors:
    - - wallpaper: ""
      - position: monitor5
  $name: Additional monitors
  $description: >-
    Add entries for more monitors (9th, 10th, or more). Position options:
    monitor1-monitor12 (left to right), leftmost, or rightmost.
- openWallpaperPicker: 0
  $name: Open image browser
  $description: >-
    Set to 1 and save settings to open a Browse window for picking wallpaper
    images. Set back to 0 after it opens. Supports JPG, PNG, GIF, BMP, WEBP.
- checkIntervalSeconds: 30
  $name: Check interval (seconds)
  $description: >-
    How often to verify wallpapers are still correct. Windows 11 may reset
    wallpapers after sleep or display changes; this interval controls recovery
    speed.
*/
// ==/WindhawkModSettings==

#include <windows.h>
#include <commdlg.h>
#include <shobjidl.h>

#include <algorithm>
#include <atomic>
#include <string>
#include <vector>

namespace {

struct MonitorBinding {
    std::wstring devicePath;
    std::wstring wallpaperPath;
    LONG left = 0;
    LONG top = 0;
    bool isPrimary = false;
};

struct WallpaperAssignment {
    std::wstring wallpaper;
    std::wstring position;
    int autoExtendedIndex = -1;
};

struct Settings {
    bool enabled = true;
    bool disableSlideshow = true;
    DESKTOP_WALLPAPER_POSITION fillMode = DWPOS_FILL;
    int checkIntervalSeconds = 30;
    std::vector<WallpaperAssignment> assignments;
};

Settings g_settings;
CRITICAL_SECTION g_applyLock;
HANDLE g_workerThread = nullptr;
HANDLE g_wakeEvent = nullptr;
std::atomic<bool> g_unloading{false};
std::atomic<bool> g_applyPending{false};
std::atomic<bool> g_pickerDialogOpen{false};

constexpr wchar_t kPickerWindowClass[] = L"WhPerMonitorWallpaperPickerWnd";

void LoadSettings();
void RequestApply(bool force);

struct WallpaperPickerRow {
    const wchar_t* label;
    const wchar_t* settingKey;
    HWND hEdit = nullptr;
};

struct WallpaperPickerState {
    WallpaperPickerRow rows[8];
    HWND hWnd = nullptr;
};

std::wstring TrimQuotes(std::wstring value) {
    while (!value.empty() && (value.front() == L' ' || value.front() == L'\t')) {
        value.erase(value.begin());
    }
    while (!value.empty() && (value.back() == L' ' || value.back() == L'\t')) {
        value.pop_back();
    }
    if (value.size() >= 2 && value.front() == L'"' && value.back() == L'"') {
        return value.substr(1, value.size() - 2);
    }
    return value;
}

DESKTOP_WALLPAPER_POSITION ParseFillMode(PCWSTR value) {
    if (!value || !*value) {
        return DWPOS_FILL;
    }
    if (_wcsicmp(value, L"fit") == 0) {
        return DWPOS_FIT;
    }
    if (_wcsicmp(value, L"stretch") == 0) {
        return DWPOS_STRETCH;
    }
    if (_wcsicmp(value, L"center") == 0) {
        return DWPOS_CENTER;
    }
    if (_wcsicmp(value, L"tile") == 0) {
        return DWPOS_TILE;
    }
    if (_wcsicmp(value, L"span") == 0) {
        return DWPOS_SPAN;
    }
    return DWPOS_FILL;
}

void SaveWallpaperPath(PCWSTR settingName, const std::wstring& path) {
    Wh_SetStringValue(settingName, path.c_str());
}

std::wstring LoadWallpaperSetting(PCWSTR settingName) {
    wchar_t storedValue[MAX_PATH * 4] = {};
    if (Wh_GetStringValue(settingName, storedValue,
                          ARRAYSIZE(storedValue)) > 0 &&
        storedValue[0]) {
        return TrimQuotes(storedValue);
    }

    PCWSTR value = Wh_GetStringSetting(settingName);
    std::wstring result = value ? TrimQuotes(value) : L"";
    Wh_FreeStringSetting(value);
    return result;
}

bool BrowseForImageFile(HWND owner, std::wstring* outPath) {
    if (!outPath) {
        return false;
    }

    wchar_t fileBuffer[MAX_PATH] = {};
    const wchar_t filter[] =
        L"Image files\0*.jpg;*.jpeg;*.png;*.bmp;*.gif;*.webp;*.jfif\0"
        L"All files\0*.*\0";

    OPENFILENAMEW ofn{};
    ofn.lStructSize = sizeof(ofn);
    ofn.hwndOwner = owner;
    ofn.lpstrFilter = filter;
    ofn.lpstrFile = fileBuffer;
    ofn.nMaxFile = ARRAYSIZE(fileBuffer);
    ofn.Flags = OFN_FILEMUSTEXIST | OFN_PATHMUSTEXIST | OFN_HIDEREADONLY |
                OFN_EXPLORER;
    ofn.lpstrTitle = L"Choose wallpaper image";

    if (!GetOpenFileNameW(&ofn)) {
        return false;
    }

    *outPath = fileBuffer;
    return true;
}

void SavePickerRows(WallpaperPickerState* state) {
    if (!state) {
        return;
    }

    for (const auto& row : state->rows) {
        if (!row.hEdit) {
            continue;
        }

        const int length = GetWindowTextLengthW(row.hEdit);
        std::wstring path(length, L'\0');
        if (length > 0) {
            GetWindowTextW(row.hEdit, path.data(), length + 1);
        }
        SaveWallpaperPath(row.settingKey, path);
        Wh_Log(L"Saved %s = %s", row.settingKey, path.c_str());
    }
}

LRESULT CALLBACK PickerWndProc(HWND hWnd, UINT msg, WPARAM wParam,
                                 LPARAM lParam) {
    auto* state = reinterpret_cast<WallpaperPickerState*>(GetWindowLongPtrW(
        hWnd, GWLP_USERDATA));

    switch (msg) {
        case WM_CREATE: {
            state = reinterpret_cast<WallpaperPickerState*>(
                reinterpret_cast<LPCREATESTRUCT>(lParam)->lpCreateParams);
            SetWindowLongPtrW(hWnd, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(state));
            state->hWnd = hWnd;

            HFONT font = CreateFontW(
                -14, 0, 0, 0, FW_NORMAL, FALSE, FALSE, FALSE, DEFAULT_CHARSET,
                OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS, CLEARTYPE_QUALITY,
                DEFAULT_PITCH | FF_DONTCARE, L"Segoe UI");

            const int browseIdBase = 3000;
            const int editIdBase = 2000;
            int y = 16;

            for (int i = 0; i < 8; i++) {
                CreateWindowExW(0, L"STATIC", state->rows[i].label,
                                WS_CHILD | WS_VISIBLE, 16, y, 120, 22, hWnd,
                                nullptr, nullptr, nullptr);

                state->rows[i].hEdit = CreateWindowExW(
                    WS_EX_CLIENTEDGE, L"EDIT", L"",
                    WS_CHILD | WS_VISIBLE | ES_AUTOHSCROLL | ES_READONLY, 140, y,
                    300, 24, hWnd, (HMENU)(UINT_PTR)(editIdBase + i), nullptr,
                    nullptr);

                CreateWindowExW(0, L"BUTTON", L"Browse...",
                                WS_CHILD | WS_VISIBLE | BS_PUSHBUTTON, 450, y,
                                90, 24, hWnd,
                                (HMENU)(UINT_PTR)(browseIdBase + i), nullptr,
                                nullptr);

                const std::wstring currentPath =
                    LoadWallpaperSetting(state->rows[i].settingKey);
                if (!currentPath.empty()) {
                    SetWindowTextW(state->rows[i].hEdit, currentPath.c_str());
                }

                y += 34;
            }

            CreateWindowExW(0, L"BUTTON", L"Save & Apply",
                            WS_CHILD | WS_VISIBLE | BS_DEFPUSHBUTTON, 300, y + 8,
                            120, 28, hWnd, (HMENU)1001, nullptr, nullptr);
            CreateWindowExW(0, L"BUTTON", L"Cancel", WS_CHILD | WS_VISIBLE, 430,
                            y + 8, 90, 28, hWnd, (HMENU)1002, nullptr, nullptr);

            if (font) {
                EnumChildWindows(
                    hWnd,
                    [](HWND child, LPARAM fontParam) -> BOOL {
                        SendMessageW(child, WM_SETFONT, fontParam, TRUE);
                        return TRUE;
                    },
                    reinterpret_cast<LPARAM>(font));
            }
            return 0;
        }

        case WM_COMMAND: {
            if (!state) {
                break;
            }

            const int id = LOWORD(wParam);
            if (id >= 3000 && id < 3008) {
                const int rowIndex = id - 3000;
                std::wstring path;
                if (BrowseForImageFile(hWnd, &path) &&
                    state->rows[rowIndex].hEdit) {
                    SetWindowTextW(state->rows[rowIndex].hEdit, path.c_str());
                }
                return 0;
            }

            if (id == 1001) {
                SavePickerRows(state);
                LoadSettings();
                RequestApply(true);
                DestroyWindow(hWnd);
                return 0;
            }

            if (id == 1002) {
                DestroyWindow(hWnd);
                return 0;
            }
            break;
        }

        case WM_CLOSE:
            DestroyWindow(hWnd);
            return 0;

        case WM_DESTROY:
            g_pickerDialogOpen = false;
            delete state;
            PostQuitMessage(0);
            return 0;
    }

    return DefWindowProcW(hWnd, msg, wParam, lParam);
}

DWORD WINAPI PickerDialogThreadProc(LPVOID) {
    if (g_pickerDialogOpen.exchange(true)) {
        return 0;
    }

    HINSTANCE instance = GetModuleHandleW(nullptr);
    WNDCLASSEXW wc{};
    wc.cbSize = sizeof(wc);
    wc.lpfnWndProc = PickerWndProc;
    wc.hInstance = instance;
    wc.hCursor = LoadCursorW(nullptr, IDC_ARROW);
    wc.hbrBackground = reinterpret_cast<HBRUSH>(COLOR_WINDOW + 1);
    wc.lpszClassName = kPickerWindowClass;
    RegisterClassExW(&wc);

    auto* state = new WallpaperPickerState();
    state->rows[0] = {L"Extended 1", L"extendedMonitor1Wallpaper"};
    state->rows[1] = {L"Extended 2", L"extendedMonitor2Wallpaper"};
    state->rows[2] = {L"Extended 3", L"extendedMonitor3Wallpaper"};
    state->rows[3] = {L"Extended 4", L"extendedMonitor4Wallpaper"};
    state->rows[4] = {L"Extended 5", L"extendedMonitor5Wallpaper"};
    state->rows[5] = {L"Extended 6", L"extendedMonitor6Wallpaper"};
    state->rows[6] = {L"Extended 7", L"extendedMonitor7Wallpaper"};
    state->rows[7] = {L"Extended 8", L"extendedMonitor8Wallpaper"};

    HWND hWnd = CreateWindowExW(
        WS_EX_DLGMODALFRAME | WS_EX_TOPMOST, kPickerWindowClass,
        L"Per-Monitor Wallpaper - Browse Images (Extended Only)", WS_OVERLAPPED | WS_CAPTION |
            WS_SYSMENU,
        CW_USEDEFAULT, CW_USEDEFAULT, 580, 400, nullptr, nullptr, instance,
        state);
    if (!hWnd) {
        g_pickerDialogOpen = false;
        delete state;
        return 1;
    }

    ShowWindow(hWnd, SW_SHOW);
    UpdateWindow(hWnd);

    MSG msg;
    while (GetMessageW(&msg, nullptr, 0, 0)) {
        TranslateMessage(&msg);
        DispatchMessageW(&msg);
    }

    UnregisterClassW(kPickerWindowClass, instance);
    return 0;
}

void StartWallpaperPickerDialog() {
    if (g_unloading || g_pickerDialogOpen) {
        return;
    }

    HANDLE thread = CreateThread(nullptr, 0, PickerDialogThreadProc, nullptr, 0,
                                 nullptr);
    if (thread) {
        CloseHandle(thread);
    }
}

std::wstring LoadPositionSetting(PCWSTR settingName, PCWSTR defaultValue) {
    PCWSTR value = Wh_GetStringSetting(settingName);
    std::wstring result =
        (value && *value) ? TrimQuotes(value) : std::wstring(defaultValue);
    Wh_FreeStringSetting(value);
    return result;
}

void LoadExtraMonitorAssignments(std::vector<WallpaperAssignment>* assignments) {
    if (!assignments) {
        return;
    }

    for (int i = 0;; i++) {
        PCWSTR wallpaper =
            Wh_GetStringSetting(L"extraMonitors[%d].wallpaper", i);
        PCWSTR position =
            Wh_GetStringSetting(L"extraMonitors[%d].position", i);

        const bool hasWallpaper = wallpaper && *wallpaper;
        const bool hasPosition = position && *position;

        if (!hasWallpaper && !hasPosition) {
            Wh_FreeStringSetting(wallpaper);
            Wh_FreeStringSetting(position);
            break;
        }

        if (hasWallpaper) {
            WallpaperAssignment assignment;
            assignment.wallpaper = TrimQuotes(wallpaper);
            assignment.position =
                hasPosition ? TrimQuotes(position) : L"monitor5";
            assignment.autoExtendedIndex = -1;
            assignments->push_back(std::move(assignment));
        }

        Wh_FreeStringSetting(wallpaper);
        Wh_FreeStringSetting(position);
    }
}

void BuildAssignmentsFromSettings() {
    g_settings.assignments.clear();

    struct ExtendedSlot {
        PCWSTR wallpaperKey;
        PCWSTR positionKey;
        int autoExtendedIndex;
    };

    const ExtendedSlot extendedSlots[] = {
        {L"extendedMonitor1Wallpaper", L"extendedMonitor1Position", 0},
        {L"extendedMonitor2Wallpaper", L"extendedMonitor2Position", 1},
        {L"extendedMonitor3Wallpaper", L"extendedMonitor3Position", 2},
        {L"extendedMonitor4Wallpaper", L"extendedMonitor4Position", 3},
        {L"extendedMonitor5Wallpaper", L"extendedMonitor5Position", 4},
        {L"extendedMonitor6Wallpaper", L"extendedMonitor6Position", 5},
        {L"extendedMonitor7Wallpaper", L"extendedMonitor7Position", 6},
        {L"extendedMonitor8Wallpaper", L"extendedMonitor8Position", 7},
    };

    for (const auto& slot : extendedSlots) {
        const std::wstring wallpaper = LoadWallpaperSetting(slot.wallpaperKey);
        if (wallpaper.empty()) {
            continue;
        }

        WallpaperAssignment assignment;
        assignment.wallpaper = wallpaper;
        assignment.position =
            LoadPositionSetting(slot.positionKey, L"auto");
        assignment.autoExtendedIndex = slot.autoExtendedIndex;
        g_settings.assignments.push_back(std::move(assignment));
    }

    LoadExtraMonitorAssignments(&g_settings.assignments);
}

MonitorBinding* ResolveMonitorByPosition(
    std::vector<MonitorBinding>& monitors,
    const std::vector<MonitorBinding*>& extendedSorted,
    const std::wstring& position,
    int autoExtendedIndex) {
    if (monitors.empty()) {
        return nullptr;
    }

    if (position.empty() || _wcsicmp(position.c_str(), L"auto") == 0) {
        if (autoExtendedIndex >= 0 &&
            static_cast<size_t>(autoExtendedIndex) < extendedSorted.size()) {
            return extendedSorted[autoExtendedIndex];
        }
        return nullptr;
    }

    if (_wcsicmp(position.c_str(), L"primary") == 0) {
        Wh_Log(L"Location 'primary' is not used in extended-only mode");
        return nullptr;
    }

    if (_wcsicmp(position.c_str(), L"leftmost") == 0) {
        return &monitors.front();
    }

    if (_wcsicmp(position.c_str(), L"rightmost") == 0) {
        return &monitors.back();
    }

    if (_wcsnicmp(position.c_str(), L"monitor", 7) == 0) {
        const int monitorIndex = _wtoi(position.c_str() + 7);
        if (monitorIndex >= 1 &&
            static_cast<size_t>(monitorIndex) <= monitors.size()) {
            return &monitors[monitorIndex - 1];
        }
    }

    return nullptr;
}

bool MonitorDevicePathsMatch(PCWSTR wallpaperDevicePath,
                             PCWSTR displayDeviceId) {
    if (!wallpaperDevicePath || !*wallpaperDevicePath || !displayDeviceId ||
        !*displayDeviceId) {
        return false;
    }

    if (_wcsicmp(wallpaperDevicePath, displayDeviceId) == 0) {
        return true;
    }

    return wcsstr(wallpaperDevicePath, displayDeviceId) != nullptr ||
           wcsstr(displayDeviceId, wallpaperDevicePath) != nullptr;
}

bool FileExists(PCWSTR path) {
    if (!path || !*path) {
        return false;
    }

    DWORD attrs = GetFileAttributesW(path);
    return attrs != INVALID_FILE_ATTRIBUTES &&
           !(attrs & FILE_ATTRIBUTE_DIRECTORY);
}

std::wstring NormalizePath(std::wstring path) {
    if (path.empty()) {
        return path;
    }

    wchar_t buffer[MAX_PATH];
    DWORD length = GetFullPathNameW(path.c_str(), ARRAYSIZE(buffer), buffer,
                                  nullptr);
    if (length == 0 || length >= ARRAYSIZE(buffer)) {
        return path;
    }

    std::wstring normalized(buffer, length);
    std::transform(normalized.begin(), normalized.end(), normalized.begin(),
                   towlower);
    return normalized;
}

bool PathsEqual(PCWSTR a, PCWSTR b) {
    if (!a || !*a) {
        return !b || !*b;
    }
    if (!b || !*b) {
        return false;
    }
    return NormalizePath(a) == NormalizePath(b);
}

HRESULT CreateDesktopWallpaper(IDesktopWallpaper** outDesktopWallpaper) {
    *outDesktopWallpaper = nullptr;

    HRESULT hr = CoCreateInstance(__uuidof(DesktopWallpaper), nullptr,
                                  CLSCTX_LOCAL_SERVER,
                                  __uuidof(IDesktopWallpaper),
                                  reinterpret_cast<void**>(outDesktopWallpaper));
    if (SUCCEEDED(hr)) {
        return hr;
    }

    return CoCreateInstance(__uuidof(DesktopWallpaper), nullptr, CLSCTX_ALL,
                            __uuidof(IDesktopWallpaper),
                            reinterpret_cast<void**>(outDesktopWallpaper));
}

void RefreshDesktop(PCWSTR wallpaperPath) {
    if (wallpaperPath && *wallpaperPath) {
        SystemParametersInfoW(SPI_SETDESKWALLPAPER, 0, (PVOID)wallpaperPath,
                              SPIF_UPDATEINIFILE | SPIF_SENDWININICHANGE);
    }

    SendMessageTimeoutW(HWND_BROADCAST, WM_SETTINGCHANGE, 0, (LPARAM)L"Desktop",
                        SMTO_ABORTIFHUNG, 2000, nullptr);

    HWND progman = FindWindowW(L"Progman", nullptr);
    if (progman) {
        SendMessageTimeoutW(progman, 0x052C, 0xD, 0, SMTO_ABORTIFHUNG, 2000,
                          nullptr);
    }
}

bool GetMonitorRect(IDesktopWallpaper* desktopWallpaper,
                    PCWSTR devicePath,
                    RECT* rect) {
    if (!desktopWallpaper || !devicePath || !rect) {
        return false;
    }

    return SUCCEEDED(desktopWallpaper->GetMonitorRECT(devicePath, rect));
}

std::vector<MonitorBinding> BuildMonitorBindings(
    IDesktopWallpaper* desktopWallpaper) {
    std::vector<MonitorBinding> monitors;

    UINT monitorCount = 0;
    if (FAILED(desktopWallpaper->GetMonitorDevicePathCount(&monitorCount))) {
        return monitors;
    }

    monitors.reserve(monitorCount);
    for (UINT i = 0; i < monitorCount; i++) {
        PWSTR devicePath = nullptr;
        if (FAILED(desktopWallpaper->GetMonitorDevicePathAt(i, &devicePath)) ||
            !devicePath) {
            continue;
        }

        MonitorBinding binding;
        binding.devicePath = devicePath;
        CoTaskMemFree(devicePath);

        RECT rect{};
        if (GetMonitorRect(desktopWallpaper, binding.devicePath.c_str(),
                           &rect)) {
            binding.left = rect.left;
            binding.top = rect.top;
        }

        monitors.push_back(std::move(binding));
    }

    std::sort(monitors.begin(), monitors.end(),
              [](const MonitorBinding& a, const MonitorBinding& b) {
                  if (a.left != b.left) {
                      return a.left < b.left;
                  }
                  return a.top < b.top;
              });

    return monitors;
}

void DetectPrimaryMonitors(std::vector<MonitorBinding>* monitors) {
    if (!monitors) {
        return;
    }

    for (auto& monitor : *monitors) {
        monitor.isPrimary = false;
    }

    auto monitorEnumProc = [&](HMONITOR hMonitor) -> BOOL {
        MONITORINFOEXW monitorInfo{};
        monitorInfo.cbSize = sizeof(monitorInfo);
        if (!GetMonitorInfoW(hMonitor, &monitorInfo)) {
            return TRUE;
        }

        DISPLAY_DEVICEW displayDevice{};
        displayDevice.cb = sizeof(displayDevice);
        if (!EnumDisplayDevicesW(monitorInfo.szDevice, 0, &displayDevice,
                                 EDD_GET_DEVICE_INTERFACE_NAME)) {
            return TRUE;
        }

        const bool isPrimary =
            (monitorInfo.dwFlags & MONITORINFOF_PRIMARY) != 0;

        for (auto& monitor : *monitors) {
            if (MonitorDevicePathsMatch(monitor.devicePath.c_str(),
                                        displayDevice.DeviceID)) {
                monitor.isPrimary = isPrimary;
            }
        }

        return TRUE;
    };

    EnumDisplayMonitors(
        nullptr, nullptr,
        [](HMONITOR hMonitor, HDC hdc, LPRECT lprcMonitor,
           LPARAM dwData) -> BOOL {
            auto& proc = *reinterpret_cast<decltype(monitorEnumProc)*>(dwData);
            return proc(hMonitor);
        },
        reinterpret_cast<LPARAM>(&monitorEnumProc));

    for (size_t i = 0; i < monitors->size(); i++) {
        const auto& monitor = monitors->at(i);
        Wh_Log(L"Monitor M%zu: %s (left=%ld): %s", i + 1,
               monitor.isPrimary ? L"PRIMARY (not managed)" : L"EXTENDED",
               monitor.left, monitor.devicePath.c_str());
    }
}

void AssignConfiguredWallpapers(std::vector<MonitorBinding>* monitors) {
    if (!monitors) {
        return;
    }

    DetectPrimaryMonitors(monitors);

    bool hasPrimary = false;
    for (const auto& monitor : *monitors) {
        if (monitor.isPrimary) {
            hasPrimary = true;
            break;
        }
    }

    if (!hasPrimary && !monitors->empty()) {
        monitors->front().isPrimary = true;
        Wh_Log(L"Primary monitor not detected, using leftmost screen as primary");
    }

    std::vector<MonitorBinding*> extendedSorted;
    extendedSorted.reserve(monitors->size());
    for (auto& monitor : *monitors) {
        if (!monitor.isPrimary) {
            extendedSorted.push_back(&monitor);
        }
    }

    std::sort(extendedSorted.begin(), extendedSorted.end(),
              [](const MonitorBinding* a, const MonitorBinding* b) {
                  if (a->left != b->left) {
                      return a->left < b->left;
                  }
                  return a->top < b->top;
              });

    std::vector<bool> assigned(monitors->size(), false);

    for (const auto& assignment : g_settings.assignments) {
        if (assignment.wallpaper.empty() ||
            !FileExists(assignment.wallpaper.c_str())) {
            continue;
        }

        MonitorBinding* target = ResolveMonitorByPosition(
            *monitors, extendedSorted, assignment.position,
            assignment.autoExtendedIndex);
        if (!target) {
            Wh_Log(L"No extended monitor matched location '%s' for wallpaper %s",
                   assignment.position.c_str(), assignment.wallpaper.c_str());
            continue;
        }

        if (target->isPrimary) {
            Wh_Log(L"Skipping primary monitor for wallpaper %s (extended-only mode)",
                   assignment.wallpaper.c_str());
            continue;
        }

        const size_t targetIndex = static_cast<size_t>(target - &monitors->front());
        if (assigned[targetIndex]) {
            Wh_Log(L"Monitor at left=%ld already assigned, skipping %s",
                   target->left, assignment.wallpaper.c_str());
            continue;
        }

        target->wallpaperPath = assignment.wallpaper;
        assigned[targetIndex] = true;
        Wh_Log(L"Assigned wallpaper to extended monitor at left=%ld (location=%s): %s",
               target->left, assignment.position.c_str(),
               assignment.wallpaper.c_str());
    }
}

void DisableSlideshowInRegistry() {
    if (!g_settings.disableSlideshow) {
        return;
    }

    // 1 = picture, 2 = slideshow in recent Windows builds.
    const DWORD backgroundType = 1;
    LSTATUS status = RegSetKeyValueW(
        HKEY_CURRENT_USER,
        L"Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\Wallpapers",
        L"BackgroundType", REG_DWORD, &backgroundType, sizeof(backgroundType));
    if (status != ERROR_SUCCESS) {
        Wh_Log(L"Failed to set BackgroundType registry value: %ld", status);
    }
}

bool ApplyFillMode(IDesktopWallpaper* desktopWallpaper) {
    if (!desktopWallpaper) {
        return false;
    }

    HRESULT hr = desktopWallpaper->SetPosition(g_settings.fillMode);
    if (FAILED(hr)) {
        Wh_Log(L"SetPosition failed: 0x%08X", hr);
        return false;
    }

    return true;
}

bool GetCurrentWallpaper(IDesktopWallpaper* desktopWallpaper,
                         PCWSTR devicePath,
                         std::wstring* wallpaperPath) {
    if (!desktopWallpaper || !devicePath || !wallpaperPath) {
        return false;
    }

    PWSTR currentPath = nullptr;
    HRESULT hr = desktopWallpaper->GetWallpaper(devicePath, &currentPath);
    if (FAILED(hr) || !currentPath) {
        return false;
    }

    *wallpaperPath = currentPath;
    CoTaskMemFree(currentPath);
    return true;
}

const wchar_t* ExtendedStatusText(bool isPrimary,
                                  const std::wstring& desired,
                                  const std::wstring& current) {
    if (isPrimary) {
        return L"SKIPPED (primary not managed)";
    }
    if (desired.empty()) {
        return L"NO ASSIGNMENT";
    }
    if (!FileExists(desired.c_str())) {
        return L"FILE MISSING";
    }
    if (PathsEqual(current.c_str(), desired.c_str())) {
        return L"OK (matches)";
    }
    return L"NEEDS APPLY";
}

void LogExtendedWallpaperStatusTable(
    IDesktopWallpaper* desktopWallpaper,
    const std::vector<MonitorBinding>& monitors) {
    Wh_Log(L"========== Extended Wallpaper Status ==========");
    Wh_Log(L"Mode: extended displays only — primary wallpaper is never changed");

    size_t extendedCount = 0;
    for (const auto& monitor : monitors) {
        if (!monitor.isPrimary) {
            extendedCount++;
        }
    }

    Wh_Log(L"Monitors: %zu total | %zu extended | %zu primary",
           monitors.size(), extendedCount, monitors.size() - extendedCount);

    if (extendedCount == 0) {
        Wh_Log(L"RESULT: NO EXTENDED DISPLAYS — mod idle, main wallpaper untouched");
        Wh_Log(L"==============================================");
        return;
    }

    Wh_Log(L"+-----+----------+--------+---------------------------+");
    Wh_Log(L"|  #  | Role     |  Left  | Status                    |");
    Wh_Log(L"+-----+----------+--------+---------------------------+");

    bool anyExtendedConfigured = false;
    bool allConfiguredMatch = true;

    for (size_t i = 0; i < monitors.size(); i++) {
        const auto& monitor = monitors[i];
        std::wstring currentPath;
        GetCurrentWallpaper(desktopWallpaper, monitor.devicePath.c_str(),
                            &currentPath);

        const wchar_t* statusText =
            ExtendedStatusText(monitor.isPrimary, monitor.wallpaperPath,
                               currentPath);

        Wh_Log(L"| M%d | %s | left=%ld | %s",
               static_cast<int>(i + 1),
               monitor.isPrimary ? L"PRIMARY" : L"EXTENDED", monitor.left,
               statusText);

        if (!monitor.wallpaperPath.empty()) {
            Wh_Log(L"|     desired: %s", monitor.wallpaperPath.c_str());
        }
        if (!currentPath.empty()) {
            Wh_Log(L"|     current: %s", currentPath.c_str());
        }

        if (monitor.isPrimary) {
            continue;
        }

        if (!monitor.wallpaperPath.empty()) {
            anyExtendedConfigured = true;
            if (!FileExists(monitor.wallpaperPath.c_str()) ||
                !PathsEqual(currentPath.c_str(), monitor.wallpaperPath.c_str())) {
                allConfiguredMatch = false;
            }
        }
    }

    Wh_Log(L"+-----+----------+--------+---------------------------+");

    if (!anyExtendedConfigured) {
        Wh_Log(L"RESULT: Extended displays detected but no wallpaper paths configured");
    } else if (allConfiguredMatch) {
        Wh_Log(L"RESULT: WORKING — all configured extended wallpapers match");
    } else {
        Wh_Log(L"RESULT: PENDING/APPLYING — extended wallpaper differs from desired");
    }

    Wh_Log(L"==============================================");
}

bool NeedsReapply(IDesktopWallpaper* desktopWallpaper,
                  const std::vector<MonitorBinding>& monitors) {
    if (g_settings.fillMode == DWPOS_SPAN) {
        Wh_Log(L"Span mode skipped in extended-only mode (would affect primary display)");
        return false;
    }

    for (const auto& monitor : monitors) {
        if (monitor.isPrimary || monitor.wallpaperPath.empty()) {
            continue;
        }

        std::wstring currentPath;
        if (!GetCurrentWallpaper(desktopWallpaper, monitor.devicePath.c_str(),
                                 &currentPath)) {
            return true;
        }

        if (!PathsEqual(currentPath.c_str(), monitor.wallpaperPath.c_str())) {
            Wh_Log(L"Extended wallpaper mismatch at left=%ld: current=%s desired=%s",
                   monitor.left, currentPath.c_str(),
                   monitor.wallpaperPath.c_str());
            return true;
        }
    }

    return false;
}

bool ApplyWallpapers(bool force) {
    if (!g_settings.enabled) {
        Wh_Log(L"Mod disabled, skipping wallpaper apply");
        return true;
    }

    bool hasConfiguredWallpaper = false;
    for (const auto& assignment : g_settings.assignments) {
        if (!assignment.wallpaper.empty() &&
            FileExists(assignment.wallpaper.c_str())) {
            hasConfiguredWallpaper = true;
            break;
        }
    }

    if (!hasConfiguredWallpaper) {
        Wh_Log(L"No valid wallpaper paths configured (check file paths exist)");
        return true;
    }

    Wh_Log(L"Applying extended wallpapers only (force=%d)", force);

    HRESULT coInit = CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
    const bool coInitialized = SUCCEEDED(coInit);

    IDesktopWallpaper* desktopWallpaper = nullptr;
    HRESULT hr = CreateDesktopWallpaper(&desktopWallpaper);
    if (FAILED(hr) || !desktopWallpaper) {
        Wh_Log(L"Failed to create IDesktopWallpaper: 0x%08X", hr);
        if (coInitialized) {
            CoUninitialize();
        }
        return false;
    }

    DisableSlideshowInRegistry();
    ApplyFillMode(desktopWallpaper);

    std::vector<MonitorBinding> monitors =
        BuildMonitorBindings(desktopWallpaper);
    if (monitors.empty()) {
        Wh_Log(L"No monitors detected");
        desktopWallpaper->Release();
        if (coInitialized) {
            CoUninitialize();
        }
        return false;
    }

    AssignConfiguredWallpapers(&monitors);
    LogExtendedWallpaperStatusTable(desktopWallpaper, monitors);

    if (!force && !NeedsReapply(desktopWallpaper, monitors)) {
        Wh_Log(L"Extended wallpapers already correct");
        desktopWallpaper->Release();
        if (coInitialized) {
            CoUninitialize();
        }
        return true;
    }

    bool success = true;
    int appliedCount = 0;
    std::wstring refreshPath;

    if (g_settings.fillMode == DWPOS_SPAN) {
        Wh_Log(L"Span fill mode not applied — extended-only mode protects primary display");
    } else {
        for (const auto& monitor : monitors) {
            if (monitor.isPrimary) {
                continue;
            }

            if (monitor.wallpaperPath.empty()) {
                continue;
            }

            hr = desktopWallpaper->SetWallpaper(monitor.devicePath.c_str(),
                                                monitor.wallpaperPath.c_str());
            if (FAILED(hr)) {
                Wh_Log(L"SetWallpaper failed for extended monitor %s: 0x%08X",
                       monitor.devicePath.c_str(), hr);
                success = false;
                continue;
            }

            appliedCount++;
            if (refreshPath.empty()) {
                refreshPath = monitor.wallpaperPath;
            }

            Wh_Log(L"Applied extended wallpaper (left=%ld): %s", monitor.left,
                   monitor.wallpaperPath.c_str());
        }
    }

    if (appliedCount == 0) {
        size_t extendedCount = 0;
        for (const auto& monitor : monitors) {
            if (!monitor.isPrimary) {
                extendedCount++;
            }
        }
        if (extendedCount == 0) {
            Wh_Log(L"No extended displays — nothing to apply (primary untouched)");
        } else {
            Wh_Log(L"No extended wallpaper was applied (check paths and locations)");
            success = false;
        }
    } else {
        RefreshDesktop(refreshPath.c_str());
        LogExtendedWallpaperStatusTable(desktopWallpaper, monitors);
    }

    desktopWallpaper->Release();
    if (coInitialized) {
        CoUninitialize();
    }

    return success;
}

void SafeApplyWallpapers(bool force) {
    EnterCriticalSection(&g_applyLock);
    ApplyWallpapers(force);
    LeaveCriticalSection(&g_applyLock);
}

void RequestApply(bool force) {
    if (force) {
        g_applyPending.store(true);
    }

    if (g_wakeEvent) {
        SetEvent(g_wakeEvent);
    }
}

void LoadSettings() {
    g_settings.enabled = Wh_GetIntSetting(L"enabled");
    g_settings.disableSlideshow = Wh_GetIntSetting(L"disableSlideshow");
    g_settings.checkIntervalSeconds =
        Wh_GetIntSetting(L"checkIntervalSeconds");
    if (g_settings.checkIntervalSeconds < 5) {
        g_settings.checkIntervalSeconds = 5;
    }

    PCWSTR fillMode = Wh_GetStringSetting(L"fillMode");
    g_settings.fillMode = ParseFillMode(fillMode);
    if (fillMode) {
        Wh_FreeStringSetting(fillMode);
    }

    BuildAssignmentsFromSettings();

    Wh_Log(L"Loaded settings: enabled=%d, extended assignments=%zu, interval=%ds",
           g_settings.enabled, g_settings.assignments.size(),
           g_settings.checkIntervalSeconds);
}

DWORD WINAPI WorkerThreadProc(LPVOID) {
    Wh_Log(L"Worker thread started");

    const HRESULT coInit = CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
    const bool coInitialized = SUCCEEDED(coInit);

    SafeApplyWallpapers(true);

    while (!g_unloading) {
        const DWORD waitMs =
            (DWORD)std::max(5, g_settings.checkIntervalSeconds) * 1000;
        const DWORD waitResult =
            WaitForSingleObject(g_wakeEvent, waitMs);

        if (g_unloading) {
            break;
        }

        const bool force = g_applyPending.exchange(false);
        if (waitResult == WAIT_OBJECT_0 || force) {
            SafeApplyWallpapers(true);
        } else {
            SafeApplyWallpapers(false);
        }
    }

    if (coInitialized) {
        CoUninitialize();
    }

    Wh_Log(L"Worker thread stopped");
    return 0;
}

void StartMonitoring() {
    if (g_workerThread) {
        return;
    }

    InitializeCriticalSection(&g_applyLock);
    g_wakeEvent = CreateEventW(nullptr, FALSE, FALSE, nullptr);
    if (!g_wakeEvent) {
        Wh_Log(L"Failed to create wake event");
        DeleteCriticalSection(&g_applyLock);
        return;
    }

    g_workerThread = CreateThread(nullptr, 0, WorkerThreadProc, nullptr, 0,
                                  nullptr);
    if (!g_workerThread) {
        Wh_Log(L"Failed to create worker thread: %u", GetLastError());
        CloseHandle(g_wakeEvent);
        g_wakeEvent = nullptr;
        DeleteCriticalSection(&g_applyLock);
    }
}

void StopMonitoring() {
    g_unloading = true;

    if (g_wakeEvent) {
        SetEvent(g_wakeEvent);
    }

    if (g_workerThread) {
        WaitForSingleObject(g_workerThread, INFINITE);
        CloseHandle(g_workerThread);
        g_workerThread = nullptr;
    }

    if (g_wakeEvent) {
        CloseHandle(g_wakeEvent);
        g_wakeEvent = nullptr;
    }

    DeleteCriticalSection(&g_applyLock);
}

}  // namespace

BOOL Wh_ModInit() {
    Wh_Log(L"Init in explorer.exe");
    LoadSettings();
    return TRUE;
}

void Wh_ModAfterInit() {
    Wh_Log(L"AfterInit");
    StartMonitoring();
}

void Wh_ModUninit() {
    Wh_Log(L"Uninit");
    StopMonitoring();
}

BOOL Wh_ModSettingsChanged(BOOL* bReload) {
    Wh_Log(L"SettingsChanged");

    const bool openPicker = Wh_GetIntSetting(L"openWallpaperPicker") != 0;
    LoadSettings();

    if (openPicker) {
        StartWallpaperPickerDialog();
    }

    RequestApply(true);
    *bReload = FALSE;
    return TRUE;
}
