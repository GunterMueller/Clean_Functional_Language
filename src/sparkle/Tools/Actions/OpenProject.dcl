/*
** Program: Clean Prover System
** Module:  OpenProject (.dcl)
** 
** Author:  Maarten de Mol
** Created: 15 September 1999
*/

definition module 
   OpenProject

import 
   States

openProject      ::         !*PState -> (!Error, !*PState)
openNamedProject :: !String !*PState -> (!Error, !*PState)