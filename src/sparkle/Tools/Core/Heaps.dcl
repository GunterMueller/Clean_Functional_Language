/*
** Program: Clean Prover System
** Module:  Heaps (.dcl)
** 
** Author:  Maarten de Mol
** Created: 26 October 2000
*/

definition module 
	Heaps

import
	StdEnv,
	CoreTypes,
	LTypes,
	ProveTypes
	, RWSDebug

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: CHeaps =
// -------------------------------------------------------------------------------------------------------------------------------------------------
	{ heapCExprVars				:: !.Heap CExprVarDef
	, heapCPropVars				:: !.Heap CPropVarDef
	, heapCTypeVars				:: !.Heap CTypeVarDef
	, heapLetDefs				:: !.Heap LLetDef
	, heapShared				:: !.Heap CShared
	, numShared					:: !Int
	, heapProofTrees			:: !.Heap ProofTree
	, heapHypotheses			:: !.Heap Hypothesis
	, heapSections				:: !.Heap Section
	, heapTheorems				:: !.Heap Theorem
	, heapModules				:: !.Heap CModule
	}
instance DummyValue CHeaps

class Pointer a
where
	newPointer					:: 			!a		!*CHeaps -> (!Ptr a, !*CHeaps)
	readPointer					:: !(Ptr a)			!*CHeaps -> (!a, !*CHeaps)
	writePointer				:: !(Ptr a)	!a		!*CHeaps -> *CHeaps
	
	getPointerName				:: !(Ptr a)			!*CHeaps -> (!CName, !*CHeaps)
	changePointerName			:: !(Ptr a) !CName	!*CHeaps -> *CHeaps
	wipePointerInfo				:: !(Ptr a)			!*CHeaps -> *CHeaps

class ReflexivePointer a
where
	readReflexivePointer	:: !(Ptr a) !*CHeaps -> (!Maybe (Ptr a), !*CHeaps)
	writeReflexivePointer	:: !(Ptr a) !(Ptr a) !*CHeaps -> *CHeaps
instance ReflexivePointer CExprVarDef
instance ReflexivePointer CPropVarDef

newPointers						::			![a]		!*CHeaps -> (![Ptr a], !*CHeaps) | Pointer a
readPointers					:: ![Ptr a]				!*CHeaps -> (![a], !*CHeaps) | Pointer a
writePointers					:: ![Ptr a]	![a]		!*CHeaps -> *CHeaps | Pointer a
getPointerNames					:: ![Ptr a]				!*CHeaps -> (![CName], !*CHeaps) | Pointer a
changePointerNames				:: ![Ptr a] ![CName]	!*CHeaps -> *CHeaps | Pointer a
wipePointerInfos				:: ![Ptr a]				!*CHeaps -> *CHeaps | Pointer a

setExprVarInfo					:: !CExprVarPtr !CExprVarInfo		!*CHeaps -> *CHeaps
setExprVarInfos					:: ![CExprVarPtr] ![CExprVarInfo]	!*CHeaps -> *CHeaps
setPropVarInfo					:: !CPropVarPtr !CPropVarInfo		!*CHeaps -> *CHeaps
setPropVarInfos					:: ![CPropVarPtr] ![CPropVarInfo]	!*CHeaps -> *CHeaps
setTypeVarInfo					:: !CTypeVarPtr !CTypeVarInfo		!*CHeaps -> *CHeaps
setTypeVarInfos					:: ![CTypeVarPtr] ![CTypeVarInfo]	!*CHeaps -> *CHeaps

setPassedInfo					:: !CSharedPtr !Bool				!*CHeaps -> *CHeaps
setPassedInfos					:: ![CSharedPtr] !Bool				!*CHeaps -> *CHeaps

findNamedPointers				:: ![CName] ![Ptr a]				!*CHeaps -> (![Ptr a], !*CHeaps) | Pointer a

instance Pointer CExprVarDef
instance Pointer CPropVarDef
instance Pointer CTypeVarDef
instance Pointer LLetDef
instance Pointer CShared
instance Pointer ProofTree
instance Pointer Hypothesis
instance Pointer Section
instance Pointer Theorem
instance Pointer CModule

sharable						:: !CExprH -> Bool
unshareCons						:: !CSharedPtr !CShared !*CHeaps -> (!CExprH, !*CHeaps)
share							:: ![CExprH] ![CName] !*CHeaps -> (![CExprH], !*CHeaps)
shareI							:: ![CExprH] !*CHeaps -> (![CExprH], !*CHeaps)

class unshare a :: !a !*CHeaps -> (!Bool, !a, !*CHeaps)
instance unshare (CExpr HeapPtr)
instance unshare (CProp HeapPtr)

class freshSharing a :: ![(CSharedPtr, CSharedPtr)] !a !*CHeaps -> (![(CSharedPtr, CSharedPtr)], !a, !*CHeaps)
instance freshSharing (CExpr HeapPtr)
FreshSharing :: !a !*CHeaps -> (!a, !*CHeaps) | freshSharing a