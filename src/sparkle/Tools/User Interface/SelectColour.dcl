/*
** Program: Clean Prover System
** Module:  SelectColour (.dcl)
** 
** Author:  Maarten de Mol
** Created: 31 November 2001
*/

definition module 
   SelectColour

import 
   StdEnv,
   StdIO,
   States

selectColour :: !*PState -> *PState