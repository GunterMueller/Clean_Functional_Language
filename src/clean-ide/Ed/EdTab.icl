implementation module EdTab

/*
 * functions that deal with those annoying tab characters
 
 o Unfortunately doesn't work with proportional fonts...
   Probably inevitable with an 'editor' view of tabs.
 */

import StdArray, StdBool, StdClass, StdEnum, StdList
import StdIOCommon, StdPicture, StdPSt
import EdMonad, syncol

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

alignAtTab` x tabSize charWidth
	| tabSize <= 0
		= x + charWidth	// sensible result for silly value
	= tabWidth * (inc (x / tabWidth))
where
	tabWidth	= tabSize * charWidth

tabDrawString :: !Point2 !String !FontInfo !*Picture -> *Picture
tabDrawString point string {thefont, showTabs,tabSize,charWidth} picture
	#! strings = splitAtTabs string
	= tabDrawString` point strings picture
where
		  
	tabDrawString` :: !Point2 [String] !*Picture -> *Picture
	
	tabDrawString` _ [] picture
	  = picture

	tabDrawString` point [ string : [] ] picture
	  # picture					 = setPenPos point picture
	  # picture					 = draw string picture
	  = picture
	  
	tabDrawString` point [ string : strings ] picture
		# picture					= setPenPos point picture
		# picture					= draw string picture
		  (newPoint,picture)		= getPenPos picture
		  newX					 	= alignAtTab` newPoint.x tabSize charWidth
		| not showTabs
		 	= tabDrawString` { point & x = newX } strings picture
		# picture					= setPenColour Red picture
		  picture					= draw '~' picture
		  picture					= setPenColour Black picture
		= tabDrawString` { point & x = newX } strings picture

:: CommentLevel
	= N Int	// normal comment nesting level
	| L		// comment till end of line...
	| S 	// in string constant...
	| C		// in char constant...
	| T Int	// in typedef
	| D Int	// in typedecl

import ospicture				// for optimized drawfuns...
optDrawS :== pictdrawstring		// use non-optimised versions
optDrawC :== pictdrawchar		// "

tabDrawStringC :: !Point2 !(!Info,!String) !FontInfo !*Picture -> *Picture
tabDrawStringC point ({comment_level=clevel,is_typedef=typedef,is_typedecl=typedecl},string)
	{tabSize,charWidth,thefont, showTabs, syntaxColours={textColour, backgroundColour,tabColour, commentColour, stringColour, charColour, keywordColour, typedefColour, typedeclColour}}
	picture
	#! strings = splitAtTabs string
	| typedef
		= tabDrawString` /*True*/ (T clevel) point strings picture
	| typedecl
		= tabDrawString` (D clevel) point strings picture
	= tabDrawString` /*True*/ (N clevel) point strings picture
where
		  
	tabDrawString` :: /*!Bool*/ !CommentLevel !Point2 !.[String] !*Picture -> *Picture
	// hmm, need to get if column 0 into local funs...
	tabDrawString` /*_*/ _ _ [] picture
//		#! (_,picture)		 = optGetPenPos picture
		= picture

	tabDrawString` /*ini*/ clevel point [string : []] picture
//		#! (_,picture)		 = optGetPenPos picture
		#! picture					 = setPenPos point picture
		#! (_,picture)				 = drawC /*ini*/ clevel string picture
//		#! (_,picture)		 = optGetPenPos picture
		= picture
	  
	tabDrawString` /*ini*/ clevel point [string : strings] picture
//		#! (_,picture)		 = optGetPenPos picture
		#! picture					 = setPenPos point picture
		#! (clevel,picture)			 = drawC /*ini*/ clevel string picture
