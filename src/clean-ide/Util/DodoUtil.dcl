definition module DodoUtil

//1.3
import StdString
//3.1

sSplit :: !.Char !String -> (!String,!String)
eSplit :: !.Char !String -> (!String,!String)
lSplit :: !.Char !String -> [String]
words :: !String -> [String]
unwords :: ![String] -> String
scopy ::
	!Int		// end of copy source index
	!Int		// current target index
	!Int		// current source index
	!*{#Char}	// target string
	!{#Char}	// source string
	-> (!Int,!.{#Char})
