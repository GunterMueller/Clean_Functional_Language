/*
** Program: Clean Prover System
** Module:  LexicalCombinators (.dcl)
** 
** Author:  Maarten de Mol
** Created: 11 September 2000
*/

definition module 
   LexicalCombinators

import 
   StdEnv

/*

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: ParseState input output	:== ([input], output)
:: Parser input output		:== [input] -> [ParseState input output]
// -------------------------------------------------------------------------------------------------------------------------------------------------

// -------------------------------------------------------------------------------------------------------------------------------------------------
AnySymbol		:: Parser a a
//Just			:: (Parser a b) -> Parser a b
LookAhead		:: (Parser a b) -> Parser a b
Pack			:: a (Parser a a) a -> Parser a a | == a
Satisfy			:: (a -> Bool) -> Parser a a
Symbol			:: a -> Parser a a | == a
Succeed			:: b -> Parser a b
Token			:: [a] -> Parser a [a] | == a
// -------------------------------------------------------------------------------------------------------------------------------------------------

// -------------------------------------------------------------------------------------------------------------------------------------------------
(<&>) infixr 6		:: (Parser a b) (Parser a c) -> Parser a (b, c)
(<:&>) infixr 6		:: (Parser a b) (Parser a [b]) -> (Parser a [b])
(<&) infixr 6		:: (Parser a b) (Parser a c) -> Parser a b
(&>) infixr 6		:: (Parser a b) (Parser a c) -> Parser a c
(<|>) infixl 4		:: (Parser a b) (Parser a b) -> Parser a b
(<!>) infixl 4		:: (Parser a b) (Parser a b) -> Parser a b
<*>					:: (Parser a b) -> Parser a [b]
<+>					:: (Parser a b) -> Parser a [b]
(<@)				infixl 5 :: (Parser a b) (b -> c) -> Parser a c
(<:)				infixl 5 :: (Parser a b) c -> Parser a c
// -------------------------------------------------------------------------------------------------------------------------------------------------

*/