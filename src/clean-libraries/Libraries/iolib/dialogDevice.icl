implementation module dialogDevice;

import StdClass; // RWS
import StdBool, StdChar, StdInt, StdString, StdReal;
import xkernel,xtypes, deltaIOSystem, xdialog;
import ioState, dialogDef;

from xwindow import get_mouse_state;
from xwindow import popdown;
from windowDevice import EventToMouse,Draw_in_window;
from picture import NewXPicture;
import misc, commonDef;


     

XModalCommandDialog		:== 0;
XModelessCommandDialog	:== 1;

XGroupRows		:== 0;
XGroupColumns	:== 1;

XMarkOn			:== 0;
XMarkOff			:== 1;

XCControl		:== 0;
XCIcon			:== 1;


PictureNormal pic :== [SetPenNormal, SetPenColour BlackColour, 
                      SetBackColour WhiteColour, EraseRectangle pic];
PictureNormalF :== [SetPenNormal, SetPenColour BlackColour,
                   SetBackColour WhiteColour];

DummyDialHandle :== DialHandle Modeless (0,0) [] DummyDialogDef;
DummyDialogDef  :== CommandDialog 0 "" [] 0 [];


    

DialogFunctions ::    DeviceFunctions s;
DialogFunctions
   = (ShowDialog,OpenDialogDevice,DialogIO,CloseDialogDevice, HideDialog);


/* Closing the entire dialog device.
*/
CloseDialogDevice :: !(IOState s) -> IOState s;
CloseDialogDevice io
   =  UEvaluate_2 (IOStateRemoveDevice io` DialogDevice)
                  (Close_dialogs dialogs);
      where {
      (dialogs, io`)=: IOStateGetDevice io DialogDevice;
      };

Close_dialogs :: !(DeviceSystemState s) -> DeviceSystemState s;
Close_dialogs (DialogSystemState dialogs) 
   #!
		strict1=strict1;
		=
		DialogSystemState strict1;
	where {
	strict1=(Close_dialogs` dialogs);
		
	};

Close_dialogs` :: ![DialogHandle s io] -> [DialogHandle s io];
Close_dialogs`  [dialog : dialogs]
   =  Evaluate_2 (Close_dialogs` dialogs) (Close_dialog dialog);
Close_dialogs` dialogs =  dialogs;

Close_dialog :: !(DialogHandle s io) -> Widget;
Close_dialog (DialHandle m (id, w) handle def) =  destroy_dialog w;


HideDialog :: !(IOState s) -> IOState s;
HideDialog io_state
   =  IOStateSetDevice io_state` dialog`;
      where {
      dialog`            =: HideDialog` dialog;
      (dialog, io_state`)=: IOStateGetDevice io_state DialogDevice;
      };

HideDialog` :: !(DeviceSystemState s) -> DeviceSystemState s;
HideDialog` (DialogSystemState dialogs)
   #!
		strict1=strict1;
		=
		DialogSystemState strict1;
	where {
	strict1=(HideDialog`` dialogs);
		
	};

HideDialog`` :: ![DialogHandle s (IOState s)] -> [DialogHandle s (IOState s)];
HideDialog`` [DialHandle m (id,w) items def : dialogs]
   #!
		strict1=strict1;
		strict2=strict2;
		=
		[DialHandle m (id,strict1) items def : strict2];
	where {
	strict1=popdown_dialog w;
		strict2=HideDialog`` dialogs;
		
	};
HideDialog`` dialogs =  dialogs;


ShowDialog :: !(IOState s) -> IOState s;
ShowDialog io_state
   =  IOStateSetDevice io_state` dialog`;
      where {
      dialog`            =: ShowDialog` dialog;
      (dialog, io_state`)=: IOStateGetDevice io_state DialogDevice;
      };

ShowDialog` :: !(DeviceSystemState s) -> DeviceSystemState s;
ShowDialog` (DialogSystemState dialogs)
   #!
		strict1=strict1;
		=
		DialogSystemState strict1;
	where {
	strict1=(ShowDialog`` dialogs);
		
	};

ShowDialog`` :: ![DialogHandle s (IOState s)] -> [DialogHandle s (IOState s)];
ShowDialog`` [h=:DialHandle Modal w items (CommandDialog id t a di items`) : dialogs]
   #!
		strict1=strict1;
		strict2=strict2;
		=
		[strict1 : strict2];
	where {
	strict1=PopupModalDialog h;
		strict2=ShowDialog`` dialogs;
		
	};
ShowDialog`` [dialog : dialogs]
   #!
		strict1=strict1;
		strict2=strict2;
		=
		[strict1 : strict2];
	where {
	strict1=PopupModelessDialog dialog;
		strict2=ShowDialog`` dialogs;
		
	};
ShowDialog`` dialogs =  dialogs;


/* Opening the dialog device at start up.
*/
OpenDialogDevice :: !(DeviceSystem s (IOState s)) !(IOState s) -> IOState s;
OpenDialogDevice (DialogSystem dialog_defs) io_state
   #!
		strict1=strict1;
		=
		IOStateSetDevice io_state (DialogSystemState strict1);
	where {
	strict1=(Open_dialogs dialog_defs);
		
	};

Open_dialogs :: ![DialogDef s (IOState s)] -> DialogHandles s (IOState s);
Open_dialogs [dialog=:CommandDialog id t a di items : dialogs]
   #!
		strict1=strict1;
		strict2=strict2;
		=
		[strict1 : strict2];
	where {
	strict1=Open_dialog Modeless dialog;
		strict2=Open_dialogs dialogs;
		
	};
Open_dialogs [dialog=:PropertyDialog id t a f1 f2 items : dialogs]
   #!
		strict1=strict1;
		strict2=strict2;
		=
		[strict1 : strict2];
	where {
		strict1=Open_dialog Modeless dialog;
		strict2=Open_dialogs dialogs;
	};
Open_dialogs [dialog=:AboutDialog appname pic=:((x0,y0),(x1,y1)) dfs help : dialogs]
	| x0==x1 && y0==y1
		#! r=set_toplevelname appname;
		= Open_dialogs (Evaluate_2 (RemoveAbouts dialogs) r);
		#!
			strict1=Open_about dialog;
			strict2=Open_dialogs (RemoveAbouts dialogs);
		  =
			[strict1 : strict2];
Open_dialogs [dialog : dialogs] 
   =  Open_dialogs dialogs;
Open_dialogs dialogs =  [];

RemoveAbouts :: ![DialogDef s (IOState s)] -> [DialogDef s (IOState s)];
RemoveAbouts [AboutDialog appname pic dfs help : dialogs]
   =  RemoveAbouts dialogs;
RemoveAbouts [dialog : dialogs]
   #!
		strict1=strict1;
		=
		[dialog : strict1];
	where {
		strict1=RemoveAbouts dialogs;
	};
RemoveAbouts dialogs =  dialogs;

Open_about :: !(DialogDef s (IOState s)) -> DialogHandle s (IOState s);
Open_about def=:(AboutDialog appname ((x0,y0),(x1,y1)) dfs NoHelp)
   #!
		about=about;
		=
		Evaluate_2 (DialHandle Modal (-1, about) [] def)
                 (set_toplevelname appname);
      where {
      about=: create_about_dialog x0 y0 x1 y1 0 "";
      };
Open_about def=:(AboutDialog appname ((x0,y0),(x1,y1)) dfs
                  (AboutHelp title f))
   #!
		about=about;
		=
		Evaluate_2 (DialHandle Modal (-1, about) [] def)
                 (set_toplevelname appname);
      where {
      about=: create_about_dialog x0 y0 x1 y1 1 title;
      };

