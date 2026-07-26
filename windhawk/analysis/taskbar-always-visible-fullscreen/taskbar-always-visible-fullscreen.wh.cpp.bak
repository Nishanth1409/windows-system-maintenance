// ==WindhawkMod==
// @id              taskbar-always-visible-fullscreen
// @name            Taskbar Auto-Hide Peek in Fullscreen
// @description     Auto-hide edge peek (mouse to bottom) works in fullscreen apps — same as a normal window
// @version         1.2.3
// @author          SystemMaintenance
// @include         explorer.exe
// @architecture    x86-64
// @compilerOptions -luser32 -ldwmapi -lole32 -loleaut32 -lversion -lpsapi
// @license         MIT
// ==/WindhawkMod==

// Inspired by Taskbar auto-hide when maximized (GPL-3.0) by m417z / ramensoftware.

// ==WindhawkModReadme==
/*
# Taskbar Auto-Hide Peek in Fullscreen

When **Automatically hide the taskbar** is on, move the mouse to the **bottom
edge** and the taskbar should slide up — including in fullscreen games, video,
and browsers (not just F11).

## What it does

- Detects bottom-edge hover and peeks the taskbar
- **Blocks Explorer from immediately hiding** it again while the mouse stays
  at the edge / over the taskbar (this is required for fullscreen)
- Raises the taskbar above fullscreen content while peeked
- When the mouse leaves, hide works at normal auto-hide speed
- Auto-hide **OFF** → mod does nothing
- Apps under **C:\\Riot Games** are excluded by default (VALORANT, League, etc.)

## Setup

1. Settings → Taskbar → enable **Automatically hide the taskbar**.
2. Compile (`Ctrl+B`) and enable this mod in Windhawk.
3. Restart Explorer once.
*/
// ==/WindhawkModReadme==

// ==WindhawkModSettings==
/*
- forceOnTopWhilePeeking: true
  $name: Force on top while peeking
  $description: >-
    Keep the peeked taskbar above fullscreen apps so it is visible and clickable.
- edgeTriggerPixels: 16
  $name: Edge trigger (px)
  $description: >-
    Distance from the bottom of the screen that opens the taskbar. Fullscreen
    apps often steal a thin edge — 16 works better than 2–6.
- peekCheckIntervalMs: 33
  $name: Peek check interval (ms)
  $description: >-
    How often to check the mouse while auto-hide is ON. Lower = snappier peek.
- excludedFolders:
  - "C:\\Riot Games"
  $name: Excluded folders
  $description: >-
    Do not peek the taskbar when the foreground app lives under any of these
    folders (all subfolders / .exe files). Example: C:\Riot Games.
- oldTaskbarOnWin11: false
  $name: Old taskbar on Windows 11
  $description: Enable with ExplorerPatcher / Windows 10-style taskbar on Windows 11.
*/
// ==/WindhawkModSettings==

#include <windhawk_utils.h>

#include <dwmapi.h>
#include <psapi.h>
#include <shellapi.h>

#include <atomic>
#include <cwctype>
#include <mutex>
#include <string>
#include <type_traits>
#include <utility>
#include <unordered_map>
#include <unordered_set>
#include <vector>

struct {
    bool forceOnTopWhilePeeking;
    int edgeTriggerPixels;
    int peekCheckIntervalMs;
    bool oldTaskbarOnWin11;
    std::vector<std::wstring> excludedFolders;
} g_settings;

enum class WinVersion {
    Unsupported,
    Win10,
    Win11,
    Win11_24H2,
};

WinVersion g_winVersion;
std::atomic<bool> g_initialized;
std::atomic<bool> g_explorerPatcherInitialized;

std::mutex g_stateMutex;
std::atomic<HANDLE> g_winEventHookThread;
std::atomic<HANDLE> g_peekWorkerThread;
std::atomic<bool> g_stopPeekWorker;

enum {
    kTrayUITimerHide = 2,
    kTrayUITimerUnhide = 3,
};


void* TrayUI_vftable_IInspectable;
void* TrayUI_vftable_ITrayComponentHost;
void* CSecondaryTray_vftable_ISecondaryTray;

using TrayUI_GetStuckMonitor_t = HMONITOR(WINAPI*)(void* pThis);
using TrayUI__Hide_t = void(WINAPI*)(void* pThis);
using TrayUI_Unhide_t = void(WINAPI*)(void* pThis,
                                      int trayUnhideFlags,
                                      int unhideRequest);
using CSecondaryTray_GetMonitor_t = HMONITOR(WINAPI*)(void* pThis);
using CSecondaryTray__AutoHide_t = void(WINAPI*)(void* pThis, bool param1);
using CSecondaryTray__Unhide_t = void(WINAPI*)(void* pThis,
                                               int trayUnhideFlags,
                                               int unhideRequest);
using TrayUI_WndProc_t = LRESULT(WINAPI*)(void* pThis,
                                          HWND hWnd,
                                          UINT Msg,
                                          WPARAM wParam,
                                          LPARAM lParam,
                                          bool* flag);
