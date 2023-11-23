/*
** Program: Clean Prover System
** Module:  ParserCombinators (.icl)
** 
** Author:  Maarten de Mol
** Created: 11 September 2000
**
** Note: These are deterministic parser-combinators. The 'Maybe'-type is used to denote
**       failures.
*/

implementation module 
   ParserCombinators

import 
   StdEnv,
   StdMaybe
       
// -------------------------------------------------------------------------------------------------------------------------------------------------
:: Parse input output		:== ([input], output)
:: Parser input output		:== [input] -> Maybe (Parse input output)
// -------------------------------------------------------------------------------------------------------------------------------------------------

// -------------------------------------------------------------------------------------------------------------------------------------------------
AnySymbol :: [input] -> Maybe (Parse input input)
// -------------------------------------------------------------------------------------------------------------------------------------------------
AnySymbol [x:xs]
	= Just (xs, x)
AnySymbol []
	= Nothing

// =================================================================================================================================================
// Only succeeds if at least one element is found.
// -------------------------------------------------------------------------------------------------------------------------------------------------
List :: [input] (Parser input output) -> Parser input [output] | == input
// -------------------------------------------------------------------------------------------------------------------------------------------------
List separator parser
	= parser <:&> (     (Token separator &> List separator parser)
	                <|> Succeed []
	              )

// -------------------------------------------------------------------------------------------------------------------------------------------------
LookAhead :: (Parser input output) [input] -> Maybe (Parse input output)
// -------------------------------------------------------------------------------------------------------------------------------------------------
LookAhead parser input
	# maybe_parse				= parser input
	| isNothing maybe_parse		= Nothing
	# (input_left, result)		= fromJust maybe_parse
	= Just (input, result)

// -------------------------------------------------------------------------------------------------------------------------------------------------
Optional :: (Parser input output) output -> Parser input output
// -------------------------------------------------------------------------------------------------------------------------------------------------
Optional parser def
	=     parser
	  <|> Succeed def

// -------------------------------------------------------------------------------------------------------------------------------------------------
Pack :: [input] (Parser input output) [input] -> Parser input output | == input
// -------------------------------------------------------------------------------------------------------------------------------------------------
Pack before parser after 
	= (Token before) &> parser <& (Token after)

// -------------------------------------------------------------------------------------------------------------------------------------------------
Satisfy :: (input -> Bool) [input] -> Maybe (Parse input input)
// -------------------------------------------------------------------------------------------------------------------------------------------------
Satisfy pred [x:xs]
	| pred x					= Just (xs, x)
	| otherwise					= Nothing
Satisfy pred []
	= Nothing

// -------------------------------------------------------------------------------------------------------------------------------------------------
Symbol :: input [input] -> Maybe (Parse input input) | == input
// -------------------------------------------------------------------------------------------------------------------------------------------------
Symbol symbol [x:xs]
	| symbol == x				= Just (xs, x)
	| otherwise					= Nothing
Symbol symbol []
	= Nothing

// -------------------------------------------------------------------------------------------------------------------------------------------------
Succeed :: output [input] -> Maybe (Parse input output)
// -------------------------------------------------------------------------------------------------------------------------------------------------
Succeed result input
	= Just (input, result)

// -------------------------------------------------------------------------------------------------------------------------------------------------
Token :: [input] [input] -> Maybe (Parse input [input]) | == input
// -------------------------------------------------------------------------------------------------------------------------------------------------
Token token input
	# len						= length token
	| take len input == token	= Just (drop len input, token)
	| otherwise					= Nothing

// -------------------------------------------------------------------------------------------------------------------------------------------------
Until :: (Parser input output) (input -> Bool) [input] -> Maybe (Parse input output)
// -------------------------------------------------------------------------------------------------------------------------------------------------
Until parser pred input
	# (before, after)			= split input
	# mb_parse					= parser before
	| isNothing mb_parse		= Nothing
	# (input_left, output)		= fromJust mb_parse
	| isEmpty input_left		= Just (after, output)
	= Nothing
	where
		split [x:xs]
			| pred x			= ([], [x:xs])
			# (before, after)	= split xs
			= ([x:before], after)
		split []
			= ([], [])

// -------------------------------------------------------------------------------------------------------------------------------------------------
(<&>) infixr 6 :: (Parser input output1) (Parser input output2) -> Parser input (output1, output2)
// -------------------------------------------------------------------------------------------------------------------------------------------------
(<&>) parser1 parser2
	= new_parser
	where
		new_parser input
			# maybe_parse				= parser1 input
			| isNothing maybe_parse		= Nothing
			# (input, result1)			= fromJust maybe_parse
			# maybe_parse				= parser2 input
			| isNothing maybe_parse		= Nothing
			# (input, result2)			= fromJust maybe_parse
			= Just (input, (result1, result2))

// -------------------------------------------------------------------------------------------------------------------------------------------------
(<:&>) infixr 6 :: (Parser input output) (Parser input [output]) -> Parser input [output]
// -------------------------------------------------------------------------------------------------------------------------------------------------
(<:&>) parser1 parser2
	= (parser1 <&> parser2) <@ (\(x, y) -> [x:y])

// -------------------------------------------------------------------------------------------------------------------------------------------------
(<&) infixr 6 :: (Parser input output1) (Parser input output2) -> Parser input output1
// -------------------------------------------------------------------------------------------------------------------------------------------------
(<&) parser1 parser2
	= parser1 <&> parser2 <@ fst

// -------------------------------------------------------------------------------------------------------------------------------------------------
(&>) infixr 6 :: (Parser input output1) (Parser input output2) -> Parser input output2
// -------------------------------------------------------------------------------------------------------------------------------------------------
(&>) parser1 parser2
	= parser1 <&> parser2 <@ snd

// -------------------------------------------------------------------------------------------------------------------------------------------------
(<|>) infixl 4 :: (Parser input output) (Parser input output) -> Parser input output
// -------------------------------------------------------------------------------------------------------------------------------------------------
(<|>) parser1 parser2
	= new_parser
	where
		new_parser input
			# maybe_parse				= parser1 input
			| isJust maybe_parse		= maybe_parse
			= parser2 input

// -------------------------------------------------------------------------------------------------------------------------------------------------
<+> :: (Parser input output) [input] -> Maybe (Parse input [output])
// -------------------------------------------------------------------------------------------------------------------------------------------------
<+> parser input
	# maybe_parse				= parser input
	| isNothing maybe_parse		= Nothing
	# (input, result)			= fromJust maybe_parse
	# maybe_parse				= <*> parser input				// always succeeds
	# (input, results)			= fromJust maybe_parse
	= Just (input, [result:results])

// -------------------------------------------------------------------------------------------------------------------------------------------------
<*> :: (Parser input output) [input] -> Maybe (Parse input [output])
// -------------------------------------------------------------------------------------------------------------------------------------------------
<*> parser input
	# maybe_parse				= parser input
	| isNothing maybe_parse		= Just (input, [])
	# (input, result)			= fromJust maybe_parse
	# maybe_parse				= <*> parser input				// always succeeds
	# (input, results)			= fromJust maybe_parse
	= Just (input, [result:results])

// -------------------------------------------------------------------------------------------------------------------------------------------------
(<@) infixl 5 :: (Parser input output1) (output1 -> output2) -> Parser input output2
// -------------------------------------------------------------------------------------------------------------------------------------------------
(<@) parser f
	= new_parser
	where
		new_parser input
			# maybe_parse				= parser input
			| isNothing maybe_parse		= Nothing
			# (input, result)			= fromJust maybe_parse
			= Just (input, f result)