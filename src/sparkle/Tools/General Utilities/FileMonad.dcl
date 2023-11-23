/*
** Program: Clean Prover System
** Module:  PolishRead (.dcl)
** 
** Author:  Maarten de Mol
** Created: 03 April 2001
*/

definition module
	FileMonad

import
	States

:: FileM state a
:: Dummy = Dummy
instance DummyValue Dummy

isValidIdChar			:: !Char -> Bool
isValidNameChar			:: !Char -> Bool

applyFileM				:: !String !String !String !Int !state !(FileM state a) !*PState -> (!Error, !a, !*PState) | DummyValue a
accStates				:: !(String Int Int state *PState -> (Error, a, state, *PState)) -> FileM state a

parseErrorM				:: !String -> FileM state a | DummyValue a
returnM					:: !a -> FileM state a
(>>=) infixl 6			:: !(FileM state a) !(a -> FileM state b) -> FileM state b | DummyValue b
(>>>) infixr 5			:: !(FileM state a) !(FileM state b) -> FileM state b | DummyValue b
mapM					:: !(a -> FileM state b) ![a] -> FileM state [b]
repeatM					:: !Int !(FileM state a) -> FileM state [a]
repeatUntilM			:: !String !(FileM state a) -> FileM state [a]

advanceLine				:: FileM state Dummy
checkAhead				:: !(Char -> Bool) !(FileM state a) !(FileM state a) -> FileM state a
eatSpaces				:: FileM state Dummy
ifEOF					:: !(FileM state a) !(FileM state a) -> FileM state a
lookAhead				:: ![(String, Bool, FileM state a)] !(FileM state a) -> FileM state a
lookAheadF				:: ![(String, FileM state a)] !(FileM state a) -> FileM state a
readBool				:: FileM state Bool
readCharacters			:: !Int -> FileM state String
readIdentifier			:: FileM state String
readName				:: !String -> FileM state String
readNumber				:: FileM state Int
readString				:: FileM state String
readToken				:: !String -> FileM state Dummy
readUntil				:: !String !Char -> FileM state String
readWhile				:: !(Char -> Bool) -> FileM state String
returnState				:: FileM state state
skipLine				:: FileM state Dummy

alignTo					:: !Int -> FileM state Dummy
writeIdentifier			:: !String -> FileM state Dummy
writeName				:: !CName -> FileM state Dummy
writeNumber				:: !Int -> FileM state Dummy
writeString				:: !String -> FileM state Dummy
writeToken				:: !String -> FileM state Dummy
