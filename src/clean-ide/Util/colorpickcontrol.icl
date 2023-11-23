implementation module colorpickcontrol

import StdControl, StdControlReceiver, StdReceiver
import ioutil

::	NoState
	= NoState

/*	The definition of the text-slider component:	*/

::	RGBPickControl ls ps
	:==	:+: SliderControl TextControl ls ps

RGBPickControl
	:: RGBColour (String,Id,Id) (RGBColour->Int) (Int->RGBColour->RGBColour) (Maybe ItemPos)
	-> RGBPickControl (RGBColour,Id) (PSt .l)
RGBPickControl rgb (text,sid,tid) get set maybePos
	=	SliderControl Horizontal (PixelWidth length) sliderstate slideraction
		[ ControlId sid
		: controlPos
		]
	:+: TextControl   (ColourText text  (get rgb))
		[ ControlWidth (ContentWidth "Green 1000")
		, ControlId tid
		]
where
	controlPos	= case maybePos of
					Just pos	-> [ControlPos pos]
					_			-> []
	length		= MaxRGB-MinRGB+1
	sliderstate	= {sliderMin=MinRGB, sliderMax=MaxRGB, sliderThumb=get rgb}//, sliderSize = 0}
	
	slideraction :: SliderMove ((RGBColour,Id),PSt .l) -> ((RGBColour,Id),PSt .l)
	slideraction move ((rgb,did),pst)
		= ((	newrgb
		  , did
		  ),	appListPIO [ setSliderThumbs [(sid,y)]
		  			   , setControlTexts [(tid,ColourText text y)]
		  			   , SetColourBox did newrgb
		  			   ] pst
		  )
	where
		y		= case move of
					SliderIncSmall	-> min (get rgb+1 ) MaxRGB

					SliderDecSmall	-> max (get rgb-1 ) MinRGB
					SliderIncLarge	-> min (get rgb+10) MaxRGB
					SliderDecLarge	-> max (get rgb-10) MinRGB
					SliderThumb x	-> x
		newrgb	= set y rgb
	
RGBPickControl`
	:: RGBColour (String,Id,Id) (RGBColour->Int) (Int->RGBColour->RGBColour) (Maybe ItemPos)
	-> RGBPickControl (RGBColour,Id) (PSt .l)
RGBPickControl` rgb (text,sid,tid) get set maybePos
	=	SliderControl Horizontal (PixelWidth length) sliderstate slideraction
		[ ControlId sid
		: controlPos
		]
	:+: TextControl   (ColourText text  (get rgb))
		[ ControlWidth (ContentWidth "Green 1000")
		, ControlId tid
		]
