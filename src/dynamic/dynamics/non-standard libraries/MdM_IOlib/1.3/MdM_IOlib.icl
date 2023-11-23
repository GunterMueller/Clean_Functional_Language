implementation module
	MdM_IOlib

import
	StdEnv,
	StdIO
//	, RWSDebug

// ---------------------------------------------------------------------------------------------------------------------------------------------------------------------
:: SmartDrawFunction :== [(!Rectangle, *Picture -> *Picture)]
// ---------------------------------------------------------------------------------------------------------------------------------------------------------------------

// ---------------------------------------------------------------------------------------------------------------------------------------------------------------------
breakIntoWords :: !String -> [!String]
// ---------------------------------------------------------------------------------------------------------------------------------------------------------------------
breakIntoWords text
	= map toString (break_into_words [c \\ c <-: text])
	where
		// --------------------------------------
		break_into_words :: [!Char] -> [[!Char]]
		// --------------------------------------
		break_into_words [c:cs]
			# words					= break_into_words cs
			| c == ' '				= [[]: words]
			| isEmpty words			= [[c]]
			# first_word			= [c: hd words]
			# rest_words			= tl words
			= [first_word: rest_words]
		break_into_words []
			= []


// ---------------------------------------------------------------------------------------------------------------------------------------------------------------------
inRectangle :: !Point2 !Rectangle -> !Bool
// ---------------------------------------------------------------------------------------------------------------------------------------------------------------------
inRectangle {x, y} rect
	= x >= rect.corner1.x && x <= rect.corner2.x && y >= rect.corner1.y && y <= rect.corner2.y

// ---------------------------------------------------------------------------------------------------------------------------------------------------------------------
haveOverlap :: !Rectangle !Rectangle -> !Bool
// ---------------------------------------------------------------------------------------------------------------------------------------------------------------------
haveOverlap rect1 rect2
	# wrong			= False
	# wrong			= wrong || rect1.corner2.x < rect2.corner1.x
	# wrong			= wrong || rect2.corner2.x < rect1.corner1.x
	# wrong			= wrong || rect1.corner2.y < rect2.corner1.y
	# wrong			= wrong || rect2.corner2.y < rect1.corner1.y
	= not wrong

// ---------------------------------------------------------------------------------------------------------------------------------------------------------------------
SmartLook :: !SmartDrawFunction (!Maybe Colour) !SelectState !UpdateState -> (*Picture -> *Picture)
// ---------------------------------------------------------------------------------------------------------------------------------------------------------------------
SmartLook smartdrawfunction bgcolour _ {oldFrame, newFrame, updArea}
	= get_draw_function bgcolour smartdrawfunction updArea
	where
		get_draw_function :: (!Maybe Colour) !SmartDrawFunction [!Rectangle] -> (*Picture -> *Picture)
		get_draw_function bgcolour smartdrawfunction [area: areas]
			# draw_background		= if (isNothing bgcolour) id (seq [setPenColour (fromJust bgcolour), fill area])
			# draw_contents			= draw_area area smartdrawfunction
			# draw_rest				= get_draw_function bgcolour smartdrawfunction areas
			= seq [draw_background, draw_contents, draw_rest]
		get_draw_function bgcolour smartdrawfunction []
			= id
		
		draw_area :: !Rectangle [(!Rectangle, *Picture -> *Picture)] -> (*Picture -> *Picture)
		draw_area rect [(area, drawfun): drawfuns]
			# draw_rest				= draw_area rect drawfuns
			| haveOverlap rect area	= seq [drawfun, draw_rest]
			= draw_rest
		draw_area rect []
			= id

// ---------------------------------------------------------------------------------------------------------------------------------------------------------------------
ScrollFunction :: !Int !Int !Direction (Int -> Int) ViewFrame SliderState SliderMove -> Int
// ---------------------------------------------------------------------------------------------------------------------------------------------------------------------
ScrollFunction abs_inc rel_inc direction round viewframe sliderstate (SliderThumb newpos)
	= round newpos
ScrollFunction abs_inc rel_inc direction round viewframe sliderstate SliderIncSmall    
	= round (sliderstate.sliderThumb + abs_inc)
ScrollFunction abs_inc rel_inc direction round viewframe sliderstate SliderDecSmall
	= round (sliderstate.sliderThumb - abs_inc)
ScrollFunction abs_inc rel_inc direction round viewframe sliderstate SliderIncLarge
	| direction == Horizontal	= round (sliderstate.sliderThumb + (abs (viewframe.corner1.x - viewframe.corner2.x) * rel_inc) / 100)
	| direction == Vertical		= round (sliderstate.sliderThumb + (abs (viewframe.corner1.y - viewframe.corner2.y) * rel_inc) / 100)
ScrollFunction abs_inc rel_inc direction round viewframe sliderstate SliderDecLarge
	| direction == Horizontal	= round (sliderstate.sliderThumb - (abs (viewframe.corner1.x - viewframe.corner2.x) * rel_inc) / 100)
	| direction == Vertical		= round (sliderstate.sliderThumb - (abs (viewframe.corner1.y - viewframe.corner2.y) * rel_inc) / 100)