Open_dialog :: !DialogMode !(DialogDef s (IOState s)) -> DialogHandle s (IOState s);
Open_dialog Modal def=:(CommandDialog id title att ditem items)
   #!
		strict1=strict1;
		=
		PopupModalDialog (strict1);
	where {
	strict1=OpenNormalDialog Modal def;
		
	};
Open_dialog modeless def=:(CommandDialog id title att ditem items)
   #!
		strict1=strict1;
		=
		PopupModelessDialog (strict1);
	where {
	strict1=OpenNormalDialog Modeless def;
		
	};
Open_dialog mode def=:(PropertyDialog id title att f1 f2 items)
   #!
		strict1=strict1;
		=
		PopupModelessDialog (strict1);
	where {
	strict1=OpenNormalDialog Modeless def;
		
	};

PopupModalDialog :: !(DialogHandle s (IOState s)) -> DialogHandle s (IOState s);
PopupModalDialog (DialHandle m (id,w) items def)
   #!
		strict1=strict1;
		=
		DialHandle Modal (id, strict1) items def;
	where {
	strict1=popup_modaldialog w;
		
	};

PopupModelessDialog :: !(DialogHandle s (IOState s))
   -> DialogHandle s (IOState s);
PopupModelessDialog (DialHandle m (id,w) items def)
   #!
		strict1=strict1;
		=
		DialHandle Modeless (id, strict1) items def;
	where {
	strict1=popup_modelessdialog w;
		
	};

