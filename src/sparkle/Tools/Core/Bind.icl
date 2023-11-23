/*
** Program: Clean Prover System
** Module:  Bind (.icl)
** 
** Author:  Maarten de Mol
** Created: 24 August 2000
*/

implementation module 
	Bind

import
	StdEnv,
	CoreTypes,
	CoreAccess,
	Predefined,
	Heaps,
	Operate,
	ChangeDefinition,
	LDeltaRules,
	frontend
	, RWSDebug

// -------------------------------------------------------------------------------------------------------------------------------------------------
class removeDeadDefaults a :: !a !*CProject -> (!Error, !a, !*CProject)  
// -------------------------------------------------------------------------------------------------------------------------------------------------

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance removeDeadDefaults (CAlgPattern HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	removeDeadDefaults algpattern=:{atpResult} prj
		# (error, atpResult, prj)		= removeDeadDefaults atpResult prj
		| isError error					= (error, DummyValue, prj)
		= (OK, {algpattern & atpResult = atpResult}, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance removeDeadDefaults (CBasicPattern HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	removeDeadDefaults basicpattern=:{bapResult} prj
		# (error, bapResult, prj)		= removeDeadDefaults bapResult prj
		| isError error					= (error, DummyValue, prj)
		= (OK, {basicpattern & bapResult = bapResult}, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance removeDeadDefaults (CCasePatterns HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	removeDeadDefaults (CAlgPatterns algtype algpatterns) prj
		# (error, algpatterns, prj)		= umapError removeDeadDefaults algpatterns prj
		| isError error					= (error, DummyValue, prj)
		= (OK, CAlgPatterns algtype algpatterns, prj)
	removeDeadDefaults (CBasicPatterns basictype basicpatterns) prj
		# (error, basicpatterns, prj)	= umapError removeDeadDefaults basicpatterns prj
		| isError error					= (error, DummyValue, prj)
		= (OK, CBasicPatterns basictype basicpatterns, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance removeDeadDefaults (CExpr HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	removeDeadDefaults (expr @# exprs) prj
		# (error, expr, prj)			= removeDeadDefaults expr prj
		| isError error					= (error, DummyValue, prj)
		# (error, exprs, prj)			= umapError removeDeadDefaults exprs prj
		| isError error					= (error, DummyValue, prj)
		= (OK, expr @# exprs, prj)
	removeDeadDefaults (ptr @@# exprs) prj
		# (error, exprs, prj)			= umapError removeDeadDefaults exprs prj
		| isError error					= (error, DummyValue, prj)
		= (OK, ptr @@# exprs, prj)
	removeDeadDefaults (CLet strict bindings let_expr) prj
		# (error, rights, prj)			= umapError removeDeadDefaults (smap snd bindings) prj
		| isError error					= (error, DummyValue, prj)
		# bindings						= zip2 (smap fst bindings) rights
		# (error,  let_expr, prj)		= removeDeadDefaults let_expr prj
		| isError error					= (error, DummyValue, prj)
		= (OK, CLet strict bindings let_expr, prj)
	removeDeadDefaults (CCase case_expr case_patterns maybe_default) prj
		# (error, case_expr, prj)		= removeDeadDefaults case_expr prj
		| isError error					= (error, DummyValue, prj)
		# (error, case_patterns, prj)	= removeDeadDefaults case_patterns prj
		| isError error					= (error, DummyValue, prj)
		# (error, is_complete, prj)		= check_completeness case_patterns prj
		| is_complete					= (OK, CCase case_expr case_patterns Nothing, prj)
		= (OK, CCase case_expr case_patterns maybe_default, prj)
		where
			check_completeness (CAlgPatterns algtypeptr patterns) prj
				# (error, algtype, prj)			= getAlgTypeDef algtypeptr prj
				| isError error					= (error, DummyValue, prj)
				= (OK, length algtype.atdConstructors == length patterns, prj)
			check_completeness (CBasicPatterns CBoolean patterns) prj
				# values						= smap (\pattern -> pattern.bapBasicValue) patterns
				# values						= smap (\value -> case value of CBasicBoolean b -> b) values
				= (OK, isMember True values && isMember False values, prj)
			check_completeness other prj
				= (OK, False, prj)
	removeDeadDefaults other prj
		= (OK, other, prj)














// -------------------------------------------------------------------------------------------------------------------------------------------------
class duplicateDefaults c :: !(Maybe (CExpr defptr)) !(c defptr) -> (c defptr) | DummyValue defptr
// -------------------------------------------------------------------------------------------------------------------------------------------------

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance duplicateDefaults CAlgPattern
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	duplicateDefaults maybe_default alg_pattern
		= {alg_pattern & atpResult = duplicateDefaults maybe_default alg_pattern.atpResult}

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance duplicateDefaults CBasicPattern
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	duplicateDefaults maybe_default basic_pattern
		= {basic_pattern & bapResult = duplicateDefaults maybe_default basic_pattern.bapResult}

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance duplicateDefaults CCasePatterns
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	duplicateDefaults maybe_default (CAlgPatterns ptr alg_patterns)
		= CAlgPatterns ptr (smap (duplicateDefaults maybe_default) alg_patterns)
	duplicateDefaults maybe_default (CBasicPatterns basictype basic_patterns)
		= CBasicPatterns basictype (smap (duplicateDefaults maybe_default) basic_patterns)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance duplicateDefaults CExpr
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	duplicateDefaults _ (expr @# exprs)
		= (duplicateDefaults Nothing expr) @# (smap (duplicateDefaults Nothing) exprs)
	duplicateDefaults _ (ptr @@# exprs)
		= ptr @@# (smap (duplicateDefaults Nothing) exprs)
	duplicateDefaults _ (CLet strict bindings expr)
		# bindings					= [(exprvar, duplicateDefaults Nothing bindsto) \\ (exprvar, bindsto) <- bindings]
		= CLet strict bindings (duplicateDefaults Nothing expr)
	duplicateDefaults old_default (CCase case_expr patterns (Just default_expr))
		# default_expr				= duplicateDefaults old_default default_expr
		= CCase (duplicateDefaults Nothing case_expr) (duplicateDefaults (Just default_expr) patterns) (Just default_expr)
	duplicateDefaults maybe_default (CCase case_expr patterns Nothing)
		= CCase (duplicateDefaults Nothing case_expr) (duplicateDefaults maybe_default patterns) maybe_default
	duplicateDefaults _ other
		= other















// -------------------------------------------------------------------------------------------------------------------------------------------------
class mergeCases a :: !a -> a
// -------------------------------------------------------------------------------------------------------------------------------------------------

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance mergeCases (CAlgPattern defptr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	mergeCases algpattern=:{atpResult}
		= {algpattern & atpResult = mergeCases atpResult}

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance mergeCases (CBasicPattern defptr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	mergeCases basicpattern=:{bapResult}
		= {basicpattern & bapResult = mergeCases bapResult}

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance mergeCases (CCasePatterns defptr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	mergeCases (CAlgPatterns algtype algpatterns)
		= CAlgPatterns algtype (smap mergeCases algpatterns)
	mergeCases (CBasicPatterns basictype basicpatterns)
		= CBasicPatterns basictype (smap mergeCases basicpatterns)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance mergeCases (CExpr defptr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	mergeCases (expr @# exprs)
		= (mergeCases expr) @# (smap mergeCases exprs)
	mergeCases (ptr @@# exprs)
		= ptr @@# (smap mergeCases exprs)
	mergeCases (CLet strict bindings let_expr)
		# bindings			= [(exprvar, mergeCases expr) \\ (exprvar, expr) <- bindings]
		= CLet strict bindings (mergeCases let_expr)
	mergeCases (CCase (CExprVar id1) case_patterns1 (Just (CCase (CExprVar id2) case_patterns2 maybe_default2)))
		# the_same			= id1 == id2
		# new_patterns		= if the_same (merge_patterns case_patterns1 case_patterns2) case_patterns1
		# new_default		= if the_same maybe_default2 (Just (CCase (CExprVar id2) case_patterns2 maybe_default2))
		# new_patterns		= mergeCases new_patterns
		# new_default		= mergeCases new_default
		= CCase (CExprVar id1) new_patterns new_default
		where
			merge_patterns (CAlgPatterns algtype1 alg_patterns1) (CAlgPatterns algtype2 alg_patterns2)
				= CAlgPatterns algtype1 (alg_patterns1 ++ alg_patterns2)
			merge_patterns (CBasicPatterns basictype1 basic_patterns1) (CBasicPatterns basictype2 basic_patterns2)
				= CBasicPatterns basictype2 (basic_patterns1 ++ basic_patterns2)
	mergeCases other
		= other

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance mergeCases (Maybe a) | mergeCases a
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	mergeCases (Just x)		= Just (mergeCases x)
	mergeCases Nothing		= Nothing










// =================================================================================================================================================
// Performs two actions:
// (1) Any expression of the form 'case (Cons x y) of (Cons a b) ->' is simplified (case is removed altogether)
// (2) If two identical case expressions are encountered, the second one is removed. (right alternative chosen automatically)
// -------------------------------------------------------------------------------------------------------------------------------------------------
class selectPattern a :: !(Maybe CExprVarPtr) ![KnownToBe] !a !*CHeaps -> (!a, !*CHeaps)
// -------------------------------------------------------------------------------------------------------------------------------------------------

:: KnownToBe		= KnownToBeCons				!CExprVarPtr !HeapPtr ![CExprVarPtr]
					| KnownToBeBasic			!CExprVarPtr !CBasicValueH
					| KnownToBeDefaultCons		!CExprVarPtr ![HeapPtr]
					| KnownToBeDefaultBasic		!CExprVarPtr ![CBasicValueH]

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance selectPattern (Maybe a) | selectPattern a
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	selectPattern mb_var known (Just x) heaps
		#! (x, heaps)				= selectPattern mb_var known x heaps
		= (Just x, heaps)
	selectPattern _ known Nothing heaps
		= (Nothing, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance selectPattern [a] | selectPattern a
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	selectPattern mb_var known [x:xs] heaps
		#! (x, heaps)				= selectPattern mb_var known x heaps
		#! (xs, heaps)				= selectPattern mb_var known xs heaps
		= ([x:xs], heaps)
	selectPattern mb_var known [] heaps
		= ([], heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance selectPattern (a,b) | selectPattern b
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	selectPattern mb_var known (a,b) heaps
		#! (b, heaps)				= selectPattern mb_var known b heaps
		= ((a,b), heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance selectPattern (CAlgPattern HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	selectPattern (Just ptr) known algpattern=:{atpResult} heaps
		# known						= [KnownToBeCons ptr algpattern.atpDataCons algpattern.atpExprVarScope: known]
		#! (atpResult, heaps)		= selectPattern Nothing known atpResult heaps
		= ({algpattern & atpResult = atpResult}, heaps)
	selectPattern _ known algpattern=:{atpResult} heaps
		#! (atpResult, heaps)		= selectPattern Nothing known atpResult heaps
		= ({algpattern & atpResult = atpResult}, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance selectPattern (CBasicPattern HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	selectPattern (Just ptr) known basicpattern=:{bapBasicValue, bapResult} heaps
		# known						= [KnownToBeBasic ptr bapBasicValue: known]
		#! (bapResult, heaps)		= selectPattern Nothing known bapResult heaps
		= ({basicpattern & bapResult = bapResult}, heaps)
	selectPattern _ known basicpattern=:{bapResult} heaps
		#! (bapResult, heaps)		= selectPattern Nothing known bapResult heaps
		= ({basicpattern & bapResult = bapResult}, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance selectPattern (CCasePatterns HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	selectPattern mb_var known (CAlgPatterns typeptr patterns) heaps
		#! (patterns, heaps)		= selectPattern mb_var known patterns heaps
		= (CAlgPatterns typeptr patterns, heaps)
	selectPattern mb_var known (CBasicPatterns typeptr patterns) heaps
		#! (patterns, heaps)		= selectPattern mb_var known patterns heaps
		= (CBasicPatterns typeptr patterns, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance selectPattern (CExpr HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	selectPattern _ known (expr @# exprs) heaps
		#! (expr, heaps)			= selectPattern Nothing known expr heaps
		#! (exprs, heaps)			= selectPattern Nothing known exprs heaps
		= (expr @# exprs, heaps)
	selectPattern _ known (ptr @@# exprs) heaps
		#! (exprs, heaps)			= selectPattern Nothing known exprs heaps
		= (ptr @@# exprs, heaps)
	selectPattern _ known (CLet strict bindings let_expr) heaps
		#! (bindings, heaps)		= selectPattern Nothing known bindings heaps
		#! (let_expr, heaps)		= selectPattern Nothing known let_expr heaps
		= (CLet strict bindings let_expr, heaps)
	selectPattern _ known (CCase (ptr @@# exprs) (CAlgPatterns typeptr patterns) maybe_default) heaps
		# (maybe_default, heaps)	= selectPattern Nothing known maybe_default heaps
		# (patterns, heaps)			= selectPattern Nothing known patterns heaps
		# (ok, result)				= find_result ptr patterns
		| ok						= selectPattern Nothing known result heaps
		= case maybe_default of
			Nothing					-> (CCase (ptr @@# exprs) (CAlgPatterns typeptr patterns) Nothing, heaps)
			Just def				-> (def, heaps)
		where
			find_result ptr [algpattern: algpatterns]
				| algpattern.atpDataCons == ptr		= (True, algpattern.atpResult)
				= find_result ptr algpatterns
			find_result ptr []
				= (False, DummyValue)
	selectPattern _ known (CCase (CExprVar ptr) patterns maybe_default) heaps
		#! (ok, expr, heaps)		= find_pattern known patterns heaps
		| not ok
			#! (patterns, heaps)	= selectPattern (Just ptr) known patterns heaps
			# known					= [known_default patterns: known]
			#! (mb_default, heaps)	= selectPattern Nothing known maybe_default heaps
			= (CCase (CExprVar ptr) patterns mb_default, heaps)
//		| ok
			= selectPattern Nothing known expr heaps
		where
			known_default :: !CCasePatternsH -> KnownToBe
			known_default (CAlgPatterns _ patterns)
				# conses			= [pattern.atpDataCons \\ pattern <- patterns]
				= KnownToBeDefaultCons ptr conses
			known_default (CBasicPatterns _ patterns)
				# values			= [pattern.bapBasicValue \\ pattern <- patterns]
				= KnownToBeDefaultBasic ptr values
			
			find_pattern :: ![KnownToBe] !CCasePatternsH !*CHeaps -> (!Bool, !CExprH, !*CHeaps)
			find_pattern [KnownToBeCons var_ptr cons_ptr cons_args: known] p=:(CAlgPatterns _ patterns) heaps
				| var_ptr <> ptr				= find_pattern known p heaps
				= select_cons_pattern cons_ptr cons_args patterns heaps
			find_pattern [KnownToBeDefaultCons var_ptr cons_ptrs: known] p=:(CAlgPatterns _ patterns) heaps
				| var_ptr <> ptr				= find_pattern known p heaps
				= select_cons_default cons_ptrs patterns heaps
			find_pattern [KnownToBeBasic var_ptr basic_value: known] p=:(CBasicPatterns _ patterns) heaps
				| var_ptr <> ptr				= find_pattern known p heaps
				= select_basic_pattern basic_value patterns heaps
			find_pattern [KnownToBeDefaultBasic var_ptr basic_values: known] p=:(CBasicPatterns _ patterns) heaps
				| var_ptr <> ptr				= find_pattern known p heaps
				= select_basic_default basic_values patterns heaps
			find_pattern [_:known] patterns heaps
				= find_pattern known patterns heaps
			find_pattern [] patterns heaps
				= (False, DummyValue, heaps)
			
			select_cons_default :: ![HeapPtr] ![CAlgPatternH] !*CHeaps -> (!Bool, !CExprH, !*CHeaps)
			select_cons_default not_ptrs [pattern:patterns] heaps
				| isMember pattern.atpDataCons not_ptrs		= select_cons_default (removeMember pattern.atpDataCons not_ptrs) patterns heaps
				= (False, DummyValue, heaps)
			select_cons_default not_ptrs [] heaps
				= case not_ptrs of
					[]										-> case maybe_default of
																Just expr		-> (True, expr, heaps)
																Nothing			-> (True, CBottom, heaps)
					_										-> (False, DummyValue, heaps)
			
			select_cons_pattern :: !HeapPtr ![CExprVarPtr] ![CAlgPatternH] !*CHeaps -> (!Bool, !CExprH, !*CHeaps)
			select_cons_pattern cons_ptr arg_ptrs [pattern:patterns] heaps
				| pattern.atpDataCons <> cons_ptr			= select_cons_pattern cons_ptr arg_ptrs patterns heaps
				#! heaps									= mark_vars pattern.atpExprVarScope arg_ptrs heaps
				#! (expr, heaps)							= unsafeSubst pattern.atpResult heaps
				= (True, expr, heaps)
				where
					mark_vars :: ![CExprVarPtr] ![CExprVarPtr] !*CHeaps -> *CHeaps
					mark_vars [ptr1:ptrs1] [ptr2:ptrs2] heaps
						#! (var, heaps)						= readPointer ptr1 heaps
						# var								= {var & evarInfo = EVar_Subst (CExprVar ptr2)}
						#! heaps							= writePointer ptr var heaps
						= mark_vars ptrs1 ptrs2 heaps
					mark_vars _ _ heaps
						= heaps
			select_cons_pattern cons_ptr arg_ptrs [] heaps
				= case maybe_default of
					Just expr								-> (True, expr, heaps)
					Nothing									-> (True, CBottom, heaps)
			
			select_basic_default :: ![CBasicValueH] ![CBasicPatternH] !*CHeaps -> (!Bool, !CExprH, !*CHeaps)
			select_basic_default not_values [pattern:patterns] heaps
				| isMember pattern.bapBasicValue not_values	= select_basic_default (removeMember pattern.bapBasicValue not_values) patterns heaps
				= (False, DummyValue, heaps)
			select_basic_default not_values [] heaps
				= case not_values of
					[]										-> case maybe_default of
																Just expr		-> (True, expr, heaps)
																Nothing			-> (True, CBottom, heaps)
					_										-> (False, DummyValue, heaps)
			
			select_basic_pattern :: !CBasicValueH ![CBasicPatternH] !*CHeaps -> (!Bool, !CExprH, !*CHeaps)
			select_basic_pattern basic_value [pattern:patterns] heaps
				| pattern.bapBasicValue <> basic_value		= select_basic_pattern basic_value patterns heaps
				= (True, pattern.bapResult, heaps)
			select_basic_pattern basic_value [] heaps
				= case maybe_default of
					Just expr								-> (True, expr, heaps)
					Nothing									-> (True, CBottom, heaps)
	selectPattern _ known (CCase expr patterns maybe_default) heaps
		#! (expr, heaps)			= selectPattern Nothing known expr heaps
		#! (patterns, heaps)		= selectPattern Nothing known patterns heaps
		#! (maybe_default, heaps)	= selectPattern Nothing known maybe_default heaps
		= (CCase expr patterns maybe_default, heaps)
	selectPattern _ known other heaps
		= (other, heaps)


























// =================================================================================================================================================
// Accepts a pointer to a classdef. Puts the prefix 'dictionary_' in front of the dictionary corresponding to the class.
// -------------------------------------------------------------------------------------------------------------------------------------------------   
markDictionary :: !HeapPtr !CClassDefH !*CProject -> (!Error, !*CProject)  
// -------------------------------------------------------------------------------------------------------------------------------------------------   
markDictionary ptr classdef prj
	# (error, recorddef, prj)			= getRecordTypeDef classdef.cldDictionary prj
	| isError error						= (error, prj)
	# newname							= "dictionary_" +++ recorddef.rtdName
	# recorddef							= {recorddef & rtdName = newname, rtdIsDictionary = True, rtdClassDef = ptr}
	# (error, prj)						= putRecordTypeDef classdef.cldDictionary recorddef prj
	| isError error						= (error, prj)
	= (OK, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------   
hasFunctionType :: !HeapPtr !*CProject -> (!Error, !Bool, !*CProject)  
// -------------------------------------------------------------------------------------------------------------------------------------------------   
hasFunctionType ptr prj
	# (error, fundef, prj)				= getFunDef ptr prj
	| isError error						= (error, DummyValue, prj)
	= (OK, fundef.fdHasType, prj)

// =================================================================================================================================================
// Lifts existential variables from a record field to its record type.
// The existential variables are the same for each field; the first is chosen.
// -------------------------------------------------------------------------------------------------------------------------------------------------   
liftExistentialVarsRT :: !CRecordTypeDefH !*CProject -> (!Error, !CRecordTypeDefH, !*CProject)  
// -------------------------------------------------------------------------------------------------------------------------------------------------   
liftExistentialVarsRT rectypedef prj
//	# (error, rectypedef, prj)		= getRecordTypeDef ptr prj
//	| isError error					= (error, prj)
	# fieldptrs						= rectypedef.rtdFields
	| isEmpty fieldptrs				= (OK, rectypedef, prj)
	# (error, fielddef, prj)		= getRecordFieldDef (hd fieldptrs) prj
	| isError error					= (error, DummyValue, prj)
	# rectypedef					= {rectypedef & rtdTypeVarScope = rectypedef.rtdTypeVarScope ++
																	  (fromJust fielddef.rfTempTypeVarScope)}
//	# (error, prj)					= putRecordTypeDef ptr rectypedef prj
//	| isError error					= (error, prj)
	# (error, prj)					= purifyRecordFields fieldptrs prj
	| isError error					= (error, rectypedef, prj)
	= (OK, rectypedef, prj)
	where
		purifyRecordFields [] prj
			= (OK, prj)
		purifyRecordFields [ptr:ptrs] prj
			# (error, fielddef, prj)		= getRecordFieldDef ptr prj
			| isError error					= (error, prj)
			# fielddef						= {fielddef & rfTempTypeVarScope = Nothing}
			# (error, prj)					= putRecordFieldDef ptr fielddef prj
			| isError error					= (error, prj)
			= purifyRecordFields ptrs prj

// =================================================================================================================================================
// Accepts a pointer to a data-constructor. If this constructor is a record-constructor, two things are done:
// (1) the pointer from the record type to its constructor is set
// (2) for each recordfield a selectorfunction is created and added to the prj
// NOTE: has to be called when existential variables have already been lifted
// -------------------------------------------------------------------------------------------------------------------------------------------------   
makeRecordFunctions :: !HeapPtr !CDataConsDefH !*CHeaps !*CProject -> (!Error, !Bool, !CDataConsDefH, !*CHeaps, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------   
makeRecordFunctions ptr dataconsdef heaps prj
	# (error, recorddef, prj)		= getRecordTypeDef dataconsdef.dcdAlgType prj
	| isError error					= (OK, False, dataconsdef, heaps, prj)
	
// BEZIG -- vermink het symbol type?
//	# dataconsdef					= {dataconsdef & dcdSymbolType = drop_strictness_s dataconsdef.dcdSymbolType}
	
	# recorddef						= {recorddef & rtdRecordConstructor = ptr}
	# (error, fielddefs, prj)		= umapError getRecordFieldDef recorddef.rtdFields prj
	| isError error					= (error, DummyValue, DummyValue, heaps, prj)
	# varnames						= smap (\field -> field.rfName) fielddefs
	# (fundefs, heaps, prj)			= makeSelectorFunctions dataconsdef.dcdSymbolType dataconsdef.dcdAlgType recorddef recorddef.rtdName varnames 0 fielddefs recorddef.rtdFields heaps prj
	# (more_fundefs, heaps, prj)	= makeUpdateFunctions dataconsdef.dcdSymbolType dataconsdef.dcdAlgType recorddef recorddef.rtdName recorddef.rtdRecordConstructor varnames 0 fielddefs recorddef.rtdFields heaps prj
	# (error, prj)					= putRecordTypeDef dataconsdef.dcdAlgType recorddef prj
	| isError error					= (error, DummyValue, DummyValue, heaps, prj)
	# (error, new_ptrs, prj)		= updateRecordFields recorddef.rtdFields fielddefs (zip2 fundefs more_fundefs) prj
	| isError error					= (error, DummyValue, DummyValue, heaps, prj)
	# mod_ptr						= ptrModule ptr
	# (mod, heaps)					= readPointer mod_ptr heaps
	# mod							= {mod & pmFunPtrs = new_ptrs ++ mod.pmFunPtrs}
	# heaps							= writePointer mod_ptr mod heaps
	
	# dataconsdef					= case recorddef.rtdIsDictionary of
										True	-> {dataconsdef & dcdName = "_create_" +++ recorddef.rtdName}
										False	-> {dataconsdef & dcdName = "_create_record_" +++ recorddef.rtdName}
	
	= (OK, True, dataconsdef, heaps, prj)
	where
		drop_strictness :: !CTypeH -> CTypeH
		drop_strictness (CStrict type)	= type
		drop_strictness type			= type
		
		drop_strictness_s :: !CSymbolTypeH -> CSymbolTypeH
		drop_strictness_s syt=:{sytArguments, sytResult}
			= {syt & sytArguments = smap drop_strictness sytArguments, sytResult = drop_strictness sytResult}
	
		makeSelectorFunctions :: !CSymbolTypeH !HeapPtr !CRecordTypeDefH !String ![String] !Int ![CRecordFieldDefH] ![HeapPtr] !*CHeaps !*CProject -> (![CFunDefH], !*CHeaps, !*CProject)  
		makeSelectorFunctions constype recptr recdef recname varnames index [field: fields] [fieldptr: fieldptrs] heaps prj
			# fun_var				= {DummyValue & evarName = "_record"}
			# (fun_scope, heaps)	= newPointer fun_var heaps
			# case_vars				= [{DummyValue & evarName = name} \\ name <- varnames]
			# (case_scope, heaps)	= newPointers case_vars heaps
			# function				=	{ fdName				= "_" +++ recname +++ "_select_" +++ field.rfName
										, fdOldName				= ""
										, fdArity				= 1
										, fdCaseVariables		= [0]
										, fdStrictVariables		= [0]
										, fdInfix				= CNoInfix
										, fdSymbolType			= {field.rfSymbolType & sytTypeVarScope = recdef.rtdTypeVarScope}
										, fdHasType				= True
										, fdExprVarScope		= [fun_scope]
										, fdBody				= CCase (CExprVar fun_scope)
																  (CAlgPatterns recptr [
																  	{ atpDataCons		= ptr
																	, atpExprVarScope	= case_scope
																	, atpResult			= CExprVar (case_scope !! index)
																	}
																  ]) Nothing
										, fdIsRecordSelector	= True
										, fdIsRecordUpdater		= False
										, fdNrDictionaries		= 0
										, fdRecordFieldDef		= fieldptr
										, fdIsDeltaRule			= False
										, fdDeltaRule			= \_ -> LBottom
										, fdOpaque				= False
										, fdDefinedness			= CDefinednessUnknown
										}
			# (functions, heaps, prj)= makeSelectorFunctions constype recptr recdef recname varnames (index+1) fields fieldptrs heaps prj
			= ([function: functions], heaps, prj)
		makeSelectorFunctions _ _ _ _ _ _ [] [] heaps prj
			= ([], heaps, prj)
		
		makeUpdateFunctions :: !CSymbolTypeH !HeapPtr !CRecordTypeDefH !String !HeapPtr ![String] !Int ![CRecordFieldDefH] ![HeapPtr] !*CHeaps !*CProject -> (![CFunDefH], !*CHeaps, !*CProject)
		makeUpdateFunctions constype recptr recdef recname consptr varnames index [field: fields] [fieldptr: fieldptrs] heaps prj
			# fun_vars				= [{DummyValue & evarName = "_record"}, {DummyValue & evarName = "_newfield"}]
			# (fun_scope, heaps)	= newPointers fun_vars heaps
			# case_vars				= [{DummyValue & evarName = name} \\ name <- varnames]
			# (case_scope, heaps)	= newPointers case_vars heaps
			# result_args			= [if (i == index) (CExprVar (fun_scope !! 1)) 
													   (CExprVar (case_scope !! i)) \\ i <- indexList varnames]
			
			# function				=	{ fdName				= "_" +++ recname +++ "_update_" +++ field.rfName
										, fdOldName				= ""
										, fdArity				= 2
										, fdCaseVariables		= [0]
										, fdStrictVariables		= [0]
										, fdInfix				= CNoInfix
										, fdSymbolType			= {field.rfSymbolType	& sytTypeVarScope	= recdef.rtdTypeVarScope
																						, sytArguments		= field.rfSymbolType.sytArguments ++ [field.rfSymbolType.sytResult]
																						, sytResult			= hd field.rfSymbolType.sytArguments}
										, fdHasType				= True
										, fdExprVarScope		= fun_scope
										, fdBody				= CCase (CExprVar (fun_scope !! 0))
																  (CAlgPatterns recptr
																	[	{ atpDataCons		= ptr
																		, atpExprVarScope	= case_scope
																		, atpResult			= consptr @@# result_args
																		}
																	]) Nothing
										, fdIsRecordSelector	= False
										, fdIsRecordUpdater		= True
										, fdNrDictionaries		= 0
										, fdRecordFieldDef		= fieldptr
										, fdIsDeltaRule			= False
										, fdDeltaRule			= \_ -> LBottom
										, fdOpaque				= False
										, fdDefinedness			= CDefinednessUnknown
										}
			# (functions, heaps, prj)= makeUpdateFunctions constype recptr recdef recname consptr varnames (index+1) fields fieldptrs heaps prj
			= ([function: functions], heaps, prj)
		makeUpdateFunctions _ _ _ _ _ _ _ [] [] heaps prj
			= ([], heaps, prj)

		updateRecordFields :: ![HeapPtr] ![CRecordFieldDefH] ![(CFunDefH, CFunDefH)] !*CProject -> (!Error, ![HeapPtr], !*CProject)  
		updateRecordFields [ptr:ptrs] [field:fields] [(selectorfun, updaterfun): funs] prj
			# modptr						= ptrModule ptr
			# (error, selectorptr, prj)		= addFunDef modptr selectorfun /*selectorfun.fdName*/ prj
			| isError error					= (error, [], prj)
			# (error, updaterptr, prj)		= addFunDef modptr updaterfun /*updaterfun.fdName*/ prj
			| isError error					= (error, [], prj)
			# field							= {field & rfSelectorFun = selectorptr, rfUpdaterFun = updaterptr}
			# (error, prj)					= putRecordFieldDef ptr field prj
			| isError error					= (error, [], prj)
			# (error, new_ptrs, prj)		= updateRecordFields ptrs fields funs prj
			| isError error					= (error, [], prj)
			= (OK, [selectorptr, updaterptr: new_ptrs], prj)
		updateRecordFields _ _ _ prj
			= (OK, [], prj)
		
		addFunDef :: !ModulePtr !CFunDefH !*CProject -> (!Error, !HeapPtr, !*CProject)  
		addFunDef mod_ptr fundef prj
			# (new_ptr, prjFunHeap)			= newPtr fundef prj.prjFunHeap
			# prj							= {prj & prjFunHeap = prjFunHeap}
			= (OK, CFunPtr mod_ptr new_ptr, prj)

// =================================================================================================================================================
// Accepts a pointer to a fundef. Traverses the expression belonging to it.
// Converts all applications of a fieldptr; these should be replaced by either the selector or the updater function of the field.
// Converts all applications of a classptr; these should be replaced by the record-constructor of the corresponding dictionary
// -------------------------------------------------------------------------------------------------------------------------------------------------   
setCreatorsAndSelectorsAndUpdaters :: !CFunDefH !*CProject -> (!Error, !CFunDefH, !*CProject)  
// -------------------------------------------------------------------------------------------------------------------------------------------------   
setCreatorsAndSelectorsAndUpdaters fundef prj
	# (body, prj)						= traverse fundef.fdBody prj
	# fundef							= {fundef & fdBody = body}
	= (OK, fundef, prj)
	where
		traverse :: !CExprH !*CProject -> (!CExprH, !*CProject)  
		traverse (CExprVar ptr) prj
			= (CExprVar ptr, prj)
		traverse (CShared ptr) prj
			= (CShared ptr, prj)
		traverse (expr @# exprs) prj
			# (expr, prj)				= traverse expr prj
			# (exprs, prj)				= umap traverse exprs prj
			= (expr @# exprs, prj)
		traverse (symptr @@# exprs) prj
			# (exprs, prj)				= umap traverse exprs prj
			# (error, classdef, prj)	= getClassDef symptr prj
			| isOK error				= get_creator_ptr classdef exprs prj
			# (error, field, prj)		= getRecordFieldDef symptr prj
			| isError error				= (symptr @@# exprs, prj)
			| (length exprs) == 1		= (field.rfSelectorFun @@# exprs, prj)
			= (field.rfUpdaterFun @@# exprs, prj)
			where
				get_creator_ptr :: !CClassDefH ![CExprH] !*CProject -> (!CExprH, !*CProject)  
				get_creator_ptr classdef exprs prj
					# (_, dict, prj)	= getRecordTypeDef classdef.cldDictionary prj
					= (dict.rtdRecordConstructor @@# exprs, prj)
		traverse (CLet strict binds expr) prj
			# traverse_bind				= (\(evar, expr) prj ->	let	(newexpr, newprj) = traverse expr prj 
																in	((evar, newexpr), newprj))
			# (binds, prj)				= umap traverse_bind binds prj
			# (expr, prj)				= traverse expr prj
			= (CLet strict binds expr, prj)
		traverse (CCase expr (CAlgPatterns typeptr patterns) maybe_expr) prj
			# (expr, prj)				= traverse expr prj
			# (maybe_expr, prj)			= case maybe_expr of
											Nothing		->	(Nothing, prj)
											Just expr	->	let	(newexpr, newprj) = traverse expr prj 
															in	(Just newexpr, newprj)
			# traverse_pattern			= (\atp prj ->	let	(expr, newprj) = traverse atp.atpResult prj
														in	({atp & atpResult = expr}, newprj))
			# (patterns, prj)			= umap traverse_pattern patterns prj
			= (CCase expr (CAlgPatterns typeptr patterns) maybe_expr, prj)
		traverse (CCase expr (CBasicPatterns value patterns) maybe_expr) prj
			# (expr, prj)				= traverse expr prj
			# (maybe_expr, prj)			= case maybe_expr of
											Nothing		->	(Nothing, prj)
											Just expr	->	let	(newexpr, newprj) = traverse expr prj 
															in	(Just newexpr, newprj)
			# traverse_pattern			= (\bap prj ->	let	(expr, newprj) = traverse bap.bapResult prj
														in	({bap & bapResult = expr}, newprj))
			# (patterns, prj)			= umap traverse_pattern patterns prj
			= (CCase expr (CBasicPatterns value patterns) maybe_expr, prj)
		traverse (CBasicValue value) prj
			= (CBasicValue value, prj)
		traverse (CCode codetype codetexts) prj
			= (CCode codetype codetexts, prj)
		traverse CBottom prj
			= (CBottom, prj)

// =================================================================================================================================================
// Accepts a pointer to a fundef. Traverses the expression belonging to it.
// Transforms applications of dummyForStrictAlias.
// -> created by compiler for #! x = y
// -> represented internally in Sparkle by CBuildTuplePtr 42
// -------------------------------------------------------------------------------------------------------------------------------------------------   
removeDummyForStrictAlias :: !CFunDefH -> CFunDefH
// -------------------------------------------------------------------------------------------------------------------------------------------------   
removeDummyForStrictAlias fundef=:{fdBody}
	= {fundef & fdBody = remove_dummy fdBody}
	where
		remove_dummy :: !CExprH -> CExprH
		remove_dummy (CExprVar ptr)
			= CExprVar ptr
		remove_dummy (CShared ptr)
			= CShared ptr
		remove_dummy (expr @# exprs)
			= (remove_dummy expr) @# (remove_dummy_list exprs)
		remove_dummy (ptr @@# exprs)
			| ptr == CBuildTuplePtr 42				= remove_dummy (hd exprs)
			= ptr @@# (map remove_dummy exprs)
		remove_dummy (CLet strict lets expr)
			= CLet strict (remove_dummy_let_list lets) (remove_dummy expr)
		remove_dummy (CCase expr patterns mb_default)
			= CCase (remove_dummy expr) patterns (remove_dummy_maybe mb_default)
		remove_dummy (CBasicValue value)
			= CBasicValue value
		remove_dummy (CCode text cod)
			= CCode text cod
		remove_dummy CBottom
			= CBottom
		
		remove_dummy_list :: ![CExprH] -> [CExprH]
		remove_dummy_list [expr: exprs]
			= [remove_dummy expr: remove_dummy_list exprs]
		remove_dummy_list []
			= []
		
		remove_dummy_let :: !(!CExprVarPtr, !CExprH) -> (!CExprVarPtr, !CExprH)
		remove_dummy_let (ptr, expr)
			= (ptr, remove_dummy expr)
		
		remove_dummy_let_list :: ![(CExprVarPtr, CExprH)] -> [(CExprVarPtr, CExprH)]
		remove_dummy_let_list [el: els]
			= [remove_dummy_let el: remove_dummy_let_list els]
		remove_dummy_let_list []
			= []
		
		remove_dummy_maybe :: !(Maybe CExprH) -> Maybe CExprH
		remove_dummy_maybe (Just expr)
			= Just (remove_dummy expr)
		remove_dummy_maybe Nothing
			= Nothing

// =================================================================================================================================================
// Accepts a pointer to a fundef. Traverses the expression belonging to it.
// Transforms case-expressions such that the default cal always be found on the non-matching case alternative
// (this is NOT the case in the compiler, where on a mismatch you have to look at the surrounding case)
// -------------------------------------------------------------------------------------------------------------------------------------------------   
simplifyCases :: !CFunDefH !*CHeaps !*CProject -> (!Error, !CFunDefH, !*CHeaps, !*CProject)  
// -------------------------------------------------------------------------------------------------------------------------------------------------   
simplifyCases fundef=:{fdBody} heaps prj
	#! fdBody							= duplicateDefaults Nothing fdBody
	#! fdBody							= mergeCases fdBody
	#! (fdBody, heaps)					= selectPattern Nothing [] fdBody heaps
	#! (error, fdBody, prj)				= removeDeadDefaults fdBody prj
	| isError error						= (error, DummyValue, heaps, prj)
	= (OK, {fundef & fdBody = fdBody}, heaps, prj)

// =================================================================================================================================================
// Accepts a pointer to a fundef. Traverses the expression belonging to it.
// Simplifies multiple non-strict lets to a single one (if possible).
// -------------------------------------------------------------------------------------------------------------------------------------------------   
simplifyLets :: !CFunDefH !*CProject -> (!CFunDefH, !*CProject)  
// -------------------------------------------------------------------------------------------------------------------------------------------------   
simplifyLets fundef prj
	# body								= collect_lets [] fundef.fdBody
	# fundef							= {fundef & fdBody = body}
	= (fundef, prj)
	where
		collect_lets :: ![(CExprVarPtr, CExprH)] !CExprH -> CExprH
		collect_lets lets (CLet False defs expr)
			= collect_lets (lets ++ defs) expr
		collect_lets [def:defs] other
			= CLet False [def:defs] (collect_lets [] other)
		collect_lets [] (CExprVar ptr)
			= CExprVar ptr
		collect_lets [] (CShared ptr)
			= CShared ptr
		collect_lets [] (expr @# exprs)
			= (collect_lets [] expr) @# (smap (collect_lets []) exprs)
		collect_lets [] (ptr @@# exprs)
			= ptr @@# (smap (collect_lets []) exprs)
		collect_lets [] (CLet strict lets expr)
			| strict			= CLet strict lets (collect_lets [] expr)
			= collect_lets lets expr
		collect_lets [] (CCase expr patterns maybe_default)
			# expr				= collect_lets [] expr
			# maybe_default		= case maybe_default of
									Nothing		-> Nothing
									(Just def)	-> Just (collect_lets [] def)
			= CCase expr patterns maybe_default
		collect_lets [] (CBasicValue basicvalue)
			= CBasicValue basicvalue
		collect_lets [] (CCode codetype codecontents)
			= CCode codetype codecontents
		collect_lets [] CBottom
			= CBottom















/*
// =================================================================================================================================================
// Accepts two overlapping scopes as arguments.
// References to the second scope are transformed to references to the first scope.
// The name is used for identification.
// -------------------------------------------------------------------------------------------------------------------------------------------------   
mergeTypeScopes :: ![!CTypeVarDef] ![!CTypeVarDef] !CTypeH -> (!Error, !CTypeH)
// -------------------------------------------------------------------------------------------------------------------------------------------------   
mergeTypeScopes goodscope badscope (CTypeVar ptr)
	# (_, name)				= findName badscope index
	| name == ""			= (OK, CTypeVar index)
	# (error, newindex)		= searchInScope goodscope name
	| newindex < 0			= (OK, CTypeVar index)
	= (OK, CTypeVar newindex)
	where
		findName :: [!CTypeVarDef] !CTypeVarId -> (!Error, !String)
		findName [def:defs] id
			| def.tvarId == id			= (OK, def.tvarName)
			= findName defs id
		findName [] id
			= (OK, "")
		
		searchInScope :: [!CTypeVarDef] !String -> (!Error, !CTypeVarId)
		searchInScope [def:defs] name
			| def.tvarName == name		= (OK, def.tvarId)
			= searchInScope defs name
		searchInScope [] name
			= (OK, -1)
mergeTypeScopes goodscope badscope (type1 ==> type2)
	# (error, type1)		= mergeTypeScopes goodscope badscope type1
	| isError error			= (error, DummyValue)
	# (error, type2)		= mergeTypeScopes goodscope badscope type2
	| isError error			= (error, DummyValue)
	= (OK, type1 ==> type2)
mergeTypeScopes goodscope badscope (type @^ types)
	# (error, type)			= mergeTypeScopes goodscope badscope type
	| isError error			= (error, DummyValue)
	# (error, types)		= mapError (mergeTypeScopes goodscope badscope) types
	| isError error			= (error, DummyValue)
	= (OK, type @^ types)
mergeTypeScopes goodscope badscope (ptr @@^ types)
	# (error, types)		= mapError (mergeTypeScopes goodscope badscope) types
	| isError error			= (error, DummyValue)
	= (OK, ptr @@^ types)
mergeTypeScopes _ _ (CBasicType basictype)
	= (OK, CBasicType basictype)
mergeTypeScopes goodscope badscope (CStrict type)
	# (error, type)			= mergeTypeScopes goodscope badscope type
	| isError error			= (error, DummyValue)
	= (OK, CStrict type)
mergeTypeScopes _ _ CUnTypable
	= (OK, CUnTypable)

// =================================================================================================================================================
// Variant of mergeTypeScopes that works on ClassRestrictions.
// -------------------------------------------------------------------------------------------------------------------------------------------------   
mergeClassRestrictions :: [!CTypeVarDef] [!CTypeVarDef] !CClassRestrictionH -> (!Error, !CClassRestrictionH)
// -------------------------------------------------------------------------------------------------------------------------------------------------   
mergeClassRestrictions goodscope badscope restrictions
	# (error, goodtypes)		= mapError (mergeTypeScopes goodscope badscope) restrictions.ccrTypes
	| isError error				= (error, DummyValue)
	= (OK, {restrictions & ccrTypes = goodtypes})

// =================================================================================================================================================
// Accepts two overlapping scopes as arguments.
// Variables that occur in both scopes are removed from the SECOND scope.
// The name is used for identification.
// -------------------------------------------------------------------------------------------------------------------------------------------------   
cleanTypeScope :: ![!CTypeVarDef] ![!CTypeVarDef] -> [!CTypeVarDef]
// -------------------------------------------------------------------------------------------------------------------------------------------------   
cleanTypeScope goodscope [def:defs]
	| definedInScope def.tvarName goodscope			= cleanTypeScope goodscope defs
	= [def: cleanTypeScope goodscope defs]
	where
		definedInScope :: !String ![!CTypeVarDef] -> !Bool
		definedInScope name [def:defs]
			| def.tvarName == name					= True
			= definedInScope name defs
		definedInScope name []
			= False
cleanTypeScope goodscope []
	= []

// =================================================================================================================================================
// Uses mergeTypeScopes to transform internal references in the symboltype to references to the argument scope.
// The scope is then cleaned up.
// -------------------------------------------------------------------------------------------------------------------------------------------------   
mergeSymbolType :: ![!CTypeVarDef] !CSymbolTypeH -> (!Error, !CSymbolTypeH)
// -------------------------------------------------------------------------------------------------------------------------------------------------   
mergeSymbolType goodscope symboltype
	# badscope					= symboltype.sytTypeVarScope
	# (error, goodresult)		= mergeTypeScopes goodscope badscope symboltype.sytResult
	| isError error				= (error, DummyValue)
	# (error, goodargs)			= mapError (mergeTypeScopes goodscope badscope) symboltype.sytArguments
	| isError error				= (error, DummyValue)
	# (error, goodrestrictions)	= mapError (mergeClassRestrictions goodscope badscope) symboltype.sytClassRestrictions
	| isError error				= (error, DummyValue)
	# cleanedscope				= cleanTypeScope goodscope badscope
	= (OK, {sytTypeVarScope = cleanedscope, sytArguments = goodargs, sytResult = goodresult,
	        sytClassRestrictions = goodrestrictions})

// =================================================================================================================================================
// Unifies the typevarscope of the recordfield with the typevarscope of the recordtype.
// -------------------------------------------------------------------------------------------------------------------------------------------------   
mergeRecordField :: !HeapPtr !*CProject -> (!Error, !*CProject)  
// -------------------------------------------------------------------------------------------------------------------------------------------------   
mergeRecordField ptr prj
	# (error, fielddef, prj)			= getRecordFieldDef ptr prj
	| isError error						= (error, prj)
	# (error, recorddef, prj)			= getRecordTypeDef fielddef.rfRecordType prj
	| isError error						= (error, prj)
	# (error, goodtype)					= mergeSymbolType recorddef.rtdTypeVarScope fielddef.rfSymbolType
	| isError error						= (pushError (X_Internal ("Could not merge symboltype of " +++ fielddef.rfName +++ " in record " +++ recorddef.rtdName)) error, prj)
	# fielddef							= {fielddef & rfSymbolType = goodtype}
	# (error, prj)						= putRecordFieldDef ptr fielddef prj
	| isError error						= (error, prj)
	= (OK, prj)

// =================================================================================================================================================
// Unifies the typevarscope of the (symbol of the) dataconstructor with the typevarscope of the algtype.
// If the dataconstructor is a record-constructor, the scope of the record type is used.
// -------------------------------------------------------------------------------------------------------------------------------------------------   
mergeDataCons :: !HeapPtr !*CProject -> (!Error, !*CProject)  
// -------------------------------------------------------------------------------------------------------------------------------------------------   
mergeDataCons ptr prj
	# (error, consdef, prj)				= getDataConsDef ptr prj
	| isError error						= (error, prj)
	# (error, algtype, prj)				= getAlgTypeDef consdef.dcdAlgType prj
	# scope								= if (isOK error) algtype.atdTypeVarScope []
	# name								= if (isOK error) ("algebraic type " +++ algtype.atdName) ""
	# (error, rectype, prj)				= getRecordTypeDef consdef.dcdAlgType prj
	# scope								= if (isOK error) rectype.rtdTypeVarScope scope
	# name								= if (isOK error) ("record type " +++ rectype.rtdName) name
	# (error, goodtype)					= mergeSymbolType scope consdef.dcdSymbolType
	| isError error						= (pushError (X_Internal ("Could not merge symboltype of " +++ consdef.dcdName +++ " in " +++ name)) error, prj)
	# consdef							= {consdef & dcdSymbolType = goodtype}
	# (error, prj)						= putDataConsDef ptr consdef prj
	| isError error						= (error, prj)
	= (OK, prj)

// =================================================================================================================================================
// Unifies the typevarscope of a member of a class with the scope of its class.
// Also removes redundant class-restrictions which are generated by the compiler for all members.
// -------------------------------------------------------------------------------------------------------------------------------------------------   
mergeMember :: !HeapPtr !*CProject -> (!Error, !*CProject)  
// -------------------------------------------------------------------------------------------------------------------------------------------------   
mergeMember ptr prj
	# (error, memberdef, prj)			= getMemberDef ptr prj
	| isError error						= (error, prj)
	# (error, classdef, prj)			= getClassDef memberdef.mbdClass prj
	| isError error						= (error, prj)
	# badtype							= memberdef.mbdSymbolType
	# (error, goodtype)					= mergeSymbolType classdef.cldTypeVarScope badtype
	| isError error						= (pushError (X_Internal ("Could not merge symboltype of member " +++ memberdef.mbdName +++ " in class " +++ classdef.cldName)) error, prj)
	# badrestrictions					= goodtype.sytClassRestrictions
	# goodrestrictions					= purifyRestrictions memberdef.mbdClass classdef.cldTypeVarScope badrestrictions
	# goodtype							= {goodtype & sytClassRestrictions = goodrestrictions}
	# memberdef							= {memberdef & mbdSymbolType = goodtype}
	# (error, prj)						= putMemberDef ptr memberdef prj
	| isError error						= (error, prj)
	= (OK, prj)
	where
		purifyRestrictions :: !HeapPtr ![!CTypeVarDef] ![!CClassRestrictionH] -> [!CClassRestrictionH]
		purifyRestrictions classptr classscope [restriction:restrictions]
			# ccrClass					= restriction.ccrClass
			# ccrTypes					= restriction.ccrTypes
			| ccrClass <> classptr		= [restriction: purifyRestrictions classptr classscope restrictions]
			# ok						= checkTypes ccrTypes classscope
			| not ok					= [restriction: purifyRestrictions classptr classscope restrictions]
			= purifyRestrictions classptr classscope restrictions
		purifyRestrictions classptr classscope []
			= []
		
		checkTypes :: ![!CTypeH] ![!CTypeVarDef] -> !Bool
		checkTypes [CTypeVar id: types] scope
			| in_scope id scope			= checkTypes types scope
			= False
		checkTypes [other: types] scope
			= False
		checkTypes [] scope
			= True
		
		in_scope :: !CTypeVarId ![!CTypeVarDef] -> !Bool
		in_scope id [var:vars]
			| var.tvarId == id			= True
			= in_scope id vars
		in_scope id []
			= False
*/

// =================================================================================================================================================
// Marks the presence of the instance in the corresponding classdef.
// Also sets the infix of a member function to the infix of the class member.
// Also changes the name of the member function.
// -------------------------------------------------------------------------------------------------------------------------------------------------   
markInstance :: !HeapPtr !CInstanceDefH !*CProject -> (!Error, !*CProject)  
// -------------------------------------------------------------------------------------------------------------------------------------------------   
markInstance ptr instancedef prj
	# (error, classdef, prj)			= getClassDef instancedef.indClass prj
	| isError error						= (error, prj)
	# classdef							= {classdef & cldInstances = [ptr:classdef.cldInstances]}
	# (error, prj)						= putClassDef instancedef.indClass classdef prj
	| isError error						= (error, prj)
	# (suffix, prj)						= pretty_suffix instancedef.indClassArguments prj
	# (error, prj)						= set_infix instancedef.indMemberFunctions classdef.cldMembers suffix prj
	| isError error						= (error, prj)
	= (OK, prj)
	where
		set_infix :: ![HeapPtr] ![HeapPtr] !String !*CProject -> (!Error, !*CProject)
		set_infix [ptr:ptrs] [member_ptr:member_ptrs] suffix prj
			# (error, fundef, prj)		= getFunDef ptr prj
			| isError error				= (error, prj)
			# (error, memberdef, prj)	= getMemberDef member_ptr prj
			| isError error				= (error, prj)
			# fundef					= {fundef & fdInfix = memberdef.mbdInfix, fdName = fundef.fdName +++ suffix, fdOldName = fundef.fdName}
			# (error, prj)				= putFunDef ptr fundef prj
			| isError error				= (error, prj)
			= set_infix ptrs member_ptrs suffix prj
		set_infix _ _ suffix prj
			= (OK, prj)
		
		pretty_suffix :: ![CTypeH] !*CProject -> (!String, !*CProject)
		pretty_suffix [CBasicType CBoolean: types] prj
			# (suffix, prj)				= pretty_suffix types prj
			= ("_bool" +++ suffix, prj)
		pretty_suffix [CBasicType CCharacter: types] prj
			# (suffix, prj)				= pretty_suffix types prj
			= ("_char" +++ suffix, prj)
		pretty_suffix [CBasicType CInteger: types] prj
			# (suffix, prj)				= pretty_suffix types prj
			= ("_int" +++ suffix, prj)
		pretty_suffix [CBasicType CRealNumber: types] prj
			# (suffix, prj)				= pretty_suffix types prj
			= ("_real" +++ suffix, prj)
		pretty_suffix [CBasicType CString: types] prj
			# (suffix, prj)				= pretty_suffix types prj
			= ("_string" +++ suffix, prj)
		pretty_suffix [ptr @@^ _: types] prj
			# (name, prj)				= get_name ptr prj
			# (suffix, prj)				= pretty_suffix types prj
			= ("_" +++ name +++ suffix, prj)
			where
				get_name ptr=:(CAlgTypePtr _ _) prj
					# (_, def, prj)		= getAlgTypeDef ptr prj
					= (def.atdName, prj)
				get_name ptr=:(CRecordTypePtr _ _) prj
					# (_, def, prj)		= getRecordTypeDef ptr prj
					= (def.rtdName, prj)
				get_name (CTuplePtr n) prj				= ("tuple" +++ toString n, prj)
				get_name CNormalArrayPtr prj			= ("array", prj)
				get_name CStrictArrayPtr prj			= ("sarray", prj)
				get_name CUnboxedArrayPtr prj			= ("uarray", prj)
				get_name CListPtr prj					= ("list", prj)
				get_name other prj						= ("x", prj)
		pretty_suffix [_ ==> _: types] prj
			# (suffix, prj)				= pretty_suffix types prj
			= ("_fun" +++ suffix, prj)
		pretty_suffix [other: types] prj
			# (suffix, prj)				= pretty_suffix types prj
			= ("_?" +++ suffix, prj)
		pretty_suffix [] prj
			= ("", prj)

// =================================================================================================================================================
// Accepts a pointer to a fundef. Traverses the expression belonging to it.
// Finds all expressions on which a case distinction is ALWAYS performed.
// Marks these variables in fdCaseVariables field.
// NOTE: Existing information in this field (derived in Conversion.icl) is erroneous.
// -------------------------------------------------------------------------------------------------------------------------------------------------   
findCaseVars :: !CFunDefH !*CProject -> (!CFunDefH, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------   
findCaseVars fundef prj
	# (case_vars, prj)					= collect fundef.fdBody prj
	# fundef							= {fundef & fdCaseVariables = get_indexes 0 fundef.fdExprVarScope case_vars}
	= (fundef, prj)
	where
		get_indexes :: !Int ![CExprVarPtr] ![CExprVarPtr] -> [Int]
		get_indexes index [arg_var:arg_vars] case_vars
			= case (isMember arg_var case_vars) of
				True					-> [index: get_indexes (index+1) arg_vars case_vars]
				False					-> get_indexes (index+1) arg_vars case_vars
		get_indexes index [] case_vars
			= []
		
		// collect case variables that occur in ONE argument expression
		collect :: !CExprH !*CProject -> (![CExprVarPtr], !*CProject)
		collect (expr @# exprs) prj
			= collect expr prj
		collect (ptr @@# exprs) prj
			# (error, consdef, prj)		= getDataConsDef ptr prj
			| isOK error				= collectList (filter_strict consdef.dcdSymbolType.sytArguments exprs) prj
			# (error, fundef, prj)		= getFunDef ptr prj
			| isOK error				= collectList (filter_strict fundef.fdSymbolType.sytArguments exprs) prj
			= ([], prj)
			where
				filter_strict :: ![CTypeH] ![CExprH] -> [CExprH]
				filter_strict [CStrict _:types] [expr:exprs]
					= [expr: filter_strict types exprs]
				filter_strict [_:types] [_:exprs]
					= filter_strict types exprs
				filter_strict _ _
					= []
		collect (CLet strict binds expr) prj
			# strict_exprs				= case strict of
											True	-> [expr: map snd binds]
											False	-> [expr]
			= collectList strict_exprs prj
		collect (CCase (CExprVar ptr) patterns mb_default) prj
			# (case_vars, prj)			= collect (CCase CBottom patterns mb_default) prj
			= ([ptr:case_vars], prj)
		collect (CCase _ patterns mb_default) prj
			# alternatives				= find_alternatives patterns mb_default
			= collectRestrictiveList alternatives prj
			where
				find_alternatives :: !CCasePatternsH !(Maybe CExprH) -> [CExprH]
				find_alternatives (CAlgPatterns _ patterns) Nothing
					= [pattern.atpResult \\ pattern <- patterns]
				find_alternatives (CAlgPatterns _ patterns) (Just expr)
					= [expr: [pattern.atpResult \\ pattern <- patterns]]
				find_alternatives (CBasicPatterns _ patterns) Nothing
					= [pattern.bapResult \\ pattern <- patterns]
				find_alternatives (CBasicPatterns _ patterns) (Just expr)
					= [expr: [pattern.bapResult \\ pattern <- patterns]]
		collect _ prj
			= ([], prj)
		
		collectList :: ![CExprH] !*CProject -> (![CExprVarPtr], !*CProject)
		collectList [expr:exprs] prj
			# (case_vars1, prj)			= collect expr prj
			# (case_vars2, prj)			= collectList exprs prj
			= (case_vars1 ++ case_vars2, prj)
		collectList [] prj
			= ([], prj)
		
		// collect case expressions that occur in ALL argument expressions
		collectRestrictiveList :: ![CExprH] !*CProject -> (![CExprVarPtr], !*CProject)
		collectRestrictiveList [expr:exprs] prj
			# (case_vars1, prj)			= collect expr prj
			| isEmpty exprs				= (case_vars1, prj)
			# (case_vars2, prj)			= collectRestrictiveList exprs prj
			= (intersect case_vars1 case_vars2, prj)
			where
				intersect :: ![CExprVarPtr] ![CExprVarPtr] -> [CExprVarPtr]
				intersect [var1:vars1] vars2
					= case (isMember var1 vars2) of
						True			-> [var1: intersect vars1 vars2]
						False			-> intersect vars1 vars2
				intersect [] vars2
					= []
		collectRestrictiveList [] prj
			= ([], prj)

// =================================================================================================================================================
// Marks variables that appear in a strict context in the body of the function.
// Also (side-effect!) counts nr of dictionaries. (and removes the strictness of these arguments)
// -------------------------------------------------------------------------------------------------------------------------------------------------
findStrictVars :: !CFunDefH !*CHeaps !*CProject -> (!CFunDefH, !*CHeaps, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------
findStrictVars fundef heaps prj
	# (ptrs, heaps, prj)				= mark [] fundef.fdBody [] heaps prj
	# (nr_dicts, prj)					= count_dictionaries 0 fundef.fdSymbolType.sytArguments prj
	# fundef							= {fundef	& fdStrictVariables				= get_strict_indexes 0 fundef.fdExprVarScope ptrs
													, fdNrDictionaries				= nr_dicts
													, fdSymbolType.sytArguments		= remove nr_dicts fundef.fdSymbolType.sytArguments
										  }
	= (fundef, heaps, prj)
	where
		remove :: !Int ![CTypeH] -> [CTypeH]
		remove 0 types					= types
		remove n []						= []
		remove n [CStrict type:types]	= [type: remove (n-1) types]
		remove n [type:types]			= [type: remove (n-1) types]
		
		mark_function_arguments :: ![CExprVarPtr] !*CHeaps -> *CHeaps
		mark_function_arguments [ptr:ptrs] heaps
			# (var, heaps)				= readPointer ptr heaps
			# var						= {var & evarInfo = EVar_Nothing}
			# heaps						= writePointer ptr var heaps
			= mark_function_arguments ptrs heaps
		mark_function_arguments [] heaps
			= heaps
	
		markL :: ![CExprVarPtr] ![CExprH] !*CHeaps !*CProject -> (![CExprVarPtr], !*CHeaps, !*CProject)
		markL strict_vars [expr:exprs] heaps prj
			# (strict_vars, heaps, prj)	= mark strict_vars expr [] heaps prj
			= markL strict_vars exprs heaps prj
		markL strict_vars [] heaps prj
			= (strict_vars, heaps, prj)
	
		mark :: ![CExprVarPtr] !CExprH ![CExprH] !*CHeaps !*CProject -> (![CExprVarPtr], !*CHeaps, !*CProject)
		mark strict_vars (CExprVar ptr) extra_args heaps prj
			# (var, heaps)				= readPointer ptr heaps
			# (ok, let_def)				= get_let var.evarInfo
			| not ok					= ([ptr:strict_vars], heaps, prj)
			# var						= {var & evarInfo = EVar_Nothing}		// prevents cycle in spine
			# heaps						= writePointer ptr var heaps
			= mark strict_vars let_def extra_args heaps prj
			where
				get_let :: !CExprVarInfo -> (!Bool, !CExprH)
				get_let (EVar_Temp expr)		= (True, expr)
				get_let _						= (False, DummyValue)
		// too restrictive, but better safe than sorry (vars in exprs might also be strict)
		mark strict_vars (expr @# exprs) extra_args heaps prj
			= mark strict_vars expr (exprs ++ extra_args) heaps prj
		mark strict_vars (ptr @@# exprs) extra_args heaps prj
			# (error, select, prj)		= getFunDef ptr prj
			| isError error				= markA strict_vars ptr (exprs ++ extra_args) heaps prj
			# is_selector				= select.fdIsRecordSelector
			| not is_selector			= markA strict_vars ptr (exprs ++ extra_args) heaps prj
			# (error, field, prj)		= getRecordFieldDef select.fdRecordFieldDef prj
			| isError error				= markA strict_vars ptr (exprs ++ extra_args) heaps prj
			# (error, record, prj)		= getRecordTypeDef field.rfRecordType prj
			| isError error				= markA strict_vars ptr (exprs ++ extra_args) heaps prj
			# is_dictionary				= record.rtdIsDictionary
			| not is_dictionary			= markA strict_vars ptr (exprs ++ extra_args) heaps prj
			# (error, clas, prj)		= getClassDef record.rtdClassDef prj
			| isError error				= markA strict_vars ptr (exprs ++ extra_args) heaps prj
			# recursive_call			= field.rfIndex >= length clas.cldMembers
			| recursive_call			= markA strict_vars ptr (exprs ++ extra_args) heaps prj
			# member_ptr				= clas.cldMembers !! field.rfIndex
			# (error, member, prj)		= getMemberDef member_ptr prj
			| isError error				= markA strict_vars ptr (exprs ++ extra_args) heaps prj
			= markI strict_vars member.mbdSymbolType.sytArguments (tl exprs ++ extra_args) heaps prj
		mark strict_vars (CCase expr patterns def) extra_args heaps prj
			# rhs						= get_rhs patterns def
			# (candidates, heaps, prj)	= mark_all rhs heaps prj
			# more_vars					= get_intersect candidates
			= mark (strict_vars ++ more_vars) expr [] heaps prj
			where
				get_rhs :: !CCasePatternsH !(Maybe CExprH) -> [CExprH]
				get_rhs (CAlgPatterns _ patterns) Nothing
					= [pattern.atpResult \\ pattern <- patterns]
				get_rhs (CAlgPatterns _ patterns) (Just expr)
					= [expr: [pattern.atpResult \\ pattern <- patterns]]
				get_rhs (CBasicPatterns _ patterns) Nothing
					= [pattern.bapResult \\ pattern <- patterns]
				get_rhs (CBasicPatterns _ patterns) (Just expr)
					= [expr:[pattern.bapResult \\ pattern <- patterns]]
				
				mark_all :: ![CExprH] !*CHeaps !*CProject -> (![[CExprVarPtr]], !*CHeaps, !*CProject)
				mark_all [expr:exprs] heaps prj
					# (vars, heaps, prj)		= mark [] expr [] heaps prj
					# (more_vars, heaps, prj)	= mark_all exprs heaps prj
					= ([vars:more_vars], heaps, prj)
				mark_all [] heaps prj
					= ([], heaps, prj)
				
				get_intersect :: ![[CExprVarPtr]] -> [CExprVarPtr]
				get_intersect [some: more]
					= check some more
				
				check :: ![CExprVarPtr] ![[CExprVarPtr]] -> [CExprVarPtr]
				check [ptr:ptrs] more
					| in_all ptr more	= [ptr: check ptrs more]
					= check ptrs more
				check [] more
					= []
				
				in_all :: !CExprVarPtr ![[CExprVarPtr]] -> Bool
				in_all ptr []
					= True
				in_all ptr [list:more]
					| isMember ptr list	= in_all ptr more
					= False
		mark strict_vars (CLet True lets expr) extra_args heaps prj
			# (vars, exprs)				= unzip lets
			# (strict_vars, heaps, prj)	= markL strict_vars exprs heaps prj
			= mark strict_vars expr [] heaps prj
		mark strict_vars (CLet False lets expr) extra_args heaps prj
			# heaps						= mark_lets lets heaps
			= mark strict_vars expr [] heaps prj
			where
				mark_lets :: ![(CExprVarPtr, CExprH)] !*CHeaps -> *CHeaps
				mark_lets [(ptr,expr):lets] heaps
					# (var, heaps)		= readPointer ptr heaps
					# var				= {var & evarInfo = EVar_Temp expr}
					# heaps				= writePointer ptr var heaps
					= mark_lets lets heaps
				mark_lets [] heaps
					= heaps
		mark strict_vars (CBasicValue _) extra_args heaps prj
			= (strict_vars, heaps, prj)
		mark strict_vars (CCode _ _) extra_args heaps prj
			= (strict_vars, heaps, prj)
		mark strict_vars CBottom extra_args heaps prj
			= (strict_vars, heaps, prj)
		
		markI :: ![CExprVarPtr] ![CTypeH] ![CExprH] !*CHeaps !*CProject -> (![CExprVarPtr], !*CHeaps, !*CProject)
		markI strict_vars [CStrict type:types] [expr:exprs] heaps prj
			# (strict_vars, heaps, prj)	= mark strict_vars expr [] heaps prj
			= markI strict_vars types exprs heaps prj
		markI strict_vars [type:types] [expr:exprs] heaps prj
			= markI strict_vars types exprs heaps prj
		markI strict_vars _ _ heaps prj
			= (strict_vars, heaps, prj)
		
		markA :: ![CExprVarPtr] !HeapPtr ![CExprH] !*CHeaps !*CProject -> (![CExprVarPtr], !*CHeaps, !*CProject)
		markA strict_vars ptr exprs heaps prj
			# (error, fundef, prj)		= getFunDef ptr prj
			| isOK error				= markI strict_vars fundef.fdSymbolType.sytArguments exprs heaps prj
			# (error, consdef, prj)		= getDataConsDef ptr prj
			| isOK error				= markI strict_vars consdef.dcdSymbolType.sytArguments exprs heaps prj
			= (strict_vars, heaps, prj)
		
		get_strict_indexes :: !Int ![CExprVarPtr] ![CExprVarPtr] -> [Int]
		get_strict_indexes current [ptr:ptrs] strict_vars
			# indexes					= get_strict_indexes (current+1) ptrs strict_vars
			= case isMember ptr strict_vars of
				True	-> [current: indexes]
				False	-> indexes
		get_strict_indexes current [] strict_vars
			= []
		
		count_dictionaries :: !Int ![CTypeH] !*CProject -> (!Int, !*CProject)
		count_dictionaries nr [] prj
			= (nr, prj)
		count_dictionaries nr [CStrict type:types] prj
			= count_dictionaries nr [type:types] prj
		count_dictionaries nr [ptr @@^ _: types] prj
			# (error, rectype, prj)		= getRecordTypeDef ptr prj
			| isError error				= (nr, prj)
			= case rectype.rtdIsDictionary of
				True	-> count_dictionaries (nr+1) types prj
				False	-> (nr, prj)
		count_dictionaries nr [_:_] prj
			= (nr, prj)



















// -------------------------------------------------------------------------------------------------------------------------------------------------
bindToProject :: ![ModulePtr] !*CHeaps !*CProject -> (!Error, !*CHeaps, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------
bindToProject new_ptrs heaps prj
	# (old_ptrs, prj)					= prj!prjModules
	# all_ptrs							= new_ptrs ++ old_ptrs
	# prj								= {prj & prjModules = all_ptrs}
	# (all_names, heaps)				= getPointerNames all_ptrs heaps
	# (error, new_modules, heaps, prj)	= uumapError (bindModule all_names all_ptrs) new_ptrs heaps prj
	| isError error						= (error, heaps, prj)
	# heaps								= writePointers new_ptrs new_modules heaps
	
	# (error, prj)						= actOnRecords new_modules prj
	| isError error						= (error, heaps, prj)
	# (error, prj)						= actOnClasses new_modules prj
	| isError error						= (error, heaps, prj)
	# (error, heaps, prj)				= actOnConses new_modules heaps prj
	| isError error						= (error, heaps, prj)
	# (error, heaps, prj)				= actOnFunctions new_modules heaps prj
	| isError error						= (error, heaps, prj)
	# (error, prj)						= actOnInstances new_modules prj
	| isError error						= (error, heaps, prj)
	# (error, prj)						= actOnMembers new_modules prj
	| isError error						= (error, heaps, prj)
	
	= (OK, heaps, prj)
	where
		actOnConses :: ![CModule] !*CHeaps !*CProject -> (!Error, !*CHeaps, !*CProject)
		actOnConses [mod:mods] heaps prj
			# (error, heaps, prj)		= act mod.pmDataConsPtrs heaps prj
			| isError error				= (error, heaps, prj)
			= actOnConses mods heaps prj
			where
				act :: ![HeapPtr] !*CHeaps !*CProject -> (!Error, !*CHeaps, !*CProject)
				act [ptr:ptrs] heaps prj
					# (error, def, prj)		= getDataConsDef ptr prj
					| isError error			= (error, heaps, prj)
					# (error, changed, def, heaps, prj)
											= makeRecordFunctions ptr def heaps prj
					| isError error			= (error, heaps, prj)
					# (error, prj)			= case changed of
												True	-> putDataConsDef ptr def prj
												False	-> (OK, prj)
					| isError error			= (error, heaps, prj)
					= act ptrs heaps prj
				act [] heaps prj
					= (OK, heaps, prj)
		actOnConses [] heaps prj
			= (OK, heaps, prj)
		
		actOnRecords :: ![CModule] !*CProject -> (!Error, !*CProject)
		actOnRecords [mod:mods] prj
			# (error, prj)				= act mod.pmRecordTypePtrs prj
			| isError error				= (error, prj)
			= actOnRecords mods prj
			where
				act :: ![HeapPtr] !*CProject -> (!Error, !*CProject)
				act [ptr:ptrs] prj
					# (error, def, prj)		= getRecordTypeDef ptr prj
					| isError error			= (error, prj)
					# (error, def, prj)		= liftExistentialVarsRT def prj
					| isError error			= (error, prj)
					# (error, prj)			= putRecordTypeDef ptr def prj
					| isError error			= (error, prj)
					= act ptrs prj
				act [] prj
					= (OK, prj)
		actOnRecords [] prj
			= (OK, prj)
		
		actOnClasses :: ![CModule] !*CProject -> (!Error, !*CProject)
		actOnClasses [mod:mods] prj
			# (error, prj)				= act mod.pmClassPtrs prj
			| isError error				= (error, prj)
			= actOnClasses mods prj
			where
				act :: ![HeapPtr] !*CProject -> (!Error, !*CProject)
				act [ptr:ptrs] prj
					# (error, def, prj)		= getClassDef ptr prj
					| isError error			= (error, prj)
					# (error, prj)			= markDictionary ptr def prj
					| isError error			= (error, prj)
					= act ptrs prj
				act [] prj
					= (OK, prj)
		actOnClasses [] prj
			= (OK, prj)
		
		actOnFunctions :: ![CModule] !*CHeaps !*CProject -> (!Error, !*CHeaps, !*CProject)
		actOnFunctions [mod:mods] heaps prj
			# (error, heaps, prj)		= act mod.pmName mod.pmFunPtrs heaps prj
			| isError error				= (error, heaps, prj)
			= actOnFunctions mods heaps prj
			where
				act :: !ModuleName ![HeapPtr] !*CHeaps !*CProject -> (!Error, !*CHeaps, !*CProject)
				act mod_name [ptr:ptrs] heaps prj
					# (error, def, prj)			= getFunDef ptr prj
					| isError error				= (error, heaps, prj)
					# (error, def, prj)			= setCreatorsAndSelectorsAndUpdaters def prj
					| isError error				= (error, heaps, prj)
					# (error, def, heaps, prj)	= simplifyCases def heaps prj
					| isError error				= (error, heaps, prj)
					# (def, prj)				= simplifyLets def prj
					# (def, heaps, prj)			= findStrictVars def heaps prj
					# (def, prj)				= findCaseVars def prj
					# (def, heaps, prj)			= setDeltaRules ptr mod_name def heaps prj
					# def						= removeDummyForStrictAlias def
					# (error, prj)				= putFunDef ptr def prj
					| isError error				= (error, heaps, prj)
					= act mod_name ptrs heaps prj
				act mod_name [] heaps prj
					= (OK, heaps, prj)
		actOnFunctions [] heaps prj
			= (OK, heaps, prj)
		
		actOnInstances :: ![CModule] !*CProject -> (!Error, !*CProject)
		actOnInstances [mod:mods] prj
			# (error, prj)				= act mod.pmInstancePtrs prj
			| isError error				= (error, prj)
			= actOnInstances mods prj
			where
				act :: ![HeapPtr] !*CProject -> (!Error, !*CProject)
				act [ptr:ptrs] prj
					# (error, def, prj)		= getInstanceDef ptr prj
					| isError error			= (error, prj)
					# (error, prj)			= markInstance ptr def prj
					| isError error			= (error, prj)
					= act ptrs prj
				act [] prj
					= (OK, prj)
		actOnInstances [] prj
			= (OK, prj)
		
		actOnMembers :: ![CModule] !*CProject -> (!Error, !*CProject)
		actOnMembers [mod:mods] prj
			| mod.pmName == "StdArray"		= find mod.pmMemberPtrs prj
			= actOnMembers mods prj
			where
				find :: ![HeapPtr] !*CProject -> (!Error, !*CProject)
				find [ptr:ptrs] prj
					# (error, def, prj)		= getMemberDef ptr prj
					| isError error			= (error, prj)
					= case def.mbdName of
						"select"	-> (OK, {prj & prjArraySelectMember = Just ptr})
						_			-> find ptrs prj
				// BEZIG -- is this OK? -- probably not -- HANDLE ARRAYS BETTER!
				find [] prj
					= (OK, prj)
		actOnMembers [] prj
			= (OK, prj)