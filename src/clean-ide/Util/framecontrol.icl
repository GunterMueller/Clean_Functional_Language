implementation module framecontrol

import StdEnv, StdIO

/*
Simple control to place a frame around other controls
*/

::	FrameControl	c ls pst
=	FrameControl    (c ls pst)                     [ControlAttribute *(ls,pst)]

instance Controls (FrameControl c) | Controls c
where
	getControlType _ = "FrameControl"
	controlToHandles (FrameControl cdef atts) pst
		# imp	= CompoundControl (cdef )
					[ ControlLook True stdUnfillUpdAreaLook
					, ControlHMargin 1 1	// aanpassen aan pen size...
					, ControlVMargin 1 1
					: atts
					]
		= controlToHandles imp pst
	where
		stdUnfillNewFrameLook :: SelectState !UpdateState !*Picture -> *Picture
		stdUnfillNewFrameLook _ {newFrame} picture
			# picture = unfill newFrame picture
			= draw newFrame picture

//--

//TestFrameControl ps
/*
Start world
	= startIO MDI ploc ppub pini patt world
where
	ploc = 0
	ppub = 0
	pini ps
		# (err,ps) = openDialog dloc ddef ps
		= ps
	patt = [ProcessClose closeProcess]
	
	dloc = 0
	ddef = Dialog "FrameControl Test"
			( FrameControl
				( CustomControl csize clook [ControlPen [PenBack Red]]
				)
				[
				]
			)
			[
			]
	csize = {w=250,h=250}
	clook _ {newFrame} = unfill newFrame
*/
