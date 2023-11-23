implementation module
	MdM_IOlib

import
	StdEnv,
	StdIO
	, RWSDebug

// ---------------------------------------------------------------------------------------------------------------------------------------------------------------------
:: SmartId a =
// ---------------------------------------------------------------------------------------------------------------------------------------------------------------------
	  S_NoId
	| S_TextId					!String
	| S_LinkId					!a

// ---------------------------------------------------------------------------------------------------------------------------------------------------------------------
:: SmartDrawArea a =
// ---------------------------------------------------------------------------------------------------------------------------------------------------------------------
	{ smartRectangle			:: !Rectangle
	, smartJustBG				:: !Bool
	, smartColour				:: !RGBColour
	, smartBGColour				:: !RGBColour
	, smartFont					:: !Font
	, smartFontDef				:: !FontDef
	, smartDrawPoint			:: !Point2						// drawfunction: drawAt smartDrawPoint smartDrawText
	, smartDrawText				:: !String						// used to compare areas
	, smartDrawLines			:: ![Line2]
	, smartKey					:: !Int							// used to converge two lists of areas
	, smartId					:: !SmartId a
	}

// ---------------------------------------------------------------------------------------------------------------------------------------------------------------------
instance == FontDef
// ---------------------------------------------------------------------------------------------------------------------------------------------------------------------
where
	(==) fontdef1 fontdef2
		| fontdef1.fName <> fontdef2.fName					= False
		| fontdef1.fSize <> fontdef2.fSize					= False
		| fontdef1.fStyles <> fontdef2.fStyles				= False
		= True

// ---------------------------------------------------------------------------------------------------------------------------------------------------------------------
instance == RGBColour
// ---------------------------------------------------------------------------------------------------------------------------------------------------------------------
where
	(==) rgb1 rgb2
		| rgb1.r <> rgb2.r									= False
		| rgb1.g <> rgb2.g									= False
		| rgb1.b <> rgb2.b									= False
		= True

// ---------------------------------------------------------------------------------------------------------------------------------------------------------------------
instance == Line2
// ---------------------------------------------------------------------------------------------------------------------------------------------------------------------
where
	(==) line1 line2
		| line1.line_end1 <> line2.line_end1				= False
		| line1.line_end2 <> line2.line_end2				= False
		= True

// ---------------------------------------------------------------------------------------------------------------------------------------------------------------------
instance == (SmartDrawArea a)
// ---------------------------------------------------------------------------------------------------------------------------------------------------------------------
where
	(==) area1 area2
		| area1.smartRectangle <> area2.smartRectangle		= False
		| area1.smartJustBG <> area2.smartJustBG			= False
		| area1.smartColour <> area2.smartColour			= False
		| area1.smartBGColour <> area2.smartBGColour		= False
		| area1.smartFontDef <> area2.smartFontDef			= False
		| area1.smartDrawLines <> area2.smartDrawLines		= False
		| area1.smartDrawText <> area2.smartDrawText		= False
		= True

// Patched for bug in Object I/O which may cause the end-point of a line not to be drawn.
// ---------------------------------------------------------------------------------------------------------------------------------------------------------------------
patchedLinesDraw :: ![Line2] !*Picture -> *Picture
// ---------------------------------------------------------------------------------------------------------------------------------------------------------------------
patchedLinesDraw [line:lines] pic
	#! pic													= draw line pic
	#! pic													= drawPointAt line.line_end2 pic
	= patchedLinesDraw lines pic
patchedLinesDraw [] pic
	= pic

// ---------------------------------------------------------------------------------------------------------------------------------------------------------------------
:: SmartDrawFunction :== [(Rectangle, *Picture -> *Picture)]
// ---------------------------------------------------------------------------------------------------------------------------------------------------------------------

// test for inequality
// ---------------------------------------------------------------------------------------------------------------------------------------------------------------------
neqRGB :: !RGBColour !RGBColour -> Bool
// ---------------------------------------------------------------------------------------------------------------------------------------------------------------------
neqRGB colour1 colour2
	= colour1.r <> colour2.r || colour1.g <> colour2.g || colour1.b <> colour2.b

