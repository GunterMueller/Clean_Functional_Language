/*
** Program: Clean Prover System
** Module:  LReduce (.dcl)
** 
** Author:  Maarten de Mol
** Created: 11 December 2007
*/

definition module 
	LReduce

import 
	StdEnv,
	CoreTypes,
	CoreAccess,
	LTypes,
	ProveTypes,
	States

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: LReduceTo							:== Bool
:: LNrSteps								:== Int
LToNF									:== True
LToRNF									:== False
// -------------------------------------------------------------------------------------------------------------------------------------------------

LReduce			:: ![LExpr] !ReduceMode !LReduceTo !LNrSteps !LExpr !*CHeaps !*CProject -> (!(!LNrSteps, !LExpr), !*CHeaps, !*CProject)
garbageCollect	:: !CExprH !*CHeaps !*CProject -> (!CExprH, !*CHeaps, !*CProject)

