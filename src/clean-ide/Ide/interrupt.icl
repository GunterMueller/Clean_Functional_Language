implementation module interrupt

import StdList
import StdPSt, StdId, StdTimer, StdWindow

checkDialogExistence id io
	# (st,io)	= getDialogsStack io
	= (isMember id st,io)

StartIntr :: !(!Id,Id) .a (.Bool -> .(.a -> .(*(PSt .b) -> *(.a,*(PSt .b))))) !*(PSt .b) -> *(PSt .b)
StartIntr (dialogId,interruptId) ls callback ps
	# (exist,ps)	= accPIO (checkDialogExistence dialogId) ps
	| exist
		# (err,ps)	= openTimer ls timerdef ps
		| err <> NoError
			= ps
		= ps
	# (_,ps)	= openTimer ls timerdef` ps
	= ps
where
	timerdef		= Timer 0
						NilLS
						[ TimerId interruptId
						, TimerSelectState Able
						, TimerFunction (TriggerIntr dialogId interruptId)
						]
	timerdef`		= Timer 0
						NilLS
						[ TimerId interruptId
						, TimerSelectState Able
						, TimerFunction (TriggerNoIntr interruptId)
						]

	TriggerIntr dialogid interruptId noi (ls, ps)
		# (exist,ps)	= accPIO (checkDialogExistence dialogId) ps
		| exist
			# ps		= appPIO (disableTimer interruptId) ps
			= callback False ls ps
		# ps			= closeWindow dialogid ps
		= callback True ls ps
		
	TriggerNoIntr interruptId noi (ls,ps)
		= callback False ls ps

StopIntr :: !(.a,!Id) !*(PSt .b) -> *(PSt .b)
StopIntr (dialogId,interruptId) ps
	= appPIO (closeTimer interruptId) ps
	
ContIntr :: !(.a,!Id) !*(PSt .b) -> *(PSt .b)
ContIntr (dialogId,interruptId) ps
	= appPIO (enableTimer interruptId) ps

