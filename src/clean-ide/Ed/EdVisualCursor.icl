implementation module EdVisualCursor

// visual operations on the cursor

import StdInt, StdClass, StdBool, StdFunc
import StdPicture, StdWindow, StdPSt, StdList
import EdSelection, EdVisualText, EdMovement, EdTab
import ioutil, StrictList

//--

vCenterCursor :: EditMonad (PSt .l) nothing
vCenterCursor = vMakeCursorVisible True Nothing

vScrollToCursor :: EditMonad (PSt .l) nothing
vScrollToCursor = vMakeCursorVisible False Nothing

vDragCursor :: !Point2 -> EditMonad (PSt .l) nothing
vDragCursor point = vMakeCursorVisible False (Just point)

vMakeCursorVisible :: !Bool !(Maybe Point2) -> EditMonad (PSt .l) nothing
vMakeCursorVisible center drag =
	getWindowId					>>>= \windowId ->
	accEnv (accPIO (getWindowViewFrame windowId))		>>>= \viewFrame -> 
//	accEnv (accPIO (getWindowViewDomain windowId))		>>>= \viewDomain -> 
	getSelection				>>>= \{start,end} ->
	getText						>>>= \text ->
	getFontInfo					>>>= \fontInfo=:{FontInfo | lineHeight,charWidth} ->
	let // give names to the components of the view frame
		cursorPoint = positionToPoint end text fontInfo
		left	 = viewFrame.corner1.x
		right	 = viewFrame.corner2.x
		top		 = viewFrame.corner1.y
		bottom	 = viewFrame.corner2.y
		
		// determine whether the cursor is on the 
		// correct (visible) side of the borders
		leftOk	 = cursorPoint.x - charWidth >= left
//		leftOk	 = case end.col of
//					0	-> (fromJust viewDomain).corner1.x = left
//					_	-> cursorPoint.x - charWidth >= left
		rightOk	 = cursorPoint.x + charWidth <= right
		topOk	 = cursorPoint.y >= top
		bottomOk = cursorPoint.y + lineHeight <= bottom
		cursorOk = leftOk && rightOk && topOk && bottomOk
		
		singleline= end.row - start.row == 0
		(dontMove,nrHPixels) 
				 = case drag of
					Just point  #
									hslop`     = charWidth
									vslop`     = lineHeight
//									leftOk`	  = point.x - hslop` >= left
//									rightOk`  = point.x + hslop` <= right
									leftOk`	  = point.x >= left
									rightOk`  = point.x <= right
									topOk`	  = point.y >= top
									bottomOk` = point.y <= bottom
									mouseOk   = leftOk` && rightOk` && topOk` && bottomOk`

									hslop``     = charWidth * 8
									vslop``     = lineHeight
									leftOk``	 = cursorPoint.x - hslop`` >= left
									rightOk``	 = cursorPoint.x + hslop`` <= right
									topOk``	 	 = cursorPoint.y >= top
									bottomOk``   = cursorPoint.y + vslop`` <= bottom
									cursorOk``   = leftOk`` && rightOk`` && topOk`` && bottomOk``
/*
									nrHPixels	= if (leftOk`` && rightOk``)
													0
													(if rightOk``
													   ( point.x - hslop` - left )
													   ( point.x + hslop` - right )
													)
*/
									nrHPixels``	= if (leftOk`` && rightOk``)
														0
														(if rightOk``
														   (~charWidth)//( point.x - hslop` - left )
														   charWidth//( point.x + hslop` - right )
														)

									nrHPixels	= if (leftOk && rightOk)
													0
													(if rightOk
													   ( cursorPoint.x - charWidth - left )
													   ( cursorPoint.x + charWidth - right )
													)
