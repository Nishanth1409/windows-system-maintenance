// System Maintenance - keep the desktop menu icons this toolkit installs.
//
// Nilesoft Shell draws the desktop context menu itself. It ships a built-in
// "@nvidia" glyph (see imports/images.nss) that it applies to any menu item
// titled exactly "NVIDIA". That substitution wins over the Icon value under
// HKCR\DesktopBackground\Shell\Perz_02_NVIDIA, and because the glyph is filled
// with the theme colours it renders white/blue instead of NVIDIA green. The
// submenu items are unaffected because their titles do not match the glyph
// name. Pinning the image here restores the extracted icon.
//
// find= only narrows to titles containing NVIDIA as a whole word, which also
// covers "NVIDIA App" and "NVIDIA Control Panel", so the where= clause pins the
// rule to the parent item alone. Without it the Control Panel entry would be
// given the NVIDIA App icon.
//
// The folder in the image path is only a placeholder. Install_Menu.bat rewrites
// it to wherever this toolkit actually lives via
// scripts\Install_NilesoftMenuIcons.ps1, so change the icon file name here
// rather than the folder in front of it.

modify(find='"NVIDIA"'
	where=str.equals(this.name, 'NVIDIA')
	image='C:\SystemMaintenance\icons\nvidia_app.ico')
