/*
** Program: Clean Prover System
** Module:  SectionMonad (.dcl)
** 
** Author:  Maarten de Mol
** Created: 26 March 2001
*/

definition module
	SectionMonad

import
	FileMonad,
	States

:: SectionState
:: SectionM a :== FileM SectionState a

applySectionM			:: !String !(SectionM a) !(CName -> *(*PState -> *PState)) !*PState -> (!Error, !SectionPtr, !*PState) | DummyValue a

addTheorem				:: !CName !CPropH -> SectionM Dummy
addUsedSymbol			:: !CName !String -> SectionM Dummy
addUsedTheorem			:: !CName !CName -> SectionM Dummy
checkDependencies		:: SectionM Dummy

disposeExprVars			:: !Int -> SectionM Dummy
disposePropVars			:: !Int -> SectionM Dummy
lookupBoundExprVar		:: !CName -> SectionM CExprVarPtr
lookupExprVar			:: !CName -> SectionM CExprVarPtr
lookupHypothesis		:: !CName -> SectionM HypothesisPtr
lookupPropVar			:: !CName -> SectionM CPropVarPtr
lookupSymbol			:: !Int -> SectionM (HeapPtr, CName)
lookupTheorem			:: !CName -> SectionM TheoremPtr
newExprVars				:: ![CName] -> SectionM [CExprVarPtr]
newPropVars				:: ![CName] -> SectionM [CPropVarPtr]

executeTactic			:: !TacticId -> SectionM Dummy
newBranch				:: SectionM Dummy
nextSubgoal				:: SectionM Dummy
saveProof				:: !(Maybe (Int,Int,Int,Int)) -> SectionM Dummy
setMessage				:: !String -> SectionM Dummy
startProof				:: !CName -> SectionM Dummy
typeAlgPatterns			:: ![CAlgPatternH] -> SectionM HeapPtr