definition module textcharstream

import StdPrintText, StrictList

:: TextCharStream = 
	{ tcs_txt :: !StrictList String
	, tcs_col :: !Int
	, tcs_sav :: !(!StrictList String,!Int)
	}

instance CharStreams TextCharStream
