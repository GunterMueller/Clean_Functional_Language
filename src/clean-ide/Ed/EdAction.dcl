definition module EdAction

// performing editor Actions

import	EdMonad, EdMovement
import	EdCommon
from	EdSelection		import :: Position
from	EdText			import :: TextFragment
from	EdActionType	import :: Action

performAction	:: Action -> EditMonad (PSt PLocState) nothing

undoAction :: EditMonad (PSt .l) nothing
