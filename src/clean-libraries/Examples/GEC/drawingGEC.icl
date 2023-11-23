module drawingGEC

import StdEnv
import StdIO
import StdGEC

// TO TEST JUST REPLACE THE EXAMPLE NAME IN THE START RULE WITH ANY OF THE EXAMPLES BELOW
// ALL EXAMPLES HAVE TO BE OF FORM pst -> pst

goGui :: (*(PSt u:Void) -> *(PSt u:Void)) *World -> .World
goGui gui world = startIO MDI Void gui [ProcessClose closeProcess] world

Start :: *World -> *World
Start world 
= 	goGui 
 	example_draw
 	world  

derive gGEC  Rectangle,Point2,Colour,RGBColour,ShapeAttributes,Shape,Oval,Box 

:: Shape =
	  Box Box
	| Oval Oval

:: ShapeAttributes =
	{ pen_colour 	:: Colour
	, pen_size	 	:: AGEC Int
	, fill_colour	:: Colour
	, x_offset		:: AGEC Int 
	, y_offset		:: AGEC Int
	}

myclock = Timed (\i -> 100) 100 

derive ggen Shape, ShapeAttributes, Mode, Oval, Box, Colour, RGBColour

example_draw pst
#	(wid,pst) 	= openId pst
#    pst 		= snd (openWindow Void (Window "Drawings" NilLS [WindowId wid]) pst)
=	startCircuit ( feedback ( 		edit "Editor" 
							>>> 	arr move 
							>>>		gecIO (mydrawfun wid) 
			  				)
		 		 ) (initrecord 100 100, myclock) pst
	
	where

		move ((initbox  <|> attr=:{x_offset},old),c) 
		| ^^ x_offset <= 300	=  ((initbox  <|> {attr & x_offset=counterAGEC(^^ x_offset + 5)},Hide (initbox  <|> attr)),	c)
		| otherwise				=  ((initbox  <|> {attr & x_offset=counterAGEC 100},Hide(initbox  <|> attr)),			c)

		mydrawfun wid (pict,hpict) pst
		# pst = appPIO (setWindowLook wid True (True,drawfun pict)) pst 
		= ((pict,hpict),pst)
		
		drawfun (Box nrect<|>nattr, Hide (Box orect<|>oattr))  nx nxx
											=	drawshape nrect nattr orect oattr
		drawfun (Oval nrect<|>nattr, Hide (Box orect<|>oattr))  nx nxx
											=	drawshape nrect nattr orect oattr

		drawshape nshape nattr oshape oattr =	drawAt n_offset nshape o
												setPenSize (^^ nattr.pen_size) o 
												setPenColour nattr.pen_colour o 
												fillAt n_offset nshape o 
												setPenColour nattr.fill_colour o 
												unfillAt o_offset oshape o
												undrawAt o_offset oshape 
		where
			n_offset = {x= ^^ nattr.x_offset,y= ^^ nattr.y_offset}
			o_offset = {x= ^^ oattr.x_offset,y= ^^ oattr.y_offset}
	
		initrecord	i j = (initstate i j,Hide (initstate (i-5) j))
		initstate i j = initbox  <|> initattr i j
		initbox  = Box {box_w=30,box_h=30}
		initattr i j = {pen_colour=Black,pen_size=counterAGEC 2,fill_colour=Red,x_offset=counterAGEC i,y_offset=counterAGEC j}