OpenNormalDialog :: !DialogMode !(DialogDef s (IOState s)) -> DialogHandle s (IOState s);
OpenNormalDialog mode def=:(CommandDialog id title att ditem items)
   #!
		strict3=GetDialogSize att;
   #  (width,height)= strict3;
   #!  command= create_commanddial title width height (GetDialogMode mode);
		strict2=(AddDialogItems command items);

      items` = PositionItems command att items strict2;
      defitem= GetCommandDefaultItem ditem items`;
      strict1=set_command_default command defitem;
		=
		DialHandle mode (id, strict1) items` def;
OpenNormalDialog mode def=:(PropertyDialog id title att f1 f2 items)
   #!
		strict2=GetDialogSize att;
   #  (width,height)= strict2;
   #! property= create_propertydial title width height;
      strict1=(AddDialogItems property items);
      items`  = PositionItems property att items strict1;
		=
		DialHandle mode (id, property) items` def;

GetDialogMode :: DialogMode -> Int; 
GetDialogMode Modal =  XModalCommandDialog;
GetDialogMode x     =  XModelessCommandDialog;

GetDialogSize :: ![DialogAttribute] -> (!Int, !Int);
GetDialogSize [DialogSize w h : rest] =  (ConvertMeasureX w,ConvertMeasureY h);
GetDialogSize [att : rest] =  GetDialogSize rest;
GetDialogSize atts =  (0,0);

ConvertMeasureX :: Measure -> Int;
ConvertMeasureX (Pixel n) =  n;
ConvertMeasureX (MM    n) =  mm_to_pixel_hor n;
ConvertMeasureX (Inch  n) =  mm_to_pixel_hor (n * 25.4);
  
ConvertMeasureY :: Measure -> Int;
ConvertMeasureY (Pixel n) =  n;
ConvertMeasureY (MM    n) =  mm_to_pixel_ver n;
ConvertMeasureY (Inch  n) =  mm_to_pixel_ver(n * 25.4);


AddDialogItems :: !Widget ![DialogItem s io] -> [XDItemHandle];
AddDialogItems dialog [DialogButton id layout title state f : items]
   #!
      item= add_dialog_button dialog 0 0 0 0 title;
      strict1=SetDialogItemAbility item state;
		strict2=AddDialogItems dialog items;
		=
		[(id, strict1) : strict2];
AddDialogItems dialog [StaticText id layout text : items]
   #!
		strict1=strict1;
		strict2=strict2;
		=
		[(id, strict1) : strict2];
	where {
	strict1=add_static_text dialog 0 0 0 0 text;
		strict2=AddDialogItems dialog items;
		
	};
AddDialogItems dialog [DynamicText id itempos width text : items]
   #!
		strict1=strict1;
		strict2=strict2;
		=
		[(id, strict1) : strict2];
	where {
	strict1=add_static_text dialog 0 0 (ConvertMeasureX width) 0 text;
		strict2=AddDialogItems dialog items;
		
	};
AddDialogItems dialog [EditText id layout width lines text : items]
   #!
		strict1=strict1;
		strict2=strict2;
		=
		[(id, strict1) : strict2];
	where {
		strict1=add_edit_text dialog 0 0 (ConvertMeasureX width) 0 lines text;
		strict2=AddDialogItems dialog items;
		
	};
AddDialogItems dialog [DialogPopUp id layout state rid radios : items]
   #  rid`    = CheckDefaultRadioId rid radios; 
   #!
      popup   = add_dialog_popup dialog 0 0 0 0;
      popup`=SetDialogItemAbility popup state;
      radios` = AddDialogRadioItems (get_popup_ex popup`) dialog rid` radios;
      radios``= CorrectPopupSize radios` popup`;
		strict2=(AddDialogItems dialog items);
		strict1=Concat radios`` strict2;
		=
		[(id, popup`) :
        strict1];
AddDialogItems dialog [RadioButtons id layout roc rid radios : items]
   #  rid`     = CheckDefaultRadioId rid radios; 
   #!	strict3=ConvertROC roc;
   #
      (roc`, n)= strict3;
   #! group    = add_dialog_exclusives dialog 0 0 0 0 roc` n;
   #! radios`  = AddDialogRadioItems group dialog rid` radios;
      strict2=(AddDialogItems dialog items);
		strict1=Concat radios` strict2;
		=
		[(id, group) : strict1];
AddDialogItems dialog [CheckBoxes id layout roc checks : items]
   #!	strict3=ConvertROC roc;
   #  (roc`, n)= strict3;
   #!
      group    = add_dialog_nonexclusives dialog 0 0 0 0 roc` n;
      checks`  = AddDialogCheckItems group dialog checks;
      strict2=(AddDialogItems dialog items);
		strict1=Concat checks` strict2;
		=
		[(id, group) : strict1];
AddDialogItems dialog [Control id layout ((x0,y0),(x1,y1)) state cstate
                                  look feel f : items]
   #!
		strict1=strict1;
		control=control;
		=
		[(id, control) : strict1];
      where {
      control=: add_dialog_control dialog 0 0 width height x0 y0 XCControl;
      width  =: x1 - x0;
      height =: y1 - y0;
      strict1=AddDialogItems dialog items;
		};
AddDialogItems dialog [DialogIconButton id pos ((x0,y0),(x1,y1)) look state f
                         : items]
   #!
		strict1=strict1;
		control=control;
		=
		[(id, control) : strict1];
      where {
      control=: add_dialog_control dialog 0 0 width height x0 y0 XCIcon;
      width  =: x1 - x0;
      height =: y1 - y0;
      strict1=AddDialogItems dialog items;
		};
AddDialogItems dialog [] =  [];

ConvertROC :: !RowsOrColumns -> (!Int, !Int);
ConvertROC (Rows r)    =  (XGroupRows, r);
ConvertROC (Columns c) =  (XGroupColumns, c);

ConvertMark :: !MarkState -> Int;
ConvertMark Mark   =  XMarkOn;
ConvertMark NoMark =  XMarkOff;

SetDialogItemAbility :: !Widget !SelectState -> Widget;
SetDialogItemAbility w Able =  enable_dialog_item w;
SetDialogItemAbility w Unable =  disable_dialog_item w;

CorrectPopupSize :: ![XDItemHandle] !Widget -> [XDItemHandle];
CorrectPopupSize radios popup 
   =  Evaluate_2 radios (correct_popup_size popup);

CheckDefaultRadioId :: !Id ![RadioItemDef s io] -> Id;
CheckDefaultRadioId rid radios=:[RadioItem id t s f : rest`]
   =  CheckDefaultRadioId` rid id radios;
CheckDefaultRadioId rid [] =  rid;

CheckDefaultRadioId` :: !Id !Id ![RadioItemDef s io] -> Id;
CheckDefaultRadioId` rid first [RadioItem id t s f : radios]
   | id == rid =  rid;
   =  CheckDefaultRadioId` rid first radios;
CheckDefaultRadioId` rid first [] =  first;

AddDialogRadioItems :: !Widget !Widget !Id ![RadioItemDef s io]
   -> [XDItemHandle];
AddDialogRadioItems group dialog rid [RadioItem id title state f : radios]
   | id == rid #!
      radio1=  add_dialog_radiob group dialog title XMarkOn;
		strict1=SetDialogItemAbility radio1 state;
	#!	radios`=radios`;
		=
		[(id, strict1) : radios`];
   #!
      radio2=  add_dialog_radiob group dialog title XMarkOff;
      strict3=SetDialogItemAbility radio2 state;
	#!	radios`=radios`;
		=
		[(id, strict3) : radios`];
      where {
      radios`=: AddDialogRadioItems group dialog rid radios;
		};
AddDialogRadioItems g d rid [] =  [];

AddDialogCheckItems :: !Widget !Widget ![CheckBoxDef s io]
   -> [XDItemHandle];
AddDialogCheckItems group dialog [CheckBox id title state mark f : radios]
   #!
		strict1=strict1;
		check=check;
		checks=checks;
		=
		[(id, strict1) : checks];
      where {
      check=:  add_dialog_checkb group dialog title (ConvertMark mark);
      checks=: AddDialogCheckItems group dialog radios;
      strict1=SetDialogItemAbility check state;
		};
AddDialogCheckItems g d [] =  [];

DoModalDialog	:: !*s !(IOState *s) -> (!*s, !IOState *s);
DoModalDialog s io
	| not active || dev <> XDialogDevice =  (s,io`);
	| not the_one =  DoModalDialog s  io`;
	=  DoModalDialog s` io``;
		where {
		(s`,io``)                  =: DialogIO` [dialog] (get_dialog_event e) s io`;
		(active,the_one,dialog,io`)=: GetActiveModalDialogHandle w io;
		(w,dev,e)                  =: GetNextEvent;
		};

GetActiveModalDialogHandle	:: !Int !(IOState s)
	-> (!Bool, !Bool, !DialogHandle s (IOState s), !IOState s);
GetActiveModalDialogHandle widget io =  (active,the_one,handle,io`);
		where {
		(active,the_one,handle)=: GetActiveModalFromDevice widget device;
		(device,io`)           =: IOStateGetDevice io DialogDevice;
		};

GetActiveModalFromDevice	:: !Int !(DeviceSystemState s)
	                         -> (!Bool, !Bool, !DialogHandle s (IOState s));
GetActiveModalFromDevice widget (DialogSystemState dialogs)
	=  GetActiveModalDialog False widget dialogs;

GetActiveModalDialog	:: !Bool !Int ![DialogHandle s (IOState s)]
	                         -> (!Bool, !Bool, !DialogHandle s (IOState s));
GetActiveModalDialog modal widget [active=:DialHandle Modal (i,w) b d : rest]
	| w == widget =  (True,True,active);
	=  GetActiveModalDialog True widget rest;
GetActiveModalDialog modal widget [active : rest]
	=  GetActiveModalDialog modal widget rest;
GetActiveModalDialog modal widget [] =  (modal, False, DummyDialHandle);

DialogIO :: !Event !*s !(IOState *s) -> (!Bool, !*s, !IOState *s);
DialogIO (w, XDialogDevice, e) s io_state
   #!
      strict2=get_dialog_event e;
      strict3=GetDialogHandle io_state w;
   #  (dialog,io``)= strict3;
   #! strict1=DialogIO` dialog (strict2) s io``;
   #  (s`, io`)= strict1;
		=
		(True, s`, io`);
DialogIO no_dialog_event s io_state =  (False, s, io_state);

DialogIO` :: ![DialogHandle *s (IOState *s)] !DialogEvent !*s !(IOState *s)
   -> (!*s, !IOState *s);
DialogIO` [dialog] event s io
   =  DialogIO`` (ReconstructDialogHandle dialog) event s io;
DialogIO` [] event s io =  (s, io);

DialogIO`` :: !(DialogHandle *s (IOState *s)) !DialogEvent !*s !(IOState *s)
   -> (!*s, !IOState *s);
DialogIO`` (DialHandle m (id,w) items def) (XDialogButton, item) s io
   =  f (DDef2DInfo def) s io;
      where {
      f=: GetButtonFunction (GetDialogItemId item items) def;
      };
DialogIO`` (DialHandle m (id,w) items def) (XDialogClosed, item) s io
   #!
		strict1=strict1;
		=
		UEvaluate_2 (s,strict1) (destroy_dialog w);
	where {
	strict1=RemoveDialogHandle w io;
		
	};
DialogIO`` h=:(DialHandle m (id,w) items def) (XDialogRadioButton, item) s io
   #!
		dstate=dstate;
		=
		(s, ChangeDialogHandle id (DState2DHandle dstate) io);
      where {
      dstate=: f (DDef2DInfo def) (DHandle2DState h);
      f=: GetDialogRadioFunction (GetDialogItemId item items) def;
      };
DialogIO`` h=:(DialHandle m (id,w) items def) (XDialogCheckButton, item) s io
   #!
		dstate=dstate;
		=
		(s, ChangeDialogHandle id (DState2DHandle dstate) io);
      where {
      dstate=: f (DDef2DInfo def) (DHandle2DState h);
      f=: GetDialogCheckFunction (GetDialogItemId item items) def;
      };
DialogIO`` (DialHandle m (id,w) items def) (XDialogRedraw, item) s io
   #!
		drawfs=drawfs;
		=
		(s, DrawInControl item (Concat (PictureNormal pic) drawfs) io);
      where {
      drawfs=: f state cs;
      (state,f,cs,pic)=: GetDialogControlLook (GetDialogItemId item items) def;
      }; 
DialogIO`` (DialHandle m (id,w) items def) (XDialogIRedraw, item) s io
   #!
		drawfs=drawfs;
		=
		(s, DrawInControl item (Concat (PictureNormal pic) drawfs) io);
      where {
      drawfs=: f able;
      (able,f,pic)=: GetDialogIconLook (GetDialogItemId item items) def;
      };
DialogIO`` handle=:(DialHandle m (id,w) items def) (XDialogMouse, item) s io
   #!
	      cid= GetDialogItemId item items;
   #  (able,f,cs)= GetDialogControlFeel cid def;
   | able
		#!	cs=cs;
	      cid= GetDialogItemId item items;
	      mouse=EventToMouse (get_mouse_state item);
		#  (cs`, drawfs)= f mouse cs;
		#! drawfs=drawfs;
		   cs`=cs`;
		#  f2= GetDialogControlFunction cid def;
	   #!
	      io`= DrawInControl item (Concat PictureNormalF drawfs) io;
	      handle`= ChangeControlState handle cid cs`;
	      strict5=DHandle2DState handle`;
	      dstate= f2 (DDef2DInfo def) (strict5);
		  strict2=DState2DHandle dstate;
		  strict1=ChangeDialogHandle id (strict2) io`;
		=
		(s, strict1);
		=
		(s, io);
DialogIO`` handle=:(DialHandle m (id,w) items def) (XDialogIMouse, item) s io
   =  HandleIconSelection items def item mouse s io;
      where {
      mouse=: EventToMouse (get_mouse_state item);
      };
DialogIO`` (DialHandle m (id,w) items def) (XDialogApply, item) s io
   =  f (DDef2DInfo def) s io;
      where {
      f=: GetDialogApplyFunction def;
      };
DialogIO`` (DialHandle m (id,w) items def) (XDialogReset, item) s io
   =  f (DDef2DInfo def) s io;
      where {
      f=: GetDialogResetFunction def;
      };
DialogIO`` dialog (XDialogActivate, item) s io
   #!
		strict1=strict1;
		=
		(s, strict1);
	where {
	strict1=MakeActiveDialog dialog io;
		
	};
DialogIO`` (DialHandle m (id,w) items (AboutDialog appname pic dfs help))
              (XAboutRedraw, item) s io
   =  (s, DrawInControl w (Concat (PictureNormal pic) dfs) io);
DialogIO`` (DialHandle m (id,w) items def=:(AboutDialog a p d (AboutHelp h f)))
              (XAboutHelp, item) s io
   =  f s io;

HandleIconSelection :: ![XDItemHandle] !(DialogDef *s (IOState *s)) !Widget
      !MouseState !*s !(IOState *s)
	-> (!*s, !IOState *s);
HandleIconSelection items def w (x,ButtonDown,m) state io
   | able =  (state, DrawInControl w [InvertRectangle pic] io);
   =  (state, io);
      where {
      (able,f,pic)=: GetDialogIconFunction (GetDialogItemId w items) def;
      };
HandleIconSelection items def w (x,ButtonUp,m) state io
   | able #!
		io`=io`;
		=
		f (DDef2DInfo def) state io`;
   #!
		io`=io`;
		=
		(state,io); 
      where {
      io`=: DrawInControl w [InvertRectangle pic] io;
      (able,f,pic)=: GetDialogIconFunction (GetDialogItemId w items) def;
      };
HandleIconSelection items def w mouse state io
   =  (state, io);

DrawInControl :: !Widget ![DrawFunction] !(IOState s) -> IOState s;
DrawInControl control dfs io
   #!
		strict1=strict1;
		=
		UEvaluate_2 io (Draw_in_window (1,strict1) (0,0) dfs);
	where {
	strict1=NewXPicture (dialog_item_to_object control);
		
	};

// IsModalDialog !(DialogDef s (IOState s)) -> BOOL;
// IsModalDialog (CommandDialog id t Modal a di i) -> TRUE;
// IsModalDialog def -> FALSE;

GetDialogItemId :: !Widget ![XDItemHandle] -> Id;
GetDialogItemId w [(id, w`) : items]
   | w == w` =  id;
   =  GetDialogItemId w items;
GetDialogItemId w [] =  0;

GetButtonFunction :: !Id !(DialogDef s (IOState s))
   -> ButtonFunction s (IOState s);
GetButtonFunction id (CommandDialog did t a di items)
   =  GetButtonFunction` id items;
GetButtonFunction id (PropertyDialog i t a f1 f2 items)
   =  GetButtonFunction` id items;

GetButtonFunction` :: !Id ![DialogItem s (IOState s)]
   -> ButtonFunction s (IOState s);
GetButtonFunction` id [DialogButton id2 l t s f : items]
   | id == id2 =  f;
   =  GetButtonFunction` id items;
GetButtonFunction` id [item : items]
   =  GetButtonFunction` id items;

GetDialogRadioFunction :: !Id !(DialogDef s (IOState s))
   -> DialogFunction s (IOState s);
GetDialogRadioFunction id (CommandDialog did t a di items)
   =  GetDialogRadioFunction` id items;
GetDialogRadioFunction id (PropertyDialog i t a f1 f2 items)
   =  GetDialogRadioFunction` id items;

GetDialogRadioFunction` :: !Id ![DialogItem s (IOState s)]
   -> DialogFunction s (IOState s);
GetDialogRadioFunction` id [RadioButtons id2 l roc did radios : items]
   | found =  f;
   =  GetDialogRadioFunction` id items;
      where {
      (f, found)=: GetDialogRadioFunction`` id radios;
      };
GetDialogRadioFunction` id [DialogPopUp id2 l able did radios : items]
   | found =  f;
   =  GetDialogRadioFunction` id items;
      where {
      (f, found)=: GetDialogRadioFunction`` id radios;
      };
GetDialogRadioFunction` id [item : items]
   =  GetDialogRadioFunction` id items;

GetDialogRadioFunction`` :: !Id ![RadioItemDef s (IOState s)]
   -> (!DialogFunction s (IOState s), !Bool);
GetDialogRadioFunction`` id [RadioItem id2 t s f : radios]
   | id == id2 =  (f, True);
   =  GetDialogRadioFunction`` id radios;
GetDialogRadioFunction`` id radios =  (EmptyDialogFunc, False);

GetDialogCheckFunction :: !Id !(DialogDef s (IOState s))
   -> DialogFunction s (IOState s);
GetDialogCheckFunction id (CommandDialog did t a di items)
   =  GetDialogCheckFunction` id items;
GetDialogCheckFunction id (PropertyDialog i t a f1 f2 items)
   =  GetDialogCheckFunction` id items;

GetDialogCheckFunction` :: !Id ![DialogItem s (IOState s)]
   -> DialogFunction s (IOState s);
GetDialogCheckFunction` id [CheckBoxes id2 l roc checks : items]
   | found =  f;
   =  GetDialogCheckFunction` id items;
      where {
      (f, found)=: GetDialogCheckFunction`` id checks;
      };
GetDialogCheckFunction` id [item : items]
   =  GetDialogCheckFunction` id items;

GetDialogCheckFunction`` :: !Id ![CheckBoxDef s (IOState s)]
   -> (!DialogFunction s (IOState s), !Bool);
GetDialogCheckFunction`` id [CheckBox id2 t s m f : checks]
   | id == id2 =  (f, True);
   =  GetDialogCheckFunction`` id checks;
GetDialogCheckFunction`` id checks =  (EmptyDialogFunc, False);

GetDialogControlFunction :: !Id !(DialogDef s (IOState s))
   -> DialogFunction s (IOState s);
GetDialogControlFunction id (CommandDialog did t a di items)
   =  GetDialogControlFunction` id items;
GetDialogControlFunction id (PropertyDialog i t a f1 f2 items)
   =  GetDialogControlFunction` id items; 

GetDialogControlFunction` :: !Id ![DialogItem s (IOState s)]
   -> DialogFunction s (IOState s);
GetDialogControlFunction` id [Control id` pos pic sel cs look feel f : items]
   | id == id` =  f;
   =  GetDialogControlFunction` id items;
GetDialogControlFunction` id [item : items]
   =  GetDialogControlFunction` id items;

EmptyDialogFunc :: !DialogInfo (DialogState s (IOState s))
   -> DialogState s (IOState s);
EmptyDialogFunc def ds =  ds;

GetDialogApplyFunction :: !(DialogDef s (IOState s))
   -> ButtonFunction s (IOState s);
GetDialogApplyFunction (PropertyDialog i t a f f1 is) =  f;

GetDialogResetFunction :: !(DialogDef s (IOState s))
   -> ButtonFunction s (IOState s);
GetDialogResetFunction (PropertyDialog i t a f1 f is) =  f;

GetDialogControlLook ::  !Id !(DialogDef s (IOState s))
   -> (!SelectState,!ControlLook, !ControlState, !PictureDomain);
GetDialogControlLook id (CommandDialog did t a di items)
   =  GetDialogControlLook` id items;
GetDialogControlLook id (PropertyDialog i t a f1 f2 items)
   =  GetDialogControlLook` id items;

GetDialogControlLook` :: !Id ![DialogItem s (IOState s)]
   -> (!SelectState,!ControlLook, !ControlState, !PictureDomain);
GetDialogControlLook` id [Control id2 l pic s cs look feel f : items]
   | id == id2 =  (s,look,cs,pic);
   =  GetDialogControlLook` id items;
GetDialogControlLook` id [item : items]
   =  GetDialogControlLook` id items;

GetDialogControlFeel ::  !Id !(DialogDef s (IOState s))
   -> (!Bool,!ControlFeel, !ControlState);
GetDialogControlFeel id (CommandDialog did t a di items)
   =  GetDialogControlFeel` id items;
GetDialogControlFeel id (PropertyDialog i t a f1 f2 items)
   =  GetDialogControlFeel` id items;

GetDialogControlFeel` :: !Id ![DialogItem s (IOState s)]
   -> (!Bool,!ControlFeel, !ControlState);
GetDialogControlFeel` id [Control id2 pic l Able cs look feel f : items]
   | id == id2 =  (True,feel, cs);
   =  GetDialogControlFeel` id items;
GetDialogControlFeel` id [item : items]
   =  GetDialogControlFeel` id items;
GetDialogControlFeel` id items
   =  (False,EmptyControlFeel, IntCS 0);

GetDialogIconLook :: !Id !(DialogDef s (IOState s))
   -> (!SelectState,!IconLook, !PictureDomain);
GetDialogIconLook id (CommandDialog did t a di items)
   =  GetDialogIconLook` id items;
GetDialogIconLook id (PropertyDialog i t a f1 f2 items)
   =  GetDialogIconLook` id items;

GetDialogIconLook` :: !Id ![DialogItem s (IOState s)]
   -> (!SelectState,!IconLook, !PictureDomain);
GetDialogIconLook` id [DialogIconButton id2 pos pic look able f : items]
   | id == id2 =  (able,look,pic);
   =  GetDialogIconLook` id items;
GetDialogIconLook` id [item:items] =  GetDialogIconLook` id items; 

GetDialogIconFunction :: !Id !(DialogDef s (IOState s))
   -> (!Bool,!ButtonFunction s (IOState s),!PictureDomain);
GetDialogIconFunction id (CommandDialog did t a di items)
   =  GetDialogIconFunction` id items;
GetDialogIconFunction id (PropertyDialog i t a f1 f2 items)
   =  GetDialogIconFunction` id items;

GetDialogIconFunction` :: !Id ![DialogItem s (IOState s)]
   -> (!Bool, !ButtonFunction s (IOState s), !PictureDomain);
GetDialogIconFunction` id [DialogIconButton id2 pos pic look able f : items]
   | id == id2 =  (Enabled able,f,pic);
   =  GetDialogIconFunction` id items;
GetDialogIconFunction` id [item:items] =  GetDialogIconFunction` id items; 

GetCommandDefaultItem :: !Id ![XDItemHandle] -> Widget;
GetCommandDefaultItem id [(id2,w)] =  w;
GetCommandDefaultItem id [(id2,w) : items]
   | id == id2 =  w;
   =  GetCommandDefaultItem id items;

EmptyControlFeel :: MouseState ControlState -> (ControlState,[DrawFunction]);
EmptyControlFeel m cs =  (cs,[]);

ReconstructDialogHandle :: !(DialogHandle s (IOState s))
   -> DialogHandle s (IOState s);
ReconstructDialogHandle (DialHandle m h items def)
   #!
		strict1=strict1;
		=
		DialHandle m h items (strict1);
	where {
	strict1=ReconstructDialog def items;
		
	};

ReconstructDialog :: !(DialogDef s (IOState s)) ![XDItemHandle]
   -> DialogDef s (IOState s);
ReconstructDialog (CommandDialog id t a d items) handles
   #!
		strict1=strict1;
		=
		CommandDialog id t a d (strict1);
	where {
	strict1=ReconstructDialog` items handles;
		
	};
ReconstructDialog (PropertyDialog id t a f1 f2 items) handles
   #!
		strict1=strict1;
		=
		PropertyDialog id t a f1 f2 (strict1);
	where {
	strict1=ReconstructDialog` items handles;
		
	};
ReconstructDialog def=:(AboutDialog appname pic dfs help) handles
   =  def;

ReconstructDialog` :: ![DialogItem s (IOState s)] ![XDItemHandle]
   -> [DialogItem s (IOState s)];
ReconstructDialog` [EditText id l w nl text : items] handles
   #!
		strict1=strict1;
		text`=text`;
		=
		[EditText id l w nl text` : strict1];
      where {
      text`=: get_edit_text (GetDialogWidget id handles);
      strict1=ReconstructDialog` items handles;
		};
ReconstructDialog` [RadioButtons id l roc did radios : items] handles
   #!
      strict1=ReconstructDialog` items handles;
		strict2=ReconstructRadioButtons radios handles;
   #  (did`, radios`)= strict2;
		=
		[RadioButtons id l roc did` radios` :
                  strict1];
ReconstructDialog` [DialogPopUp id l able did radios : items] handles
   #!
		strict1=strict1;
		=
		[DialogPopUp id l able did` radios` :
                  strict1];
      where {
      (did`, radios`)=: ReconstructRadioButtons radios handles;
      strict1=ReconstructDialog` items handles;
		};
ReconstructDialog` [CheckBoxes id l roc checks : items ] handles
   #!
		strict1=strict1;
		checks`=checks`;
		=
		[CheckBoxes id l roc checks` : strict1];
      where {
      checks`=: ReconstructCheckBoxes checks handles;
      strict1=ReconstructDialog` items handles;
		};
ReconstructDialog` [item : items] [handle : handles]
   #!
		strict1=strict1;
		=
		[item : strict1];
	where {
	strict1=ReconstructDialog` items handles;
		
	};
ReconstructDialog` items handles =  items;

ReconstructRadioButtons :: ![RadioItemDef s (IOState s)] ![XDItemHandle]
   -> (!Id, ![RadioItemDef s (IOState s)]);
ReconstructRadioButtons [radio=:RadioItem id t state f : radios] handles
   | IsMark (get_mark (GetDialogWidget id handles)) =  (id, [radio : radios]);
   #!
      strict2=ReconstructRadioButtons radios handles;
   #  (id`, radios`)= strict2;
   #!
		radios`=radios`;
		strict2=strict2;
		=
		(id`, [radio : radios`]);
ReconstructRadioButtons radios handles =  (0,radios);

ReconstructCheckBoxes :: ![CheckBoxDef s (IOState s)] ![XDItemHandle]
   -> [CheckBoxDef s (IOState s)];
ReconstructCheckBoxes [CheckBox id t state mark f : checks] handles
   #!
      xmark= get_mark (GetDialogWidget id handles);
   | IsMark xmark #!
		checks`=checks`;
		=
		 [CheckBox id t state Mark f : checks`];
   #!
		checks`=checks`;
		=
		[CheckBox id t state NoMark f : checks`];
      where {
      checks`=: ReconstructCheckBoxes checks handles;
      };
ReconstructCheckBoxes checks handles =  checks;

ChangeControlState :: !(DialogHandle s (IOState s)) !Id !ControlState
   -> DialogHandle s (IOState s);
ChangeControlState (DialHandle m (id, w) items def) cid cs
   #!
		def`=def`;
		=
		DialHandle m (id, w) items def`;
      where {
      def`=: ChangeControlState` def cid cs;
      };

ChangeControlState` :: !(DialogDef s (IOState s)) !Id !ControlState
   -> DialogDef s (IOState s);
ChangeControlState` (CommandDialog did t a di items) cid cs
   #!
		strict1=strict1;
		=
		CommandDialog did t a di (strict1);
	where {
	strict1=ChangeControlState`` items cid cs;
		
	};
ChangeControlState` (PropertyDialog i t a f1 f2 items) cid cs
   #!
		strict1=strict1;
		=
		PropertyDialog i t a f1 f2 (strict1);
	where {
	strict1=ChangeControlState`` items cid cs;
		
	};

ChangeControlState`` :: ![DialogItem s (IOState s)] !Id !ControlState
   -> [DialogItem s (IOState s)];
ChangeControlState`` [item=:Control id l p s cs look feel f: items] cid cs`
   | id == cid =  [Control id l p s cs` look feel f: items];
   #!
		strict1=strict1;
		=
		[item : strict1];
	where {
	strict1=ChangeControlState`` items cid cs`;
		
	};
ChangeControlState`` [item :items] cid cs 
   #!
		strict1=strict1;
		=
		[item : strict1];
	where {
	strict1=ChangeControlState`` items cid cs;
		
	};
ChangeControlState`` items cid cs =  items;

IsMark :: !Int -> Bool;
IsMark XMarkOn  =  True;
IsMark XMarkOff =  False;

GetDialogWidget :: !Id ![XDItemHandle] -> Widget;
GetDialogWidget id [(id2,w): handles]
   | id == id2 =  w;
   =  GetDialogWidget id handles;

GetDialogHandle :: !(IOState s) !Widget 
   -> (![DialogHandle s (IOState s)], !IOState s);
GetDialogHandle io w
   =  (dialog, io`);
      where {
      dialog       =: GetDialogHandle` device w;
      (device, io`)=: IOStateGetDevice io DialogDevice;
      };

GetDialogHandle` :: !(DeviceSystemState s) !Widget
   -> [DialogHandle s (IOState s)];
GetDialogHandle` (DialogSystemState dialogs) w
   =  GetDialogHandle`` dialogs w;

GetDialogHandle`` :: !(DialogHandles s (IOState s)) !Widget
   -> [DialogHandle s (IOState s)];
GetDialogHandle`` [handle=: DialHandle m (id, w`) b d : dialogs] w
   | w == w` =  [handle];
   =  GetDialogHandle`` dialogs w;
GetDialogHandle`` dialogs w =  dialogs;

GetDialogHandleFromId :: !(IOState s) !Id
   -> (![DialogHandle s (IOState s)], !IOState s);
GetDialogHandleFromId io id
   =  (dialog, io`);
      where {
      dialog       =: GetDialogHandleFromId` device id;
      (device, io`)=: IOStateGetDevice io DialogDevice;
      };

GetDialogHandleFromId` :: !(DeviceSystemState s) !Id
   -> [DialogHandle s (IOState s)];
GetDialogHandleFromId` (DialogSystemState dialogs) id
   =  GetDialogHandleFromId`` dialogs id;

GetDialogHandleFromId`` :: !(DialogHandles s (IOState s)) !Id
   -> [DialogHandle s (IOState s)];
GetDialogHandleFromId`` [handle=: DialHandle m (id`, w) b d : dialogs] id
   | id == id` =  [handle];
   =  GetDialogHandleFromId`` dialogs id;
GetDialogHandleFromId`` dialogs id =  dialogs;

DialogNotOpen :: !(DialogDef s (IOState s)) !(DialogHandles s (IOState s))
   -> Bool;
DialogNotOpen (CommandDialog id t a did items) dialogs
   =  DialogNotOpen` (GetDialogHandleFromId`` dialogs id);
DialogNotOpen (PropertyDialog id t a f1 f2 items) dialogs
   =  DialogNotOpen` (GetDialogHandleFromId`` dialogs id);

DialogNotOpen` :: ![DialogHandle s (IOState s)] -> Bool;
DialogNotOpen` [] =  True;
DialogNotOpen` [DialHandle m (id,w) items def : rest]
   =  Evaluate_2 False (activate_dialog w);

MakeActiveDialog :: !(DialogHandle s (IOState s)) !(IOState s) -> IOState s;
MakeActiveDialog dialog io_state
   =  IOStateSetDevice io_state` device`;
      where {
      device`            =: MakeActiveDialog` dialog device;
      (device, io_state`)=: IOStateGetDevice io_state DialogDevice;
      };

MakeActiveDialog` :: !(DialogHandle s (IOState s)) !(DeviceSystemState s)
   -> DeviceSystemState s;
MakeActiveDialog` dialog=: (DialHandle m (id,w) items def)
                     (DialogSystemState dialogs)
   #!
		strict1=strict1;
		=
		DialogSystemState [dialog : strict1];
	where {
	strict1=RemoveDialogHandle`` w dialogs;
		
	};

RemoveDialogHandle :: !Widget !(IOState s) -> IOState s;
RemoveDialogHandle w io_state
   =  IOStateSetDevice io_state` device`;
      where {
      device`            =: RemoveDialogHandle` w device;
      (device, io_state`)=: IOStateGetDevice io_state DialogDevice;
      };

RemoveDialogHandle` :: !Widget !(DeviceSystemState s) -> DeviceSystemState s;
RemoveDialogHandle` w (DialogSystemState dialogs)
   #!
		strict1=strict1;
		=
		DialogSystemState strict1;
	where {
	strict1=(RemoveDialogHandle`` w dialogs);
		
	};

RemoveDialogHandle`` :: !Widget !(DialogHandles s (IOState s))
   -> DialogHandles s (IOState s);
RemoveDialogHandle`` w [handle=: DialHandle m (id, w`) b d : dialogs]
   | w == w` =  dialogs;
   #!
		strict1=strict1;
		=
		[handle : strict1];
	where {
	strict1=RemoveDialogHandle`` w dialogs;
		
	};
RemoveDialogHandle`` w dialogs =  dialogs;

ChangeDialogHandle :: !Id !(DialogHandle s (IOState s)) !(IOState s) -> IOState s;
ChangeDialogHandle id handle io_state
   =  IOStateSetDevice io_state` dialog`;
      where {
      dialog`           =: ChangeDialogHandle` id handle dialog;
      (dialog,io_state`)=: IOStateGetDevice io_state DialogDevice;
      };

ChangeDialogHandle` :: !Id !(DialogHandle s (IOState s)) !(DeviceSystemState s)
   -> DeviceSystemState s;
ChangeDialogHandle` id handle (DialogSystemState dialogs)
   #!
		strict1=strict1;
		=
		DialogSystemState strict1;
	where {
	strict1=(ChangeDialogHandle`` id handle dialogs);
		
	};

ChangeDialogHandle`` :: !Id !(DialogHandle s (IOState s)) 
      ![DialogHandle s (IOState s)] 
   -> [DialogHandle s (IOState s)];
ChangeDialogHandle`` id handle [handle`=: DialHandle m (id`, w) i d : dialogs]
   | id == id` =  [handle : dialogs];
   #!
		strict1=strict1;
		=
		[handle`: strict1];
	where {
	strict1=ChangeDialogHandle`` id handle dialogs;
		
	}; 