using CSecondaryTray_v_WndProc_t = LRESULT(WINAPI*)(void* pThis,
                                                    HWND hWnd,
                                                    UINT Msg,
                                                    WPARAM wParam,
                                                    LPARAM lParam);

TrayUI_GetStuckMonitor_t TrayUI_GetStuckMonitor_Original;
TrayUI__Hide_t TrayUI__Hide_Original;
TrayUI_Unhide_t TrayUI_Unhide_Original;
CSecondaryTray_GetMonitor_t CSecondaryTray_GetMonitor_Original;
CSecondaryTray__AutoHide_t CSecondaryTray__AutoHide_Original;
CSecondaryTray__Unhide_t CSecondaryTray__Unhide_Original;
TrayUI_WndProc_t TrayUI_WndProc_Original;
CSecondaryTray_v_WndProc_t CSecondaryTray_v_WndProc_Original;

struct TaskbarEntry {
    HWND hwnd = nullptr;
    void* trayObject = nullptr;  // TrayUI* / CSecondaryTray*
    bool primary = true;
    HMONITOR monitor = nullptr;
};

std::unordered_map<HWND, TaskbarEntry> g_taskbars;
// While present, Explorer _Hide must not run (same idea as m417z keep-shown).
std::unordered_map<void*, HWND> g_peekingTaskbars;

void DiscoverExistingTaskbarsLocked();

void* QueryViaVtable(void* object, void* vtable) {
    void* ptr = object;
    while (*(void**)ptr != vtable) {
        ptr = (void**)ptr + 1;
    }
    return ptr;
}

void* QueryViaVtableBackwards(void* object, void* vtable) {
    void* ptr = object;
    while (*(void**)ptr != vtable) {
        ptr = (void**)ptr - 1;
    }
    return ptr;
}

HWND FindCurrentProcessTaskbarWnd() {
    HWND hTaskbarWnd = nullptr;

    EnumWindows(
        [](HWND hWnd, LPARAM lParam) -> BOOL {
            DWORD dwProcessId;
            WCHAR className[32];
            if (GetWindowThreadProcessId(hWnd, &dwProcessId) &&
                dwProcessId == GetCurrentProcessId() &&
                GetClassName(hWnd, className, ARRAYSIZE(className)) &&
                _wcsicmp(className, L"Shell_TrayWnd") == 0) {
                *reinterpret_cast<HWND*>(lParam) = hWnd;
                return FALSE;
            }
            return TRUE;
        },
        reinterpret_cast<LPARAM>(&hTaskbarWnd));

    return hTaskbarWnd;
}

bool IsTaskbarWindow(HWND hWnd) {
    WCHAR szClassName[32];
    if (!GetClassName(hWnd, szClassName, ARRAYSIZE(szClassName))) {
        return false;
    }

    return _wcsicmp(szClassName, L"Shell_TrayWnd") == 0 ||
           _wcsicmp(szClassName, L"Shell_SecondaryTrayWnd") == 0;
}

bool IsSystemAutoHideEnabled() {
    APPBARDATA abd{.cbSize = sizeof(APPBARDATA)};
    return (SHAppBarMessage(ABM_GETSTATE, &abd) & ABS_AUTOHIDE) != 0;
}

int GetEdgeTriggerPx(HWND referenceWnd) {
    UINT dpi = 96;
    if (referenceWnd) {
        dpi = GetDpiForWindow(referenceWnd);
    }

    int trigger = g_settings.edgeTriggerPixels;
    if (trigger < 1) {
        trigger = 1;
    }

    return MulDiv(trigger, dpi, 96);
}

bool IsCursorInTaskbarEdgeZone(HMONITOR monitor, HWND referenceWnd) {
    POINT pt{};
    if (!GetCursorPos(&pt)) {
        return false;
    }

    if (MonitorFromPoint(pt, MONITOR_DEFAULTTONEAREST) != monitor) {
        return false;
    }

    MONITORINFO monitorInfo{.cbSize = sizeof(MONITORINFO)};
    if (!GetMonitorInfo(monitor, &monitorInfo)) {
        return false;
    }

    const int trigger = GetEdgeTriggerPx(referenceWnd);
    return pt.y >= monitorInfo.rcMonitor.bottom - trigger;
}

bool IsCursorOverTaskbar(HWND hTaskbarWnd) {
    if (!hTaskbarWnd) {
        return false;
    }

    POINT pt{};
    if (!GetCursorPos(&pt)) {
        return false;
    }

    RECT taskbarRect{};
    if (!GetWindowRect(hTaskbarWnd, &taskbarRect)) {
        return false;
    }

    // Expand hit-test slightly so peek can stick while you click icons.
    InflateRect(&taskbarRect, 0, MulDiv(8, GetDpiForWindow(hTaskbarWnd), 96));
    return PtInRect(&taskbarRect, pt) != FALSE;
}