//		#! (newPoint,picture)		 = optGetPenPos picture
		#! (newPoint,picture)		 = getPenPos picture
		#! newX						 = alignAtTab` newPoint.x tabSize charWidth
		| not showTabs
		 	= tabDrawString` /*False*/ clevel {point & x = newX} strings picture
		#! picture					 = setPenColour tabColour picture
		#! picture					 = optDrawC '~' picture
		#! picture					 = setPenColour textColour picture
		= tabDrawString` /*False*/ clevel {point & x = newX} strings picture

	drawC :: /*!Bool*/ !CommentLevel !.String !*Picture -> (!CommentLevel,!*Picture)
	drawC /*ini*/ c s pic
		= drawC c pic
	where
		drawC :: !CommentLevel !*Picture -> (!CommentLevel,!*Picture)
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
			= dL /*ini*/ (N cl) 0 pic
		drawC (T cl) pic
			# pic = (if (cl==0) (setPenColour typedefColour) (setPenColour commentColour)) pic
			= dL /*ini*/ (T cl) 0 pic
		drawC (D cl) pic
			# pic = (if (cl==0) (setPenColour typedeclColour) (setPenColour commentColour)) pic
			= dL (D cl) 0 pic

		l = size s
		funnyChar i = isStringMember s.[i] (dec funnySize) funnyChars

		isStringMember :: !Char !Int !{#Char} -> Bool
		isStringMember x i s
			| i < 0 = False
			| s.[i] == x = True
			= isStringMember x (dec i) s

		funnyChars = "~@#$%^?!+-*<>\\/|&=:."
		funnySize = 20

		dL :: /*!Bool*/ !CommentLevel !.Int !*Picture -> (!CommentLevel,!*Picture)
		dL /*ini*/ cl i pic
			| i >= l
				= (cl,pic)
/*
			| ini && s.[i] == ':' && not (in_comment cl)
				# i` = inc i
				| i` >= l
					# (cl,pic) = normalise ini i cl pic
					# pic = optDrawC ':' pic
					= (N 0,pic)
				| s.[i`] == ':'
					# i`` = inc i`
					| i`` < l && funnyChar i``
						# j = scanfunny i
						# r = s%(i,dec j)
						# pic = optDrawS r pic
						= dL False (N 0) j pic
					# pic = setPenColour typedefColour pic
					# pic = optDrawS "::" pic
					= dL False (T 0) i`` pic
				| s.[i`] == '='
					# i`` = inc i`
					| i`` < l && funnyChar i``
						# j = scanfunny i
						# r = s%(i,dec j)
						# (cl,pic) = case r of
							":=="	-> (cl,pic)
							_		-> normalise ini i cl pic
						# pic = optDrawS r pic
						= dL False cl j pic
					# (cl,pic) = normalise ini i cl pic
					# pic = optDrawS ":=" pic
					= dL False (N 0) i`` pic
				# (cl,pic) = normalise ini i cl pic
				# pic = optDrawC ':' pic
				= dL False (N 0) i` pic
*/
			| s.[i] == '*'
				# i` = inc i
				| i` >= l
//					# (cl,pic) = normalise ini i cl pic
					# pic = optDrawC '*' pic
					= (cl,pic)
				| s.[i`] == '/'
					# i`` = inc i`
					| in_comment cl	//cl <> 0
						# pic = setPenColour commentColour pic	// idiot proof for trickery at start of text...
						# pic = optDrawS "*/" pic
						# cl = dec_comment cl
						| not (in_comment cl)	//cl == 0
							# pic = setPenColour (non_comment_colour cl)/*textColour*/ pic
							= dL /*False*/ cl i`` pic
						= dL /*False*/ cl i`` pic
						
					| i`` < l && funnyChar i``
						// eat till end of funnyid substring...
						# j = scanfunny i``
						# r = s%(i``,dec j)
//						# (cl,pic) = normalise ini i cl pic
						# pic = optDrawS "*/" pic
						# pic = optDrawS r pic
						= dL /*False*/ cl j pic
					# pic = setPenColour commentColour pic		// idiot proof for trickery at start of text...
					# pic = optDrawS "*/" pic
					# cl = dec_comment cl
					| not (in_comment cl)	//cl == 0
						# pic = setPenColour (non_comment_colour cl)/*textColour*/ pic
						= dL /*False*/ cl i`` pic
					= dL /*False*/ cl i`` pic
