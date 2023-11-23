implementation module osevent


import	StdInt, StdBool, StdList, StdMaybe, StdTuple
import	events, desk, pointer
import	StdClass, StdMisc
import	code from "cTCP."
import osrgn,commondef,ostime
from	quickdraw import QRectRgn, QLocalToGlobal, QNewRgn

//import StdDebug
//import dodebug

DebugTraceEvents msg osEvent state
	:== state
/*
	= case isIgnoreEvent osEvent of
			True	-> state
			False	-> DebugStr (msg +++ showEvent osEvent) state
where
	isIgnoreEvent (_,what,_,_,_,_,_) = what == NullEvent || what == OsEvent
*/


oseventFatalError :: String String -> .x
oseventFatalError function error
	= fatalError function "osevent" error
	
::	*OSEvents
	//	=	Event Int				// The event stream
	:== [OSEvent]

//	The empty event stream:

osNewEvents :: OSEvents
osNewEvents = []	//Event 0

/*	PA: does not seem to be used.
osCopyEvents :: !OSEvents -> (!OSEvents,!OSEvents)
//OScopyEvents (Event e)
//	= (Event e, Event e)
osCopyEvents []
	= ([],[])
osCopyEvents [e:es]
	= ([e:es1],[e:es2])
where
	(es1,es2)	= osCopyEvents es
*/

osAppendEvents	:: !*[OSEvent] !OSEvents -> OSEvents
osAppendEvents newEvents osEvents
	= osEvents ++ newEvents
	
osInsertEvents	:: !*[OSEvent] !OSEvents -> OSEvents
osInsertEvents newEvents osEvents
	= newEvents ++ osEvents
	
osIsEmptyEvents	:: !OSEvents -> (!Bool,!OSEvents)
osIsEmptyEvents []
	= (True, [])
osIsEmptyEvents osEvents
	= (False, osEvents)
	
osRemoveEvent	:: !OSEvents -> (!OSEvent,!OSEvents)
osRemoveEvent [osEvent:osEvents]
	= (osEvent,osEvents)
osRemoveEvent []
	= oseventFatalError "osRemoveEvent" "OSEvents argument is empty"

::	OSEvent				:== (!Bool,!Int,!Int,!Int,!Int,!Int,!Int)
//::	CrossCallInfo		= CCI				// Dummy to keep imports happy	(PA: not required anymore)
::	OSSleepTime			:== Int				// The max time the process allows multi-tasking

osNullEvent :: OSEvent
osNullEvent = (True,NullEvent,0,0,0,0,0)	// ???

//OSLongSleep				:==	2147483647		// The application requires no timing (2^31-1)
//OSLongSleep				:== 65535			// The application requires no timing (2^16-1)
OSLongSleep		:==	60//1//60

OSNoSleep		:== 0//1//0

mRgn =: rgn

rgn
	# (rgn,tb)	= QNewRgn OSNewToolbox
	# (x,y,tb)	= GetMouse tb
	# (x,y,tb)	= QLocalToGlobal x y tb
	# tb		= QRectRgn rgn (x,y,inc x,inc y) tb
	| tb == OSNewToolbox = rgn
	= abort "initialising mouseRegion failed"

osHandleEvents	:: !(.s -> (Bool,.s)) !(.s -> (OSEvents,.s)) !((OSEvents,.s) -> .s) !(.s -> (Int,.s)) !(OSEvent -> .s -> ([Int],.s)) !(!.s,!*OSToolbox) -> (!.s,!*OSToolbox)
osHandleEvents isFinalState getOSEvents setOSEvents getSleepTime handleOSEvent (state,tb)
	# (terminate,state) 		= isFinalState state
	# (now,tb)	= TickCount tb
	| terminate
		= (state,tb)
	# (osEvents,state)			= getOSEvents state
	# (noDelayEvents,osEvents)	= osIsEmptyEvents osEvents
	| noDelayEvents
		# (sleep,state)			= getSleepTime state
		# (tracking,tb)			= loadTracking tb
		# (sleep,tb) = case tracking of
							0  -> (min OSLongSleep sleep,tb)
							-1 -> (max 1 sleep,stopTracking tb)
							_  -> (sleep,tb)
		# (x,y,tb)				= GetMouse tb
		# (x,y,tb)				= QLocalToGlobal x y tb
		# (osEvent,osEvents,tb)	= EventsWaitEvent sleep mRgn osEvents tb
		# tb = case osEvent of
					(b,OsEvent,message,_,x,y,_)	-> if ((message >> 24) bitand 0xFF == MouseMovedMessage) (QRectRgn mRgn (x,y,inc x,inc y) tb) tb
					_ -> tb
		# state					= setOSEvents (osEvents,state)
		# state					= DebugTraceEvents ("Event["+++toString (now,sleep,tracking)+++"]:\t") osEvent state
		# (_,state)				= handleOSEvent osEvent state
		= osHandleEvents isFinalState getOSEvents setOSEvents getSleepTime handleOSEvent (state,tb)
	# (osEvent,osEvents)		= osRemoveEvent osEvents
	# state						= setOSEvents (osEvents,state)
	# state						= DebugTraceEvents ("Delayed["+++toString now+++"]:\t") osEvent state
	# (_,state)					= handleOSEvent osEvent state
	= osHandleEvents isFinalState getOSEvents setOSEvents getSleepTime handleOSEvent (state,tb)