void NormalizePathInPlace(std::wstring& path) {
    for (wchar_t& ch : path) {
        if (ch == L'/') {
            ch = L'\\';
        }
        ch = towlower(ch);
    }

    while (!path.empty() && (path.back() == L'\\' || path.back() == L' ')) {
        path.pop_back();
    }
}

bool GetProcessImagePath(DWORD processId, std::wstring& outPath) {
    outPath.clear();
    if (!processId) {
        return false;
    }

    HANDLE process =
        OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, processId);
    if (!process) {
        return false;
    }

    WCHAR buffer[MAX_PATH * 2]{};
    DWORD size = ARRAYSIZE(buffer);
    BOOL ok = QueryFullProcessImageNameW(process, 0, buffer, &size);
    CloseHandle(process);

    if (!ok || size == 0) {
        return false;
    }

    outPath.assign(buffer, size);
    NormalizePathInPlace(outPath);
    return true;
}

bool PathIsUnderFolder(const std::wstring& filePath,
                       const std::wstring& folderPath) {
    if (filePath.empty() || folderPath.empty()) {
        return false;
    }

    if (filePath.size() < folderPath.size()) {
        return false;
    }

    if (_wcsnicmp(filePath.c_str(), folderPath.c_str(), folderPath.size()) !=
        0) {
        return false;
    }

    // Exact folder match, or next char is path separator / end.
    if (filePath.size() == folderPath.size()) {
        return true;
    }

    return filePath[folderPath.size()] == L'\\';
}

bool IsForegroundAppExcluded() {
    if (g_settings.excludedFolders.empty()) {
        return false;
    }

    HWND foreground = GetForegroundWindow();
    if (!foreground) {
        return false;
    }

    // Ignore when Explorer itself is foreground (desktop/taskbar).
    DWORD processId = 0;
    GetWindowThreadProcessId(foreground, &processId);
    if (!processId || processId == GetCurrentProcessId()) {
        return false;
    }

    std::wstring imagePath;
    if (!GetProcessImagePath(processId, imagePath)) {
        return false;
    }

    for (const std::wstring& folder : g_settings.excludedFolders) {
        if (PathIsUnderFolder(imagePath, folder)) {
            Wh_Log(L"Foreground app excluded: %s", imagePath.c_str());
            return true;
        }
    }

    return false;
}

bool ShouldPeek(const TaskbarEntry& entry) {
    if (IsForegroundAppExcluded()) {
        return false;
    }

    return IsCursorInTaskbarEdgeZone(entry.monitor, entry.hwnd) ||
           IsCursorOverTaskbar(entry.hwnd);
}

void* PeekKeyForEntry(const TaskbarEntry& entry) {
    if (!entry.trayObject) {
        return nullptr;
    }

    if (entry.primary && TrayUI_vftable_IInspectable) {
        return QueryViaVtableBackwards(entry.trayObject,
                                       TrayUI_vftable_IInspectable);
    }

    return entry.trayObject;
}

void BeginPeek(const TaskbarEntry& entry) {
    if (!entry.hwnd) {
        return;
    }

    void* key = PeekKeyForEntry(entry);
    if (key) {
        std::lock_guard<std::mutex> lock(g_stateMutex);
        g_peekingTaskbars[key] = entry.hwnd;
    }

    KillTimer(entry.hwnd, kTrayUITimerHide);

    bool unhideCalled = false;

    if (entry.primary && entry.trayObject && TrayUI_Unhide_Original &&
        TrayUI_vftable_ITrayComponentHost) {
        void* host =
            QueryViaVtable(entry.trayObject, TrayUI_vftable_ITrayComponentHost);
        TrayUI_Unhide_Original(host, 0, 0);
        unhideCalled = true;
    } else if (!entry.primary && entry.trayObject &&
               CSecondaryTray__Unhide_Original) {
        CSecondaryTray__Unhide_Original(entry.trayObject, 0, 0);
        unhideCalled = true;
    }

    if (!unhideCalled) {
        SetTimer(entry.hwnd, kTrayUITimerUnhide, 0, nullptr);
        ShowWindow(entry.hwnd, SW_SHOWNA);
    }

    if (g_settings.forceOnTopWhilePeeking) {
        SetWindowPos(entry.hwnd, HWND_TOPMOST, 0, 0, 0, 0,
                     SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE | SWP_SHOWWINDOW);
    }
}

void EndPeek(const TaskbarEntry& entry) {
    void* key = PeekKeyForEntry(entry);
    if (key) {
        std::lock_guard<std::mutex> lock(g_stateMutex);
        g_peekingTaskbars.erase(key);
    }

    if (!entry.hwnd) {
        return;
    }

    if (g_settings.forceOnTopWhilePeeking) {
        SetWindowPos(entry.hwnd, HWND_NOTOPMOST, 0, 0, 0, 0,
                     SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE);
    }

    // Restore Explorer's normal auto-hide path regardless of the TOPMOST setting.
    SetTimer(entry.hwnd, kTrayUITimerHide, 0, nullptr);
}

