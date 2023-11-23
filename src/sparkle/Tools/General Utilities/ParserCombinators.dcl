/*
** Program: Clean Prover System
** Module:  ParserCombinators (.dcl)
** 
** Author:  Maarten de Mol
** Created: 11 September 2000
*/

definition module 
   ParserCombinators

import 
   StdEnv,
   StdMaybe
       
// -------------------------------------------------------------------------------------------------------------------------------------------------
:: Parse input output		:== ([input], output)
:: Parser input output		:== [input] -> Maybe (Parse input output)
// -------------------------------------------------------------------------------------------------------------------------------------------------

AnySymbol		:: [input] -> Maybe (Parse input input)
LookAhead		:: (Parser input output) [input] -> Maybe (Parse input output)
List			:: [input] (Parser input output) -> Parser input [output] | == input
Optional		:: (Parser input output) output -> Parser input output
Pack			:: [input] (Parser input output) [input] -> Parser input output | == input
Satisfy			:: (input -> Bool) [input] -> Maybe (Parse input input)
Symbol			:: input [input] -> Maybe (Parse input input) | == input
Succeed			:: output [input] -> Maybe (Parse input output)
Token			:: [input] [input] -> Maybe (Parse input [input]) | == input
Until			:: (Parser input output) (input -> Bool) [input] -> Maybe (Parse input output)

(<&>) infixr 6		:: (Parser input output1) (Parser input output2) -> Parser input (output1, output2)
(<:&>) infixr 6		:: (Parser input output) (Parser input [output]) -> Parser input [output]
(<&) infixr 6		:: (Parser input output1) (Parser input output2) -> Parser input output1
(&>) infixr 6		:: (Parser input output1) (Parser input output2) -> Parser input output2
(<|>) infixl 4		:: (Parser input output) (Parser input output) -> Parser input output
<+>					:: (Parser input output) [input] -> Maybe (Parse input [output])
<*>					:: (Parser input output) [input] -> Maybe (Parse input [output])
(<@) infixl 5		:: (Parser input output1) (output1 -> output2) -> Parser input output2
