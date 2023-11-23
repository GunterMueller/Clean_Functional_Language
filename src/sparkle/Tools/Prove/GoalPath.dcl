/*
** Program: Clean Prover System
** Module:  GoalPath (.dcl)
** 
** Author:  Maarten de Mol
** Created: 18 December 2000
*/

definition module
	GoalPath

import 
	StdEnv,
	CoreTypes,
	ProveTypes,
	Heaps,
	Tactics
	, RWSDebug

wipeGoalPath		:: !ProofTreePtr !*CHeaps -> *CHeaps
//updateGoalPath		:: !TheoremPtr !Theorem ![TheoremPtr] !*CHeaps !*CProject -> (!*CHeaps, !*CProject)
undoProofSteps		:: !Int !Proof !*CHeaps -> (!Error, !Proof, !*CHeaps)
goToProofStep		:: !ProofTreePtr !ProofTree ![ProofTreePtr] !Proof !*CHeaps -> (!Error, !Proof, !*CHeaps)
//findDependencies	:: !Proof !*CHeaps -> (![TheoremPtr], !*CHeaps)
