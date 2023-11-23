/*
** Program: Clean Prover System
** Module:  Operate (.dcl)
** 
** Author:  Maarten de Mol
** Created: 29 November 2000
*/

definition module 
	Operate

import
	StdEnv,
	CoreTypes,
	ProveTypes,
	Heaps

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: FindLocations =
// -------------------------------------------------------------------------------------------------------------------------------------------------
	{ findVars					:: !Bool
	, findCases					:: !Bool
	, findLets					:: !Bool
	, findKinds					:: ![DefinitionKind]
	}
instance DummyValue FindLocations

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: MatchPassed =
// -------------------------------------------------------------------------------------------------------------------------------------------------
	{ mpExprVars				:: ![CExprVarPtr]			// bind FORALL to free occurence
	, mpPropVars				:: ![CPropVarPtr]			// bind FORALL to free occurence
	, mpAlphaExprVars			:: ![CExprVarPtr]			// bind FORALL to bound occurence
	, mpAlphaPropVars			:: ![CPropVarPtr]			// bind FORALL to bound occurence
	, mpAdditionalArguments		:: ![CExprH]				// used to rewrite (reverse2 = reverse) in (reverse2 x = reverse x)
	}

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: Choice a b
// -------------------------------------------------------------------------------------------------------------------------------------------------
	= Either				a
	| Or					b

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: PtrInfo =
// -------------------------------------------------------------------------------------------------------------------------------------------------
	{ freeExprVars			:: ![CExprVarPtr]
	, freePropVars			:: ![CPropVarPtr]
	, freeTypeVars			:: ![CTypeVarPtr]
	, boundExprVars			:: ![CExprVarPtr]
	, boundPropVars			:: ![CPropVarPtr]
	, boundTypeVars			:: ![CTypeVarPtr]
	, sharedExprs			:: ![CSharedPtr]
	}
instance DummyValue PtrInfo

// -------------------------------------------------------------------------------------------------------------------------------------------------   
:: Substitution = 
// -------------------------------------------------------------------------------------------------------------------------------------------------   
	{ subExprVars			:: ![(CExprVarPtr, CExprH)]
	, subPropVars			:: ![(CPropVarPtr, CPropH)]
	, subTypeVars			:: ![(CTypeVarPtr, CTypeH)]
	}
instance DummyValue Substitution

generateTypeName :: !Int -> (!CName, !Int)

:: Passed
class alphaEqual a :: !a !a !*Passed !*CHeaps -> (!Bool, !*Passed, !*CHeaps)
instance alphaEqual [a] | alphaEqual a
instance alphaEqual (Maybe a) | alphaEqual a
instance alphaEqual (Ptr a) | ReflexivePointer a
instance alphaEqual (CAlgPattern HeapPtr)
instance alphaEqual (CBasicPattern HeapPtr)
instance alphaEqual (CBasicValue HeapPtr)
instance alphaEqual (CCasePatterns HeapPtr)
instance alphaEqual (CExpr HeapPtr)
instance alphaEqual (CProp HeapPtr)
AlphaEqual :: !a !a !*CHeaps -> (!Bool, !*CHeaps) | alphaEqual a

class fresh a :: !Int !a !*CHeaps -> (!Int, !a, !*CHeaps)
instance fresh [a] | fresh a
instance fresh (CClassRestriction HeapPtr)
instance fresh (CSymbolType HeapPtr)
instance fresh (CType HeapPtr)

class freshVars a :: !a !*CHeaps -> (![CExprVarPtr], ![CPropVarPtr], !a, !*CHeaps)
instance freshVars [a] | freshVars a
instance freshVars (Maybe a) | freshVars a
instance freshVars (Ptr a) | freshVars,Pointer a
instance freshVars (CExpr HeapPtr)
instance freshVars (CProp HeapPtr)
instance freshVars Goal
instance freshVars Hypothesis
FreshVars :: !a !*CHeaps -> (!a, !*CHeaps) | freshVars a

