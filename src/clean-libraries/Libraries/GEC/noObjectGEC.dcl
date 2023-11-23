definition module noObjectGEC

import StdAGEC

derive gGEC NoObject, YesObject

::	NoObject  a = NoObject  a
::	YesObject a = YesObject a

noObjectAGEC  :: a -> AGEC a	| gGEC{|*|} a	// identity, no OBJ pulldown menu constructed.
yesObjectAGEC :: a -> AGEC a	| gGEC{|*|} a	// identity, OBJ pulldown menu constructed.