/*									nrHPixels = if (leftOk`` && rightOk``)
														0
														(if rightOk``
														   ( cursorPoint.x - hslop`` - left )
														   ( cursorPoint.x + hslop`` - right )
														)
*/
//								-> (if singleline (mouseOk || cursorOk``) (cursorOk``), nrHPixels)
								-> if singleline
									(mouseOk || cursorOk``,nrHPixels``)
									(cursorOk``,nrHPixels)
					Nothing		#
									nrHPixels	= if (leftOk && rightOk)
													0
													(if rightOk
													   ( cursorPoint.x - charWidth - left )
													   ( cursorPoint.x + charWidth - right )
													)
								-> (cursorOk, nrHPixels)
	in
	
	// if cursor is visible, nothing has to be done
	IF (dontMove)	   
	THEN  
	  ( skip )
	ELSE
	  (
		let halfHeight	= ( bottom - top ) / 2
			halfWidth	= ( right - left ) / 2
			newTop		= if (topOk && bottomOk) top  (cursorPoint.y - halfHeight)
			newLeft		= if (leftOk && rightOk) left (cursorPoint.x - halfWidth)
			nrVPixels	= if (topOk && bottomOk)
							0											// if visible do nothing
							(if bottomOk 
							   ( cursorPoint.y - top )					// if move up move to top...
							   ( cursorPoint.y + lineHeight - bottom )	// if move down move to bottom...
							)
			vector		= if center
							{ vx = newLeft - left, vy = newTop - top }
							{ vx = nrHPixels, vy = nrVPixels }
		in
		appEnv (appPIO (moveWindowViewFrame windowId vector))
	  )

vMoveCursor :: !Movement -> EditMonad (PSt .l) nothing
vMoveCursor move =
	getWindowId					>>>= \windowId ->
	accEnv (accPIO (getWindowViewFrame windowId))		>>>= \viewFrame -> 
	getSelection				>>>= \{end} ->
	getFontInfo					>>>= \fontInfo=:{FontInfo | lineHeight} ->
	getText						>>>= \text ->
	let // give names to the components of the view frame
		cursorPoint		= positionToPoint end text fontInfo
		left	 		= viewFrame.corner1.x
		right	 		= viewFrame.corner2.x
		top		 		= viewFrame.corner1.y
		bottom	 		= viewFrame.corner2.y
		
		// determine whether the cursor is on the 
		// correct (visible) side of the borders
		leftOk	 		= cursorPoint.x >= left 
		rightOk	 		= cursorPoint.x <= right
		halfWidth		= ( right - left ) / 2
		newLeft			= if (leftOk && rightOk) left (cursorPoint.x - halfWidth)
    	linesInFrame	= (bottom - top) / lineHeight
        pagePixels		= (linesInFrame - 1) * lineHeight 
        topPixel		= 0
        botPixel		= textLength text * lineHeight
        movePixel		= case move of
							PageUp          -> (max topPixel (top - pagePixels)) - top
							PageDown        -> (min botPixel (bottom + pagePixels)) - bottom
							_				-> 0
		vector			= { vx = newLeft - left, vy = movePixel }
	in
	appEnv (appPIO (moveWindowViewFrame windowId vector))

//---

vDoCursorSafe :: (EditMonad (PSt .l) a) -> EditMonad (PSt .l) a
vDoCursorSafe operation =
	vHideCursor						>>>
	operation						>>>
	vShowCursor

vShowCursor :: EditMonad (PSt .l) nothing
vShowCursor =
	getSelection					>>>= \selection=:{end} ->
	IF (isEmptySelection selection)
	THEN (
		getCursorVisibility				>>>= \visible ->
		IF visible
		THEN
		  ( skip)
		ELSE
		  (
			getCursorHeight				>>>= \height ->
			getFontInfo					>>>= \fontInfo ->
			getText						>>>= \text ->
			setCursorVisibility True	>>>
			vDraw (vDrawCursor True end height text fontInfo)
		  )
		)
	ELSE (skip)
  
vHideCursor :: EditMonad (PSt .l) nothing
vHideCursor =
	getCursorVisibility				>>>= \visible ->
	IF visible
	THEN
	  (
		getCursorHeight				>>>= \height ->			//  == lineHeight from fontInfo
		getFontInfo					>>>= \fontInfo ->
		getText						>>>= \text ->
		getSelection				>>>= \{end} ->
		setCursorVisibility False	>>>
		vDraw (vDrawCursor False end height text fontInfo)
	  )
	ELSE
	  ( skip )

