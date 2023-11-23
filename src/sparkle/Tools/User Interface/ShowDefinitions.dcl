/*
** Program: Clean Prover System
** Module:  ShowDefinitions (.dcl)
** 
** Author:  Maarten de Mol
** Created: 28 February 2001
*/

definition module
	ShowDefinitions

import
	States

showDefinitions :: !(Maybe Id) !(Maybe DefinitionFilter) !*PState -> *PState