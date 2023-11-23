implementation module EdLineText

// a type for dealing with line-oriented operations on texts

import	StdString, StdClass, StdInt, StdList, StdBool, StdFunc, StdArray, StdTuple
import	StrictList
from	EdPosition	import :: LineNr
import	syncol
import	Platform

//import dodebug
trace_n` _ f :== f

//-- stuff we want to parametrise...
/*
class TextAnnot a // b
where
	dummyLineAnnot	:: !a
	annotLine		:: !.{#Char} -> (!a,!.{#Char})
	annotWhole		:: !(StrictList {#Char}) -> (Int, StrictList (a,{#Char}))
	annotPart		:: !Int !Int !(StrictList (a,{#Char})) -> (Int,StrictList (a,{#Char}))
//	annotText		:: b

export TextAnnot Void, SyncInf, ConsInf
*/

:: LineAnnot	:== Info
dummyLineAnnot	:== {comment_level=0,is_typedef=False,is_typedecl=False,offside_level=0,flush=False}
annotLine		:== slMap (\s->(dummyLineAnnot,s))
annotWhole		:== firstParse
annotPart		:== quickParse
annotText		:== id

/*===>
annotDummy	:== 0
annotWhole	:== ...
annotPart	:== ...
*/

//-- ...stuff

:: Text
	= { nrLines :: Int
	  , blocks  :: [StrictList (!LineAnnot,!String)]
	  }
   
BlockSize :== 80

:: TextFragment 
	:== StrictList String

newText :: Text
newText
  # new			= SCons "" SNil
  # new			= annotLine new
  = { nrLines	= 1
    , blocks	= [ new ]
    }

emptyText :: Text
emptyText =
	{ nrLines	= 0
	, blocks	= [ SNil ]
	}

textToStrings :: !Text -> StrictList String
textToStrings { blocks }
  = blocksToStrings blocks

textToStringsC :: !Text -> StrictList (Info,String)
textToStringsC { blocks }
  = blocksToStringsC blocks

stringsToText :: (StrictList String) -> Text
stringsToText lines
  # lines		= annotWhole lines
  = { nrLines	= slLength lines
    , blocks	= group BlockSize lines
    }

stringsToString :: !(StrictList String) -> String
/*
stringsToString SNil					= ""
stringsToString (SCons string SNil)		= string
stringsToString (SCons string strings)	= string +++. "\n" +++. stringsToString strings
*/
stringsToString ss
	# s = createArray (sSize ss) '\xd'
	= sUpdate 0 s ss
where
	sizeNewline
		= PlatformDependant
			2	// silly DOS
			1	// mac
	newline
		= PlatformDependant
			"\xd\xa"				// windows
			"\xd"					// mac
	
	sSize SNil = 0
	sSize (SCons string SNil) = size string
	sSize (SCons string rest) = size string + sizeNewline + sSize rest
	
	sUpdate :: !Int !*String !(StrictList String) -> *String
	sUpdate i s SNil = s
	sUpdate i s (SCons string SNil)
		# (_,s) = sU (size string) i 0 s string
		= s
	sUpdate i s (SCons string rest)
		# (i,s) = sU (size string) i 0 s string
		# (i,s) = sU sizeNewline i 0 s newline
		= sUpdate i s rest
	
	sU l i j s h
		| j >= l = (i,s)
		# s = update s i h.[j]
		= sU l (inc i) (inc j) s h

stringToStrings :: !String -> StrictList String
stringToStrings string
  = stringToStrings` 0 string 0
where
	stringToStrings` i string start
		# stringsize	= size string
		| i >= stringsize
			= SCons  (string % (start, dec stringsize)) SNil
		# lastchar = string.[i]
		| lastchar == '\xa'
			= SCons	(string % (start, i - 1)) (stringToStrings` (i+1) string (i+1))
		| lastchar == '\xd'
			# haslookahead	= i < dec stringsize
			| haslookahead && (string.[i+1] == '\xa')
				= SCons (string % (start, i - 1)) (stringToStrings` (i+2) string (i+2))
			= SCons (string % (start, i - 1)) (stringToStrings` (i+1) string (i+1))
		= stringToStrings` (i+1) string start
	
StringToText s
	:== stringsToText (stringToStrings s)

blockToStrings :: !(StrictList (Info,String)) -> StrictList String
blockToStrings block = slMap snd block

blocksToStrings :: ![StrictList (Info,String)] -> StrictList String
blocksToStrings [] = SNil
blocksToStrings [block:blocks]
  = slAppend (blockToStrings block) (blocksToStrings blocks)

blocksToStringsC :: ![StrictList (Info,String)] -> StrictList (Info,String)
blocksToStringsC [] = SNil
blocksToStringsC [block:blocks]
  = slAppend block (blocksToStringsC blocks)

group :: Int !(StrictList a) -> [(StrictList a)]
group _ SNil	= []
group n xs		= [ ys : group n zs ]
where
	(ys, zs) = slSplitAt n xs 

textLength :: !Text -> Int
textLength { nrLines, blocks } = nrLines

lastLineNr :: !Text -> LineNr
lastLineNr text
  = textLength text - 1
  
validateLineNr :: !LineNr Text -> LineNr
validateLineNr lineNr text
  | lineNr < 0
	= 0
  | lineNr > lastNr
	= lastNr
	= lineNr
where
	lastNr = lastLineNr text

getLine :: !LineNr !u:Text -> (!String, !u:Text)
getLine linenr text=:{nrLines, blocks}
  # (_,line) = slIndex lineNr` theBlock
  = ( line, text)