vUpdateCursor :: !Bool !Position !Int !FontInfo !Text !ViewFrame ![Rectangle] -> (*Picture -> *Picture)
vUpdateCursor visible end height fontInfo text viewFrame rectangles =
	IF visible 
	THEN 
	  (
		let
			point	= positionToPoint end text fontInfo
			{x,y}	= point
		in
		IF (any (isCursorInRectangle point height) rectangles)
//		THEN (seq
		THEN (appXorPicture (seq
		  [ setPenColour Black
		  , drawLine	{ x=x, y=y }
		  				{ x=x, y=y+height - 1 }
//		  ])
		  ]))
		ELSE
		  id
	  )
	ELSE
	  id

vDrawCursor :: Bool Position Int Text FontInfo -> (*Picture -> *Picture)
vDrawCursor show end cursorHeight text fontInfo =
	let
		p		= positionToPoint end text fontInfo
		{x,y}	= p
	in
//		( appXorPicture (seq
//			[ setPenColour Black
/*
		( (seq
			[ setPenColour (if show Black fontInfo.syntaxColours.backgroundColour)
			, drawLine	{ x=x, y=y }
						{ x=x, y=y+cursorHeight - 1 }
			])
		)
*/ 
		( if True//show
		  (appXorPicture (seq
			[ setPenColour Black
			, drawLine	{ x=x, y=y }
						{ x=x, y=y+cursorHeight - 1 }
			]))
		  (seq
			[ setPenColour (backcolour x fontInfo)
			, drawLine	{ x=x, y=y }
						{ x=x, y=y+cursorHeight - 1 }
			])
		)
	where
		backcolour :: Int FontInfo -> Colour
		backcolour x {charWidth, marginWidth, syntaxColours}
			| marginWidth > 0 && x >= charWidth * marginWidth
				=	syntaxColours.marginColour
			// otherwise
				=	syntaxColours.backgroundColour
//--- Visual Selection Stuff

vUpdateSelection :: !Selection FontInfo Text ViewFrame [Rectangle] -> (*Picture -> *Picture)
vUpdateSelection selection fontInfo text frame rects =
	IF (isEmptySelection selection) THEN id ELSE (
	let orderedSelection = orderSelection selection
		clippedSelection = clipSelection frame fontInfo orderedSelection
	in
	vHiliteSelection frame rects text fontInfo clippedSelection
	)
 
vChangeSelectionTo :: Selection -> EditMonad (PSt .l) nothing
vChangeSelectionTo newSelection =
	// retrieve the current selection from the state and then
	// update the state with the new selection
	
	getSelection									>>>= \oldSelection ->
	setSelection newSelection						>>>
	
	// compute the selections that have to hilited and discard
	// those that are not visible
	
	getViewFrame									>>>= \frame ->
	getText											>>>= \text ->
	getFontInfo										>>>= \fontInfo ->
	let hiliteSels = changeSelection oldSelection newSelection
		visibleHiliteSels = map (clipSelection frame fontInfo) hiliteSels
	in

	// draw the visibile hilite selections
	
	vDraw ((seqmap (vHiliteSelection frame [frame] text fontInfo) 
						visibleHiliteSels))			>>>
	skip

vHiliteSelection :: ViewFrame [Rectangle] Text FontInfo Selection *Picture -> *Picture
vHiliteSelection frame upds text fontInfo=:{charWidth, marginWidth, syntaxColours} selection pic
	# rects = selToRects selection frame text fontInfo
//	# rects = trace_l rects rects
//	= trace_n` ("vHiliteSelection",frame) appClipPicture (toRegion upds)(seq(map hilite rects) ) pic
	| marginWidth <= 0
		= appClipPicture (toRegion upds)(seq(map hilite rects) o setPenBack syntaxColours.backgroundColour) pic
	//
		= appClipPicture (toRegion upds) (seq (map (hiliteBackground syntaxColours fontInfo) rects)) pic
where
	margin
		=	marginWidth * charWidth

	hiliteBackground colours {charWidth, marginWidth} r=:{ corner1 = {x=x1,y=y1}, corner2 = {x=x2,y=y2} }
		| marginWidth <= 0 || x2 <= margin
			= seq	[ setPenBack colours.backgroundColour
					, hilite r
					]
		| x1 >= margin
			= seq	[ setPenBack colours.marginColour
					, hilite r
					]
			= seq	[ setPenBack colours.marginColour
					, hilite {r & corner1.x = margin}
					, setPenBack colours.backgroundColour
					, hilite {r & corner2.x = margin}
					]
		where
			margin
				=	marginWidth * charWidth

