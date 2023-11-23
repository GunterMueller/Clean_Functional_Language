implementation module
	BalancedText

import
	StdEnv,
	StdIO,
	MdM_IOlib
from StdFunc import seq

// ---------------------------------------------------------------------------------------------------------------------------------------------------------------------
:: BalancedTextAttribute =
// ---------------------------------------------------------------------------------------------------------------------------------------------------------------------
	  BalancedTextColour			!Colour
	| BalancedTextBackgroundColour	!Colour
	| BalancedTextFont				!FontDef
	| BalancedTextFontSize			!Int
	| BalancedTextFontStyle			![String]
	| BalancedTextFontFace			!String

// ---------------------------------------------------------------------------------------------------------------------------------------------------------------------
:: BalancedTextState ls ps =
// ---------------------------------------------------------------------------------------------------------------------------------------------------------------------
	{ batText					:: !String
	, batWidth					:: !Int
	, batCustomAttributes		:: ![BalancedTextAttribute]
	, batControlAttributes		:: ![ControlAttribute *(ls, ps)]
	}

// ---------------------------------------------------------------------------------------------------------------------------------------------------------------------
BalancedTextControl :: !String !Int ![BalancedTextAttribute] ![ControlAttribute *(.ls, .ps)] -> BalancedTextState .ls .ps
// ---------------------------------------------------------------------------------------------------------------------------------------------------------------------
BalancedTextControl text width custom_attributes control_attributes
	=	{ batText				= text
		, batWidth				= width
		, batCustomAttributes	= custom_attributes
		, batControlAttributes	= control_attributes
		}

// ---------------------------------------------------------------------------------------------------------------------------------------------------------------------
BalancedTextWindow :: !String !String !Int !Size ![BalancedTextAttribute] ![WindowAttribute *(Int, *PSt .ps)] !*(PSt .ps) -> *PSt .ps
// ---------------------------------------------------------------------------------------------------------------------------------------------------------------------
BalancedTextWindow title text width windowsize custom_attributes window_attributes state
	# (fontdef, colour, bgcolour, state)		= getAttributesInfo custom_attributes state
	# ((_, font), state)						= accPIO (accScreenPicture (openFont fontdef)) state
	# (fontmetrics, state)						= accPIO (accScreenPicture (getFontMetrics font)) state
	# baseline									= fontmetrics.fAscent + fontmetrics.fDescent
	# skip										= baseline + fontmetrics.fLeading
	# (drawfuns, state)							= computeDrawFunctions font baseline skip colour width zero (breakIntoWords text) state
	# (maxx, maxy)								= getMaxXY (map fst drawfuns)
	# the_window								= Window title NilLS
													([ WindowViewSize	windowsize
													 , WindowViewDomain	{corner1=zero, corner2={x=maxx, y=maxy}}
													 , WindowLook		True (SmartLook drawfuns bgcolour)
													 , WindowHScroll	(ScrollFunction 10 85 Horizontal id)
													 , WindowVScroll	(ScrollFunction 10 85 Vertical id)
													 ] ++ window_attributes)
	= snd (openWindow 0 the_window state)

// ---------------------------------------------------------------------------------------------------------------------------------------------------------------------
getAttributesInfo :: ![BalancedTextAttribute] !*(PSt .ps) -> (!FontDef, !Colour, !Colour, !*PSt .ps)
// ---------------------------------------------------------------------------------------------------------------------------------------------------------------------
getAttributesInfo attrs state
	# (font, state)					= accPIO (accScreenPicture openDefaultFont) state
	# (fontdef, colour, bgcolour)	= get_info "" 0 [] Black White (getFontDef font) attrs
	= (fontdef, colour, bgcolour, state)
	where
		get_info _    size styles colour bgcolour fontdef [BalancedTextFontFace face            : attrs] = get_info face size styles colour bgcolour fontdef attrs
		get_info face _    styles colour bgcolour fontdef [BalancedTextFontSize size            : attrs] = get_info face size styles colour bgcolour fontdef attrs
		get_info face size _      colour bgcolour fontdef [BalancedTextFontStyle styles         : attrs] = get_info face size styles colour bgcolour fontdef attrs
		get_info face size styles _      bgcolour fontdef [BalancedTextColour colour            : attrs] = get_info face size styles colour bgcolour fontdef attrs
		get_info face size styles colour _        fontdef [BalancedTextBackgroundColour bgcolour: attrs] = get_info face size styles colour bgcolour fontdef attrs
		get_info face size styles colour bgcolour _       [BalancedTextFont fontdef             : attrs] = get_info face size styles colour bgcolour fontdef attrs
		get_info face size styles colour bgcolour fontdef []
			# new_size			= if (size == 0) fontdef.fSize size
			# new_face			= if (face == "") fontdef.fName face
			# new_styles		= if (isEmpty styles) fontdef.fStyles styles
			= ({fSize = new_size, fName = new_face, fStyles = new_styles}, colour, bgcolour)

// ---------------------------------------------------------------------------------------------------------------------------------------------------------------------
getMaxXY :: ![Rectangle] -> (!Int, !Int)
// ---------------------------------------------------------------------------------------------------------------------------------------------------------------------
getMaxXY rectangles
	| isEmpty rectangles				= (0, 0)
	= (maxList [rec.corner2.x \\ rec <- rectangles], maxList [rec.corner2.y \\ rec <- rectangles])

