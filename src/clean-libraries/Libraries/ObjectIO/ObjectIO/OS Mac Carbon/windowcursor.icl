implementation module windowcursor


import	StdBool, StdTuple
import	OS_utilities,pointer,iostate
import	commondef, windowaccess
from	windowdefaccess	import getWindowCursorAtt, isWindowCursor, 
								isAllWindowsAttribute, isWindowOnlyAttribute, isDialogOnlyAttribute
import osutil,osrgn,oswindow
from quickdraw import QPtInRgn, QGlobalToLocal, QDisposeRgn, QDiffRgn, QRectRgn, QNewRgn
from quickdraw import QUnionRgn, QInitCursor, QHideCursor, QSetCursor, QShowCursor
//import dodebug

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

/*	checkcursorinfo sets the appropriate cursor shape. 
	The arguments h and v must be in global coordinates.
*/
checkcursorinfo :: !Int !Int !OSWindowPtr !(WindowHandles .ps) !(IOSt .l) -> (!WindowHandles .ps,!IOSt .l)
checkcursorinfo h v wPtr windows ioState
//	# ioState = trace_n` ("checkcursorinfo",h,v,wPtr) ioState
	#	(cInfo,windows)			= getWindowHandlesCursorInfo windows
	|	cInfo.cGlobalSet		= (windows,ioState)
	|	not cInfo.cInfoChanged	= (windows,ioState)
	#	wasInRgn				= cInfo.cMouseWasInRgn
		localRgn				= cInfo.cLocalRgn
		(inRgn,ioState)			= accIOToolbox (accGrafport wPtr (pointInRgn h v localRgn)) ioState
	|	inRgn==wasInRgn			= (windows,ioState)
	#	cInfo1					= {cInfo & cInfoChanged=False, cMouseWasInRgn=inRgn}
		windows					= setWindowHandlesCursorInfo cInfo1 windows
	|	inRgn					= (windows,appIOToolbox (osSetCursorShape cInfo.cLocalShape) ioState)
	#	ioState					= appIOToolbox (osSetCursorShape StandardCursor) ioState
	= (windows,ioState)

pointInRgn :: !Int !Int !OSRgnHandle !*OSToolbox -> (!Bool, !*OSToolbox)
pointInRgn h v rgnH tb
#	(h,v,tb)	= QGlobalToLocal h v tb
=	QPtInRgn (h,v) rgnH tb

confirmcursorinfo :: !Int !Int !OSWindowPtr !CursorShape !OSRgnHandle !(WindowHandles .ps) !(IOSt .l) -> (!WindowHandles .ps,!IOSt .l)
confirmcursorinfo h v wPtr cursor clipRgn windows ioState
//#	(clipRgn,dPtr,cursor,dsH1)	= (\dsH=:(DialogLSHandle {dlsHandle={dhClip,dhPtr,dhAtts}})->(dhClip,dhPtr,getCursor dhAtts,dsH)) dsH
#	(cInfo,windows)				= getWindowHandlesCursorInfo windows
	globalSet					= cInfo.cGlobalSet
|	/*not found &&*/ globalSet	= (windows,appIOToolbox (osSetCursorShape cInfo.cGlobalShape)	ioState)
//|	not found					= appIOToolbox (osSetCursorShape StandardCursor)		ioState
#	(tb,ioState)				= getIOToolbox ioState
	((w,h),tb)					= osGetWindowViewFrameSize wPtr tb
	(aidRgn,tb)					= QNewRgn tb
	tb							= QRectRgn aidRgn (0,0,w,h) tb
	(aidRgn1,tb)				= QDiffRgn aidRgn clipRgn aidRgn tb
	(inBack, tb)				= accGrafport wPtr (pointInRgn h v aidRgn1) tb
	cInfo1						= {cInfo &	cMouseWasInRgn	= inBack
										 ,	cLocalShape		= cursor
								  }
	(cInfo2, tb)				= cursorinfoSetLocalRgn aidRgn1 cInfo1 tb
	tb							= QDisposeRgn aidRgn1 tb
	windows						= setWindowHandlesCursorInfo cInfo2 windows
//	dsH2						= DialogStateHandleSetDialogClip clipRgn dsH1
//	ioState						= IOStReplaceDialog dsH2 ioState
|	globalSet					= (windows,setIOToolbox (osSetCursorShape cInfo.cGlobalShape tb)	ioState)
|	inBack						= (windows,setIOToolbox (osSetCursorShape cursor tb)				ioState)
								= (windows,setIOToolbox (osSetCursorShape StandardCursor tb)		ioState)


cursorinfoSetLocalRgn :: !OSRgnHandle !CursorInfo !*OSToolbox -> (!CursorInfo,!*OSToolbox)
cursorinfoSetLocalRgn backRgnH cInfo tb
#	tb				= QRectRgn localRgnH zero tb
	(localRgnH1,tb)	= QUnionRgn localRgnH backRgnH localRgnH tb
=	(	{cInfo	& cInfoChanged	= True
				, cLocalRgn		= localRgnH1
		}
	,	tb
	)
where
	localRgnH		= cInfo.cLocalRgn
	zero			= (0,0,0,0)
	

cursorinfoSetLocalCursor :: !CursorShape !CursorInfo -> CursorInfo
cursorinfoSetLocalCursor cShape cInfo = {cInfo & cLocalShape=cShape}

cursorinfoSetGlobalCursor :: !CursorShape !CursorInfo !*OSToolbox -> (!CursorInfo, !*OSToolbox)
cursorinfoSetGlobalCursor HiddenCursor cInfo tb
=	(cInfo,tb)
cursorinfoSetGlobalCursor cShape cInfo tb
=	(	{cInfo	&	cGlobalSet	=True
				,	cGlobalShape=cShape
		}
	,	osSetCursorShape cShape tb
	)

cursorinfoResetGlobalCursor :: !CursorInfo !*OSToolbox -> (!CursorInfo, !*OSToolbox)
cursorinfoResetGlobalCursor cInfo tb = ({cInfo & cGlobalSet=False}, tb)


/*	PA: moved to oswindow; renamed to osSetCursorShape.
//	Set the cursor shape.

IBeamC	:== 1
CrossC	:== 2
PlusC	:== 3
WatchC	:== 4

setCursorShape	:: !CursorShape !*OSToolbox -> *OSToolbox
setCursorShape StandardCursor	tb = QInitCursor			tb
setCursorShape BusyCursor		tb = setCursorShape` WatchC	tb
setCursorShape IBeamCursor		tb = setCursorShape` IBeamC	tb
setCursorShape CrossCursor		tb = setCursorShape` CrossC	tb
setCursorShape FatCrossCursor	tb = setCursorShape` PlusC	tb
setCursorShape HiddenCursor		tb = QHideCursor			tb
setCursorShape _				tb = QInitCursor			tb

setCursorShape`	:: !Int !*OSToolbox -> *OSToolbox
setCursorShape` cursorId tb
#	(cursorH,tb)= GetCursor cursorId	tb
	(cursor, tb)= LoadLong  cursorH		tb
	tb			= QShowCursor			tb
	tb			= QSetCursor cursor		tb
=	tb
*/
