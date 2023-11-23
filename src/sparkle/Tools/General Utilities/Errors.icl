/*
** Program: Clean Prover System
** Module:  Errors (.icl)
** 
** Author:  Maarten de Mol
** Created: 10 June 1999
*/

implementation module 
   Errors

import 
   StdEnv,
   StdMaybe,
   ErrorHandler,
   StdDebug
   
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
    
// -------------------------------------------------------------------------------------------------------------------------------------------------
showError :: !Error !*(PSt .ps) -> *PSt .ps
// -------------------------------------------------------------------------------------------------------------------------------------------------
showError error pstate
	= snd (ErrorHandler ShortDescription LongDescription True error ["OK"] pstate)

// -------------------------------------------------------------------------------------------------------------------------------------------------
handleError :: !Error ![String] !*(PSt .ps) -> (!String, !*PSt .ps)
// -------------------------------------------------------------------------------------------------------------------------------------------------
handleError error buttons pstate
	= ErrorHandler ShortDescription LongDescription True error buttons pstate

// -------------------------------------------------------------------------------------------------------------------------------------------------
correctError :: !Error ![String] !*(PSt .ps) -> (!String, !*PSt .ps)
// -------------------------------------------------------------------------------------------------------------------------------------------------
correctError error buttons pstate
	= ErrorHandler ShortDescription LongDescription False error buttons pstate

// -------------------------------------------------------------------------------------------------------------------------------------------------
ShortDescription :: !ErrorCode -> String
// -------------------------------------------------------------------------------------------------------------------------------------------------
ShortDescription (X_ApplyTactic name msg)          = "Unable to apply tactic '" +++ name +++ "'."
ShortDescription (X_CloseFile filename)            = "Unable to close file '" +++ filename +++ "'."
ShortDescription (X_OpenFile filename)             = "Unable to open file '" +++ filename +++ "'."
ShortDescription (X_WriteToFile filename)          = "Unable to write to file '" +++ filename +++ "'."
ShortDescription (X_FileCorrupt filename)          = "The file '" +++ filename +++ "' is corrupt."
ShortDescription (X_OpenModule modulename)         = "Unable to open the module '" +++ modulename +++ "'."
ShortDescription (X_OpenProject projectname)       = "Unable to open the project '" +++ (TruncPath projectname) +++ "'."
ShortDescription (X_CompileModule modulename)      = "Unable to compile the module '" +++ modulename +++ "'."
ShortDescription (X_ConvertModule modulename)      = "Unable to convert compiled module '" +++ modulename +++ "' to internal representation."
ShortDescription (X_BindModule modname)   			= "Unable to bind definitions of module '" +++ modname +++ "' to existing project."
ShortDescription (X_CheckFunctionTypes defname)		= "Not all occuring functions could be typed. (no type for '" +++ defname +++ "')."
ShortDescription (X_RemoveModules cause)			= "Unable to remove module(s)."
ShortDescription (X_RemoveSection name cause)		= "Unable to remove section " +++ name +++ "."
ShortDescription (X_RemoveTheorem name cause)		= "Unable to remove theorem " +++ name +++ "."
ShortDescription (X_Lexeme details)					= "Unable to filter string into list of lexemes."
ShortDescription (X_Parse details)					= "Unable to parse lexemes."
ShortDescription (X_ParseFile file nr1 nr2 _)		= "Parse error in '" +++ file +++ "' on line " +++ (toString nr1) +++ " (char " +++ (toString nr2) +++ ")."
ShortDescription (X_BindSectionSymbol name _ _)		= "Dependency check failure for section '" +++ name +++ "'."
ShortDescription (X_BindSectionTheorem name _ _)	= "Dependency check failure for section '" +++ name +++ "'."
ShortDescription (X_DuplicateTheoremName name _)	= "Name check failure for section '" +++ name +++ "'."
ShortDescription (X_UnknownTheorem file _ nr _)		= "Bind error in '" +++ file +++ "' on line " +++ (toString nr) +++ "."
ShortDescription (X_UnknownExprVar file _ nr _)		= "Bind error in '" +++ file +++ "' on line " +++ (toString nr) +++ "."
ShortDescription (X_UnknownPropVar file _ nr _)		= "Bind error in '" +++ file +++ "' on line " +++ (toString nr) +++ "."
ShortDescription (X_UnknownHypothesis file _ nr _)	= "Bind error in '" +++ file +++ "' on line " +++ (toString nr) +++ "."
ShortDescription (X_ApplySectionTactic file _ nr _)	= "Check error in '" +++ file +++ "' on line " +++ (toString nr) +++ "."
ShortDescription (X_Reduction details)				= "Error while trying to reduce expression to root-normal-form."
ShortDescription (X_Type details)					= "Typing error."
ShortDescription (X_Internal routine)              = "{Internal error} " +++ routine +++ "."
ShortDescription (X_External msg)                  = "*** " +++ msg
ShortDescription (X_Message msg)					= msg
ShortDescription X_I_Did_Nothing				 	= "X_I_Did_Nothing"