where
	nrLines` = dec nrLines
	lineNr | linenr > nrLines` = nrLines`
		= linenr
	lineNr`	 = lineNr - nrSkip * BlockSize
	nrSkip	 = lineNr / BlockSize
	theBlock = blocks!!nrSkip
	
getLineC :: !LineNr !u:Text -> ((!Info,!String), !u:Text)
getLineC linenr text=:{nrLines, blocks}
  # line = slIndex lineNr` theBlock
  = ( line, text)
where
	nrLines` = dec nrLines
	lineNr | linenr > nrLines` = nrLines`
		= linenr
	lineNr`	 = lineNr - nrSkip * BlockSize
	nrSkip	 = lineNr / BlockSize
	theBlock = blocks!!nrSkip
	
// getBlocks returns only the blocks that contain the text range
// denotes by the line numbers. It also returns the number of
// the first block

getBlocks :: !LineNr !LineNr !Text -> (!Int, ![StrictList (Info,String)])
getBlocks first last { blocks }
  = ( nrSkip
	, blocks%(nrSkip,nrTake)
	)
where
	nrSkip = first / BlockSize
	nrTake = last / BlockSize + 1
  
getLines :: !LineNr !LineNr !Text -> (!StrictList String, !Text)
getLines first last text
  = ( slTake (last - first + 1) 
			 (slDrop first` (blocksToStrings blocks))
	, text
	)
where
	(firstBlockNr, blocks) = getBlocks first last text
	first` = first - firstBlockNr * BlockSize
	
getLinesC :: LineNr LineNr Text -> (StrictList (Info,String), Text)
getLinesC first last text
  # lines		= textToStringsC text
  # lines		= slTake (last - first + 1) (slDrop first lines)
  = ( lines
	, text
	)
	
removeLine :: !LineNr !Text -> Text
removeLine lineNr text
  = removeLines lineNr lineNr text
 
removeLines :: !LineNr !LineNr !Text -> Text
removeLines first last text=:{ nrLines, blocks }
	| first == 0 && last == lastLineNr text
		= newText
	# nrRemoveLines		= last - first + 1
	# lines				= textToStringsC text
	# (before,after)	= slSplitAt first lines
	# after				= slDrop nrRemoveLines after
	#! lines			= slAppend before after
	# (_,_,lines)		= annotPart (dec first) (dec first) lines
	= {blocks = group BlockSize lines, nrLines = nrLines - nrRemoveLines}

insertLines :: !LineNr !(StrictList String) !Text -> Text
insertLines lineNr strings text=:{ nrLines, blocks }
	# nrInsertLines		= slLength strings
	# lines				= textToStringsC text
	# (before,after)	= slSplitAt lineNr lines
	# strings			= annotLine strings
	#! after			= slAppend strings after
	#! lines			= slAppend before after
	# (_,_,lines)		= annotPart (dec lineNr) (lineNr + nrInsertLines) lines
	= {blocks = group BlockSize lines, nrLines = nrLines + nrInsertLines}
	
appendLines :: !(StrictList String) !Text -> Text
appendLines strings text=:{ nrLines, blocks }
	# nrAppendLines		= slLength strings
	# before			= textToStringsC text
	# after				= annotLine strings
	#! lines			= slAppend before after
	# (_,_,lines)		= annotPart (dec nrLines) (nrLines + nrAppendLines) lines
	= {blocks = group BlockSize lines, nrLines = nrLines + nrAppendLines}
	
appendLines` :: !(StrictList String) !Text -> Text
appendLines` strings text=:{ nrLines, blocks }
	# (string,strings) = case strings of
		SNil -> ("",SNil)
		(SCons s ss) -> (s,ss)
	# nrAppendLines		= slLength strings
	# before			= textToStringsC text
	# (before,update)	= slSplitAt (dec nrLines) before
	# after				= annotLine strings
	# update = case slHead update of
		(pl,st) -> (pl,st+++.string)
	#! lines			= slAppend before (SCons update after)
	# (_,_,lines)		= annotPart (dec nrLines) (nrLines + nrAppendLines) lines
	= {blocks = group BlockSize lines, nrLines = nrLines + nrAppendLines}
	
updateLine :: !LineNr !String !.Text -> (!Int,!Int,!.Text)
updateLine lineNr string text=:{ nrLines, blocks }
	# lines				= textToStringsC text
	# (before,after)	= slSplitAt lineNr lines
	# (pl,_)			= slHead after
	# after				= SCons (pl,string) (slTail after)
	#! lines			= slAppend before after
	# (st,fin,lines)	= annotPart lineNr lineNr lines
	= trace_n` ("updateLine",st,fin) (st,fin,{blocks = group BlockSize lines, nrLines = nrLines})
