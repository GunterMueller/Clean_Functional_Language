implementation module EdActionType

import StdOverloaded, StdArray, StdInt, StdString, StdChar, StdList
import StrictList
import EdMovement
from EdText import :: TextFragment

:: Action
        = Move          Movement
        | Insert        TextFragment
//		| InsertChar	Char			// DvA: try this for typing speed?
        | Scroll        Movement
        | Select        Movement
        | Remove        Movement

instance toString Action where
  toString (Move   movement) = "Move to "   +++ toString movement
  toString (Scroll movement) = "Scroll to " +++ toString movement 
  toString (Select movement) = "Select to " +++ toString movement
  toString (Remove movement) = "Remove to " +++ toString movement
  toString (Insert fragment) = "Insert " +++ toStr fragment
  toString _                 = "toString (EdAction.icl): unknown action"

instance fromString Action
where
	fromString s
		# (move,s) = hasprefix "Move to " s
		| move = Move (fromString s)
		# (scroll,s) = hasprefix "Scroll to " s
		| scroll  = Scroll (fromString s)
		# (select,s) = hasprefix "Select to " s
		| select = Select (fromString s)
		# (remove,s) = hasprefix "Remove to " s
		| remove = Remove (fromString s)
		# (insert,s) = hasprefix "Insert " s
		| insert = Insert (fromStr s)
		= Scroll StartOfText	// silly default
	where
		hasprefix p s
			# x = size p - 1
			| p == s%(0,x)
				= (True,s%(x+1,size s - 1))
			= (False,s)

//toStr TextFragment
toStr SNil = ""
toStr (SCons t ts)
	= tosafe t +++ toStr ts

//fromStr TextFragment
fromStr "" = SNil
fromStr s
	# (l,r) = fromsafe s
	= SCons l (fromStr r)

tosafe "" = "$@"
tosafe s
	| s.[0] == '$'
		= "$!" +++ tosafe s%(1,size s - 1)
	= s%(0,0) +++ tosafe s%(1,size s - 1)

fromsafe s
	# (dollar,s) = hasprefix "$!" s
	| dollar
		# (l,r) = fromsafe s
		= ("$"+++l,r)
	# (eoflin,s) = hasprefix "$@" s
	| eoflin
		= ("",s)
	# (l,r) = fromsafe (s%(1,size s - 1))
	= (s%(0,0)+++l,r)
where
	hasprefix p s
		# x = size p - 1
		| p == s%(0,x)
			= (True,s%(x+1,size s - 1))
		= (False,s)

instance == Action
where
  (==) (Move   movement)        (Move   movement`)      = movement == movement`
  (==) (Scroll movement)        (Scroll movement`)      = movement == movement`
  (==) (Select movement)        (Select movement`)      = movement == movement`
  (==) (Remove movement)        (Remove movement`)      = movement == movement`
  (==) (Insert text)            (Insert text`)          = text == text`
  (==) _                                        _       = False

allActions :: [Action]
allActions
  =      [ Move   movement \\ movement <- allMovements ]
  ++ [ Select movement \\ movement <- allMovements ]
  ++ [ Scroll movement \\ movement <- [ PageUp, PageDown, StartOfText, EndOfText ] ]
  ++ [ Remove movement \\ movement <- [ CharLeft, CharRight, WordLeft, WordRight, StartOfLine, EndOfLine ] ]