ChangeDialoghandle`` id handle dialogs =  dialogs;


/* Functions used for parsing and installing the layout hints.
*/

    

:: Rect :== (!Int,!Int,!Int,!Int);
:: ItemLayout :== (!XDItemHandle, !Rect, !ItemPos, ![(!XDItemHandle, !Rect)]);


     

VerticalSep    :== 10;
HorizontalSep  :== 6;

RefOk          :== 1;
RefFalse       :== 2;
RefCenter      :== 3;
RefRight       :== 4;


    

PositionItems :: !Widget ![DialogAttribute] ![DialogItem s io] ![XDItemHandle]
   -> [XDItemHandle];
PositionItems dialog att items handles
   =  Evaluate_2 handles (RepositionCItems dialog margins itemlayouts``);
      where {
      (marginx,marginy)=: margins;
      itemlayouts``=: RepositionItems itemlayouts`;
      (height,itemlayouts`) =: LayoutPass2 margins spaces 0 [] itemlayouts;
      margins      =: GetDialogMargins att;
      spaces       =: GetDialogItemSpaces att;
      itemlayouts  =: MakeItemLayouts items handles;
      };


GetDialogMargins :: ![DialogAttribute] -> (!Int,!Int);
GetDialogMargins [DialogMargin x y : rest]
   =  (ConvertMeasureX x, ConvertMeasureY y);