void WINAPI TrayUI__Hide_Hook(void* pThis) {
    void* key = nullptr;
    if (TrayUI_vftable_IInspectable) {
        key = QueryViaVtableBackwards(pThis, TrayUI_vftable_IInspectable);
    }

    {
        std::lock_guard<std::mutex> lock(g_stateMutex);
        auto it = g_peekingTaskbars.find(key);
        if (it != g_peekingTaskbars.end()) {
            KillTimer(it->second, kTrayUITimerHide);
            Wh_Log(L"Blocked TrayUI::_Hide while peeking");
            return;
        }
    }

    TrayUI__Hide_Original(pThis);
}

void WINAPI CSecondaryTray__AutoHide_Hook(void* pThis, bool hide) {
    if (hide) {
        std::lock_guard<std::mutex> lock(g_stateMutex);
        auto it = g_peekingTaskbars.find(pThis);
        if (it != g_peekingTaskbars.end()) {
            KillTimer(it->second, kTrayUITimerHide);
            Wh_Log(L"Blocked CSecondaryTray::_AutoHide while peeking");
            return;
        }
    }

    CSecondaryTray__AutoHide_Original(pThis, hide);
}

void DiscoverExistingTaskbarsLocked() {
    HWND primary = FindCurrentProcessTaskbarWnd();
    if (!primary) {
        return;
    }

    if (!g_taskbars.contains(primary)) {
        g_taskbars[primary] = TaskbarEntry{
            primary, nullptr, true,
            MonitorFromWindow(primary, MONITOR_DEFAULTTONEAREST)};
        Wh_Log(L"Discovered primary taskbar %08X", (DWORD)(ULONG_PTR)primary);
    }

    DWORD taskbarThreadId = GetWindowThreadProcessId(primary, nullptr);
    if (!taskbarThreadId) {
        return;
    }

    EnumThreadWindows(
        taskbarThreadId,
        [](HWND hWnd, LPARAM) -> BOOL {
            WCHAR className[32];
            if (GetClassName(hWnd, className, ARRAYSIZE(className)) &&
                _wcsicmp(className, L"Shell_SecondaryTrayWnd") == 0 &&
                !g_taskbars.contains(hWnd)) {
                g_taskbars[hWnd] = TaskbarEntry{
                    hWnd, nullptr, false,
                    MonitorFromWindow(hWnd, MONITOR_DEFAULTTONEAREST)};
                Wh_Log(L"Discovered secondary taskbar %08X",
                       (DWORD)(ULONG_PTR)hWnd);
            }
            return TRUE;
        },
        0);
}

void DiscoverExistingTaskbars() {
    std::lock_guard<std::mutex> lock(g_stateMutex);
    DiscoverExistingTaskbarsLocked();
}

void RegisterOrUpdateTaskbar(HWND hWnd, void* pThis, bool primary) {
    if (!hWnd || !pThis) {
        return;
    }

    HMONITOR monitor = MonitorFromWindow(hWnd, MONITOR_DEFAULTTONEAREST);

    if (primary && TrayUI_GetStuckMonitor_Original) {
        monitor = TrayUI_GetStuckMonitor_Original(pThis);
    } else if (!primary && CSecondaryTray_GetMonitor_Original &&
               CSecondaryTray_vftable_ISecondaryTray) {
        void* secondary =
            QueryViaVtable(pThis, CSecondaryTray_vftable_ISecondaryTray);
        monitor = CSecondaryTray_GetMonitor_Original(secondary);
    }

    std::lock_guard<std::mutex> lock(g_stateMutex);
    g_taskbars[hWnd] = TaskbarEntry{hWnd, pThis, primary, monitor};
}

void UnregisterTaskbar(HWND hWnd) {
    std::lock_guard<std::mutex> lock(g_stateMutex);
    auto it = g_taskbars.find(hWnd);
    if (it != g_taskbars.end()) {
        void* key = PeekKeyForEntry(it->second);
        if (key) {
            g_peekingTaskbars.erase(key);
        }
        g_taskbars.erase(it);
    }
}

void RunPeekPass() {
    std::vector<TaskbarEntry> taskbars;
    {
        std::lock_guard<std::mutex> lock(g_stateMutex);
        if (g_taskbars.empty()) {
            DiscoverExistingTaskbarsLocked();
        }

        for (const auto& [hwnd, entry] : g_taskbars) {
            TaskbarEntry copy = entry;
            copy.monitor =
                MonitorFromWindow(hwnd, MONITOR_DEFAULTTONEAREST);
            taskbars.push_back(copy);
        }
    }

    const bool autoHideEnabled = IsSystemAutoHideEnabled();
    const bool excluded = autoHideEnabled && IsForegroundAppExcluded();

    for (const TaskbarEntry& entry : taskbars) {
        void* key = PeekKeyForEntry(entry);
        bool wasPeeking = false;

        if (key) {
            std::lock_guard<std::mutex> lock(g_stateMutex);
            wasPeeking = g_peekingTaskbars.contains(key);
        }

        const bool shouldPeek =
            autoHideEnabled && !excluded &&
            (IsCursorInTaskbarEdgeZone(entry.monitor, entry.hwnd) ||
             IsCursorOverTaskbar(entry.hwnd));

        if (shouldPeek) {
            // Do not repeatedly call Explorer's internal Unhide method every
            // polling interval. One call per hidden -> peek transition is enough.
            if (!wasPeeking) {
                BeginPeek(entry);
            }
        } else if (wasPeeking) {
            EndPeek(entry);
        }
    }
}

