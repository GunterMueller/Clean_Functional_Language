/*
** Program: Clean Prover System
** Module:  ShowDefinition (.dcl)
** 
** Author:  Maarten de Mol
** Created: 28 September 1999
*/

definition module 
   ShowDefinition

import 
   States

//pickDefinition	:: !*PState -> !*PState
showDefinition		:: !HeapPtr !*PState -> *PState
showDefinedness		:: !(Maybe HeapPtr) !*PState -> *PState
