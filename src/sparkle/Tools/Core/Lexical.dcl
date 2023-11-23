/*
** Program: Clean Prover System
** Module:  Lexical (.dcl)
** 
** Author:  Maarten de Mol
** Created: 11 September 2000
*/

definition module 
	Lexical

import
	StdEnv,
	Errors

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
instance == CLexeme

fromBoolDenotation		:: CLexeme -> Bool
fromCharDenotation		:: CLexeme -> Char
fromCharListDenotation	:: CLexeme -> [Char]
fromIdentifier			:: CLexeme -> String
fromIntDenotation		:: CLexeme -> Int
fromRealDenotation		:: CLexeme -> Real
fromStringDenotation	:: CLexeme -> String

CAnyBoolDenotation		:== CBoolDenotation True
CAnyCharDenotation		:== CCharDenotation 'a'
CAnyCharListDenotation	:== CCharListDenotation ['Hallo']
CAnyIdentifier			:== CIdentifier ""
CAnyIntDenotation		:== CIntDenotation 42
CAnyRealDenotation		:== CRealDenotation 0.0
CAnyStringDenotation	:== CStringDenotation "Hallo"

isWord :: !String !CLexeme -> Bool

parseLexemes			:: !String -> (!Error, ![CLexeme])
parseListLexemes		:: ![Char] -> (!Error, ![CLexeme])