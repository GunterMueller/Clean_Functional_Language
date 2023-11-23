implementation module interrupt

import StdId, StdPSt, StdTimer
//import PmDriver
import IdeState

//import StdDebug
trace_n m f :== f

StartIntr :: !(!Id,Id) .a (.Bool -> .(.a -> .(*(PSt .b) -> *(.a,*(PSt .b))))) !*(PSt .b) -> *(PSt .b)
StartIntr (dialogId,interruptId) ls callback ps
	# (err,ps)	= openTimer ls timerdef` ps
	= trace_n ("Start: "+++toString err) ps
where
	timerdef`		= Timer 0
						NilLS
						[ TimerId interruptId
						, TimerSelectState Able
						, TimerFunction (TriggerNoIntr interruptId)
						]
	TriggerNoIntr interruptId noi (ls,ps)
		= trace_n "trigger" callback False ls ps

StopIntr :: !(.a,!Id) !*(PSt .b) -> *(PSt .b)
StopIntr (dialogId,interruptId) ps
	= trace_n "Stop" appPIO (closeTimer interruptId) ps

ContIntr :: !(.a,!Id) !*(PSt .b) -> *(PSt .b)
ContIntr (dialogId,interruptId) ps
	= trace_n "Cont" appPIO (enableTimer interruptId) ps
