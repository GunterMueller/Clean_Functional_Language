definition module EdSelection

// non-visual operations on selections

import	EdPosition
from	EdLineText		import :: Text

:: Selection 
	= { start	:: Position
	  , end		:: Position
	  }

emptySelection		::								Selection
lineSelection		:: !Int						->	Selection
isEmptySelection	:: !Selection				->	Bool
orderSelection		:: !Selection				->	Selection
changeSelection 	:: !Selection !Selection	->	[Selection]
selectLines			:: !Int !Int !Text			->	Selection
validateSelection	:: !Selection Text			->	Selection

// emptySelection:		returns an empty selection.
// isEmptySelection:	returns True if the selection is empty.
// orderSelection:		makes sure that the first position in the
//						selection comes before the second.
// changeSelection: 	computes which selections should be hilited (XOR-ed)
//						if the selection changes from the first to the second
//						argument

