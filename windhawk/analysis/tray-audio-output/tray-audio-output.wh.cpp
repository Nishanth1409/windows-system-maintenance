// ==WindhawkMod==
// @id              tray-audio-output
// @name            Tray Audio Output
// @description     System tray audio: pick output, volume, scroll to switch, share to multiple speakers (WASAPI mirror). Auto device list with smart Bluetooth limits.
// @version         1.5.8
// @author          SystemMaintenance
// @include         windhawk.exe
// @compilerOptions -lshell32 -lgdi32 -luser32 -lole32 -luuid -loleaut32 -ladvapi32 -lcomctl32 -luxtheme -ldwmapi -lavrt
// @license         MIT
// ==/WindhawkMod==

// ==WindhawkModReadme==
/*
# Tray Audio Output

Manage Windows audio output from the notification area — no trip to **Settings → Sound**.

## Features

- **Auto device list** — every connected playback device appears automatically; unplugging removes it, plugging in adds it.
- **Left click** — menu of all connected speakers: pick default output, share to multiple devices.
- **Right click** — mute / unmute the current output device.
- **Scroll wheel** over the tray icon — cycle to the next or previous output device.
- **Multiple output** — share to multiple devices (WASAPI mirror). Wired/USB: unlimited. Bluetooth: smart limits.
- **Sync delay** — change in Settings (default 152 ms), or hover *Sync delay* in the menu and scroll the mouse wheel.

## Usage

1. Compile (`Ctrl+B`) and enable the mod.
2. Find the speaker icon in the system tray (hidden icons chevron on Windows 11).
3. Scroll over the icon to swap outputs, or left-click for the speaker menu, right-click to mute.

No manual device configuration is required.
*/
// ==/WindhawkModReadme==

// ==WindhawkModSettings==
/*
- scrollStepPercent: 3
  $name: Scroll volume step (%)
  $description: When only one output device is connected, scrolling adjusts volume by this percentage instead of cycling.
- showDeviceRoles: true
  $name: Show default role labels
  $description: Append "(Default)" or "(Communications)" to device names in the menu when applicable.
- bluetoothDefaultDelayMs: 152
  $name: Sync delay (ms)
  $description: "Mirror synchronization delay (0-2000). Also adjustable by hovering Sync delay in the tray menu and scrolling the mouse wheel. Default: 152."
*/
// ==/WindhawkModSettings==

#define NOMINMAX

#include <windows.h>
#include <shellapi.h>
#include <shobjidl.h>
#include <endpointvolume.h>
#include <dwmapi.h>
#include <propkey.h>
#include <propsys.h>
#include <mmdeviceapi.h>
#include <audioclient.h>
#include <avrt.h>
#include <functiondiscoverykeys_devpkey.h>
#include <uxtheme.h>

#include <windhawk_utils.h>

#include <algorithm>
#include <vector>
#include <string>
#include <cstring>

static const GUID TRAY_AUDIO_GUID = {
    0xA4B71C92, 0x6E3D, 0x4F18,
    {0x9B, 0x2A, 0x1C, 0x8D, 0x5E, 0x7F, 0x3A, 0x91}};

static const GUID kVolumeChangeCtx = {
    0x9F2A1D8E, 0xC7B4, 0x4E63,
    {0x8A, 0x1F, 0x2D, 0x5B, 0x6E, 0x7C, 0x8D, 0x9F}};

#define TRAY_ICON_ID         1
#define WM_TRAY_CALLBACK     (WM_USER + 1)
#define WM_UPDATE_TRAY       (WM_USER + 2)
#define WM_DEVICES_CHANGED   (WM_USER + 3)
#define WM_MIRROR_CHANGED    (WM_USER + 4)
#define WM_MIRROR_VOLUME_DELTA (WM_USER + 5)
#define TRAY_RECT_TIMER      99
#define TRAY_UPDATE_DEBOUNCE_TIMER 100
#define TRAY_ICON_HEALTH_TIMER 101
// Coalesce volume-driven tip refreshes so Shell_NotifyIcon is not hammered.
#define TRAY_UPDATE_DEBOUNCE_MS 80
// Sparse health check: recover a vanished GUID icon without busy-polling.
#define TRAY_ICON_HEALTH_MS  12000
#define TRAY_ICON_READD_MIN_MS 2500
#define TRAY_RECT_RETRY_MS   400
#define TRAY_RECT_FAILS_BEFORE_READD 4

#define MENU_DEVICE_BASE     1000
#define MENU_MIRROR_BASE     2000
#define MENU_MIRROR_STOP     1998
#define MENU_VOLUME_BASE     3000
#define MENU_MUTE            9001
#define MENU_OPEN_WINDHAWK   9000

#define MAX_MIRROR_DEVICES   16

#ifndef NIN_SELECT
#define NIN_SELECT     (WM_USER + 0)
#endif
#ifndef NIN_KEYSELECT
#define NIN_KEYSELECT  (NIN_SELECT | 0x1)
#endif

const CLSID CLSID_CPolicyConfigClient = {
    0x870af99c, 0x171d, 0x4f9e,
    {0xaf, 0x0d, 0xe6, 0x3d, 0xf4, 0x0c, 0x2b, 0xc9}};
const IID IID_IPolicyConfig_Win10_11 = {
    0xf8679f50, 0x850a, 0x41cf,
    {0x9c, 0x72, 0x43, 0x0f, 0x29, 0x02, 0x90, 0xc8}};

MIDL_INTERFACE("f8679f50-850a-41cf-9c72-430f290290c8")
IPolicyConfig : public IUnknown {
public:
    virtual HRESULT STDMETHODCALLTYPE GetMixFormat(PCWSTR, void**) = 0;
    virtual HRESULT STDMETHODCALLTYPE GetDeviceFormat(PCWSTR, INT, void**) = 0;
    virtual HRESULT STDMETHODCALLTYPE ResetDeviceFormat(PCWSTR) = 0;
    virtual HRESULT STDMETHODCALLTYPE SetDeviceFormat(PCWSTR, void*, void*) = 0;
    virtual HRESULT STDMETHODCALLTYPE GetProcessingPeriod(PCWSTR, INT, PINT, PINT) = 0;
    virtual HRESULT STDMETHODCALLTYPE SetProcessingPeriod(PCWSTR, PINT) = 0;
    virtual HRESULT STDMETHODCALLTYPE GetShareMode(PCWSTR, void*) = 0;
    virtual HRESULT STDMETHODCALLTYPE SetShareMode(PCWSTR, void*) = 0;
    virtual HRESULT STDMETHODCALLTYPE GetPropertyValue(PCWSTR, const PROPERTYKEY&, PROPVARIANT*) = 0;
    virtual HRESULT STDMETHODCALLTYPE SetPropertyValue(PCWSTR, const PROPERTYKEY&, PROPVARIANT*) = 0;
    virtual HRESULT STDMETHODCALLTYPE SetDefaultEndpoint(PCWSTR wszDeviceId, ERole eRole) = 0;
    virtual HRESULT STDMETHODCALLTYPE SetEndpointVisibility(PCWSTR, INT) = 0;
};

struct AudioDevice {
    std::wstring id;
    std::wstring name;
    bool isDefaultMultimedia = false;
    bool isDefaultCommunications = false;
    bool isBluetooth = false;
};

struct ModSettings {
    int scrollStepPercent = 3;
    bool showDeviceRoles = true;
    int mirrorDuckPercent = 1;
    int bluetoothDefaultDelayMs = 152;
} g_settings;

static CRITICAL_SECTION g_lock;
static std::vector<AudioDevice> g_devices;
static HANDLE         g_trayThread   = nullptr;
static volatile HWND  g_trayHwnd     = nullptr;
static HINSTANCE      g_hInstance    = nullptr;
static WCHAR          g_windhawkPath[MAX_PATH] = {};
static WCHAR          g_ddoresPath[MAX_PATH] = {};
static HICON          g_hTrayIcon    = nullptr;
static HBITMAP        g_hWindHawkBmp = nullptr;
static RECT           g_trayIconRect = {};
static UINT           g_taskbarCreatedMsg = 0;
static DWORD          g_lastClickMs  = 0;
static DWORD          g_lastScrollMs = 0;
static DWORD          g_lastTrayReaddMs = 0;
static int            g_trayRectFailCount = 0;
static bool           g_trayIconPresent = false;
static WCHAR          g_lastTrayTip[128] = {};
static bool           g_lastTrayMuted = false;
static int            g_lastTrayVol = -1;
static bool           g_lastTrayMirroring = false;
static size_t         g_lastTrayMirrorCount = 0;
static volatile LONG  g_menuOpen = FALSE;
static volatile LONG  g_hoveredMenuCommand = 0;
static HMENU          g_activePopupMenu = nullptr;


static IMMDeviceEnumerator* g_enum = nullptr;
static class DeviceNotifier* g_notifier = nullptr;
static IAudioEndpointVolume* g_endpointVol = nullptr;
static std::vector<std::wstring> SnapshotMirrorIds();
// Last known Windows-default endpoint volume (%). Used to apply the same
// keyboard/OS volume step to every shared output without forcing equal levels.
static volatile LONG g_lastDefaultVolPct = -1;

class VolNotifier : public IAudioEndpointVolumeCallback {
    volatile LONG m_ref = 1;
public:
    HRESULT STDMETHODCALLTYPE QueryInterface(REFIID riid, void** ppv) override {
        if (riid == __uuidof(IUnknown) || riid == __uuidof(IAudioEndpointVolumeCallback)) {
            *ppv = static_cast<IAudioEndpointVolumeCallback*>(this);
            AddRef();
            return S_OK;
        }
        *ppv = nullptr;
        return E_NOINTERFACE;
    }
    ULONG STDMETHODCALLTYPE AddRef() override {
        return (ULONG)InterlockedIncrement(&m_ref);
    }
    ULONG STDMETHODCALLTYPE Release() override {
        LONG r = InterlockedDecrement(&m_ref);
        if (r == 0) delete this;
        return (ULONG)r;
    }
    HRESULT STDMETHODCALLTYPE OnNotify(
        PAUDIO_VOLUME_NOTIFICATION_DATA data) override {
        HWND hwnd = (HWND)InterlockedCompareExchangePointer(
            (volatile PVOID*)&g_trayHwnd, nullptr, nullptr);

        if (data) {
            const LONG newPct = std::max<LONG>(
                0, std::min<LONG>(
                    100, static_cast<LONG>(
                        data->fMasterVolume * 100.0f + 0.5f)));
            const LONG oldPct = InterlockedExchange(&g_lastDefaultVolPct, newPct);
            const bool ourEdit =
                IsEqualGUID(data->guidEventContext, kVolumeChangeCtx) != FALSE;

            // OS / keyboard / tray volume step: nudge every shared output by
            // the same delta (34→44 and 15→25). Tray-menu per-device edits use
            // kVolumeChangeCtx and must not fan out.
            if (!ourEdit && oldPct >= 0 && newPct != oldPct &&
                !SnapshotMirrorIds().empty() && hwnd) {
                PostMessageW(hwnd, WM_MIRROR_VOLUME_DELTA, 0,
                             (LPARAM)(newPct - oldPct));
            }
        }

        if (hwnd)
            PostMessageW(hwnd, WM_UPDATE_TRAY, 0, 0);
        return S_OK;
    }
};

static VolNotifier* g_volNotifier = nullptr;

static CRITICAL_SECTION g_mirrorLock;
static std::vector<std::wstring> g_mirrorIds;
static volatile LONG  g_mirrorRunning = 0;

static std::vector<AudioDevice> SnapshotDevices();
static void BindEndpointVolume();

// ─── Settings ────────────────────────────────────────────────────────────────

static void LoadSettings() {
    g_settings.scrollStepPercent = Wh_GetIntSetting(L"scrollStepPercent");
    if (g_settings.scrollStepPercent < 1) g_settings.scrollStepPercent = 1;
    if (g_settings.scrollStepPercent > 20) g_settings.scrollStepPercent = 20;
    g_settings.showDeviceRoles = Wh_GetIntSetting(L"showDeviceRoles") != 0;
    g_settings.mirrorDuckPercent = Wh_GetIntSetting(L"mirrorDuckPercent");
    if (g_settings.mirrorDuckPercent < 0) g_settings.mirrorDuckPercent = 0;
    if (g_settings.mirrorDuckPercent > 10) g_settings.mirrorDuckPercent = 10;

    // Settings UI default is 152. Mouse-wheel tweaks persist via syncDelayMs.
    const int fromUi = std::max(
        0, std::min(2000, Wh_GetIntSetting(L"bluetoothDefaultDelayMs")));
    g_settings.bluetoothDefaultDelayMs = std::max(
        0, std::min(2000, (int)Wh_GetIntValue(L"syncDelayMs", fromUi)));
}

