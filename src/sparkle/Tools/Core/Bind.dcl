/*
** Program: Clean Prover System
** Module:  Bind (.dcl)
** 
** Author:  Maarten de Mol
** Created: 24 August 2000
*/

definition module 
	Bind

import 
	StdEnv,
	CoreTypes,
	Heaps,
	frontend

bindToProject :: ![ModulePtr] !*CHeaps !*CProject -> (!Error, !*CHeaps, !*CProject)