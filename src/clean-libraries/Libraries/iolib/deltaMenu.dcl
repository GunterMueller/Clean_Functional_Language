definition module deltaMenu;

//	Version 0.8

//
//	Operations on menus. 
//

import deltaIOSystem, deltaEventIO;

//	Operations on unknown MenuIds/MenuItemIds are ignored.

    
EnableMenuSystem	::  !(IOState s) -> IOState s;
DisableMenuSystem	:: !(IOState s) -> IOState s;

/*	Enabling and Disabling of the MenuSystem. When the menu system is enabled
	the previously selectable menus and menu items will become selectable again.
	Operations on a disabled menu system take effect when the menu system is
	re-enabled. */

EnableMenus	::	 ![MenuId] !(IOState s) -> IOState s;
DisableMenus	:: ![MenuId] !(IOState s) -> IOState s;

/*	Enabling and disabling of menus. Disabling a menu causes its
	contents to be unselectable. Enabling a disabled menu which
	contents was partially selectable before disabling causes all
	items to become selectable again. */

InsertMenuItems	:: !MenuItemGroupId !Int ![MenuElement s (IOState s)]
	!(IOState s) -> IOState s;
AppendMenuItems	:: !MenuItemGroupId !Int ![MenuElement s (IOState s)]
	!(IOState s) -> IOState s;
RemoveMenuItems	:: ![MenuItemId] !(IOState s) -> IOState s;
RemoveMenuGroupItems	:: !MenuItemGroupId ![Int] !(IOState s) -> IOState s;

/*	Addition and removal of menu items in MenuItemGroups.
	InsertMenuItems inserts menu items before the item with the specified
	index, AppendMenuItems inserts them after that item. Items are
	numbered starting from one. Indices smaller than one resp. greater
	than the number of items in the group cause the elements to be
	inserted before the first resp. after the last item of the group.
	Only (Check)MenuItems and MenuSeparators are added to a MenuItemGroup.
	RemoveMenu(Group)Items only works on items that are in a MenuItemGroup.
	RemoveMenuGroupItems removes those items of the specified MenuItemGroup
	given the indices. Indices are numbered starting from one. If an index
	is invalid (less than one or larger than the amount of items), no item
	is removed for that index. */

SelectMenuRadioItem	:: !MenuItemId !(IOState s) -> IOState s;

/*	SelectMenuRadioItem marks the indicated Menu RadioItem and unmarks the
	currently marked MenuRadioItem in the group. */

EnableMenuItems	::	![MenuItemId]	!(IOState s) -> IOState s;
DisableMenuItems	::	![MenuItemId]	!(IOState s) -> IOState s;
MarkMenuItems	::		![MenuItemId]	!(IOState s) -> IOState s;
UnmarkMenuItems	::	![MenuItemId]	!(IOState s) -> IOState s;
ChangeMenuItemTitles	::	![(MenuItemId, ItemTitle)] !(IOState s)
	-> IOState s;
ChangeMenuItemFunctions	:: ![(MenuItemId, MenuFunction s (IOState s))]
	!(IOState s) -> IOState s;

/*	Enable, disable, mark, unmark and change titles and functions of
	MenuElements. */