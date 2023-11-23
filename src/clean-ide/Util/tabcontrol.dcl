definition module tabcontrol

import StdControlClass

:: TabControl c ls pst = TabControl (c ls pst) RowsOrColumns [ControlAttribute *(ls,pst)]

instance Controls (TabControl c) | Panes c

//--

class Panes pdef
where
	getLC :: !(pdef .ls (PSt .l)) !Bool !Id !*(PSt .l) -> (![String],![Id],!Xane .ls .l,!*(PSt .l))

:: Xane ls l :== (PSt l) -> *(*[ControlState ls (PSt l)],(PSt l))

instance Panes (Pane c)				| Controls c
instance Panes (:+: c1 c2)			| Panes c1 & Panes c2
/*
instance Panes (AddLS  c)			| Panes c
instance Panes (NewLS  c)			| Panes c
instance Panes (ListLS c)			| Panes c
instance Panes NilLS
*/

:: Pane c ls pst = Pane String (c ls pst)
