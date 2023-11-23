definition module framecontrol

import StdControlDef, StdControlClass

::	FrameControl	c ls pst
=	FrameControl    (c ls pst)                     [ControlAttribute *(ls,pst)]

instance Controls (FrameControl c) | Controls c
