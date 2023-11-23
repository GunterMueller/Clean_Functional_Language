definition module
	MdM_IOlib

import
	StdBool,
	StdInt,
	StdMaybe,
	StdIOBasic,
	StdIOCommon

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
instance == FontDef
instance == RGBColour
instance == (SmartDrawArea a)

:: SmartDrawFunction :== [(Rectangle, *Picture -> *Picture)]

breakIntoWords				:: !String -> [String]
inRectangle					:: !Point2 !Rectangle -> Bool
haveOverlap					:: !Rectangle !Rectangle -> Bool
ImmediateDraw				:: ![SmartDrawArea a] !*Picture -> *Picture
SmartLook					:: !SmartDrawFunction !Colour !SelectState !UpdateState !*Picture -> *Picture
DrawSmartAreas				:: ![SmartDrawArea a] !RGBColour !SelectState !UpdateState !*Picture -> *Picture
ChangeDrawAreas				:: !RGBColour ![SmartDrawArea a] ![SmartDrawArea a ] -> [SmartDrawArea a]
ScrollFunction				:: !Int !Int !Direction !(Int -> Int) !ViewFrame !SliderState !SliderMove -> Int
getDialogBackgroundColour	:: Colour