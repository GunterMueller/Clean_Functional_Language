/*
** Program: Clean Prover System
** Module:  Rewrite (.icl)
** 
** Author:  Maarten de Mol
** Created: 23 August 2000
*/

implementation module 
	Rewrite

import
	StdEnv,
	DynArray,
	CoreTypes,
	CoreAccess,
	ProveTypes,
	Print,
	Heaps,
	Operate,
	States,
	RWSDebug

// -------------------------------------------------------------------------------------------------------------------------------------------------
areMembers :: ![CExprVarPtr] ![CExprVarPtr] -> Bool
// -------------------------------------------------------------------------------------------------------------------------------------------------
areMembers [ptr:ptrs] all_ptrs
	| isMember ptr all_ptrs				= areMembers ptrs all_ptrs
	= False
areMembers [] all_ptrs
	= True










// -------------------------------------------------------------------------------------------------------------------------------------------------
:: ReductionStatus 
// -------------------------------------------------------------------------------------------------------------------------------------------------
	= NotReducable							// root normal form found (but not bottom)
	| UndefinedForm							// bottom
	| VariableForm							// always stop reduction (also used for opaque functions)
	| MaybeVariableForm	![CExprVarPtr]		// check if all variables occur in options.roDefined (only in function reduction)
	| ReducedOnce							// only used in ReduceStep
instance DummyValue ReductionStatus
	where DummyValue = NotReducable
instance == ReductionStatus
	where	(==) NotReducable			NotReducable			= True
			(==) UndefinedForm			UndefinedForm			= True
			(==) VariableForm			VariableForm			= True
			(==) (MaybeVariableForm _)	(MaybeVariableForm _)	= True
			(==) ReducedOnce			ReducedOnce				= True
			(==) _						_						= False

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: ReductionOptions =
// -------------------------------------------------------------------------------------------------------------------------------------------------
	{ roAmount							:: !ReduceAmount
	, roMode							:: !ReduceMode
	, roDefinedVariables				:: ![CExprVarPtr]
	, roDefinedExpressions				:: ![CExprH]
	}











