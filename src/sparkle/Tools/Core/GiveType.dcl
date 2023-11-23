/*
** Program: Clean Prover System
** Module:  CoreTypes (.dcl)
** 
** Author:  Maarten de Mol
** Created: 22 August 2000
*/

definition module 
	GiveType

import
	StdEnv,
	CoreTypes,
	Operate

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: TypingInfo =
// -------------------------------------------------------------------------------------------------------------------------------------------------
	{ tiNextIndex		:: !Int
	, tiUnify			:: ![(CTypeVarPtr, CTypeH)]
	, tiSymbolTypes		:: ![CSymbolTypeH]				// used in bindLexeme only!
	, tiEqualType		:: !CTypeVarPtr					// used when e1=e2 must be typed
	}
instance DummyValue TypingInfo

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: TypingInfoP =
// -------------------------------------------------------------------------------------------------------------------------------------------------
	{ tpNextIndex		:: !Int
	, tpUnify			:: ![(CName, CType CName)]
	, tpSymbolTypes		:: ![CSymbolType CName]				// used in bindLexeme only!
	}
makePrintableI :: !TypingInfo !*CHeaps !*CProject -> (!TypingInfoP, !*CHeaps, !*CProject)

class unify a :: !a !a -> (!Bool, ![(CTypeVarPtr, CTypeH)])
instance unify [a] | unify a
instance unify (CType HeapPtr)

adjustSymbolType	:: !Int !CSymbolTypeH -> CSymbolTypeH
solveUnification	:: !TypingInfo -> (!Bool, !Substitution)

typeExpr			:: !CExprH !*CHeaps !*CProject -> (!Error, !(!TypingInfo, !CTypeH), !*CHeaps, !*CProject)
typeProp			:: !CPropH ![(CName, CTypeH)] !*CHeaps !*CProject -> (!Error, !TypingInfo, !*CHeaps, !*CProject)
wellTyped			:: !Goal !*CHeaps !*CProject -> (!Error, !Substitution, !TypingInfo, !*CHeaps, !*CProject)
typeExprInGoal		:: !CExprH !Goal !*CHeaps !*CProject -> (!Error, !(!TypingInfo, !CTypeH), !*CHeaps, !*CProject)
typePropInGoal		:: !CPropH !Goal ![(CName, CTypeH)] !*CHeaps !*CProject -> (!Error, !TypingInfo, !*CHeaps, !*CProject)