GetDialogMargins [att : rest] =  GetDialogMargins rest;
GetDialogMargins atts =  (HorizontalSep, VerticalSep);

GetDialogItemSpaces :: ![DialogAttribute] -> (!Int,!Int);
GetDialogItemSpaces [ItemSpace x y : rest]
   =  (ConvertMeasureX x, ConvertMeasureY y);
GetDialogItemSpaces [att : rest] =  GetDialogItemSpaces rest;
GetDialogItemSpaces atts =  (HorizontalSep, VerticalSep);

MakeItemLayouts :: ![DialogItem s io] ![XDItemHandle] -> [ItemLayout];
MakeItemLayouts [DialogButton id pos t s f : items] handles
   #!
		strict1=strict1;
		=
		[(handle, get_current_rect w, pos, []) : strict1];
      where {
      (handle, handles`)=: GetXDItemHandle id handles;
      (id`,w)=: handle;
      strict1=MakeItemLayouts items handles`;
		};
MakeItemLayouts [DialogIconButton id pos p l s f : items] handles
   #!
		strict1=strict1;
		=
		[(handle, get_current_rect w, pos, []) : strict1];
      where {
      (handle, handles`)=: GetXDItemHandle id handles;
      (id`,w)=: handle;
      strict1=MakeItemLayouts items handles`;
		};
