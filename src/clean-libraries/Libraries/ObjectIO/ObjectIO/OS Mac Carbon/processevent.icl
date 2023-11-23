implementation module processevent


//	Clean Object I/O library, version 1.2

/*	processevent defines the DeviceEventFunction for the process device.
	This function is placed in a separate module because it is platform dependent.
*/


import	StdArray, StdBool, StdList
from	ostypes			import OSNoWindowPtr, :: OSWindowPtr
import	deviceevents, iostate
from	commondef		import fatalError
from	processstack	import topShowProcessShowState
import events,windows
import StdPSt,windowaccess, StdFunc
import osdirectory

//import dodebug
trace_n _ f :== f
trace _ f :== f

from oswindow import osSetCursorShape

processeventFatalError :: String String -> .x
processeventFatalError function error
	= fatalError function "processevent" error


/*	processEvent filters the scheduler events that can be handled by this process device.
	processEvent assumes that it is not applied to an empty IOSt.
*/
processEvent :: !SchedulerEvent !(PSt .l) -> (!Bool,!Maybe DeviceEvent,!SchedulerEvent,!PSt .l)
processEvent schedulerEvent=:(ScheduleOSEvent osEvent=:(_,what,message,_,h,v,_) _) pState
//	| what == NullEvent
//		= (True,Nothing,schedulerEvent,pState)
	| what == OsEvent
		| (message >> 24) bitand 0xFF == SuspendResumeMessage		// Only if 'Accept Suspend' SIZE flag is set...
			| (message bitand ResumeFlag) <> 0						// Activate...
				| (message bitand ConvertClipboardFlag) <> 0		// Require clipboard conversion
					# pState = appPIO (appIOToolbox (osSetCursorShape StandardCursor)) pState
					= trace_n "ProcessActivate..." (True,Just ProcessRequestClipboardChanged,schedulerEvent,pState)
				# pState = appPIO (appIOToolbox (osSetCursorShape StandardCursor)) pState
				= trace_n "ProcessActivate..." (False,Nothing,schedulerEvent,pState)
			// Deactivate...
			= trace_n "ProcessDeactivate" (False,Nothing,schedulerEvent,pState)
//		| (message >> 24) bitand 0xFF == MouseMovedMessage
//			= trace_n "MouseMoved" (False,Nothing,schedulerEvent,pState)
		= (False,Nothing,schedulerEvent,pState)
	| what == HighLevelEvent
		= processHighLevelEvent schedulerEvent pState
	// copied from windowevent...
/*
	# (wDevice,pState)	= accPIO ((\(_,a,b)->(a,b)) o (ioStGetDevice WindowDevice)) pState
//	# (wMetrics, ioState)	= ioStGetOSWindowMetrics ioState
	  windows				= windowSystemStateGetWindowHandles wDevice
	# (wPtr,pState)			= accPIO(accIOToolbox (\tb -> case what of
									MouseDownEvent
										# (_,wPtr,tb)	= FindWindow h v tb
										-> (wPtr,tb)
									MouseUpEvent		-> FrontWindow tb
									KeyDownEvent		-> FrontWindow tb
									KeyUpEvent			-> FrontWindow tb
									AutoKeyEvent		-> FrontWindow tb
									NullEvent			-> FrontWindow tb
									UpdateEvent			-> (message, tb)
									ActivateEvent		-> (message, tb)
									)) pState
	# (isMyWindow,wsH,windows)	= getWindowHandlesWindow (toWID wPtr) windows
*/
	# (lastIO,	pState)			= accPIO ioStLastInteraction pState
	| lastIO
//	| not isMyWindow && lastIO
		# pState				= appPIO checkBeep pState
//*	Waarom gebeurde dit? cq waarom lopen we net te doen of we updates afhandelen die helemaal
//	niet voor ons zijn? Ging in ieder geval mis bij meerdere processen, i.e. bounce.
		# pState				= appPIO (appIOToolbox checkUpdate) pState
//*/
//		# pState = trace_n ("windowevent:filterOSEvent: not my window & lastIO "+++toString wPtr) pState

