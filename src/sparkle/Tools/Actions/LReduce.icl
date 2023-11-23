/*
** Program: Clean Prover System
** Module:  LReduce (.icl)
** 
** Author:  Maarten de Mol
** Created: 11 December 2007
*/


/*
** NOTES:
** -- An expression is in Root Normal Form(RNF) if it is either:
**    (o) a basic value (including arrays);
**    (o) a partial application;
**    (o) a total constructor application, whose strict arguments are all in DRNF;
**    (o) bottom.
** -- An expression is in Defined Root Normal Form(DRNF) if it is
**    in root normal form, but is unequal to bottom.
** -- An expression is in Sharable Normal Form(SNF) if it is either:
**    (o) a variable;
**    (o) a basic value; (if array, all elements must be in SNF too);
**    (o) a partial application, whose arguments are all in SNF;
**    (o) a total constructor application, whose arguments are all in DSNF;
**    (o) bottom.
** -- An expression is in Defined Sharable Normal Form(DSNF) if it is
**    in sharable normal form, but is unequal to bottom.
** -- The reduction system is an extension of the system described in the paper
**    'A Single-Step Term-Graph Reduction System for Proof Assistants'.
**    The system in the paper is single-step confluent.
**    Due to the addition of let-joining, our system is *not*:
**      App (Let L1 (Let L2 E1)) E2 -> Let L1 (App (Let L2 E1) E2), and
**      App (Let L1 (Let L2 E1)) E2 -> App (Let (L1+L2) E1) E2,
**    but those cannot be joined in one single step.
** -- The reduction system in this module implements leftmost-outermost reduction.
**    (exception: the outer redex of garbage collection is always performed at the end) 
**    If a let is produced, it must therefore be lifted/joined as much as possible
**    first. This is achieved by means of the 'LetStore'.
*/

implementation module 
	LReduce

import
	StdEnv,
	DynArray,
	CoreTypes,
	CoreAccess,
	LTypes,
	ProveTypes,
	Print,
	Heaps,
	Operate,
	States,
	RWSDebug

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: LInRNF								:== Bool
:: LInUNF								:== Bool

:: LExprDepth							:== Int
:: LLetStore							=	{ outerLets			:: ![LLetDefPtr]
											, innerLets			:: ![LLetDefPtr]
											, innerLetsDepth	:: !LExprDepth
											}

