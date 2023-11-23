module draw2GEC

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

derive gGEC  Rectangle,Point2,Colour,RGBColour,ShapeAttributes,Oval,Box, Shape 

:: Shape = Box

:: ShapeAttributes t =
	{ shape		 	:: Shape
	, pen_colour 	:: Colour
	, pen_size	 	:: t
	, fill_colour	:: Colour
	, heigth		:: t
	, width			:: t
	, x_offset		:: t 
	, y_offset		:: t
	}

myclock = Timed (\i -> 100) 100 


derive gGEC MouseState, Modifiers
derive ggen ShapeAttributes, Mode, MouseState, Colour, Shape, Modifiers, Point2, RGBColour

example_mouse pst
	=	startCircuit (feedback  (  edit "Mouse" >>> gecMouse "Mouse" )) MouseLost pst

example_draw pst
=	startCircuit ( feedback ( 		arr (\list -> listAGEC True [(toEditReprs fig,Hide fig) \\ fig <- list])
				>>>		edit "Editor"
				>>>		arr	(\list -> [(fromEditReprs nfig,ofig) \\ (nfig,Hide ofig) <- ^^ list])
				>>>		(gecMouse "Drawings" &&& gecIO (mydrawfun "Drawings") ) 
				>>>		arr	(\(mousestate,list) -> hit mousestate [fig \\ (fig,_) <- list])
			  )
		 ) [(initshape 30 30 100 100)] pst
	
	where


		hit (MouseDown point2 mods nrs) figs = map (change point2) figs
		hit _ figs = figs 

		change {x,y} fig=:{heigth,width,x_offset,y_offset}
		|  x_offset <= x && x <= x_offset+width &&
		   y_offset <= y && y <= y_offset+heigth = {fig & fill_colour = Red}
		= fig

		mydrawfun title figlist pst
		# (Just wid,pst) = accPIO (searchWindowIdWithTitle title) pst
		# pst = appPIO (setWindowLook wid True (True,mapdrawfig figlist)) pst 
		= (figlist,pst)
		
		mapdrawfig [] _ _ 			=	setPenColour Black
		mapdrawfig [fig:figs] x xx  =	drawfig fig o mapdrawfig figs x xx

		drawfig (nfig,ofig) =	drawAt n_offset n_shape			o
								setPenSize nfig.pen_size 		o 
								setPenColour nfig.pen_colour	o 
								fillAt n_offset n_shape 		o 
								setPenColour nfig.fill_colour	o
								unfillAt o_offset o_shape		o
								undrawAt o_offset o_shape 
		where
			n_shape			=	{box_w = nfig.width	, box_h= nfig.heigth}
			o_shape			=	{box_w = ofig.width	, box_h= ofig.heigth}
			n_offset 		= 	{x = nfig.x_offset	, y = nfig.y_offset}
			o_offset 		= 	{x = ofig.x_offset	, y = ofig.y_offset}

		initshape h w xoff yoff 
						= 	{ shape		 	= 	Box
							, pen_colour 	= 	Black
							, pen_size	 	= 	1
							, fill_colour	= 	Red
							, heigth		= 	h 
							, width			= 	w
							, x_offset		= 	xoff 
							, y_offset		= 	yoff
							}

		toEditReprs :: (ShapeAttributes Int) -> ShapeAttributes (AGEC Int)
		toEditReprs all=:{pen_size,heigth,width,x_offset,y_offset}
			= {all & pen_size 	= counterAGEC pen_size
				   , heigth 	= counterAGEC heigth
				   , width 		= counterAGEC width
				   , x_offset 	= counterAGEC x_offset
				   , y_offset 	= counterAGEC y_offset
				   } 
		fromEditReprs :: (ShapeAttributes (AGEC Int)) -> ShapeAttributes Int
		fromEditReprs all=:{pen_size,heigth,width,x_offset,y_offset}
			= {all & pen_size 	= ^^ pen_size
				   , heigth 	= ^^ heigth
				   , width 		= ^^ width
				   , x_offset 	= ^^ x_offset
				   , y_offset 	= ^^ y_offset
				   } 
	