/*
** Program: Clean Prover System
** Module:  LTypes (.icl)
** 
** Author:  Maarten de Mol
** Created: 19 July 2007
*/

implementation module 
	LTypes

import
	commondef,
	StdEnv

import
	CoreAccess,
	CoreTypes,
	Heaps

// -------------------------------------------------------------------------------------------------------------------------------------------------   
instance DummyValue LAlgPattern
// -------------------------------------------------------------------------------------------------------------------------------------------------   
	where DummyValue =	{ lapDataCons		= DummyValue
						, lapExprVarScope	= DummyValue
						, lapResult			= DummyValue
						}

// -------------------------------------------------------------------------------------------------------------------------------------------------   
instance DummyValue LBasicPattern
// -------------------------------------------------------------------------------------------------------------------------------------------------   
	where DummyValue =	{ lbpBasicValue		= DummyValue
						, lbpResult			= DummyValue
						}

// -------------------------------------------------------------------------------------------------------------------------------------------------   
instance DummyValue LBasicValue
// -------------------------------------------------------------------------------------------------------------------------------------------------   
	where DummyValue = LBasicInteger (-1)

// -------------------------------------------------------------------------------------------------------------------------------------------------   
instance DummyValue LCasePatterns
// -------------------------------------------------------------------------------------------------------------------------------------------------   
	where DummyValue = LAlgPatterns DummyValue []

// -------------------------------------------------------------------------------------------------------------------------------------------------   
instance DummyValue LConsInfo
// -------------------------------------------------------------------------------------------------------------------------------------------------   
	where DummyValue = {lciAnnotatedStrictVars = DummyValue}

// -------------------------------------------------------------------------------------------------------------------------------------------------   
instance DummyValue LExpr
// -------------------------------------------------------------------------------------------------------------------------------------------------   
	where DummyValue = LBottom

// -------------------------------------------------------------------------------------------------------------------------------------------------   
instance DummyValue LFunInfo
// -------------------------------------------------------------------------------------------------------------------------------------------------   
	where DummyValue =	{ lfiAnnotatedStrictVars		= DummyValue
						, lfiCaseVars					= DummyValue
						, lfiStrictVars					= DummyValue
						}

// -------------------------------------------------------------------------------------------------------------------------------------------------   
instance DummyValue LSymbolKind
// -------------------------------------------------------------------------------------------------------------------------------------------------   
	where DummyValue = LCons DummyValue













// -------------------------------------------------------------------------------------------------------------------------------------------------
instance == LAlgPattern
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	(==) p1								p2							= p1.lapDataCons == p2.lapDataCons &&
																	  p1.lapResult   == p2.lapResult

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance == LBasicValue
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	(==) (LBasicInteger i1)				(LBasicInteger i2)			= i1 == i2
	(==) (LBasicCharacter c1)			(LBasicCharacter c2)		= c1 == c2
	(==) (LBasicRealNumber r1)			(LBasicRealNumber r2)		= r1 == r2
	(==) (LBasicBoolean b1)				(LBasicBoolean b2)			= b1 == b2
	(==) (LBasicString s1)				(LBasicString s2)			= s1 == s2
	(==) (LBasicArray es1)				(LBasicArray es2)			= es1 == es2
	(==) _								_							= False

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance == LBasicPattern
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	(==) p1								p2							= p1.lbpBasicValue == p2.lbpBasicValue &&
																	  p1.lbpResult     == p2.lbpResult

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance == LCasePatterns
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	(==) (LAlgPatterns t1 p1)			(LAlgPatterns t2 p2)		= t1 == t2 && p1 == p2
	(==) (LBasicPatterns t1 p1)			(LBasicPatterns t2 p2)		= t1 == t2 && p1 == p2
	(==) _								_							= False

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance == LExpr
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	(==) (LExprVar ptr1 _)				(LExprVar ptr2 _)			= ptr1 == ptr2
	(==) (LBasicValue value1)			(LBasicValue value2)		= value1 == value2
	(==) (LSymbol _ ptr1 _ es1)			(LSymbol _ ptr2 _ es2)		= ptr1 == ptr2 && es1 == es2
	(==) (LApp e1 e2)					(LApp e3 e4)				= e1 == e3 && e2 == e4
	(==) (LCase e1 p1 d1)				(LCase e2 p2 d2)			= e1 == e2 && p1 == p2 && d1 == d2
	(==) (LLazyLet ds1 e1)				(LLazyLet ds2 e2)			= ds1 == ds2 && e1 == e2
	(==) (LStrictLet v1 d1 e1 e2)		(LStrictLet v2 d2 e3 e4)	= v1 == v2 && e1 == e3 && e2 == e4
	(==) LBottom						LBottom						= True
	(==) _								_							= False


















// -------------------------------------------------------------------------------------------------------------------------------------------------
:: ConvTable :== [(CExprVarPtr, LLetDefPtr)]
// -------------------------------------------------------------------------------------------------------------------------------------------------

// -------------------------------------------------------------------------------------------------------------------------------------------------
convertC2L :: !c !*CHeaps !*CProject -> (!l, !*CHeaps, !*CProject) | convertCL c l
// -------------------------------------------------------------------------------------------------------------------------------------------------
convertC2L c heaps prj
	= toL c [] heaps prj

