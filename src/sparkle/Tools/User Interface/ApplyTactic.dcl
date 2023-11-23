/*
** Program: Clean Prover System
** Module:  ApplyTactic (.icl)
** 
** Author:  Maarten de Mol
** Created: 11 Januari 2001
*/

definition module 
	ApplyTactic

import 
	States

applyName			:: !String !TheoremPtr !Theorem !Goal !*PState -> *PState
//useHypothesis		:: !HypothesisPtr !TheoremPtr !Theorem !Goal !*PState -> *PState
