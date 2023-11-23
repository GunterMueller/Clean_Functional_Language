/*
** Program: Clean Prover System
** Module:  Depends (.dcl)
** 
** Author:  Maarten de Mol
** Created: 13 March 2001
*/

definition module
	Depends

import
	States

modulesUsingModule			:: !ModulePtr !*PState -> (![ModulePtr], !*PState)
theoremsUsingModule			:: !ModulePtr !*PState -> (![TheoremPtr], !*PState)

theoremsUsingTheorem		:: !TheoremPtr !*PState -> (![TheoremPtr], !*PState)
theoremsUsingSection		:: !SectionPtr !*PState -> (![TheoremPtr], !*PState)

isTheoremProved				:: !TheoremPtr !*PState -> (!Bool, ![TheoremPtr], ![TheoremPtr], !*PState)
areTheoremsProved			:: ![TheoremPtr] ![TheoremPtr] ![TheoremPtr] !*PState -> (![TheoremPtr], ![TheoremPtr], !*PState)

resetDependencies			:: !TheoremPtr !*PState -> *PState
