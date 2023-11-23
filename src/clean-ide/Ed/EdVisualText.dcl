definition module EdVisualText

// visual operations on texts

from StdIOCommon	import	:: ViewFrame, :: Rectangle, :: Point2, :: ViewDomain
from EdText			import	:: TextFragment, :: StrictList, stringsToString,
							getTextFragment, stringToStrings, getLine, textLength,
							newText, emptyText, stringsToText, updateLine, lastLineNr
from StdPicture		import	:: Picture, :: FontName
import EdMonad


vUpdateText		:: !FontInfo !Text !ViewFrame ![Rectangle] -> (*Picture -> *Picture)
// vUpdateText:		updates the text in the rectangles within 
//					the given view frame

vInsertText		:: Position TextFragment		->	EditMonad (PSt .l) nothing
// vInsertText:		inserts a piece of text into the visual text
//					(assumes that the position where the insert takes place is visible)

vAppendLines	:: TextFragment					->	EditMonad (PSt .l) nothing
vAppendText		:: TextFragment					->	EditMonad (PSt .l) nothing

vRemoveText		:: !Selection					->	EditMonad (PSt .l) nothing
// vRemoveText:		removes a piece of text from the visual text.
//					(assumes that the first position in the selection is visible)

computeViewDomain	::								EditMonad .env ViewDomain 
getViewFrame		::								EditMonad (PSt .l) ViewFrame
vResetViewDomain	::								EditMonad (PSt .l) nothing
vTextUpdate			:: !Position Int			->	EditMonad (PSt .l) nothing
vDraw				:: (*Picture -> *Picture)	->	EditMonad (PSt .l) a

pointToPosition :: !Point2 !Text !FontInfo		->	Position
positionToPoint :: !Position !Text !FontInfo	->	Point2

tabStringWidth	:: !Int ![String] !FontInfo		->	Int
// tabStringWidth: computes the width of a string that is already split 
//				   at tabs. The first argument specifies the x-coordinate 
//				   where string is placed.
