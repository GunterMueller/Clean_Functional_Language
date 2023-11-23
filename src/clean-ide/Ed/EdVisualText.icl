implementation module EdVisualText

// visual operations on texts

import StdClass, StdFunc, StdArray, StdInt, StdMisc, StdList, StdBool
import StdIOCommon, StdPicture, StdPSt, StdWindow
import EdText, EdTab, StrictList, EdMonad, EdSelection

//-- util

tabStringWidth :: !Int ![String] !FontInfo -> Int
tabStringWidth startX strings {tabSize, charWidth}
	# widths = map width strings
	= (virtualDraw widths startX) - startX
where
	width s = (size s) * charWidth

	virtualDraw []		_ = 0
	virtualDraw [w]		x = x + w
	virtualDraw [w:ws]	x = virtualDraw ws x`
	where
		x`	= tabWidth * (inc ((x + w) / tabWidth))
	
	tabSize`	= max 1 tabSize			// ensure sensible minimum
	tabWidth	= tabSize` * charWidth

seqmap :: (.a -> .(.b -> .b)) ![.a] !.b -> .b;
seqmap f [] e = e
seqmap f [h:t] e
	#! e = f h e
	= seqmap f t e

// compute the y-coordinate of the base line of a certain text line

computeBaseLine :: !LineNr !FontInfo -> Int
computeBaseLine lineNr { metrics, lineHeight }
  = lineNr * lineHeight + metrics.fAscent + metrics.fLeading

// computeViewDomain computes the rectangle that is needed
// to completely show the current visual text

computeViewDomain :: EditMonad .env ViewDomain 
computeViewDomain 
  = getText			>>>= \text ->
	getFontInfo		>>>= \fontInfo ->
	getLineNumbers	>>>= \lineNumbers ->
	result 
	   { corner1 = { x = if lineNumbers (fontInfo.metrics.fMaxWidth*(-5)) (-4)
				   , y = 0
				   }
	   , corner2 = { x = fontInfo.charWidth * MAX_LINE_WIDTH
				   , y = fontInfo.lineHeight * textLength text + fontInfo.metrics.fLeading + fontInfo.metrics.fDescent
				   }
	   }
where
	MAX_LINE_WIDTH = 320

//\\//\\//\\//\\//
getViewFrame :: EditMonad (PSt .l) ViewFrame
getViewFrame
  = getWindowId		>>>= \windowId ->
	accEnv (accPIO (getWindowViewFrame windowId))
  
//-- EXPORTED

vUpdateText :: !FontInfo !Text !ViewFrame ![Rectangle] -> (*Picture -> *Picture)
vUpdateText fontInfo text frame rectangles
	= seqmap (vUpdateRectangle text fontInfo) rectangles

vInsertText :: Position TextFragment -> EditMonad (PSt .l) nothing
vInsertText position textFragment =
	getText										>>>= \text ->
	let (fin,newText) = insertText position textFragment text
	in
	setText newText								>>>
	IF (isNothing fin)
	THEN
		vResetViewDomain
	ELSE
//		(vTextUpdate position (fromJust fin - position.row + 1))
		let
			(beg,end)	= fromJust fin
		in
		(vTextUpdate {col=0,row=beg} (end - beg + 1))

vAppendLines :: TextFragment -> EditMonad (PSt .l) nothing
vAppendLines textFragment =
	getText										>>>= \text ->
	let
		newText = appendLines textFragment text
	in
	setText newText								>>>
	vResetViewDomain
where
	vResetViewDomain (editState,pState)
		#! (windowId,(editState,pState))	= getWindowId (editState,pState)
		#! (maybeOldViewDomain,pState)		= accPIO (getWindowViewDomain windowId) pState
		| isNothing maybeOldViewDomain
			= abort "vResetViewDomain (EdVisualText.icl): unknown window id"
		#! oldViewDomain					= fromJust maybeOldViewDomain
//		#! (oldViewFrame,pState)			= accPIO (getWindowViewFrame windowId) pState
		#! (viewDomain,(editState,pState))	= computeViewDomain (editState,pState)
		| viewDomain == oldViewDomain
			#! pState						= appPIO (updateWindow windowId Nothing) pState
			= (undef,(editState,pState))
		#! pState = appPIO (setWindowViewDomain windowId viewDomain) pState
		= (undef,(editState,pState))
	
vAppendText :: TextFragment -> EditMonad (PSt .l) nothing
vAppendText textFragment =
	getText										>>>= \text ->
	let
		newText = appendText textFragment text
	in
	setText newText								>>>
	vResetViewDomain
