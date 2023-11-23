definition module menus;

import mac_types;

//	Initialization and Allocation

NewMenu :: !Int !{#Char} !*Toolbox -> (!MacMenuHandle, !*Toolbox);
DisposeMenu :: !MacMenuHandle !*Toolbox -> *Toolbox;

//	Forming the menus

AppendMenu :: !MacMenuHandle !{#Char} !*Toolbox -> *Toolbox;
AddResMenu :: !MacMenuHandle !Int !*Toolbox -> *Toolbox;

//	Forming the Menu Bar

InsertMenu :: !MacMenuHandle !Int !*Toolbox -> *Toolbox;
ClearMenuBar :: !*Toolbox -> *Toolbox;
DrawMenuBar :: !*Toolbox -> *Toolbox;
DeleteMenu :: !Int !*Toolbox -> *Toolbox;
CalcMenuSize :: !MacMenuHandle !*Toolbox -> *Toolbox;
GetMHandle :: !Int !*Toolbox -> (!MacMenuHandle, !*Toolbox);
GetMenuBar :: !*Toolbox -> (!Handle, !*Toolbox);
SetMenuBar :: !Handle !*Toolbox -> *Toolbox;
InsMenuItem :: !MacMenuHandle !{#Char} !Int !*Toolbox -> *Toolbox;
DelMenuItem :: !MacMenuHandle !Int !*Toolbox -> *Toolbox;

//	Choosing From a Menu

MenuSelect :: !Int !Int !*Toolbox -> (!Int,!Int,!*Toolbox);
MenuKey :: !Int !*Toolbox -> (!Int,!Int,!*Toolbox);
HiliteMenu :: !Int !*Toolbox -> *Toolbox;
PopUpMenuSelect :: !MacMenuHandle !Int !Int !Int !*Toolbox -> (!Int,!Int,!*Toolbox);

//	Controlling the Appearance of Items

SetItem :: !MacMenuHandle !Int !{#Char} !*Toolbox -> *Toolbox;
GetItem :: !MacMenuHandle !Int !{#Char} !*Toolbox -> (!{#Char},!*Toolbox);
DisableItem :: !MacMenuHandle !Int !*Toolbox -> *Toolbox;
EnableItem :: !MacMenuHandle !Int !*Toolbox -> *Toolbox;
CheckItem :: !MacMenuHandle !Int !Bool !*Toolbox -> *Toolbox;

//	Miscellaneous Routines

CountMenuItems :: !MacMenuHandle !*Toolbox -> (!Int,!*Toolbox);
