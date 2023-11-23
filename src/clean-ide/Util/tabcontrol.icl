implementation module tabcontrol

import StdEnum, StdFunc, StdList
import StdId, StdPSt, StdControl, windowhandle
import Platform

LighterGrey = RGB {r=225,g=225,b=225}
Vellum = RGB {r=200,g=225,b=255}


//--- Tab Control

:: TabControl c ls pst = TabControl (c ls pst) RowsOrColumns [ControlAttribute *(ls,pst)]

instance Controls (TabControl c) | Panes c
where
	getControlType _ = "TabControl"
	controlToHandles (TabControl tabs rowsorcols atts) ps
		# (rid,ps)		= openId ps
		# (ts,is,cs,ps)	= getLC tabs True rid ps
		# (sz,ps)		= controlSize (rdef rowsorcols rid ts is) False (Just (0,0)) (Just (0,0)) Nothing ps
		# (cs`,ps)		= controlToHandles (imp rowsorcols sz rid ts cs is atts) ps
		= (cs`,ps)

look sz ss us=:{newFrame} pc
	# pc = PlatformDependant pc (setPenBack White pc)
	# pc = PlatformDependant pc (stdUnfillUpdAreaLook ss us pc)

	# pc = setPenColour DarkGrey pc
	# pc = drawLine
			{x=left, y=yoffset}
			{x=right, y=yoffset}
			pc
	# pc = setPenColour LighterGrey pc
	# pc = drawLine
			{x=left, y=yoffset`}
			{x=right, y=yoffset`}
			pc
	# pc = PlatformDependant pc (setPenColour Black pc)
	= pc
where
	left		= newFrame.corner1.x
	right		= newFrame.corner2.x
	yoffset		= sz.h + 5
	yoffset`	= inc yoffset

imp rowsorcols sz rid labels panes ids atts
		= CompoundControl
		(	rdef rowsorcols rid labels ids
		:+:	(Handles panes)
		)
		[ControlLook True (look sz),ControlHMargin 0 0, ControlVMargin 0 0:atts]

rdef rowsorcols rid labels ids
	= RadioControl
		[ (label,Nothing,noLS (switchto x))
		\\	label <- labels
		&	x <- [0..]
		] rowsorcols 1 [ControlId rid]
where
	switchto x ps
		= appPIO (showControl (ids!!x) o hideControls ids) ps

//--

:: Handles ls pst = Handles (pst -> *(*[ControlState ls pst],pst))

instance Controls Handles
where
	getControlType _ = "Handles"
	controlToHandles (Handles h) ps = h ps

:: Xane ls l :== (PSt l) -> *(*[ControlState ls (PSt l)],(PSt l))

class Panes pdef
where
	getLC :: !(pdef .ls (PSt .l)) !Bool !Id !*(PSt .l) -> (![String],![Id],!Xane .ls .l,!*(PSt .l))
	

instance Panes (Pane c) | Controls c
where
	getLC (Pane t c) ini rid ps
		# (i,ps) = openId ps
		# h = controlToHandles (LayoutControl c
					[ ControlId i
					, ControlPos (Below rid,OffsetVector {vx=0,vy=10})
					, ControlHMargin 0 0
					, ControlVMargin 0 0
					: if ini [] [ControlHide]
					])
		= ([t],[i],h,ps)

instance Panes (:+: c1 c2) | Panes c1 & Panes c2
where
	getLC (c1 :+: c2) ini rid ps
		# (t1,i1,h1,ps) = getLC c1 ini rid ps
		# (t2,i2,h2,ps) = getLC c2 False rid ps
		= (t1++t2,i1++i2,hh h1 h2,ps)
	where
		hh h1 h2 ps
			# (hh1,ps) = h1 ps
			# (hh2,ps) = h2 ps
			= (hh1++hh2,ps)
/*
instance Panes (AddLS  c) | Panes c
where
	getLC NilLS ini rid ps = ([],[],[],ps)
instance Panes (NewLS  c) | Panes c
where
	getLC NilLS ini rid ps = ([],[],[],ps)
instance Panes (ListLS c) | Panes c
where
	getLC NilLS ini rid ps = ([],[],[],ps)
instance Panes NilLS
where
	getLC NilLS ini rid ps
		# h = controlToHandles NilLS
		= ([],[],h,ps)
*/

:: Pane c ls pst = Pane String (c ls pst)
