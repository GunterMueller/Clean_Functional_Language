/*
** Program: Clean Prover System
** Module:  DeltaRules (.dcl)
** 
** Author:  Maarten de Mol
** Created: 18 December 2007
*/

definition module 
	LDeltaRules

import
	StdEnv,
	CoreTypes,
	CoreAccess,
	LTypes

setDeltaRules :: !HeapPtr !ModuleName !CFunDefH !*CHeaps !*CProject -> (!CFunDefH, !*CHeaps, !*CProject)