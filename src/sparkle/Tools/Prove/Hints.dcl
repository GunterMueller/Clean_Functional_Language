/*
** Program: Clean Prover System
** Module:  Hints (.dcl)
** 
** Author:  Maarten de Mol
** Created: 9 May 2001
*/

definition module 
   Hints

import 
   States

openHints			:: !*PState -> *PState
setTheoremHint		:: !Bool !TheoremPtr !CPropH !(Maybe (Int, Int, Int, Int)) !*PState -> *PState
