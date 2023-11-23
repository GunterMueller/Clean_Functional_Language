implementation module EdMovement

import StdMisc, StdInt, StdTuple, StdArray, StdChar, StdBool, StdList, StdFunc
import StdIOCommon, StdPSt
import EdMonad, EdVisualText, EdSelection

:: Movement
	= LineUp
	| LineDown
	| CharLeft
	| CharRight
	| WordLeft
	| WordRight
	| PageUp
	| PageDown
	| StartOfLine
	| EndOfLine
	| StartOfText
	| EndOfText

instance == Movement where
  (==) LineUp		LineUp		= True
  (==) LineDown		LineDown	= True
  (==) CharLeft		CharLeft	= True
  (==) CharRight	CharRight	= True
  (==) WordLeft		WordLeft	= True
  (==) WordRight	WordRight	= True
  (==) PageUp		PageUp		= True
  (==) PageDown		PageDown	= True
  (==) StartOfLine	StartOfLine	= True
  (==) EndOfLine	EndOfLine	= True
  (==) StartOfText	StartOfText	= True
  (==) EndOfText	EndOfText	= True
  (==) _ 			_			= False

instance toString Movement where
  toString movement
    = case movement of
        LineUp		->	"previous line"
        LineDown	->	"next line"
        CharLeft	->	"previous character"
        CharRight	->	"next character"
        WordLeft	->	"previous word"
        WordRight	->	"next word"
        PageUp		->	"previous page"
        PageDown	->	"next page"
        StartOfLine	->	"start of line"
        EndOfLine	->	"end of line"
        StartOfText	->	"start of text"
        EndOfText	->	"end of text"
		_			->	"toString (EdMovement.icl): unknown movement"

instance fromString Movement
where
	fromString s = case s of
		"previous line"	-> LineUp
		"next line"		-> LineDown
        "previous character"	-> CharLeft
        "next character"-> CharRight
        "previous word"	-> WordLeft
        "next word"		-> WordRight
        "previous page"	-> PageUp
        "next page"		-> PageDown
        "start of line"	-> StartOfLine
        "end of line"	-> EndOfLine
        "start of text"	-> StartOfText
        "end of text"	-> EndOfText
        _ -> StartOfText	// silly default

positionAfterMove :: !Movement !Position -> EditMonad (PSt .l) Position
positionAfterMove movement position
  = fun position
  where
    fun = case movement of
		LineUp		->	lineUp
  		LineDown	->	lineDown
		CharLeft	->	charLeft
		CharRight	->	charRight
		WordLeft	->	wordLeft
		WordRight	->	wordRight
		PageUp		->	pageUp
		PageDown	->	pageDown
		StartOfLine	->	startOfLine
		EndOfLine	->	endOfLine
		StartOfText	->	startOfText
		EndOfText	->	endOfText
		_			->	abort "positionAfterArrow (EdAction.icl): unknown movement"
  
isVerticalMove :: !Movement -> Bool
isVerticalMove movement
  = isMember movement [ LineUp, LineDown, PageUp, PageDown ]
  
lineUp :: Position -> EditMonad (PSt .l) Position
lineUp position
  = verticalMove 0 (~1) position
  
lineDown :: Position -> EditMonad (PSt .l) Position
lineDown position
  = getText						>>>= \text ->
	verticalMove (textLength text - 1) 1 position
	
charLeft :: Position -> EditMonad (PSt .l) Position
charLeft {col, row}
  = getText					>>>= \text ->
	let previousLine = fst (getLine (row - 1) text) in
	IF (col == 0)
	THEN
	  ( 
		result (if (row == 0)
					 {col=col, row=row}					// stay at beginning of text
					 {col=size previousLine, row=row-1}	// go to end of previous line
			   )
	  )
	ELSE
	  (
		result { col=col-1, row=row} 					// one position to the left
	  )

charRight :: Position -> EditMonad (PSt .l) Position
charRight {col, row}
  = getText					>>>= \text ->
	let currentLine = fst (getLine row text) in
	IF (col == size currentLine)
	THEN
	  (
		result (if (row == textLength text - 1)
					 {col=col, row=row}					// stay at the end of the text
					 {col=0, row=row+1}					// go to beginning of the next line
			   )
	  )
	ELSE
	  (
		result {col=col+1, row=row}						// one position to the right
	  )

startOfText :: Position -> EditMonad .env Position
startOfText _
  = result {col=0,row=0}

endOfText :: Position -> EditMonad .env Position
endOfText _
  = getText											>>>= \text ->
	let lastLineNr		= textLength text - 1
		(lastLine, _)	= getLine lastLineNr text in
	result {col=size lastLine,row=lastLineNr}

startOfLine :: Position -> EditMonad .env Position
startOfLine {col,row}
  = result {col=0,row=row}

endOfLine :: Position -> EditMonad .env Position
endOfLine {col,row}
  = getText											>>>= \text ->
	let (textLine, _) = getLine row text in
	result {col=size textLine,row=row}

wordLeft :: Position -> EditMonad .env Position
wordLeft position=:{col, row}
  = getText											>>>= \text ->
	let previousLine = fst (getLine (row - 1) text) in
    IF (col == 0)
	THEN 
	  (
		result (if (row == 0)	position
								{col=size previousLine,row=row-1} )
	  )
	ELSE
	  ( 
		selectWordAt position						>>>= \selection ->
		result selection.start
	  )

wordRight :: Position -> EditMonad .env Position
wordRight position=:{col, row} =
	getText											>>>= \text ->
	let currentLine = fst (getLine row text) in
    IF (col == size currentLine)
	THEN 
	  (
		result (if (row == textLength text - 1)
					position
					{col=0,row=row+1} )
	  )
	ELSE
	  ( 
		selectWordAt {col=col+1, row=row}			>>>= \selection ->
		result selection.end
	  )

