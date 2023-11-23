/*
** Program: Clean Prover System
** Module:  Errors (.dcl)
** 
** Author:  Maarten de Mol
** Created: 10 June 1999
*/

definition module 
   Errors

import 
   StdEnv,
   StdMaybe,
   ErrorHandler
   
:: Error :== HandlerError ErrorCode
:: ErrorCode =
	  X_CloseFile					!String
	| X_OpenFile					!String
	| X_WriteToFile					!String
	| X_FileCorrupt					!String
    
	| X_OpenModule					!String
	| X_OpenProject					!String
	| X_CompileModule				!String
	| X_ConvertModule				!String
	| X_BindModule					!String
	| X_CheckFunctionTypes			!String
	
	| X_RemoveModules				!String
	| X_RemoveSection				!String !String
	| X_RemoveTheorem				!String !String
	
	| X_Lexeme						!String
	| X_Parse						!String
	| X_Reduction					!String
	| X_Type						!String
	
	| X_ApplyTactic					!String !String

	| X_BindSectionSymbol			!String !String !String
	| X_BindSectionTheorem			!String !String !String
	| X_DuplicateTheoremName		!String !String
	| X_UnknownTheorem				!String !String !Int !String
	| X_UnknownExprVar				!String !String !Int !String
	| X_UnknownPropVar				!String !String !Int !String
	| X_UnknownHypothesis			!String !String !Int !String
	| X_ParseFile					!String !Int !Int !String
	| X_ApplySectionTactic			!String !String !Int !String
	| X_UnrecoveredError
    
	| X_Internal					!String
	| X_External					!String
	| X_Message						!String
	
	| X_I_Did_Nothing

ShortDescription	:: !ErrorCode -> String
LongDescription		:: !ErrorCode -> String

showError			:: !Error !*(PSt .ps) -> *PSt .ps
handleError			:: !Error ![String] !*(PSt .ps) -> (!String, !*PSt .ps)
correctError		:: !Error ![String] !*(PSt .ps) -> (!String, !*PSt .ps)

myCreateArray		:: {!a}

class    DummyValue a :: .a
instance DummyValue Bool
instance DummyValue Int
instance DummyValue Real
instance DummyValue Char
instance DummyValue [a]
instance DummyValue {.a}
instance DummyValue {!.a}
instance DummyValue {#Char}
instance DummyValue (Maybe a)
instance DummyValue (a, b)          | DummyValue a & DummyValue b
instance DummyValue (a, b, c)       | DummyValue a & DummyValue b & DummyValue c
instance DummyValue (a, b, c, d)    | DummyValue a & DummyValue b & DummyValue c & DummyValue d
//instance DummyValue (a, b, c, d, e) | DummyValue a & DummyValue b & DummyValue c & DummyValue d & DummyValue e
instance DummyValue (a -> b)        | DummyValue b