/*
** Program: Clean Prover System
** Module:  Tactics (.icl)
** 
** Author:  Maarten de Mol
** Created: 20 November 2000
*/

implementation module 
	Tactics

import 
	StdEnv,
	Arith,
	Compare,
	Definedness,
	States,
	CoreTypes,
	CoreAccess,
	ProveTypes,
	Operate,
	GiveType,
	Print,
	Rewrite,
	LTypes,
	LReduce,
	BindLexeme
	, RWSDebug

// ------------------------------------------------------------------------------------------------------------------------
:: Tactic			:== Goal *CHeaps -> *(*CProject -> *(Error, [Goal], [TheoremPtr], [HeapPtr], *CHeaps, *CProject))
// ------------------------------------------------------------------------------------------------------------------------

// ------------------------------------------------------------------------------------------------------------------------
:: Either a b =
// ------------------------------------------------------------------------------------------------------------------------
	  ELeft a
	| ERight b

// ------------------------------------------------------------------------------------------------------------------------
:: Either3 a b c =
// ------------------------------------------------------------------------------------------------------------------------
	  E1 a
	| E2 b
	| E3 c

// ------------------------------------------------------------------------------------------------------------------------
apply :: !TacticId -> Tactic
// ------------------------------------------------------------------------------------------------------------------------
apply (TacticAbsurd ptr1 ptr2)				= Absurd ptr1 ptr2
apply (TacticAbsurdEquality)				= AbsurdEquality
apply (TacticAbsurdEqualityH ptr)			= AbsurdEqualityH ptr
apply (TacticApply fact)					= Apply fact
apply (TacticApplyH fact ptr mode)			= ApplyH fact ptr mode
apply (TacticAssume prop mode)				= Assume prop mode
apply TacticAxiom							= Axiom
apply (TacticCase depth num)				= CaseN depth num
apply (TacticCaseH depth hyp mode)			= CaseH depth hyp mode
apply (TacticCases expr mode)				= Cases expr mode
apply TacticChooseCase						= ChooseCase
apply (TacticChooseCaseH ptr)				= ChooseCaseH ptr
apply (TacticCompare e1 e2)					= Compare e1 e2
apply (TacticCompareH ptr mode)				= CompareH ptr mode
apply (TacticContradiction mode)			= Contradiction mode
apply (TacticContradictionH hyp)			= ContradictionH hyp
apply (TacticCut fact)						= Cut fact
apply TacticDefinedness						= Definedness
apply (TacticDiscard evars pvars hyps)		= Discard evars pvars hyps
apply (TacticExact fact)					= Exact fact
apply (TacticExFalso hyp)					= ExFalso hyp
apply (TacticExpandFun name index)			= unsupported "ExpandFun" // ExpandFun name index
apply (TacticExpandFunH name index ptr mode)= unsupported "ExpandFun" // ExpandFunH name index ptr mode
apply (TacticExtensionality name)			= Extensionality name
apply (TacticGeneralizeE expr name)			= GeneralizeE expr name
apply (TacticGeneralizeP prop name)			= GeneralizeP prop name
apply (TacticInduction ptr mode)			= Induction ptr mode
apply TacticInjective						= Injective
apply (TacticInjectiveH ptr mode)			= InjectiveH ptr mode
apply (TacticIntroduce names)				= Introduce names
apply (TacticIntArith location)				= IntArith location
apply (TacticIntArithH location ptr mode)	= IntArithH location ptr mode
apply TacticIntCompare						= IntCompare
apply TacticMakeUnique						= MakeUnique
apply (TacticManualDefinedness ptrs)		= ManualDefinedness ptrs
apply (TacticMoveInCase name index)			= unsupported "MoveInCase" // MoveInCase name index
apply (TacticMoveInCaseH name i ptr mode)	= unsupported "MoveInCase" // MoveInCaseH name i ptr mode
apply (TacticMoveQuantors dir)				= MoveQuantors dir
apply (TacticMoveQuantorsH dir ptr mode)	= MoveQuantorsH dir ptr mode
apply (TacticOpaque ptr)					= Opaque ptr
apply (TacticReduce rm am loc ps)			= ReduceN rm am loc ps
apply (TacticReduceH rm am loc hyp ps mode)	= ReduceH rm am loc hyp ps mode
apply TacticRefineUndefinedness				= RefineUndefinedness
apply (TacticRefineUndefinednessH ptr mode)	= RefineUndefinednessH ptr mode
apply TacticReflexive						= Reflexive
apply (TacticRemoveCase index)				= unsupported "RemoveCase" // RemoveCase index
apply (TacticRemoveCaseH index ptr mode)	= unsupported "RemoveCase" // RemoveCaseH index ptr mode
apply (TacticRenameE ptr name)				= RenameE ptr name
apply (TacticRenameP ptr name)				= RenameP ptr name
apply (TacticRenameH ptr name)				= RenameH ptr name
apply (TacticRewrite dir redex fact)		= RewriteN dir redex fact
apply (TacticRewriteH dir redex fact hyp m) = RewriteH dir redex fact hyp m
apply (TacticSpecializeE ptr expr mode)		= SpecializeE ptr expr mode
apply (TacticSpecializeP ptr prop mode)		= SpecializeP ptr prop mode
apply (TacticSplit depth)					= Split depth
apply (TacticSplitCase num mode)			= SplitCase num mode
apply (TacticSplitH ptr depth mode)			= SplitH ptr depth mode
apply TacticSplitIff						= SplitIff
apply (TacticSplitIffH ptr mode)			= SplitIffH ptr mode
apply TacticSymmetric						= Symmetric
apply (TacticSymmetricH ptr mode)			= SymmetricH ptr mode
apply (TacticTransitiveE expr)				= TransitiveE expr
apply (TacticTransitiveP prop)				= TransitiveP prop
apply (TacticTransparent ptr)				= Transparent ptr
apply TacticTrivial							= Trivial
apply TacticUncurry							= Uncurry
apply (TacticUncurryH ptr mode)				= UncurryH ptr mode
apply (TacticUnshare mode letl var varl)	= Unshare mode letl var varl
apply (TacticUnshareH mode letl var varl h)	= UnshareH mode letl var varl h
apply (TacticWitnessE expr)					= WitnessE expr
apply (TacticWitnessP prop)					= WitnessP prop
apply (TacticWitnessH ptr mode)				= WitnessH ptr mode

// ------------------------------------------------------------------------------------------------------------------------
tacticTitle :: !TacticId -> String
// ------------------------------------------------------------------------------------------------------------------------
tacticTitle (TacticAbsurd _ _)				= "Absurd"
tacticTitle (TacticAbsurdEquality)			= "AbsurdEquality"
tacticTitle (TacticAbsurdEqualityH _)		= "AbsurdEquality"
tacticTitle (TacticApply _)					= "Apply"
tacticTitle (TacticApplyH _ _ _)			= "Apply"
tacticTitle (TacticAssume _ _)				= "Assume"
tacticTitle TacticAxiom						= "Axiom"
tacticTitle (TacticCase _ _)				= "Case"
tacticTitle (TacticCaseH _ _ _)				= "Case"
tacticTitle (TacticCases _ _)				= "Cases"
tacticTitle TacticChooseCase				= "ChooseCase"
tacticTitle (TacticChooseCaseH _)			= "ChooseCase"
tacticTitle (TacticCompare _ _)				= "Compare"
tacticTitle (TacticCompareH _ _)			= "Compare"
tacticTitle (TacticContradiction _)			= "Contradiction"
tacticTitle (TacticContradictionH _)		= "Contradiction"
tacticTitle (TacticCut _)					= "Cut"
tacticTitle TacticDefinedness				= "Definedness"
tacticTitle (TacticDiscard _ _ _)			= "Discard"
tacticTitle (TacticExact _)					= "Exact"
tacticTitle (TacticExFalso _)				= "ExFalso"
tacticTitle (TacticExpandFun _ _)			= "ExpandFun"
tacticTitle (TacticExpandFunH _ _ _ _)		= "ExpandFun"
tacticTitle (TacticExtensionality name)		= "Extensionality"
tacticTitle (TacticGeneralizeE _ _)			= "Generalize"
tacticTitle (TacticGeneralizeP _ _)			= "Generalize"
tacticTitle (TacticInduction _ _)			= "Induction"
tacticTitle TacticInjective					= "Injective"
tacticTitle (TacticInjectiveH _ _)			= "InjectiveH"
tacticTitle (TacticIntroduce _)				= "Intro"
tacticTitle (TacticIntArith _)				= "IntArith"
tacticTitle (TacticIntArithH _ _ _)			= "IntArith"
tacticTitle TacticIntCompare				= "IntCompare"
tacticTitle TacticMakeUnique				= "MakeUnique"
tacticTitle (TacticManualDefinedness _)		= "ManualDefinedness"
tacticTitle (TacticMoveInCase _ _)			= "MoveInCase"
tacticTitle (TacticMoveInCaseH _ _ _ _)		= "MoveInCase"
tacticTitle (TacticMoveQuantors _)			= "MoveQuantors"
tacticTitle (TacticMoveQuantorsH _ _ _)		= "MoveQuantors"
tacticTitle (TacticOpaque _)				= "Opaque"
tacticTitle (TacticReduce _ _ _ _)			= "Reduce"
tacticTitle (TacticReduceH _ _ _ _ _ _)		= "Reduce"
tacticTitle TacticRefineUndefinedness		= "RefineUndefinedness"
tacticTitle (TacticRefineUndefinednessH _ _)= "RefineUndefinedness"
tacticTitle TacticReflexive					= "Reflexive"
tacticTitle (TacticRemoveCase _)			= "RemoveCase"
tacticTitle (TacticRemoveCaseH _ _ _)		= "RemoveCase"
tacticTitle (TacticRenameE _ _)				= "Rename"
tacticTitle (TacticRenameP _ _)				= "Rename"
tacticTitle (TacticRenameH _ _)				= "Rename"
tacticTitle (TacticRewrite _ _ _)			= "Rewrite"
tacticTitle (TacticRewriteH _ _ _ _ _)		= "Rewrite"
tacticTitle (TacticSpecializeE _ _ _)		= "Specialize"
tacticTitle (TacticSpecializeP _ _ _)		= "Specialize"
tacticTitle (TacticSplit _)					= "Split"
tacticTitle (TacticSplitH _ _ _)			= "Split"
tacticTitle (TacticSplitCase _ _)			= "SplitCase"
tacticTitle TacticSplitIff					= "SplitIff"
tacticTitle (TacticSplitIffH _ _)			= "SplitIff"
tacticTitle TacticSymmetric					= "Symmetric"
tacticTitle (TacticSymmetricH _ _)			= "Symmetric"
tacticTitle (TacticTransitiveE _)			= "Transitive"
tacticTitle (TacticTransitiveP _)			= "Transitive"
tacticTitle (TacticTransparent _)			= "Transparent"
tacticTitle TacticTrivial					= "Trivial"
tacticTitle TacticUncurry					= "Uncurry"
tacticTitle (TacticUncurryH _ _)			= "Uncurry"
tacticTitle (TacticUnshare _ _ _ _)			= "Unshare"
tacticTitle (TacticUnshareH _ _ _ _ _)		= "Unshare"
tacticTitle (TacticWitnessE _)				= "Witness"
tacticTitle (TacticWitnessP _)				= "Witness"
tacticTitle (TacticWitnessH _ _)			= "Witness"

// ------------------------------------------------------------------------------------------------------------------------
unsupported :: !String !Goal !*CHeaps !*CProject -> (!Error, ![Goal], ![TheoremPtr], ![HeapPtr], !*CHeaps, !*CProject)
// ------------------------------------------------------------------------------------------------------------------------
unsupported title goal heaps prj
	# error									= pushError (X_Internal ("Due to buggy behavior, access to " +++ title +++ " has temporarily been removed")) OK
	= (error, [], [], [], heaps, prj)

// ------------------------------------------------------------------------------------------------------------------------
splitAtMember :: !ProofTreePtr ![ProofTreePtr] -> (![ProofTreePtr], ![ProofTreePtr])
// ------------------------------------------------------------------------------------------------------------------------
splitAtMember split_ptr [ptr:ptrs]
	| ptr == split_ptr						= ([], ptrs)
	# (before, after)						= splitAtMember split_ptr ptrs
	= ([ptr:before], after)
splitAtMember split_ptr []
	= ([], [])

// ------------------------------------------------------------------------------------------------------------------------
discardVariables :: !Bool ![Goal] !*CHeaps -> (![Goal], !*CHeaps)
// ------------------------------------------------------------------------------------------------------------------------
discardVariables False goals heaps
	= (goals, heaps)
discardVariables True [goal:goals] heaps
	# (ptr_info, heaps)						= GetPtrInfo goal heaps
	# goal									= {goal		& glExprVars	= discard_expr_vars goal.glExprVars ptr_info
														, glPropVars	= discard_prop_vars goal.glPropVars ptr_info
											  }
	# (goals, heaps)						= discardVariables True goals heaps
	= ([goal:goals], heaps)
	where
		discard_expr_vars :: ![CExprVarPtr] !PtrInfo -> [CExprVarPtr]
		discard_expr_vars [ptr:ptrs] info
			= case isMember ptr info.freeExprVars of
				True	-> [ptr: discard_expr_vars ptrs info]
				False	-> discard_expr_vars ptrs info
		discard_expr_vars [] info
			= []
		
		discard_prop_vars :: ![CPropVarPtr] !PtrInfo -> [CPropVarPtr]
		discard_prop_vars [ptr:ptrs] info
			= case isMember ptr info.freePropVars of
				True	-> [ptr: discard_prop_vars ptrs info]
				False	-> discard_prop_vars ptrs info
		discard_prop_vars [] info
			= []

discardVariables True [] heaps
	= ([], heaps)

// ------------------------------------------------------------------------------------------------------------------------
applyTactic :: !TacticId !TheoremPtr !Theorem !Options !*CHeaps !*CProject -> (!Error, !Theorem, ![ProofTreePtr], !*CHeaps, !*CProject)
// ------------------------------------------------------------------------------------------------------------------------
applyTactic tactic theorem_ptr theorem=:{thProof} options heaps prj
	| isEmpty thProof.pLeafs				= (pushError (X_ApplyTactic (tacticTitle tactic) "Theorem already proved.") OK, theorem, [], heaps, prj)
	#! prj									= setManualDefinedness thProof.pCurrentGoal prj
	# (error, created_goals, used_theorems, used_symbols, heaps, prj)
											= apply tactic thProof.pCurrentGoal heaps prj
	#! prj									= unsetManualDefinedness thProof.pCurrentGoal prj
	| isError error							= (error, theorem, [], heaps, prj)
	# (cycle, heaps)						= test_for_cycle used_theorems heaps
	| cycle									= (pushError (X_ApplyTactic (tacticTitle tactic) "Cyclic dependency between proofs detected.") OK, theorem, [], heaps, prj)
	# (created_goals, heaps)				= discardVariables options.optAutomaticDiscard created_goals heaps
	# used_theorems							= case isEmpty used_theorems of
												True	-> theorem.thProof.pUsedTheorems
												False	-> removeDup (used_theorems ++ theorem.thProof.pUsedTheorems)
	# used_symbols							= case isEmpty used_symbols of
												True	-> theorem.thProof.pUsedSymbols
												False	-> removeDup (used_symbols ++ theorem.thProof.pUsedSymbols)
	# (created_leafs, heaps)				= newPointers (map ProofLeaf created_goals) heaps
	# heaps									= writePointer thProof.pCurrentLeaf (ProofNode (Just thProof.pCurrentGoal) tactic created_leafs) heaps
	# (old_leafs1, old_leafs2)				= splitAtMember thProof.pCurrentLeaf thProof.pLeafs
	# new_leafs								= old_leafs1 ++ created_leafs ++ old_leafs2
	| isEmpty new_leafs
		= (OK, {theorem	& thProof.pLeafs			= []
						, thProof.pCurrentLeaf		= nilPtr
						, thProof.pCurrentGoal		= DummyValue
						, thProof.pUsedTheorems		= used_theorems
						, thProof.pUsedSymbols		= used_symbols
						}, created_leafs, heaps, prj)
	| isEmpty created_goals
		# new_leaf							= case old_leafs2 of
												[new_leaf:_]	-> new_leaf
												[]				-> hd old_leafs1
		# (new_goal, heaps)					= get_goal new_leaf heaps
		= (OK, {theorem	& thProof.pLeafs			= new_leafs
						, thProof.pCurrentLeaf		= new_leaf
						, thProof.pCurrentGoal		= new_goal
						, thProof.pUsedTheorems		= used_theorems
						, thProof.pUsedSymbols		= used_symbols
						}, created_leafs, heaps, prj)
	| otherwise
		= (OK, {theorem	& thProof.pLeafs			= new_leafs
						, thProof.pCurrentLeaf		= hd created_leafs
						, thProof.pCurrentGoal		= hd created_goals
						, thProof.pUsedTheorems		= used_theorems
						, thProof.pUsedSymbols		= used_symbols
						}, created_leafs, heaps, prj)
	where
		get_goal :: !ProofTreePtr !*CHeaps -> (!Goal, !*CHeaps)
		get_goal ptr heaps
			# (leaf, heaps)					= readPointer ptr heaps
			= (fromLeaf leaf, heaps)
		
		test_for_cycle :: ![TheoremPtr] !*CHeaps -> (!Bool, !*CHeaps)
		test_for_cycle [ptr:ptrs] heaps
			# (theorem, heaps)				= readPointer ptr heaps
			| ptr == theorem_ptr			= (True, heaps)
			= test_for_cycle (theorem.thProof.pUsedTheorems ++ ptrs) heaps
		test_for_cycle [] heaps
			= (False, heaps)

// ------------------------------------------------------------------------------------------------------------------------
applyTactical :: !PTactical !TheoremPtr ![TheoremPtr] !Theorem !Options !*CHeaps !*CProject -> (!Error, !Theorem, ![ProofTreePtr], !*CHeaps, !*CProject)
// ------------------------------------------------------------------------------------------------------------------------
applyTactical (PTacticalCompose tactical1 tactical2) theorem_ptr all_theorem_ptrs theorem options heaps prj
	# (error, theorem, new, heaps, prj)		= applyTactical tactical1 theorem_ptr all_theorem_ptrs theorem options heaps prj
	| isError error							= (error, theorem, new, heaps, prj)
	= go_on new tactical2 theorem_ptr all_theorem_ptrs theorem options heaps prj
	where
		go_on :: ![ProofTreePtr] !PTactical !TheoremPtr ![TheoremPtr] !Theorem !Options !*CHeaps !*CProject -> (!Error, !Theorem, ![ProofTreePtr], !*CHeaps, !*CProject)
		go_on [ptr:ptrs] tactical theorem_ptr all_theorem_ptrs theorem options heaps prj
			# (proof, heaps)					= readPointer ptr heaps
			# goal								= fromLeaf proof
			# theorem							= {theorem	& thProof.pCurrentLeaf		= ptr
															, thProof.pCurrentGoal		= goal
												  }
			# (error, theorem, new1, heaps, prj)= applyTactical tactical theorem_ptr all_theorem_ptrs theorem options heaps prj
			| isError error						= (error, theorem, new1 ++ ptrs, heaps, prj)
			# (error, theorem, new2, heaps, prj)= go_on ptrs tactical theorem_ptr all_theorem_ptrs theorem options heaps prj
			# new								= new1 ++ new2
			| isEmpty new						= (error, theorem, new, heaps, prj)
			# new_ptr							= hd new
			# (proof, heaps)					= readPointer new_ptr heaps
			# new_goal							= fromLeaf proof
			# theorem							= {theorem	& thProof.pCurrentLeaf		= new_ptr
															, thProof.pCurrentGoal		= new_goal
												  }
			= (error, theorem, new, heaps, prj)
		go_on [] _ _ _ theorem _ heaps prj
			= (OK, theorem, [], heaps, prj)
applyTactical (PTacticalRepeat n tactical) theorem_ptr all_theorem_ptrs theorem options heaps prj
	| n >= 100								= (pushError (X_ApplyTactic "Tactical" "Cannot repeat tactic more than 100 times.") OK, theorem, [], heaps, prj)
	# (error, theorem, new, heaps, prj)		= applyTactical tactical theorem_ptr all_theorem_ptrs theorem options heaps prj
	| isError error							= (OK, theorem, [], heaps, prj)
	| isEmpty new							= (OK, theorem, [], heaps, prj)
	# (first, rest)							= (hd new, tl new)
	# (error, theorem, new, heaps, prj)		= applyTactical (PTacticalRepeat (n+1) tactical) theorem_ptr all_theorem_ptrs theorem options heaps prj
	= (error, theorem, new ++ rest, heaps, prj)
applyTactical (PTacticalTry tactical) theorem_ptr all_theorem_ptrs theorem options heaps prj
	# (error, theorem, new, heaps, prj)		= applyTactical tactical theorem_ptr all_theorem_ptrs theorem options heaps prj
	| isError error							= (OK, theorem, [theorem.thProof.pCurrentLeaf], heaps, prj)
	= (OK, theorem, new, heaps, prj)
applyTactical (PTacticalUnit tactic) theorem_ptr all_theorem_ptrs theorem options heaps prj
	# (error, tactic, heaps, prj)			= bindTactic tactic theorem.thProof.pCurrentGoal all_theorem_ptrs options heaps prj
	| isError error							= (error, theorem, [], heaps, prj)
	= applyTactic tactic theorem_ptr theorem options heaps prj
applyTactical tactical theorem_ptr all_theorem_ptrs theorem options heaps prj
	= undef























// ========================================================================================================================
// Inserts FORALLS for each unbound variable.
// ------------------------------------------------------------------------------------------------------------------------
bindVariables :: !CPropH !Goal !*CHeaps -> (!CPropH, !*CHeaps)
// ------------------------------------------------------------------------------------------------------------------------
bindVariables prop goal heaps
	# (evars, heaps)						= readPointers goal.glExprVars heaps
	# (pvars, heaps)						= readPointers goal.glPropVars heaps
	= bind prop DummyValue evars goal.glExprVars pvars goal.glPropVars heaps
	where
		bind :: !CPropH !Substitution ![CExprVarDef] ![CExprVarPtr] ![CPropVarDef] ![CPropVarPtr] !*CHeaps -> (!CPropH, !*CHeaps)
		bind (CExprForall ptr p) subst evars eptrs pvars pptrs heaps
			# (var, heaps)					= readPointer ptr heaps
			# (ok, known_ptr)				= find_e var.evarName evars eptrs
			| not ok
				# (p, heaps)				= bind p subst evars eptrs pvars pptrs heaps
				= (CExprForall ptr p, heaps)
			# subst							= {subst & subExprVars = [(ptr, CExprVar known_ptr):subst.subExprVars]}
			= bind p subst evars eptrs pvars pptrs heaps
		bind (CPropForall ptr p) subst evars eptrs pvars pptrs heaps
			# (var, heaps)					= readPointer ptr heaps
			# (ok, known_ptr)				= find_p var.pvarName pvars pptrs
			| not ok
				# (p, heaps)				= bind p subst evars eptrs pvars pptrs heaps
				= (CPropForall ptr p, heaps)
			# subst							= {subst & subPropVars = [(ptr, CPropVar known_ptr):subst.subPropVars]}
			= bind p subst evars eptrs pvars pptrs heaps
		bind prop subst _ _ _ _ heaps
			= SafeSubst subst prop heaps
		
		find_e :: !CName ![CExprVarDef] ![CExprVarPtr] -> (!Bool, !CExprVarPtr)
		find_e name [var:vars] [ptr:ptrs]
			| var.evarName == name			= (True, ptr)
			= find_e name vars ptrs
		find_e name [] []
			= (False, nilPtr)
		
		find_p :: !CName ![CPropVarDef] ![CPropVarPtr] -> (!Bool, !CPropVarPtr)
		find_p name [var:vars] [ptr:ptrs]
			| var.pvarName == name			= (True, ptr)
			= find_p name vars ptrs
		find_p name [] []
			= (False, nilPtr)

// ------------------------------------------------------------------------------------------------------------------------
getExprVar :: !String !UseExprVar ![CExprVarPtr] !*CHeaps -> (!Error, !CExprVarPtr, CExprVarDef, !*CHeaps)
// ------------------------------------------------------------------------------------------------------------------------
getExprVar tactic (KnownExprVar name ptr) _ heaps
	# (var, heaps)							= readPointer ptr heaps
	= (OK, ptr, var, heaps)
getExprVar tactic (UnknownExprVar name) ptrs heaps
	= find ptrs name heaps
	where
		find :: ![CExprVarPtr] !CName !*CHeaps -> (!Error, !CExprVarPtr, CExprVarDef, !*CHeaps)
		find [ptr:ptrs] name heaps
			# (var, heaps)					= readPointer ptr heaps
			| var.evarName == name			= (OK, ptr, var, heaps)
			= find ptrs name heaps
		find [] _ heaps
			= (pushError (X_ApplyTactic tactic ("Unable to find variable '" +++ name +++ "'")) OK, nilPtr, DummyValue, heaps)

// ------------------------------------------------------------------------------------------------------------------------
getFact :: !UseFact !*CHeaps -> (!Error, !CPropH, ![TheoremPtr], ![HeapPtr], !*CHeaps)
// ------------------------------------------------------------------------------------------------------------------------
getFact (HypothesisFact ptr args) heaps
	# (hyp, heaps)							= readPointer ptr heaps
	# (prop, heaps)							= FreshVars hyp.hypProp heaps
	# (error, prop, symbols, heaps)			= getFactArgs prop args [] heaps
	= (error, prop, [], symbols, heaps)
getFact (TheoremFact theorem_ptr args) heaps
	# (theorem, heaps)						= readPointer theorem_ptr heaps
	# (prop, heaps)							= FreshVars theorem.thInitial heaps
	# (error, prop, symbols, heaps)			= getFactArgs prop args [] heaps
	= (error, prop, [theorem_ptr], symbols, heaps)

// ------------------------------------------------------------------------------------------------------------------------
getFactArgs :: !CPropH ![UseFactArgument] ![HeapPtr] !*CHeaps -> (!Error, !CPropH, ![HeapPtr], !*CHeaps)
// ------------------------------------------------------------------------------------------------------------------------
getFactArgs p [] symbols heaps
	= (OK, p, symbols, heaps)
getFactArgs (CExprForall ptr p) [NoArgument: args] symbols heaps
	# (error, p, symbols, heaps)			= getFactArgs p args symbols heaps
	= (error, CExprForall ptr p, symbols, heaps)
getFactArgs (CExprForall ptr p) [ExprArgument expr: args] symbols heaps
	# (used, heaps)							= GetUsedSymbols expr heaps
	# subst									= {DummyValue & subExprVars = [(ptr, expr)]}
	# (p, heaps)							= SafeSubst subst p heaps
	= getFactArgs p args (used ++ symbols) heaps
getFactArgs (CExprForall ptr p) [PropArgument _: args] symbols heaps
	= ([X_Internal "Invalid argument (prop; expected expr) of fact."], DummyValue, DummyValue, heaps)
getFactArgs (CPropForall ptr p) [NoArgument: args] symbols heaps
	# (error, p, symbols, heaps)			= getFactArgs p args symbols heaps
	= (error, CPropForall ptr p, symbols, heaps)
getFactArgs (CPropForall ptr p) [PropArgument prop: args] symbols heaps
	# (used, heaps)							= GetUsedSymbols prop heaps
	# subst									= {DummyValue & subPropVars = [(ptr, prop)]}
	# (p, heaps)							= SafeSubst subst p heaps
	= getFactArgs p args (used ++ symbols) heaps
getFactArgs (CPropForall ptr p) [ExprArgument _: args] symbols heaps
	= ([X_Internal "Invalid argument (expr; expected prop) of fact."], DummyValue, DummyValue, heaps)
getFactArgs p [arg:args] symbols heaps
	= ([X_Internal "Too many arguments of fact."], DummyValue, DummyValue, heaps)

// ------------------------------------------------------------------------------------------------------------------------
newHypotheses :: !Goal ![CPropH] !*CHeaps !*CProject -> (!Goal, !*CHeaps, !*CProject)
// ------------------------------------------------------------------------------------------------------------------------
newHypotheses goal [p:ps] heaps prj
	# num									= goal.glNewHypNum
	# name									= "H" +++ toString num
	# hyp									= {hypName = name, hypProp = p}
	# (ptr, heaps)							= newPointer hyp heaps
	# goal									= {goal & glNewHypNum = num+1, glHypotheses = [ptr:goal.glHypotheses]}
	= newHypotheses goal ps heaps prj
newHypotheses goal [] heaps prj
	= (goal, heaps, prj)

