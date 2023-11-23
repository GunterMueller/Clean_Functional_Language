implementation module EdFind

import StdList, StdFunc, StdArray, StdEnum, StdString, StdBool
import StdRegExp
import EdText, StrictList
import EdSelection

//--

isFalse False = True
isFalse _ = False

//-- regexp replace interface
regexpLineReplace :: !Selection !Bool !Bool !Bool !Bool !String !String !String -> Maybe String
regexpLineReplace sel=:{start,end} backwards wraparound ignore_case match_words search replace line
	| isEmpty maybeREParserList = Nothing	// "no valid search pattern"
	| not (isEmpty restParsers)	= Nothing	// "pattern generates multiple parsers"
	| not (isEmpty restPattern)	= Nothing	// "pattern does not consume entire pattern"
	| start == end				= Nothing	// "nothing to replace"
	# markedString				= reline
	| isNothing markedString	= Nothing
	# findResult				= fromJust markedString
	# massagedResult			= massageResult findResult
	# (err,res)					= replaceOne_RE [c\\c<-:replace] massagedResult
	| isJust err				= Nothing
	= Just (toString (fromJust res))
where
	maybeREParserList = findParser [c\\c<-:search]

	((restPattern,reParser),restParsers) = split maybeREParserList
	where split [h:t] = (h,t)

	reline
		# t = reParser [c\\c<-:line]
		# t = map (\(_,c)->c) t		// ===> [markedstring,(start,fin)]
		= find t
	where
		find [] = Nothing
		find [(m,(s,f)):r]
			| s == start.col && f == end.col = Just m
			= Nothing

//-- regexp searching interface

regexpLineSearch :: !Selection !Bool !Bool !Bool !Bool !String !Text -> Maybe Selection
regexpLineSearch sel=:{start,end} backwards wraparound ignore_case match_words search text
	| isEmpty maybeREParserList = Nothing	// "no valid search pattern"
	| not (isEmpty restParsers)	= Nothing	// "pattern generates multiple parsers"
	| not (isEmpty restPattern)	= Nothing	// "pattern does not consume entire pattern"
	| start == end
		= singleLineSearch` True sel text
	= singleLineSearch` True {sel & end = {start & col = next start.col}} text
where
	maybeREParserList = findParser [c\\c<-:search]

	((restPattern,reParser),restParsers) = split maybeREParserList
	where split [h:t] = (h,t)

	inisel = start <> end

	stringlength = size search

	textlength = textLength text

	next
		| backwards = dec
		= inc

	singleLineSearch` ini {start,end=e=:{row,col}} text`
		# rl = reline
		| isNothing rl
			| row == start.row && ini == False
				= Nothing
			# row = next row
			| row >= textlength || row < 0
				| wraparound 
					| backwards
						= singleLineSearch` False {start=start,end={row=dec textlength,col=0}} text
					= singleLineSearch` False {start=start,end={row=0,col=0}} text
				= Nothing
			= singleLineSearch` False {start=start,end={row= row,col=0}} text
		# (scol,ecol) = fromJust rl
		| inisel && scol == start.col && start.row == row
			= Nothing
		= Just {start = {row=row, col = scol}, end = {row=row, col = ecol}}
	where
		(line,text) = getLine row text`
		col`
			| ini
				| backwards
					= (min (dec col) (size line - stringlength))
				= col
			| backwards
				= (size line - stringlength)
			= 0
		reline
			# t = reParser [c\\c<-:line]
			# t = map (\(_,(_,c))->c) t		// ===> [(start,fin)]
			//  find col in list t...
			| backwards
				= findb (reverse t)
			= findf t
		where
			findf [] = Nothing
			findf [(s,f):r]
				| s >= col` = Just (s,f)
				= findf r
			findb [] = Nothing
			findb [(s,f):r]
				| s <= col` = Just (s,f)
				= findb r

regexpLineSearch` :: !Selection !Bool !Bool !Bool !Bool !String !*{String} -> (!Maybe Selection,!*{String})
regexpLineSearch` sel=:{start,end} backwards wraparound ignore_case match_words search text`
	| isEmpty maybeREParserList = (Nothing,text)	// "no valid search pattern"
	| not (isEmpty restParsers)	= (Nothing,text)	// "pattern generates multiple parsers"
	| not (isEmpty restPattern)	= (Nothing,text)	// "pattern does not consume entire pattern"
	| start == end
		= singleLineSearch` True sel text
	= singleLineSearch` True {sel & end = {start & col = next start.col}} text
