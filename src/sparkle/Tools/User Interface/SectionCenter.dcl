/*
** Program: Clean Prover System
** Module:  SectionCenter (.dcl)
** 
** Author:  Maarten de Mol
** Created: 19 January 2001
*/

definition module
	SectionCenter

import 
	States
   
openSectionCenter	:: !*PState -> *PState
newSection			:: !*PState -> *PState