static bool IsBluetoothDeviceId(PCWSTR id) {
    if (!id || !id[0]) return false;
    std::wstring s(id);
    for (auto& c : s) c = towlower(c);
    return s.find(L"bth") != std::wstring::npos ||
           s.find(L"bluetooth") != std::wstring::npos;
}

static bool IsBluetoothDevice(IMMDevice* dev) {
    LPWSTR id = nullptr;
    if (FAILED(dev->GetId(&id))) return false;
    const bool bt = IsBluetoothDeviceId(id);
    CoTaskMemFree(id);
    if (bt) return true;

    IPropertyStore* store = nullptr;
    if (FAILED(dev->OpenPropertyStore(STGM_READ, &store))) return false;
    PROPVARIANT v;
    PropVariantInit(&v);
    bool result = false;
    if (SUCCEEDED(store->GetValue(PKEY_Device_EnumeratorName, &v)) && v.pwszVal) {
        std::wstring en(v.pwszVal);
        for (auto& c : en) c = towlower(c);
        result = en.find(L"bth") != std::wstring::npos;
    }
    PropVariantClear(&v);
    store->Release();
    return result;
}

static void SaveMirrorSelection() {
    EnterCriticalSection(&g_mirrorLock);
    std::wstring blob;
    for (size_t i = 0; i < g_mirrorIds.size(); i++) {
        if (i) blob += L'|';
        blob += g_mirrorIds[i];
    }
    LeaveCriticalSection(&g_mirrorLock);
    Wh_SetStringValue(L"mirrorDeviceIds", blob.c_str());
}

static void LoadMirrorSelection() {
    WCHAR buf[8192] = {};
    Wh_GetStringValue(L"mirrorDeviceIds", buf, ARRAYSIZE(buf));
    std::vector<std::wstring> ids;
    for (WCHAR* ctx = nullptr, *tok = wcstok_s(buf, L"|", &ctx); tok;
         tok = wcstok_s(nullptr, L"|", &ctx)) {
        if (tok[0]) ids.push_back(tok);
    }
    EnterCriticalSection(&g_mirrorLock);
    g_mirrorIds = std::move(ids);
    LeaveCriticalSection(&g_mirrorLock);
}

static std::vector<std::wstring> SnapshotMirrorIds() {
    EnterCriticalSection(&g_mirrorLock);
    auto copy = g_mirrorIds;
    LeaveCriticalSection(&g_mirrorLock);
    return copy;
}

static bool IsMirrored(const std::wstring& id) {
    EnterCriticalSection(&g_mirrorLock);
    bool found = false;
    for (const auto& m : g_mirrorIds)
        if (m == id) { found = true; break; }
    LeaveCriticalSection(&g_mirrorLock);
    return found;
}

static int CountBluetoothInMirror(const std::vector<AudioDevice>& devices,
                                  const std::vector<std::wstring>& mirrorIds,
                                  const std::wstring* excludeId = nullptr) {
    int count = 0;
    for (const auto& mid : mirrorIds) {
        if (excludeId && *excludeId == mid) continue;
        for (const auto& d : devices)
            if (d.id == mid && d.isBluetooth) { count++; break; }
    }
    return count;
}

static bool ToggleMirrorDevice(const AudioDevice& dev, HWND hwnd) {
    auto devices = SnapshotDevices();
    EnterCriticalSection(&g_mirrorLock);
    auto& list = g_mirrorIds;
    auto it = std::find(list.begin(), list.end(), dev.id);
    if (it != list.end()) {
        list.erase(it);
        LeaveCriticalSection(&g_mirrorLock);
        SaveMirrorSelection();
        return true;
    }

    if (dev.isBluetooth && CountBluetoothInMirror(devices, list) >= 1) {
        LeaveCriticalSection(&g_mirrorLock);
        MessageBoxW(hwnd,
            L"Only one Bluetooth output can share audio at a time on a single adapter.\n\n"
            L"Uncheck the other Bluetooth device first, or use wired/USB speakers for additional outputs.",
            L"Tray Audio Output", MB_OK | MB_ICONINFORMATION);
        return false;
    }

    if ((int)list.size() >= MAX_MIRROR_DEVICES) {
        LeaveCriticalSection(&g_mirrorLock);
        MessageBoxW(hwnd, L"Maximum number of mirror outputs reached.", L"Tray Audio Output",
                    MB_OK | MB_ICONINFORMATION);
        return false;
    }

    list.push_back(dev.id);
    LeaveCriticalSection(&g_mirrorLock);
    SaveMirrorSelection();
    return true;
}

// ─── Device enumeration ──────────────────────────────────────────────────────

static std::wstring GetDeviceFriendlyName(IMMDevice* dev) {
    std::wstring name = L"Unknown device";
    IPropertyStore* store = nullptr;
    if (SUCCEEDED(dev->OpenPropertyStore(STGM_READ, &store))) {
        PROPVARIANT v;
        PropVariantInit(&v);
        if (SUCCEEDED(store->GetValue(PKEY_Device_FriendlyName, &v)) && v.pwszVal)
            name = v.pwszVal;
        PropVariantClear(&v);
        store->Release();
    }
    return name;
}

static std::wstring GetDefaultDeviceId(ERole role) {
    if (!g_enum) return {};
    IMMDevice* dev = nullptr;
    if (FAILED(g_enum->GetDefaultAudioEndpoint(eRender, role, &dev)))
        return {};
    LPWSTR id = nullptr;
    std::wstring result;
    if (SUCCEEDED(dev->GetId(&id))) {
        result = id;
        CoTaskMemFree(id);
    }
    dev->Release();
    return result;
}

static void RefreshDeviceList() {
    std::vector<AudioDevice> list;
    if (!g_enum) return;

    const std::wstring defMulti = GetDefaultDeviceId(eMultimedia);
    const std::wstring defComm  = GetDefaultDeviceId(eCommunications);

    IMMDeviceCollection* coll = nullptr;
    if (SUCCEEDED(g_enum->EnumAudioEndpoints(eRender, DEVICE_STATE_ACTIVE, &coll))) {
        UINT count = 0;
        coll->GetCount(&count);
        list.reserve(count);
        for (UINT i = 0; i < count; i++) {
            IMMDevice* dev = nullptr;
            if (SUCCEEDED(coll->Item(i, &dev))) {
                LPWSTR id = nullptr;
                if (SUCCEEDED(dev->GetId(&id))) {
                    AudioDevice entry;
                    entry.id = id;
                    entry.name = GetDeviceFriendlyName(dev);
                    entry.isBluetooth = IsBluetoothDevice(dev);
                    entry.isDefaultMultimedia =
                        !defMulti.empty() && entry.id == defMulti;
                    entry.isDefaultCommunications =
                        !defComm.empty() && entry.id == defComm;
                    list.push_back(std::move(entry));
                    CoTaskMemFree(id);
                }
                dev->Release();
            }
        }
        coll->Release();
    }

    EnterCriticalSection(&g_lock);
    g_devices = std::move(list);
    LeaveCriticalSection(&g_lock);
}

static std::vector<AudioDevice> SnapshotDevices() {
    EnterCriticalSection(&g_lock);
    auto copy = g_devices;
    LeaveCriticalSection(&g_lock);
    return copy;
}

static int FindDeviceIndex(const std::vector<AudioDevice>& devices,
                           const std::wstring& id) {
    for (size_t i = 0; i < devices.size(); i++)
        if (devices[i].id == id) return (int)i;
    return -1;
}

static bool SetDefaultOutput(PCWSTR deviceId) {
    if (!deviceId || !deviceId[0]) return false;
    IPolicyConfig* policy = nullptr;
    if (FAILED(CoCreateInstance(CLSID_CPolicyConfigClient, nullptr, CLSCTX_ALL,
                                IID_IPolicyConfig_Win10_11, (void**)&policy)))
        return false;
    policy->SetDefaultEndpoint(deviceId, eConsole);
    policy->SetDefaultEndpoint(deviceId, eMultimedia);
    policy->SetDefaultEndpoint(deviceId, eCommunications);
    policy->Release();
    return true;
}

static bool CycleOutput(int direction) {
    auto devices = SnapshotDevices();
    if (devices.size() < 2) return false;

    const std::wstring currentId = GetDefaultDeviceId(eMultimedia);
    int idx = FindDeviceIndex(devices, currentId);
    if (idx < 0) idx = 0;

    const int n = (int)devices.size();
    for (int step = 1; step <= n; step++) {
        int candidate = (idx + step * direction) % n;
        if (candidate < 0) candidate += n;
        if (SetDefaultOutput(devices[candidate].id.c_str()))
            return true;
    }
    return false;
}


static bool GetDeviceVolumePct(const std::wstring& deviceId, int* pct) {
    if (!g_enum || !pct) return false;
    IMMDevice* dev = nullptr;
    IAudioEndpointVolume* vol = nullptr;
    bool ok = false;
    if (SUCCEEDED(g_enum->GetDevice(deviceId.c_str(), &dev)) && dev &&
        SUCCEEDED(dev->Activate(__uuidof(IAudioEndpointVolume), CLSCTX_ALL,
                                nullptr, (void**)&vol)) && vol) {
        float scalar = 0.0f;
        if (SUCCEEDED(vol->GetMasterVolumeLevelScalar(&scalar))) {
            *pct = (int)(scalar * 100.0f + 0.5f);
            ok = true;
        }
    }
    if (vol) vol->Release();
    if (dev) dev->Release();
    return ok;
}

static bool SetDeviceVolumeScalar(const std::wstring& deviceId, float scalar) {
    if (!g_enum) return false;
    scalar = std::max(0.0f, std::min(1.0f, scalar));
    IMMDevice* dev = nullptr;
    IAudioEndpointVolume* vol = nullptr;
    bool ok = false;
    if (SUCCEEDED(g_enum->GetDevice(deviceId.c_str(), &dev)) && dev &&
        SUCCEEDED(dev->Activate(__uuidof(IAudioEndpointVolume), CLSCTX_ALL,
                                nullptr, (void**)&vol)) && vol) {
        // Tag intentional per-device edits so OS volume steps still fan out,
        // but menu/popup scrolls on one row do not.
        ok = SUCCEEDED(vol->SetMasterVolumeLevelScalar(scalar, &kVolumeChangeCtx));
    }
    if (vol) vol->Release();
    if (dev) dev->Release();
    return ok;
}

static void ApplyVolumeDeltaToMirroredOutputs(int deltaPct) {
    if (deltaPct == 0) return;

    const std::wstring currentDefault = GetDefaultDeviceId(eMultimedia);
    const auto mirrorIds = SnapshotMirrorIds();

    for (const auto& id : mirrorIds) {
        if (id.empty() || id == currentDefault)
            continue;

        int pct = 0;
        if (!GetDeviceVolumePct(id, &pct))
            continue;

        pct = std::max(0, std::min(100, pct + deltaPct));
        SetDeviceVolumeScalar(id, pct / 100.0f);
    }
}

// ─── WASAPI multi-output mirror (Double Headphones style) ────────────────────

namespace AudioMirror {

struct OutputStream {
    std::wstring id;
    IAudioClient* client = nullptr;
    IAudioRenderClient* render = nullptr;
    HANDLE event = nullptr;
    UINT32 bufferFrames = 0;