where
	maybeREParserList = findParser [c\\c<-:search]

	((restPattern,reParser),restParsers) = split maybeREParserList
	where split [h:t] = (h,t)

	inisel = start <> end

	stringlength = size search

	(textlength,text) = usize text`

	next
		| backwards = dec
		= inc

	singleLineSearch` ini {start,end=e=:{row,col}} text`
		# rl = reline
		| isNothing rl
			| row == start.row && ini == False
				= (Nothing,text)
			# row = next row
			| row >= textlength || row < 0
				| wraparound 
					| backwards
						= singleLineSearch` False {start=start,end={row=dec textlength,col=0}} text
					= singleLineSearch` False {start=start,end={row=0,col=0}} text
				= (Nothing,text)
			= singleLineSearch` False {start=start,end={row= row,col=0}} text
		# (scol,ecol) = fromJust rl
		| inisel && scol == start.col && start.row == row
			= (Nothing,text)
		= (Just {start = {row=row, col = scol}, end = {row=row, col = ecol}},text)
	where
		(line,text) = uselect text` row
		col`
			| ini
				| backwards
					= (min (dec col) (size line - stringlength))
				= col
			| backwards
				= (size line - stringlength)
			= 0
		reline
			# t = reParser [c\\c<-:line]
			# t = map (\(_,(_,c))->c) t		// ===> [(start,fin)]
			//  find col in list t...
			| backwards
				= findb (reverse t)
			= findf t
		where
			findf [] = Nothing
			findf [(s,f):r]
				| s >= col` = Just (s,f)
				= findf r
			findb [] = Nothing
			findb [(s,f):r]
				| s <= col` = Just (s,f)
				= findb r

//-- regular searching interface

simpleLineSearch :: !Selection !Bool !Bool !Bool !Bool !String !Text -> Maybe Selection
simpleLineSearch sel=:{start,end} backwards wraparound ignore_case match_words search text
	| start == end = singleLineSearch` True sel text
	= singleLineSearch` True {sel & end = {start & col = next start.col}} text
where
	inisel = start <> end
	stringlength = size search
	textlength = textLength text
	next
		| backwards = dec
		= inc
	singleLineSearch` ini {start,end=e=:{row,col}} text
		# (line,text) = getLine row text
		# col = if ini
					(if backwards (min (dec col) (size line - stringlength)) col)
					(if backwards (size line - stringlength) 0)
		# xxx = mcolumn col line
		| isNothing xxx
			| row == start.row && ini == False = Nothing
			# row = next row
			| row >= textlength || row < 0
				| wraparound 
					| backwards = singleLineSearch` False {start=start,end={row=dec textlength,col=0}} text
					= singleLineSearch` False {start=start,end={row=0,col=0}} text
				= Nothing
			= singleLineSearch` False {start=start,end={row= row,col=0}} text
		# col = fromJust xxx
		| inisel && col == start.col && start.row == row = Nothing
		= Just {start = {row=row, col = col}, end = {row=row, col = col + stringlength}}
	where
		mcolumn col line
			| ignore_case	= findIgnore` col
			= findInLine` col
		where
		    maxColumn	= size line - stringlength
		    firstChar	= search.[0]

		    findInLine` column
		      | (not backwards && column > maxColumn) || column < 0
		        = Nothing
		      | firstChar == line.[column]						// first char ok?
				| search == line % (column, column+stringlength-1)	// all chars ok?
				  | match_words
				  	| found_word (dec column) (column+stringlength) line 
				  	  = Just column
				  	= findInLine` (next column)
				  = Just column
				= findInLine` (next column)
			  = findInLine` (next column)

		    findIgnore` column
		      | (not backwards && column > maxColumn) || column < 0
		        = Nothing
		      | ignoreCaseEqChar firstChar line.[column]						// first char ok?
				| ignoreCaseEqString search (line % (column, column+stringlength-1))	// all chars ok?
				  | match_words
				  	| found_word (dec column) (column+stringlength) line 
				  	  = Just column 
				  	= findInLine` (next column)
				  = Just column
				= findIgnore` (next column )
			  = findIgnore` (next column)
			