// returns the selection that contains the word the cursor is
// currently on

selectWordAt :: !Position -> EditMonad .env Selection 
selectWordAt {col, row}
  = IF (col == 0)
	THEN
	  ( result {start={col=0,row=row},end={col=0,row=row}} )
	ELSE
	  (
		getText										>>>= \text ->
		let col`				= col - 1
 			(line, _)			= getLine row text
 			char				= line.[col`]
	 		isCorrectChar		=
	 			if (isWordChar char) isWordChar
	 			(if (isFunnyChar char) isFunnyChar
	 			(if (isWhiteSpace char) isWhiteSpace
	 			(otherChar char)))
			(leftCol, rightCol)	= findWord isCorrectChar col` line
		in
	 	result	{ start	= { col = leftCol,	row = row }
	 			, end	= { col = rightCol,	row = row }
	 			}
	  )

findWord :: (Char -> Bool) ColumnNr String -> (ColumnNr, ColumnNr)
findWord isCorrectChar column line
  = (findLeft column, findRight column)
  where
    findLeft column
      | column < 0
        = 0
      | isCorrectChar line.[column]
        = findLeft (column-1)
        = column + 1
    findRight column
      | column >= size line
        = size line
      | isCorrectChar line.[column]
        = findRight (column+1)
        = column

isWordChar c	= isAlpha c || isDigit c || isMember c ['`_']
isFunnyChar c	= isMember c ['~@#$%^?!+-*<>\\/|&=:.']
isWhiteSpace c	= isMember c [' \t\r\n\f\b']
otherChar c		= (==) c

pageUp :: Position -> EditMonad (PSt .l) Position
pageUp position=:{col,row} =
	getViewFrame			>>>= \frame ->
	getFontInfo				>>>= \{lineHeight} ->
	let	rowsInFrame	= (frame.corner2.y - frame.corner1.y) / lineHeight - 1	// one page
		topRow		= (frame.corner1.y) / lineHeight						// top row
		rowChange	= if (row < rowsInFrame)
						(~row)
						(if (topRow < rowsInFrame)
							(~topRow)
							(~rowsInFrame)
						)
	in
	verticalMove 0 rowChange position

pageDown :: Position -> EditMonad (PSt .l) Position
pageDown position=:{col,row} =
	getViewFrame			>>>= \frame ->
	getFontInfo				>>>= \fontInfo=:{lineHeight} ->
	getText					>>>= \text ->
	let	botRow		= (frame.corner2.y - 1) / lineHeight
		lastLineNr`	= (lastLineNr text)
		lastRow		= max lastLineNr` botRow	// normalise now that we can resize window larger than text...
		rowsInFrame	= (frame.corner2.y - frame.corner1.y) / lineHeight - 1	// one page
		rowChange	= if (row > lastRow - rowsInFrame)
						(lastRow - row)
						(if (botRow > lastRow - rowsInFrame)
							(lastRow - botRow)
							(rowsInFrame)
						)
	in
	getVirtualX						>>>= \virtualX ->
	IF (row == lastLineNr`)
	THEN	// if end of text reached, reset virtual x
	  ( 
		setVirtualX 0				>>>	// when scrolling down you really want to end up at the end of the line...
		result position
	  )
	ELSE	// otherwise, go up or down rowChange lines
	  ( 
		let
			newRow					= min lastLineNr` (rowChange + row)
			// determine where the cursor currently is and set the virtual x
			// to that value, unless it is already set
			(newVirtualX,newCol)	= picfun newRow virtualX position text fontInfo
		in
		setVirtualX newVirtualX						>>>	
		result {col=newCol, row=newRow}
	  )
where
	picfun newRow virtualX position text fontInfo=:{lineHeight}
		# point			= positionToPoint position text fontInfo
		# newVirtualX	= if (virtualX == 0) point.x virtualX
		# virtualPoint	= {x = newVirtualX, y = newRow * lineHeight}
		# {col=newCol} = pointToPosition virtualPoint text fontInfo
		= (newVirtualX,newCol)
		
verticalMove :: Int Int Position -> EditMonad (PSt .l) Position
verticalMove endReached rowChange position=:{col, row} =
	getFontInfo						>>>= \fontInfo=:{lineHeight} ->
	getVirtualX						>>>= \virtualX ->
	getText							>>>= \text ->
	IF (row == endReached)
	THEN	// if end of text reached, reset virtual x
	  ( 
		setVirtualX 0				>>>	// when scrolling down you really want to end up at the end of the line...
		result position
	  )
	ELSE	// otherwise, go up or down rowChange lines
	  ( 
		let
			newRow					= (rowChange + row)
			// determine where the cursor currently is and set the virtual x
			// to that value, unless it is already set
			(newVirtualX,newCol)	= picfun newRow virtualX position text fontInfo
		in
		setVirtualX newVirtualX						>>>	
		result {col=newCol, row=newRow}
	  )
where
	picfun newRow virtualX position text fontInfo=:{lineHeight}
		# point					= positionToPoint position text fontInfo
		# newVirtualX			= if (virtualX == 0) point.x virtualX
		# virtualPoint			= {x = newVirtualX, y = newRow * lineHeight}
		# {col=newCol}			= pointToPosition virtualPoint text fontInfo
		= (newVirtualX,newCol)

allMovements :: [Movement]
allMovements  
  = [ LineUp, LineDown, CharLeft, CharRight
	, WordLeft, WordRight, PageUp, PageDown
	, StartOfLine, EndOfLine, StartOfText, EndOfText
	]
