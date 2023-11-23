definition module
	MdM_IOlib

import
	StdBool,
	StdInt,
	StdMaybe,
	StdIOBasic,
	StdIOCommon

:: SmartDrawFunction :== [(!Rectangle, *Picture -> *Picture)]

breakIntoWords			:: !String -> [!String]
inRectangle				:: !Point2 !Rectangle -> !Bool
haveOverlap				:: !Rectangle !Rectangle -> !Bool
SmartLook				:: !SmartDrawFunction (!Maybe Colour) !SelectState !UpdateState -> (*Picture -> *Picture) 
ScrollFunction			:: !Int !Int !Direction (Int -> Int) ViewFrame SliderState SliderMove -> Int