// -------------------------------------------------------------------------------------------------------------------------------------------------
LongDescription :: !ErrorCode -> String
// -------------------------------------------------------------------------------------------------------------------------------------------------
LongDescription (X_ApplyTactic _ details)			= details
LongDescription (X_OpenProject filename)			= "Loading of the project belonging to '" +++ filename +++ "' failed. " +++
                                                      "The project-file may be corrupt, or one of the modules in the project could not be compiled successfully."
LongDescription (X_RemoveModules cause)				= cause
LongDescription (X_RemoveSection name cause)		= cause
LongDescription (X_RemoveTheorem name cause)		= cause
LongDescription (X_Lexeme details)					= details
LongDescription (X_Parse details)					= details
LongDescription (X_ParseFile _ _ _ cause)			= cause
LongDescription (X_BindSectionSymbol _ name type)	= "Unable to find symbol '" +++ name +++ "' of type '" +++ type +++ "'."
LongDescription (X_BindSectionTheorem _ name sname)	= "Unable to find theorem '" +++ name +++ "' (expected in section '" +++ sname +++ "')."
LongDescription (X_DuplicateTheoremName _ name)		= "Duplicate theorem named '" +++ name +++ "'."
LongDescription (X_UnknownTheorem _ n1 _ n2)		= "Undefined theorem '" +++ n2 +++ "' in proof script of theorem '" +++ n1 +++ "'."
LongDescription (X_UnknownExprVar _ n1 _ n2)		= "Undefined expression variable '" +++ n2 +++ "' in proof script of theorem '" +++ n1 +++ "'."
LongDescription (X_UnknownPropVar _ n1 _ n2)		= "Undefined proposition variable '" +++ n2 +++ "' in proof script of theorem '" +++ n1 +++ "'."
LongDescription (X_UnknownHypothesis _ n1 _ n2)		= "Undefined hypothesis '" +++ n2 +++ "' in proof script of theorem '" +++ n1 +++ "'."
LongDescription (X_ApplySectionTactic _ n1 _ n2)	= "Could not apply tactic '" +++ n2 +++ "' in proof script of theorem '" +++ n1 +++ "'."
LongDescription (X_Reduction details)				= details
LongDescription (X_Type details)					= details
LongDescription _									= ""

// -------------------------------------------------------------------------------------------------------------------------------------------------   
class    DummyValue a          :: .a
// -------------------------------------------------------------------------------------------------------------------------------------------------   

myCreateArray :: {!a}
myCreateArray
	=: {}

myCreateArray2 :: {!.a}
myCreateArray2
	= code {
		.d 0 0
		jmp	e_Errors_smyCreateArray
	}


// -------------------------------------------------------------------------------------------------------------------------------------------------   
instance DummyValue Bool       where DummyValue = True
instance DummyValue Int        where DummyValue = 0
instance DummyValue Real       where DummyValue = 0.0
instance DummyValue Char       where DummyValue = '0'
instance DummyValue [a]        where DummyValue = []
instance DummyValue {.a}       where DummyValue = {}
instance DummyValue {!.a}      where DummyValue = myCreateArray2
instance DummyValue {#Char}    where DummyValue = {}
instance DummyValue (Maybe a)  where DummyValue = Nothing

instance DummyValue (a, b) | DummyValue a & DummyValue b
   where DummyValue = (DummyValue, DummyValue)

instance DummyValue (a, b, c) | DummyValue a & DummyValue b & DummyValue c
   where DummyValue = (DummyValue, DummyValue, DummyValue)

instance DummyValue (a -> b) | DummyValue b
   where DummyValue = \x -> DummyValue

instance DummyValue (a, b, c, d) | DummyValue a & DummyValue b & DummyValue c & DummyValue d
   where DummyValue = (DummyValue, DummyValue, DummyValue, DummyValue)

//instance DummyValue (a, b, c, d, e) | DummyValue a & DummyValue b & DummyValue c & DummyValue d & DummyValue e
//   where DummyValue = (DummyValue, DummyValue, DummyValue, DummyValue, DummyValue)