/*
** Program: Clean Prover System
** Module:  ControlMaybe (.dcl)
** 
** Author:  Maarten de Mol, Diederik van Arkel
** Created: 30 November 2000
*/

definition module
	ControlMaybe

import 
	StdEnv,
	StdControl

:: ControlMaybe c ls pst
	= ControlJust (c ls pst)
	| ControlNothing

instance Controls (ControlMaybe c) | Controls c