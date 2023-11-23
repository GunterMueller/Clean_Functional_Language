implementation module processevent


//	Clean Object I/O library, version 1.2

/*	processevent defines the DeviceEventFunction for the process device.
	This function is placed in a separate module because it is platform dependent.
*/


import	StdArray, StdBool, StdList
from	clCrossCall_12	import CcWmDDEEXECUTE, CcWmPROCESSCLOSE, CcWmPROCESSDROPFILES
from	clCrossCall_12	import CcWmDRAWCLIPBOARD, :: CrossCallInfo(..)
from	clCCall_12		import winGetCStringAndFree, :: CSTR
from	ostypes			import OSNoWindowPtr, :: OSWindowPtr
import	deviceevents, iostate
from	commondef		import fatalError
from	processstack	import topShowProcessShowState

trace_n` m f :== f

processeventFatalError :: String String -> .x
processeventFatalError function error
	= fatalError function "processevent" error


/*	processEvent filters the scheduler events that can be handled by this process device.
	processEvent assumes that it is not applied to an empty IOSt.
*/
processEvent :: !SchedulerEvent !(PSt .l) -> (!Bool,!Maybe DeviceEvent,!SchedulerEvent,!PSt .l)
processEvent schedulerEvent=:(ScheduleOSEvent osEvent=:{ccMsg} _) pState=:{io=ioState}
	| isProcessOSEvent ccMsg
		# (processStack,ioState)		= ioStGetProcessStack ioState
		  (found,systemId)				= topShowProcessShowState processStack
		# (ioId,ioState)				= ioStGetIOId ioState
		# (osdInfo,ioState)				= ioStGetOSDInfo ioState
		# (tb,ioState)					= getIOToolbox ioState
		# (myEvent,replyToOS,deviceEvent,tb)
		  								= filterOSEvent osEvent (found && systemId==ioId) osdInfo tb
		# ioState						= setIOToolbox tb ioState
		# pState						= {pState & io=ioState}
		  schedulerEvent				= if (isJust replyToOS) (ScheduleOSEvent osEvent (fromJust replyToOS)) schedulerEvent
		= (myEvent,deviceEvent,schedulerEvent,pState)
	| otherwise
		= (False,Nothing,schedulerEvent,pState)
where
	isProcessOSEvent :: !Int -> Bool
	isProcessOSEvent CcWmDDEEXECUTE			= True
	isProcessOSEvent CcWmPROCESSCLOSE		= True
	isProcessOSEvent CcWmPROCESSDROPFILES	= True
	isProcessOSEvent CcWmDRAWCLIPBOARD		= True
	isProcessOSEvent 141		= True
	isProcessOSEvent 142		= True
	isProcessOSEvent 143		= True
	isProcessOSEvent _						= False

processEvent schedulerEvent pState
	= (False,Nothing,schedulerEvent,pState)

/*	filterOSEvent filters the OSEvents that can be handled by this process device.
		The Bool argument is True iff the parent process is visible and active.
*/
filterOSEvent :: !OSEvent !Bool !OSDInfo !*OSToolbox -> (!Bool,!Maybe [Int],!Maybe DeviceEvent,!*OSToolbox)

// DvA...
filterOSEvent {ccMsg=141} isActive _ tb
	| not isActive
		= (False,Nothing,Nothing,tb)
	= trace_n` "ConsoleQuitEvent" (True, Nothing, Just (ConsoleQuitEvent), tb)
filterOSEvent {ccMsg=142,p1} isActive _ tb
	| not isActive
		= (False,Nothing,Nothing,tb)
	# (string,tb)	= winGetCStringAndFree p1 tb
	= trace_n` "ConsoleOutEvent" (True, Nothing, Just (ConsoleOutEvent string), tb)
filterOSEvent {ccMsg=143,p1} isActive _ tb
	| not isActive
		= (False,Nothing,Nothing,tb)
	# (string,tb)	= winGetCStringAndFree p1 tb
	=  trace_n` "ConsoleErrEvent" (True, Nothing, Just (ConsoleErrEvent string), tb)
// ...DvA
filterOSEvent {ccMsg=CcWmDDEEXECUTE,p1=cString} isActive _ tb
	| not isActive
		= (False,Nothing,Nothing,tb)
	| otherwise
		# (fName,tb)	= winGetCStringAndFree cString tb
		= (True,Nothing,Just (ProcessRequestOpenFiles [fName]),tb)

filterOSEvent {ccMsg=CcWmPROCESSCLOSE,p1=framePtr} _ osdInfo tb
	| framePtr==getOSDInfoFramePtr osdInfo
		= (True,Nothing,Just ProcessRequestClose,tb)
	| otherwise
		= (False,Nothing,Nothing,tb)

filterOSEvent {ccMsg=CcWmPROCESSDROPFILES,p1=framePtr,p2=cString} _ osdInfo tb
	| framePtr<>getOSDInfoFramePtr osdInfo
		= (False,Nothing,Nothing,tb)
	| otherwise
		# (allNames,tb)	= winGetCStringAndFree cString tb
		  allNames		= if (allNames.[size allNames-1]=='\n') allNames (allNames+++"\n")
		= (True,Nothing,Just (ProcessRequestOpenFiles (filter ((<>) "") (getFileNames 0 0 (size allNames) allNames []))),tb)
where
//	getFileNames assumes that the file names are separated by a single '\n' and the string ends with a '\n'.
	getFileNames :: !Int !Int !Int !String [String] -> [String]
	getFileNames low up nrChars allNames fNames
		| up>=nrChars			= fNames
		| allNames.[up]=='\n'	= getFileNames (up+1) (up+1) nrChars allNames [allNames%(low,up-1):fNames]
		| otherwise				= getFileNames low (up+1) nrChars allNames fNames

filterOSEvent {ccMsg=CcWmDRAWCLIPBOARD} _ osdInfo tb
	// of moeten we moeilijker doen en aan alle process doorgeven?
	= (True,Nothing,Just ProcessRequestClipboardChanged,tb)
//	= (False,Nothing,Nothing,tb)

filterOSEvent _ _ _ _
	= processeventFatalError "filterOSEvent" "unmatched OSEvent"


getOSDInfoFramePtr :: !OSDInfo -> OSWindowPtr
getOSDInfoFramePtr osdInfo
	= case (getOSDInfoOSInfo osdInfo) of
		Just info -> info.osFrame
		_         -> OSNoWindowPtr