DWORD WINAPI PeekWorkerThreadProc(LPVOID) {
    while (!g_stopPeekWorker.load()) {
        RunPeekPass();

        int interval = g_settings.peekCheckIntervalMs;
        if (interval < 10) {
            interval = 10;
        }
        Sleep(interval);
    }
    return 0;
}

void StartPeekWorker() {
    if (g_peekWorkerThread) {
        return;
    }

    g_stopPeekWorker = false;
    HANDLE thread = CreateThread(nullptr, 0, PeekWorkerThreadProc, nullptr, 0,
                                 nullptr);
    if (thread) {
        g_peekWorkerThread = thread;
    }
}

void StopPeekWorker() {
    HANDLE thread = g_peekWorkerThread.exchange(nullptr);
    if (!thread) {
        return;
    }

    g_stopPeekWorker = true;
    WaitForSingleObject(thread, INFINITE);
    CloseHandle(thread);
}

LRESULT WINAPI TrayUI_WndProc_Hook(void* pThis,
                                   HWND hWnd,
                                   UINT Msg,
                                   WPARAM wParam,
                                   LPARAM lParam,
                                   bool* flag) {
    if (pThis && IsTaskbarWindow(hWnd)) {
        RegisterOrUpdateTaskbar(hWnd, pThis, true);
    }

    if (Msg == WM_NCCREATE) {
        RegisterOrUpdateTaskbar(hWnd, pThis, true);
    } else if (Msg == WM_NCDESTROY) {
        UnregisterTaskbar(hWnd);
    }

    return TrayUI_WndProc_Original(pThis, hWnd, Msg, wParam, lParam, flag);
}

LRESULT WINAPI CSecondaryTray_v_WndProc_Hook(void* pThis,
                                             HWND hWnd,
                                             UINT Msg,
                                             WPARAM wParam,
                                             LPARAM lParam) {
    if (pThis && IsTaskbarWindow(hWnd)) {
        RegisterOrUpdateTaskbar(hWnd, pThis, false);
    }

    if (Msg == WM_NCCREATE) {
        RegisterOrUpdateTaskbar(hWnd, pThis, false);
    } else if (Msg == WM_NCDESTROY) {
        UnregisterTaskbar(hWnd);
    }

    return CSecondaryTray_v_WndProc_Original(pThis, hWnd, Msg, wParam, lParam);
}

void CALLBACK WinEventProc(HWINEVENTHOOK,
                           DWORD event,
                           HWND hWnd,
                           LONG idObject,
                           LONG,
                           DWORD,
                           DWORD) {
    if (idObject != OBJID_WINDOW || IsTaskbarWindow(hWnd)) {
        return;
    }

    if (event == EVENT_SYSTEM_FOREGROUND ||
        event == EVENT_OBJECT_LOCATIONCHANGE || event == EVENT_OBJECT_SHOW ||
        event == EVENT_OBJECT_HIDE) {
        RunPeekPass();
    }
}

DWORD WINAPI WinEventHookThread(LPVOID) {
    HWINEVENTHOOK foregroundHook = SetWinEventHook(
        EVENT_SYSTEM_FOREGROUND, EVENT_SYSTEM_FOREGROUND, nullptr, WinEventProc,
        0, 0, WINEVENT_OUTOFCONTEXT);

    HWINEVENTHOOK locationHook = SetWinEventHook(
        EVENT_OBJECT_LOCATIONCHANGE, EVENT_OBJECT_LOCATIONCHANGE, nullptr,
        WinEventProc, 0, 0, WINEVENT_OUTOFCONTEXT);

    HWINEVENTHOOK showHideHook =
        SetWinEventHook(EVENT_OBJECT_SHOW, EVENT_OBJECT_HIDE, nullptr,
                        WinEventProc, 0, 0, WINEVENT_OUTOFCONTEXT);

    MSG msg;
    while (GetMessage(&msg, nullptr, 0, 0) > 0) {
        if (msg.hwnd == nullptr && msg.message == WM_APP) {
            PostQuitMessage(0);
            continue;
        }
        TranslateMessage(&msg);
        DispatchMessage(&msg);
    }

    if (foregroundHook) {
        UnhookWinEvent(foregroundHook);
    }
    if (locationHook) {
        UnhookWinEvent(locationHook);
    }
    if (showHideHook) {
        UnhookWinEvent(showHideHook);
    }

    return 0;
}

