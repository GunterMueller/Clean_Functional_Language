/*
** Program: Clean Prover System
** Module:  ShowSection (.dcl)
** 
** Author:  Maarten de Mol
** Created: 19 January 2000
*/

definition module 
	ShowSection

import 
	States

openSection		:: !SectionPtr !*PState -> *PState