// test for inequality
// ---------------------------------------------------------------------------------------------------------------------------------------------------------------------
neqFontDef :: !FontDef !FontDef -> Bool
// ---------------------------------------------------------------------------------------------------------------------------------------------------------------------
neqFontDef font1 font2
	= font1.fName <> font2.fName || font1.fSize <> font2.fSize || font1.fStyles <> font2.fStyles







// ---------------------------------------------------------------------------------------------------------------------------------------------------------------------
breakIntoWords :: !String -> [String]
// ---------------------------------------------------------------------------------------------------------------------------------------------------------------------
breakIntoWords text
	= map toString (break_into_words [c \\ c <-: text])
	where
		// --------------------------------------
		break_into_words :: ![Char] -> [[Char]]
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
inRectangle :: !Point2 !Rectangle -> Bool
// ---------------------------------------------------------------------------------------------------------------------------------------------------------------------
inRectangle {x, y} rect
	= x >= rect.corner1.x && x <= rect.corner2.x && y >= rect.corner1.y && y <= rect.corner2.y

// ---------------------------------------------------------------------------------------------------------------------------------------------------------------------
haveOverlap :: !Rectangle !Rectangle -> Bool
// ---------------------------------------------------------------------------------------------------------------------------------------------------------------------
haveOverlap rect1 rect2
	# wrong			= False
	# wrong			= wrong || rect1.corner2.x < rect2.corner1.x
	# wrong			= wrong || rect2.corner2.x < rect1.corner1.x
	# wrong			= wrong || rect1.corner2.y < rect2.corner1.y
	# wrong			= wrong || rect2.corner2.y < rect1.corner1.y
	= not wrong

// ---------------------------------------------------------------------------------------------------------------------------------------------------------------------
haveAnyOverlap :: !Rectangle ![Rectangle] -> Bool
// ---------------------------------------------------------------------------------------------------------------------------------------------------------------------
haveAnyOverlap rect1 [rect2:rects2]
	| haveOverlap rect1 rect2			= True
	= haveAnyOverlap rect1 rects2
haveAnyOverlap rect1 []
	= False

// ---------------------------------------------------------------------------------------------------------------------------------------------------------------------
// DvA -- compensate for bug in Object IO
// ---------------------------------------------------------------------------------------------------------------------------------------------------------------------
cleanUpdate [] = []
cleanUpdate [h:t]
	| h.corner1.x == h.corner2.x = cleanUpdate t
	| h.corner1.y == h.corner2.y = cleanUpdate t
	= [h: cleanUpdate t]

// ---------------------------------------------------------------------------------------------------------------------------------------------------------------------
ImmediateDraw :: ![SmartDrawArea a] !*Picture -> *Picture
// ---------------------------------------------------------------------------------------------------------------------------------------------------------------------
ImmediateDraw [] pict
	= pict
ImmediateDraw [area:areas] pict
	#! pict							= setPenBack (RGB area.smartBGColour) pict
	#! pict							= setPenColour (RGB area.smartColour) pict
	#! pict							= setPenFont area.smartFont pict
	#! pict							= unfill area.smartRectangle pict
	#! pict							= case area.smartJustBG of
										True	-> pict
										False	-> case area.smartDrawText of
													""		-> pict
													word	-> drawAt area.smartDrawPoint word pict
	= draw_rest area.smartBGColour area.smartColour area.smartFontDef areas pict
	where
		draw_rest :: !RGBColour !RGBColour !FontDef ![SmartDrawArea a] !*Picture -> *Picture
		draw_rest bgcolour colour fontdef [area:areas] pict
			#! pict					= case area.smartBGColour == bgcolour of
										True	-> pict
										False	-> setPenBack (RGB area.smartBGColour) pict
			#! pict					= unfill area.smartRectangle pict
			| area.smartJustBG		= draw_rest area.smartBGColour colour fontdef areas pict
			#! pict					= case area.smartColour == colour of
										True	-> pict
										False	-> setPenColour (RGB area.smartColour) pict
			#! pict					= case area.smartFontDef == fontdef of
										True	-> pict
										False	-> setPenFont area.smartFont pict
			#! pict					= case area.smartDrawText of
										""		-> pict
										word	-> drawAt area.smartDrawPoint word pict
			#! pict					= patchedLinesDraw area.smartDrawLines pict
			= draw_rest area.smartBGColour area.smartColour area.smartFontDef areas pict
		draw_rest _ _ _ [] pict
			= pict