class getPtrInfo a :: !a !PtrInfo !*CHeaps -> (!PtrInfo, !*CHeaps)
instance getPtrInfo [a] | getPtrInfo a
instance getPtrInfo (Maybe a) | getPtrInfo a
instance getPtrInfo (Ptr a) | getPtrInfo,Pointer a
instance getPtrInfo (CAlgPattern a)
instance getPtrInfo (CBasicPattern a)
instance getPtrInfo (CBasicValue a)
instance getPtrInfo (CCasePatterns a)
instance getPtrInfo (CExpr a)
instance getPtrInfo Goal
instance getPtrInfo Hypothesis
instance getPtrInfo (CProp a)
instance getPtrInfo (CType a)
GetPtrInfo :: !a !*CHeaps -> (!PtrInfo, !*CHeaps) | getPtrInfo a
MakeUniqueNames :: !PtrInfo !*CHeaps -> (!Bool, !*CHeaps)

class removeStrictness a :: !a -> a
instance removeStrictness [a] | removeStrictness a
instance removeStrictness (CSymbolType a)
instance removeStrictness (CType a)

class safeSubst a :: ![CSharedPtr] !a !*CHeaps -> (![CSharedPtr], !a, !*CHeaps)
instance safeSubst [a] | safeSubst a
instance safeSubst (Maybe a) | safeSubst a
instance safeSubst (Ptr a) | safeSubst,Pointer a
instance safeSubst (CAlgPattern HeapPtr)
instance safeSubst (CBasicPattern HeapPtr)
instance safeSubst (CBasicValue HeapPtr)
instance safeSubst (CCasePatterns HeapPtr)
instance safeSubst (CExpr HeapPtr)
instance safeSubst (CProp HeapPtr)
instance safeSubst (CType HeapPtr)
instance safeSubst Goal
instance safeSubst Hypothesis
SafeSubst :: !Substitution !a !*CHeaps -> (!a, !*CHeaps) | safeSubst a

class unsafeSubst a :: !a !*CHeaps -> (!a, !*CHeaps)
instance unsafeSubst [a] | unsafeSubst a
instance unsafeSubst (Maybe a) | unsafeSubst a
instance unsafeSubst (Ptr a) | unsafeSubst,Pointer a
instance unsafeSubst (CAlgPattern HeapPtr)
instance unsafeSubst (CBasicPattern HeapPtr)
instance unsafeSubst (CBasicValue HeapPtr)
instance unsafeSubst (CCasePatterns HeapPtr)
instance unsafeSubst (CExpr HeapPtr)
instance unsafeSubst (CProp HeapPtr)
instance unsafeSubst (CType HeapPtr)
instance unsafeSubst Hypothesis
UnsafeSubst :: !Substitution !a !*CHeaps -> (!a, !*CHeaps) | unsafeSubst a

class SimpleSubst a :: !Substitution !a -> a
instance SimpleSubst [a] | SimpleSubst a
instance SimpleSubst (CClassRestriction HeapPtr)
instance SimpleSubst (CSymbolType HeapPtr)
instance SimpleSubst (CType HeapPtr)

class match a :: !MatchPassed !a !a !*CHeaps -> (!Bool, !MatchPassed, !*CHeaps)
instance match [a] | match a
instance match (Maybe a) | match a
instance match (CAlgPattern HeapPtr)
instance match (CBasicPattern HeapPtr)
instance match (CBasicValue HeapPtr)
instance match (CCasePatterns HeapPtr)
instance match (CExpr HeapPtr)
instance match (CProp HeapPtr)
Match :: ![CExprVarPtr] ![CPropVarPtr] !a !a !*CHeaps -> (!Bool, !Substitution, ![CExprH], ![CExprVarPtr], ![CPropVarPtr], !*CHeaps) | match a

:: RewriteState
class rewriteProp a :: !a !CPropH !CPropH !RewriteState !*CHeaps -> (!a, !RewriteState, !*CHeaps)
instance rewriteProp (CProp HeapPtr)
RewriteProp :: !a !Redex ![CExprVarPtr] ![CPropVarPtr] !CPropH !CPropH !*CHeaps -> (!Bool, ![Substitution], !a, !*CHeaps) | rewriteProp a

class rewriteExpr a :: !a !CExprH !CExprH !RewriteState !*CHeaps -> (!a, !RewriteState, !*CHeaps)
instance rewriteExpr [a] | rewriteExpr a
instance rewriteExpr (Maybe a) | rewriteExpr a
instance rewriteExpr (CAlgPattern HeapPtr)
instance rewriteExpr (CBasicPattern HeapPtr)
instance rewriteExpr (CBasicValue HeapPtr)
instance rewriteExpr (CCasePatterns HeapPtr)
instance rewriteExpr (CExpr HeapPtr)
instance rewriteExpr (CProp HeapPtr)
RewriteExpr :: !a !Redex ![CExprVarPtr] ![CPropVarPtr] !CExprH !CExprH !*CHeaps -> (!Bool, ![Substitution], !a, !*CHeaps) | rewriteExpr a

