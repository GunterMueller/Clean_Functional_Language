implementation module deltaDialog;

/*	Halbe: OpenModalDialog is niet correct: termineert direct...
*/

import StdClass; // RWS
import StdString, StdInt, StdBool, StdMisc;
import misc, ioState;
import xtypes,xevent,xdialog,dialogDef,dialogDevice;
from windowDevice import Draw_in_window;

PictureNormal pic :== [SetPenNormal, SetPenColour BlackColour,
                      SetBackColour WhiteColour, EraseRectangle pic];

XMark :== 0;
XNoMark :== 1;

DialogError rule mes id
	:== Error rule "deltaDialog" (mes +++  " " +++  toString id);

:: DialogChange *s :== (DialogState s (IOState s)) ->  DialogState s (IOState s) ;

/* Opening and closing dialogs.
*/
OpenDialog :: !(DialogDef s (IOState s)) !(IOState s) -> IOState s;
OpenDialog (AboutDialog appname pic dfs help) io =  io;
OpenDialog dialog io =  OpenThisDialog Modeless dialog io;

// Halbe: !!! Niet correct !!!
OpenModalDialog :: !(DialogDef *s (IOState *s)) !*s !(IOState *s) -> (!*s,!IOState *s);
OpenModalDialog (AboutDialog an pc ds hp) s io =  (s,io);
OpenModalDialog dialog s io =  DoModalDialog s io`;
		where {
		io`=: OpenThisDialog Modal dialog io;
		};

OpenThisDialog :: !DialogMode !(DialogDef s (IOState s)) !(IOState s) -> IOState s;
OpenThisDialog mode dialog io_state
   =  IOStateSetDevice io_state` dialogs`;
      where {
      dialogs`            =: OpenDialog` mode dialog dialogs;
      (dialogs, io_state`)=: IOStateGetDevice io_state DialogDevice;
      };

OpenDialog` :: !DialogMode !(DialogDef s (IOState s)) !(DeviceSystemState s)
   -> DeviceSystemState s;
OpenDialog` mode dialog (DialogSystemState dialogs) 
   | DialogNotOpen dialog dialogs #!
		strict1=strict1;
		=
		DialogSystemState [strict1 : dialogs];
   #!
		strict1=strict1;
		=
		DialogSystemState dialogs;
	where {
	strict1=Open_dialog mode dialog;
		
	};

CloseDialog :: !DialogId !(IOState s) -> IOState s;
CloseDialog id io_state
   =  CloseDialog` handle io_state`;
      where {
      (handle, io_state`)=: GetDialogHandleFromId io_state id;
      };

CloseDialog` :: ![DialogHandle s (IOState s)] !(IOState s) -> IOState s;
CloseDialog` [] io =  io;
CloseDialog` [handle=:DialHandle m (id,w) items def] io
   =  UEvaluate_2 (RemoveDialogHandle w io) (Close_dialog handle);

CloseActiveDialog :: !(IOState s) -> IOState s;
CloseActiveDialog io_state
   =  IOStateSetDevice io_state` dialogs`;
      where {
      dialogs`            =: CloseActiveDialog` dialogs;
      (dialogs, io_state`)=: IOStateGetDevice io_state DialogDevice;
      };

CloseActiveDialog` :: !(DeviceSystemState s) -> DeviceSystemState s;
CloseActiveDialog` (DialogSystemState [handle : dialogs])
   =  Evaluate_2 (DialogSystemState dialogs) (Close_dialog handle);
CloseActiveDialog` ds=:(DialogSystemState []) =  ds;

OpenNotice :: !NoticeDef !*s !(IOState *s) -> (!NoticeButtonId, !*s, !IOState *s);
OpenNotice (Notice text defbutton buttons) program_state io_state
   =  (handle_notice notice, program_state, io_state);
      where {
      notice =: AddNoticeButtons notice` [defbutton : buttons];
      notice`=: create_notice (CreateNoticeText text);
      };

CreateNoticeText :: ![String] -> String;
CreateNoticeText [s : rest] =  (s +++ "\n") +++  CreateNoticeText rest ;
CreateNoticeText s =  "";

AddNoticeButtons :: !Widget ![NoticeButtonDef] -> Widget;
AddNoticeButtons w [NoticeButton id label :buttons]
   =  AddNoticeButtons (add_n_button w label id) buttons;
AddNoticeButtons w buttons =  w;

Beep :: !(IOState s) -> IOState s;
Beep io =  UEvaluate_2 io (beep 0);

GetDialogInfo :: !DialogId !(IOState s) -> (!Bool, !DialogInfo, !IOState s);
GetDialogInfo id io_state =  (found, DDef2DInfo def, io_state``);
   	where {
   	(found,def,io_state``)=: GetDialogDef` handle io_state`;
      (handle,   io_state` )=: GetDialogHandleFromId io_state id;
   	};