std::mutex g_winEventHookThreadMutex;

void StartWinEventHookThread() {
    std::lock_guard<std::mutex> guard(g_winEventHookThreadMutex);
    if (!g_winEventHookThread) {
        g_winEventHookThread = CreateThread(nullptr, 0, WinEventHookThread,
                                            nullptr, 0, nullptr);
    }
}

void StopWinEventHookThread() {
    std::lock_guard<std::mutex> guard(g_winEventHookThreadMutex);
    if (g_winEventHookThread) {
        PostThreadMessage(GetThreadId(g_winEventHookThread), WM_APP, 0, 0);
        WaitForSingleObject(g_winEventHookThread, INFINITE);
        CloseHandle(g_winEventHookThread);
        g_winEventHookThread = nullptr;
    }
}

bool HookTaskbarSymbols(HMODULE module) {
    WindhawkUtils::SYMBOL_HOOK symbolHooks[] = {
        {
            {
                LR"(const TrayUI::`vftable'{for `IInspectable'})",
                LR"(const TrayUI::`vftable'{for `ITrayDeskBand'})",
            },
            &TrayUI_vftable_IInspectable,
        },
        {
            {LR"(const TrayUI::`vftable'{for `ITrayComponentHost'})"},
            &TrayUI_vftable_ITrayComponentHost,
        },
        {
            {LR"(const CSecondaryTray::`vftable'{for `ISecondaryTray'})"},
            &CSecondaryTray_vftable_ISecondaryTray,
        },
        {
            {LR"(public: virtual struct HMONITOR__ * __cdecl TrayUI::GetStuckMonitor(void))"},
            &TrayUI_GetStuckMonitor_Original,
        },
        {
            {LR"(public: virtual struct HMONITOR__ * __cdecl CSecondaryTray::GetMonitor(void))"},
            &CSecondaryTray_GetMonitor_Original,
        },
        {
            {LR"(public: void __cdecl TrayUI::_Hide(void))"},
            &TrayUI__Hide_Original,
            TrayUI__Hide_Hook,
        },
        {
            {LR"(private: void __cdecl CSecondaryTray::_AutoHide(bool))"},
            &CSecondaryTray__AutoHide_Original,
            CSecondaryTray__AutoHide_Hook,
        },
        {
            {LR"(public: virtual void __cdecl TrayUI::Unhide(enum TrayCommon::TrayUnhideFlags,enum TrayCommon::UnhideRequest))"},
            &TrayUI_Unhide_Original,
        },
        {
            {LR"(private: void __cdecl CSecondaryTray::_Unhide(enum TrayCommon::TrayUnhideFlags,enum TrayCommon::UnhideRequest))"},
            &CSecondaryTray__Unhide_Original,
        },
        {
            {LR"(public: virtual __int64 __cdecl TrayUI::WndProc(struct HWND__ *,unsigned int,unsigned __int64,__int64,bool *))"},
            &TrayUI_WndProc_Original,
            TrayUI_WndProc_Hook,
        },
        {
            {LR"(private: virtual __int64 __cdecl CSecondaryTray::v_WndProc(struct HWND__ *,unsigned int,unsigned __int64,__int64))"},
            &CSecondaryTray_v_WndProc_Original,
            CSecondaryTray_v_WndProc_Hook,
        },
    };

    if (!WindhawkUtils::HookSymbols(module, symbolHooks,
                                    ARRAYSIZE(symbolHooks))) {
        Wh_Log(L"HookSymbols failed");
        return false;
    }

    return true;
}

VS_FIXEDFILEINFO* GetModuleVersionInfo(HMODULE hModule, UINT* puPtrLen) {
    void* pFixedFileInfo = nullptr;
    UINT uPtrLen = 0;

    HRSRC hResource =
        FindResource(hModule, MAKEINTRESOURCE(VS_VERSION_INFO), RT_VERSION);
    if (hResource) {
        HGLOBAL hGlobal = LoadResource(hModule, hResource);
        if (hGlobal) {
            void* pData = LockResource(hGlobal);
            if (pData &&
                (!VerQueryValue(pData, L"\\", &pFixedFileInfo, &uPtrLen) ||
                 uPtrLen == 0)) {
                pFixedFileInfo = nullptr;
                uPtrLen = 0;
            }
        }
    }

    if (puPtrLen) {
        *puPtrLen = uPtrLen;
    }

    return (VS_FIXEDFILEINFO*)pFixedFileInfo;
}

WinVersion GetExplorerVersion() {
    VS_FIXEDFILEINFO* fixedFileInfo = GetModuleVersionInfo(nullptr, nullptr);
    if (!fixedFileInfo) {
        return WinVersion::Unsupported;
    }

    WORD major = HIWORD(fixedFileInfo->dwFileVersionMS);
    WORD build = HIWORD(fixedFileInfo->dwFileVersionLS);

    Wh_Log(L"Version: %u build %u", major, build);

    if (major == 10) {
        if (build < 22000) {
            return WinVersion::Win10;
        }
        if (build < 26100) {
            return WinVersion::Win11;
        }
        return WinVersion::Win11_24H2;
    }

    return WinVersion::Unsupported;
}

