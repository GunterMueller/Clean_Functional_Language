/*
** Program: Clean Prover System
** Module:  ShowModule (.dcl)
** 
** Author:  Maarten de Mol
** Created: 28 February 2001
*/

definition module
	ShowModule

import
	States

showModule				:: !(Maybe ModulePtr) !*PState -> *PState		// Nothing denotes the predefined module