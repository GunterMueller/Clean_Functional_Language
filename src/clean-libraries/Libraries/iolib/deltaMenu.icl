implementation module deltaMenu;


import StdClass, StdInt, StdBool, StdMisc, StdString, StdFile;
import ioState, deltaIOSystem, menuDevice, misc, xmenu;


    

/* Enabling and disabling of complete menusystems.
*/
EnableMenuSystem :: !(IOState s) -> IOState s;
EnableMenuSystem io_state =  SetMenuSystemAbility io_state True;

DisableMenuSystem :: !(IOState s) -> IOState s;
DisableMenuSystem io_state =  SetMenuSystemAbility io_state False;

SetMenuSystemAbility :: !(IOState s) !Bool -> IOState s;
SetMenuSystemAbility io_state ability
   =  IOStateSetDevice io_state` menus`;
      where {
      menus`            =: SetMenuSystemAbility` menus ability;
      (menus, io_state`)=: IOStateGetDevice io_state MenuDevice;
      };

SetMenuSystemAbility` :: !(DeviceSystemState s) !Bool -> DeviceSystemState s;
SetMenuSystemAbility` (MenuSystemState bar (keys,handle,old)) ability
   #!
		strict1=strict1;
		=
		MenuSystemState bar (keys,strict1,ability);
	where {
	strict1=SetMenuSystemAbility`` handle ability;
		
	};

SetMenuSystemAbility`` :: ![MenuHandle s (IOState s)] !Bool
   -> [MenuHandle s (IOState s)];
SetMenuSystemAbility`` [PullDownHandle ability (id,w) items : menus] True
   #!
		strict1=strict1;
		strict2=strict2;
		=
		[PullDownHandle ability (id, strict1) items : 
       strict2];
	where {
	strict1=SetMenuAbility w ability;
		strict2=SetMenuSystemAbility`` menus True;
		
	};
SetMenuSystemAbility`` [PullDownHandle ability (id,w) items : menus] False
   #!
		strict1=strict1;
		strict2=strict2;
		=
		[PullDownHandle ability (id, strict1) items :
       strict2];
	where {
	strict1=SetMenuAbility w Unable;
		strict2=SetMenuSystemAbility`` menus False;
		
	};
SetMenuSystemAbility`` menus ability =  menus;


/*	Enabling and Disabling of Menus:
*/
EnableMenus :: ![MenuId] !(IOState state) -> IOState state;
EnableMenus [] io_state =  io_state;
EnableMenus menu_ids io_state
   =  IOStateSetDevice io_state` menus`;
      where {
      menus`            =: SetAbilityMenus menu_ids menus Able;
      (menus, io_state`)=: IOStateGetDevice io_state MenuDevice;
      };

DisableMenus :: ![MenuId] !(IOState f) -> IOState f;
DisableMenus [] io_state =  io_state;
DisableMenus menu_ids io_state
   =  IOStateSetDevice io_state` menus`;
      where {
      menus`            =: SetAbilityMenus menu_ids menus Unable;
      (menus, io_state`)=: IOStateGetDevice io_state MenuDevice;
      };

SetAbilityMenus :: ![MenuId] !(DeviceSystemState s) !SelectState 
   -> DeviceSystemState s;
SetAbilityMenus menu_ids (MenuSystemState bar (keys, menus, able)) ability
   #!
		menus`=menus`;
		=
		MenuSystemState bar (keys, menus`, able);
      where {
      menus`=: SetAbilityMenus` menu_ids menus ability able;
      };

SetAbilityMenus` :: ![MenuId] ![MenuHandle s io] !SelectState !Bool
   -> [MenuHandle s io];
SetAbilityMenus` menu_ids [menu=: (PullDownHandle old xh=:(id,w) items) : menus] ability True| IdListContainsId menu_ids id
                              #!
		strict1=strict1;
		menus`=menus`;
		=
		[PullDownHandle ability (id, strict1) items : menus`];
   #!
		strict1=strict1;
		menus`=menus`;
		=
		[menu : menus`];
      where {
      menus`=: SetAbilityMenus` menu_ids menus ability True;
      strict1=SetMenuAbility w ability;
		};
SetAbilityMenus` menu_ids [menu=: (PullDownHandle old xh=:(id,w) items) : menus] ability menu_system_ability| IdListContainsId menu_ids id
                              =  [PullDownHandle ability (id, w) items : menus`];
   #!
		menus`=menus`;
		=
		[menu : menus`];  
      where {
      menus`=: SetAbilityMenus` menu_ids menus ability menu_system_ability;
      };
SetAbilityMenus` menu_ids menus able menu_system_ability =  menus;


/*	Adding and removing items from groups
*/
InsertMenuItems :: !MenuItemGroupId !Int ![MenuElement s (IOState s)] !(IOState s)
   -> IOState s;
InsertMenuItems id index items io_state
   =  IOStateSetDevice io_state` menus`;
      where {
      menus`            =: InsertInGroup id index items menus;
      (menus, io_state`)=: IOStateGetDevice io_state MenuDevice;
      };

AppendMenuItems :: !MenuItemGroupId !Int ![MenuElement s (IOState s)] !(IOState s)
   -> IOState s;
AppendMenuItems id index items io_state
   =  IOStateSetDevice io_state` menus`;
      where {
      menus`            =: InsertInGroup id (inc index) items menus;
      (menus, io_state`)=: IOStateGetDevice io_state MenuDevice;
      };

RemoveMenuItems :: ![MenuItemId] !(IOState s) -> IOState s;
RemoveMenuItems ids io_state
   =  IOStateSetDevice io_state` menus`;
      where {
      menus`            =: DelFromGroups ids menus;
      (menus, io_state`)=: IOStateGetDevice io_state MenuDevice;
      };

