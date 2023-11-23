/*
** Program: Clean Prover System
** Module:  Depends (.icl)
** 
** Author:  Maarten de Mol
** Created: 13 March 2001
**
** (1) Dependency graph of modules is complete; it is not needed to follow chains.
** (2) Dependency graph of theorems is not complete; it IS needed to follow chains.
*/

implementation module
	Depends

import
	StdEnv,
	Operate,
	States

// -------------------------------------------------------------------------------------------------------------------------------------------------
havePtrOverlap :: ![TheoremPtr] ![TheoremPtr] -> Bool
// -------------------------------------------------------------------------------------------------------------------------------------------------
havePtrOverlap [ptr:ptrs1] ptrs2
	| isMember ptr ptrs2						= True
	= havePtrOverlap ptrs1 ptrs2
havePtrOverlap [] ptrs2
	= False















// nilPtr can be used for Predefined module
// -------------------------------------------------------------------------------------------------------------------------------------------------
theoremsUsingModule :: !ModulePtr !*PState -> (![TheoremPtr], !*PState)
// -------------------------------------------------------------------------------------------------------------------------------------------------
theoremsUsingModule module_ptr pstate
	# (theorem_ptrs, pstate)					= allTheorems pstate
	= accHeaps (filter_used theorem_ptrs) pstate
	where
		filter_used :: ![TheoremPtr] !*CHeaps -> (![TheoremPtr], !*CHeaps)
		filter_used [ptr:ptrs] heaps
			# (ptrs, heaps)						= filter_used ptrs heaps
			# (theorem, heaps)					= readPointer ptr heaps
			# symbols							= theorem.thProof.pUsedSymbols
			# modules							= map ptrModule symbols
			# used								= or (map (safePtrEq module_ptr) modules)
			| not used							= (ptrs, heaps)
			= ([ptr:ptrs], heaps)
		filter_used [] heaps
			= ([], heaps)

// nilPtr can be used for Predefined module
// -------------------------------------------------------------------------------------------------------------------------------------------------
modulesUsingModule :: !ModulePtr !*PState -> (![ModulePtr], !*PState)
// -------------------------------------------------------------------------------------------------------------------------------------------------
modulesUsingModule module_ptr pstate
	| isNilPtr module_ptr						= pstate!ls.stProject.prjModules
	# (all_ptrs, pstate)						= pstate!ls.stProject.prjModules
	= accHeaps (filter_used all_ptrs) pstate
	where
		filter_used :: ![ModulePtr] !*CHeaps -> (![ModulePtr], !*CHeaps)
		filter_used [ptr:ptrs] heaps
			# (ptrs, heaps)						= filter_used ptrs heaps
			# (mod, heaps)						= readPointer ptr heaps
			# used								= isMember module_ptr mod.pmImportedModules
			| not used							= (ptrs, heaps)
			= ([ptr:ptrs], heaps)
		filter_used [] heaps
			= ([], heaps)