// ---------------------------------------------------------------------------------------------------------------------------------------------------------------------
SmartLook :: !SmartDrawFunction !Colour !SelectState !UpdateState !*Picture -> *Picture
// ---------------------------------------------------------------------------------------------------------------------------------------------------------------------
SmartLook smartdrawfunction bgcolour _ {oldFrame, newFrame, updArea} pict
	#! updArea						= cleanUpdate updArea
	#! pict							= draw_backgrounds bgcolour updArea pict
	= draw_areas smartdrawfunction updArea pict
	where
		draw_backgrounds :: !Colour ![Rectangle] !*Picture -> *Picture
		draw_backgrounds colour [area:areas] pict
			#! pict					= setPenBack colour pict
			#! pict					= unfill area pict
			= draw_backgrounds colour areas pict
		draw_backgrounds colour [] pict
			= pict
		
		draw_areas :: ![(Rectangle, *Picture -> *Picture)] ![Rectangle] !*Picture -> *Picture
		draw_areas [(area,draw):areas] updArea pict
			# redraw				= haveAnyOverlap area updArea
			| not redraw			= draw_areas areas updArea pict
			#! pict					= draw pict
			= draw_areas areas updArea pict
		draw_areas [] updArea pict
			= pict

// ---------------------------------------------------------------------------------------------------------------------------------------------------------------------
DrawSmartAreas :: ![SmartDrawArea a] !RGBColour !SelectState !UpdateState !*Picture -> *Picture
// ---------------------------------------------------------------------------------------------------------------------------------------------------------------------
DrawSmartAreas areas bgcolour _ {updArea} pict
	#! updArea						= cleanUpdate updArea
	#! pict							= setPenBack (RGB bgcolour) pict
	#! pict							= draw_backgrounds updArea pict
	= draw_areas areas True {r=0,g=0,b=0} {fName = "", fStyles = [], fSize = 0} pict
	where
		draw_areas :: ![SmartDrawArea a] !Bool !RGBColour !FontDef !*Picture -> *Picture
		draw_areas [area:areas] first colour fontdef pict
			# redraw				= haveAnyOverlap area.smartRectangle updArea
			| not redraw			= draw_areas areas first colour fontdef pict
			# new_bgcolour			= neqRGB area.smartBGColour bgcolour
			#! pict					= case new_bgcolour of
										True	-> unfill area.smartRectangle (setPenBack (RGB area.smartBGColour) pict)
										False	-> pict
			| area.smartJustBG		= draw_areas areas first colour fontdef pict
			# new_colour			= first || neqRGB area.smartColour colour
			#! pict					= case new_colour of
										True	-> setPenColour (RGB area.smartColour) pict
										False	-> pict
			# area_fontdef			= area.smartFontDef
			# new_font				= first || neqFontDef area_fontdef fontdef
			#! pict					= case new_font of
										True	-> setPenFont area.smartFont pict
										False	-> pict
			#! pict					= case area.smartDrawText of
										""		-> pict
										word	-> drawAt area.smartDrawPoint word pict
			#! pict					= patchedLinesDraw area.smartDrawLines pict
			= draw_areas areas False area.smartColour area_fontdef pict
		draw_areas [] _ _ _ pict
			= pict
		
		draw_backgrounds :: ![Rectangle] !*Picture -> *Picture
		draw_backgrounds [rect:rects] pict
			#! pict					= unfill rect pict
			= draw_backgrounds rects pict
		draw_backgrounds [] pict
			= pict

