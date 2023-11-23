definition module ioutil

import StdOverloaded, StdBool, StdList
import StdPicture, StdPSt, StdId, StdIOCommon, StdFile
from commondef import unzip3,unzip4


instance toString FontDef
instance accScreenPicture (PSt .l)
instance FileEnv Files

safeOpenFont			:: !FontDef !(PSt .l) -> (Font,PSt .l)
safeOpenFixedFont		:: !FontDef !*Picture -> (Font,*Picture);
altScrollFunction		:: !Direction !Int -> ScrollFunction
alignScrollFunction		:: !Direction !Int -> ScrollFunction
filterReturnKeys		:: KeyboardStateFilter
escFilter				:: KeyboardStateFilter
toMark					:: !Bool -> MarkState
toSelect				:: !Bool -> SelectState
noPS					:: .(.a -> .b) !(.a,.c) -> (.b,.c)
drawLeft				:: !.Point2 a !*Picture -> *Picture | toString a
drawCenter				:: !.Point2 a !*Picture -> *Picture | toString a
drawRight				:: !.Point2 a !*Picture -> *Picture | toString a
setCheckControlItem		:: !Id .Index !.Bool !*(IOSt .l) -> *(IOSt .l)
zip3					:: ![.a] [.b] [.c] -> [(.a,.b,.c)]
getPenAttributeFont		:: ![.PenAttribute] -> FontDef;
getPenAttributeColour	:: ![.PenAttribute] -> Colour;
getPenAttributeBack		:: ![.PenAttribute] -> Colour;
seqmap					:: (.a -> .(.b -> .b)) ![.a] !.b -> .b;
notEmpty s				:== not (isEmpty s)
lisFixedWidth			:: !.FontName !*Picture -> (!Bool,!*Picture)
lfilter					:: ![.Bool] ![.a] -> [.a]