vRemoveSelection :: EditMonad (PSt .l) nothing
vRemoveSelection =
	getSelection										>>>= \selection ->
	let orderedSelection = orderSelection selection
	in
    IF (isEmptySelection selection)
    THEN
	  ( skip )
	ELSE   
	  (
		let
			pos = orderedSelection.start
		in
		vChangeSelectionTo {start=pos,end=pos}	>>>
		vRemoveText orderedSelection
	  )

//--

// clipSelectionToRectangle takes a selection and a rectangle and
// determines the part of the selection that is visible within
// the rectangle.

clipSelection :: Rectangle FontInfo Selection -> Selection
clipSelection
		{ corner1 = { x = x1, y = y1 }, corner2 = { x = x2, y = y2 } }
		fontInfo=:{FontInfo | lineHeight}
		{ start = { col = col1, row = row1 }, end = { col = col2, row = row2 } }
	#	firstLineNr	= y1     / lineHeight
	#	lastLineNr	= (y2-1) / lineHeight
	| (   row1 < firstLineNr && row2 < firstLineNr		// selection above...
		|| row1 > lastLineNr  && row2 > lastLineNr		// ...or below rectangle?
	   )
		= emptySelection
	# startVisible	= row1 >= firstLineNr && row1 <= lastLineNr
	#		endVisible		= row2 >= firstLineNr && row2 <= lastLineNr
	#		newCol1			= if startVisible col1 0
	#		newRow1			= if startVisible row1 firstLineNr
	#		newCol2			= if endVisible   col2 0
	#		newRow2			= if endVisible   row2 (lastLineNr+1)
	= { start = { col = newCol1, row = newRow1 }
	  		   , end   = { col = newCol2, row = newRow2 }
	  		   }
	 
selToRects :: Selection ViewFrame Text FontInfo -> [Rectangle]
selToRects selection frame text fontInfo=:{FontInfo | lineHeight}
	// get the first line of the selection and split it into the part to the left
	// of the selection start and the part to the right
	# { start={ col=col1, row=row1 }, end=end=:{ col=col2, row=row2 } }
								= orderSelection selection
	# (strings, _)				= getTextFragment {start={col=0,row=row1},end=end} text
	# firstString				= slHead strings
	# firstLeft					= firstString % (0, col1 - 1)
	# firstRight				= firstString % (col1, col2 - 1) 
	# firstY					= row1 * lineHeight
	# firstLeftWidth			= tabStringWidth 0 (splitAtTabs firstLeft) fontInfo
	| row1 == row2
		// selection within one line
		# firstRightWidth		= tabStringWidth firstLeftWidth (splitAtTabs firstRight) fontInfo
		=	[	{ corner1 = { x = firstLeftWidth, y = firstY }
				, corner2 = { x = firstLeftWidth + firstRightWidth, y = firstY + lineHeight }
				}
		  	]
	// selection contains more than one line
	# lastString				= slLast strings
	# lastLeft					= lastString % (0, col2 - 1)
	# lastY						= row2 * lineHeight
	# lastLeftWidth				= tabStringWidth 0 (splitAtTabs lastLeft) fontInfo
	# firstRect					=
			{ corner1 = {x = firstLeftWidth,			y = firstY}
			, corner2 = {x = frame.corner2.x,			y = firstY + lineHeight}
			}
	# middleRect				= 
			{ corner1 = {x = max frame.corner1.x 0,		y = firstY + lineHeight}
			, corner2 = {x = frame.corner2.x,			y = lastY}
			}
	# lastRect					=
			{ corner1 = {x = 0,							y = lastY}
			, corner2 = {x = lastLeftWidth,				y = lastY + lineHeight}
			}
	= [ firstRect, middleRect, lastRect ]

isCursorInRectangle :: !Point2 !Int !Rectangle -> Bool
isCursorInRectangle {x,y} height {corner1={x=x1,y=y1},corner2={x=x2,y=y2}}
  = not ( x < x1 || x >= x2 || y >= y2 || y + height <= y1 )  