RemoveMenuGroupItems :: !MenuItemGroupId ![Int] !(IOState s) -> IOState s;
RemoveMenuGroupItems id indexes io_state
   =  IOStateSetDevice io_state` menus`;
      where {
      menus`            =: DelFromGroupIndex id indexes menus;
      (menus, io_state`)=: IOStateGetDevice io_state MenuDevice;
      };


/* Press a RadioMenuItem.
*/
SelectMenuRadioItem :: !MenuItemId !(IOState s) -> IOState s;
SelectMenuRadioItem id io_state
   =  IOStateSetDevice io_state` menus`;
      where {
      menus`            =: SelectRadioItem` id menus;
      (menus, io_state`)=: IOStateGetDevice io_state MenuDevice;
      };

SelectRadioItem` :: !MenuItemId !(DeviceSystemState s) -> DeviceSystemState s;
SelectRadioItem` id (MenuSystemState w (keys,handles,able))
   #!
		strict1=strict1;
		=
		MenuSystemState w (keys,strict1,able);
	where {
	strict1=SelectRadioItem`` id handles;
		
	};

SelectRadioItem`` :: !Id ![MenuHandle s (IOState s)]
   -> [MenuHandle s (IOState s)];
SelectRadioItem`` id [menu=: PullDownHandle ability xh items : menus]
   | found =  [PullDownHandle ability xh items` : menus];
   #!
		strict1=strict1;
	= 	[menu : strict1];
      where {
      (found, items`)=: SelectRadioItem``` id items;
      strict1=SelectRadioItem`` id menus;
		};
SelectRadioItem`` id menus =  menus;

SelectRadioItem``` :: !Id ![MenuItemHandle s (IOState s)]
   -> (!Bool, ![MenuItemHandle s (IOState s)]);
SelectRadioItem``` id [item=: RadioHandle rid radios : items]
   | found #!
		radios`=radios`;
		=
		 (True,   [RadioHandle rid radios` : items]);
   #!
		radios`=radios`;
		=
		(found`, [item : items`]);
      where {
      (found`,items`)=: SelectRadioItem``` id items;
      found          =: IsInRadioGroup id radios;
      radios`        =: SelectRadioItem```` id radios;
      };
SelectRadioItem``` id [item : items] =  SelectRadioItem``` id items;
SelectRadioItem``` id items =  (False, items); 

IsInRadioGroup :: !Id ![RadioMenuItemHandle s (IOState s)] -> Bool;
IsInRadioGroup id [RadioItemHandle (id`,w) f : radios]
   | id == id` =  True;
   =  IsInRadioGroup id radios;
IsInRadioGroup id radios =  False;

SelectRadioItem```` :: !Id ![RadioMenuItemHandle s (IOState s)] 
   -> [RadioMenuItemHandle s (IOState s)];
SelectRadioItem```` id [RadioItemHandle (id`,w) f : radios]
   | id == id` #!
		strict1=strict1;
		strict2=strict2;
		radios`=radios`;
		=
		[RadioItemHandle (id`, strict1  ) f : radios`];
   #!
		strict1=strict1;
		strict2=strict2;
		radios`=radios`;
		=
		[RadioItemHandle (id`, strict2) f : radios`];
      where {
      radios`=: SelectRadioItem```` id radios;
      strict2=CheckXWidget w NoMark;
		strict1=CheckXWidget w Mark;
		};
SelectRadioItem```` id radios =  radios; 


/*	Enabling and Disabling of MenuItems:
*/
EnableMenuItems :: ![MenuItemId] !(IOState state) -> IOState state;
EnableMenuItems item_ids io_state
   =  ChangeMenuItems item_ids io_state (SetItemAbility Able);

DisableMenuItems :: ![MenuItemId] !(IOState state) -> IOState state;
DisableMenuItems item_ids io_state
   =  ChangeMenuItems item_ids io_state (SetItemAbility Unable);

SetItemAbility :: !SelectState !XHandle -> XHandle;
SetItemAbility able (id,w) #!
		strict1=strict1;
		=
		(id, strict1);
	where {
	strict1=SetWidgetAbility w able;
		
	};

MarkMenuItems :: ![MenuItemId] !(IOState state) -> IOState state;
MarkMenuItems item_ids io_state
   =  ChangeMenuItems item_ids io_state (SetItemMark Mark);

UnmarkMenuItems :: ![MenuItemId] !(IOState state) -> IOState state;
UnmarkMenuItems item_ids io_state
   =  ChangeMenuItems item_ids io_state (SetItemMark NoMark);

SetItemMark :: !MarkState !XHandle -> XHandle;
SetItemMark mark (id,w) #!
		strict1=strict1;
		=
		(id, strict1);
	where {
	strict1=CheckXWidget w mark;
		
	};

ChangeMenuItemTitles ::	![(MenuItemId, ItemTitle)] !(IOState s)-> IOState s;
ChangeMenuItemTitles atts io_state
   =  ChangeMenuItems (ExtractIds atts) io_state (ChangeItemTitles atts);

ExtractIds :: ![(MenuItemId, String)] -> [MenuItemId];
ExtractIds [(a,b) : rest] #!
		strict1=strict1;
		=
		[a : strict1];
	where {
	strict1=ExtractIds rest;
		
	};
ExtractIds rest =  [];

ChangeItemTitles :: ![(MenuItemId,String)] !XHandle -> XHandle;
ChangeItemTitles attributes (id,w)
   #!
		strict1=strict1;
		=
		(id, strict1);
	where {
	strict1=set_widget_title w (GetTitle attributes id);
		
	};

GetTitle :: ![(MenuItemId,String)] !MenuItemId -> String;
GetTitle [(id,s) : rest] id`
      | id == id`=  s;
   =  GetTitle rest id`;
GetTitle rest id =  "";


/* It's more straightforward to let this function parse the structure itself,
   than creating some weird Attribute function.
*/
ChangeMenuItemFunctions :: ![(MenuItemId, MenuFunction s (IOState s))] 
      !(IOState s)
   -> IOState s;
ChangeMenuItemFunctions atts io_state
   =  IOStateSetDevice io_state` menus`;
      where {
      menus`            =: ChangeMenuItemFunctions``` atts menus;
      (menus, io_state`)=: IOStateGetDevice io_state MenuDevice;
      };

ChangeMenuItemFunctions``` :: ![(MenuItemId,MenuFunction s (IOState s))]
      !(DeviceSystemState s)
   -> DeviceSystemState s;
ChangeMenuItemFunctions``` changes (MenuSystemState w (keys,handles,able))
   #!
		strict1=strict1;
		=
		MenuSystemState w (keys,strict1,able);
	where {
	strict1=ChangeMenuItemFunctions` changes handles;
		
	};

ChangeMenuItemFunctions` :: ![(MenuItemId, MenuFunction s io)] ![MenuHandle s io]
   -> [MenuHandle s io];
ChangeMenuItemFunctions` atts [PullDownHandle ability xh items : menus]
   #!
		items`=items`;
		menus`=menus`;
		=
		[PullDownHandle ability xh items` : menus`];
      where {
      items`=: ChangeMenuItemFunctions`` atts items;
      menus`=: ChangeMenuItemFunctions`  atts menus;
      };
ChangeMenuItemFunctions` atts menus =  menus;

ChangeMenuItemFunctions`` :: ![(MenuItemId, MenuFunction s io)] 
      ![MenuItemHandle s io]
   -> [MenuItemHandle s io];
ChangeMenuItemFunctions`` atts [item=:ItemHandle xh=:(id,w) f : items]
   | contains   #!
		items`=items`;
		=
		[ItemHandle xh newf : items`];
   #!
		items`=items`;
		=
		[item : items`];
      where {
      (contains, newf)=: FuncAttContainsId atts id;
      items`          =: ChangeMenuItemFunctions`` atts items;
      };
ChangeMenuItemFunctions`` atts [SubMenuHandle xh=:(id,w) subitems : items]
   #!
		strict1=strict1;
		subitems`=subitems`;
		=
		[SubMenuHandle xh subitems` : strict1];
      where {
      subitems`=: ChangeMenuItemFunctions`` atts subitems;
      strict1=ChangeMenuItemFunctions`` atts items;
		};
ChangeMenuItemFunctions`` atts [MenuItemGroupHandle xh=:(id,w) subitems : items]
   #!
		items`=items`;
		subitems`=subitems`;
		=
		[MenuItemGroupHandle xh subitems` : items`];
      where {
      items`   =: ChangeMenuItemFunctions`` atts items;
      subitems`=: ChangeMenuItemFunctions`` atts subitems;
      };
ChangeMenuItemFunctions`` atts [RadioHandle w radios : items]
   #!
		items`=items`;
		radios`=radios`;
		=
		[RadioHandle w radios` : items`];
      where {
      items` =: ChangeMenuItemFunctions`` atts items;
      radios`=: ChangeMenuRadioItemFunctions atts radios;
      };
ChangeMenuItemFunctions`` atts [item : items]
   #!
		strict1=strict1;
		=
		[item : strict1];
	where {
	strict1=ChangeMenuItemFunctions`` atts items;
		
	};
ChangeMenuItemFunctions`` atts items =  items;

FuncAttContainsId :: ![(MenuItemId, MenuFunction s io)] !MenuItemId 
   -> (Bool, MenuFunction s io);
FuncAttContainsId [(id,f) : rest] id`
   | id == id`   =  (True, f);
   =  FuncAttContainsId rest id`;
FuncAttContainsId rest id =  (False, DoNotChangeMenu);

DoNotChangeMenu :: * s * io -> (*s, *io);
DoNotChangeMenu s io_state =  (s, io_state);

ChangeMenuRadioItemFunctions :: ![(!MenuItemId, !MenuFunction s io)]
      ![RadioMenuItemHandle s io]
   ->  [RadioMenuItemHandle s io];
ChangeMenuRadioItemFunctions atts [radio=:RadioItemHandle xh=:(id,w) f : items]
   | contains   #!
		items`=items`;
		= [RadioItemHandle xh newf : items`];
   #!
		items`=items`;
		=
		[radio : items`];
      where {
      (contains, newf)=: FuncAttContainsId atts id;
      items`          =: ChangeMenuRadioItemFunctions atts items;
      };
ChangeMenuRadioItemFunctions atts items =  items;


/* Changing menu items by using some function.
*/

    

:: AttFunc :== XHandle -> XHandle;


    

ChangeMenuItems :: ![MenuItemId] !(IOState s) !AttFunc -> IOState s;
ChangeMenuItems item_ids io_state function
   =  IOStateSetDevice io_state` menus`;
      where {
      menus`            =: ChangeMenuItems``` item_ids function menus;
      (menus, io_state`)=: IOStateGetDevice io_state MenuDevice;
      };

ChangeMenuItems``` :: ![MenuItemId] !AttFunc !(DeviceSystemState s)
   -> DeviceSystemState s;
ChangeMenuItems``` ids f (MenuSystemState w (keys,handles,able))
   #!
		strict1=strict1;
		=
		MenuSystemState w (keys,strict1,able);
	where {
	strict1=ChangeMenuItems` ids handles f;
		
	};

ChangeMenuItems` :: ![MenuItemId] ![MenuHandle s io] !AttFunc
   -> [MenuHandle s io];
ChangeMenuItems` item_ids [PullDownHandle ability xh items : menus] function
   #!
		menus`=menus`;
		items`=items`;
		=
		[PullDownHandle ability xh items` : menus`];
      where {
      menus`=: ChangeMenuItems`  item_ids menus function;
      items`=: ChangeMenuItems`` item_ids items function;
      };
ChangeMenuItems` item_ids menus f =  menus;

ChangeMenuItems`` :: ![MenuItemId] ![MenuItemHandle s io] !AttFunc
   -> [MenuItemHandle s io];
ChangeMenuItems`` item_ids [ItemHandle xh=:(id,w) f : items] function
   #!
      strict1=(DoAttFunction (IdListContainsId item_ids id)
                                         function xh);
      items`= ChangeMenuItems`` item_ids items function;
   #  item` = ItemHandle strict1 f;
	=	[item` : items`];
ChangeMenuItems`` item_ids [SubMenuHandle xh=:(id,w) subitems : items] function
   #!
      strict1=(DoAttFunction (IdListContainsId item_ids id) 
                                               function xh);
      items`   = ChangeMenuItems`` item_ids items function;
      subitems`= ChangeMenuItems`` item_ids subitems function;
   #  item`    = SubMenuHandle strict1 subitems`;
	=	[item` : items`];
ChangeMenuItems`` item_ids [MenuItemGroupHandle xh=:(id,w) subitems : items]
                     function
   #!
      strict1=(DoAttFunction (IdListContainsId item_ids id)
                                                 function xh);
      items`   = ChangeMenuItems`` item_ids items function;
      subitems`= ChangeMenuItems`` item_ids subitems function;
   #  item`= MenuItemGroupHandle strict1 subitems`;
	# r	=
		[item` : items`];
	= r;
ChangeMenuItems`` item_ids [RadioHandle w radios : items] function
   #!
		items`=items`;
		radios`=radios`;
		=
		[RadioHandle w radios` : items`];
      where {
      items` =: ChangeMenuItems`` item_ids items function;
      radios`=: ChangeMenuRadioItems item_ids radios function;
      };
ChangeMenuItems`` item_ids [item : items] f
   #!
		strict1=strict1;
		=
		[item : strict1];
	where {
	strict1=ChangeMenuItems`` item_ids items f;
		
	};
ChangeMenuItems`` item_ids items f =  items;

DoAttFunction :: !Bool !AttFunc !XHandle -> XHandle;
DoAttFunction do_it f xh | do_it   =  f xh;
                            =  xh;

ChangeMenuRadioItems :: ![MenuItemId] ![RadioMenuItemHandle s io] !AttFunc
   -> [RadioMenuItemHandle s io];
ChangeMenuRadioItems item_ids [RadioItemHandle xh=:(id,w) f : items] function
   #!
      strict1=ChangeMenuRadioItems item_ids items function;
		strict2=(DoAttFunction (IdListContainsId item_ids id)
                                              function xh);
   #  radio`= RadioItemHandle strict2 f;
	=	[radio` : strict1];
ChangeMenuRadioItems ids items f =  items;

