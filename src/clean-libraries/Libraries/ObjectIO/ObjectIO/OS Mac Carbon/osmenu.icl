implementation module osmenu

import StdMisc, StdArray, StdEnum, StdList, StdBool
import ostoolbox, osdocumentinterface
import menus
from memory		import DisposHandle
from commondef	import removeSpecialChars
//import menuhandle
from events		import GetMouse, StillDown, GetKeys
from quickdraw	import QLocalToGlobal
from osutil		import KeyMapToModifiers

//--

//import StdDebug
//import dodebug
trace_n _ t :== t

//--

osInitialiseMenus :: !*OSToolbox -> *OSToolbox
osInitialiseMenus tb = tb

:: OSMenu					:== Int		// was MacMenuHandle
:: OSMenuItem				:== Int		// was ItemLS ??
:: OSMenuSeparator			:== Int		// was SepLS ??

:: OSMenuNr					:== Int		// was MacId??
:: OSSubMenuNr				:== Int		// was SubMacId ??
/* dummy's to keep imports happy... */
/*	PA: not required anymore.
:: HMENU	:== Int
:: HITEM	:== Int
:: HWND		:== Int
*/

//	Dummy values:

OSNoMenu			:== 0
OSNoMenuItem		:== 0
OSNoMenuSeparator	:== 0

//	Menu functions:

osDisableMenu :: !Int !OSMenuBar !*OSToolbox -> *OSToolbox
osDisableMenu zIndex osMenuBar tb
	// special case for zIndex 0 nl disable first item of AppleMenu???
	| zIndex == 0
		# (menuHandle,tb)	= GetMHandle AppleMenuId tb
		# tb				= trace_n ("osDisableMenu",zIndex,AppleMenuId,menuHandle) tb
		= DisableItem menuHandle 1 tb
	# zIndex = zIndex - 1

	# menuID			= mb_lookup zIndex osMenuBar
	# (menuHandle,tb)	= GetMHandle menuID tb
	# tb				= trace_n ("osDisableMenu",zIndex,menuID,menuHandle) tb
	= DisableItem menuHandle 0 tb

osEnableMenu :: !Int !OSMenuBar !*OSToolbox -> *OSToolbox
osEnableMenu zIndex osMenuBar tb
	// special case for zIndex 0 nl enable first item of AppleMenu???
	| zIndex == 0
		# (menuHandle,tb)	= GetMHandle AppleMenuId tb
		# tb				= trace_n ("osEnableMenu",zIndex,AppleMenuId,menuHandle) tb
		= EnableItem menuHandle 1 tb
	# zIndex = zIndex - 1

	# menuID			= mb_lookup zIndex osMenuBar
	# (menuHandle,tb)	= GetMHandle menuID tb
	# tb				= trace_n ("osEnableMenu",zIndex,menuID,menuHandle) tb
	= EnableItem menuHandle 0 tb


osDisableMenuItem :: !OSMenu !OSMenuItem !Int !*OSToolbox -> *OSToolbox
osDisableMenuItem menuHandle menuItem index tb
//	= DisableItem menuHandle index tb
	# (err,tb)			= ChangeMenuItemAttributes menuHandle index kMenuItemAttrDisabled 0 tb
	# tb				= trace_n ("osDisableMenuItem",menuItem,menuHandle,err) tb
	= tb

osEnableMenuItem :: !OSMenu !OSMenuItem !Int !*OSToolbox -> *OSToolbox
osEnableMenuItem menuHandle menuItem index tb
//	= EnableItem menuHandle index tb
	# (err,tb)			= ChangeMenuItemAttributes menuHandle index 0 kMenuItemAttrDisabled tb
	# tb				= trace_n ("osEnableMenuItem:",menuItem,menuHandle) tb
	= tb


osDisableSubMenu :: !OSMenu !OSMenuItem !Int !*OSToolbox -> *OSToolbox
osDisableSubMenu menuHandle menuItem index tb
	# tb				= trace_n ("osDisableSubMenu",menuHandle,index) tb
	= DisableItem menuHandle index tb

