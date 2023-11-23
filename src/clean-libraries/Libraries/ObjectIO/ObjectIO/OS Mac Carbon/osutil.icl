implementation module osutil

import StdEnv//, StdIO
import ostypes, ostoolbox,commondef
import events,pointer,controls, windows
from quickdraw import QNewRgn, QGetClip, QClipRect, QSetClip, QGetPort, QSetPort, QDisposeRgn, :: GrafPtr
	, QGlobalToLocal, QLocalToGlobal, /*GetRegionBounds,*/ GetWindowPort, SetPortWindowPort
from oswindow import accGrafport, appGrafport
import windowhandle
//import dodebug

loadUpdateBBox :: !OSWindowPtr !*OSToolbox -> (!OSRect,!*OSToolbox)
loadUpdateBBox wPtr tb
	# (err,bb,tb)	= GetWindowBounds wPtr kWindowUpdateRgn tb
	| err <> 0 = abort ("loadUpdateBBox failed: " +++ toString err+++ "\n")
	# (l,t, r,b)	= toTuple4 bb
//	# tb = abort`` tb ("loadUpdateBBox",wPtr,(l,t),(r,b))
	# (ltLocal,tb)	= accGrafport wPtr (GlobalToLocal {x=l,y=t}) tb
//	# tb = abort`` tb ("loadUpdateBBox",wPtr,((l,t),(r,b)),ltLocal)
	# (rbLocal,tb)	= accGrafport wPtr (GlobalToLocal {x=r,y=b}) tb
	= (fromTuple4 (ltLocal.x,ltLocal.y, rbLocal.x,rbLocal.y),tb)

loadUpdateRegion :: !OSWindowPtr !*OSToolbox -> (!OSRgnHandle,!*OSToolbox)
loadUpdateRegion wPtr tb
	# (rgn,tb)	= QNewRgn tb
	# tb		= GetWindowRegion wPtr kWindowUpdateRgn rgn tb
	= (rgn,tb)

kWindowUpdateRgn		:== 34

GetWindowBounds :: !OSWindowPtr !Int !*OSToolbox -> (!Int,!OSRect,!*OSToolbox)
GetWindowBounds wPtr rgnCode tb
	# (err,tl,br,tb)	= GetWindowBounds wPtr rgnCode tb
	= (err,{rleft = tl bitand 0xFFFF, rtop = tl >> 16,rright = br bitand 0xFFFF, rbottom = br >> 16},tb)
where
	GetWindowBounds :: !OSWindowPtr !Int !*OSToolbox -> (!Int,!Int,!Int,!*OSToolbox)
	GetWindowBounds _ _ _ = code {
		ccall GetWindowBounds "II:III:I"
		}

GlobalToLocal :: !Point2 !*OSToolbox -> (!Point2,!*OSToolbox)
GlobalToLocal {x,y} tb
#	(x,y,tb)	= QGlobalToLocal x y tb
=	({x=x,y=y},tb)

LocalToGlobal :: !Point2 !*OSToolbox -> (!Point2,!*OSToolbox)
LocalToGlobal {x,y} tb
#	(x,y,tb)	= QLocalToGlobal x y tb
=	({x=x,y=y},tb)

/*	Mouse access functions:
*/
GetMousePosition :: !*OSToolbox -> (!Point2, !*OSToolbox)
GetMousePosition tb
#	(x,y,tb)	= GetMouse tb
=	({x=x,y=y},tb)

WaitForMouseUp :: !*OSToolbox -> *OSToolbox
WaitForMouseUp tb
#	(mouseDown,tb)	= WaitMouseUp tb
|	mouseDown		= WaitForMouseUp tb
					= tb

toModifiers :: !Int -> Modifiers
toModifiers flags
=	{	shiftDown	= FlagIsSet flags 512
	,	optionDown	= FlagIsSet flags 2048
	,	commandDown	= FlagIsSet flags 256
	,	controlDown	= FlagIsSet flags 4096
	,	altDown		= False
	}

FlagIsSet flags flag	:== (flags bitand flag) <> 0

/*	Convert a KeyMap (returned by GetKeys) into Modifiers (5 Booleans of which altDown==False).
*/
KeyMapToModifiers :: !(!Int,!Int,!Int,!Int) -> Modifiers
KeyMapToModifiers (w1,word,w3,w4) =
	{ shiftDown		= FlagIsSet word ShiftMask		// shift <> 0
	, optionDown	= FlagIsSet word OptionMask		// option <> 0
	, commandDown	= FlagIsSet word CommandMask	// command <> 0
	, controlDown	= FlagIsSet word ControlMask	// control <> 0
	, altDown		= False
	}
where
	shift	= word bitand ShiftMask
	option	= word bitand OptionMask
	command	= word bitand CommandMask
	control	= word bitand ControlMask

ShiftMask				:== 1
OptionMask				:== 4
CommandMask				:== 32768
ControlMask				:== 8

