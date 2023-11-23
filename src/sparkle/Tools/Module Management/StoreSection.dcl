/*
** Program: Clean Prover System
** Module:  StoreSection (.dcl)
** 
** Author:  Maarten de Mol
** Created: 23 February 2001
*/

definition module
	StoreSection

import
	StdEnv,
	States

storeSection		:: !SectionPtr !*PState -> *PState
restoreSection		:: !(Maybe CName) !*PState -> *PState