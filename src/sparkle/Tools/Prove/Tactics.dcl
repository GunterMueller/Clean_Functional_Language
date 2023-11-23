/*
** Program: Clean Prover System
** Module:  Tactics (.dcl)
** 
** Author:  Maarten de Mol
** Created: 20 November 2000
*/

definition module 
	Tactics

import 
	StdEnv,
	States,
	CoreTypes,
	CoreAccess,
	ProveTypes
	, RWSDebug

:: Tactic				:== Goal *CHeaps -> *(*CProject -> *(Error, [Goal], [TheoremPtr], [HeapPtr], *CHeaps, *CProject))

apply					:: !TacticId -> Tactic
applyTactic				:: !TacticId !TheoremPtr !Theorem !Options !*CHeaps !*CProject -> (!Error, !Theorem, ![ProofTreePtr], !*CHeaps, !*CProject)
applyTactical			:: !PTactical !TheoremPtr ![TheoremPtr] !Theorem !Options !*CHeaps !*CProject -> (!Error, !Theorem, ![ProofTreePtr], !*CHeaps, !*CProject)

tacticTitle				:: !TacticId -> String
absurd_equality			:: !Bool !CPropH !*CProject -> (!Bool, !*CProject)
chooseCase				:: !Bool !CPropH !Goal !*CHeaps !*CProject -> (!Bool, !Goal, !*CHeaps, !*CProject)
inject					:: !Bool !CPropH !Goal !*CHeaps !*CProject -> (!Bool, !Int, !CPropH, !*CHeaps, !*CProject)
isManualDefinedness		:: !TheoremPtr !*CHeaps !*CProject -> (!Bool, !String, !(!HeapPtr, ![Bool]), !*CHeaps, !*CProject)
areManualDefinedness	:: ![TheoremPtr] !*CHeaps !*CProject -> (!Bool, !String, ![(HeapPtr, [Bool])], !*CHeaps, !*CProject)
setManualDefinedness	:: !Goal !*CProject -> *CProject
unsetManualDefinedness	:: !Goal !*CProject -> *CProject
moveInCase				:: !CExprH !*CHeaps !*CProject -> (!Error, !(!Bool, !CExprH), !*CHeaps, !*CProject)
moveQuantors			:: !MoveDirection !CPropH !*CHeaps -> (!(!Bool, !CPropH), !*CHeaps)
ncurry					:: !CExprH !*CHeaps !*CProject -> (!Error, !(!Bool, !CExprH), !*CHeaps, !*CProject)
refineUndefinedness	 	:: !CPropH !*CProject -> (!Bool, !CPropH, !*CProject)
removeCase				:: !CExprH !*CHeaps !*CProject -> (!Error, !(!Bool, !CExprH), !*CHeaps, !*CProject)

rewrite					:: !RewriteDirection !Redex !CPropH !CPropH !*CHeaps -> (!Error, !Bool, ![CPropH], !CPropH, !*CHeaps)
RewriteN				:: !RewriteDirection !Redex !UseFact !Goal !*CHeaps !*CProject -> (!Error, ![Goal], ![TheoremPtr], ![HeapPtr], !*CHeaps, !*CProject)
RewriteH				:: !RewriteDirection !Redex !UseFact !HypothesisPtr !TacticMode !Goal !*CHeaps !*CProject -> (!Error, ![Goal], ![TheoremPtr], ![HeapPtr], !*CHeaps, !*CProject)