    // Per-output FIFO. Each WASAPI endpoint has its own clock and available
    // buffer space, so captured packets must never be written blindly or
    // dropped just because one endpoint is temporarily full.
    std::vector<BYTE> pending;
    size_t pendingOffset = 0;
    bool delayPrimed = false;
    ULONGLONG lastDelayRefreshMs = 0;
};

static HANDLE         g_thread      = nullptr;
static volatile LONG  g_stop        = 0;
static HANDLE         g_stopEvent   = nullptr;
static float          g_savedDefaultVol = 1.0f;
static bool           g_savedDefault    = false;
static std::wstring   g_savedDefaultId;
static std::wstring   g_captureDeviceId;
static std::vector<std::wstring> g_runtimeTargetIds;
static int            g_syncDelayMs = 152;
#define MENU_SYNC_DELAY 4000


static void RestoreDefaultEndpoint() {
    std::wstring id;
    EnterCriticalSection(&g_mirrorLock);
    id = g_savedDefaultId;
    LeaveCriticalSection(&g_mirrorLock);
    if (!id.empty()) {
        SetDefaultOutput(id.c_str());
    }
}

static void RestoreDefaultVolume() {
    if (!g_savedDefault || !g_enum) return;
    IMMDevice* dev = nullptr;
    if (SUCCEEDED(g_enum->GetDefaultAudioEndpoint(eRender, eMultimedia, &dev))) {
        IAudioEndpointVolume* vol = nullptr;
        if (SUCCEEDED(dev->Activate(__uuidof(IAudioEndpointVolume), CLSCTX_ALL,
                                    nullptr, (void**)&vol)) && vol) {
            vol->SetMasterVolumeLevelScalar(g_savedDefaultVol, nullptr);
            vol->Release();
        }
        dev->Release();
    }
    g_savedDefault = false;
}

static void DuckDefaultVolume() {
    if (!g_enum) return;
    IMMDevice* dev = nullptr;
    if (FAILED(g_enum->GetDefaultAudioEndpoint(eRender, eMultimedia, &dev))) return;
    IAudioEndpointVolume* vol = nullptr;
    if (SUCCEEDED(dev->Activate(__uuidof(IAudioEndpointVolume), CLSCTX_ALL,
                                nullptr, (void**)&vol)) && vol) {
        if (!g_savedDefault) {
            float scalar = 1.0f;
            if (SUCCEEDED(vol->GetMasterVolumeLevelScalar(&scalar)))
                g_savedDefaultVol = scalar;
            g_savedDefault = true;
        }
        const float duck = g_settings.mirrorDuckPercent / 100.0f;
        vol->SetMasterVolumeLevelScalar(duck, nullptr);
        vol->Release();
    }
    dev->Release();
}

static void FreeOutput(OutputStream& o) {
    if (o.render) { o.render->Release(); o.render = nullptr; }
    if (o.client) {
        o.client->Stop();
        o.client->Release();
        o.client = nullptr;
    }
    if (o.event) { CloseHandle(o.event); o.event = nullptr; }
}

static void CopyFrames(BYTE* dst, const BYTE* src, UINT32 frames,
                       const WAVEFORMATEX* fmt, float gain) {
    const UINT32 bytes = frames * fmt->nBlockAlign;
    if (gain >= 0.999f) {
        memcpy(dst, src, bytes);
        return;
    }
    if (fmt->wFormatTag == WAVE_FORMAT_IEEE_FLOAT ||
        (fmt->wFormatTag == WAVE_FORMAT_EXTENSIBLE &&
         fmt->wBitsPerSample == 32)) {
        const float* s = reinterpret_cast<const float*>(src);
        float* d = reinterpret_cast<float*>(dst);
        const UINT32 samples = frames * fmt->nChannels;
        for (UINT32 i = 0; i < samples; i++)
            d[i] = s[i] * gain;
        return;
    }
    if (fmt->wBitsPerSample == 16) {
        const int16_t* s = reinterpret_cast<const int16_t*>(src);
        int16_t* d = reinterpret_cast<int16_t*>(dst);
        const UINT32 samples = frames * fmt->nChannels;
        for (UINT32 i = 0; i < samples; i++)
            d[i] = (int16_t)(s[i] * gain);
        return;
    }
    memcpy(dst, src, bytes);
}


static size_t PendingBytes(const OutputStream& o) {
    return o.pending.size() - o.pendingOffset;
}

static void CompactPending(OutputStream& o) {
    if (o.pendingOffset == 0) return;
    if (o.pendingOffset >= o.pending.size()) {
        o.pending.clear();
        o.pendingOffset = 0;
        return;
    }
    if (o.pendingOffset >= 65536 || o.pendingOffset * 2 >= o.pending.size()) {
        o.pending.erase(o.pending.begin(), o.pending.begin() + o.pendingOffset);
        o.pendingOffset = 0;
    }
}

static void QueueFrames(OutputStream& o, const BYTE* data, UINT32 frames,
                        const WAVEFORMATEX* fmt, bool silent) {
    if (!frames) return;

    const ULONGLONG nowMs = GetTickCount64();

    if (!o.delayPrimed && g_syncDelayMs > 0) {
        const size_t delayFrames =
            (static_cast<size_t>(fmt->nSamplesPerSec) * g_syncDelayMs) / 1000;
        const size_t delayBytes = delayFrames * fmt->nBlockAlign;
        o.pending.insert(o.pending.end(), delayBytes, 0);
        o.delayPrimed = true;
        o.lastDelayRefreshMs = nowMs;
    }

    // Re-evaluate the sync delay target periodically without restarting WASAPI
    // and without inserting another full delay block. Repeatedly adding silence
    // would make latency grow and would cause gaps/crackling.
    //
    // If a track boundary or endpoint flush has drained the FIFO too far, add
    // only the missing amount needed to restore the target queue depth.
    if (o.delayPrimed && g_syncDelayMs > 0 &&
        nowMs - o.lastDelayRefreshMs >= 2000) {
        const size_t targetFrames =
            (static_cast<size_t>(fmt->nSamplesPerSec) * g_syncDelayMs) / 1000;
        const size_t targetBytes = targetFrames * fmt->nBlockAlign;
        const size_t queuedBytes = PendingBytes(o);

        if (queuedBytes < targetBytes) {
            const size_t missingBytes =
                targetBytes - queuedBytes -
                ((targetBytes - queuedBytes) % fmt->nBlockAlign);
            if (missingBytes > 0)
                o.pending.insert(o.pending.end(), missingBytes, 0);
        }

        o.lastDelayRefreshMs = nowMs;
    }
    const size_t bytes = static_cast<size_t>(frames) * fmt->nBlockAlign;
    CompactPending(o);
    const size_t oldSize = o.pending.size();
    o.pending.resize(oldSize + bytes);
    if (silent || !data)
        memset(o.pending.data() + oldSize, 0, bytes);
    else
        memcpy(o.pending.data() + oldSize, data, bytes);

    // QUALITY FIRST: never discard PCM frames to chase latency. Dropping queued
    // frames creates audible clicks, time compression and loss of music detail.
    // Keep the queue lossless; DrainOutput and the endpoint clock consume it.
    // A hard safety ceiling is retained only for a genuinely stalled device.
    const size_t maxBytes =
        static_cast<size_t>(fmt->nAvgBytesPerSec) * 2; // 2-second fault ceiling
    const size_t queued = PendingBytes(o);
    if (queued > maxBytes) {
        // A device that is this far behind is no longer a synchronization case;
        // reset its pending queue at a frame boundary instead of continuously
        // dropping small chunks and degrading the whole song.
        o.pending.clear();
        o.pendingOffset = 0;
    }
}

static void DrainOutput(OutputStream& o, const WAVEFORMATEX* fmt) {
    if (!o.client || !o.render) return;

    const size_t queuedBytes = PendingBytes(o);
    if (queuedBytes < fmt->nBlockAlign) return;

    UINT32 padding = 0;
    if (FAILED(o.client->GetCurrentPadding(&padding))) return;
    if (padding >= o.bufferFrames) return;

    const UINT32 available = o.bufferFrames - padding;
    const UINT32 queuedFrames =
        static_cast<UINT32>(queuedBytes / fmt->nBlockAlign);
    const UINT32 framesToWrite = std::min(available, queuedFrames);
    if (!framesToWrite) return;

    BYTE* outBuf = nullptr;
    if (FAILED(o.render->GetBuffer(framesToWrite, &outBuf)) || !outBuf) return;

    const size_t bytes =
        static_cast<size_t>(framesToWrite) * fmt->nBlockAlign;
    memcpy(outBuf, o.pending.data() + o.pendingOffset, bytes);
    if (SUCCEEDED(o.render->ReleaseBuffer(framesToWrite, 0))) {
        o.pendingOffset += bytes;
        CompactPending(o);
    }
}

static DWORD WINAPI MirrorThreadProc(LPVOID) {
    HRESULT hrCo = CoInitialize(nullptr);
    if (FAILED(hrCo) && hrCo != RPC_E_CHANGED_MODE) return 1;

    DWORD taskIndex = 0;
    HANDLE hTask = AvSetMmThreadCharacteristicsW(L"Audio", &taskIndex);
    DWORD result = 1;

    auto cleanupAll = [&](IMMDevice* capDev, IAudioClient* capClient,
                          IAudioCaptureClient* capture, HANDLE capEvent,
                          WAVEFORMATEX* mix, std::vector<OutputStream>& outputs) {
        for (auto& o : outputs) {
            if (o.client) o.client->Stop();
            FreeOutput(o);
        }
        outputs.clear();
        if (capClient) capClient->Stop();
        if (capture) capture->Release();
        if (capClient) capClient->Release();
        if (capEvent) CloseHandle(capEvent);
        if (mix) CoTaskMemFree(mix);
        if (capDev) capDev->Release();
        InterlockedExchange(&g_mirrorRunning, FALSE);
    };

    std::vector<std::wstring> targetIds;
    EnterCriticalSection(&g_mirrorLock);
    targetIds = g_runtimeTargetIds.empty() ? g_mirrorIds : g_runtimeTargetIds;
    LeaveCriticalSection(&g_mirrorLock);
    // The Windows default endpoint is the original/source playback device and is
    // intentionally excluded from g_mirrorIds. Therefore one selected secondary
    // endpoint is enough to start sharing.
    if (targetIds.empty()) {
        if (hTask) AvRevertMmThreadCharacteristics(hTask);
        if (SUCCEEDED(hrCo)) CoUninitialize();
        return 1;
    }

    std::wstring captureId;
    EnterCriticalSection(&g_mirrorLock);
    captureId = g_captureDeviceId;
    LeaveCriticalSection(&g_mirrorLock);
    if (captureId.empty()) {
        if (hTask) AvRevertMmThreadCharacteristics(hTask);
        if (SUCCEEDED(hrCo)) CoUninitialize();
        return 1;
    }

    IMMDevice* capDev = nullptr;
    IAudioClient* capClient = nullptr;
    IAudioCaptureClient* capture = nullptr;
    HANDLE capEvent = nullptr;
    WAVEFORMATEX* mix = nullptr;
    std::vector<OutputStream> outputs;

    if (!g_enum ||
        FAILED(g_enum->GetDevice(captureId.c_str(), &capDev)) ||
        !capDev ||
        FAILED(capDev->Activate(__uuidof(IAudioClient), CLSCTX_ALL, nullptr,
                                (void**)&capClient)) ||
        !capClient ||
        FAILED(capClient->GetMixFormat(&mix)) || !mix) {
        cleanupAll(capDev, capClient, capture, capEvent, mix, outputs);
        if (hTask) AvRevertMmThreadCharacteristics(hTask);
        if (SUCCEEDED(hrCo)) CoUninitialize();
        return 1;
    }

    capEvent = CreateEventW(nullptr, FALSE, FALSE, nullptr);
    if (!capEvent) {
        cleanupAll(capDev, capClient, capture, capEvent, mix, outputs);
        if (hTask) AvRevertMmThreadCharacteristics(hTask);
        if (SUCCEEDED(hrCo)) CoUninitialize();
        return 1;
    }

    const REFERENCE_TIME bufDur = 100000;
    if (FAILED(capClient->Initialize(
            AUDCLNT_SHAREMODE_SHARED,
            AUDCLNT_STREAMFLAGS_LOOPBACK | AUDCLNT_STREAMFLAGS_EVENTCALLBACK,
            0, 0, mix, nullptr)) ||
        FAILED(capClient->GetService(__uuidof(IAudioCaptureClient), (void**)&capture)) ||
        !capture ||
        FAILED(capClient->SetEventHandle(capEvent))) {
        cleanupAll(capDev, capClient, capture, capEvent, mix, outputs);
        if (hTask) AvRevertMmThreadCharacteristics(hTask);
        if (SUCCEEDED(hrCo)) CoUninitialize();
        return 1;
    }

    for (const auto& id : targetIds) {
        // The capture endpoint is already playing the original system mix.
        // Rendering the captured mix back to it would duplicate/echo the audio.
        if (id == captureId) continue;

        IMMDevice* outDev = nullptr;
        if (FAILED(g_enum->GetDevice(id.c_str(), &outDev)) || !outDev) continue;

        OutputStream stream;
        stream.id = id;
        stream.event = CreateEventW(nullptr, FALSE, FALSE, nullptr);
        if (!stream.event) {
            outDev->Release();
            continue;
        }

        if (FAILED(outDev->Activate(__uuidof(IAudioClient), CLSCTX_ALL, nullptr,
                                    (void**)&stream.client)) || !stream.client) {
            CloseHandle(stream.event);
            outDev->Release();
            continue;
        }

        // Feed the captured PCM format to each shared-mode render stream and let
        // the Windows Audio Engine perform endpoint-specific sample-rate/channel
        // conversion. This avoids silently rejecting common combinations such as
        // 48 kHz Realtek + 44.1/48 kHz Bluetooth/USB devices.
        //
        // AUTOCONVERTPCM enables PCM format conversion and SRC_DEFAULT_QUALITY
        // requests the higher-quality Windows sample-rate conversion path.
        const DWORD renderFlags =
            AUDCLNT_STREAMFLAGS_EVENTCALLBACK |
            AUDCLNT_STREAMFLAGS_AUTOCONVERTPCM |
            AUDCLNT_STREAMFLAGS_SRC_DEFAULT_QUALITY;

        HRESULT hrFmt = stream.client->Initialize(
            AUDCLNT_SHAREMODE_SHARED, renderFlags,
            0, 0, mix, nullptr);
        if (FAILED(hrFmt) ||
            FAILED(stream.client->GetBufferSize(&stream.bufferFrames)) ||
            FAILED(stream.client->GetService(__uuidof(IAudioRenderClient),
                                            (void**)&stream.render)) ||
            !stream.render ||
            FAILED(stream.client->SetEventHandle(stream.event))) {
            FreeOutput(stream);
            outDev->Release();
            continue;
        }

        outputs.push_back(stream);
        outDev->Release();
    }

    if (outputs.empty()) {
        cleanupAll(capDev, capClient, capture, capEvent, mix, outputs);
        if (hTask) AvRevertMmThreadCharacteristics(hTask);
        if (SUCCEEDED(hrCo)) CoUninitialize();
        return 1;
    }

    // Start capture first. Render endpoints start immediately afterward; the
    // per-output FIFO absorbs short scheduling jitter without the old large
    // latency buildup.
    if (FAILED(capClient->Start())) {
        cleanupAll(capDev, capClient, capture, capEvent, mix, outputs);
        if (hTask) AvRevertMmThreadCharacteristics(hTask);
        if (SUCCEEDED(hrCo)) CoUninitialize();
        return 1;
    }
    for (auto& o : outputs) {
        if (FAILED(o.client->Start())) {
            // Leave failed endpoints out of active draining rather than blocking
            // the real-time loop or disturbing the working default endpoint.
            o.client->Stop();
        }
    }

    InterlockedExchange(&g_mirrorRunning, TRUE);
    result = 0;

    HANDLE waitHandles[17];
    UINT waitCount = 0;
    waitHandles[waitCount++] = g_stopEvent;
    waitHandles[waitCount++] = capEvent;
    for (auto& o : outputs) waitHandles[waitCount++] = o.event;

    while (!InterlockedCompareExchange(&g_stop, 0, 0)) {
        DWORD wr = WaitForMultipleObjects(waitCount, waitHandles, FALSE, 200);
        if (wr == WAIT_OBJECT_0) break;

        UINT32 packet = 0;
        while (SUCCEEDED(capture->GetNextPacketSize(&packet)) && packet > 0) {
            BYTE* data = nullptr;
            UINT32 frames = 0;
            DWORD flags = 0;
            if (FAILED(capture->GetBuffer(&data, &frames, &flags, nullptr, nullptr)))
                break;

            if (frames > 0) {
                const bool silent = (flags & AUDCLNT_BUFFERFLAGS_SILENT) != 0;
                for (auto& o : outputs)
                    QueueFrames(o, data, frames, mix, silent);
            }
            capture->ReleaseBuffer(frames);

            // Drain after every captured packet. GetCurrentPadding ensures that
            // each endpoint receives only as many frames as it can accept.
            for (auto& o : outputs)
                DrainOutput(o, mix);
        }

        // Output events can fire even when no new capture packet arrives.
        // Drain queued audio so slow/different-clock devices keep flowing.
        for (auto& o : outputs)
            DrainOutput(o, mix);
    }

    cleanupAll(capDev, capClient, capture, capEvent, mix, outputs);
    if (hTask) AvRevertMmThreadCharacteristics(hTask);
    if (SUCCEEDED(hrCo)) CoUninitialize();
    return result;
}

static void Stop() {
    InterlockedExchange(&g_stop, 1);
    if (g_stopEvent) SetEvent(g_stopEvent);
    if (g_thread) {
        WaitForSingleObject(g_thread, 5000);
        CloseHandle(g_thread);
        g_thread = nullptr;
    }
    InterlockedExchange(&g_stop, 0);
}

static void PruneMissingDevices() {
    auto devices = SnapshotDevices();
    const std::wstring defaultId = GetDefaultDeviceId(eMultimedia);

    EnterCriticalSection(&g_mirrorLock);
    g_mirrorIds.erase(
        std::remove_if(g_mirrorIds.begin(), g_mirrorIds.end(),
            [&](const std::wstring& id) {
                // The current Windows default endpoint is the source/original
                // playback device. It must never also be a mirror destination.
                if (!defaultId.empty() && id == defaultId)
                    return true;

                return std::none_of(devices.begin(), devices.end(),
                    [&](const AudioDevice& d) { return d.id == id; });
            }),
        g_mirrorIds.end());
    LeaveCriticalSection(&g_mirrorLock);
    SaveMirrorSelection();
}

static void Apply(HWND hwnd) {
    Stop();
    PruneMissingDevices();
    auto ids = SnapshotMirrorIds();
    // The default output is the original playback path. A single selected
    // secondary endpoint is sufficient for two-device sharing.
    if (ids.empty()) {
        if (hwnd) PostMessageW(hwnd, WM_UPDATE_TRAY, 0, 0);
        return;
    }

    // IMPORTANT: never change the Windows default endpoint when sharing starts.
    // The default device remains the original playback path. We loopback-capture
    // that endpoint and render only to the selected additional outputs.
    //
    // Changing the default here caused media apps to rebuild their audio session,
    // device notifications to recursively restart the mirror engine, audible
    // crackling, and temporary UI stalls.
    {
        const std::wstring currentDefault = GetDefaultDeviceId(eMultimedia);
        const auto devices = SnapshotDevices();

        std::wstring bluetoothSource;
        for (const auto& id : ids) {
            auto it = std::find_if(devices.begin(), devices.end(),
                [&](const AudioDevice& d) { return d.id == id; });
            if (it != devices.end() && it->isBluetooth) {
                bluetoothSource = id;
                break;
            }
        }

        std::vector<std::wstring> runtimeTargets = ids;
        std::wstring captureSource = currentDefault;

        // Bluetooth-first synchronization: when Bluetooth is the secondary,
        // make it the capture/source clock and mirror the original fast output.
        // This uses the same direction the user observed to be naturally synced:
        // Bluetooth default -> laptop mirrored.
        if (!bluetoothSource.empty() && bluetoothSource != currentDefault) {
            runtimeTargets.erase(
                std::remove(runtimeTargets.begin(), runtimeTargets.end(),
                            bluetoothSource),
                runtimeTargets.end());
            runtimeTargets.push_back(currentDefault);

            EnterCriticalSection(&g_mirrorLock);
            g_savedDefaultId = currentDefault;
            LeaveCriticalSection(&g_mirrorLock);

            if (SetDefaultOutput(bluetoothSource.c_str()))
                captureSource = bluetoothSource;
        }

        EnterCriticalSection(&g_mirrorLock);
        g_captureDeviceId = captureSource;
        g_runtimeTargetIds = runtimeTargets;
        LeaveCriticalSection(&g_mirrorLock);

        g_syncDelayMs = g_settings.bluetoothDefaultDelayMs;
    }

    if (g_captureDeviceId.empty()) {
        if (hwnd) PostMessageW(hwnd, WM_UPDATE_TRAY, 0, 0);
        return;
    }

    if (!g_stopEvent)
        g_stopEvent = CreateEventW(nullptr, TRUE, FALSE, nullptr);
    ResetEvent(g_stopEvent);
    InterlockedExchange(&g_stop, 0);

    // Leave each mirrored output at its own volume (scroll per device in menu).

    g_thread = CreateThread(nullptr, 0, MirrorThreadProc, nullptr, 0, nullptr);
    if (!g_thread) {
        RestoreDefaultVolume();
        MessageBoxW(hwnd,
            L"Could not start multi-output sharing. Keep one device as the Windows default and select at least one different active output.",
            L"Tray Audio Output", MB_OK | MB_ICONWARNING);
    }
    if (hwnd) PostMessageW(hwnd, WM_UPDATE_TRAY, 0, 0);
}

static void Shutdown() {
    Stop();
    if (g_stopEvent) {
        CloseHandle(g_stopEvent);
        g_stopEvent = nullptr;
    }
}

}  // namespace AudioMirror