/*	Check the status of the keyboard yields (return/enter, return/enter still, command '.') down.
*/
KeyEventInfo :: !Int !Int !Int -> (Bool,Bool,Bool)
KeyEventInfo what message mods
|	what==KeyDownEvent	= (returnOrEnter, False, commandPeriod || escape)
|	what==AutoKeyEvent	= (False, returnOrEnter, False)
						= (False, False, False)
where
	returnOrEnter		= (returnCode==charCode || enterCode==charCode) && ms+cmdKey==0
	commandPeriod		= '.'==charCode && ms==0 && cmdKey <> 0
	escape				= escapeCode==virtCode && ms+cmdKey==0
	ms					= shiftKey + optionKey + controlKey
	cmdKey				= mods bitand 256
	shiftKey			= mods bitand 512
	alphaLock			= mods bitand 1024
	optionKey			= mods bitand 2048
	controlKey			= mods bitand 4096
	charCode			= toChar (message bitand 255)
	virtCode			= (message>>8) bitand 255

returnCode	:== '\015'
enterCode	:== '\003'
escapeCode	:== 53

/*	Conversion of (KeyDown/AutoKey/KeyUp) Event message field to ASCII and key code.
*/
getASCII :: !Int -> Char	// return character code (MacASCII)
getASCII message = toChar (message bitand 255)

getMacCode :: !Int -> Int	// return virtual keycode
getMacCode message = (message>>8) bitand 255

/*	Conversion of (KeyDown/AutoKey/KeyUp) Event what field to KeyState.
*/
keyEventToKeyState :: !Int -> KeyState
keyEventToKeyState KeyDownEvent	= KeyDown False
keyEventToKeyState AutoKeyEvent	= KeyDown True
keyEventToKeyState KeyUpEvent	= KeyUp

//---s


assertPort` :: !OSWindowPtr !*OSToolbox -> *OSToolbox
assertPort` w tb
	# (p,tb)	= GetWindowPort w tb
	# (q,tb)	= QGetPort tb
	| p <> q
		= osutilFatalError "assertPort`" "ports unequal!"
	= tb

osutilFatalError :: String String -> .x
osutilFatalError function error
	= fatalError function "osutil" error

doWindowScrollers :: !OSWindowPtr !WindowData !Size !*OSToolbox -> (!WindowInfo,!*OSToolbox)
doWindowScrollers wPtr info {w,h} tb = accGrafport wPtr (doScrollers` info) tb
where
	doScrollers` info=:{windowHScroll,windowVScroll} tb
		# (rgn,tb)	= QNewRgn tb
		# (rgn,tb)	= QGetClip rgn tb
		# tb		= case windowHScroll of
				(Just {scrollItemPtr})	-> Draw1Control scrollItemPtr (QClipRect hrect tb) 
				Nothing					-> tb
		# tb		= case windowVScroll of
				(Just {scrollItemPtr})	-> Draw1Control scrollItemPtr (QClipRect vrect tb) 
				Nothing					-> tb
		# tb		= QClipRect grect tb
		# tb		= DrawGrowIcon wPtr tb
		# tb		= QSetClip rgn tb
		# tb		= QDisposeRgn rgn tb
		= (WindowInfo info,tb)
	where
		hrect = ( 0, h - 15, w - 16, h) // compare with scrollItemPos,Size
		vrect = ( w - 15, 0, w, h - 16) // id
		grect = ( w - 15, h - 15, w, h)
	
kWindowContentRgn		:== 33

appClipped :: !OSWindowPtr !(IdFun *OSToolbox) !*OSToolbox -> *OSToolbox
appClipped wPtr f tb
	| wPtr == 0		= abort "osutil:appClipped: called with nil wPtr"
	#!	(port,tb)	= QGetPort		tb
		tb			= SetPortWindowPort wPtr	tb
		(rgn, tb)	= QNewRgn		tb
		(rgn, tb)	= QGetClip rgn	tb
		(rgn`,tb)	= QNewRgn tb
		tb			= GetWindowRegion wPtr kWindowContentRgn rgn` tb
		tb			= QSetClip rgn` tb
		tb			= f tb
		tb			= QSetClip		rgn	tb
		tb			= QDisposeRgn	rgn	tb
		tb			= QDisposeRgn rgn` tb
		tb			= QSetPort		port	tb
	= tb
	
//--

OSRect2Rect r	:== (rleft,rtop,rright,rbottom)
where
	{rleft,rtop,rright,rbottom} = r

Rect2OSRect	(l,t,r,b)	:== {rleft=l,rtop=t,rright=r,rbottom=b}

zoomWindow :: !OSWindowPtr !Int !Bool !*Toolbox -> *Toolbox;
zoomWindow wPtr rHdl b tb = appGrafport wPtr (ZoomWindow wPtr rHdl b) tb

invalRect :: !OSWindowPtr !Rect !*Toolbox -> *Toolbox;
invalRect wPtr r tb = InvalWindowRect wPtr r tb
