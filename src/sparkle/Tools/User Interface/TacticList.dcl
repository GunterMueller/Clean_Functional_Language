/*
** Program: Clean Prover System
** Module:  TacticList (.dcl)
** 
** Author:  Maarten de Mol
** Created: 10 Januari 2001
*/

definition module 
	TacticList

import 
	StdEnv,
	StdPSt,
	States

openTacticList			:: !Int !*PState -> *PState