// -------------------------------------------------------------------------------------------------------------------------------------------------
convertL2C :: !l !*CHeaps !*CProject -> (!c, !*CHeaps, !*CProject) | convertCL c l
// -------------------------------------------------------------------------------------------------------------------------------------------------
convertL2C l heaps prj
	= toC l [] heaps prj

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance convertCL [c] [l] | convertCL c l
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	toC [l:ls] table heaps prj
		# (c, heaps, prj)							= toC l table heaps prj
		# (cs, heaps, prj)							= toC ls table heaps prj
		= ([c:cs], heaps, prj)
	toC [] table heaps prj
		= ([], heaps, prj)
	
	toL [c:cs] table heaps prj
		# (l, heaps, prj)							= toL c table heaps prj
		# (ls, heaps, prj)							= toL cs table heaps prj
		= ([l:ls], heaps, prj)
	toL [] table heaps prj
		= ([], heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance convertCL (Maybe c) (Maybe l) | convertCL c l
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	toC (Just l) table heaps prj
		# (c, heaps, prj)							= toC l table heaps prj
		= (Just c, heaps, prj)
	toC Nothing table heaps prj
		= (Nothing, heaps, prj)
	
	toL (Just c) table heaps prj
		# (l, heaps, prj)							= toL c table heaps prj
		= (Just l, heaps, prj)
	toL Nothing table heaps prj
		= (Nothing, heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance convertCL CAlgPatternH LAlgPattern
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	toC pattern table heaps prj
		# (result, heaps, prj)						= toC pattern.lapResult table heaps prj
		= (	{ atpDataCons							= pattern.lapDataCons
			, atpExprVarScope						= pattern.lapExprVarScope
			, atpResult								= result
			}, heaps, prj)
	
	toL pattern table heaps prj
		# (result, heaps, prj)						= toL pattern.atpResult table heaps prj
		= (	{ lapDataCons							= pattern.atpDataCons
			, lapExprVarScope						= pattern.atpExprVarScope
			, lapResult								= result
			}, heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance convertCL CBasicPatternH LBasicPattern
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	toC pattern table heaps prj
		# (value, heaps, prj)						= toC pattern.lbpBasicValue table heaps prj
		# (result, heaps, prj)						= toC pattern.lbpResult table heaps prj
		= ({bapBasicValue = value, bapResult = result}, heaps, prj)
	
	toL pattern table heaps prj
		# (value, heaps, prj)						= toL pattern.bapBasicValue table heaps prj
		# (result, heaps, prj)						= toL pattern.bapResult table heaps prj
		= ({lbpBasicValue = value, lbpResult = result}, heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance convertCL CBasicValueH LBasicValue
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	toC (LBasicInteger i) table heaps prj			= (CBasicInteger i, heaps, prj)
	toC (LBasicCharacter c) table heaps prj			= (CBasicCharacter c, heaps, prj)
	toC (LBasicRealNumber r) table heaps prj		= (CBasicRealNumber r, heaps, prj)
	toC (LBasicBoolean l) table heaps prj			= (CBasicBoolean l, heaps, prj)
	toC (LBasicString s) table heaps prj			= (CBasicString s, heaps, prj)
	toC (LBasicArray es) table heaps prj
		# (es, heaps, prj)							= toC es table heaps prj
		= (CBasicArray es, heaps, prj)

	toL (CBasicInteger i) table heaps prj			= (LBasicInteger i, heaps, prj)
	toL (CBasicCharacter c) table heaps prj			= (LBasicCharacter c, heaps, prj)
	toL (CBasicRealNumber r) table heaps prj		= (LBasicRealNumber r, heaps, prj)
	toL (CBasicBoolean l) table heaps prj			= (LBasicBoolean l, heaps, prj)
	toL (CBasicString s) table heaps prj			= (LBasicString s, heaps, prj)
	toL (CBasicArray es) table heaps prj
		# (es, heaps, prj)							= toL es table heaps prj
		= (LBasicArray es, heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance convertCL CCasePatternsH LCasePatterns
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	toC (LAlgPatterns ptr patterns) table heaps prj
		# (patterns, heaps, prj)					= toC patterns table heaps prj
		= (CAlgPatterns ptr patterns, heaps, prj)
	toC (LBasicPatterns type patterns) table heaps prj
		# (patterns, heaps, prj)					= toC patterns table heaps prj
		= (CBasicPatterns type patterns, heaps, prj)
	
	toL (CAlgPatterns ptr patterns) table heaps prj
		# (patterns, heaps, prj)					= toL patterns table heaps prj
		= (LAlgPatterns ptr patterns, heaps, prj)
	toL (CBasicPatterns type patterns) table heaps prj
		# (patterns, heaps, prj)					= toL patterns table heaps prj
		= (LBasicPatterns type patterns, heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance convertCL CExprH LExpr
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	toC (LExprVar ptr _) table heaps prj
		= (CExprVar ptr, heaps, prj)
	toC (LBasicValue value) table heaps prj
		# (value, heaps, prj)						= toC value table heaps prj
		= (CBasicValue value, heaps, prj)
	toC (LSymbol (LFieldSelector i) ptr LTotal [e]) table heaps prj
		# (e, heaps, prj)							= toC e table heaps prj
		= (select_field i ptr e, heaps, prj)
		where
			select_field :: !Int !HeapPtr !CExprH -> CExprH
			select_field i ptr CBottom				= CBottom
			select_field i ptr (_ @@# es)			= es !! i
			select_field i ptr e					= ptr @@# [e]
	toC (LSymbol _ ptr _ es) table heaps prj
		# (es, heaps, prj)							= toC es table heaps prj
		= (ptr @@# es, heaps, prj)
	toC (LApp e1 e2) table heaps prj
		# (e1, heaps, prj)							= toC e1 table heaps prj
		# (e2, heaps, prj)							= toC e2 table heaps prj
		= combine e1 e2 heaps prj
		where
			combine :: !CExprH !CExprH !*CHeaps !*CProject -> (!CExprH, !*CHeaps, !*CProject)
			combine e1=:(ptr @@# es) e2 heaps prj
				# (_, arity, heaps, prj)			= getDefinitionArity ptr heaps prj
				| arity <= length es				= (e1 @# [e2], heaps, prj)
				= (ptr @@# (es ++ [e2]), heaps, prj)
			combine (e1 @# es) e2 heaps prj
				= (e1 @# (es ++ [e2]), heaps, prj)
			combine e1 e2 heaps prj
				= (e1 @# [e2], heaps, prj)
	toC (LCase patterns e def) table heaps prj
		# (patterns, heaps, prj)					= toC patterns table heaps prj
		# (e, heaps, prj)							= toC e table heaps prj
		# (def, heaps, prj)							= toC def table heaps prj
		= (CCase patterns e def, heaps, prj)
	toC (LLazyLet defs e) table heaps prj
		# (vars, es, heaps)							= unzip defs heaps
		# (es, heaps, prj)							= toC es table heaps prj
		# (e, heaps, prj)							= toC e table heaps prj
		= (CLet False (zip2 vars es) e, heaps, prj)
		where
			unzip :: ![LLetDefPtr] !*CHeaps -> (![CExprVarPtr], ![LExpr], !*CHeaps)
			unzip [ptr:ptrs] heaps
				# (def, heaps)						= readPointer ptr heaps
				# (var, e)							= extract def
				# (vars, es, heaps)					= unzip ptrs heaps
				= ([var:vars], [e:es], heaps)
			unzip [] heaps
				= ([], [], heaps)
			
			extract :: !LLetDef -> (!CExprVarPtr, !LExpr)
			extract (LLetDef var _ e)
				= (var, e)
	toC (LStrictLet var d e1 e2) table heaps prj
		# (e1, heaps, prj)							= toC e1 table heaps prj
		# (e2, heaps, prj)							= toC e2 table heaps prj
		= (CLet True [(var,e1)] e2, heaps, prj)
	toC LBottom table heaps prj
		= (CBottom, heaps, prj)

	toL (CExprVar ptr) table heaps prj
		= (LExprVar ptr (find ptr table), heaps, prj)
		where
			find :: !CExprVarPtr ![(CExprVarPtr, LLetDefPtr)] -> Maybe LLetDefPtr
			find ptr1 [(ptr2,def): table]
				| ptr1 == ptr2						= Just def
													= find ptr1 table
			find ptr []
				= Nothing
	toL (CBasicValue value) table heaps prj
		# (value, heaps, prj)						= toL value table heaps prj
		= (LBasicValue value, heaps, prj)
	toL (ptr @@# es) table heaps prj
		# (es, heaps, prj)							= toL es table heaps prj
		# (kind, arity, prj)						= app_type ptr prj
//		# strictness								= makeStrictness symboltype.sytArguments
		| arity >= length es						= (LSymbol kind ptr (arity-length es) es, heaps, prj)
		# (es1, es2)								= splitAt arity es
		= (makeApp (LSymbol kind ptr LTotal es1) es2, heaps, prj)
		where
			app_type :: !HeapPtr !*CProject -> (!LSymbolKind, !CArity, !*CProject)
			app_type ptr prj
				# ptr_kind							= ptrKind ptr
				| ptr_kind == CDataCons
					# (_, consdef, prj)				= getDataConsDef ptr prj
					# info							=	{ lciAnnotatedStrictVars	= convStrictness consdef.dcdSymbolType.sytArguments}
					= (LCons info, consdef.dcdArity, prj)
				| ptr_kind == CFun
					# (_, fundef, prj)				= getFunDef ptr prj
					# info							=	{ lfiAnnotatedStrictVars	= convStrictness fundef.fdSymbolType.sytArguments
														, lfiCaseVars				= convIndexedArray fundef.fdCaseVariables
														, lfiStrictVars				= convIndexedArray fundef.fdStrictVariables
														}
					| not fundef.fdIsRecordSelector	= (LFun info, fundef.fdArity, prj)
					# (_, field, prj)				= getRecordFieldDef fundef.fdRecordFieldDef prj
					= (LFieldSelector field.rfIndex, fundef.fdArity, prj)
	toL (e @# es) table heaps prj
		# (e, heaps, prj)							= toL e table heaps prj
		# (es, heaps, prj)							= toL es table heaps prj
		= (combine e es, heaps, prj)
		where
			combine :: !LExpr ![LExpr] -> LExpr
			combine e []							= e
			combine e=:(LSymbol _ _ LTotal _) es	= makeApp e es
			combine (LSymbol t ptr c as) [e:es]		= combine (LSymbol t ptr (c-1) (as ++ [e])) es
			combine e es							= makeApp e es
	toL (CCase patterns e def) table heaps prj
		# (patterns, heaps, prj)					= toL patterns table heaps prj
		# (e, heaps, prj)							= toL e table heaps prj
		# (def, heaps, prj)							= toL def table heaps prj
		= (LCase patterns e def, heaps, prj)
	toL (CLet False defs e) table heaps prj
		# (lptrs, es, table, heaps)					= create_ldefs defs table heaps
		# (es, heaps, prj)							= toL es table heaps prj
		# heaps										= set_es lptrs es heaps
		# (e, heaps, prj)							= toL e table heaps prj
		= (LLazyLet lptrs e, heaps, prj)
		where
			create_ldefs :: ![(CExprVarPtr, CExprH)] !ConvTable !*CHeaps -> (![LLetDefPtr], [CExprH], !ConvTable, !*CHeaps)
			create_ldefs [(var,e):defs] table heaps
				# (ptr, heaps)						= newPointer (LLetDef var False DummyValue) heaps
				# table								= [(var,ptr):table]
				# (ptrs, es, table, heaps)			= create_ldefs defs table heaps
				= ([ptr:ptrs], [e:es], table, heaps)
			create_ldefs [] table heaps
				= ([], [], table, heaps)
			
			set_es :: ![LLetDefPtr] ![LExpr] !*CHeaps -> *CHeaps
			set_es [ptr:ptrs] [e:es] heaps
				# (LLetDef var _ _, heaps)			= readPointer ptr heaps
				# heaps								= writePointer ptr (LLetDef var False e) heaps
				= set_es ptrs es heaps
			set_es [] [] heaps
				= heaps
	toL (CLet True [(var,e1)] e2) table heaps prj
		# (ptr, heaps)								= newPointer LStrictLetDef heaps
		# table										= [(var,ptr):table]
		# (e1, heaps, prj)							= toL e1 table heaps prj
		# (e2, heaps, prj)							= toL e2 table heaps prj
		= (LStrictLet var ptr e1 e2, heaps, prj)
	toL (CLet True _ _) table heaps prj
		= abort "Conversion C->L encountered a strict let with more than one variable definition."
	toL CBottom table heaps prj
		= (LBottom, heaps, prj)






















// -------------------------------------------------------------------------------------------------------------------------------------------------
instance lSubst [l] | lSubst l
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	lSubst table [x:xs] heaps
		# (x, heaps)								= lSubst table x heaps
		# (xs, heaps)								= lSubst table xs heaps
		= ([x:xs], heaps)
	lSubst table [] heaps
		= ([], heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance lSubst (Maybe l) | lSubst l
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	lSubst table (Just x) heaps
		# (x, heaps)								= lSubst table x heaps
		= (Just x, heaps)
	lSubst table Nothing heaps
		= (Nothing, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance lSubst LAlgPattern
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	lSubst table p heaps
		# (result, heaps)							= lSubst table p.lapResult heaps
		= ({p & lapResult = result}, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance lSubst LBasicPattern
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	lSubst table p heaps
		# (result, heaps)							= lSubst table p.lbpResult heaps
		= ({p & lbpResult = result}, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance lSubst LBasicValue
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	lSubst table (LBasicArray es) heaps
		# (es, heaps)								= lSubst table es heaps
		= (LBasicArray es, heaps)
	lSubst table e heaps
		= (e, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance lSubst LCasePatterns
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	lSubst table (LAlgPatterns type ps) heaps
		# (ps, heaps)								= lSubst table ps heaps
		= (LAlgPatterns type ps, heaps)
	lSubst table (LBasicPatterns type ps) heaps
		# (ps, heaps)								= lSubst table ps heaps
		= (LBasicPatterns type ps, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance lSubst LExpr
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	lSubst table e=:(LExprVar ptr _) heaps
		= (find ptr table e, heaps)
		where
			find :: !CExprVarPtr ![(CExprVarPtr, LExpr)] !LExpr -> LExpr
			find ptr1 [(ptr2,e):table] old_e
				| ptr1 == ptr2						= e
				| otherwise							= find ptr1 table old_e
			find _ _ old_e
				= old_e
	lSubst table (LBasicValue v) heaps
		# (v, heaps)								= lSubst table v heaps
		= (LBasicValue v, heaps)
	lSubst table (LSymbol type ptr c es) heaps
		# (es, heaps)								= lSubst table es heaps
		= (LSymbol type ptr c es, heaps)
	lSubst table (LApp e1 e2) heaps
		# (e1, heaps)								= lSubst table e1 heaps
		# (e2, heaps)								= lSubst table e2 heaps
		= (LApp e1 e2, heaps)
	lSubst table (LCase e patterns mb_def) heaps
		# (e, heaps)								= lSubst table e heaps
		# (patterns, heaps)							= lSubst table patterns heaps
		# (mb_def, heaps)							= lSubst table mb_def heaps
		= (LCase e patterns mb_def, heaps)
	lSubst table (LLazyLet defs e) heaps
		# (defs, heaps)								= lSubst table defs heaps
		# (e, heaps)								= lSubst table e heaps
		= (LLazyLet defs e, heaps)
	lSubst table (LStrictLet var ptr e1 e2) heaps
		# (e1, heaps)								= lSubst table e1 heaps
		# (e2, heaps)								= lSubst table e2 heaps
		= (LStrictLet var ptr e1 e2, heaps)
	lSubst table e heaps
		= (e, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance lSubst LLetDef
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	lSubst table (LLetDef ptr mu e) heaps
		# (e, heaps)								= lSubst table e heaps
		= (LLetDef ptr mu e, heaps)
	lSubst table LStrictLetDef heaps
		= (LStrictLetDef, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance lSubst LLetDefPtr
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	lSubst table ptr heaps
		# (def, heaps)								= readPointer ptr heaps
		# heaps										= writePointer ptr LStrictLetDef heaps
		# (def, heaps)								= lSubst table def heaps
		# heaps										= writePointer ptr def heaps
		= (ptr, heaps)

// version of lSubst that is robust for dependent substitutions, i.e. [x:=y, z:=x]
// -------------------------------------------------------------------------------------------------------------------------------------------------
lDependentSubst :: ![CExprVarPtr] ![LExpr] !x !*CHeaps -> (!x, !*CHeaps) | lSubst x
// -------------------------------------------------------------------------------------------------------------------------------------------------
lDependentSubst [var:vars] [e:es] x heaps
	# (x, heaps)									= lSubst [(var,e)] x heaps
	# (es, heaps)									= lSubst [(var,e)] es heaps
	= lDependentSubst vars es x heaps
lDependentSubst [] [] x heaps
	= (x, heaps)
















// -------------------------------------------------------------------------------------------------------------------------------------------------
instance lFresh [l] | lFresh l
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	lFresh table [x:xs] heaps
		# (x, heaps)								= lFresh table x heaps
		# (xs, heaps)								= lFresh table xs heaps
		= ([x:xs], heaps)
	lFresh table [] heaps
		= ([], heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance lFresh (Maybe l) | lFresh l
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	lFresh table (Just x) heaps
		# (x, heaps)								= lFresh table x heaps
		= (Just x, heaps)
	lFresh table Nothing heaps
		= (Nothing, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance lFresh CExprVarPtr
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	lFresh table old_ptr heaps
		# (vardef, heaps)							= readPointer old_ptr heaps
		# (new_ptr, heaps)							= newPointer vardef heaps
		= (new_ptr, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance lFresh LAlgPattern
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	lFresh table pattern heaps
		# (new_scope, heaps)						= lFresh table pattern.lapExprVarScope heaps
		# table										= (zip2 pattern.lapExprVarScope new_scope) ++ table
		# (new_result, heaps)						= lFresh table pattern.lapResult heaps
		= ({pattern & lapExprVarScope = new_scope, lapResult = new_result}, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance lFresh LBasicPattern
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	lFresh table pattern heaps
		# (new_result, heaps)						= lFresh table pattern.lbpResult heaps
		= ({pattern & lbpResult = new_result}, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance lFresh LBasicValue
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	lFresh table (LBasicArray es) heaps
		# (es, heaps)								= lFresh table es heaps
		= (LBasicArray es, heaps)
	lFresh table v heaps
		= (v, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance lFresh LCasePatterns
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	lFresh table (LAlgPatterns type patterns) heaps
		# (patterns, heaps)							= lFresh table patterns heaps
		= (LAlgPatterns type patterns, heaps)
	lFresh table (LBasicPatterns type patterns) heaps
		# (patterns, heaps)							= lFresh table patterns heaps
		= (LBasicPatterns type patterns, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance lFresh LExpr
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	lFresh table (LExprVar ptr mb_def) heaps
		= (LExprVar (find ptr table) mb_def, heaps)
		where
			find :: !CExprVarPtr ![(CExprVarPtr, CExprVarPtr)] -> CExprVarPtr
			find ptr1 [(ptr2,ptr3):table]
				| ptr1 == ptr2						= ptr3
				| otherwise							= find ptr1 table
			find ptr1 []							= ptr1
	lFresh table (LBasicValue v) heaps
		# (v, heaps)								= lFresh table v heaps
		= (LBasicValue v, heaps)
	lFresh table (LSymbol type ptr c es) heaps
		# (es, heaps)								= lFresh table es heaps
		= (LSymbol type ptr c es, heaps)
	lFresh table (LApp e1 e2) heaps
		# (e1, heaps)								= lFresh table e1 heaps
		# (e2, heaps)								= lFresh table e2 heaps
		= (LApp e1 e2, heaps)
	lFresh table (LCase e patterns mb_def) heaps
		# (e, heaps)								= lFresh table e heaps
		# (patterns, heaps)							= lFresh table patterns heaps
		# (mb_def, heaps)							= lFresh table mb_def heaps
		= (LCase e patterns mb_def, heaps)
	lFresh table (LLazyLet defs e) heaps
		# (extend_table, heaps)						= fresh_vars defs heaps
		# table										= extend_table ++ table
		# (defs, heaps)								= lFresh table defs heaps
		# (e, heaps)								= lFresh table e heaps
		= (LLazyLet defs e, heaps)
		where
			fresh_vars :: ![LLetDefPtr] !*CHeaps -> (![(CExprVarPtr, CExprVarPtr)], !*CHeaps)
			fresh_vars [ptr:ptrs] heaps
				# (def, heaps)						= readPointer ptr heaps
				# (old_var, new_var, def, heaps)	= fresh_var def heaps
				# heaps								= writePointer ptr def heaps
				# (extend_table, heaps)				= fresh_vars ptrs heaps
				= ([(old_var,new_var):extend_table], heaps)
			fresh_vars [] heaps
				= ([], heaps)
			
			fresh_var :: !LLetDef !*CHeaps -> (!CExprVarPtr, !CExprVarPtr, !LLetDef, !*CHeaps)
			fresh_var (LLetDef old_var mu e) heaps
				# (new_var, heaps)					= lFresh [] old_var heaps
				= (old_var, new_var, LLetDef new_var mu e, heaps)
	lFresh table (LStrictLet old_var ptr e1 e2) heaps
		# (new_var, heaps)							= lFresh table old_var heaps
		# table										= [(old_var,new_var):table]
		# (e1, heaps)								= lFresh table e1 heaps
		# (e2, heaps)								= lFresh table e2 heaps
		= (LStrictLet new_var ptr e1 e2, heaps)
	lFresh table e heaps
		= (e, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance lFresh LLetDef
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	lFresh table (LLetDef var mu e) heaps
		# (e, heaps)								= lFresh table e heaps
		= (LLetDef var mu e, heaps)
	lFresh table LStrictLetDef heaps
		= (LStrictLetDef, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance lFresh LLetDefPtr
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	lFresh table ptr heaps
		# (def, heaps)								= readPointer ptr heaps
		# (def, heaps)								= lFresh table def heaps
		# heaps										= writePointer ptr def heaps
		= (ptr, heaps)


















// -------------------------------------------------------------------------------------------------------------------------------------------------
instance lShow [l] | lShow l
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	lShow xs heaps prj
		# (xs, heaps, prj)							= show xs heaps prj
		= ("[" +++ xs +++ "]", heaps, prj)
		where
			show [x:xs] heaps prj
				# (x, heaps, prj)					= lShow x heaps prj
				| isEmpty xs						= (x, heaps, prj)
				# (xs, heaps, prj)					= show xs heaps prj
				= (x +++ ", " +++ xs, heaps, prj)
			show [] heaps prj
				= ("", heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance lShow (Maybe l) | lShow l
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	lShow (Just x) heaps prj
		# (x, heaps, prj)							= lShow x heaps prj
		= ("Just " +++ x +++ "", heaps, prj)
	lShow Nothing heaps prj
		= ("Nothing", heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance lShow LBasicValue
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	lShow (LBasicInteger i) heaps prj				= ("INT:" +++ toString i, heaps, prj)
	lShow (LBasicCharacter c) heaps prj				= ("CHAR:" +++ toString c, heaps, prj)
	lShow (LBasicRealNumber r) heaps prj			= ("REAL:" +++ toString r, heaps, prj)
	lShow (LBasicBoolean b) heaps prj				= ("BOOL:" +++ toString b, heaps, prj)
	lShow (LBasicString s) heaps prj				= ("STRING:" +++ s, heaps, prj)
	lShow (LBasicArray es) heaps prj
		# (es, heaps, prj)							= lShow es heaps prj
		= ("ARRAY:" +++ es, heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance lShow LExpr
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	lShow (LExprVar ptr _) heaps prj
		# (var, heaps)								= readPointer ptr heaps
		= ("VAR:" +++ var.evarName, heaps, prj)
	lShow (LBasicValue v) heaps prj
		= lShow v heaps prj
	lShow (LSymbol _ ptr c es) heaps prj
		# (_, name, heaps, prj)						= getDefinitionName ptr heaps prj
		# (es, heaps, prj)							= lShow es heaps prj
		= (name +++ "(-" +++ toString c +++ "):" +++ es, heaps, prj)
	lShow (LApp e1 e2) heaps prj
		# (e1, heaps, prj)							= lShow e1 heaps prj
		# (e2, heaps, prj)							= lShow e2 heaps prj
		= ("@(" +++ e1 +++ ", " +++ e2 +++ ")", heaps, prj)
	lShow (LCase e patterns mb_def) heaps prj
		= ("CASE", heaps, prj)
	lShow (LLazyLet defs e) heaps prj
		# (defs, heaps, prj)						= lShow defs heaps prj
		# (e, heaps, prj)							= lShow e heaps prj
		= ("LAZYLET " +++ defs +++ " IN " +++ e, heaps, prj)
	lShow (LStrictLet var ptr e1 e2) heaps prj
		= ("STRICTLET", heaps, prj)
	lShow LBottom heaps prj
		= ("_|_", heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance lShow LLetDefPtr
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	lShow ptr heaps prj
		# (letdef, heaps)							= readPointer ptr heaps
		= lShow letdef heaps prj

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance lShow LLetDef
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	lShow (LLetDef var mu e) heaps prj
		# (var_name, heaps)							= getPointerName var heaps
		# (e, heaps, prj)							= lShow e heaps prj
		# sign										= if mu ":=" "="
		= (var_name +++ sign +++ e, heaps, prj)
	lShow LStrictLetDef heaps prj
		= ("*", heaps, prj)




















// -------------------------------------------------------------------------------------------------------------------------------------------------
class lCount l
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	lCount :: ![CExprVarPtr] !l !*(![Int], !*CHeaps) -> (![Int], !*CHeaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance lCount [a] | lCount a
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	lCount vars [x:xs] env
		= lCount vars x (lCount vars xs env)
	lCount vars [] env
		= env

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance lCount (Maybe a) | lCount a
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	lCount vars (Just x) env
		= lCount vars x env
	lCount vars Nothing env
		= env

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance lCount LAlgPattern
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	lCount vars pattern env
		= lCount vars pattern.lapResult env

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance lCount LBasicPattern
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	lCount vars pattern env
		= lCount vars pattern.lbpResult env

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance lCount LBasicValue
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	lCount vars (LBasicArray es) env
		= lCount vars es env
	lCount vars v env
		= env

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance lCount LCasePatterns
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	lCount vars (LAlgPatterns _ patterns) env
		= lCount vars patterns env
	lCount vars (LBasicPatterns _ patterns) env
		= lCount vars patterns env

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance lCount LExpr
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	lCount vars (LExprVar ptr _) (counts, heaps)
		= (update ptr vars counts, heaps)
		where
			update :: !CExprVarPtr ![CExprVarPtr] ![Int] -> [Int]
			update ptr [var:vars] [count:counts]
				= case ptr == var of
					True							-> [inc count: counts]
					False							-> [count: update ptr vars counts]
			update _ [] counts
				= counts
	lCount vars (LBasicValue v) env
		= lCount vars v env
	lCount vars (LSymbol _ _ _ es) env
		= lCount vars es env
	lCount vars (LApp e1 e2) env
		= lCount vars e1 (lCount vars e2 env)
	lCount vars (LCase e patterns mb_def) env
		= lCount vars e (lCount vars patterns (lCount vars mb_def env))
	lCount vars (LLazyLet ptrs e) (counts, heaps)
		# (letdefs, heaps)							= readPointers ptrs heaps
		# heaps										= writePointers ptrs (repeat LStrictLetDef) heaps
		# (counts, heaps)							= lCount vars letdefs (counts, heaps)
		# (counts, heaps)							= lCount vars e (counts, heaps)
		# heaps										= writePointers ptrs letdefs heaps
		= (counts, heaps)
	lCount vars (LStrictLet _ _ e1 e2) env
		= lCount vars e1 (lCount vars e2 env)
	lCount vars LBottom env
		= env

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance lCount LLetDef
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	lCount vars (LLetDef _ _ e) env
		= lCount vars e env
	lCount vars LStrictLetDef env
		= env















// ------------------------------------------------------------------------------------------------------------------------
class lUnshareVars l
// ------------------------------------------------------------------------------------------------------------------------
where
	lUnshareVars :: !VarLocation !CExprVarPtr !LExpr !l !*CHeaps -> (!Int, !VarLocation, !l, !*CHeaps)

// ------------------------------------------------------------------------------------------------------------------------
instance lUnshareVars [l] | lUnshareVars l
// ------------------------------------------------------------------------------------------------------------------------
where
	lUnshareVars varl ptr var_e [x:xs] heaps
		# (c1, varl, x, heaps)						= lUnshareVars varl ptr var_e x heaps
		# (c2, varl, xs, heaps)						= lUnshareVars varl ptr var_e xs heaps
		= (c1+c2, varl, [x:xs], heaps)
	lUnshareVars varl ptr var_e [] heaps
		= (0, varl, [], heaps)

// ------------------------------------------------------------------------------------------------------------------------
instance lUnshareVars (Maybe l) | lUnshareVars l
// ------------------------------------------------------------------------------------------------------------------------
where
	lUnshareVars varl ptr var_e (Just x) heaps
		# (c, varl, x, heaps)						= lUnshareVars varl ptr var_e x heaps
		= (c, varl, Just x, heaps)
	lUnshareVars varl ptr var_e Nothing heaps
		= (0, varl, Nothing, heaps)

// ------------------------------------------------------------------------------------------------------------------------
instance lUnshareVars LAlgPattern
// ------------------------------------------------------------------------------------------------------------------------
where
	lUnshareVars varl ptr var_e pattern heaps
		# (c, varl, result, heaps)					= lUnshareVars varl ptr var_e pattern.lapResult heaps
		= (c, varl, {pattern & lapResult = result}, heaps)

// ------------------------------------------------------------------------------------------------------------------------
instance lUnshareVars LBasicPattern
// ------------------------------------------------------------------------------------------------------------------------
where
	lUnshareVars varl ptr var_e pattern heaps
		# (c, varl, result, heaps)					= lUnshareVars varl ptr var_e pattern.lbpResult heaps
		= (c, varl, {pattern & lbpResult = result}, heaps)

// ------------------------------------------------------------------------------------------------------------------------
instance lUnshareVars LBasicValue
// ------------------------------------------------------------------------------------------------------------------------
where
	lUnshareVars varl ptr var_e (LBasicArray es) heaps
		# (c, varl, es, heaps)						= lUnshareVars varl ptr var_e es heaps
		= (c, varl, LBasicArray es, heaps)
	lUnshareVars varl ptr var_e v heaps
		= (0, varl, v, heaps)

// ------------------------------------------------------------------------------------------------------------------------
instance lUnshareVars LCasePatterns
// ------------------------------------------------------------------------------------------------------------------------
where
	lUnshareVars varl ptr var_e (LAlgPatterns type patterns) heaps
		# (c, varl, patterns, heaps)				= lUnshareVars varl ptr var_e patterns heaps
		= (c, varl, LAlgPatterns type patterns, heaps)
	lUnshareVars varl ptr var_e (LBasicPatterns type patterns) heaps
		# (c, varl, patterns, heaps)				= lUnshareVars varl ptr var_e patterns heaps
		= (c, varl, LBasicPatterns type patterns, heaps)

// ------------------------------------------------------------------------------------------------------------------------
instance lUnshareVars LExpr
// ------------------------------------------------------------------------------------------------------------------------
where
	lUnshareVars varl ptr1 var_e expr=:(LExprVar ptr2 _) heaps
		| ptr1 <> ptr2								= (0, varl, expr, heaps)
		# (replace_here, varl)						= decrease_loc varl
		= case replace_here of
			True									-> (1, varl, var_e, heaps)
			False									-> (1, varl, expr, heaps)
		where
			decrease_loc :: !VarLocation -> (!Bool, !VarLocation)
			decrease_loc AllVars					= (True, AllVars)
			decrease_loc (JustVarIndex 0)			= (False, JustVarIndex 0)
			decrease_loc (JustVarIndex 1)			= (True, JustVarIndex 0)
			decrease_loc (JustVarIndex n)			= (False, JustVarIndex (n-1))
	lUnshareVars varl ptr var_e (LBasicValue v) heaps
		# (c, varl, v, heaps)						= lUnshareVars varl ptr var_e v heaps
		= (c, varl, LBasicValue v, heaps)
	lUnshareVars varl ptr var_e (LSymbol kind sptr n es) heaps
		# (c, varl, es, heaps)						= lUnshareVars varl ptr var_e es heaps
		= (c, varl, LSymbol kind sptr n es, heaps)
	lUnshareVars varl ptr var_e (LApp e1 e2) heaps
		# (c1, varl, e1, heaps)						= lUnshareVars varl ptr var_e e1 heaps
		# (c2, varl, e2, heaps)						= lUnshareVars varl ptr var_e e2 heaps
		= (c1+c2, varl, LApp e1 e2, heaps)
	lUnshareVars varl ptr var_e (LCase e patterns mb_def) heaps
		# (c1, varl, e, heaps)						= lUnshareVars varl ptr var_e e heaps
		# (c2, varl, patterns, heaps)				= lUnshareVars varl ptr var_e patterns heaps
		# (c3, varl, mb_def, heaps)					= lUnshareVars varl ptr var_e mb_def heaps
		= (c1+c2+c3, varl, LCase e patterns mb_def, heaps)
	lUnshareVars varl ptr var_e (LLazyLet ptrs e) heaps
		# (letdefs, heaps)							= readPointers ptrs heaps
		# heaps										= writePointers ptrs (repeat LStrictLetDef) heaps
		# (c1, varl, letdefs, heaps)				= lUnshareVars varl ptr var_e letdefs heaps
		# heaps										= writePointers ptrs letdefs heaps
		# (c2, varl, e, heaps)						= lUnshareVars varl ptr var_e e heaps
		= (c1+c2, varl, LLazyLet ptrs e, heaps)
	lUnshareVars varl ptr var_e (LStrictLet var lptr e1 e2) heaps
		# (c1, varl, e1, heaps)						= lUnshareVars varl ptr var_e e1 heaps
		# (c2, varl, e2, heaps)						= lUnshareVars varl ptr var_e e2 heaps
		= (c1+c2, varl, LStrictLet var lptr e1 e2, heaps)
	lUnshareVars varl ptr var_e LBottom heaps
		= (0, varl, LBottom, heaps)

// ------------------------------------------------------------------------------------------------------------------------
instance lUnshareVars LLetDef
// ------------------------------------------------------------------------------------------------------------------------
where
	lUnshareVars varl ptr var_e (LLetDef lptr lmu le) heaps
		# (c, varl, le, heaps)						= lUnshareVars varl ptr var_e le heaps
		= (c, varl, LLetDef lptr lmu le, heaps)
	lUnshareVars varl ptr var_e LStrictLetDef heaps
		= (0, varl, LStrictLetDef, heaps)












// -------------------------------------------------------------------------------------------------------------------------------------------------
makeApp :: !LExpr ![LExpr] -> LExpr
// -------------------------------------------------------------------------------------------------------------------------------------------------
makeApp f es
	= make_app f (reverse es)
	where
		make_app :: !LExpr ![LExpr] -> LExpr
		make_app f [e:es]
			= LApp (make_app f es) e
		make_app f []
			= f

// -------------------------------------------------------------------------------------------------------------------------------------------------
convIndexedArray :: ![Int] -> LListOfBool
// -------------------------------------------------------------------------------------------------------------------------------------------------
convIndexedArray [i:is]
	= (convIndexedArray is) bitor (1 << i)
convIndexedArray []
	= 0

// -------------------------------------------------------------------------------------------------------------------------------------------------
convStrictness :: ![CTypeH] -> LListOfBool
// -------------------------------------------------------------------------------------------------------------------------------------------------
convStrictness []
	= 0
convStrictness [CStrict _: types]
	= ((convStrictness types) << 1) + 1
convStrictness [_: types]
	= (convStrictness types) << 1