showEvent :: !OSEvent -> {#Char}
showEvent (_,what,mess,when,_,_,_) = case what of
	NullEvent		-> "NullEvent@"+++toString when
	MouseDownEvent	-> "MouseDownEvent"
	MouseUpEvent	-> "MouseUpEvent"
	KeyDownEvent	-> "KeyDownEvent"
	KeyUpEvent		-> "KeyUpEvent"
	AutoKeyEvent	-> "AutoKeyEvent"
	UpdateEvent 	-> "UpdateEvent"
	DiskEvent		-> "DiskEvent"
	ActivateEvent	-> "ActivateEvent"
	NetworkEvent	-> "NetworkEvent"
	DriverEvent 	-> "DriverEvent"
	OsEvent			| (mess >> 24) bitand 0xFF == MouseMovedMessage		-> "MouseMovedEvent"
					| (mess >> 24) bitand 0xFF == SuspendResumeMessage	-> "SuspendResumeEvent"
					-> "OsEvent"
	HighLevelEvent	-> "HighLevelEvent"
	InetEvent		-> "InetEvent"
	_				-> "unknown event: " +++ toString what
	
osEventIsUrgent	:: !OSEvent -> Bool
osEventIsUrgent osEvent=:(_,what,_,when,_,_,_)
	| what == NullEvent
		# (time,_) = loadTracking OSNewToolbox
		| time == 0
			= False
		| when - 2 < time
			= False
			= True
	= True
	
//setReplyInOSEvent	:: ![Int] -> OSEvent
//setReplyInOSEvent 

createOSActivateWindowEvent		:: !OSWindowPtr !*OSToolbox -> (!OSEvent,!*OSToolbox)
createOSActivateWindowEvent wPtr tb
	# event = (True,ActivateEvent,wPtr,0,0,0,1)	// dummy implementation
	= // trace_n "createOSActivateWindowEvent: dummy"
		(event,tb)
	
createOSDeactivateWindowEvent	:: !OSWindowPtr !*OSToolbox -> (!OSEvent,!*OSToolbox)
createOSDeactivateWindowEvent wPtr tb
	# event = (True,ActivateEvent,wPtr,0,0,0,0)	// dummy implementation
	= // trace_n "createOSDeactivateWindowEvent: dummy"
		(event,tb)	// dummy implementation

createOSActivateControlEvent	:: !OSWindowPtr !OSWindowPtr !*OSToolbox -> (!OSEvent,!*OSToolbox)
createOSActivateControlEvent wPtr cPtr tb
	= // trace_n "createOSActivateControlEvent: dummy"
		(osNullEvent,tb)	// dummy implementation

createOSDeactivateControlEvent	:: !OSWindowPtr !OSWindowPtr !*OSToolbox -> (!OSEvent,!*OSToolbox)
createOSDeactivateControlEvent wPtr cPtr tb
	= // trace_n "createOSDeactivateControlEvent: dummy"
		(osNullEvent,tb)	// dummy implementation


createOSLooseMouseEvent	:: !OSWindowPtr !OSWindowPtr !*OSToolbox -> (!OSEvent,!*OSToolbox)
createOSLooseMouseEvent wPtr cPtr tb
	= // trace_n "createOSLooseMouseEvent: dummy"
		(osNullEvent,tb)	// dummy implementation

createOSLooseKeyEvent	:: !OSWindowPtr !OSWindowPtr !*OSToolbox -> (!OSEvent,!*OSToolbox)
createOSLooseKeyEvent wPtr cPtr tb
	= // trace_n "createOSLooseKeyEvent: dummy"
		(osNullEvent,tb)	// dummy implementation
/*
createOSKeyDownEvent		:: !OSWindowPtr !*OSToolbox -> (!OSEvent,!*OSToolbox)
createOSKeyDownEvent wPtr tb
	= ((True,what,message,when,wherex,wherey,modifiers),tb)
where
	what			= KeyDownEvent
	message	= 
	when			= 0
	wherex		= 0
	wherey		= 0
	modifiers	= mods
	
m2i :: !Modifiers -> Int
m2i flags = a + b + c + d + e
where
	a
		| flags.shiftDown	= 512
		= 0
	b
		| flags.optionDown	= 2048
		= 0
	c
		| flags.commandDown	= 256
		= 0
	d
		| flags.controlDown	= 4096
	,	altDown		= False
	}
*/
createOSZeroTimerEvent	:: !OSTime -> OSEvent
createOSZeroTimerEvent (OSTime zeroStart)
	= (True,NullEvent,0,zeroStart,0,0,0)

getOSZeroTimerStartTime	:: !OSEvent -> Maybe OSTime
getOSZeroTimerStartTime (interesting,what,message,i,h,v,mods)
	| interesting && what == NullEvent
		= Just (OSTime i)
	= Nothing

//	Two ways to retrieve events from the event stream:

DeviceMaskGetNextEvent	:== 383				// UpdateMask+ActivMask+KeyboardMask+MouseMask+1
DeviceMaskWaitNextEvent	:== -32385			// OsMask+DeviceMaskGetNextEvent
DeviceMaskWNHEvent		:== -31361			// HighLevelEventMask+DeviceMaskWaitNextEvent

//	On a non multi-tasking Macintosh (using GetNextEvent):
/*
EventsGetEvent :: !*OSEvents !*OSToolbox -> (!OSEvent,!*OSEvents,!*OSToolbox)
EventsGetEvent events tb
#	(event,tb) = GetEvent tb
=	(event,events,tb)

GetEvent :: !*OSToolbox -> (!OSEvent,!*OSToolbox)
GetEvent tb
|	True
=	abort "event.icl: GetEvent used"
#	(interesting,what,message,i,h,v,mods,tb)	= GetNextEvent DeviceMaskGetNextEvent tb
|	interesting || what==NullEvent
=	((interesting,what,message,i,h,v,mods), tb)
=	GetEvent (SystemTask tb)
*/
//	On a multi-tasking Macintosh (using WaitNextEvent):

EventsWaitEvent :: !Int !OSRgnHandle !*OSEvents !*OSToolbox -> (!OSEvent,!*OSEvents,!*OSToolbox)
EventsWaitEvent sleep mouseRgn events tb
#	(event, tb) = WaitEvent sleep mouseRgn tb
=	(event,events,tb)

/* MW: it was:

WaitEvent :: !Int !OSRgnHandle !*OSToolbox -> (!OSEvent,!*OSToolbox)
WaitEvent sleep mouseRgn tb
#	(interesting,what,message,i,h,v,mods,tb)	= WaitNextEvent DeviceMaskWaitNextEvent sleep mouseRgn tb
|	interesting || what==NullEvent
	=	((interesting,what,message,i,h,v,mods), tb)
=	WaitEvent sleep mouseRgn tb
*/

WaitEvent :: !Int !OSRgnHandle !*OSToolbox -> (!OSEvent,!*OSToolbox)
WaitEvent sleep mouseRgn tb
// MW: WaitNextEventC also returns TCP events
//#	(interesting,what,message,i,h,v,mods,tb)	= WaitNextEvent DeviceMaskWaitNextEvent 0 mouseRgn tb
//#	event = (interesting,what,message,i,h,v,mods)
# (caret,tb) = GetCaretTime tb							// <= kan je in osLongSleep regelen...
//# tb = abort`` tb "WaitEvent: after GetCaretTime"
# sleep = min sleep caret
//#	(event=:(interesting,what,message,i,h,v,mods),tb)	= WaitNextEventC DeviceMaskWaitNextEvent sleep mouseRgn tb
#	(event=:(interesting,what,message,i,h,v,mods),tb)	= WaitNextEventC DeviceMaskWNHEvent sleep mouseRgn tb
//# (interesting,what,message,i,h,v,mods,tb)				= WaitNextEvent DeviceMaskWNHEvent sleep mouseRgn tb
//# event = (interesting,what,message,i,h,v,mods)
//# tb = abort`` tb "WaitEvent: after WaitNextEventC"
|	interesting || what==NullEvent
	=	(event, tb)
=	WaitEvent sleep mouseRgn tb

WaitNextEventC :: !Int !Int !OSRgnHandle !*OSToolbox -> (!OSEvent, !*OSToolbox)
WaitNextEventC _ _ _ _
	= code
		{
			ccall WaitNextEventC "IIII-IIIIIIII"
		}

//===
import memory,pointer

tracking =: iniTrack

iniTrack
	# (ptr,err,tb)	= NewPtr 4 OSNewToolbox
	| err <> 0 || tb <> OSNewToolbox = abort "initialising tracking info failed..."
	# ptr = StoreLong ptr 0 tb
//	| tb <> OSNewToolbox = abort "initialising tracking info failed..."
	= ptr

startTracking :: !OSTime !*OSToolbox -> *OSToolbox
startTracking (OSTime time) tb = StoreLong tracking time tb

stopTracking :: !*OSToolbox -> *OSToolbox
stopTracking tb = StoreLong tracking 0 tb

loadTracking :: !*OSToolbox -> (!Int,!*OSToolbox)
loadTracking tb = LoadLong tracking tb
