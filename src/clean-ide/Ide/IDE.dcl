definition module IDE

import	StdPSt
from	PmTypes		import :: Modulename
from	EdClient	import :: Selection, :: Position, :: ColumnNr, :: LineNr
from	IdeState	import :: General

OpenModule :: !.Modulename !.Selection !*(PSt General) -> *PSt General
