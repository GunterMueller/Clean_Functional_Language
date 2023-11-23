/*
** Program: Clean Prover System
** Module:  AddModule (.dcl)
** 
** Author:  Maarten de Mol
** Created: 13 March 2001
*/

definition module
	AddModule

import
	States,
	StatusDialog

addModule			:: !*PState -> *PState
addToProject		:: ![String] !String !(StatusDialogEvent -> *PState -> *PState) !*PState -> *PState
