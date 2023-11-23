/*
** Program: Clean Prover System
** Module:  Compare (.icl)
** 
** Author:  Maarten de Mol
** Created: 20 June 2001
*/

implementation module
	Compare

import
	CoreAccess,
	CoreTypes,
	Debug,
	Definedness,
	Heaps,
	Print,
	States

// ------------------------------------------------------------------------------------------------------------------------
:: Chain =
// ------------------------------------------------------------------------------------------------------------------------
	  SmallerChain		!CExprH !Chain
	| SmallerEqualChain	!CExprH !Chain
	| EndChain			!CExprH

// ------------------------------------------------------------------------------------------------------------------------
:: Comparison :== (!Bool, !CExprH, !CExprH)			// (True, e1, e2)   means e1 <= e2
													// (False, e1, e2)  means e1 <  e2
// ------------------------------------------------------------------------------------------------------------------------

// ------------------------------------------------------------------------------------------------------------------------
CompareInts :: !Goal !*CHeaps !*CProject -> (!Bool, !*CHeaps, !*CProject)
// ------------------------------------------------------------------------------------------------------------------------
CompareInts goal heaps prj
	# (_, definedness_info, heaps, prj)		= findDefinednessInfo goal heaps prj
	# defined								= definedness_info.definedExpressions
	# (intfuns, prj)						= prj!prjABCFunctions.stdInt
	# (boolfuns, prj)						= prj!prjABCFunctions.stdBool
	# (comparisons, heaps)					= buildComparisons goal.glHypotheses intfuns boolfuns heaps
	# conclusion							= find_conclusion goal.glToProve
	# (are_defined, result, e)				= check_definedness_prop conclusion defined intfuns boolfuns
	# negative_conclusion					= CEqual e (CBasicValue (CBasicBoolean (not result)))
	# comparisons							= case are_defined of
												True	-> case (buildComparison negative_conclusion intfuns boolfuns) of
															(Just comparison)	-> [comparison:comparisons]
															Nothing				-> comparisons
												False	-> comparisons
	# candidates							= removeDup (getCandidates comparisons)
	# chains								= buildChains candidates comparisons
