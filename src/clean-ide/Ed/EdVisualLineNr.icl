implementation module EdVisualLineNr

import StdArray,StdClass,StdFunc,StdInt
import StdIOCommon,StdPicture
import EdMonad, EdText
from ioutil import seqmap

//-- public

vDrawLineNrs :: !FontInfo !Text !ViewFrame ![Rectangle] -> (*Picture -> *Picture)
vDrawLineNrs fontinfo text frame rectangles =
		seqmap (vUpdate text fontinfo) rectangles

//-- private

vUpdate text fontinfo=:{lineHeight,thefont} rectangle=:{ corner1 = {x=x1,y=y1}, corner2 = {x=x2,y=y2} } =
	
	// compute which lines were affected and retrieve them
	
	let lineNr1 = (validateLineNr (y1 / lineHeight) text )
		lineNr2 = (validateLineNr (y2 / lineHeight) text )
	in

	 (
		appClipPicture (toRegion rectangle`) ( seq
			[ setPenColour	LightGrey
			, setPenFont thefont
			, fill rectangle`
			, setPenColour Black
			, drawLineNrs lineNr1 lineNr2 fontinfo
			]
		)
	)
where
	l = min r (max (-100) x1)
	r = min (0) x2
	rectangle` = {corner1 = {x = l, y = y1}, corner2 = {x = r, y = y2}}

drawLineNrs lineNr1		// first line
		  lineNr2		// last line
		  fontInfo=:{ lineHeight, metrics, charWidth } 
		  picture
  = drawLines firstY (inc lineNr1) (inc lineNr2) picture
where
	// compute the base line of the first line
	firstY = computeBaseLine lineNr1 fontInfo

	drawLines y n m picture
	  | n > m = picture
	  # picture = drawRight { x= -5, y = y } n picture
	  = drawLines (y + lineHeight) (inc n) m picture
	  
	drawRight v=:{x} n p
		# n = toString n
		# d = (size n) * charWidth
		= drawAt {v & x = x - d} n p

// compute the y-coordinate of the base line of a certain text line

//computeBaseLine :: LineNr FontInfo -> Int
computeBaseLine lineNr { metrics, lineHeight }
  = lineNr * lineHeight + metrics.fAscent + metrics.fLeading

