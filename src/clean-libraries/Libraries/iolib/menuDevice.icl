implementation module menuDevice;


import misc,xtypes,deltaIOSystem,ioState,commonDef,xkernel,xmenu;
import StdEnv;


    

MenuFunctions ::    DeviceFunctions s;
MenuFunctions = (ShowMenu,OpenMenu,MenuIO,CloseMenu,HideMenu);

CloseMenu :: !(IOState state) -> IOState state;
CloseMenu io_state
   =  UEvaluate_2 (IOStateRemoveDevice io_state` MenuDevice)
                  (DisposeMenuSystemState menu);
      where {
      (menu, io_state`)=: IOStateGetDevice io_state MenuDevice;
      };

HideMenu :: !(IOState s) -> IOState s;
HideMenu io_state
   =  IOStateSetDevice io_state` menu`;
      where {
      menu`            =: ClearMenuSystem menu;
      (menu, io_state`)=: IOStateGetDevice io_state MenuDevice;
      };

ShowMenu :: !(IOState s) -> IOState s;
ShowMenu io_state
   =  IOStateSetDevice io_state` menu`;
      where {
      menu`            =: DrawMenuSystem menu;
      (menu, io_state`)=: IOStateGetDevice io_state MenuDevice;
      };


/* Opening a menu
*/
OpenMenu :: !(DeviceSystem s (IOState s)) !(IOState s) -> IOState s;
OpenMenu (MenuSystem menus) io_state
   #!
      menu_bar   = add_menu_bar 0;
      handles    = CreateXHandles [] menus menu_bar;
   #!
      menu_system= MenuSystemState menu_bar handles; 
   #!
      strict1=(DrawMenuSystem menu_system);
		=
		IOStateSetDevice io_state strict1;

/* For every kind of 'root` menu (moveable/popup/menubar) a structure is build,
   that contains handles to the subparts (menus/items) of this structure.
*/
CreateXHandles :: ![KeyShortcut] ![MenuDef s (IOState s)] Widget 
   -> MenuHandles s (IOState s);
CreateXHandles keys [PullDownMenu id s able items : menus] bar 
   #!   strict1=AddXMenu bar s able;
   #  (new_menu, bar`)     = strict1;
   #!	strict2=CreateXMenuItemHandles keys new_menu items;
		strict3=CreateXHandles keys menus bar`;
   #   (keys`, item_handles)= strict2;
   #!  pulldown_handle      = PullDownHandle able (id,new_menu) item_handles;
   #  (keys``, menus`, b)  = strict3;
		=
		(keys``, [pulldown_handle : menus`], True);
CreateXHandles keys menus bar =  (keys, [], True);

/* Creating all the menu items and putting them in a list that is returned.
   According to the OPEN LOOK guidelines grouping in menus is done by an
   empty menu item.
*/
CreateXMenuItemHandles :: [KeyShortcut] Widget [MenuElement s (IOState s)] 
   -> (![KeyShortcut], ![MenuItemHandle s (IOState s)]);
CreateXMenuItemHandles keys menu [MenuItem id s cut able f : items]
   #!
      cut`              = CorrectKeyShortcut cut keys;
      strict1=AddXMenuItem menu s cut` able;
    # (new_item`, menu`)= strict1;
    #! new_item          = ItemHandle (id, new_item`) f;
    # (keys`, items`)   = CreateXMenuItemHandles (AddKey cut` keys) menu` items;
		=
		(keys`, [new_item : items`]);
CreateXMenuItemHandles keys menu [CheckMenuItem id s cut able mark f : items]
   #!
      cut`              = CorrectKeyShortcut cut keys;
      strict1=AddXCheckMenuItem menu s cut` mark able;
      # (new_item`, menu`)= strict1;
      #! new_item          = ItemHandle (id, new_item`) f;
      # (keys`, items`)   = CreateXMenuItemHandles (AddKey cut` keys) menu` items;
		=
		(keys`, [new_item : items`]);
