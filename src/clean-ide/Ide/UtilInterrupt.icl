implementation module UtilInterrupt

import StdClass,StdBool,StdInt, StdList
import StdTimer, StdWindow
import IdeState

// Convert to message passing...?
// Zero timers really aren't nice. Should be a separate thread.

getDialogExistence id io
	# (st,io)	= getDialogsStack io
	= (isMember id st, io)

:: Callback l :== Bool (*PSt l) -> *PSt l

StartIntr :: !(!Id,!Id) !(Callback General) !*(PSt General) -> *(PSt General)
StartIntr (dialogId,interruptId) callback ps
	# ps		= setCallback callback ps
	# (exists,ps)	= accPIO (getDialogExistence dialogId) ps
	| exists
		# (_,ps)	= openTimer 0 timerdef ps
		= callback False ps
	# (_,ps)	= openTimer 0 timerdef` ps
	= callback False ps
where
	timerdef		= Timer 0
						NilLS
						[ TimerId interruptId
						, TimerSelectState Unable
						, TimerFunction (TriggerIntr dialogId interruptId)
						]
	timerdef`		= Timer 0
						NilLS
						[ TimerId interruptId
						, TimerSelectState Unable
						, TimerFunction (TriggerNoIntr interruptId)
						]

TriggerIntr dialogId interruptId noi (ls, ps)
	# (callback,ps) = getCallback ps
	# (exists,ps)	= accPIO (getDialogExistence dialogId) ps
	| exists
		# ps		= appPIO (disableTimer interruptId) ps
		= (ls,callback False ps)
	# ps			= closeWindow dialogId ps
	# ps			= appPIO (closeTimer interruptId) ps
	= (ls,callback True  ps)
	
TriggerNoIntr interruptId noi (ls,ps)
	# (callback,ps) = getCallback ps
	# ps			= appPIO (disableTimer interruptId) ps
	= (ls,callback False ps)

StopIntr :: !(!Id,!Id) !*(PSt .l) -> *(PSt .l)
StopIntr (dialogId,interruptId) ps
	= appPIO (closeTimer interruptId) ps
	
ContIntr :: !(!Id,!Id) !(Callback General) !*(PSt General) -> *(PSt General)
ContIntr (dialogId,interruptId) callback ps
	# ps			= setCallback callback ps
	= appPIO (enableTimer interruptId) ps