// =================================================================================================================================================
// Remark: dictionaries are only shared in 'AsInClean' mode.
// -------------------------------------------------------------------------------------------------------------------------------------------------
fillinFun :: !ReduceMode !CFunDefH ![CExprH] !*CHeaps !*CProject -> (!CExprH, !*CHeaps, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------
fillinFun AsInClean fundef exprs heaps prj
	# (args, extra_args)						= splitAt fundef.fdArity exprs
	# (varnames, heaps)							= getPointerNames fundef.fdExprVarScope heaps
	# (args, heaps)								= share args varnames heaps
	# heaps										= setInfos fundef.fdExprVarScope args heaps
	#! (body, heaps)							= unsafeSubst fundef.fdBody heaps
	#! heaps									= wipePointerInfos fundef.fdExprVarScope heaps
	| isEmpty extra_args
		= (body, heaps, prj)
		= (body @# extra_args, heaps, prj)
	where
		setInfos :: ![CExprVarPtr] ![CExprH] !*CHeaps -> *CHeaps
		setInfos [ptr:ptrs] [expr:exprs] heaps
			# (var, heaps)						= readPointer ptr heaps
			# var								= {var & evarInfo = EVar_Subst expr}
			# heaps								= writePointer ptr var heaps
			= setInfos ptrs exprs heaps
		setInfos [] [] heaps
			= heaps
fillinFun _ fundef exprs heaps prj
	# (args, extra_args)						= splitAt fundef.fdArity exprs
	# nr_dicts									= fundef.fdNrDictionaries
	# (dict_args, normal_args)					= splitAt nr_dicts args
	# (varnames, heaps)							= getPointerNames fundef.fdExprVarScope heaps
	# (_, varnames)								= splitAt nr_dicts varnames
	# (normal_args, heaps)						= share normal_args varnames heaps
	#! heaps									= setInfos fundef.fdExprVarScope (dict_args ++ normal_args) heaps
	#! (body, heaps)							= unsafeSubst fundef.fdBody heaps
	#! (body, heaps, prj)						= removeDictSelections body heaps prj
	#! heaps									= wipePointerInfos fundef.fdExprVarScope heaps
	| isEmpty extra_args
		= (body, heaps, prj)
		= (body @# extra_args, heaps, prj)
	where
		setInfos :: ![CExprVarPtr] ![CExprH] !*CHeaps -> *CHeaps
		setInfos [ptr:ptrs] [expr:exprs] heaps
			#! (var, heaps)						= readPointer ptr heaps
			#! var								= {var & evarInfo = EVar_Subst expr}
			#! heaps							= writePointer ptr var heaps
			= setInfos ptrs exprs heaps
		setInfos [] [] heaps
			= heaps

// =================================================================================================================================================
// In case of special reduction, the arity is determined by examining the function type.
// Otherwise the usual arity is returned.
// (EXAMPLE: The 'real' arity of (o) will be 3 instead of 2.)
// -------------------------------------------------------------------------------------------------------------------------------------------------
getRealArity :: !ReduceMode !CFunDefH -> Int
// -------------------------------------------------------------------------------------------------------------------------------------------------
getRealArity AsInClean fundef
	= fundef.fdArity
getRealArity _ fundef
	# normal_arity							= fundef.fdArity
	# extra_arity							= get_arity fundef.fdSymbolType.sytResult
	= normal_arity + extra_arity
	where
		get_arity :: !CTypeH -> Int
		get_arity (CStrict type)
			= get_arity type
		get_arity (type1 ==> type2)
			= 1 + get_arity type2
		get_arity type
			= 0

// =================================================================================================================================================
// Shares a list of expressions. Uses generated names. Handles recursive dependencies.
// -------------------------------------------------------------------------------------------------------------------------------------------------
shareLets :: ![CExprVarPtr] ![CExprH] !*CHeaps -> (!Substitution, !*CHeaps)
// -------------------------------------------------------------------------------------------------------------------------------------------------
shareLets var_ptrs exprs heaps
	# (shared_ptrs, exprs, subst, heaps)	= build_shared var_ptrs exprs DummyValue heaps
	# (exprs, heaps)						= UnsafeSubst subst exprs heaps
	# heaps									= write_shared shared_ptrs exprs heaps
	= (subst, heaps)
	where
		build_shared :: ![CExprVarPtr] ![CExprH] !Substitution !*CHeaps -> (![CSharedPtr], ![CExprH], !Substitution, !*CHeaps)
		build_shared [ptr:ptrs] [expr:exprs] subst heaps
			# (ptrs, exprs, subst, heaps)	= build_shared ptrs exprs subst heaps
			| not (sharable expr)
				# subst						= {subst & subExprVars = [(ptr,expr):subst.subExprVars]}
				= (ptrs, exprs, subst, heaps)
//			| sharable expr
				# shared					= {shName = "@", shExpr = DummyValue, shPassed = False}
				# (new_ptr, heaps)			= newPointer shared heaps
				# subst						= {subst & subExprVars = [(ptr,CShared new_ptr):subst.subExprVars]}
				= ([new_ptr:ptrs], [expr:exprs], subst, heaps)
		build_shared [] [] subst heaps
			= ([], [], subst, heaps)
		
		write_shared :: ![CSharedPtr] ![CExprH] !*CHeaps -> *CHeaps
		write_shared [ptr:ptrs] [expr:exprs] heaps
			# (shared, heaps)				= readPointer ptr heaps
			# shared						= {shared & shExpr = expr}
			# heaps							= writePointer ptr shared heaps
			= write_shared ptrs exprs heaps
		write_shared [] [] heaps
			= heaps


// -------------------------------------------------------------------------------------------------------------------------------------------------   
FindStrictArgs :: !CSymbolTypeH -> [Int]
// -------------------------------------------------------------------------------------------------------------------------------------------------   
FindStrictArgs symboltype
	# indexed					= zip2 symboltype.sytArguments (indexList symboltype.sytArguments)
	# filtered					= filter (\(type,index) -> isStrict type) indexed
	= map snd filtered
	where
		isStrict :: !CTypeH -> Bool
		isStrict (CStrict type)		= True
		isStrict other				= False











// -------------------------------------------------------------------------------------------------------------------------------------------------   
// Attempts to reduce to root normal form.
// A root normal form is either:
// - a basic value;
// - a partial application of any symbol;
// - a total application of a constructor, but only if all strict arguments are in root normal form themselves;
// - the undefined expression.
// -------------------------------------------------------------------------------------------------------------------------------------------------   
ReduceRNF :: !Int !ReductionOptions !CExprH !*CHeaps !*CProject -> (!Error, !(!Int, !Bool, !CExprH), !*CHeaps, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------   
ReduceRNF 0 options expr heaps prj
	= ([X_Reduction "Passed reduction bounds."], (-1, False, expr), heaps, prj)
ReduceRNF n options expr=:(CExprVar ptr) heaps prj
	= (OK, (n, False, expr), heaps, prj)
ReduceRNF n options (CShared ptr) heaps prj
	#! (shared, heaps)							= readPointer ptr heaps
	| shared.shName == "__cycle"				= (OK, (n-1, True, CBottom), heaps, prj)
	# old_name									= shared.shName
	# shared									= {shared & shName = "__cycle"}
	#! heaps									= writePointer ptr shared heaps
	#! (error, (n, rnf, expr), heaps, prj)		= ReduceRNF n options shared.shExpr heaps prj
	# shared									= {shared & shName = old_name, shExpr = expr}
	#! heaps									= writePointer ptr shared heaps
	| isError error								= (error, (n, False, CShared ptr), heaps, prj)
	| not rnf									= (OK, (n, False, CShared ptr), heaps, prj)
	= case expr of
		symbol_ptr @@# args						-> let	(shared_args, heaps2)	= shareI args heaps
														new_expr				= symbol_ptr @@# shared_args
														new_shared				= {shName = old_name, shExpr = new_expr, shPassed = False}
														heaps3					= writePointer ptr new_shared heaps2
													in	(OK, (n, True, new_expr), heaps2, prj)
		_										-> (OK, (n, True, expr), heaps, prj)
ReduceRNF n options (expr @# []) heaps prj
	= ReduceRNF (n-1) options expr heaps prj
ReduceRNF n options (expr @# exprs) heaps prj
	# (error, (n, rnf, expr), heaps, prj)		= ReduceRNF n options expr heaps prj
	| isError error								= (error, (n, False, expr @# exprs), heaps, prj)
	| not rnf									= (OK, (n, False, expr @# exprs), heaps, prj)
	= case expr of
		ptr @@# args							-> case n of
														0	-> ([X_Reduction "Passed reduction bounds."], (-1, False, expr @# exprs), heaps, prj)
														_	-> ReduceRNF (n-1) options (ptr @@# (args ++ exprs)) heaps prj
		_										-> (OK, (n, False, expr @# exprs), heaps, prj)
ReduceRNF n options expr=:(ptr @@# args) heaps prj
	| ptrKind ptr == CFun
		# (error, fundef, prj)					= getFunDef ptr prj
		| isError error							= ([X_Reduction "Invalid function pointer encountered."], (n, False, expr), heaps, prj)
		= reduce_fun n ptr fundef args heaps prj
	| ptrKind ptr == CDataCons
		# (error, consdef, prj)					= getDataConsDef ptr prj
		| isError error							= ([X_Reduction "Invalid constructor pointer encountered."], (n, False, expr), heaps, prj)
		= reduce_cons n ptr consdef args heaps prj
	= ([X_Reduction "Invalid <other> pointer encountered."], (n, False, expr), heaps, prj)
	where
		reduce_cons :: !Int !HeapPtr !CDataConsDefH ![CExprH] !*CHeaps !*CProject -> (!Error, !(!Int, !Bool, !CExprH), !*CHeaps, !*CProject)
		reduce_cons n ptr consdef args heaps prj
			| consdef.dcdArity > length args			= (OK, (n, True, expr), heaps, prj)
			# (error, (n, unf, def, args), heaps, prj)	= reduce_cons_args n consdef.dcdSymbolType.sytArguments args heaps prj
			| isError error								= (error, (n, False, ptr @@# args), heaps, prj)
			| unf
				| n == 0							= ([X_Reduction "Passed reduction bounds."], (-1, False, ptr @@# args), heaps, prj)
													= (OK, (n-1, True, CBottom), heaps, prj)
			= (OK, (n, def, ptr @@# args), heaps, prj)
	
		reduce_cons_args :: !Int ![CTypeH] ![CExprH] !*CHeaps !*CProject -> (!Error, !(!Int, !Bool, !Bool, ![CExprH]), !*CHeaps, !*CProject)
		reduce_cons_args 0 types exprs heaps prj
			= ([X_Reduction "Passed reduction bounds."], (-1, False, False, exprs), heaps, prj)
		reduce_cons_args n types [] heaps prj
			= (OK, (n, False, True, []), heaps, prj)
		reduce_cons_args n [] args heaps prj
			= (OK, (n, False, True, args), heaps, prj)
		reduce_cons_args n [CStrict _:types] [arg:args] heaps prj
			# (error, (n, rnf, arg), heaps, prj)		= ReduceRNF n options arg heaps prj
			| isError error								= (error, (n, False, False, [arg:args]), heaps, prj)
			| rnf && arg == CBottom						= (OK, (n, True, False, [arg:args]), heaps, prj)
			# def1										= rnf || isMember arg options.roDefinedExpressions
			# (error, (n, unf, def2, args), heaps, prj)	= reduce_cons_args n types args heaps prj
			= (error, (n, unf, def1 && def2, [arg:args]), heaps, prj)
		reduce_cons_args n [_:types] [arg:args] heaps prj
			# (error, (n, unf, def, args), heaps, prj)	= reduce_cons_args n types args heaps prj
			= (error, (n, unf, def, [arg:args]), heaps, prj)
		
		reduce_fun :: !Int !HeapPtr !CFunDefH ![CExprH] !*CHeaps !*CProject -> (!Error, !(!Int, !Bool, !CExprH), !*CHeaps, !*CProject)
		reduce_fun n ptr fundef args heaps prj
			# real_arity								= getRealArity options.roMode fundef
			| real_arity > length args					= (OK, (n, True, expr), heaps, prj)
			# (error, (n, unf, exp, args), heaps, prj)	= reduce_fun_args 0 fundef.fdCaseVariables fundef.fdStrictVariables n fundef.fdSymbolType.sytArguments args heaps prj
			| isError error								= (error, (n, False, ptr @@# args), heaps, prj)
			| not exp || fundef.fdOpaque				= (OK, (n, False, ptr @@# args), heaps, prj)
			| n == 0									= ([X_Reduction "Passed reduction bounds."], (-1, False, ptr @@# args), heaps, prj)
			| unf										= (OK, (n-1, True, CBottom), heaps, prj)
			| fundef.fdIsDeltaRule
				# (largs, heaps, prj)					= convertC2L args heaps prj
				# lexpr									= fundef.fdDeltaRule largs
				# (expr, heaps, prj)					= convertL2C lexpr heaps prj
				= ReduceRNF (n-1) options expr heaps prj
			# (expr, heaps, prj)						= fillinFun options.roMode fundef args heaps prj
			= ReduceRNF (n-1) options expr heaps prj
	
		reduce_fun_args :: !Int ![Int] ![Int] !Int ![CTypeH] ![CExprH] !*CHeaps !*CProject -> (!Error, !(!Int, !Bool, !Bool, ![CExprH]), !*CHeaps, !*CProject)
		reduce_fun_args index case_vars strict_vars 0 types args heaps prj
			= ([X_Reduction "Passed reduction bounds."], (-1, False, False, args), heaps, prj)
		reduce_fun_args index case_vars strict_vars n types [] heaps prj
			= (OK, (n, False, True, []), heaps, prj)
		reduce_fun_args index case_vars strict_vars n [] args heaps prj
			= (OK, (n, False, True, args), heaps, prj)
		reduce_fun_args index case_vars strict_vars n [CStrict _:types] [arg:args] heaps prj
			# (error, (n, rnf, arg), heaps, prj)		= ReduceRNF n options arg heaps prj
			| isError error								= (error, (n, False, False, [arg:args]), heaps, prj)
			| rnf && arg == CBottom						= (OK, (n, True, True, [arg:args]), heaps, prj)
			# strict_arg								= isMember index strict_vars		// is arg mathematically strict
			# case_arg									= isMember index case_vars			// is a case distinction performed
			# defined_arg								= isMember arg options.roDefinedExpressions
			# exp_arg									= rnf || case options.roMode of
																	AsInClean	-> False
																	Defensive	-> (not case_arg) && (strict_arg || defined_arg)
																	Offensive	-> strict_arg || defined_arg
			# (error, (n, unf, exp_args, args), heaps, prj)		= reduce_fun_args (index+1) case_vars strict_vars n types args heaps prj
			= (error, (n, unf, unf || (exp_arg && exp_args), [arg:args]), heaps, prj)
		reduce_fun_args index case_vars strict_vars n [type:types] [arg:args] heaps prj
			// warning for line below: bottom arg will reduce application to bottom now!
			| isMember index case_vars					= reduce_fun_args index case_vars strict_vars n [CStrict type:types] [arg:args] heaps prj
			# (error, (n, unf, exp_args, args), heaps, prj)	
														= reduce_fun_args (index+1) case_vars strict_vars n types args heaps prj
			= (error, (n, unf, exp_args, [arg:args]), heaps, prj)
ReduceRNF n options (CLet True [(var,expr)] let_expr) heaps prj
	# (error, (n, rnf, expr), heaps, prj)		= ReduceRNF n options expr heaps prj
	| isError error								= (error, (n, False, CLet True [(var,expr)] let_expr), heaps, prj)
	| rnf && expr == CBottom
		| n == 0								= ([X_Reduction "Passed reduction bounds."], (-1, False, CLet True [(var,expr)] let_expr), heaps, prj)
												= (OK, (n-1, True, CBottom), heaps, prj)
	# may_expand								= rnf || case options.roMode of
															AsInClean	-> False
															_			-> isMember expr options.roDefinedExpressions
	| not may_expand							= (OK, (n, False, CLet True [(var,expr)] let_expr), heaps, prj)
	| n == 0									= ([X_Reduction "Passed reduction bounds."], (-1, False, CLet True [(var,expr)] let_expr), heaps, prj)
	# (subst, heaps)							= shareLets [var] [expr] heaps
	# (let_expr, heaps)							= SafeSubst subst let_expr heaps
	= ReduceRNF (n-1) options let_expr heaps prj
ReduceRNF n options (CLet False lets let_expr) heaps prj
	# (vars, exprs)								= unzip lets
	# (subst, heaps)							= shareLets vars exprs heaps
	# (let_expr, heaps)							= SafeSubst subst let_expr heaps
	= ReduceRNF (n-1) options let_expr heaps prj
ReduceRNF n options (CCase expr patterns maybe_default) heaps prj
	# (error, (n, rnf, expr), heaps, prj)		= ReduceRNF n options expr heaps prj
	| isError error								= (error, (n, False, CCase expr patterns maybe_default), heaps, prj)
	| not rnf									= (OK, (n, False, CCase expr patterns maybe_default), heaps, prj)
	| n == 0									= ([X_Reduction "Passed reduction bounds."], (-1, False, CCase expr patterns maybe_default), heaps, prj)
	| expr == CBottom							= (OK, (n-1, True, CBottom), heaps, prj)
	= match_patterns n expr patterns maybe_default heaps prj
	where
		match_patterns :: !Int !CExprH !CCasePatternsH !(Maybe CExprH) !*CHeaps !*CProject -> (!Error, !(!Int, !Bool, !CExprH), !*CHeaps, !*CProject)
		match_patterns n (CBasicValue value) (CBasicPatterns _ patterns) maybe_default heaps prj
			= match_basic n value patterns maybe_default heaps prj
		match_patterns n (ptr @@# args) (CAlgPatterns _ patterns) maybe_default heaps prj
			= match_cons n ptr args patterns maybe_default heaps prj
		match_patterns n _ _ _ heaps prj
			= (OK, (n-1, True, CBottom), heaps, prj)
		
		match_basic :: !Int !CBasicValueH ![CBasicPatternH] !(Maybe CExprH) !*CHeaps !*CProject -> (!Error, !(!Int, !Bool, !CExprH), !*CHeaps, !*CProject)
		match_basic n value [pattern:patterns] maybe_default heaps prj
			| value <> pattern.bapBasicValue	= match_basic n value patterns maybe_default heaps prj
			= ReduceRNF (n-1) options pattern.bapResult heaps prj
		match_basic n _ [] (Just expr) heaps prj
			= ReduceRNF (n-1) options expr heaps prj
		match_basic n _ [] Nothing heaps prj
			= (OK, (n-1, True, CBottom), heaps, prj)
		
		match_cons :: !Int !HeapPtr ![CExprH] ![CAlgPatternH] !(Maybe CExprH) !*CHeaps !*CProject -> (!Error, !(!Int, !Bool, !CExprH), !*CHeaps, !*CProject)
		match_cons n ptr args [pattern:patterns] maybe_default heaps prj
			| ptr <> pattern.atpDataCons		= match_cons n ptr args patterns maybe_default heaps prj
			# (varnames, heaps)					= getPointerNames pattern.atpExprVarScope heaps
			# (args, heaps)						= share args varnames heaps
			# subE								= zip2 pattern.atpExprVarScope args
			#! (result, heaps)					= UnsafeSubst {DummyValue & subExprVars = subE} pattern.atpResult heaps
			= ReduceRNF (n-1) options result heaps prj
		match_cons n _ _ [] (Just expr) heaps prj
			= ReduceRNF (n-1) options expr heaps prj
		match_cons n _ _ [] Nothing heaps prj
			= (OK, (n-1, True, CBottom), heaps, prj)
ReduceRNF n options expr=:(CBasicValue value) heaps prj
	= (OK, (n, True, expr), heaps, prj)
ReduceRNF n options expr=:(CCode _ _) heaps prj
	= ([X_Reduction "Encountered ABC-code."], (n, False, expr), heaps, prj)
ReduceRNF n options expr=:CBottom heaps prj
	= (OK, (n, True, expr), heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------   
// Attempts to reduce to full normal form.
// Method: repeated application of ReduceRNF.
// Note that this process does not always terminate, therefore the bounding integer argument.
// -------------------------------------------------------------------------------------------------------------------------------------------------   
ReduceNF :: !Int !ReductionOptions !CExprH !*CHeaps !*CProject -> (!Error, !(!Int, !CExprH), !*CHeaps, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------   
ReduceNF n options expr heaps prj
	# (error, (n, _, expr), heaps, prj)			= ReduceRNF n options expr heaps prj
	| isError error								= (error, (n, expr), heaps, prj)
	= continueReduce False n options expr heaps prj

// -------------------------------------------------------------------------------------------------------------------------------------------------   
class continueReduce a
// -------------------------------------------------------------------------------------------------------------------------------------------------   
where
	continueReduce :: !Bool !Int !ReductionOptions !a !*CHeaps !*CProject -> (!Error, !(!Int, !a), !*CHeaps, !*CProject)

// -------------------------------------------------------------------------------------------------------------------------------------------------   
instance continueReduce (a,b) | continueReduce b
// -------------------------------------------------------------------------------------------------------------------------------------------------   
where
	continueReduce _ n options (x,y) heaps prj
		# (error, (n, y), heaps, prj)			= continueReduce True n options y heaps prj
		= (error, (n, (x,y)), heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------   
instance continueReduce [a] | continueReduce a
// -------------------------------------------------------------------------------------------------------------------------------------------------   
where
	continueReduce _ n options [x:xs] heaps prj
		# (error, (n, x), heaps, prj)			= continueReduce True n options x heaps prj
		| isError error							= (error, (n, [x:xs]), heaps, prj)
		# (error, (n, xs), heaps, prj)			= continueReduce True n options xs heaps prj
		= (error, (n, [x:xs]), heaps, prj)
	continueReduce _ n options [] heaps prj
		= (OK, (n, []), heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------   
instance continueReduce (Maybe a) | continueReduce a
// -------------------------------------------------------------------------------------------------------------------------------------------------   
where
	continueReduce _ n options (Just x) heaps prj
		# (error, (n, x), heaps, prj)			= continueReduce True n options x heaps prj
		= (error, (n, Just x), heaps, prj)
	continueReduce _ n options Nothing heaps prj
		= (OK, (n, Nothing), heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------   
instance continueReduce (CAlgPattern HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------   
where
	continueReduce _ n options pattern heaps prj
		# (error, (n, result), heaps, prj)		= continueReduce True n options pattern.atpResult heaps prj
		# pattern								= {pattern & atpResult = result}
		= (error, (n, pattern), heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------   
instance continueReduce (CBasicPattern HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------   
where
	continueReduce _ n options pattern heaps prj
		# (error, (n, result), heaps, prj)		= continueReduce True n options pattern.bapResult heaps prj
		# pattern								= {pattern & bapResult = result}
		= (error, (n, pattern), heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------   
instance continueReduce (CCasePatterns HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------   
where
	continueReduce _ n options (CAlgPatterns type patterns) heaps prj
		# (error, (n, patterns), heaps, prj)	= continueReduce True n options patterns heaps prj
		= (error, (n, CAlgPatterns type patterns), heaps, prj)
	continueReduce _ n options (CBasicPatterns type patterns) heaps prj
		# (error, (n, patterns), heaps, prj)	= continueReduce True n options patterns heaps prj
		= (error, (n, CBasicPatterns type patterns), heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------   
instance continueReduce (CExpr HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------   
where
	continueReduce False n options (CBasicValue (CBasicArray exprs)) heaps prj
		# (error, (n, exprs), heaps, prj)		= continueReduce True n options exprs heaps prj
		= (error, (n, CBasicValue (CBasicArray exprs)), heaps, prj)
	continueReduce False n options (expr @# exprs) heaps prj
		# (error, (n, expr), heaps, prj)		= continueReduce True n options expr heaps prj
		| isError error							= (error, (n, expr @# exprs), heaps, prj)
		# (error, (n, exprs), heaps, prj)		= continueReduce True n options exprs heaps prj
		= (OK, (n, expr @# exprs), heaps, prj)
	continueReduce False n options (ptr @@# args) heaps prj
		# (error, (n, args), heaps, prj)		= continueReduce True n options args heaps prj
		= (error, (n, ptr @@# args), heaps, prj)
	continueReduce False n options (CCase expr patterns mb_default) heaps prj
		# (error, (n, expr), heaps, prj)		= continueReduce True n options expr heaps prj
		| isError error							= (error, (n, CCase expr patterns mb_default), heaps, prj)
		# (error, (n, patterns), heaps, prj)	= continueReduce True n options patterns heaps prj
		| isError error							= (error, (n, CCase expr patterns mb_default), heaps, prj)
		# (error, (n, mb_default), heaps, prj)	= continueReduce True n options mb_default heaps prj
		= (error, (n, CCase expr patterns mb_default), heaps, prj)
	continueReduce False n options (CLet strict lets expr) heaps prj
		# (error, (n, lets), heaps, prj)		= continueReduce True n options lets heaps prj
		| isError error							= (error, (n, CLet strict lets expr), heaps, prj)
		# (error, (n, expr), heaps, prj)		= continueReduce True n options expr heaps prj
		= (error, (n, CLet strict lets expr), heaps, prj)
	continueReduce False n options (CShared ptr) heaps prj
		#! (shared, heaps)						= readPointer ptr heaps
		#! heaps								= writePointer ptr {shared & shExpr = CExprVar nilPtr} heaps
		# (error, (n, expr), heaps, prj)		= continueReduce True n options shared.shExpr heaps prj
		#! heaps								= writePointer ptr {shared & shExpr = expr} heaps
		= (error, (n, CShared ptr), heaps, prj)
	continueReduce False n options other heaps prj
		= (OK, (n, other), heaps, prj)
	continueReduce True n options expr heaps prj
		= ReduceNF n options expr heaps prj

// -------------------------------------------------------------------------------------------------------------------------------------------------   
ReduceSteps :: !Int !ReductionOptions !CExprH !*CHeaps !*CProject -> (!Error, !(!Bool, !CExprH), !*CHeaps, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------   
ReduceSteps n1 options expr heaps prj
//	# (error, (n2, _, expr), heaps, prj)		= ReduceRNF n1 options expr heaps prj
	# (error, (n2, expr), heaps, prj)			= ReduceNF n1 options expr heaps prj
	| n2 < 0									= (OK, (True, expr), heaps, prj)
	| isError error								= (error, (False, expr), heaps, prj)
	= (OK, (n2 < n1, expr), heaps, prj)












































/*
// =================================================================================================================================================
// ReduceStep puts an expression in a strict-context and reduces it one step.
// NOTE: The following situation may NEVER occur:
//       (OK, (NotReducable, SharedPtr, env), prj)
//       If NotReducable is returned, the top-level sharing must always be broken!!!!
// -------------------------------------------------------------------------------------------------------------------------------------------------   
ReduceStep :: !ReductionOptions !CExprH !*CHeaps !*CProject -> (!Error, !(!ReductionStatus, !CExprH), !*CHeaps, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------   
ReduceStep options (CExprVar ptr) heaps prj
	= (OK, (MaybeVariableForm [ptr], CExprVar ptr), heaps, prj)
ReduceStep options (CShared ptr) heaps prj
	#! (shared, heaps)						= readPointer ptr heaps
	| shared.shName == "__cycle"			= (OK, (ReducedOnce, CBottom), heaps, prj)
	# old_name								= shared.shName
	# shared								= {shared & shName = "__cycle"}
	#! heaps								= writePointer ptr shared heaps
	#! (error, (status, expr), heaps, prj)	= ReduceStep options shared.shExpr heaps prj
	# shared								= {shared & shName = old_name, shExpr = expr}
	#! heaps								= writePointer ptr shared heaps
	| isError error							= (error, (DummyValue, CShared ptr), heaps, prj)
	= case status of
		NotReducable						-> let (new_expr, new_heaps) = unshareCons ptr shared heaps
												in (OK, (status, new_expr), new_heaps, prj)		// partially remove sharing
		UndefinedForm						-> (OK, (status, CBottom), heaps, prj)				// remove sharing
		VariableForm						-> (OK, (status, shared.shExpr), heaps, prj)		// remove sharing
		(MaybeVariableForm ptrs)			-> (OK, (status, shared.shExpr), heaps, prj)		// remove sharing
		ReducedOnce							-> (OK, (status, CShared ptr), heaps, prj)			// maintain sharing
ReduceStep options (expr @# exprs) heaps prj
	#! (error, (status, expr), heaps, prj)	= ReduceStep options expr heaps prj
	| isError error							= (error, (DummyValue, expr @# exprs), heaps, prj)
	= case status of
		NotReducable						-> (OK, try_to_combine_args expr exprs, heaps, prj)
		UndefinedForm						-> (OK, (ReducedOnce, CBottom), heaps, prj)
		VariableForm						-> case isMember (expr @# exprs) options.roDefinedExpressions of
												True	-> (OK, (MaybeVariableForm [], expr @# exprs), heaps, prj)
												False	-> (OK, (VariableForm, expr @# exprs), heaps, prj)
		(MaybeVariableForm ptrs)			-> case isMember (expr @# exprs) options.roDefinedExpressions of
												True	-> (OK, (MaybeVariableForm [], expr @# exprs), heaps, prj)
												False	-> (OK, (VariableForm, expr @# exprs), heaps, prj)
		ReducedOnce							-> (OK, (status, expr @# exprs), heaps, prj)
	where
		try_to_combine_args :: !CExprH ![CExprH] -> (!ReductionStatus, !CExprH)
		try_to_combine_args expr []
			= (ReducedOnce, expr)
		try_to_combine_args (expr @# args1) args2
			= (ReducedOnce, expr @# (args1 ++ args2))
		try_to_combine_args  (ptr @@# args1) args2
			= (ReducedOnce, ptr @@# (args1 ++ args2))
		try_to_combine_args expr args
			= (NotReducable, expr @# args)
ReduceStep options (ptr @@# exprs) heaps prj
	# (arity, arg_types, mb_fundef, prj)			= get_fundef ptr prj
	# sufficient_arguments							= arity <= length exprs
//	| arity > length exprs							= (OK, (NotReducable, ptr @@# exprs), heaps, prj)
	# (error, status, exprs, heaps, prj)			= reduce_args sufficient_arguments 0 arg_types exprs mb_fundef heaps prj
	| isError error									= (error, (DummyValue, ptr @@# exprs), heaps, prj)
	= case status of
		NotReducable								-> case sufficient_arguments of
														True	-> fillin ptr exprs mb_fundef heaps prj
														False	-> (OK, (NotReducable, ptr @@# exprs), heaps, prj)
		UndefinedForm								-> (OK, (ReducedOnce, CBottom), heaps, prj)
		VariableForm								-> case isMember (ptr @@# exprs) options.roDefinedExpressions of
														True	-> (OK, (MaybeVariableForm [], ptr @@# exprs), heaps, prj)
														False	-> (OK, (VariableForm, ptr @@# exprs), heaps, prj)
		MaybeVariableForm ptrs						-> case keep_maybe_vars mb_fundef  of
															True	-> (OK, (status, ptr @@# exprs), heaps, prj)
															False	-> case isMember (ptr @@# exprs) options.roDefinedExpressions of
																		True	-> (OK, (MaybeVariableForm [], ptr @@# exprs), heaps, prj)
																		False	-> (OK, (VariableForm, ptr @@# exprs), heaps, prj)
		ReducedOnce									-> (OK, (status, ptr @@# exprs), heaps, prj)
	where
		fillin :: !HeapPtr ![CExprH] !(Maybe CFunDefH) !*CHeaps !*CProject -> (!Error, !(!ReductionStatus, !CExprH), !*CHeaps, !*CProject)
		fillin ptr args Nothing heaps prj
			= (OK, (NotReducable, ptr @@# args), heaps, prj)
		fillin ptr args (Just fundef) heaps prj
			| fundef.fdOpaque						= (OK, (VariableForm, ptr @@# args), heaps, prj)
			| isJust fundef.fdDeltaRule
				# (error, result)					= (fromJust fundef.fdDeltaRule) args
				| isError error						= (error, (DummyValue, ptr @@# args), heaps, prj)
				= (OK, (ReducedOnce, result), heaps, prj)
			# (result, heaps, prj)					= fillinFun options.roMode fundef args heaps prj
			= (OK, (ReducedOnce, result), heaps, prj)
		
		get_fundef :: !HeapPtr !*CProject -> (!Int, ![CTypeH], !Maybe CFunDefH, !*CProject)
		get_fundef ptr prj
			| ptrKind ptr == CFun
				# (error, fundef, prj)				= getFunDef ptr prj
				| isError error						= (-1, [], Nothing, prj)
				# fun_arity							= getRealArity options.roMode fundef
				= (fun_arity, fundef.fdSymbolType.sytArguments, Just fundef, prj)
			| ptrKind ptr == CDataCons
				# (error, consdef, prj)				= getDataConsDef ptr prj
				| isError error						= (-1, [], Nothing, prj)
				= (consdef.dcdArity, consdef.dcdSymbolType.sytArguments, Nothing, prj)
			= (-1, [], Nothing, prj)
		
		keep_maybe_vars :: !(Maybe CFunDefH) -> Bool
		keep_maybe_vars Nothing						= True
		keep_maybe_vars (Just fun)					= fun.fdHalting
		
		reduce_args :: !Bool !Int ![CTypeH] ![CExprH] !(Maybe CFunDefH) !*CHeaps !*CProject -> (!Error, !ReductionStatus, ![CExprH], !*CHeaps, !*CProject)
		reduce_args sufficient_arguments index types [] mb_fundef heaps prj
			= (OK, NotReducable, [], heaps, prj)
		reduce_args sufficient_arguments index [] exprs mb_fundef heaps prj
			= (OK, NotReducable, exprs, heaps, prj)
		reduce_args sufficient_arguments index [CStrict type:types] [expr:exprs] mb_fundef heaps prj
			# (error, (status, expr), heaps, prj)	= ReduceStep options expr heaps prj
			| isError error							= (error, DummyValue, [expr:exprs], heaps, prj)
			= case status of
				NotReducable						-> next_arg expr heaps prj
				UndefinedForm						-> case sufficient_arguments of
															True	-> (OK, UndefinedForm, [], heaps, prj)
															False	-> next_arg expr heaps prj
				VariableForm						-> case may_skip mb_fundef of
															True	-> next_arg expr heaps prj
															False	-> ignore_arg VariableForm heaps prj
				MaybeVariableForm ptrs				-> case may_skip_maybe ptrs expr mb_fundef of
															True	-> next_arg expr heaps prj
															False	-> ignore_arg (MaybeVariableForm ptrs) heaps prj
				ReducedOnce							-> (OK, ReducedOnce, [expr:exprs], heaps, prj)
			where
				next_arg expr heaps prj
					# (error, status, exprs, heaps, prj)
													= reduce_args sufficient_arguments (index+1) types exprs mb_fundef heaps prj
					= (error, status, [expr:exprs], heaps, prj)
				
				ignore_arg old_status heaps prj
					# (error, status, exprs, heaps, prj)
													= reduce_args sufficient_arguments (index+1) types exprs mb_fundef heaps prj
					# status						= combine old_status status
					= (error, status, [expr:exprs], heaps, prj)
				
				may_skip Nothing
					= False
				may_skip (Just fundef)
					| isJust fundef.fdDeltaRule		= False
					= case options.roMode of
						AsInClean					-> False
						Defensive					-> ( not (isMember index fundef.fdCaseVariables)) &&
													   ( isMember index fundef.fdStrictVariables )
						Offensive					-> isMember index fundef.fdStrictVariables
				
				may_skip_maybe ptrs expr Nothing
					= case options.roMode of
						AsInClean					-> False
						Defensive					-> areMembers ptrs options.roDefinedVariables
						Offensive					-> areMembers ptrs options.roDefinedVariables
				may_skip_maybe ptrs expr (Just fundef)
					| isJust fundef.fdDeltaRule		= False
					= case options.roMode of
						AsInClean					-> False
						Defensive					-> ( not (isMember index fundef.fdCaseVariables)
													   ) &&
													   ( isMember index fundef.fdStrictVariables	||
													     areMembers ptrs options.roDefinedVariables
													   )
						Offensive					-> ( isMember index fundef.fdStrictVariables	||
													     areMembers ptrs options.roDefinedVariables
													   )
				
				combine old ReducedOnce
					= ReducedOnce
				combine old UndefinedForm
					= UndefinedForm
				combine old VariableForm
					= VariableForm
				combine VariableForm other
					= VariableForm
				combine (MaybeVariableForm ptrs1) (MaybeVariableForm ptrs2)
					= MaybeVariableForm (removeDup (ptrs1 ++ ptrs2))
				combine old other
					= old
		reduce_args sufficient_arguments index [type:types] [expr:exprs] mb_fundef heaps prj
			# (error, status, exprs, heaps, prj)					= reduce_args sufficient_arguments (index+1) types exprs mb_fundef heaps prj
			= (error, status, [expr:exprs], heaps, prj)
		
ReduceStep options (CLet True [(var,expr)] let_expr) heaps prj
	#! (error, (status, expr), heaps, prj)	= ReduceStep options expr heaps prj
	| isError error							= (error, (DummyValue, CLet True [(var,expr)] let_expr), heaps, prj)
	= case status of
		NotReducable						-> ReduceStep options (CLet False [(var,expr)] let_expr) heaps prj
		UndefinedForm						-> (OK, (ReducedOnce, CBottom), heaps, prj)
		VariableForm						-> case isMember (CLet True [(var,expr)] let_expr) options.roDefinedExpressions of
												True	-> (OK, (MaybeVariableForm [], CLet True [(var,expr)] let_expr), heaps, prj)
												False	-> (OK, (VariableForm, CLet True [(var,expr)] let_expr), heaps, prj)
		(MaybeVariableForm ptrs)			-> case isMember (CLet True [(var,expr)] let_expr) options.roDefinedExpressions of
												True	-> (OK, (MaybeVariableForm [], CLet True [(var,expr)] let_expr), heaps, prj)
												False	-> (OK, (VariableForm, CLet True [(var,expr)] let_expr), heaps, prj)
		ReducedOnce							-> (OK, (status, CLet True [(var,expr)] let_expr), heaps, prj)
ReduceStep options (CLet False lets let_expr) heaps prj
	# (vars, exprs)							= unzip lets
	# (subst, heaps)						= shareLets vars exprs heaps
	# (let_expr, heaps)						= SafeSubst subst let_expr heaps
	= (OK, (ReducedOnce, let_expr), heaps, prj)
ReduceStep options (CCase expr patterns maybe_default) heaps prj
	#! (error, (status, expr), heaps, prj)	= ReduceStep options expr heaps prj
	| isError error							= (error, (DummyValue, CCase expr patterns maybe_default), heaps, prj)
	= case status of
		NotReducable						-> match_pattern expr patterns maybe_default heaps prj
		UndefinedForm						-> (OK, (ReducedOnce, CBottom), heaps, prj)
		VariableForm						-> case isMember (CCase expr patterns maybe_default) options.roDefinedExpressions of
												True	-> (OK, (MaybeVariableForm [], CCase expr patterns maybe_default), heaps, prj)
												False	-> (OK, (VariableForm, CCase expr patterns maybe_default), heaps, prj)
		(MaybeVariableForm ptrs)			-> case isMember (CCase expr patterns maybe_default) options.roDefinedExpressions of
												True	-> (OK, (MaybeVariableForm [], CCase expr patterns maybe_default), heaps, prj)
												False	-> (OK, (VariableForm, CCase expr patterns maybe_default), heaps, prj)
		ReducedOnce							-> (OK, (status, CCase expr patterns maybe_default), heaps, prj)
	where
		match_pattern :: !CExprH !CCasePatternsH !(Maybe CExprH) !*CHeaps !*CProject -> (!Error, !(!ReductionStatus, !CExprH), !*CHeaps, !*CProject)
		match_pattern (CBasicValue value) (CBasicPatterns _ patterns) maybe_default heaps prj
			= match_basic value patterns maybe_default heaps prj
		match_pattern (ptr @@# args) (CAlgPatterns _ patterns) maybe_default heaps prj
			| ptrKind ptr == CDataCons		= match_cons ptr args patterns maybe_default heaps prj
			= (OK, (ReducedOnce, CBottom), heaps, prj)
		match_pattern _ _ _ heaps prj
			= (OK, (ReducedOnce, CBottom), heaps, prj)
		
		match_basic :: !CBasicValueH ![CBasicPatternH] !(Maybe CExprH) !*CHeaps !*CProject -> (!Error, !(!ReductionStatus, !CExprH), !*CHeaps, !*CProject)
		match_basic value [] maybe_default heaps prj
			| isNothing maybe_default		= (OK, (ReducedOnce, CBottom), heaps, prj)
			= (OK, (ReducedOnce, fromJust maybe_default), heaps, prj)
		match_basic value [pattern:patterns] maybe_default heaps prj
			| value <> pattern.bapBasicValue= match_basic value patterns maybe_default heaps prj
			= (OK, (ReducedOnce, pattern.bapResult), heaps, prj)
		
		match_cons :: !HeapPtr ![CExprH] ![CAlgPatternH] !(Maybe CExprH) !*CHeaps !*CProject -> (!Error, !(!ReductionStatus, !CExprH), !*CHeaps, !*CProject)
		match_cons ptr args [] maybe_default heaps prj
			| isNothing maybe_default		= (OK, (ReducedOnce, CBottom), heaps, prj)
			= (OK, (ReducedOnce, fromJust maybe_default), heaps, prj)
		match_cons ptr args [pattern:patterns] maybe_default heaps prj
			| ptr <> pattern.atpDataCons	= match_cons ptr args patterns maybe_default heaps prj
			# (varnames, heaps)				= getPointerNames pattern.atpExprVarScope heaps
			# (args, heaps)					= share args varnames heaps
			# subE							= zip2 pattern.atpExprVarScope args
			#! (result, heaps)				= UnsafeSubst {DummyValue & subExprVars = subE} pattern.atpResult heaps
			= (OK, (ReducedOnce, result), heaps, prj)
ReduceStep options (CBasicValue value) heaps prj
	= (OK, (NotReducable, CBasicValue value), heaps, prj)
ReduceStep options (CCode type cod) heaps prj
	= (error, (NotReducable, CCode type cod), heaps, prj)
	where
		error 	=> pushError (X_Reduction "Encountered ABC-code.") OK
ReduceStep options CBottom heaps prj
	= (OK, (UndefinedForm, CBottom), heaps, prj)

// =================================================================================================================================================
// Skips constructors. (for user interface only)
// INCORRECT
// -------------------------------------------------------------------------------------------------------------------------------------------------   
InnerReduceStep :: !ReductionOptions !CExprH !*CHeaps !*CProject -> (!Error, !(!ReductionStatus, !CExprH), !*CHeaps, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------   
InnerReduceStep options expr=:(ptr @@# exprs) heaps prj
	| ptrKind ptr <> CDataCons						= ReduceStep options expr heaps prj
	# (error, (status, exprs), heaps, prj)			= inner exprs heaps prj
	= (error, (status, ptr @@# exprs), heaps, prj)
	where
		inner :: ![CExprH] !*CHeaps !*CProject -> (!Error, !(!ReductionStatus, ![CExprH]), !*CHeaps, !*CProject)
		inner [expr:exprs] heaps prj
			# (error, (status, expr), heaps, prj)	= InnerReduceStep options expr heaps prj
			| isError error							= (error, (status, [expr:exprs]), heaps, prj)
			= case status of
				NotReducable						-> let (error2, (status2, exprs2), heaps2, prj2) = inner exprs heaps prj
														in (error2, (status2, [expr:exprs2]), heaps2, prj2)
				_									-> (OK, (status, [expr:exprs]), heaps, prj)
		inner [] heaps prj
			= (OK, (NotReducable, []), heaps, prj)
InnerReduceStep options other heaps prj
	= ReduceStep options other heaps prj

// =================================================================================================================================================
// Reduce puts an expression in a strict-context and reduces it to root-normal-form.
// -------------------------------------------------------------------------------------------------------------------------------------------------   
ReduceOld :: !ReductionOptions !Int !CExprH !*CHeaps !*CProject -> (!Error, !(!Int, !ReductionStatus, !CExprH), !*CHeaps, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------   
ReduceOld options 0 expr heaps prj
	= (error, (0, DummyValue, expr), heaps, prj)
	where
		error => pushError (X_Reduction "Passed reduction bounds.") OK
ReduceOld options n (CExprVar ptr) heaps prj
	= (OK, (n, MaybeVariableForm [ptr], CExprVar ptr), heaps, prj)
ReduceOld options n (CShared ptr) heaps prj
	# (shared, heaps)							= readPointer ptr heaps
	| shared.shName == "__cycle"				= (OK, (n-1, UndefinedForm, CBottom), heaps, prj)
	# old_name									= shared.shName
	# shared									= {shared & shName = "__cycle"}
	# heaps										= writePointer ptr shared heaps
	#! (error, (n, status, expr), heaps, prj)	= ReduceOld options n shared.shExpr heaps prj
	# shared									= {shared & shName = old_name, shExpr = expr}
	# heaps										= writePointer ptr shared heaps
	| isError error								= (error, (n, DummyValue, CShared ptr), heaps, prj)
	= case status of
		NotReducable							-> let (new_expr, new_heaps) = unshareCons ptr shared heaps
													in (OK, (n, status, new_expr), new_heaps, prj)	// partially remove sharing
		UndefinedForm							-> (OK, (n, status, CBottom), heaps, prj)			// remove sharing
		VariableForm							-> (OK, (n, status, shared.shExpr), heaps, prj)		// remove sharing
		(MaybeVariableForm ptrs)				-> (OK, (n, status, shared.shExpr), heaps, prj)		// remove sharing
ReduceOld options n (expr @# exprs) heaps prj
	#! (error, (n, status, expr), heaps, prj)	= ReduceOld options n expr heaps prj
	| isError error								= (error, (n, DummyValue, expr @# exprs), heaps, prj)
	= case status of
		NotReducable							-> combine_and_continue n expr exprs heaps prj
		UndefinedForm							-> (OK, (n-1, UndefinedForm, CBottom), heaps, prj)
		VariableForm							-> case isMember (expr @# exprs) options.roDefinedExpressions of
													True	-> (OK, (n, MaybeVariableForm [], expr @# exprs), heaps, prj)
													False	-> (OK, (n, status, expr @# exprs), heaps, prj)
		(MaybeVariableForm ptrs)				-> case isMember (expr @# exprs) options.roDefinedExpressions of
													True	-> (OK, (n, MaybeVariableForm [], expr @# exprs), heaps, prj)
													False	-> (OK, (n, VariableForm, expr @# exprs), heaps, prj)
	where
		// Called in case reduction of application node terminates with 'NotReducable'.
		combine_and_continue :: !Int !CExprH ![CExprH] !*CHeaps !*CProject -> (!Error, !(!Int, !ReductionStatus, !CExprH), !*CHeaps, !*CProject)
		combine_and_continue n expr [] heaps prj
			= (OK, (n-1, NotReducable, expr), heaps, prj)
		combine_and_continue n (expr @# args1) args2 heaps prj
			= ReduceOld options (n-1) (expr @# (args1 ++ args2)) heaps prj
		combine_and_continue n (ptr @@# args1) args2 heaps prj
			= ReduceOld options (n-1) (ptr @@# (args1 ++ args2)) heaps prj
		combine_and_continue n expr args heaps prj
			= (OK, (n, NotReducable, expr @# args), heaps, prj)
ReduceOld options n (ptr @@# exprs) heaps prj
	# (arity, arg_types, mb_fundef, prj)			= get_fundef ptr prj
	# sufficient_arguments							= arity <= length exprs
//	| arity > length exprs							= (OK, (n, NotReducable, ptr @@# exprs), heaps, prj)
	# (error, n, status, exprs, heaps, prj)			= reduce_args sufficient_arguments n 0 arg_types exprs mb_fundef heaps prj
	| isError error									= (error, (n, DummyValue, ptr @@# exprs), heaps, prj)
	= case status of
		NotReducable								-> case sufficient_arguments of
														True	-> fillin n ptr exprs mb_fundef heaps prj
														False	-> (OK, (n, NotReducable, ptr @@# exprs), heaps, prj)
		UndefinedForm								-> (OK, (n-1, UndefinedForm, CBottom), heaps, prj)
		VariableForm								-> case isMember (ptr @@# exprs) options.roDefinedExpressions of
														True	-> (OK, (n, MaybeVariableForm [], ptr @@# exprs), heaps, prj)
														False	-> (OK, (n, VariableForm, ptr @@# exprs), heaps, prj)
		MaybeVariableForm ptrs						-> case keep_maybe_vars mb_fundef of
															True	-> (OK, (n, status, ptr @@# exprs), heaps, prj)
															False	-> case isMember (ptr @@# exprs) options.roDefinedExpressions of
																		True	-> (OK, (n, MaybeVariableForm [], ptr @@# exprs), heaps, prj)
																		False	-> (OK, (n, VariableForm, ptr @@# exprs), heaps, prj)
	where
		fillin :: !Int !HeapPtr ![CExprH] !(Maybe CFunDefH) !*CHeaps !*CProject -> (!Error, !(!Int, !ReductionStatus, !CExprH), !*CHeaps, !*CProject)
		fillin n ptr args Nothing heaps prj
			= (OK, (n, NotReducable, ptr @@# args), heaps, prj)
		fillin n ptr args (Just fundef) heaps prj
			| fundef.fdOpaque						= (OK, (n, VariableForm, ptr @@# args), heaps, prj)
			| isJust fundef.fdDeltaRule
				# (error, result)					= (fromJust fundef.fdDeltaRule) args
				| isError error						= (error, (n, DummyValue, ptr @@# args), heaps, prj)
				= ReduceOld options (n-1) result heaps prj
			# (result, heaps, prj)					= fillinFun options.roMode fundef args heaps prj
			= ReduceOld options (n-1) result heaps prj
		
		get_fundef :: !HeapPtr !*CProject -> (!Int, ![CTypeH], !Maybe CFunDefH, !*CProject)
		get_fundef ptr prj
			| ptrKind ptr == CFun
				# (error, fundef, prj)				= getFunDef ptr prj
				| isError error						= (-1, [], Nothing, prj)
				# fun_arity							= getRealArity options.roMode fundef
				= (fun_arity, fundef.fdSymbolType.sytArguments, Just fundef, prj)
			| ptrKind ptr == CDataCons
				# (error, consdef, prj)				= getDataConsDef ptr prj
				| isError error						= (-1, [], Nothing, prj)
				= (consdef.dcdArity, consdef.dcdSymbolType.sytArguments, Nothing, prj)
			= (-1, [], Nothing, prj)
		
		keep_maybe_vars :: !(Maybe CFunDefH) -> Bool
		keep_maybe_vars Nothing						= True
		keep_maybe_vars (Just fun)					= fun.fdHalting
		
		reduce_args :: !Bool !Int !Int ![CTypeH] ![CExprH] !(Maybe CFunDefH) !*CHeaps !*CProject -> (!Error, !Int, !ReductionStatus, ![CExprH], !*CHeaps, !*CProject)
		reduce_args sufficient_arguments n index types [] mb_fundef heaps prj
			= (OK, n, NotReducable, [], heaps, prj)
		reduce_args sufficient_arguments n index [] exprs mb_fundef heaps prj
			= (OK, n, NotReducable, exprs, heaps, prj)
		reduce_args sufficient_arguments n index [CStrict type:types] [expr:exprs] mb_fundef heaps prj
			# (error, (n, status, expr), heaps, prj)= ReduceOld options n expr heaps prj
			| isError error							= (error, n, DummyValue, [expr:exprs], heaps, prj)
			= case status of
				NotReducable						-> next_arg n expr heaps prj
				UndefinedForm						-> case sufficient_arguments of
															True	-> (OK, n, UndefinedForm, [], heaps, prj)
															False	-> next_arg n expr heaps prj
				VariableForm						-> case may_skip mb_fundef of
															True	-> next_arg n expr heaps prj
															False	-> ignore_arg n expr VariableForm heaps prj
				MaybeVariableForm ptrs				-> case may_skip_maybe ptrs expr mb_fundef of
															True	-> next_arg n expr heaps prj
															False	-> ignore_arg n expr (MaybeVariableForm ptrs) heaps prj
			where
				next_arg n expr heaps prj
					# (error, n, status, exprs, heaps, prj)
													= reduce_args sufficient_arguments n (index+1) types exprs mb_fundef heaps prj
					= (error, n, status, [expr:exprs], heaps, prj)
				
				ignore_arg n expr old_status heaps prj
					# (error, n, status, exprs, heaps, prj)
													= reduce_args sufficient_arguments n (index+1) types exprs mb_fundef heaps prj
					# status						= combine old_status status
					= (error, n, status, [expr:exprs], heaps, prj)
				
				may_skip Nothing
					= False
				may_skip (Just fundef)
					| isJust fundef.fdDeltaRule		= False
					= case options.roMode of
						AsInClean					-> False
						Defensive					-> ( not (isMember index fundef.fdCaseVariables)) &&
													   ( isMember index fundef.fdStrictVariables )
						Offensive					-> isMember index fundef.fdStrictVariables
				
				may_skip_maybe ptrs expr Nothing
					= case options.roMode of
						AsInClean					-> False
						Defensive					-> areMembers ptrs options.roDefinedVariables
						Offensive					-> areMembers ptrs options.roDefinedVariables
				may_skip_maybe ptrs expr (Just fundef)
					| isJust fundef.fdDeltaRule		= False
					= case options.roMode of
						AsInClean					-> False
						Defensive					-> ( not (isMember index fundef.fdCaseVariables)
													   ) &&
													   ( isMember index fundef.fdStrictVariables	||
													     areMembers ptrs options.roDefinedVariables
													   )
						Offensive					-> ( isMember index fundef.fdStrictVariables	||
													     areMembers ptrs options.roDefinedVariables
													   )
				
				combine old UndefinedForm
					= UndefinedForm
				combine old VariableForm
					= VariableForm
				combine VariableForm other
					= VariableForm
				combine (MaybeVariableForm ptrs1) (MaybeVariableForm ptrs2)
					= MaybeVariableForm (removeDup (ptrs1 ++ ptrs2))
				combine old other
					= old
		reduce_args sufficient_arguments n index [type:types] [expr:exprs] mb_fundef heaps prj
			# (error, status, n, exprs, heaps, prj)					= reduce_args sufficient_arguments n (index+1) types exprs mb_fundef heaps prj
			= (error, status, n, [expr:exprs], heaps, prj)
ReduceOld options n (CLet True [(var,expr)] let_expr) heaps prj
	#! (error, (n, status, expr), heaps, prj)	= ReduceOld options n expr heaps prj
	| isError error								= (error, (n, DummyValue, CLet True [(var,expr)] let_expr), heaps, prj)
	= case status of
		NotReducable							-> ReduceOld options n (CLet False [(var,expr)] let_expr) heaps prj
		UndefinedForm							-> (OK, (n-1, UndefinedForm, CBottom), heaps, prj)
		VariableForm							-> case isMember (CLet True [(var,expr)] let_expr) options.roDefinedExpressions of
													True	-> (OK, (n, MaybeVariableForm [], CLet True [(var,expr)] let_expr), heaps, prj)
													False	-> (OK, (n, VariableForm, CLet True [(var,expr)] let_expr), heaps, prj)
		(MaybeVariableForm ptrs)				-> case isMember (CLet True [(var,expr)] let_expr) options.roDefinedExpressions of
													True	-> (OK, (n, MaybeVariableForm [], CLet True [(var,expr)] let_expr), heaps, prj)
													False	-> (OK, (n, VariableForm, CLet True [(var,expr)] let_expr), heaps, prj)
ReduceOld options n (CLet False lets let_expr) heaps prj
	# (vars, exprs)								= unzip lets
	# (subst, heaps)							= shareLets vars exprs heaps
	# (let_expr, heaps)							= SafeSubst subst let_expr heaps
	= ReduceOld options (n-1) let_expr heaps prj
ReduceOld options n (CCase expr patterns maybe_default) heaps prj
	#! (error, (n, status, expr), heaps, prj)	= ReduceOld options n expr heaps prj
	| isError error								= (error, (n, DummyValue, CCase expr patterns maybe_default), heaps, prj)
	= case status of
		NotReducable							-> match_pattern n expr patterns maybe_default heaps prj
		UndefinedForm							-> (OK, (n-1, UndefinedForm, CBottom), heaps, prj)
		VariableForm							-> case isMember (CCase expr patterns maybe_default) options.roDefinedExpressions of
													True	-> (OK, (n, MaybeVariableForm [], CCase expr patterns maybe_default), heaps, prj)
													False	-> (OK, (n, VariableForm, CCase expr patterns maybe_default), heaps, prj)
		(MaybeVariableForm ptrs)				-> case isMember (CCase expr patterns maybe_default) options.roDefinedExpressions of
													True	-> (OK, (n, MaybeVariableForm [], CCase expr patterns maybe_default), heaps, prj)
													False	-> (OK, (n, VariableForm, CCase expr patterns maybe_default), heaps, prj)
	where
		match_pattern n (CBasicValue value) (CBasicPatterns _ patterns) maybe_default heaps prj
			= match_basic n value patterns maybe_default heaps prj
		match_pattern n (ptr @@# args) (CAlgPatterns _ patterns) maybe_default heaps prj
			| ptrKind ptr == CDataCons			= match_cons n ptr args patterns maybe_default heaps prj
			= (OK, (n, UndefinedForm, CBottom), heaps, prj)
		match_pattern n _ _ _ heaps prj
			= (OK, (n-1, UndefinedForm, CBottom), heaps, prj)
		
		match_basic n value [] maybe_default heaps prj
			| isNothing maybe_default			= (OK, (n-1, UndefinedForm, CBottom), heaps, prj)
			= ReduceOld options (n-1) (fromJust maybe_default) heaps prj
		match_basic n value [pattern:patterns] maybe_default heaps prj
			| value <> pattern.bapBasicValue	= match_basic n value patterns maybe_default heaps prj
			= ReduceOld options (n-1) pattern.bapResult heaps prj
		
		match_cons n ptr args [] maybe_default heaps prj
			| isNothing maybe_default			= (OK, (n-1, UndefinedForm, CBottom), heaps, prj)
			= ReduceOld options (n-1) (fromJust maybe_default) heaps prj
		match_cons n ptr args [pattern:patterns] maybe_default heaps prj
			| ptr <> pattern.atpDataCons		= match_cons n ptr args patterns maybe_default heaps prj
			# (varnames, heaps)					= getPointerNames pattern.atpExprVarScope heaps
			# (args, heaps)						= share args varnames heaps
			# subE								= zip2 pattern.atpExprVarScope args
			#! (result, heaps)					= UnsafeSubst {DummyValue & subExprVars = subE} pattern.atpResult heaps
			= ReduceOld options (n-1) result heaps prj
ReduceOld options n (CBasicValue value) heaps prj
	= (OK, (n, NotReducable, CBasicValue value), heaps, prj)
ReduceOld options n (CCode type cod) heaps prj
	= (error, (n, NotReducable, CCode type cod), heaps, prj)
	where
		error 	=> pushError (X_Reduction "Encountered ABC-code.") OK
ReduceOld options n CBottom heaps prj
	= (OK, (n, UndefinedForm, CBottom), heaps, prj)

// =================================================================================================================================================
// Skips constructors. (for user interface only)
// INCORRECT
// -------------------------------------------------------------------------------------------------------------------------------------------------   
InnerReduce :: !ReductionOptions !Int !CExprH !*CHeaps !*CProject -> (!Error, !(!Int, !ReductionStatus, !CExprH), !*CHeaps, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------   
InnerReduce options n expr=:(ptr @@# exprs) heaps prj
	| ptrKind ptr <> CDataCons						= ReduceOld options n expr heaps prj
	# (error, (n, status, exprs), heaps, prj)		= inner n exprs heaps prj
	= (error, (n, status, ptr @@# exprs), heaps, prj)
	where
		inner :: !Int ![CExprH] !*CHeaps !*CProject -> (!Error, !(!Int, !ReductionStatus, ![CExprH]), !*CHeaps, !*CProject)
		inner n [expr:exprs] heaps prj
			# (error, (n, status, expr), heaps, prj)= InnerReduce options n expr heaps prj
			| isError error							= (error, (n, status, [expr:exprs]), heaps, prj)
			= case status of
				NotReducable						-> let (error2, (n2, status2, exprs2), heaps2, prj2) = inner n exprs heaps prj
														in (error2, (n2, status2, [expr:exprs2]), heaps2, prj2)
				_									-> (OK, (n, status, [expr:exprs]), heaps, prj)
		inner n [] heaps prj
			= (OK, (n, NotReducable, []), heaps, prj)
InnerReduce options n other heaps prj
	= ReduceOld options n other heaps prj

// =================================================================================================================================================
// Also reduces on ALL lazy positions, but only afterwards.
// Result: everything will be reduced.
// Use with caution; may not terminate.
// -------------------------------------------------------------------------------------------------------------------------------------------------   
ReduceAll :: !ReductionOptions !Int !CExprH !*CHeaps !*CProject -> (!Error, !(!Int, !CExprH), !*CHeaps, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------   
ReduceAll options count expr heaps prj
	# (error, (count, status, expr), heaps, prj)	= ReduceOld options count expr heaps prj
	| isError error									= (error, (count, expr), heaps, prj)
	// TEST -- decrease count to prevent 'fruitless' reductions (as in '_from_to m n')
	= inner (count-1) expr heaps prj
	where
		inner :: !Int !CExprH !*CHeaps !*CProject -> (!Error, !(!Int, !CExprH), !*CHeaps, !*CProject)
		inner count (expr @# exprs) heaps prj
			# (error, (count, expr), heaps, prj)	= ReduceAll options count expr heaps prj
			| isError error							= (error, (count, expr @# exprs), heaps, prj)
			# (error, (count, exprs), heaps, prj)	= ReduceAllList options count exprs heaps prj
			= (error, (count, expr @# exprs), heaps, prj)
		inner count (ptr @@# exprs) heaps prj
			# (error, (count, exprs), heaps, prj)	= ReduceAllList options count exprs heaps prj
			= (error, (count, ptr @@# exprs), heaps, prj)
		inner count (CCase expr patterns def) heaps prj
			# (error, (count, patterns), heaps, prj)= inner_patterns count patterns heaps prj
			| isError error							= (error, (count, CCase expr patterns def), heaps, prj)
			# (error, (count, def), heaps, prj)		= inner_def count def heaps prj
			= (error, (count, CCase expr patterns def), heaps, prj)
		inner count (CBasicValue (CBasicArray exprs)) heaps prj
			# (error, (count, exprs), heaps, prj)	= ReduceAllList options count exprs heaps prj
			= (error, (count, CBasicValue (CBasicArray exprs)), heaps, prj)
		inner count other heaps prj
			= (OK, (count, other), heaps, prj)
		
		inner_def :: !Int !(Maybe CExprH) !*CHeaps !*CProject -> (!Error, !(!Int, !Maybe CExprH), !*CHeaps, !*CProject)
		inner_def count (Just expr) heaps prj
			# (error, (count, expr), heaps, prj)	= ReduceAll options count expr heaps prj
			= (error, (count, Just expr), heaps, prj)
		inner_def count Nothing heaps prj
			= (OK, (count, Nothing), heaps, prj)
		
		inner_patterns :: !Int !CCasePatternsH !*CHeaps !*CProject -> (!Error, !(!Int, !CCasePatternsH), !*CHeaps, !*CProject)
		inner_patterns count (CAlgPatterns type patterns) heaps prj
			# (error, (count, patterns), heaps, prj)= inner_alg_patterns count patterns heaps prj
			= (error, (count, CAlgPatterns type patterns), heaps, prj)
		inner_patterns count (CBasicPatterns type patterns) heaps prj
			# (error, (count, patterns), heaps, prj)= inner_basic_patterns count patterns heaps prj
			= (error, (count, CBasicPatterns type patterns), heaps, prj)
		
		inner_alg_patterns :: !Int ![CAlgPatternH] !*CHeaps !*CProject -> (!Error, !(!Int, ![CAlgPatternH]), !*CHeaps, !*CProject)
		inner_alg_patterns count [pattern:patterns] heaps prj
			# (error, (count, expr), heaps, prj)	= ReduceAll options count pattern.atpResult heaps prj
			| isError error							= (error, (count, [pattern:patterns]), heaps, prj)
			# pattern								= {pattern & atpResult = expr}
			# (error, (count, patterns), heaps, prj)= inner_alg_patterns count patterns heaps prj
			= (error, (count, [pattern:patterns]), heaps, prj)
		inner_alg_patterns count [] heaps prj
			= (OK, (count, []), heaps, prj)
		
		inner_basic_patterns :: !Int ![CBasicPatternH] !*CHeaps !*CProject -> (!Error, !(!Int, ![CBasicPatternH]), !*CHeaps, !*CProject)
		inner_basic_patterns count [pattern:patterns] heaps prj
			# (error, (count, expr), heaps, prj)	= ReduceAll options count pattern.bapResult heaps prj
			| isError error							= (error, (count, [pattern:patterns]), heaps, prj)
			# pattern								= {pattern & bapResult = expr}
			# (error, (count, patterns), heaps, prj)= inner_basic_patterns count patterns heaps prj
			= (error, (count, [pattern:patterns]), heaps, prj)
		inner_basic_patterns count [] heaps prj
			= (OK, (count, []), heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------   
ReduceAllList :: !ReductionOptions !Int ![CExprH] !*CHeaps !*CProject -> (!Error, !(!Int, ![CExprH]), !*CHeaps, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------   
ReduceAllList options count [expr:exprs] heaps prj
	# (error, (count, expr), heaps, prj)			= ReduceAll options count expr heaps prj
	| isError error									= (error, (count, [expr:exprs]), heaps, prj)
	# (error, (count, exprs), heaps, prj)			= ReduceAllList options count exprs heaps prj
	= (error, (count, [expr:exprs]), heaps, prj)
ReduceAllList options count [] heaps prj
	= (OK, (count, []), heaps, prj)
*/