class replaceExpr a :: !a !CExprH !CExprH !*CHeaps -> (!Bool, !a, !*CHeaps)
instance replaceExpr [a] | replaceExpr a
instance replaceExpr (Maybe a) | replaceExpr a
instance replaceExpr (Ptr a) | Pointer, replaceExpr a
instance replaceExpr (CAlgPattern HeapPtr)
instance replaceExpr (CBasicPattern HeapPtr)
instance replaceExpr (CBasicValue HeapPtr)
instance replaceExpr (CCasePatterns HeapPtr)
instance replaceExpr (CExpr HeapPtr)
instance replaceExpr (CProp HeapPtr)
instance replaceExpr Hypothesis
instance replaceExpr Goal

class replaceProp a :: !a !CPropH !CPropH !*CHeaps -> (!Bool, !a, !*CHeaps)
instance replaceProp (CProp HeapPtr)

class getUsedSymbols a :: !a !*CHeaps -> (![HeapPtr], !*CHeaps)
instance getUsedSymbols (CExpr HeapPtr)
instance getUsedSymbols (CProp HeapPtr)
GetUsedSymbols :: !a !*CHeaps -> (![HeapPtr], !*CHeaps) | getUsedSymbols a

class isUsing a :: !a ![String] !*CHeaps !*CProject -> (![String], !*CHeaps, !*CProject)
instance isUsing (CExpr HeapPtr)
instance isUsing (CProp HeapPtr)
IsUsing :: !a ![String] !*CHeaps !*CProject -> (!Bool, !*CHeaps, !*CProject) | isUsing a

class removeDictSelections a :: !a !*CHeaps !*CProject -> (!a, !*CHeaps, !*CProject)
instance removeDictSelections (CExpr HeapPtr)

class getExprLocations a :: !FindLocations !a ![(CName, Int)] !*CHeaps !*CProject -> (![(CName, Int)], !*CHeaps, !*CProject)
instance getExprLocations (CExpr HeapPtr)
instance getExprLocations (CProp HeapPtr)
GetExprLocations :: !FindLocations !a !*CHeaps !*CProject -> (![(CName, Int)], !*CHeaps, !*CProject) | getExprLocations a
getExprOnLocationInExpr :: !CName !Int !CExprH !*CHeaps !*CProject -> (!Bool, !CExprH, !*CHeaps, !*CProject)
getExprOnLocationInProp :: !CName !Int !CPropH !*CHeaps !*CProject -> (!Bool, !CExprH, !*CHeaps, !*CProject)

:: ExprFun :== (CExprH -> *(*CHeaps -> *(*CProject -> *(Error, (Bool, CExprH), *CHeaps, *CProject))))
actOnExprLocation :: !ExprLocation !CPropH !ExprFun !*CHeaps !*CProject -> (!Error, !(!Bool, !CPropH), !*CHeaps, !*CProject)

class recurse a :: !ExprFun !a !*CHeaps !*CProject -> (!Error, !(!Bool, !a), !*CHeaps, !*CProject)
instance recurse [a] | recurse a
instance recurse (Maybe a) | recurse a
instance recurse (CAlgPattern HeapPtr)
instance recurse (CBasicPattern HeapPtr)
instance recurse (CBasicValue HeapPtr)
instance recurse (CCasePatterns HeapPtr)
instance recurse (CExpr HeapPtr)
instance recurse (CProp HeapPtr)

class toSmaller a :: !IntFunctions !a -> a
instance toSmaller (CExpr HeapPtr)

class appE a
where
	appE :: !CExprLoc !a !(CExprH -> *(*CHeaps -> *(*CProject -> *(Error, CExprH, *CHeaps, *CProject)))) !*CHeaps !*CProject -> (!Bool, !Error, !CExprLoc, !a, !*CHeaps, !*CProject)

instance appE CExprH
instance appE CPropH
applyToInnerExpr :: !CExprLoc !a !(CExprH -> *(*CHeaps -> *(*CProject -> *(Error, CExprH, *CHeaps, *CProject)))) !*CHeaps !*CProject -> (!Error, !a, !*CHeaps, !*CProject) | appE a