// ---------------------------------------------------------------------------------------------------------------------------------------------------------------------
computeDrawFunctions :: !Font !Int !Int !Colour !Int !Point2 ![String] !*(PSt .ps) -> (![(Rectangle, *Picture -> *Picture)], !*PSt .ps)
// ---------------------------------------------------------------------------------------------------------------------------------------------------------------------
computeDrawFunctions font baseline skip colour width {x,y} [word: words] state
	# (word_width, state)			= accPIO (accScreenPicture (getFontStringWidth font word)) state
	# (space_width, state)			= accPIO (accScreenPicture (getFontCharWidth font ' ')) state
	# (newpoint, drawword)			= case x + word_width <= width of
										True	->   fitWord font baseline skip colour width {x=x,y=y} word_width space_width word
										False	-> nofitWord font baseline skip colour width {x=x,y=y} word_width space_width word
	# (drawwords, state)			= computeDrawFunctions font baseline skip colour width newpoint words state
	= ([drawword: drawwords], state)
	where
		// ----------------------------------------------------------------------------------------------------------------
		fitWord :: !Font !Int !Int !Colour !Int !Point2 !Int !Int !String -> (!Point2, !(!Rectangle, !*Picture -> *Picture))
		// ----------------------------------------------------------------------------------------------------------------
		fitWord font baseline skip colour width {x,y} word_width space_width word
			# drawword				= seq [setPenFont font, setPenColour colour, drawAt {x=x,y=y+baseline} word]
			# drawrectangle			= {corner1 = {x=x,y=y}, corner2 = {x=x+word_width,y=y+skip}}
			# (newx, newy)			= case x+word_width+space_width <= width of
										True	-> (x+word_width+space_width, y)
										False	-> (0, y+skip)
			= ({x=newx, y=newy}, (drawrectangle, drawword))
		
		// ------------------------------------------------------------------------------------------------------------------
		nofitWord :: !Font !Int !Int !Colour !Int !Point2 !Int !Int !String -> (!Point2, !(!Rectangle, !*Picture -> *Picture))
		// ------------------------------------------------------------------------------------------------------------------
		nofitWord font baseline skip colour width {x,y} word_width space_width word
			# drawword				= seq [setPenFont font, setPenColour colour, drawAt {x=0,y=y+skip+baseline} word]
			# drawrectangle			= {corner1 = {x=0,y=y+skip}, corner2 = {x=word_width,y=y+skip+skip}}
			# (newx, newy)			= (word_width + space_width, y+skip)
			= ({x=newx, y=newy}, (drawrectangle, drawword))
computeDrawFunctions font baseline skip colour width {x,y} [] state
	= ([], state)

/*
// ---------------------------------------------------------------------------------------------------------------------------------------------------------------------
efficientLook :: !Colour [(!Rectangle, *Picture -> *Picture)] !SelectState !UpdateState -> (*Picture -> *Picture)
// ---------------------------------------------------------------------------------------------------------------------------------------------------------------------
efficientLook bgcolour drawfuns _ {oldFrame, newFrame, updArea}
	= get_all_draws bgcolour updArea drawfuns
	where
		// ------------------------------------------------------------------------------------
		get_draws :: !Rectangle [(!Rectangle, *Picture -> *Picture)] -> (*Picture -> *Picture)
		// ------------------------------------------------------------------------------------
		get_draws updArea [(area, drawfun): drawfuns]
			# corner1_x_in_range	= area.corner1.x >= area.corner1.x && area.corner1.x <= area.corner2.x
			# corner2_x_in_range	= area.corner2.x >= area.corner1.x && area.corner2.x <= area.corner2.x
			# corner1_y_in_range	= area.corner1.y >= area.corner1.y && area.corner1.y <= area.corner2.y
			# corner2_y_in_range	= area.corner2.y >= area.corner1.y && area.corner2.y <= area.corner2.y
			# overlap				= (corner1_x_in_range || corner2_x_in_range) && (corner1_y_in_range || corner2_y_in_range)
			| overlap				= seq [drawfun, get_draws updArea drawfuns]
			| otherwise				= get_draws updArea drawfuns
		get_draws updArea []
			= id
		
		// --------------------------------------------------------------------------------------------------
		get_all_draws :: !Colour [!Rectangle] [(!Rectangle, *Picture -> *Picture)] -> (*Picture -> *Picture)
		// --------------------------------------------------------------------------------------------------
		get_all_draws bgcolour [area: areas] drawfuns
			# draw_background				= seq [setPenColour bgcolour, fill area]
			# draw_one						= get_draws area drawfuns
			# draw_others					= get_all_draws bgcolour areas drawfuns
			= seq [draw_background, draw_one, draw_others]
		get_all_draws bgcolour [] drawfuns
			= id
*/

// ---------------------------------------------------------------------------------------------------------------------------------------------------------------------
instance Controls BalancedTextState
// ---------------------------------------------------------------------------------------------------------------------------------------------------------------------
where
	getControlType _							= "BalancedTextControl"
	controlToHandles bstate state
		# (fontdef, colour, bgcolour, state)	= getAttributesInfo bstate.batCustomAttributes state
		# ((_, font), state)					= accPIO (accScreenPicture (openFont fontdef)) state
		# (fontmetrics, state)					= accPIO (accScreenPicture (getFontMetrics font)) state
		# baseline								= fontmetrics.fAscent + fontmetrics.fDescent
		# skip									= baseline + fontmetrics.fLeading
		# (drawfuns, state)						= computeDrawFunctions font baseline skip colour bstate.batWidth zero (breakIntoWords bstate.batText) state
		# (maxx, maxy)							= getMaxXY (map fst drawfuns)
		# the_control							= CompoundControl NilLS 
													([ ControlViewSize	{w=maxx,h=maxy}
													 , ControlLook		True (SmartLook drawfuns bgcolour)
													 ] ++ bstate.batControlAttributes)
		= controlToHandles the_control state
