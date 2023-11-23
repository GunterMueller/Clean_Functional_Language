definition module EdLineText

// a type for dealing with line-oriented operations on texts

from StrictList	import :: StrictList
from EdPosition	import :: LineNr
from syncol		import :: Info

:: Text
:: TextFragment
	:== StrictList String

newText				:: Text
emptyText			:: Text

textToStrings		:: !Text							-> StrictList String
stringsToText		:: (StrictList String)				-> Text
stringsToString		:: !(StrictList String)				-> String
stringToStrings		:: !String							-> (StrictList String)

StringToText s
	:== stringsToText (stringToStrings s)
 
textLength			:: !Text							-> Int
lastLineNr			:: !Text							-> LineNr
validateLineNr		:: !LineNr Text						-> LineNr

getLine				:: !LineNr !u:Text					-> (!String, !u:Text)
getLineC			:: !LineNr !u:Text					-> ((!Info,!String), !u:Text)
getLines			:: !LineNr !LineNr !Text			-> (!StrictList String, !Text)
//getLinesC			:: LineNr LineNr Text				-> (StrictList (Int,String), Text)

updateLine			:: !LineNr !String !.Text			-> (!Int,!Int,!.Text)
removeLine			:: !LineNr !Text					-> Text

removeLines			:: !LineNr !LineNr !Text				-> Text
insertLines			:: !LineNr !(StrictList String) !Text	-> Text
appendLines			:: !(StrictList String) !Text			-> Text
appendLines`		:: !(StrictList String) !Text			-> Text

// newText:			creates a new text. A new text consists of one
//					empty line.

// textToStrings:	converts a text to a list of strings. 
// stringsToText:	converts a list of strings to a text. 

// textLength:		returns the number of lines in the text.
// lastLineNr:		returns the number of the last line in the text.
// validateLineNr:	makes sure that the line number is legal within the text.

// getLine:			returns the line indicated by the line number.
// getLinesFrom:	returns the lines including and below the line 
//					indicated by the line number.
// updateLine:		changes the line by the given string.
// removeLine:		removes the line with the given number.
// removeLines:		removes all lines with line numbers
//					between and including the given line numbers.
// insertLines:		inserts some lines before the line with the given number.