// =====================================================================================================================================================================
// @1: new areas to be drawn
// @2: old areas, which are already drawn
// Removes all @2 from @1. When a member of @2 is not present in @1, a new area drawing its background will be generated.
// ---------------------------------------------------------------------------------------------------------------------------------------------------------------------
ChangeDrawAreas :: !RGBColour ![SmartDrawArea a] ![SmartDrawArea a] -> [SmartDrawArea a]
// ---------------------------------------------------------------------------------------------------------------------------------------------------------------------
ChangeDrawAreas bgcolour new [area:areas]
	# (removed, new)				= remove area new
	| removed						= ChangeDrawAreas bgcolour new areas
	# area							= {area & smartJustBG = True, smartBGColour = bgcolour}
	# new							= ChangeDrawAreas bgcolour new areas
	= [area:new]
	where
		remove :: !(SmartDrawArea a) ![SmartDrawArea a] -> (!Bool, ![SmartDrawArea a])
		remove to_remove [area:areas]
			| area == to_remove		= (True, areas)
			# (removed, areas)		= remove to_remove areas
			= (removed, [area:areas])
		remove _ []
			= (False, [])
ChangeDrawAreas _ new []
	= new

// ---------------------------------------------------------------------------------------------------------------------------------------------------------------------
ScrollFunction :: !Int !Int !Direction !(Int -> Int) !ViewFrame !SliderState !SliderMove -> Int
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

// ------------------------------------------------------------------------------------------------------------------------   
// Hack by Diederik to get the background-colour of a dialog.
// ------------------------------------------------------------------------------------------------------------------------   

COLOR_SCROLLBAR         :== 0
COLOR_BACKGROUND        :== 1
COLOR_ACTIVECAPTION     :== 2
COLOR_INACTIVECAPTION   :== 3
COLOR_MENU              :== 4
COLOR_WINDOW            :== 5
COLOR_WINDOWFRAME       :== 6
COLOR_MENUTEXT          :== 7
COLOR_WINDOWTEXT        :== 8
COLOR_CAPTIONTEXT       :== 9
COLOR_ACTIVEBORDER      :== 10
COLOR_INACTIVEBORDER    :== 11
COLOR_APPWORKSPACE      :== 12
COLOR_HIGHLIGHT         :== 13
COLOR_HIGHLIGHTTEXT     :== 14
COLOR_BTNFACE           :== 15
COLOR_BTNSHADOW         :== 16
COLOR_GRAYTEXT          :== 17
COLOR_BTNTEXT           :== 18
COLOR_INACTIVECAPTIONTEXT :== 19
COLOR_BTNHIGHLIGHT      :== 20

COLOR_3DDKSHADOW        :== 21
COLOR_3DLIGHT           :== 22
COLOR_INFOTEXT          :== 23
COLOR_INFOBK            :== 24

COLOR_HOTLIGHT                  :== 26
COLOR_GRADIENTACTIVECAPTION     :== 27
COLOR_GRADIENTINACTIVECAPTION   :== 28

COLOR_DESKTOP           :== COLOR_BACKGROUND
COLOR_3DFACE            :== COLOR_BTNFACE
COLOR_3DSHADOW          :== COLOR_BTNSHADOW
COLOR_3DHIGHLIGHT       :== COLOR_BTNHIGHLIGHT
COLOR_3DHILIGHT         :== COLOR_BTNHIGHLIGHT
COLOR_BTNHILIGHT        :== COLOR_BTNHIGHLIGHT

GetSysColor :: !Int -> Int
GetSysColor nIndex = code {
	ccall GetSysColor@4 "PI:I"
	}

getDialogBackgroundColour :: Colour
getDialogBackgroundColour
	= RGB {r = rcol, g = gcol, b = bcol}
where
	col		= GetSysColor COLOR_BTNFACE
	rcol	= (col bitand 0x000000FF)
	gcol	= (col bitand 0x0000FF00) >> 8
	bcol	= (col bitand 0x00FF0000) >> 16

// ------------------------------------------------------------------------------------------------------------------------   
// End Hack
// ------------------------------------------------------------------------------------------------------------------------   
