definition module deltaIOSystem;

//	Version 0.8.3b

//
//	Module deltaIOSystem specifies the IOSystems and Devices
//	that can be used in Concurrent Clean Event I/O
//

from deltaPicture import :: Picture, :: Rectangle, :: DrawFunction, :: Point;

    

::	IOSystem		 * s * io	:== [DeviceSystem s io];
::	DeviceSystem * s * io	= TimerSystem	 [TimerDef	s io]
										|  MenuSystem	 [MenuDef 	s io]
										|  WindowSystem [WindowDef	s io]
										|  DialogSystem [DialogDef	s io];
						

/*	The timer device:
	The Timer responds only to timer events. A timer event occurs as
	soon as a certain TimerInterval (a number in terms of 1/TicksPerSecond
	seconds (see deltaTimer.dcl)) has expired since the last time it was
	`sampled'. The timer event causes the programmer defined TimerFunction
	to be evaluated. The TimerState argument of the TimerFunction indicates
	how many times the TimerInterval has expired since the last timer
	event. The timer device can initially be Able or Unable (SelectState).

::	TimerDef UNQ s UNQ io
	->	Timer TimerId SelectState TimerInterval (TimerFunction s io);
::	TimerId							-> INT;
::	TimerInterval					-> INT;
::	TimerFunction UNQ s UNQ io	-> => TimerState (=> s (=> io (s, io)));
::	TimerState						-> INT;


<<	The menu device may consist of several PullDownMenus. The PullDownMenus
	are logically grouped into a menu bar, in the same order as they are
	specified. PullDownMenus are selected by pressing the mousebutton on
	their MenuTitle in the MenuBar. Menus contain MenuElements. The
	MenuFunction of an element is executed when the element is selected. >>

::	MenuDef UNQ s UNQ io
		-> PullDownMenu MenuId MenuTitle SelectState [MenuElement s io];
::	MenuElement UNQ s UNQ io
		-> MenuItem			MenuItemId ItemTitle KeyShortcut
								SelectState (MenuFunction s io)
		-> CheckMenuItem  MenuItemId ItemTitle KeyShortcut
								SelectState MarkState (MenuFunction s io)
		-> SubMenuItem		MenuId ItemTitle SelectState [MenuElement  s io]
		-> MenuItemGroup	MenuItemGroupId [MenuElement  s io]
		-> MenuRadioItems	MenuItemId [RadioElement s io]
		-> MenuSeparator;
::	RadioElement UNQ s UNQ io
		-> MenuRadioItem MenuItemId ItemTitle KeyShortcut
								SelectState (MenuFunction s io);
::	MenuFunction UNQ s UNQ io -> => s (=> io (s, io));
::	MenuId		  		-> INT;
::	MenuItemId	  		-> INT;
::	MenuItemGroupId	-> INT;
::	KeyShortcut			-> Key KeyCode | NoKey;


<<	The window device may consist of several ScrollWindows or FixedWindows.
	A ScrollWindow is defined by the following arguments:
	- WindowId			 : the number by which the programmer refers to the window.
	- WindowPos			 : the position of the upper-left corner of the window.
	- WindowTitle		 : the title of the window.
	- WindowColourType : NormalColour allows only 8 colours (see deltaPicture)
	                 			and FullColour allows all RGB colours. Don't use
	                     	FullColour windows on the Macintosh Plus.
	- ScrollBarDefs	 : the horizontal and vertical scrollbars (in that order).
	- PictureDomain	 : the range of the drawing operations in the window.
	- MinimumWindowSize: the smallest dimensions of the (contents of a) window.
	- InitialWindowSize: the initial dimensions of the (contents of a) window.
	- UpdateFunction	 : the function to redraw parts (UpdateArea) of the window.
	- An attribute list that may contain the following window attributes:
		- Activate	: the way to respond to activation of the window.
		- Deactivate: the way to respond to deactivation of the window.
		- GoAway		: the way to respond to a click in the go-away area.
		- Keyboard  : the way the window responds to keyboard input.
		- Mouse     : the way the window responds to mouse input.
		- Cursor    : the shape of the mouse pointer inside the window.
		- StandByWindow: When this attribute is present the window will be a so-called
		                 stand-by window: The mouse event related to the activation
		                 of the window will be handled also.
	A FixedWindow has a fixed size, which is defined by its PictureDomain.
	Therefore it has no scroll bars and no size parameters. When the PictureDomain
	of a FixedWindow becomes greater that on of the screen's dimensions it
	becomes a ScrollWindow. >>

::	WindowDef UNQ s UNQ io
	-> ScrollWindow WindowId WindowPos WindowTitle
						 ScrollBarDef ScrollBarDef
						 PictureDomain MinimumWindowSize InitialWindowSize
						 (UpdateFunction s) [WindowAttribute s io]
	-> FixedWindow WindowId WindowPos WindowTitle
						PictureDomain (UpdateFunction s) [WindowAttribute s io];

::	WindowId					-> INT;
::	WindowPos				-> (!INT, !INT);
::	WindowTitle				-> STRING;
::	ScrollBarDef			-> ScrollBar ThumbValue ScrollValue;
::	ThumbValue				-> Thumb  INT;
::	ScrollValue				-> Scroll INT;
::	MinimumWindowSize		-> (!INT, !INT);
::	InitialWindowSize		-> (!INT, !INT);
::	UpdateArea				-> [Rectangle];
::	UpdateFunction UNQ s	-> => UpdateArea (=> s (s, [DrawFunction]));

::	WindowAttribute UNQ s UNQ io
		->	Activate		(WindowFunction s io)
		->	Deactivate	(WindowFunction s io)
		->	GoAway		(WindowFunction s io)
		->	Mouse			SelectState (MouseFunction s io)
		->	Keyboard		SelectState (KeyboardFunction s io)
		->	Cursor		CursorShape
		->	StandByWindow;

::	WindowFunction	  UNQ s UNQ io -> => s (=> io (s, io));		
::	MouseFunction	  UNQ s UNQ io -> => MouseState	  (=> s (=> io (s, io)));
::	KeyboardFunction UNQ s UNQ io -> => KeyboardState (=> s (=> io (s, io)));

::	KeyboardState	-> (!KeyCode, !KeyState, !Modifiers);
::	KeyCode			-> CHAR;
::	KeyState			-> KeyUp | KeyDown | KeyStillDown;

::	MouseState		-> (!MousePosition, !ButtonState, !Modifiers);
::	MousePosition	-> (!INT, !INT);
::	ButtonState		-> ButtonUp | ButtonDown | ButtonDoubleDown |
							ButtonTripleDown | ButtonStillDown;

::	CursorShape	->	StandardCursor	| BusyCursor     | IBeamCursor |
                  CrossCursor    | FatCrossCursor | ArrowCursor | HiddenCursor;


<<	The dialog device: Modal dialogs given in the initial dialog device are
	ignored. Use the Open(Modal)Dialog function (deltaDialog.icl) to open dialogs
	during the interaction. PropertyDialogs are special modeless dialogs with
	two predefined buttons: the Set and the Reset button. A CommandDialog can
	be modal as well as modeless.
	A PropertyDialog is defined by the following attributes:
	- DialogId: a number by which the programmer can refer to the dialog.
	- DialogTitle: The title of the dialog (ignored for modal dialogs).
	- A list of attributes that may contain the following dialog attributes:
	  - DialogPos	 : The position of the dialog on the screen.
	  - DialogSize	 : The size of the dialog.
	  - DialogMargin: The horizontal and vertical margins between the borders
	                  of the dialog and the items.
	  - ItemSpace	 : The horizontal and vertical space between the items of
	                  the dialog.
	  - StandByDialog: When this attribute is present the dialog will be a so-called
	                   stand-by dialog: it will also react to the MouseDown related
	                   to activation of the dialog.
	  When none of these attributes is specified the dialog is centered on
	  the screen, a size is chosen such that all items fit in the dialog and
	  safe default margins and item spaces are chosen. The first Measure always
	  is the horizontal attribute value, the second is always the vertical
	  attribute value.
	- SetFunction/ResetFunction: The button function for the set/reset button.
	- A list of DialogItems		: Other items such as CheckBoxes, Control's etc..
	A CommandDialog also has an id, a title, a position, a size and a list of
	DialogItems. Furthermore it has the following attribute:
	- DialogItemId: The item id of the default button.
	In the AboutDialog information about the application (version, authors etc.)
	can be presented. The first AboutDialog encountered in the initial
	DialogDevice becomes the AboutDialog of the application. Attempts to open
	AboutDialogs with OpenDialog are ignored. The AboutDialog may contain a button
	which should provide a help facility. The AboutDialog will be accessible by
	the user during the interaction in a system-dependent way. >>

::	DialogDef UNQ s UNQ io
	-> PropertyDialog DialogId DialogTitle [DialogAttribute] (SetFunction s io)
	                  (ResetFunction s io) [DialogItem s io]
	-> CommandDialog  DialogId DialogTitle [DialogAttribute]
	                  DialogItemId [DialogItem s io]
	-> AboutDialog    ApplicationName PictureDomain [DrawFunction] (AboutHelpDef s io);

::	DialogId		-> INT;
::	DialogTitle	-> STRING;
::	DialogAttribute
	-> DialogPos    Measure Measure
	-> DialogSize   Measure Measure
	-> DialogMargin Measure Measure
	-> ItemSpace    Measure Measure
	-> StandByDialog;
::	Measure     -> MM REAL | Inch REAL | Pixel INT;

::	ApplicationName -> STRING;
::	AboutHelpDef UNQ s UNQ io
	-> AboutHelp ItemTitle (AboutHelpFunction s io)
	-> NoHelp;
::	AboutHelpFunction UNQ s UNQ io -> => s (=> io (s,io));

<<	A DialogItem can be a final button (DialogButton), a final button with a
	user-defined look (DialogIconButton), an unchangable piece of text
	(StaticText), a changeable piece of text (DynamicText), an editable text
	field (EditText), a group of RadioButtons, a group of CheckBoxes, or a
	user-defined Control. The ItemPos specifies the position of the item
	relative to the other items. When the ItemPos is DefPos the item is placed
	beneath all other items, left-aligned. >>

::	DialogItem UNQ s UNQ io
	-> DialogButton DialogItemId ItemPos ItemTitle SelectState
		             (ButtonFunction s io)
	-> DialogIconButton DialogItemId ItemPos PictureDomain IconLook
	                    SelectState (ButtonFunction s io)
	-> StaticText DialogItemId ItemPos STRING
	-> DynamicText DialogItemId ItemPos TextWidth STRING
	-> EditText DialogItemId ItemPos TextWidth NrEditLines STRING
	-> DialogPopUp  DialogItemId ItemPos SelectState DialogItemId
	                [RadioItemDef s io]
	-> RadioButtons DialogItemId ItemPos RowsOrColumns DialogItemId
	                [RadioItemDef s io]
	-> CheckBoxes DialogItemId ItemPos RowsOrColumns [CheckBoxDef s io]
	-> Control DialogItemId ItemPos PictureDomain SelectState ControlState
		        ControlLook ControlFeel (DialogFunction s io);

::	DialogItemId	-> INT;
::	ItemPos		-> Left | Center | Right | RightTo DialogItemId |
			Below DialogItemId | XOffset DialogItemId Measure |
						   YOffset DialogItemId Measure | XY Measure Measure |
						   ItemBox INT INT INT INT;
::	IconLook			-> => SelectState [DrawFunction];
::	TextWidth		-> Measure;
::	NrEditLines		-> INT;
::	RowsOrColumns	-> Rows INT | Columns INT;

::	RadioItemDef UNQ s UNQ io
	-> RadioItem DialogItemId ItemTitle SelectState (DialogFunction s io);
::	CheckBoxDef UNQ s UNQ io
	-> CheckBox DialogItemId ItemTitle SelectState MarkState
	            (DialogFunction s io);

<<	Attributes of a user-defined control: The ControlState can be a boolean, an
	integer, a real, a string or a pair or list of one of these basic types.
	The look of the Control is defined by the list of drawfunctions returned by
	the ControlLook function. The ControlFeel defines the way to respond to mouse
	clicks in the Control's picture domain. >>

::	ControlState	-> BoolCS BOOL | IntCS INT | RealCS REAL | StringCS STRING |
						   PairCS ControlState ControlState | ListCS [ControlState];
::	ControlLook	 -> => SelectState (=> ControlState [DrawFunction]);
::	ControlFeel	 -> => MouseState  (=> ControlState
                                      (ControlState,[DrawFunction]));

<<	Types of the several dialog item functions. >>

::	SetFunction    UNQ s UNQ io -> ButtonFunction s io;
::	ResetFunction  UNQ s UNQ io -> ButtonFunction s io;
::	DialogFunction UNQ s UNQ io
	-> => DialogInfo (=> (DialogState s io) (DialogState s io));
::	ButtonFunction  UNQ s UNQ io
	-> => DialogInfo (=> s (=> io (s,io)));

<<	A notice is a simple, modal dialog containing only text and final buttons.
	It can be used to inform the user about unusual or dangerous situations.
	Notices can be opened with the OpenNotice function (deltaDialog) A notice
	is defined by the following attributes:
	- A list of strings: Each string is a line of the message of the notice.
	- A NoticeButtonDef: The default button of the notice.
	- A list of NoticeButtonDefs: The other buttons of the notice. >>

::	NoticeDef		 -> Notice [STRING] NoticeButtonDef [NoticeButtonDef];
::	NoticeButtonDef -> NoticeButton NoticeButtonId ItemTitle;
::	NoticeButtonId	 -> INT;


<<	For each modifier (Shift,Option,Command,Control) a boolean in Modifiers
	indicates whether it was pressed (TRUE) or not (FALSE). On systems that
	have no Command key both the third and the fourth boolean become TRUE when
	Control is pressed. >>

::	Modifiers 	-> (BOOL,BOOL,BOOL,BOOL);
::	ItemTitle	-> STRING;
::	SelectState	-> Able | Unable;
::	MarkState	-> Mark | NoMark;
*/