CreateXMenuItemHandles keys menu [SubMenuItem id s able sub_items : items]
   #!
		strict2=AddXSubMenuItem menu s able;
   #  (sub_widget, menu`)= strict2;
   #! strict1=CreateXMenuItemHandles keys sub_widget sub_items;
   #  (keys`, sub_items`)= strict1;
      (keys``, items`)   = CreateXMenuItemHandles keys` menu` items;
   #! sub_menu           = SubMenuHandle (id, sub_widget) sub_items`;
		=
		(keys``, [sub_menu : items`]);
CreateXMenuItemHandles keys menu [MenuItemGroup id group_items : items]
   #!
      strict1=AddXGroupItemHandles keys menu group_items;
   #
      (keys` , group_items`)= strict1;
   #!
      group                 = MenuItemGroupHandle (id, menu) group_items`;
	#
      (keys``, items`      )= CreateXMenuItemHandles keys` menu items;
		=
		(keys``, [group : items`]);
CreateXMenuItemHandles keys menu [MenuRadioItems id radios : items] 
   #!
      strict1=CreateXRadioItems keys menu radios id;
   #  (keys` , radios`, menu`)= strict1;
      (keys``, items`)        = CreateXMenuItemHandles keys` menu` items;
		=
		(keys``, [radios` : items`]);
CreateXMenuItemHandles keys menu [MenuSeparator : items]
   #!
      strict1=AddXMenuSeparator menu;
   #  (new_item`, menu`)= strict1;
      (keys`, items`)   = CreateXMenuItemHandles keys menu` items;
      new_item          = MenuSeparatorHandle new_item`;
		=
		(keys`, [new_item : items`]);
CreateXMenuItemHandles keys menu items =  (keys, []);

/* Creation of MenuRadioItems as a "group" of CheckMenuItems.               
*/
CreateXRadioItems :: ![KeyShortcut] !Widget ![RadioElement s (IOState s)]
      !MenuItemId
   -> (![KeyShortcut], !MenuItemHandle s (IOState s), !Widget);
CreateXRadioItems keys menu radios id 
   =  (keys`, RadioHandle id radios`, menu`);
      where {
      (keys`, radios`, menu`)=: CreateXRadioItems` keys menu id radios;
      };

CreateXRadioItems` :: ![KeyShortcut] Widget !MenuItemId
      ![RadioElement s (IOState s)] 
   -> (![KeyShortcut], ![RadioMenuItemHandle s (IOState s)], !Widget);
CreateXRadioItems` keys w defaultId [MenuRadioItem id s sh able f : radios]
   | id == defaultId   #!
		sh`=sh`;
		newkeys=newkeys;
      strict3=AddXCheckMenuItem w s sh` Mark   able;
   #  (radio_item , w` )= strict3;
      radio = RadioItemHandle (id, radio_item ) f;
      (keys` , radios` , menu` )= CreateXRadioItems` newkeys w`  defaultId radios;
   #!	radios`=radios`;
		=
		(keys` , [radio  : radios` ], menu` );
   #!
		sh`=sh`;
		newkeys=newkeys;
		strict4=AddXCheckMenuItem w s sh` NoMark able;
    # (radio_item`, w``)= strict4;
      radio`= RadioItemHandle (id, radio_item`) f;
    # (keys``, radios``, menu``)= CreateXRadioItems` newkeys w`` defaultId radios;

	#!	radios``=radios``;
		=
		(keys``, [radio` : radios``], menu``);
      where {
      sh`               =: CorrectKeyShortcut sh keys;
      newkeys           =: AddKey sh` keys;
		};
CreateXRadioItems` keys w id radios =  (keys, [], w);


/* Doing menu I/O
*/
MenuIO :: !Event !*s !(IOState *s) -> (!Bool, !*s, !IOState *s);
MenuIO (widget, XMenuDevice, e) state io_state 
   =  (True, state`, io_state``);
      where {
      (state`, io_state``)=: MenuIO` widget menus state io_state`;
      (menus,  io_state` )=: IOStateGetDevice io_state MenuDevice;
      };
MenuIO no_menu_device state io_state =  (False, state, io_state);

MenuIO` :: !Widget !(DeviceSystemState *s) !*s !(IOState *s) -> (!*s, !IOState *s);
/* RWS don't do any menu io on disabled menu systems */
MenuIO` _ (MenuSystemState _ (_,_,False)) state io_state
	=	(state, io_state);
MenuIO` widget (MenuSystemState bar h=:(keys,menu_specs,able)) state io_state
   =  menu_f state io_state;
      where {
      menu_f=: GetMenuFunction widget menu_specs;
      };

GetMenuFunction :: !Widget ![MenuHandle s (IOState s)] -> MenuFunction s (IOState s);
/* RWS only consider able menus
	GetMenuFunction widget [PullDownHandle ability xh items : menus] */
GetMenuFunction widget [PullDownHandle Able xh items : menus]
   | found   =  f;
      where {
      (found, f)=: GetMenuFunction` widget items;
      };
GetMenuFunction widget [_ : menus]
   =  GetMenuFunction widget menus;
/* RWS : no function applicable, return noop function */
GetMenuFunction widget []
	=	noop;
	where
	{
		noop state io
			=	(state, io);
	}

GetMenuFunction` :: !Widget ![MenuItemHandle s (IOState s)] 
   -> (!Bool, !MenuFunction s (IOState s));
GetMenuFunction` widget [ItemHandle (id`,w) f : items]
   | widget == w =  (True, f);
   =  GetMenuFunction` widget items;
GetMenuFunction` widget [SubMenuHandle xhandle sub_items : items]
   =  GetMenuFunction` widget (Concat sub_items items);
GetMenuFunction` widget [MenuItemGroupHandle xhandle group_items : items]
   =  GetMenuFunction` widget (Concat group_items items);
GetMenuFunction` widget [RadioHandle id` radio_items : items] 
   | found =  (True, RadioFunction f radio_items widget);
   =  GetMenuFunction` widget items;
      where {
      (found, f)=: GetRadioFunction widget radio_items;
      };
GetMenuFunction` widget [item : items] =  GetMenuFunction` widget items;
GetMenuFunction` widget items =  (False, NoFunc);

GetRadioFunction :: !Widget ![RadioMenuItemHandle s (IOState s)] 
   -> (!Bool, !MenuFunction s (IOState s));
GetRadioFunction widget [RadioItemHandle (id`,w) f : radios] 
   | widget == w =  (True, f);
   =  GetRadioFunction widget radios;
GetRadioFunction widget radios =  (False, NoFunc);

RadioFunction :: !(MenuFunction *s (IOState *s)) ![RadioMenuItemHandle *s io] !Widget 
                 *s !(IOState *s) -> (*s, !IOState *s);
RadioFunction f radios widget s io
	= f s (SetRadios radios widget io);

SetRadios :: ![RadioMenuItemHandle s io] !Widget !(IOState s) -> IOState s;
SetRadios [RadioItemHandle (id,w) f : radios] widget io
   | widget == w =  UEvaluate_2 radios` (CheckXWidget w Mark);
   =  UEvaluate_2 radios` (CheckXWidget w NoMark);
      where {
      radios`=: SetRadios radios widget io;
      };
SetRadios radios widget io =  io;

NoFunc :: *s (IOState *s) -> (*s, IOState *s);
NoFunc s io =  (s,io);


     

  XMark   :== 1;
  XNoMark :== 0;

  Set     :== 1;
  UnSet   :== 0;


    

/* Allocation and creation of menus/items etc.
*/
AddXMenu :: !Widget !String !SelectState -> (!Widget, !Widget);
AddXMenu bar s able 
   | Enabled able #!
		menu=menu;
		=
		 (enable_menu_widget  menu, bar);
   #!
		menu=menu;
		=
		(disable_menu_widget menu, bar);
      where {
      menu=: add_menu bar s;
      };

AddXMenuSeparator :: !Widget -> (!Widget, !Widget);
AddXMenuSeparator menu =  (add_menu_separator menu, menu);

AddXMenuItem :: !Widget !String !KeyShortcut !SelectState -> (!Widget, !Widget);
AddXMenuItem menu s ks able 
   #!   item = add_menu_item menu s;
     	item`= InstallKeyShortcut item ks;
   | Enabled able
		=
		 (enable_menu_widget  item`, menu);
		=
		(disable_menu_widget item`, menu);

AddXSubMenuItem :: !Widget !String !SelectState -> (!Widget, !Widget);
AddXSubMenuItem menu s able 
   | Enabled able #!
		sub=sub;
		=
		 (enable_menu_widget  sub, menu);
   #!
		sub=sub;
		=
		(disable_menu_widget sub, menu);
      where {
      sub=: add_sub_menu menu s;
      };

AddXCheckMenuItem :: !Widget !String !KeyShortcut !MarkState !SelectState
   -> (!Widget, !Widget);
AddXCheckMenuItem menu s ks ms able 
   #!
      item = AddXCheckMenuItem` menu s ms;
	  item`= InstallKeyShortcut item ks;
   | Enabled able
   		=
		(enable_menu_widget  item`, menu);
		=
		(disable_menu_widget item`, menu);

AddXCheckMenuItem` :: !Widget !String !MarkState -> Widget;
AddXCheckMenuItem` menu s ms
   | MarkEqual Mark ms =  add_check_item menu s XMark;
   =  add_check_item menu s XNoMark;

/* Handling group items
*/
AddXGroupItemHandle :: ![KeyShortcut] !Widget !(MenuElement s (IOState s))
   -> (!KeyShortcut, !MenuItemHandle s (IOState s), !Widget);
AddXGroupItemHandle keys group (MenuItem id s key able f)
   =  (key`, ItemHandle (id, item) f, group`); 
      where {
      key`          =: CorrectKeyShortcut key keys;
      (item, group`)=: AddXMenuItem group s key` able;
      };
AddXGroupItemHandle keys group (CheckMenuItem id s key able mark f)
   =  (key`, ItemHandle (id, item) f, group`);
      where {
      key`          =: CorrectKeyShortcut key keys;
      (item, group`)=: AddXCheckMenuItem group s key` mark able;
      };
AddXGroupItemHandle keys group MenuSeparator
   =  (NoKey, MenuSeparatorHandle item, group`);
      where {
      (item, group`)=: AddXMenuItem group " " NoKey Unable;
      };

AddXGroupItemHandles :: ![KeyShortcut] !Widget ![MenuElement s (IOState s)] 
   -> (![KeyShortcut], ![MenuItemHandle s (IOState s)]);
AddXGroupItemHandles keys group [item : items]
   | IsGroupItem item #!
		item`=item`;
		=
		(keys``, [item` : items`]);
   =  (keys  , items`);
      where {
      (key, item`, group`)=: AddXGroupItemHandle keys group item;
      (keys``, items`)    =: AddXGroupItemHandles (AddKey key keys) group` items;
      };
AddXGroupItemHandles keys group items =  (keys, []);

IsGroupItem :: !(MenuElement s (IOState s)) -> Bool;
IsGroupItem (MenuItem      id s key able      f) =  True;
IsGroupItem (CheckMenuItem id s key able mark f) =  True;
IsGroupItem MenuSeparator                        =  True;
IsGroupItem item =  False;

InsertInGroup :: !MenuItemGroupId !Int ![MenuElement s (IOState s)]
                 !(DeviceSystemState s) -> DeviceSystemState s;
InsertInGroup id index item (MenuSystemState w (keys, menu_specs, able))
   #!
      strict1=InsertInGroup` id index item menu_specs keys;
   #
      (keys`, menu_specs`, b)= strict1;
		=
		MenuSystemState w (keys`, menu_specs`, able);

InsertInGroup` :: !MenuItemGroupId !Int ![MenuElement s (IOState s)]
      ![MenuHandle s (IOState s)] ![KeyShortcut]
   -> MenuHandles s (IOState s);
InsertInGroup` id index item [menu=: (PullDownHandle ability xh items) : menus] keys
   #!
		strict2=InsertInGroup`` id index item items keys;
   #
      (ready, keys`, items`)= strict2;
	| ready =  (keys` , [PullDownHandle ability xh items` : menus], True);
   #!
      strict1=InsertInGroup` id index item menus keys;
   #
      (keys``, menus`, b)   = strict1;
		=
		(keys``, [menu : menus`], True);
InsertInGroup` id index item menus keys =  (keys, [], True);

InsertInGroup`` :: !MenuItemGroupId !Int ![MenuElement s (IOState s)]
      ![MenuItemHandle s (IOState s)] ![KeyShortcut]
   -> (!Bool, ![KeyShortcut], ![MenuItemHandle s (IOState s)]);
InsertInGroup`` id index newitems [item=: (MenuItemGroupHandle (id`, w) els) : items] keys| id == id`
	#!	strict7=ReconstructMenuElements els keys;
	#   (keys1, els``)   = strict7;
	#!	strict6=ReconstructMenuElements items keys1;
	    els``=els``
    #  (keys2, reitems) = strict6;
    #!  strict4=(InsertInThisGroup index newitems els``);
    # (keys3, els`)    = AddXGroupItemHandles keys2 w
                              strict4;
      (keys4, reitems`)= CreateXMenuItemHandles keys3 w reitems;
	#! reitems`=reitems`;
	    els`=els`;

		=
		(True,  keys4, [MenuItemGroupHandle (id`,w) els` : reitems`]);
   #!
		strict8=InsertInGroup`` id index newitems items keys;
      (ready, keys5, result)= strict8;
	#! result=result;
		=
		(ready, keys5, [item : result]);
InsertInGroup`` id index newitems [item : items] keys
   #!
		strict1=strict1;
		=
		(ready, keys`, [item : items`]);
      where {
      (ready, keys`, items`)= strict1;
      strict1=InsertInGroup`` id index newitems items keys;
		};
InsertInGroup`` id index newitems items keys =  (False, keys, items);

InsertInThisGroup :: !Int ![MenuElement s (IOState s)] 
      ![MenuElement s (IOState s)]
   -> [MenuElement s (IOState s)];
InsertInThisGroup index elems [item]
   | index <= 1   =  Append elems item;
   =  [item : elems];
InsertInThisGroup index elems [item1, item2]
   | index <= 1   =  Append (InsertInThisGroup index elems [item1]) item2;
   | index  == 2                          #!
		strict1=strict1;
		=
		[item1 : strict1];
   #!
		strict2=strict2;
		=
		[item1 : strict2];
	where {
	strict2=InsertInThisGroup index elems [item2];
		
	strict1=Append elems item2;
		};
InsertInThisGroup index elems [item : items]
   | index <= 1    =  Concat (InsertInThisGroup index elems [item]) items;
   #!
		strict1=strict1;
		=
		[item : strict1];
	where {
	strict1=InsertInThisGroup (dec index) elems items;
		
	};
InsertInThisGroup index elems items 
   =  elems;

DelFromGroupIndex :: !MenuItemGroupId ![Int] !(DeviceSystemState s)
   -> DeviceSystemState s;
DelFromGroupIndex id indexes (MenuSystemState w (keys, menuhandles, able))
   #!
      strict1=DelFromGroup id indexes menuhandles keys;
   #
      (keys`,menuhandles`,b)= strict1;
		=
		MenuSystemState w (keys`, menuhandles`, able);

DelFromGroup :: !MenuItemGroupId ![Int] ![MenuHandle s (IOState s)]
      ![KeyShortcut]
   -> MenuHandles s (IOState s);
DelFromGroup id indexes [menu=:PullDownHandle ability xh items : menus] keys
   #! strict2=DelFromGroup` id indexes items keys;
   #  (ready, keys`, items`)= strict2;
   | ready
		=
		(keys`,  [PullDownHandle ability xh items` : menus], True);
   #!
      strict1=DelFromGroup  id indexes menus keys;
   #  (keys``, menus`, b)   = strict1;
		=
		(keys``, [menu : menus`], True);
DelFromGroup id indexes menus keys =  (keys, menus, True);

DelFromGroup` :: !MenuItemGroupId ![Int] ![MenuItemHandle s (IOState s)] 
      ![KeyShortcut]
   -> (!Bool, ![KeyShortcut], ![MenuItemHandle s (IOState s)]);
DelFromGroup` id indexes [item=: MenuItemGroupHandle (id`,w) els : items] keys
   | id == id`
	#!	strict6=ReconstructMenuElements els keys;

    #  (keys1, els``)        = strict6;
	#!	els``=els``;
		strict5=ReconstructMenuElements items keys1;
    #  (keys2, reitems)      = strict5;
    #! strict3=(DelFromThisGroup 1 indexes els``);
    #  (keys3, els`)         = AddXGroupItemHandles keys2 w 
                                   strict3;
	#!	els`=els`;
    #  (keys4, reitems`)     = CreateXMenuItemHandles keys3 w reitems;
	#!	reitems`=reitems`;
		=
		(True,  keys4, [MenuItemGroupHandle (id`,w) els` : reitems`]);
   #!
		strict7=DelFromGroup` id indexes items keys;
   #   (ready, keys5, result)= strict7;
		=
		(ready, keys5, [item : result]);
DelFromGroup` id indexes [item : items] keys
   #!
      strict1=DelFromGroup` id indexes items keys;
   #
      (ready, keys`, items`)= strict1;
		=
		(ready, keys`, [item : items`]);
DelFromGroup` id indexes items keys =  (False, keys, items);

DelFromThisGroup :: !Int ![Int] ![MenuElement s (IOState s)]
   -> [MenuElement s (IOState s)];
DelFromThisGroup index indexes [item : items]
   | IdListContainsId indexes index =  DelFromThisGroup index` indexes items;
   #!
		strict1=strict1;
		=
		[item : strict1];
      where {
      index`=: inc index;
      strict1=DelFromThisGroup index` indexes items;
		};
DelFromThisGroup index indexes items =  items;

DelFromGroups :: ![MenuItemId] !(DeviceSystemState s) -> DeviceSystemState s;
DelFromGroups ids (MenuSystemState w (keys, menuhandles, able))
   #!
		strict1=strict1;
		=
		MenuSystemState w strict1;
	where {
	strict1=(DelFromGroups` ids menuhandles keys able);
		
	};

DelFromGroups` :: ![MenuItemId] ![MenuHandle s (IOState s)] ![KeyShortcut] !Bool
   -> MenuHandles s (IOState s);
DelFromGroups` ids [menu=: PullDownHandle ability xh items : menus] keys able
   #!	strict3=DelFromGroups`` ids items keys;
   #   (keys``,items`)   = strict3;
   #!
      strict2=DelFromGroups`  ids menus keys`` able;
   #   (keys`, menus`, b)= strict2;
		items`=items`;
		=
		(keys`, [PullDownHandle ability xh items` : menus`], able);
DelFromGroups` ids menus keys able =  (keys, menus, able);

DelFromGroups`` :: ![MenuItemId] ![MenuItemHandle s (IOState s)] ![KeyShortcut]
   -> (![KeyShortcut], ![MenuItemHandle s (IOState s)]);
DelFromGroups`` ids [MenuItemGroupHandle (id`,w) els : items] keys
   #!
		strict7=ReconstructMenuElements els keys;
   #   (keys1, els``)   = strict7;
	#!	els``=els``;
		strict6=ReconstructMenuElements items keys1;
   #   (keys2, reitems) = strict6;
	#!	strict4=(RemoveFromThisGroup ids els``);
    #  (keys3, els`)    = AddXGroupItemHandles keys2 w 
                             strict4;
	#!	els`=els`;
    #  (keys4, reitems`)= CreateXMenuItemHandles keys3 w reitems;
    #!  strict3=DelFromGroups`` ids reitems` keys4;
    #  (keys5, items`)  = strict3;
	#!	items`=items`;
		=
		(keys5, [MenuItemGroupHandle (id`,w) els` : items`]);
DelFromGroups`` ids [item : items] keys
   #!
      strict1=DelFromGroups`` ids items keys;
   #
      (keys`, items`)= strict1;
		=
		(keys`, [item : items`]);
DelFromGroups`` ids items keys =  (keys, items);

RemoveFromThisGroup :: ![MenuItemId] ![MenuElement s (IOState s)]
   -> [MenuElement s (IOState s)];
RemoveFromThisGroup ids [item=: MenuItem id s k a f : items]
   | IdListContainsId ids id =  RemoveFromThisGroup ids items;
   #!
		strict1=strict1;
		=
		[item : strict1];
	where {
	strict1=RemoveFromThisGroup ids items;
		
	};
RemoveFromThisGroup ids [item=: CheckMenuItem id s k a m f : items]
   | IdListContainsId ids id =  RemoveFromThisGroup ids items;
   #!
		strict1=strict1;
		=
		[item: strict1];
	where {
	strict1=RemoveFromThisGroup ids items;
		
	};
RemoveFromThisGroup ids [item : items]
   #!
		strict1=strict1;
		=
		[item : strict1];
	where {
	strict1=RemoveFromThisGroup ids items;
		
	};
RemoveFromThisGroup ids items =  items;

ReconstructMenuElements :: ![MenuItemHandle s (IOState s)] ![KeyShortcut]
   -> (![KeyShortcut], ![MenuElement s (IOState s)]);
ReconstructMenuElements [ItemHandle (id,w) f : items] keys 
   #
      info            = get_item_info w;
      (keys` , item  )= ConvertItemHandle info id f keys;
   #!
		strict2=ReconstructMenuElements items keys`;
   #    (keys``, items`)= strict2;
   #!
      strict1=DestroyOld item w;
		=
		(keys``, [strict1 : items`]);
ReconstructMenuElements [MenuSeparatorHandle w : items] keys
   #!
		strict2=ReconstructMenuElements items keys;
   #   (keys`, items`)= strict2;
   #!   strict1=DestroyOld MenuSeparator w;
		=
		(keys`, [strict1 : items`]);
ReconstructMenuElements [SubMenuHandle (id,w) handles : items] keys
   #!
		strict3=ReconstructMenuElements handles keys;
    #  (keys` , subitems)= strict3;
	#!	strict2=ReconstructMenuElements items keys`;
   #   (keys``, items`  )= strict2;
      (title, ability)  = get_submenu_info w;
      ability`          = if (ability == 0) Unable Able;
   #!   strict1=DestroyOld (SubMenuItem id title ability` subitems) w;
		=
		(keys``, [strict1 : items`]);
ReconstructMenuElements [MenuItemGroupHandle (id,w) handles : items] keys
   #!
		strict2=ReconstructMenuElements handles keys;
   #
      (keys` , subitems)= strict2;
   #!
      strict1=ReconstructMenuElements items keys`;
   #
      (keys``, items`  )= strict1;
		=
		(keys``, [MenuItemGroup id subitems : items`]);
ReconstructMenuElements [RadioHandle id radios : items] keys
   #!
		strict2=ReconstructRadioElements 0 radios keys;
   #
      (did, keys`, radios`)= strict2;
   #!
      strict1=ReconstructMenuElements items keys`;
   #
      (keys``, items`)     = strict1;
		=
		(keys``, [MenuRadioItems did radios` : items`]);
ReconstructMenuElements items keys =  (keys, []);

ReconstructRadioElements :: !Int ![RadioMenuItemHandle s (IOState s)]
      ![KeyShortcut]
   -> (!Int, ![KeyShortcut], ![RadioElement s (IOState s)]);
ReconstructRadioElements did [RadioItemHandle (id,w) f : items] keys
   #!
      info                  = get_item_info w;
		strict3=ConvertRadioItemHandle info id f keys;
    #  (id` , keys` , item  )= strict3;
	#!	strict2=ReconstructRadioElements id` items keys`;
   #   (id``, keys``, items`)= strict2;
    #!  strict1=DestroyOld item w;
		=
		(id``, keys``, [strict1 : items`]);
ReconstructRadioElements did items keys =  (did, keys, []);

DestroyOld :: !x !Widget -> x;
DestroyOld x w =  Evaluate_2 x (destroy_item_widget w);

ConvertItemHandle :: !(!Int, !Int, !String, !String) !Int
      !(MenuFunction s (IOState s)) ![KeyShortcut]
   -> (![KeyShortcut], MenuElement s (IOState s));
ConvertItemHandle (ability,-1,title,key) id f keys
   =  (keys`, MenuItem id title key` ability` f);
      where {
      keys`   =: RemoveKey key` keys;
      key`    =: if (key == "") NoKey (Key (key.[0]));
      ability`=: if (ability == 0) Unable Able;
      };
ConvertItemHandle (ability,state,title,key) id f keys
   =  (keys`, CheckMenuItem id title key` ability` state` f);
      where {
      keys`   =: RemoveKey key` keys;
      key`    =: if (key == "") NoKey (Key (key.[0]));
      ability`=: if (ability == 0) Unable Able;
      state`  =: if (state == 0) NoMark Mark;
      };

ConvertRadioItemHandle :: !(!Int, !Int, !String, !String) !Int
      !(MenuFunction s (IOState s)) ![KeyShortcut]
   -> (!Int, ![KeyShortcut], RadioElement s (IOState s));
ConvertRadioItemHandle (ability,state,title,key) id f keys
   | state == 1 =  (id, keys`, radio);
   =  (0,  keys`, radio);
      where {
      keys`   =: RemoveKey key` keys;
      key`    =: if (key == "") NoKey (Key (key.[0]));
      ability`=: if (ability == 0) Unable Able;
      radio=:MenuRadioItem id title key` ability` f;
		};


/* Controlling the appearance of menus and items.
*/
CheckXWidget :: !Widget !MarkState -> Widget;
CheckXWidget w Mark =  check_widget w XMark ;
CheckXWidget w NoMark =  check_widget w XNoMark;

SetWidgetAbility :: !Widget !SelectState -> Widget;
SetWidgetAbility w Able =  enable_menu_widget w ;
SetWidgetAbility w Unable =  disable_menu_widget w;

SetMenuAbility :: !Widget !SelectState -> Widget;
SetMenuAbility w state =  SetWidgetAbility w state;


/* Disposing a MenuSystem, i.e. destroying the corresponding widgettree!
*/
DisposeMenuSystemState :: !(DeviceSystemState s) -> DeviceSystemState s;
DisposeMenuSystemState (MenuSystemState w handles)
   =  Evaluate_2 (MenuSystemState 0 ([],[],True)) (destroy_menu w);

/* (Un)drawing a MenuSystem (menubar),i.e. (un)managing widgets.
*/
ClearMenuSystem :: !(DeviceSystemState s) -> DeviceSystemState s;
ClearMenuSystem h=:(MenuSystemState w handles) =  Evaluate_2 h (hide_menu w);

DrawMenuSystem :: !(DeviceSystemState s) -> DeviceSystemState s;
DrawMenuSystem h=:(MenuSystemState w handles) =  Evaluate_2 h (show_menu w);


/* Installing key shortcuts.
*/
InstallKeyShortcut :: !Widget !KeyShortcut -> Widget;
InstallKeyShortcut w (Key c) =  install_shortcut w (toString c);
InstallKeyShortcut w key =  w;

AddKey :: !KeyShortcut ![KeyShortcut] -> [KeyShortcut];
AddKey NoKey keys =  keys;
AddKey key keys =  [key : keys];

CorrectKeyShortcut :: !KeyShortcut ![KeyShortcut] -> KeyShortcut;
CorrectKeyShortcut key=:(Key c) [Key c` : keys]
   | c == c` =  NoKey;
   =  CorrectKeyShortcut key keys;
CorrectKeyShortcut key keys =  key;

RemoveKey :: !KeyShortcut ![KeyShortcut] -> [KeyShortcut];
RemoveKey k=:(Key c) [k`=:Key c` : keys]
   | c == c` =  keys;
   #!
		strict1=strict1;
		=
		[k` : strict1];
	where {
	strict1=RemoveKey k keys;
		
	};
RemoveKey key keys =  keys;

IdListContainsId :: ![Int] !Int -> Bool;
IdListContainsId [id` : ids] id
      | id` == id=  True; 
   =  IdListContainsId ids id;
IdListContainsId ids id =  False;