// ─── Volume helpers ──────────────────────────────────────────────────────────

static void UnbindEndpointVolume() {
    if (g_endpointVol && g_volNotifier)
        g_endpointVol->UnregisterControlChangeNotify(g_volNotifier);
    if (g_volNotifier) { g_volNotifier->Release(); g_volNotifier = nullptr; }
    if (g_endpointVol) { g_endpointVol->Release(); g_endpointVol = nullptr; }
    InterlockedExchange(&g_lastDefaultVolPct, -1);
}

static void BindEndpointVolume() {
    UnbindEndpointVolume();
    if (!g_enum) return;
    IMMDevice* dev = nullptr;
    if (FAILED(g_enum->GetDefaultAudioEndpoint(eRender, eMultimedia, &dev)) || !dev)
        return;
    IAudioEndpointVolume* vol = nullptr;
    if (SUCCEEDED(dev->Activate(__uuidof(IAudioEndpointVolume), CLSCTX_ALL,
                                nullptr, (void**)&vol)) && vol) {
        g_endpointVol = vol;
        g_volNotifier = new VolNotifier();
        g_endpointVol->RegisterControlChangeNotify(g_volNotifier);

        float scalar = 0.0f;
        if (SUCCEEDED(g_endpointVol->GetMasterVolumeLevelScalar(&scalar))) {
            InterlockedExchange(
                &g_lastDefaultVolPct,
                std::max<LONG>(0, std::min<LONG>(
                    100, static_cast<LONG>(scalar * 100.0f + 0.5f))));
        }
    }
    dev->Release();
}

static int GetCurrentVolumePct() {
    float scalar = 0.0f;
    if (g_endpointVol &&
        SUCCEEDED(g_endpointVol->GetMasterVolumeLevelScalar(&scalar))) {
        int pct = (int)(scalar * 100.0f + 0.5f);
        return std::max(0, std::min(100, pct));
    }
    return 0;
}

static void SetCurrentVolumeScalar(float scalar) {
    scalar = std::max(0.0f, std::min(1.0f, scalar));
    if (g_endpointVol)
        g_endpointVol->SetMasterVolumeLevelScalar(scalar, &kVolumeChangeCtx);
}

static void ToggleMute() {
    if (!g_endpointVol) return;
    BOOL muted = FALSE;
    if (SUCCEEDED(g_endpointVol->GetMute(&muted)))
        g_endpointVol->SetMute(!muted, &kVolumeChangeCtx);
}

static bool IsCurrentMuted() {
    if (!g_endpointVol) return false;
    BOOL muted = FALSE;
    if (SUCCEEDED(g_endpointVol->GetMute(&muted))) return muted != FALSE;
    return false;
}

// ─── IMMNotificationClient ───────────────────────────────────────────────────

class DeviceNotifier : public IMMNotificationClient {
    volatile LONG m_ref = 1;
public:
    HRESULT STDMETHODCALLTYPE QueryInterface(REFIID riid, void** ppv) override {
        if (riid == __uuidof(IUnknown) || riid == __uuidof(IMMNotificationClient)) {
            *ppv = static_cast<IMMNotificationClient*>(this);
            AddRef();
            return S_OK;
        }
        *ppv = nullptr;
        return E_NOINTERFACE;
    }
    ULONG STDMETHODCALLTYPE AddRef() override {
        return (ULONG)InterlockedIncrement(&m_ref);
    }
    ULONG STDMETHODCALLTYPE Release() override {
        LONG r = InterlockedDecrement(&m_ref);
        if (r == 0) delete this;
        return (ULONG)r;
    }

    HRESULT STDMETHODCALLTYPE OnDefaultDeviceChanged(
        EDataFlow flow, ERole role, LPCWSTR) override {
        if (flow == eRender && role == eMultimedia) {
            HWND hwnd = (HWND)InterlockedCompareExchangePointer(
                (volatile PVOID*)&g_trayHwnd, nullptr, nullptr);
            if (hwnd) {
                PostMessageW(hwnd, WM_DEVICES_CHANGED, 0, 0);
                PostMessageW(hwnd, WM_UPDATE_TRAY, 0, 0);
            }
        }
        return S_OK;
    }
    HRESULT STDMETHODCALLTYPE OnDeviceAdded(LPCWSTR) override {
        return OnDeviceListChanged();
    }
    HRESULT STDMETHODCALLTYPE OnDeviceRemoved(LPCWSTR) override {
        return OnDeviceListChanged();
    }
    HRESULT STDMETHODCALLTYPE OnDeviceStateChanged(LPCWSTR, DWORD) override {
        return OnDeviceListChanged();
    }
    HRESULT STDMETHODCALLTYPE OnPropertyValueChanged(LPCWSTR, const PROPERTYKEY) override {
        return S_OK;
    }

private:
    HRESULT OnDeviceListChanged() {
        HWND hwnd = (HWND)InterlockedCompareExchangePointer(
            (volatile PVOID*)&g_trayHwnd, nullptr, nullptr);
        if (hwnd) PostMessageW(hwnd, WM_DEVICES_CHANGED, 0, 0);
        return S_OK;
    }
};

