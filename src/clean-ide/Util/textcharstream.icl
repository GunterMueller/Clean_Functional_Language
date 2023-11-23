implementation module textcharstream

import StdArray, StdClass, StdInt
import StdPrintText
import StrictList

:: TextCharStream = 
	{ tcs_txt :: !StrictList String
	, tcs_col :: !Int
	, tcs_sav :: !(!StrictList String,!Int)
	}

instance CharStreams TextCharStream
where
	getChar		:: !*TextCharStream -> (!Bool,!Char,!*TextCharStream)
	getChar tcs=:{tcs_txt=SNil}	= (False,'\f',tcs)
	getChar tcs=:{tcs_txt=SCons "" rot}	= getChar {tcs & tcs_txt = rot}
	getChar tcs=:{tcs_txt=SCons str rot, tcs_col}
		| size str == tcs_col = getChar {tcs & tcs_txt = rot, tcs_col = 0}
		= (True,str.[tcs_col],{tcs & tcs_col = inc tcs_col})

	savePos		:: !*TextCharStream -> *TextCharStream
	savePos tcs=:{tcs_txt,tcs_col} = {tcs & tcs_sav = (tcs_txt,tcs_col)}
	
	restorePos	:: !*TextCharStream -> *TextCharStream
	restorePos tcs=:{tcs_sav=(sav_txt,sav_col)} = {tcs & tcs_txt = sav_txt, tcs_col = sav_col}
	
	eos			:: !*TextCharStream -> (!Bool,!*TextCharStream)
	eos tcs=:{tcs_txt = SNil} = (True,tcs)
	eos tcs=:{tcs_txt = SCons "" rot} = eos {tcs & tcs_txt = rot}
	eos tcs=:{tcs_txt = SCons str rot, tcs_col}
		| size str == tcs_col = eos {tcs & tcs_txt = rot, tcs_col = 0}
		= (False,tcs)
