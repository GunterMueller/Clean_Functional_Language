/*
** Program: Clean Prover System
** Module:  ControlMaybe (.icl)
** 
** Author:  Maarten de Mol, Diederik van Arkel
** Created: 30 November 2000
*/

implementation module 
	ControlMaybe

import 
	StdEnv,
	StdIO

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: ControlMaybe c ls pst
// -------------------------------------------------------------------------------------------------------------------------------------------------
	= ControlJust (c ls pst)
	| ControlNothing

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance Controls (ControlMaybe c) | Controls c
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	controlToHandles mc pState
		= case mc of 
			(ControlJust c)
				#  (cs,pState)	= controlToHandles c pState
				-> (cs,pState)
			ControlNothing
				-> ([],pState)
	getControlType _
		= ""