// ─── Icons ───────────────────────────────────────────────────────────────────

static HICON LoadSpeakerIcon() {
    HICON icon = nullptr;
    ExtractIconExW(g_ddoresPath, 90, nullptr, &icon, 1);
    if (!icon) ExtractIconExW(g_ddoresPath, 4, nullptr, &icon, 1);
    return icon;
}

static HICON CreateMutedOverlay(HICON base) {
    if (!base) return nullptr;
    const int SZ = 32;
    HDC screen = GetDC(nullptr);
    if (!screen) return nullptr;

    BITMAPINFO bmi = {};
    bmi.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
    bmi.bmiHeader.biWidth = SZ;
    bmi.bmiHeader.biHeight = -SZ;
    bmi.bmiHeader.biPlanes = 1;
    bmi.bmiHeader.biBitCount = 32;
    bmi.bmiHeader.biCompression = BI_RGB;

    void* bits = nullptr;
    HBITMAP color = CreateDIBSection(screen, &bmi, DIB_RGB_COLORS, &bits, nullptr, 0);
    HDC colorDC = CreateCompatibleDC(screen);
    HBITMAP oldColor = (HBITMAP)SelectObject(colorDC, color);
    memset(bits, 0, SZ * SZ * 4);

    HDC maskDC = CreateCompatibleDC(screen);
    HBITMAP mask = CreateBitmap(SZ, SZ, 1, 1, nullptr);
    HBITMAP oldMask = (HBITMAP)SelectObject(maskDC, mask);
    PatBlt(maskDC, 0, 0, SZ, SZ, WHITENESS);
    DrawIconEx(colorDC, 0, 0, base, SZ, SZ, 0, nullptr, DI_NORMAL);
    DrawIconEx(maskDC, 0, 0, base, SZ, SZ, 0, nullptr, DI_MASK);

    const int D = 18, X = SZ - D - 2, Y = SZ - D - 2;
    SelectObject(colorDC, GetStockObject(NULL_PEN));
    SelectObject(maskDC, GetStockObject(NULL_PEN));
    HBRUSH red = CreateSolidBrush(RGB(220, 30, 30));
    SelectObject(colorDC, red);
    Ellipse(colorDC, X, Y, X + D, Y + D);
    DeleteObject(red);

    DWORD* px = (DWORD*)bits;
    for (int y = Y; y < Y + D + 1; y++)
        for (int x = X; x < X + D + 1; x++)
            if (px[y * SZ + x] & 0x00FFFFFF)
                px[y * SZ + x] |= 0xFF000000;

    SelectObject(colorDC, oldColor);
    SelectObject(maskDC, oldMask);
    ICONINFO ii = {};
    ii.fIcon = TRUE;
    ii.hbmMask = mask;
    ii.hbmColor = color;
    HICON result = CreateIconIndirect(&ii);
    DeleteObject(color);
    DeleteObject(mask);
    DeleteDC(colorDC);
    DeleteDC(maskDC);
    ReleaseDC(nullptr, screen);
    return result;
}

static void RefreshTrayIconRect();
static void UpdateTrayIcon(HWND hwnd, bool add);
static bool ForceReaddTrayIcon(HWND hwnd);
static void ScheduleTrayIconHealth(HWND hwnd);

static void DeleteTrayIconSlot(HWND hwnd) {
    NOTIFYICONDATAW nid = {sizeof(nid)};
    nid.hWnd = hwnd;
    nid.uID = TRAY_ICON_ID;
    nid.uFlags = NIF_GUID;
    nid.guidItem = TRAY_AUDIO_GUID;
    Shell_NotifyIconW(NIM_DELETE, &nid);
    // Also clear any plain-uID leftover from older builds.
    NOTIFYICONDATAW plain = {sizeof(plain)};
    plain.hWnd = hwnd;
    plain.uID = TRAY_ICON_ID;
    Shell_NotifyIconW(NIM_DELETE, &plain);
    g_trayIconPresent = false;
    g_trayIconRect = {};
}

static void SetTrayIconVersion(HWND hwnd) {
    NOTIFYICONDATAW ver = {sizeof(ver)};
    ver.hWnd = hwnd;
    ver.uID = TRAY_ICON_ID;
    ver.uFlags = NIF_GUID;
    ver.guidItem = TRAY_AUDIO_GUID;
    ver.uVersion = NOTIFYICON_VERSION_4;
    Shell_NotifyIconW(NIM_SETVERSION, &ver);
}

static void ScheduleTrayIconHealth(HWND hwnd) {
    if (!hwnd) return;
    SetTimer(hwnd, TRAY_ICON_HEALTH_TIMER, TRAY_ICON_HEALTH_MS, nullptr);
}

static bool ForceReaddTrayIcon(HWND hwnd) {
    if (!hwnd) return false;
    const DWORD now = GetTickCount();
    if (g_lastTrayReaddMs != 0 &&
        now - g_lastTrayReaddMs < TRAY_ICON_READD_MIN_MS)
        return false;
    g_lastTrayReaddMs = now;
    g_trayRectFailCount = 0;
    // Invalidate tip cache so UpdateTrayIcon always pushes a fresh icon.
    g_lastTrayTip[0] = 0;
    g_lastTrayVol = -1;
    DeleteTrayIconSlot(hwnd);
    UpdateTrayIcon(hwnd, TRUE);
    return true;
}

static void RefreshTrayIconRect() {
    HWND hwnd = g_trayHwnd;
    if (!hwnd) return;
    NOTIFYICONIDENTIFIER nii = {sizeof(nii)};
    nii.guidItem = TRAY_AUDIO_GUID;
    RECT rc = {};
    if (SUCCEEDED(Shell_NotifyIconGetRect(&nii, &rc)) && rc.right > rc.left) {
        g_trayIconRect = rc;
        g_trayRectFailCount = 0;
        g_trayIconPresent = true;
        KillTimer(hwnd, TRAY_RECT_TIMER);
        ScheduleTrayIconHealth(hwnd);
        return;
    }

    g_trayIconPresent = false;
    ++g_trayRectFailCount;

    // Explorer sometimes needs a short moment after ADD. Retry a few times,
    // then force DELETE+ADD instead of polling every 200ms forever.
    if (g_trayRectFailCount >= TRAY_RECT_FAILS_BEFORE_READD) {
        KillTimer(hwnd, TRAY_RECT_TIMER);
        if (!ForceReaddTrayIcon(hwnd)) {
            // Rate-limited: try again soon without busy-looping.
            SetTimer(hwnd, TRAY_RECT_TIMER, TRAY_ICON_READD_MIN_MS, nullptr);
        }
        ScheduleTrayIconHealth(hwnd);
        return;
    }

    SetTimer(hwnd, TRAY_RECT_TIMER, TRAY_RECT_RETRY_MS, nullptr);
}

static void UpdateTrayIcon(HWND hwnd, bool add) {
    auto devices = SnapshotDevices();
    const std::wstring currentId = GetDefaultDeviceId(eMultimedia);

    std::wstring currentName = L"No output device";
    for (const auto& d : devices) {
        if (d.id == currentId) {
            currentName = d.name;
            break;
        }
    }

    const int vol = GetCurrentVolumePct();
    const bool muted = IsCurrentMuted();
    auto mirrorIds = SnapshotMirrorIds();
    const bool mirroring = mirrorIds.size() >= 1 &&
        InterlockedCompareExchange(&g_mirrorRunning, 0, 0) != 0;

    WCHAR tip[128];
    if (mirroring) {
        if (muted)
            swprintf_s(tip, L"Audio mirror: %zu devices (%d%%, Muted)",
                       mirrorIds.size(), vol);
        else
            swprintf_s(tip, L"Audio mirror: %zu devices (%d%%)",
                       mirrorIds.size(), vol);
    } else if (muted)
        swprintf_s(tip, L"Audio: %s (%d%%, Muted)", currentName.c_str(), vol);
    else
        swprintf_s(tip, L"Audio: %s (%d%%)", currentName.c_str(), vol);

    // Skip no-op MODIFY calls (volume notifier fires often). Keeps tray/shell
    // traffic and GDI overlay work near zero when nothing visible changed.
    if (!add && g_trayIconPresent &&
        muted == g_lastTrayMuted &&
        vol == g_lastTrayVol &&
        mirroring == g_lastTrayMirroring &&
        mirrorIds.size() == g_lastTrayMirrorCount &&
        wcscmp(tip, g_lastTrayTip) == 0) {
        return;
    }

    NOTIFYICONDATAW nid = {sizeof(nid)};
    nid.hWnd = hwnd;
    nid.uID = TRAY_ICON_ID;
    nid.uFlags = NIF_MESSAGE | NIF_TIP | NIF_SHOWTIP | NIF_ICON | NIF_GUID;
    nid.guidItem = TRAY_AUDIO_GUID;
    nid.uCallbackMessage = WM_TRAY_CALLBACK;
    wcscpy_s(nid.szTip, tip);

    HICON overlay = muted ? CreateMutedOverlay(g_hTrayIcon) : nullptr;
    nid.hIcon = overlay ? overlay : g_hTrayIcon;
    if (!nid.hIcon) {
        // The shell can reserve the tray slot even when hIcon is null, which
        // produces exactly the invisible blank space reported by the user.
        nid.hIcon = LoadIconW(nullptr, IDI_APPLICATION);
    }

    BOOL iconOk = FALSE;
    if (add) {
        DeleteTrayIconSlot(hwnd);
        iconOk = Shell_NotifyIconW(NIM_ADD, &nid);
        if (iconOk) SetTrayIconVersion(hwnd);
    } else {
        iconOk = Shell_NotifyIconW(NIM_MODIFY, &nid);
        if (!iconOk) {
            // MODIFY failed: GUID slot is gone — re-add (same as toggling the mod).
            DeleteTrayIconSlot(hwnd);
            iconOk = Shell_NotifyIconW(NIM_ADD, &nid);
            if (iconOk) SetTrayIconVersion(hwnd);
            g_lastTrayReaddMs = GetTickCount();
        }
    }

    if (overlay) DestroyIcon(overlay);

    if (iconOk) {
        wcscpy_s(g_lastTrayTip, tip);
        g_lastTrayMuted = muted;
        g_lastTrayVol = vol;
        g_lastTrayMirroring = mirroring;
        g_lastTrayMirrorCount = mirrorIds.size();
        g_trayIconPresent = true;
    } else {
        g_trayIconPresent = false;
    }

    RefreshTrayIconRect();
    ScheduleTrayIconHealth(hwnd);
}

// ─── Volume popup ────────────────────────────────────────────────────────────

