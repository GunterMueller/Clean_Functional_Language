/*
** Program: Sparkle
** Module:  WarningStdEnv (.dcl)
** 
** Author:  Maarten de Mol
** Created: 3 July 2007
*/

definition module
	WarningStdEnv

import
	CoreTypes,
	States

warningStdEnv			:: ![ModulePtr] !*PState -> *PState
