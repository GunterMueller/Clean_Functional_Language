/*
** Program: Clean Prover System
** Module:  Tautology (.dcl)
** 
** Author:  Maarten de Mol
** Created: 12 Februari 2001
*/

definition module 
	Tautology

import
	StdEnv,
	CoreTypes,
	States

Tautology :: !*PState -> !*PState