namespace VolumePopup {

static constexpr WCHAR kClass[] = L"TrayAudioVolumePopup";
static constexpr int kW = 260, kH = 76;
static constexpr int kPad = 16, kTitleY = 12, kTitleH = 18;
static constexpr int kTrackY = 54, kTrackH = 6, kThumbR = 9, kThumbRH = 10;
static constexpr UINT kTimerId = 101;
static constexpr COLORREF kBg = RGB(28, 28, 28);
static constexpr COLORREF kBorder = RGB(50, 50, 50);
static constexpr COLORREF kTrackBg = RGB(58, 58, 58);
static constexpr COLORREF kFill = RGB(0, 120, 215);
static constexpr COLORREF kThumb = RGB(255, 255, 255);
static constexpr COLORREF kTextPri = RGB(235, 235, 235);
static constexpr COLORREF kTextSec = RGB(130, 130, 130);

static HWND g_hwnd = nullptr;
static int g_value = 0;
static bool g_drag = false, g_hover = false, g_dirty = false;
static HFONT g_font = nullptr;
static std::wstring g_targetDeviceId;
static std::wstring g_targetDeviceName;

static int ThumbX() { return kPad + (g_value * (kW - 2 * kPad)) / 100; }
static int XToVal(int x) {
    int v = ((x - kPad) * 100 + (kW - 2 * kPad) / 2) / (kW - 2 * kPad);
    return std::max(0, std::min(100, v));
}

static LRESULT CALLBACK WndProc(HWND h, UINT msg, WPARAM wp, LPARAM lp) {
    switch (msg) {
    case WM_CREATE: {
        g_value = (int)(INT_PTR)((CREATESTRUCTW*)lp)->lpCreateParams;
        g_drag = false;
        g_hover = false;
        g_font = CreateFontW(-14, 0, 0, 0, FW_NORMAL, 0, 0, 0, DEFAULT_CHARSET, 0, 0,
                             CLEARTYPE_QUALITY, DEFAULT_PITCH | FF_DONTCARE, L"Segoe UI");
        HMODULE dwm = GetModuleHandleW(L"dwmapi.dll");
        if (dwm) {
            using Fn = HRESULT(WINAPI*)(HWND, DWORD, LPCVOID, DWORD);
            auto fn = (Fn)GetProcAddress(dwm, "DwmSetWindowAttribute");
            if (fn) { UINT pref = 3; fn(h, 33, &pref, sizeof(pref)); }
        }
        SetTimer(h, kTimerId, 16, nullptr);
        return 0;
    }
    case WM_ERASEBKGND:
        return 1;
    case WM_PAINT: {
        PAINTSTRUCT ps;
        HDC hdc = BeginPaint(h, &ps);
        HDC mem = CreateCompatibleDC(hdc);
        HBITMAP bmp = CreateCompatibleBitmap(hdc, kW, kH);
        HBITMAP old = (HBITMAP)SelectObject(mem, bmp);
        RECT all = {0, 0, kW, kH};
        HBRUSH bg = CreateSolidBrush(kBg);
        FillRect(mem, &all, bg);
        DeleteObject(bg);
        FrameRect(mem, &all, (HBRUSH)GetStockObject(GRAY_BRUSH));

        HFONT oldF = (HFONT)SelectObject(mem, g_font ? g_font : GetStockObject(DEFAULT_GUI_FONT));
        SetBkMode(mem, TRANSPARENT);
        SetTextColor(mem, kTextSec);
        RECT left = {kPad, kTitleY, kW - kPad, kTitleY + kTitleH};
        DrawTextW(mem, g_targetDeviceName.empty() ? L"Output volume" : g_targetDeviceName.c_str(), -1, &left, DT_LEFT | DT_VCENTER | DT_SINGLELINE | DT_END_ELLIPSIS);
        WCHAR buf[8];
        swprintf_s(buf, L"%d%%", g_value);
        SetTextColor(mem, kTextPri);
        DrawTextW(mem, buf, -1, &left, DT_RIGHT | DT_VCENTER | DT_SINGLELINE);
        SelectObject(mem, oldF);

        int tL = kPad, tR = kW - kPad, tT = kTrackY - kTrackH / 2, tB = kTrackY + kTrackH / 2;
        int tx = ThumbX();
        SelectObject(mem, GetStockObject(NULL_PEN));
        HBRUSH track = CreateSolidBrush(kTrackBg);
        SelectObject(mem, track);
        RoundRect(mem, tL, tT, tR, tB, kTrackH, kTrackH);
        DeleteObject(track);
        if (tx > tL) {
            HBRUSH fill = CreateSolidBrush(kFill);
            SelectObject(mem, fill);
            RoundRect(mem, tL, tT, tx, tB, kTrackH, kTrackH);
            DeleteObject(fill);
        }
        int r = (g_drag || g_hover) ? kThumbRH : kThumbR;
        HBRUSH th = CreateSolidBrush(kThumb);
        SelectObject(mem, th);
        Ellipse(mem, tx - r, kTrackY - r, tx + r, kTrackY + r);
        DeleteObject(th);

        BitBlt(hdc, 0, 0, kW, kH, mem, 0, 0, SRCCOPY);
        SelectObject(mem, old);
        DeleteObject(bmp);
        DeleteDC(mem);
        EndPaint(h, &ps);
        return 0;
    }
    case WM_LBUTTONDOWN: {
        int mx = (short)LOWORD(lp), my = (short)HIWORD(lp);
        if (my >= kTrackY - kThumbRH * 2 && my <= kTrackY + kThumbRH * 2 &&
            mx >= kPad && mx <= kW - kPad) {
            g_value = XToVal(mx);
            g_drag = true;
            SetCapture(h);
            SetDeviceVolumeScalar(g_targetDeviceId, g_value / 100.0f);
            InvalidateRect(h, nullptr, FALSE);
        }
        return 0;
    }
    case WM_MOUSEMOVE: {
        TRACKMOUSEEVENT tme = {sizeof(tme), TME_LEAVE, h, 0};
        TrackMouseEvent(&tme);
        if (g_drag) {
            int nv = XToVal((short)LOWORD(lp));
            if (nv != g_value) {
                g_value = nv;
                g_dirty = true;
                InvalidateRect(h, nullptr, FALSE);
            }
        } else {
            bool was = g_hover;
            int dx = (short)LOWORD(lp) - ThumbX(), dy = (short)HIWORD(lp) - kTrackY;
            g_hover = (dx * dx + dy * dy) <= (kThumbRH + 4) * (kThumbRH + 4);
            if (g_hover != was) InvalidateRect(h, nullptr, FALSE);
        }
        return 0;
    }
    case WM_LBUTTONUP:
        if (g_drag) {
            g_drag = false;
            ReleaseCapture();
            g_value = XToVal((short)LOWORD(lp));
            g_dirty = false;
            SetDeviceVolumeScalar(g_targetDeviceId, g_value / 100.0f);
            InvalidateRect(h, nullptr, FALSE);
        }
        return 0;
    case WM_MOUSEWHEEL: {
        int step = GET_WHEEL_DELTA_WPARAM(wp) > 0 ? g_settings.scrollStepPercent
                                                  : -g_settings.scrollStepPercent;
        g_value = std::max(0, std::min(100, g_value + step));
        SetDeviceVolumeScalar(g_targetDeviceId, g_value / 100.0f);
        InvalidateRect(h, nullptr, FALSE);
        return 0;
    }
    case WM_ACTIVATE:
        if (LOWORD(wp) == WA_INACTIVE) DestroyWindow(h);
        return 0;
    case WM_TIMER:
        if (wp == kTimerId && g_dirty) {
            g_dirty = false;
            SetDeviceVolumeScalar(g_targetDeviceId, g_value / 100.0f);
        }
        return 0;
    case WM_DESTROY:
        KillTimer(h, kTimerId);
        if (g_dirty) SetDeviceVolumeScalar(g_targetDeviceId, g_value / 100.0f);
        if (g_font) { DeleteObject(g_font); g_font = nullptr; }
        g_hwnd = nullptr;
        return 0;
    }
    return DefWindowProcW(h, msg, wp, lp);
}

static void Register() {
    WNDCLASSEXW wc = {sizeof(wc)};
    wc.lpfnWndProc = WndProc;
    wc.hInstance = g_hInstance;
    wc.lpszClassName = kClass;
    wc.hCursor = LoadCursor(nullptr, IDC_ARROW);
    RegisterClassExW(&wc);
}

static void Unregister() {
    UnregisterClassW(kClass, g_hInstance);
}

static void Show(const std::wstring& deviceId, const std::wstring& deviceName, int volPct) {
    g_targetDeviceId = deviceId;
    g_targetDeviceName = deviceName;
    if (g_hwnd) {
        SetForegroundWindow(g_hwnd);
        return;
    }
    int x = (g_trayIconRect.left + g_trayIconRect.right) / 2 - kW / 2;
    int y = g_trayIconRect.top - kH - 8;
    POINT pt = {(g_trayIconRect.left + g_trayIconRect.right) / 2, g_trayIconRect.top};
    HMONITOR mon = MonitorFromPoint(pt, MONITOR_DEFAULTTONEAREST);
    MONITORINFO mi = {sizeof(mi)};
    if (GetMonitorInfo(mon, &mi)) {
        if (x < mi.rcWork.left) x = mi.rcWork.left;
        if (x + kW > mi.rcWork.right) x = mi.rcWork.right - kW;
        if (y < mi.rcWork.top) y = g_trayIconRect.bottom + 8;
    }
    g_hwnd = CreateWindowExW(WS_EX_TOOLWINDOW | WS_EX_TOPMOST, kClass, nullptr, WS_POPUP,
                             x, y, kW, kH, g_trayHwnd, nullptr, g_hInstance,
                             (LPVOID)(INT_PTR)volPct);
    if (g_hwnd) {
        ShowWindow(g_hwnd, SW_SHOWNOACTIVATE);
        SetForegroundWindow(g_hwnd);
    }
}

}  // namespace VolumePopup

// ─── Context menu ────────────────────────────────────────────────────────────

static bool IsSystemDarkMode() {
    DWORD value = 1, size = sizeof(value);
    RegGetValueW(HKEY_CURRENT_USER,
                 L"Software\\Microsoft\\Windows\\CurrentVersion\\Themes\\Personalize",
                 L"AppsUseLightTheme", RRF_RT_REG_DWORD, nullptr, &value, &size);
    return value == 0;
}

static void ApplyMenuTheme(HWND hwnd, bool dark) {
    HMODULE ux = GetModuleHandleW(L"uxtheme.dll");
    if (!ux) return;
    using Fn135 = int(WINAPI*)(int);
    using Fn133 = bool(WINAPI*)(HWND, bool);
    using Fn136 = void(WINAPI*)();
    if (auto f = (Fn135)GetProcAddress(ux, MAKEINTRESOURCEA(135))) f(dark ? 2 : 0);
    if (auto f = (Fn133)GetProcAddress(ux, MAKEINTRESOURCEA(133))) f(hwnd, dark);
    if (auto f = (Fn136)GetProcAddress(ux, MAKEINTRESOURCEA(136))) f();
}

static std::wstring MenuLabel(const AudioDevice& d) {
    std::wstring label = d.name;
    if (d.isBluetooth) label += L" [BT]";
    if (!g_settings.showDeviceRoles) return label;
    if (d.isDefaultMultimedia && d.isDefaultCommunications)
        label += L" (Default)";
    else if (d.isDefaultMultimedia)
        label += L" (Default)";
    else if (d.isDefaultCommunications)
        label += L" (Communications)";
    return label;
}

static std::wstring VolumeMenuLabel(const AudioDevice& d, bool mirrorRow) {
    int pct = 0;
    GetDeviceVolumePct(d.id, &pct);

    WCHAR prefix[16];
    swprintf_s(prefix, L"%d%%  ", pct);

    std::wstring label = prefix;
    label += d.name;
    if (mirrorRow && d.isBluetooth)
        label += L" [BT]";
    return label;
}

static std::wstring MirrorMenuLabel(const AudioDevice& d) {
    return VolumeMenuLabel(d, true);
}

