/*
** Program: Clean Prover System
** Module:  Lexical (.icl)
** 
** Author:  Maarten de Mol
** Created: 11 September 2000
*/

implementation module 
	Lexical

import
	StdEnv,
	StdMaybe,
	Errors,
	ParserCombinators,
	RWSDebug

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: CLexeme = 
// -------------------------------------------------------------------------------------------------------------------------------------------------
	  CBoolDenotation		!Bool
	| CCharDenotation		!Char
	| CCharListDenotation	![Char]
	| CIdentifier			!String
	| CIntDenotation		!Int
	| CRealDenotation		!Real
	| CReserved				!String
	| CStringDenotation		!String

fromBoolDenotation		:: CLexeme -> Bool;		fromBoolDenotation		(CBoolDenotation bool)		= bool
fromCharDenotation		:: CLexeme -> Char;		fromCharDenotation		(CCharDenotation chars)		= chars
fromCharListDenotation	:: CLexeme -> [Char];	fromCharListDenotation	(CCharListDenotation chars)	= chars
fromIdentifier			:: CLexeme -> String;	fromIdentifier			(CIdentifier text)			= text
fromIntDenotation		:: CLexeme -> Int;		fromIntDenotation		(CIntDenotation num)		= num
fromRealDenotation		:: CLexeme -> Real;		fromRealDenotation		(CRealDenotation num)		= num
fromStringDenotation	:: CLexeme -> String;	fromStringDenotation	(CStringDenotation text)	= text

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance == CLexeme
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	(==) (CBoolDenotation _)		(CBoolDenotation _)			= True
	(==) (CCharDenotation _)		(CCharDenotation _)			= True
	(==) (CCharListDenotation _)	(CCharListDenotation _)		= True
	(==) (CIdentifier _)			(CIdentifier _)				= True
	(==) (CIntDenotation _)			(CIntDenotation _)			= True
	(==) (CRealDenotation _)		(CRealDenotation _)			= True
	(==) (CReserved text1)			(CReserved text2)			= text1 == text2
	(==) (CStringDenotation _)		(CStringDenotation _)		= True
	(==) _							_							= False
CAnyBoolDenotation		:== CBoolDenotation True
CAnyCharDenotation		:== CCharDenotation 'a'
CAnyCharListDenotation	:== CCharListDenotation ['Hallo']
CAnyIdentifier			:== CIdentifier ""
CAnyIntDenotation		:== CIntDenotation 42
CAnyRealDenotation		:== CRealDenotation 0.0
CAnyStringDenotation	:== CStringDenotation "Hallo"

// -------------------------------------------------------------------------------------------------------------------------------------------------
isWord :: !String !CLexeme -> Bool
// -------------------------------------------------------------------------------------------------------------------------------------------------
isWord word (CIdentifier text)
	= WORD == TEXT
	where
		WORD :: String
		WORD
			= {toUpper c \\ c <-: word}
		TEXT :: String
		TEXT
			= {toUpper c \\ c <-: text}
isWord word (CReserved text)
	= WORD == TEXT
	where
		WORD :: String
		WORD
			= {toUpper c \\ c <-: word}
		TEXT :: String
		TEXT
			= {toUpper c \\ c <-: text}
isWord word other
	= False











// -------------------------------------------------------------------------------------------------------------------------------------------------
isADigit :: !Char -> Bool
// -------------------------------------------------------------------------------------------------------------------------------------------------
isADigit char
	= isMember char ['0123456789']

// -------------------------------------------------------------------------------------------------------------------------------------------------
isIdChar :: !Char -> Bool
// -------------------------------------------------------------------------------------------------------------------------------------------------
isIdChar char
	= or [isMember char ['_`'], isADigit char, isLowerCaseChar char, isUpperCaseChar char]

// -------------------------------------------------------------------------------------------------------------------------------------------------
isLowerCaseChar :: !Char -> Bool
// -------------------------------------------------------------------------------------------------------------------------------------------------
isLowerCaseChar char
	= isMember char ['abcdefghijklmnopqrstuvwxyz']

// -------------------------------------------------------------------------------------------------------------------------------------------------
isReservedChar :: !Char -> Bool
// -------------------------------------------------------------------------------------------------------------------------------------------------
isReservedChar char
	= isMember char ['(){}[];,.']

// -------------------------------------------------------------------------------------------------------------------------------------------------
isSpecialChar :: !Char -> Bool
// -------------------------------------------------------------------------------------------------------------------------------------------------
isSpecialChar char
//	= isMember char ['~@#$%^?!+-*<>/|&=:.', '\\']
	= isMember char ['~@#$%^?!+-*<>/|&=:', '\\']

// -------------------------------------------------------------------------------------------------------------------------------------------------
isUpperCaseChar :: !Char -> Bool
// -------------------------------------------------------------------------------------------------------------------------------------------------
isUpperCaseChar char
	= isMember char ['ABCDEFGHIJKLMNOPQRSTUVWXYZ']

