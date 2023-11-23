implementation module ioutil

import StdBool,StdList,StdFile
import StdControl,StdPSt
import iostate

altScrollFunction :: !Direction !Int -> ScrollFunction
altScrollFunction direction d
	= altScrollFunction` direction d
where
	altScrollFunction` :: !Direction !Int !ViewFrame !SliderState !SliderMove -> Int
	altScrollFunction` direction d {corner1,corner2} {sliderThumb=x} move
		# d				= abs d
		  edge			= if (direction==Horizontal)
		  					(abs (corner2.x-corner1.x-d))
		  					(abs (corner2.y-corner1.y-d))
		= case move of
			SliderIncSmall	-> x+d
			SliderDecSmall	-> x-d
			SliderIncLarge	-> x+edge
			SliderDecLarge	-> x-edge
			SliderThumb x	-> x

alignScrollFunction :: !Direction !Int -> ScrollFunction
alignScrollFunction direction d
	= alignScrollFunction` direction d
where
	alignScrollFunction` :: !Direction !Int !ViewFrame !SliderState !SliderMove -> Int
	alignScrollFunction` direction d {corner1,corner2} {sliderThumb=x,sliderMax=m} move
		# d				= abs d
		  edge			= if (direction==Horizontal)
		  					(abs (corner2.x-corner1.x-d))
		  					(abs (corner2.y-corner1.y-d))
		= case move of
			SliderIncSmall	-> let x` = x+d in if (x`>m) m (align x`)
			SliderDecSmall	-> align (x-d)
			SliderIncLarge	-> align (x+edge)
			SliderDecLarge	-> align (x-edge)
			SliderThumb x	-> if (x == m) x (align x)
	align x = (x / d) * d

safeOpenFont :: !FontDef !(PSt .l) -> (Font,PSt .l)
safeOpenFont fdef ps
	# ((ok,font),ps)	= accScreenPicture (openFont fdef) ps
	| not ok
		= accScreenPicture openDefaultFont ps
	= (font,ps)

safeOpenFixedFont :: !FontDef !*Picture -> (Font,*Picture);
safeOpenFixedFont fdef pict
	# ((ok,fnt),pict) = openFont fdef pict
	# ((ok,fnt),pict) = case ok of
							True -> ((ok,fnt),pict)
							False -> openFont fdef` pict
	| not ok
		= openDefaultFont pict
	= (fnt,pict)
where
	fdef` = NonProportionalFontDef
	
instance toString FontDef
where
	toString {fName,fSize,fStyles} = "<fName: "+++fName+++",fSize: "+++toString fSize+++",fStyles: "+++toS fStyles+++ ">"
	where
		toS [] = ""
		toS [s] = s
		toS [h:t] = h+++", "+++toS t

filterReturnKeys :: KeyboardStateFilter
filterReturnKeys = filterfun
where
	filterfun (SpecialKey key  (KeyDown False) _)	= key==enterKey || key==returnKey
//	filterfun (CharKey    '\n' (KeyDown False))		= True
	filterfun _										= False

escFilter :: KeyboardStateFilter
escFilter = filter
where
	filter (SpecialKey key KeyUp mods) = (key == escapeKey) && (mods == NoModifiers)
	filter _ = False

instance accScreenPicture (PSt .l)
where
	accScreenPicture f ps = accPIO (accScreenPicture f) ps

toMark :: !Bool -> MarkState
toMark True = Mark
toMark False = NoMark

toSelect :: !Bool -> SelectState
toSelect True = Able
toSelect False = Unable

noPS :: .(.a -> .b) !(.a,.c) -> (.b,.c)
noPS f (ls,ps) = (f ls,ps)

drawLeft :: !.Point2 a !*Picture -> *Picture | toString a
drawLeft point info picture
	#	text				= toString info
	=	drawAt point text picture

drawCenter :: !.Point2 a !*Picture -> *Picture | toString a
drawCenter {x,y} info picture
	#	text				= toString info
		(width,picture)		= getPenFontStringWidth text picture
	=	drawAt {x=x-width/2,y=y} text picture

drawRight :: !.Point2 a !*Picture -> *Picture | toString a
drawRight {x,y} info picture
	#	text				= toString info
		(width,picture)		= getPenFontStringWidth text picture
	=	drawAt {x=x-width,y=y} text picture

setCheckControlItem :: !Id .Index !.Bool !*(IOSt .l) -> *(IOSt .l)
setCheckControlItem id idx True io = markCheckControlItems id [idx] io
setCheckControlItem id idx False io = unmarkCheckControlItems id [idx] io

zip3::![.a] [.b] [.c] -> [(.a,.b,.c)]
zip3 [a:as] [b:bs] [c:cs]	= [(a,b,c):zip3 as bs cs]
zip3 as bs cs				= []

getPenAttributeFont :: ![.PenAttribute] -> FontDef;
getPenAttributeFont [] = SansSerifFontDef
getPenAttributeFont [PenFont f:_] = getFontDef f
getPenAttributeFont [_:t] = getPenAttributeFont t

getPenAttributeColour :: ![.PenAttribute] -> Colour;
getPenAttributeColour [] = Black
getPenAttributeColour [PenColour c:_] = c
getPenAttributeColour [_:r] = getPenAttributeColour r

getPenAttributeBack :: ![.PenAttribute] -> Colour;
getPenAttributeBack [] = White
getPenAttributeBack [PenBack c:_] = c
getPenAttributeBack [_:r] = getPenAttributeBack r

instance FileEnv Files
where
	accFiles f e = f e
	appFiles f e = f e

seqmap :: (.a -> .(.b -> .b)) ![.a] !.b -> .b;
seqmap f [] e = e
seqmap f [h:t] e
	#! e = f h e
	= seqmap f t e

notEmpty s		:== not (isEmpty s)

//--

lisFixedWidth :: !.FontName !*Picture -> (!Bool,!*Picture)
lisFixedWidth fontname env
  # ((ok,font),   env) = openFont {fName=fontname,fSize=12,fStyles=[]} env
  | not ok = (ok,env)
//  # (wide,	 env) = getFontCharWidth font 'M' env
//	(narrow, env) = getFontCharWidth font 'i' env
  # ([wide,narrow:_], env)	= getFontCharWidths font ['M','i'] env
  = (wide == narrow, env)

lfilter :: ![.Bool] ![.a] -> [.a]
lfilter [True:r] [a:x]	= [a:lfilter r x]
lfilter [_:r] [_:x] = lfilter r x
lfilter _ _				= []