static void ShowContextMenu(HWND hwnd) {
    auto devices = SnapshotDevices();
    const std::wstring currentId = GetDefaultDeviceId(eMultimedia);
    auto mirrorIds = SnapshotMirrorIds();
    const bool mirroring = mirrorIds.size() >= 1 &&
        InterlockedCompareExchange(&g_mirrorRunning, 0, 0) != 0;

    HMENU menu = CreatePopupMenu();
    if (devices.empty()) {
        AppendMenuW(menu, MF_STRING | MF_GRAYED, 0, L"No playback devices");
    } else {
        AppendMenuW(menu, MF_STRING | MF_GRAYED, 0, L"Default output (single):");
        AppendMenuW(menu, MF_SEPARATOR, 0, nullptr);
        for (size_t i = 0; i < devices.size(); i++) {
            UINT flags = MF_STRING;
            if (devices[i].id == currentId) flags |= MF_CHECKED;
            AppendMenuW(menu, flags, MENU_DEVICE_BASE + (UINT)i,
                        VolumeMenuLabel(devices[i], false).c_str());
        }

        AppendMenuW(menu, MF_SEPARATOR, 0, nullptr);
        AppendMenuW(menu, MF_STRING | MF_GRAYED, 0,
                    L"Share audio to additional outputs:");
        for (size_t i = 0; i < devices.size(); i++) {
            // Dynamic rule: the current Windows default output already plays
            // the original system audio, so it must not appear as a selectable
            // mirror destination.
            if (devices[i].id == currentId)
                continue;

            UINT flags = MF_STRING;
            if (IsMirrored(devices[i].id)) flags |= MF_CHECKED;
            AppendMenuW(menu, flags, MENU_MIRROR_BASE + (UINT)i,
                        MirrorMenuLabel(devices[i]).c_str());
        }
        if (mirrorIds.size() >= 1) {
            AppendMenuW(menu, MF_SEPARATOR, 0, nullptr);
            WCHAR status[128];
            swprintf_s(status, mirroring ? L"Pause sharing (%zu devices)"
                                       : L"Resume sharing (%zu devices)",
                       mirrorIds.size());
            AppendMenuW(menu, MF_STRING, MENU_MIRROR_STOP, status);
        }
    }

    AppendMenuW(menu, MF_SEPARATOR, 0, nullptr);
    {
        WCHAR delayLabel[96];
        swprintf_s(delayLabel, L"Sync delay — %d ms",
                   AudioMirror::g_syncDelayMs);
        AppendMenuW(menu, MF_STRING, MENU_SYNC_DELAY, delayLabel);
    }

    AppendMenuW(menu, MF_SEPARATOR, 0, nullptr);
    AppendMenuW(menu, MF_STRING, MENU_MUTE,
                IsCurrentMuted() ? L"Unmute" : L"Mute");
    AppendMenuW(menu, MF_SEPARATOR, 0, nullptr);

    MENUITEMINFOW wh = {sizeof(wh)};
    wh.fMask = MIIM_ID | MIIM_STRING | MIIM_BITMAP;
    wh.wID = MENU_OPEN_WINDHAWK;
    wh.dwTypeData = (LPWSTR)L"Open Windhawk";
    wh.hbmpItem = g_hWindHawkBmp;
    InsertMenuItemW(menu, (UINT)-1, TRUE, &wh);

    POINT pt;
    GetCursorPos(&pt);
    ApplyMenuTheme(hwnd, IsSystemDarkMode());
    SetForegroundWindow(hwnd);
    InterlockedExchange(&g_hoveredMenuCommand, 0);
    g_activePopupMenu = menu;
    InterlockedExchange(&g_menuOpen, TRUE);
    UINT cmd = TrackPopupMenu(menu,
        TPM_RETURNCMD | TPM_RIGHTBUTTON | TPM_BOTTOMALIGN | TPM_RIGHTALIGN,
        pt.x, pt.y, 0, hwnd, nullptr);
    InterlockedExchange(&g_menuOpen, FALSE);
    g_activePopupMenu = nullptr;
    InterlockedExchange(&g_hoveredMenuCommand, 0);
    PostMessageW(hwnd, WM_NULL, 0, 0);
    DestroyMenu(menu);

    if (cmd >= MENU_DEVICE_BASE && cmd < MENU_DEVICE_BASE + devices.size()) {
        size_t idx = cmd - MENU_DEVICE_BASE;
        AudioMirror::Stop();
        EnterCriticalSection(&g_mirrorLock);
        g_mirrorIds.clear();
        LeaveCriticalSection(&g_mirrorLock);
        SaveMirrorSelection();
        if (SetDefaultOutput(devices[idx].id.c_str())) {
            RefreshDeviceList();
            BindEndpointVolume();
            PostMessageW(hwnd, WM_UPDATE_TRAY, 0, 0);
        }
    } else if (cmd >= MENU_MIRROR_BASE && cmd < MENU_MIRROR_BASE + devices.size()) {
        size_t idx = cmd - MENU_MIRROR_BASE;
        const std::wstring liveDefaultId = GetDefaultDeviceId(eMultimedia);
        if (devices[idx].id == liveDefaultId) {
            // The default changed while the menu was open. Ignore this stale
            // mirror command; the next menu open will dynamically exclude it.
            PostMessageW(hwnd, WM_UPDATE_TRAY, 0, 0);
        } else if (ToggleMirrorDevice(devices[idx], hwnd)) {
            PostMessageW(hwnd, WM_MIRROR_CHANGED, 0, 0);
        }
    } else if (cmd == MENU_MIRROR_STOP) {
        if (InterlockedCompareExchange(&g_mirrorRunning, 0, 0))
            AudioMirror::Stop();
        else
            PostMessageW(hwnd, WM_MIRROR_CHANGED, 0, 0);
        PostMessageW(hwnd, WM_UPDATE_TRAY, 0, 0);
    } else if (cmd == MENU_MUTE) {
        ToggleMute();
        PostMessageW(hwnd, WM_UPDATE_TRAY, 0, 0);
    } else if (cmd == MENU_OPEN_WINDHAWK) {
        SHELLEXECUTEINFOW sei = {sizeof(sei)};
        sei.lpFile = g_windhawkPath;
        sei.nShow = SW_SHOWNORMAL;
        ShellExecuteExW(&sei);
    }
}

// ─── Tray window ─────────────────────────────────────────────────────────────

static LRESULT CALLBACK TrayWndProc(HWND hwnd, UINT msg, WPARAM wp, LPARAM lp) {
    if (msg == WM_MENUSELECT) {
        const UINT item = LOWORD(wp);
        const UINT flags = HIWORD(wp);
        if ((flags & MF_POPUP) == 0 && (flags & MF_SEPARATOR) == 0 &&
            item != 0xFFFF)
            InterlockedExchange(&g_hoveredMenuCommand, (LONG)item);
        else
            InterlockedExchange(&g_hoveredMenuCommand, 0);
        return 0;
    }

    if (msg == WM_TRAY_CALLBACK) {
        const UINT ev = LOWORD(lp);
        if (ev == WM_LBUTTONUP || ev == NIN_SELECT || ev == NIN_KEYSELECT) {
            DWORD now = GetTickCount();
            if (now - g_lastClickMs > 400) {
                g_lastClickMs = now;
                ShowContextMenu(hwnd);
            }
        } else if (ev == WM_MBUTTONUP) {
            {
                const std::wstring id = GetDefaultDeviceId(eMultimedia);
                std::wstring name = L"Output volume";
                for (const auto& d : SnapshotDevices())
                    if (d.id == id) { name = d.name; break; }
                VolumePopup::Show(id, name, GetCurrentVolumePct());
            }
        } else if (ev == WM_RBUTTONUP || ev == WM_CONTEXTMENU) {
            DWORD now = GetTickCount();
            if (now - g_lastClickMs > 400) {
                g_lastClickMs = now;
                ToggleMute();
                PostMessageW(hwnd, WM_UPDATE_TRAY, 0, 0);
            }
        }
        return 0;
    }

    if (msg == WM_INPUT) {
        UINT sz = 0;
        GetRawInputData((HRAWINPUT)lp, RID_INPUT, nullptr, &sz, sizeof(RAWINPUTHEADER));
        if (sz > 0) {
            std::vector<BYTE> buf(sz);
            if (GetRawInputData((HRAWINPUT)lp, RID_INPUT, buf.data(), &sz,
                                sizeof(RAWINPUTHEADER)) == sz) {
                auto* raw = reinterpret_cast<RAWINPUT*>(buf.data());
                if (raw->header.dwType == RIM_TYPEMOUSE &&
                    (raw->data.mouse.usButtonFlags & RI_MOUSE_WHEEL)) {
                    POINT pt;
                    GetCursorPos(&pt);
                    if (InterlockedCompareExchange(&g_menuOpen, 0, 0)) {
                        const auto menuDevices = SnapshotDevices();
                        const short menuDelta =
                            (short)raw->data.mouse.usButtonData;
                        const UINT hovered = (UINT)InterlockedCompareExchange(
                            &g_hoveredMenuCommand, 0, 0);

                        if (hovered == MENU_SYNC_DELAY) {
                            const int change = menuDelta > 0 ? 1 : -1;
                            const int oldDelay = AudioMirror::g_syncDelayMs;
                            const int newDelay = std::max(
                                0, std::min(2000, oldDelay + change));

                            if (newDelay != oldDelay) {
                                AudioMirror::g_syncDelayMs = newDelay;
                                g_settings.bluetoothDefaultDelayMs = newDelay;
                                Wh_SetIntValue(L"syncDelayMs", newDelay);

                                if (g_activePopupMenu) {
                                    WCHAR delayLabel[96];
                                    swprintf_s(
                                        delayLabel,
                                        L"Sync delay — %d ms",
                                        AudioMirror::g_syncDelayMs);
                                    ModifyMenuW(
                                        g_activePopupMenu,
                                        MENU_SYNC_DELAY,
                                        MF_BYCOMMAND | MF_STRING,
                                        MENU_SYNC_DELAY,
                                        delayLabel);
                                    DrawMenuBar(hwnd);
                                }

                                if (InterlockedCompareExchange(
                                        &g_mirrorRunning, 0, 0)) {
                                    AudioMirror::Apply(hwnd);
                                }
                            }
                            return 0;
                        }

                        size_t idx = SIZE_MAX;
                        if (hovered >= MENU_DEVICE_BASE &&
                            hovered < MENU_DEVICE_BASE + menuDevices.size()) {
                            idx = hovered - MENU_DEVICE_BASE;
                        } else if (hovered >= MENU_MIRROR_BASE &&
                                   hovered < MENU_MIRROR_BASE + menuDevices.size()) {
                            idx = hovered - MENU_MIRROR_BASE;
                        }

                        if (idx < menuDevices.size()) {
                            int pct = 0;
                            if (GetDeviceVolumePct(menuDevices[idx].id, &pct)) {
                                const int step = std::max(
                                    1, (int)g_settings.scrollStepPercent);
                                pct = std::max(
                                    0, std::min(
                                        100, pct + (menuDelta > 0 ? step : -step)));
                                SetDeviceVolumeScalar(
                                    menuDevices[idx].id, pct / 100.0f);

                                if (g_activePopupMenu) {
                                    const bool mirrorRow =
                                        hovered >= MENU_MIRROR_BASE &&
                                        hovered < MENU_MIRROR_BASE +
                                                      menuDevices.size();
                                    const std::wstring liveLabel =
                                        VolumeMenuLabel(
                                            menuDevices[idx], mirrorRow);

                                    UINT flags = MF_BYCOMMAND | MF_STRING;
                                    if (mirrorRow &&
                                        IsMirrored(menuDevices[idx].id)) {
                                        flags |= MF_CHECKED;
                                    } else if (!mirrorRow &&
                                               menuDevices[idx].id ==
                                                   GetDefaultDeviceId(
                                                       eMultimedia)) {
                                        flags |= MF_CHECKED;
                                    }

                                    ModifyMenuW(
                                        g_activePopupMenu, hovered, flags,
                                        hovered, liveLabel.c_str());
                                    DrawMenuBar(hwnd);
                                }

                                PostMessageW(hwnd, WM_UPDATE_TRAY, 0, 0);
                            }
                            return 0;
                        }
                    }

                    if (PtInRect(&g_trayIconRect, pt)) {
                        DWORD now = GetTickCount();
                        if (now - g_lastScrollMs < 250) return 0;
                        g_lastScrollMs = now;
                        short delta = (short)raw->data.mouse.usButtonData;
                        int dir = delta > 0 ? -1 : 1;
                        auto devices = SnapshotDevices();
                        const bool mirroring =
                            SnapshotMirrorIds().size() >= 1 &&
                            InterlockedCompareExchange(&g_mirrorRunning, 0, 0);
                        if (!mirroring && devices.size() >= 2) {
                            if (CycleOutput(dir))
                                PostMessageW(hwnd, WM_DEVICES_CHANGED, 0, 0);
                        } else if (g_endpointVol) {
                            float scalar = 0.0f;
                            if (SUCCEEDED(g_endpointVol->GetMasterVolumeLevelScalar(&scalar))) {
                                float step = g_settings.scrollStepPercent / 100.0f;
                                scalar = std::max(0.0f, std::min(1.0f,
                                    scalar + (delta > 0 ? step : -step)));
                                g_endpointVol->SetMasterVolumeLevelScalar(scalar, nullptr);
                            }
                        }
                        PostMessageW(hwnd, WM_UPDATE_TRAY, 0, 0);
                    }
                }
            }
        }
        return DefWindowProcW(hwnd, msg, wp, lp);
    }

    if (msg == g_taskbarCreatedMsg && g_taskbarCreatedMsg != 0) {
        // Explorer rebuilt the tray — force a fresh GUID registration.
        ForceReaddTrayIcon(hwnd);
        return 0;
    }

    switch (msg) {
    case WM_DEVICES_CHANGED:
        RefreshDeviceList();
        BindEndpointVolume();
        if (SnapshotMirrorIds().size() >= 1)
            AudioMirror::Apply(hwnd);
        else
            AudioMirror::Stop();
        UpdateTrayIcon(hwnd, FALSE);
        return 0;
    case WM_MIRROR_CHANGED:
        AudioMirror::Apply(hwnd);
        return 0;
    case WM_MIRROR_VOLUME_DELTA:
        ApplyVolumeDeltaToMirroredOutputs((int)lp);
        return 0;
    case WM_UPDATE_TRAY:
        // Coalesce bursty volume notifications into one shell update.
        SetTimer(hwnd, TRAY_UPDATE_DEBOUNCE_TIMER, TRAY_UPDATE_DEBOUNCE_MS, nullptr);
        return 0;
    case WM_TIMER:
        if (wp == TRAY_UPDATE_DEBOUNCE_TIMER) {
            KillTimer(hwnd, TRAY_UPDATE_DEBOUNCE_TIMER);
            UpdateTrayIcon(hwnd, FALSE);
        } else if (wp == TRAY_RECT_TIMER) {
            RefreshTrayIconRect();
        } else if (wp == TRAY_ICON_HEALTH_TIMER) {
            NOTIFYICONIDENTIFIER nii = {sizeof(nii)};
            nii.guidItem = TRAY_AUDIO_GUID;
            RECT rc = {};
            if (FAILED(Shell_NotifyIconGetRect(&nii, &rc)) ||
                rc.right <= rc.left) {
                ForceReaddTrayIcon(hwnd);
            } else {
                g_trayIconRect = rc;
                g_trayIconPresent = true;
                g_trayRectFailCount = 0;
                // Soft refresh: Explorer can keep the slot but drop the bitmap
                // (blank space). A cheap MODIFY restores it without DELETE/ADD.
                g_lastTrayVol = -1;
                UpdateTrayIcon(hwnd, FALSE);
            }
            ScheduleTrayIconHealth(hwnd);
        }
        return 0;
    case WM_CLOSE: {
        KillTimer(hwnd, TRAY_RECT_TIMER);
        KillTimer(hwnd, TRAY_UPDATE_DEBOUNCE_TIMER);
        KillTimer(hwnd, TRAY_ICON_HEALTH_TIMER);
        AudioMirror::Shutdown();
        DeleteTrayIconSlot(hwnd);
        if (VolumePopup::g_hwnd) DestroyWindow(VolumePopup::g_hwnd);
        DestroyWindow(hwnd);
        return 0;
    }
    case WM_DESTROY:
        InterlockedExchangePointer((PVOID*)&g_trayHwnd, nullptr);
        PostQuitMessage(0);
        return 0;
    }
    return DefWindowProcW(hwnd, msg, wp, lp);
}

