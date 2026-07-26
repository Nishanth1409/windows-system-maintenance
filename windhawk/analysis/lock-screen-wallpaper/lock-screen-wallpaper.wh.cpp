// ==WindhawkMod==
// @id              lock-screen-wallpaper
// @name            Lock Screen Wallpaper
// @description     Force a custom lock screen image and keep it after restart, sleep, and sign-out
// @version         2.2
// @author          You
// @include         explorer.exe
// @include         LogonUI.exe
// @architecture    x86-64
// @compilerOptions -lcomdlg32 -ladvapi32 -lwtsapi32 -lgdi32 -lshell32 -DUNICODE -D_UNICODE -D_WIN32_WINNT=0x0A00 -DNTDDI_VERSION=0x0A000008
// @license         MIT
// ==/WindhawkMod==

// ==WindhawkModReadme==
/*
# Lock Screen Wallpaper

Windows 11 often resets the lock screen to the default blue Windows image after a
full shutdown, restart, or sign-out. Windows Spotlight and cached SystemData
files can override your chosen picture even when Settings shows the right image.

This mod **forcefully** keeps your lock screen wallpaper by:

1. Copying your image to **ProgramData** (readable by SYSTEM at cold boot).
2. Disabling Windows Spotlight and lock screen slideshow registry flags.
3. Writing lock screen registry keys (Creative, LogonUI, PersonalizationCSP).
4. Calling the Windows lock screen API and fixing broken organization policy paths.
5. Re-applying on a timer, at startup (with delayed retries), and when you
   unlock or log on.
6. Running inside **LogonUI** at boot so the image is restored before you sign
   in.

## Quick setup

1. Compile the mod (Ctrl+B) and **enable** it in Windhawk.
2. Restart Explorer once after first enable.
3. Set **Lock screen wallpaper** to a **local** JPG or PNG path.
4. **Accept the UAC prompt** if shown (fixes a broken system policy path).
5. Lock the PC (Win+L), then **restart once** to confirm cold-boot persistence.

### Browse for an image

Set **Open image browser** to `1` and save settings. A window opens with
**Browse...**. Set the value back to `0` after it opens.

## Tips

- Use a local path (not a network drive) for best results after cold boot.
- Keep **Disable Windows Spotlight on lock screen** enabled.
- Enable **Copy to SystemData cache** for stronger persistence (may log a
  warning if Windows blocks the copy; registry apply still runs).
- Enable mod logs to see when the image is staged and registry is updated.
- The mod keeps **Win+L** and **sign-in / shutdown** screens on the same image.
- If Windows shows a UAC prompt once, accept it to repair a missing policy image
  path (common cause of the default blue lock screen).
- Disable the lock screen option in the Per-Monitor Wallpaper mod if you use
  both mods, to avoid duplicate work.
*/
// ==/WindhawkModReadme==

// ==WindhawkModSettings==
/*
- enabled: true
  $name: Enable mod
  $description: When disabled, the lock screen is not changed or enforced.
- disableSpotlight: true
  $name: Disable Windows Spotlight on lock screen
  $description: >-
    Turns off Spotlight and rotating lock screen features that replace your
    image with the default blue Windows background after restart.
- copyToSystemData: true
  $name: Copy to SystemData cache
  $description: >-
    Also copies the image into Windows SystemData ReadOnly cache. Helps
    persistence after cold boot when the registry alone is not enough.
- checkIntervalSeconds: 15
  $name: Check interval (seconds)
  $description: >-
    How often to verify and re-apply the lock screen image. Windows may reset
    it after sleep or updates; lower values recover faster.
- openImageBrowser: 0
  $name: Open image browser
  $description: >-
    Set to 1 and save settings to open a Browse window. Set back to 0 after it
    opens.
*/
// ==/WindhawkModSettings==

#include <windows.h>
#include <sddl.h>
#include <shellapi.h>
#include <wtsapi32.h>
#include <commdlg.h>

#include <algorithm>
#include <atomic>
#include <string>
#include <vector>

