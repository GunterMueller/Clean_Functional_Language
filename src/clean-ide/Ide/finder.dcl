definition module finder

from StdClass		import class ==
from StdPSt			import :: PSt
from IDE			import :: General

// implement find commands...

sr_find				:: !*(PSt *General) -> *PSt *General
sr_find_next		:: !*(PSt *General) -> *PSt *General
sr_find_sel			:: !*(PSt *General) -> *PSt *General
sr_rep_find			:: !*(PSt *General) -> *PSt *General
sr_goto_cursor		:: !*(PSt *General) -> *PSt *General
sr_goto_line		:: !*(PSt *General) -> *PSt *General
sr_goto_selection	:: !*(PSt *General) -> *PSt *General

//-- avoid compiler warnings...
:: WorkType
instance == WorkType
