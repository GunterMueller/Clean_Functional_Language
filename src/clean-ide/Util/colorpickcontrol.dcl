definition module colorpickcontrol

import StdControl, StdControlClass, StdReceiver, StdId

:: In l
	= InGet ((Maybe Colour) l -> l)
	| InSetI Id
	| InSetC Colour
	| InSetC` Colour

::	RGBId l	:==	RId (In l)

openRGBId :: !*env -> (!RGBId .l,!*env) | Ids env

::	RGBColourPickControl ls ps
	= RGBColourPickControl (RGBId ps) Colour (Maybe ItemPos)

instance Controls RGBColourPickControl

::	RGBColourPickControl` ls ps
	= RGBColourPickControl` (RGBId ps) Colour Id (Maybe ItemPos)

instance Controls RGBColourPickControl`

:: ColourBoxControl ls ps
	= ColourBoxControl RGBColour Id (Maybe ItemPos)

instance Controls ColourBoxControl

SetColourBox :: Id RGBColour !*(IOSt .l) -> *IOSt .l

:: ColourBoxControl` ls ps
	= ColourBoxControl` RGBColour Id (MouseStateFilter,MouseFunction *(ls,ps)) (Maybe ItemPos)

instance Controls ColourBoxControl`

SetColourBox` :: Id RGBColour !*(IOSt .l) -> *IOSt .l

setColourBoxColour	:: !(RGBId (PSt .l)) Colour !*(PSt .l) -> *PSt .l
setColourBoxColour`	:: !(RGBId (PSt .l)) Colour !*(PSt .l) -> *PSt .l
getColourBoxColour	:: !(RGBId (PSt .l`)) ((Maybe Colour) *(PSt .l`) -> PSt .l`) !*(PSt .l) -> *PSt .l
setColourBoxId		:: !(RGBId (PSt .l)) Id !*(PSt .l) -> *PSt .l