namespace {

struct Settings {
    bool enabled = true;
    bool disableSpotlight = true;
    bool copyToSystemData = true;
    int checkIntervalSeconds = 15;
};

Settings g_settings;
CRITICAL_SECTION g_applyLock;
HANDLE g_workerThread = nullptr;
HANDLE g_wakeEvent = nullptr;
HWND g_notifyWnd = nullptr;
std::atomic<bool> g_unloading{false};
std::atomic<bool> g_applyPending{false};
std::atomic<bool> g_pickerDialogOpen{false};
std::atomic<bool> g_isExplorerProcess{false};

constexpr wchar_t kNotifyWindowClass[] = L"WhLockScreenWallpaperNotifyWnd";
constexpr wchar_t kPickerWindowClass[] = L"WhLockScreenWallpaperPickerWnd";
constexpr wchar_t kStagingDirName[] = L"WindhawkLockScreen";
constexpr wchar_t kStagingFileBase[] = L"lockscreen";

constexpr wchar_t kCreativeKey[] =
    L"Software\\Microsoft\\Windows\\CurrentVersion\\Lock Screen\\Creative";
constexpr wchar_t kLockScreenKey[] =
    L"Software\\Microsoft\\Windows\\CurrentVersion\\Lock Screen";
constexpr wchar_t kContentDeliveryManager[] =
    L"Software\\Microsoft\\Windows\\CurrentVersion\\ContentDeliveryManager";
constexpr wchar_t kPersonalizationCspKey[] =
    L"Software\\Microsoft\\Windows\\CurrentVersion\\PersonalizationCSP";
constexpr wchar_t kCloudContentKey[] =
    L"Software\\Policies\\Microsoft\\Windows\\CloudContent";
constexpr wchar_t kPersonalizationPolicyKey[] =
    L"Software\\Policies\\Microsoft\\Windows\\Personalization";
constexpr wchar_t kDesktopKey[] = L"Control Panel\\Desktop";
constexpr wchar_t kLogonUiCreativeRoot[] =
    L"SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Authentication\\LogonUI\\Creative";
constexpr wchar_t kLogonUiBackgroundKey[] =
    L"SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Authentication\\LogonUI\\Background";
constexpr wchar_t kSystemProtectedUserDataRoot[] =
    L"SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\SystemProtectedUserData";
constexpr wchar_t kSystemPolicyKey[] =
    L"SOFTWARE\\Policies\\Microsoft\\Windows\\System";
constexpr wchar_t kApplyScriptName[] = L"apply-lockscreen.ps1";
constexpr wchar_t kAdminApplyScriptName[] = L"apply-lockscreen-admin.ps1";
constexpr wchar_t kSourceMarkerName[] = L"source.path";
constexpr wchar_t kElevatedMarkerName[] = L"elevated.stamp";

void LoadSettings();
void RequestApply(bool force);
bool ApplyLockScreenWallpaper(bool force);
std::wstring GetProgramDataStagingDir();
std::wstring ReadPersistedSourcePath();

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

void SaveWallpaperPath(PCWSTR settingName, const std::wstring& path) {
    Wh_SetStringValue(settingName, path.c_str());
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

    std::wstring normalized = buffer;
    for (auto& ch : normalized) {
        if (ch == L'/') {
            ch = L'\\';
        }
    }

    while (normalized.size() > 3 && normalized.back() == L'\\') {
        normalized.pop_back();
    }

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

bool IsExplorerProcess() {
    wchar_t modulePath[MAX_PATH] = {};
    const DWORD length =
        GetModuleFileNameW(nullptr, modulePath, ARRAYSIZE(modulePath));
    if (length == 0 || length >= ARRAYSIZE(modulePath)) {
        return false;
    }

    const wchar_t* fileName = wcsrchr(modulePath, L'\\');
    fileName = fileName ? fileName + 1 : modulePath;
    return _wcsicmp(fileName, L"explorer.exe") == 0;
}

bool SetRegistryDword(HKEY root, PCWSTR subKey, PCWSTR valueName, DWORD value) {
    return RegSetKeyValueW(root, subKey, valueName, REG_DWORD, &value,
                           sizeof(value)) == ERROR_SUCCESS;
}

bool SetRegistryString(HKEY root, PCWSTR subKey, PCWSTR valueName,
                       PCWSTR value) {
    if (!value) {
        value = L"";
    }
    return RegSetKeyValueW(root, subKey, valueName, REG_SZ, value,
                           static_cast<DWORD>((wcslen(value) + 1) *
                                              sizeof(wchar_t))) == ERROR_SUCCESS;
}

bool ReadRegistryString(HKEY root, PCWSTR subKey, PCWSTR valueName,
                        std::wstring* outValue) {
    if (!outValue) {
        return false;
    }

    outValue->clear();
    DWORD type = 0;
    DWORD size = 0;
    LSTATUS status =
        RegGetValueW(root, subKey, valueName, RRF_RT_REG_SZ, &type, nullptr,
                     &size);
    if (status != ERROR_SUCCESS || size < sizeof(wchar_t)) {
        return false;
    }

    outValue->resize((size / sizeof(wchar_t)) - 1);
    status = RegGetValueW(root, subKey, valueName, RRF_RT_REG_SZ, &type,
                          outValue->data(), &size);
    return status == ERROR_SUCCESS;
}

bool EnsureDirectoryExists(const std::wstring& path) {
    if (path.empty()) {
        return false;
    }

    DWORD attrs = GetFileAttributesW(path.c_str());
    if (attrs != INVALID_FILE_ATTRIBUTES &&
        (attrs & FILE_ATTRIBUTE_DIRECTORY)) {
        return true;
    }

    return CreateDirectoryW(path.c_str(), nullptr) != FALSE ||
           GetLastError() == ERROR_ALREADY_EXISTS;
}

bool GetFileLastWriteTime(PCWSTR path, FILETIME* writeTime) {
    if (!path || !writeTime) {
        return false;
    }

    WIN32_FILE_ATTRIBUTE_DATA fileData{};
    if (!GetFileAttributesExW(path, GetFileExInfoStandard, &fileData)) {
        return false;
    }

    *writeTime = fileData.ftLastWriteTime;
    return true;
}

bool IsSourceNewerThanTarget(PCWSTR sourcePath, PCWSTR targetPath) {
    FILETIME sourceTime{};
    FILETIME targetTime{};
    if (!GetFileLastWriteTime(sourcePath, &sourceTime)) {
        return true;
    }
    if (!GetFileLastWriteTime(targetPath, &targetTime)) {
        return true;
    }

    return CompareFileTime(&sourceTime, &targetTime) > 0;
}

bool CopyFileIfNeeded(PCWSTR sourcePath, PCWSTR targetPath) {
    if (!sourcePath || !*sourcePath || !targetPath || !*targetPath) {
        return false;
    }

    const std::wstring persistedSource = ReadPersistedSourcePath();
    const bool sourceChanged =
        persistedSource.empty() || !PathsEqual(sourcePath, persistedSource.c_str());

    if (!sourceChanged && !IsSourceNewerThanTarget(sourcePath, targetPath) &&
        FileExists(targetPath)) {
        return true;
    }

    const std::wstring targetDir = NormalizePath(targetPath).substr(
        0, NormalizePath(targetPath).find_last_of(L'\\'));
    if (!EnsureDirectoryExists(targetDir)) {
        Wh_Log(L"Failed to create directory for %s", targetPath);
        return false;
    }

    if (!CopyFileW(sourcePath, targetPath, FALSE)) {
        Wh_Log(L"Failed to copy %s -> %s: %u", sourcePath, targetPath,
               GetLastError());
        return false;
    }

    return true;
}

std::wstring BuildSourceVersionStamp(PCWSTR sourcePath) {
    if (!sourcePath || !*sourcePath) {
        return L"";
    }

    FILETIME writeTime{};
    if (!GetFileLastWriteTime(sourcePath, &writeTime)) {
        return NormalizePath(sourcePath);
    }

    return NormalizePath(sourcePath) + L"|" +
           std::to_wstring(writeTime.dwHighDateTime) + L":" +
           std::to_wstring(writeTime.dwLowDateTime);
}

bool ReadElevatedMarker(std::wstring* stamp) {
    if (!stamp) {
        return false;
    }

    stamp->clear();
    const std::wstring stagingDir = GetProgramDataStagingDir();
    if (stagingDir.empty()) {
        return false;
    }

    const std::wstring markerPath = stagingDir + L"\\" + kElevatedMarkerName;
    HANDLE file =
        CreateFileW(markerPath.c_str(), GENERIC_READ, FILE_SHARE_READ, nullptr,
                    OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, nullptr);
    if (file == INVALID_HANDLE_VALUE) {
        return false;
    }

    std::vector<wchar_t> buffer(4096, L'\0');
    DWORD read = 0;
    if (!ReadFile(file, buffer.data(),
                  static_cast<DWORD>((buffer.size() - 1) * sizeof(wchar_t)),
                  &read, nullptr) ||
        read < sizeof(wchar_t)) {
        CloseHandle(file);
        return false;
    }

    CloseHandle(file);
    *stamp = TrimQuotes(std::wstring(buffer.data(), read / sizeof(wchar_t)));
    return true;
}

bool WriteElevatedMarker(PCWSTR stamp) {
    if (!stamp || !*stamp) {
        return false;
    }

    const std::wstring stagingDir = GetProgramDataStagingDir();
    if (stagingDir.empty() || !EnsureDirectoryExists(stagingDir)) {
        return false;
    }

    const std::wstring markerPath = stagingDir + L"\\" + kElevatedMarkerName;
    HANDLE file = CreateFileW(markerPath.c_str(), GENERIC_WRITE, 0, nullptr,
                              CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, nullptr);
    if (file == INVALID_HANDLE_VALUE) {
        return false;
    }

    const std::wstring normalized = TrimQuotes(stamp);
    const DWORD bytes =
        static_cast<DWORD>(normalized.size() * sizeof(wchar_t));
    DWORD written = 0;
    const BOOL ok = WriteFile(file, normalized.c_str(), bytes, &written, nullptr) &&
                    written == bytes;
    CloseHandle(file);
    return ok != FALSE;
}

bool NeedsElevatedPolicyFix(PCWSTR stagedPath) {
    if (!stagedPath || !*stagedPath) {
        return false;
    }

    std::wstring policyImage;
    if (ReadRegistryString(HKEY_LOCAL_MACHINE, kPersonalizationPolicyKey,
                           L"LockScreenImage", &policyImage)) {
        if (!FileExists(policyImage.c_str())) {
            Wh_Log(L"HKLM policy lock screen image missing: %s",
                   policyImage.c_str());
            return true;
        }

        if (!PathsEqual(policyImage.c_str(), stagedPath)) {
            Wh_Log(L"HKLM policy lock screen path differs from staged image");
            return true;
        }

        return false;
    }

    return !FileExists(stagedPath);
}

bool ShouldRunElevatedPolicyFix(PCWSTR sourcePath, PCWSTR stagedPath) {
    if (!NeedsElevatedPolicyFix(stagedPath)) {
        return false;
    }

    const std::wstring currentStamp = BuildSourceVersionStamp(sourcePath);
    std::wstring appliedStamp;
    if (ReadElevatedMarker(&appliedStamp) &&
        PathsEqual(appliedStamp.c_str(), currentStamp.c_str())) {
        return false;
    }

    return true;
}

std::wstring GetFileExtension(PCWSTR sourcePath) {
    if (!sourcePath || !*sourcePath) {
        return L".jpg";
    }

    const wchar_t* fileName = wcsrchr(sourcePath, L'\\');
    fileName = fileName ? fileName + 1 : sourcePath;
    const wchar_t* extension = wcsrchr(fileName, L'.');
    if (!extension || extension == fileName) {
        return L".jpg";
    }

    return extension;
}

std::wstring GetProgramDataStagingDir() {
    wchar_t programData[MAX_PATH] = {};
    DWORD length = GetEnvironmentVariableW(L"ProgramData", programData,
                                           ARRAYSIZE(programData));
    if (length == 0 || length >= ARRAYSIZE(programData)) {
        return L"";
    }

    return std::wstring(programData) + L"\\" + kStagingDirName;
}

std::wstring BuildProgramDataStagedPath(PCWSTR sourcePath) {
    const std::wstring stagingDir = GetProgramDataStagingDir();
    if (stagingDir.empty() || !EnsureDirectoryExists(stagingDir)) {
        return L"";
    }

    return stagingDir + L"\\" + kStagingFileBase +
           GetFileExtension(sourcePath);
}

std::wstring BuildProgramDataUniquePath(PCWSTR sourcePath) {
    const std::wstring stagingDir = GetProgramDataStagingDir();
    if (stagingDir.empty() || !EnsureDirectoryExists(stagingDir)) {
        return L"";
    }

    SYSTEMTIME time{};
    GetSystemTime(&time);
    wchar_t suffix[64] = {};
    swprintf_s(suffix, L"_%04u%02u%02u_%02u%02u%02u", time.wYear, time.wMonth,
               time.wDay, time.wHour, time.wMinute, time.wSecond);

    return stagingDir + L"\\" + kStagingFileBase + suffix +
           GetFileExtension(sourcePath);
}

std::wstring BuildLocalStagingPath(PCWSTR sourcePath) {
    wchar_t localAppData[MAX_PATH] = {};
    DWORD length = GetEnvironmentVariableW(L"LOCALAPPDATA", localAppData,
                                           ARRAYSIZE(localAppData));
    if (length == 0 || length >= ARRAYSIZE(localAppData)) {
        return L"";
    }

    const std::wstring stagingDir =
        std::wstring(localAppData) + L"\\" + kStagingDirName;
    if (!EnsureDirectoryExists(stagingDir)) {
        return L"";
    }

    return stagingDir + L"\\" + kStagingFileBase +
           GetFileExtension(sourcePath);
}

bool WritePersistedSourcePath(PCWSTR sourcePath) {
    if (!sourcePath || !*sourcePath) {
        return false;
    }

    const std::wstring stagingDir = GetProgramDataStagingDir();
    if (stagingDir.empty() || !EnsureDirectoryExists(stagingDir)) {
        return false;
    }

    const std::wstring markerPath = stagingDir + L"\\" + kSourceMarkerName;
    HANDLE file = CreateFileW(markerPath.c_str(), GENERIC_WRITE, 0, nullptr,
                              CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, nullptr);
    if (file == INVALID_HANDLE_VALUE) {
        return false;
    }

    const std::wstring normalized = NormalizePath(sourcePath);
    const DWORD bytes = static_cast<DWORD>(normalized.size() * sizeof(wchar_t));
    DWORD written = 0;
    const BOOL ok =
        WriteFile(file, normalized.c_str(), bytes, &written, nullptr) &&
        written == bytes;
    CloseHandle(file);
    return ok != FALSE;
}

std::wstring ReadPersistedSourcePath() {
    const std::wstring stagingDir = GetProgramDataStagingDir();
    if (stagingDir.empty()) {
        return L"";
    }

    const std::wstring markerPath = stagingDir + L"\\" + kSourceMarkerName;
    HANDLE file =
        CreateFileW(markerPath.c_str(), GENERIC_READ, FILE_SHARE_READ, nullptr,
                    OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, nullptr);
    if (file == INVALID_HANDLE_VALUE) {
        return L"";
    }

    std::vector<wchar_t> buffer(4096, L'\0');
    DWORD read = 0;
    if (!ReadFile(file, buffer.data(),
                  static_cast<DWORD>((buffer.size() - 1) * sizeof(wchar_t)),
                  &read, nullptr) ||
        read < sizeof(wchar_t)) {
        CloseHandle(file);
        return L"";
    }

    CloseHandle(file);
    return TrimQuotes(std::wstring(buffer.data(), read / sizeof(wchar_t)));
}

std::wstring ResolveSourcePath() {
    const std::wstring configured =
        LoadWallpaperSetting(L"lockScreenWallpaper");
    if (!configured.empty() && FileExists(configured.c_str())) {
        return configured;
    }

    const std::wstring persisted = ReadPersistedSourcePath();
    if (!persisted.empty() && FileExists(persisted.c_str())) {
        return persisted;
    }

    const std::wstring stagingDir = GetProgramDataStagingDir();
    if (!stagingDir.empty()) {
        const PCWSTR candidates[] = {L"\\lockscreen.jpg", L"\\lockscreen.jpeg",
                                       L"\\lockscreen.png", L"\\lockscreen.bmp",
                                       L"\\lockscreen.webp"};
        for (PCWSTR suffix : candidates) {
            const std::wstring candidate = stagingDir + suffix;
            if (FileExists(candidate.c_str())) {
                return candidate;
            }
        }
    }

    return L"";
}

std::wstring StageLockScreenImage(PCWSTR sourcePath, bool createUniqueCopy) {
    if (!sourcePath || !*sourcePath) {
        return L"";
    }

    const std::wstring programDataPath =
        BuildProgramDataStagedPath(sourcePath);
    if (programDataPath.empty() ||
        !CopyFileIfNeeded(sourcePath, programDataPath.c_str())) {
        Wh_Log(L"Failed to stage lock screen image in ProgramData");
        return L"";
    }

    const std::wstring localPath = BuildLocalStagingPath(sourcePath);
    if (!localPath.empty()) {
        CopyFileIfNeeded(sourcePath, localPath.c_str());
    }

    WritePersistedSourcePath(sourcePath);

    if (createUniqueCopy) {
        const std::wstring uniquePath =
            BuildProgramDataUniquePath(sourcePath);
        if (!uniquePath.empty() &&
            CopyFileW(sourcePath, uniquePath.c_str(), FALSE)) {
            Wh_Log(L"Created unique lock screen copy at %s", uniquePath.c_str());
            return uniquePath;
        }
    }

    Wh_Log(L"Staged lock screen image at %s", programDataPath.c_str());
    return programDataPath;
}

bool GetCurrentUserSidString(std::wstring* sidString) {
    if (!sidString) {
        return false;
    }

    HANDLE token = nullptr;
    if (!OpenProcessToken(GetCurrentProcess(), TOKEN_QUERY, &token)) {
        return false;
    }

    DWORD size = 0;
    GetTokenInformation(token, TokenUser, nullptr, 0, &size);
    std::vector<BYTE> buffer(size);
    if (!GetTokenInformation(token, TokenUser, buffer.data(), size, &size)) {
        CloseHandle(token);
        return false;
    }
    CloseHandle(token);

    PSID sid = reinterpret_cast<TOKEN_USER*>(buffer.data())->User.Sid;
    LPWSTR sidStr = nullptr;
    if (!ConvertSidToStringSidW(sid, &sidStr)) {
        return false;
    }

    *sidString = sidStr;
    LocalFree(sidStr);
    return true;
}

bool CopyToSystemDataCache(PCWSTR stagedPath, PCWSTR sourcePath) {
    if (!g_settings.copyToSystemData || !stagedPath || !*stagedPath) {
        return true;
    }

    std::wstring sidString;
    if (!GetCurrentUserSidString(&sidString)) {
        Wh_Log(L"Could not resolve user SID for SystemData copy");
        return false;
    }

    wchar_t programData[MAX_PATH] = {};
    DWORD length = GetEnvironmentVariableW(L"ProgramData", programData,
                                           ARRAYSIZE(programData));
    if (length == 0 || length >= ARRAYSIZE(programData)) {
        Wh_Log(L"Failed to resolve ProgramData");
        return false;
    }

    const std::wstring readOnlyDir =
        std::wstring(programData) + L"\\Microsoft\\Windows\\SystemData\\" +
        sidString + L"\\ReadOnly";
    if (!EnsureDirectoryExists(readOnlyDir)) {
        Wh_Log(L"Could not create SystemData ReadOnly folder (may need admin)");
        return false;
    }

    const std::wstring cachePath =
        readOnlyDir + L"\\LockScreen_" + kStagingFileBase +
        GetFileExtension(sourcePath ? sourcePath : stagedPath);

    if (!CopyFileIfNeeded(stagedPath, cachePath.c_str())) {
        Wh_Log(L"SystemData cache copy failed (registry apply still attempted)");
        return false;
    }

    Wh_Log(L"Copied lock screen image to SystemData cache: %s",
           cachePath.c_str());
    return true;
}

void ApplyLogonUiCreativeKeys(PCWSTR imagePath) {
    if (!imagePath || !*imagePath) {
        return;
    }

    std::wstring sidString;
    if (!GetCurrentUserSidString(&sidString)) {
        Wh_Log(L"Could not resolve SID for LogonUI registry");
        return;
    }

    const std::wstring sidKey =
        std::wstring(kLogonUiCreativeRoot) + L"\\" + sidString;
    const std::wstring sidSubKey = sidKey + L"\\Windhawk";

    const DWORD zero = 0;
    if (SetRegistryDword(HKEY_LOCAL_MACHINE, sidKey.c_str(),
                         L"RotatingLockScreenEnabled", zero)) {
        Wh_Log(L"Updated LogonUI Creative key for SID");
    }
    SetRegistryDword(HKEY_LOCAL_MACHINE, sidKey.c_str(),
                     L"RotatingLockScreenOverlayEnabled", zero);
    SetRegistryDword(HKEY_LOCAL_MACHINE, sidKey.c_str(), L"LockImageFlags", zero);
    SetRegistryDword(HKEY_LOCAL_MACHINE, sidKey.c_str(), L"LockScreenOptions",
                     zero);
    SetRegistryString(HKEY_LOCAL_MACHINE, sidKey.c_str(), L"LandscapeAssetPath",
                      imagePath);
    SetRegistryString(HKEY_LOCAL_MACHINE, sidKey.c_str(), L"PortraitAssetPath",
                      imagePath);
    SetRegistryString(HKEY_LOCAL_MACHINE, sidSubKey.c_str(), L"landscapeImage",
                      imagePath);
    SetRegistryString(HKEY_LOCAL_MACHINE, sidSubKey.c_str(), L"portraitImage",
                      imagePath);

    wchar_t numericSubKeyName[32] = {};
    swprintf_s(numericSubKeyName, L"%llu",
               static_cast<unsigned long long>(GetTickCount64() % 1000000000ULL));
    const std::wstring numericSubKey = sidKey + L"\\" + numericSubKeyName;
    SetRegistryString(HKEY_LOCAL_MACHINE, numericSubKey.c_str(), L"landscapeImage",
                      imagePath);
    SetRegistryString(HKEY_LOCAL_MACHINE, numericSubKey.c_str(), L"portraitImage",
                      imagePath);
}

void ApplySignInScreenSyncKeys(PCWSTR imagePath) {
    const DWORD showBackground = 0;

    SetRegistryDword(HKEY_LOCAL_MACHINE, kLogonUiBackgroundKey,
                     L"HideLogonBackgroundImage", showBackground);
    RegDeleteKeyValueW(HKEY_LOCAL_MACHINE, kSystemPolicyKey,
                       L"DisableLogonBackgroundImage");

    std::wstring sidString;
    if (!GetCurrentUserSidString(&sidString)) {
        Wh_Log(L"Could not resolve SID for sign-in screen sync");
        return;
    }

    const std::wstring signInKey =
        std::wstring(kSystemProtectedUserDataRoot) + L"\\" + sidString +
        L"\\AnyoneRead\\LockScreen";
    if (SetRegistryDword(HKEY_LOCAL_MACHINE, signInKey.c_str(),
                         L"HideLogonBackgroundImage", showBackground)) {
        Wh_Log(L"Enabled sign-in screen background (same as lock screen)");
    }

    if (imagePath && *imagePath) {
        SetRegistryString(HKEY_LOCAL_MACHINE, signInKey.c_str(),
                          L"LandscapeAssetPath", imagePath);
        SetRegistryString(HKEY_LOCAL_MACHINE, signInKey.c_str(),
                          L"PortraitAssetPath", imagePath);
    }
}

bool IsWorkstationLocked() {
    HDESK inputDesktop = OpenInputDesktop(0, FALSE, DESKTOP_READOBJECTS);
    if (!inputDesktop) {
        return false;
    }

    wchar_t desktopName[256] = {};
    DWORD nameLength = 0;
    const bool gotName = GetUserObjectInformationW(
        inputDesktop, UOI_NAME, desktopName, sizeof(desktopName), &nameLength);
    CloseDesktop(inputDesktop);

    if (!gotName) {
        return false;
    }

    return _wcsicmp(desktopName, L"Default") != 0 &&
           _wcsicmp(desktopName, L"Winsta0\\Default") != 0;
}

void RestartLockAppIfUnlocked() {
    if (IsWorkstationLocked()) {
        return;
    }

    STARTUPINFOW startupInfo{};
    startupInfo.cb = sizeof(startupInfo);
    startupInfo.dwFlags = STARTF_USESHOWWINDOW;
    startupInfo.wShowWindow = SW_HIDE;

    wchar_t command[] = L"taskkill.exe /IM LockApp.exe /F /T";
    PROCESS_INFORMATION processInfo{};

    if (!CreateProcessW(nullptr, command, nullptr, nullptr, FALSE,
                        CREATE_NO_WINDOW, nullptr, nullptr, &startupInfo,
                        &processInfo)) {
        return;
    }

    WaitForSingleObject(processInfo.hProcess, 5000);
    CloseHandle(processInfo.hThread);
    CloseHandle(processInfo.hProcess);
    Wh_Log(L"Restarted LockApp so Win+L uses the new image");
}

void ApplyDesktopLockScreenKeys() {
    SetRegistryString(HKEY_CURRENT_USER, kDesktopKey, L"LockScreenAutoLockActive",
                      L"0");
}

void DisableLockScreenSpotlight() {
    if (!g_settings.disableSpotlight) {
        return;
    }

    const DWORD disabled = 0;
    const DWORD enabled = 1;

    const PCWSTR spotlightDwordValues[] = {
        L"RotatingLockScreenEnabled",
        L"RotatingLockScreenOverlayEnabled",
        L"SubscribedContent-310093Enabled",
        L"SubscribedContent-338387Enabled",
        L"SubscribedContent-338388Enabled",
        L"SubscribedContent-338389Enabled",
        L"SubscribedContent-338393Enabled",
        L"SubscribedContent-353694Enabled",
        L"SubscribedContent-353696Enabled",
        L"SoftLandingEnabled",
        L"SystemPaneSuggestionsEnabled",
    };

    for (PCWSTR valueName : spotlightDwordValues) {
        if (!SetRegistryDword(HKEY_CURRENT_USER, kContentDeliveryManager,
                              valueName, disabled)) {
            Wh_Log(L"Failed to disable ContentDeliveryManager value %s",
                   valueName);
        }
    }

    SetRegistryDword(HKEY_CURRENT_USER, kCloudContentKey,
                     L"DisableWindowsSpotlightFeatures", enabled);
    SetRegistryDword(HKEY_CURRENT_USER, kCloudContentKey,
                     L"DisableWindowsConsumerFeatures", enabled);
    SetRegistryDword(HKEY_LOCAL_MACHINE, kCloudContentKey,
                     L"DisableWindowsSpotlightFeatures", enabled);
    SetRegistryDword(HKEY_LOCAL_MACHINE, kCloudContentKey,
                     L"DisableWindowsConsumerFeatures", enabled);
}

void NotifyPersonalizationChanged() {
    SendMessageTimeoutW(HWND_BROADCAST, WM_SETTINGCHANGE, 0,
                        (LPARAM)L"Personalization", SMTO_ABORTIFHUNG, 2000,
                        nullptr);
    SendMessageTimeoutW(HWND_BROADCAST, WM_SETTINGCHANGE, 0,
                        (LPARAM)L"Desktop", SMTO_ABORTIFHUNG, 2000, nullptr);
}

void ApplyPersonalizationCspKeys(PCWSTR imagePath) {
    if (!imagePath || !*imagePath) {
        return;
    }

    const DWORD statusEnabled = 1;
    SetRegistryDword(HKEY_CURRENT_USER, kPersonalizationCspKey,
                     L"LockScreenImageStatus", statusEnabled);
    SetRegistryString(HKEY_CURRENT_USER, kPersonalizationCspKey,
                      L"LockScreenImagePath", imagePath);
    SetRegistryString(HKEY_CURRENT_USER, kPersonalizationCspKey,
                      L"LockScreenImageUrl", imagePath);

    SetRegistryString(HKEY_CURRENT_USER, kPersonalizationPolicyKey,
                      L"LockScreenImage", imagePath);
    SetRegistryDword(HKEY_CURRENT_USER, kPersonalizationPolicyKey,
                     L"LockScreenOverlaysDisabled", 1);
}

void ApplyCreativeRegistryKeys(PCWSTR imagePath) {
    if (!imagePath || !*imagePath) {
        return;
    }

    const DWORD lockImageFlags = 0;
    const DWORD lockScreenOptions = 0;

    SetRegistryDword(HKEY_CURRENT_USER, kCreativeKey, L"LockImageFlags",
                     lockImageFlags);
    SetRegistryDword(HKEY_CURRENT_USER, kCreativeKey, L"LockScreenOptions",
                     lockScreenOptions);
    SetRegistryString(HKEY_CURRENT_USER, kCreativeKey, L"CreativeId", L"");
    SetRegistryString(HKEY_CURRENT_USER, kCreativeKey, L"LandscapeAssetPath",
                      imagePath);
    SetRegistryString(HKEY_CURRENT_USER, kCreativeKey, L"PortraitAssetPath",
                      imagePath);
    SetRegistryString(HKEY_CURRENT_USER, kCreativeKey, L"PlacementId", L"");
    SetRegistryString(HKEY_CURRENT_USER, kCreativeKey, L"ImpressionToken", L"");
    SetRegistryString(HKEY_CURRENT_USER, kCreativeKey,
                      L"HotspotImageFolderPath", imagePath);
    SetRegistryString(HKEY_CURRENT_USER, kCreativeKey, L"CreativeJson", L"");

    SetRegistryDword(HKEY_CURRENT_USER, kLockScreenKey, L"SlideshowEnabled", 0);
}

bool LockScreenRegistryMatches(PCWSTR imagePath) {
    if (!imagePath || !*imagePath) {
        return false;
    }

    std::wstring landscapePath;
    if (!ReadRegistryString(HKEY_CURRENT_USER, kCreativeKey,
                            L"LandscapeAssetPath", &landscapePath)) {
        return false;
    }

    return PathsEqual(landscapePath.c_str(), imagePath);
}

bool LockScreenNeedsReapply(PCWSTR sourcePath, PCWSTR stagedPath) {
    if (!stagedPath || !*stagedPath) {
        return true;
    }

    if (!LockScreenRegistryMatches(stagedPath)) {
        return true;
    }

    const std::wstring configured =
        LoadWallpaperSetting(L"lockScreenWallpaper");
    if (!configured.empty() && !PathsEqual(configured.c_str(), stagedPath) &&
        !PathsEqual(configured.c_str(), ReadPersistedSourcePath().c_str())) {
        return true;
    }

    if (sourcePath && *sourcePath &&
        IsSourceNewerThanTarget(sourcePath, stagedPath)) {
        return true;
    }

    return !FileExists(stagedPath);
}

bool WriteScriptFile(PCWSTR scriptPath, PCWSTR scriptContent) {
    if (!scriptPath || !scriptContent) {
        return false;
    }

    HANDLE file = CreateFileW(scriptPath, GENERIC_WRITE, 0, nullptr,
                              CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, nullptr);
    if (file == INVALID_HANDLE_VALUE) {
        return false;
    }

    const DWORD bytes =
        static_cast<DWORD>(wcslen(scriptContent) * sizeof(wchar_t));
    DWORD written = 0;
    const BOOL ok = WriteFile(file, scriptContent, bytes, &written, nullptr) &&
                    written == bytes;
    CloseHandle(file);
    return ok != FALSE;
}

bool EnsureApplyScript(std::wstring* scriptPath) {
    if (!scriptPath) {
        return false;
    }

    const std::wstring stagingDir = GetProgramDataStagingDir();
    if (stagingDir.empty() || !EnsureDirectoryExists(stagingDir)) {
        return false;
    }

    *scriptPath = stagingDir + L"\\" + kApplyScriptName;

    const wchar_t scriptContent[] =
        L"param([Parameter(Mandatory=$true)][string]$ImagePath)\r\n"
        L"$ErrorActionPreference = 'Stop'\r\n"
        L"if (-not (Test-Path -LiteralPath $ImagePath)) { exit 2 }\r\n"
        L"Add-Type -AssemblyName System.Runtime.WindowsRuntime\r\n"
        L"function Await($WinRTAsyncOp, $ResultType) {\r\n"
        L"  $asTaskGeneric = ([System.WindowsRuntimeSystemExtensions].GetMethods() "
        L"| Where-Object { $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 "
        L"-and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' "
        L"})[0]\r\n"
        L"  $asTask = $asTaskGeneric.MakeGenericMethod($ResultType)\r\n"
        L"  $netTask = $asTask.Invoke($null, @($WinRTAsyncOp))\r\n"
        L"  $netTask.Wait(-1) | Out-Null\r\n"
        L"  $netTask.Result\r\n"
        L"}\r\n"
        L"[void][Windows.Storage.StorageFile,Windows.Storage,"
        L"ContentType=WindowsRuntime]\r\n"
        L"[void][Windows.System.UserProfile.UserProfilePersonalizationSettings,"
        L"Windows.System.UserProfile,ContentType=WindowsRuntime]\r\n"
        L"$file = Await ([Windows.Storage.StorageFile]::GetFileFromPathAsync("
        L"$ImagePath)) ([Windows.Storage.StorageFile])\r\n"
        L"$ok = Await ([Windows.System.UserProfile.UserProfilePersonalizationSettings]"
        L"::Current.TrySetLockScreenImageAsync($file)) ([bool])\r\n"
        L"if (-not $ok) { exit 1 }\r\n"
        L"exit 0\r\n";

    return WriteScriptFile(scriptPath->c_str(), scriptContent);
}

bool EnsureAdminApplyScript(std::wstring* scriptPath) {
    if (!scriptPath) {
        return false;
    }

    const std::wstring stagingDir = GetProgramDataStagingDir();
    if (stagingDir.empty() || !EnsureDirectoryExists(stagingDir)) {
        return false;
    }

    *scriptPath = stagingDir + L"\\" + kAdminApplyScriptName;

    const wchar_t scriptContent[] =
        L"param([Parameter(Mandatory=$true)][string]$ImagePath)\r\n"
        L"$ErrorActionPreference = 'Stop'\r\n"
        L"if (-not (Test-Path -LiteralPath $ImagePath)) { exit 2 }\r\n"
        L"$policyKey = 'HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows\\Personalization'\r\n"
        L"$policyPath = $null\r\n"
        L"try { $policyPath = (Get-ItemProperty -Path $policyKey -Name "
        L"LockScreenImage -ErrorAction Stop).LockScreenImage } catch {}\r\n"
        L"$targets = @()\r\n"
        L"if ($policyPath) { $targets += $policyPath }\r\n"
        L"$targets += 'C:\\Windows\\Web\\Screen\\wall.jpg'\r\n"
        L"foreach ($target in ($targets | Select-Object -Unique)) {\r\n"
        L"  if ([string]::IsNullOrWhiteSpace($target)) { continue }\r\n"
        L"  $dir = Split-Path -Parent $target\r\n"
        L"  if ($dir -and -not (Test-Path -LiteralPath $dir)) {\r\n"
        L"    New-Item -ItemType Directory -Force -Path $dir | Out-Null\r\n"
        L"  }\r\n"
        L"  Copy-Item -LiteralPath $ImagePath -Destination $target -Force\r\n"
        L"}\r\n"
        L"Set-ItemProperty -Path $policyKey -Name LockScreenImage -Value $ImagePath "
        L"-Type String -Force\r\n"
        L"$csp = 'HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\PersonalizationCSP'\r\n"
        L"New-Item -Path $csp -Force | Out-Null\r\n"
        L"Set-ItemProperty -Path $csp -Name LockScreenImagePath -Value $ImagePath "
        L"-Type String -Force\r\n"
        L"Set-ItemProperty -Path $csp -Name LockScreenImageUrl -Value $ImagePath "
        L"-Type String -Force\r\n"
        L"Set-ItemProperty -Path $csp -Name LockScreenImageStatus -Value 1 -Type DWord "
        L"-Force\r\n"
        L"exit 0\r\n";

    return WriteScriptFile(scriptPath->c_str(), scriptContent);
}

bool RunPowerShellScript(PCWSTR scriptPath, PCWSTR imagePath, bool elevated) {
    if (!scriptPath || !imagePath) {
        return false;
    }

    std::wstring parameters =
        L"-NoProfile -Sta -NonInteractive -WindowStyle Hidden "
        L"-ExecutionPolicy Bypass -File \"";
    parameters += scriptPath;
    parameters += L"\" -ImagePath \"";
    parameters += imagePath;
    parameters += L"\"";

    if (elevated) {
        SHELLEXECUTEINFOW shellInfo{};
        shellInfo.cbSize = sizeof(shellInfo);
        shellInfo.fMask = SEE_MASK_NOCLOSEPROCESS;
        shellInfo.lpVerb = L"runas";
        shellInfo.lpFile = L"powershell.exe";
        shellInfo.lpParameters = parameters.c_str();
        shellInfo.nShow = SW_HIDE;

        if (!ShellExecuteExW(&shellInfo) || !shellInfo.hProcess) {
            Wh_Log(L"Elevated apply declined or failed: %u", GetLastError());
            return false;
        }

        WaitForSingleObject(shellInfo.hProcess, 120000);
        DWORD exitCode = 1;
        GetExitCodeProcess(shellInfo.hProcess, &exitCode);
        CloseHandle(shellInfo.hProcess);
        return exitCode == 0;
    }

    STARTUPINFOW startupInfo{};
    startupInfo.cb = sizeof(startupInfo);
    startupInfo.dwFlags = STARTF_USESHOWWINDOW;
    startupInfo.wShowWindow = SW_HIDE;

    std::wstring command = L"powershell.exe " + parameters;
    PROCESS_INFORMATION processInfo{};
    std::vector<wchar_t> commandBuffer(command.begin(), command.end());
    commandBuffer.push_back(L'\0');

    if (!CreateProcessW(nullptr, commandBuffer.data(), nullptr, nullptr, FALSE,
                        CREATE_NO_WINDOW, nullptr, nullptr, &startupInfo,
                        &processInfo)) {
        Wh_Log(L"Failed to launch PowerShell helper: %u", GetLastError());
        return false;
    }

    WaitForSingleObject(processInfo.hProcess, 60000);
    DWORD exitCode = 1;
    GetExitCodeProcess(processInfo.hProcess, &exitCode);
    CloseHandle(processInfo.hThread);
    CloseHandle(processInfo.hProcess);
    return exitCode == 0;
}

bool ApplyLockScreenViaWindowsApi(PCWSTR imagePath) {
    if (!imagePath || !*imagePath || !FileExists(imagePath)) {
        return false;
    }

    std::wstring scriptPath;
    if (!EnsureApplyScript(&scriptPath)) {
        Wh_Log(L"Failed to write lock screen helper script");
        return false;
    }

    if (RunPowerShellScript(scriptPath.c_str(), imagePath, false)) {
        Wh_Log(L"Windows lock screen API succeeded for %s", imagePath);
        return true;
    }

    Wh_Log(L"Windows lock screen API failed for %s", imagePath);
    return false;
}

bool ApplyElevatedPolicyFix(PCWSTR sourcePath, PCWSTR stagedPath) {
    if (!sourcePath || !stagedPath) {
        return false;
    }

    std::wstring scriptPath;
    if (!EnsureAdminApplyScript(&scriptPath)) {
        Wh_Log(L"Failed to write elevated lock screen helper script");
        return false;
    }

    Wh_Log(L"Running elevated policy fix for %s", stagedPath);
    if (!RunPowerShellScript(scriptPath.c_str(), stagedPath, true)) {
        Wh_Log(L"Elevated policy fix failed");
        return false;
    }

    WriteElevatedMarker(BuildSourceVersionStamp(sourcePath).c_str());
    Wh_Log(L"Elevated policy fix succeeded");
    return true;
}

bool ApplyLockScreenWallpaper(bool force) {
    if (!g_settings.enabled) {
        return true;
    }

    const std::wstring sourcePath = ResolveSourcePath();
    if (sourcePath.empty()) {
        Wh_Log(L"No valid lock screen image configured");
        return false;
    }

    const std::wstring registryPath =
        StageLockScreenImage(sourcePath.c_str(), false);
    if (registryPath.empty()) {
        return false;
    }

    const bool inExplorer = g_isExplorerProcess.load();
    if (!inExplorer) {
        force = true;
    }

    if (!force &&
        !LockScreenNeedsReapply(sourcePath.c_str(), registryPath.c_str())) {
        Wh_Log(L"Lock screen wallpaper already correct");
        return true;
    }

    Wh_Log(L"Applying lock screen wallpaper (force=%d, explorer=%d): %s", force,
           inExplorer, registryPath.c_str());

    DisableLockScreenSpotlight();
    ApplyDesktopLockScreenKeys();
    CopyToSystemDataCache(registryPath.c_str(), sourcePath.c_str());
    ApplyCreativeRegistryKeys(registryPath.c_str());
    ApplyPersonalizationCspKeys(registryPath.c_str());
    ApplyLogonUiCreativeKeys(registryPath.c_str());
    ApplySignInScreenSyncKeys(registryPath.c_str());

    if (inExplorer) {
        const std::wstring apiPath =
            StageLockScreenImage(sourcePath.c_str(), true);
        const PCWSTR winRtPath =
            !apiPath.empty() ? apiPath.c_str() : registryPath.c_str();
        const bool winRtOk = ApplyLockScreenViaWindowsApi(winRtPath);

        if (!winRtOk ||
            ShouldRunElevatedPolicyFix(sourcePath.c_str(), registryPath.c_str())) {
            ApplyElevatedPolicyFix(sourcePath.c_str(), registryPath.c_str());
        }

        RestartLockAppIfUnlocked();
    }

    NotifyPersonalizationChanged();
    Wh_Log(L"Lock screen apply finished");
    return true;
}

void SafeApplyLockScreen(bool force) {
    EnterCriticalSection(&g_applyLock);
    ApplyLockScreenWallpaper(force);
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
    ofn.lpstrTitle = L"Choose lock screen image";

    if (!GetOpenFileNameW(&ofn)) {
        return false;
    }

    *outPath = fileBuffer;
    return true;
}

BOOL CALLBACK SetPickerChildFontProc(HWND child, LPARAM fontParam) {
    SendMessageW(child, WM_SETFONT, fontParam, TRUE);
    return TRUE;
}

LRESULT CALLBACK PickerWndProc(HWND hWnd, UINT msg, WPARAM wParam,
                               LPARAM lParam) {
    switch (msg) {
        case WM_CREATE: {
            HFONT font = CreateFontW(
                -14, 0, 0, 0, FW_NORMAL, FALSE, FALSE, FALSE, DEFAULT_CHARSET,
                OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS, CLEARTYPE_QUALITY,
                DEFAULT_PITCH | FF_DONTCARE, L"Segoe UI");

            CreateWindowExW(0, L"STATIC", L"Lock screen image:",
                            WS_CHILD | WS_VISIBLE, 16, 20, 120, 22, hWnd,
                            nullptr, nullptr, nullptr);

            HWND hEdit = CreateWindowExW(
                WS_EX_CLIENTEDGE, L"EDIT", L"",
                WS_CHILD | WS_VISIBLE | ES_AUTOHSCROLL, 140, 18, 300, 24, hWnd,
                (HMENU)2001, nullptr, nullptr);

            CreateWindowExW(0, L"BUTTON", L"Browse...",
                            WS_CHILD | WS_VISIBLE | BS_PUSHBUTTON, 450, 18, 90,
                            24, hWnd, (HMENU)3001, nullptr, nullptr);

            CreateWindowExW(0, L"BUTTON", L"Save & Apply",
                            WS_CHILD | WS_VISIBLE | BS_DEFPUSHBUTTON, 300, 60,
                            120, 28, hWnd, (HMENU)1001, nullptr, nullptr);
            CreateWindowExW(0, L"BUTTON", L"Cancel", WS_CHILD | WS_VISIBLE, 430,
                            60, 90, 28, hWnd, (HMENU)1002, nullptr, nullptr);

            const std::wstring currentPath =
                LoadWallpaperSetting(L"lockScreenWallpaper");
            if (!currentPath.empty() && hEdit) {
                SetWindowTextW(hEdit, currentPath.c_str());
            }

            SetWindowLongPtrW(hWnd, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(hEdit));

            if (font) {
                EnumChildWindows(hWnd, SetPickerChildFontProc,
                                 reinterpret_cast<LPARAM>(font));
            }
            return 0;
        }

        case WM_COMMAND: {
            HWND hEdit = reinterpret_cast<HWND>(
                GetWindowLongPtrW(hWnd, GWLP_USERDATA));

            const int id = LOWORD(wParam);
            if (id == 3001 && hEdit) {
                std::wstring path;
                if (BrowseForImageFile(hWnd, &path)) {
                    SetWindowTextW(hEdit, path.c_str());
                }
                return 0;
            }

            if (id == 1001 && hEdit) {
                const int length = GetWindowTextLengthW(hEdit);
                std::wstring path(length, L'\0');
                if (length > 0) {
                    GetWindowTextW(hEdit, path.data(), length + 1);
                }
                SaveWallpaperPath(L"lockScreenWallpaper", path);
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
            g_pickerDialogOpen.store(false);
            return 0;
    }

    return DefWindowProcW(hWnd, msg, wParam, lParam);
}

void StartWallpaperPickerDialog() {
    if (g_pickerDialogOpen.exchange(true)) {
        return;
    }

    WNDCLASSEXW wc{};
    wc.cbSize = sizeof(wc);
    wc.lpfnWndProc = PickerWndProc;
    wc.hInstance = GetModuleHandleW(nullptr);
    wc.hCursor = LoadCursorW(nullptr, IDC_ARROW);
    wc.hbrBackground = reinterpret_cast<HBRUSH>(COLOR_WINDOW + 1);
    wc.lpszClassName = kPickerWindowClass;
    RegisterClassExW(&wc);

    HWND hWnd = CreateWindowExW(
        WS_EX_DLGMODALFRAME | WS_EX_TOPMOST, kPickerWindowClass,
        L"Lock Screen Wallpaper", WS_OVERLAPPED | WS_CAPTION | WS_SYSMENU,
        CW_USEDEFAULT, CW_USEDEFAULT, 560, 130, nullptr, nullptr,
        wc.hInstance, nullptr);

    if (!hWnd) {
        g_pickerDialogOpen.store(false);
        return;
    }

    ShowWindow(hWnd, SW_SHOW);
    UpdateWindow(hWnd);
}

LRESULT CALLBACK NotifyWndProc(HWND hWnd, UINT msg, WPARAM wParam,
                               LPARAM lParam) {
    switch (msg) {
        case WM_WTSSESSION_CHANGE:
            if (wParam == WTS_SESSION_UNLOCK || wParam == WTS_SESSION_LOGON) {
                Wh_Log(L"Session change (%u), re-applying lock screen", wParam);
                RequestApply(true);
            }
            return 0;

        case WM_DESTROY:
            WTSUnRegisterSessionNotification(hWnd);
            return 0;
    }

    return DefWindowProcW(hWnd, msg, wParam, lParam);
}

void CreateNotifyWindow() {
    if (g_notifyWnd) {
        return;
    }

    WNDCLASSEXW wc{};
    wc.cbSize = sizeof(wc);
    wc.lpfnWndProc = NotifyWndProc;
    wc.hInstance = GetModuleHandleW(nullptr);
    wc.lpszClassName = kNotifyWindowClass;
    RegisterClassExW(&wc);

    g_notifyWnd =
        CreateWindowExW(0, kNotifyWindowClass, L"", 0, 0, 0, 0, 0,
                        HWND_MESSAGE, nullptr, wc.hInstance, nullptr);
    if (g_notifyWnd) {
        WTSRegisterSessionNotification(g_notifyWnd, NOTIFY_FOR_THIS_SESSION);
    }
}

void DestroyNotifyWindow() {
    if (!g_notifyWnd) {
        return;
    }

    DestroyWindow(g_notifyWnd);
    g_notifyWnd = nullptr;
}

void LoadSettings() {
    g_settings.enabled = Wh_GetIntSetting(L"enabled");
    g_settings.disableSpotlight = Wh_GetIntSetting(L"disableSpotlight");
    g_settings.copyToSystemData = Wh_GetIntSetting(L"copyToSystemData");
    g_settings.checkIntervalSeconds =
        Wh_GetIntSetting(L"checkIntervalSeconds");
    if (g_settings.checkIntervalSeconds < 5) {
        g_settings.checkIntervalSeconds = 5;
    }

    Wh_Log(L"Loaded settings: enabled=%d, spotlightOff=%d, systemData=%d, "
           L"interval=%ds",
           g_settings.enabled, g_settings.disableSpotlight,
           g_settings.copyToSystemData, g_settings.checkIntervalSeconds);
}

DWORD WINAPI WorkerThreadProc(LPVOID) {
    Wh_Log(L"Worker thread started");

    const int startupDelaysMs[] = {0, 2000, 5000, 15000, 30000, 60000, 120000};
    for (int delayMs : startupDelaysMs) {
        if (g_unloading) {
            break;
        }

        if (delayMs > 0) {
            const DWORD waitResult =
                WaitForSingleObject(g_wakeEvent, static_cast<DWORD>(delayMs));
            if (g_unloading) {
                break;
            }
            if (waitResult == WAIT_OBJECT_0) {
                g_applyPending.exchange(false);
            }
        }

        SafeApplyLockScreen(true);
    }

    while (!g_unloading) {
        const DWORD waitMs =
            static_cast<DWORD>(std::max(5, g_settings.checkIntervalSeconds)) *
            1000;
        const DWORD waitResult = WaitForSingleObject(g_wakeEvent, waitMs);

        if (g_unloading) {
            break;
        }

        const bool force = g_applyPending.exchange(false);
        SafeApplyLockScreen(force || waitResult == WAIT_OBJECT_0);
    }

    Wh_Log(L"Worker thread stopped");
    return 0;
}

void StartMonitoring() {
    if (g_workerThread) {
        return;
    }

    CreateNotifyWindow();

    g_wakeEvent = CreateEventW(nullptr, FALSE, FALSE, nullptr);
    if (!g_wakeEvent) {
        Wh_Log(L"Failed to create wake event");
        DestroyNotifyWindow();
        return;
    }

    g_workerThread = CreateThread(nullptr, 0, WorkerThreadProc, nullptr, 0,
                                  nullptr);
    if (!g_workerThread) {
        Wh_Log(L"Failed to create worker thread: %u", GetLastError());
        CloseHandle(g_wakeEvent);
        g_wakeEvent = nullptr;
        DestroyNotifyWindow();
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

    DestroyNotifyWindow();
}

}  // namespace

BOOL Wh_ModInit() {
    g_isExplorerProcess.store(IsExplorerProcess());
    Wh_Log(L"Init in %s", g_isExplorerProcess.load() ? L"explorer.exe"
                                                     : L"LogonUI.exe");
    InitializeCriticalSection(&g_applyLock);
    LoadSettings();
    return TRUE;
}

void Wh_ModAfterInit() {
    Wh_Log(L"AfterInit");
    SafeApplyLockScreen(true);

    if (g_isExplorerProcess.load()) {
        StartMonitoring();
    }
}

void Wh_ModUninit() {
    Wh_Log(L"Uninit");
    if (g_isExplorerProcess.load()) {
        StopMonitoring();
    }
    DeleteCriticalSection(&g_applyLock);
}

BOOL Wh_ModSettingsChanged(BOOL* bReload) {
    Wh_Log(L"SettingsChanged");

    if (!g_isExplorerProcess.load()) {
        *bReload = FALSE;
        return TRUE;
    }

    const bool openPicker = Wh_GetIntSetting(L"openImageBrowser") != 0;
    LoadSettings();

    if (openPicker) {
        StartWallpaperPickerDialog();
    }

    RequestApply(true);
    *bReload = FALSE;
    return TRUE;
}
