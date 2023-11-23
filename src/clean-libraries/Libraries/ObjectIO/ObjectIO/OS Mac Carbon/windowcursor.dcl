definition module windowcursor


//from	mac_types		import RgnHandle, OSToolbox
import ostoolbox,ostypes,osrgn
from	iostate			import :: IOSt
from	id				import :: Id
import	windowhandle
from	StdMaybe		import :: Maybe//, Just, Nothing
from	StdWindowDef	import :: CursorShape
//								,StandardCursor, BusyCursor, IBeamCursor, 
//								CrossCursor, FatCrossCursor, ArrowCursor, HiddenCursor

/*
::	CursorInfo
	=	{	cInfoChanged	:: Bool							// True if cLocalRgn or cMouseWasInRgn has changed
		,	cLocalRgn		:: OSRgnHandle					// Background region of active window
		,	cMouseWasInRgn	:: Bool							// Previous mouse was in background region
		,	cLocalShape		:: CursorShape					// Cursor shape of active window
		,	cGlobalSet		:: Bool							// Global cursor is set
		,	cGlobalShape	:: CursorShape					// Global cursor shape
		}
*/
//checkcursorinfo :: !Int !Int !(IOSt .l) -> IOSt .l
checkcursorinfo :: !Int !Int !OSWindowPtr !(WindowHandles .ps) !(IOSt .l) -> (!WindowHandles .ps,!IOSt .l)
/*	checkcursorinfo sets the appropriate cursor shape if necessary. 
	The Integer arguments must be the global mouse coordinates. */
	
//confirmcursorinfo :: !Int !Int !(IOSt .l) -> IOSt .l
confirmcursorinfo :: !Int !Int !OSWindowPtr !CursorShape !OSRgnHandle !(WindowHandles .ps) !(IOSt .l) -> (!WindowHandles .ps,!IOSt .l)
/*	confirmcursorinfo sets the appropriate cursor shape. 
	The Integer arguments must be the global mouse coordinates. */

cursorinfoSetLocalRgn		:: !OSRgnHandle	!CursorInfo !*OSToolbox -> (!CursorInfo, !*OSToolbox)
cursorinfoSetLocalCursor	:: !CursorShape	!CursorInfo			 ->   CursorInfo

cursorinfoSetGlobalCursor	:: !CursorShape	!CursorInfo !*OSToolbox -> (!CursorInfo, !*OSToolbox)
cursorinfoResetGlobalCursor	::				!CursorInfo !*OSToolbox -> (!CursorInfo, !*OSToolbox)
