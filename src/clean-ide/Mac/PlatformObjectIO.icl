implementation module PlatformObjectIO

import StdInt, StdMisc, StdFile
import StdTuple,StdOverloaded,StdArray
import StdPSt
import StdIOCommon
import StdSystem

import windowaccess, iostate, StdBool,menuwindowmenu
import code from library "winmod_library"

initPlatformCommandLineArguments :: !*(PSt .l) -> (![String],!*PSt .l)
initPlatformCommandLineArguments ps
	= ([],ps)

installPlatformEventHandlers :: !*(PSt .l) -> *(PSt .l)
installPlatformEventHandlers ps
	| install_apple_event_handlers == 0
//		= trace_n "apple events installed" ps
		= ps
//	= trace_n "installing apple events failed :-(" ps
	= ps

openPlatformWindowMenu :: !*(PSt .l) -> *(PSt .l)
openPlatformWindowMenu ps
	= ps
//	= openWindowMenu ps

// FIXME: should be IdePlatform
pAbort			:: !(PSt .a) -> PSt .a
pAbort ps = ps

install_apple_event_handlers :: Int
install_apple_event_handlers
	= code ()(r=D0) {
		call	.install_apple_event_handlers
	}

//////////////

getWindowModified :: !Id !(IOSt .l) -> (!Maybe Bool,!IOSt .l)
getWindowModified id ioState
	# (found,wDevice,ioState)	= ioStGetDevice WindowDevice ioState
	| not found
		= (Nothing,ioState)
	# windows					= windowSystemStateGetWindowHandles wDevice
	  (found,wsH,windows)		= getWindowHandlesWindow (toWID id) windows
	| not found
		= (Nothing,ioStSetDevice (WindowSystemState windows) ioState)
	| otherwise
		# (mod,wsH,ioState)		= getWindowModified wsH ioState
		= (Just mod,ioStSetDevice (WindowSystemState (setWindowHandlesWindow wsH windows)) ioState)
where
	getWindowModified wsH=:{wshIds={wPtr}} ioState
		# (mod,ioState)			= accIOToolbox (IsWindowModified wPtr) ioState
		= (mod<>0,wsH,ioState)
	
	IsWindowModified :: !OSWindowPtr !*OSToolbox -> (!Int,!*OSToolbox)
	IsWindowModified wPtr ioState = code {
		ccall IsWindowModified "PI:I:I"
		}

:: OSStatus	:== Int

setWindowModified :: !Id !String !Bool !(IOSt .l) -> IOSt .l
setWindowModified id windowName mod ioState
	# windowTitle				= if mod ("¥"+++windowName) windowName
	# ioState					= changeWindowInWindowMenu id windowTitle ioState

	# (found,wDevice,ioState)	= ioStGetDevice WindowDevice ioState
	| not found
		= ioState
	# windows					= windowSystemStateGetWindowHandles wDevice
	  (found,wsH,windows)		= getWindowHandlesWindow (toWID id) windows
	| not found
		= ioStSetDevice (WindowSystemState windows) ioState
	| otherwise
		# (wsH,ioState)			= setWindowModified wsH mod ioState
		= ioStSetDevice (WindowSystemState (setWindowHandlesWindow wsH windows)) ioState
where
	setWindowModified wsH=:{wshIds={wPtr}} mod ioState
		# (err,ioState)			= accIOToolbox (SetWindowModified wPtr (if mod (1 << 24) 0)) ioState
		= (wsH,ioState)
	
	SetWindowModified :: !OSWindowPtr !Int !*OSToolbox -> (!OSStatus,!*OSToolbox)
	SetWindowModified wPtr mod ioState = code {
		ccall SetWindowModified "PII:I:I"
		}
