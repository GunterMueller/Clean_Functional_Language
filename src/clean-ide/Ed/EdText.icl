implementation module EdText

// operations on text areas (extends EdLineText)

import StdClass, StdArray, StdMisc, StdInt, StdString, StdMaybe
import EdLineText, EdSelection
import StrictList

getTextFragment :: !Selection !Text -> (!TextFragment, !Text)
getTextFragment {start={col=col1,row=row1},end={col=col2,row=row2}} text
  // selection is within one line ?
  | row1 == row2 
	# (line, text) = getLine row1 text
	= ( SCons (line % (col1, col2 - 1)) SNil
	  , text
	  )
  // selection contains more than one line
  # (SCons firstLine restLines, text) 
				= getLines row1 row2 text
  = ( SCons (firstLine % (col1, size firstLine - 1)) 
		   (chopLastLine restLines)
	, text
	)
where
	chopLastLine SNil 
	  = SNil
	chopLastLine (SCons lastLine SNil)
	  = SCons (lastLine % (0, col2 - 1)) SNil
	chopLastLine (SCons aLine lines)
	  = SCons aLine (chopLastLine lines)

removeText :: !Selection !Text -> (Maybe (Int,Int),Text)
removeText {start={col=col1,row=row1},end={col=col2,row=row2}} text
  # (firstLine, text)	= getLine row1 text
  // selection within one line?
  | row1 == row2 
	# (st,fin,text)		= updateLine row1 
							(	firstLine % (0, col1 - 1) 
							+++ firstLine % (col2, size firstLine - 1)
							) text
	= (Just (st,fin),text)
  // selection contains more than one line
  # (lastLine, text)	= getLine row2 text
  # newLine				= firstLine % (0, col1 - 1) +++ 
						  lastLine	% (col2, size lastLine - 1)
  # (_,_,text)			= updateLine row1 newLine text
  # text				= removeLines (row1 + 1) row2 text
  = (Nothing,text)

insertText :: !Position !TextFragment !Text -> (Maybe (Int,Int),Text)
insertText { col, row } strings text
  # (line, text) = getLine row text
	left  = line % (0, col - 1)
	right = line % (col, size line - 1)
  // no strings at all
  | nrOfStrings == 0
	= (Nothing,text)
  // insertion in a single line
  | nrOfStrings == 1
	# newLine = left +++ slHead strings +++ right
	# (st,fin,text) = updateLine row newLine text
	= (Just (st,fin),text)
  // insertion of more than one line
  # fragment
	  = SCons
	  		(left +++ slHead strings)
			(appendToLastLine (slTail strings) right)
  // use this order to avoid trouble with removeLine applied to newText...
  # text = insertLines (inc row) fragment text
  # text = removeLine row text
  = (Nothing,text )
where
	nrOfStrings = slLength strings

replaceText :: !Selection !TextFragment !Text -> Text
replaceText sel=:{start={col=col1,row=row1},end={col=col2,row=row2}} strings text
	# (firstLine, text)	= getLine row1 text
	# (lastLine, text)	= if (row1==row2)
							(firstLine,text)
							(getLine row2 text)
	# left = firstLine%(0, col1 - 1)
	# right = lastLine%(col2, size lastLine - 1)
	# text				= if (row1 == row2)
							text
							(removeLines (row1 + 1) row2 text)
	// no strings at all
	| nrOfStrings == 0
		# newLine			= left +++ right
		# (_,_,text)		= updateLine row1 newLine text
		= text
	// insertion in a single line
	| nrOfStrings == 1
		# newLine			= left +++ slHead strings +++ right
		# (_,_,text)		= updateLine row1 newLine text
		= text
	// insertion of more than one line
	# fragment = SCons
	  		(left +++ slHead strings)
			(appendToLastLine (slTail strings) right)
	// use this order to avoid trouble with removeLine applied to newText...
	# text = insertLines (inc row1) fragment text
	# text = removeLine row1 text
	= text
where
	nrOfStrings = slLength strings

appendText :: !TextFragment !Text -> Text
appendText SNil text
	= text
appendText strings text
	# text = appendLines` strings text
	= text

appendToLastLine :: .(StrictList String) String -> .StrictList String
appendToLastLine (SCons string SNil) right
  = SCons (string +++ right) SNil
appendToLastLine (SCons string strings) right
  = SCons string (appendToLastLine strings right)
appendToLastLine SNil right
  = SCons right SNil