//		# pState				= appPIO (ioStSetDevice (WindowSystemState windows)) pState
		= (False,Nothing,schedulerEvent,pState)
	with
		
		checkUpdate :: !*OSToolbox -> *OSToolbox
		checkUpdate tb
			| what==UpdateEvent	= EndUpdate message (BeginUpdate message tb)
								= tb
		
		checkBeep :: !(IOSt .l) -> IOSt .l
		checkBeep ioState
			# (optModal,ioState)	= ioStGetIOIsModal ioState
			| isJust optModal && what==MouseDownEvent
								= trace_n ("processevent","checkBeep") beep ioState
								= ioState
	= (False,Nothing,schedulerEvent,pState)


processEvent schedulerEvent pState
	= (False,Nothing,schedulerEvent,pState)

int_from_string s i
	# s1=toInt s.[i]
	# s2=toInt s.[i+1]
	# s3=toInt s.[i+2]
	# s4=toInt s.[i+3]
	= (s1<<24) bitor (s2<<16) bitor (s3<<8) bitor s4;

processHighLevelEvent schedulerEvent=:(ScheduleOSEvent osEvent=:(_,what,message,when,p1,p2,modifiers) _) pState
	# result_string	= createArray 2048 ' '
	# r				= handle_apple_event what message when p1 p2 modifiers result_string
//	# r = trace_n (HighLevelEvent,r) r
	| r == 4 && (result_string%(0,3) == "QUIT")
		= (True,Just ProcessRequestClose,schedulerEvent,pState)					// generate processQuit
	| r >= 6 && (result_string%(0,5) == "SCRIPT")
		= (True,Nothing,schedulerEvent,pState)					// ???
	| r >= 7 && (result_string%(0,6) == "APPDIED")
		= (True,Nothing,schedulerEvent,pState)					// ???
	| r > 4	&& result_string%(0,3) == "OPEN"
//	| r > 4	// assume "OPEN" ???
		# info			= getFileNames 4 r result_string
		# processEvent	= ProcessRequestOpenFiles info
//		= trace_l info (True,Just processEvent,schedulerEvent,pState)
		= (True,Just processEvent,schedulerEvent,pState)
	| r>=6 && result_string%(0,5) == "ANSWER"		// Hmmm MacIDE testing stuff but doesn't actually seem to do anything...
		# pState = trace (/*"a "+++*/toString (int_from_string result_string 6)+++" "
//			+++toString (int_from_string result_string 10)+++" "
//			+++toString (int_from_string result_string 14)+++" "
			+++result_string%(10,r-1)+++" ") pState;

/*		# result_string=result_string % (0,r-1)
		| trace_tn ("processHighLevelEvent "
					+++(toString (int_from_string result_string 6))+++" "
					+++(toString (int_from_string result_string 10))+++" "
					+++toString (size result_string))
			= (True,Nothing,schedulerEvent,pState)
*/
		= (True,Nothing,schedulerEvent,pState)
	= (False,Nothing,schedulerEvent,pState)
where
	getFileNames i r result_string
		| i >= r = []
		= [fileName:getFileNames (i+70) r result_string]
	where
		(fileName,_)	= Get_directory_path vrefnum parid name OSNewToolbox
		vrefnum			= (toInt (result_string.[i]) << 8) bitor (toInt (result_string.[i+1]))
		parid			= (toInt (result_string.[i+2]) << 24)
							bitor (toInt (result_string.[i+3]) << 16)
							bitor (toInt (result_string.[i+4]) << 8)
							bitor (toInt (result_string.[i+5]))
		name			= result_string%(i+7,i+6+length)
		length			= toInt (result_string.[i+6])

//import dodebug,StdDebug
//--

import code from "cae."

install_apple_event_handlers :: Int
install_apple_event_handlers
	= code ()(r=D0) {
		call	.install_apple_event_handlers
	}

handle_apple_event :: !Int !Int !Int !Int !Int !Int !String -> Int
handle_apple_event what message when p1 p2 modifiers string
	= code (modifiers=W,p1=W,p2=W,when=L,message=L,what=W,string=O0D0U)(r=I16D0) {
		instruction 0x38970000		| addi	r4,r23,0
		call	.handle_apple_event
	}