MakeItemLayouts [StaticText id pos s : items] handles
   #!
		strict1=strict1;
		=
		[(handle, get_current_rect w, pos, []) : strict1];
      where {
      (handle, handles`)=: GetXDItemHandle id handles;
      (id`,w)=: handle;
      strict1=MakeItemLayouts items handles`;
		};
MakeItemLayouts [DynamicText id pos width s : items] handles
   #!
		strict1=strict1;
		=
		[(handle, get_current_rect w, pos, []) : strict1];
      where {
      (handle, handles`)=: GetXDItemHandle id handles;
      (id`,w)=: handle;
      strict1=MakeItemLayouts items handles`;
		};
MakeItemLayouts [EditText id pos wi n s : items] handles
   #!
		strict1=strict1;
		=
		[(handle, get_current_rect w, pos, []) : strict1]
      where {
      (handle, handles`)=: GetXDItemHandle id handles;
      (id`,w)=: handle;
      strict1=MakeItemLayouts items handles`;
		};
MakeItemLayouts [DialogPopUp id pos able did radios : items] handles
   #!
		strict1=strict1;
		=
		[(handle, get_current_rect w, pos, []) :
       strict1];
      where {
      (handle, handles`)=: GetXDItemHandle id handles;
      (id`,w)=: handle;
      strict1=MakeItemLayouts items handles`;
		};