static DWORD WINAPI TrayThreadProc(LPVOID) {
    HRESULT hr = CoInitialize(nullptr);
    if (FAILED(hr) && hr != RPC_E_CHANGED_MODE) return 1;

    g_taskbarCreatedMsg = RegisterWindowMessageW(L"TaskbarCreated");
    VolumePopup::Register();

    WNDCLASSW wc = {};
    wc.lpfnWndProc = TrayWndProc;
    wc.hInstance = g_hInstance;
    wc.lpszClassName = L"TrayAudioOutputClass";
    RegisterClassW(&wc);

    HWND hwnd = CreateWindowExW(WS_EX_TOOLWINDOW | WS_EX_NOACTIVATE, wc.lpszClassName,
                                L"Tray Audio Output", WS_POPUP, 0, 0, 1, 1,
                                nullptr, nullptr, g_hInstance, nullptr);
    InterlockedExchangePointer((PVOID*)&g_trayHwnd, hwnd);
    if (!hwnd) {
        if (SUCCEEDED(hr)) CoUninitialize();
        return 1;
    }

    if (SUCCEEDED(CoCreateInstance(__uuidof(MMDeviceEnumerator), nullptr, CLSCTX_ALL,
                                   __uuidof(IMMDeviceEnumerator), (void**)&g_enum))) {
        g_notifier = new DeviceNotifier();
        g_enum->RegisterEndpointNotificationCallback(g_notifier);
    }

    RefreshDeviceList();
    BindEndpointVolume();
    LoadMirrorSelection();
    if (SnapshotMirrorIds().size() >= 1)
        AudioMirror::Apply(hwnd);

    RAWINPUTDEVICE rid = {1, 2, RIDEV_INPUTSINK, hwnd};
    RegisterRawInputDevices(&rid, 1, sizeof(rid));

    UpdateTrayIcon(hwnd, TRUE);

    MSG msg;
    while (GetMessageW(&msg, nullptr, 0, 0) > 0)
        DispatchMessageW(&msg);

    UnbindEndpointVolume();
    AudioMirror::Shutdown();
    if (g_enum && g_notifier) {
        g_enum->UnregisterEndpointNotificationCallback(g_notifier);
        g_notifier->Release();
        g_notifier = nullptr;
        g_enum->Release();
        g_enum = nullptr;
    }
    RAWINPUTDEVICE remove = {1, 2, RIDEV_REMOVE, nullptr};
    RegisterRawInputDevices(&remove, 1, sizeof(remove));
    VolumePopup::Unregister();
    if (SUCCEEDED(hr)) CoUninitialize();
    return 0;
}

// ─── Tool mod lifecycle ──────────────────────────────────────────────────────

BOOL WhTool_ModInit() {
    Wh_Log(L"Tray Audio Output init");
    InitializeCriticalSection(&g_lock);
    InitializeCriticalSection(&g_mirrorLock);
    LoadSettings();
    AudioMirror::g_syncDelayMs = g_settings.bluetoothDefaultDelayMs;
    LoadMirrorSelection();

    g_hInstance = GetModuleHandleW(nullptr);
    if (!GetModuleFileNameW(nullptr, g_windhawkPath, ARRAYSIZE(g_windhawkPath)))
        return FALSE;

    UINT sysLen = GetSystemDirectoryW(g_ddoresPath, MAX_PATH);
    if (sysLen > 0 && sysLen < MAX_PATH - 12)
        lstrcatW(g_ddoresPath, L"\\ddores.dll");
    else
        lstrcpyW(g_ddoresPath, L"ddores.dll");

    g_hTrayIcon = LoadSpeakerIcon();

    HICON whIcon = nullptr;
    ExtractIconExW(g_ddoresPath, 98, nullptr, &whIcon, 1);
    if (!whIcon) ExtractIconExW(g_ddoresPath, 94, nullptr, &whIcon, 1);
    if (whIcon) {
        ICONINFO ii = {};
        if (GetIconInfo(whIcon, &ii)) {
            g_hWindHawkBmp = ii.hbmColor ? ii.hbmColor : ii.hbmMask;
            if (ii.hbmColor && ii.hbmMask) DeleteObject(ii.hbmMask);
        }
        DestroyIcon(whIcon);
    }

    g_trayThread = CreateThread(nullptr, 0, TrayThreadProc, nullptr, 0, nullptr);
    return g_trayThread != nullptr;
}

void WhTool_ModSettingsChanged() {
    // Settings UI is authoritative when the user edits Windhawk Settings.
    const int fromUi = std::max(
        0, std::min(2000, Wh_GetIntSetting(L"bluetoothDefaultDelayMs")));
    Wh_SetIntValue(L"syncDelayMs", fromUi);

    LoadSettings();
    AudioMirror::g_syncDelayMs = g_settings.bluetoothDefaultDelayMs;

    HWND hwnd = (HWND)InterlockedCompareExchangePointer(
        (volatile PVOID*)&g_trayHwnd, nullptr, nullptr);
    if (hwnd && IsWindow(hwnd)) {
        PostMessageW(hwnd, WM_UPDATE_TRAY, 0, 0);
        if (InterlockedCompareExchange(&g_mirrorRunning, 0, 0))
            PostMessageW(hwnd, WM_MIRROR_CHANGED, 0, 0);
    }
}

void WhTool_ModUninit() {
    Wh_Log(L"Tray Audio Output uninit");
    HWND hwnd = (HWND)InterlockedCompareExchangePointer(
        (volatile PVOID*)&g_trayHwnd, nullptr, nullptr);
    if (hwnd && IsWindow(hwnd)) PostMessageW(hwnd, WM_CLOSE, 0, 0);
    if (g_trayThread) {
        WaitForSingleObject(g_trayThread, 3000);
        CloseHandle(g_trayThread);
        g_trayThread = nullptr;
    }
    if (g_hTrayIcon) { DestroyIcon(g_hTrayIcon); g_hTrayIcon = nullptr; }
    if (g_hWindHawkBmp) { DeleteObject(g_hWindHawkBmp); g_hWindHawkBmp = nullptr; }
    DeleteCriticalSection(&g_mirrorLock);
    DeleteCriticalSection(&g_lock);
}

// ─── Windhawk tool-mod launcher ──────────────────────────────────────────────

bool g_isToolModProcessLauncher;
HANDLE g_toolModProcessMutex;

void WINAPI EntryPoint_Hook() {
    Wh_Log(L">");
    ExitThread(0);
}

BOOL Wh_ModInit() {
    DWORD sessionId = 0;
    if (ProcessIdToSessionId(GetCurrentProcessId(), &sessionId) && sessionId == 0)
        return FALSE;

    bool isExcluded = false;
    bool isToolModProcess = false;
    bool isCurrentToolModProcess = false;

    int argc = 0;
    LPWSTR* argv = CommandLineToArgvW(GetCommandLineW(), &argc);
    if (!argv) return FALSE;

    for (int i = 1; i < argc; i++) {
        if (wcscmp(argv[i], L"-service") == 0 ||
            wcscmp(argv[i], L"-service-start") == 0 ||
            wcscmp(argv[i], L"-service-stop") == 0) {
            isExcluded = true;
            break;
        }
    }
    for (int i = 1; i < argc - 1; i++) {
        if (wcscmp(argv[i], L"-tool-mod") == 0) {
            isToolModProcess = true;
            if (wcscmp(argv[i + 1], WH_MOD_ID) == 0)
                isCurrentToolModProcess = true;
            break;
        }
    }
    LocalFree(argv);

    if (isExcluded) return FALSE;

    if (isCurrentToolModProcess) {
        g_toolModProcessMutex =
            CreateMutexW(nullptr, TRUE, L"windhawk-tool-mod_" WH_MOD_ID);
        if (!g_toolModProcessMutex) {
            Wh_Log(L"CreateMutex failed");
            ExitProcess(1);
        }
        if (GetLastError() == ERROR_ALREADY_EXISTS) {
            Wh_Log(L"Tool mod already running");
            ExitProcess(1);
        }
        if (!WhTool_ModInit()) ExitProcess(1);

        IMAGE_DOS_HEADER* dos = (IMAGE_DOS_HEADER*)GetModuleHandleW(nullptr);
        IMAGE_NT_HEADERS* nt = (IMAGE_NT_HEADERS*)((BYTE*)dos + dos->e_lfanew);
        void* entry = (BYTE*)dos + nt->OptionalHeader.AddressOfEntryPoint;
        Wh_SetFunctionHook(entry, (void*)EntryPoint_Hook, nullptr);
        return TRUE;
    }

    if (isToolModProcess) return FALSE;

    g_isToolModProcessLauncher = true;
    return TRUE;
}

void Wh_ModAfterInit() {
    if (!g_isToolModProcessLauncher) return;

    WCHAR path[MAX_PATH];
    if (!GetModuleFileNameW(nullptr, path, ARRAYSIZE(path))) return;

    WCHAR cmdLine[MAX_PATH + 64];
    swprintf_s(cmdLine, L"\"%s\" -tool-mod \"%s\"", path, WH_MOD_ID);

    HMODULE kernel = GetModuleHandleW(L"kernelbase.dll");
    if (!kernel) kernel = GetModuleHandleW(L"kernel32.dll");
    if (!kernel) return;

    using CreateProcessInternalW_t = BOOL(WINAPI*)(
        HANDLE, LPCWSTR, LPWSTR, LPSECURITY_ATTRIBUTES, LPSECURITY_ATTRIBUTES,
        BOOL, DWORD, LPVOID, LPCWSTR, LPSTARTUPINFOW, LPPROCESS_INFORMATION, PHANDLE);
    auto pCreate = (CreateProcessInternalW_t)GetProcAddress(kernel, "CreateProcessInternalW");
    if (!pCreate) return;

    STARTUPINFOW si = {};
    si.cb = sizeof(si);
    si.dwFlags = STARTF_FORCEOFFFEEDBACK;
    PROCESS_INFORMATION pi = {};
    if (pCreate(nullptr, path, cmdLine, nullptr, nullptr, FALSE, NORMAL_PRIORITY_CLASS,
                nullptr, nullptr, &si, &pi, nullptr)) {
        CloseHandle(pi.hProcess);
        CloseHandle(pi.hThread);
    }
}

void Wh_ModSettingsChanged() {
    if (!g_isToolModProcessLauncher) WhTool_ModSettingsChanged();
}

void Wh_ModUninit() {
    if (!g_isToolModProcessLauncher) {
        WhTool_ModUninit();
        ExitProcess(0);
    }
}