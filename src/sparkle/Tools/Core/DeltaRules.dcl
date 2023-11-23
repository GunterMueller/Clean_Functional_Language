/*
** Program: Clean Prover System
** Module:  DeltaRules (.dcl)
** 
** Author:  Maarten de Mol
** Created: 28 August 2000
*/

definition module 
	DeltaRules

import
	StdEnv,
	CoreTypes,
	CoreAccess

setDeltaRules :: !HeapPtr !ModuleName !CFunDefH !*CHeaps !*CProject -> (!CFunDefH, !*CHeaps, !*CProject)