// ------------------------------------------------------------------------------------------------------------------------
overwriteHypothesis :: ![HypothesisPtr] !HypothesisPtr !CPropH !*CHeaps !*CProject -> (![HypothesisPtr], !*CHeaps, !*CProject)
// ------------------------------------------------------------------------------------------------------------------------
overwriteHypothesis [ptr:ptrs] the_ptr prop heaps prj
	| ptr == the_ptr
		# (hyp, heaps)						= readPointer ptr heaps
		# new_hyp							= {hyp & hypProp = prop}
		# (new_ptr, heaps)					= newPointer new_hyp heaps
		= ([new_ptr:ptrs], heaps, prj)
	| ptr <> the_ptr
		# (ptrs, heaps, prj)				= overwriteHypothesis ptrs the_ptr prop heaps prj
		= ([ptr:ptrs], heaps, prj)
	= undef
overwriteHypothesis [] the_ptr prop heaps prj
	= ([], heaps, prj)
























// ------------------------------------------------------------------------------------------------------------------------
Absurd :: !HypothesisPtr !HypothesisPtr !Goal !*CHeaps !*CProject -> (!Error, ![Goal], ![TheoremPtr], ![HeapPtr], !*CHeaps, !*CProject)
// ------------------------------------------------------------------------------------------------------------------------
Absurd ptr1 ptr2 goal heaps prj
	# (hyp1, heaps)							= readPointer ptr1 heaps
	# (hyp2, heaps)							= readPointer ptr2 heaps
	# (ok, heaps)							= contradict hyp1.hypProp hyp2.hypProp heaps
	| not ok								= (pushError (X_ApplyTactic "Absurd" ("Hypothesis '" +++ hyp1.hypName +++ "' is not the negation of '" +++ hyp2.hypName +++ "' (or vice-versa)")) OK, DummyValue, DummyValue, DummyValue, heaps, prj)
	= (OK, [], [], [], heaps, prj)
	where
		contradict :: !CPropH !CPropH !*CHeaps -> (!Bool, !*CHeaps)
		contradict (CNot p) (CNot q) heaps
			= contradict p q heaps
		contradict (CNot p) q heaps
			= AlphaEqual p q heaps
		contradict p (CNot q) heaps
			= AlphaEqual p q heaps
		contradict p q heaps
			= (False, heaps)