:: *LReduceResultE						:== (!LNrSteps, !LLetStore, !(!LInRNF, !LInUNF, !LExpr), !*CHeaps, !*CProject)
:: *LReduceResultES						:== (!LNrSteps, !LLetStore, !(![LInRNF], !LInUNF, ![LExpr]), !*CHeaps, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------

// -------------------------------------------------------------------------------------------------------------------------------------------------
endOnBlocked n ls e heaps prj			:== (n, ls, (False, False, e), heaps, prj)
endOnRNF n ls e heaps prj				:== (n, ls, (True, False, e), heaps, prj)
endOnUNF n ls heaps prj					:== (n, ls, (True, True, LBottom), heaps, prj)
endOnRebind n ls e heaps prj			:==	(n, {ls & innerLetsDepth = (-1)},
											(False, False, LLazyLet ls.innerLets e), heaps, prj)
// -------------------------------------------------------------------------------------------------------------------------------------------------

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: LReductionEnv =
// -------------------------------------------------------------------------------------------------------------------------------------------------
	{ envDefined						:: ![LExpr]
	, envOpenedVars						:: ![LLetDefPtr]
	, envReduceMode						:: !ReduceMode
	}

// Precondition: n > 0. 
// -------------------------------------------------------------------------------------------------------------------------------------------------
addToStore :: !LNrSteps !LLetStore !LExprDepth ![LLetDefPtr] !LReductionEnv -> (!Bool, !LNrSteps, !LLetStore)
// -------------------------------------------------------------------------------------------------------------------------------------------------
addToStore n ls d ptrs env
	= case (n >= d) of
		True										-> case (isEmpty env.envOpenedVars) of
														True	-> (True, n-d, {ls & outerLets = ls.outerLets ++ ptrs})
														False	-> case isMember (hd env.envOpenedVars) ls.outerLets of
																	True	-> (True, n-d, snd (insertInStoreAt ls (hd env.envOpenedVars) ptrs))
																	False	-> (False, n, ls)
		False										-> (True, 0, {ls & innerLets = ptrs, innerLetsDepth = d-n})

// Can fail when in reduceToNF mode, in which case the surrounding let is not part of the local store.
// -------------------------------------------------------------------------------------------------------------------------------------------------
insertInStoreAt :: !LLetStore !LLetDefPtr ![LLetDefPtr] -> (!Bool, !LLetStore)
// -------------------------------------------------------------------------------------------------------------------------------------------------
insertInStoreAt ls ptr lets
	# (ok, outer_lets)								= locatedInsert ls.outerLets ptr lets
	| not ok										= (False, ls)
	= (True, {ls & outerLets = outer_lets})
	where
		locatedInsert [ptr:ptrs] loc add
			| ptr == loc							= (True, [ptr:add] ++ ptrs)
			# (ok, ptrs)							= locatedInsert ptrs loc add
			= (ok, [ptr:ptrs])
		locatedInsert [] loc add
			= (False, [])

// -------------------------------------------------------------------------------------------------------------------------------------------------
reduceExpr :: !LNrSteps !LLetStore !LExprDepth !LExpr !LReductionEnv !*CHeaps !*CProject -> *LReduceResultE
// -------------------------------------------------------------------------------------------------------------------------------------------------
reduceExpr n ls d var_expr=:(LExprVar var (Just ptr)) env heaps prj
	| isMember ptr env.envOpenedVars				= endOnBlocked n ls var_expr heaps prj
	# (letdef, heaps)								= readPointer ptr heaps
	= lreduce n ls d var_expr ptr letdef env heaps prj
	where
		lreduce n ls d var_expr ptr (LLetDef var True e) env heaps prj
			| n == 0								= endOnBlocked n ls var_expr heaps prj
			= reduceExpr (n-1) ls d e env heaps prj
		lreduce n ls d var_expr ptr (LLetDef var False e) env heaps prj
			# rec_env								= {env & envOpenedVars = [ptr:env.envOpenedVars]}
			# (n, ls, (rnf, _, e), heaps, prj)		= reduceExpr n ls 1 e rec_env heaps prj
			# rnf									= rnf || is_expr_var e
			| not rnf || n == 0
				# heaps								= writePointer ptr (LLetDef var False e) heaps
				= endOnBlocked n ls var_expr heaps prj
			| otherwise
				# (more_lets, e, heaps)				= makeSharable e heaps
				# (n, more_lets, e, heaps, prj)		= garbageCollectE n more_lets e heaps prj
				# (ok, ls)							= insertInStoreAt ls ptr more_lets
				| not ok && not (isEmpty more_lets)
					# heaps							= writePointer ptr (LLetDef var False (LLazyLet more_lets e)) heaps
					= endOnBlocked n ls var_expr heaps prj
				# heaps								= writePointer ptr (LLetDef var True e) heaps
				= reduceExpr (n-1) ls d e env heaps prj
		lreduce n ls d var_expr ptr LStrictLetDef env heaps prj
			= endOnBlocked n ls var_expr heaps prj
		
		is_expr_var (LExprVar _ _)					= True
		is_expr_var _								= False
reduceExpr n ls d var_expr=:(LExprVar _ Nothing) env heaps prj
	= endOnBlocked n ls var_expr heaps prj
reduceExpr n ls d basic_value=:(LBasicValue v) env heaps prj
	= endOnRNF n ls basic_value heaps prj
reduceExpr n ls d (LSymbol (LCons info) ptr LTotal es) env heaps prj
	# (n, ls, (rnf_es, unf, es), heaps, prj)		= reduceExprList n ls (d+1) info.lciAnnotatedStrictVars es env heaps prj
	# new_symbol_expr								= LSymbol (LCons info) ptr LTotal es
	| ls.innerLetsDepth == d						= endOnRebind n ls new_symbol_expr heaps prj
	| n > 0 && unf									= endOnUNF (n-1) ls heaps prj
	= case args_defined rnf_es es env of
		True										-> endOnRNF n ls new_symbol_expr heaps prj
		False										-> endOnBlocked n ls new_symbol_expr heaps prj
	where
		args_defined :: ![Bool] ![LExpr] !LReductionEnv -> Bool
		args_defined [True:rnf_es] [e:es] env		= args_defined rnf_es es env
		args_defined [False:rnf_es] [e:es] env		= (isMember e env.envDefined) && args_defined rnf_es es env
		args_defined [] [] env						= True
reduceExpr n ls d (LSymbol (LFun info) ptr LTotal es) env heaps prj
	# (n, ls, (rnf_es, unf, es), heaps, prj)		= reduceExprList n ls (d+1) (info.lfiAnnotatedStrictVars bitor info.lfiCaseVars) es env heaps prj
	# new_symbol_expr								= LSymbol (LFun info) ptr LTotal es
	| ls.innerLetsDepth == d						= endOnRebind n ls new_symbol_expr heaps prj
	| n > 0 && unf									= endOnUNF (n-1) ls heaps prj
	# (_, fundef, prj)								= getFunDef ptr prj
	| n == 0 || fundef.fdOpaque || not (may_expand rnf_es es env.envReduceMode info.lfiCaseVars info.lfiStrictVars env)
													= endOnBlocked n ls new_symbol_expr heaps prj
	# (body, heaps, prj)							= instantiate fundef es heaps prj
	= reduceExpr (n-1) ls d body env heaps prj
	where
		instantiate :: !CFunDefH ![LExpr] !*CHeaps !*CProject -> (!LExpr, !*CHeaps, !*CProject)
		instantiate fundef es heaps prj
			# (_, fundef, prj)						= getFunDef ptr prj
			| fundef.fdIsDeltaRule					= (fundef.fdDeltaRule es, heaps, prj)
			# (body, heaps, prj)					= convertC2L fundef.fdBody heaps prj
			# (body, heaps)							= lFresh [] body heaps
			# (lets, es, heaps)						= shareNamedExprs fundef.fdNrDictionaries fundef.fdExprVarScope es heaps
			# (body, heaps)							= lSubst (zip2 fundef.fdExprVarScope es) body heaps
			# body									= if (isEmpty lets) body (LLazyLet lets body)
			= (body, heaps, prj)
		
		may_expand :: ![Bool] ![LExpr] !ReduceMode !LListOfBool !LListOfBool !LReductionEnv -> Bool
		may_expand [True:rnfs] [e:es] mode case_vars strict_vars env
			= may_expand rnfs es mode (case_vars>>1) (strict_vars>>1) env
		may_expand [False:rnfs] [e:es] AsInClean case_vars strict_vars env
			= may_expand rnfs es AsInClean (case_vars>>1) (strict_vars>>1) env
		may_expand [False:rnfs] [e:es] mode case_vars strict_vars env
			= case override mode (isOdd case_vars) (isOdd strict_vars) (isMember e env.envDefined) of
				True								-> may_expand rnfs es mode (case_vars>>1) (strict_vars>>1) env
				False								-> False
			where
				override Defensive cv sv defined	= (not cv) && (sv || defined)
				override Offensive cv sv defined	= sv || defined
		may_expand [] [] _ _ _ _
			= True
reduceExpr n ls d (LSymbol (LFieldSelector i) ptr LTotal [e]) env heaps prj
	# (n, ls, (rnf, unf, e), heaps, prj)			= reduceExpr n ls (d+1) e env heaps prj
	# new_symbol_expr								= LSymbol (LFieldSelector i) ptr LTotal [e]
	| ls.innerLetsDepth == d						= endOnRebind n ls new_symbol_expr heaps prj
	| n == 0 || not rnf								= endOnBlocked n ls new_symbol_expr heaps prj
	= reduceExpr (n-1) ls d (select_field i e) env heaps prj
	where
		select_field :: !Int !LExpr -> LExpr
		select_field i (LSymbol _ _ _ es)			= es !! i
reduceExpr n ls d partial_app=:(LSymbol _ _ _ _) env heaps prj
	= endOnRNF n ls partial_app heaps prj
reduceExpr n ls d (LApp e1 e2) env heaps prj
	# (n, ls, (rnf, unf, e1), heaps, prj)			= reduceExpr n ls (d+1) e1 env heaps prj
	# new_app_expr									= LApp e1 e2
	| ls.innerLetsDepth == d						= endOnRebind n ls new_app_expr heaps prj
	| n > 0 && unf									= endOnUNF (n-1) ls heaps prj
	# (ok, symbol_e1_e2)							= combine e1 e2
	| not ok										= endOnBlocked n ls new_app_expr heaps prj
	= reduceExpr n ls d symbol_e1_e2 env heaps prj
	where
		combine :: !LExpr !LExpr -> (!Bool, LExpr)
		combine e1=:(LSymbol _ _ LTotal _) e2		= (False, DummyValue)
		combine (LSymbol k p c es) e				= (True, LSymbol k p (c-1) (es++[e]))
		combine e1 e2								= (False, DummyValue)
reduceExpr n ls d (LCase e patterns mb_def) env heaps prj
	# (n, ls, (rnf, unf, e), heaps, prj)			= reduceExpr n ls (d+1) e env heaps prj
	# new_case_expr									= LCase e patterns mb_def
	| ls.innerLetsDepth == 0						= endOnRebind n ls new_case_expr heaps prj
	| not rnf || n == 0								= endOnBlocked n ls new_case_expr heaps prj
	| unf											= endOnUNF (n-1) ls heaps prj
	# (result, heaps)								= match e patterns mb_def heaps
	= reduceExpr (n-1) ls d result env heaps prj
	where
		match :: !LExpr !LCasePatterns !(Maybe LExpr) !*CHeaps -> (!LExpr, !*CHeaps)
		match (LBasicValue v) (LBasicPatterns _ patterns) mb_def heaps
			= matchBasic v patterns mb_def heaps
		match (LSymbol (LCons _) ptr LTotal es) (LAlgPatterns _ patterns) mb_def heaps
			= matchCons ptr es patterns mb_def heaps
		match _ _ _ _
			= abort "Reduction(@match) encountered an incorrectly typed case distinction."
		
		matchBasic :: !LBasicValue ![LBasicPattern] !(Maybe LExpr) !*CHeaps -> (!LExpr, !*CHeaps)
		matchBasic v [p:ps] mb_def heaps
			| v <> p.lbpBasicValue					= matchBasic v ps mb_def heaps
			= (p.lbpResult, heaps)
		matchBasic v [] (Just def) heaps
			= (def, heaps)
		matchBasic v [] Nothing heaps
			= (LBottom, heaps)
		
		matchCons :: !HeapPtr ![LExpr] ![LAlgPattern] !(Maybe LExpr) !*CHeaps -> (!LExpr, !*CHeaps)
		matchCons ptr es [p:ps] mb_def heaps
			| ptr <> p.lapDataCons					= matchCons ptr es ps mb_def heaps
			# (lets, es, heaps)						= shareNamedExprs 0 p.lapExprVarScope es heaps
			# (result, heaps)						= lSubst (zip2 p.lapExprVarScope es) p.lapResult heaps
			# result								= if (isEmpty lets) result (LLazyLet lets result)
			= (result, heaps)
		matchCons ptr es [] (Just def) heaps
			= (def, heaps)
		matchCons ptr es [] Nothing heaps
			= (LBottom, heaps)
reduceExpr n ls d (LLazyLet ptrs e) env heaps prj
	# (n, ptrs, e, heaps, prj)						= garbageCollectE n ptrs e heaps prj
	| isEmpty ptrs									= reduceExpr n ls d e env heaps prj
	| n == 0										= endOnBlocked n ls (LLazyLet ptrs e) heaps prj
	# (ok, n, ls)									= addToStore n ls d ptrs env
	| not ok										= endOnBlocked n ls (LLazyLet ptrs e) heaps prj
	| n == 0										= endOnBlocked n ls e heaps prj
	# (n, ls, (rnf, unf, e), heaps, prj)			= reduceExpr n ls (d+1) e env heaps prj
	# ls											= if (ls.innerLetsDepth == d) {ls & innerLetsDepth = d-1} ls 
	= (n, ls, (rnf, unf, e), heaps, prj)
reduceExpr n ls d (LStrictLet var ptr e1 e2) env heaps prj
	# (n, ls, (rnf, unf, e1), heaps, prj)			= reduceExpr n ls (d+1) e1 env heaps prj
	# new_strict_let_expr							= LStrictLet var ptr e1 e2
	| ls.innerLetsDepth == d						= endOnRebind n ls new_strict_let_expr heaps prj
	# defined										= rnf || isMember e1 env.envDefined
	| not defined || n == 0							= endOnBlocked n ls new_strict_let_expr heaps prj
	| unf											= endOnUNF (n-1) ls heaps prj
	# (new_lets, e1, heaps)							= makeSharable e1 heaps
	# heaps											= writePointer ptr (LLetDef var True e1) heaps
	= reduceExpr (n-1) ls d (LLazyLet [ptr:new_lets] e2) env heaps prj
reduceExpr n ls d LBottom env heaps prj
	= endOnUNF n ls heaps prj

// -------------------------------------------------------------------------------------------------------------------------------------------------
reduceExprList :: !LNrSteps !LLetStore !LExprDepth !LListOfBool ![LExpr] !LReductionEnv !*CHeaps !*CProject -> *LReduceResultES
// -------------------------------------------------------------------------------------------------------------------------------------------------
reduceExprList n ls d strictness [e:es] env heaps prj
	| isEven strictness
		# (n, ls, (rnf_es, unf, es), heaps, prj)	= reduceExprList n ls d (strictness >> 1) es env heaps prj
		= (n, ls, ([True:rnf_es], unf, [e:es]), heaps, prj)
	# (n, ls, (rnf_e, unf, e), heaps, prj)			= reduceExpr n ls d e env heaps prj
	| unf											= (n, ls, ([], True, [e:es]), heaps, prj)
	# (n, ls, (rnf_es, unf, es), heaps, prj)		= reduceExprList n ls d (strictness >> 1) es env heaps prj
	= (n, ls, ([rnf_e:rnf_es], unf, [e:es]), heaps, prj)
reduceExprList n ls d strictness [] env heaps prj
	= (n, ls, ([], False, []), heaps, prj)


























// -------------------------------------------------------------------------------------------------------------------------------------------------
garbageCollect :: !CExprH !*CHeaps !*CProject -> (!CExprH, !*CHeaps, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------
garbageCollect c=:(CLet False _ _) heaps prj
	# (LLazyLet lets e, heaps, prj)					= convertC2L c heaps prj
	# (_, lets, l, heaps, prj)						= garbageCollectE 99999 lets e heaps prj
	# l												= if (isEmpty lets) e (LLazyLet lets e)
	= convertL2C l heaps prj
garbageCollect e heaps prj
	= (e, heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
garbageCollectE :: !LNrSteps ![LLetDefPtr] !LExpr !*CHeaps !*CProject -> (!LNrSteps, ![LLetDefPtr], !LExpr, !*CHeaps, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------
garbageCollectE n ptrs e heaps prj
	# (letdefs, heaps)								= readPointers ptrs heaps
	# (vars, mus, es)								= disect letdefs
	# (n, ptrs, vars, es, old_vars, old_es)			= sepSNFs n ptrs vars mus es
	# ([e:es], heaps)								= lDependentSubst old_vars old_es [e:es] heaps
	# (reachable, heaps)							= collectReachable vars es [] [e] heaps
	# (n, ptrs, vars, es)							= removeUnreachable n ptrs vars es reachable
	# (counts, heaps)								= lCount vars [e:es] (repeat 0, heaps)
	# (n, ptrs, vars, es, old_vars, old_es)			= removeSingletons n ptrs vars es counts
	# ([e:es], heaps)								= lDependentSubst old_vars old_es [e:es] heaps
	# heaps											= writePointers ptrs (join vars es) heaps
	= (n, ptrs, e, heaps, prj)
	where
		disect :: ![LLetDef] -> (![CExprVarPtr], ![Bool], ![LExpr])
		disect [LLetDef var mu e:letdefs]
			# (vars, mus, es)						= disect letdefs
			= ([var:vars], [mu:mus], [e:es])
		disect []
			= ([], [], [])
		
		join :: ![CExprVarPtr] ![LExpr] -> [LLetDef]
		join [ptr:ptrs] [e:es]						= [LLetDef ptr False e: join ptrs es]
		join _ _									= []

// -------------------------------------------------------------------------------------------------------------------------------------------------
collectReachable :: ![CExprVarPtr] ![LExpr] ![CExprVarPtr] ![LExpr] !*CHeaps -> (![CExprVarPtr], !*CHeaps)
// -------------------------------------------------------------------------------------------------------------------------------------------------
collectReachable vars es reached [analyze_e: tba] heaps
	# (counts, heaps)								= lCount vars analyze_e (repeat 0, heaps)
	# (vars, es, reached, tba)						= addReachedVars vars es counts reached tba
	= collectReachable vars es reached tba heaps
	where
		addReachedVars :: ![CExprVarPtr] ![LExpr] ![Int] ![CExprVarPtr] ![LExpr] -> (![CExprVarPtr], ![LExpr], ![CExprVarPtr], ![LExpr])
		addReachedVars [var:vars] [e:es] [count:counts] reached tba
			= hasBeenReached (count > 0) var e (addReachedVars vars es counts reached tba)
		addReachedVars [] [] _ reached tba
			= ([], [], reached, tba)
		
		hasBeenReached :: !Bool !CExprVarPtr !LExpr !(![CExprVarPtr], ![LExpr], ![CExprVarPtr], ![LExpr]) -> (![CExprVarPtr], ![LExpr], ![CExprVarPtr], ![LExpr])
		hasBeenReached True var e (vars, es, reached, tba)
			= (vars, es, [var:reached], [e:tba])
		hasBeenReached False var e (vars, es, reached, tba)
			= ([var:vars], [e:es], reached, tba)
collectReachable _ _ reached_vars [] heaps
	= (reached_vars, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
removeUnreachable :: !LNrSteps ![LLetDefPtr] ![CExprVarPtr] ![LExpr] ![CExprVarPtr] -> (!LNrSteps, ![LLetDefPtr], ![CExprVarPtr], ![LExpr])
// -------------------------------------------------------------------------------------------------------------------------------------------------
removeUnreachable n [ptr:ptrs] [var:vars] [e:es] reachable
	| not (isMember var reachable) && n > 0			= removeUnreachable (n-1) ptrs vars es reachable
	# (n, ptrs, vars, es)							= removeUnreachable n ptrs vars es reachable
	= (n, [ptr:ptrs], [var:vars], [e:es])
removeUnreachable n [] [] [] reachable
	= (n, [], [], [])

// -------------------------------------------------------------------------------------------------------------------------------------------------
removeSingletons :: !LNrSteps ![LLetDefPtr] ![CExprVarPtr] ![LExpr] ![Int]
				-> (!LNrSteps, ![LLetDefPtr], ![CExprVarPtr], ![LExpr], ![CExprVarPtr], ![LExpr])
// -------------------------------------------------------------------------------------------------------------------------------------------------
removeSingletons n [ptr:ptrs] [var:vars] [e:es] [count:counts]
	| count == 1 && n > 0
		# (n, ptrs, vars, es, old_vars, old_es)		= removeSingletons (n-1) ptrs vars es counts
		= (n, ptrs, vars, es, [var:old_vars], [e:old_es])
	| otherwise
		# (n, ptrs, vars, es, old_vars, old_es)		= removeSingletons n ptrs vars es counts
		= (n, [ptr:ptrs], [var:vars], [e:es], old_vars, old_es)
removeSingletons n [] [] [] _
	= (n, [], [], [], [], [])

// -------------------------------------------------------------------------------------------------------------------------------------------------
sepSNFs :: !LNrSteps ![LLetDefPtr] ![CExprVarPtr] ![Bool] ![LExpr]
		-> (!LNrSteps, ![LLetDefPtr], ![CExprVarPtr], ![LExpr], ![CExprVarPtr], ![LExpr])
// -------------------------------------------------------------------------------------------------------------------------------------------------
sepSNFs n [ptr:ptrs] [var:vars] [mu:mus] [e:es]
	| n > 0 && mu
		# (n, ptrs, vars, es, old_vars, old_es)		= sepSNFs (n-1) ptrs vars mus es
		= (n, ptrs, vars, es, [var:old_vars], [e:old_es])
	| otherwise
		# (n, ptrs, vars, es, old_vars, old_es)		= sepSNFs n ptrs vars mus es
		= (n, [ptr:ptrs], [var:vars], [e:es], old_vars, old_es)
sepSNFs n [] [] [] []
	= (n, [], [], [], [], [])





















// Precondition: expression is in root normal form.
// -------------------------------------------------------------------------------------------------------------------------------------------------
makeSharable :: !LExpr !*CHeaps -> (![LLetDefPtr], !LExpr, !*CHeaps)
// -------------------------------------------------------------------------------------------------------------------------------------------------
makeSharable (LSymbol ptr type n es) heaps
	# (defs, es, heaps)								= shareExprs 1 es heaps
	= (defs, LSymbol ptr type n es, heaps)
makeSharable e heaps
	= ([], e, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
shareExprs :: !Int ![LExpr] !*CHeaps -> (![LLetDefPtr], ![LExpr], !*CHeaps)
// -------------------------------------------------------------------------------------------------------------------------------------------------
shareExprs n [e:es] heaps
	# (defs, es, heaps)								= shareExprs (n+1) es heaps
	| SNF e											= (defs, [e:es], heaps)
	# var											= {evarName = "x" +++ toString n, evarInfo = DummyValue}
	# (var_ptr, heaps)								= newPointer var heaps
	# letdef										= LLetDef var_ptr False e
	# (letdef_ptr, heaps)							= newPointer letdef heaps
	= ([letdef_ptr:defs], [LExprVar var_ptr (Just letdef_ptr):es], heaps)
shareExprs n [] heaps
	= ([], [], heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
shareNamedExprs :: !Int ![CExprVarPtr] ![LExpr] !*CHeaps -> (![LLetDefPtr], ![LExpr], !*CHeaps)
// -------------------------------------------------------------------------------------------------------------------------------------------------
shareNamedExprs nr_fixed_rnfs [ptr:ptrs] [e:es] heaps
	# (defs, es, heaps)								= shareNamedExprs (nr_fixed_rnfs-1) ptrs es heaps
	| nr_fixed_rnfs > 0 || SNF e					= (defs, [e:es], heaps)
	# (name, heaps)									= getPointerName ptr heaps
	# var											= {evarName = name, evarInfo = DummyValue}
	# (var_ptr, heaps)								= newPointer var heaps
	# letdef										= LLetDef var_ptr False e
	# (letdef_ptr, heaps)							= newPointer letdef heaps
	= ([letdef_ptr:defs], [LExprVar var_ptr (Just letdef_ptr):es], heaps)
shareNamedExprs _ _ [] heaps
	= ([], [], heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
SNF :: !LExpr -> Bool
// -------------------------------------------------------------------------------------------------------------------------------------------------
SNF (LExprVar _ _)									= True
SNF (LBasicValue (LBasicArray es))					= and (map SNF es)
SNF (LBasicValue _)									= True
SNF (LSymbol (LCons i) _ LTotal es)					= SNF_args i.lciAnnotatedStrictVars es
SNF (LSymbol _         _ LTotal _)					= False
SNF (LSymbol _         _ _      es)					= and (map SNF es)
SNF LBottom											= True
SNF _												= False

// -------------------------------------------------------------------------------------------------------------------------------------------------
SNF_args :: !LListOfBool ![LExpr] -> Bool
// -------------------------------------------------------------------------------------------------------------------------------------------------
SNF_args s []										= True
SNF_args s [e:es]
	| isOdd s										= SNF e && e <> LBottom && SNF_args (s >> 1) es
	| otherwise										= SNF e && SNF_args (s >> 1) es















// -------------------------------------------------------------------------------------------------------------------------------------------------
class reduce e
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	reduceNF :: !LNrSteps !e !LReductionEnv !*CHeaps !*CProject -> (!LNrSteps, !e, !*CHeaps, !*CProject)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance reduce [e] | reduce e
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	reduceNF n [e:es] env heaps prj
		# (n, e, heaps, prj)						= reduceNF n e env heaps prj
		# (n, es, heaps, prj)						= reduceNF n es env heaps prj
		= (n, [e:es], heaps, prj)
	reduceNF n [] env heaps prj
		= (n, [], heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance reduce (Maybe e) | reduce e
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	reduceNF n (Just e) env heaps prj
		# (n, e, heaps, prj)						= reduceNF n e env heaps prj
		= (n, Just e, heaps, prj)
	reduceNF n Nothing env heaps prj
		= (n, Nothing, heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance reduce LAlgPattern
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	reduceNF n pattern env heaps prj
		# (n, result, heaps, prj)					= reduceNF n pattern.lapResult env heaps prj
		= (n, {pattern & lapResult = result}, heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance reduce LBasicPattern
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	reduceNF n pattern env heaps prj
		# (n, result, heaps, prj)					= reduceNF n pattern.lbpResult env heaps prj
		= (n, {pattern & lbpResult = result}, heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance reduce LBasicValue
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	reduceNF n (LBasicArray es) env heaps prj
		# (n, es, heaps, prj)						= reduceNF n es env heaps prj
		= (n, LBasicArray es, heaps, prj)
	reduceNF n basic_value env heaps prj
		= (n, basic_value, heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance reduce LCasePatterns
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	reduceNF n (LAlgPatterns type patterns) env heaps prj
		# (n, patterns, heaps, prj)					= reduceNF n patterns env heaps prj
		= (n, LAlgPatterns type patterns, heaps, prj)
	reduceNF n (LBasicPatterns type patterns) env heaps prj
		# (n, patterns, heaps, prj)					= reduceNF n patterns env heaps prj
		= (n, LBasicPatterns type patterns, heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance reduce LExpr
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	reduceNF n e env heaps prj
		# (n, e, heaps, prj)						= reduceRNF n e env heaps prj
		= continue n e env heaps prj
		where
			continue_let n (LLetDef var mu e) env heaps prj
				# (n, e, heaps, prj)				= reduceNF n e env heaps prj
				= (n, LLetDef var mu e, heaps, prj)
			continue_let n LStrictLetDef env heaps prj
				= (n, LStrictLetDef, heaps, prj)

			continue n var_e=:(LExprVar var (Just ptr)) env heaps prj
				| isMember ptr env.envOpenedVars	= (n, var_e, heaps, prj)
				# (letdef, heaps)					= readPointer ptr heaps
				# (n, letdef, heaps, prj)			= continue_let n letdef {env & envOpenedVars = [ptr:env.envOpenedVars]} heaps prj
				# heaps								= writePointer ptr letdef heaps
				= (n, var_e, heaps, prj)
			continue n (LBasicValue v) env heaps prj
				# (n, v, heaps, prj)				= reduceNF n v env heaps prj
				= (n, LBasicValue v, heaps, prj)
			continue n (LSymbol kind ptr i es) env heaps prj
				# (n, es, heaps, prj)				= reduceNF n es env heaps prj
				= (n, LSymbol kind ptr i es, heaps, prj)
			continue n (LApp e1 e2) env heaps prj
				# (n, e1, heaps, prj)				= reduceNF n e1 env heaps prj
				# (n, e2, heaps, prj)				= reduceNF n e2 env heaps prj
				= (n, LApp e1 e2, heaps, prj)
			continue n (LCase e patterns mb_def) env heaps prj
				# (n, e, heaps, prj)				= reduceNF n e env heaps prj
				# (n, patterns, heaps, prj)			= reduceNF n patterns env heaps prj
				# (n, mb_def, heaps, prj)			= reduceNF n mb_def env heaps prj
				= (n, LCase e patterns mb_def, heaps, prj)
			// BEZIG.
			// Still to add: afterwards let lifting, afterwards garbage collection
			continue n (LLazyLet ptrs e) env heaps prj
				# (lets, heaps)						= readPointers ptrs heaps
				# heaps								= writePointers ptrs (repeat LStrictLetDef) heaps
				# (n, lets, heaps, prj)				= reduceNF n lets env heaps prj
				# heaps								= writePointers ptrs lets heaps
				# (n, e, heaps, prj)				= reduceNF n e env heaps prj
				// afterwards: manual let lifting
				# (lets, heaps)						= readPointers ptrs heaps
				# (ptrs, lets, heaps)				= manual_lift ptrs lets heaps
				# heaps								= writePointers ptrs lets heaps
				// afterwards: garbage collection
				# (n, ptrs, e, heaps, prj)			= garbageCollectE n ptrs e heaps prj
				| isEmpty ptrs						= (n, e, heaps, prj)
				= (n, LLazyLet ptrs e, heaps, prj)
				where
					manual_lift [ptr:ptrs] [LLetDef var mu (LLazyLet ptrsE e): lets] heaps
						# (letsE, heaps)			= readPointers ptrsE heaps
						# (ptrs, lets, heaps)		= manual_lift ptrs lets heaps
						= ([ptr:ptrsE++ptrs], [LLetDef var mu e: letsE++lets], heaps)
					manual_lift [ptr:ptrs] [l:lets] heaps
						# (ptrs, lets, heaps)		= manual_lift ptrs lets heaps
						= ([ptr:ptrs], [l:lets], heaps)
					manual_lift [] [] heaps
						= ([], [], heaps)
			continue n (LStrictLet var ptr e1 e2) env heaps prj
				# (n, e1, heaps, prj)				= reduceNF n e1 env heaps prj
				# (n, e2, heaps, prj)				= reduceNF n e2 env heaps prj
				= (n, LStrictLet var ptr e1 e2, heaps, prj)
			continue n e env heaps prj
				= (n, e, heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance reduce LLetDef
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	reduceNF n (LLetDef var False e) env heaps prj
		# (n, e, heaps, prj)						= reduceNF n e env heaps prj
		= (n, LLetDef var False e, heaps, prj)
	reduceNF n other env heaps prj
		= (n, other, heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
reduceRNF :: !LNrSteps !LExpr !LReductionEnv !*CHeaps !*CProject -> (!LNrSteps, !LExpr, !*CHeaps, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------
reduceRNF n e env heaps prj
	# empty_ls										= {innerLets = [], outerLets = [], innerLetsDepth = (-1)}
	# (n, ls, (_, _, e), heaps, prj)				= reduceExpr n empty_ls 0 e env heaps prj
	# (n, lets, e, heaps, prj)						= garbageCollectE n ls.outerLets e heaps prj
	# e												= if (isEmpty lets) e (LLazyLet lets e)
	= (n, e, heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
LReduce :: ![LExpr] !ReduceMode !LReduceTo !LNrSteps !LExpr !*CHeaps !*CProject -> (!(!LNrSteps, !LExpr), !*CHeaps, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------
LReduce defs mode reduce_to n e heaps prj
	# env											=	{ envDefined				= defs
														, envReduceMode				= mode
														, envOpenedVars				= []
														}
	# (n, e, heaps, prj)							= case reduce_to of
														LToRNF	-> reduceRNF n e env heaps prj
														LToNF	-> reduceNF n e env heaps prj
	= ((n,e), heaps, prj)