where
	vResetViewDomain (editState,pState)
		#! (windowId,(editState,pState))	= getWindowId (editState,pState)
		#! (maybeOldViewDomain,pState)		= accPIO (getWindowViewDomain windowId) pState
		| isNothing maybeOldViewDomain
			= abort "vResetViewDomain (EdVisualText.icl): unknown window id"
		#! oldViewDomain					= fromJust maybeOldViewDomain
//		#! (oldViewFrame,pState)			= accPIO (getWindowViewFrame windowId) pState
		#! (viewDomain,(editState,pState))	= computeViewDomain (editState,pState)
		| viewDomain == oldViewDomain
			#! pState						= appPIO (updateWindow windowId Nothing) pState
			= (undef,(editState,pState))
		#! pState = appPIO (setWindowViewDomain windowId viewDomain) pState
		= (undef,(editState,pState))
	

vRemoveText :: !Selection -> EditMonad (PSt .l) nothing
vRemoveText selection=:{ start=start=:{ col=col1,row=row1 }
					   , end={ col=col2,row=row2 }
					   }
  = getText										>>>= \text ->
	let (fin,newText) = removeText selection text
	in
	setText newText								>>>
	IF (isNothing fin)
	THEN
		vResetViewDomain
	ELSE
//		(vTextUpdate start (fromJust fin - row1 + 1))
		let (beg,end) = fromJust fin in
		(vTextUpdate {col=0,row=beg} (end - beg + 1))

//--

// updating a rectangle is done by first erasing it and then redrawing
// the lines contained in that rectangle

// FIXME: this code assumes that corner1 of the rectangle is the upper left
// and corner2 the lower right corner, which is not garantueed by the ObjectIO
// (although in practice it is)

//vUpdateRectangle :: Text FontInfo Rectangle *Picture -> *Picture//-> EditMonad *Picture nothing
vUpdateRectangle text fontInfo=:{lineHeight,thefont,syntaxColours} rectangle=:{ corner1 = {x=x1,y=y1}, corner2 = {x=x2,y=y2} } //pict =
	// compute which lines were affected and retrieve them
	= vUR
