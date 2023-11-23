/*
** Program: Clean Prover System
** Module:  RemoveModules (.icl)
** 
** Author:  Maarten de Mol
** Created: 13 March 2001
*/

definition module
	RemoveModules

import
	States

removeModules			:: !Bool ![ModulePtr] !*PState -> *PState