// -------------------------------------------------------------------------------------------------------------------------------------------------
isWhiteSpace :: !Char -> Bool
// -------------------------------------------------------------------------------------------------------------------------------------------------
isWhiteSpace char
	= isMember char [' ', '\t', '\n', '\r']





// -------------------------------------------------------------------------------------------------------------------------------------------------
parseBoolDenotation :: Parser Char CLexeme
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseBoolDenotation
	= (     (Token ['True']  &> Succeed True)
	    <|> (Token ['False'] &> Succeed False)
	  ) <@ CBoolDenotation

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseCharInChar :: Parser Char Char
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseCharInChar
	=     (Satisfy isIdChar)
	  <|> (Satisfy isReservedChar)
	  <|> (Satisfy isLowerCaseChar)
	  <|> (Satisfy isUpperCaseChar)
	  <|> (Symbol  '"')
	  <|> parseSpecial
	  <|> (Satisfy isSpecialChar)

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseCharInString :: Parser Char Char
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseCharInString
	=     (Satisfy isIdChar)
	  <|> (Satisfy isReservedChar)
	  <|> (Symbol  '\'')
	  <|> (Symbol ' ')
	  <|> parseSpecial
	  <|> (Satisfy isSpecialChar)

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseCharDenotation :: Parser Char CLexeme
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseCharDenotation
	= (Pack ['\''] (<+> parseCharInChar) ['\'']) <@ make_character
	where
		make_character :: ![Char] -> CLexeme
		make_character chars
			| length chars == 1				= CCharDenotation (hd chars)
			= CCharListDenotation chars

// =================================================================================================================================================
// Also recognizes _|_ (Reserved) and _ (special identifier)
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseIdentifier :: Parser Char CLexeme
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseIdentifier
	= (     Token ['Reduce+']
	    <|> Token ['Reduce-']
	    <|> Token ['Rewrite-']
	    <|> (Satisfy isLowerCaseChar <:&> <*> (Satisfy isIdChar))
	    <|> (Satisfy isUpperCaseChar <:&> <*> (Satisfy isIdChar))
	    <|> ((Symbol '_')            <:&> <+> (Satisfy isIdChar))
	    <|> (     (<+> (Satisfy isSpecialChar))
	          <&> (     (Symbol '_') <:&> (<+> (Satisfy isIdChar))
	                <|> Succeed []
	              )
	        ) <@ (\(x,y) -> x ++ y)
	    <|> Token ['_|_']
	    <|> Token ['_']
	  ) <@ (filterReserved o CIdentifier o toString)
	where
		// list of identifiers that are parsed as something else -- see parseReserved for the rest
		filterReserved :: CLexeme -> CLexeme
		filterReserved (CIdentifier "=")		= CReserved "="
		filterReserved (CIdentifier "->")		= CReserved "->"
		filterReserved (CIdentifier "=>")		= CReserved "=>"
		filterReserved (CIdentifier "<->")		= CReserved "<->"
		filterReserved (CIdentifier "<=>")		= CReserved "<=>"
		filterReserved (CIdentifier "/\\")		= CReserved "/\\"
		filterReserved (CIdentifier "\\/")		= CReserved "\\/"
		filterReserved (CIdentifier "//")		= CReserved "//"
		filterReserved (CIdentifier "~")		= CReserved "~"
		filterReserved (CIdentifier ":")		= CReserved ":"
		filterReserved (CIdentifier "::")		= CReserved "::"
//		filterReserved (CIdentifier ".")		= CReserved "."
		filterReserved (CIdentifier "!")		= CReserved "!"
		filterReserved (CIdentifier "&")		= CReserved "&"
		filterReserved (CIdentifier "|")		= CReserved "|"
		filterReserved (CIdentifier "@")		= CReserved "@"
		filterReserved (CIdentifier "case")		= CReserved "case"
		filterReserved (CIdentifier "default")	= CReserved "default"
		filterReserved (CIdentifier "in")		= CReserved "in"
		filterReserved (CIdentifier "let")		= CReserved "let"
		filterReserved (CIdentifier "of")		= CReserved "of"
		filterReserved (CIdentifier "to")		= CReserved "to"
		filterReserved (CIdentifier "TRUE")		= CReserved "TRUE"
		filterReserved (CIdentifier "FALSE")	= CReserved "FALSE"
		filterReserved (CIdentifier "_|_")		= CReserved "_|_"
		filterReserved other					= other

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseIntDenotation :: Parser Char CLexeme
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseIntDenotation
//	= (     (Symbol '+' &> parseInteger)
//	    <|> (Symbol '-' &> parseInteger) <@ (~)
//	    <|> parseInteger
//	  ) <@ CIntDenotation
	= parseInteger <@ CIntDenotation

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseInteger :: Parser Char Int
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseInteger
	= <+> (Satisfy isDigit <@ digitToInt) <@ (make_num 0)
	where
		make_num :: Int [Int] -> Int
		make_num acc [x:xs]
			# new_acc				= acc*10 + x
			| new_acc < acc			= acc						// simple overflow test
			= make_num new_acc xs
		make_num acc []
			= acc

