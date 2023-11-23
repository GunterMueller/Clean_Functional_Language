definition module UtilInterrupt

import StdId, StdPSt
import IdeState

// version A of interrupt routines
// todo: generalise and reintegrate with version B (interrupt)

:: Callback l :== Bool (*PSt l) -> *PSt l

/*	Starts an 'interruptable' function.
	1st arg.	The dialog id of the 'control dialog'. Closing this dialog 'terminates' the
				interruptable function.
	2nd arg.	The interruptable function. 'StartIntr' will start a timer which will cause the 
				interruptable function to be called once. The interruptable function must call
				'ContIntr' if it has not yet been completed its task, or 'StopIntr' when it has
				finished.
	3rd arg.	The program state.
*/
StartIntr :: !(!Id,!Id) !(Callback General) !*(PSt General) -> *(PSt General)

/*	Stops an 'interruptable' function. This function must be called when it wants to terminate.
	1st arg.	The dialog id of the 'control dialog'.
	2nd arg.	The program state.
*/
StopIntr :: !(!Id,!Id) !*(PSt .l) -> *(PSt .l)

/*	Continues an 'interruptable' function. This function is called by an 'interruptable' function to
	allow user interruption at this state of its processing.
	1st arg.	The dialog id of the 'control dialog'.
	2nd arg.	The continuation function.
	3rd arg.	The program state.
*/
ContIntr :: !(!Id,!Id) !(Callback General) !*(PSt General) -> *(PSt General)