MakeItemLayouts [RadioButtons id pos roc did radios : items] handles
   #!
		strict1=strict1;
		=
		[(handle, get_current_rect w, pos, []) : strict1];
      where {
      (handle, handles`)=: GetXDItemHandle id handles;
      (id`,w)=: handle;
      strict1=MakeItemLayouts items handles`;
		};
MakeItemLayouts [CheckBoxes id pos roc checks : items] handles
   #!
		strict1=strict1;
		=
		[(handle, get_current_rect w, pos, []) : strict1];
      where {
      (handle, handles`)=: GetXDItemHandle id handles;
      (id`,w)=: handle;
      strict1=MakeItemLayouts items handles`;
		};
MakeItemLayouts [Control id pos p s cs lo fe f : items] handles
   #!
		strict1=strict1;
		=
		[(handle, get_current_rect w, pos, []) : strict1];
      where {
      (handle, handles`)=: GetXDItemHandle id handles;
      (id`,w)=: handle;
      strict1=MakeItemLayouts items handles`;
		};
MakeItemLayouts [] handles =  [];

GetXDItemHandle :: !Id ![XDItemHandle] -> (!XDItemHandle, ![XDItemHandle]);
GetXDItemHandle id [handle=:(id`,w) : handles]
   | id == id` =  (handle, handles)
   =  (handle`, [handle : handles`])
      where {
      (handle`, handles`)=: GetXDItemHandle id handles;
      };


// Halbe: RepositionItems moet ook items in list 'l' verplaatsen,
//        daarom RepositionCList toegevoegd.

RepositionItems :: ![ItemLayout] -> [ItemLayout];
RepositionItems [item=:((id,widget),(x,y,w,h),pos,l) : items]
   #!
		strict1=strict1;
		strict2=strict2;
		=
		[strict1  : strict2];
      where {
      change=: RepositionCList l (repos_widget widget x y w h);
      strict1=Evaluate_2 item change;
		strict2=RepositionItems items;
		};
RepositionItems items =  items;

RepositionCList :: ![(XDItemHandle,Rect)] !Int -> Int;
RepositionCList [((id,widget),(x,y,w,h)) : rest] c
   =  RepositionCList rest (repos_widget widget x y w h);
RepositionCList [] c =  c;

LayoutPass2 :: !(!Int,!Int) !(!Int,!Int) !Int ![ItemLayout] ![ItemLayout]
   -> (!Int, [ItemLayout]);
LayoutPass2 margins spaces cline citems [item=: ((handle, (x,y,w,h), ItemBox x` y` w` h`, [])) : items]=  LayoutPass2 margins spaces cline` 
                  [(handle,(x`,y`,w`,h`),Left,[]) : citems] items;
      where {
      cline`=: NewCurrentLine y` h` cline;
      };
LayoutPass2 margins spaces cline citems [item=: ((handle, (x,y,w,h), XY x` y`, [])) : items]=  LayoutPass2 margins spaces cline`
                  [(handle,(x``,y``,w,h),Left,[]) : citems] items;
      where {
      cline`=: NewCurrentLine y`` h cline;
      x``   =: ConvertMeasureX x`;
      y``   =: ConvertMeasureY y`;
      };
LayoutPass2 margins=: ((marginx,marginy)) spaces=:(spacex,spacey) cline citems [item=: ((handle, (x,y,w,h), Left, [])) : items]=  LayoutPass2 margins spaces (h + y`)
                  [(handle,(marginx,y`,w,h), Left, []) : citems] items;
      where {
      y`=: if (cline == 0) (marginy + cline) (spacey + cline);
      };
LayoutPass2 margins spaces=:(spacex,spacey) cline citems [item=: ((handle, rect=:(x,y,w,h), Below ref, [])) : items]| valid == RefOk =  LayoutPass2 margins spaces cline` 
                  [(handle,(x`,y``,w,h),Left,[]) : citems]
                  items;
   | valid == RefCenter =  LayoutPass2 margins spaces cline`
                  [(handle,(0,y``,w,h),Center,[]) : citems]
                  items;
   | valid == RefRight =  LayoutPass2 margins spaces cline`
                  [(handle,(0,y``,w,h),Right,[]) : citems]
                  items;
   =  LayoutPass2 margins spaces cline citems
                  [(handle, rect, Left, []) : items];
      where {
      (valid, x`, y`, w`, h`)=: GetRefRect citems ref;
      y``=: y` + (spacey + h`);
      cline`=: NewCurrentLine y`` h cline;
      };
LayoutPass2 margins spaces cline citems [item=: ((handle, rect=:(x,y,w,h), YOffset ref yoffset, [])) : items]| valid == RefOk =  LayoutPass2 margins spaces cline`
                  [(handle,(x`,y``,w,h),Left,[]) : citems]
                  items;
   | valid == RefCenter =  LayoutPass2 margins spaces cline` 
                  [(handle,(0,y``,w,h),Center,[]) : citems]
                  items;
   | valid == RefRight =  LayoutPass2 margins spaces cline` 
                  [(handle,(0,y``,w,h),Right,[]) : citems]
                  items;
   =  LayoutPass2 margins spaces cline citems 
                  [(handle, rect, Left, []) : items];
      where {
      (valid, x`, y`, w`, h`)=: GetRefRect citems ref;
      y``=:  y` + h`  +  ConvertMeasureY yoffset ;
      cline`=: NewCurrentLine y`` h cline;
      }; 
LayoutPass2 margins spaces=:(spacex,spacey) cline citems [item=: ((handle, rect=:(x,y,w,h), RightTo ref, [])) : items]| valid == RefOk =  LayoutPass2 margins spaces cline`
                  [(handle,(x``,y`,w,h),Left,[]) : citems]
                  items;
   | (valid == RefCenter) || (valid == RefRight) =  LayoutPass2 margins spaces cline`                           // Halbe: was cline
                  (CenteredRef citems ref handle (x``,y`,w,h))
                  items;
   =  LayoutPass2 margins spaces cline citems
                  [(handle, rect, Left, []) : items];
      where {
      (valid, x`, y`, w`, h`)=: GetRefRect citems ref;
      x``=: x` + (spacex + w`);
      cline`=: NewCurrentLine y` h cline;
      };