where
	vUR pict
		# x1` = min x1 x2
		# x2` = max x1 x2
		# y1` = min y1 y2
		# y2` = max y1 y2
		# lineNr1	= validateLineNr (y1` / lineHeight) text 
		# lineNr2	= validateLineNr (y2` / lineHeight) text
		# rectangle` = {corner1 = {x = max (-1) x1`, y = y1`}, corner2 = {x = max (-1) x2`, y = y2`}}
		# region`	= toRegion rectangle`
		# pict		= appClipPicture region` (seq
						[ setPenFont thefont
						, drawBackground syntaxColours fontInfo rectangle`
						, drawLines lineNr1 lineNr2 fontInfo text
						]) pict
		= pict

	// drawBackground colours the background
	drawBackground colours {charWidth, marginWidth} r=:{ corner1 = {x=x1,y=y1}, corner2 = {x=x2,y=y2} }
		| marginWidth <= 0 || x2 <= margin
			= seq	[ setPenBack colours.backgroundColour
					, unfill r
					]
		| x1 >= margin
			= seq	[ setPenBack colours.marginColour
					, unfill r
					]
		//
			= seq	[ setPenBack colours.marginColour
					, unfill {r & corner1.x = margin}
					, setPenBack colours.backgroundColour
					, unfill {r & corner2.x = margin}
					]
		where
			margin
				=	marginWidth * charWidth
			
	// drawLines draws the lines in the range indicated by
	// the first two arguments, e.g. drawLines 0 3 draws the
	// text lines 0, 1, 2, and 3.
	
	//drawLines :: LineNr LineNr FontInfo Text *Picture -> *Picture 
	drawLines f l i=:{showSyntax} t p
		| showSyntax = drawLinesC f l i t p
		= drawLinesP f l i t p
	
	// draw lines with syntax colouring
	drawLinesC firstLine lastLine fontInfo=:{ lineHeight, metrics} text picture
		= drawTextLines firstLine firstY text picture
	where
		firstY		= computeBaseLine firstLine fontInfo
	
//		drawTextLines :: Int Int Text *Picture -> *Picture
		drawTextLines f y text picture
		  | f > lastLine
		  	= picture
		  # (line,text) = getLineC f text
		  # picture = tabDrawStringC {x=0,y=y} line fontInfo picture
		  = drawTextLines (inc f) (y + lineHeight) text picture
	
	// draw lines plain
	drawLinesP firstLine lastLine fontInfo=:{ lineHeight, metrics} text picture
		= drawTextLines firstY lines picture
	where
		firstY		= computeBaseLine firstLine fontInfo
		(lines, _)	= getLines firstLine lastLine text
	
		drawTextLines :: Int (StrictList String) *Picture -> *Picture
		drawTextLines _ SNil picture
		  = picture
		drawTextLines y (SCons string strings) picture
		  # picture = tabDrawString { x=0,y=y } string fontInfo picture
		  # picture = drawTextLines (y + lineHeight) strings picture
		  = picture

vTextUpdate :: !Position Int -> EditMonad (PSt .l) nothing
vTextUpdate position=:{row} numLines =
	getText 					>>>= \text ->
	getViewFrame				>>>= \frame ->
	getFontInfo					>>>= \fontInfo ->
	let point = positionToPoint position text fontInfo in
	
	// one line affected or more ?
	IF (numLines <> 0)
	THEN
	  ( 
		// compute the rectangle that covers the rest of the line
		let updateRect
				  = { corner1={ x=frame.corner1.x, y=point.y }
					, corner2={ x=frame.corner2.x, y= min (frame.corner2.y) (point.y+fontInfo.lineHeight * numLines)}
					}
		in
		vDraw (vUpdateRectangle text fontInfo updateRect) 
	  )
	ELSE
	  (
		let updateRect
			  = { corner1={ x=frame.corner1.x, y=point.y }
				, corner2={ x=frame.corner2.x, y=frame.corner2.y }
				}
		in
		vDraw (vUpdateRectangle text fontInfo updateRect)
	  )

// vResetViewDomain changes the view domain, so that the current visual
// text fits in the window.

vResetViewDomain :: EditMonad (PSt .l) nothing
vResetViewDomain  = monad
where
	monad (editState,pState)
		#! (windowId,(editState,pState))	= getWindowId (editState,pState)
		#! (maybeOldViewDomain,pState)		= accPIO (getWindowViewDomain windowId) pState
		| isNothing maybeOldViewDomain
			= abort "vResetViewDomain (EdVisualText.icl): unknown window id"
		#! oldViewDomain					= fromJust maybeOldViewDomain
		#! (viewDomain,(editState,pState))	= computeViewDomain (editState,pState)
		| viewDomain == oldViewDomain
			#! pState						= appPIO (updateWindow windowId Nothing) pState
			= (undef,(editState,pState))
		#! (x,(editState,pState))			= my_set_view_domain windowId viewDomain (editState,pState)
		= (x,(editState,pState))

	my_set_view_domain windowId viewDomain (editState,pState)
		#! pState = appPIO (setWindowViewDomain windowId viewDomain) pState
		#! pState = appPIO (updateWindow windowId Nothing) pState	// quick fix for changed setViewDomain interpretation...
		= (undef,(editState,pState))
	
vDraw :: (*Picture -> *Picture) -> EditMonad (PSt .l) a
vDraw drawFun =
	getWindowId		>>>= \windowId ->
	appEnv (appPIO (appWindowPicture windowId drawFun))

//--

positionToPoint :: !Position !Text !FontInfo -> Point2
positionToPoint {col, row} text fontInfo
	# (textLine, _)	= getLine row text
	# left			= textLine % (0, col-1) 
	# y				= fontInfo.lineHeight * row
	# x				= tabStringWidth 0 (splitAtTabs left) fontInfo
	= {x=x, y=y}

// pointToPosition 
// First, it determines the character in the middle of the line and
// then x-coordinate of the middle of that character. It then
// goes into recursion on the correct "half" until the segment
// has become empty.
	
pointToPosition :: !Point2 !Text !FontInfo -> Position
pointToPosition { x, y } text fontInfo
	# row = y / fontInfo.lineHeight 
	# lastLineNr = textLength text - 1
	| (row > lastLineNr)
	  	# (lastLine, _) = getLine lastLineNr text
	  	= {col=size lastLine, row=lastLineNr}
	| (row < 0)
	  = {col=0, row=0}
	# col = findColumn x row text fontInfo
	= {col=col, row=row}
where
	findColumn :: Int LineNr Text FontInfo -> Int
	findColumn x row text fontInfo
		| x < 0
			= 0
		# (textLine, _)	= getLine row text
		# len			= size textLine
		# splitLine		= splitAtTabs textLine
		# width			= tabStringWidth 0 splitLine fontInfo
		| x > width
			= len
			= binarySearch x 0 len splitLine
	where
		binarySearch :: Int Int Int [String] -> Int
		binarySearch x left right splitLine
			| left==right
				= left
			# middle = left + (right - left) / 2
			# width1 = tabStringWidth 0 (tabTake middle splitLine) fontInfo
			# width2 = tabStringWidth 0 (tabTake (middle+1) splitLine) fontInfo
			# middleX = (width1 + width2) / 2
			| x < middleX
				= binarySearch x left       middle splitLine
				= binarySearch x (middle+1) right  splitLine