struct EXPLORER_PATCHER_HOOK {
    PCSTR symbol;
    void** pOriginalFunction;
    void* hookFunction = nullptr;
    bool optional = false;

    template <typename Prototype>
    EXPLORER_PATCHER_HOOK(
        PCSTR symbol,
        Prototype** originalFunction,
        std::type_identity_t<Prototype*> hookFunction = nullptr,
        bool optional = false)
        : symbol(symbol),
          pOriginalFunction(reinterpret_cast<void**>(originalFunction)),
          hookFunction(reinterpret_cast<void*>(hookFunction)),
          optional(optional) {}
};

bool HookExplorerPatcherSymbols(HMODULE explorerPatcherModule) {
    if (g_explorerPatcherInitialized.exchange(true)) {
        return true;
    }

    if (g_winVersion >= WinVersion::Win11) {
        g_winVersion = WinVersion::Win10;
    }

    EXPLORER_PATCHER_HOOK hooks[] = {
        {R"(??_7TrayUI@@6BITrayDeskBand@@@)", &TrayUI_vftable_IInspectable},
        {R"(??_7TrayUI@@6BITrayComponentHost@@@)",
         &TrayUI_vftable_ITrayComponentHost},
        {R"(??_7CSecondaryTray@@6BISecondaryTray@@@)",
         &CSecondaryTray_vftable_ISecondaryTray},
        {R"(?GetStuckMonitor@TrayUI@@UEAAPEAUHMONITOR__@@XZ)",
         &TrayUI_GetStuckMonitor_Original},
        {R"(?GetMonitor@CSecondaryTray@@UEAAPEAUHMONITOR__@@XZ)",
         &CSecondaryTray_GetMonitor_Original},
        {R"(?_Hide@TrayUI@@QEAAXXZ)", &TrayUI__Hide_Original, TrayUI__Hide_Hook},
        {R"(?_AutoHide@CSecondaryTray@@AEAAX_N@Z)",
         &CSecondaryTray__AutoHide_Original, CSecondaryTray__AutoHide_Hook},
        {R"(?Unhide@TrayUI@@UEAAXW4TrayUnhideFlags@TrayCommon@@W4UnhideRequest@3@@Z)",
         &TrayUI_Unhide_Original},
        {R"(?_Unhide@CSecondaryTray@@AEAAXW4TrayUnhideFlags@TrayCommon@@W4UnhideRequest@3@@Z)",
         &CSecondaryTray__Unhide_Original},
        {R"(?WndProc@TrayUI@@UEAA_JPEAUHWND__@@I_K_JPEA_N@Z)",
         &TrayUI_WndProc_Original, TrayUI_WndProc_Hook},
        {R"(?v_WndProc@CSecondaryTray@@EEAA_JPEAUHWND__@@I_K_J@Z)",
         &CSecondaryTray_v_WndProc_Original, CSecondaryTray_v_WndProc_Hook,
         true},
    };

    bool succeeded = true;

    for (const auto& hook : hooks) {
        void* ptr = (void*)GetProcAddress(explorerPatcherModule, hook.symbol);
        if (!ptr) {
            Wh_Log(L"ExplorerPatcher symbol%s missing: %S",
                   hook.optional ? L" (optional)" : L"", hook.symbol);
            if (!hook.optional) {
                succeeded = false;
            }
            continue;
        }

        if (hook.hookFunction) {
            Wh_SetFunctionHook(ptr, hook.hookFunction, hook.pOriginalFunction);
        } else {
            *hook.pOriginalFunction = ptr;
        }
    }

    if (succeeded && g_initialized) {
        Wh_ApplyHookOperations();
    }

    return succeeded;
}

bool IsExplorerPatcherModule(HMODULE module) {
    WCHAR moduleFilePath[MAX_PATH];
    if (!GetModuleFileName(module, moduleFilePath, ARRAYSIZE(moduleFilePath))) {
        return false;
    }

    PCWSTR moduleFileName = wcsrchr(moduleFilePath, L'\\');
    if (!moduleFileName) {
        return false;
    }

    moduleFileName++;
    return _wcsnicmp(L"ep_taskbar.", moduleFileName,
                     sizeof("ep_taskbar.") - 1) == 0;
}

bool HandleLoadedExplorerPatcher() {
    HMODULE hMods[1024];
    DWORD cbNeeded;
    if (!EnumProcessModules(GetCurrentProcess(), hMods, sizeof(hMods),
                            &cbNeeded)) {
        return true;
    }

    for (size_t i = 0; i < cbNeeded / sizeof(HMODULE); i++) {
        if (IsExplorerPatcherModule(hMods[i])) {
            return HookExplorerPatcherSymbols(hMods[i]);
        }
    }

    return true;
}

