/*
** Program: Clean Prover System
** Module:  ParseTypes (.icl)
** 
** Author:  Maarten de Mol
** Created: 9 Januari 2001
*/

definition module 
	ParseTypes

import
	StdEnv,
	StdMaybe,
	Errors,
	CoreTypes

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: ParsedPtr =
// -------------------------------------------------------------------------------------------------------------------------------------------------
	  PHeapPtr			!HeapPtr
	| PInfixPtr			!HeapPtr
	| PNamedPtr			!PQualifiedName
	| PBuildRecord		!(Maybe PQualifiedName) ![CName]
	| PSelectField		!PQualifiedName
	| PSelectIndex
	| PUnknownPtr
instance DummyValue ParsedPtr
instance == ParsedPtr

// -------------------------------------------------------------------------------------------------------------------------------------------------   
:: PAlgPattern =
// -------------------------------------------------------------------------------------------------------------------------------------------------   
	{ p_atpDataCons		:: ParsedPtr
	, p_atpExprVarScope	:: ![CName]
	, p_atpResult		:: !PExpr
	}
instance DummyValue PAlgPattern

// -------------------------------------------------------------------------------------------------------------------------------------------------   
:: PBasicPattern =
// -------------------------------------------------------------------------------------------------------------------------------------------------   
	{ p_bapBasicValue	:: !PBasicValue
	, p_bapResult		:: !PExpr
	}
instance DummyValue PBasicPattern

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: PBasicValue = 
// -------------------------------------------------------------------------------------------------------------------------------------------------
	  PBasicInteger		!Int  
	| PBasicCharacter	!Char
	| PBasicRealNumber	!Real
	| PBasicBoolean		!Bool  
	| PBasicString		!String
	| PBasicArray		![PExpr]
instance DummyValue PBasicValue

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: PCasePatterns =
// -------------------------------------------------------------------------------------------------------------------------------------------------
	  PAlgPatterns		![PAlgPattern]
	| PBasicPatterns 	![PBasicPattern]
instance DummyValue PCasePatterns

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: PExpr = 
// -------------------------------------------------------------------------------------------------------------------------------------------------
	  PExprVar			!CName
	| PApp				!PExpr !.[PExpr]
	| PSymbol			!ParsedPtr ![PExpr]
	| PLet				!CIsStrict ![(CName, PExpr)] !PExpr
	| PCase				!PExpr !PCasePatterns !(Maybe PExpr)
	| PBasicValue		!PBasicValue
	| PBottom
	| PBracketExpr		!PExpr
instance DummyValue PExpr

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: PProp =
// -------------------------------------------------------------------------------------------------------------------------------------------------
	  PTrue
	| PFalse
	| PPropVar			!CName
	| PEqual			!PExpr !PExpr
	| PNot				!PProp
	| PAnd				!PProp !PProp
	| POr				!PProp !PProp
	| PImplies			!PProp !PProp
	| PIff				!PProp !PProp
	| PExprForall		!CName !(Maybe PType) !PProp
	| PExprExists		!CName !(Maybe PType) !PProp
	| PPropForall		!CName !PProp
	| PPropExists		!CName !PProp
	| PPredicate		!ParsedPtr ![PExpr]
	| PBracketProp		!PProp
instance DummyValue PProp

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: PQualifiedName =
// -------------------------------------------------------------------------------------------------------------------------------------------------
	{ quaModuleName		:: !Maybe CName
	, quaName			:: !CName
	}
instance == PQualifiedName

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: PType =
// -------------------------------------------------------------------------------------------------------------------------------------------------
	  PTypeVar			!CName
	| PArrow			!PType !PType
	| PTApp				!ParsedPtr ![PType]
	| PBasic			!CBasicType