simpleLineSearch` :: !Selection !Bool !Bool !Bool !Bool !String !*{String} -> (!Maybe Selection,!*{String})
simpleLineSearch` sel=:{start,end} backwards wraparound ignore_case match_words search text`
	| start == end = singleLineSearch` True sel text
	= singleLineSearch` True {sel & end = {start & col = next start.col}} text
where
	inisel = start <> end
	stringlength = size search
	(textlength,text) = usize text`
	next
		| backwards = dec
		= inc
	singleLineSearch` ini {start,end=e=:{row,col}} text
		# (line,text) = uselect text row
		# col = if ini
					(if backwards (min (dec col) (size line - stringlength)) col)
					(if backwards (size line - stringlength) 0)
		# xxx = mcolumn col line
		| isNothing xxx
			| row == start.row && ini == False = (Nothing,text)
			# row = next row
			| row >= textlength || row < 0
				| wraparound 
					| backwards = singleLineSearch` False {start=start,end={row=dec textlength,col=0}} text
					= singleLineSearch` False {start=start,end={row=0,col=0}} text
				= (Nothing,text)
			= singleLineSearch` False {start=start,end={row= row,col=0}} text
		# col = fromJust xxx
		| inisel && col == start.col && start.row == row = (Nothing,text)
		= (Just {start = {row=row, col = col}, end = {row=row, col = col + stringlength}},text)
	where
		mcolumn col line
			| ignore_case	= findIgnore` col
			= findInLine` col
		where
		    maxColumn	= size line - stringlength
		    firstChar	= search.[0]

		    findInLine` column
		      | (not backwards && column > maxColumn) || column < 0
		        = Nothing
		      | firstChar == line.[column]						// first char ok?
				| search == line % (column, column+stringlength-1)	// all chars ok?
				  | match_words
				  	| found_word (dec column) (column+stringlength) line 
				  	  = Just column
				  	= findInLine` (next column)
				  = Just column
				= findInLine` (next column)
			  = findInLine` (next column)

		    findIgnore` column
		      | (not backwards && column > maxColumn) || column < 0
		        = Nothing
		      | ignoreCaseEqChar firstChar line.[column]						// first char ok?
				| ignoreCaseEqString search (line % (column, column+stringlength-1))	// all chars ok?
				  | match_words
				  	| found_word (dec column) (column+stringlength) line 
				  	  = Just column 
				  	= findInLine` (next column)
				  = Just column
				= findIgnore` (next column )
			  = findIgnore` (next column)
			
ignoreCaseEqChar c1 c2 :== (toUpper c1) == (toUpper c2)
ignoreCaseEqString s1 s2 :== (size s1 == size s2) && ((isEmpty (filter (isFalse) [ignoreCaseEqChar c1 c2\\ c1 <-: s1 & c2 <-: s2])))

found_word before_index after_index string :==
	(		before_index<0
		|| not_both_ident_or_funny_chars (string.[before_index]) (string.[inc before_index])
	)
	&&
	(		after_index >= size string
		|| not_both_ident_or_funny_chars (string.[dec after_index]) (string.[after_index])
	)
where
		not_both_ident_or_funny_chars char1 char2
			| (IsFunnyChar char1 && IsFunnyChar char2) || (IsIdentChar char1 && IsIdentChar char2)
				= False
				= True

		IsFunnyChar c
			=	c == '~' || c == '@' || c == '#' || c == '$' || c == '%' || c == '^' || c == '?'  ||
				c == '!' || c == '+' || c == '-' || c == '*' || c == '<' || c == '>' || c == '\\' ||
				c == '/' || c == '|' || c == '&' || c == ':'
		
		IsIdentChar c
			= 'a' <= c && c <= 'z' || 'A' <= c && c <= 'Z' || '0' <= c && c <= '9' || c == '_' || c == '`'

/*
		IsReservedChar c
			= c == '(' || c == ')' || c == '{' || c == '}' || c == '[' || c == ']' || c == ';' || c == ',' || c == '.'
*/

//--

