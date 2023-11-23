implementation module EdTab

/*
 * EdTab.icl: functions that deal with those annoying tab characters
 
 o Unfortunately doesn't work with proportional fonts...
   Probably inevitable with an 'editor' view of tabs.
 */

import StdArray, StdBool, StdClass, StdEnum, StdList
import StdIOCommon, StdPicture, StdPSt
import EdMonad

splitAtTabs :: !String -> .[String]
splitAtTabs string
  = splitAtTabs` 0 0
where
	maxIndex = size string - 1

	splitAtTabs` startIndex currentIndex
		| currentIndex > maxIndex					// has the end been reached?
			= [ string % (startIndex, maxIndex) ]
		# newIndex = currentIndex + 1
		| string.[currentIndex] == '\t'				// is the current character a tab character?
			= [ string % (startIndex, currentIndex - 1)
			  : splitAtTabs` newIndex newIndex
			  ]
		// no, it's a normal character
		= splitAtTabs` startIndex newIndex

tabDrawString :: !Point2 !String !FontInfo !*Picture -> *Picture
tabDrawString point string {thefont, showTabs,tabSize,charWidth} picture
	#! strings = splitAtTabs string
	= tabDrawString` point strings picture
where
		  
	tabDrawString` :: Point2 [String] !*Picture -> *Picture
	
	tabDrawString` _ [] picture
	  = picture

	tabDrawString` point [ string : [] ] picture
	  # picture					 = setPenPos point picture
	  # picture					 = draw string picture
	  = picture
	  
	tabDrawString` point [ string : strings ] picture
		# picture					 = setPenPos point picture
		# picture					 = draw string picture
		  (newPoint,picture)		 = getPenPos picture
		  newX					 = alignAtTab` newPoint.x tabSize charWidth
		| not showTabs
		 	= tabDrawString` { point & x = newX } strings picture
		# picture					 = setPenColour Red picture
		  picture					 = draw '~' picture
		  picture					 = setPenColour Black picture
		= tabDrawString` { point & x = newX } strings picture

:: CommentLevel
	= N Int	// normal comment nesting level
	| L		// comment till end of line...
	| S 	// in string constant...
	| C		// in char constant...
	
import ospicture				// for optimized drawfuns...
optDrawS :== pictdrawstring		// use non-optimised versions
optDrawC :== pictdrawchar		// "

tabDrawStringC :: !Point2 !(!Int,!String) !FontInfo !*Picture -> *Picture
tabDrawStringC point (clevel,string)
	{tabSize,charWidth,thefont, showTabs, syntaxColours={textColour, backgroundColour,tabColour, commentColour, stringColour, charColour, keywordColour}}
	picture
	#! strings = splitAtTabs string
	= tabDrawString` (N clevel) point strings picture
where
		  
	tabDrawString` :: !CommentLevel !Point2 !.[String] !*Picture -> !*Picture
	// hmm, moeten wel/niet kolom 0 naar local funs zien te krijgen...
	tabDrawString` _ _ [] picture
//		#! (_,picture)		 = optGetPenPos picture
		= picture

	tabDrawString` clevel point [string : []] picture
//		#! (_,picture)		 = optGetPenPos picture
		#! picture					 = setPenPos point picture
		#! (_,picture)				 = drawC clevel string picture
//		#! (_,picture)		 = optGetPenPos picture
		= picture
	  
	tabDrawString` clevel point [string : strings] picture
//		#! (_,picture)		 = optGetPenPos picture
		#! picture					 = setPenPos point picture
		#! (clevel,picture)			 = drawC clevel string picture
//		#! (newPoint,picture)		 = optGetPenPos picture
		#! (newPoint,picture)		 = getPenPos picture
		#! newX						 = alignAtTab` newPoint.x tabSize charWidth
		| not showTabs
		 	= tabDrawString` clevel {point & x = newX} strings picture
		#! picture					 = setPenColour tabColour picture
		#! picture					 = optDrawC '~' picture
		#! picture					 = setPenColour textColour picture
		= tabDrawString` clevel {point & x = newX} strings picture
	
	
	
	drawC :: !.CommentLevel !.String !*Picture -> !(!.CommentLevel,!*Picture)
	drawC c s pic
		= drawC c pic
	where
		drawC :: !.CommentLevel !*Picture -> !(!.CommentLevel,!*Picture)
		drawC S pic	// string literal
			# pic = setPenColour stringColour pic
			= dS 0 pic
		drawC C pic	// char literal
			# pic = setPenColour charColour pic
			= dC 0 pic
		drawC L pic	// line comment
			# pic = setPenColour commentColour pic
			# pic = optDrawS s pic
			= (L,pic)
		drawC (N cl) pic	// normal
			# pic = (if (cl==0) (setPenColour textColour) (setPenColour commentColour)) pic
			= dL cl 0 pic

		l = size s
		funnyChar i = isStringMember s.[i] (dec funnySize) funnyChars

		//isStringMember:: a !.[a] -> .Bool | Eq a
		isStringMember x 0 s = False
		isStringMember x i s = s.[i] == x || isStringMember x (dec i) s

		funnyChars =: "~@#$%^?!+-*<>\\/|&=:."
		funnySize = 20

		dL :: !.Int !.Int !*Picture -> !(!.CommentLevel,!*Picture)
		dL cl i pic
			| i >= l
				= (N cl,pic)
			| s.[i] == '*'
				# i = inc i
				| i >= l
					# pic = optDrawC '*' pic
					= (N cl,pic)
				| s.[i] == '/'
					// moet nog proofer controleren of verder gaat als funny id...
					# i = inc i
					| cl <> 0
						# pic = setPenColour commentColour pic // idiot proof voor trickery aan begin van bestand...
						# pic = optDrawS "*/" pic
	//					# pic = draw '/' pic
						# cl = dec cl
						| cl == 0
							# pic = setPenColour textColour pic
							= dL cl i pic
						= dL cl i pic
						
					| i < l && funnyChar i
						// eat till end of funnyid substring...
						# j = scanfunny i
						# r = s%(i,dec j)
						# pic = optDrawS "*/" pic
	//					# pic = draw '/' pic
						# pic = optDrawS r pic
						= dL cl j pic
					# pic = setPenColour commentColour pic // idiot proof voor trickery aan begin van bestand...
					# pic = optDrawS "*/" pic
	//				# pic = draw '/' pic
					# cl = dec cl
					| cl == 0
						# pic = setPenColour textColour pic
						= dL cl i pic
					= dL cl i pic
				# pic = optDrawC '*' pic
				= dL cl i pic
			| s.[i] == '/'
/*				| (i-1 >= 0) && (funnyChar (i-1))
					// eat till end of funnyid substring...
					# j = scanfunny i
					# r = s%(i,dec j)
				//	# pic = draw '/' pic
					# pic = draw r pic
					= dL cl j pic
//					# pic = draw '/' pic
//					= dL cl (inc i) pic
*/
				# i = inc i
				| i >= l
					# pic = optDrawC '/' pic
					= (N cl,pic)
				| s.[i] == '/'
					# pic = setPenColour commentColour pic
					# pic = optDrawS "//" pic
	//				# pic = draw '/' pic
					# r = s%(inc i,l)
					# pic = optDrawS r pic
					= (L,pic)
				| s.[i] == '*'
					# pic = setPenColour commentColour pic
					# pic = optDrawS "/*" pic
	//				# pic = draw '*' pic
					= dL (inc cl) (inc i) pic
				# pic = optDrawC '/' pic
				= dL cl i pic
/*
			| s.[i] == '\\'
				# pic = draw '\\' pic
				# i = inc i
				| i >= l
					= (N cl,pic)
				# pic = draw s.[i] pic	// moet hier doorlezen tot einde van ding. Gaat nu mis met \win enzo
				= dL cl (inc i) pic
*/
			| (s.[i] == '"') && (cl == 0)
				# pic = setPenColour stringColour pic
				# pic = optDrawC '"' pic
				= dS (inc i) pic
			| (s.[i] == '\'') && (cl == 0)
				# pic = setPenColour charColour pic
				# pic = optDrawC '\'' pic
				= dC (inc i) pic
			| (cl == 0) && (funnyChar i)
				# j = scanfunny i
				# r = s%(i,dec j)
				# pic = optDrawS r pic
				= dL cl j pic
			// hier keyword filtering pogen... ???
			// neen hier vang je ook keyword suffixes...
			// zou evt nog moeten lukken, komt nl eerst prefix tegen...
//			/*
			// scan chars tot whitespace, matchen met keywords...
			# (key,j) = scankeyword s i
			| key && cl == 0
				# r = s%(i,dec j)
				# (c,pic) = getPenColour pic
				# pic = setPenColour keywordColour pic
				# pic = optDrawS r pic
				# pic = setPenColour c pic
				= dL cl j pic
			# r = s%(i,dec j)
			# pic = optDrawS r pic
			= dL cl j pic
//			*/
			/*
			# pic = draw s.[i] pic
			= dL cl (inc i) pic
			*/
		where
			scankeyword :: !.String !Int -> !(!Bool,!Int)
			scankeyword s i
				# c = s.[i]
				| not (isAlpha c)
					// lees zoveel nonalpha's als mogelijk? nee.. gaat mis met comments...
					# j = inc i//scannonalpha (inc i)
					= (False,j)
				// lees zoveel alpha's als mogelijk (lazy!)
				# j = scanalpha (inc i)
				| c == 'f'	// from
					| (j == i+4) && (s%(i,i+3)=="from") = (True,j)
					= (False,j)
				| c == 'd'	// definition
					| (j == i+10) && (s%(i,i+9)=="definition") = (True,j)
					| (j == i+7) && (s%(i,i+6)=="default") = (True,j)			// eigenlijk alleen in typedef
					= (False,j)
				| c == 'i'	// implementation, import, if, in, infix, infixl, infixr, instance
					| (j == i+14) && (s%(i,i+13)=="implementation") = (True,j)
					| (j == i+8) && (s%(i,i+7)=="instance") = (True,j)			// eigenlijk alleen in typedef
					| (j == i+6) && (s%(i,i+5)=="import") = (True,j)
					| (j == i+6) && (s%(i,i+5)=="infixl") = (True,j)
					| (j == i+6) && (s%(i,i+5)=="infixr") = (True,j)
					| (j == i+5) && (s%(i,i+4)=="infix") = (True,j)
					| (j == i+2) && (s%(i,i+1)=="if") = (True,j)
					| (j == i+2) && (s%(i,i+1)=="in") = (True,j)
					= (False,j)
				| c == 'e'	// export
					| (j == i+6) && (s%(i,i+5)=="export") = (True,j)
					= (False,j)
				| c == 'm'	// module
					| (j == i+6) && (s%(i,i+5)=="module") = (True,j)
					= (False,j)
				| c == 's'	// system
					| (j == i+6) && (s%(i,i+5)=="system") = (True,j)
					= (False,j)
				| c == 'c'	// case, code, class
					| (j == i+5) && (s%(i,i+4)=="class") = (True,j)
					| (j == i+4)
						| (s%(i,i+3)=="case") = (True,j)
						| (s%(i,i+3)=="code") = (True,j)
						= (False,j)
					= (False,j)
				| c == 'l'	// let, let!
					| (j == i+4) && (s%(i,i+3)=="let!") = (True,j)				// werkt niet!
					| (j == i+3) && (s%(i,i+2)=="let") = (True,j)
					= (False,j)
				| c == 'o'	// of
					| (j == i+2) && (s%(i,i+1)=="of") = (True,j)
					= (False,j)
				| c == 'w'	// where, with
					| (j == i+4) && (s%(i,i+3)=="with") = (True,j)
					| (j == i+5) && (s%(i,i+4)=="where") = (True,j)
					= (False,j)
/*				| c == 'B'	// bool
					| (j == i+4) && (s%(i,i+3)=="Bool") = (True,j)
					= (False,j)
				| c == 'C'	// char
					| (j == i+4) && (s%(i,i+3)=="Char") = (True,j)
					= (False,j)
				| c == 'I'	// int
					| (j == i+3) && (s%(i,i+2)=="Int") = (True,j)
					= (False,j)
*/
				= (False,j)
			scanalpha i
				| i >= l = l
				# c = s.[i]
				| isAlphanum c = scanalpha (inc i)
//				| isDigit c = scanalpha (inc i)
				| c == '_' = scanalpha (inc i)
				| c == '`' = scanalpha (inc i)
				= i
/*
			scannonalpha
				| i >= l = l
				| isAlpha s.[i] = i
				= scannonalpha (inc i)
*/
			scanfunny i
				| i >= l = l
				| funnyChar i = scanfunny (inc i)
				= i
			
		dS :: !Int !*Picture -> !(!.CommentLevel,!*Picture)
		dS i pic
			| i >= l
				= (S,pic)
			| s.[i] == '"'
				# pic = optDrawC '"' pic
				# pic = setPenColour textColour pic
				= dL 0 (inc i) pic
			| s.[i] == '\\'
				# pic = optDrawC '\\' pic
				# i = inc i
				| i >= l
					= (S,pic)
				# pic = optDrawC s.[i] pic
				= dS (inc i) pic
			# pic = optDrawC s.[i] pic
			= dS (inc i) pic
		dC :: !Int !*Picture -> !(!.CommentLevel,!*Picture)
		dC i pic
			| i >= l
				= (C,pic)
			| s.[i] == '\''
				# pic = optDrawC '\'' pic
				# pic = setPenColour textColour pic
				= dL 0 (inc i) pic
			| s.[i] == '\\'
				# pic = optDrawC '\\' pic
				# i = inc i
				| i >= l
					= (C,pic)
				# pic = optDrawC s.[i] pic
				= dC (inc i) pic
			# pic = optDrawC s.[i] pic
			= dC (inc i) pic
	  
tabStringWidth :: !Int ![String] !FontInfo -> Int
tabStringWidth startX strings {tabSize, charWidth}
	# widths = map width strings
	= (virtualDraw widths startX) - startX
where
	width s = (size s) * charWidth

	virtualDraw []		_ = 0
	virtualDraw [w]		x = x + w
	virtualDraw [w:ws]	x = virtualDraw ws (alignAtTab` (x+w) tabSize charWidth)

alignAtTab` x tabSize charWidth
	| tabSize <= 0 = x + charWidth	// sensible result for silly value
	= hd [j \\ j <- [0,tabSize*charWidth..] | j > x]	// fix this with immediate calculation...

tabTake :: !Int [String] -> [String]
tabTake 0 _ 
  = [""]
tabTake _ []
  = []
tabTake n [string:strings]
  | n <= len 
	= [ string % (0, n - 1) ]
	= [ string : tabTake (n - len - 1) strings ]
  where
	len = size string

//--