GetDialogDef` :: ![DialogHandle s (IOState s)] !(IOState s)
   -> (!Bool, !DialogDef s (IOState s), !IOState s);
GetDialogDef` [dialog : x] io_state
   #!
		strict1=strict1;
		=
		(True, GetDialogDef`` (strict1), io_state);
	where {
	strict1=ReconstructDialogHandle dialog;
		
	};
GetDialogDef` [] io_state
   =  (False, AboutDialog "" ((0,0),(0,0)) [] NoHelp, io_state);

GetDialogDef`` :: !(DialogHandle s (IOState s)) -> DialogDef s (IOState s);
GetDialogDef`` (DialHandle m xh items def) =  def;

GetActiveDialogInfo :: !(IOState s) -> (!Bool, !DialogInfo, !IOState s);
GetActiveDialogInfo io_state =  (found, DDef2DInfo def, io_state``);
   	where {
   	(found,def,io_state``)=: GetActiveDialogDef` dialogs io_state`;
      (dialogs  ,io_state` )=: IOStateGetDevice io_state DialogDevice;
   	};

GetActiveDialogDef` :: !(DeviceSystemState s) !(IOState s)
   -> (!Bool, !DialogDef s (IOState s), !IOState s);
GetActiveDialogDef` (DialogSystemState handles) io_state
   =  GetDialogDef` handles io_state;


/* The internal parse functions to support the functions that 
   change the state of DialogItems.
*/

    

:: ItemChange *s
   :== XDItemHandle ->  (DialogItem s (IOState s)) -> 
                      (XDItemHandle, DialogItem s (IOState s)) ;

    

ChangeDialogItems :: ![DialogItemId] !(ItemChange *s) !(DialogState *s (IOState *s))
   -> DialogState *s (IOState *s);
ChangeDialogItems ids change dstate
   =  DHandle2DState (ChangeDialogItems` ids change (DState2DHandle dstate)); 

ChangeDialogItems` :: ![DialogItemId] !(ItemChange *s) !(DialogHandle *s (IOState *s))
   -> DialogHandle *s (IOState *s);
ChangeDialogItems` [id : ids] change dial=:(DialHandle m h handles def)
   | IsDItem id handles #!
      strict1=ChangeDialogItem id change handles def;
   #   (handles`, def`)= strict1;
		=
		ChangeDialogItems` ids change 
                         (DialHandle m h handles` def`);
		=
		ChangeDialogItems` ids change dial; 
ChangeDialogItems` ids change handle =  handle; 

ChangeDialogItem :: !DialogItemId !(ItemChange *s) ![XDItemHandle]
      !(DialogDef *s (IOState *s))
   -> (![XDItemHandle], !DialogDef *s (IOState *s));
ChangeDialogItem id change handles def
   #!
      strict1=change (GetDItemHandle handles id) (GetDialogDefItem id def);
   #
      (handle, item)= strict1;
		=
		(ChangeDItemHandles id handles handle, ChangeDialogItemDef id def item);

IsDItem :: !DialogItemId ![XDItemHandle] -> Bool;
IsDItem id [(id`,w) : handles] | id == id` =  True;
                                  =  IsDItem id handles;
IsDItem id handles =  False;

GetDItemHandle :: ![XDItemHandle] !DialogItemId -> XDItemHandle;
GetDItemHandle [handle=:(id, w) : handles] id`
   | id == id`   =  handle;
   =  GetDItemHandle handles id`;

GetDialogDefItem :: !DialogItemId !(DialogDef s (IOState s)) 
   -> DialogItem s (IOState s);
GetDialogDefItem id (CommandDialog did t a deid items)
   =  GetDialogItemDef` items id;
GetDialogDefItem id (PropertyDialog did t a f1 f2 items)
   =  GetDialogItemDef` items id;