// -------------------------------------------------------------------------------------------------------------------------------------------------
theoremsUsingTheorem :: !TheoremPtr !*PState -> (![TheoremPtr], !*PState)
// -------------------------------------------------------------------------------------------------------------------------------------------------
theoremsUsingTheorem theorem_ptr pstate
	# (all_sections, pstate)					= pstate!ls.stSections
	= accHeaps (check_sections all_sections) pstate
	where
		check_sections :: ![SectionPtr] !*CHeaps -> (![TheoremPtr], !*CHeaps)
		check_sections [ptr:ptrs] heaps
			# (section, heaps)					= readPointer ptr heaps
			# (theorems1, heaps)				= check_theorems section.seTheorems heaps
			# (theorems2, heaps)				= check_sections ptrs heaps
			= (theorems1 ++ theorems2, heaps)
		check_sections [] heaps
			= ([], heaps)
		
		check_theorems :: ![TheoremPtr] !*CHeaps -> (![TheoremPtr], !*CHeaps)
		check_theorems [ptr:ptrs] heaps
			# (ptrs, heaps)						= check_theorems ptrs heaps
			# (theorem, heaps)					= readPointer ptr heaps
			# used								= theorem.thProof.pUsedTheorems
			= case isMember theorem_ptr used of
				True	-> ([ptr:ptrs], heaps)
				False	-> (ptrs, heaps)
		check_theorems [] heaps
			= ([], heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
theoremsUsingSection :: !SectionPtr !*PState -> (![TheoremPtr], !*PState)
// -------------------------------------------------------------------------------------------------------------------------------------------------
theoremsUsingSection section_ptr pstate
	# (section, pstate)							= accHeaps (readPointer section_ptr) pstate
	# (all_sections, pstate)					= pstate!ls.stSections
	= accHeaps (check_sections all_sections section.seTheorems) pstate
	where
		check_sections :: ![SectionPtr] ![TheoremPtr] !*CHeaps -> (![TheoremPtr], !*CHeaps)
		check_sections [ptr:ptrs] theorems heaps
			| ptr == section_ptr				= check_sections ptrs theorems heaps
			# (section, heaps)					= readPointer ptr heaps
			# (theorems1, heaps)				= check_theorems section.seTheorems theorems heaps
			# (theorems2, heaps)				= check_sections ptrs theorems heaps
			= (theorems1 ++ theorems2, heaps)
		check_sections [] theorems heaps
			= ([], heaps)
		
		check_theorems :: ![TheoremPtr] ![TheoremPtr] !*CHeaps -> (![TheoremPtr], !*CHeaps)
		check_theorems [ptr:ptrs] theorems heaps
			# (ptrs, heaps)						= check_theorems ptrs theorems heaps
			# (theorem, heaps)					= readPointer ptr heaps
			# used								= theorem.thProof.pUsedTheorems
			= case havePtrOverlap used theorems of
				True	-> ([ptr:ptrs], heaps)
				False	-> (ptrs, heaps)
		check_theorems [] theorems heaps
			= ([], heaps)


















// -------------------------------------------------------------------------------------------------------------------------------------------------
isTheoremProved :: !TheoremPtr !*PState -> (!Bool, ![TheoremPtr], ![TheoremPtr], !*PState)
// -------------------------------------------------------------------------------------------------------------------------------------------------
isTheoremProved ptr pstate
	# (theorem, pstate)							= accHeaps (readPointer ptr) pstate
	# (proved_ptrs, unproved_ptrs, pstate)		= areTheoremsProved theorem.thProof.pUsedTheorems [] [] pstate
	# proof_complete							= isEmpty theorem.thProof.pLeafs
	# depends_ok								= isEmpty unproved_ptrs
	= (proof_complete && depends_ok, proved_ptrs, unproved_ptrs, pstate)

// -------------------------------------------------------------------------------------------------------------------------------------------------
areTheoremsProved :: ![TheoremPtr] ![TheoremPtr] ![TheoremPtr] !*PState -> (![TheoremPtr], ![TheoremPtr], !*PState)
// -------------------------------------------------------------------------------------------------------------------------------------------------
areTheoremsProved [ptr:ptrs] proved unproved pstate
	| isMember ptr proved						= areTheoremsProved ptrs proved unproved pstate
	| isMember ptr unproved						= areTheoremsProved ptrs proved unproved pstate
	# (yes, add_proved, add_unproved, pstate)	= isTheoremProved ptr pstate
	# all_proved								= add_proved ++ proved
	# all_unproved								= add_unproved ++ unproved
	= case yes of
		True	-> areTheoremsProved ptrs [ptr:all_proved] all_unproved pstate
		False	-> areTheoremsProved ptrs all_proved [ptr:all_unproved] pstate
areTheoremsProved [] proved unproved pstate
	= (removeDup proved, removeDup unproved, pstate)


















// -------------------------------------------------------------------------------------------------------------------------------------------------
resetDependencies :: !TheoremPtr !*PState -> *PState
// -------------------------------------------------------------------------------------------------------------------------------------------------
resetDependencies ptr pstate
	# (theorem, pstate)							= accHeaps (readPointer ptr) pstate
	# (theorem_ptrs, symbol_ptrs, pstate)		= acc2Heaps (acc_depends [theorem.thProof.pTree] [] []) pstate
	# (used_symbols, pstate)					= accHeaps (GetUsedSymbols theorem.thInitial) pstate
	# theorem									= { theorem		& thProof.pUsedTheorems		= removeDup theorem_ptrs
																, thProof.pUsedSymbols		= removeDup (symbol_ptrs ++ used_symbols)
												  }
	# pstate									= appHeaps (writePointer ptr theorem) pstate
	= pstate
	where
		acc_depends :: ![ProofTreePtr] ![TheoremPtr] ![HeapPtr] !*CHeaps -> (![TheoremPtr], ![HeapPtr], !*CHeaps)
		acc_depends [ptr:ptrs] theorems symbols heaps
			# (tree, heaps)						= readPointer ptr heaps
			# (theorems, symbols, heaps)		= add_tree tree theorems symbols heaps
			= acc_depends ptrs theorems symbols heaps
		acc_depends [] theorems symbols heaps
			= (theorems, symbols, heaps)
		
		add_tree :: !ProofTree ![TheoremPtr] ![HeapPtr] !*CHeaps -> (![TheoremPtr], ![HeapPtr], !*CHeaps)
		add_tree (ProofLeaf goal) theorems symbols heaps
			= (theorems, symbols, heaps)
		add_tree (ProofNode _ tactic children) theorems symbols heaps
			# (theorems, symbols, heaps)		= add_tactic tactic theorems symbols heaps
			= acc_depends children theorems symbols heaps
		
		add_tactic :: !TacticId ![TheoremPtr] ![HeapPtr] !*CHeaps -> (![TheoremPtr], ![HeapPtr], !*CHeaps)
		add_tactic (TacticApply fact) theorems symbols heaps
			= add_fact fact theorems symbols heaps
		add_tactic (TacticApplyH fact _ _) theorems symbols heaps
			= add_fact fact theorems symbols heaps
		add_tactic (TacticAssume prop _) theorems symbols heaps
			= add_prop prop theorems symbols heaps
		add_tactic (TacticCases expr _) theorems symbols heaps
			= add_expr expr theorems symbols heaps
		add_tactic (TacticCompare e1 e2) theorems symbols heaps
			# (theorems, symbols, heaps)		= add_expr e1 theorems symbols heaps
			= add_expr e2 theorems symbols heaps
		add_tactic (TacticCut fact) theorems symbols heaps
			= add_fact fact theorems symbols heaps
		add_tactic (TacticExact fact) theorems symbols heaps
			= add_fact fact theorems symbols heaps
		add_tactic (TacticGeneralizeE expr _) theorems symbols heaps
			= add_expr expr theorems symbols heaps
		add_tactic (TacticGeneralizeP prop _) theorems symbols heaps
			= add_prop prop theorems symbols heaps
		add_tactic (TacticOpaque ptr) theorems symbols heaps
			= (theorems, [ptr:symbols], heaps)
		add_tactic (TacticRewrite _ _ fact) theorems symbols heaps
			= add_fact fact theorems symbols heaps
		add_tactic (TacticRewriteH _ _ fact _ _) theorems symbols heaps
			= add_fact fact theorems symbols heaps
		add_tactic (TacticSpecializeE _ expr _) theorems symbols heaps
			= add_expr expr theorems symbols heaps
		add_tactic (TacticSpecializeP _ prop _) theorems symbols heaps
			= add_prop prop theorems symbols heaps
		add_tactic (TacticTransitiveE expr) theorems symbols heaps
			= add_expr expr theorems symbols heaps
		add_tactic (TacticTransitiveP prop) theorems symbols heaps
			= add_prop prop theorems symbols heaps
		add_tactic (TacticWitnessE expr) theorems symbols heaps
			= add_expr expr theorems symbols heaps
		add_tactic (TacticWitnessP prop) theorems symbols heaps
			= add_prop prop theorems symbols heaps
		add_tactic _ theorems symbols heaps
			= (theorems, symbols, heaps)
		
		add_fact :: !UseFact ![TheoremPtr] ![HeapPtr] !*CHeaps -> (![TheoremPtr], ![HeapPtr], !*CHeaps)
		add_fact (HypothesisFact _ args) theorems symbols heaps
			= add_fact_args args theorems symbols heaps
		add_fact (TheoremFact ptr args) theorems symbols heaps
			= add_fact_args args [ptr:theorems] symbols heaps
		
		add_fact_args :: ![UseFactArgument] ![TheoremPtr] ![HeapPtr] !*CHeaps -> (![TheoremPtr], ![HeapPtr], !*CHeaps)
		add_fact_args [] theorems symbols heaps
			= (theorems, symbols, heaps)
		add_fact_args [NoArgument: args] theorems symbols heaps
			= add_fact_args args theorems symbols heaps
		add_fact_args [ExprArgument expr: args] theorems symbols heaps
			# (theorems, symbols, heaps)		= add_expr expr theorems symbols heaps
			= add_fact_args args theorems symbols heaps
		add_fact_args [PropArgument prop: args] theorems symbols heaps
			# (theorems, symbols, heaps)		= add_prop prop theorems symbols heaps
			= add_fact_args args theorems symbols heaps
		
		add_expr :: !CExprH ![TheoremPtr] ![HeapPtr] !*CHeaps -> (![TheoremPtr], ![HeapPtr], !*CHeaps)
		add_expr e theorems symbols heaps
			# (used_symbols, heaps)				= GetUsedSymbols e heaps
			= (theorems, used_symbols ++ symbols, heaps)		
		
		add_prop :: !CPropH ![TheoremPtr] ![HeapPtr] !*CHeaps -> (![TheoremPtr], ![HeapPtr], !*CHeaps)
		add_prop p theorems symbols heaps
			# (used_symbols, heaps)				= GetUsedSymbols p heaps
			= (theorems, used_symbols ++ symbols, heaps)