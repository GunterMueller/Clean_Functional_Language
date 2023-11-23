/*
** Program: Clean Prover System
** Module:  ShowTheorem (.dcl)
** 
** Author:  Maarten de Mol
** Created: 19 January 2000
*/

definition module
	ShowTheorem

import 
	States

openTheorem			:: !TheoremPtr !*PState -> *PState
undo				:: !(RId (MarkUpMessage WindowCommand)) !TheoremPtr !ProofTreePtr !*PState -> *PState
changeHintScores	:: !TheoremPtr !*PState -> *PState
