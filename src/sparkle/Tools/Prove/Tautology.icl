/*
** Program: Clean Prover System
** Module:  Tautology (.icl)
** 
** Author:  Maarten de Mol
** Created: 12 Februari 2001
*/

implementation module 
	Tautology

import
	StdEnv,
	CoreTypes,
	BindLexeme,
	Tactics,
	States

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: UseTactic =
// -------------------------------------------------------------------------------------------------------------------------------------------------
	  KnownTactic			!TacticId
	| UnknownTactic			!PTacticId

// -------------------------------------------------------------------------------------------------------------------------------------------------
Tautology :: !*PState -> !*PState
// -------------------------------------------------------------------------------------------------------------------------------------------------
Tautology pstate
	# tautology							=	{ seName			= "tautology"
											, seTheorems		= []
											}
	# (tautology_ptr, pstate)			= accHeaps (newPointer tautology) pstate
	# (old_sections, pstate)			= pstate!ls.stSections
	# pstate							= {pstate & ls.stSections = [tautology_ptr:old_sections]}
	# (options, pstate)					= pstate!ls.stOptions
	# (_, and_false_x, pstate)			= accErrorHeapsProject (createAndFalseX tautology_ptr options) pstate
	# (_, and_true_x, pstate)			= accErrorHeapsProject (createAndTrueX tautology_ptr options) pstate
	# (_, and_x_false, pstate)			= accErrorHeapsProject (createAndXFalse tautology_ptr options) pstate
	# (_, and_x_true, pstate)			= accErrorHeapsProject (createAndXTrue tautology_ptr options) pstate
	# (_, de_morgan_and, pstate)		= accErrorHeapsProject (createDeMorganAnd tautology_ptr options) pstate
	# (_, de_morgan_or, pstate)			= accErrorHeapsProject (createDeMorganOr tautology_ptr options) pstate
	# (_, idempotent_and, pstate)		= accErrorHeapsProject (createIdempotentAnd tautology_ptr options) pstate
	# (_, idempotent_or, pstate)		= accErrorHeapsProject (createIdempotentOr tautology_ptr options) pstate
	# (_, implies_false_x, pstate)		= accErrorHeapsProject (createImpliesFalseX tautology_ptr options) pstate
	# (_, implies_true_x, pstate)		= accErrorHeapsProject (createImpliesTrueX tautology_ptr options) pstate
	# (_, implies_x_false, pstate)		= accErrorHeapsProject (createImpliesXFalse tautology_ptr options) pstate
	# (_, implies_x_true, pstate)		= accErrorHeapsProject (createImpliesXTrue tautology_ptr options) pstate
	# (_, invert_implies, pstate)		= accErrorHeapsProject (createInvertImplies tautology_ptr options) pstate
	# (_, not_true, pstate)				= accErrorHeapsProject (createNotTrue tautology_ptr options) pstate
	# (_, not_false, pstate)			= accErrorHeapsProject (createNotFalse tautology_ptr options) pstate
	# (_, not_not, pstate)				= accErrorHeapsProject (createNotNot tautology_ptr options) pstate
	# (_, or_not_left, pstate)			= accErrorHeapsProject (createOrNotLeft tautology_ptr options) pstate
	# (_, or_not_right, pstate)			= accErrorHeapsProject (createOrNotRight tautology_ptr options) pstate
	# (_, or_false_x, pstate)			= accErrorHeapsProject (createOrFalseX tautology_ptr options) pstate
	# (_, or_true_x, pstate)			= accErrorHeapsProject (createOrTrueX tautology_ptr options) pstate
	# (_, or_x_false, pstate)			= accErrorHeapsProject (createOrXFalse tautology_ptr options) pstate
	# (_, or_x_true, pstate)			= accErrorHeapsProject (createOrXTrue tautology_ptr options) pstate
	# (_, reflexive_implies, pstate)	= accErrorHeapsProject (createReflexiveImplies tautology_ptr options) pstate
	# (_, split_iff, pstate)			= accErrorHeapsProject (createSplitIff tautology_ptr options) pstate
	# (_, symmetric_and, pstate)		= accErrorHeapsProject (createSymmetricAnd tautology_ptr options) pstate
	# (_, symmetric_or, pstate)			= accErrorHeapsProject (createSymmetricOr tautology_ptr options) pstate
	// dependent proofs
	# (_, tertium, pstate)				= accErrorHeapsProject (createTertium tautology_ptr de_morgan_or options) pstate
	# (_, implies_or, pstate)			= accErrorHeapsProject (createImpliesOr tautology_ptr tertium options) pstate
	= pstate

