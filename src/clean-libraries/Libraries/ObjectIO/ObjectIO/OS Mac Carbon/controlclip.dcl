definition module controlclip


from	controls	import	ControlHandle
from quickdraw		import GrafPtr
import	wstate


//trackClippedControl		:: !OSWindowPtr !Rect !ControlHandle !Point2		  !*OSToolbox -> (!Int,!*OSToolbox)
//trackRectArea			:: !OSWindowPtr !Rect !Rect !*OSToolbox -> (!Bool,!*OSToolbox)
//trackCustomButton		:: !OSWindowPtr !Rect !Rect !*OSToolbox -> (!Bool,!*OSToolbox)
	
//setClippedControlValue	:: !OSWindowPtr !Rect !ControlHandle !Int			  !*OSToolbox -> *OSToolbox
//hiliteClippedControl	:: !OSWindowPtr !Rect !ControlHandle !Int			  !*OSToolbox -> *OSToolbox
//scrollClippedRect		:: !Vector2    !Rect								  !*OSToolbox -> (![Rect],!*OSToolbox)
/*
calcUpdateRgn			:: ![Rect]										  !*OSToolbox -> (!OSRgnHandle,!*OSToolbox)
calcDialogClip			:: !Rect !(Maybe Id) ![WElementHandle .ls .ps] !*OSToolbox -> (!OSRgnHandle,![WElementHandle .ls .ps],!*OSToolbox)
calcDialogClip`			:: !Rect !(Maybe Id) ![WElementHandle`]        !*OSToolbox -> (!OSRgnHandle,!*OSToolbox)
*/
//openClipDrawing :: !OSWindowPtr !*OSToolbox -> (!GrafPtr,!OSRgnHandle,!*OSToolbox)
//closeClipDrawing :: !GrafPtr !OSRgnHandle !*OSToolbox -> *OSToolbox
