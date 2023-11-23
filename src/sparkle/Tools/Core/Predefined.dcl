/*
** Program: Clean Prover System
** Module:  Predefined (.dcl)
** 
** Author:  Maarten de Mol
** Created: 23 August 2000
*/

definition module 
	Predefined

import 
	StdEnv,
	CoreTypes,
	Heaps

CPredefined			:: CModule
buildPredefined		:: !*CHeaps -> (!CPredefined, !*CHeaps)