using LoadLibraryExW_t = decltype(&LoadLibraryExW);
LoadLibraryExW_t LoadLibraryExW_Original;
HMODULE WINAPI LoadLibraryExW_Hook(LPCWSTR lpLibFileName,
                                   HANDLE hFile,
                                   DWORD dwFlags) {
    HMODULE module = LoadLibraryExW_Original(lpLibFileName, hFile, dwFlags);
    if (module && !g_explorerPatcherInitialized &&
        IsExplorerPatcherModule(module)) {
        HookExplorerPatcherSymbols(module);
    }
    return module;
}

void LoadSettings() {
    g_settings.forceOnTopWhilePeeking =
        Wh_GetIntSetting(L"forceOnTopWhilePeeking");
    g_settings.edgeTriggerPixels = Wh_GetIntSetting(L"edgeTriggerPixels");
    g_settings.peekCheckIntervalMs = Wh_GetIntSetting(L"peekCheckIntervalMs");
    g_settings.oldTaskbarOnWin11 = Wh_GetIntSetting(L"oldTaskbarOnWin11");

    g_settings.excludedFolders.clear();
    for (int i = 0;; i++) {
        PCWSTR folder = Wh_GetStringSetting(L"excludedFolders[%d]", i);
        bool hasFolder = folder && *folder;
        if (hasFolder) {
            std::wstring normalized = folder;
            NormalizePathInPlace(normalized);
            if (!normalized.empty()) {
                g_settings.excludedFolders.push_back(std::move(normalized));
            }
        }
        Wh_FreeStringSetting(folder);
        if (!hasFolder) {
            break;
        }
    }

    // Always keep Riot Games excluded even if settings list is empty/corrupt.
    const std::wstring riot = L"c:\\riot games";
    bool hasRiot = false;
    for (const std::wstring& folder : g_settings.excludedFolders) {
        if (folder == riot) {
            hasRiot = true;
            break;
        }
    }
    if (!hasRiot) {
        g_settings.excludedFolders.push_back(riot);
    }

    if (g_settings.edgeTriggerPixels < 1) {
        g_settings.edgeTriggerPixels = 1;
    }
    if (g_settings.peekCheckIntervalMs < 0) {
        g_settings.peekCheckIntervalMs = 0;
    }
}

BOOL Wh_ModInit() {
    Wh_Log(L"Init");

    LoadSettings();

    g_winVersion = GetExplorerVersion();
    if (g_winVersion == WinVersion::Unsupported) {
        Wh_Log(L"Unsupported Windows version");
        return FALSE;
    }

    if (g_settings.oldTaskbarOnWin11) {
        if (g_winVersion >= WinVersion::Win11) {
            g_winVersion = WinVersion::Win10;
        }
        if (!HookTaskbarSymbols(GetModuleHandle(nullptr))) {
            // ExplorerPatcher path may still hook later.
            Wh_Log(L"Native symbols not hooked (ExplorerPatcher mode?)");
        }
    } else if (g_winVersion >= WinVersion::Win11) {
        HMODULE taskbarModule = LoadLibraryEx(L"taskbar.dll", nullptr,
                                              LOAD_LIBRARY_SEARCH_SYSTEM32);
        if (!taskbarModule) {
            Wh_Log(L"Couldn't load taskbar.dll");
            return FALSE;
        }
        if (!HookTaskbarSymbols(taskbarModule)) {
            return FALSE;
        }
    } else {
        if (!HookTaskbarSymbols(GetModuleHandle(nullptr))) {
            return FALSE;
        }
    }

    if (!HandleLoadedExplorerPatcher()) {
        Wh_Log(L"ExplorerPatcher hook failed");
        return FALSE;
    }

    HMODULE kernelBaseModule = GetModuleHandle(L"kernelbase.dll");
    auto pKernelBaseLoadLibraryExW =
        (decltype(&LoadLibraryExW))GetProcAddress(kernelBaseModule,
                                                  "LoadLibraryExW");
    WindhawkUtils::SetFunctionHook(pKernelBaseLoadLibraryExW,
                                   LoadLibraryExW_Hook,
                                   &LoadLibraryExW_Original);

    g_initialized = true;
    StartWinEventHookThread();

    return TRUE;
}

void Wh_ModAfterInit() {
    Wh_Log(L"AfterInit");

    if (!g_explorerPatcherInitialized) {
        HandleLoadedExplorerPatcher();
    }

    DiscoverExistingTaskbars();
    StartPeekWorker();
    RunPeekPass();
}

void Wh_ModUninit() {
    Wh_Log(L"Uninit");

    StopPeekWorker();
    StopWinEventHookThread();

    std::lock_guard<std::mutex> lock(g_stateMutex);
    g_taskbars.clear();
    g_peekingTaskbars.clear();
}

void Wh_ModSettingsChanged() {
    Wh_Log(L"SettingsChanged");

    StopPeekWorker();
    LoadSettings();
    StartPeekWorker();
    RunPeekPass();
}