osEnableSubMenu :: !OSMenu !OSMenuItem !Int !*OSToolbox -> *OSToolbox
osEnableSubMenu menuHandle menuItem index tb
	# tb				= trace_n ("osEnableSubMenu",menuHandle,index) tb
	= EnableItem menuHandle index tb


osDrawMenuBar :: !OSMenuBar !*OSToolbox -> *OSToolbox
osDrawMenuBar {mbHandle} tb
	# tb				= trace_n ("osDrawMenuBar",mbHandle) tb
//	# tb				= SetMenuBar mbHandle tb				// DvA: necessary?
	= DrawMenuBar tb											// DvA: replace by InvalMenuBar?

osMenuBarClear :: !*OSToolbox -> *OSToolbox
osMenuBarClear tb
	# tb				= trace_n ("osMenuBarClear") tb
	= DrawMenuBar (ClearMenuBar tb)
/*
	# (menuBar,tb)	= GetMenuBar tb
	| mMList==0
	= ({menus & mMList=menuBar}, tb)
	= ({menus & mMList=menuBar}, snd (DisposHandle mMList tb))
*/

osMenuBarSet :: !OSMenuBar !*OSToolbox -> (!OSMenuBar,!*OSToolbox)
osMenuBarSet mbar=:{mbHandle} tb
	# tb				= trace_n ("osMenuBarSet",mbHandle) tb
	# tb				= SetMenuBar mbHandle tb
	# tb				= DrawMenuBar tb						// necessary?
	= (mbar,tb)													// DvA: ???

