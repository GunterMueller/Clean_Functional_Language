definition module deltaDialog;

//	Version 0.8.3b

//
//	Module deltaDialog specifies all functions on dialogs. 
//

import deltaIOSystem;
from dialogDef import :: DialogState, :: DialogInfo;
from ioState   import :: IOState;

//	Functions applied on non-existent dialogs or unknown id's are ignored.
    
::	DialogChange *s :== (DialogState s (IOState s)) ->  DialogState s (IOState s) ;

    
/*	OpenDialog opens a modeless property or command dialog. */

OpenDialog	:: !(DialogDef s (IOState s)) !(IOState s) -> IOState s;

/*	OpenModalDialog opens a modal CommandDialog. The function terminates when
	the dialog is closed (by means of Close(Active)Dialog). */

OpenModalDialog	:: !(DialogDef *s (IOState *s)) !*s !(IOState *s) -> (!*s, !IOState *s);

/*	Close(Active)Dialog closes the indicated dialog. */

CloseDialog	:: !DialogId !(IOState s) -> IOState s;
CloseActiveDialog	:: !(IOState s) -> IOState s;

/*	OpenNotice opens a notice (which is always modal) and returns the id of the
	selected notice button. */

OpenNotice :: !NoticeDef !*s !(IOState *s) -> (!NoticeButtonId, !*s, !IOState *s);

/*	A Beep is the simplest kind of notice. */

Beep	:: !(IOState s) -> IOState s;

/*	Get(Active)DialogInfo returns the DialogInfo for the indicated dialog.
	The boolean indicates whether the indicated dialog exists. When it is FALSE
	a dummy DialogInfo is returned. */ 

GetDialogInfo	:: !DialogId !(IOState s) -> (!Bool, !DialogInfo, !IOState s);
GetActiveDialogInfo	:: !(IOState s) -> (!Bool, !DialogInfo, !IOState s);

/*	With the following function the state of dialog items can be changed.
	When an id is specified of an item for which the state change is invalid
	the functions have no effect. */

EnableDialogItems	::	![DialogItemId]		!(DialogState s (IOState s))
						-> DialogState s (IOState s);
DisableDialogItems	::	![DialogItemId]		!(DialogState s (IOState s))
						-> DialogState s (IOState s);
MarkCheckBoxes	::		![DialogItemId]		!(DialogState s (IOState s))
						-> DialogState s (IOState s);
UnmarkCheckBoxes	::	![DialogItemId]		!(DialogState s (IOState s))
						-> DialogState s (IOState s);
SelectDialogRadioItem	::	!DialogItemId	!(DialogState s (IOState s))
						-> DialogState s (IOState s);
ChangeEditText	:: !DialogItemId !String	!(DialogState s (IOState s))
						-> DialogState s (IOState s);
ChangeDynamicText	:: !DialogItemId !String	!(DialogState s (IOState s))
						-> DialogState s (IOState s);
ChangeIconLook	:: !DialogItemId !IconLook	!(DialogState s (IOState s))
						-> DialogState s (IOState s);

/*	Functions to change state, look and feel (behaviour) of Controls. When the
	id is not the id of a Control the functions have no effect. */

ChangeControlState	::	!DialogItemId !ControlState !(DialogState s (IOState s))
						-> DialogState s (IOState s);
ChangeControlLook	::	!DialogItemId !ControlLook !(DialogState s (IOState s))
						-> DialogState s (IOState s);
ChangeControlFeel	::	!DialogItemId !ControlFeel !(DialogState s (IOState s))
						-> DialogState s (IOState s);

/*	Functions to change the functions related to dialog items. */

ChangeDialogFunction	:: !DialogItemId !(DialogFunction s (IOState s))
					!(DialogState s (IOState s)) -> DialogState s (IOState s);
ChangeButtonFunction	:: !DialogItemId !(ButtonFunction s (IOState s))
					!(DialogState s (IOState s)) -> DialogState s (IOState s);
ChangeSetFunction	::	 !(SetFunction s (IOState s))
					!(DialogState s (IOState s)) -> DialogState s (IOState s);
ChangeResetFunction	::	 !(ResetFunction s (IOState s))
					!(DialogState s (IOState s)) -> DialogState s (IOState s);

/* DialogStateGetDialogInfo returns the DialogInfo corresponding to
   the DialogState given to it. */

DialogStateGetDialogInfo	:: !(DialogState s (IOState s))
	-> (!DialogInfo, !DialogState s (IOState s));

/*	Functions that return the current contents of dialog items that
	can be changed by the user. When the corresponding item cannot
	be found a run-time error will be generated. The function
	CheckBoxesMarked returns the settings of a group of CheckBoxes.
	The id passed to it should be an id of such a group. The id
	passed to GetSelectedRadioItemId must be eihter the id of a
	DialogPopUp or the id of a group of RadioButtons. */

GetEditText	::      !DialogItemId !DialogInfo -> String;
GetSelectedRadioItemId	:: !DialogItemId !DialogInfo -> DialogItemId;
CheckBoxesMarked	:: !DialogItemId !DialogInfo -> [(DialogItemId,Bool)];
CheckBoxMarked	::   !DialogItemId !DialogInfo -> Bool;
GetControlState	::  !DialogItemId !DialogInfo -> ControlState;

/*	ChangeDialog can be used to modify open (modeless) dialogs. */

ChangeDialog	:: !DialogId ![DialogChange *s] !(IOState *s) -> IOState *s;
