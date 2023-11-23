/*
** Program: Clean Prover System
** Module:  Refresh (.dcl)
** 
** Author:  Maarten de Mol
** Created: 14 February 2000
*/

definition module 
	Refresh

import
	States

:: RefreshAction =
	  ChangedDisplayOption
	| ChangedProof					!TheoremPtr !Theorem !Bool
	| ChangedProofStatus			!TheoremPtr !Theorem				// only to be used after ChangedProof
	| ChangedSubgoal				!TheoremPtr !Theorem
	| CreatedSection
	| CreatedTheorem				!TheoremPtr !Theorem
	| DeletedSection				!SectionPtr !Section
	| DeletedTheorem				!TheoremPtr !Theorem
	| MovedTheorem					!TheoremPtr !Theorem !SectionPtr !SectionPtr
	| RenamedSection				!SectionPtr !Section
	| RenamedTheorem				!TheoremPtr !Theorem
	| RestartedTheorem				!TheoremPtr !Theorem

visualize :: !RefreshAction !*PState -> !*PState