/*
** Program: Clean Prover System
** Module:  ParseTypes (.icl)
** 
** Author:  Maarten de Mol
** Created: 9 Januari 2001
*/

implementation module 
	ParseTypes

import
	StdEnv,
	StdMaybe,
	CoreTypes,
	Errors

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
	where DummyValue = PUnknownPtr

// -------------------------------------------------------------------------------------------------------------------------------------------------   
:: PAlgPattern =
// -------------------------------------------------------------------------------------------------------------------------------------------------   
	{ p_atpDataCons		:: ParsedPtr
	, p_atpExprVarScope	:: ![CName]
	, p_atpResult		:: !PExpr
	}
instance DummyValue PAlgPattern
	where DummyValue = {p_atpDataCons = DummyValue, p_atpExprVarScope = [], p_atpResult = DummyValue}

// -------------------------------------------------------------------------------------------------------------------------------------------------   
:: PBasicPattern =
// -------------------------------------------------------------------------------------------------------------------------------------------------   
	{ p_bapBasicValue	:: !PBasicValue
	, p_bapResult		:: !PExpr
	}
instance DummyValue PBasicPattern
	where DummyValue = {p_bapBasicValue = DummyValue, p_bapResult = DummyValue}

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
	where DummyValue = PBasicInteger 42

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: PCasePatterns =
// -------------------------------------------------------------------------------------------------------------------------------------------------
	  PAlgPatterns		![PAlgPattern]
	| PBasicPatterns 	![PBasicPattern]
instance DummyValue PCasePatterns
	where DummyValue = PAlgPatterns []

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
	where DummyValue = PBottom

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
	where DummyValue = PTrue

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: PQualifiedName =
// -------------------------------------------------------------------------------------------------------------------------------------------------
	{ quaModuleName		:: !Maybe CName
	, quaName			:: !CName
	}

// only simple types; higher order variables are not allowed (for now)
// -------------------------------------------------------------------------------------------------------------------------------------------------
:: PType =
// -------------------------------------------------------------------------------------------------------------------------------------------------
	  PTypeVar			!CName
	| PArrow			!PType !PType
	| PTApp				!ParsedPtr ![PType]
	| PBasic			!CBasicType














// -------------------------------------------------------------------------------------------------------------------------------------------------
instance == PQualifiedName
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	(==) name1 name2	= name1.quaModuleName == name2.quaModuleName && name1.quaName == name2.quaName

// Only checks equality of known pointers
// -------------------------------------------------------------------------------------------------------------------------------------------------
instance == ParsedPtr
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	(==) (PHeapPtr ptr1)	(PHeapPtr ptr2)			= ptr1 == ptr2
	(==) other1				other2					= False