/*
** Program: Clean Prover System
** Module:  ChangeDefinition (.dcl)
** 
** Author:  Maarten de Mol
** Created: 23 August 2000
*/

definition module 
	ChangeDefinition

import 
	StdEnv,
	CoreTypes,
	Heaps

bindModule :: ![ModuleName] ![ModulePtr] !ModulePtr !*CHeaps !*CProject -> (!Error, !CModule, !*CHeaps, !*CProject)