GetDialogItemDef` :: ![DialogItem s (IOState s)] !DialogItemId
   -> DialogItem s (IOState s);
GetDialogItemDef` [item=: DialogButton id` l t s f : items] id
   | id == id` =  item;
   =  GetDialogItemDef` items id;
GetDialogItemDef` [item=: DialogIconButton id` l p i s f : items] id
   | id == id` =  item;
   =  GetDialogItemDef` items id;
GetDialogItemDef` [item=: StaticText id` l s : items] id
   | id == id` =  item;
   =  GetDialogItemDef` items id;
GetDialogItemDef` [item=: DynamicText id` l w s : items] id
   | id == id` =  item;
   =  GetDialogItemDef` items id;
GetDialogItemDef` [item=: EditText id` l w nl s : items] id
   | id == id` =  item;
   =  GetDialogItemDef` items id;
GetDialogItemDef` [item=: Control id` l p s cs cl cf f : items] id
   | id == id` =  item;
   =  GetDialogItemDef` items id;
GetDialogItemDef` [item=: DialogPopUp id` l able rid radios : items] id
   | id == id` || RadioButtonsContainId radios id =  item; 
   =  GetDialogItemDef` items id;
GetDialogItemDef` [item=: RadioButtons id` l roc rid radios : items] id
   | id == id` || RadioButtonsContainId radios id =  item;
   =  GetDialogItemDef` items id;
GetDialogItemDef` [item=: CheckBoxes id` l roc checks : items] id
   | id == id` || CheckBoxesContainId checks id =  item;
   =  GetDialogItemDef` items id;
GetDialogItemDef` [] id
   =  abort "GetDialogDefItem invoked with an invalid DialogItemId.\n";

RadioButtonsContainId :: ![RadioItemDef s (IOState s)] !DialogItemId -> Bool;
RadioButtonsContainId [RadioItem id` t s f : radios] id
   | id == id` =  True;
   =  RadioButtonsContainId radios id;
RadioButtonsContainId radios id =  False;

CheckBoxesContainId :: ![CheckBoxDef s (IOState s)] !DialogItemId -> Bool;
CheckBoxesContainId [CheckBox id` t s m f : checks] id
   | id == id` =  True;
   =  CheckBoxesContainId checks id;
CheckBoxesContainId checks id =  False;

ChangeDItemHandles :: !DialogItemId ![XDItemHandle] !XDItemHandle
   -> [XDItemHandle];
ChangeDItemHandles id [(id`, w) : handles] handle
   | id == id` =  [handle : handles];
   #!
		strict1=strict1;
		=
		[(id`,w) : strict1];
	where {
	strict1=ChangeDItemHandles id handles handle;
		
	};

ChangeDialogItemDef :: !DialogItemId !(DialogDef s (IOState s)) 
      !(DialogItem s (IOState s))
   -> DialogDef s (IOState s);
ChangeDialogItemDef id (CommandDialog i t a did items) item
   #!
		strict1=strict1;
		=
		CommandDialog i t a did strict1;
	where {
	strict1=(ChangeDialogItemDef` id items item);
		
	};
ChangeDialogItemDef id (PropertyDialog i t a f1 f2 items) item
   #!
		strict1=strict1;
		=
		PropertyDialog i t a f1 f2 strict1;
	where {
	strict1=(ChangeDialogItemDef` id items item);
		
	};

ChangeDialogItemDef` :: !DialogItemId ![DialogItem s (IOState s)] 
      !(DialogItem s (IOState s))
   -> [DialogItem s (IOState s)];
ChangeDialogItemDef` id [item`=: DialogButton id` l t s f : items] item
   | id == id` =  [item : items];
   #!
		strict1=strict1;
		=
		[item` : strict1];
	where {
	strict1=ChangeDialogItemDef` id items item;
		
	};
ChangeDialogItemDef` id [item`=: DialogIconButton id` l p i s f : items] item
   | id == id` =  [item : items];
   #!
		strict1=strict1;
		=
		[item` : strict1];
	where {
	strict1=ChangeDialogItemDef` id items item;
		
	};
ChangeDialogItemDef` id [item`=: StaticText id` l s : items] item
   | id == id` =  [item : items];
   #!
		strict1=strict1;
		=
		[item` : strict1];
	where {
	strict1=ChangeDialogItemDef` id items item;
		
	};
ChangeDialogItemDef` id [item`=: DynamicText id` l w s : items] item
   | id == id` =  [item : items];
   #!
		strict1=strict1;
		=
		[item` : strict1];
	where {
	strict1=ChangeDialogItemDef` id items item;
		
	};
ChangeDialogItemDef` id [item`=: EditText id` l w nl s : items] item
   | id == id` =  [item : items];
   #!
		strict1=strict1;
		=
		[item` : strict1];
	where {
	strict1=ChangeDialogItemDef` id items item;
		
	};
ChangeDialogItemDef` id [item`=: DialogPopUp id` l a d radios : items] item
   | id == id` || RadioButtonsContainId radios id =  [item : items];
   #!
		strict1=strict1;
		=
		[item` : strict1];
	where {
	strict1=ChangeDialogItemDef` id items item;
		
	};
ChangeDialogItemDef` id [item`=: RadioButtons id` l r d radios : items] item
   | id == id` || RadioButtonsContainId radios id =  [item : items];
   #!
		strict1=strict1;
		=
		[item` : strict1];
	where {
	strict1=ChangeDialogItemDef` id items item;
		
	};
ChangeDialogItemDef` id [item`=: CheckBoxes id` l r checks : items] item
   | id == id` || CheckBoxesContainId checks id =  [item : items];
   #!
		strict1=strict1;
		=
		[item` : strict1];
	where {
	strict1=ChangeDialogItemDef` id items item;
		
	};
ChangeDialogItemDef` id [item`=: Control id` l p s cs cl cf f: items] item
   | id == id` =  [item : items];
   #!
		strict1=strict1;
		=
		[item` : strict1];
	where {
	strict1=ChangeDialogItemDef` id items item;
		
	};


/* The functions to change the DialogState (and the Dialog).
*/
EnableDialogItems :: ![DialogItemId] !(DialogState s (IOState s))
   -> DialogState s (IOState s);
EnableDialogItems ids dialog
   =  ChangeDialogItems ids (CAbilityDialogItem Able) dialog;

DisableDialogItems :: ![DialogItemId] !(DialogState s (IOState s))
   -> DialogState s (IOState s);
DisableDialogItems ids dialog
   =  ChangeDialogItems ids (CAbilityDialogItem Unable) dialog;

/* Halbe: added alternatives for CheckBoxes and RadioButtons.
*/
CAbilityDialogItem :: !SelectState !XDItemHandle !(DialogItem s (IOState s))
   -> (!XDItemHandle, !DialogItem s (IOState s));
CAbilityDialogItem state (id,w) (DialogButton i l t s f)
   #!
		strict1=strict1;
		=
		((id, strict1), DialogButton i l t state f);
	where {
	strict1=SetDialogItemAbility w state;
		
	};
CAbilityDialogItem state (id,w) (DialogIconButton i l p look s f)
   #
      dfs= Concat (PictureNormal p) (look state);
   #!
      strict2=NewXPicture (dialog_item_to_object w);
      w` = Evaluate_2 w (Draw_in_window (1, strict2) (0,0) dfs);
		=
		((id, w`), DialogIconButton i l p look state f);
CAbilityDialogItem state (id,w) (Control i l p s cs look feel f)
   #
      dfs= Concat (PictureNormal p) (look state cs);
   #!
      strict2=NewXPicture (dialog_item_to_object w);
      w` = Evaluate_2 w (Draw_in_window (1, strict2) (0,0) dfs);
		=
		((id, w`), Control i l p state cs look feel f);
CAbilityDialogItem state (id,w) item=:(DialogPopUp id` l able d radios)
   | id <> id` #!
		strict1=strict1;
		=
		((id, strict1), item);
   #!
		strict2=strict2;
		=
		((id, strict2), DialogPopUp id` l state d radios);
	where {
	strict2=SetDialogItemAbility w state;
		
	strict1=SetDialogItemAbility w state;
		};
CAbilityDialogItem state handle=:(id,w) item=:(RadioButtons id` l rc di radios)
   | id == id` =  (handle,item);
   #!
		strict1=strict1;
		=
		((id, strict1), item);
	where {
	strict1=SetDialogItemAbility w state;
		
	};
CAbilityDialogItem state handle=:(id,w) item=:(CheckBoxes id` l rc checks)
   | id == id` =  (handle,item);
   #!
		strict1=strict1;
		=
		((id, strict1), item);
	where {
	strict1=SetDialogItemAbility w state;
		
	};
CAbilityDialogItem state handle item =  (handle, item);

MarkCheckBoxes :: ![DialogItemId] !(DialogState s (IOState s))
   -> DialogState s (IOState s);
MarkCheckBoxes ids dialog
   =  ChangeDialogItems ids (CMarkDialogItem Mark) dialog;

UnmarkCheckBoxes :: ![DialogItemId] !(DialogState s (IOState s))
   -> DialogState s (IOState s);
UnmarkCheckBoxes ids dialog
   =  ChangeDialogItems ids (CMarkDialogItem NoMark) dialog;

CMarkDialogItem :: !MarkState !XDItemHandle !(DialogItem s (IOState s))
   -> (!XDItemHandle, !DialogItem s (IOState s));
CMarkDialogItem mark (id,w) item=:(CheckBoxes i l roc checks)
   #!
		strict1=strict1;
		=
		((id, strict1), item);
	where {
	strict1=CheckDialogItem w mark;
		
	};
CMarkDialogItem mark handle item =  (handle,item);

CheckDialogItem :: !Widget !MarkState -> Widget;
CheckDialogItem w Mark =  check_dialog_item w XMark;
CheckDialogItem w mark =  check_dialog_item w XNoMark;

SelectDialogRadioItem :: !DialogItemId !(DialogState s (IOState s))
   -> DialogState s (IOState s);
SelectDialogRadioItem id dialog
   =  ChangeDialogItems [id] SelectDialogRadioItem` dialog;

SelectDialogRadioItem` :: !XDItemHandle !(DialogItem s (IOState s))
   -> (!XDItemHandle, !DialogItem s (IOState s));
SelectDialogRadioItem` (id,w) (RadioButtons id` l roc did radios)
   #!
		strict1=strict1;
		=
		((id, strict1), RadioButtons id` l roc id radios);
	where {
	strict1=press_radio_widget w "";
		
	};
SelectDialogRadioItem` (id,w) (DialogPopUp id` l a did radios)
   #!
		strict1=strict1;
		=
		((id, strict1), DialogPopUp id` l a id radios);
      where {
      title=: GetDefaultRadioTitle id radios;
      strict1=press_radio_widget w title;
		};
SelectDialogRadioItem` handle item =  (handle,item);

GetDefaultRadioTitle :: !Id ![RadioItemDef s (IOState s)] -> ItemTitle;
GetDefaultRadioTitle id [RadioItem id` title s f : rest]
   | id == id` =  title;
   =  GetDefaultRadioTitle id rest;
GetDefaultRadioTitle id [] =  "";

ChangeEditText :: !DialogItemId !String !(DialogState s (IOState s))
   -> DialogState s (IOState s);
ChangeEditText id text dialog
   =  ChangeDialogItems [id] (ChangeEditText` text) dialog;

ChangeEditText` :: !String !XDItemHandle !(DialogItem s (IOState s))
   -> (!XDItemHandle, !DialogItem s (IOState s));
ChangeEditText` text (id,w) (EditText id` l wi nl text`)
   #!
		strict1=strict1;
		=
		((id, strict1), EditText id` l wi nl text);
	where {
	strict1=set_edit_text w text;
		
	}; 
ChangeEditText` text handle item =  (handle,item);

ChangeDynamicText :: !DialogItemId !String !(DialogState s (IOState s))
   -> DialogState s (IOState s);
ChangeDynamicText id text dialog
   =  ChangeDialogItems [id] (ChangeDynamicText` text) dialog;

ChangeDynamicText` :: !String !XDItemHandle !(DialogItem s (IOState s))
   -> (!XDItemHandle, !DialogItem s (IOState s));
ChangeDynamicText` text (id,w) (DynamicText id` l wi text`)
   #!
		strict1=strict1;
		=
		((id, strict1), DynamicText id` l wi text);
	where {
	strict1=set_static_text w text;
		
	};
ChangeDynamicText` text handle item =  (handle,item);

ChangeIconLook :: !DialogItemId !IconLook !(DialogState s (IOState s))
   -> DialogState s (IOState s);
ChangeIconLook id look dialog
   =  ChangeDialogItems [id] (ChangeIconLook` look) dialog;

ChangeIconLook` :: !IconLook !XDItemHandle !(DialogItem s (IOState s))
   -> (!XDItemHandle, !DialogItem s (IOState s));
ChangeIconLook` look (id,w) (DialogIconButton id` l p look` s f)
   #
      dfs= Concat (PictureNormal p) (look s);
   #!
      strict2=NewXPicture (dialog_item_to_object w);
      w` = Evaluate_2 w (Draw_in_window (1, strict2) (0,0) dfs);
		=
		((id, w`), DialogIconButton id` l p look s f);
ChangeIconLook` look handle item =  (handle,item);

ChangeControlState :: !DialogItemId !ControlState !(DialogState s (IOState s))
   -> DialogState s (IOState s);
ChangeControlState id cs dialog
   =  ChangeDialogItems [id] (ChangeControlState` cs) dialog;

ChangeControlState` :: !ControlState !XDItemHandle !(DialogItem s (IOState s))
   -> (!XDItemHandle, !DialogItem s (IOState s));
ChangeControlState` cs (id,w) (Control id` l p s cs` look feel f)
   #
      dfs= Concat (PictureNormal p) (look s cs);
   #!
      strict2=NewXPicture (dialog_item_to_object w);
      w` = Evaluate_2 w (Draw_in_window (1, strict2) (0,0) dfs);
		=
		((id, w`), Control id` l p s cs look feel f);
ChangeControlState` cs handle item =  (handle, item);

ChangeControlLook :: !DialogItemId !ControlLook !(DialogState s (IOState s))
   -> DialogState s (IOState s);
ChangeControlLook id look dialog
   =  ChangeDialogItems [id] (ChangeControlLook` look) dialog;

ChangeControlLook` :: !ControlLook !XDItemHandle !(DialogItem s (IOState s))
   -> (!XDItemHandle, !DialogItem s (IOState s));
ChangeControlLook` look (id,w) (Control id` l p s cs look` feel f)
   #
      dfs= Concat (PictureNormal p) (look s cs);
   #!
      strict2=NewXPicture (dialog_item_to_object w);
      w` = Evaluate_2 w (Draw_in_window (1, strict2) (0,0) dfs);
		=
		((id, w`), Control id` l p s cs look feel f);
ChangeControlLook` look handle item =  (handle, item);

ChangeControlFeel :: !DialogItemId !ControlFeel !(DialogState s (IOState s))
   -> DialogState s (IOState s);
ChangeControlFeel id feel dialog
   =  ChangeDialogItems [id] (ChangeControlFeel` feel) dialog;

ChangeControlFeel` :: !ControlFeel !XDItemHandle !(DialogItem s (IOState s))
   -> (!XDItemHandle, !DialogItem s (IOState s));
ChangeControlFeel` feel handle (Control id` l p s cs look feel` f)
   =  (handle, Control id` l p s cs look feel f);
ChangeControlFeel` feel handle item =  (handle, item);

ChangeDialogFunction :: !DialogItemId !(DialogFunction s (IOState s))
      !(DialogState s (IOState s))
   -> DialogState s (IOState s);
ChangeDialogFunction id f dialog
   =  ChangeDialogItems [id] (ChangeDialogFunction` f) dialog;

ChangeDialogFunction` :: !(DialogFunction s (IOState s)) !XDItemHandle
      !(DialogItem s (IOState s))
   -> (!XDItemHandle, !DialogItem s (IOState s));
ChangeDialogFunction` f handle=:(id,w) (RadioButtons id` l roc did radios)
   #!
		strict1=strict1;
		=
		(handle, RadioButtons id` l roc did (strict1));
	where {
	strict1=ChangeDialogFunctionR id f radios;
		
	};
ChangeDialogFunction` f handle=:(id,w) (DialogPopUp id` l a did radios)
   #!
		strict1=strict1;
		=
		(handle, DialogPopUp id` l a did (strict1));
	where {
	strict1=ChangeDialogFunctionR id f radios;
		
	};
ChangeDialogFunction` f handle=:(id,w) (CheckBoxes id` l roc checks)
   #!
		strict1=strict1;
		=
		(handle, CheckBoxes id` l roc (strict1));
	where {
	strict1=ChangeDialogFunctionC id f checks;
		
	};
ChangeDialogFunction` f handle (Control id l p s cs look feel f`)
   =  (handle, Control id l p s cs look feel f);
ChangeDialogFunction` f handle item =  (handle, item);

ChangeDialogFunctionR :: !DialogItemId !(DialogFunction s (IOState s))
      ![RadioItemDef s (IOState s)]
   -> [RadioItemDef s (IOState s)];
ChangeDialogFunctionR id f [radio=:RadioItem id` t s f` : radios]
   | id == id` =  [RadioItem id` t s f : radios];
   #!
		strict1=strict1;
		=
		[radio : strict1];
	where {
	strict1=ChangeDialogFunctionR id f radios;
		
	};
ChangeDialogFunctionR id f radios =  radios;

ChangeDialogFunctionC :: !DialogItemId !(DialogFunction s (IOState s))
      ![CheckBoxDef s (IOState s)]
   -> [CheckBoxDef s (IOState s)];
ChangeDialogFunctionC id f [check=:CheckBox id` t s m f` : checks]
   | id == id` =  [CheckBox id` t s m f : checks];
   #!
		strict1=strict1;
		=
		[check : strict1];
	where {
	strict1=ChangeDialogFunctionC id f checks;
		
	};
ChangeDialogFunctionC id f checks =  checks;

ChangeButtonFunction :: !DialogItemId !(ButtonFunction s (IOState s))
      !(DialogState s (IOState s))
   -> DialogState s (IOState s);
ChangeButtonFunction id f dialog
   =  ChangeDialogItems [id] (ChangeButtonFunction` f) dialog;

ChangeButtonFunction` :: !(ButtonFunction s (IOState s)) !XDItemHandle
      !(DialogItem s (IOState s))
   -> (!XDItemHandle, !DialogItem s (IOState s));
ChangeButtonFunction` f handle (DialogButton id` l t s f`)
   =  (handle, DialogButton id` l t s f);
ChangeButtonFunction` f handle (DialogIconButton id` l p lo s f`)
   =  (handle, DialogIconButton id` l p lo s f);
ChangeButtonFunction` f handle item =  (handle,item);

ChangeSetFunction :: !(SetFunction s (IOState s)) !(DialogState s (IOState s))
   -> DialogState s (IOState s);
ChangeSetFunction set dialog
   #!
	strict2=DState2DHandle dialog;
		strict1=ChangeSetFunction` set (strict2);
		=
		DHandle2DState (strict1);

ChangeSetFunction` :: !(SetFunction s (IOState s)) !(DialogHandle s (IOState s))
   -> DialogHandle s (IOState s);
ChangeSetFunction` set (DialHandle m h hs def=: (PropertyDialog id t a set` reset items))=  DialHandle m h hs (PropertyDialog id t a set reset items);
ChangeSetFunction` set dialog =  dialog;

ChangeResetFunction	::	 !(ResetFunction s (IOState s))
					!(DialogState s (IOState s)) -> DialogState s (IOState s);
ChangeResetFunction set dialog
   #!
	strict2=DState2DHandle dialog;
		strict1=ChangeResetFunction` set (strict2);
		=
		DHandle2DState (strict1);

ChangeResetFunction` :: !(ResetFunction s (IOState s))
      !(DialogHandle s (IOState s))
   -> DialogHandle s (IOState s);
ChangeResetFunction` reset (DialHandle m h hs def=: (PropertyDialog id t a set reset` items))=  DialHandle m h hs (PropertyDialog id t a set reset items);
ChangeResetFunction` reset dialog =  dialog;

ChangeDialog :: !DialogId ![DialogChange *s] !(IOState *s) -> IOState *s;
ChangeDialog id changes io
   | DialogHandleValid handle #!
      strict2=DHandle2DState (GetDH handle);
		strict1=ChangeDialog` changes
                                      (strict2);
   #   handle`= DState2DHandle (strict1);
		= ChangeDialogHandle id handle` io`;
		=
		io`;
      where {
      (handle, io`)=: GetDialogHandleFromId io id;
		};

DialogHandleValid :: ![DialogHandle s (IOState s)] -> Bool;
DialogHandleValid [] =  False;
DialogHandleValid handle =  True;

GetDH :: ![DialogHandle s (IOState s)] -> DialogHandle s (IOState s);
GetDH [handle] =  handle;

ChangeDialog` :: ![DialogChange *s] !(DialogState *s (IOState *s))
   -> DialogState *s (IOState *s);
ChangeDialog` [change : changes] dialog
   =  ChangeDialog` changes (change dialog);
ChangeDialog` changes dialog =  dialog;

/* Retrieve the DialogInfo from the DialogState */

DialogStateGetDialogInfo	:: !(DialogState s (IOState s))
	-> (!DialogInfo, !DialogState s (IOState s));
DialogStateGetDialogInfo dstate
	#	handle= DState2DHandle dstate;
	#!	strict1=ReconstructDialogHandle handle;
	# 	ddef  = GetDialogDef`` (strict1);
		=
		(DDef2DInfo ddef, DHandle2DState handle);

/* Access rules on the DialogInfo */

GetEditText :: !DialogItemId !DialogInfo -> String;
GetEditText tid dinfo =  RetrieveEditText tid edits;
      where {
      (edits,radios,checks,ctrls)=: DialogInfo2ItemInfo dinfo;
      };

RetrieveEditText :: !DialogItemId ![(DialogItemId,String)] -> String;
RetrieveEditText tid [(id,text):rest]
   | id == tid =  text;
   =  RetrieveEditText tid rest;
RetrieveEditText tid []
   =  DialogError "GetEditText" "No EditText item found with id" tid;

GetSelectedRadioItemId	:: !DialogItemId !DialogInfo -> DialogItemId;
GetSelectedRadioItemId tid dinfo =  RetrieveRadioItemId tid radios;
      where {
      (edits,radios,checks,ctrls)=: DialogInfo2ItemInfo dinfo;
      };

RetrieveRadioItemId :: !DialogItemId ![(DialogItemId,DialogItemId)] -> DialogItemId;
RetrieveRadioItemId tid [(id,di):rest]
   | id == tid =  di;
   =  RetrieveRadioItemId tid rest;
RetrieveRadioItemId tid []
   =  DialogError "GetSelectedRadioItemId" "No RadioButtons or DialogPopUp item found with id" tid;

CheckBoxesMarked	:: !DialogItemId !DialogInfo -> [(DialogItemId,Bool)];
CheckBoxesMarked tid dinfo =  RetrieveCheckMarks tid checks;
      where {
      (edits,radios,checks,ctrls)=: DialogInfo2ItemInfo dinfo;
      };

RetrieveCheckMarks :: !DialogItemId ![(DialogItemId,[(DialogItemId,Bool)])] -> [(DialogItemId,Bool)];
RetrieveCheckMarks tid [(id,boxes):rest]
   | id == tid =  boxes;
   =  RetrieveCheckMarks tid rest;
RetrieveCheckMarks tid []
   =  DialogError "CheckBoxesMarked" "No CheckBoxes item found with id" tid;

CheckBoxMarked :: !DialogItemId !DialogInfo -> Bool;
CheckBoxMarked tid dinfo =  RetrieveCheckMark tid checks;
      where {
      (edits,radios,checks,ctrls)=: DialogInfo2ItemInfo dinfo;
      };

RetrieveCheckMark :: !DialogItemId ![(DialogItemId,[(DialogItemId,Bool)])] -> Bool;
RetrieveCheckMark tid [(id,boxes):rest]
   | found =  mark;
   =  RetrieveCheckMark tid rest;
      where {
      (found,mark)=: FindCheckMark tid boxes;
      };
RetrieveCheckMark tid []
   =  DialogError "CheckBoxMarked" "No CheckBox item found with id" tid;

FindCheckMark :: !DialogItemId ![(DialogItemId,Bool)] -> (Bool,Bool);
FindCheckMark tid [(id,mark):rest]
   | id == tid =  (True,mark);
   =  FindCheckMark tid rest;
FindCheckMark tid [] =  (False,False);

GetControlState	:: !DialogItemId !DialogInfo -> ControlState;
GetControlState tid dinfo =  RetrieveControlState tid ctrls;
      where {
      (edits,radios,checks,ctrls)=: DialogInfo2ItemInfo dinfo;
      };

RetrieveControlState :: !DialogItemId ![(DialogItemId,ControlState)] -> ControlState;
RetrieveControlState tid [(id,state):rest]
   | id == tid =  state;
   =  RetrieveControlState tid rest;
RetrieveControlState tid []
   =  DialogError "GetControlState" "No Control item found with id" tid;