from timerDef import
	:: TimerDef (Timer), :: TimerId, :: TimerInterval, :: TimerFunction, :: TimerState;
from menuDef import
	:: MenuDef (PullDownMenu),
		:: MenuId, :: MenuTitle,
		:: MenuItemId,
		:: KeyShortcut (Key, NoKey), :: MenuFunction,
		:: MenuElement (MenuItem, CheckMenuItem, SubMenuItem,
				MenuItemGroup, MenuRadioItems, MenuSeparator),
		:: MenuItemGroupId, :: RadioElement (MenuRadioItem);
from windowDef import
	:: WindowDef
		(ScrollWindow, FixedWindow),
			:: WindowId, :: WindowPos, :: WindowTitle,
			:: MinimumWindowSize, :: InitialWindowSize, :: UpdateFunction,
		:: ScrollBarDef (ScrollBar),
		:: ThumbValue (Thumb), :: ScrollValue (Scroll),
		:: UpdateArea,
		:: WindowAttribute (Activate, Deactivate, GoAway,
		Mouse,
		Keyboard,
		StandByWindow,
		Cursor),
		:: WindowFunction, :: MouseFunction, :: KeyboardFunction,
		:: CursorShape
			(StandardCursor, BusyCursor, IBeamCursor,
			CrossCursor, FatCrossCursor, ArrowCursor, HiddenCursor);