LayoutPass2 margins spaces cline citems [item=: ((handle, rect=:(x,y,w,h), XOffset ref xoffset, [])) : items]| valid == RefOk =  LayoutPass2 margins spaces cline` 
                  [(handle,(x``,y`,w,h),Left,[]) : citems]
                  items;
   | (valid == RefCenter) || (valid == RefRight) =  LayoutPass2 margins spaces cline`                           // Halbe: was cline
                  (CenteredRef citems ref handle (x``,y`,w,h))
                  items;
   =  LayoutPass2 margins spaces cline citems 
                  [(handle, rect, Left, []) : items];
      where {
      (valid, x`, y`, w`, h`)=: GetRefRect citems ref;
      x``=:  x` + w`  +  ConvertMeasureX xoffset ;
      cline`=: NewCurrentLine y` h cline;
      };
LayoutPass2 margins spaces=:(spacex,spacey) cline citems [item=: ((handle, rect=:(x,y,w,h), Center, [])) : items]=  LayoutPass2 margins spaces (h + y`) 
                  [(handle,(0,y`,w,h),Center,[]) : citems] items;
      where {
      y`=: cline + spacey;
      };
LayoutPass2 margins spaces=:(spacex,spacey) cline citems [item=: ((handle, rect=:(x,y,w,h), Right, [])) : items]=  LayoutPass2 margins spaces (h + y`)
                  [(handle,(0,y`,w,h),Right,[]) : citems] items;
      where {
      y`=: cline + spacey;
      };
LayoutPass2 (marginx,marginy) spaces cline citems []
   =  (cline + marginy,citems);

GetRefRect :: ![ItemLayout] !Id -> (!Int, !Int, !Int, !Int, !Int);
GetRefRect [((id,widget), (x,y,w,h), Center, l) : items] id`
   | id == id` =  (RefCenter,x,y,w,h);
   | refinlist =  (RefCenter,x`,y`,w`,h`);
   =  GetRefRect items id`;
      where {
      (refinlist, x`, y`, w`, h`)=: GetCenteredRefRect l id`;
      };
GetRefRect [((id,widget), (x,y,w,h), Right, l) : items] id`
   | id == id` =  (RefRight,x,y,w,h);
   | refinlist =  (RefRight,x`,y`,w`,h`);
   =  GetRefRect items id`;
      where {
      (refinlist, x`, y`, w`, h`)=: GetCenteredRefRect l id`;
      };
GetRefRect [((id,widget), (x,y,w,h), pos, l) : items] id`
   | id == id` =  (RefOk,x,y,w,h);
   =  GetRefRect items id`;
GetRefRect [] id` =  (RefFalse,0,0,0,0);

GetCenteredRefRect :: ![(!XDItemHandle, !Rect)] !Id
   -> (!Bool,!Int,!Int,!Int,!Int);
GetCenteredRefRect [((id,widget), (x,y,w,h)) : items] id`
   | id == id` =  (True,x,y,w,h);
   =  GetCenteredRefRect items id`;
GetCenteredRefRect items id =  (False,0,0,0,0);

CenteredRef :: ![ItemLayout] !Id !XDItemHandle !Rect -> [ItemLayout];
CenteredRef [item=:(h=:(id,w),r,Center,l) : citems] ref handle rect
   | ref == id || RefInList ref l =  [(h,r,Center,[(handle,rect) : l]) : citems];
   #!
		strict1=strict1;
		=
		[item : strict1];
	where {
	strict1=CenteredRef citems ref handle rect;
		
	};
CenteredRef [item=:(h=:(id,w),r,Right,l) : citems] ref handle rect
   | ref == id || RefInList ref l =  [(h,r,Right,[(handle,rect) : l]) : citems];
   #!
		strict1=strict1;
		=
		[item : strict1];
	where {
	strict1=CenteredRef citems ref handle rect;
		
	};
CenteredRef [item : citems] ref handle rect 
   #!
		strict1=strict1;
		=
		[item : strict1];
	where {
	strict1=CenteredRef citems ref handle rect;
		
	};

RefInList :: !Id ![(!XDItemHandle, !Rect)] -> Bool;
RefInList id [((id`,w),rect) : items] 
   | id == id` =  True;
   =  RefInList id items;
RefInList id items =  False;

NewCurrentLine :: !Int !Int !Int -> Int;
NewCurrentLine y h cline 
   | newcline > cline =  newcline;
   =  cline;
      where {
      newcline=: y + h;
      };

RepositionCItems :: !Widget !(!Int,!Int) ![ItemLayout] -> [Widget];
RepositionCItems dialog m=:(mx,my) [(handle,rect,Center,l) : items]
   =  Concat (CenterItems mx [(handle,rect):l])
             (RepositionCItems dialog m items);
RepositionCItems dialog m=:(mx,my) [(handle,rect,Right,l) : items]
   =  Concat (RightItems mx [(handle,rect):l])
             (RepositionCItems dialog m items);
RepositionCItems dialog m [item : items] =  RepositionCItems dialog m items;
RepositionCItems dialog (mx,my) []
   =  Evaluate_2 [] (set_dialog_margins dialog mx my);

CenterItems :: !Int ![(!XDItemHandle, !Rect)] -> [Widget];
CenterItems mx l=:[item=: ((id,w),rect) : items]
   =  CenterItems` base l;
      where {
      base=: ( dialogwidth - groupwidth  - (mx + mx)) / 2;
      dialogwidth=: get_father_width w;
      groupwidth=: GetTotalWidth mx l;
      };

RightItems :: !Int ![(!XDItemHandle, !Rect)] -> [Widget];
RightItems mx l=:[item=: ((id,w),rect) : items]
   =  CenterItems` base l;
      where {
      base=:  dialogwidth - groupwidth  - (mx + mx);
      dialogwidth=: get_father_width w;
      groupwidth=: GetTotalWidth mx l;
      };

GetTotalWidth :: !Int ![(!XDItemHandle, !Rect)] -> Int;
GetTotalWidth width [(handle, (x,y,w,h)) : items]
   | width` > width =  GetTotalWidth width` items;
   =  GetTotalWidth width items;
      where {
      width`=: x + w;
      };
GetTotalWidth width items =  width;

CenterItems` :: !Int ![(!XDItemHandle, !Rect)] -> [Widget];
CenterItems` base [((id,widget),(x,y,w,h)) : items] 
   #!
		strict1=strict1;
		strict2=strict2;
		=
		[strict1 : strict2];
	where {
	strict1=repos_widget widget (x + base) y w h;
		strict2=CenterItems` base items;
		
	};
CenterItems` base items =  [];

