/*
** Program: Clean Prover System
** Module:  OptionsMonad (.dcl)
** 
** Author:  Maarten de Mol
** Created: 03 April 2001
*/

definition module 
	OptionsMonad

import
	States

writeOptions			:: !*PState -> *PState
readOptions				:: !*PState -> *PState