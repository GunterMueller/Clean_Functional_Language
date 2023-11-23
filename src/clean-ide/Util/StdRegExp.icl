implementation module StdRegExp

import StdBool, StdClass, StdEnum, StdFunc, StdList, StdMisc, StdTuple
import StdParsComb, StdMaybe

>*< :: (CParser s r t) -> CParser s [r] t
>*< p = 	yield []
		<|> (    p <&> \r  -> 
             >*< p <@  \rs -> [r:rs])

// DvA: special combinators not greedy, short to long matches...
// check with Pieter what the difference is...

<*~> :: (CParser s r t) -> CParser s [r] t
<*~> p =		yield []
			<|> (     p        <!&> \r  -> 
                 <*~> p <@     \rs -> [r:rs])

<+~> :: (CParser s r t) -> CParser s [r] t
<+~> p = p <&> \r -> <*~> p <@ \rs -> [r:rs]
         
//

instance toString (a,b) | toString a & toString b
where toString (a,b) = "("+toString a+", "+toString b+")"

showList :: [a] -> String | toString a
showList [] = "[]"
showList l	= "["+ tail l
where
	tail [a]	= toString a + "]"
	tail [a:r]	= toString a + ", " + tail r

instance + {#Char}
where (+) s t = s +++ t

// **************************

:: Cparser a b	:== CParser Char a b
:: StrSlice 	:== (![Char],!(!Int,!Int))
:: StrResult	:== (!StrSlice,![StrSlice])
Beginmark		:== '\000'					// character reserved for marking begin of substring
Endmark			:== '\001'					// character reserved for marking end of substring

controlsearch	:== ['()*+.[]{}@~#']		// control chars for search RE, | and ^ only have a meaning on top level
controlrepl		:== ['&$#'] 				// control chars for replace RE

// **************************
// Specification of character sequence to look for.
// Functions yield a parser that recognize the character sequence.

charSeq 	::	Cparser (Cparser [Char] a) b
charSeq		=	<+> nextChar <@ \cs -> token cs

nextChar	::	Cparser Char a
nextChar	= 		satisfy (\c -> not (isMember c controlsearch))
 				<!> symbol '#' &> anySymbol

anySymbol :== satisfy (\c -> True)

nonAlpha	::	Cparser (Cparser [Char] a) b
nonAlpha	=	symbol '~' <@ \_ -> satisfy (not o isAlpha) <@ \c -> [c]

anyAlpha	::	Cparser (Cparser [Char] a) b
anyAlpha	=	symbol '@' <@ \_ -> satisfy (not o isAlpha) <@ \c -> [c]

anyChar 	::	Cparser (Cparser [Char] a) b
anyChar		=	symbol '.' <@ \_ -> anySymbol <@ \c -> [c]

oneOfaSet 	::	Cparser (Cparser [Char] a) b
oneOfaSet 	=		symbol '['
				&>	<+> (dotdot <!> nextChar <@ \e->[e])
				<&	symbol ']'
				<@	\cl -> satisfy (\c -> isMember c (flatten cl)) <@ \r -> [r]
where
	dotdot 	= 	nextChar <&> \b -> token ['..'] &> nextChar <@ \e -> if (b<=e) [b..e] [e..b]
			
Unit 		::	Cparser (Cparser [Char] a) b
Unit		=	charSeq	
			<!> anyChar		
			<!> anyAlpha		
			<!> nonAlpha		
			<!> oneOfaSet
			<!> exprGroup
			<!>	subExpr

Exprs :: Cparser (Cparser [Char] a) b
Exprs =	Unit <&> (\parser1 ->		symbol '*' &>
									(	Exprs <@ (\parser2 -> (<*~> parser1 <@ flatten) <++> parser2)
									<!> yield (<*~> parser1 <@ flatten)
									) 
								<!>	symbol '+' &>
									(	Exprs <@ (\parser2 -> (<+~> parser1 <@ flatten) <++> parser2)
									<!> yield (<+~> parser1 <@ flatten)
									) 
								<!>	sp Exprs <@ (\parser2 -> parser1 <++> parser2)
  								<!> yield parser1
				 )

Expr ::  Cparser (Cparser [Char] a) b
Expr =	Exprs	<&>	(\parser1 ->		Expr <@ (\parser2 -> parser1 <++> parser2)
									<!>	yield parser1
					)

subExpr :: Cparser (Cparser [Char] a) b
subExpr =	symbol '{' &> Exprs <& symbol '}' <@ (\i -> (begin <++> i <++> end))
where			
	begin	= yield [Beginmark]	// []
	end  	= yield [Endmark]	// []

exprGroup 	:: Cparser (Cparser [Char] a) b
exprGroup 	= 	symbol '(' &> Exprs  <& symbol ')'

findParser :: Parser Char (Parser Char StrSlice)
findParser
 =	begin1 (beg <&> \pbeg -> Expr <& sp eof <@ \pExpr -> begin (pbeg <&> \b -> pExpr <@ \e -> slice b e))
where
	slice b e = (e,(lb,lb+length e`))
	where
		lb = length b`	// NO, no. Must slice over non-marked string...
		b` = strip b
		e` = strip e
		strip s = [c\\c<-s|c<>Beginmark&&c<>Endmark]

beg :: Cparser (Cparser [Char] a) b
beg =	symbol '^' <@ (\_ -> (>*< newline) <@ flatten)
	<!>	symbol '|' <@ (\_ -> (<*> (satisfy isSpace)) <++> (>*< (word <++> space) <@ flatten))
	<!> yield (>*< anySymbol)

newline :: Cparser [Char] a
newline
 =	<+>	(satisfy (\c -> c <> '\n')) <&> \l -> 
		 satisfy (\c -> c == '\n')  <@  \_ -> l ++ ['\n']

word :: Cparser [Char] a
word = <+> (satisfy isAlphanum)

space :: Cparser [Char] a
space = <+> (satisfy isSpace)

// **************************
// only one result

begin1 :: (CParser s t t) -> Parser s t
begin1 p = p (\x nc rc ss -> [(ss,x)]) (\rc -> rc) []

// **************************
searchAnyWhere :: ![Char] ![Char] -> String
searchAnyWhere pat string
 = case begin1 (Expr <& eof) pat of
	[]			-> "no valid search pattern"
	[([],p)]	-> showList (AnyWhere p 0 string)
	[(l ,p)]	-> "Internal error, pattern does not consume entire pattern"
	_			-> "Internal error, pattern generates multiple parsers"
where
	AnyWhere p n []     = []
	AnyWhere p n string = p (\r xc ac ss -> [(ss,(r,(n,n+length r)))]) (\x -> x) (AnyWhere p (inc n) (tl string)) string

searchOne_RE :: ![Char] ![Char] -> String
searchOne_RE pat string
 = case findParser pat of
	[]			-> "no valid search pattern"
	[([],p)]	-> showList (p string)
	[(l ,p)]	-> "Internal error, pattern does not comsume entire pattern"
	_			-> "Internal error, pattern generates multiple parsers"

searchOne_RE` :: [.Char] [.Char] -> (.Maybe {#Char},.Maybe (ParsResult Char StrSlice));
searchOne_RE` pat string
 = case findParser pat of
	[]			->
					(Just "no valid search pattern",Nothing)
	[([],p)]	-> (Nothing,Just (p string))
	[(l ,p)]	-> (Just "Internal error, pattern does not comsume entire pattern",Nothing)
	_			-> (Just "Internal error, pattern generates multiple parsers",Nothing)

// **************************

nextrepChar	::	Cparser Char a
nextrepChar	=	satisfy (\c -> not (isMember c controlrepl))
 			<!>	symbol '#' &> anySymbol

repcharSeq	::	Cparser (StrResult -> [Char]) b
repcharSeq	=	<+> nextrepChar <@ (\repl _ -> repl)

repExprs 	::  Cparser (StrResult -> [Char]) b
repExprs 	=	repcharSeq	
			<!> wholeString		
			<!> subrepString

wholeString	::  Cparser (StrResult -> [Char]) b
wholeString = 	symbol '&' <@ (\_ ((string,_),_) -> string)

subrepString	::  Cparser (StrResult -> [Char]) b
subrepString 	= 	symbol '$' &> satisfy isDigit <@ \i tup -> fetchstring tup (digitToInt i)
where
	fetchstring (string,substrings) i
		# n_substrings					= length substrings
		| i >= 0 && i < n_substrings 	= fst (substrings !! i)	// if index in list of substrings, select substring
		| otherwise						= []					// otherwise, an empty substring

replaceExpr	=		repExpr 
				<!> abort "Illegal replace expression"

repExpr ::  Cparser [StrResult -> [Char]] b
repExpr =	repExprs <&> (\parser1 -> repExpr <@ \parser2 -> [parser1:parser2])
		<!>	repExprs <@   \parser1 -> [parser1]

// **************************
replaceParser
	=	begin1
		(				replaceExpr
		<& sp eof
		<@ \pExpr arg -> flatten (map (\f->f arg) pExpr)
		)

replaceOne_RE :: [.Char] !.StrResult -> (.Maybe {#Char},Maybe .[Char]);
replaceOne_RE rep string
 = case (replaceParser rep) of
	[]			-> (Just "no valid replace pattern",Nothing)
	[([],p)]	-> (Nothing,Just (p string))
	[(l ,p)]	-> (Just "Internal error, pattern does not comsume entire pattern",Nothing)
	_			-> (Just "Internal error, pattern generates multiple parsers",Nothing)

massageResult :: ![Char] -> StrResult
massageResult string = (wholeSlice,subSlices)
where
	filterMarks s = filter (\c-> c <> Beginmark && c <> Endmark) s
	wholeSlice = (whole,(0,length whole))
	whole :: [Char]
	whole = filterMarks string
	subSlices = fillOut (take 10 (subSlice string 0)) whole

subSlice [] i = []
subSlice [h:t] i
	| h == Endmark = subSlice t i
	| h <> Beginmark = subSlice t (inc i)
	# e = matchingEnd t i 0
	= [(i,e):subSlice t i]

matchingEnd [] _ _ = abort "No matching end found??"
matchingEnd [h:t] i x
	= case h of
		Beginmark	-> matchingEnd t i (inc x)
		Endmark		-> if (x==0) i (matchingEnd t i (dec x))
		_			-> matchingEnd t (inc i) x

fillOut [] _ = []
fillOut [h=:(f,l):t] s = [(s%(f,dec l),h):fillOut t s]