// @1: True denotes current goal; False denotes a hypothesis
// ------------------------------------------------------------------------------------------------------------------------
absurd_equality :: !Bool !CPropH !*CProject -> (!Bool, !*CProject)
// ------------------------------------------------------------------------------------------------------------------------
absurd_equality mode prop prj
	# equalities							= find_equalities mode prop
	| isEmpty equalities					= (False, prj)
	= has_absurd_equality equalities prj
	where
		// @1: True denotes current goal; False denotes a hypothesis
		// (Note that in the current goal, when p -> q is encountered, p can be regarded as a hypothesis)
 		find_equalities :: !Bool !CPropH -> [(CExprH, CExprH)]
		find_equalities True (CEqual e1 e2)				= []
		find_equalities False (CEqual e1 e2)			= [(e1,e2)]
		find_equalities mode (CExprForall var p)		= find_equalities mode p
		find_equalities mode (CExprExists var p)		= find_equalities mode p
		find_equalities mode (CPropForall var p)		= find_equalities mode p
		find_equalities mode (CPropExists var p)		= find_equalities mode p
		find_equalities True (CImplies p q)				= find_equalities False p ++ find_equalities True q
		find_equalities False (CImplies p q)			= find_equalities False q
		find_equalities _ _								= []
		
		has_absurd_equality :: ![(CExprH, CExprH)] !*CProject -> (!Bool, !*CProject)
		has_absurd_equality [(CBottom, CBottom):equalities] prj
			= has_absurd_equality equalities prj
		has_absurd_equality [(expr,CBottom):equalities] prj
			= has_absurd_equality [(CBottom,expr):equalities] prj
		has_absurd_equality [(CBottom, CBasicValue _):_] prj
			= (True, prj)
		has_absurd_equality [(CBottom, ptr @@# _):equalities] prj
			| ptrKind ptr <> CDataCons					= has_absurd_equality equalities prj
			# (error, consdef, prj)						= getDataConsDef ptr prj
			| isError error								= has_absurd_equality equalities prj
			# strict									= has_strict_args consdef.dcdSymbolType.sytArguments
			| strict									= has_absurd_equality equalities prj
			= (True, prj)
			where
				has_strict_args :: ![CTypeH] -> Bool
				has_strict_args [CStrict type: types]
					= True
				has_strict_args [type: types]
					= has_strict_args types
				has_strict_args []
					= False
		has_absurd_equality [(CBasicValue (CBasicInteger n1), CBasicValue (CBasicInteger n2)): equalities] prj
			| n1 == n2									= has_absurd_equality equalities prj
			= (True, prj)
		has_absurd_equality [(CBasicValue (CBasicCharacter c1), CBasicValue (CBasicCharacter c2)): equalities] prj
			| c1 == c2									= has_absurd_equality equalities prj
			= (True, prj)
		has_absurd_equality [(CBasicValue (CBasicRealNumber r1), CBasicValue (CBasicRealNumber r2)): equalities] prj
			| r1 == r2									= has_absurd_equality equalities prj
			= (True, prj)
		has_absurd_equality [(CBasicValue (CBasicBoolean b1), CBasicValue (CBasicBoolean b2)): equalities] prj
			| b1 == b2									= has_absurd_equality equalities prj
			= (True, prj)
		has_absurd_equality [(CBasicValue (CBasicString s1), CBasicValue (CBasicString s2)): equalities] prj
			| s1 == s2									= has_absurd_equality equalities prj
			= (True, prj)
		has_absurd_equality [(ptr1 @@# _, ptr2 @@# _):equalities] prj
			# (error, c1, prj)							= getDataConsDef ptr1 prj
			| isError error								= has_absurd_equality equalities prj
			# (error, c2, prj)							= getDataConsDef ptr2 prj
			| isError error								= has_absurd_equality equalities prj
			| c1.dcdAlgType <> c2.dcdAlgType			= has_absurd_equality equalities prj
			| ptr1 == ptr2								= has_absurd_equality equalities prj
			= (True, prj)
		has_absurd_equality [_:equalities] prj
			= has_absurd_equality equalities prj
		has_absurd_equality [] prj
			= (False, prj)

// ------------------------------------------------------------------------------------------------------------------------
AbsurdEquality :: !Goal !*CHeaps !*CProject -> (!Error, ![Goal], ![TheoremPtr], ![HeapPtr], !*CHeaps, !*CProject)
// ------------------------------------------------------------------------------------------------------------------------
AbsurdEquality goal heaps prj
	# (ok, prj)								= absurd_equality True goal.glToProve prj
	| not ok								= ([X_ApplyTactic "AbsurdEquality" "Current goal does not contain a suitable absurd equality."], DummyValue, DummyValue, DummyValue, heaps, prj)
	= (OK, [], [], [], heaps, prj)

// ------------------------------------------------------------------------------------------------------------------------
AbsurdEqualityH :: !HypothesisPtr !Goal !*CHeaps !*CProject -> (!Error, ![Goal], ![TheoremPtr], ![HeapPtr], !*CHeaps, !*CProject)
// ------------------------------------------------------------------------------------------------------------------------
AbsurdEqualityH ptr goal heaps prj
	# (hyp, heaps)							= readPointer ptr heaps
	# (ok, prj)								= absurd_equality False hyp.hypProp prj
	| not ok								= ([X_ApplyTactic "AbsurdEquality" "Hypothesis given does not contain a suitable absurd equality."], DummyValue, DummyValue, DummyValue, heaps, prj)
	= (OK, [], [], [], heaps, prj)

// ------------------------------------------------------------------------------------------------------------------------
Apply :: !UseFact !Goal !*CHeaps !*CProject -> (!Error, ![Goal], ![TheoremPtr], ![HeapPtr], !*CHeaps, !*CProject)
// ------------------------------------------------------------------------------------------------------------------------
Apply fact goal heaps prj
	# (error, prop, used_theorems, used_symbols, heaps)
											= getFact fact heaps
	| isError error							= (error, DummyValue, DummyValue, DummyValue, heaps, prj)
	# (evars, pvars, prop)					= strip_vars prop
	# components							= strip_implies prop
	# (lhs, rhs)							= (init components, last components)
	# (ok, sub, add, left_e, left_p, heaps)	= Match evars pvars rhs goal.glToProve heaps
	| not ok || not (isEmpty add)			= (pushError (X_ApplyTactic "Apply" "Given fact can not be applied to current goal.") OK, DummyValue, DummyValue, DummyValue, heaps, prj)
	| isEmpty lhs							= (OK, [], used_theorems, [], heaps, prj)
	# (lhs, heaps)							= SafeSubst sub lhs heaps
	# prop									= fold_and lhs
	# (prop, heaps)							= fold_existse left_e [] prop heaps
	# (prop, heaps)							= fold_existsp left_p [] prop heaps
	# goal									= {goal & glToProve = prop, glNrIHs = 0}
	= (OK, [goal], used_theorems, used_symbols, heaps, prj)
	where
		strip_vars :: !CPropH -> (![CExprVarPtr], ![CPropVarPtr], !CPropH)
		strip_vars (CExprForall var p)
			# (evars, pvars, p)				= strip_vars p
			= ([var:evars], pvars, p)
		strip_vars (CPropForall var p)
			# (evars, pvars, p)				= strip_vars p
			= (evars, [var:pvars], p)
		strip_vars other
			= ([], [], other)
		
		strip_implies :: !CPropH -> [CPropH]
		strip_implies (CImplies p q)		= [p: strip_implies q]
		strip_implies other					= [other]
		
		fold_and :: ![CPropH] -> CPropH
		fold_and [p:ps]
			| isEmpty ps					= p
			= CAnd p (fold_and ps)
		
		fold_existsp :: ![CPropVarPtr] ![(CPropVarPtr, CPropH)] !CPropH !*CHeaps -> (!CPropH, !*CHeaps)
		fold_existsp [ptr:ptrs] subst p heaps
			# (var, heaps)					= readPointer ptr heaps
			# (new_ptr, heaps)				= newPointer var heaps
			# (p, heaps)					= fold_existsp ptrs [(ptr, CPropVar new_ptr):subst] p heaps
			= (CPropExists new_ptr p, heaps)
		fold_existsp [] subst p heaps
			# subst							= {DummyValue & subPropVars = subst}
			= SafeSubst subst p heaps
		
		fold_existse :: ![CExprVarPtr] ![(CExprVarPtr, CExprH)] !CPropH !*CHeaps -> (!CPropH, !*CHeaps)
		fold_existse [ptr:ptrs] subst p heaps
			# (var, heaps)					= readPointer ptr heaps
			# (new_ptr, heaps)				= newPointer var heaps
			# (p, heaps)					= fold_existse ptrs [(ptr, CExprVar new_ptr):subst] p heaps
			= (CExprExists new_ptr p, heaps)
		fold_existse [] subst p heaps
			# subst							= {DummyValue & subExprVars = subst}
			= SafeSubst subst p heaps

// ------------------------------------------------------------------------------------------------------------------------
ApplyH :: !UseFact !HypothesisPtr !TacticMode !Goal !*CHeaps !*CProject -> (!Error, ![Goal], ![TheoremPtr], ![HeapPtr], !*CHeaps, !*CProject)
// ------------------------------------------------------------------------------------------------------------------------
ApplyH fact ptr mode goal heaps prj
	# (error, prop, used_theorems, used_symbols, heaps)
											= getFact fact heaps
	| isError error							= (error, DummyValue, DummyValue, DummyValue, heaps, prj)
	# (ok, evars, pvars, lhs, rhs)			= make_rule prop
	| not ok								= (pushError (X_ApplyTactic "Apply" "Given fact can not be used as a rule.") OK, DummyValue, DummyValue, DummyValue, heaps, prj)
	# (hyp, heaps)							= readPointer ptr heaps
	# (ok, sub, add, left_e, left_p, heaps)	= Match evars pvars lhs hyp.hypProp heaps
	| not ok || not (isEmpty add)			= (pushError (X_ApplyTactic "Apply" ("Given fact can not be applied to hypothesis '" +++ hyp.hypName +++ "'.")) OK, DummyValue, DummyValue, DummyValue, heaps, prj)
	# (rhs, heaps)							= SafeSubst sub rhs heaps
	# (new_hyp, correct_sub, heaps)			= fold_foralle left_e rhs DummyValue heaps
	# (new_hyp, correct_sub, heaps)			= fold_forallp left_p new_hyp correct_sub heaps
	# (new_hyp, heaps)						= SafeSubst correct_sub new_hyp heaps
	| mode == Implicit
		# (goal, heaps, prj)				= newHypotheses goal [new_hyp] heaps prj
		# goal								= case fact of
												HypothesisFact hyp_ptr _	-> {goal & glHypotheses = removeMember hyp_ptr goal.glHypotheses}
												_							-> goal
		= (OK, [goal], used_theorems, used_symbols, heaps, prj)
	| mode == Explicit
		# goal								= {goal & glToProve = CImplies new_hyp goal.glToProve, glNrIHs = 0}
		= (OK, [goal], used_theorems, used_symbols, heaps, prj)
	where
		make_rule :: !CPropH -> (!Bool, ![CExprVarPtr], ![CPropVarPtr], !CPropH, !CPropH)
		make_rule (CExprForall var p)
			# (ok, evars, pvars, lhs, rhs)	= make_rule p
			= (ok, [var:evars], pvars, lhs, rhs)
		make_rule (CPropForall var p)
			# (ok, evars, pvars, lhs, rhs)	= make_rule p
			= (ok, evars, [var:pvars], lhs, rhs)
		make_rule (CImplies p q)
			= (True, [], [], p, q)
		make_rule other
			= (False, [], [], DummyValue, DummyValue)
		
		fold_forallp :: ![CPropVarPtr] !CPropH !Substitution !*CHeaps -> (!CPropH, !Substitution, !*CHeaps)
		fold_forallp [ptr:ptrs] p sub heaps
			# (var, heaps)					= readPointer ptr heaps
			# (new_ptr, heaps)				= newPointer var heaps
			# sub							= {sub & subPropVars = [(ptr, CPropVar new_ptr):sub.subPropVars]}
			# (p, sub, heaps)				= fold_forallp ptrs p sub heaps
			= (CPropForall new_ptr p, sub, heaps)
		fold_forallp [] p sub heaps
			= (p, sub, heaps)
		
		fold_foralle :: ![CExprVarPtr] !CPropH !Substitution !*CHeaps -> (!CPropH, !Substitution, !*CHeaps)
		fold_foralle [ptr:ptrs] p sub heaps
			# (var, heaps)					= readPointer ptr heaps
			# (new_ptr, heaps)				= newPointer var heaps
			# sub							= {sub & subExprVars = [(ptr, CExprVar new_ptr):sub.subExprVars]}
			# (p, sub, heaps)				= fold_foralle ptrs p sub heaps
			= (CExprForall new_ptr p, sub, heaps)
		fold_foralle [] p sub heaps
			= (p, sub, heaps)

// ------------------------------------------------------------------------------------------------------------------------
Assume :: !CPropH !TacticMode !Goal !*CHeaps !*CProject -> (!Error, ![Goal], ![TheoremPtr], ![HeapPtr], !*CHeaps, !*CProject)
// ------------------------------------------------------------------------------------------------------------------------
Assume prop Explicit goal heaps prj
	# assumption							= {goal & glToProve = prop, glNrIHs = 0}
	# new_goal								= {goal & glToProve = CImplies prop goal.glToProve, glNrIHs = 0}
	# (used_symbols, heaps)					= GetUsedSymbols prop heaps
	= (OK, [new_goal, assumption], [], used_symbols, heaps, prj)
Assume prop Implicit goal heaps prj
	# assumption							= {goal & glToProve = prop, glNrIHs = 0}
	# (new_goal, heaps, prj)				= newHypotheses goal [prop] heaps prj
	# (used_symbols, heaps)					= GetUsedSymbols prop heaps
	= (OK, [new_goal, assumption], [], used_symbols, heaps, prj)

// ------------------------------------------------------------------------------------------------------------------------
Axiom :: !Goal !*CHeaps !*CProject -> (!Error, ![Goal], ![TheoremPtr], ![HeapPtr], !*CHeaps, !*CProject)
// ------------------------------------------------------------------------------------------------------------------------
Axiom goal heaps prj
	# (x, heaps)							= newPointer {DummyValue & evarName = "x"} heaps
	# (y, heaps)							= newPointer {DummyValue & evarName = "y"} heaps
	# (z, heaps)							= newPointer {DummyValue & evarName = "z"} heaps
	# eX									= CExprVar x
	# eY									= CExprVar y
	# eZ									= CExprVar z
	# (funs, prj)							= prj!prjABCFunctions.stdInt
	# (sfuns, prj)							= prj!prjABCFunctions.stdString
	// ~(x = _|_) -> x - x = 0
	# hyp									= CNot (CEqual eX CBottom)
	# concl									= CEqual (minus funs eX eX) (CBasicValue (CBasicInteger 0))
	# axiom									= all1 x (CImplies hyp concl)
	# (ok, heaps)							= AlphaEqual goal.glToProve axiom heaps
	| ok									= (OK, [], [], [], heaps, prj)
	// x + y = y + x
	# axiom									= all2 x y (CEqual (plus funs eX eY) (plus funs eY eX))
	# (ok, heaps)							= AlphaEqual goal.glToProve axiom heaps
	| ok									= (OK, [], [], [], heaps, prj)
	// (x + y) + z = x + (y + z)
	# axiom									= all3 x y z (CEqual (plus funs (plus funs eX eY) eZ) (plus funs eX (plus funs eY eZ)))
	# (ok, heaps)							= AlphaEqual goal.glToProve axiom heaps
	| ok									= (OK, [], [], [], heaps, prj)
	// x < y = False <-> y < x+1 = True
	# axiom									= all2 x y (CIff (not_le funs eX eY) (le funs eY (plus funs eX int1)))
	# (ok, heaps)							= AlphaEqual goal.glToProve axiom heaps
	| ok									= (OK, [], [], [], heaps, prj)
	// x < y = True -> z < 0 = False -> x < z + y = True
	# hyp1									= le funs eX eY
	# hyp2									= not_le funs eZ (CBasicValue (CBasicInteger 0))
	# concl									= le funs eX (plus funs eZ eY)
	# axiom									= all3 x y z (CImplies hyp1 (CImplies hyp2 concl))
	# (ok, heaps)							= AlphaEqual goal.glToProve axiom heaps
	| ok									= (OK, [], [], [], heaps, prj)
	// x <> _|_ -> y < z = (y+x) < (z+x)
	# hyp									= CNot (CEqual eX CBottom)
	# concl									= CEqual (funs.intSmaller @@# [eY,eZ])
													 (funs.intSmaller @@# [plus funs eY eX, plus funs eZ eX])
	# axiom									= all3 x y z (CImplies hyp concl)
	# (ok, heaps)							= AlphaEqual goal.glToProve axiom heaps
	| ok									= (OK, [], [], [], heaps, prj)
	// x <> _|_ -> y < z = (y-x) < (z-x)
	# hyp									= CNot (CEqual eX CBottom)
	# concl									= CEqual (funs.intSmaller @@# [eY,eZ])
													 (funs.intSmaller @@# [minus funs eY eX, minus funs eZ eX])
	# axiom									= all3 x y z (CImplies hyp concl)
	# (ok, heaps)							= AlphaEqual goal.glToProve axiom heaps
	| ok									= (OK, [], [], [], heaps, prj)
	// x <> _|_ -> x < x = False
	# hyp									= CNot (CEqual eX CBottom)
	# concl									= not_le funs eX eX
	# axiom									= all1 x (CImplies hyp concl)
	# (ok, heaps)							= AlphaEqual goal.glToProve axiom heaps
	| ok									= (OK, [], [], [], heaps, prj)
	// x < y -> y < z -> x < z
	# hyp1									= le funs eX eY
	# hyp2									= le funs eY eZ
	# concl									= le funs eX eZ
	# axiom									= all3 x y z (CImplies hyp1 (CImplies hyp2 concl))
	# (ok, heaps)							= AlphaEqual goal.glToProve axiom heaps
	| ok									= (OK, [], [], [], heaps, prj)
	// ~(x = _|_) -> ~(y = _|_) -> x == y = True <-> x = y (Int)
	# hyp1									= CNot (CEqual eX CBottom)
	# hyp2									= CNot (CEqual eY CBottom)
	# concl									= CIff (i_equal funs eX eY) (CEqual eX eY)
	# axiom									= all2 x y (CImplies hyp1 (CImplies hyp2 concl))
	# (ok, heaps)							= AlphaEqual goal.glToProve axiom heaps
	| ok									= (OK, [], [], [], heaps, prj)
	// ~(x = _|_) -> ~(y = _|_) -> x == y = True <-> x = y (String)
	# hyp1									= CNot (CEqual eX CBottom)
	# hyp2									= CNot (CEqual eY CBottom)
	# concl									= CIff (s_equal sfuns eX eY) (CEqual eX eY)
	# axiom									= all2 x y (CImplies hyp1 (CImplies hyp2 concl))
	# (ok, heaps)							= AlphaEqual goal.glToProve axiom heaps
	| ok									= (OK, [], [], [], heaps, prj)
	// x < y -> x == x = False
	# hyp									= le funs eX eY
	# concl									= not_i_equal funs eX eY
	# axiom									= all2 x y (CImplies hyp concl)
	# (ok, heaps)							= AlphaEqual goal.glToProve axiom heaps
	| ok									= (OK, [], [], [], heaps, prj)
	// x <> _|_ -> x * x < 0 = False
	# hyp									= CNot (CEqual eX CBottom)
	# concl									= not_le funs (times funs eX eX) (CBasicValue (CBasicInteger 0))
	# axiom									= all1 x (CImplies hyp concl)
	# (ok, heaps)							= AlphaEqual goal.glToProve axiom heaps
	| ok									= (OK, [], [], [], heaps, prj)
	= ([X_ApplyTactic "Axiom" "Not a predefined axiom."], DummyValue, DummyValue, DummyValue, heaps, prj)
	where
		all1 ptr p							= CExprForall ptr p
		all2 ptr1 ptr2 p					= CExprForall ptr1 (CExprForall ptr2 p)
		all3 ptr1 ptr2 ptr3 p				= CExprForall ptr1 (CExprForall ptr2 (CExprForall ptr3 p))
		
		int1								= CBasicValue (CBasicInteger 1)
		plus funs p q						= funs.intAdd @@# [p,q]
		minus funs p q						= funs.intSubtract @@# [p,q]
		times funs p q						= funs.intMultiply @@# [p,q]
		le funs p q							= CEqual (funs.intSmaller @@# [p,q]) (CBasicValue (CBasicBoolean True))
		not_le funs p q						= CEqual (funs.intSmaller @@# [p,q]) (CBasicValue (CBasicBoolean False))
		i_equal funs e1 e2					= CEqual (funs.intEqual @@# [e1,e2]) (CBasicValue (CBasicBoolean True))
		not_i_equal funs e1 e2				= CEqual (funs.intEqual @@# [e1,e2]) (CBasicValue (CBasicBoolean False))
		s_equal funs e1 e2					= CEqual (funs.stringEqual @@# [e1,e2]) (CBasicValue (CBasicBoolean True))

// ------------------------------------------------------------------------------------------------------------------------
findCases :: !Depth !CPropH -> [CPropH]
// ------------------------------------------------------------------------------------------------------------------------
findCases Shallow (COr p q)
	= [p, q]
findCases Deep (COr p q)
	= findCases Deep p ++ findCases Deep q
findCases _ other
	= [other]

// ------------------------------------------------------------------------------------------------------------------------
CaseN :: !Depth !Int !Goal !*CHeaps !*CProject -> (!Error, ![Goal], ![TheoremPtr], ![HeapPtr], !*CHeaps, !*CProject)
// ------------------------------------------------------------------------------------------------------------------------
CaseN depth num goal heaps prj
	# props									= findCases depth goal.glToProve
	| length props < 2						= (pushError (X_ApplyTactic "Case" "Current goal is not a disjunction.") OK, DummyValue, DummyValue, DummyValue, heaps, prj)
	| num > length props					= (pushError (X_ApplyTactic "Case" "No such case in current goal.") OK, DummyValue, DummyValue, DummyValue, heaps, prj)
	# goal									= {goal & glToProve = props !! (num-1), glNrIHs = 0}
	= (OK, [goal], [], [], heaps, prj)

// ------------------------------------------------------------------------------------------------------------------------
CaseH :: !Depth !HypothesisPtr !TacticMode !Goal !*CHeaps !*CProject -> (!Error, ![Goal], ![TheoremPtr], ![HeapPtr], !*CHeaps, !*CProject)
// ------------------------------------------------------------------------------------------------------------------------
CaseH depth ptr mode goal heaps prj
	# (hyp, heaps)							= readPointer ptr heaps
	# (prop, heaps)							= FreshVars hyp.hypProp heaps
	# props									= findCases depth prop
	| length props < 2						= (pushError (X_ApplyTactic "Case" ("Hypothesis '" +++ hyp.hypName +++ "' is not a disjunction.")) OK, DummyValue, DummyValue, DummyValue, heaps, prj)
	# (goals, heaps, prj)					= build_goals mode ptr props goal heaps prj
	= (OK, goals, [], [], heaps, prj)
	where
		build_goals :: !TacticMode !HypothesisPtr ![CPropH] !Goal !*CHeaps !*CProject -> (![Goal], !*CHeaps, !*CProject)
		build_goals Implicit ptr [p:ps] goal heaps prj
			# (hyps, heaps, prj)			= overwriteHypothesis goal.glHypotheses ptr p heaps prj
			# new_goal						= {goal & glHypotheses = hyps}
			# (new_goals, heaps, prj)		= build_goals Implicit ptr ps goal heaps prj
			= ([new_goal:new_goals], heaps, prj)
		build_goals Explicit ptr [p:ps] goal heaps prj
			# new_goal						= {goal & glToProve = CImplies p goal.glToProve, glNrIHs = 0}
			# (new_goals, heaps, prj)		= build_goals Explicit ptr ps goal heaps prj
			= ([new_goal:new_goals], heaps, prj)
		build_goals _ _ [] goal heaps prj
			= ([], heaps, prj)

// ------------------------------------------------------------------------------------------------------------------------
Cases :: !CExprH !TacticMode !Goal !*CHeaps !*CProject -> (!Error, ![Goal], ![TheoremPtr], ![HeapPtr], !*CHeaps, !*CProject)
// ------------------------------------------------------------------------------------------------------------------------
Cases expr mode goal heaps prj
	# (used_symbols, heaps)					= GetUsedSymbols expr heaps
	# (error, (_, type), heaps, prj)		= typeExprInGoal expr goal heaps prj
	| isError error							= (error, DummyValue, DummyValue, DummyValue, heaps, prj)
	| type == CBasicType CBoolean
		| mode == Explicit
			# equal0						= CEqual expr CBottom
			# equal1						= CEqual expr (CBasicValue (CBasicBoolean True))
			# equal2						= CEqual expr (CBasicValue (CBasicBoolean False))
			# goal0							= {goal & glToProve = CImplies equal0 goal.glToProve, glNrIHs = 0}
			# goal1							= {goal & glToProve = CImplies equal1 goal.glToProve, glNrIHs = 0}
			# goal2							= {goal & glToProve = CImplies equal2 goal.glToProve, glNrIHs = 0}
			= (OK, [goal0,goal1,goal2], [], used_symbols, heaps, prj)
		| mode == Implicit
			# (ok, goal0, heaps)			= replaceExpr goal expr CBottom heaps
			| not ok						= (pushError (X_ApplyTactic "Cases" "Specified expression does not occur in goal.") OK, DummyValue, DummyValue, DummyValue, heaps, prj)
			# (_, goal1, heaps)				= replaceExpr goal expr (CBasicValue (CBasicBoolean True)) heaps
			# (_, goal2, heaps)				= replaceExpr goal expr (CBasicValue (CBasicBoolean False)) heaps
			= (OK, [goal0,goal1,goal2], [], used_symbols, heaps, prj)
		= undef
	# (ok, alg_ptr)							= get_alg_type type
	| not ok								= (pushError (X_ApplyTactic "Cases" "Expression does not have an algebraic type") OK, DummyValue, DummyValue, DummyValue, heaps, prj)
	# (error, alg_type, prj)				= getAlgTypeDef alg_ptr prj
	| isError error							= (error, DummyValue, DummyValue, DummyValue, heaps, prj)
	# (error, goals, heaps, prj)			= build_goals expr alg_type.atdConstructors goal heaps prj
	| isError error							= (error, DummyValue, DummyValue, DummyValue, heaps, prj)
	# (ok, goal, heaps)						= build_goal mode expr CBottom [] goal heaps
	| not ok								= (pushError (X_ApplyTactic "Cases" "Specified expression does not occur in goal.") OK, DummyValue, DummyValue, DummyValue, heaps, prj)
	= (OK, [goal:goals], [], used_symbols, heaps, prj)
	where
		get_alg_type :: !CTypeH -> (!Bool, !HeapPtr)
		get_alg_type (ptr @@^ types)
			| ptrKind ptr == CAlgType		= (True, ptr)
			= (False, DummyValue)
		get_alg_type other
			= (False, DummyValue)
		
		build_goals :: !CExprH ![HeapPtr] !Goal !*CHeaps !*CProject -> (!Error, ![Goal], !*CHeaps, !*CProject)
		build_goals expr [ptr:ptrs] old_goal heaps prj
			# (error, consdef, prj)			= getDataConsDef ptr prj
			| isError error					= (error, DummyValue, heaps, prj)
			# (fresh_vars, heaps)			= new_vars 1 consdef.dcdArity heaps
			# apply_cons					= ptr @@# (map CExprVar fresh_vars)
			# (_, goal, heaps)				= build_goal mode expr apply_cons fresh_vars old_goal heaps
			# (error, goals, heaps, prj)	= build_goals expr ptrs old_goal heaps prj
			| isError error					= (error, DummyValue, heaps, prj)
			= (OK, [goal:goals], heaps, prj)
			where
				new_vars :: !Int !Int !*CHeaps -> (![CExprVarPtr], !*CHeaps)
				new_vars index 0 heaps
					= ([], heaps)
				new_vars index n heaps
					# new_var				= {DummyValue & evarName = "x" +++ toString index}
					# (new_ptr, heaps)		= newPointer new_var heaps
					# (new_ptrs, heaps)		= new_vars (index+1) (n-1) heaps
					= ([new_ptr:new_ptrs], heaps)
		build_goals expr [] goal heaps prj
			= (OK, [], heaps, prj)
		
		build_goal :: !TacticMode !CExprH !CExprH ![CExprVarPtr] !Goal !*CHeaps -> (!Bool, !Goal, !*CHeaps)
		build_goal Explicit var_ptr apply_cons fresh_vars goal heaps
			# equal							= CEqual expr apply_cons
			# to_prove						= CImplies equal goal.glToProve
			# (to_prove, heaps)				= FreshVars to_prove heaps
			# to_prove						= add_foralls fresh_vars to_prove
			# goal							= {goal & glToProve = to_prove, glNrIHs = 0}
			= (True, goal, heaps)
		build_goal Implicit expr apply_cons fresh_vars goal heaps
			# (ok, goal, heaps)				= replaceExpr goal expr apply_cons heaps
			# goal							= {goal & glExprVars = fresh_vars ++ goal.glExprVars}
			= (ok, goal, heaps)
				
		add_foralls :: ![CExprVarPtr] !CPropH -> CPropH
		add_foralls [ptr:ptrs] p
			= CExprForall ptr (add_foralls ptrs p)
		add_foralls [] p
			= p

:: MyPattern :== Either3 CAlgPatternH CBasicPatternH CExprH
// ------------------------------------------------------------------------------------------------------------------------
chooseCase :: !Bool !CPropH !Goal !*CHeaps !*CProject -> (!Bool, !Goal, !*CHeaps, !*CProject)
// ------------------------------------------------------------------------------------------------------------------------
chooseCase mode prop goal heaps prj
	# (ok, expr, patterns, def, value)				= get_case prop
	| not ok										= (False, DummyValue, heaps, prj)
	# my_patterns									= build_my_patterns patterns def
	# my_patterns									= filter (check_pattern value) my_patterns
	| length my_patterns <> 1						= (False, DummyValue, heaps, prj)
	// Goal mode
	| mode
		# (error, to_prove, heaps)					= build_prop expr value (hd my_patterns) heaps
		| isError error								= (False, goal, heaps, prj)
		# goal										= {goal & glToProve = to_prove}
		= (True, goal, heaps, prj)
	// Hypothesis mode
		# (error, to_prove, heaps)					= add_hyps expr value (hd my_patterns) goal.glToProve heaps
		| isError error								= (False, goal, heaps, prj)
		# goal										= {goal & glToProve = to_prove}
		= (True, goal, heaps, prj)
	where
		get_case :: !CPropH -> (!Bool, !CExprH, !CCasePatternsH, !Maybe CExprH, !CBasicValueH)
		get_case (CEqual (CCase expr patterns def) (CBasicValue value))
			= (True, expr, patterns, def, value)
		get_case other
			= (False, DummyValue, DummyValue, DummyValue, DummyValue)
		
		build_my_patterns :: !CCasePatternsH !(Maybe CExprH) -> [MyPattern]
		build_my_patterns (CAlgPatterns type patterns) mb_def
			# my_patterns							= map E1 patterns
			= case mb_def of
				Just def	-> [E3 def: my_patterns]
				Nothing		-> my_patterns
		build_my_patterns (CBasicPatterns type patterns) mb_def
			# my_patterns							= map E2 patterns
			= case mb_def of
				Just def	-> [E3 def: my_patterns]
				Nothing		-> my_patterns
		
		unequal :: !CExprH !CBasicValueH -> Bool
		unequal (CBasicValue value1) value2
			= value1 <> value2
		unequal CBottom _
			= True
		unequal other _
			= False
		
		check_pattern :: !CBasicValueH !MyPattern -> Bool
		check_pattern value (E1 pattern)
			= not (unequal pattern.atpResult value)
		check_pattern value (E2 pattern)
			= not (unequal pattern.bapResult value)
		check_pattern value (E3 def)
			= not (unequal def value)
		
		add_hyps :: !CExprH !CBasicValueH !MyPattern !CPropH !*CHeaps -> (!Error, !CPropH, !*CHeaps)
		add_hyps expr value (E1 pattern) prop heaps
			# old_ptrs								= pattern.atpExprVarScope
			# (old_vars, heaps)						= readPointers old_ptrs heaps
			# (new_ptrs, heaps)						= newPointers old_vars heaps
			# subst									= {DummyValue & subExprVars = zip2 old_ptrs (map CExprVar new_ptrs)}
			# hyp1									= CEqual expr (pattern.atpDataCons @@# (map CExprVar new_ptrs))
			# hyp2									= CEqual pattern.atpResult (CBasicValue value)
			# (hyp2, heaps)							= SafeSubst subst hyp2 heaps
			= (OK, add_vars new_ptrs (CImplies hyp1 (CImplies hyp2 prop)), heaps)
			where
				add_vars [ptr:ptrs] p
					= CExprForall ptr (add_vars ptrs p)
				add_vars [] p
					= p
		add_hyps expr value (E2 pattern) prop heaps
			# hyp1									= CEqual expr (CBasicValue pattern.bapBasicValue)
			# hyp2									= CEqual pattern.bapResult (CBasicValue value)
			= (OK, CImplies hyp1 (CImplies hyp2 prop), heaps)
		// BEZIG
		add_hyps expr value (E3 def) prop heaps
			= ([X_Internal "ChooseCase with default: not built-in yet."], DummyValue, heaps)
		
		build_prop :: !CExprH !CBasicValueH !MyPattern !*CHeaps -> (!Error, !CPropH, !*CHeaps)
		build_prop expr value (E1 pattern) heaps
			# old_ptrs								= pattern.atpExprVarScope
			# (old_vars, heaps)						= readPointers old_ptrs heaps
			# (new_ptrs, heaps)						= newPointers old_vars heaps
			# subst									= {DummyValue & subExprVars = zip2 old_ptrs (map CExprVar new_ptrs)}
			# hyp1									= CEqual expr (pattern.atpDataCons @@# (map CExprVar new_ptrs))
			# hyp2									= CEqual pattern.atpResult (CBasicValue value)
			# (hyp2, heaps)							= SafeSubst subst hyp1 heaps
			= (OK, add_vars new_ptrs (CAnd hyp1 hyp2), heaps)
			where
				add_vars [ptr:ptrs] p
					= CExprForall ptr (add_vars ptrs p)
				add_vars [] p
					= p
		build_prop expr value (E2 pattern) heaps
			# hyp1									= CEqual expr (CBasicValue pattern.bapBasicValue)
			# hyp2									= CEqual pattern.bapResult (CBasicValue value)
			= (OK, CAnd hyp1 hyp2, heaps)
		// BEZIG
		build_prop expr value (E3 def) heaps
			= ([X_Internal "ChooseCase with default: not built-in yet."], DummyValue, heaps)


// ------------------------------------------------------------------------------------------------------------------------
ChooseCase :: !Goal !*CHeaps !*CProject -> (!Error, ![Goal], ![TheoremPtr], ![HeapPtr], !*CHeaps, !*CProject)
// ------------------------------------------------------------------------------------------------------------------------
ChooseCase goal heaps prj
	# goal											= {goal & glNrIHs = 0}
	# (ok, goal, heaps, prj)						= chooseCase True goal.glToProve goal heaps prj
	| not ok										= ([X_ApplyTactic "ChooseCase" "Current goal does not have a suitable case to split."], DummyValue, DummyValue, DummyValue, heaps, prj)
	= (OK, [goal], [], [], heaps, prj)

// ------------------------------------------------------------------------------------------------------------------------
ChooseCaseH :: !HypothesisPtr !Goal !*CHeaps !*CProject -> (!Error, ![Goal], ![TheoremPtr], ![HeapPtr], !*CHeaps, !*CProject)
// ------------------------------------------------------------------------------------------------------------------------
ChooseCaseH ptr goal heaps prj
	# goal											= {goal & glNrIHs = 0}
	# (hyp, heaps)									= readPointer ptr heaps
	# (ok, goal, heaps, prj)						= chooseCase False hyp.hypProp goal heaps prj
	| not ok										= ([X_ApplyTactic "ChooseCaseH" "Given hypothesis does not have a suitable case to split."], DummyValue, DummyValue, DummyValue, heaps, prj)
	= (OK, [goal], [], [], heaps, prj)

// ------------------------------------------------------------------------------------------------------------------------
Compare :: !CExprH !CExprH !Goal !*CHeaps !*CProject -> (!Error, ![Goal], ![TheoremPtr], ![HeapPtr], !*CHeaps, !*CProject)
// ------------------------------------------------------------------------------------------------------------------------
Compare e1 e2 goal heaps prj
	# goal									= {goal & glNrIHs = 0}
	// check type of e1
	# (error, (_, type), heaps, prj)		= typeExprInGoal e1 goal heaps prj
	| isError error							= (error, DummyValue, DummyValue, DummyValue, heaps, prj)
	| type <> CBasicType CInteger			= ([X_ApplyTactic "Compare" "First expression is not of type Int."], DummyValue, DummyValue, DummyValue, heaps, prj)
	// check type of e2
	# (error, (_, type), heaps, prj)		= typeExprInGoal e2 goal heaps prj
	| isError error							= (error, DummyValue, DummyValue, DummyValue, heaps, prj)
	| type <> CBasicType CInteger			= ([X_ApplyTactic "Compare" "Second expression is not of type Int."], DummyValue, DummyValue, DummyValue, heaps, prj)
	// administrate
	# (int_funs, prj)						= prj!prjABCFunctions.stdInt
	# (plus, smaller)						= (int_funs.intAdd, int_funs.intSmaller)
	| plus == DummyValue					= ([X_ApplyTactic "Compare" "Can not find '+' in module 'StdInt'."], DummyValue, DummyValue, DummyValue, heaps, prj)
	| smaller == DummyValue					= ([X_ApplyTactic "Compare" "Can not find '<' in module 'StdInt'."], DummyValue, DummyValue, DummyValue, heaps, prj)
	# (used_symbols1, heaps)				= GetUsedSymbols e1 heaps
	# (used_symbols2, heaps)				= GetUsedSymbols e2 heaps
	// e1 = bottom
	# hyp									= CEqual e1 CBottom
	# goal0									= {goal & glToProve = CImplies hyp goal.glToProve}
	// e2 = bottom
	# hyp									= CEqual e2 CBottom
	# goal1									= {goal & glToProve = CImplies hyp goal.glToProve}
	// e1 < e2
	# hyp									= CEqual (smaller @@# [e1, e2]) (CBasicValue (CBasicBoolean True))
	# goal2									= {goal & glToProve = CImplies hyp goal.glToProve}
	// e1 = e2
	# hyp1									= CNot (CEqual e1 CBottom)
	# hyp2									= CNot (CEqual e2 CBottom)
	# hyp3									= CEqual e1 e2
	# goal3									= {goal & glToProve = CImplies hyp1 (CImplies hyp2 (CImplies hyp3 goal.glToProve))}
	// e2 < e1
	# hyp									= CEqual (smaller @@# [e2, e1]) (CBasicValue (CBasicBoolean True))
	# goal4									= {goal & glToProve = CImplies hyp goal.glToProve}
	= (OK, [goal0,goal1,goal2,goal3,goal4], [], used_symbols1 ++ used_symbols2, heaps, prj)

// ------------------------------------------------------------------------------------------------------------------------
CompareH :: !HypothesisPtr !TacticMode !Goal !*CHeaps !*CProject -> (!Error, ![Goal], ![TheoremPtr], ![HeapPtr], !*CHeaps, !*CProject)
// ------------------------------------------------------------------------------------------------------------------------
CompareH ptr mode goal heaps prj
	# (hyp, heaps)							= readPointer ptr heaps
	# (int_funs, prj)						= prj!prjABCFunctions.stdInt
	# smaller								= int_funs.intSmaller
	# (ok, e1, e2)							= check hyp.hypProp smaller
	| not ok								= ([X_ApplyTactic "Compare" "Hypothesis not of the form e1 < e2 = False"], DummyValue, DummyValue, DummyValue, heaps, prj)
	# hyp0									= CEqual e1 e2
	# hyp1									= CEqual (smaller @@# [e2,e1]) (CBasicValue (CBasicBoolean True))
	| mode == Implicit
		# (hyps0, heaps, prj)				= overwriteHypothesis goal.glHypotheses ptr hyp0 heaps prj
		# goal0								= {goal & glHypotheses = hyps0}
		# (hyps1, heaps, prj)				= overwriteHypothesis goal.glHypotheses ptr hyp1 heaps prj
		# goal1								= {goal & glHypotheses = hyps1}
		= (OK, [goal0, goal1], [], [], heaps, prj)
//	| mode == Explicit
		# goal0								= {goal & glToProve = CImplies hyp0 goal.glToProve, glNrIHs = 0}
		# goal1								= {goal & glToProve = CImplies hyp1 goal.glToProve, glNrIHs = 0}
		= (OK, [goal0, goal1], [], [], heaps, prj)
	where
		check :: !CPropH !HeapPtr -> (!Bool, !CExprH, !CExprH)
		check (CEqual (ptr @@# [e1,e2]) (CBasicValue (CBasicBoolean False))) smaller
			= (ptr == smaller, e1, e2)
		check other smaller
			= (False, DummyValue, DummyValue)

// ------------------------------------------------------------------------------------------------------------------------
contradict :: !CPropH -> CPropH
// ------------------------------------------------------------------------------------------------------------------------
contradict (CNot p)
	= p
contradict p
	= CNot p

// ------------------------------------------------------------------------------------------------------------------------
Contradiction :: !TacticMode !Goal !*CHeaps !*CProject -> (!Error, ![Goal], ![TheoremPtr], ![HeapPtr], !*CHeaps, !*CProject)
// ------------------------------------------------------------------------------------------------------------------------
Contradiction Explicit goal heaps prj
	# goal									= { goal	& glToProve = CImplies (contradict goal.glToProve) CFalse
											  }
	= (OK, [goal], [], [], heaps, prj)
Contradiction Implicit goal heaps prj
	# prop									= contradict goal.glToProve
	# goal									= {goal & glToProve = CFalse}
	# (goal, heaps, prj)					= newHypotheses goal [prop] heaps prj
	= (OK, [goal], [], [], heaps, prj)

// ------------------------------------------------------------------------------------------------------------------------
ContradictionH :: !HypothesisPtr !Goal !*CHeaps !*CProject -> (!Error, ![Goal], ![TheoremPtr], ![HeapPtr], !*CHeaps, !*CProject)
// ------------------------------------------------------------------------------------------------------------------------
ContradictionH ptr goal heaps prj
	# (hyp, heaps)							= readPointer ptr heaps
	# (prop, heaps)							= FreshVars hyp.hypProp heaps
	# goal									= {goal		& glToProve = contradict prop}
	= (OK, [goal], [], [], heaps, prj)

// ------------------------------------------------------------------------------------------------------------------------
Cut :: !UseFact !Goal !*CHeaps !*CProject -> (!Error, ![Goal], ![TheoremPtr], ![HeapPtr], !*CHeaps, !*CProject)
// ------------------------------------------------------------------------------------------------------------------------
Cut fact goal heaps prj
	# (error, prop, used_theorems, used_symbols, heaps)
											= getFact fact heaps
	| isError error							= (error, DummyValue, DummyValue, DummyValue, heaps, prj)
	# goal									= {goal & glToProve = CImplies prop goal.glToProve, glNrIHs = 0}
	= (OK, [goal], used_theorems, used_symbols, heaps, prj)

// ------------------------------------------------------------------------------------------------------------------------
Definedness :: !Goal !*CHeaps !*CProject -> (!Error, ![Goal], ![TheoremPtr], ![HeapPtr], !*CHeaps, !*CProject)
// ------------------------------------------------------------------------------------------------------------------------
Definedness goal heaps prj
	# (con, definedness_info, heaps, prj)	= findDefinednessInfo goal heaps prj
	= case con || contradict definedness_info.definedExpressions definedness_info.undefinedExpressions of
		True	-> (OK, [], [], [], heaps, prj)
		False	-> ([X_ApplyTactic "Definedness" "No contradictory definedness could be detected."], DummyValue, DummyValue, DummyValue, heaps, prj)
	where
		contradict :: ![CExprH] ![CExprH] -> Bool
		contradict [expr:exprs] undefined
			| isMember expr undefined						= True
			= contradict exprs undefined
		contradict [] undefined
			= False

// ------------------------------------------------------------------------------------------------------------------------
Discard :: ![CExprVarPtr] ![CPropVarPtr] ![HypothesisPtr] !Goal !*CHeaps !*CProject -> (!Error, ![Goal], ![TheoremPtr], ![HeapPtr], !*CHeaps, !*CProject)
// ------------------------------------------------------------------------------------------------------------------------
Discard evars pvars hyps goal heaps prj
	# new_goal								= {goal	& glExprVars	= removeMembers goal.glExprVars evars
													, glPropVars	= removeMembers goal.glPropVars pvars
													, glHypotheses	= removeMembers goal.glHypotheses hyps}
	# (ptr_info, heaps)						= GetPtrInfo new_goal heaps
	# (error, heaps)						= check_evars evars ptr_info.freeExprVars heaps
	| isError error							= (error, DummyValue, DummyValue, DummyValue, heaps, prj)
	# (error, heaps)						= check_pvars pvars ptr_info.freePropVars heaps
	| isError error							= (error, DummyValue, DummyValue, DummyValue, heaps, prj)
	# (new_num, heaps)						= reset_hyp_num 1 new_goal.glHypotheses heaps
	# (new_ih_num, heaps)					= reset_ih_num 1 new_goal.glHypotheses heaps
	# new_goal								= {new_goal & glNewHypNum = new_num, glNewIHNum = new_ih_num}
	= (OK, [new_goal], [], [], heaps, prj)
	where
		check_evars :: ![CExprVarPtr] ![CExprVarPtr] !*CHeaps -> (!Error, !*CHeaps)
		check_evars [ptr:ptrs] free heaps
			| not (isMember ptr free)		= check_evars ptrs free heaps
			# (var, heaps)					= readPointer ptr heaps
			= (pushError (X_ApplyTactic "Discard" ("Variable '" +++ var.evarName +++ "' may not be discarded.")) OK, heaps)
		check_evars [] free heaps
			= (OK, heaps)
		
		check_pvars :: ![CPropVarPtr] ![CPropVarPtr] !*CHeaps -> (!Error, !*CHeaps)
		check_pvars [ptr:ptrs] free heaps
			| not (isMember ptr free)		= check_pvars ptrs free heaps
			# (var, heaps)					= readPointer ptr heaps
			= (pushError (X_ApplyTactic "Discard" ("Variable '" +++ var.pvarName +++ "' may not be discarded.")) OK, heaps)
		check_pvars [] free heaps
			= (OK, heaps)
		
		reset_hyp_num :: !Int ![HypothesisPtr] !*CHeaps -> (!Int, !*CHeaps)
		reset_hyp_num n [] heaps
			= (n, heaps)
		reset_hyp_num n [ptr:ptrs] heaps
			# (hyp, heaps)					= readPointer ptr heaps
			| hyp.hypName.[0] <> 'H'		= reset_hyp_num n ptrs heaps
			# this_num						= toInt (hyp.hypName % (1, size hyp.hypName-1))
			= reset_hyp_num (max n (this_num+1)) ptrs heaps
		
		reset_ih_num :: !Int ![HypothesisPtr] !*CHeaps -> (!Int, !*CHeaps)
		reset_ih_num n [] heaps
			= (n, heaps)
		reset_ih_num n [ptr:ptrs] heaps
			# (hyp, heaps)					= readPointer ptr heaps
			| hyp.hypName.[0] <> 'I'		= reset_ih_num n ptrs heaps
			| hyp.hypName.[1] <> 'H'		= reset_ih_num n ptrs heaps
			# this_num						= toInt (hyp.hypName % (2, size hyp.hypName-1))
			= reset_ih_num (max n (this_num+1)) ptrs heaps

// ------------------------------------------------------------------------------------------------------------------------
Exact :: !UseFact !Goal !*CHeaps !*CProject -> (!Error, ![Goal], ![TheoremPtr], ![HeapPtr], !*CHeaps, !*CProject)
// ------------------------------------------------------------------------------------------------------------------------
Exact fact goal heaps prj
	# (error, prop, used_theorems, used_symbols, heaps)
											= getFact fact heaps
	| isError error							= (error, DummyValue, DummyValue, DummyValue, heaps, prj)
	# (equal, heaps)						= AlphaEqual goal.glToProve prop heaps
	| not equal								= (pushError (X_ApplyTactic "Exact" "Given fact is not equal to current goal") OK, DummyValue, DummyValue, DummyValue, heaps, prj)
	= (OK, [], used_theorems, used_symbols, heaps, prj)

// ------------------------------------------------------------------------------------------------------------------------
ExFalso :: !HypothesisPtr !Goal !*CHeaps !*CProject -> (!Error, ![Goal], ![TheoremPtr], ![HeapPtr], !*CHeaps, !*CProject)
// ------------------------------------------------------------------------------------------------------------------------
ExFalso hyp goal heaps prj
	# (hyp, heaps)							= readPointer hyp heaps
	| hyp.hypProp <> CFalse					= (pushError (X_ApplyTactic "ExFalso" "Given hypothesis is not FALSE") OK, DummyValue, DummyValue, DummyValue, heaps, prj)
	= (OK, [], [], [], heaps, prj)

// ------------------------------------------------------------------------------------------------------------------------
expandFun :: !ReductionOptions !CExprH !*CHeaps !*CProject -> (!Error, !(!Bool, !CExprH), !*CHeaps, !*CProject)
// ------------------------------------------------------------------------------------------------------------------------
expandFun options expr=:(ptr @@# exprs) heaps prj
	| ptrKind ptr <> CFun					= (OK, (False, DummyValue), heaps, prj)
	# (error, fundef, prj)					= getFunDef ptr prj
	| isError error							= (error, DummyValue, heaps, prj)
	# (error, (changed, expr), heaps, prj)	= ReduceSteps 1 options expr heaps prj
	| isError error							= (error, DummyValue, heaps, prj)
	= case changed of
		True			-> case expr of
							p2 @@# _		-> case ptr == p2 of
												True	-> ([X_ApplyTactic "ExpandFun" "Strict arguments of function are not in root normal form."], DummyValue, heaps, prj)
												False	-> (OK, (True, expr), heaps, prj)
							_				-> (OK, (True, expr), heaps, prj)
		other			-> ([X_ApplyTactic "ExpandFun" "Strict arguments of function are not in root normal form."], DummyValue, heaps, prj)
expandFun options expr heaps prj
	= (OK, (False, expr), heaps, prj)

// ------------------------------------------------------------------------------------------------------------------------
ExpandFun :: !CName !Int !Goal !*CHeaps !*CProject -> (!Error, ![Goal], ![TheoremPtr], ![HeapPtr], !*CHeaps, !*CProject)
// ------------------------------------------------------------------------------------------------------------------------
ExpandFun name index goal heaps prj
	# (_, definedness_info, heaps, prj)		= findDefinednessInfo goal heaps prj
	# options								= {roAmount = ReduceExactly 1, roMode = Offensive, roDefinedVariables = definedness_info.definedVariables, roDefinedExpressions = definedness_info.definedExpressions}
	# location								= SelectedSubExpr name index Nothing
	# (error, (changed, prop), heaps, prj)	= actOnExprLocation location goal.glToProve (expandFun options) heaps prj
	| isError error							= (error, DummyValue, DummyValue, DummyValue, heaps, prj)
	| not changed							= ([X_ApplyTactic "ExpandFun" "Function not found in current goal."], DummyValue, DummyValue, DummyValue, heaps, prj)
	# goal									= {goal & glToProve = prop}
	= (OK, [goal], [], [], heaps, prj)

// ------------------------------------------------------------------------------------------------------------------------
ExpandFunH :: !CName !Int !HypothesisPtr !TacticMode !Goal !*CHeaps !*CProject -> (!Error, ![Goal], ![TheoremPtr], ![HeapPtr], !*CHeaps, !*CProject)
// ------------------------------------------------------------------------------------------------------------------------
ExpandFunH name index ptr mode goal heaps prj
	# (_, definedness_info, heaps, prj)		= findDefinednessInfo goal heaps prj
	# options								= {roAmount = ReduceExactly 1, roMode = Offensive, roDefinedVariables = definedness_info.definedVariables, roDefinedExpressions = definedness_info.definedExpressions}
	# (hyp, heaps)							= readPointer ptr heaps
	# location								= SelectedSubExpr name index Nothing
	# (error, (changed, prop), heaps, prj)	= actOnExprLocation location hyp.hypProp (expandFun options) heaps prj
	| isError error							= (error, DummyValue, DummyValue, DummyValue, heaps, prj)
	| not changed							= ([X_ApplyTactic "ExpandFun" ("Function not found in hypothesis '" +++ hyp.hypName +++ "'.")], DummyValue, DummyValue, DummyValue, heaps, prj)
	| mode == Implicit
		# (hypotheses, heaps, prj)			= overwriteHypothesis goal.glHypotheses ptr prop heaps prj
		# goal								= {goal & glHypotheses = hypotheses}
		= (OK, [goal], [], [], heaps, prj)
//	| mode == Explicit
		# (prop, heaps)						= FreshVars prop heaps
		# goal								= {goal & glToProve = CImplies prop goal.glToProve}
		= (OK, [goal], [], [], heaps, prj)

// ------------------------------------------------------------------------------------------------------------------------
Extensionality :: !CName !Goal !*CHeaps !*CProject -> (!Error, ![Goal], ![TheoremPtr], ![HeapPtr], !*CHeaps, !*CProject)
// ------------------------------------------------------------------------------------------------------------------------
Extensionality name goal heaps prj
	# (ok, e1, e2, intros)					= is_equality goal.glToProve
	| not ok								= (pushError (X_ApplyTactic "Extensionality" "Current goal is not an equality.") OK, DummyValue, DummyValue, DummyValue, heaps, prj)
	# (error, (_, type), heaps, prj)		= typeExprInGoal e1 (intro_in_goal intros goal) heaps prj
	| isError error							= (error, DummyValue, DummyValue, DummyValue, heaps, prj)
	| not (is_function_type type)			= (pushError (X_ApplyTactic "Extensionality" "Expressions in equality do not have a function type.") OK, DummyValue, DummyValue, DummyValue, heaps, prj)
	# new_var								= {DummyValue & evarName = name}
	# (new_ptr, heaps)						= newPointer new_var heaps
	# (defined_e1, e1_with_arg, heaps, prj)	= add_argument e1 (CExprVar new_ptr) heaps prj
	# (defined_e2, e2_with_arg, heaps, prj)	= add_argument e2 (CExprVar new_ptr) heaps prj
	# bottom_check							= CIff (CEqual e1 CBottom) (CEqual e2 CBottom)
	# p_without_foralls						= case (defined_e1 && defined_e2) of
												True	-> CEqual e1_with_arg e2_with_arg
												False	-> CAnd bottom_check (CEqual e1_with_arg e2_with_arg)
	# p										= intro_in_prop intros p_without_foralls
	# goal									= {goal & glToProve = CExprForall new_ptr p}
	= (OK, [goal], [], [], heaps, prj)
	where
		is_equality :: !CPropH -> (!Bool, !CExprH, !CExprH, ![Either3 CExprVarPtr CPropVarPtr CPropH])
		is_equality (CEqual e1 e2)
			= (True, e1, e2, [])
		is_equality (CExprForall ptr p)
			# (ok, e1, e2, intros)			= is_equality p
			= (ok, e1, e2, [E1 ptr: intros])
		is_equality (CPropForall ptr p)
			# (ok, e1, e2, intros)			= is_equality p
			= (ok, e1, e2, [E2 ptr: intros])
		is_equality (CImplies p q)
			# (ok, e1, e2, intros)			= is_equality q
			= (ok, e1, e2, [E3 p: intros])
		is_equality _
			= (False, DummyValue, DummyValue, [])
		
		intro_in_goal :: ![Either3 CExprVarPtr CPropVarPtr CPropH] !Goal -> Goal
		intro_in_goal [E1 ptr: intros] goal
			= intro_in_goal intros {goal & glExprVars = [ptr: goal.glExprVars]}
		intro_in_goal [E2 ptr: intros] goal
			= intro_in_goal intros {goal & glPropVars = [ptr: goal.glPropVars]}
		intro_in_goal [E3 p: intros] goal
			= intro_in_goal intros {goal & glToProve = CImplies p goal.glToProve}
		intro_in_goal [] goal
			= goal
		
		is_function_type :: !CTypeH -> Bool
		is_function_type (t1 ==> t2)		= True
		is_function_type _					= False
		
		add_argument :: !CExprH !CExprH !*CHeaps !*CProject -> (!Bool, !CExprH, !*CHeaps, !*CProject)
		add_argument (expr @# exprs) e heaps prj
			= (False, expr @# (exprs ++ [e]), heaps, prj)
		add_argument (ptr @@# exprs) e heaps prj
			# new_expr						= ptr @@# (exprs ++ [e])
			# (error, fundef, prj)			= getFunDef ptr prj
			| isOK error
				# (mod, heaps)				= readPointer (ptrModule ptr) heaps
				# modified_arity			= case (mod.pmName == "StdFunc" && fundef.fdName == "o") of
												True	-> 3
												False	-> fundef.fdArity
				= (modified_arity > length exprs, new_expr, heaps, prj)
			# (error, consdef, prj)			= getDataConsDef ptr prj
			| isError error					= (False, new_expr, heaps, prj)
			= (all_lazy consdef.dcdSymbolType.sytArguments, new_expr, heaps, prj)
			where
				all_lazy :: ![CTypeH] -> Bool
				all_lazy [CStrict _: _]		= False
				all_lazy [_: types]			= all_lazy types
				all_lazy []					= True
		add_argument expr e heaps prj
			= (False, expr @# [e], heaps, prj)
		
		intro_in_prop :: ![Either3 CExprVarPtr CPropVarPtr CPropH] !CPropH -> CPropH
		intro_in_prop [E1 ptr: intros] prop
			= CExprForall ptr (intro_in_prop intros prop)
		intro_in_prop [E2 ptr: intros] prop
			= CPropForall ptr (intro_in_prop intros prop)
		intro_in_prop [E3 p: intros] prop
			= CImplies p (intro_in_prop intros prop)
		intro_in_prop [] prop
			= prop

// ------------------------------------------------------------------------------------------------------------------------
GeneralizeE :: !CExprH !CName !Goal !*CHeaps !*CProject -> (!Error, ![Goal], ![TheoremPtr], ![HeapPtr], !*CHeaps, !*CProject)
// ------------------------------------------------------------------------------------------------------------------------
GeneralizeE expr name goal heaps prj
	# (new_var, heaps)						= newPointer {DummyValue & evarName = name} heaps
	# (ok, to_prove, heaps)					= replaceExpr goal.glToProve expr (CExprVar new_var) heaps
	| not ok								= (pushError (X_ApplyTactic "Generalize" "Expression given was not found in current goal") OK, DummyValue, DummyValue, DummyValue, heaps, prj)
	# goal									= {goal & glToProve = CExprForall new_var to_prove}
	# (used_symbols, heaps)					= GetUsedSymbols expr heaps
	= (OK, [goal], [], used_symbols, heaps, prj)

// ------------------------------------------------------------------------------------------------------------------------
GeneralizeP :: !CPropH !CName !Goal !*CHeaps !*CProject -> (!Error, ![Goal], ![TheoremPtr], ![HeapPtr], !*CHeaps, !*CProject)
// ------------------------------------------------------------------------------------------------------------------------
GeneralizeP prop name goal heaps prj
	# (new_var, heaps)						= newPointer {DummyValue & pvarName = name} heaps
	# (ok, to_prove, heaps)					= replaceProp goal.glToProve prop (CPropVar new_var) heaps
	| not ok								= (pushError (X_ApplyTactic "Generalize" "Proposition given was not found in current goal") OK, DummyValue, DummyValue, DummyValue, heaps, prj)
	# goal									= {goal & glToProve = CPropForall new_var to_prove}
	# (used_symbols, heaps)					= GetUsedSymbols prop heaps
	= (OK, [goal], [], used_symbols, heaps, prj)

// ========================================================================================================================
// Checks if Induction is allowed on a proposition (w.r.t. lazy structures).
// Criterium: all equalities occurring on negative positions should be decidable.
// An equality is decidable if it can be expressed with '=='.
// A negative position is a position within an odd numbers of NOTs.
// (a FORALL quantor on a negative position is *not* allowed)
// Arguments: 
// @1 -- Bool -- encountered an odd number of NOTS.
// ------------------------------------------------------------------------------------------------------------------------
inductionAllowed :: !CExprVarPtr !Bool !CPropH !Goal !*CHeaps !*CProject -> (!Bool, !*CHeaps, !*CProject)
// ------------------------------------------------------------------------------------------------------------------------
inductionAllowed var _ CTrue goal heaps prj
	= (True, heaps, prj)
inductionAllowed var _ CFalse goal heaps prj
	= (True, heaps, prj)
inductionAllowed var _ (CPropVar _) goal heaps prj
	= (True, heaps, prj)
inductionAllowed var negative (CNot p) goal heaps prj
	= inductionAllowed var (not negative) p goal heaps prj
inductionAllowed var negative (CAnd p q) goal heaps prj
	#! (allowed, heaps, prj)				= inductionAllowed var negative p goal heaps prj
	| not allowed							= (False, heaps, prj)
	= inductionAllowed var negative q goal heaps prj
inductionAllowed var negative (COr p q) goal heaps prj
	#! (allowed, heaps, prj)				= inductionAllowed var negative p goal heaps prj
	| not allowed							= (False, heaps, prj)
	= inductionAllowed var negative q goal heaps prj
inductionAllowed var negative (CImplies p q) goal heaps prj
	#! (allowed, heaps, prj)				= inductionAllowed var (not negative) p goal heaps prj
	| not allowed							= (False, heaps, prj)
	= inductionAllowed var negative q goal heaps prj
inductionAllowed var negative (CIff p q) goal heaps prj
	#! (allowed, heaps, prj)				= inductionAllowed var (not negative) p goal heaps prj
	| not allowed							= (False, heaps, prj)
	= inductionAllowed var (not negative) q goal heaps prj
// BEZIG -- mag je bij proposities niet gewoon doorgaan? of juist nooit?
inductionAllowed var negative (CPropForall _ p) goal heaps prj
//	| negative								= (False, heaps, prj)
	= inductionAllowed var negative p goal heaps prj
// BEZIG -- mag je bij proposities niet gewoon doorgaan? of juist nooit?
inductionAllowed var negative (CPropExists _ p) goal heaps prj
//	| not negative							= (False, heaps, prj)
	= inductionAllowed var negative p goal heaps prj
inductionAllowed var negative (CExprForall _ p) goal heaps prj
	= inductionAllowed var negative p goal heaps prj
inductionAllowed var negative (CExprExists _ p) goal heaps prj
	= inductionAllowed var negative p goal heaps prj
inductionAllowed var negative (CEqual e1 e2) goal heaps prj
	| not negative							= (True, heaps, prj)
	// comparing to an expression in Normal Form is always decidable
	| inNormalForm e1 || inNormalForm e2	= (True, heaps, prj)
	// comparing is always decidable if the variable does not occur
	# (info, heaps)							= GetPtrInfo (CEqual e1 e2) heaps
	| not (isMember var info.freeExprVars)	= (True, heaps, prj)
	// comparing within a finite type is always decidable (1)
	# (error, (_, type), heaps, prj)		= typeExprInGoal e1 goal heaps prj
	| isError error							= (False, heaps, prj)
	# (lazy, prj)							= isLazyType type prj
	| lazy									= (False, heaps, prj)
	// comparing within a finite type is always decidable (1)
	# (error, (_, type), heaps, prj)		= typeExprInGoal e2 goal heaps prj
	| isError error							= (False, heaps, prj)
	# (lazy, prj)							= isLazyType type prj
	| lazy									= (False, heaps, prj)
	= (True, heaps, prj)
inductionAllowed var _ (CPredicate _ _) goal heaps prj
	= (False, heaps, prj)

// ------------------------------------------------------------------------------------------------------------------------
inNormalForm :: !CExprH -> Bool
// ------------------------------------------------------------------------------------------------------------------------
inNormalForm (CExprVar _)
	= False
inNormalForm (expr @# exprs)
	= False
inNormalForm (ptr @@# exprs)
	| ptrKind ptr <> CDataCons				= False
	| isEmpty exprs							= True
	= and (map inNormalForm exprs)
inNormalForm (CLet _ _ _)
	= False
inNormalForm (CCase _ _ _)
	= False
inNormalForm (CBasicValue _)
	= True
inNormalForm (CCode _ _)
	= False
inNormalForm CBottom
	= False

// ------------------------------------------------------------------------------------------------------------------------
isLazyType :: !CTypeH !*CProject -> (!Bool, !*CProject)
// ------------------------------------------------------------------------------------------------------------------------
isLazyType (ptr @@^ _) prj
	| ptrKind ptr <> CAlgType				= (False, prj)
	# (error, algtype, prj)					= getAlgTypeDef ptr prj
	| isError error							= (True, prj)
	= isLazyConses ptr algtype.atdConstructors prj
isLazyType _ prj
	= (False, prj)

// ------------------------------------------------------------------------------------------------------------------------
isLazyConses :: !HeapPtr ![HeapPtr] !*CProject -> (!Bool, !*CProject)
// ------------------------------------------------------------------------------------------------------------------------
isLazyConses algptr [consptr:consptrs] prj
	# (error, cons, prj)					= getDataConsDef consptr prj
	| isError error							= (True, prj)
	# recursive								= isRecursiveType algptr cons.dcdSymbolType.sytArguments
	| recursive								= (True, prj)
	= isLazyConses algptr consptrs prj
isLazyConses _ [] prj
	= (False, prj)

// ------------------------------------------------------------------------------------------------------------------------
isRecursiveType :: !HeapPtr ![CTypeH] -> Bool
// ------------------------------------------------------------------------------------------------------------------------
isRecursiveType algptr [ptr @@^ _:types]
	| ptr == algptr							= True
	= isRecursiveType algptr types
isRecursiveType algptr [_:types]
	= isRecursiveType algptr types
isRecursiveType algptr []
	= False

// ------------------------------------------------------------------------------------------------------------------------
Induction :: !CExprVarPtr !TacticMode !Goal !*CHeaps !*CProject -> (!Error, ![Goal], ![TheoremPtr], ![HeapPtr], !*CHeaps, !*CProject)
// ------------------------------------------------------------------------------------------------------------------------
Induction ptr mode goal heaps prj
	# (ok, prop)							= remove_var ptr goal.glToProve
	| not ok								= ([X_ApplyTactic "Induction" "Variable may not be introduced."], DummyValue, DummyValue, DummyValue, heaps, prj)
	# goal									= {goal & glToProve = prop, glExprVars = [ptr:goal.glExprVars]}
	# (error, sub, info, heaps, prj)		= wellTyped goal heaps prj
	| isError error							= (error, DummyValue, DummyValue, DummyValue, heaps, prj)
	# (var, heaps)							= readPointer ptr heaps
	# (ok, type)							= get_type var.evarInfo
	| not ok								= (pushError (X_ApplyTactic "Induction" "[I] No type found???") OK, DummyValue, DummyValue, DummyValue, heaps, prj)
	# type									= SimpleSubst sub type
	
	# (lazy, prj)							= isLazyType type prj
	# (allowed, heaps, prj)					= case lazy of
												True	-> inductionAllowed ptr False goal.glToProve goal heaps prj
												False	-> (True, heaps, prj)
	| not allowed							= ([X_ApplyTactic "Induction" "Proposition does not satisfy demands for lazy structures."], DummyValue, DummyValue, DummyValue, heaps, prj)
	
	| type == CBasicType CBoolean
		| mode == Explicit
			# equal0						= CEqual (CExprVar ptr) CBottom
			# equal1						= CEqual (CExprVar ptr) (CBasicValue (CBasicBoolean True))
			# equal2						= CEqual (CExprVar ptr) (CBasicValue (CBasicBoolean False))
			# goal0							= {goal & glToProve = CImplies equal0 goal.glToProve, glNrIHs = 0}
			# goal1							= {goal & glToProve = CImplies equal1 goal.glToProve, glNrIHs = 0}
			# goal2							= {goal & glToProve = CImplies equal2 goal.glToProve, glNrIHs = 0}
			= (OK, [goal0,goal1,goal2], [], [], heaps, prj)
//		| mode == Implicit
			# (goal0, heaps)				= SafeSubst {DummyValue & subExprVars = [(ptr, CBottom)]} goal heaps
			# (goal1, heaps)				= SafeSubst {DummyValue & subExprVars = [(ptr, (CBasicValue (CBasicBoolean True)))]} goal heaps
			# (goal2, heaps)				= SafeSubst {DummyValue & subExprVars = [(ptr, (CBasicValue (CBasicBoolean False)))]} goal heaps
			= (OK, [goal0,goal1,goal2], [], [], heaps, prj)
	// BEZIG
	| type == CBasicType CInteger
		# (int_funs, prj)					= prj!prjABCFunctions.stdInt
		# (plus, smaller)					= (int_funs.intAdd, int_funs.intSmaller)
		| plus == DummyValue				= ([X_ApplyTactic "Induction" "Can not find '+' in module 'StdInt'. (these are required for induction on ints)"], DummyValue, DummyValue, DummyValue, heaps, prj)
		| smaller == DummyValue				= ([X_ApplyTactic "Induction" "Can not find '<' in module 'StdInt'. (these are required for induction on ints)"], DummyValue, DummyValue, DummyValue, heaps, prj)
		| mode == Explicit
			= undef
//		| mode == Implicit
			# goal							= {goal & glNrIHs = 0}
			# (goal0, heaps)				= SafeSubst {DummyValue & subExprVars = [(ptr, CBottom)]} goal heaps
			# smaller_prop					= CEqual (smaller @@# [CExprVar ptr, CBasicValue (CBasicInteger 0)]) (CBasicValue (CBasicBoolean True))
			# not_smaller_prop				= CEqual (smaller @@# [CExprVar ptr, CBasicValue (CBasicInteger 0)]) (CBasicValue (CBasicBoolean False))
			# goal1							= {goal & glToProve = CImplies smaller_prop goal.glToProve}
			# (goal2, heaps)				= SafeSubst {DummyValue & subExprVars = [(ptr, CBasicValue (CBasicInteger 0))]} goal heaps
			# ih							= goal.glToProve
			# (ih, heaps)					= FreshVars ih heaps
			# (is, heaps)					= SafeSubst {DummyValue & subExprVars = [(ptr, plus @@# [CExprVar ptr, CBasicValue (CBasicInteger 1)])]} goal.glToProve heaps
			# goal3							= {goal & glToProve = CImplies not_smaller_prop (CImplies ih is)}
			= (OK, [goal0, goal1, goal2, goal3], [], [], heaps, prj)
	# (ok, alg_ptr)							= get_alg_type type
	| not ok								= (pushError (X_ApplyTactic "Induction" "Variable does not have an algebraic type") OK, DummyValue, DummyValue, DummyValue, heaps, prj)
	# (error, alg_type, prj)				= getAlgTypeDef alg_ptr prj
	| isError error							= (error, DummyValue, DummyValue, DummyValue, heaps, prj)
	# (error, goals, heaps, prj)			= build_goals var ptr alg_type.atdConstructors goal heaps prj
	| isError error							= (error, DummyValue, DummyValue, DummyValue, heaps, prj)
	# (goal, heaps, prj)					= build_goal mode ptr DummyValue CBottom [] goal heaps prj
	= (OK, [goal:goals], [], [], heaps, prj)
	where
		get_type :: !CExprVarInfo -> (!Bool, !CTypeH)
		get_type (EVar_Type type)			= (True, type)
		get_type other						= (False, DummyValue)
		
		get_alg_type :: !CTypeH -> (!Bool, !HeapPtr)
		get_alg_type (ptr @@^ types)
			| ptrKind ptr == CAlgType		= (True, ptr)
			= (False, DummyValue)
		get_alg_type other
			= (False, DummyValue)
		
		build_goals :: !CExprVarDef !CExprVarPtr ![HeapPtr] !Goal !*CHeaps !*CProject -> (!Error, ![Goal], !*CHeaps, !*CProject)
		build_goals var var_ptr [ptr:ptrs] old_goal heaps prj
			# (error, consdef, prj)			= getDataConsDef ptr prj
			| isError error					= (error, DummyValue, heaps, prj)
			# (fresh_vars, heaps)			= new_vars 1 consdef.dcdArity heaps
			# apply_cons					= ptr @@# (map CExprVar fresh_vars)
			# (goal, heaps, prj)			= build_goal mode var_ptr consdef apply_cons fresh_vars old_goal heaps prj
			# goal							= {goal & glInductionVars = fresh_vars ++ goal.glInductionVars}
			# (error, goals, heaps, prj)	= build_goals var var_ptr ptrs old_goal heaps prj
			| isError error					= (error, DummyValue, heaps, prj)
			= (OK, [goal:goals], heaps, prj)
			where
				new_vars :: !Int !Int !*CHeaps -> (![CExprVarPtr], !*CHeaps)
				new_vars index 0 heaps
					= ([], heaps)
				new_vars index n heaps
					# new_var				= {DummyValue & evarName = new_name ptr index var.evarName}
					# (new_ptr, heaps)		= newPointer new_var heaps
					# (new_ptrs, heaps)		= new_vars (index+1) (n-1) heaps
					= ([new_ptr:new_ptrs], heaps)
				
				new_name :: !HeapPtr !Int !CName -> CName
				new_name CConsPtr index old_name
					# name					= remove_last_s old_name
					| index == 1			= name			// Head
					= name +++ "s"							// Tail
				new_name _ index old_name
					= old_name +++ toString index
				
				remove_last_s :: !CName -> CName
				remove_last_s name
					# len					= size name
					| name.[len-1] == 's'	= name % (0, len-2)
					= name
		build_goals var var_ptr [] goal heaps prj
			= (OK, [], heaps, prj)

		build_goal :: !TacticMode !CExprVarPtr !CDataConsDefH !CExprH ![CExprVarPtr] !Goal !*CHeaps !*CProject -> (!Goal, !*CHeaps, !*CProject)
		build_goal Explicit var_ptr consdef apply_cons fresh_vars goal heaps prj
			# equal							= CEqual (CExprVar var_ptr) apply_cons
			# to_prove						= CImplies equal goal.glToProve
			# (to_prove, heaps)				= FreshVars to_prove heaps
			# (r_vars, heaps, prj)			= recursive_vars consdef consdef.dcdSymbolType.sytArguments fresh_vars heaps prj
			# (to_prove, heaps)				= add_ihs var_ptr r_vars goal.glToProve to_prove heaps
			# to_prove						= add_foralls fresh_vars to_prove
			# goal							= {goal & glToProve = to_prove, glNrIHs = 0}
			= (goal, heaps, prj)
		build_goal Implicit var_ptr consdef apply_cons fresh_vars goal heaps prj
			# (to_prove, heaps)				= FreshVars goal.glToProve heaps
			# (to_prove, heaps)				= SafeSubst {DummyValue & subExprVars = [(var_ptr,apply_cons)]} to_prove heaps
			# (r_vars, heaps, prj)			= recursive_vars consdef consdef.dcdSymbolType.sytArguments fresh_vars heaps prj
			# (to_prove, heaps)				= add_ihs var_ptr r_vars goal.glToProve to_prove heaps
			# to_prove						= add_foralls fresh_vars to_prove
			# goal							= {goal & glToProve = to_prove, glNrIHs = length r_vars}
			= (goal, heaps, prj)
		
		recursive_vars :: !CDataConsDefH ![CTypeH] ![CExprVarPtr] !*CHeaps !*CProject -> (![CExprVarPtr], !*CHeaps, !*CProject)
		recursive_vars consdef [CStrict type:types] [var:vars] heaps prj
			= recursive_vars consdef [type:types] [var:vars] heaps prj
		recursive_vars consdef [tcons_ptr @@^ args:types] [var:vars] heaps prj
			# recursive_ptr					= consdef.dcdAlgType == tcons_ptr
			| not recursive_ptr				= recursive_vars consdef types vars heaps prj
			# (_, algtype, prj)				= getAlgTypeDef consdef.dcdAlgType prj
			# (arg_names1, heaps)			= get_names args heaps
			# (arg_names2, heaps)			= getPointerNames [var \\ var <- algtype.atdTypeVarScope] heaps
			# same_args						= arg_names1 == arg_names2
			| not same_args					= recursive_vars consdef types vars heaps prj
			# (vars, heaps, prj)			= recursive_vars consdef types vars heaps prj
			= ([var:vars], heaps, prj)
			where
				get_names :: ![CTypeH] !*CHeaps -> (![CName], !*CHeaps)
				get_names [CTypeVar ptr:types] heaps
					# (name, heaps)			= getPointerName ptr heaps
					# (names, heaps)		= get_names types heaps
					= ([name:names], heaps)
				get_names _ heaps
					= ([], heaps)
		recursive_vars consdef [type:types] [var:vars] heaps prj
			= recursive_vars consdef types vars heaps prj
		recursive_vars _ _ _ heaps prj
			= ([], heaps, prj)
		
		add_ihs :: !CExprVarPtr ![CExprVarPtr] !CPropH !CPropH !*CHeaps -> (!CPropH, !*CHeaps)
		add_ihs predicate_var [var:vars] predicate p heaps
			# (prop, heaps)					= SafeSubst {DummyValue & subExprVars = [(predicate_var, CExprVar var)]} predicate heaps
			# (p, heaps)					= add_ihs predicate_var vars predicate p heaps
			= (CImplies prop p, heaps)
		add_ihs predicate_var [] predicate p heaps
			= (p, heaps)
		
		add_foralls :: ![CExprVarPtr] !CPropH -> CPropH
		add_foralls [ptr:ptrs] p
			= CExprForall ptr (add_foralls ptrs p)
		add_foralls [] p
			= p
		
		remove_var :: !CExprVarPtr !CPropH -> (!Bool, !CPropH)
		remove_var ptr (CExprForall var p)
			| ptr == var					= (True, p)
			# (ok, p)						= remove_var ptr p
			= (ok, CExprForall var p)
		remove_var ptr (CPropForall var p)
			# (ok, p)						= remove_var ptr p
			= (ok, CPropForall var p)
		remove_var ptr other
			= (False, other)

// ========================================================================================================================
// @1: True = in goal; False = in hypothesis
// In a hypothesis, the following are not allowed:
//		(1) functions
//		(2) data-constructors which are NOT known to be defined and which have more than one strict argument
// Output: @2 denotes what was found:
//		(0) = nothing;
//		(1) = function;
//		(2) = case, or function with just one argument;
//		(3) = constructor
// ------------------------------------------------------------------------------------------------------------------------
inject :: !Bool !CPropH !Goal !*CHeaps !*CProject -> (!Bool, !Int, !CPropH, !*CHeaps, !*CProject)
// ------------------------------------------------------------------------------------------------------------------------
inject in_goal (CPropVar ptr) goal heaps prj
	= (False, 0, CPropVar ptr, heaps, prj)
inject in_goal CTrue goal heaps prj
	= (False, 0, CTrue, heaps, prj)
inject in_goal CFalse goal heaps prj
	= (False, 0, CFalse, heaps, prj)
inject in_goal (CEqual e1=:(ptr1 @@# es1) e2=:(ptr2 @@# es2)) goal heaps prj
	= inject_applications in_goal [] e1 [] e2 goal heaps prj
inject in_goal (CEqual (CLet False defs1 e1=:(ptr1 @@# es1)) e2=:(ptr2 @@# es2)) goal heaps prj
	= inject_applications in_goal defs1 e1 [] e2 goal heaps prj
inject in_goal (CEqual e1=:(ptr1 @@# es1) (CLet False defs2 e2=:(ptr2 @@# es2))) goal heaps prj
	= inject_applications in_goal [] e1 defs2 e2 goal heaps prj
inject in_goal (CEqual (CLet False defs1 e1=:(ptr1 @@# es1)) (CLet False defs2 e2=:(ptr2 @@# es2))) goal heaps prj
	= inject_applications in_goal defs1 e1 defs2 e2 goal heaps prj
inject in_goal (CEqual e1=:(CCase expr1 patterns1 def1) e2=:(CCase expr2 patterns2 def2)) goal heaps prj
	| expr1 <> expr2						= (False, 0, CEqual e1 e2, heaps, prj)
	# (ok, equal, heaps)					= make_pattern_equal patterns1 patterns2 heaps
	| not ok								= (False, 0, CEqual e1 e2, heaps, prj)
	# (ok, equal)							= add_default_equal def1 def2 equal
	| not ok								= (False, 0, CEqual e1 e2, heaps, prj)
	= (True, 2, equal, heaps, prj)
	where
		make_pattern_equal :: !CCasePatternsH !CCasePatternsH !*CHeaps -> (!Bool, !CPropH, !*CHeaps)
		make_pattern_equal (CAlgPatterns _ ps1) (CAlgPatterns _ ps2) heaps
			= make_alg_equal ps1 ps2 heaps
		make_pattern_equal (CBasicPatterns _ ps1) (CBasicPatterns _ ps2) heaps
			= make_basic_equal ps1 ps2 heaps
		make_pattern_equal _ _ heaps
			= (False, DummyValue, heaps)
		
		make_alg_equal :: ![CAlgPatternH] ![CAlgPatternH] !*CHeaps -> (!Bool, !CPropH, !*CHeaps)
		make_alg_equal [p1:ps1] [p2:ps2] heaps
			# compatible					= p1.atpDataCons == p2.atpDataCons
			| not compatible				= (False, DummyValue, heaps)
			# (vars, heaps)					= readPointers p1.atpExprVarScope heaps
			# vars							= [{var & evarInfo = EVar_Nothing} \\ var <- vars]
			# (ptrs, heaps)					= newPointers vars heaps
			# exprs							= map CExprVar ptrs
			# sub1							= {DummyValue & subExprVars = zip2 p1.atpExprVarScope exprs}
			# (e1, heaps)					= SafeSubst sub1 p1.atpResult heaps
			# sub2							= {DummyValue & subExprVars = zip2 p2.atpExprVarScope exprs}
			# (e2, heaps)					= SafeSubst sub2 p2.atpResult heaps
			# equal1						= intro_vars ptrs (CEqual e1 e2)
			| isEmpty ps1 && isEmpty ps2	= (True, equal1, heaps)
			# (ok, equal2, heaps)			= make_alg_equal ps1 ps2 heaps
			= (ok, CAnd equal1 equal2, heaps)
		make_alg_equal [] [] heaps
			= (True, CTrue, heaps)
		make_alg_equal _ _ heaps
			= (False, DummyValue, heaps)
		
		intro_vars :: ![CExprVarPtr] !CPropH -> CPropH
		intro_vars [ptr:ptrs] prop
			= CExprForall ptr (intro_vars ptrs prop)
		intro_vars [] prop
			= prop
		
		make_basic_equal :: ![CBasicPatternH] ![CBasicPatternH] !*CHeaps -> (!Bool, !CPropH, !*CHeaps)
		make_basic_equal [p1:ps1] [p2:ps2] heaps
			# compatible					= p1.bapBasicValue == p2.bapBasicValue
			| not compatible				= (False, DummyValue, heaps)
			# equal1						= CEqual p1.bapResult p2.bapResult
			| isEmpty ps1 && isEmpty ps2	= (True, equal1, heaps)
			# (ok, equal2, heaps)			= make_basic_equal ps1 ps2 heaps
			= (ok, CAnd equal1 equal2, heaps)
		make_basic_equal [] [] heaps
			= (True, CTrue, heaps)
		make_basic_equal _ _ heaps
			= (False, DummyValue, heaps)
		
		add_default_equal :: !(Maybe CExprH) !(Maybe CExprH) !CPropH -> (!Bool, !CPropH)
		add_default_equal (Just e1) (Just e2) p
			= (True, CAnd p (CEqual e1 e2))
		add_default_equal Nothing Nothing p
			= (True, p)
		add_default_equal _ _ _
			= (False, DummyValue)
inject in_goal (CEqual e1 e2) goal heaps prj
	= (False, 0, CEqual e1 e2, heaps, prj)
inject in_goal (CNot p) goal heaps prj
	# (changed, score, p, heaps, prj)		= inject False p goal heaps prj
	= (changed, score, CNot p, heaps, prj)
inject in_goal (CAnd p q) goal heaps prj
	# (changed1, score1, p, heaps, prj)		= inject in_goal p goal heaps prj
	# (changed2, score2, q, heaps, prj)		= inject in_goal q goal heaps prj
	= (changed1 || changed2, max score1 score2, CAnd p q, heaps, prj)
inject in_goal (COr p q) goal heaps prj
	# (changed1, score1, p, heaps, prj)		= inject False p goal heaps prj
	# (changed2, score2, q, heaps, prj)		= inject False q goal heaps prj
	= (changed1 || changed2, max score1 score2, COr p q, heaps, prj)
inject in_goal (CImplies p q) goal heaps prj
	# (changed1, score1, p, heaps, prj)		= inject False p goal heaps prj
	# (changed2, score2, q, heaps, prj)		= inject in_goal q goal heaps prj
	= (changed1 || changed2, max score1 score2, CImplies p q, heaps, prj)
inject in_goal (CIff p q) goal heaps prj
	# (changed1, score1, p, heaps, prj)		= inject False p goal heaps prj
	# (changed2, score2, q, heaps, prj)		= inject False q goal heaps prj
	= (changed1 || changed2, max score1 score2, CIff p q, heaps, prj)
inject in_goal (CExprForall ptr p) goal heaps prj
	# (changed, score, p, heaps, prj)		= inject in_goal p goal heaps prj
	= (changed, score, CExprForall ptr p, heaps, prj)
inject in_goal (CExprExists ptr p) goal heaps prj
	# (changed, score, p, heaps, prj)		= inject False p goal heaps prj
	= (changed, score, CExprExists ptr p, heaps, prj)
inject in_goal (CPropForall ptr p) goal heaps prj
	# (changed, score, p, heaps, prj)		= inject in_goal p goal heaps prj
	= (changed, score, CPropForall ptr p, heaps, prj)
inject in_goal (CPropExists ptr p) goal heaps prj
	# (changed, score, p, heaps, prj)		= inject False p goal heaps prj
	= (changed, score, CPropExists ptr p, heaps, prj)
inject in_goal (CPredicate ptr exprs) goal heaps prj
	= (False, 0, CPredicate ptr exprs, heaps, prj)

// ------------------------------------------------------------------------------------------------------------------------
inject_applications :: !Bool ![(CExprVarPtr, CExprH)] !CExprH ![(CExprVarPtr, CExprH)] !CExprH !Goal !*CHeaps !*CProject -> (!Bool, !Int, !CPropH, !*CHeaps, !*CProject)
// ------------------------------------------------------------------------------------------------------------------------
inject_applications in_goal lets1 e1=:(ptr1 @@# es1) lets2 e2=:(ptr2 @@# es2) goal heaps prj
	| ptr1 <> ptr2							= (False, 0, CEqual e1 e2, heaps, prj)
	| ptrKind ptr1 == CFun
		| not in_goal						= (False, 0, CEqual e1 e2, heaps, prj)
		| length es1 <> length es2			= (False, 0, CEqual e1 e2, heaps, prj)
		# score								= if (length es1 == 1) 2 1
		= produce score es1 es2 heaps prj
	| ptrKind ptr1 == CDataCons
		# (_, consdef, prj)					= getDataConsDef ptr1 prj
		# (strictness_ok, heaps, prj)		= is_strictness_ok consdef.dcdSymbolType.sytArguments heaps prj
		# may_continue						= in_goal || strictness_ok
		| not may_continue					= (False, 0, CEqual e1 e2, heaps, prj)
		= produce 3 es1 es2 heaps prj
	= (False, 0, CEqual e1 e2, heaps, prj)
	where
		produce :: !Int ![CExprH] ![CExprH] !*CHeaps !*CProject -> (!Bool, !Int, !CPropH, !*CHeaps, !*CProject)
		produce score list1 list2 heaps prj
			# (equals, heaps, prj)			= make_equals lets1 list1 lets2 list2 heaps prj
			= case reverse equals of
				[]		-> (True, score, CTrue, heaps, prj)
				[p]		-> (True, score, p, heaps, prj)
				[p:ps]	-> (True, score, foldr CAnd p ps, heaps, prj)
		
		make_equals :: ![(CExprVarPtr, CExprH)] ![CExprH] ![(CExprVarPtr, CExprH)] ![CExprH] !*CHeaps !*CProject -> (![CPropH], !*CHeaps, !*CProject)
		make_equals lets1 [e1:es1] lets2 [e2:es2] heaps prj
			# (equals, heaps, prj)			= make_equals lets1 es1 lets2 es2 heaps prj
			# (e1, heaps, prj)				= garbageCollect (CLet False lets1 e1) heaps prj
			# (e2, heaps, prj)				= garbageCollect (CLet False lets2 e2) heaps prj
			= ([CEqual e1 e2: equals], heaps, prj)
		make_equals lets1 [] lets2 [] heaps prj
			= ([], heaps, prj)
		
		count_strict_args :: ![CTypeH] -> Int
		count_strict_args [CStrict _:types]
			= 1 + count_strict_args types
		count_strict_args [_:types]
			= count_strict_args types
		count_strict_args []
			= 0
		
		is_strictness_ok :: ![CTypeH] !*CHeaps !*CProject -> (!Bool, !*CHeaps, !*CProject)
		is_strictness_ok types heaps prj
			| count_strict_args types <= 1	= (True, heaps, prj)
			# (_, info, heaps, prj)			= findDefinednessInfo goal heaps prj
			# (defined1, prj)				= applyDefinednessInfo es1 info prj
			# (defined2, prj)				= applyDefinednessInfo es2 info prj
			= (check defined1 defined2, heaps, prj)
			where
				check :: !Definedness !Definedness -> Bool
				check IsDefined IsDefined
					= True
				check IsDefined (DependsOn _)
					= True
				check (DependsOn _) IsDefined
					= True
				check _ _
					= False

// ------------------------------------------------------------------------------------------------------------------------
Injective :: !Goal !*CHeaps !*CProject -> (!Error, ![Goal], ![TheoremPtr], ![HeapPtr], !*CHeaps, !*CProject)
// ------------------------------------------------------------------------------------------------------------------------
Injective goal heaps prj
	# (changed, _, prop, heaps, prj)	= inject True goal.glToProve goal heaps prj
	| not changed						= ([X_ApplyTactic "Injective" "Not applicable in current goal."], DummyValue, DummyValue, DummyValue, heaps, prj)
	# goal								= {goal & glToProve = prop}
	= (OK, [goal], [], [], heaps, prj)

// ------------------------------------------------------------------------------------------------------------------------
InjectiveH :: !HypothesisPtr !TacticMode !Goal !*CHeaps !*CProject -> (!Error, ![Goal], ![TheoremPtr], ![HeapPtr], !*CHeaps, !*CProject)
// ------------------------------------------------------------------------------------------------------------------------
InjectiveH ptr mode goal heaps prj
	# (hyp, heaps)						= readPointer ptr heaps
	# (changed, _, prop, heaps, prj)	= inject False hyp.hypProp goal heaps prj
	| not changed						= ([X_ApplyTactic "Injective" ("Not applicable in hypothesis '" +++ hyp.hypName +++ "'.")], DummyValue, DummyValue, DummyValue, heaps, prj)
	| mode == Implicit
		# (hypotheses, heaps, prj)		= overwriteHypothesis goal.glHypotheses ptr prop heaps prj
		# goal							= {goal & glHypotheses = hypotheses}
		= (OK, [goal], [], [], heaps, prj)
//	| mode == Explicit
		# goal							= {goal & glToProve = CImplies prop goal.glToProve, glNrIHs = 0}
		= (OK, [goal], [], [], heaps, prj)

// ------------------------------------------------------------------------------------------------------------------------
Introduce :: ![CName] !Goal !*CHeaps !*CProject -> (!Error, ![Goal], ![TheoremPtr], ![HeapPtr], !*CHeaps, !*CProject)
// ------------------------------------------------------------------------------------------------------------------------
Introduce names goal heaps prj
	| isEmpty names						= (pushError (X_ApplyTactic "Introduce" "Nothing to introduce.") OK, DummyValue, DummyValue, DummyValue, heaps, prj)
	# (ok, toProve, goal, heaps, prj)	= intro names goal.glToProve goal heaps prj
	| not ok							= (pushError (X_ApplyTactic "Intro" "More names given than things to introduce.") OK, DummyValue, DummyValue, DummyValue, heaps, prj)
	# new_goal							= {goal & glToProve = toProve}
	= (OK, [new_goal], [], [], heaps, prj)
	where
		intro :: ![CName] !CPropH !Goal !*CHeaps !*CProject -> (!Bool, !CPropH, !Goal, !*CHeaps, !*CProject)
		intro [] prop goal heaps prj
			= (True, prop, goal, heaps, prj)
		intro ["_":names] (CExprForall var prop) goal heaps prj
			# goal						= {goal & glExprVars = [var:goal.glExprVars]}
			= intro names prop goal heaps prj
		intro [name:names] (CExprForall var prop) goal heaps prj
			# (olddef, heaps)			= readPointer var heaps
			| olddef.evarName == name
				# goal					= {goal & glExprVars = [var:goal.glExprVars]}
				= intro names prop goal heaps prj
			# newdef					= {olddef & evarName = name}
			# (newvar, heaps)			= newPointer newdef heaps
			# subst						= {DummyValue & subExprVars = [(var, CExprVar newvar)]}
			# (prop, heaps)				= SafeSubst subst prop heaps
			# (hyps, heaps)				= SafeSubst subst goal.glHypotheses heaps
			= intro names prop {goal & glHypotheses = hyps, glExprVars = [newvar:goal.glExprVars]} heaps prj
		intro ["_":names] (CPropForall var prop) goal heaps prj
			# goal						= {goal & glPropVars = [var:goal.glPropVars]}
			= intro names prop goal heaps prj
		intro [name:names] (CPropForall var prop) goal heaps prj
			# (olddef, heaps)			= readPointer var heaps
			| olddef.pvarName == name
				# goal					= {goal & glPropVars = [var:goal.glPropVars]}
				= intro names prop goal heaps prj
			# newdef					= {olddef & pvarName = name}
			# (newvar, heaps)			= newPointer newdef heaps
			# subst						= {DummyValue & subPropVars = [(var, CPropVar newvar)]}
			# (prop, heaps)				= SafeSubst subst prop heaps
			# (hyps, heaps)				= SafeSubst subst goal.glHypotheses heaps
			= intro names prop {goal & glHypotheses = hyps, glPropVars = [newvar:goal.glPropVars]} heaps prj
		intro [name:names] (CImplies p q) goal heaps prj
//			#! heaps					= heaps --->> (goal.glNrIHs, name)
			# new_name					= case name of
											"_"		-> case goal.glNrIHs > 0 of
														True	-> "IH" +++ (toString goal.glNewIHNum)
														False	-> "H" +++ (toString goal.glNewHypNum)
											_		-> name
			# new_num					= case name of
											"_"		-> if (goal.glNrIHs > 0) goal.glNewHypNum (goal.glNewHypNum+1)
											_		-> goal.glNewHypNum
			# new_ih_num				= case name of
											"_"		-> if (goal.glNrIHs > 0) (goal.glNewIHNum+1) goal.glNewIHNum
											_		-> goal.glNewIHNum
			# new_num					= case name.[0] of
											'H'		-> let hyp_num = toInt (name%(1,size name))
														in if (hyp_num >= new_num) (hyp_num+1) new_num
											_		-> new_num 
			# new_ih_num				= case size name >= 2 && name.[0] == 'I' && name.[1] == 'H' of
											True	-> let hyp_num = toInt (name%(2,size name))
														in if (hyp_num >= new_ih_num) (hyp_num+1) new_ih_num
											False	-> new_ih_num
			# (hyp, heaps)				= newPointer {hypName = new_name, hypProp = p} heaps
			# goal						= {goal	& glNewHypNum		= new_num
												, glNewIHNum		= new_ih_num
												, glHypotheses		= [hyp:goal.glHypotheses]
												, glNrIHs			= if (goal.glNrIHs > 0) (goal.glNrIHs-1) goal.glNrIHs}
			= intro names q goal heaps prj
		intro [name:names] prop goal heaps prj
			# no_underscores			= filter (\name -> name <> "_") names
			= (not (isEmpty no_underscores), prop, goal, heaps, prj)

// ------------------------------------------------------------------------------------------------------------------------
IntArith :: !ExprLocation !Goal !*CHeaps !*CProject -> (!Error, ![Goal], ![TheoremPtr], ![HeapPtr], !*CHeaps, !*CProject)
// ------------------------------------------------------------------------------------------------------------------------
IntArith location goal heaps prj
	# (error, (changed, prop), heaps, prj)	= actOnExprLocation location goal.glToProve ArithInt heaps prj
	| isError error							= (error, DummyValue, DummyValue, DummyValue, heaps, prj)
	| not changed							= ([X_ApplyTactic "Arith" "No simplification possible."], DummyValue, DummyValue, DummyValue, heaps, prj)
	# goal									= {goal & glToProve = prop}
	= (OK, [goal], [], [], heaps, prj)

// ------------------------------------------------------------------------------------------------------------------------
IntArithH :: !ExprLocation !HypothesisPtr !TacticMode !Goal !*CHeaps !*CProject -> (!Error, ![Goal], ![TheoremPtr], ![HeapPtr], !*CHeaps, !*CProject)
// ------------------------------------------------------------------------------------------------------------------------
IntArithH location ptr mode goal heaps prj
	# (hyp, heaps)									= readPointer ptr heaps
	# (error, (changed, prop), heaps, prj)			= actOnExprLocation location hyp.hypProp ArithInt heaps prj
	| isError error									= (error, DummyValue, DummyValue, DummyValue, heaps, prj)
	| not changed									= ([X_ApplyTactic "IntArith" "No arithmetic simplification possible."], DummyValue, DummyValue, DummyValue, heaps, prj)
	| mode == Implicit
		# (hypotheses, heaps, prj)					= overwriteHypothesis goal.glHypotheses ptr prop heaps prj
		# goal										= {goal & glHypotheses = hypotheses}
		= (OK, [goal], [], [], heaps, prj)
//	| mode == Explicit
		# (prop, heaps)								= FreshVars prop heaps
		# goal										= {goal & glToProve = CImplies prop goal.glToProve, glNrIHs = 0}
		= (OK, [goal], [], [], heaps, prj)

// ------------------------------------------------------------------------------------------------------------------------
IntCompare :: !Goal !*CHeaps !*CProject -> (!Error, ![Goal], ![TheoremPtr], ![HeapPtr], !*CHeaps, !*CProject)
// ------------------------------------------------------------------------------------------------------------------------
IntCompare goal heaps prj
	# (contradiction, heaps, prj)					= CompareInts goal heaps prj
	| not contradiction								= ([X_ApplyTactic "IntCompare" "No contradictory integer comparisons were found."], DummyValue, DummyValue, DummyValue, heaps, prj)
	= (OK, [], [], [], heaps, prj)

// ------------------------------------------------------------------------------------------------------------------------
MakeUnique :: !Goal !*CHeaps !*CProject -> (!Error, ![Goal], ![TheoremPtr], ![HeapPtr], !*CHeaps, !*CProject)
// ------------------------------------------------------------------------------------------------------------------------
MakeUnique goal heaps prj
	# (goal, heaps)									= FreshVars goal heaps
	# (ptr_info, heaps)								= GetPtrInfo goal heaps
	# (changed, heaps)								= MakeUniqueNames ptr_info heaps
	| not changed									= ([X_ApplyTactic "MakeUnique" "No duplicate names found."], DummyValue, DummyValue, DummyValue, heaps, prj)
	= (OK, [goal], [], [], heaps, prj)

// ------------------------------------------------------------------------------------------------------------------------
varsUnintro :: !CPropH -> (![Either CExprVarPtr CPropVarPtr], !CPropH)
// ------------------------------------------------------------------------------------------------------------------------
varsUnintro (CExprForall evar p)
	# (vars, p)							= varsUnintro p
	= ([ELeft evar: vars], p)
varsUnintro (CPropForall pvar p)
	# (vars, p)							= varsUnintro p
	= ([ERight pvar: vars], p)
varsUnintro other
	= ([], other)

// ------------------------------------------------------------------------------------------------------------------------
varsIntro :: ![Either CExprVarPtr CPropVarPtr] !CPropH -> CPropH
// ------------------------------------------------------------------------------------------------------------------------
varsIntro [ELeft evar:vars] p
	= CExprForall evar (varsIntro vars p)
varsIntro [ERight pvar:vars] p
	= CPropForall pvar (varsIntro vars p)
varsIntro [] p
	= p

// ------------------------------------------------------------------------------------------------------------------------
setManualDefinedness :: !Goal !*CProject -> *CProject
// ------------------------------------------------------------------------------------------------------------------------
setManualDefinedness goal prj
	= set_definedness goal.glDefinedness prj
	where
		set_definedness :: ![(HeapPtr, [Bool])] !*CProject -> *CProject
		set_definedness [(ptr,selector):info] prj
			# (error, fundef, prj)		= getFunDef ptr prj
			| isError error				= set_definedness info prj
			# fundef					= {fundef & fdDefinedness = CDefinedBy selector}
			# (_, prj)					= putFunDef ptr fundef prj
			= set_definedness info prj
		set_definedness [] prj
			= prj

// ------------------------------------------------------------------------------------------------------------------------
unsetManualDefinedness :: !Goal !*CProject -> *CProject
// ------------------------------------------------------------------------------------------------------------------------
unsetManualDefinedness goal prj
	= unset_definedness goal.glDefinedness prj
	where
		unset_definedness :: ![(HeapPtr, [Bool])] !*CProject -> *CProject
		unset_definedness [(ptr,selector):info] prj
			# (error, fundef, prj)		= getFunDef ptr prj
			| isError error				= unset_definedness info prj
			# fundef					= {fundef & fdDefinedness = CDefinednessUnknown}
			# (_, prj)					= putFunDef ptr fundef prj
			= unset_definedness info prj
		unset_definedness [] prj
			= prj

// ------------------------------------------------------------------------------------------------------------------------
areManualDefinedness :: ![TheoremPtr] !*CHeaps !*CProject -> (!Bool, !String, ![(HeapPtr, [Bool])], !*CHeaps, !*CProject)
// ------------------------------------------------------------------------------------------------------------------------
areManualDefinedness [ptr:ptrs] heaps prj
	# (ok, name, info, heaps, prj)		= isManualDefinedness ptr heaps prj
	| not ok							= (False, name, DummyValue, heaps, prj)
	# (ok, name, infos, heaps, prj)		= areManualDefinedness ptrs heaps prj
	| not ok							= (False, name, DummyValue, heaps, prj)
	= (True, "", [info:infos], heaps, prj)
areManualDefinedness [] heaps prj
	= (True, "", [], heaps, prj)

// ------------------------------------------------------------------------------------------------------------------------
isManualDefinedness :: !TheoremPtr !*CHeaps !*CProject -> (!Bool, !String, !(!HeapPtr, ![Bool]), !*CHeaps, !*CProject)
// ------------------------------------------------------------------------------------------------------------------------
isManualDefinedness ptr heaps prj
	# (theorem, heaps)					= readPointer ptr heaps
	# (ok, info, heaps, prj)			= analyze_prop 0 [] theorem.thInitial heaps prj
	= (ok, theorem.thName, info, heaps, prj)
	where
		analyze_prop :: !Int ![CExprVarPtr] !CPropH !*CHeaps !*CProject -> (!Bool, !(!HeapPtr, ![Bool]), !*CHeaps, !*CProject)
		analyze_prop n [] (CExprForall _ p) heaps prj
			= analyze_prop (n+1) [] p heaps prj
		analyze_prop n vars (CImplies (CNot (CEqual (CExprVar var) CBottom)) p) heaps prj
			| isMember var vars			= (False, DummyValue, heaps, prj)
			= analyze_prop n [var:vars] p heaps prj
		analyze_prop n vars (CNot (CEqual (ptr @@# args) CBottom)) heaps prj
			| isEmpty vars				= (False, DummyValue, heaps, prj)
			# (error, fun, prj)			= getFunDef ptr prj
			| isError error				= (False, DummyValue, heaps, prj)
			| not (unknown fun.fdDefinedness)
										= (False, DummyValue, heaps, prj)
			| n <> fun.fdArity			= (False, DummyValue, heaps, prj)
			# (ok, selector)			= build_selector args vars
			| not ok					= (False, DummyValue, heaps, prj)
			= (True, (ptr, selector), heaps, prj)
		analyze_prop _ _ _ heaps prj
			= (False, DummyValue, heaps, prj)
		
		build_selector :: ![CExprH] ![CExprVarPtr] -> (!Bool, ![Bool])
		build_selector [CExprVar var: args] vars
			# (ok, selector)			= build_selector args vars
			= (ok, [isMember var vars: selector])
		build_selector [_:_] _
			= (False, [])
		build_selector [] _
			= (True, [])

// ------------------------------------------------------------------------------------------------------------------------
ManualDefinedness :: ![TheoremPtr] !Goal !*CHeaps !*CProject -> (!Error, ![Goal], ![TheoremPtr], ![HeapPtr], !*CHeaps, !*CProject)
// ------------------------------------------------------------------------------------------------------------------------
ManualDefinedness ptrs goal heaps prj
	# (ok, name, infos, heaps, prj	)	= areManualDefinedness ptrs heaps prj
	| not ok							= (pushError (X_ApplyTactic "ManualDefinedness" ("Theorem '" +++ name +++ "' does not state definedness of a function symbol.")) OK, DummyValue, DummyValue, DummyValue, heaps, prj)
	# goal								= {goal & glDefinedness = infos ++ goal.glDefinedness}
	= (OK, [goal], ptrs, [], heaps, prj)

// used in MoveInCase
// ------------------------------------------------------------------------------------------------------------------------
class combineCase a :: !a !(CExprH -> CExprH) !*CHeaps !*CProject -> (!a, !*CHeaps, !*CProject)
// ------------------------------------------------------------------------------------------------------------------------

// ------------------------------------------------------------------------------------------------------------------------
instance combineCase (Maybe a) | combineCase a
// ------------------------------------------------------------------------------------------------------------------------
where
	combineCase (Just x) f heaps prj
		# (x, heaps, prj)							= combineCase x f heaps prj
		= (Just x, heaps, prj)
	combineCase Nothing exprs heaps prj
		= (Nothing, heaps, prj)

// ------------------------------------------------------------------------------------------------------------------------
instance combineCase [a] | combineCase a
// ------------------------------------------------------------------------------------------------------------------------
where
	combineCase [x:xs] f heaps prj
		# (x, heaps, prj)							= combineCase x f heaps prj
		# (xs, heaps, prj)							= combineCase xs f heaps prj
		= ([x:xs], heaps, prj)
	combineCase [] f heaps prj
		= ([], heaps, prj)

// ------------------------------------------------------------------------------------------------------------------------
instance combineCase (CAlgPattern HeapPtr)
// ------------------------------------------------------------------------------------------------------------------------
where
	combineCase pattern f heaps prj
		# (expr, heaps, prj)						= combineCase pattern.atpResult f heaps prj
		# pattern									= {pattern & atpResult = expr}
		= (pattern, heaps, prj)

// ------------------------------------------------------------------------------------------------------------------------
instance combineCase (CBasicPattern HeapPtr)
// ------------------------------------------------------------------------------------------------------------------------
where
	combineCase pattern f heaps prj
		# (expr, heaps, prj)						= combineCase pattern.bapResult f heaps prj
		# pattern									= {pattern & bapResult = expr}
		= (pattern, heaps, prj)

// ------------------------------------------------------------------------------------------------------------------------
instance combineCase (CCasePatterns HeapPtr)
// ------------------------------------------------------------------------------------------------------------------------
where
	combineCase (CAlgPatterns type patterns) f heaps prj
		# (patterns, heaps, prj)					= combineCase patterns f heaps prj
		= (CAlgPatterns type patterns, heaps, prj)
	combineCase (CBasicPatterns type patterns) f heaps prj
		# (patterns, heaps, prj)					= combineCase patterns f heaps prj
		= (CBasicPatterns type patterns, heaps, prj)

// ------------------------------------------------------------------------------------------------------------------------
instance combineCase (CExpr HeapPtr)
// ------------------------------------------------------------------------------------------------------------------------
where
	combineCase expr f heaps prj
		# expr										= f expr
		# (error, (ok, expr2), heaps, prj)			= moveInCase expr heaps prj
		| isError error								= (expr, heaps, prj)
		| not ok									= (expr, heaps, prj)
		= (expr2, heaps, prj)

// ------------------------------------------------------------------------------------------------------------------------
moveInCase :: !CExprH !*CHeaps !*CProject -> (!Error, !(!Bool, !CExprH), !*CHeaps, !*CProject)
// ------------------------------------------------------------------------------------------------------------------------
moveInCase (CCase expr patterns def @# exprs) heaps prj
	# (patterns, heaps, prj)						= combineCase patterns (\e -> e @# exprs) heaps prj
	# (def, heaps, prj)								= combineCase def (\e -> e @# exprs) heaps prj
	= (OK, (True, CCase expr patterns def), heaps, prj)
moveInCase (expr @# exprs) heaps prj
	# (found, e, ps, d, f)							= search_exprs [] exprs
	| found
		# (ps, heaps, prj)							= combineCase ps f heaps prj
		# (d, heaps, prj)							= combineCase d f heaps prj
		= (OK, (True, CCase e ps d), heaps, prj)
//	| not found
		= (OK, (False, DummyValue), heaps, prj)
	where
		search_exprs :: ![CExprH] ![CExprH] -> (!Bool, !CExprH, !CCasePatternsH, !Maybe CExprH, !(CExprH -> CExprH))
		search_exprs seen []
			= (False, DummyValue, DummyValue, DummyValue, DummyValue)
		search_exprs seen [CCase e ps d: not_seen]
			= (True, e, ps, d, \ee -> expr @# (seen ++ [ee] ++ not_seen))
		search_exprs seen [expr:not_seen]
			= search_exprs (seen ++ [expr]) not_seen
moveInCase old=:(ptr @@# exprs) heaps prj
	# (found, e, ps, d, f)							= search_exprs [] exprs
	| found
		# (ps, heaps, prj)							= combineCase ps f heaps prj
		# (d, heaps, prj)							= combineCase d f heaps prj
		= (OK, (True, CCase e ps d), heaps, prj)
//	| not found
		= (OK, (False, old), heaps, prj)
	where
		search_exprs :: ![CExprH] ![CExprH] -> (!Bool, !CExprH, !CCasePatternsH, !Maybe CExprH, !(CExprH -> CExprH))
		search_exprs seen []
			= (False, DummyValue, DummyValue, DummyValue, DummyValue)
		search_exprs seen [CCase e ps d: not_seen]
			= (True, e, ps, d, \ee -> ptr @@# (seen ++ [ee] ++ not_seen))
		search_exprs seen [expr:not_seen]
			= search_exprs (seen ++ [expr]) not_seen
moveInCase other heaps prj
	= (OK, (False, other), heaps, prj)

// ------------------------------------------------------------------------------------------------------------------------
MoveInCase :: !CName !Int !Goal !*CHeaps !*CProject -> (!Error, ![Goal], ![TheoremPtr], ![HeapPtr], !*CHeaps, !*CProject)
// ------------------------------------------------------------------------------------------------------------------------
MoveInCase name index goal heaps prj
	# loc											= SelectedSubExpr name index Nothing
	# (error, (changed, prop), heaps, prj)			= actOnExprLocation loc goal.glToProve moveInCase heaps prj
	| isError error									= (error, DummyValue, DummyValue, DummyValue, heaps, prj)
	| not changed									= ([X_ApplyTactic "MoveInCase" "No case found."], DummyValue, DummyValue, DummyValue, heaps, prj)
	# goal											= {goal & glToProve = prop}
	= (OK, [goal], [], [], heaps, prj)

// ------------------------------------------------------------------------------------------------------------------------
MoveInCaseH :: !CName !Int !HypothesisPtr !TacticMode !Goal !*CHeaps !*CProject -> (!Error, ![Goal], ![TheoremPtr], ![HeapPtr], !*CHeaps, !*CProject)
// ------------------------------------------------------------------------------------------------------------------------
MoveInCaseH name index ptr mode goal heaps prj
	# loc											= SelectedSubExpr name index Nothing
	# (hyp, heaps)									= readPointer ptr heaps
	# (error, (changed, prop), heaps, prj)			= actOnExprLocation loc hyp.hypProp moveInCase heaps prj
	| isError error									= (error, DummyValue, DummyValue, DummyValue, heaps, prj)
	| not changed									= ([X_ApplyTactic "MoveInCase" "No redex found in hypothesis given."], DummyValue, DummyValue, DummyValue, heaps, prj)
	| mode == Implicit
		# (hypotheses, heaps, prj)					= overwriteHypothesis goal.glHypotheses ptr prop heaps prj
		# goal										= {goal & glHypotheses = hypotheses}
		= (OK, [goal], [], [], heaps, prj)
	| mode == Explicit
		# goal										= {goal & glToProve = CImplies prop goal.glToProve, glNrIHs = 0}
		= (OK, [goal], [], [], heaps, prj)
	= undef

// ------------------------------------------------------------------------------------------------------------------------
moveQuantors :: !MoveDirection !CPropH !*CHeaps -> (!(!Bool, !CPropH), !*CHeaps)
// ------------------------------------------------------------------------------------------------------------------------
moveQuantors dir p heaps
	| dir == MoveIn
		# (vars, p)									= get_top_vars p
		| isEmpty vars								= ((False, DummyValue), heaps)
		= drop_vars vars p heaps
//	| dir == MoveOut
		# (vars, p)									= get_inner_vars False p
		| isEmpty vars								= ((False, DummyValue), heaps)
		= ((True, intro_vars vars p), heaps)
	where
		get_inner_vars :: !Bool !CPropH -> (![Either CExprVarPtr CPropVarPtr], !CPropH)
		get_inner_vars _ (CImplies p q)
			# (vars, q)								= get_inner_vars True q
			= (vars, CImplies p q)
		get_inner_vars False other
			= ([], DummyValue)
		get_inner_vars True p=:(CExprForall _ _)
			= get_top_vars p
		get_inner_vars True p=:(CPropForall _ _)
			= get_top_vars p
		get_inner_vars True other
			= ([], DummyValue)
		
		get_top_vars :: !CPropH -> (![Either CExprVarPtr CPropVarPtr], !CPropH)
		get_top_vars (CExprForall var p)
			# (vars, p)								= get_top_vars p
			= ([ELeft var: vars], p)
		get_top_vars (CPropForall var p)
			# (vars, p)								= get_top_vars p
			= ([ERight var: vars], p)
		get_top_vars p
			= ([], p)
		
		drop_vars :: ![Either CExprVarPtr CPropVarPtr] !CPropH !*CHeaps -> (!(!Bool, !CPropH), !*CHeaps)
		drop_vars vars (CImplies p q) heaps
			# (info, heaps)							= GetPtrInfo p heaps
			| not (check_info vars info)			= ((False, intro_vars vars (CImplies p q)), heaps)
			# ((_, q), heaps)						= drop_vars vars q heaps
			= ((True, CImplies p q), heaps)
		drop_vars vars other heaps
			= ((False, intro_vars vars other), heaps)
		
		intro_vars :: ![Either CExprVarPtr CPropVarPtr] !CPropH -> CPropH
		intro_vars [ELeft var: vars] p
			= CExprForall var (intro_vars vars p)
		intro_vars [ERight var: vars] p
			= CPropForall var (intro_vars vars p)
		intro_vars [] p
			= p
		
		check_info :: ![Either CExprVarPtr CPropVarPtr] !PtrInfo -> Bool
		check_info [ELeft var: vars] info
			| isMember var info.freeExprVars		= False
			= check_info vars info
		check_info [ERight var: vars] info
			| isMember var info.freePropVars		= False
			= check_info vars info
		check_info [] _
			= True

// ------------------------------------------------------------------------------------------------------------------------
MoveQuantors :: !MoveDirection !Goal !*CHeaps !*CProject -> (!Error, ![Goal], ![TheoremPtr], ![HeapPtr], !*CHeaps, !*CProject)
// ------------------------------------------------------------------------------------------------------------------------
MoveQuantors dir goal heaps prj
	# ((changed, p), heaps)							= moveQuantors dir goal.glToProve heaps
	| not changed									= (pushError (X_ApplyTactic "MoveQuantors" "No quantors could be moved in the current goal") OK, DummyValue, DummyValue, DummyValue, heaps, prj)
	# goal											= {goal & glToProve = p}
	= (OK, [goal], [], [], heaps, prj)

// ------------------------------------------------------------------------------------------------------------------------
MoveQuantorsH :: !MoveDirection !HypothesisPtr !TacticMode !Goal !*CHeaps !*CProject -> (!Error, ![Goal], ![TheoremPtr], ![HeapPtr], !*CHeaps, !*CProject)
// ------------------------------------------------------------------------------------------------------------------------
MoveQuantorsH dir ptr mode goal heaps prj
	# (hyp, heaps)									= readPointer ptr heaps
	# ((changed, p), heaps)							= moveQuantors dir hyp.hypProp heaps
	| not changed									= (pushError (X_ApplyTactic "MoveQuantors" ("No foralls could be moved in hypothesis '" +++ hyp.hypName +++ "'.")) OK, DummyValue, DummyValue, DummyValue, heaps, prj)
	| mode == Implicit
		# (hypotheses, heaps, prj)					= overwriteHypothesis goal.glHypotheses ptr p heaps prj
		# goal										= {goal & glHypotheses = hypotheses}
		= (OK, [goal], [], [], heaps, prj)
//	| mode == Explicit
		# (p, heaps)								= FreshVars p heaps
		# goal										= {goal & glToProve = CImplies p goal.glToProve, glNrIHs = 0}
		= (OK, [goal], [], [], heaps, prj)

// ------------------------------------------------------------------------------------------------------------------------
Opaque :: !HeapPtr !Goal !*CHeaps !*CProject -> (!Error, ![Goal], ![TheoremPtr], ![HeapPtr], !*CHeaps, !*CProject)
// ------------------------------------------------------------------------------------------------------------------------
Opaque ptr goal heaps prj
	# (ok, opaque)									= add goal.glOpaque ptr
	| not ok										= ([X_ApplyTactic "Opaque" "Function already opaque."], DummyValue, DummyValue, DummyValue, heaps, prj)
	# goal											= {goal & glOpaque = opaque}
	= (OK, [goal], [], [ptr], heaps, prj)
	where
		add :: ![HeapPtr] !HeapPtr -> (!Bool, ![HeapPtr])
		add [ptr:ptrs] this
			| ptr == this							= (False, [])
			# (ok, ptrs)							= add ptrs this
			= (ok, [ptr: ptrs])
		add [] this
			= (True, [this])

// ReduceMax :== 55555
ReduceMax :== 500
// ------------------------------------------------------------------------------------------------------------------------
reduce :: !ReduceAmount !ReductionOptions !CExprH !*CHeaps !*CProject -> (!Error, !(!Bool, !CExprH), !*CHeaps, !*CProject)
// ------------------------------------------------------------------------------------------------------------------------
reduce (ReduceExactly n) options expr heaps prj
	# (defined, heaps, prj)						= convertC2L options.roDefinedExpressions heaps prj
	# (expr, heaps, prj)						= convertC2L expr heaps prj
	// hack for debugging purposes
	# to_nf										= if (n == 12345) LToNF LToRNF
	// end hack
	# ((out_n, expr), heaps, prj)				= LReduce defined options.roMode to_nf n expr heaps prj
	# (expr, heaps, prj)						= convertL2C expr heaps prj
	= (OK, (out_n < n, expr), heaps, prj)
reduce ReduceToRNF options expr heaps prj
	# (defined, heaps, prj)						= convertC2L options.roDefinedExpressions heaps prj
	# (expr, heaps, prj)						= convertC2L expr heaps prj
	# ((out_n, expr), heaps, prj)				= LReduce defined options.roMode LToRNF ReduceMax expr heaps prj
	# (expr, heaps, prj)						= convertL2C expr heaps prj
	= (OK, (out_n < ReduceMax, expr), heaps, prj)
reduce ReduceToNF options expr heaps prj
	# (defined, heaps, prj)						= convertC2L options.roDefinedExpressions heaps prj
	# (expr, heaps, prj)						= convertC2L expr heaps prj
	# ((out_n, expr), heaps, prj)				= LReduce defined options.roMode LToNF ReduceMax expr heaps prj
	# (expr, heaps, prj)						= convertL2C expr heaps prj
	= (OK, (out_n < ReduceMax, expr), heaps, prj)

// ------------------------------------------------------------------------------------------------------------------------
ReduceN :: !ReduceMode !ReduceAmount !ExprLocation ![CExprVarPtr] !Goal !*CHeaps !*CProject -> (!Error, ![Goal], ![TheoremPtr], ![HeapPtr], !*CHeaps, !*CProject)
// ------------------------------------------------------------------------------------------------------------------------
ReduceN rmode (ReduceExactly 0) loc defined_vars goal heaps prj
	= ([X_ApplyTactic "Reduce" "Reduction amount must be greater than zero."], DummyValue, DummyValue, DummyValue, heaps, prj)
ReduceN rmode amount loc defined_vars goal heaps prj
	# prj											= mark True goal.glOpaque prj
	# (_, definedness_info, heaps, prj)				= findDefinednessInfo goal heaps prj
	# options										= {roAmount = amount,  roMode = rmode, roDefinedVariables = defined_vars ++ definedness_info.definedVariables, roDefinedExpressions = definedness_info.definedExpressions}
	# (error, (changed, prop), heaps, prj)			= actOnExprLocation loc goal.glToProve (reduce amount options) heaps prj
	# prj											= mark False goal.glOpaque prj
	| isError error									= (error, DummyValue, DummyValue, DummyValue, heaps, prj)
	| not changed									= ([X_ApplyTactic "Reduce" "No redex found at given location in current goal."], DummyValue, DummyValue, DummyValue, heaps, prj)
	# goal											= {goal & glToProve = prop}
	# goals											= make_other_goals goal defined_vars
	= (OK, [goal:goals], [], [], heaps, prj)
	where
		mark :: !Bool ![HeapPtr] !*CProject -> *CProject
		mark on_off [ptr:ptrs] prj
			# (_, fundef, prj)						= getFunDef ptr prj
			# fundef								= {fundef & fdOpaque = on_off}
			# (_, prj)								= putFunDef ptr fundef prj
			= mark on_off ptrs prj
		mark _ [] prj
			= prj
		
		make_other_goals :: !Goal ![CExprVarPtr] -> [Goal]
		make_other_goals goal [ptr:ptrs]
			# goal									= {goal & glToProve = CNot (CEqual (CExprVar ptr) CBottom)}
			# goals									= make_other_goals goal ptrs
			= [goal:goals]
		make_other_goals goal []
			= []

// ------------------------------------------------------------------------------------------------------------------------
ReduceH :: !ReduceMode !ReduceAmount !ExprLocation !HypothesisPtr ![CExprVarPtr] !TacticMode !Goal !*CHeaps !*CProject -> (!Error, ![Goal], ![TheoremPtr], ![HeapPtr], !*CHeaps, !*CProject)
// ------------------------------------------------------------------------------------------------------------------------
ReduceH rmode (ReduceExactly 0) loc ptr defined_vars mode goal heaps prj
	= ([X_ApplyTactic "Reduce" "Reduction amount must be greater than zero."], DummyValue, DummyValue, DummyValue, heaps, prj)
ReduceH rmode amount loc ptr defined_vars mode goal heaps prj
	# (hyp, heaps)									= readPointer ptr heaps
	# prj											= mark True goal.glOpaque prj
	# (_, definedness_info, heaps, prj)				= findDefinednessInfo goal heaps prj
	# options										= {roAmount = amount, roMode = rmode, roDefinedVariables = defined_vars ++ definedness_info.definedVariables, roDefinedExpressions = definedness_info.definedExpressions}
	# (error, (changed, prop), heaps, prj)			= actOnExprLocation loc hyp.hypProp (reduce amount options)  heaps prj
	# prj											= mark False goal.glOpaque prj
	| isError error									= (error, DummyValue, DummyValue, DummyValue, heaps, prj)
	| not changed									= ([X_ApplyTactic "Reduce" "No redex found at given location in hypothesis."], DummyValue, DummyValue, DummyValue, heaps, prj)
	# goals											= make_other_goals goal defined_vars
	| mode == Implicit
		# (hypotheses, heaps, prj)					= overwriteHypothesis goal.glHypotheses ptr prop heaps prj
		# goal										= {goal & glHypotheses = hypotheses}
		= (OK, [goal:goals], [], [], heaps, prj)
	| mode == Explicit
		# goal										= {goal & glToProve = CImplies prop goal.glToProve, glNrIHs = 0}
		= (OK, [goal:goals], [], [], heaps, prj)
	= undef
	where
		mark :: !Bool ![HeapPtr] !*CProject -> *CProject
		mark on_off [ptr:ptrs] prj
			# (_, fundef, prj)						= getFunDef ptr prj
			# fundef								= {fundef & fdOpaque = on_off}
			# (_, prj)								= putFunDef ptr fundef prj
			= mark on_off ptrs prj
		mark _ [] prj
			= prj
		
		make_other_goals :: !Goal ![CExprVarPtr] -> [Goal]
		make_other_goals goal [ptr:ptrs]
			# goal									= {goal & glToProve = CNot (CEqual (CExprVar ptr) CBottom)}
			# goals									= make_other_goals goal ptrs
			= [goal:goals]
		make_other_goals goal []
			= []

// ------------------------------------------------------------------------------------------------------------------------
refineUndefinedness :: !CPropH !*CProject -> (!Bool, !CPropH, !*CProject)
// ------------------------------------------------------------------------------------------------------------------------
refineUndefinedness (CPropVar ptr) prj
	= (False, CPropVar ptr, prj)
refineUndefinedness CTrue prj
	= (False, CTrue, prj)
refineUndefinedness CFalse prj
	= (False, CFalse, prj)
refineUndefinedness (CNot p) prj
	# (changed, p, prj)								= refineUndefinedness p prj
	= (changed, CNot p, prj)
refineUndefinedness (CAnd p q) prj
	# (changed1, p, prj)							= refineUndefinedness p prj
	# (changed2, q, prj)							= refineUndefinedness q prj
	= (changed1 || changed2, CAnd p q, prj)
refineUndefinedness (COr p q) prj
	# (changed1, p, prj)							= refineUndefinedness p prj
	# (changed2, q, prj)							= refineUndefinedness q prj
	= (changed1 || changed2, COr p q, prj)
refineUndefinedness (CImplies p q) prj
	# (changed1, p, prj)							= refineUndefinedness p prj
	# (changed2, q, prj)							= refineUndefinedness q prj
	= (changed1 || changed2, CImplies p q, prj)
refineUndefinedness (CIff p q) prj
	# (changed1, p, prj)							= refineUndefinedness p prj
	# (changed2, q, prj)							= refineUndefinedness q prj
	= (changed1 || changed2, CIff p q, prj)
refineUndefinedness (CExprForall ptr p) prj
	# (changed, p, prj)								= refineUndefinedness p prj
	= (changed, CExprForall ptr p, prj)
refineUndefinedness (CExprExists ptr p) prj
	# (changed, p, prj)								= refineUndefinedness p prj
	= (changed, CExprExists ptr p, prj)
refineUndefinedness (CPropForall ptr p) prj
	# (changed, p, prj)								= refineUndefinedness p prj
	= (changed, CPropForall ptr p, prj)
refineUndefinedness (CPropExists ptr p) prj
	# (changed, p, prj)								= refineUndefinedness p prj
	= (changed, CPropExists ptr p, prj)
refineUndefinedness (CEqual (ptr @@# exprs) CBottom) prj
	| ptrKind ptr == CFun
		| isEmpty exprs								= (False, CEqual (ptr @@# exprs) CBottom, prj)
		# (error, fun, prj)							= getFunDef ptr prj
		| isError error								= (False, CEqual (ptr @@# exprs) CBottom, prj)
		| fun.fdArity <> length exprs				= (False, CEqual (ptr @@# exprs) CBottom, prj)
		# (known, defining_selector)				= getDefiningArgs fun.fdDefinedness
		| not known									= (False, CEqual (ptr @@# exprs) CBottom, prj)
		# exprs										= selectDefining defining_selector exprs
		= (True, create exprs, prj)
	| ptrKind ptr == CDataCons
		| isEmpty exprs								= (False, CEqual (ptr @@# exprs) CBottom, prj)
		# (error, cons, prj)						= getDataConsDef ptr prj
		| isError error								= (False, CEqual (ptr @@# exprs) CBottom, prj)
		| cons.dcdArity <> length exprs				= (False, CEqual (ptr @@# exprs) CBottom, prj)
		# exprs										= selectStrict cons.dcdSymbolType.sytArguments exprs
		= (True, create exprs, prj)
	= (False, CEqual (ptr @@# exprs) CBottom, prj)
	where
		selectDefining :: ![Bool] ![CExprH] -> [CExprH]
		selectDefining [True:bs] [e:es]				= [e: selectDefining bs es]
		selectDefining [False:bs] [e:es]			= selectDefining bs es
		selectDefining _ _							= []
	
		selectStrict :: ![CTypeH] ![CExprH] -> [CExprH]
		selectStrict [CStrict _:types] [expr:exprs]	= [expr: selectStrict types exprs]
		selectStrict [_:types] [_:exprs]			= selectStrict types exprs
		selectStrict _ _							= []
		
		create :: ![CExprH] -> CPropH
		create [expr]								= CEqual expr CBottom
		create [expr:exprs]							= COr (CEqual expr CBottom) (create exprs)
refineUndefinedness (CEqual CBottom (ptr @@# exprs)) prj
	| ptrKind ptr == CFun
		| isEmpty exprs								= (False, CEqual CBottom (ptr @@# exprs), prj)
		# (error, fun, prj)							= getFunDef ptr prj
		| isError error								= (False, CEqual CBottom (ptr @@# exprs), prj)
		| fun.fdArity <> length exprs				= (False, CEqual CBottom (ptr @@# exprs), prj)
		# (known, defining_selector)				= getDefiningArgs fun.fdDefinedness
		| not known									= (False, CEqual CBottom (ptr @@# exprs), prj)
		# exprs										= selectDefining defining_selector exprs
		= (True, create exprs, prj)
	| ptrKind ptr == CDataCons
		| isEmpty exprs								= (False, CEqual CBottom (ptr @@# exprs), prj)
		# (error, cons, prj)						= getDataConsDef ptr prj
		| isError error								= (False, CEqual CBottom (ptr @@# exprs), prj)
		| cons.dcdArity <> length exprs				= (False, CEqual CBottom (ptr @@# exprs), prj)
		# exprs										= selectStrict cons.dcdSymbolType.sytArguments exprs
		= (True, create exprs, prj)
	= (False, CEqual (ptr @@# exprs) CBottom, prj)
	where
		selectDefining :: ![Bool] ![CExprH] -> [CExprH]
		selectDefining [True:bs] [e:es]				= [e: selectDefining bs es]
		selectDefining [False:bs] [e:es]			= selectDefining bs es
		selectDefining _ _							= []
	
		selectStrict :: ![CTypeH] ![CExprH] -> [CExprH]
		selectStrict [CStrict _:types] [expr:exprs]	= [expr: selectStrict types exprs]
		selectStrict [_:types] [_:exprs]			= selectStrict types exprs
		selectStrict _ _							= []
		
		create :: ![CExprH] -> CPropH
		create [expr]								= CEqual CBottom expr
		create [expr:exprs]							= COr (CEqual CBottom expr) (create exprs)
refineUndefinedness (CEqual e1 e2) prj
	= (False, CEqual e1 e2, prj)

// ------------------------------------------------------------------------------------------------------------------------
RefineUndefinedness :: !Goal !*CHeaps !*CProject -> (!Error, ![Goal], ![TheoremPtr], ![HeapPtr], !*CHeaps, !*CProject)
// ------------------------------------------------------------------------------------------------------------------------
RefineUndefinedness goal heaps prj
	# (changed, to_prove, prj)						= refineUndefinedness goal.glToProve prj
	| not changed									= (pushError (X_ApplyTactic "RefineUndefinedness" "The current goal could not be refined by using equalities of the form E=_|_") OK, DummyValue, DummyValue, DummyValue, heaps, prj)
	# goal											= {goal & glToProve = to_prove}
	= (OK, [goal], [], [], heaps, prj)

// ------------------------------------------------------------------------------------------------------------------------
RefineUndefinednessH :: !HypothesisPtr !TacticMode !Goal !*CHeaps !*CProject -> (!Error, ![Goal], ![TheoremPtr], ![HeapPtr], !*CHeaps, !*CProject)
// ------------------------------------------------------------------------------------------------------------------------
RefineUndefinednessH ptr mode goal heaps prj
	# (hyp, heaps)									= readPointer ptr heaps
	# (changed, hyp_prop, prj)						= refineUndefinedness hyp.hypProp prj
	| not changed									= (pushError (X_ApplyTactic "RefineUndefinedness" ("Hypothesis " +++ hyp.hypName +++ " could not be refined by using equalities of the form E=_|_")) OK, DummyValue, DummyValue, DummyValue, heaps, prj)
	| mode == Implicit
		# (hypotheses, heaps, prj)					= overwriteHypothesis goal.glHypotheses ptr hyp_prop heaps prj
		# goal										= {goal & glHypotheses = hypotheses}
		= (OK, [goal], [], [], heaps, prj)
//	| mode == Explicit
		# (hyp_prop, heaps)							= FreshVars hyp_prop heaps
		# goal										= {goal & glToProve = CImplies hyp_prop goal.glToProve, glNrIHs = 0}
		= (OK, [goal], [], [], heaps, prj)

// ------------------------------------------------------------------------------------------------------------------------
Reflexive :: !Goal !*CHeaps !*CProject -> (!Error, ![Goal], ![TheoremPtr], ![HeapPtr], !*CHeaps, !*CProject)
// ------------------------------------------------------------------------------------------------------------------------
Reflexive goal heaps prj
	# (ok, heaps)									= check goal.glToProve heaps
	| not ok										= (pushError (X_ApplyTactic "Reflexive" "Current goal is not a reflexive equality.") OK, DummyValue, DummyValue, DummyValue, heaps, prj)
	= (OK, [], [], [], heaps, prj)
	where
		check :: !CPropH !*CHeaps -> (!Bool, !*CHeaps)
		check (CExprForall var p) heaps
			= check p heaps
		check (CExprExists var p) heaps
			= check p heaps
		check (CPropForall var p) heaps
			= check p heaps
		check (CPropExists var p) heaps
			= check p heaps
		check (CImplies p q) heaps
			= check q heaps
		check (CEqual e1 e2) heaps
			= AlphaEqual e1 e2 heaps
		check (CIff p q) heaps
			= AlphaEqual p q heaps
		check prop heaps
			= (False, heaps)

// ------------------------------------------------------------------------------------------------------------------------
c_hange :: ![Ptr a] !(Ptr a) !(Ptr a) -> [Ptr a]
// ------------------------------------------------------------------------------------------------------------------------
c_hange [ptr:ptrs] src dst
	| ptr == src									= [dst: ptrs]
	= [ptr: c_hange ptrs src dst]
c_hange [] src dst
	= []

// ------------------------------------------------------------------------------------------------------------------------
removeCase :: !CExprH !*CHeaps !*CProject -> (!Error, !(!Bool, !CExprH), !*CHeaps, !*CProject)
// ------------------------------------------------------------------------------------------------------------------------
removeCase old=:(CCase expr patterns def) heaps prj
	# exprs											= get_rhs patterns
	# exprs											= case def of
														(Just expr)		-> [expr:exprs]
														Nothing			-> exprs
	| isEmpty exprs									= ([X_Internal "Empty case!"], DummyValue, heaps, prj)
	# expr											= hd exprs
	# exprs											= tl exprs
	# check											= and (map ((==) expr) exprs)
	| not check										= (OK, (False, old), heaps, prj)
	= (OK, (True, expr), heaps, prj)
	where
		get_rhs :: !CCasePatternsH -> [CExprH]
		get_rhs (CAlgPatterns _ patterns)
			= [pattern.atpResult \\ pattern <- patterns]
		get_rhs (CBasicPatterns _ patterns)
			= [pattern.bapResult \\ pattern <- patterns]
removeCase other heaps prj
	# error											= [X_ApplyTactic "RemoveCase" "No such case."]
	= (error, DummyValue, heaps, prj)

// ------------------------------------------------------------------------------------------------------------------------
RemoveCase :: !Int !Goal !*CHeaps !*CProject -> (!Error, ![Goal], ![TheoremPtr], ![HeapPtr], !*CHeaps, !*CProject)
// ------------------------------------------------------------------------------------------------------------------------
RemoveCase index goal heaps prj
	# location										= SelectedSubExpr "case" index Nothing
	# (error, (changed, prop), heaps, prj)			= actOnExprLocation location goal.glToProve removeCase heaps prj
	| isError error									= (error, DummyValue, DummyValue, DummyValue, heaps, prj)
	| not changed									= ([X_ApplyTactic "RemoveCase" "Case could not be simplified."], DummyValue, DummyValue, DummyValue, heaps, prj)
	# goal											= {goal & glToProve = prop}
	= (OK, [goal], [], [], heaps, prj)

// ------------------------------------------------------------------------------------------------------------------------
RemoveCaseH :: !Int !HypothesisPtr !TacticMode !Goal !*CHeaps !*CProject -> (!Error, ![Goal], ![TheoremPtr], ![HeapPtr], !*CHeaps, !*CProject)
// ------------------------------------------------------------------------------------------------------------------------
RemoveCaseH index ptr mode goal heaps prj
	# (hyp, heaps)									= readPointer ptr heaps
	# location										= SelectedSubExpr "case" index Nothing
	# (error, (changed, prop), heaps, prj)			= actOnExprLocation location hyp.hypProp removeCase heaps prj
	| isError error									= (error, DummyValue, DummyValue, DummyValue, heaps, prj)
	| not changed									= ([X_ApplyTactic "RemoveCase" "Case could not be simplified."], DummyValue, DummyValue, DummyValue, heaps, prj)
	| mode == Implicit
		# (hypotheses, heaps, prj)					= overwriteHypothesis goal.glHypotheses ptr prop heaps prj
		# goal										= {goal & glHypotheses = hypotheses}
		= (OK, [goal], [], [], heaps, prj)
//	| mode == Explicit
		# (prop, heaps)								= FreshVars prop heaps
		# goal										= {goal & glToProve = CImplies prop goal.glToProve, glNrIHs = 0}
		= (OK, [goal], [], [], heaps, prj)

// ------------------------------------------------------------------------------------------------------------------------
RenameE :: !CExprVarPtr !CName !Goal !*CHeaps !*CProject -> (!Error, ![Goal], ![TheoremPtr], ![HeapPtr], !*CHeaps, !*CProject)
// ------------------------------------------------------------------------------------------------------------------------
RenameE oldptr name goal heaps prj
	# (oldvar, heaps)								= readPointer oldptr heaps
	# newvar										= {oldvar & evarName = name}
	# (newptr, heaps)								= newPointer newvar heaps
	# sub											= {DummyValue & subExprVars = [(oldptr, CExprVar newptr)]}
	# (goal, heaps)									= SafeSubst sub goal heaps
	# goal											= {goal & glExprVars = c_hange goal.glExprVars oldptr newptr}
	= (OK, [goal], [], [], heaps, prj)

// ------------------------------------------------------------------------------------------------------------------------
RenameP :: !CPropVarPtr !CName !Goal !*CHeaps !*CProject -> (!Error, ![Goal], ![TheoremPtr], ![HeapPtr], !*CHeaps, !*CProject)
// ------------------------------------------------------------------------------------------------------------------------
RenameP oldptr name goal heaps prj
	# (oldvar, heaps)								= readPointer oldptr heaps
	# newvar										= {oldvar & pvarName = name}
	# (newptr, heaps)								= newPointer newvar heaps
	# sub											= {DummyValue & subPropVars = [(oldptr, CPropVar newptr)]}
	# (goal, heaps)									= SafeSubst sub goal heaps
	# goal											= {goal & glPropVars = c_hange goal.glPropVars oldptr newptr}
	= (OK, [goal], [], [], heaps, prj)

// ------------------------------------------------------------------------------------------------------------------------
RenameH :: !HypothesisPtr !CName !Goal !*CHeaps !*CProject -> (!Error, ![Goal], ![TheoremPtr], ![HeapPtr], !*CHeaps, !*CProject)
// ------------------------------------------------------------------------------------------------------------------------
RenameH oldptr name goal heaps prj
	# (oldhyp, heaps)								= readPointer oldptr heaps
	# newhyp										= {oldhyp & hypName = name}
	# (newptr, heaps)								= newPointer newhyp heaps
	# goal											= {goal & glHypotheses = c_hange goal.glHypotheses oldptr newptr}
	= (OK, [goal], [], [], heaps, prj)

// ========================================================================================================================
// Output: @2 - Bool     - True: expression-rule; False: proposition-rule
//         @3 - [CPropH] - conditional rewriting! 
// ------------------------------------------------------------------------------------------------------------------------
rewrite :: !RewriteDirection !Redex !CPropH !CPropH !*CHeaps -> (!Error, !Bool, ![CPropH], !CPropH, !*CHeaps)
// ------------------------------------------------------------------------------------------------------------------------
rewrite direction redex rule target heaps
//	# (evars, pvars, rule)							= strip_vars rule
//	# (conditions, rule)							= strip_conditions rule
	# (evars, pvars, conditions, rule)				= strip_vars_and_conditions rule
	# (ok, lhs, rhs)								= make_expr_rule direction rule
	| ok
		# (changed, subs, target, heaps)			= RewriteExpr target redex evars pvars lhs rhs heaps
		| not changed								= (pushError (X_ApplyTactic "Rewrite" "Given rewrite-rule is not applicable in current goal.") OK, DummyValue, DummyValue, DummyValue, heaps)
		# (conditions, heaps)						= build_conditions conditions subs heaps
		= (OK, True, conditions, target, heaps)
	# (ok, lhs, rhs)								= make_prop_rule direction rule
	| ok
		# (changed, subs, target, heaps)			= RewriteProp target redex evars pvars lhs rhs heaps
		| not changed								= (pushError (X_ApplyTactic "Rewrite" "Given rewrite-rule is not applicable in current goal.") OK, DummyValue, DummyValue, DummyValue, heaps)
		# (conditions, heaps)						= build_conditions conditions subs heaps
		= (OK, False, conditions, target, heaps)
	= (pushError (X_ApplyTactic "Rewrite" "Given fact is not a proper equality.") OK, DummyValue, DummyValue, DummyValue, heaps)
	where
//		strip_vars :: !CPropH -> (![CExprVarPtr], ![CPropVarPtr], !CPropH)
//		strip_vars (CExprForall evar p)
//			# (evars, pvars, p)						= strip_vars p
//			= ([evar:evars], pvars, p)
//		strip_vars (CPropForall pvar p)
//			# (evars, pvars, p)						= strip_vars p
//			= (evars, [pvar:pvars], p)
//		strip_vars other
//			= ([], [], other)
//		
//		strip_conditions :: !CPropH -> (![CPropH], !CPropH)
//		strip_conditions (CImplies p q)
//			# (ps, rhs)								= strip_conditions q
//			= ([p:ps], rhs)
//		strip_conditions other
//			= ([], other)
		
		strip_vars_and_conditions :: !CPropH -> (![CExprVarPtr], ![CPropVarPtr], ![CPropH], !CPropH)
		strip_vars_and_conditions (CImplies p q)
			# (evars, pvars, ps, rhs)				= strip_vars_and_conditions q
			= (evars, pvars, [p:ps], rhs)
		strip_vars_and_conditions (CExprForall evar p)
			# (evars, pvars, ps, rhs)				= strip_vars_and_conditions p
			= ([evar:evars], pvars, ps, rhs)
		strip_vars_and_conditions (CPropForall pvar p)
			# (evars, pvars, ps, rhs)				= strip_vars_and_conditions p
			= (evars, [pvar:pvars], ps, rhs)
		strip_vars_and_conditions other
			= ([], [], [], other)
		
		make_expr_rule :: !RewriteDirection !CPropH -> (!Bool, !CExprH, !CExprH)
		make_expr_rule LeftToRight (CEqual e1 e2)	= (True, e1, e2)
		make_expr_rule RightToLeft (CEqual e1 e2)	= (True, e2, e1)
		make_expr_rule _ _							= (False, DummyValue, DummyValue)
		
		make_prop_rule :: !RewriteDirection !CPropH -> (!Bool, !CPropH, !CPropH)
		make_prop_rule LeftToRight (CIff p1 p2)		= (True, p1, p2)
		make_prop_rule RightToLeft (CIff p1 p2)		= (True, p2, p1)
		make_prop_rule _ _							= (False, DummyValue, DummyValue)
		
		build_conditions :: ![CPropH] ![Substitution] !*CHeaps -> (![CPropH], !*CHeaps)
		build_conditions [p:ps] subs heaps
			# (conds1, heaps)						= build p subs heaps
			# (conds2, heaps)						= build_conditions ps subs heaps
			= (removeDup (conds1 ++ conds2), heaps)
			where
				build p [sub:subs] heaps
					# (cond, heaps)					= SafeSubst sub p heaps
					# (conds, heaps)				= build p subs heaps
					= ([cond:conds], heaps)
				build p [] heaps
					= ([], heaps)
		build_conditions [] subs heaps
			= ([], heaps)

// ------------------------------------------------------------------------------------------------------------------------
RewriteN :: !RewriteDirection !Redex !UseFact !Goal !*CHeaps !*CProject -> (!Error, ![Goal], ![TheoremPtr], ![HeapPtr], !*CHeaps, !*CProject)
// ------------------------------------------------------------------------------------------------------------------------
RewriteN direction redex fact goal heaps prj
	# (error, rule, used_theorems, used_symbols, heaps)
													= getFact fact heaps
	| isError error									= (error, DummyValue, DummyValue, DummyValue, heaps, prj)
	# (error, expr_rule, conditions, prop, heaps)	= rewrite direction redex rule goal.glToProve heaps
	| isError error									= (error, DummyValue, DummyValue, DummyValue, heaps, prj)
	# goal											= add_history direction fact goal
	# cond_goals									= [{goal & glToProve = cond, glNrIHs = 0} \\ cond <- conditions]
	# goal											= {goal & glToProve = prop, glNrIHs = if expr_rule goal.glNrIHs 0}
	// type check
	# test_goal										= {goal & glToProve = foldr (CAnd) goal.glToProve conditions}
	# (error, _, _, heaps, prj)						= wellTyped test_goal heaps prj
	| isError error									= ([X_ApplyTactic "Rewrite" "Type error: rewrite-rule may not be applied this way"], DummyValue, DummyValue, DummyValue, heaps, prj)
	// check vars
	# (error, heaps)								= check_vars cond_goals heaps
	| isError error									= (error, DummyValue, DummyValue, DummyValue, heaps, prj)
	= (OK, [goal:cond_goals], used_theorems, used_symbols, heaps, prj)
	where
		check_vars :: ![Goal] !*CHeaps -> (!Error, !*CHeaps)
		check_vars [] heaps
			= (OK, heaps)
		check_vars [goal:goals] heaps
			# (info, heaps)							= GetPtrInfo goal.glToProve heaps
			# free_e								= info.freeExprVars
			# bound_e								= goal.glExprVars
			| not (are_members free_e bound_e)		= ([X_ApplyTactic "Rewrite" "Reference to bound variable in one of the conditions."], heaps)
			# free_p								= info.freePropVars
			# bound_p								= goal.glPropVars
			| not (are_members free_p bound_p)		= ([X_ApplyTactic "Rewrite" "Reference to bound variable in one of the conditions."], heaps)
			= check_vars goals heaps
		
		are_members [ptr:ptrs] all
			| isMember ptr all						= are_members ptrs all
			= False
		are_members [] all
			= True
		
		add_history :: !RewriteDirection !UseFact !Goal -> Goal
		add_history LeftToRight (HypothesisFact ptr []) goal
			= {goal & glRewrittenLR = removeDup [ptr:goal.glRewrittenLR]}
		add_history RightToLeft (HypothesisFact ptr []) goal
			= {goal & glRewrittenRL = removeDup [ptr:goal.glRewrittenRL]}
		add_history _ _ goal
			= goal

// ------------------------------------------------------------------------------------------------------------------------
RewriteH :: !RewriteDirection !Redex !UseFact !HypothesisPtr !TacticMode !Goal !*CHeaps !*CProject -> (!Error, ![Goal], ![TheoremPtr], ![HeapPtr], !*CHeaps, !*CProject)
// ------------------------------------------------------------------------------------------------------------------------
RewriteH direction redex fact ptr mode goal heaps prj
	# (error, rule, used_theorems, used_symbols, heaps)
													= getFact fact heaps
	| isError error									= (error, DummyValue, DummyValue, DummyValue, heaps, prj)
	# (hyp, heaps)									= readPointer ptr heaps
	# (error, _, conditions, prop, heaps)			= rewrite direction redex rule hyp.hypProp heaps
	| isError error									= (error, DummyValue, DummyValue, DummyValue, heaps, prj)
	# cond_goals									= [{goal & glToProve = cond, glNrIHs = 0} \\ cond <- conditions]
	| mode == Implicit
		# (hypotheses, heaps, prj)					= overwriteHypothesis goal.glHypotheses ptr prop heaps prj
		# goal										= {goal & glHypotheses = hypotheses}
		// type check
		# test_goal									= {goal & glToProve = foldr (CAnd) goal.glToProve conditions}
		# (error, _, _, heaps, prj)					= wellTyped test_goal heaps prj
		| isError error								= ([X_ApplyTactic "Rewrite" "Type error: rewrite-rule may not be applied this way"], DummyValue, DummyValue, DummyValue, heaps, prj)
		// check vars
		# (error, heaps)							= check_vars cond_goals heaps
		| isError error								= (error, DummyValue, DummyValue, DummyValue, heaps, prj)
		= (OK, [goal:cond_goals], used_theorems, used_symbols, heaps, prj)
	| mode == Explicit
		# goal										= {goal & glToProve = CImplies prop goal.glToProve, glNrIHs = 0}
		// type check
		# test_goal									= {goal & glToProve = foldr (CAnd) goal.glToProve conditions}
		# (error, _, _, heaps, prj)					= wellTyped test_goal heaps prj
		| isError error								= ([X_ApplyTactic "Rewrite" "Type error: rewrite-rule may not be applied this way"], DummyValue, DummyValue, DummyValue, heaps, prj)
		// check vars
		# (error, heaps)							= check_vars cond_goals heaps
		| isError error								= (error, DummyValue, DummyValue, DummyValue, heaps, prj)
		= (OK, [goal:cond_goals], used_theorems, used_symbols, heaps, prj)
	= undef
	where
		check_vars :: ![Goal] !*CHeaps -> (!Error, !*CHeaps)
		check_vars [] heaps
			= (OK, heaps)
		check_vars [goal:goals] heaps
			# (info, heaps)							= GetPtrInfo goal.glToProve heaps
			# free_e								= info.freeExprVars
			# bound_e								= goal.glExprVars
			| not (are_members free_e bound_e)		= ([X_ApplyTactic "Rewrite" "Reference to bound variable in one of the conditions."], heaps)
			# free_p								= info.freePropVars
			# bound_p								= goal.glPropVars
			| not (are_members free_p bound_p)		= ([X_ApplyTactic "Rewrite" "Reference to bound variable in one of the conditions."], heaps)
			= check_vars goals heaps
		
		are_members [ptr:ptrs] all
			| isMember ptr all						= are_members ptrs all
			= False
		are_members [] all
			= True

// ------------------------------------------------------------------------------------------------------------------------
SpecializeE :: !HypothesisPtr !CExprH !TacticMode !Goal !*CHeaps !*CProject -> (!Error, ![Goal], ![TheoremPtr], ![HeapPtr], !*CHeaps, !*CProject)
// ------------------------------------------------------------------------------------------------------------------------
SpecializeE ptr expr mode goal heaps prj
	# (hyp, heaps)									= readPointer ptr heaps
	# (ok, var, rest)								= disect hyp.hypProp
	| not ok										= (pushError (X_ApplyTactic "Specialize" "Hypothesis given does not start with proper FORALL.") OK, DummyValue, DummyValue, DummyValue, heaps, prj)
	# (new_prop, heaps)								= SafeSubst {DummyValue & subExprVars = [(var,expr)]} rest heaps
	# (used_symbols, heaps)							= GetUsedSymbols expr heaps
	| mode == Implicit
		# (hypotheses, heaps, prj)					= overwriteHypothesis goal.glHypotheses ptr new_prop heaps prj
		# goal										= {goal & glHypotheses = hypotheses}
		# (error, _, _, heaps, prj)					= wellTyped goal heaps prj
		| isError error								= (pushError (X_ApplyTactic "Specialize" "Expression given does not have the correct type.") error, DummyValue, DummyValue, DummyValue, heaps, prj)
		= (OK, [goal], [], used_symbols, heaps, prj)
	| mode == Explicit
		# goal										= {goal & glToProve = CImplies new_prop goal.glToProve, glNrIHs = 0}
		# (error, _, _, heaps, prj)					= wellTyped goal heaps prj
		| isError error								= (pushError (X_ApplyTactic "Specialize" "Expression given does not have the correct type.") error, DummyValue, DummyValue, DummyValue, heaps, prj)
		= (OK, [goal], [], used_symbols, heaps, prj)
	= undef
	where
		disect :: !CPropH -> (!Bool, !CExprVarPtr, !CPropH)
		disect (CExprForall var p)					= (True, var, p)
		disect other								= (False, nilPtr, DummyValue)

// ------------------------------------------------------------------------------------------------------------------------
SpecializeP :: !HypothesisPtr !CPropH !TacticMode !Goal !*CHeaps !*CProject -> (!Error, ![Goal], ![TheoremPtr], ![HeapPtr], !*CHeaps, !*CProject)
// ------------------------------------------------------------------------------------------------------------------------
SpecializeP ptr prop mode goal heaps prj
	# (hyp, heaps)									= readPointer ptr heaps
	# (ok, var, rest)								= disect hyp.hypProp
	| not ok										= (pushError (X_ApplyTactic "Specialize" "Hypothesis given does not start with proper FORALL.") OK, DummyValue, DummyValue, DummyValue, heaps, prj)
	# (new_prop, heaps)								= SafeSubst {DummyValue & subPropVars = [(var,prop)]} rest heaps
	# (used_symbols, heaps)							= GetUsedSymbols prop heaps
	| mode == Implicit
		# (hypotheses, heaps, prj)					= overwriteHypothesis goal.glHypotheses ptr new_prop heaps prj
		# goal										= {goal & glHypotheses = hypotheses}
		= (OK, [goal], [], used_symbols, heaps, prj)
	| mode == Explicit
		# goal										= {goal & glToProve = CImplies new_prop goal.glToProve, glNrIHs = 0}
		= (OK, [goal], [], used_symbols, heaps, prj)
	= undef
	where
		disect :: !CPropH -> (!Bool, !CPropVarPtr, !CPropH)
		disect (CPropForall var p)					= (True, var, p)
		disect other								= (False, nilPtr, DummyValue)

// ------------------------------------------------------------------------------------------------------------------------
split :: !Depth !CPropH -> [CPropH]
// ------------------------------------------------------------------------------------------------------------------------
split Deep (CAnd p q)
	= (split Deep p) ++ (split Deep q)
split Shallow (CAnd p q)
	= [p, q]
split _ other
	= [other]

// ------------------------------------------------------------------------------------------------------------------------
Split :: !Depth !Goal !*CHeaps !*CProject -> (!Error, ![Goal], ![TheoremPtr], ![HeapPtr], !*CHeaps, !*CProject)
// ------------------------------------------------------------------------------------------------------------------------
Split depth goal heaps prj
	# new											= split depth goal.glToProve
	| length new < 2								= (pushError (X_ApplyTactic "Split" "Current goal is not a conjunction.") OK, DummyValue, DummyValue, DummyValue, heaps, prj)
	# new_goals										= [{goal & glToProve = prop} \\ prop <- new]
	= (OK, new_goals, [], [], heaps, prj)

// ------------------------------------------------------------------------------------------------------------------------
SplitH :: !HypothesisPtr !Depth !TacticMode !Goal !*CHeaps !*CProject -> (!Error, ![Goal], ![TheoremPtr], ![HeapPtr], !*CHeaps, !*CProject)
// ------------------------------------------------------------------------------------------------------------------------
SplitH ptr depth mode goal heaps prj
	# (hyp, heaps)									= readPointer ptr heaps
	# (prop, heaps)									= FreshVars hyp.hypProp heaps
	# parts											= split depth prop
	| length parts < 2								= (pushError (X_ApplyTactic "Split" ("Hypothesis '" +++ hyp.hypName +++ "' is not a conjunction.")) OK, DummyValue, DummyValue, DummyValue, heaps, prj)
	| mode == Explicit
		# prop										= foldr CImplies goal.glToProve parts
		# goal										= {goal & glToProve = prop}
		= (OK, [goal], [], [], heaps, prj)
	| mode == Implicit
		# hypotheses								= removeMember ptr goal.glHypotheses
		# goal										= {goal & glHypotheses = hypotheses, glNewHypNum = new_num hyp.hypName goal.glNewHypNum}
		# (goal, heaps, prj)						= newHypotheses goal parts heaps prj
		= (OK, [goal], [], [], heaps, prj)
	= undef
	where
		new_num :: !String !Int -> Int
		new_num removed_name old_num
			= case removed_name == ("H" +++ toString (old_num-1)) of
				True	-> old_num - 1
				False	-> old_num

// ------------------------------------------------------------------------------------------------------------------------
SplitCase :: !Int !TacticMode !Goal !*CHeaps !*CProject -> (!Error, ![Goal], ![TheoremPtr], ![HeapPtr], !*CHeaps, !*CProject)
// ------------------------------------------------------------------------------------------------------------------------
SplitCase num mode goal heaps prj
	# (ok, expr, heaps, prj)				= getExprOnLocationInProp "case" num goal.glToProve heaps prj
	| not ok								= ([X_ApplyTactic "SplitCase" "No such case."], DummyValue, DummyValue, DummyValue, heaps, prj)
	# (ptr_info, heaps)						= GetPtrInfo expr heaps
	# checks								= map (\ptr -> isMember ptr goal.glExprVars) ptr_info.freeExprVars
	| not (and checks)						= ([X_ApplyTactic "SplitCase" "Not allowed on bound variables."], DummyValue, DummyValue, DummyValue, heaps, prj)
	# (case_expr, case_patterns, case_def)	= split_case expr
	# case_def								= case case_def of
												Just e		-> e
												_			-> CBottom
	// _|_
	# (bottom_goal, heaps, prj)				= exchange_case_in_goal CBottom heaps prj
	# (bottom_goal, heaps, prj)				= add_conditions mode bottom_goal [CEqual case_expr CBottom] heaps prj
	# (_, (_, prop), heaps, prj)			= recurse (updateBottomSplitCase case_expr) bottom_goal.glToProve heaps prj
	# bottom_goal							= {bottom_goal & glToProve = prop}
	// pattern goals
	# (error, pattern_goals, mb_other_conses, mb_other_bools, heaps, prj)
											= build_positive_goals case_expr case_patterns heaps prj
	| isError error							= (error, DummyValue, DummyValue, DummyValue, heaps, prj)
	// default goal (not reachable)
	| mb_other_conses == Just []			= (OK, [bottom_goal:pattern_goals], [], [], heaps, prj)
	| mb_other_bools == Just []				= (OK, [bottom_goal:pattern_goals], [], [], heaps, prj)
	// default goal (create)
	# (error, default_goal, heaps, prj)		= case mb_other_conses of
												Just conses	-> build_positive_alg_default_goal case_expr conses case_def heaps prj
												_			-> case mb_other_bools of
																Just bools	-> build_positive_bool_default_goal case_expr bools case_def heaps prj
																_			-> build_negative_basic_default_goal case_expr case_patterns case_def heaps prj
	| isError error							= (error, DummyValue, DummyValue, DummyValue, heaps, prj)
	# (_, (_, prop), heaps, prj)			= recurse (updateDefaultSplitCase case_expr case_patterns) default_goal.glToProve heaps prj
	# default_goal							= {default_goal & glToProve = prop}
	// concat
	# all_goals								= [bottom_goal:pattern_goals] ++ [default_goal]
	= (OK, all_goals, [], [], heaps, prj)
	where
		split_case :: !CExprH -> (!CExprH, !CCasePatternsH, !Maybe CExprH)
		split_case (CCase expr patterns def)
			= (expr, patterns, def)
		
		exchange_case_in_goal :: !CExprH !*CHeaps !*CProject -> (!Goal, !*CHeaps, !*CProject)
		exchange_case_in_goal expr heaps prj
			# location								= SelectedSubExpr "case" num Nothing
			# (_, (_, prop), heaps, prj)			= actOnExprLocation location goal.glToProve set heaps prj
			# goal									= {goal & glToProve = prop}
			= (goal, heaps, prj)
			where
				set _ heaps prj						= (OK, (True, expr), heaps, prj)
		
		add_conditions :: !TacticMode !Goal ![CPropH] !*CHeaps !*CProject -> (!Goal, !*CHeaps, !*CProject)
		add_conditions Implicit goal conds heaps prj
			= newHypotheses goal conds heaps prj
		add_conditions Explicit goal [cond:conds] heaps prj
			# (goal, heaps, prj)					= add_conditions Explicit goal conds heaps prj
			# goal									= {goal & glToProve = CImplies cond goal.glToProve, glNrIHs = 0}
			= (goal, heaps, prj)
		add_conditions Explicit goal [] heaps prj
			= (goal, heaps, prj)
			
		add_quantors :: !(CExprVarPtr -> CPropH -> CPropH) ![CExprVarPtr] !CPropH -> CPropH
		add_quantors quantor [ptr:ptrs] p			= quantor ptr (add_quantors quantor ptrs p)
		add_quantors quantor [] p					= p
		
		make_fresh_vars_and_subst :: ![CExprVarPtr] !*CHeaps -> (![CExprVarPtr], !*CHeaps)
		make_fresh_vars_and_subst [ptr:ptrs] heaps
			# (var, heaps)							= readPointer ptr heaps
			# (new_ptr, heaps)						= newPointer var heaps
			# var									= {var & evarInfo = EVar_Subst (CExprVar new_ptr)}
			# heaps									= writePointer ptr var heaps
			# (new_ptrs, heaps)						= make_fresh_vars_and_subst ptrs heaps
			= ([new_ptr:new_ptrs], heaps)
		make_fresh_vars_and_subst [] heaps
			= ([], heaps)
		
		// Output: if a Just is given, the unhandled cases are in it (otherwise: not possible to do so)
		build_positive_goals :: !CExprH !CCasePatternsH !*CHeaps !*CProject -> (!Error, ![Goal], !Maybe [HeapPtr], !Maybe [Bool], !*CHeaps, !*CProject)
		build_positive_goals case_expr (CAlgPatterns alg_ptr patterns) heaps prj
			# (error, atd, prj)						= getAlgTypeDef alg_ptr prj
			| isError error							= (error, DummyValue, DummyValue, DummyValue, heaps, prj)
			# all_conses							= atd.atdConstructors
			# (goals, conses, heaps, prj)			= build_alg_goals case_expr patterns all_conses heaps prj
			= (OK, goals, Just conses, Nothing, heaps, prj)
		build_positive_goals case_expr (CBasicPatterns type patterns) heaps prj
			# (goals, bools, heaps, prj)			= build_basic_goals case_expr patterns [True,False] heaps prj
			# mb_bools_left							= case type of
														CBoolean	-> Just bools
														_			-> Nothing
			= (OK, goals, Nothing, mb_bools_left, heaps, prj)
		
		build_alg_goals :: !CExprH ![CAlgPatternH] ![HeapPtr] !*CHeaps !*CProject -> (![Goal], ![HeapPtr], !*CHeaps, !*CProject)
		build_alg_goals case_expr [pattern:patterns] conses heaps prj
			# (fresh_ptrs, heaps)					= make_fresh_vars_and_subst pattern.atpExprVarScope heaps
			# pattern_expr							= pattern.atpDataCons @@# (map CExprVar fresh_ptrs)
			# (rhs, heaps)							= unsafeSubst pattern.atpResult heaps
			# heaps									= wipePointerInfos pattern.atpExprVarScope heaps
			# (goal, heaps, prj)					= exchange_case_in_goal rhs heaps prj
			# (goal, heaps, prj)					= add_conditions mode goal [CEqual case_expr pattern_expr] heaps prj
			# goal									= case mode of
														Implicit	-> {goal & glExprVars = goal.glExprVars ++ fresh_ptrs}
														Explicit	-> {goal & glToProve = add_quantors CExprForall goal.glExprVars goal.glToProve}
			# (_, (_, prop), heaps, prj)			= recurse (updatePositiveSplitCase case_expr pattern_expr) goal.glToProve heaps prj
			# goal									= {goal & glToProve = prop}
			# conses								= removeMember pattern.atpDataCons conses
			# (goals, conses, heaps, prj)			= build_alg_goals case_expr patterns conses heaps prj
			= ([goal:goals], conses, heaps, prj)
		build_alg_goals case_expr [] conses heaps prj
			= ([], conses, heaps, prj)
		
		build_basic_goals :: !CExprH ![CBasicPatternH] ![Bool] !*CHeaps !*CProject -> (![Goal], ![Bool], !*CHeaps, !*CProject)
		build_basic_goals case_expr [pattern:patterns] bools heaps prj
			# pattern_expr							= CBasicValue pattern.bapBasicValue
			# (goal, heaps, prj)					= exchange_case_in_goal pattern.bapResult heaps prj
			# (goal, heaps, prj)					= add_conditions mode goal [CEqual case_expr pattern_expr] heaps prj
			# (_, (_, prop), heaps, prj)			= recurse (updatePositiveSplitCase case_expr pattern_expr) goal.glToProve heaps prj
			# goal									= {goal & glToProve = prop}
			# bools									= case pattern.bapBasicValue of
														CBasicBoolean b		-> removeMember b bools
														_					-> bools
			# (goals, bools, heaps, prj)			= build_basic_goals case_expr patterns bools heaps prj
			= ([goal:goals], bools, heaps, prj)
		build_basic_goals case_expr [] bools heaps prj
			= ([], bools, heaps, prj)
		
		build_positive_alg_default_goal :: !CExprH ![HeapPtr] !CExprH !*CHeaps !*CProject -> (!Error, !Goal, !*CHeaps, !*CProject)
		build_positive_alg_default_goal case_expr conses pattern_result heaps prj
			# (error, condition, heaps, prj)		= build_condition CTrue conses heaps prj
			| isError error							= (error, DummyValue, heaps, prj)
			# (goal, heaps, prj)					= exchange_case_in_goal pattern_result heaps prj
			# (goal, heaps, prj)					= add_conditions mode goal [condition] heaps prj
			= (OK, goal, heaps, prj)
			where
				build_condition :: !CPropH ![HeapPtr] !*CHeaps !*CProject -> (!Error, !CPropH, !*CHeaps, !*CProject)
				build_condition condition [ptr:ptrs] heaps prj
					# (error, cons, prj)			= getDataConsDef ptr prj
					| isError error					= (error, DummyValue, heaps, prj)
					# fresh_vars					= [{DummyValue & evarName = "c" +++ toString num} \\ num <- [1..cons.dcdArity]]
					# (fresh_ptrs, heaps)			= newPointers fresh_vars heaps
					# equality						= CEqual case_expr (ptr @@# (map CExprVar fresh_ptrs))
					# ex_equality					= add_quantors CExprExists fresh_ptrs equality
					# condition						= case condition of
														CTrue	-> ex_equality
														_		-> COr condition ex_equality
					= build_condition condition ptrs heaps prj
				build_condition condition [] heaps prj
					= (OK, condition, heaps, prj)
		
		build_positive_bool_default_goal :: !CExprH ![Bool] !CExprH !*CHeaps !*CProject -> (!Error, !Goal, !*CHeaps, !*CProject)
		build_positive_bool_default_goal case_expr bools pattern_result heaps prj
			# condition								= build_condition CTrue bools
			# (goal, heaps, prj)					= exchange_case_in_goal pattern_result heaps prj
			# (goal, heaps, prj)					= add_conditions mode goal [condition] heaps prj
			= (OK, goal, heaps, prj)
			where
				build_condition :: !CPropH ![Bool] -> CPropH
				build_condition condition [bool:bools]
					# equality						= CEqual case_expr (CBasicValue (CBasicBoolean bool))
					# condition						= case condition of
														CTrue	-> equality
														_		-> COr condition equality
					= build_condition condition bools
				build_condition condition []
					= condition
		
		build_negative_basic_default_goal :: !CExprH !CCasePatternsH !CExprH !*CHeaps !*CProject -> (!Error, !Goal, !*CHeaps, !*CProject)
		build_negative_basic_default_goal case_expr (CBasicPatterns _ patterns) pattern_result heaps prj
			# conditions							= build_conditions patterns
			# conditions							= [CNot (CEqual case_expr CBottom): conditions]
			# (goal, heaps, prj)					= exchange_case_in_goal pattern_result heaps prj
			# (goal, heaps, prj)					= add_conditions mode goal conditions heaps prj
			= (OK, goal, heaps, prj)
			where
				build_conditions :: ![CBasicPatternH] -> [CPropH]
				build_conditions [pattern:patterns]
					= [CNot (CEqual case_expr (CBasicValue pattern.bapBasicValue)): build_conditions patterns]
				build_conditions []
					= [] 

// ========================================================================================================================
// Auxiliary function to be called in SplitCase.
// Scans propositions for other occurences and does the proper substitutions.
// ---------------------------------------------------------------------------------------------------------------------------
updateBottomSplitCase :: !CExprH !CExprH !*CHeaps !*CProject -> (!Error, !(!Bool, !CExprH), !*CHeaps, !*CProject)
// ---------------------------------------------------------------------------------------------------------------------------
updateBottomSplitCase case_expr old=:(CCase expr patterns def) heaps prj
	| case_expr == expr								= (OK, (True, CBottom), heaps, prj)
	= (OK, (False, old), heaps, prj)
updateBottomSplitCase case_expr other heaps prj
	= (OK, (False, other), heaps, prj)

// ========================================================================================================================
// Auxiliary function to be called in SplitCase.
// Also takes an expression of the form (Cons new1 new2 .... newn) [filled in pattern] as argument.
// Scans propositions for other occurences and does the proper substitutions.
// ---------------------------------------------------------------------------------------------------------------------------
updatePositiveSplitCase :: !CExprH !CExprH !CExprH !*CHeaps !*CProject -> (!Error, !(!Bool, !CExprH), !*CHeaps, !*CProject)
// ---------------------------------------------------------------------------------------------------------------------------
updatePositiveSplitCase case_expr pattern_equality old=:(CCase expr patterns def) heaps prj
	| expr <> case_expr								= (OK, (False, old), heaps, prj)
	= scan patterns heaps prj
	where
		scan :: !CCasePatternsH !*CHeaps !*CProject -> (!Error, !(!Bool, !CExprH), !*CHeaps, !*CProject)
		scan (CAlgPatterns type patterns) heaps prj
			# (ok, cons, args)						= disect_pattern pattern_equality
			| not ok								= (OK, (False, old), heaps, prj)
			= scan_alg patterns cons args heaps prj
			where
				disect_pattern :: !CExprH -> (!Bool, !HeapPtr, ![CExprH])
				disect_pattern (ptr @@# exprs)		= (True, ptr, exprs)
				disect_pattern _					= (False, DummyValue, [])
		scan (CBasicPatterns type patterns) heaps prj
			# (ok, value)							= disect_pattern pattern_equality
			| not ok								= (OK, (False, old), heaps, prj)
			= scan_basic patterns value heaps prj
			where
				disect_pattern :: !CExprH -> (!Bool, !CBasicValueH)
				disect_pattern (CBasicValue value)	= (True, value)
				disect_pattern _					= (False, DummyValue)
		
		scan_alg :: ![CAlgPatternH] !HeapPtr ![CExprH] !*CHeaps !*CProject -> (!Error, !(!Bool, !CExprH), !*CHeaps, !*CProject)
		scan_alg [pattern:patterns] cons args heaps prj
			| pattern.atpDataCons <> cons			= scan_alg patterns cons args heaps prj
			# sub									= {DummyValue & subExprVars = zip2 pattern.atpExprVarScope args}
			# (expr, heaps)							= UnsafeSubst sub pattern.atpResult heaps
			= (OK, (True, expr), heaps, prj)
		scan_alg [] _ _ heaps prj
			= (OK, (False, old), heaps, prj)
		
		scan_basic :: ![CBasicPatternH] !CBasicValueH !*CHeaps !*CProject -> (!Error, !(!Bool, !CExprH), !*CHeaps, !*CProject)
		scan_basic [pattern:patterns] value heaps prj
			| pattern.bapBasicValue <> value		= scan_basic patterns value heaps prj
			= (OK, (True, pattern.bapResult), heaps, prj)
		scan_basic [] _ heaps prj
			= (OK, (False, old), heaps, prj)
updatePositiveSplitCase case_expr pattern_equality other heaps prj
	= (OK, (False, other), heaps, prj)

// ========================================================================================================================
// Auxiliary function to be called in SplitCase.
// Also takes a list of case-patterns as argument.
// Scans propositions for other occurences of the same case and determines if the default should be used.
// ---------------------------------------------------------------------------------------------------------------------------
updateDefaultSplitCase :: !CExprH !CCasePatternsH !CExprH !*CHeaps !*CProject -> (!Error, !(!Bool, !CExprH), !*CHeaps, !*CProject)
// ---------------------------------------------------------------------------------------------------------------------------
updateDefaultSplitCase case_expr case_patterns old=:(CCase expr patterns def) heaps prj
	| expr <> case_expr								= (OK, (False, old), heaps, prj)
	# ok											= compare_patterns case_patterns patterns
	| not ok										= (OK, (False, old), heaps, prj)
	= case def of
		Just def	-> (OK, (True, def), heaps, prj)
		_			-> (OK, (True, CBottom), heaps, prj)
	where
		compare_patterns :: !CCasePatternsH !CCasePatternsH -> Bool
		compare_patterns (CAlgPatterns _ patterns1) (CAlgPatterns _ patterns2)
			= compare_alg_patterns patterns1 patterns2
		compare_patterns (CBasicPatterns _ patterns1) (CBasicPatterns _ patterns2)
			= compare_basic_patterns patterns1 patterns2
		compare_patterns _ _
			= False
		
		compare_alg_patterns :: ![CAlgPatternH] ![CAlgPatternH] -> Bool
		compare_alg_patterns [pattern1:patterns1] [pattern2:patterns2]
			| pattern1.atpDataCons <> pattern2.atpDataCons
													= False
			= compare_alg_patterns patterns1 patterns2
		compare_alg_patterns [] []
			= True
		compare_alg_patterns _ _
			= False
		
		compare_basic_patterns :: ![CBasicPatternH] ![CBasicPatternH] -> Bool
		compare_basic_patterns [pattern1:patterns1] [pattern2:patterns2]
			| pattern1.bapBasicValue <> pattern2.bapBasicValue
													= False
			= compare_basic_patterns patterns1 patterns2
		compare_basic_patterns [] []
			= True
		compare_basic_patterns _ _
			= False
updateDefaultSplitCase case_expr case_patterns other heaps prj
	= (OK, (False, other), heaps, prj)

// ------------------------------------------------------------------------------------------------------------------------
SplitIff :: !Goal !*CHeaps !*CProject -> (!Error, ![Goal], ![TheoremPtr], ![HeapPtr], !*CHeaps, !*CProject)
// ------------------------------------------------------------------------------------------------------------------------
SplitIff goal heaps prj
	# (ok, left, right)								= split goal.glToProve
	| not ok										= (pushError (X_ApplyTactic "SplitIff" "The current goal is not a <-> statement.") OK, DummyValue, DummyValue, DummyValue, heaps, prj)
	# goal1											= {goal & glToProve = left}
	# goal2											= {goal & glToProve = right}
	= (OK, [goal1,goal2], [], [], heaps, prj)
	where
		split :: !CPropH -> (!Bool, !CPropH, !CPropH)
		split (CIff p q)							= (True, CImplies p q, CImplies q p)
		split _										= (False, DummyValue, DummyValue)

// ------------------------------------------------------------------------------------------------------------------------
SplitIffH :: !HypothesisPtr !TacticMode !Goal !*CHeaps !*CProject -> (!Error, ![Goal], ![TheoremPtr], ![HeapPtr], !*CHeaps, !*CProject)
// ------------------------------------------------------------------------------------------------------------------------
SplitIffH ptr mode goal heaps prj
	# (hyp, heaps)									= readPointer ptr heaps
	# (prop, heaps)									= FreshVars hyp.hypProp heaps
	# (ok, left, right)								= split prop
	| not ok										= (pushError (X_ApplyTactic "SplitIff" ("Hypothesis '" +++ hyp.hypName +++ "' is not a <-> statement.")) OK, DummyValue, DummyValue, DummyValue, heaps, prj)
	| mode == Explicit
		# goal										= {goal & glToProve = CImplies left (CImplies right goal.glToProve)}
		= (OK, [goal], [], [], heaps, prj)
	| mode == Implicit
		# goal										= {goal & glHypotheses = removeMember ptr goal.glHypotheses}
		# (goal, heaps, prj)						= newHypotheses goal [left, right] heaps prj
		= (OK, [goal], [], [], heaps, prj)
	= undef
	where
		split :: !CPropH -> (!Bool, !CPropH, !CPropH)
		split (CIff p q)							= (True, CImplies p q, CImplies q p)
		split _										= (False, DummyValue, DummyValue)

// ------------------------------------------------------------------------------------------------------------------------
symmetric :: !CPropH -> (!Bool, !CPropH)
// ------------------------------------------------------------------------------------------------------------------------
symmetric (CExprForall var p)
	# (ok, p)								= symmetric p
	= (ok, CExprForall var p)
symmetric (CExprExists var p)
	# (ok, p)								= symmetric p
	= (ok, CExprExists var p)
symmetric (CPropForall var p)
	# (ok, p)								= symmetric p
	= (ok, CPropForall var p)
symmetric (CPropExists var p)
	# (ok, p)								= symmetric p
	= (ok, CPropExists var p)
symmetric (CImplies p q)
	# (ok, q)								= symmetric q
	= (ok, CImplies p q)
symmetric (CEqual e1 e2)
	= (True, CEqual e2 e1)
symmetric (CIff p q)
	= (True, CIff q p)
symmetric (CNot p)
	# (ok, p)								= symmetric p
	= (True, CNot p)
symmetric prop
	= (False, DummyValue)

// ------------------------------------------------------------------------------------------------------------------------
Symmetric :: !Goal !*CHeaps !*CProject -> (!Error, ![Goal], ![TheoremPtr], ![HeapPtr], !*CHeaps, !*CProject)
// ------------------------------------------------------------------------------------------------------------------------
Symmetric goal heaps prj
	# (ok, new_prop)								= symmetric goal.glToProve
	| not ok										= (pushError (X_ApplyTactic "Symmetric" "Current goal is not an equality.") OK, DummyValue, DummyValue, DummyValue, heaps, prj)
	# goal											= {goal & glToProve = new_prop}
	= (OK, [goal], [], [], heaps, prj)

// ------------------------------------------------------------------------------------------------------------------------
SymmetricH :: !HypothesisPtr !TacticMode !Goal !*CHeaps !*CProject -> (!Error, ![Goal], ![TheoremPtr], ![HeapPtr], !*CHeaps, !*CProject)
// ------------------------------------------------------------------------------------------------------------------------
SymmetricH ptr mode goal heaps prj
	# (hyp, heaps)									= readPointer ptr heaps
	# (prop, heaps)									= FreshVars hyp.hypProp heaps
	# (ok, new_hyp)									= symmetric prop
	| not ok										= (pushError (X_ApplyTactic "Symmetric" ("Hypothesis '" +++ hyp.hypName +++ "' is not an equality.")) OK, DummyValue, DummyValue, DummyValue, heaps, prj)
	| mode == Implicit
		# (hypotheses, heaps, prj)					= overwriteHypothesis goal.glHypotheses ptr new_hyp heaps prj
		# goal										= {goal & glHypotheses = hypotheses}
		= (OK, [goal], [], [], heaps, prj)
	| mode == Explicit
		# goal										= {goal & glToProve = CImplies new_hyp goal.glToProve, glNrIHs = 0}
		= (OK, [goal], [], [], heaps, prj)
	= undef

// ------------------------------------------------------------------------------------------------------------------------
TransitiveE :: !CExprH !Goal !*CHeaps !*CProject -> (!Error, ![Goal], ![TheoremPtr], ![HeapPtr], !*CHeaps, !*CProject)
// ------------------------------------------------------------------------------------------------------------------------
TransitiveE expr goal heaps prj
	# (ok, new1, new2)								= transitive expr goal.glToProve
	| not ok										= (pushError (X_ApplyTactic "Transitive" "Expected a goal of the form e1=e2.") OK, DummyValue, DummyValue, DummyValue, heaps, prj)
	# goal1											= {goal & glToProve = new1}
	# (error, _, _, heaps, prj)						= wellTyped goal1 heaps prj
	| isError error									= (pushError (X_ApplyTactic "Transitive" "Expression given has invalid type.") error, DummyValue, DummyValue, DummyValue, heaps, prj)
	# goal2											= {goal & glToProve = new2}
	# (error, _, _, heaps, prj)						= wellTyped goal2 heaps prj
	| isError error									= (pushError (X_ApplyTactic "Transitive" "Expression given has invalid type.") error, DummyValue, DummyValue, DummyValue, heaps, prj)
	# (used_symbols, heaps)							= GetUsedSymbols expr heaps
	= (OK, [goal1,goal2], [], used_symbols, heaps, prj)
	where
		transitive :: !CExprH !CPropH -> (!Bool, !CPropH, !CPropH)
		transitive e2 (CEqual e1 e3)
			= (True, CEqual e1 e2, CEqual e2 e3)
		transitive _ _
			= (False, DummyValue, DummyValue)

// ------------------------------------------------------------------------------------------------------------------------
TransitiveP :: !CPropH !Goal !*CHeaps !*CProject -> (!Error, ![Goal], ![TheoremPtr], ![HeapPtr], !*CHeaps, !*CProject)
// ------------------------------------------------------------------------------------------------------------------------
TransitiveP prop goal heaps prj
	# (ok, new1, new2)								= transitive prop goal.glToProve
	| not ok										= (pushError (X_ApplyTactic "Transitive" "Expected a goal of the form p<->q.") OK, DummyValue, DummyValue, DummyValue, heaps, prj)
	# goal1											= {goal & glToProve = new1}
	# goal2											= {goal & glToProve = new2}
	# (used_symbols, heaps)							= GetUsedSymbols prop heaps
	= (OK, [goal1,goal2], [], used_symbols, heaps, prj)
	where
		transitive :: !CPropH !CPropH -> (!Bool, !CPropH, !CPropH)
		transitive p2 (CIff p1 p3)
			= (True, CIff p1 p2, CIff p2 p3)
		transitive _ _
			= (False, DummyValue, DummyValue)

// ------------------------------------------------------------------------------------------------------------------------
Transparent :: !HeapPtr !Goal !*CHeaps !*CProject -> (!Error, ![Goal], ![TheoremPtr], ![HeapPtr], !*CHeaps, !*CProject)
// ------------------------------------------------------------------------------------------------------------------------
Transparent ptr goal heaps prj
	# (ok, opaque)									= remove goal.glOpaque ptr
	| not ok										= ([X_ApplyTactic "Transparent" "Function not opaque."], DummyValue, DummyValue, DummyValue, heaps, prj)
	# goal											= {goal & glOpaque = opaque}
	= (OK, [goal], [], [], heaps, prj)
	where
		remove :: ![HeapPtr] !HeapPtr -> (!Bool, ![HeapPtr])
		remove [ptr:ptrs] this
			| ptr == this							= (True, ptrs)
			# (ok, ptrs)							= remove ptrs this
			= (ok, [ptr:ptrs])
		remove [] this
			= (False, [])

// ------------------------------------------------------------------------------------------------------------------------
Trivial :: !Goal !*CHeaps !*CProject -> (!Error, ![Goal], ![TheoremPtr], ![HeapPtr], !*CHeaps, !*CProject)
// ------------------------------------------------------------------------------------------------------------------------
Trivial goal heaps prj
	| not (is_true goal.glToProve)					= (pushError (X_ApplyTactic "Trivial" "Current goal is not TRUE.") OK, DummyValue, DummyValue, DummyValue, heaps, prj)
	= (OK, [], [], [], heaps, prj)
	where
		is_true :: !CPropH -> Bool
		is_true (CExprForall _ p)	= is_true p
		is_true (CExprExists _ p)	= is_true p
		is_true (CPropForall _ p)	= is_true p
		is_true (CPropExists _ p)	= is_true p
		is_true (CImplies p q)		= is_true q
		is_true CTrue				= True
		is_true _					= False

// ------------------------------------------------------------------------------------------------------------------------
ncurry :: !CExprH !*CHeaps !*CProject -> (!Error, !(!Bool, !CExprH), !*CHeaps, !*CProject)
// ------------------------------------------------------------------------------------------------------------------------
ncurry ((expr @# exprs1) @# exprs2) heaps prj
	= (OK, (True, expr @# (exprs1 ++ exprs2)), heaps, prj)
ncurry ((ptr @@# exprs1) @# exprs2) heaps prj
	= (OK, (True, ptr @@# (exprs1 ++ exprs2)), heaps, prj)
ncurry other heaps prj
	= (OK, (False, other), heaps, prj)

// ------------------------------------------------------------------------------------------------------------------------
Uncurry :: !Goal !*CHeaps !*CProject -> (!Error, ![Goal], ![TheoremPtr], ![HeapPtr], !*CHeaps, !*CProject)
// ------------------------------------------------------------------------------------------------------------------------
Uncurry goal heaps prj
	# (error, (changed, prop), heaps, prj)			= recurse ncurry goal.glToProve heaps prj
	| isError error									= (error, DummyValue, DummyValue, DummyValue, heaps, prj)
	| not changed									= ([X_ApplyTactic "Uncurry" "Nothing to uncurry."], DummyValue, DummyValue, DummyValue, heaps, prj)
	# goal											= {goal & glToProve = prop}
	= (OK, [goal], [], [], heaps, prj)

// ------------------------------------------------------------------------------------------------------------------------
UncurryH :: !HypothesisPtr !TacticMode !Goal !*CHeaps !*CProject -> (!Error, ![Goal], ![TheoremPtr], ![HeapPtr], !*CHeaps, !*CProject)
// ------------------------------------------------------------------------------------------------------------------------
UncurryH ptr mode goal heaps prj
	# (hyp, heaps)									= readPointer ptr heaps
	# (error, (changed, prop), heaps, prj)			= recurse ncurry hyp.hypProp heaps prj
	| isError error									= (error, DummyValue, DummyValue, DummyValue, heaps, prj)
	| not changed									= ([X_ApplyTactic "Uncurry" ("Nothing to uncurry in hypothesis '" +++ hyp.hypName +++ "'.")], DummyValue, DummyValue, DummyValue, heaps, prj)
	| mode == Explicit
		# goal										= {goal & glToProve = CImplies prop goal.glToProve}
		= (OK, [goal], [], [], heaps, prj)
	| mode == Implicit
		# hyp										= {hyp & hypProp = prop}
		# heaps										= writePointer ptr hyp heaps
		= (OK, [goal], [], [], heaps, prj)
	= undef

// ------------------------------------------------------------------------------------------------------------------------
ushare :: !DestroyAfterwards !CName !VarLocation !CExprH !*CHeaps !*CProject -> (!Error, !(!Bool, !CExprH), !*CHeaps, !*CProject)
// ------------------------------------------------------------------------------------------------------------------------
ushare destroy_afterwards var varl cexpr heaps prj
	# (lexpr, heaps, prj)							= convertC2L cexpr heaps prj
	# (error, ptr, var_e, i, heaps)					= find_var var lexpr heaps
	| isError error									= (error, (False, DummyValue), heaps, prj)
	# (count, varl, lexpr, heaps)					= lUnshareVars varl ptr var_e lexpr heaps
	| not (expr_changed count varl)					= ([X_ApplyTactic "Unshare" "Variable does not occur at indicated variable location."], (False, DummyValue), heaps, prj)
	# (cexpr, heaps, prj)							= convertL2C lexpr heaps prj
	| not destroy_afterwards						= (OK, (True, cexpr), heaps, prj)
	# (cs, heaps)									= lCount [ptr] var_e ([0], heaps)
	| hd cs <> 0									= (OK, (True, cexpr), heaps, prj)	// cannot destroy recursive let
	| not (destroy_possible count varl)				= (OK, (True, cexpr), heaps, prj)
	# lexpr											= destroy i lexpr
	# (cexpr, heaps, prj)							= convertL2C lexpr heaps prj
	= (OK, (True, cexpr), heaps, prj)
	where
		find_var :: !CName !LExpr !*CHeaps -> (!Error, !CExprVarPtr, !LExpr, !Int, !*CHeaps)
		find_var name (LLazyLet ptrs _) heaps
			# (letdefs, heaps)						= readPointers ptrs heaps
			= find_var_2 name 0 letdefs heaps
		find_var name _ heaps
			= ([X_ApplyTactic "Unshare" "Indicated let does not exist."], nilPtr, DummyValue, DummyValue, heaps)
		
		find_var_2 :: !CName !Int ![LLetDef] !*CHeaps -> (!Error, !CExprVarPtr, !LExpr, !Int, !*CHeaps)
		find_var_2 name i [LLetDef ptr _ e: letdefs] heaps
			# (var, heaps)							= readPointer ptr heaps
			| var.evarName == name					= (OK, ptr, e, i, heaps)
			= find_var_2 name (i+1) letdefs heaps
		find_var_2 name i [_:letdefs] heaps
			= find_var_2 name (i+1) letdefs heaps
		find_var_2 name i [] heaps
			= ([X_ApplyTactic "Unshare" ("Variable " +++ name +++ " does not occur in indicated let.")], nilPtr, DummyValue, DummyValue, heaps)
		
		expr_changed :: !Int !VarLocation -> Bool
		expr_changed 0 _							= True
		expr_changed n AllVars						= True
		expr_changed n (JustVarIndex 0)				= True
		expr_changed _ _							= False
		
		destroy_possible :: !Int !VarLocation -> Bool
		destroy_possible 1 (JustVarIndex 0)			= True
		destroy_possible n AllVars					= True
		destroy_possible _ _						= False
		
		destroy :: !Int !LExpr -> LExpr
		destroy i (LLazyLet ptrs e)
			| isEmpty (tl ptrs)						= e
			= LLazyLet (removeAt i ptrs) e

// ------------------------------------------------------------------------------------------------------------------------
Unshare :: !DestroyAfterwards !LetLocation !CName !VarLocation !Goal !*CHeaps !*CProject -> (!Error, ![Goal], ![TheoremPtr], ![HeapPtr], !*CHeaps, !*CProject)
// ------------------------------------------------------------------------------------------------------------------------
Unshare mode letl var varl goal heaps prj
	# (error, (changed, toProve), heaps, prj)		= actOnExprLocation (SelectedSubExpr "let" letl Nothing) goal.glToProve (ushare mode var varl) heaps prj
	| isError error									= (error, DummyValue, DummyValue, DummyValue, heaps, prj)
	| not changed									= ([X_ApplyTactic "Unshare" "Indicated let does not exist."], DummyValue, DummyValue, DummyValue, heaps, prj)
	# goal											= {goal & glToProve = toProve}
	= (OK, [goal], [], [], heaps, prj)

// ------------------------------------------------------------------------------------------------------------------------
UnshareH :: !DestroyAfterwards !LetLocation !CName !VarLocation !HypothesisPtr !Goal !*CHeaps !*CProject -> (!Error, ![Goal], ![TheoremPtr], ![HeapPtr], !*CHeaps, !*CProject)
// ------------------------------------------------------------------------------------------------------------------------
UnshareH mode letl var varl ptr goal heaps prj
	# (hyp, heaps)									= readPointer ptr heaps
	# (error, (changed, prop), heaps, prj)			= actOnExprLocation (SelectedSubExpr "let" letl Nothing) hyp.hypProp (ushare mode var varl) heaps prj
	| isError error									= (error, DummyValue, DummyValue, DummyValue, heaps, prj)
	| not changed									= ([X_ApplyTactic "Unshare" "Indicated let does not exist."], DummyValue, DummyValue, DummyValue, heaps, prj)
	# (hypotheses, heaps, prj)						= overwriteHypothesis goal.glHypotheses ptr prop heaps prj
	# goal											= {goal & glHypotheses = hypotheses}
	= (OK, [goal], [], [], heaps, prj)

// ------------------------------------------------------------------------------------------------------------------------
WitnessE :: !CExprH !Goal !*CHeaps !*CProject -> (!Error, ![Goal], ![TheoremPtr], ![HeapPtr], !*CHeaps, !*CProject)
// ------------------------------------------------------------------------------------------------------------------------
WitnessE expr goal heaps prj
	# (ok, new_prop, heaps)							= fill_in expr goal.glToProve heaps
	| not ok										= (pushError (X_ApplyTactic "Witness" "Goal does not start with expression-exists.") OK, DummyValue, DummyValue, DummyValue, heaps, prj)
	# goal											= {goal & glToProve = new_prop}
	# (error, _, _, heaps, prj)						= wellTyped goal heaps prj
	| isError error									= (pushError (X_ApplyTactic "Witness" "Witness does not have valid type.") error, DummyValue, DummyValue, DummyValue, heaps, prj)
	# (used_symbols, heaps)							= GetUsedSymbols expr heaps
	= (OK, [goal], [], used_symbols, heaps, prj)
	where
		fill_in :: !CExprH !CPropH !*CHeaps -> (!Bool, !CPropH, !*CHeaps)
		fill_in witness (CExprExists ptr prop) heaps
			# (prop, heaps)							= SafeSubst {DummyValue & subExprVars = [(ptr,witness)]} prop heaps
			= (True, prop, heaps)
		fill_in witness other heaps
			= (False, DummyValue, heaps)

// ------------------------------------------------------------------------------------------------------------------------
WitnessP :: !CPropH !Goal !*CHeaps !*CProject -> (!Error, ![Goal], ![TheoremPtr], ![HeapPtr], !*CHeaps, !*CProject)
// ------------------------------------------------------------------------------------------------------------------------
WitnessP prop goal heaps prj
	# (ok, new_prop, heaps)							= fill_in prop goal.glToProve heaps
	| not ok										= (pushError (X_ApplyTactic "Witness" "Goal does not start with expression-exists.") OK, DummyValue, DummyValue, DummyValue, heaps, prj)
	# goal											= {goal & glToProve = new_prop}
	# (used_symbols, heaps)							= GetUsedSymbols prop heaps
	= (OK, [goal], [], used_symbols, heaps, prj)
	where
		fill_in :: !CPropH !CPropH !*CHeaps -> (!Bool, !CPropH, !*CHeaps)
		fill_in witness (CPropExists ptr prop) heaps
			# (prop, heaps)							= SafeSubst {DummyValue & subPropVars = [(ptr,witness)]} prop heaps
			= (True, prop, heaps)
		fill_in witness other heaps
			= (False, DummyValue, heaps)

// ------------------------------------------------------------------------------------------------------------------------
WitnessH :: !HypothesisPtr !TacticMode !Goal !*CHeaps !*CProject -> (!Error, ![Goal], ![TheoremPtr], ![HeapPtr], !*CHeaps, !*CProject)
// ------------------------------------------------------------------------------------------------------------------------
WitnessH ptr mode goal heaps prj
	# (hyp, heaps)									= readPointer ptr heaps
	# (prop, heaps)									= FreshVars hyp.hypProp heaps
	# (type, eptr, pptr, prop)						= disect prop
	| type == 0
		= (pushError (X_ApplyTactic "Witness" "Hypothesis given does not start with existential quantor.") OK, DummyValue, DummyValue, DummyValue, heaps, prj)
	| type == 1
		# (evar, heaps)								= readPointer eptr heaps
		# (new_ptr, heaps)							= newPointer evar heaps
		# (prop, heaps)								= SafeSubst {DummyValue & subExprVars = [(eptr,CExprVar new_ptr)]} prop heaps
		| mode == Explicit
			# goal									= {goal & glToProve = CExprForall new_ptr (CImplies prop goal.glToProve), glNrIHs = 0}
			= (OK, [goal], [], [], heaps, prj)
		| mode == Implicit
			# (hypotheses, heaps, prj)				= overwriteHypothesis goal.glHypotheses ptr prop heaps prj
			# goal									= {goal & glExprVars = [new_ptr:goal.glExprVars], glHypotheses = hypotheses}
			= (OK, [goal], [], [], heaps, prj)
		= undef
	| type == 2
		# (pvar, heaps)								= readPointer pptr heaps
		# (new_ptr, heaps)							= newPointer pvar heaps
		# (prop, heaps)								= SafeSubst {DummyValue & subPropVars = [(pptr,CPropVar new_ptr)]} prop heaps
		| mode == Explicit
			# goal									= {goal & glToProve = CPropForall new_ptr (CImplies prop goal.glToProve), glNrIHs = 0}
			= (OK, [goal], [], [], heaps, prj)
		| mode == Implicit
			# (hypotheses, heaps, prj)				= overwriteHypothesis goal.glHypotheses ptr prop heaps prj
			# goal									= {goal & glPropVars = [new_ptr:goal.glPropVars], glHypotheses = hypotheses}
			= (OK, [goal], [], [], heaps, prj)
		= undef
	= undef
	where
		disect :: !CPropH -> (!Int, !CExprVarPtr, !CPropVarPtr, !CPropH)
		disect (CExprExists ptr p)
			= (1, ptr, nilPtr, p)
		disect (CPropExists ptr p)
			= (2, nilPtr, ptr, p)
		disect other
			= (0, nilPtr, nilPtr, DummyValue)