//	#! (heaps, prj)							= showChains chains heaps prj
	# contradiction							= or (map (contradictionInChain [] []) chains)
	= (contradiction, heaps, prj)
	where
		find_conclusion :: !CPropH -> CPropH
		find_conclusion (CExprForall var p)
			= find_conclusion p
		find_conclusion (CImplies p q)
			= find_conclusion q
		find_conclusion p
			= p
		
		check_definedness_prop :: !CPropH ![CExprH] !IntFunctions !BoolFunctions -> (!Bool, !Bool, !CExprH)
		check_definedness_prop (CEqual e (CBasicValue (CBasicBoolean bool))) defined intfuns boolfuns
			= (check_definedness_expr e defined intfuns boolfuns, bool, e)
		check_definedness_prop (CEqual (CBasicValue (CBasicBoolean bool)) e) defined intfuns boolfuns
			= (check_definedness_expr e defined intfuns boolfuns, bool, e)
		check_definedness_prop other defined intfuns boolfuns
			= (False, DummyValue, DummyValue)
		
		check_definedness_expr :: !CExprH ![CExprH] !IntFunctions !BoolFunctions -> Bool
		check_definedness_expr (ptr @@# [arg]) defined intfuns boolfuns
			= case ptr == boolfuns.boolNot of
				True	-> check_definedness_expr arg defined intfuns boolfuns
				False	-> False
		check_definedness_expr (ptr @@# [arg1,arg2]) defined intfuns boolfuns
			= case ptr == intfuns.intSmaller of
				True	-> check_definedness_expr arg1 defined intfuns boolfuns &&
						   check_definedness_expr arg2 defined intfuns boolfuns
				False	-> False
		check_definedness_expr (CBasicValue value) defined intfuns boolfuns
			= True
		check_definedness_expr expr defined intfuns boolfuns
			= isMember expr defined

// ------------------------------------------------------------------------------------------------------------------------
showChain :: !Chain !*CHeaps !*CProject -> (!*CHeaps, !*CProject)
// ------------------------------------------------------------------------------------------------------------------------
showChain (SmallerChain expr chain) heaps prj
	# (print, heaps, prj)					= makePrintable expr heaps prj
	#! prj									= debugAfter print my_debug prj
	#! prj									= debugAfter " < " my_debug prj
	= showChain chain heaps prj
	where
		my_debug expr
			= debugShowWithOptions [DebugTerminator ""] expr
showChain (SmallerEqualChain expr chain) heaps prj
	# (print, heaps, prj)					= makePrintable expr heaps prj
	#! prj									= debugAfter print my_debug prj
	#! prj									= debugAfter " <= " my_debug prj
	= showChain chain heaps prj
	where
		my_debug expr
			= debugShowWithOptions [DebugTerminator ""] expr
showChain (EndChain expr) heaps prj
	# (print, heaps, prj)					= makePrintable expr heaps prj
	#! prj									= prj --->> print
	= (heaps, prj)

// ------------------------------------------------------------------------------------------------------------------------
showChains :: ![Chain] !*CHeaps !*CProject -> (!*CHeaps, !*CProject)
// ------------------------------------------------------------------------------------------------------------------------
showChains [chain:chains] heaps prj
	#! (heaps, prj)							= showChain chain heaps prj
	= showChains chains heaps prj
showChains [] heaps prj
	= (heaps, prj)











// ------------------------------------------------------------------------------------------------------------------------
buildChain :: !CExprH ![Comparison] -> [Chain]
// ------------------------------------------------------------------------------------------------------------------------
buildChain expr comparisons
	= extendChain expr comparisons comparisons
	where
		extendChain :: !CExprH ![Comparison] ![Comparison] -> [Chain]
		extendChain expr [(smaller_equal, e1, e2): comparisons] all_comparisons
			# other_chains					= extendChain expr comparisons all_comparisons
			| expr <> e1					= other_chains
			# e2_chains						= buildChain e2 (removeMember (smaller_equal, e1, e2) all_comparisons)
			# chains						= case smaller_equal of
												True	-> map (SmallerEqualChain expr) e2_chains
												False	-> map (SmallerChain expr) e2_chains
			= chains ++ other_chains
		extendChain expr [] all_comparisons
			= [EndChain expr]

// ------------------------------------------------------------------------------------------------------------------------
buildChains :: ![CExprH] ![Comparison] -> [Chain]
// ------------------------------------------------------------------------------------------------------------------------
buildChains [expr:exprs] comparisons
	# chains								= buildChain expr comparisons
	# more_chains							= buildChains exprs comparisons
	= chains ++ more_chains
buildChains [] _
	= []

// ------------------------------------------------------------------------------------------------------------------------
buildComparison :: !CPropH !IntFunctions !BoolFunctions -> Maybe Comparison
// ------------------------------------------------------------------------------------------------------------------------
buildComparison (CEqual (CBasicValue value) (ptr @@# args)) intfuns boolfuns
	= buildComparison (CEqual (ptr @@# args) (CBasicValue value)) intfuns boolfuns
buildComparison (CEqual (ptr @@# [arg]) (CBasicValue (CBasicBoolean bool))) intfuns boolfuns
	| ptr == boolfuns.boolNot				= buildComparison (CEqual arg (CBasicValue (CBasicBoolean (not bool)))) intfuns boolfuns
	= Nothing
buildComparison (CEqual (ptr @@# [arg1, arg2]) (CBasicValue (CBasicBoolean bool))) intfuns boolfuns
	| ptr == intfuns.intSmaller
		= case bool of
			True	-> Just (False, arg1, arg2)
			False	-> Just (True, arg2, arg1)
	= Nothing
buildComparison prop intfuns boolfuns
	= Nothing

// ------------------------------------------------------------------------------------------------------------------------
buildComparisons :: ![HypothesisPtr] !IntFunctions !BoolFunctions !*CHeaps -> (![Comparison], !*CHeaps)
// ------------------------------------------------------------------------------------------------------------------------
buildComparisons [ptr:ptrs] intfuns boolfuns heaps
	# (hyp, heaps)							= readPointer ptr heaps
	# mb_comparison							= buildComparison hyp.hypProp intfuns boolfuns
	# (comparisons, heaps)					= buildComparisons ptrs intfuns boolfuns heaps
	= case mb_comparison of
		(Just comparison)		-> ([comparison:comparisons], heaps)
		Nothing					-> (comparisons, heaps)
buildComparisons [] intfuns boolfuns heaps
	= ([], heaps)

// ------------------------------------------------------------------------------------------------------------------------
contradictionInChain :: ![CExprH] ![CExprH] !Chain -> Bool
// ------------------------------------------------------------------------------------------------------------------------
contradictionInChain smaller smaller_equal (SmallerChain expr chain)
	# contradict							= contradictionInSmaller smaller expr
	| contradict							= True
	# contradict							= contradictionInSmallerEqual smaller_equal expr
	| contradict							= True
	# smaller								= add_one smaller
	= contradictionInChain [expr: smaller++smaller_equal] [] chain
	where
		add_one :: ![CExprH] -> [CExprH]
		add_one [CBasicValue (CBasicInteger n): exprs]
			= [CBasicValue (CBasicInteger (n+1)): add_one exprs]
		add_one [expr:exprs]
			= [expr: add_one exprs]
		add_one []
			= []
contradictionInChain smaller smaller_equal (SmallerEqualChain expr chain)
	# contradict							= contradictionInSmaller smaller expr
	| contradict							= True
	# contradict							= contradictionInSmallerEqual smaller_equal expr
	| contradict							= True
	= contradictionInChain smaller [expr:smaller_equal] chain
contradictionInChain smaller smaller_equal (EndChain expr)
	# contradict							= contradictionInSmaller smaller expr
	| contradict							= True
	# contradict							= contradictionInSmallerEqual smaller_equal expr
	| contradict							= True
	= False

// ------------------------------------------------------------------------------------------------------------------------
contradictionInSmaller :: ![CExprH] !CExprH -> Bool
// ------------------------------------------------------------------------------------------------------------------------
contradictionInSmaller [(CBasicValue (CBasicInteger n1)): smaller] (CBasicValue (CBasicInteger n2))
	= case n1 >= n2 of
		True	-> True
		False	-> contradictionInSmaller smaller (CBasicValue (CBasicInteger n2))
contradictionInSmaller [e1:smaller] e2
	= case e1 == e2 of
		True	-> True
		False	-> contradictionInSmaller smaller e2
contradictionInSmaller [] _
	= False

// ------------------------------------------------------------------------------------------------------------------------
contradictionInSmallerEqual :: ![CExprH] !CExprH -> Bool
// ------------------------------------------------------------------------------------------------------------------------
contradictionInSmallerEqual [(CBasicValue (CBasicInteger n1)): smaller_equal] (CBasicValue (CBasicInteger n2))
	= case n1 > n2 of
		True	-> True
		False	-> contradictionInSmallerEqual smaller_equal (CBasicValue (CBasicInteger n2))
contradictionInSmallerEqual [_:smaller_equal] expr
	= contradictionInSmallerEqual smaller_equal expr
contradictionInSmallerEqual [] _
	= False

// ------------------------------------------------------------------------------------------------------------------------
getCandidates :: ![Comparison] -> [CExprH]
// ------------------------------------------------------------------------------------------------------------------------
getCandidates [(_, e1, e2): comparisons]
	= [e1, e2: getCandidates comparisons]
getCandidates []
	= []