// =================================================================================================================================================
// Watch out: always pare Identifiers before Literals (due to +7 overlap)
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseLexeme :: Parser Char CLexeme
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseLexeme
	=     parseReserved
	  <|> parseLiteral
	  <|> parseIdentifier

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseLiteral :: Parser Char CLexeme
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseLiteral
	=     parseRealDenotation
      <|> parseIntDenotation
      <|> parseBoolDenotation
      <|> parseCharDenotation
      <|> parseStringDenotation

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseReal :: Parser Char Real
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseReal
	= (     (parseInteger <& Symbol '.')
	    <&> parse_zero_integer
	    <&> parseRealExponent
	  ) <@ make_real
	where
		make_real :: (Int, ((Int, Int), Int)) -> Real
		make_real (whole, ((zeros, frac), exponent))
			# zero_string			= toString (repeatn zeros '0')
			# original_string		= toString whole +++ "." +++ zero_string +++ toString frac
			# original_string		= if (exponent == 0) original_string (original_string +++ "E" +++ toString exponent)
			= toReal original_string
		
		parse_zero_integer
			=     (Symbol '0' &> parse_zero_integer) <@ (\(count, num) -> (count+1, num))
			  <|> parseInteger <@ (\num -> (0, num))

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseRealDenotation :: Parser Char CLexeme
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseRealDenotation
//	= (     (Symbol '+' &> parseReal)
//	    <|> (Symbol '-' &> parseReal) <@ (~)
//	    <|> parseReal
//	  ) <@ CRealDenotation
	= parseReal <@ CRealDenotation

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseRealExponent :: Parser Char Int
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseRealExponent
	=     (Symbol 'E' &> parseIntDenotation) <@ fromIntDenotation
	  <|> (Succeed 0)

// =================================================================================================================================================
// Only parses the reserved symbols that cannot be parsed as something else.
// (see parseIdentifier for the others)
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseReserved :: Parser Char CLexeme
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseReserved
	= (     (Symbol '[' &> Succeed "[")
	    <|> (Symbol ']' &> Succeed "]")
	    <|> (Symbol '(' &> Succeed "(")
	    <|> (Symbol ')' &> Succeed ")")
	    <|> (Symbol '{' &> Succeed "{")
	    <|> (Symbol '}' &> Succeed "}")
	    <|> (Symbol ',' &> Succeed ",")
	    <|> (Symbol ';' &> Succeed ";")
	    <|> (Symbol '.' &> Succeed ".")
	    <|> (Token ['let!'] &> Succeed "let!")
	  ) <@ CReserved

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseSpecial :: Parser Char Char
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseSpecial
	=     (Token ['\n'] &> Succeed '\n')
	  <|> (Token ['\r'] &> Succeed '\r')
	  <|> (Token ['\f'] &> Succeed '\f')
	  <|> (Token ['\b'] &> Succeed '\b')
	  <|> (Token ['\t'] &> Succeed '\t')
	  <|> (Token ['\\\\'] &> Succeed '\\')
	  <|> (Token ['\\\''] &> Succeed '\'')
	  <|> (Token ['\\\"'] &> Succeed '\"')

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseString :: Parser Char String
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseString
	= <*> parseCharInString <@ toString

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseStringDenotation :: Parser Char CLexeme
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseStringDenotation
	= (Pack ['"'] parseString ['"']) <@ CStringDenotation












// -------------------------------------------------------------------------------------------------------------------------------------------------
parseListLexemes :: ![Char] -> (!Error, ![CLexeme])
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseListLexemes input
	# maybe_parse				= parser input
	| isNothing maybe_parse		= (pushError (X_Lexeme "Unrecognized syntax.") OK, [])
	# (input_left, lexemes)		= fromJust maybe_parse
	| not (isEmpty input_left)	= (pushError (X_Lexeme "Unrecognized symbol.") OK, [])
	= (OK, filter_comments False lexemes)
	where
		parser
			= <*> (optional_white &> parseLexeme <& optional_white)
			
		optional_white
			= <*> (Satisfy isWhiteSpace)
		
		// hack -- also filters ~~ to ~ ~ and ~~~ to ~ ~ ~
		filter_comments :: !Bool ![CLexeme] -> [CLexeme]
		filter_comments bool [CIdentifier "~~": lexemes]
			= [CReserved "~", CReserved "~": filter_comments bool lexemes]
		filter_comments bool [CIdentifier "~~~": lexemes]
			= [CReserved "~", CReserved "~", CReserved "~": filter_comments bool lexemes]
		filter_comments bool [CReserved "//": lexemes]
			= filter_comments (not bool) lexemes
		filter_comments True [lexeme: lexemes]
			= filter_comments True lexemes
		filter_comments False [lexeme: lexemes]
			= [lexeme: filter_comments False lexemes]
		filter_comments bool []
			= []

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseLexemes :: !String -> (!Error, ![CLexeme])
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseLexemes input
	= parseListLexemes [c \\ c <-: input]