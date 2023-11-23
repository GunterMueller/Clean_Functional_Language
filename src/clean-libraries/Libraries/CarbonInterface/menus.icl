implementation module menus;

import mac_types;

//	Initialization and Allocation

NewMenu :: !Int !{#Char} !*Toolbox -> (!MacMenuHandle,!*Toolbox);
NewMenu menuID menuTitle t = code (menuID=D0,menuTitle=SD1,t=U)(newMenuHandle=D0,z=Z){
	call	.NewMenu
};

DisposeMenu :: !MacMenuHandle !*Toolbox -> *Toolbox;
DisposeMenu theMenu t = code (theMenu=D0,t=U)(z=Z){
	call	.DisposeMenu
};

//	Forming the menus

AppendMenu :: !MacMenuHandle !{#Char} !*Toolbox -> *Toolbox;
AppendMenu theMenu data t = code (theMenu=D0,data=SD1,t=U)(z=Z){
	call	.AppendMenu
};

AddResMenu :: !MacMenuHandle !Int !*Toolbox -> *Toolbox;
AddResMenu theMenu theType t = code (theMenu=D0,theType=D1,t=U)(z=Z){
	call	.AppendResMenu
};

//	Forming the Menu Bar

InsertMenu :: !MacMenuHandle !Int !*Toolbox -> *Toolbox;
InsertMenu theMenu beforeID t = code (theMenu=D0,beforeID=D1,t=U)(z=Z){
	call	.InsertMenu
};

ClearMenuBar :: !*Toolbox -> *Toolbox;
ClearMenuBar t = code (t=U)(z=Z){
	call	.ClearMenuBar
};

import StdMisc;

DrawMenuBar :: !*Toolbox -> *Toolbox;
DrawMenuBar t = code (t=U)(z=Z){
	call	.DrawMenuBar
};

DeleteMenu :: !Int !*Toolbox -> *Toolbox;
DeleteMenu menuID t = code (menuID=D0,t=U)(z=Z){
	call	.DeleteMenu
};

CalcMenuSize :: !MacMenuHandle !*Toolbox -> *Toolbox;
CalcMenuSize theMenu t = code (theMenu=D0,t=U)(z=Z){
	call	.CalcMenuSize
};

GetMHandle :: !Int !*Toolbox -> (!MacMenuHandle,!*Toolbox);
GetMHandle menuID t = code (menuID=D0,t=U)(menu_handle=D0,z=Z){
	call	.GetMenuHandle
};

GetMenuBar :: !*Toolbox -> (!Handle,!*Toolbox);
GetMenuBar t = code (t=U)(menu_list=D0,z=Z){
	call	.GetMenuBar
};

SetMenuBar :: !Handle !*Toolbox -> *Toolbox;
SetMenuBar menu_list t = code (menu_list=D0,t=U)(z=Z){
	call	.SetMenuBar
};

InsMenuItem :: !MacMenuHandle !{#Char} !Int !*Toolbox -> *Toolbox;
InsMenuItem theMenu itemString afterItem t = code (theMenu=D0,itemString=SD1,afterItem=D2,t=U)(z=Z){
	call	.InsertMenuItem
};

DelMenuItem :: !MacMenuHandle !Int !*Toolbox -> *Toolbox;
DelMenuItem theMenu item t = code (theMenu=D0,item=D1,t=U)(z=Z){
	call	.DeleteMenuItem
};

//	Choosing From a Menu

MenuSelect :: !Int !Int !*Toolbox -> (!Int,!Int,!*Toolbox);
MenuSelect h v t = code (h=D0,v=A0,t=U)(menu_ID=D1,menu_item=D0,z=Z){
	instruction 0x52E3801E	| rlwimi	r3,r23,16,0,15
	call	.MenuSelect
	instruction	0x5464843E	| srwi		r4,r3,16
	instruction 0x7063FFFF	| andi.		r3,r3,65535
};

MenuKey :: !Int !*Toolbox -> (!Int,!Int,!*Toolbox);
MenuKey char t = code (char=D0,t=U)(menu_ID=D1,menu_item=D0,z=Z){
	call	.MenuKey
	instruction	0x5464843E	| srwi	r4,r3,16
	instruction 0x7063FFFF	| andi.	r3,r3,65535
};

HiliteMenu :: !Int !*Toolbox -> *Toolbox;
HiliteMenu menuID t = code (menuID=D0,t=U)(z=Z){
	call	.HiliteMenu
};

PopUpMenuSelect :: !MacMenuHandle !Int !Int !Int !*Toolbox -> (!Int,!Int,!*Toolbox);
PopUpMenuSelect menu top left popUpItem t
= code (menu=D0,top=D1,left=D2,popUpItem=D3,t=U)(menu_ID=D1,menu_item=D0,z=Z){
	call	.PopUpMenuSelect
	instruction	0x5464843E	| srwi	r4,r3,16
	instruction 0x7063FFFF	| andi.	r3,r3,65535
};

//	Controlling the Appearance of Items

SetItem :: !MacMenuHandle !Int !{#Char} !*Toolbox -> *Toolbox;
SetItem theMenu item itemString t = code (theMenu=D0,item=D1,itemString=SD2)(z=Z){
	call	.SetMenuItemText
};

GetItem :: !MacMenuHandle !Int !{#Char} !*Toolbox -> (!{#Char},!*Toolbox);
GetItem theMenu item s tb = (GetItem1 theMenu item s tb, NewToolbox);

GetItem1 :: !MacMenuHandle !Int !{#Char} !*Toolbox -> {#Char};
GetItem1 theMenu item s t = code (theMenu=D0,item=D1,s=U,t=U)(itemString=A0){
	instruction 0x3AA00000	|	li		r21,0
	instruction 0x92B70004	|	stw		r21,4(r23)
	instruction 0x38B70007	|	addi	r5,r23,7
	call	.GetMenuItemText
};

DisableItem :: !MacMenuHandle !Int !*Toolbox -> *Toolbox;
DisableItem theMenu item t = code (theMenu=D0,item=D1,t=U)(z=Z){
	call	.DisableMenuItem
};

EnableItem :: !MacMenuHandle !Int !*Toolbox -> *Toolbox;
EnableItem theMenu item t = code (theMenu=D0,item=D1,t=U)(z=Z){
	call	.EnableMenuItem
};

CheckItem :: !MacMenuHandle !Int !Bool !*Toolbox -> *Toolbox;
CheckItem theMenu item checked t = code (theMenu=D0,item=D1,checked=D2,t=U)(z=Z){
	call	.CheckMenuItem
};

//	Miscellaneous Routines

CountMenuItems :: !MacMenuHandle !*Toolbox -> (!Int,!*Toolbox);
CountMenuItems theMenu tb = code (theMenu=D0,tb=U)(count=D0,z=Z){
	call	.CountMenuItems
};
