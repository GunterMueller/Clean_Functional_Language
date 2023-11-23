definition module EdActionType

import	StdOverloaded
import	EdMovement
from	EdText			import :: TextFragment

:: Action
	= Move		Movement
	| Insert	TextFragment
	| Scroll	Movement
	| Select	Movement
	| Remove	Movement

instance toString Action
instance fromString Action
instance == Action

allActions		:: [Action]
