/*
** Program: Clean Prover System
** Module:  MenuBar (.dcl)
** 
** Author:  Maarten de Mol
** Created: 26 May 1999
*/

definition module 
   MenuBar

import 
   States
      
aboutDialog		:: !Bool !*PState -> *PState
close_process	:: !*PState -> *PState
createMenuBar	:: !*PState -> *PState