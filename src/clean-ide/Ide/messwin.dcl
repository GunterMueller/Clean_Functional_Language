definition module messwin

// Display PmDriver messages...

import StdPSt
from IdeState import :: General

:: InfoMessage					// message levels
	= Level1 String
	| Level2 String
	| Level3 [String]

showInfo	:: !.InfoMessage !*(PSt General) -> *PSt General
closeInfo	:: !*(PSt General) -> *PSt General
