/*
** Program: Clean Prover System
** Module:  LTypes (.dcl)
** 
** Author:  Maarten de Mol
** Created: 19 July 2007
*/

definition module 
	LTypes

import
	CoreTypes,
	Heaps

// -------------------------------------------------------------------------------------------------------------------------------------------------   
:: LAlgPattern =
// -------------------------------------------------------------------------------------------------------------------------------------------------   
	{ lapDataCons				:: !HeapPtr
	, lapExprVarScope			:: ![CExprVarPtr]
	, lapResult					:: !LExpr
	}
instance DummyValue LAlgPattern
instance == LAlgPattern

// -------------------------------------------------------------------------------------------------------------------------------------------------   
:: LBasicPattern =
// -------------------------------------------------------------------------------------------------------------------------------------------------   
	{ lbpBasicValue				:: !LBasicValue
	, lbpResult					:: !LExpr
	}
instance DummyValue LBasicPattern
instance == LBasicPattern

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: LBasicValue = 
// -------------------------------------------------------------------------------------------------------------------------------------------------
	  LBasicInteger				!Int  
	| LBasicCharacter			!Char
	| LBasicRealNumber			!Real
	| LBasicBoolean				!Bool  
	| LBasicString				!String
	| LBasicArray				![LExpr]
instance DummyValue LBasicValue
instance == LBasicValue

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: LCasePatterns = 
// -------------------------------------------------------------------------------------------------------------------------------------------------
	  LAlgPatterns		!HeapPtr		![LAlgPattern]
	| LBasicPatterns 	!CBasicType		![LBasicPattern]
instance DummyValue LCasePatterns
instance == LCasePatterns

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: LConsInfo =
// -------------------------------------------------------------------------------------------------------------------------------------------------
	{ lciAnnotatedStrictVars	:: !LListOfBool
	}
instance DummyValue LConsInfo

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: LExpr = 
// -------------------------------------------------------------------------------------------------------------------------------------------------
	  LExprVar					!CExprVarPtr !(Maybe LLetDefPtr)
	| LBasicValue				!LBasicValue
	| LSymbol					!LSymbolKind !HeapPtr !LNrMissingArguments ![LExpr]
	| LApp						!LExpr !LExpr
	| LCase						!LExpr !LCasePatterns !(Maybe LExpr)
	| LLazyLet					![LLetDefPtr] !LExpr
	| LStrictLet				!CExprVarPtr !LLetDefPtr !LExpr !LExpr
	| LBottom
instance DummyValue LExpr
instance == LExpr

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: LFunInfo =
// -------------------------------------------------------------------------------------------------------------------------------------------------
	{ lfiAnnotatedStrictVars	:: !LListOfBool
	, lfiCaseVars				:: !LListOfBool
	, lfiStrictVars				:: !LListOfBool
	}
instance DummyValue LFunInfo

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: LLetDef =
// -------------------------------------------------------------------------------------------------------------------------------------------------
	  LLetDef					!CExprVarPtr !LMayUnravel !LExpr
	| LStrictLetDef

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: LSymbolKind
// -------------------------------------------------------------------------------------------------------------------------------------------------
	= LCons						!LConsInfo
	| LFun						!LFunInfo
	| LFieldSelector			!Int
instance DummyValue LSymbolKind

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: LLetDefPtr					:== Ptr LLetDef
:: LMayUnravel					:== Bool
:: LName						:== String
:: LNrMissingArguments			:== Int
:: LListOfBool					:== Int					// bitwise representation of list of bools
LTotal							:== 0
// -------------------------------------------------------------------------------------------------------------------------------------------------

convertC2L						:: !c !*CHeaps !*CProject -> (!l, !*CHeaps, !*CProject) | convertCL c l
convertL2C						:: !l !*CHeaps !*CProject -> (!c, !*CHeaps, !*CProject) | convertCL c l

:: ConvTable
// -------------------------------------------------------------------------------------------------------------------------------------------------
class convertCL c l
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	toC			:: !l !ConvTable !*CHeaps !*CProject -> (!c, !*CHeaps, !*CProject)
	toL			:: !c !ConvTable !*CHeaps !*CProject -> (!l, !*CHeaps, !*CProject)

instance convertCL [c]				[l]					| convertCL c l
instance convertCL (Maybe c)		(Maybe l)			| convertCL c l
instance convertCL CAlgPatternH		LAlgPattern
instance convertCL CBasicPatternH	LBasicPattern
instance convertCL CBasicValueH		LBasicValue
instance convertCL CCasePatternsH	LCasePatterns
instance convertCL CExprH			LExpr

// -------------------------------------------------------------------------------------------------------------------------------------------------
class lSubst l
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	lSubst :: ![(CExprVarPtr,LExpr)] !l !*CHeaps -> (!l, !*CHeaps)

instance lSubst [l]				| lSubst l
instance lSubst (Maybe l)		| lSubst l
instance lSubst LAlgPattern
instance lSubst LBasicPattern
instance lSubst LBasicValue
instance lSubst LCasePatterns
instance lSubst LExpr
instance lSubst LLetDef
instance lSubst LLetDefPtr

lDependentSubst :: ![CExprVarPtr] ![LExpr] !x !*CHeaps -> (!x, !*CHeaps) | lSubst x

// -------------------------------------------------------------------------------------------------------------------------------------------------
class lFresh l
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	lFresh :: ![(CExprVarPtr,CExprVarPtr)] !l !*CHeaps -> (!l, !*CHeaps)

instance lFresh [l]				| lFresh l
instance lFresh (Maybe l)		| lFresh l
instance lFresh LAlgPattern
instance lFresh LBasicPattern
instance lFresh LBasicValue
instance lFresh LCasePatterns
instance lFresh LExpr
instance lFresh LLetDef
instance lFresh LLetDefPtr

// -------------------------------------------------------------------------------------------------------------------------------------------------
class lShow l
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	lShow :: !l !*CHeaps !*CProject -> (!String, !*CHeaps, !*CProject)

instance lShow [l]				| lShow l
instance lShow (Maybe l)		| lShow l
instance lShow LBasicValue
instance lShow LExpr

// -------------------------------------------------------------------------------------------------------------------------------------------------
class lCount l
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	lCount :: ![CExprVarPtr] !l !*(![Int], !*CHeaps) -> (![Int], !*CHeaps)

instance lCount [l]				| lCount l
instance lCount (Maybe l)		| lCount l
instance lCount LAlgPattern
instance lCount LBasicPattern
instance lCount LBasicValue
instance lCount LCasePatterns
instance lCount LExpr
instance lCount LLetDef

// ------------------------------------------------------------------------------------------------------------------------
class lUnshareVars l
// ------------------------------------------------------------------------------------------------------------------------
where
	lUnshareVars :: !VarLocation !CExprVarPtr !LExpr !l !*CHeaps -> (!Int, !VarLocation, !l, !*CHeaps)

instance lUnshareVars [l]				| lUnshareVars l
instance lUnshareVars (Maybe l)			| lUnshareVars l
instance lUnshareVars LAlgPattern
instance lUnshareVars LBasicPattern
instance lUnshareVars LBasicValue
instance lUnshareVars LCasePatterns
instance lUnshareVars LExpr
instance lUnshareVars LLetDef



makeApp							:: !LExpr ![LExpr] -> LExpr
//makeStrictness					:: ![CTypeH] -> LStrictness