// System Maintenance - keep the desktop menu icons this toolkit installs.
//
// Nilesoft Shell draws the desktop context menu itself. Built-in glyphs
// (imports/images.nss) win over HKCR Icon values and are filled with theme
// colours. The "@nvidia" glyph is the known bad case (white/blue instead of
// NVIDIA green). The same pin pattern is applied to every custom menu title
// we own so dll/.ico icons stay correct on any PC with Nilesoft installed.
//
// Each rule uses where=str.equals(this.name, '...') so find= does not spill
// onto similarly named submenu items (e.g. NVIDIA vs NVIDIA Control Panel).
// Desktop-scoped rules use window.is_desktop so Restart/Sleep/Shut down in
// other folders are left alone.
//
// The folder in each image path is only a placeholder. Install_Menu.bat
// rewrites it via scripts\Install_NilesoftMenuIcons.ps1.

// --- Top-level custom items ---
modify(find='"Installed Apps"'
	where=window.is_desktop and str.equals(this.name, 'Installed Apps')
	image='C:\SystemMaintenance\icons\menu_apps.ico')

modify(find='"NVIDIA"'
	where=window.is_desktop and str.equals(this.name, 'NVIDIA')
	image='C:\SystemMaintenance\icons\nvidia_app.ico')

modify(find='"System Maintenance"'
	where=window.is_desktop and str.equals(this.name, 'System Maintenance')
	image='C:\SystemMaintenance\icons\menu_maintenance.ico')

modify(find='"Power"'
	where=window.is_desktop and str.equals(this.name, 'Power')
	image='C:\SystemMaintenance\icons\menu_power.ico')

// --- NVIDIA submenu (exact titles) ---
modify(find='"NVIDIA App"'
	where=window.is_desktop and str.equals(this.name, 'NVIDIA App')
	image='C:\SystemMaintenance\icons\nvidia_app.ico')

modify(find='"NVIDIA Control Panel"'
	where=window.is_desktop and str.equals(this.name, 'NVIDIA Control Panel')
	image='C:\SystemMaintenance\icons\nvidia_controlpanel.ico')

// --- Power submenu ---
modify(find='"Restart"'
	where=window.is_desktop and str.equals(this.name, 'Restart')
	image='C:\SystemMaintenance\icons\menu_restart.ico')

modify(find='"Sleep"'
	where=window.is_desktop and str.equals(this.name, 'Sleep')
	image='C:\SystemMaintenance\icons\menu_sleep.ico')

modify(find='"Shut down"'
	where=window.is_desktop and str.equals(this.name, 'Shut down')
	image='C:\SystemMaintenance\icons\menu_shutdown.ico')
