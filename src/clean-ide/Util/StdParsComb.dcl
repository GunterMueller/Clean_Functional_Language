definition module StdParsComb

import StdString, StdOverloaded

:: Parser s r :== [s] -> ParsResult s r
:: ParsResult s r :== [([s],r)]

:: CParser s r t :== (SucCont s r t) (XorCont s t) (AltCont s t) -> Parser s t
:: SucCont s r t :== r (XorCont s t) (AltCont s t) -> Parser s t			// internal continuation
:: XorCont s t   :== (AltCont s t) -> ParsResult s t						// internal continuation
:: AltCont s t   :== ParsResult s t											// internal continuation

begin	:: !(CParser s t t) -> Parser s t									// to initiate a Cparser

fail	:: CParser s r t													// always fails
yield	:: r -> CParser s r t												// always succeed with given item
symbol	:: s -> CParser s s t | == s										// parse symbol
token	:: [s] -> CParser s [s] t | ==s										// parse list of symbols
satisfy	:: (s->Bool) -> CParser s s t										// first input satisfies condition?
eof		:: CParser s Int t													// End of input stream?					// new

(<|>)	infixr 4 :: (CParser s r t) (CParser s r t) -> CParser s r t		// inclusive or
(<&>)	infixr 6 :: (CParser s u t) (u -> CParser s v t) -> CParser s v t	// monadic and
(<@)	infixl 5 :: (CParser s r t) (r->u) -> CParser s u t					// apply function to item
<*>		:: (CParser s r t) -> CParser s [r] t								// zero or more times
<+>		:: (CParser s r t) -> CParser s [r] t								// one or more times

(<&)	infixr 6 :: (CParser s u t) (CParser s v t) -> CParser s u t		// only left of and
(&>)	infixr 6 :: (CParser s u t) (CParser s v t) -> CParser s v t		// only right of and
(<:&>)	infixr 6 :: (CParser s u t) (CParser s [u] t) -> CParser s [u] t	// cons results
(<++>)	infixr 6 :: (CParser s [u] t) (CParser s [u] t) -> CParser s [u] t	// append results

(<!>)	infixr 4 :: (CParser s r t) (CParser s r t) -> CParser s r t		// exclusive or
(<!&>)	infixr 6 :: (CParser s u t) (u -> CParser s v t) -> CParser s v t	// and with cut
<+?>	:: (CParser s r t) -> CParser s [r] t								// zero or more times, all
<*?>	:: (CParser s r t) -> CParser s [r] t								// one or more times. all
cut		:: (CParser s r t) -> CParser s r t									// cut exor branch

<?> 	:: (CParser s r t) -> CParser s [r] t								// Eager version, if p succeeds use it!
<?@>	:: (CParser s r t) (r->u) u -> CParser s u t						// if p succeeds apply f, otherwise yield u
<??>	:: (CParser s r t) -> CParser s [r] t								// Lazy version of <?>
<??@>	:: (CParser s r t) (r->u) u -> CParser s u t						// lazy version of <?@>
(>?<)	infix 9 :: (CParser s r t) (r -> Bool) -> (CParser s r t)			// condition on parsed item

digit		:: CParser Char Int x
nat			:: CParser Char Int t
int			:: CParser Char Int t
identifier	:: CParser Char String t

sp			:: (CParser Char r t) -> CParser Char r t						// skip spaces
spsymbol	:: Char -> CParser Char Char t									// symbol after skipping spaces
sptoken		:: [Char] -> CParser Char [Char] t								// token after skiping spaces

parseSequence	:: (CParser a b c) (CParser a d c) -> CParser a [b] c		//	accept one or more 'b''s sepparated by 'd''s; accumulate 'b''s in a list
parseChainLeft	:: (CParser a b c) (CParser a (b b -> b) c) -> CParser a b c// p1 parses elements that are given to the function found by p2. Left associative.
parseChainRight	:: (CParser a b c) (CParser a (b b -> b) c) -> CParser a b c// p1 parses elements that are given to the function found by p2. Right associative.

choice :: ![CParser a b c] -> CParser a b c									// Apply the first parser from the list that succeeds