from dialogDef import
// RWS
	:: DialogHandle, :: XDialogHandle, :: XDItemHandle, :: XHandle,
	:: Id, :: Widget,
	:: DialogMode (Modal, Modeless),
	:: DialogState,
	:: DialogInfo,
	:: DialogDef
		(PropertyDialog, CommandDialog, AboutDialog),
		:: DialogId, :: DialogTitle,
		:: DialogAttribute
			(DialogSize, DialogPos, DialogMargin, ItemSpace, StandByDialog),
		:: Measure (MM, Inch, Pixel),
		:: SetFunction, :: ResetFunction,
		:: ApplicationName,
			:: AboutHelpDef (AboutHelp, NoHelp), :: AboutHelpFunction,
		:: DialogItemId,
		:: DialogItem (DialogButton, DialogIconButton, StaticText, DynamicText,
				EditText, DialogPopUp, RadioButtons, CheckBoxes, Control),
		:: ItemPos
			(Left, Center, Right, RightTo, Below, XOffset, YOffset, XY, ItemBox),
		:: ButtonFunction,
		:: IconLook,
		:: TextWidth, :: NrEditLines,
		:: RowsOrColumns (Rows, Columns),
		:: RadioItemDef (RadioItem),
		:: DialogFunction, 
		:: CheckBoxDef (CheckBox),
		:: ControlLook, :: ControlFeel,
		:: ControlState (BoolCS, IntCS, RealCS, StringCS, PairCS, ListCS),
	:: NoticeDef (Notice),
		:: NoticeButtonId, :: NoticeButtonDef (NoticeButton);
from commonDef import
	:: ItemTitle,
	:: SelectState (Able, Unable),
	:: MarkState (Mark, NoMark),
	:: KeyboardState, :: KeyCode,
	:: KeyState (KeyUp, KeyDown, KeyStillDown),
	:: MouseState, :: MousePosition,
	:: ButtonState (ButtonUp, ButtonDown, ButtonDoubleDown, ButtonTripleDown, ButtonStillDown),
	:: Modifiers,
	:: PictureDomain;
