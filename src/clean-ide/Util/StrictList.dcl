definition module StrictList

from StdClass import class ==

// Strict lists consume less space than normal lists

:: StrictList a
	= SCons !a (StrictList a)
	| SNil

instance == (StrictList a) | == a

slAppend	:: !(StrictList .a) !u:(StrictList .a) -> u:StrictList .a
slReverse	:: !(StrictList a) -> StrictList a
slSplitAt	:: !Int u:(StrictList .a) -> (StrictList .a, u:StrictList .a)
slFromList	:: ![a] -> StrictList a
slMap		:: !(a -> b) !(StrictList a) -> StrictList b
slLength	:: !(StrictList a) -> Int
slHead		:: !(StrictList a) -> a
slTail		:: !(StrictList a) -> (StrictList a)
slToList	:: !(StrictList a) -> [a]
slIndex		:: !Int !(StrictList .a) -> .a
slIsEmpty	:: !(StrictList a) -> Bool
slTake		:: !Int !(StrictList a) -> StrictList a
slDrop		:: !Int !(StrictList a) -> StrictList a
slLast		:: !(StrictList a) -> a
slInit		:: !(StrictList a) -> StrictList a
slUpdate	:: !Int !.a !u:(StrictList .a) -> u:StrictList .a

// slAppend:	Appends two strict lists
// slReverse:	Reverses a strict list
// slSplitAt:	Splits a strict list at the indicated position
// slFromList:	Converts a normal list to a strict list
// slMap:		Maps a function over a strict list
// slLength:	Computes the length of a strict list
// slHead:		Returns the head of the list
// slTail:		Returns the tail of the list
// slToList:	Converts a strict list to a normal list
// slIndex:		Returns the element at the given position
// slIsEmpty:	Returns whether the list is empty or not
// slTake:		Returns a number of elements from the beginning
// slDrop:		Removes a number of elements from the beginning
// slLast:		Return the last element
// slInit:		Returns all but the last element