// -------------------------------------------------------------------------------------------------------------------------------------------------
buildTheorem :: !String !SectionPtr ![TheoremPtr] !String !CPropH ![UseTactic] !Options !*CHeaps !*CProject -> (!Error, !TheoremPtr, !*CHeaps, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------
buildTheorem name section_ptr theorems initial_text initial tactics options heaps prj
	# goal								= {DummyValue & glToProve = initial}
	# (leaf, heaps)						= newPointer (ProofLeaf goal) heaps
	# proof								=	{ pTree				= leaf
											, pLeafs			= [leaf]
											, pCurrentLeaf		= leaf
											, pCurrentGoal		= goal
											, pUsedTheorems		= []
											, pUsedSymbols		= []
											}
	# theorem							=	{ thName			= name
											, thInitial			= initial
											, thInitialText		= initial_text
											, thProof			= proof
											, thSection			= section_ptr
											, thSubgoals		= False
											}
	# (theorem_ptr, heaps)				= newPointer theorem heaps
	# (error, theorem, heaps, prj)		= apply_tactics tactics theorem_ptr theorem heaps prj
	# heaps								= writePointer theorem_ptr theorem heaps
	# (section, heaps)					= readPointer section_ptr heaps
	# section							= {section & seTheorems = [theorem_ptr:section.seTheorems]}
	# heaps								= writePointer section_ptr section heaps
	= (error, theorem_ptr, heaps, prj)
	where
		apply_tactics :: ![UseTactic] !TheoremPtr !Theorem !*CHeaps !*CProject -> (!Error, !Theorem, !*CHeaps, !*CProject)
		apply_tactics [KnownTactic tactic:tactics] ptr theorem heaps prj
			# (error, theorem, _, heaps, prj)	= applyTactic tactic ptr theorem heaps prj
			| isError error						= (error, theorem, heaps, prj)
			= apply_tactics tactics ptr theorem heaps prj
		apply_tactics [UnknownTactic tactic:tactics] ptr theorem heaps prj
			# (error, tactic, heaps, prj)		= bindTactic tactic theorem.thProof.pCurrentGoal theorems options heaps prj
			| isError error						= (error, theorem, heaps, prj)
			# (error, theorem, _, heaps, prj)	= applyTactic tactic ptr theorem heaps prj
			| isError error						= (error, theorem, heaps, prj)
			= apply_tactics tactics ptr theorem heaps prj
		apply_tactics [] ptr theorem heaps prj
			= (OK, theorem, heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
createAndFalseX :: !SectionPtr !Options !*CHeaps !*CProject -> (!Error, !TheoremPtr, !*CHeaps, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------
createAndFalseX section options heaps prj
	# (new_var, heaps)					= newPointer {DummyValue & pvarName = "P"} heaps
	= buildTheorem "and_false_x" section [] "(FALSE /\\ P) <-> FALSE" (initial new_var) proof options heaps prj
	where
		initial p
			= CPropForall p (CIff (CAnd CFalse P) CFalse)
			where
				P	= CPropVar p
		
		proof
			=	[ KnownTactic	(	TacticIntroduce			["P"]							)
				, KnownTactic	(	TacticSplitIff											)
				, KnownTactic	(	TacticIntroduce			["H1"]							)
				, UnknownTactic	(	PTacticSplit			(Just "H1") Shallow Implicit	)
				, UnknownTactic	(	PTacticExFalso			"H2"							)
				, KnownTactic	(	TacticIntroduce			["H1"]							)
				, UnknownTactic	(	PTacticExFalso			"H1"							)
				]

// -------------------------------------------------------------------------------------------------------------------------------------------------
createAndTrueX :: !SectionPtr !Options !*CHeaps !*CProject -> (!Error, !TheoremPtr, !*CHeaps, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------
createAndTrueX section options heaps prj
	# (new_var, heaps)					= newPointer {DummyValue & pvarName = "P"} heaps
	= buildTheorem "and_true_x" section [] "(TRUE /\\ P) <-> P" (initial new_var) proof options heaps prj
	where
		initial p
			= CPropForall p (CIff (CAnd CTrue P) P)
			where
				P	= CPropVar p
		
		proof
			=	[ KnownTactic	(	TacticIntroduce			["P"]							)
				, KnownTactic	(	TacticSplitIff											)
				, KnownTactic	(	TacticIntroduce			["H1"]							)
				, UnknownTactic	(	PTacticSplit			(Just "H1") Shallow Implicit	)
				, UnknownTactic	(	PTacticExact			(PHypothesisFact "H3")			)
				, KnownTactic	(	TacticIntroduce			["H1"]							)
				, KnownTactic	(	TacticSplit				Shallow							)
				, KnownTactic	(	TacticTrivial											)
				, UnknownTactic	(	PTacticExact			(PHypothesisFact "H1")			)
				]

// -------------------------------------------------------------------------------------------------------------------------------------------------
createAndXFalse :: !SectionPtr !Options !*CHeaps !*CProject -> (!Error, !TheoremPtr, !*CHeaps, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------
createAndXFalse section options heaps prj
	# (new_var, heaps)					= newPointer {DummyValue & pvarName = "P"} heaps
	= buildTheorem "and_x_false" section [] "(P /\\ FALSE) <-> FALSE" (initial new_var) proof options heaps prj
	where
		initial p
			= CPropForall p (CIff (CAnd P CFalse) CFalse)
			where
				P	= CPropVar p
		
		proof
			=	[ KnownTactic	(	TacticIntroduce			["P"]							)
				, KnownTactic	(	TacticSplitIff											)
				, KnownTactic	(	TacticIntroduce			["H1"]							)
				, UnknownTactic	(	PTacticSplit			(Just "H1") Shallow Implicit	)
				, UnknownTactic	(	PTacticExFalso			"H3"							)
				, KnownTactic	(	TacticIntroduce			["H1"]							)
				, UnknownTactic	(	PTacticExFalso			"H1"							)
				]

// -------------------------------------------------------------------------------------------------------------------------------------------------
createAndXTrue :: !SectionPtr !Options !*CHeaps !*CProject -> (!Error, !TheoremPtr, !*CHeaps, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------
createAndXTrue section options heaps prj
	# (new_var, heaps)					= newPointer {DummyValue & pvarName = "P"} heaps
	= buildTheorem "and_x_true" section [] "(P /\\ TRUE) <-> P" (initial new_var) proof options heaps prj
	where
		initial p
			= CPropForall p (CIff (CAnd P CTrue) P)
			where
				P	= CPropVar p
		
		proof
			=	[ KnownTactic	(	TacticIntroduce			["P"]							)
				, KnownTactic	(	TacticSplitIff											)
				, KnownTactic	(	TacticIntroduce			["H1"]							)
				, UnknownTactic	(	PTacticSplit			(Just "H1") Shallow Implicit	)
				, UnknownTactic	(	PTacticExact			(PHypothesisFact "H2")			)
				, KnownTactic	(	TacticIntroduce			["H1"]							)
				, KnownTactic	(	TacticSplit				Shallow							)
				, UnknownTactic	(	PTacticExact			(PHypothesisFact "H1")			)
				, KnownTactic	(	TacticTrivial											)
				]

// -------------------------------------------------------------------------------------------------------------------------------------------------
createDeMorganAnd :: !SectionPtr !Options !*CHeaps !*CProject -> (!Error, !TheoremPtr, !*CHeaps, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------
createDeMorganAnd section options heaps prj
	# (new_var1, heaps)					= newPointer {DummyValue & pvarName = "P"} heaps
	# (new_var2, heaps)					= newPointer {DummyValue & pvarName = "Q"} heaps
	= buildTheorem "deMorgan_and" section [] "~(P /\\ Q) <-> (~P \\/ ~Q)" (initial new_var1 new_var2) proof options heaps prj
	where
		initial p q
			= CPropForall p (CPropForall q (CIff (CNot (CAnd P Q)) (COr (CNot P) (CNot Q))))
			where
				P	= CPropVar p
				Q	= CPropVar q
		
		proof
			=	[ KnownTactic	(	TacticIntroduce			["P", "Q"]						)
				, KnownTactic	(	TacticSplitIff											)
				, KnownTactic	(	TacticIntroduce			["H1"]							)
				, KnownTactic	(	TacticContradiction		Implicit						)
				, UnknownTactic	(	PTacticContradiction	(Just "H1") Implicit			)
				, KnownTactic	(	TacticSplit				Shallow							)
				, KnownTactic	(	TacticContradiction		Implicit						)
				, UnknownTactic	(	PTacticContradiction	(Just "H2") Implicit			)
				, KnownTactic	(	TacticCase				Shallow 1						)
				, UnknownTactic	(	PTacticExact			(PHypothesisFact "H3")			)
				, KnownTactic	(	TacticContradiction		Implicit						)
				, UnknownTactic	(	PTacticContradiction	(Just "H2") Implicit			)
				, KnownTactic	(	TacticCase				Shallow 2						)
				, UnknownTactic	(	PTacticExact			(PHypothesisFact "H3")			)
				, KnownTactic	(	TacticIntroduce			["H1"]							)
				, KnownTactic	(	TacticContradiction		Implicit						)
				, UnknownTactic	(	PTacticSplit			(Just "H2") Shallow Implicit	)
				, UnknownTactic	(	PTacticCase				Shallow Nothing
															(Just "H1") Implicit			)
				, UnknownTactic	(	PTacticAbsurd			"H1" "H3"						)
				, UnknownTactic	(	PTacticAbsurd			"H1" "H4"						)
				]

// -------------------------------------------------------------------------------------------------------------------------------------------------
createDeMorganOr :: !SectionPtr !Options !*CHeaps !*CProject -> (!Error, !TheoremPtr, !*CHeaps, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------
createDeMorganOr section options heaps prj
	# (new_var1, heaps)					= newPointer {DummyValue & pvarName = "P"} heaps
	# (new_var2, heaps)					= newPointer {DummyValue & pvarName = "Q"} heaps
	= buildTheorem "deMorgan_or" section [] "~(P \\/ Q) <-> (~P /\\ ~Q)" (initial new_var1 new_var2) proof options heaps prj
	where
		initial p q
			= CPropForall p (CPropForall q (CIff (CNot (COr P Q)) (CAnd (CNot P) (CNot Q))))
			where
				P	= CPropVar p
				Q	= CPropVar q
		
		proof
			=	[ KnownTactic	(	TacticIntroduce			["P", "Q"]						)
				, KnownTactic	(	TacticSplitIff											)
				, KnownTactic	(	TacticIntroduce			["H1"]							)
				, KnownTactic	(	TacticSplit				Shallow							)
				, KnownTactic	(	TacticContradiction		Implicit						)
				, UnknownTactic	(	PTacticContradiction	(Just "H1") Implicit			)
				, KnownTactic	(	TacticCase				Shallow 1						)
				, UnknownTactic	(	PTacticExact			(PHypothesisFact "H2")			)
				, KnownTactic	(	TacticContradiction		Implicit						)
				, UnknownTactic	(	PTacticContradiction	(Just "H1") Implicit			)
				, KnownTactic	(	TacticCase				Shallow 2						)
				, UnknownTactic	(	PTacticExact			(PHypothesisFact "H2")			)
				, KnownTactic	(	TacticIntroduce			["H1"]							)
				, UnknownTactic	(	PTacticSplit			(Just "H1") Shallow Implicit	)
				, KnownTactic	(	TacticContradiction		Implicit						)
				, UnknownTactic	(	PTacticCase				Shallow Nothing
															(Just "H4") Implicit			)
				, UnknownTactic	(	PTacticAbsurd			"H2" "H4"						)
				, UnknownTactic	(	PTacticAbsurd			"H3" "H4"						)
				]

// -------------------------------------------------------------------------------------------------------------------------------------------------
createIdempotentAnd :: !SectionPtr !Options !*CHeaps !*CProject -> (!Error, !TheoremPtr, !*CHeaps, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------
createIdempotentAnd section options heaps prj
	# (new_var, heaps)					= newPointer {DummyValue & pvarName = "P"} heaps
	= buildTheorem "idempotent_and" section [] "(P /\\ P) <-> P" (initial new_var) proof options heaps prj
	where
		initial p
			= CPropForall p (CIff (CAnd (CPropVar p) (CPropVar p)) (CPropVar p))
		
		proof
			=	[ KnownTactic	(	TacticIntroduce			["P"]							)
				, KnownTactic	(	TacticSplitIff											)
				, KnownTactic	(	TacticIntroduce			["H1"]							)
				, UnknownTactic	(	PTacticSplit			(Just "H1") Shallow Implicit	)
				, UnknownTactic	(	PTacticExact			(PHypothesisFact "H2")			)
				, KnownTactic	(	TacticIntroduce			["H1"]							)
				, KnownTactic	(	TacticSplit				Shallow							)
				, UnknownTactic	(	PTacticExact			(PHypothesisFact "H1")			)
				, UnknownTactic	(	PTacticExact			(PHypothesisFact "H1")			)
				]

// -------------------------------------------------------------------------------------------------------------------------------------------------
createIdempotentOr :: !SectionPtr !Options !*CHeaps !*CProject -> (!Error, !TheoremPtr, !*CHeaps, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------
createIdempotentOr section options heaps prj
	# (new_var, heaps)					= newPointer {DummyValue & pvarName = "P"} heaps
	= buildTheorem "idempotent_or" section [] "(P \\/ P) <-> P" (initial new_var) proof options heaps prj
	where
		initial p
			= CPropForall p (CIff (COr (CPropVar p) (CPropVar p)) (CPropVar p))
		
		proof
			=	[ KnownTactic	(	TacticIntroduce			["P"]							)
				, KnownTactic	(	TacticSplitIff											)
				, KnownTactic	(	TacticIntroduce			["H1"]							)
				, UnknownTactic	(	PTacticCase				Shallow Nothing
															(Just "H1") Implicit			)
				, UnknownTactic	(	PTacticExact			(PHypothesisFact "H1")			)
				, UnknownTactic	(	PTacticExact			(PHypothesisFact "H1")			)
				, KnownTactic	(	TacticIntroduce			["H1"]							)
				, KnownTactic	(	TacticCase				Shallow 1						)
				, UnknownTactic	(	PTacticExact			(PHypothesisFact "H1")			)
				]

// -------------------------------------------------------------------------------------------------------------------------------------------------
createImpliesOr :: !SectionPtr !TheoremPtr !Options !*CHeaps !*CProject -> (!Error, !TheoremPtr, !*CHeaps, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------
createImpliesOr section tertium options heaps prj
	# (new_var1, heaps)					= newPointer {DummyValue & pvarName = "P"} heaps
	# (new_var2, heaps)					= newPointer {DummyValue & pvarName = "Q"} heaps
	= buildTheorem "implies_or" section [] "(P -> Q) <-> (~P \\/ Q)" (initial new_var1 new_var2) (proof new_var1 new_var2) options heaps prj
	where
		initial p q
			= CPropForall p (CPropForall q (CIff (CImplies P Q) (COr (CNot P) Q)))
			where
				P	= CPropVar p
				Q	= CPropVar q
		
		proof p q
			=	[ KnownTactic	(	TacticIntroduce			["P", "Q"]						)
				, KnownTactic	(	TacticSplitIff											)
				, KnownTactic	(	TacticIntroduce			["H1"]							)
				, KnownTactic	(	TacticAssume			(COr P (CNot P)) Implicit		)
				, UnknownTactic	(	PTacticCase				Shallow Nothing
															(Just "H2") Implicit			)
				, KnownTactic	(	TacticCase				Shallow 2						)
				, UnknownTactic	(	PTacticApply			(PHypothesisFact "H1")
															Nothing Implicit				)
				, UnknownTactic	(	PTacticExact			(PHypothesisFact "H2")			)
				, KnownTactic	(	TacticCase				Shallow 1						)
				, UnknownTactic	(	PTacticExact			(PHypothesisFact "H2")			)
				, KnownTactic	(	TacticApply				(TheoremFact tertium)			)
				, KnownTactic	(	TacticIntroduce			["H1", "H2"]					)
				, UnknownTactic	(	PTacticCase				Shallow Nothing
															(Just "H1") Implicit			)
				, UnknownTactic	(	PTacticAbsurd			"H1" "H2"						)
				, UnknownTactic	(	PTacticExact			(PHypothesisFact "H1")			)
				]
				
			where
				P	= CPropVar p
				Q	= CPropVar q

// -------------------------------------------------------------------------------------------------------------------------------------------------
createImpliesFalseX :: !SectionPtr !Options !*CHeaps !*CProject -> (!Error, !TheoremPtr, !*CHeaps, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------
createImpliesFalseX section options heaps prj
	# (new_var, heaps)					= newPointer {DummyValue & pvarName = "P"} heaps
	= buildTheorem "implies_false_x" section [] "(FALSE -> P) <-> TRUE" (initial new_var) proof options heaps prj
	where
		initial p
			= CPropForall p (CIff (CImplies CFalse P) CTrue)
			where
				P	= CPropVar p
		
		proof
			=	[ KnownTactic	(	TacticIntroduce			["P"]							)
				, KnownTactic	(	TacticSplitIff											)
				, KnownTactic	(	TacticIntroduce			["H1"]							)
				, KnownTactic	(	TacticTrivial											)
				, KnownTactic	(	TacticIntroduce			["H1", "H2"]					)
				, UnknownTactic	(	PTacticExFalso			"H2"							)
				]

// -------------------------------------------------------------------------------------------------------------------------------------------------
createImpliesTrueX :: !SectionPtr !Options !*CHeaps !*CProject -> (!Error, !TheoremPtr, !*CHeaps, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------
createImpliesTrueX section options heaps prj
	# (new_var, heaps)					= newPointer {DummyValue & pvarName = "P"} heaps
	= buildTheorem "implies_true_x" section [] "(TRUE -> P) <-> P" (initial new_var) proof options heaps prj
	where
		initial p
			= CPropForall p (CIff (CImplies CTrue P) P)
			where
				P	= CPropVar p
		
		proof
			=	[ KnownTactic	(	TacticIntroduce			["P"]							)
				, KnownTactic	(	TacticSplitIff											)
				, KnownTactic	(	TacticIntroduce			["H1"]							)
				, UnknownTactic	(	PTacticApply			(PHypothesisFact "H1")
															Nothing Implicit				)
				, KnownTactic	(	TacticTrivial											)
				, KnownTactic	(	TacticIntroduce			["H1", "H2"]					)
				, UnknownTactic	(	PTacticExact			(PHypothesisFact "H1")			)
				]

// -------------------------------------------------------------------------------------------------------------------------------------------------
createImpliesXFalse :: !SectionPtr !Options !*CHeaps !*CProject -> (!Error, !TheoremPtr, !*CHeaps, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------
createImpliesXFalse section options heaps prj
	# (new_var, heaps)					= newPointer {DummyValue & pvarName = "P"} heaps
	= buildTheorem "implies_x_false" section [] "(P -> FALSE) <-> ~P" (initial new_var) proof options heaps prj
	where
		initial p
			= CPropForall p (CIff (CImplies P CFalse) (CNot P))
			where
				P	= CPropVar p
		
		proof
			=	[ KnownTactic	(	TacticIntroduce			["P"]							)
				, KnownTactic	(	TacticSplitIff											)
				, KnownTactic	(	TacticIntroduce			["H1"]							)
				, KnownTactic	(	TacticContradiction		Implicit						)
				, UnknownTactic	(	PTacticApply			(PHypothesisFact "H1")
															Nothing Implicit				)
				, UnknownTactic	(	PTacticExact			(PHypothesisFact "H2")			)
				, KnownTactic	(	TacticIntroduce			["H1", "H2"]					)
				, UnknownTactic	(	PTacticAbsurd			"H1" "H2"						)
				]

// -------------------------------------------------------------------------------------------------------------------------------------------------
createImpliesXTrue :: !SectionPtr !Options !*CHeaps !*CProject -> (!Error, !TheoremPtr, !*CHeaps, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------
createImpliesXTrue section options heaps prj
	# (new_var, heaps)					= newPointer {DummyValue & pvarName = "P"} heaps
	= buildTheorem "implies_x_true" section [] "(P -> TRUE) <-> TRUE" (initial new_var) proof options heaps prj
	where
		initial p
			= CPropForall p (CIff (CImplies P CTrue) CTrue)
			where
				P	= CPropVar p
		
		proof
			=	[ KnownTactic	(	TacticIntroduce			["P"]							)
				, KnownTactic	(	TacticSplitIff											)
				, KnownTactic	(	TacticIntroduce			["H1"]							)
				, KnownTactic	(	TacticTrivial											)
				, KnownTactic	(	TacticIntroduce			["H1", "H2"]					)
				, KnownTactic	(	TacticTrivial											)
				]

// -------------------------------------------------------------------------------------------------------------------------------------------------
createInvertImplies :: !SectionPtr !Options !*CHeaps !*CProject -> (!Error, !TheoremPtr, !*CHeaps, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------
createInvertImplies section options heaps prj
	# (new_var1, heaps)					= newPointer {DummyValue & pvarName = "P"} heaps
	# (new_var2, heaps)					= newPointer {DummyValue & pvarName = "Q"} heaps
	= buildTheorem "invert_implies" section [] "(P -> Q) <-> (~Q -> ~P)" (initial new_var1 new_var2) proof options heaps prj
	where
		initial p q
			= CPropForall p (CPropForall q (CIff (CImplies P Q) (CImplies (CNot Q) (CNot P))))
			where
				P	= CPropVar p
				Q	= CPropVar q
		
		proof
			=	[ KnownTactic	(	TacticIntroduce			["P", "Q"]						)
				, KnownTactic	(	TacticSplitIff											)
				, KnownTactic	(	TacticIntroduce			["H1", "H2"]					)
				, KnownTactic	(	TacticContradiction		Implicit						)
				, UnknownTactic	(	PTacticApply			(PHypothesisFact "H1")
															(Just "H3") Implicit			)
				, UnknownTactic	(	PTacticAbsurd			"H2" "H4"						)
				, KnownTactic	(	TacticIntroduce			["H1", "H2"]					)
				, KnownTactic	(	TacticContradiction		Implicit						)
				, UnknownTactic	(	PTacticApply			(PHypothesisFact "H1")
															(Just "H3") Implicit			)
				, UnknownTactic	(	PTacticAbsurd			"H2" "H4"						)
				]

// -------------------------------------------------------------------------------------------------------------------------------------------------
createNotFalse :: !SectionPtr !Options !*CHeaps !*CProject -> (!Error, !TheoremPtr, !*CHeaps, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------
createNotFalse section options heaps prj
	= buildTheorem "not_false" section [] "~FALSE <-> TRUE" initial proof options heaps prj
	where
		initial
			= CIff (CNot CFalse) CTrue
		
		proof
			=	[ KnownTactic	(	TacticSplitIff											)
				, KnownTactic	(	TacticIntroduce			["H1"]							)
				, KnownTactic	(	TacticTrivial											)
				, KnownTactic	(	TacticIntroduce			["H1"]							)
				, KnownTactic	(	TacticContradiction		Implicit						)
				, UnknownTactic	(	PTacticExFalso			"H2"							)
				]

// -------------------------------------------------------------------------------------------------------------------------------------------------
createNotNot :: !SectionPtr !Options !*CHeaps !*CProject -> (!Error, !TheoremPtr, !*CHeaps, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------
createNotNot section options heaps prj
	# (new_var, heaps)					= newPointer {DummyValue & pvarName = "P"} heaps
	= buildTheorem "not_not" section [] "~~P <-> P" (initial new_var) proof options heaps prj
	where
		initial p
			= CPropForall p (CIff (CNot (CNot (CPropVar p))) (CPropVar p))
		
		proof
			=	[ KnownTactic	(	TacticIntroduce			["P"]							)
				, KnownTactic	(	TacticSplitIff											)
				, KnownTactic	(	TacticIntroduce			["H1"]							)
				, KnownTactic	(	TacticContradiction		Implicit						)
				, UnknownTactic	(	PTacticAbsurd			"H1" "H2"						)
				, KnownTactic	(	TacticIntroduce			["H1"]							)
				, KnownTactic	(	TacticContradiction		Implicit						)
				, UnknownTactic	(	PTacticAbsurd			"H1" "H2"						)
				]

// -------------------------------------------------------------------------------------------------------------------------------------------------
createNotTrue :: !SectionPtr !Options !*CHeaps !*CProject -> (!Error, !TheoremPtr, !*CHeaps, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------
createNotTrue section options heaps prj
	= buildTheorem "not_true" section [] "~TRUE <-> FALSE" initial proof options heaps prj
	where
		initial
			= CIff (CNot CTrue) CFalse
		
		proof
			=	[ KnownTactic	(	TacticSplitIff											)
				, KnownTactic	(	TacticIntroduce			["H1"]							)
				, UnknownTactic	(	PTacticContradiction	(Just "H1") Implicit			)
				, KnownTactic	(	TacticTrivial											)
				, KnownTactic	(	TacticIntroduce			["H1"]							)
				, UnknownTactic	(	PTacticExFalso			"H1"							)
				]

// -------------------------------------------------------------------------------------------------------------------------------------------------
createOrNotLeft :: !SectionPtr !Options !*CHeaps !*CProject -> (!Error, !TheoremPtr, !*CHeaps, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------
createOrNotLeft section options heaps prj
	# (new_var1, heaps)					= newPointer {DummyValue & pvarName = "P"} heaps
	# (new_var2, heaps)					= newPointer {DummyValue & pvarName = "Q"} heaps
	= buildTheorem "or_not_left" section [] "~P -> (P \\/ Q) <-> Q" (initial new_var1 new_var2) proof options heaps prj
	where
		initial p q
			= CPropForall p (CPropForall q (CImplies (CNot P) (CIff (COr P Q) Q)))
			where
				P	= CPropVar p
				Q	= CPropVar q
		
		proof
			=	[ KnownTactic	(	TacticIntroduce			["P", "Q", "H1"]				)
				, KnownTactic	(	TacticSplitIff											)
				, KnownTactic	(	TacticIntroduce			["H2"]							)
				, UnknownTactic	(	PTacticCase				Shallow Nothing
															(Just "H2") Implicit			)
				, UnknownTactic	(	PTacticAbsurd			"H1" "H2"						)
				, UnknownTactic	(	PTacticExact			(PHypothesisFact "H2")			)
				, KnownTactic	(	TacticIntroduce			["H2"]							)
				, KnownTactic	(	TacticCase				Shallow 2						)
				, UnknownTactic	(	PTacticExact			(PHypothesisFact "H2")			)
				]

// -------------------------------------------------------------------------------------------------------------------------------------------------
createOrNotRight :: !SectionPtr !Options !*CHeaps !*CProject -> (!Error, !TheoremPtr, !*CHeaps, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------
createOrNotRight section options heaps prj
	# (new_var1, heaps)					= newPointer {DummyValue & pvarName = "P"} heaps
	# (new_var2, heaps)					= newPointer {DummyValue & pvarName = "Q"} heaps
	= buildTheorem "or_not_right" section [] "~Q -> (P \\/ Q) <-> P" (initial new_var1 new_var2) proof options heaps prj
	where
		initial p q
			= CPropForall p (CPropForall q (CImplies (CNot Q) (CIff (COr P Q) P)))
			where
				P	= CPropVar p
				Q	= CPropVar q
		
		proof
			=	[ KnownTactic	(	TacticIntroduce			["P", "Q", "H1"]				)
				, KnownTactic	(	TacticSplitIff											)
				, KnownTactic	(	TacticIntroduce			["H2"]							)
				, UnknownTactic	(	PTacticCase				Shallow Nothing
															(Just "H2") Implicit			)
				, UnknownTactic	(	PTacticExact			(PHypothesisFact "H2")			)
				, UnknownTactic	(	PTacticAbsurd			"H1" "H2"						)
				, KnownTactic	(	TacticIntroduce			["H2"]							)
				, KnownTactic	(	TacticCase				Shallow 1						)
				, UnknownTactic	(	PTacticExact			(PHypothesisFact "H2")			)
				]

// -------------------------------------------------------------------------------------------------------------------------------------------------
createOrFalseX :: !SectionPtr !Options !*CHeaps !*CProject -> (!Error, !TheoremPtr, !*CHeaps, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------
createOrFalseX section options heaps prj
	# (new_var, heaps)					= newPointer {DummyValue & pvarName = "P"} heaps
	= buildTheorem "or_false_x" section [] "(FALSE \\/ P) <-> P" (initial new_var) proof options heaps prj
	where
		initial p
			= CPropForall p (CIff (COr CFalse P) P)
			where
				P	= CPropVar p
		
		proof
			=	[ KnownTactic	(	TacticIntroduce			["P"]							)
				, KnownTactic	(	TacticSplitIff											)
				, KnownTactic	(	TacticIntroduce			["H1"]							)
				, UnknownTactic	(	PTacticCase				Shallow Nothing
															(Just "H1") Implicit			)
				, UnknownTactic	(	PTacticExFalso			"H1"							)
				, UnknownTactic	(	PTacticExact			(PHypothesisFact "H1")			)
				, KnownTactic	(	TacticIntroduce			["H1"]							)
				, KnownTactic	(	TacticCase				Shallow 2						)
				, UnknownTactic	(	PTacticExact			(PHypothesisFact "H1")			)
				]

// -------------------------------------------------------------------------------------------------------------------------------------------------
createOrTrueX :: !SectionPtr !Options !*CHeaps !*CProject -> (!Error, !TheoremPtr, !*CHeaps, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------
createOrTrueX section options heaps prj
	# (new_var, heaps)					= newPointer {DummyValue & pvarName = "P"} heaps
	= buildTheorem "or_true_x" section [] "(TRUE \\/ P) <-> TRUE" (initial new_var) proof options heaps prj
	where
		initial p
			= CPropForall p (CIff (COr CTrue P) CTrue)
			where
				P	= CPropVar p
		
		proof
			=	[ KnownTactic	(	TacticIntroduce			["P"]							)
				, KnownTactic	(	TacticSplitIff											)
				, KnownTactic	(	TacticIntroduce			["H1"]							)
				, KnownTactic	(	TacticTrivial											)
				, KnownTactic	(	TacticIntroduce			["H1"]							)
				, KnownTactic	(	TacticCase				Shallow 1						)
				, KnownTactic	(	TacticTrivial											)
				]

// -------------------------------------------------------------------------------------------------------------------------------------------------
createOrXFalse :: !SectionPtr !Options !*CHeaps !*CProject -> (!Error, !TheoremPtr, !*CHeaps, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------
createOrXFalse section options heaps prj
	# (new_var, heaps)					= newPointer {DummyValue & pvarName = "P"} heaps
	= buildTheorem "or_x_false" section [] "(P \\/ FALSE) <-> P" (initial new_var) proof options heaps prj
	where
		initial p
			= CPropForall p (CIff (COr P CFalse) P)
			where
				P	= CPropVar p
		
		proof
			=	[ KnownTactic	(	TacticIntroduce			["P"]							)
				, KnownTactic	(	TacticSplitIff											)
				, KnownTactic	(	TacticIntroduce			["H1"]							)
				, UnknownTactic	(	PTacticCase				Shallow Nothing
															(Just "H1") Implicit			)
				, UnknownTactic	(	PTacticExact			(PHypothesisFact "H1")			)
				, UnknownTactic	(	PTacticExFalso			"H1"							)
				, KnownTactic	(	TacticIntroduce			["H1"]							)
				, KnownTactic	(	TacticCase				Shallow 1						)
				, UnknownTactic	(	PTacticExact			(PHypothesisFact "H1")			)
				]

// -------------------------------------------------------------------------------------------------------------------------------------------------
createOrXTrue :: !SectionPtr !Options !*CHeaps !*CProject -> (!Error, !TheoremPtr, !*CHeaps, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------
createOrXTrue section options heaps prj
	# (new_var, heaps)					= newPointer {DummyValue & pvarName = "P"} heaps
	= buildTheorem "or_x_true" section [] "(P \\/ TRUE) <-> TRUE" (initial new_var) proof options heaps prj
	where
		initial p
			= CPropForall p (CIff (COr P CTrue) CTrue)
			where
				P	= CPropVar p
		
		proof
			=	[ KnownTactic	(	TacticIntroduce			["P"]							)
				, KnownTactic	(	TacticSplitIff											)
				, KnownTactic	(	TacticIntroduce			["H1"]							)
				, KnownTactic	(	TacticTrivial											)
				, KnownTactic	(	TacticIntroduce			["H1"]							)
				, KnownTactic	(	TacticCase				Shallow 2						)
				, KnownTactic	(	TacticTrivial											)
				]

// -------------------------------------------------------------------------------------------------------------------------------------------------
createReflexiveImplies :: !SectionPtr !Options !*CHeaps !*CProject -> (!Error, !TheoremPtr, !*CHeaps, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------
createReflexiveImplies section options heaps prj
	# (new_var, heaps)					= newPointer {DummyValue & pvarName = "P"} heaps
	= buildTheorem "reflexive_implies" section [] "(P -> P) <-> TRUE" (initial new_var) proof options heaps prj
	where
		initial p
			= CPropForall p (CIff (CImplies P P) CTrue)
			where
				P	= CPropVar p
		
		proof
			=	[ KnownTactic	(	TacticIntroduce			["P"]							)
				, KnownTactic	(	TacticSplitIff											)
				, KnownTactic	(	TacticIntroduce			["H1"]							)
				, KnownTactic	(	TacticTrivial											)
				, KnownTactic	(	TacticIntroduce			["H1", "H2"]					)
				, UnknownTactic	(	PTacticExact			(PHypothesisFact "H2")			)
				]

// -------------------------------------------------------------------------------------------------------------------------------------------------
createSplitIff :: !SectionPtr !Options !*CHeaps !*CProject -> (!Error, !TheoremPtr, !*CHeaps, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------
createSplitIff section options heaps prj
	# (new_var1, heaps)					= newPointer {DummyValue & pvarName = "P"} heaps
	# (new_var2, heaps)					= newPointer {DummyValue & pvarName = "Q"} heaps
	= buildTheorem "split_iff" section [] "(P <-> Q) <-> ((P -> Q) /\\ (Q -> P))" (initial new_var1 new_var2) proof options heaps prj
	where
		initial p q
			= CPropForall p (CPropForall q (CIff (CIff P Q) (CAnd (CImplies P Q) (CImplies Q P))))
			where
				P	= CPropVar p
				Q	= CPropVar q
		
		proof
			=	[ KnownTactic	(	TacticIntroduce			["P", "Q"]						)
				, KnownTactic	(	TacticSplitIff											)
				, KnownTactic	(	TacticIntroduce			["H1"]							)
				, UnknownTactic	(	PTacticSplitIff			(Just "H1") Implicit			)
				, KnownTactic	(	TacticSplit				Shallow							)
				, UnknownTactic	(	PTacticExact			(PHypothesisFact "H2")			)
				, UnknownTactic	(	PTacticExact			(PHypothesisFact "H3")			)
				, KnownTactic	(	TacticIntroduce			["H1"]							)
				, UnknownTactic	(	PTacticSplit			(Just "H1") Shallow Implicit	)
				, KnownTactic	(	TacticSplitIff											)
				, UnknownTactic	(	PTacticExact			(PHypothesisFact "H2")			)
				, UnknownTactic	(	PTacticExact			(PHypothesisFact "H3")			)
				]

// -------------------------------------------------------------------------------------------------------------------------------------------------
createSymmetricAnd :: !SectionPtr !Options !*CHeaps !*CProject -> (!Error, !TheoremPtr, !*CHeaps, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------
createSymmetricAnd section options heaps prj
	# (new_var1, heaps)					= newPointer {DummyValue & pvarName = "P"} heaps
	# (new_var2, heaps)					= newPointer {DummyValue & pvarName = "Q"} heaps
	= buildTheorem "symmetric_and" section [] "(P /\\ Q) <-> (Q /\\ P)" (initial new_var1 new_var2) proof options heaps prj
	where
		initial p q
			= CPropForall p (CPropForall q (CIff (CAnd P Q) (CAnd Q P)))
			where
				P	= CPropVar p
				Q	= CPropVar q
		
		proof
			=	[ KnownTactic	(	TacticIntroduce			["P", "Q"]						)
				, KnownTactic	(	TacticSplitIff											)
				, KnownTactic	(	TacticIntroduce			["H1"]							)
				, UnknownTactic	(	PTacticSplit			(Just "H1") Shallow Implicit	)
				, KnownTactic	(	TacticSplit				Shallow							)
				, UnknownTactic	(	PTacticExact			(PHypothesisFact "H3")			)
				, UnknownTactic	(	PTacticExact			(PHypothesisFact "H2")			)
				, KnownTactic	(	TacticIntroduce			["H1"]							)
				, UnknownTactic	(	PTacticSplit			(Just "H1") Shallow Implicit	)
				, KnownTactic	(	TacticSplit				Shallow							)
				, UnknownTactic	(	PTacticExact			(PHypothesisFact "H3")			)
				, UnknownTactic	(	PTacticExact			(PHypothesisFact "H2")			)
				]

// -------------------------------------------------------------------------------------------------------------------------------------------------
createSymmetricOr :: !SectionPtr !Options !*CHeaps !*CProject -> (!Error, !TheoremPtr, !*CHeaps, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------
createSymmetricOr section options heaps prj
	# (new_var1, heaps)					= newPointer {DummyValue & pvarName = "P"} heaps
	# (new_var2, heaps)					= newPointer {DummyValue & pvarName = "Q"} heaps
	= buildTheorem "symmetric_or" section [] "(P \\/ Q) <-> (Q \\/ P)" (initial new_var1 new_var2) proof options heaps prj
	where
		initial p q
			= CPropForall p (CPropForall q (CIff (COr P Q) (COr Q P)))
			where
				P	= CPropVar p
				Q	= CPropVar q
		
		proof
			=	[ KnownTactic	(	TacticIntroduce			["P", "Q"]						)
				, KnownTactic	(	TacticSplitIff											)
				, KnownTactic	(	TacticIntroduce			["H1"]							)
				, UnknownTactic	(	PTacticCase				Shallow Nothing
															(Just "H1") Implicit			)
				, KnownTactic	(	TacticCase				Shallow 2						)
				, UnknownTactic	(	PTacticExact			(PHypothesisFact "H1")			)
				, KnownTactic	(	TacticCase				Shallow 1						)
				, UnknownTactic	(	PTacticExact			(PHypothesisFact "H1")			)
				, KnownTactic	(	TacticIntroduce			["H1"]							)
				, UnknownTactic	(	PTacticCase				Shallow Nothing
															(Just "H1") Implicit			)
				, KnownTactic	(	TacticCase				Shallow 2						)
				, UnknownTactic	(	PTacticExact			(PHypothesisFact "H1")			)
				, KnownTactic	(	TacticCase				Shallow 1						)
				, UnknownTactic	(	PTacticExact			(PHypothesisFact "H1")			)
				]

// -------------------------------------------------------------------------------------------------------------------------------------------------
createTertium :: !SectionPtr !TheoremPtr !Options !*CHeaps !*CProject -> (!Error, !TheoremPtr, !*CHeaps, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------
createTertium section de_morgan_or options heaps prj
	# (new_var, heaps)					= newPointer {DummyValue & pvarName = "P"} heaps
	= buildTheorem "tertium" section [de_morgan_or] "P \/ ~P" (initial new_var) proof options heaps prj
	where
		initial p
			= CPropForall p (COr P (CNot P))
			where
				P	= CPropVar p
		
		proof
			=	[ KnownTactic	(	TacticIntroduce			["P"]							)
				, KnownTactic	(	TacticContradiction		Implicit						)
				, UnknownTactic	(	PTacticRewrite			LeftToRight AllRedexes
															(PTheoremFact "deMorgan_or")
															(Just "H1") Implicit			)
				, UnknownTactic	(	PTacticSplit			(Just "H1") Shallow Implicit	)
				, UnknownTactic	(	PTacticAbsurd			"H2" "H3"						)
				]