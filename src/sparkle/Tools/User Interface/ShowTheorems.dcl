/*
** Program: Clean Prover System
** Module:  ShowTheorems (.dcl)
** 
** Author:  Maarten de Mol
** Created: 14 March 2001
*/

definition module
	ShowTheorems

import
	States

showTheorems		:: !Bool !(Maybe TheoremFilter) !*PState -> *PState

moveTheorem			:: !TheoremPtr !*PState -> *PState
renameTheorem		:: !TheoremPtr !*PState -> *PState
removeTheorem		:: !TheoremPtr !*PState -> *PState