//				# (cl,pic) = normalise ini i cl pic
				# pic = optDrawC '*' pic
				= dL /*False*/ cl i` pic
			| s.[i] == '/'
				# i` = inc i
				| i` >= l
//					# (cl,pic) = normalise ini i cl pic
					# pic = optDrawC '/' pic
					= (cl,pic)
				| s.[i`] == '/'
					# pic = setPenColour commentColour pic
					# pic = optDrawS "//" pic
					# r = s%(inc i`,l)
					# pic = optDrawS r pic
					= (L,pic)
				| s.[i`] == '*'
					# pic = setPenColour commentColour pic
					# pic = optDrawS "/*" pic
					# cl = inc_comment cl
					| in_comment cl
						= dL cl (inc i`) pic
					# pic = setPenColour (non_comment_colour cl) pic
					= dL /*False*/ cl (inc i`) pic
//				# (cl,pic) = normalise ini i cl pic
				# pic = optDrawC '/' pic
				= dL /*False*/ cl i` pic
			| (s.[i] == '"') && (not (in_comment cl))	//(cl == 0)
				# pic = setPenColour stringColour pic
				# pic = optDrawC '"' pic
				= dS (inc i) pic
			| (s.[i] == '\'') && (not (in_comment cl))	//(cl == 0)
				# pic = setPenColour charColour pic
				# pic = optDrawC '\'' pic
				= dC (inc i) pic

			| /*(cl == 0)*/ (not (in_comment cl)) && (funnyChar i)
				# j = scanfunny i
				# r = s%(i,dec j)
/*
				# (cl,pic) = case r of
								"|"	-> (cl,pic)
								"=" -> (cl,pic)
								_	-> normalise ini i cl pic
*/
				# pic = optDrawS r pic
				= dL /*False*/ cl j pic
/*
			# (cl,pic) = case WhiteSpace s.[i] of
							True -> (cl,pic)
							_	 -> normalise ini i cl pic
*/
			# (key,j) = scankeyword s i
			| key && (not (in_comment cl))	//cl == 0
				# r = s%(i,dec j)
				# (c,pic) = getPenColour pic
				# pic = setPenColour keywordColour pic
				# pic = optDrawS r pic
				# pic = setPenColour c pic
				= dL /*False*/ cl j pic
			# r = s%(i,dec j)
			# pic = optDrawS r pic
			= dL /*False*/ cl j pic
		where
/*
			normalise True 0 (T 0) pic
				# pic = setPenColour textColour pic
				= (N 0,pic)
			normalise _ _ cl pic
				= (cl,pic)
			in_typedef cl = case cl of
				T l	-> l == 0
				_	-> False
*/
			in_comment cl = case cl of
				N l	-> l <> 0
				T l	-> l <> 0
				D l -> l <> 0
				_	-> False

			dec_comment cl = case cl of
				N l	-> N (dec l)
				T l	-> T (dec l)
				D l -> D (dec l)

			inc_comment cl = case cl of
				N l	-> N (inc l)
				T l	-> T (inc l)
				D l -> D (inc l)

			non_comment_colour cl = case cl of
				N _	-> textColour
				T _	-> typedefColour
				D _ -> typedeclColour

			scankeyword :: !.String !Int -> (!Bool,!Int)
			scankeyword s i
				# c = s.[i]
				| not (isAlpha c || (c == '_'))
					# j = inc i
					= (False,j)
				# j = scanalpha (inc i)
				| c == 'f'	// from
					| (j == i+4) && (s%(i,i+3)=="from") = (True,j)
					= (False,j)
				| c == 'g'	// generic
					| (j == i+7) && (s%(i,i+6)=="generic") = (True,j)
					= (False,j)
				| c == 'd'	// definition, derive, dynamic
					| j == i+10 = (s % (i,i+9)=="definition",j)
					| j == i+6  = (s % (i,i+5)=="derive",j)
					| j == i+7  = (s % (i,i+6)=="dynamic",j)
					= (False,j)
				| c == 'i'	// implementation, import, if, in, infix, infixl, infixr, instance
					| (j == i+14) && (s%(i,i+13)=="implementation") = (True,j)
					| (j == i+8) && (s%(i,i+7)=="instance") = (True,j)			// only in typedef!
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
					| (j == i+4) && (s%(i,i+3)=="let!") = (True,j)				// doesn't work!
					| (j == i+3) && (s%(i,i+2)=="let") = (True,j)
					= (False,j)
				| c == 'o'	// of
					| (j == i+2) && (s%(i,i+1)=="of") = (True,j)
					= (False,j)
				| c == 'w'	// where, with
					| (j == i+4) && (s%(i,i+3)=="with") = (True,j)
					| (j == i+5) && (s%(i,i+4)=="where") = (True,j)
					= (False,j)
				= (False,j)
			scanalpha i
				| i >= l = l
				# c = s.[i]
				| isAlphanum c = scanalpha (inc i)
				| c == '_' = scanalpha (inc i)
				| c == '`' = scanalpha (inc i)
				= i
			scanfunny i
				| i >= l = l
				| funnyChar i = scanfunny (inc i)
				= i
			
		dS :: !Int !*Picture -> (!CommentLevel,!*Picture)
		dS i pic
			| i >= l
				= (S,pic)
			| s.[i] == '"'
				# pic = optDrawC '"' pic
				# pic = setPenColour textColour pic
				= dL /*False*/ (N 0) (inc i) pic
			| s.[i] == '\\'
				# pic = optDrawC '\\' pic
				# i = inc i
				| i >= l
					= (S,pic)
				# pic = optDrawC s.[i] pic
				= dS (inc i) pic
			# pic = optDrawC s.[i] pic
			= dS (inc i) pic

		dC :: !Int !*Picture -> (!CommentLevel,!*Picture)
		dC i pic
			| i >= l
				= (C,pic)
			| s.[i] == '\''
				# pic = optDrawC '\'' pic
				# pic = setPenColour textColour pic
				= dL /*False*/ (N 0) (inc i) pic
			| s.[i] == '\\'
				# pic = optDrawC '\\' pic
				# i = inc i
				| i >= l
					= (C,pic)
				# pic = optDrawC s.[i] pic
				= dC (inc i) pic
			# pic = optDrawC s.[i] pic
			= dC (inc i) pic

WhiteSpace c
:==	c == ' ' || c == '\t' || c == '\n' || c == '\r' || c == '\f';
