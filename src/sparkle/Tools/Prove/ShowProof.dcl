/*
** Program: Clean Prover System
** Module:  ShowProof (.dcl)
** 
** Author:  Maarten de Mol
** Created: 7 November 2000
*/

definition module
   ShowProof

import 
   States

openProof		:: !TheoremPtr !Theorem !*PState -> *PState
showToProve		:: !FormatInfo !Theorem !*PState -> (!Error, !(!Bool, !DefinednessInfo), !MarkUpText WindowCommand, !*PState)