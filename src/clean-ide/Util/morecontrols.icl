implementation module morecontrols

import StdList
import  StdControl

// font name control

FontNameControl :: [.String] (String -> IdFun *(.a,.b)) .Index [.ControlAttribute *(.a,.b)] -> .PopUpControl .a .b;
FontNameControl names action initial atts =
  	PopUpControl
  	[ (name, (action name))
  	\\ name <- names
  	] initial (atts++[])

// font size control

FontSizeControl :: .[a] (a -> IdFun *(.b,.c)) .Index [.ControlAttribute *(.b,.c)] -> .PopUpControl .b .c | toString a;
FontSizeControl sizes action initial atts =
	PopUpControl
	[ (toString size, (action size))
	\\ size <- sizes
	] initial (atts++[])				// make editable...

//--

findNameInList :: a !.[a] -> Int | == a;
findNameInList name list
	= find 1 list
where
	find i [] = 0
	find i [h:t]
		| name==h = i
		= find (inc i) t

//==
import StdEnv,StdIO

:: FontNameSizeControl ls pst =
  FontNameSizeControl
	.String
	.Int
	[.String]
	[.Int]
	(String -> IdFun *(ls,pst))
	(Int -> IdFun *(ls,pst))
	[.ControlAttribute *(ls,pst)]

instance Controls FontNameSizeControl
where
	getControlType _ = "FontNameSizeControl"
	controlToHandles (FontNameSizeControl fontname fontsize fontNames fontSizes nameFun sizeFun atts) ps
		# (namesId,ps)	= openId ps
		# (sizesId,ps)	= openId ps
		# control
		      =	LayoutControl
		      	(	TextControl "Font:" [ left ]
			  	:+: FontNameControl fontNames nameFun (findNameInList fontname fontNames) [ControlId namesId]
				:+:	TextControl "Size:" [ left ]
				:+: FontSizeControl fontSizes sizeFun (findNameInList fontsize fontSizes) [ControlId sizesId]
				) (atts++[ControlHMargin 0 0,ControlVMargin 0 0])
		# selectfun = \fontname fontsize ps ->
						let
					    	namesIdx		= findNameInList fontname fontNames
					    	sizesIdx		= findNameInList fontsize fontSizes
				    	in appPIO (selectPopUpControlItem sizesId sizesIdx o selectPopUpControlItem namesId namesIdx) ps
		= controlToHandles control ps
	where
	    left = ControlPos (Left, zero)