where
	controlPos	= case maybePos of
					Just pos	-> [ControlPos pos]
					_			-> []
	length		= MaxRGB-MinRGB+1
	sliderstate	= {sliderMin=MinRGB, sliderMax=MaxRGB, sliderThumb=get rgb}//, sliderSize = 0}
	
	slideraction :: SliderMove ((RGBColour,Id),PSt .l) -> ((RGBColour,Id),PSt .l)
	slideraction move ((rgb,did),pst)
		= ((	newrgb
		  , did
		  ),	appListPIO [ setSliderThumbs [(sid,y)]
		  			   , setControlTexts [(tid,ColourText text y)]
		  			   , SetColourBox` did newrgb
		  			   ] pst
		  )
	where
		y		= case move of
					SliderIncSmall	-> min (get rgb+1 ) MaxRGB

					SliderDecSmall	-> max (get rgb-1 ) MinRGB
					SliderIncLarge	-> min (get rgb+10) MaxRGB
					SliderDecLarge	-> max (get rgb-10) MinRGB
					SliderThumb x	-> x
		newrgb	= set y rgb
	
ColourText :: String Int -> String
ColourText text x
	= text+++" "+++toString x



/*	The definition of a colour box:		*/
:: ColourBoxControl ls ps = ColourBoxControl RGBColour Id (Maybe ItemPos)

instance Controls ColourBoxControl
where
	getControlType _ = "ColourBoxControl"
	controlToHandles (ColourBoxControl rgb cId maybePos) ps
		= controlToHandles imp ps
	where
		imp = CustomControl {w=40,h=40} (ColourBoxLook False rgb)
			[	ControlId cId
			:	case maybePos of (Just pos) -> [ControlPos pos];_->[]
			]

ColourBoxLook :: Bool RGBColour SelectState UpdateState *Picture -> *Picture
ColourBoxLook focus colour _ {newFrame} picture
	# picture	= setPenColour	(RGB colour) picture
	# picture	= fill			newFrame	 picture
	// now build frame...
	| focus
		# picture	= setPenSize	3			picture
		# picture	= setPenColour	Black		picture
		# picture	= draw			newFrame	picture
		# picture	= setPenSize	2			picture
		# picture	= setPenColour	LightGrey	picture
		# picture	= draw			newFrame	picture
		# picture	= setPenSize	1			picture
		# picture	= setPenColour	Black		picture
		# picture	= draw			newFrame	picture
		= picture
	# picture	= setPenSize	1			 picture
	# picture	= setPenColour	Black		 picture
	# picture	= draw			newFrame	 picture
	= picture

SetColourBox :: Id RGBColour !*(IOSt .l) -> *IOSt .l
SetColourBox id rgb iost
	= setControlLooks [(id,True,(True,ColourBoxLook False rgb))] iost

//--
:: ColourBoxControl` ls ps = ColourBoxControl` RGBColour Id (MouseStateFilter,MouseFunction *(ls,ps)) (Maybe ItemPos)

instance Controls ColourBoxControl`
where
	getControlType _ = "ColourBoxControl`"
	controlToHandles (ColourBoxControl` rgb cId (mfilter,mfunction) maybePos) ps
		= controlToHandles imp ps
	where
		imp = CustomControl {w=40,h=40} (ColourBoxLook False rgb)
			[	ControlId cId
			, ControlMouse mfilter Able mfunction
			:	case maybePos of (Just pos) -> [ControlPos pos];_->[]
			]

SetColourBox` :: Id RGBColour !*(IOSt .l) -> *IOSt .l
SetColourBox` id rgb iost
	= setControlLooks [(id,True,(True,ColourBoxLook True rgb))] iost

/*	The definition of the RGB access control:	*/

:: In l
	= InGet ((Maybe Colour) l -> l)
	| InSetI Id
	| InSetC Colour
	| InSetC` Colour


::	RGBId l	:==	RId (In l)

openRGBId :: !*env -> (!RGBId .l,!*env) | Ids env
openRGBId env = openRId env

::	ColourPickAccess ls ps	:==	Receiver (In ls) RGBColour ps

//ColourPickAccess :: (RGBId (PSt .l)) [(String,Id,Id)] Id -> ColourPickAccess .l (PSt .l)
ColourPickAccess rid rgbpicks
	= Receiver rid accessRGB []
where
	//accessRGB :: (In .l) (RGBColour,PSt .l) -> PSt .l
	accessRGB (InGet cont) ((rgb,did),ps)
		# col	= RGB rgb
		# ps	= cont (Just col) ps
		= ((rgb,did),ps)
	accessRGB (InSetC col) ((_,did),ps=:{io})
		# rgb		= toRGBColour col
		# {r,g,b}	= rgb
		# settings	= zip2 [r,g,b] rgbpicks
		# io		= SetColourBox    did rgb io
		# io		= setSliderThumbs (map (\(y,(_,sid,_))->(sid,y)) settings) io
		# io		= setControlTexts (map (\(y,(text,_,tid))->(tid,ColourText text y)) settings) io
		= ((rgb,did),{ps & io=io})
	accessRGB (InSetC` col) ((_,did),ps=:{io})
		# rgb		= toRGBColour col
		# {r,g,b}	= rgb
		# settings	= zip2 [r,g,b] rgbpicks
		# io		= SetColourBox`    did rgb io
		# io		= setSliderThumbs (map (\(y,(_,sid,_))->(sid,y)) settings) io
		# io		= setControlTexts (map (\(y,(text,_,tid))->(tid,ColourText text y)) settings) io
		= ((rgb,did),{ps & io=io})
	accessRGB (InSetI did) ((rgb,_),ps=:{io})
		# {r,g,b}	= rgb
		# settings	= zip2 [r,g,b] rgbpicks
		# io		= SetColourBox    did rgb io
		# io		= setSliderThumbs (map (\(y,(_,sid,_))->(sid,y)) settings) io
		# io		= setControlTexts (map (\(y,(text,_,tid))->(tid,ColourText text y)) settings) io
		= ((rgb,did),{ps & io=io})


/*	The definition of the assembled colour picking control:	*/

::	RGBColourPickControl ls ps
	= RGBColourPickControl (RGBId ps) Colour (Maybe ItemPos)

::	RGBColourPickControl` ls ps
	= RGBColourPickControl` (RGBId ps) Colour Id (Maybe ItemPos)

instance Controls RGBColourPickControl
where
	getControlType _ = "ColourPickControl"
	controlToHandles (RGBColourPickControl rgbid initcol maybePos) ps
		# initrgb					= toRGBColour initcol
		# (rid,ps)					= openId ps
		# (rtid,ps)					= openId ps
		# (gid,ps)					= openId ps
		# (gtid,ps)					= openId ps
		# (bid,ps)					= openId ps
		# (btid,ps)					= openId ps
		# (did,ps)					= openId ps
		# (rpicks,gpicks,bpicks)	= ((rtext,rid,rtid),(gtext,gid,gtid),(btext,bid,btid))
		= controlToHandles
			{ newLS 	= (initrgb,did)
		  	, newDef	= LayoutControl
						(	LayoutControl
						(	ListLS
						[	RGBPickControl initrgb rpicks (\rgb->rgb.r) (\x rgb->{rgb&r=x}) left
						,	RGBPickControl initrgb gpicks (\rgb->rgb.g) (\x rgb->{rgb&g=x}) left
						,	RGBPickControl initrgb bpicks (\rgb->rgb.b) (\x rgb->{rgb&b=x}) left
						])	[ControlHMargin 0 0,ControlVMargin 0 0]
						:+: ColourBoxControl initrgb did Nothing
						:+:	ColourPickAccess rgbid [rpicks,gpicks,bpicks]
						)	(case maybePos of (Just pos) -> [ControlPos pos]; _->[])
		  } ps
	where	
		(rtext,gtext,btext)					= ("Red","Green","Blue")
		left								= Just (Left,NoOffset)

instance Controls RGBColourPickControl`
where
	getControlType _ = "ColourPickControl"
	controlToHandles (RGBColourPickControl` rgbid initcol did maybePos) ps
		# initrgb					= toRGBColour initcol
		# (rid,ps)					= openId ps
		# (rtid,ps)					= openId ps
		# (gid,ps)					= openId ps
		# (gtid,ps)					= openId ps
		# (bid,ps)					= openId ps
		# (btid,ps)					= openId ps
		# (rpicks,gpicks,bpicks)	= ((rtext,rid,rtid),(gtext,gid,gtid),(btext,bid,btid))
		= controlToHandles
			{ newLS 	= (initrgb,did)
		  	, newDef	= LayoutControl
						(	LayoutControl
						(	ListLS
						[	RGBPickControl` initrgb rpicks (\rgb->rgb.r) (\x rgb->{rgb&r=x}) left
						,	RGBPickControl` initrgb gpicks (\rgb->rgb.g) (\x rgb->{rgb&g=x}) left
						,	RGBPickControl` initrgb bpicks (\rgb->rgb.b) (\x rgb->{rgb&b=x}) left
						])	[ControlHMargin 0 0,ControlVMargin 0 0]
						:+:	ColourPickAccess rgbid [rpicks,gpicks,bpicks]
						)	(case maybePos of (Just pos) -> [ControlPos pos]; _->[])
		  } ps
	where	
		(rtext,gtext,btext)					= ("Red","Green","Blue")
		left								= Just (Left,NoOffset)

//--

setColourBoxColour :: !(RGBId (PSt .l)) Colour !*(PSt .l) -> *PSt .l
setColourBoxColour rgbId colour ps
	# (_,ps) = asyncSend rgbId (InSetC colour) ps
	= ps

setColourBoxColour` :: !(RGBId (PSt .l)) Colour !*(PSt .l) -> *PSt .l
setColourBoxColour` rgbId colour ps
	# (_,ps) = asyncSend rgbId (InSetC` colour) ps
	= ps

getColourBoxColour :: !(RGBId (PSt .l`)) ((Maybe Colour) *(PSt .l`) -> PSt .l`) !*(PSt .l) -> *PSt .l
getColourBoxColour rgbId cont ps
	# (_,ps) = asyncSend rgbId (InGet cont) ps
	= ps

setColourBoxId :: !(RGBId (PSt .l)) Id !*(PSt .l) -> *PSt .l
setColourBoxId rgbId cbId ps
	# (_,ps) = asyncSend rgbId (InSetI cbId) ps
	= ps
