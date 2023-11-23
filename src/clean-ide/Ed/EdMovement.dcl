definition module EdMovement

from	StdClass		import class ==, class toString, class fromString
from	EdSelection		import :: Position, :: ColumnNr, :: LineNr
import	EdMonad

:: Movement
	= LineUp
	| LineDown
	| CharLeft
	| CharRight
	| WordLeft
	| WordRight
	| PageUp
	| PageDown
	| StartOfLine
	| EndOfLine
	| StartOfText
	| EndOfText

instance == Movement
instance toString Movement
instance fromString Movement

positionAfterMove	:: !Movement !Position	->	EditMonad (PSt .l) Position
isVerticalMove		:: !Movement			->	Bool
selectWordAt		:: !Position			->	EditMonad .env Selection 
allMovements		::							[Movement]