osMenuInsert :: !Int !OSMenuNr !{#Char} !OSMenuBar !*OSToolbox -> (!OSMenu,!OSMenuBar,!*OSToolbox)
osMenuInsert zIndex osMenuNr title menuBar=:{mbHandle} tb
	# title				= validateMenuTitle title
	# (menuHandle,tb)	= NewMenu osMenuNr title tb
	# beforeId			= mb_lookup zIndex menuBar
	# tb				= InsertMenu menuHandle beforeId tb
	# menuBar			= mb_insert zIndex osMenuNr menuBar
	# (_,tb)			= DisposHandle mbHandle tb
	# (mbHandle,tb)		= GetMenuBar tb
	# tb				= trace_n ("osMenuInsert",zIndex,osMenuNr,mbHandle,menuHandle) tb
	= (menuHandle,{menuBar & mbHandle = mbHandle},tb)

osSubMenuInsert :: !Int !OSMenuNr !{#Char} !OSMenu !*OSToolbox -> (!OSMenu,!OSMenu,!*OSToolbox)
osSubMenuInsert index osMenuNr title parentMenu tb
	# title				= validateMenuItemTitle title
	# data				= subMenuHandleToMacElement osMenuNr enabled title
	# (menuHandle,tb)	= NewMenu osMenuNr title tb
//	# tb				= EnableItem menuHandle 0 tb			// DvA: unnecessary?
	# tb				= InsertMenu menuHandle beforeId tb
	# tb				= AppendMenu parentMenu data tb
//	# tb				= SetItem parentMenu (index+1) title tb
	# tb				= trace_n ("osSubMenuInsert",osMenuNr,index,parentMenu,menuHandle) tb
	= (menuHandle,parentMenu,tb)
where
	beforeId	= -1
	enabled		= True											// DvA: ???

subMenuHandleToMacElement id enabled title
	| enabled
	= submenu_id+++title
	= submenu_id+++title+++disable
where
	submenu_id	= submenu+++menu_id
	submenu		= "/"+++toString (toChar 27)			// /$1B this item is a SubMenu
	menu_id		= "!"+++toString (toChar id)			// !id = menu defining the SubMenu
	disable		= "("


osMenuRemove :: !OSMenu !OSMenuBar !*OSToolbox -> (!OSMenuBar,!*OSToolbox)
osMenuRemove menuHandle menuBar=:{mbHandle} tb
	# (menuId,tb)		= GetMenuID menuHandle tb
	# tb				= DeleteMenu menuId tb
	# tb				= DisposeMenu menuHandle tb
	# menuBar			= mb_remove menuId menuBar
	# tb				= trace_n ("osMenuRemove",menuId,mbHandle,menuHandle) tb
	# (_,tb)			= DisposHandle mbHandle tb
	# (mbHandle,tb)		= GetMenuBar tb
	= ({menuBar & mbHandle = mbHandle},tb)

osSubMenuRemove :: !OSMenu !OSMenu !Int !Int !*OSToolbox -> (!OSMenu, !*OSToolbox)
osSubMenuRemove submenuHandle hmenu submenuId index tb
	# tb				= DeleteMenu  submenuId  tb
	# tb				= trace_n ("osSubMenuRemove",submenuHandle,submenuId,hmenu,index) tb
	# tb				= DisposeMenu submenuHandle tb
	# tb				= DelMenuItem hmenu index tb			// DvA: also needed???
	= (hmenu,tb)

osRemoveMenuShortKey :: !OSWindowPtr !OSMenuItem !*OSToolbox -> *OSToolbox
osRemoveMenuShortKey _ _ tb
	= tb

osAppendMenuItem :: !OSMenuBar !Int !OSMenu !{#Char} !Bool !Bool !Char !*OSToolbox -> (!OSMenuItem,!OSMenu,!*OSToolbox)
osAppendMenuItem menuBar index menu title able mark key tb
	# tb				= trace_n ("osAppendMenuItem",menu,index) tb
	# title				= validateMenuItemTitle title
	# data				= menuItemHandleToMacElement key able mark
	# tb				= InsMenuItem menu data index tb
	# (count,tb)		= CountMenuItems menu tb
	# index`			= determine_index index count
	# tb				= SetItem menu index` title tb
	# (err,tb) = case key of
			'X'	-> SetMenuItemCommandID menu index` kHICommandCut tb
			'C'	-> SetMenuItemCommandID menu index` kHICommandCopy tb
			'V'	-> SetMenuItemCommandID menu index` kHICommandPaste tb
			_	-> (0,tb)
	= (index`,menu,tb)
where
	determine_index 0 _ = 1
	determine_index i m
		| i >= m = m
		= i+1

kHICommandCut                 = "cut "
kHICommandCopy                = "copy"
kHICommandPaste               = "past"

SetMenuItemCommandID :: !OSMenu !Int !String !*OSToolbox -> (!Int,!*OSToolbox)
SetMenuItemCommandID menu index tag tb
	# iTag	= ((toInt tag.[0]) << 24) bitor ((toInt tag.[1]) << 16) bitor ((toInt tag.[2]) << 8) bitor ((toInt tag.[3]) << 0)
	= SetMenuItemCommandID menu index iTag tb
where
	SetMenuItemCommandID :: !OSMenu !Int !Int !*OSToolbox -> (!Int,!*OSToolbox)
	SetMenuItemCommandID _ _ _ _ = code {
		ccall SetMenuItemCommandID "PIII:I:I"
		}

menuItemHandleToMacElement key able checked
	| not hasKey && checked && able	= s+++check
	| not hasKey && checked			= s+++disable+++check
	| not hasKey && able			= s
	| not hasKey					= s+++disable
	| not checked && able			= s+++shortcut
	| checked     && able			= s+++check  +++shortcut
	| not checked					= s+++disable+++shortcut
	| otherwise						= s+++disable+++check+++shortcut
where
	s								= "D"
	disable							= "("
	check							= "!" +++ toString (toChar 18)
	shortcut						= keyToShortcut key
	hasKey							= key <> '\0'
	keyToShortcut c
		| c>='a' && c<='z'
		= "/"+++toString (toChar (toInt 'A'+(toInt c-toInt 'a')))
		= "/"+++toString c


osAppendMenuSeparator :: !Int !OSMenu !*OSToolbox -> (!OSMenuSeparator,!OSMenu,!*OSToolbox)
osAppendMenuSeparator index menu tb
	# tb				= trace_n ("osAppendMenuSeparator",menu,index) tb
	# (title,data)		= MenuSeparatorMacElement
	# tb				= InsMenuItem menu data index tb
	# (count,tb)		= CountMenuItems menu tb
	# index`			= determine_index index count
	# tb				= SetItem menu index` title tb
	= (index`,menu,tb)
where
	determine_index 0 _ = 1
	determine_index i m
		| i >= m = m
		= i+1
	
	MenuSeparatorMacElement = ("-", "-(")


osChangeMenuTitle :: !OSMenuBar !OSMenu !{#Char} !*OSToolbox -> *OSToolbox
osChangeMenuTitle menuBar menuHandle title tb
	# (err,tb)			= SetMenuTitle menuHandle title tb
	= tb

osChangeMenuItemTitle :: !OSMenu !OSMenuItem !Int !{#Char} !*OSToolbox -> *OSToolbox
osChangeMenuItemTitle menu item index title tb
	# tb				= trace_n ("osChangeMenuItemTitle",menu,item,title) tb
	= SetItem menu index title tb							// validateMenuItemTitle?

osMenuItemCheck :: !Bool !OSMenu !OSMenuItem !Int !Int !*OSToolbox -> *OSToolbox
osMenuItemCheck check menu item index zIndex tb
	# tb				= trace_n ("osMenuItemCheck",check,menu,item,index,zIndex) tb
	= CheckItem menu zIndex check tb

osMenuRemoveItem :: !OSMenuItem !Int !OSMenu !*OSToolbox -> (!OSMenu,!*OSToolbox)
osMenuRemoveItem item index menu tb
	# tb				= trace_n ("osMenuRemoveItem",menu,index) tb
	# tb				= DelMenuItem menu index tb
	= (menu,tb)

//--

osValidateMenuItemTitle :: !(Maybe Char) !{#Char} -> {#Char}	// PA: function now includes short key; ignore on Mac
osValidateMenuItemTitle _ title
	= validateMenuItemTitle title

/*
	validateMenu(Item)Title transforms the ItemTitle:
		""					-> " "
		"-"+++str			-> "'\320'"+++str
	Each occurence of:
		str+++"&&"+++str`	-> str+++"&"+++str`
		str+++"&"+++str`	-> str+++str`
*/

validateMenuTitle :: !String -> String
validateMenuTitle str = removeSpecialChars ['&'] (okTitle str)

validateMenuItemTitle :: !String -> String
validateMenuItemTitle str = removeSpecialChars ['&'] (okTitle str)

okTitle :: !String -> String
okTitle str
	| str==""
	= " "
	| select str 0 <> '-'
	= str
	= str:=(0,'\320')

//-- Apple menu handling

AppleMenuId				:== 128
InsertPullDownPosition	:== 0
AppleTitle				:== toString (toChar 20)

AppleMenu :: !*OSToolbox -> (!OSMenu,!*OSToolbox)
AppleMenu tb
	# (menu,tb)		= NewMenu AppleMenuId AppleTitle tb
	  tb			= AppendMenu menu "About..."	tb
	  tb			= AppendMenu menu "-("			tb
//	  tb			= AddResMenu menu driverType	tb NOT NEEDED IN CARBON
	  tb			= InsertMenu menu InsertPullDownPosition tb
	= (menu,tb)
where
	s1				= toInt 'D'
	s2				= toInt 'R' + s1<<8
	s3				= toInt 'V' + s2<<8
	s4				= toInt 'R' + s3<<8
	driverType		= s4

//-- MenuId generation

osNewMenuNr :: !*OSToolbox -> (!Bool,!OSMenuNr,!*OSToolbox)
osNewMenuNr tb
	= getFreeMenuId MacPullDownIds tb

osNewSubMenuNr :: !*OSToolbox -> (!Bool,!OSSubMenuNr,!*OSToolbox)
osNewSubMenuNr tb
	= getFreeMenuId MacSubIds tb

/*	Creation of correct internal menu numbers only.
	Notes:	- MacSubMenuEndId is 234 rather than 235 because the windows use 235 for generating PopUpControls.
			- MacSubMenuIds cannot be AppleMenuId because this is used by the always present apple menu (see menuopen, IOStIsActive). 
*/

getFreeMenuId :: ![Int] !*OSToolbox -> (!Bool,!OSMenuNr,!*OSToolbox)
getFreeMenuId [macid:macids] tb
	# (h,tb)		= GetMHandle macid tb
	| h==0
		= (True,macid,tb)
	= getFreeMenuId macids tb
getFreeMenuId [] tb
	= (False,0,tb)

MacPullDownStartId	:== 1
MacPullDownEndId	:== 16
MacSubMenuStartId	:== 17
MacSubMenuEndId		:== 234

MacPullDownIds		:==	[MacPullDownStartId..MacPullDownEndId]
MacSubIds			:==	[MacSubMenuStartId..AppleMenuId-1]++[AppleMenuId+1..MacSubMenuEndId]


//-- PopUpMenu handling

::	OSTrackPopUpMenu									// The result of tracking an item in a PopUpMenu:
	=	{	ospupItem		:: !OSTrackPopUpMenuResult	//	the item that has been selected
		,	ospupModifiers	:: !Modifiers				//	the modifiers that have been pressed at selection
		}
::	OSTrackPopUpMenuResult								// The item of a pop up menu that has been selected is indicated by:
	=	PopUpTrackedByIndex	 !Int !Int					//	the parent menu id and the item's index position (used on Mac)
	|	PopUpTrackedByItemId !Int						//	its identification                               (used on Windows)

PopUpMenuID			:==	235				//	The fixed Menu ID for the PopUpControl
PopUpWid			:== 24

osCreatePopUpMenu :: !*OSToolbox -> (!OSMenu,!*OSToolbox)
osCreatePopUpMenu tb
	# tb				= trace_n ("osCreatePopUpMenu") tb
	= NewMenu PopUpMenuID "" tb
	
//---

osTrackPopUpMenu	:: !OSMenu !OSWindowPtr !*OSToolbox -> (!Maybe OSTrackPopUpMenu,!*OSToolbox)
osTrackPopUpMenu menu framePtr tb
	# tb					= InsertMenu menu beforeId tb
	# (x,y,tb)				= GetMouse tb
	# (x,y,tb)				= QLocalToGlobal x y tb
	# x = inc x
	# y = inc y
	# (stillDown,tb)		= StillDown tb
	# (menuId,itemNr,tb)	= PopUpMenuSelect menu y x 0 tb
	# tb					= DeleteMenu PopUpMenuID tb
	# (k1,k2,k3,k4,tb)		= GetKeys tb
	# mods					= KeyMapToModifiers (k1,k2,k3,k4)
	= (Just {ospupItem=PopUpTrackedByIndex menuId itemNr,ospupModifiers=mods},tb)
where
	beforeId	= -1

	
GetMenuID :: !OSMenu !*Toolbox -> (!OSMenuNr,!*Toolbox);
GetMenuID menuHandle t = code (menuHandle=D0,t=U)(menuId=D0,z=Z){
	call	.GetMenuID
};

SetMenuTitle :: !OSMenu !String !*Toolbox -> (!Int,!*Toolbox)
SetMenuTitle menuHandle itemString t = code (menuHandle=D0,itemString=SD1,t=U)(error=D0,z=Z){
	call	.SetMenuTitle
};

:: MenuItemAttributes	:== Int
kMenuItemAttrDisabled					:==    1
kMenuItemAttrIconDisabled				:==    2
kMenuItemAttrSubmenuParentChoosable		:==    4
kMenuItemAttrDynamic					:==    8
kMenuItemAttrNotPreviousAlternate		:==   16
kMenuItemAttrHidden						:==   32
kMenuItemAttrSeparator					:==   64
kMenuItemAttrSectionHeader				:==  128
kMenuItemAttrIgnoreMeta					:==  256
kMenuItemAttrAutoRepeat					:==  512
kMenuItemAttrUseVirtualKey				:== 1024
kMenuItemAttrCustomDraw					:== 2048
kMenuItemAttrIncludeInCmdKeyMatching	:== 4096

ChangeMenuItemAttributes :: !OSMenu !Int !Int !Int !*Toolbox -> (!Int,!*Toolbox)
ChangeMenuItemAttributes menu item setTheseAttributes clearTheseAttributes tb = code {
	ccall ChangeMenuItemAttributes "PIIII:I:I"
	}
