definition module osevent

//	Clean Object I/O library, version 1.2

//import	events
import	ostime
import	ostypes
from	StdMaybe	import :: Maybe//, Just, Nothing


showEvent :: !OSEvent -> {#Char}


::	*OSEvents

osNewEvents		:: OSEvents
//osCopyEvents	:: !OSEvents -> (!OSEvents,!OSEvents)		PA: not used
osAppendEvents	:: !*[OSEvent] !OSEvents -> OSEvents		// osAppendEvents adds events at the end of the queue
osInsertEvents	:: !*[OSEvent] !OSEvents -> OSEvents		// osInsertEvents adds events at the front of the queue
osIsEmptyEvents	:: !OSEvents -> (!Bool,!OSEvents)
osRemoveEvent	:: !OSEvents -> (!OSEvent,!OSEvents)


::	OSEvent
	:== (!Bool,!Int,!Int,!Int,!Int,!Int,!Int)
::	OSSleepTime			// The max time the process allows multi-tasking
	:== Int

osNullEvent :: OSEvent	// osNullEvent returns a valid non-informative event

// OSLongSleep :: OSSleepTime
OSLongSleep	:==	60	//65535
// OSNoSleep :: OSSleepTime
OSNoSleep	:== 0	//0

osHandleEvents			:: !(.s -> (Bool,.s)) 
						   !(.s -> (OSEvents,.s)) !((OSEvents,.s) -> .s)
						   !(.s -> (Int,.s))
						   !(OSEvent -> .s -> ([Int],.s))
						   !(!.s,!*OSToolbox)
						->  (!.s,!*OSToolbox)
osEventIsUrgent			:: !OSEvent -> Bool
//setReplyInOSEvent		:: ![Int] -> OSEvent

/*	createOS(Dea/A)ctivateWindowEvent creates the event the platform would generate for a genuine (de)activate event. */
createOSActivateWindowEvent		:: !OSWindowPtr !*OSToolbox -> (!OSEvent,!*OSToolbox)
createOSDeactivateWindowEvent	:: !OSWindowPtr !*OSToolbox -> (!OSEvent,!*OSToolbox)

/*	createOS(Dea/A)ctivateControlEvent creates the event the platform would generate for a genuine (de)activate event. */
createOSActivateControlEvent	:: !OSWindowPtr !OSWindowPtr !*OSToolbox -> (!OSEvent,!*OSToolbox)
createOSDeactivateControlEvent	:: !OSWindowPtr !OSWindowPtr !*OSToolbox -> (!OSEvent,!*OSToolbox)

/*	createOSLoose(Mouse/Key)Event creates the event for reporting loss of mouse/keyboard input (virtual event). */
createOSLooseMouseEvent	:: !OSWindowPtr !OSWindowPtr !*OSToolbox -> (!OSEvent,!*OSToolbox)
createOSLooseKeyEvent	:: !OSWindowPtr !OSWindowPtr !*OSToolbox -> (!OSEvent,!*OSToolbox)

/*	createOSZeroTimerEvent  creates the event for reporting continued zero timer (virtual event).
	getOSZeroTimerStartTime returns the registered time in the virtual event. Nothing is returned if wrong argument.
*/
createOSZeroTimerEvent	:: !OSTime -> OSEvent
getOSZeroTimerStartTime	:: !OSEvent -> Maybe OSTime

//======

startTracking :: !OSTime !*OSToolbox -> *OSToolbox
stopTracking :: !*OSToolbox -> *OSToolbox
loadTracking :: !*OSToolbox -> (!Int,!*OSToolbox)
