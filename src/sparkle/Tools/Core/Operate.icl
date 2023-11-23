/*
** Program: Clean Prover System
** Module:  Operate (.icl)
** 
** Author:  Maarten de Mol
** Created: 29 November 2000
*/

implementation module 
	Operate

import
	StdEnv,
	CoreTypes,
	CoreAccess,
	ProveTypes,
	Heaps

// -hack-to-prevent-overloading---------------------------------------------------------------------------------------------------------------------
isMember1 :: !CSharedPtr ![CSharedPtr] -> Bool
isMember1 x [y:ys]
	| x == y			= True
	= isMember1 x ys
isMember1 x []
	= False
// -------------------------------------------------------------------------------------------------------------------------------------------------










// -------------------------------------------------------------------------------------------------------------------------------------------------
:: Choice a b
// -------------------------------------------------------------------------------------------------------------------------------------------------
	= Either				a
	| Or					b

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: PtrInfo =
// -------------------------------------------------------------------------------------------------------------------------------------------------
	{ freeExprVars			:: ![CExprVarPtr]
	, freePropVars			:: ![CPropVarPtr]
	, freeTypeVars			:: ![CTypeVarPtr]
	, boundExprVars			:: ![CExprVarPtr]
	, boundPropVars			:: ![CPropVarPtr]
	, boundTypeVars			:: ![CTypeVarPtr]
	, sharedExprs			:: ![CSharedPtr]
	}
instance DummyValue PtrInfo
	where DummyValue =	{ freeExprVars		= []
						, freePropVars		= []
						, freeTypeVars		= []
						, boundExprVars		= []
						, boundPropVars		= []
						, boundTypeVars		= []
						, sharedExprs		= []
						}

// -------------------------------------------------------------------------------------------------------------------------------------------------   
:: RewriteState =
// -------------------------------------------------------------------------------------------------------------------------------------------------   
	{ rsChanged				:: !Bool
	, rsOne					:: !Int
	, rsAll					:: !Bool
	, rsExprVars			:: ![CExprVarPtr]
	, rsPropVars			:: ![CPropVarPtr]
	, rsSubs				:: ![Substitution]
	}

// -------------------------------------------------------------------------------------------------------------------------------------------------   
:: Substitution = 
// -------------------------------------------------------------------------------------------------------------------------------------------------   
	{ subExprVars			:: ![(CExprVarPtr, CExprH)]
	, subPropVars			:: ![(CPropVarPtr, CPropH)]
	, subTypeVars			:: ![(CTypeVarPtr, CTypeH)]
	}
instance DummyValue Substitution
	where DummyValue =	{ subExprVars = [] 
						, subPropVars = []
						, subTypeVars = []
						}































// -------------------------------------------------------------------------------------------------------------------------------------------------
:: Passed =
// -------------------------------------------------------------------------------------------------------------------------------------------------
	{ pExprVars					:: ![CExprVarPtr]
	, pPropVars					:: ![CPropVarPtr]
	}

// -------------------------------------------------------------------------------------------------------------------------------------------------
bindExprScope :: ![CExprVarPtr] ![CExprVarPtr] !*Passed !*CHeaps -> (!Bool, !*Passed, !*CHeaps)
// -------------------------------------------------------------------------------------------------------------------------------------------------
bindExprScope [ptr1:ptrs1] [ptr2:ptrs2] passed heaps
	# heaps								= writeReflexivePointer ptr1 ptr2 heaps
	# passed							= {passed & pExprVars = [ptr1:passed.pExprVars]}
	= bindExprScope ptrs1 ptrs2 passed heaps
bindExprScope [] [] passed heaps
	= (True, passed, heaps)
bindExprScope _ _ passed heaps
	= (False, passed, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
bindPropScope :: ![CPropVarPtr] ![CPropVarPtr] !*Passed !*CHeaps -> (!Bool, !*Passed, !*CHeaps)
// -------------------------------------------------------------------------------------------------------------------------------------------------
bindPropScope [ptr1:ptrs1] [ptr2:ptrs2] passed heaps
	# heaps								= writeReflexivePointer ptr1 ptr2 heaps
	# passed							= {passed & pPropVars = [ptr1:passed.pPropVars]}
	= bindPropScope ptrs1 ptrs2 passed heaps
bindPropScope [] [] passed heaps
	= (True, passed, heaps)
bindPropScope _ _ passed heaps
	= (False, passed, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
class alphaEqual a :: !a !a !*Passed !*CHeaps -> (!Bool, !*Passed, !*CHeaps)
// -------------------------------------------------------------------------------------------------------------------------------------------------

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance alphaEqual [a] | alphaEqual a
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	alphaEqual [x:xs] [y:ys] passed heaps
		# (equal, passed, heaps)		= alphaEqual x y passed heaps
		| not equal						= (False, passed, heaps)
		= alphaEqual xs ys passed heaps
	alphaEqual [] [] passed heaps
		= (True, passed, heaps)
	alphaEqual _ _ passed heaps
		= (False, passed, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance alphaEqual (Maybe a) | alphaEqual a
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	alphaEqual (Just x) (Just y) passed heaps
		= alphaEqual x y passed heaps
	alphaEqual Nothing Nothing passed heaps
		= (True, passed, heaps)
	alphaEqual _ _ passed heaps
		= (False, passed, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance alphaEqual (Ptr a) | ReflexivePointer a
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	alphaEqual ptr1 ptr2 passed heaps
		# (mb_target_ptr, heaps)		= readReflexivePointer ptr1 heaps
		| isNothing mb_target_ptr		= (ptr1 == ptr2, passed, heaps)
		# target_ptr					= fromJust mb_target_ptr
		= (target_ptr == ptr2, passed, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance alphaEqual (CAlgPattern HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	alphaEqual pattern1 pattern2 passed heaps
		# equal							= pattern1.atpDataCons == pattern2.atpDataCons
		| not equal						= (False, passed, heaps)
		# (ok, passed, heaps)			= bindExprScope pattern1.atpExprVarScope pattern2.atpExprVarScope passed heaps
		| not ok						= (False, passed, heaps)
		= alphaEqual pattern1.atpResult pattern2.atpResult passed heaps

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance alphaEqual (CBasicPattern HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	alphaEqual pattern1 pattern2 passed heaps
		# (equal, passed, heaps)		= alphaEqual pattern1.bapBasicValue pattern2.bapBasicValue passed heaps
		| not equal						= (False, passed, heaps)
		= alphaEqual pattern1.bapResult pattern2.bapResult passed heaps

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance alphaEqual (CBasicValue HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	alphaEqual (CBasicArray es1) (CBasicArray es2) passed heaps
		= alphaEqual es1 es2 passed heaps
	alphaEqual other1 other2 passed heaps
		= (other1 == other2, passed, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance alphaEqual (CCasePatterns HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	alphaEqual (CAlgPatterns ptr1 patterns1) (CAlgPatterns ptr2 patterns2) passed heaps
		| ptr1 <> ptr2					= (False, passed, heaps)
		= alphaEqual patterns1 patterns2 passed heaps
	alphaEqual (CBasicPatterns value1 patterns1) (CBasicPatterns value2 patterns2) passed heaps
		| value1 <> value2				= (False, passed, heaps)
		= alphaEqual patterns1 patterns2 passed heaps

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance alphaEqual (CExpr HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	alphaEqual (CExprVar ptr1) (CExprVar ptr2) passed heaps
		= alphaEqual ptr1 ptr2 passed heaps
	alphaEqual (CShared ptr) expr passed heaps
		# (shared, heaps)				= readPointer ptr heaps
		= alphaEqual shared.shExpr expr passed heaps
	alphaEqual expr (CShared ptr) passed heaps
		# (shared, heaps)				= readPointer ptr heaps
		= alphaEqual expr shared.shExpr passed heaps
	alphaEqual ((ptr @@# exprs1) @# exprs2) expr passed heaps
		= alphaEqual (ptr @@# (exprs1 ++ exprs2)) expr passed heaps
	alphaEqual ((expr1 @# exprs1) @# exprs2) expr2 passed heaps
		= alphaEqual (expr1 @# (exprs1 ++ exprs2)) expr2 passed heaps
	alphaEqual expr ((ptr @@# exprs1) @# exprs2) passed heaps
		= alphaEqual expr (ptr @@# (exprs1 ++ exprs2)) passed heaps
	alphaEqual expr1 ((expr2 @# exprs1) @# exprs2) passed heaps
		= alphaEqual expr1 (expr2 @# (exprs1 ++ exprs2)) passed heaps
	alphaEqual (e1 @# es1) (e2 @# es2) passed heaps
		# (equal, passed, heaps)		= alphaEqual e1 e2 passed heaps
		| not equal						= (False, passed, heaps)
		= alphaEqual es1 es2 passed heaps
	alphaEqual (ptr1 @@# es1) (ptr2 @@# es2) passed heaps
		| ptr1 <> ptr2					= (False, passed, heaps)
		= alphaEqual es1 es2 passed heaps
	alphaEqual (CLet strict1 lets1 e1) (CLet strict2 lets2 e2) passed heaps
		| strict1 <> strict2			= (False, passed, heaps)
		# (vars1, es1)					= unzip lets1
		# (vars2, es2)					= unzip lets2
		# (ok, passed, heaps)			= bindExprScope vars1 vars2 passed heaps
		| not ok						= (False, passed, heaps)
		# (equal, passed, heaps)		= alphaEqual es1 es2 passed heaps
		| not equal						= (False, passed, heaps)
		= alphaEqual e1 e2 passed heaps
	alphaEqual (CCase e1 patterns1 def1) (CCase e2 patterns2 def2) passed heaps
		# (equal, passed, heaps)		= alphaEqual e1 e2 passed heaps
		| not equal						= (False, passed, heaps)
		# (equal, passed, heaps)		= alphaEqual patterns1 patterns2 passed heaps
		| not equal						= (False, passed, heaps)
		= alphaEqual def1 def2 passed heaps
	alphaEqual (CBasicValue value1) (CBasicValue value2) passed heaps
		= alphaEqual value1 value2 passed heaps
	alphaEqual CBottom CBottom passed heaps
		= (True, passed, heaps)
	alphaEqual expr1 expr2 passed heaps
		= (False, passed, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance alphaEqual (CProp HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	alphaEqual CTrue CTrue passed heaps
		= (True, passed, heaps)
	alphaEqual CFalse CFalse passed heaps
		= (True, passed, heaps)
	alphaEqual (CPropVar ptr1) (CPropVar ptr2) passed heaps
		= alphaEqual ptr1 ptr2 passed heaps
	alphaEqual (CEqual e1 e2) (CEqual e3 e4) passed heaps
		# (equal, passed, heaps)		= alphaEqual e1 e3 passed heaps
		| not equal						= (False, passed, heaps)
		= alphaEqual e2 e4 passed heaps
	alphaEqual (CNot p1) (CNot p2) passed heaps
		= alphaEqual p1 p2 passed heaps
	alphaEqual (CAnd p1 q1) (CAnd p2 q2) passed heaps
		# (equal, passed, heaps)		= alphaEqual p1 p2 passed heaps
		| not equal						= (False, passed, heaps)
		= alphaEqual q1 q2 passed heaps
	alphaEqual (COr p1 q1) (COr p2 q2) passed heaps
		# (equal, passed, heaps)		= alphaEqual p1 p2 passed heaps
		| not equal						= (False, passed, heaps)
		= alphaEqual q1 q2 passed heaps
	alphaEqual (CImplies p1 q1) (CImplies p2 q2) passed heaps
		# (equal, passed, heaps)		= alphaEqual p1 p2 passed heaps
		| not equal						= (False, passed, heaps)
		= alphaEqual q1 q2 passed heaps
	alphaEqual (CIff p1 q1) (CIff p2 q2) passed heaps
		# (equal, passed, heaps)		= alphaEqual p1 p2 passed heaps
		| not equal						= (False, passed, heaps)
		= alphaEqual q1 q2 passed heaps
	alphaEqual (CExprForall ptr1 p1) (CExprForall ptr2 p2) passed heaps
		# (ok, passed, heaps)			= bindExprScope [ptr1] [ptr2] passed heaps
		| not ok						= (False, passed, heaps)
		= alphaEqual p1 p2 passed heaps
	alphaEqual (CExprExists ptr1 p1) (CExprExists ptr2 p2) passed heaps
		# (ok, passed, heaps)			= bindExprScope [ptr1] [ptr2] passed heaps
		| not ok						= (False, passed, heaps)
		= alphaEqual p1 p2 passed heaps
	alphaEqual (CPropForall ptr1 p1) (CPropForall ptr2 p2) passed heaps
		# (ok, passed, heaps)			= bindPropScope [ptr1] [ptr2] passed heaps
		| not ok						= (False, passed, heaps)
		= alphaEqual p1 p2 passed heaps
	alphaEqual (CPropExists ptr1 p1) (CPropExists ptr2 p2) passed heaps
		# (ok, passed, heaps)			= bindPropScope [ptr1] [ptr2] passed heaps
		| not ok						= (False, passed, heaps)
		= alphaEqual p1 p2 passed heaps
	alphaEqual (CPredicate ptr1 es1) (CPredicate ptr2 es2) passed heaps
		| ptr1 <> ptr2					= (False, passed, heaps)
		= alphaEqual es1 es2 passed heaps
	alphaEqual p q passed heaps
		= (False, passed, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
AlphaEqual :: !a !a !*CHeaps -> (!Bool, !*CHeaps) | alphaEqual a
// -------------------------------------------------------------------------------------------------------------------------------------------------
AlphaEqual x y heaps
	# passed							= {pExprVars = [], pPropVars = []}
	# (equal, passed, heaps)			= alphaEqual x y passed heaps
	# heaps								= wipePointerInfos passed.pExprVars heaps
	# heaps								= wipePointerInfos passed.pPropVars heaps
	= (equal, heaps)


























// -------------------------------------------------------------------------------------------------------------------------------------------------
class fresh a :: !Int !a !*CHeaps -> (!Int, !a, !*CHeaps)
// -------------------------------------------------------------------------------------------------------------------------------------------------

// -------------------------------------------------------------------------------------------------------------------------------------------------
generateTypeName :: !Int -> (!CName, !Int)
// -------------------------------------------------------------------------------------------------------------------------------------------------
generateTypeName num
	| num < 26				= ({"abcdefghijklmnopqrstuvwxyz".[num]}, num+1)
	= ("a" +++ toString num, num+1)

// -------------------------------------------------------------------------------------------------------------------------------------------------
newTypeDefs :: !Int ![CTypeVarPtr] !*CHeaps -> (!Int, ![CTypeVarPtr], !*CHeaps)
// -------------------------------------------------------------------------------------------------------------------------------------------------
newTypeDefs next [] heaps
	= (next, [], heaps)
newTypeDefs next [old_ptr:old_ptrs] heaps
	# (name, next)						= generateTypeName next
	# new_def							= {DummyValue & tvarName = name}
	# (new_ptr, heaps)					= newPointer new_def heaps
	# (old_def, heaps)					= readPointer old_ptr heaps
	# old_def							= {old_def & tvarInfo = TVar_Fresh new_ptr}
	# heaps								= writePointer old_ptr old_def heaps
	# (next, new_ptrs, heaps)			= newTypeDefs next old_ptrs heaps
	= (next, [new_ptr:new_ptrs], heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance fresh [a] | fresh a
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	fresh next [] heaps
		= (next, [], heaps)
	fresh next [x:xs] heaps
		#! (next, x, heaps)				= fresh next x heaps
		#! (next, xs, heaps)			= fresh next xs heaps
		= (next, [x:xs], heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance fresh (CClassRestriction HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	fresh next restriction heaps
		# (next, types, heaps)			= fresh next restriction.ccrTypes heaps
		= (next, {restriction & ccrTypes = types}, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance fresh (CSymbolType HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	fresh next symboltype heaps
		# old_ptrs						= symboltype.sytTypeVarScope
		# (next, new_ptrs, heaps)		= newTypeDefs next old_ptrs heaps
		# (next, args, heaps)			= fresh next symboltype.sytArguments heaps
		# (next, result, heaps)			= fresh next symboltype.sytResult heaps
		# (next, restrictions, heaps)	= fresh next symboltype.sytClassRestrictions heaps
		= (next, {sytTypeVarScope = new_ptrs, sytArguments = args, sytResult = result, sytClassRestrictions = restrictions}, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance fresh (CType HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	fresh next (CTypeVar ptr) heaps
		# (def, heaps)					= readPointer ptr heaps
		# (fresh, new_ptr)				= is_fresh def.tvarInfo
		| fresh							= (next, CTypeVar new_ptr, heaps)
		= (next, CTypeVar ptr, heaps)
		where
			is_fresh :: !CTypeVarInfo -> (!Bool, !CTypeVarPtr)
			is_fresh (TVar_Fresh ptr)		= (True, ptr)
			is_fresh other					= (False, nilPtr)
	fresh next (type1 ==> type2) heaps
		# (next, type1, heaps)			= fresh next type1 heaps
		# (next, type2, heaps)			= fresh next type2 heaps
		= (next, type1 ==> type2, heaps)
	fresh next (type @^ types) heaps
		# (next, type, heaps)			= fresh next type heaps
		# (next, types, heaps)			= fresh next types heaps
		= (next, type @^ types, heaps)
	fresh next (ptr @@^ types) heaps
		# (next, types, heaps)			= fresh next types heaps
		= (next, ptr @@^ types, heaps)
	fresh next (CBasicType basic) heaps
		= (next, CBasicType basic, heaps)
	fresh next (CStrict type) heaps
		= fresh next type heaps
	fresh next CUnTypable heaps
		= (next, CUnTypable, heaps)


























// -------------------------------------------------------------------------------------------------------------------------------------------------
class freshVars a :: !a !*CHeaps -> (![CExprVarPtr], ![CPropVarPtr], !a, !*CHeaps)
// -------------------------------------------------------------------------------------------------------------------------------------------------

// -------------------------------------------------------------------------------------------------------------------------------------------------
freshExprVar :: !CExprVarPtr !*CHeaps -> (!CExprVarPtr, !*CHeaps)
// -------------------------------------------------------------------------------------------------------------------------------------------------
freshExprVar old_ptr heaps
	# (old_var, heaps)							= readPointer old_ptr heaps
	# (new_ptr, heaps)							= newPointer old_var heaps
	# old_var									= {old_var & evarInfo = EVar_Fresh new_ptr}
	# heaps										= writePointer old_ptr old_var heaps
	= (new_ptr, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
freshPropVar :: !CPropVarPtr !*CHeaps -> (!CPropVarPtr, !*CHeaps)
// -------------------------------------------------------------------------------------------------------------------------------------------------
freshPropVar old_ptr heaps
	# (old_var, heaps)							= readPointer old_ptr heaps
	# (new_ptr, heaps)							= newPointer old_var heaps
	# old_var									= {old_var & pvarInfo = PVar_Fresh new_ptr}
	# heaps										= writePointer old_ptr old_var heaps
	= (new_ptr, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance freshVars [a] | freshVars a
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	freshVars [x:xs] heaps
		# (evars1, pvars1, x, heaps)			= freshVars x heaps
		# (evars2, pvars2, xs, heaps)			= freshVars xs heaps
		= (evars1 ++ evars2, pvars1 ++ pvars2, [x:xs], heaps)
	freshVars [] heaps
		= ([], [], [], heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance freshVars (Maybe a) | freshVars a
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	freshVars (Just x) heaps
		# (evars, pvars, x, heaps)				= freshVars x heaps
		= (evars, pvars, Just x, heaps)
	freshVars Nothing heaps
		= ([], [], Nothing, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance freshVars (Ptr a) | freshVars,Pointer a
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	freshVars ptr heaps
		# (x, heaps)							= readPointer ptr heaps
		# (evars, pvars, x, heaps)				= freshVars x heaps
		# heaps									= writePointer ptr x heaps
		= ([], [], ptr, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance freshVars (CAlgPattern HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	freshVars pattern heaps
		# old_scope								= pattern.atpExprVarScope
		# (new_scope, heaps)					= umap freshExprVar old_scope heaps
		# (evars, _, result, heaps)				= freshVars pattern.atpResult heaps
		# pattern								= {pattern & atpExprVarScope = new_scope, atpResult = result}
		= (old_scope ++ evars, [], pattern, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance freshVars (CBasicPattern HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	freshVars pattern heaps
		# (evars, _, result, heaps)				= freshVars pattern.bapResult heaps
		# pattern								= {pattern & bapResult = result}
		= (evars, [], pattern, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance freshVars (CBasicValue HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	freshVars (CBasicArray exprs) heaps
		# (evars, _, exprs, heaps)				= freshVars exprs heaps
		= (evars, [], CBasicArray exprs, heaps)
	freshVars other heaps
		= ([], [], other, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance freshVars (CCasePatterns HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	freshVars (CAlgPatterns type patterns) heaps
		# (evars, _, patterns, heaps)			= freshVars patterns heaps
		= (evars, [], CAlgPatterns type patterns, heaps)
	freshVars (CBasicPatterns type patterns) heaps
		# (evars, _, patterns, heaps)			= freshVars patterns heaps
		= (evars, [], CBasicPatterns type patterns, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance freshVars (CExpr HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	freshVars (CExprVar ptr) heaps
		# (var, heaps)							= readPointer ptr heaps
		= ([], [], CExprVar (exchange ptr var.evarInfo), heaps)
		where
			exchange ptr1 (EVar_Fresh ptr2)		= ptr2
			exchange ptr1 _						= ptr1
	freshVars (CShared ptr) heaps
		# (shared, heaps)						= readPointer ptr heaps
		# (evars, _, expr, heaps)				= freshVars shared.shExpr heaps
		# shared								= {shared & shExpr = expr}
		# heaps									= writePointer ptr shared heaps
		= (evars, [], CShared ptr, heaps)
	freshVars (expr @# exprs) heaps
		# (evars1, _, expr, heaps)				= freshVars expr heaps
		# (evars2, _, exprs, heaps)				= freshVars exprs heaps
		= (evars1 ++ evars2, [], expr @# exprs, heaps)
	freshVars (ptr @@# exprs) heaps
		# (evars, _, exprs, heaps)				= freshVars exprs heaps
		= (evars, [], ptr @@# exprs, heaps)
	freshVars (CLet strict lets expr) heaps
		# (old_scope, exprs)					= unzip lets
		# (new_scope, heaps)					= umap freshExprVar old_scope heaps
		# (evars1, _, exprs, heaps)				= freshVars exprs heaps
		# lets									= zip2 new_scope exprs
		# (evars2, _, expr, heaps)				= freshVars expr heaps
		= (old_scope ++ evars1 ++ evars2, [], CLet strict lets expr, heaps)
	freshVars (CCase expr patterns def) heaps
		# (evars1, _, expr, heaps)				= freshVars expr heaps
		# (evars2, _, patterns, heaps)			= freshVars patterns heaps
		# (evars3, _, def, heaps)				= freshVars def heaps
		= (evars1 ++ evars2 ++ evars3, [], CCase expr patterns def, heaps)
	freshVars (CBasicValue value) heaps
		# (evars, _, value, heaps)				= freshVars value heaps
		= (evars, [], CBasicValue value, heaps)
	freshVars (CCode codetype codecontents) heaps
		= ([], [], CCode codetype codecontents, heaps)
	freshVars CBottom heaps
		= ([], [], CBottom, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance freshVars Goal
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	freshVars goal heaps
		# (new_evars, heaps)					= umap freshExprVar goal.glExprVars heaps
		# (new_pvars, heaps)					= umap freshPropVar goal.glPropVars heaps
		# (evars1, pvars1, hyps, heaps)			= freshVars goal.glHypotheses heaps
		# (evars2, pvars2, prop, heaps)			= freshVars goal.glToProve heaps
		# goal									= {goal & glToProve = prop, glHypotheses = hyps, glExprVars = new_evars, glPropVars = new_pvars}
		= (goal.glExprVars ++ evars1 ++ evars2, goal.glPropVars ++ pvars1 ++ pvars2, goal, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance freshVars Hypothesis
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	freshVars hypothesis heaps
		# (evars, pvars, prop, heaps)			= freshVars hypothesis.hypProp heaps
		= (evars, pvars, {hypothesis & hypProp = prop}, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance freshVars (CProp HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	freshVars CTrue heaps
		= ([], [], CTrue, heaps)
	freshVars CFalse heaps
		= ([], [], CFalse, heaps)
	freshVars (CPropVar ptr) heaps
		# (var, heaps)							= readPointer ptr heaps
		= ([], [], CPropVar (exchange ptr var.pvarInfo), heaps)
		where
			exchange ptr1 (PVar_Fresh ptr2)		= ptr2
			exchange ptr1 _						= ptr1
	freshVars (CNot p) heaps
		# (evars, pvars, p, heaps)				= freshVars p heaps
		= (evars, pvars, CNot p, heaps)
	freshVars (CAnd p q) heaps
		# (evars1, pvars1, p, heaps)			= freshVars p heaps
		# (evars2, pvars2, q, heaps)			= freshVars q heaps
		= (evars1 ++ evars2, pvars1 ++ pvars2, CAnd p q, heaps)
	freshVars (COr p q) heaps
		# (evars1, pvars1, p, heaps)			= freshVars p heaps
		# (evars2, pvars2, q, heaps)			= freshVars q heaps
		= (evars1 ++ evars2, pvars1 ++ pvars2, COr p q, heaps)
	freshVars (CImplies p q) heaps
		# (evars1, pvars1, p, heaps)			= freshVars p heaps
		# (evars2, pvars2, q, heaps)			= freshVars q heaps
		= (evars1 ++ evars2, pvars1 ++ pvars2, CImplies p q, heaps)
	freshVars (CIff p q) heaps
		# (evars1, pvars1, p, heaps)			= freshVars p heaps
		# (evars2, pvars2, q, heaps)			= freshVars q heaps
		= (evars1 ++ evars2, pvars1 ++ pvars2, CIff p q, heaps)
	freshVars (CExprForall old_ptr p) heaps
		# (new_ptr, heaps)						= freshExprVar old_ptr heaps
		# (evars, pvars, p, heaps)				= freshVars p heaps
		= ([old_ptr:evars], pvars, CExprForall new_ptr p, heaps)
	freshVars (CExprExists old_ptr p) heaps
		# (new_ptr, heaps)						= freshExprVar old_ptr heaps
		# (evars, pvars, p, heaps)				= freshVars p heaps
		= ([old_ptr:evars], pvars, CExprExists new_ptr p, heaps)
	freshVars (CPropForall old_ptr p) heaps
		# (new_ptr, heaps)						= freshPropVar old_ptr heaps
		# (evars, pvars, p, heaps)				= freshVars p heaps
		= (evars, [old_ptr:pvars], CPropForall new_ptr p, heaps)
	freshVars (CPropExists old_ptr p) heaps
		# (new_ptr, heaps)						= freshPropVar old_ptr heaps
		# (evars, pvars, p, heaps)				= freshVars p heaps
		= (evars, [old_ptr:pvars], CPropExists new_ptr p, heaps)
	freshVars (CEqual e1 e2) heaps
		# (evars1, _, e1, heaps)				= freshVars e1 heaps
		# (evars2, _, e2, heaps)				= freshVars e2 heaps
		= (evars1 ++ evars2, [], CEqual e1 e2, heaps)
	freshVars (CPredicate ptr exprs) heaps
		# (evars, _, exprs, heaps)				= freshVars exprs heaps
		= (evars, [], CPredicate ptr exprs, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
FreshVars :: !a !*CHeaps -> (!a, !*CHeaps) | freshVars a
// -------------------------------------------------------------------------------------------------------------------------------------------------
FreshVars x heaps
	# (evars, pvars, x, heaps)					= freshVars x heaps
	# heaps										= wipePointerInfos evars heaps
	# heaps										= wipePointerInfos pvars heaps
	= (x, heaps)













// -------------------------------------------------------------------------------------------------------------------------------------------------
class getPtrInfo a :: !a !PtrInfo !*CHeaps -> (!PtrInfo, !*CHeaps)
// -------------------------------------------------------------------------------------------------------------------------------------------------

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance getPtrInfo [a] | getPtrInfo a
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	getPtrInfo [] info heaps
		= (info, heaps)
	getPtrInfo [x:xs] info heaps
		# (info, heaps)				= getPtrInfo x info heaps
		# (info, heaps)				= getPtrInfo xs info heaps
		= (info, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance getPtrInfo (Maybe a) | getPtrInfo a
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	getPtrInfo Nothing info heaps
		= (info, heaps)
	getPtrInfo (Just x) info heaps
		= getPtrInfo x info heaps

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance getPtrInfo (Ptr a) | getPtrInfo,Pointer a
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	getPtrInfo ptr info heaps
		# (x, heaps)				= readPointer ptr heaps
		# (info, heaps)				= getPtrInfo x info heaps
		= (info, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance getPtrInfo (CAlgPattern a)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	getPtrInfo pattern info heaps
		# info						= {info & boundExprVars = pattern.atpExprVarScope ++ info.boundExprVars}
		= getPtrInfo pattern.atpResult info heaps

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance getPtrInfo (CBasicPattern a)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	getPtrInfo pattern info heaps
		= getPtrInfo pattern.bapResult info heaps

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance getPtrInfo (CBasicValue a)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	getPtrInfo (CBasicArray exprs) info heaps
		= getPtrInfo exprs info heaps
	getPtrInfo _ info heaps
		= (info, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance getPtrInfo (CCasePatterns a)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	getPtrInfo (CAlgPatterns _ patterns) info heaps
		= getPtrInfo patterns info heaps
	getPtrInfo (CBasicPatterns _ patterns) info heaps
		= getPtrInfo patterns info heaps

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance getPtrInfo (CExpr a)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	getPtrInfo (CExprVar ptr) info heaps
		# is_bound					= isMember ptr info.boundExprVars
		| is_bound					= (info, heaps)
		# seen_before				= isMember ptr info.freeExprVars
		| seen_before				= (info, heaps)
		= ({info & freeExprVars = [ptr:info.freeExprVars]}, heaps)
	getPtrInfo (CShared ptr) info heaps
		# seen_before				= isMember ptr info.sharedExprs
		| seen_before				= (info, heaps)
		# info						= {info & sharedExprs = [ptr:info.sharedExprs]}
		# (shared, heaps)			= readPointer ptr heaps
		= getPtrInfo shared.shExpr info heaps
	getPtrInfo (expr @# exprs) info heaps
		# (info, heaps)				= getPtrInfo expr info heaps
		# (info, heaps)				= getPtrInfo exprs info heaps
		= (info, heaps)
	getPtrInfo (_ @@# exprs) info heaps
		= getPtrInfo exprs info heaps
	getPtrInfo (CLet _ lets expr) info heaps
		# (vars, exprs)				= unzip lets
		# info						= {info & boundExprVars = vars ++ info.boundExprVars}
		# (info, heaps)				= getPtrInfo exprs info heaps
		# (info, heaps)				= getPtrInfo expr info heaps
		= (info, heaps)
	getPtrInfo (CCase expr patterns def) info heaps
		# (info, heaps)				= getPtrInfo expr info heaps
		# (info, heaps)				= getPtrInfo patterns info heaps
		# (info, heaps)				= getPtrInfo def info heaps
		= (info, heaps)
	getPtrInfo (CBasicValue value) info heaps
		= getPtrInfo value info heaps
	getPtrInfo (CCode _ _) info heaps
		= (info, heaps)
	getPtrInfo CBottom info heaps
		= (info, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance getPtrInfo Goal
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	getPtrInfo goal info heaps
		# (info, heaps)				= getPtrInfo goal.glHypotheses info heaps
		# (info, heaps)				= getPtrInfo goal.glToProve info heaps
		= (info, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance getPtrInfo Hypothesis
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	getPtrInfo hypothesis info heaps
		= getPtrInfo hypothesis.hypProp info heaps

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance getPtrInfo (CProp a)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	getPtrInfo (CPropVar ptr) info heaps
		# is_bound					= isMember ptr info.boundPropVars
		| is_bound					= (info, heaps)
		# seen_before				= isMember ptr info.freePropVars
		| seen_before				= (info, heaps)
		= ({info & freePropVars = [ptr:info.freePropVars]}, heaps)
	getPtrInfo CTrue info heaps
		= (info, heaps)
	getPtrInfo CFalse info heaps
		= (info, heaps)
	getPtrInfo (CNot p) info heaps
		= getPtrInfo p info heaps
	getPtrInfo (CAnd p q) info heaps
		# (info, heaps)				= getPtrInfo p info heaps
		# (info, heaps)				= getPtrInfo q info heaps
		= (info, heaps)
	getPtrInfo (COr p q) info heaps
		# (info, heaps)				= getPtrInfo p info heaps
		# (info, heaps)				= getPtrInfo q info heaps
		= (info, heaps)
	getPtrInfo (CImplies p q) info heaps
		# (info, heaps)				= getPtrInfo p info heaps
		# (info, heaps)				= getPtrInfo q info heaps
		= (info, heaps)
	getPtrInfo (CIff p q) info heaps
		# (info, heaps)				= getPtrInfo p info heaps
		# (info, heaps)				= getPtrInfo q info heaps
		= (info, heaps)
	getPtrInfo (CExprForall ptr p) info heaps
		# info						= {info & boundExprVars = [ptr:info.boundExprVars]}
		= getPtrInfo p info heaps
	getPtrInfo (CExprExists ptr p) info heaps
		# info						= {info & boundExprVars = [ptr:info.boundExprVars]}
		= getPtrInfo p info heaps
	getPtrInfo (CPropForall ptr p) info heaps
		# info						= {info & boundPropVars = [ptr:info.boundPropVars]}
		= getPtrInfo p info heaps
	getPtrInfo (CPropExists ptr p) info heaps
		# info						= {info & boundPropVars = [ptr:info.boundPropVars]}
		= getPtrInfo p info heaps
	getPtrInfo (CEqual e1 e2) info heaps
		# (info, heaps)				= getPtrInfo e1 info heaps
		# (info, heaps)				= getPtrInfo e2 info heaps
		= (info, heaps)
	getPtrInfo (CPredicate ptr exprs) info heaps
		= getPtrInfo exprs info heaps

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance getPtrInfo (CType a)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	getPtrInfo (CTypeVar ptr) info heaps
		# is_bound					= isMember ptr info.boundTypeVars
		| is_bound					= (info, heaps)
		# seen_before				= isMember ptr info.freeTypeVars
		| seen_before				= (info, heaps)
		= ({info & freeTypeVars = [ptr:info.freeTypeVars]}, heaps)
	getPtrInfo (type1 ==> type2) info heaps
		# (info, heaps)				= getPtrInfo type1 info heaps
		# (info, heaps)				= getPtrInfo type2 info heaps
		= (info, heaps)
	getPtrInfo (type @^ types) info heaps
		# (info, heaps)				= getPtrInfo type info heaps
		# (info, heaps)				= getPtrInfo types info heaps
		= (info, heaps)
	getPtrInfo (_ @@^ types) info heaps
		= getPtrInfo types info heaps
	getPtrInfo (CBasicType _) info heaps
		= (info, heaps)
	getPtrInfo (CStrict type) info heaps
		= getPtrInfo type info heaps
	getPtrInfo CUnTypable info heaps
		= (info, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
GetPtrInfo :: !a !*CHeaps -> (!PtrInfo, !*CHeaps) | getPtrInfo a
// -------------------------------------------------------------------------------------------------------------------------------------------------
GetPtrInfo x heaps
	= getPtrInfo x DummyValue heaps















:: SourcePointer = SourceExprVar CExprVarPtr | SourcePropVar CPropVarPtr
:: VarDB :== [(SourcePointer, String, Int)]
// -------------------------------------------------------------------------------------------------------------------------------------------------
MakeUniqueNames :: !PtrInfo !*CHeaps -> (!Bool, !*CHeaps)
// -------------------------------------------------------------------------------------------------------------------------------------------------
MakeUniqueNames info heaps
	# (var_db, heaps)					= gatherNames (removeDup (info.boundExprVars ++ info.freeExprVars))
													  (removeDup (info.boundPropVars ++ info.freePropVars))
													  heaps
	= makeUnique False [] var_db heaps

// -------------------------------------------------------------------------------------------------------------------------------------------------
disectName :: !String ![Int] -> (!String, !Int)
// -------------------------------------------------------------------------------------------------------------------------------------------------
disectName name digits
	# l									= size name
	| l == 0							= abort "Error in MakeUnique: encountered a variable name that is either empty or a number."
	# last_char							= select name (l-1)
	= case isDigit last_char of
		True							-> disectName (name%(0, l-2)) [digitToInt last_char: digits]
		False							-> (name, if (isEmpty digits) (-1) (makeNum 0 digits))

// -------------------------------------------------------------------------------------------------------------------------------------------------
gatherNames :: ![CExprVarPtr] ![CPropVarPtr] !*CHeaps -> (!VarDB, !*CHeaps)
// -------------------------------------------------------------------------------------------------------------------------------------------------
gatherNames [ptr:ptrs] pvars heaps
	# (var, heaps)						= readPointer ptr heaps
	# (name, index)						= disectName var.evarName []
	# (var_db, heaps)					= gatherNames ptrs pvars heaps
	= ([(SourceExprVar ptr, name, index): var_db], heaps)
gatherNames [] [ptr:ptrs] heaps
	# (var, heaps)						= readPointer ptr heaps
	# (name, index)						= disectName var.pvarName []
	# (var_db, heaps)					= gatherNames [] ptrs heaps
	= ([(SourcePropVar ptr, name, index): var_db], heaps)
gatherNames [] [] heaps
	= ([], heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
makeNum :: !Int ![Int] -> Int
// -------------------------------------------------------------------------------------------------------------------------------------------------
makeNum n []
	= n
makeNum n [digit: digits]
	= makeNum (10*n + digit) digits 

// -------------------------------------------------------------------------------------------------------------------------------------------------
makeUnique :: !Bool !VarDB !VarDB !*CHeaps -> (!Bool, !*CHeaps)
// -------------------------------------------------------------------------------------------------------------------------------------------------
makeUnique changed passed_db [entry=:(source, name, index): var_db] heaps
	# other_indexes						= [i \\ (_, n, i) <- passed_db++var_db | n == name]
	| not (isMember index other_indexes)= makeUnique changed [entry: passed_db] var_db heaps
	# new_index							= newIndex (if (index < 0) 1 (index+1)) other_indexes
	# new_entry							= (source, name, new_index) 
	# heaps								= newName new_entry heaps
	= makeUnique True [new_entry: passed_db] var_db heaps
makeUnique changed _ [] heaps
	= (changed, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
newIndex :: !Int ![Int] -> Int
// -------------------------------------------------------------------------------------------------------------------------------------------------
newIndex i list
	= case (isMember i list) of
		True							-> newIndex (i+1) list
		False							-> i

// -------------------------------------------------------------------------------------------------------------------------------------------------
newName :: !(!SourcePointer, !String, !Int) !*CHeaps -> *CHeaps
// -------------------------------------------------------------------------------------------------------------------------------------------------
newName (SourceExprVar ptr, name, index) heaps
	# (var, heaps)						= readPointer ptr heaps
	# var								= {var & evarName = name +++ toString index}
	= writePointer ptr var heaps
newName (SourcePropVar ptr, name, index) heaps
	# (var, heaps)						= readPointer ptr heaps
	# var								= {var & pvarName = name +++ toString index}
	= writePointer ptr var heaps
















// -------------------------------------------------------------------------------------------------------------------------------------------------
class removeStrictness a :: !a -> a
// -------------------------------------------------------------------------------------------------------------------------------------------------

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance removeStrictness [a] | removeStrictness a
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	removeStrictness [x:xs]
		= [removeStrictness x: removeStrictness xs]
	removeStrictness []
		= []

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance removeStrictness (CSymbolType a)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	removeStrictness symboltype
		= {symboltype	& sytArguments	= removeStrictness symboltype.sytArguments
						, sytResult		= removeStrictness symboltype.sytResult}

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance removeStrictness (CType a)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	removeStrictness (CTypeVar ptr)
		= CTypeVar ptr
	removeStrictness (type1 ==> type2)
		= removeStrictness type1 ==> removeStrictness type2
	removeStrictness (type @^ types)
		= removeStrictness type @^ removeStrictness types
	removeStrictness (ptr @@^ types)
		= ptr @@^ removeStrictness types
	removeStrictness (CBasicType type)
		= CBasicType type
	removeStrictness (CStrict type)
		= removeStrictness type
	removeStrictness CUnTypable
		= CUnTypable






















// -------------------------------------------------------------------------------------------------------------------------------------------------
class safeSubst a		:: ![CSharedPtr] !a !*CHeaps -> (![CSharedPtr], !a, !*CHeaps)
class substPointer a	:: !(Ptr a)			!*CHeaps -> (!Ptr a, !*CHeaps)
class SimpleSubst a		:: !Substitution !a			 -> a
// -------------------------------------------------------------------------------------------------------------------------------------------------

// -------------------------------------------------------------------------------------------------------------------------------------------------
SafeSubst :: !Substitution !a !*CHeaps -> (!a, !*CHeaps) | safeSubst a
// -------------------------------------------------------------------------------------------------------------------------------------------------
SafeSubst sub x heaps
	# (expr_ptrs, exprs)				= unzip sub.subExprVars
	# (prop_ptrs, props)				= unzip sub.subPropVars
	# (type_ptrs, types)				= unzip sub.subTypeVars
	# heaps								= setExprVarInfos expr_ptrs (map EVar_Subst exprs) heaps
	# heaps								= setPropVarInfos prop_ptrs (map PVar_Subst props) heaps
	# heaps								= setTypeVarInfos type_ptrs (map TVar_Subst types) heaps
	#! (passed, x, heaps)				= safeSubst [] x heaps
	# heaps								= wipePointerInfos expr_ptrs heaps
	# heaps								= wipePointerInfos prop_ptrs heaps
	# heaps								= wipePointerInfos type_ptrs heaps
	# heaps								= setPassedInfos passed False heaps
	= (x, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance safeSubst [a] | safeSubst a
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	safeSubst passed [x:xs] heaps
		#! (passed, x, heaps)			= safeSubst passed x heaps
		#! (passed, xs, heaps)			= safeSubst passed xs heaps
		= (passed, [x:xs], heaps)
	safeSubst passed [] heaps
		= (passed, [], heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance SimpleSubst [a] | SimpleSubst a
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	SimpleSubst sub [x:xs]
		# x								= SimpleSubst sub x
		# xs							= SimpleSubst sub xs
		= [x:xs]
	SimpleSubst sub []
		= []

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance safeSubst (Maybe a) | safeSubst a
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	safeSubst passed (Just x) heaps
		#! (passed, x, heaps)			= safeSubst passed x heaps
		= (passed, Just x, heaps)
	safeSubst passed Nothing heaps
		= (passed, Nothing, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance safeSubst (Ptr a) | safeSubst,Pointer a
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	safeSubst passed ptr heaps
		# (x, heaps)					= readPointer ptr heaps
		#! (passed, x, heaps)			= safeSubst passed x heaps
		# heaps							= writePointer ptr x heaps
		= (passed, ptr, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance safeSubst (CAlgPattern HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	safeSubst passed pattern heaps
		# (scope, heaps)				= umap substPointer pattern.atpExprVarScope heaps
		#! (passed, result, heaps)		= safeSubst passed pattern.atpResult heaps
		= (passed, {pattern & atpExprVarScope = scope, atpResult = result}, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance safeSubst (CBasicPattern HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	safeSubst passed pattern heaps
		#! (passed, result, heaps)		= safeSubst passed pattern.bapResult heaps
		= (passed, {pattern & bapResult = result}, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance safeSubst (CBasicValue HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	safeSubst passed (CBasicArray exprs) heaps
		#! (passed, exprs, heaps)		= safeSubst passed exprs heaps
		= (passed, CBasicArray exprs, heaps)
	safeSubst passed other heaps
		= (passed, other, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance safeSubst (CCasePatterns HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	safeSubst passed (CAlgPatterns type patterns) heaps
		#! (passed, patterns, heaps)	= safeSubst passed patterns heaps
		= (passed, CAlgPatterns type patterns, heaps)
	safeSubst passed (CBasicPatterns type patterns) heaps
		#! (passed, patterns, heaps)	= safeSubst passed patterns heaps
		= (passed, CBasicPatterns type patterns, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance SimpleSubst (CClassRestriction HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	SimpleSubst sub restr
		= {restr	& ccrTypes			= map (SimpleSubst sub) restr.ccrTypes
		  }

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance safeSubst (CExpr HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	safeSubst passed (CExprVar ptr) heaps
		#! (def, heaps)					= readPointer ptr heaps
		# (change, expr)				= is_subst def.evarInfo
		| change						= (passed, expr, heaps)
		= (passed, CExprVar ptr, heaps)
		where
			is_subst :: !CExprVarInfo -> (!Bool, !CExprH)
			is_subst (EVar_Subst expr)	= (True, expr)
			is_subst other				= (False, DummyValue)
	safeSubst passed (CShared ptr) heaps
		# passed						= [ptr:passed]
		#! (shared, heaps)				= readPointer ptr heaps
		| shared.shPassed				= (passed, CShared ptr, heaps)
		#! (passed, expr, heaps)		= safeSubst passed shared.shExpr heaps
		# shared						= {shared & shExpr = expr, shPassed = True}
		#! heaps						= writePointer ptr shared heaps
		= (passed, CShared ptr, heaps)
	safeSubst passed (expr @# exprs) heaps
		#! (passed, expr, heaps)		= safeSubst passed expr heaps
		#! (passed, exprs, heaps)		= safeSubst passed exprs heaps
		= (passed, expr @# exprs, heaps)
	safeSubst passed (ptr @@# exprs) heaps
		#! (passed, exprs, heaps)		= safeSubst passed exprs heaps
		= (passed, ptr @@# exprs, heaps)
	safeSubst passed (CLet strict lets expr) heaps
		# (vars, exprs)					= unzip lets
		# (vars, heaps)					= umap substPointer vars heaps
		#! (passed, exprs, heaps)		= safeSubst passed exprs heaps
		# lets							= zip2 vars exprs
		#! (passed, expr, heaps)		= safeSubst passed expr heaps
		= (passed, CLet strict lets expr, heaps)
	safeSubst passed (CCase expr patterns def) heaps
		#! (passed, expr, heaps)		= safeSubst passed expr heaps
		#! (passed, patterns, heaps)	= safeSubst passed patterns heaps
		#! (passed, def, heaps)			= safeSubst passed def heaps
		= (passed, CCase expr patterns def, heaps)
	safeSubst passed (CBasicValue value) heaps
		#! (passed, value, heaps)		= safeSubst passed value heaps
		= (passed, CBasicValue value, heaps)
	safeSubst passed (CCode codetype codecontents) heaps
		= (passed, CCode codetype codecontents, heaps)
	safeSubst passed CBottom heaps
		= (passed, CBottom, heaps)

// change a VAR to a VAR
// -------------------------------------------------------------------------------------------------------------------------------------------------
instance substPointer CExprVarDef
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	substPointer ptr heaps
		#! (def, heaps)					= readPointer ptr heaps
		# (change, new_ptr)				= is_subst_var def.evarInfo
		| change						= (new_ptr, heaps)
		= (ptr, heaps)
		where
			is_subst_var :: !CExprVarInfo -> (!Bool, !CExprVarPtr)
			is_subst_var (EVar_Subst (CExprVar ptr))		= (True, ptr)
			is_subst_var other								= (False, nilPtr)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance safeSubst Goal
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	safeSubst passed goal heaps
		# (passed, to_prove, heaps)		= safeSubst passed goal.glToProve heaps
		# (passed, hyps, heaps)			= subst_in_hyps passed goal.glHypotheses heaps
		= (passed, {goal & glHypotheses = hyps, glToProve = to_prove}, heaps)
		where
			subst_in_hyps :: ![CSharedPtr] ![HypothesisPtr] !*CHeaps -> (![CSharedPtr], ![HypothesisPtr], !*CHeaps)
			subst_in_hyps passed [ptr:ptrs] heaps
				# (hyp, heaps)			= readPointer ptr heaps
				# (passed, prop, heaps)	= safeSubst passed hyp.hypProp heaps
				# new_hyp				= {hyp & hypProp = prop}
				# (new_ptr, heaps)		= newPointer new_hyp heaps
				# (passed, ptrs, heaps)	= subst_in_hyps passed ptrs heaps
				= (passed, [new_ptr:ptrs], heaps)
			subst_in_hyps passed [] heaps
				= (passed, [], heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance safeSubst Hypothesis
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	safeSubst passed hyp heaps
		# (passed, prop, heaps)			= safeSubst passed hyp.hypProp heaps
		= (passed, {hyp & hypProp = prop}, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance safeSubst (CProp HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	safeSubst passed CTrue heaps
		= (passed, CTrue, heaps)
	safeSubst passed CFalse heaps
		= (passed, CFalse, heaps)
	safeSubst passed (CPropVar ptr) heaps
		#! (def, heaps)					= readPointer ptr heaps
		# (change, prop)				= is_subst def.pvarInfo
		| change						= (passed, prop, heaps)
		= (passed, CPropVar ptr, heaps)
		where
			is_subst :: !CPropVarInfo -> (!Bool, !CPropH)
			is_subst (PVar_Subst prop)	= (True, prop)
			is_subst other				= (False, DummyValue)
	safeSubst passed (CNot p) heaps
		#! (passed, p, heaps)			= safeSubst passed p heaps
		= (passed, CNot p, heaps)
	safeSubst passed (CAnd p q) heaps
		#! (passed, p, heaps)			= safeSubst passed p heaps
		#! (passed, q, heaps)			= safeSubst passed q heaps
		= (passed, CAnd p q, heaps)
	safeSubst passed (COr p q) heaps
		#! (passed, p, heaps)			= safeSubst passed p heaps
		#! (passed, q, heaps)			= safeSubst passed q heaps
		= (passed, COr p q, heaps)
	safeSubst passed (CImplies p q) heaps
		#! (passed, p, heaps)			= safeSubst passed p heaps
		#! (passed, q, heaps)			= safeSubst passed q heaps
		= (passed, CImplies p q, heaps)
	safeSubst passed (CIff p q) heaps
		#! (passed, p, heaps)			= safeSubst passed p heaps
		#! (passed, q, heaps)			= safeSubst passed q heaps
		= (passed, CIff p q, heaps)
	safeSubst passed (CExprForall ptr p) heaps
		# (ptr, heaps)					= substPointer ptr heaps
		#! (passed, p, heaps)			= safeSubst passed p heaps
		= (passed, CExprForall ptr p, heaps)
	safeSubst passed (CExprExists ptr p) heaps
		# (ptr, heaps)					= substPointer ptr heaps
		#! (passed, p, heaps)			= safeSubst passed p heaps
		= (passed, CExprExists ptr p, heaps)
	safeSubst passed (CPropForall ptr p) heaps
		# (ptr, heaps)					= substPointer ptr heaps
		#! (passed, p, heaps)			= safeSubst passed p heaps
		= (passed, CPropForall ptr p, heaps)
	safeSubst passed (CPropExists ptr p) heaps
		# (ptr, heaps)					= substPointer ptr heaps
		#! (passed, p, heaps)			= safeSubst passed p heaps
		= (passed, CPropExists ptr p, heaps)
	safeSubst passed (CEqual e1 e2) heaps
		#! (passed, e1, heaps)			= safeSubst passed e1 heaps
		#! (passed, e2, heaps)			= safeSubst passed e2 heaps
		= (passed, CEqual e1 e2, heaps)
	safeSubst passed (CPredicate ptr exprs) heaps
		#! (passed, exprs, heaps)		= safeSubst passed exprs heaps
		= (passed, CPredicate ptr exprs, heaps)

// change a VAR to a VAR
// -------------------------------------------------------------------------------------------------------------------------------------------------
instance substPointer CPropVarDef
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	substPointer ptr heaps
		#! (def, heaps)					= readPointer ptr heaps
		# (change, new_ptr)				= is_subst_var def.pvarInfo
		| change						= (new_ptr, heaps)
		= (ptr, heaps)
		where
			is_subst_var :: !CPropVarInfo -> (!Bool, !CPropVarPtr)
			is_subst_var (PVar_Subst (CPropVar ptr))		= (True, ptr)
			is_subst_var other								= (False, nilPtr)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance SimpleSubst (CSymbolType HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	SimpleSubst sub symboltype
		= {symboltype	& sytArguments			= map (SimpleSubst sub) symboltype.sytArguments
						, sytResult				= SimpleSubst sub symboltype.sytResult
						, sytClassRestrictions	= map (SimpleSubst sub) symboltype.sytClassRestrictions
						}

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance safeSubst (CType HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	safeSubst passed (CTypeVar ptr) heaps
		#! (def, heaps)					= readPointer ptr heaps
		# (change, type)				= is_subst def.tvarInfo
		| change						= (passed, type, heaps)
		= (passed, CTypeVar ptr, heaps)
		where
			is_subst :: !CTypeVarInfo -> (!Bool, !CTypeH)
			is_subst (TVar_Subst type)	= (True, type)
			is_subst other				= (False, DummyValue)
	safeSubst passed (type1 ==> type2) heaps
		#! (passed, type1, heaps)		= safeSubst passed type1 heaps
		#! (passed, type2, heaps)		= safeSubst passed type2 heaps
		= (passed, type1 ==> type2, heaps)
	safeSubst passed ((CTypeVar ptr) @^ types) heaps
		#! (passed, types, heaps)		= safeSubst passed types heaps
		#! (def, heaps)					= readPointer ptr heaps
		= (passed, change ptr def.tvarInfo types, heaps)
		where
			change :: !CTypeVarPtr !CTypeVarInfo ![CTypeH] -> CTypeH
			change ptr1 (TVar_Subst (ptr2 @^ args)) types	= ptr2 @^ (args ++ types)
			change ptr1 (TVar_Subst (type @@^ args)) types	= type @@^ (args ++ types)
			change ptr1 (TVar_Subst other)			types	= other @^ types
			change ptr1 other						types	= (CTypeVar ptr1) @^ types
	safeSubst passed (type @^ types) heaps
		#! (passed, type, heaps)		= safeSubst passed type heaps
		#! (passed, types, heaps)		= safeSubst passed types heaps
		= (passed, type @^ types, heaps)
	safeSubst passed (ptr @@^ types) heaps
		#! (passed, types, heaps)		= safeSubst passed types heaps
		= (passed, ptr @@^ types, heaps)
	safeSubst passed (CBasicType type) heaps
		= (passed, CBasicType type, heaps)
	safeSubst passed (CStrict type) heaps
		#! (passed, type, heaps)		= safeSubst passed type heaps
		= (passed, CStrict type, heaps)
	safeSubst passed CUnTypable heaps
		= (passed, CUnTypable, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance SimpleSubst (CType HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	SimpleSubst sub (CTypeVar ptr)
		# filtered						= filter (\(var,type) -> var == ptr) sub.subTypeVars
		| isEmpty filtered				= CTypeVar ptr
		= snd (hd filtered)
	SimpleSubst sub (type1 ==> type2)
		# type1							= SimpleSubst sub type1
		# type2							= SimpleSubst sub type2
		= type1 ==> type2
	SimpleSubst sub ((CTypeVar ptr) @^ types)
		# types							= SimpleSubst sub types
		# filtered						= filter (\(var,type) -> var == ptr) sub.subTypeVars
		| isEmpty filtered				= (CTypeVar ptr) @^ types
		= change ptr (snd (hd filtered)) types
		where
			change :: !CTypeVarPtr !CTypeH ![CTypeH] -> CTypeH
			change ptr1 (ptr2 @^ args)  types	= ptr2 @^ (args ++ types)
			change ptr1 (type @@^ args) types	= type @@^ (args ++ types)
			change ptr1 other			types	= other @^ types
	SimpleSubst sub (type @^ types)
		# type							= SimpleSubst sub type
		# types							= SimpleSubst sub types
		= type @^ types
	SimpleSubst sub (ptr @@^ types)
		# types							= SimpleSubst sub types
		= ptr @@^ types
	SimpleSubst sub (CBasicType type)
		= CBasicType type
	SimpleSubst sub (CStrict type)
		# type							= SimpleSubst sub type
		= CStrict type
	SimpleSubst sub CUnTypable
		= CUnTypable




















// -------------------------------------------------------------------------------------------------------------------------------------------------
class unsafeSubst a		:: !a !*CHeaps -> (!a, !*CHeaps)
// -------------------------------------------------------------------------------------------------------------------------------------------------

// -------------------------------------------------------------------------------------------------------------------------------------------------
UnsafeSubst :: !Substitution !a !*CHeaps -> (!a, !*CHeaps) | unsafeSubst a
// -------------------------------------------------------------------------------------------------------------------------------------------------
UnsafeSubst sub x heaps
	# (expr_ptrs, exprs)				= unzip sub.subExprVars
	# (prop_ptrs, props)				= unzip sub.subPropVars
	# (type_ptrs, types)				= unzip sub.subTypeVars
	# heaps								= setExprVarInfos expr_ptrs (map EVar_Subst exprs) heaps
	# heaps								= setPropVarInfos prop_ptrs (map PVar_Subst props) heaps
	# heaps								= setTypeVarInfos type_ptrs (map TVar_Subst types) heaps
	#! (x, heaps)						= unsafeSubst x heaps
	# heaps								= wipePointerInfos expr_ptrs heaps
	# heaps								= wipePointerInfos prop_ptrs heaps
	# heaps								= wipePointerInfos type_ptrs heaps
	= (x, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance unsafeSubst [a] | unsafeSubst a
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	unsafeSubst [x:xs] heaps
		#! (x, heaps)					= unsafeSubst x heaps
		#! (xs, heaps)					= unsafeSubst xs heaps
		= ([x:xs], heaps)
	unsafeSubst [] heaps
		= ([], heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance unsafeSubst (Maybe a) | unsafeSubst a
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	unsafeSubst (Just x) heaps
		#! (x, heaps)					= unsafeSubst x heaps
		= (Just x, heaps)
	unsafeSubst Nothing heaps
		= (Nothing, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance unsafeSubst (Ptr a) | unsafeSubst,Pointer a
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	unsafeSubst ptr heaps
		# (x, heaps)					= readPointer ptr heaps
		#! (x, heaps)					= unsafeSubst x heaps
		# heaps							= writePointer ptr x heaps
		= (ptr, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance unsafeSubst (CAlgPattern HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	unsafeSubst pattern heaps
		# (scope, heaps)				= umap substPointer pattern.atpExprVarScope heaps
		#! (result, heaps)				= unsafeSubst pattern.atpResult heaps
		= ({pattern & atpExprVarScope = scope, atpResult = result}, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance unsafeSubst (CBasicPattern HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	unsafeSubst pattern heaps
		#! (result, heaps)				= unsafeSubst pattern.bapResult heaps
		= ({pattern & bapResult = result}, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance unsafeSubst (CBasicValue HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	unsafeSubst (CBasicArray exprs) heaps
		#! (exprs, heaps)				= unsafeSubst exprs heaps
		= (CBasicArray exprs, heaps)
	unsafeSubst other heaps
		= (other, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance unsafeSubst (CCasePatterns HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	unsafeSubst (CAlgPatterns type patterns) heaps
		#! (patterns, heaps)			= unsafeSubst patterns heaps
		= (CAlgPatterns type patterns, heaps)
	unsafeSubst (CBasicPatterns type patterns) heaps
		#! (patterns, heaps)			= unsafeSubst patterns heaps
		= (CBasicPatterns type patterns, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance unsafeSubst (CExpr HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	unsafeSubst (CExprVar ptr) heaps
		#! (def, heaps)					= readPointer ptr heaps
		# (change, expr)				= is_subst def.evarInfo
		| change						= (expr, heaps)
		= (CExprVar ptr, heaps)
		where
			is_subst :: !CExprVarInfo -> (!Bool, !CExprH)
			is_subst (EVar_Subst expr)	= (True, expr)
			is_subst other				= (False, DummyValue)
	unsafeSubst (CShared ptr) heaps
		= (CShared ptr, heaps)
	unsafeSubst (expr @# exprs) heaps
		#! (expr, heaps)				= unsafeSubst expr heaps
		#! (exprs, heaps)				= unsafeSubst exprs heaps
		= (expr @# exprs, heaps)
	unsafeSubst (ptr @@# exprs) heaps
		#! (exprs, heaps)				= unsafeSubst exprs heaps
		= (ptr @@# exprs, heaps)
	unsafeSubst (CLet strict lets expr) heaps
		# (vars, exprs)					= unzip lets
		# (vars, heaps)					= umap substPointer vars heaps
		#! (exprs, heaps)				= unsafeSubst exprs heaps
		# lets							= zip2 vars exprs
		#! (expr, heaps)				= unsafeSubst expr heaps
		= (CLet strict lets expr, heaps)
	unsafeSubst (CCase expr patterns def) heaps
		#! (expr, heaps)				= unsafeSubst expr heaps
		#! (patterns, heaps)			= unsafeSubst patterns heaps
		#! (def, heaps)					= unsafeSubst def heaps
		= (CCase expr patterns def, heaps)
	unsafeSubst (CBasicValue value) heaps
		#! (value, heaps)				= unsafeSubst value heaps
		= (CBasicValue value, heaps)
	unsafeSubst (CCode codetype codecontents) heaps
		= (CCode codetype codecontents, heaps)
	unsafeSubst CBottom heaps
		= (CBottom, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance unsafeSubst (CProp HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	unsafeSubst CTrue heaps
		= (CTrue, heaps)
	unsafeSubst CFalse heaps
		= (CFalse, heaps)
	unsafeSubst (CPropVar ptr) heaps
		#! (def, heaps)					= readPointer ptr heaps
		# (change, prop)				= is_subst def.pvarInfo
		| change						= (prop, heaps)
		= (CPropVar ptr, heaps)
		where
			is_subst :: !CPropVarInfo -> (!Bool, !CPropH)
			is_subst (PVar_Subst prop)	= (True, prop)
			is_subst other				= (False, DummyValue)
	unsafeSubst (CNot p) heaps
		#! (p, heaps)					= unsafeSubst p heaps
		= (CNot p, heaps)
	unsafeSubst (CAnd p q) heaps
		#! (p, heaps)					= unsafeSubst p heaps
		#! (q, heaps)					= unsafeSubst q heaps
		= (CAnd p q, heaps)
	unsafeSubst (COr p q) heaps
		#! (p, heaps)					= unsafeSubst p heaps
		#! (q, heaps)					= unsafeSubst q heaps
		= (COr p q, heaps)
	unsafeSubst (CImplies p q) heaps
		#! (p, heaps)					= unsafeSubst p heaps
		#! (q, heaps)					= unsafeSubst q heaps
		= (CImplies p q, heaps)
	unsafeSubst (CIff p q) heaps
		#! (p, heaps)					= unsafeSubst p heaps
		#! (q, heaps)					= unsafeSubst q heaps
		= (CIff p q, heaps)
	unsafeSubst (CExprForall ptr p) heaps
		# (ptr, heaps)					= substPointer ptr heaps
		#! (p, heaps)					= unsafeSubst p heaps
		= (CExprForall ptr p, heaps)
	unsafeSubst (CExprExists ptr p) heaps
		# (ptr, heaps)					= substPointer ptr heaps
		#! (p, heaps)					= unsafeSubst p heaps
		= (CExprExists ptr p, heaps)
	unsafeSubst (CPropForall ptr p) heaps
		# (ptr, heaps)					= substPointer ptr heaps
		#! (p, heaps)					= unsafeSubst p heaps
		= (CPropForall ptr p, heaps)
	unsafeSubst (CPropExists ptr p) heaps
		# (ptr, heaps)					= substPointer ptr heaps
		#! (p, heaps)					= unsafeSubst p heaps
		= (CPropExists ptr p, heaps)
	unsafeSubst (CEqual e1 e2) heaps
		#! (e1, heaps)					= unsafeSubst e1 heaps
		#! (e2, heaps)					= unsafeSubst e2 heaps
		= (CEqual e1 e2, heaps)
	unsafeSubst (CPredicate ptr exprs) heaps
		#! (exprs, heaps)				= unsafeSubst exprs heaps
		= (CPredicate ptr exprs, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance unsafeSubst (CType HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	unsafeSubst (CTypeVar ptr) heaps
		#! (def, heaps)					= readPointer ptr heaps
		# (change, type)				= is_subst def.tvarInfo
		| change						= (type, heaps)
		= (CTypeVar ptr, heaps)
		where
			is_subst :: !CTypeVarInfo -> (!Bool, !CTypeH)
			is_subst (TVar_Subst type)	= (True, type)
			is_subst other				= (False, DummyValue)
	unsafeSubst (type1 ==> type2) heaps
		#! (type1, heaps)				= unsafeSubst type1 heaps
		#! (type2, heaps)				= unsafeSubst type2 heaps
		= (type1 ==> type2, heaps)
	unsafeSubst ((CTypeVar ptr) @^ types) heaps
		#! (types, heaps)				= unsafeSubst types heaps
		#! (def, heaps)					= readPointer ptr heaps
		= (change ptr def.tvarInfo types, heaps)
		where
			change :: !CTypeVarPtr !CTypeVarInfo ![CTypeH] -> CTypeH
			change ptr1 (TVar_Subst (ptr2 @^ args)) types	= ptr2 @^ (args ++ types)
			change ptr1 (TVar_Subst (type @@^ args)) types	= type @@^ (args ++ types)
			change ptr1 (TVar_Subst other)			types	= other @^ types
			change ptr1 other						types	= (CTypeVar ptr1) @^ types
	unsafeSubst (type @^ types) heaps
		#! (type, heaps)				= unsafeSubst type heaps
		#! (types, heaps)				= unsafeSubst types heaps
		= (type @^ types, heaps)
	unsafeSubst (ptr @@^ types) heaps
		#! (types, heaps)				= unsafeSubst types heaps
		= (ptr @@^ types, heaps)
	unsafeSubst (CBasicType type) heaps
		= (CBasicType type, heaps)
	unsafeSubst (CStrict type) heaps
		#! (type, heaps)				= unsafeSubst type heaps
		= (CStrict type, heaps)
	unsafeSubst CUnTypable heaps
		= (CUnTypable, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance unsafeSubst Hypothesis
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	unsafeSubst hypothesis heaps
		#! (prop, heaps)				= unsafeSubst hypothesis.hypProp heaps
		= ({hypothesis & hypProp = prop}, heaps)




















// =================================================================================================================================================
// Records substutition in heap; use Match to get this substitution afterwards.
// (*) Does left-to-right unification.
// (*) Gets a list of 'free' variables that may be bound.
// (*) Also does alpha-conversion; binds bound variables of the lhs to bound variables of the rhs.
// -------------------------------------------------------------------------------------------------------------------------------------------------
class match a :: !MatchPassed !a !a !*CHeaps -> (!Bool, !MatchPassed, !*CHeaps)
// -------------------------------------------------------------------------------------------------------------------------------------------------

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: MatchPassed =
// -------------------------------------------------------------------------------------------------------------------------------------------------
	{ mpExprVars				:: ![CExprVarPtr]			// bind FORALL to free occurence
	, mpPropVars				:: ![CPropVarPtr]			// bind FORALL to free occurence
	, mpAlphaExprVars			:: ![CExprVarPtr]			// bind FORALL to bound occurence
	, mpAlphaPropVars			:: ![CPropVarPtr]			// bind FORALL to bound occurence
	, mpAdditionalArguments		:: ![CExprH]				// used to rewrite (reverse2 = reverse) in (reverse2 x = reverse x)
	}

// -------------------------------------------------------------------------------------------------------------------------------------------------
markExprScope :: !MatchPassed ![CExprVarPtr] ![CExprVarPtr] !*CHeaps -> (!Bool, !MatchPassed, !*CHeaps)
// -------------------------------------------------------------------------------------------------------------------------------------------------
markExprScope passed [ptr1:ptrs1] [ptr2:ptrs2] heaps
	# (var1, heaps)						= readPointer ptr1 heaps
	# var1								= {var1 & evarInfo = EVar_Subst (CExprVar ptr2)}
	# heaps								= writePointer ptr1 var1 heaps
	# passed							= {passed & mpAlphaExprVars = [ptr1:passed.mpAlphaExprVars]}
	= markExprScope passed ptrs1 ptrs2 heaps
markExprScope passed [] [] heaps
	= (True, passed, heaps)
markExprScope passed _ _ heaps
	= (False, passed, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
markPropScope :: !MatchPassed ![CPropVarPtr] ![CPropVarPtr] !*CHeaps -> (!Bool, !MatchPassed, !*CHeaps)
// -------------------------------------------------------------------------------------------------------------------------------------------------
markPropScope passed [ptr1:ptrs1] [ptr2:ptrs2] heaps
	# (var1, heaps)						= readPointer ptr1 heaps
	# var1								= {var1 & pvarInfo = PVar_Subst (CPropVar ptr2)}
	# heaps								= writePointer ptr1 var1 heaps
	# passed							= {passed & mpAlphaPropVars = [ptr1:passed.mpAlphaPropVars]}
	= markPropScope passed ptrs1 ptrs2 heaps
markPropScope passed [] [] heaps
	= (True, passed, heaps)
markPropScope passed _ _ heaps
	= (False, passed, heaps)

// Used for rewriting of partial applications.
// -------------------------------------------------------------------------------------------------------------------------------------------------
matchExprs :: !MatchPassed ![CExprH] ![CExprH] !*CHeaps -> (!Bool, !MatchPassed, !*CHeaps)
// -------------------------------------------------------------------------------------------------------------------------------------------------
matchExprs passed [x:xs] [y:ys] heaps
	# (ok, passed, heaps)				= match passed x y heaps
	| not ok							= (False, passed, heaps)
	= matchExprs passed xs ys heaps
matchExprs passed [] additional heaps
	# passed							= {passed & mpAdditionalArguments = additional}
	= (True, passed, heaps)
matchExprs passed _ _ heaps
	= (False, passed, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance match [a] | match a
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	match passed [x:xs] [y:ys] heaps
		# (ok, passed, heaps)			= match passed x y heaps
		| not ok						= (False, passed, heaps)
		= match passed xs ys heaps
	match passed [] [] heaps
//		# passed						= {passed & mpAdditionalArguments = additional}
		= (True, passed, heaps)
	match passed _ _ heaps
		= (False, passed, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance match (Maybe a) | match a
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	match passed (Just x) (Just y) heaps
		= match passed x y heaps
	match passed Nothing Nothing heaps
		= (True, passed, heaps)
	match passed _ _ heaps
		= (False, passed, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance match (CAlgPattern HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	match passed pattern1 pattern2 heaps
		# cons1							= pattern1.atpDataCons
		# cons2							= pattern2.atpDataCons
		| cons1 <> cons2				= (False, passed, heaps)
		# (ok, passed, heaps)			= markExprScope passed pattern1.atpExprVarScope pattern2.atpExprVarScope heaps
		| not ok						= (False, passed, heaps)
		= match passed pattern1.atpResult pattern2.atpResult heaps

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance match (CBasicPattern HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	match passed pattern1 pattern2 heaps
		# value1						= pattern1.bapBasicValue
		# value2						= pattern2.bapBasicValue
		| value1 <> value2				= (False, passed, heaps)
		= match passed pattern1.bapResult pattern2.bapResult heaps

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance match (CBasicValue HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	match passed (CBasicArray es1) (CBasicArray es2) heaps
		= match passed es1 es2 heaps
	match passed value1 value2 heaps
		= (value1 == value2, passed, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance match (CCasePatterns HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	match passed (CAlgPatterns ptr1 patterns1) (CAlgPatterns ptr2 patterns2) heaps
		| ptr1 <> ptr2					= (False, passed, heaps)
		= match passed patterns1 patterns2 heaps
	match passed (CBasicPatterns ptr1 patterns1) (CBasicPatterns ptr2 patterns2) heaps
		| ptr1 <> ptr2					= (False, passed, heaps)
		= match passed patterns1 patterns2 heaps
	match passed _ _ heaps
		= (False, passed, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance match (CExpr HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	match passed (CExprVar ptr1) expr2 heaps
		| isMember ptr1 passed.mpExprVars || isMember ptr1 passed.mpAlphaExprVars
			# (var, heaps)				= readPointer ptr1 heaps
			# (seen_before, expr)		= is_expr var.evarInfo
			| seen_before				= (expr == expr2, passed, heaps)
			# var						= {var & evarInfo = EVar_Subst expr2}
			= (True, passed, writePointer ptr1 var heaps)
		= (expr2 == CExprVar ptr1, passed, heaps)
		where
			is_expr :: !CExprVarInfo -> (!Bool, !CExprH)
			is_expr (EVar_Subst e)		= (True, e)
			is_expr _					= (False, DummyValue)
	match passed (CShared ptr) expr heaps
		# (shared, heaps)				= readPointer ptr heaps
		= match passed shared.shExpr expr heaps
	match passed expr (CShared ptr) heaps
		# (shared, heaps)				= readPointer ptr heaps
		= match passed expr shared.shExpr heaps
	match passed ((ptr @@# exprs1) @# exprs2) expr heaps
		= match passed (ptr @@# (exprs1 ++ exprs2)) expr heaps
	match passed ((expr1 @# exprs1) @# exprs2) expr2 heaps
		= match passed (expr1 @# (exprs1 ++ exprs2)) expr2 heaps
	match passed expr ((ptr @@# exprs1) @# exprs2) heaps
		= match passed expr (ptr @@# (exprs1 ++ exprs2)) heaps
	match passed expr1 ((expr2 @# exprs1) @# exprs2) heaps
		= match passed expr1 (expr2 @# (exprs1 ++ exprs2)) heaps
	match passed (expr1 @# exprs1) (expr2 @# exprs2) heaps
		# (ok, passed, heaps)			= match passed expr1 expr2 heaps
		| not ok						= (False, passed, heaps)
		= matchExprs passed exprs1 exprs2 heaps
	match passed (ptr1 @@# exprs1) (ptr2 @@# exprs2) heaps
		| ptr1 <> ptr2					= (False, passed, heaps)
		= matchExprs passed exprs1 exprs2 heaps
	match passed (CLet strict1 lets1 expr1) (CLet strict2 lets2 expr2) heaps
		| strict1 <> strict2			= (False, passed, heaps)
		# (vars1, exprs1)				= unzip lets1
		# (vars2, exprs2)				= unzip lets2
		# (ok, passed, heaps)			= markExprScope passed vars1 vars2 heaps
		| not ok						= (False, passed, heaps)
		# (ok, passed, heaps)			= match passed exprs1 exprs2 heaps
		| not ok						= (False, passed, heaps)
		= match passed expr1 expr2 heaps
	match passed (CCase expr1 patterns1 def1) (CCase expr2 patterns2 def2) heaps
		# (ok, passed, heaps)			= match passed expr1 expr2 heaps
		| not ok						= (False, passed, heaps)
		# (ok, passed, heaps)			= match passed patterns1 patterns2 heaps
		| not ok						= (False, passed, heaps)
		= match passed def1 def2 heaps
	match passed (CBasicValue value1) (CBasicValue value2) heaps
		= match passed value1 value2 heaps
	match passed CBottom CBottom heaps
		= (True, passed, heaps)
	match passed _ _ heaps
		= (False, passed, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance match (CProp HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	match passed CTrue CTrue heaps
		= (True, passed, heaps)
	match passed CFalse CFalse heaps
		= (True, passed, heaps)
	match passed (CPropVar ptr1) prop2 heaps
		| isMember ptr1 passed.mpPropVars || isMember ptr1 passed.mpAlphaPropVars
			# (var, heaps)				= readPointer ptr1 heaps
			# (seen_before, prop)		= is_prop var.pvarInfo
			| seen_before				= (prop == prop2, passed, heaps)
			# var						= {var & pvarInfo = PVar_Subst prop2}
			= (True, passed, writePointer ptr1 var heaps)
		= (prop2 == CPropVar ptr1, passed, heaps)
		where
			is_prop :: !CPropVarInfo -> (!Bool, !CPropH)
			is_prop (PVar_Subst p)		= (True, p)
			is_prop _					= (False, DummyValue)
	match passed (CEqual e1 e2) (CEqual e3 e4) heaps
		# (ok, passed, heaps)			= match passed e1 e3 heaps
		| not ok						= (False, passed, heaps)
		= match passed e2 e4 heaps
	match passed (CNot p1) (CNot p2) heaps
		= match passed p1 p2 heaps
	match passed (CAnd p1 q1) (CAnd p2 q2) heaps
		# (ok, passed, heaps)			= match passed p1 p2 heaps
		| not ok						= (False, passed, heaps)
		= match passed q1 q2 heaps
	match passed (COr p1 q1) (COr p2 q2) heaps
		# (ok, passed, heaps)			= match passed p1 p2 heaps
		| not ok						= (False, passed, heaps)
		= match passed q1 q2 heaps
	match passed (CImplies p1 q1) (CImplies p2 q2) heaps
		# (ok, passed, heaps)			= match passed p1 p2 heaps
		| not ok						= (False, passed, heaps)
		= match passed q1 q2 heaps
	match passed (CIff p1 q1) (CIff p2 q2) heaps
		# (ok, passed, heaps)			= match passed p1 p2 heaps
		| not ok						= (False, passed, heaps)
		= match passed q1 q2 heaps
	match passed (CExprForall var1 p1) (CExprForall var2 p2) heaps
		# (ok, passed, heaps)			= markExprScope passed [var1] [var2] heaps
		| not ok						= (False, passed, heaps)
		= match passed p1 p2 heaps
	match passed (CExprExists var1 p1) (CExprExists var2 p2) heaps
		# (ok, passed, heaps)			= markExprScope passed [var1] [var2] heaps
		| not ok						= (False, passed, heaps)
		= match passed p1 p2 heaps
	match passed (CPropForall var1 p1) (CPropForall var2 p2) heaps
		# (ok, passed, heaps)			= markPropScope passed [var1] [var2] heaps
		| not ok						= (False, passed, heaps)
		= match passed p1 p2 heaps
	match passed (CPredicate ptr1 exprs1) (CPredicate ptr2 exprs2) heaps
		| ptr1 <> ptr2					= (False, passed, heaps)
		= match passed exprs1 exprs2 heaps
	match passed _ _ heaps
		= (False, passed, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
Match :: ![CExprVarPtr] ![CPropVarPtr] !a !a !*CHeaps -> (!Bool, !Substitution, ![CExprH], ![CExprVarPtr], ![CPropVarPtr], !*CHeaps) | match a
// -------------------------------------------------------------------------------------------------------------------------------------------------
Match exprvars propvars x y heaps
	# passed							=	{ mpExprVars			= exprvars
											, mpPropVars			= propvars
											, mpAlphaExprVars		= []
											, mpAlphaPropVars		= []
											, mpAdditionalArguments	= []
											}
	# (ok, passed, heaps)				= match passed x y heaps
	# (sub_e, unpassed_e, heaps)		= build_e_subst passed.mpExprVars heaps
	# (sub_p, unpassed_p, heaps)		= build_p_subst passed.mpPropVars heaps
	# heaps								= wipePointerInfos passed.mpAlphaExprVars heaps
	# heaps								= wipePointerInfos passed.mpAlphaPropVars heaps
	| not ok							= (False, DummyValue, DummyValue, DummyValue, DummyValue, heaps)
	= (True, {DummyValue & subExprVars = sub_e, subPropVars = sub_p}, passed.mpAdditionalArguments, unpassed_e, unpassed_p, heaps)
	where
		build_e_subst :: ![CExprVarPtr] !*CHeaps -> (![(CExprVarPtr, CExprH)], ![CExprVarPtr], !*CHeaps)
		build_e_subst [ptr:ptrs] heaps
			# (var, heaps)				= readPointer ptr heaps
			# (ok, expr)				= get_expr var.evarInfo
			# var						= {var & evarInfo = EVar_Nothing}
			# heaps						= writePointer ptr var heaps
			# (sub_e, unpassed_e, heaps)= build_e_subst ptrs heaps
			| ok
				= ([(ptr,expr):sub_e], unpassed_e, heaps)
				= (sub_e, [ptr:unpassed_e], heaps)
			where
				get_expr :: !CExprVarInfo -> (!Bool, !CExprH)
				get_expr (EVar_Subst e)	= (True, e)
				get_expr _				= (False, DummyValue)
		build_e_subst [] heaps
			= ([], [], heaps)
		
		build_p_subst :: ![CPropVarPtr] !*CHeaps -> (![(CPropVarPtr, CPropH)], ![CPropVarPtr], !*CHeaps)
		build_p_subst [ptr:ptrs] heaps
			# (var, heaps)				= readPointer ptr heaps
			# (ok, prop)				= get_prop var.pvarInfo
			# var						= {var & pvarInfo = PVar_Nothing}
			# heaps						= writePointer ptr var heaps
			# (sub_p, unpassed_p, heaps)= build_p_subst ptrs heaps
			| ok
				= ([(ptr,prop):sub_p], unpassed_p, heaps)
				= (sub_p, [ptr:unpassed_p], heaps)
			where
				get_prop :: !CPropVarInfo -> (!Bool, !CPropH)
				get_prop (PVar_Subst p)	= (True, p)
				get_prop _				= (False, DummyValue)
		build_p_subst [] heaps
			= ([], [], heaps)




















// -------------------------------------------------------------------------------------------------------------------------------------------------   
foundRedex :: !RewriteState -> (!Bool, !RewriteState)
// -------------------------------------------------------------------------------------------------------------------------------------------------   
foundRedex rstate
	| rstate.rsAll						= (True, {rstate & rsChanged = True})
	| rstate.rsOne == 1					= (True, {rstate & rsChanged = True, rsOne = 0})
	= (False, {rstate & rsOne = rstate.rsOne - 1})

// -------------------------------------------------------------------------------------------------------------------------------------------------
class rewriteProp a :: !a !CPropH !CPropH !RewriteState !*CHeaps -> (!a, !RewriteState, !*CHeaps)
// -------------------------------------------------------------------------------------------------------------------------------------------------

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance rewriteProp (CProp HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	rewriteProp p lhs rhs rstate heaps
		# (ok, sub, _, evars, pvars, heaps)
										= Match rstate.rsExprVars rstate.rsPropVars lhs p heaps
		| not (isEmpty evars) || not (isEmpty pvars)
			= (p, rstate, heaps)
		| ok
			# (rewrite_now, rstate)		= foundRedex rstate
			| not rewrite_now			= rewrite p lhs rhs rstate heaps
			# (result, heaps)			= SafeSubst sub rhs heaps
			# rstate					= {rstate & rsSubs = [sub:rstate.rsSubs]}
			= (result, rstate, heaps)
		| not ok
			= rewrite p lhs rhs rstate heaps
	where
		rewrite :: !CPropH !CPropH !CPropH !RewriteState !*CHeaps -> (!CPropH, !RewriteState, !*CHeaps)
		rewrite CTrue lhs rhs rstate heaps
			= (CTrue, rstate, heaps)
		rewrite CFalse lhs rhs rstate heaps
			= (CFalse, rstate, heaps)
		rewrite (CPropVar var) lhs rhs rstate heaps
			= (CPropVar var, rstate, heaps)
		rewrite (CEqual e1 e2) lhs rhs rstate heaps
			= (CEqual e1 e2, rstate, heaps)
		rewrite (CNot p) lhs rhs rstate heaps
			# (p, rstate, heaps)		= rewriteProp p lhs rhs rstate heaps
			= (CNot p, rstate, heaps)
		rewrite (CAnd p q) lhs rhs rstate heaps
			# (p, rstate, heaps)		= rewriteProp p lhs rhs rstate heaps
			# (q, rstate, heaps)		= rewriteProp q lhs rhs rstate heaps
			= (CAnd p q, rstate, heaps)
		rewrite (COr p q) lhs rhs rstate heaps
			# (p, rstate, heaps)		= rewriteProp p lhs rhs rstate heaps
			# (q, rstate, heaps)		= rewriteProp q lhs rhs rstate heaps
			= (COr p q, rstate, heaps)
		rewrite (CImplies p q) lhs rhs rstate heaps
			# (p, rstate, heaps)		= rewriteProp p lhs rhs rstate heaps
			# (q, rstate, heaps)		= rewriteProp q lhs rhs rstate heaps
			= (CImplies p q, rstate, heaps)
		rewrite (CIff p q) lhs rhs rstate heaps
			# (p, rstate, heaps)		= rewriteProp p lhs rhs rstate heaps
			# (q, rstate, heaps)		= rewriteProp q lhs rhs rstate heaps
			= (CIff p q, rstate, heaps)
		rewrite (CExprForall var p) lhs rhs rstate heaps
			# (p, rstate, heaps)		= rewriteProp p lhs rhs rstate heaps
			= (CExprForall var p, rstate, heaps)
		rewrite (CExprExists var p) lhs rhs rstate heaps
			# (p, rstate, heaps)		= rewriteProp p lhs rhs rstate heaps
			= (CExprExists var p, rstate, heaps)
		rewrite (CPropForall var p) lhs rhs rstate heaps
			# (p, rstate, heaps)		= rewriteProp p lhs rhs rstate heaps
			= (CPropForall var p, rstate, heaps)
		rewrite (CPropExists var p) lhs rhs rstate heaps
			# (p, rstate, heaps)		= rewriteProp p lhs rhs rstate heaps
			= (CPropExists var p, rstate, heaps)
		rewrite (CPredicate ptr exprs) lhs rhs rstate heaps
			= (CPredicate ptr exprs, rstate, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
RewriteProp :: !a !Redex ![CExprVarPtr] ![CPropVarPtr] !CPropH !CPropH !*CHeaps -> (!Bool, ![Substitution], !a, !*CHeaps) | rewriteProp a
// -------------------------------------------------------------------------------------------------------------------------------------------------
RewriteProp x redex evars pvars lhs rhs heaps
	# (all, num)						= check_redex redex
	# rstate							=	{ rsChanged			= False
											, rsOne				= num
											, rsAll				= all
											, rsExprVars		= evars
											, rsPropVars		= pvars
											, rsSubs			= []
											}
	# (x, rstate, heaps)				= rewriteProp x lhs rhs rstate heaps
	= (rstate.rsChanged, rstate.rsSubs, x, heaps)
	where
		check_redex :: !Redex -> (!Bool, !Int)
		check_redex AllRedexes			= (True, 0)
		check_redex (OneRedex num)		= (False, num)






















// -------------------------------------------------------------------------------------------------------------------------------------------------
class rewriteExpr a :: !a !CExprH !CExprH !RewriteState !*CHeaps -> (!a, !RewriteState, !*CHeaps)
// -------------------------------------------------------------------------------------------------------------------------------------------------

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance rewriteExpr [a] | rewriteExpr a
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	rewriteExpr [x:xs] lhs rhs rstate heaps
		# (x, rstate, heaps)		= rewriteExpr x lhs rhs rstate heaps
		# (xs, rstate, heaps)		= rewriteExpr xs lhs rhs rstate heaps
		= ([x:xs], rstate, heaps)
	rewriteExpr [] lhs rhs rstate heaps
		= ([], rstate, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance rewriteExpr (Maybe a) | rewriteExpr a
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	rewriteExpr (Just x) lhs rhs rstate heaps
		# (x, rstate, heaps)		= rewriteExpr x lhs rhs rstate heaps
		= (Just x, rstate, heaps)
	rewriteExpr Nothing lhs rhs rstate heaps
		= (Nothing, rstate, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance rewriteExpr (CAlgPattern HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	rewriteExpr pattern lhs rhs rstate heaps
		# (expr, rstate, heaps)		= rewriteExpr pattern.atpResult lhs rhs rstate heaps
		= ({pattern & atpResult = expr}, rstate, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance rewriteExpr (CBasicPattern HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	rewriteExpr pattern lhs rhs rstate heaps
		# (expr, rstate, heaps)		= rewriteExpr pattern.bapResult lhs rhs rstate heaps
		= ({pattern & bapResult = expr}, rstate, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance rewriteExpr (CBasicValue HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	rewriteExpr (CBasicArray exprs) lhs rhs rstate heaps
		# (exprs, rstate, heaps)	= rewriteExpr exprs lhs rhs rstate heaps
		= (CBasicArray exprs, rstate, heaps)
	rewriteExpr other lhs rhs rstate heaps
		= (other, rstate, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance rewriteExpr (CCasePatterns HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	rewriteExpr (CAlgPatterns ptr patterns) lhs rhs rstate heaps
		# (patterns, rstate, heaps)	= rewriteExpr patterns lhs rhs rstate heaps
		= (CAlgPatterns ptr patterns, rstate, heaps)
	rewriteExpr (CBasicPatterns ptr patterns) lhs rhs rstate heaps
		# (patterns, rstate, heaps)	= rewriteExpr patterns lhs rhs rstate heaps
		= (CBasicPatterns ptr patterns, rstate, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance rewriteExpr (CExpr HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	rewriteExpr expr lhs rhs rstate heaps
		# (ok, sub, additional, evars, pvars, heaps)
										= Match rstate.rsExprVars rstate.rsPropVars lhs expr heaps
		| not (isEmpty evars) || not (isEmpty pvars)
			= (expr, rstate, heaps)
		| ok
			# (rewrite_now, rstate)		= foundRedex rstate
			| not rewrite_now			= rewrite expr lhs rhs rstate heaps
			# (result, heaps)			= SafeSubst sub rhs heaps
			# rstate					= {rstate & rsSubs = [sub:rstate.rsSubs]}
			# result					= combine result additional
			= (result, rstate, heaps)
//		| not ok
			= rewrite expr lhs rhs rstate heaps
	where
		combine :: !CExprH ![CExprH] -> CExprH
		combine expr []							= expr
		combine (ptr @@# exprs1) exprs2			= ptr @@# (exprs1 ++ exprs2)
		combine (expr @# exprs1) exprs2			= expr @# (exprs1 ++ exprs2)
		combine expr exprs						= expr @# exprs
		
		rewrite :: !CExprH !CExprH !CExprH !RewriteState !*CHeaps -> (!CExprH, !RewriteState, !*CHeaps)
		rewrite (CExprVar ptr) lhs rhs rstate heaps
			= (CExprVar ptr, rstate, heaps)
		rewrite (expr @# exprs) lhs rhs rstate heaps
			# (expr, rstate, heaps)		= rewriteExpr expr lhs rhs rstate heaps
			# (exprs, rstate, heaps)	= rewriteExpr exprs lhs rhs rstate heaps
			= (expr @# exprs, rstate, heaps)
		rewrite (ptr @@# exprs) lhs rhs rstate heaps
			# (exprs, rstate, heaps)	= rewriteExpr exprs lhs rhs rstate heaps
			= (ptr @@# exprs, rstate, heaps)
		rewrite (CLet strict lets expr) lhs rhs rstate heaps
			# (vars, exprs)				= unzip lets
			# (exprs, rstate, heaps)	= rewriteExpr exprs lhs rhs rstate heaps
			# lets						= zip2 vars exprs
			# (expr, rstate, heaps)		= rewriteExpr expr lhs rhs rstate heaps
			= (CLet strict lets expr, rstate, heaps)
		rewrite (CCase expr patterns def) lhs rhs rstate heaps
			# (expr, rstate, heaps)		= rewriteExpr expr lhs rhs rstate heaps
			# (patterns, rstate, heaps)	= rewriteExpr patterns lhs rhs rstate heaps
			# (def, rstate, heaps)		= rewriteExpr def lhs rhs rstate heaps
			= (CCase expr patterns def, rstate, heaps)
		rewrite (CBasicValue value) lhs rhs rstate heaps
			# (value, rstate, heaps)	= rewriteExpr value lhs rhs rstate heaps
			= (CBasicValue value, rstate, heaps)
		rewrite (CCode codetype codecontents) lhs rhs rstate heaps
			= (CCode codetype codecontents, rstate, heaps)
		rewrite CBottom lhs rhs rstate heaps
			= (CBottom, rstate, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance rewriteExpr (CProp HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	rewriteExpr CTrue lhs rhs rstate heaps
		= (CTrue, rstate, heaps)
	rewriteExpr CFalse lhs rhs rstate heaps
		= (CFalse, rstate, heaps)
	rewriteExpr (CPropVar var) lhs rhs rstate heaps
		= (CPropVar var, rstate, heaps)
	rewriteExpr (CEqual e1 e2) lhs rhs rstate heaps
		# (e1, rstate, heaps)		= rewriteExpr e1 lhs rhs rstate heaps
		# (e2, rstate, heaps)		= rewriteExpr e2 lhs rhs rstate heaps
		= (CEqual e1 e2, rstate, heaps)
	rewriteExpr (CNot p) lhs rhs rstate heaps
		# (p, rstate, heaps)		= rewriteExpr p lhs rhs rstate heaps
		= (CNot p, rstate, heaps)
	rewriteExpr (CAnd p q) lhs rhs rstate heaps
		# (p, rstate, heaps)		= rewriteExpr p lhs rhs rstate heaps
		# (q, rstate, heaps)		= rewriteExpr q lhs rhs rstate heaps
		= (CAnd p q, rstate, heaps)
	rewriteExpr (COr p q) lhs rhs rstate heaps
		# (p, rstate, heaps)		= rewriteExpr p lhs rhs rstate heaps
		# (q, rstate, heaps)		= rewriteExpr q lhs rhs rstate heaps
		= (COr p q, rstate, heaps)
	rewriteExpr (CImplies p q) lhs rhs rstate heaps
		# (p, rstate, heaps)		= rewriteExpr p lhs rhs rstate heaps
		# (q, rstate, heaps)		= rewriteExpr q lhs rhs rstate heaps
		= (CImplies p q, rstate, heaps)
	rewriteExpr (CIff p q) lhs rhs rstate heaps
		# (p, rstate, heaps)		= rewriteExpr p lhs rhs rstate heaps
		# (q, rstate, heaps)		= rewriteExpr q lhs rhs rstate heaps
		= (CIff p q, rstate, heaps)
	rewriteExpr (CExprForall var p) lhs rhs rstate heaps
		# (p, rstate, heaps)		= rewriteExpr p lhs rhs rstate heaps
		= (CExprForall var p, rstate, heaps)
	rewriteExpr (CExprExists var p) lhs rhs rstate heaps
		# (p, rstate, heaps)		= rewriteExpr p lhs rhs rstate heaps
		= (CExprExists var p, rstate, heaps)
	rewriteExpr (CPropForall var p) lhs rhs rstate heaps
		# (p, rstate, heaps)		= rewriteExpr p lhs rhs rstate heaps
		= (CPropForall var p, rstate, heaps)
	rewriteExpr (CPropExists var p) lhs rhs rstate heaps
		# (p, rstate, heaps)		= rewriteExpr p lhs rhs rstate heaps
		= (CPropExists var p, rstate, heaps)
	rewriteExpr (CPredicate ptr exprs) lhs rhs rstate heaps
		= (CPredicate ptr exprs, rstate, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
RewriteExpr :: !a !Redex ![CExprVarPtr] ![CPropVarPtr] !CExprH !CExprH !*CHeaps -> (!Bool, ![Substitution], !a, !*CHeaps) | rewriteExpr a
// -------------------------------------------------------------------------------------------------------------------------------------------------
RewriteExpr x redex evars pvars lhs rhs heaps
	# (all, num)						= check_redex redex
	# rstate							=	{ rsChanged			= False
											, rsOne				= num
											, rsAll				= all
											, rsExprVars		= evars
											, rsPropVars		= pvars
											, rsSubs			= []
											}
	# (x, rstate, heaps)				= rewriteExpr x lhs rhs rstate heaps
	= (rstate.rsChanged, rstate.rsSubs, x, heaps)
	where
		check_redex :: !Redex -> (!Bool, !Int)
		check_redex AllRedexes				= (True, 0)
		check_redex (OneRedex num)			= (False, num)






















// -------------------------------------------------------------------------------------------------------------------------------------------------
class replaceExpr a :: !a !CExprH !CExprH !*CHeaps -> (!Bool, !a, !*CHeaps)
// -------------------------------------------------------------------------------------------------------------------------------------------------

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance replaceExpr [a] | replaceExpr a
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	replaceExpr [x:xs] e1 e2 heaps
		# (ok1, x, heaps)					= replaceExpr x e1 e2 heaps
		# (ok2, xs, heaps)					= replaceExpr xs e1 e2 heaps
		= (ok1 || ok2, [x:xs], heaps)
	replaceExpr [] e1 e2 heaps
		= (False, [], heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance replaceExpr (Maybe a) | replaceExpr a
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	replaceExpr (Just x) e1 e2 heaps
		# (ok, x, heaps)					= replaceExpr x e1 e2 heaps
		= (ok, Just x, heaps)
	replaceExpr Nothing e1 e2 heaps
		= (False, Nothing, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance replaceExpr (Ptr a) | Pointer, replaceExpr a
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	replaceExpr ptr e1 e2 heaps
		# (x, heaps)						= readPointer ptr heaps
		# (ok, x, heaps)					= replaceExpr x e1 e2 heaps
		# (new_ptr, heaps)					= newPointer x heaps
		= (ok, new_ptr, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance replaceExpr (CAlgPattern HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	replaceExpr pattern e1 e2 heaps
		# (ok, result, heaps)				= replaceExpr pattern.atpResult e1 e2 heaps
		= (ok, {pattern & atpResult = result}, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance replaceExpr (CBasicPattern HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	replaceExpr pattern e1 e2 heaps
		# (ok, result, heaps)				= replaceExpr pattern.bapResult e1 e2 heaps
		= (ok, {pattern & bapResult = result}, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance replaceExpr (CBasicValue HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	replaceExpr (CBasicArray list) e1 e2 heaps
		# (ok, list, heaps)					= replaceExpr list e1 e2 heaps
		= (ok, CBasicArray list, heaps)
	replaceExpr other e1 e2 heaps
		= (False, other, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance replaceExpr (CCasePatterns HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	replaceExpr (CAlgPatterns ptr patterns) e1 e2 heaps
		# (ok, patterns, heaps)				= replaceExpr patterns e1 e2 heaps
		= (ok, CAlgPatterns ptr patterns, heaps)
	replaceExpr (CBasicPatterns ptr patterns) e1 e2 heaps
		# (ok, patterns, heaps)				= replaceExpr patterns e1 e2 heaps
		= (ok, CBasicPatterns ptr patterns, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance replaceExpr (CExpr HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	replaceExpr expr e1 e2 heaps
		# (ok, heaps)						= AlphaEqual expr e1 heaps
		| ok								= (True, e2, heaps)
		= replace expr e1 e2 heaps
		where
			replace :: !CExprH !CExprH !CExprH !*CHeaps -> (!Bool, !CExprH, !*CHeaps)
			replace (CExprVar ptr) e1 e2 heaps
				= (False, CExprVar ptr, heaps)
			replace (CShared ptr) e1 e2 heaps
				# (shared, heaps)			= readPointer ptr heaps
				= replace shared.shExpr e1 e2 heaps
			replace (expr @# exprs) e1 e2 heaps
				# (ok1, expr, heaps)		= replaceExpr expr e1 e2 heaps
				# (ok2, exprs, heaps)		= replaceExpr exprs e1 e2 heaps
				= (ok1 || ok2, expr @# exprs, heaps)
			replace (ptr @@# exprs) e1 e2 heaps
				# (ok, exprs, heaps)		= replaceExpr exprs e1 e2 heaps
				= (ok, ptr @@# exprs, heaps)
			replace (CLet strict lets expr) e1 e2 heaps
				# (vars, exprs)				= unzip lets
				# (ok1, exprs, heaps)		= replaceExpr exprs e1 e2 heaps
				# lets						= zip2 vars exprs
				# (ok2, expr, heaps)		= replaceExpr expr e1 e2 heaps
				= (ok1 || ok2, CLet strict lets expr, heaps)
			replace (CCase expr patterns def) e1 e2 heaps
				# (ok1, expr, heaps)		= replaceExpr expr e1 e2 heaps
				# (ok2, patterns, heaps)	= replaceExpr patterns e1 e2 heaps
				# (ok3, def, heaps)			= replaceExpr def e1 e2 heaps
				= (ok1 || ok2 || ok3, CCase expr patterns def, heaps)
			replace (CBasicValue value) e1 e2 heaps
				# (ok, value, heaps)		= replaceExpr value e1 e2 heaps
				= (ok, CBasicValue value, heaps)
			replace (CCode codetype codecontents) e1 e2 heaps
				= (False, CCode codetype codecontents, heaps)
			replace CBottom e1 e2 heaps
				= (False, CBottom, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance replaceExpr (CProp HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	replaceExpr (CPropVar ptr) e1 e2 heaps
		= (False, CPropVar ptr, heaps)
	replaceExpr CTrue e1 e2 heaps
		= (False, CTrue, heaps)
	replaceExpr CFalse e1 e2 heaps
		= (False, CFalse, heaps)
	replaceExpr (CEqual expr1 expr2) e1 e2 heaps
		# (ok1, expr1, heaps)				= replaceExpr expr1 e1 e2 heaps
		# (ok2, expr2, heaps)				= replaceExpr expr2 e1 e2 heaps
		= (ok1 || ok2, CEqual expr1 expr2, heaps)
	replaceExpr (CNot p) e1 e2 heaps
		# (ok, p, heaps)					= replaceExpr p e1 e2 heaps
		= (ok, CNot p, heaps)
	replaceExpr (CAnd p q) e1 e2 heaps
		# (ok1, p, heaps)					= replaceExpr p e1 e2 heaps
		# (ok2, q, heaps)					= replaceExpr q e1 e2 heaps
		= (ok1 || ok2, CAnd p q, heaps)
	replaceExpr (COr p q) e1 e2 heaps
		# (ok1, p, heaps)					= replaceExpr p e1 e2 heaps
		# (ok2, q, heaps)					= replaceExpr q e1 e2 heaps
		= (ok1 || ok2, COr p q, heaps)
	replaceExpr (CImplies p q) e1 e2 heaps
		# (ok1, p, heaps)					= replaceExpr p e1 e2 heaps
		# (ok2, q, heaps)					= replaceExpr q e1 e2 heaps
		= (ok1 || ok2, CImplies p q, heaps)
	replaceExpr (CIff p q) e1 e2 heaps
		# (ok1, p, heaps)					= replaceExpr p e1 e2 heaps
		# (ok2, q, heaps)					= replaceExpr q e1 e2 heaps
		= (ok1 || ok2, CIff p q, heaps)
	replaceExpr (CExprForall ptr p) e1 e2 heaps
		# (ok, p, heaps)					= replaceExpr p e1 e2 heaps
		= (ok, CExprForall ptr p, heaps)
	replaceExpr (CExprExists ptr p) e1 e2 heaps
		# (ok, p, heaps)					= replaceExpr p e1 e2 heaps
		= (ok, CExprExists ptr p, heaps)
	replaceExpr (CPropForall ptr p) e1 e2 heaps
		# (ok, p, heaps)					= replaceExpr p e1 e2 heaps
		= (ok, CPropForall ptr p, heaps)
	replaceExpr (CPropExists ptr p) e1 e2 heaps
		# (ok, p, heaps)					= replaceExpr p e1 e2 heaps
		= (ok, CPropExists ptr p, heaps)
	replaceExpr (CPredicate ptr exprs) e1 e2 heaps
		# (ok, exprs, heaps)				= replaceExpr exprs e1 e2 heaps
		= (ok, CPredicate ptr exprs, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance replaceExpr Goal
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	replaceExpr goal e1 e2 heaps
		# (ok1, hyps, heaps)				= replaceExpr goal.glHypotheses e1 e2 heaps
		# (ok2, toprove, heaps)				= replaceExpr goal.glToProve e1 e2 heaps
		# goal								= {goal & glToProve = toprove, glHypotheses = hyps}
		= (ok1 || ok2, goal, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance replaceExpr Hypothesis
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	replaceExpr hyp e1 e2 heaps
		# (ok, prop, heaps)					= replaceExpr hyp.hypProp e1 e2 heaps
		# hyp								= {hyp & hypProp = prop}
		= (ok, hyp, heaps)


















// -------------------------------------------------------------------------------------------------------------------------------------------------
class replaceProp a :: !a !CPropH !CPropH !*CHeaps -> (!Bool, !a, !*CHeaps)
// -------------------------------------------------------------------------------------------------------------------------------------------------

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance replaceProp (CProp HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	replaceProp prop p1 p2 heaps
		# (ok, heaps)						= AlphaEqual prop p1 heaps
		| ok								= (True, p2, heaps)
		= replace prop p1 p2 heaps
		where
			replace :: !CPropH !CPropH !CPropH !*CHeaps -> (!Bool, !CPropH, !*CHeaps)
			replace (CPropVar ptr) p1 p2 heaps
				= (False, CPropVar ptr, heaps)
			replace CTrue p1 p2 heaps
				= (False, CTrue, heaps)
			replace CFalse p1 p2 heaps
				= (False, CFalse, heaps)
			replace (CEqual e1 e2) p1 p2 heaps
				= (False, CEqual e1 e2, heaps)
			replace (CNot p) p1 p2 heaps
				# (ok, p, heaps)			= replaceProp p p1 p2 heaps
				= (ok, CNot p, heaps)
			replace (CAnd p q) p1 p2 heaps
				# (ok1, p, heaps)			= replaceProp p p1 p2 heaps
				# (ok2, q, heaps)			= replaceProp q p1 p2 heaps
				= (ok1 || ok2, CAnd p q, heaps)
			replace (COr p q) p1 p2 heaps
				# (ok1, p, heaps)			= replaceProp p p1 p2 heaps
				# (ok2, q, heaps)			= replaceProp q p1 p2 heaps
				= (ok1 || ok2, COr p q, heaps)
			replace (CImplies p q) p1 p2 heaps
				# (ok1, p, heaps)			= replaceProp p p1 p2 heaps
				# (ok2, q, heaps)			= replaceProp q p1 p2 heaps
				= (ok1 || ok2, CImplies p q, heaps)
			replace (CIff p q) p1 p2 heaps
				# (ok1, p, heaps)			= replaceProp p p1 p2 heaps
				# (ok2, q, heaps)			= replaceProp q p1 p2 heaps
				= (ok1 || ok2, CIff p q, heaps)
			replace (CExprForall ptr p) p1 p2 heaps
				# (ok, p, heaps)			= replaceProp p p1 p2 heaps
				= (ok, CExprForall ptr p, heaps)
			replace (CExprExists ptr p) p1 p2 heaps
				# (ok, p, heaps)			= replaceProp p p1 p2 heaps
				= (ok, CExprExists ptr p, heaps)
			replace (CPropForall ptr p) p1 p2 heaps
				# (ok, p, heaps)			= replaceProp p p1 p2 heaps
				= (ok, CPropForall ptr p, heaps)
			replace (CPropExists ptr p) p1 p2 heaps
				# (ok, p, heaps)			= replaceProp p p1 p2 heaps
				= (ok, CPropExists ptr p, heaps)
			replace (CPredicate ptr exprs) p1 p2 heaps
				= (False, CPredicate ptr exprs, heaps)





















// -------------------------------------------------------------------------------------------------------------------------------------------------
class getUsedSymbols a :: !a !*CHeaps -> (![HeapPtr], !*CHeaps)
// -------------------------------------------------------------------------------------------------------------------------------------------------

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance getUsedSymbols [a] | getUsedSymbols a
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	getUsedSymbols [x:xs] heaps
		# (used1, heaps)					= getUsedSymbols x heaps
		# (used2, heaps)					= getUsedSymbols xs heaps
		= (used1 ++ used2, heaps)
	getUsedSymbols [] heaps
		= ([], heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance getUsedSymbols (Maybe a) | getUsedSymbols a
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	getUsedSymbols (Just x) heaps
		= getUsedSymbols x heaps
	getUsedSymbols Nothing heaps
		= ([], heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance getUsedSymbols (CAlgPattern HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	getUsedSymbols pattern heaps
		# (used, heaps)						= getUsedSymbols pattern.atpResult heaps
		= ([pattern.atpDataCons: used], heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance getUsedSymbols (CBasicPattern HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	getUsedSymbols pattern heaps
		= getUsedSymbols pattern.bapResult heaps

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance getUsedSymbols (CBasicValue HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	getUsedSymbols (CBasicArray list) heaps
		= getUsedSymbols list heaps
	getUsedSymbols other heaps
		= ([], heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance getUsedSymbols (CCasePatterns HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	getUsedSymbols (CAlgPatterns ptr patterns) heaps
		= getUsedSymbols patterns heaps
	getUsedSymbols (CBasicPatterns ptr patterns) heaps
		= getUsedSymbols patterns heaps

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance getUsedSymbols (CExpr HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	getUsedSymbols (CExprVar ptr) heaps
		= ([], heaps)
	getUsedSymbols (CShared ptr) heaps
		# (shared, heaps)					= readPointer ptr heaps
		= getUsedSymbols shared.shExpr heaps
	getUsedSymbols (expr @# exprs) heaps
		# (used1, heaps)					= getUsedSymbols expr heaps
		# (used2, heaps)					= getUsedSymbols exprs heaps
		= (used1 ++ used2, heaps)
	getUsedSymbols (ptr @@# exprs) heaps
		# (used, heaps)						= getUsedSymbols exprs heaps
		| ptr == DummyValue					= ([ptr:used], heaps)
		# predef							= isNilPtr (ptrModule ptr)
		# is_symbol							= isMember (ptrKind ptr) [CFun, CDataCons]
		= case (not predef) && is_symbol of
			True	-> ([ptr:used], heaps)
			False	-> (used, heaps)
	getUsedSymbols (CLet strict lets expr) heaps
		# (vars, exprs)						= unzip lets
		# (used1, heaps)					= getUsedSymbols exprs heaps
		# (used2, heaps)					= getUsedSymbols expr heaps
		= (used1 ++ used2, heaps)
	getUsedSymbols (CCase expr patterns def) heaps
		# (used1, heaps)					= getUsedSymbols expr heaps
		# (used2, heaps)					= getUsedSymbols patterns heaps
		# (used3, heaps)					= getUsedSymbols def heaps
		= (used1 ++ used2 ++ used3, heaps)
	getUsedSymbols (CBasicValue value) heaps
		= getUsedSymbols value heaps
	getUsedSymbols (CCode codetype codecontents) heaps
		= ([], heaps)
	getUsedSymbols CBottom heaps
		= ([], heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance getUsedSymbols (CProp HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	getUsedSymbols (CPropVar ptr) heaps
		= ([], heaps)
	getUsedSymbols CTrue heaps
		= ([], heaps)
	getUsedSymbols CFalse heaps
		= ([], heaps)
	getUsedSymbols (CEqual e1 e2) heaps
		# (used1, heaps)					= getUsedSymbols e1 heaps
		# (used2, heaps)					= getUsedSymbols e2 heaps
		= (used1 ++ used2, heaps)
	getUsedSymbols (CNot p) heaps
		= getUsedSymbols p heaps
	getUsedSymbols (CAnd p q) heaps
		# (used1, heaps)					= getUsedSymbols p heaps
		# (used2, heaps)					= getUsedSymbols q heaps
		= (used1 ++ used2, heaps)
	getUsedSymbols (COr p q) heaps
		# (used1, heaps)					= getUsedSymbols p heaps
		# (used2, heaps)					= getUsedSymbols q heaps
		= (used1 ++ used2, heaps)
	getUsedSymbols (CImplies p q) heaps
		# (used1, heaps)					= getUsedSymbols p heaps
		# (used2, heaps)					= getUsedSymbols q heaps
		= (used1 ++ used2, heaps)
	getUsedSymbols (CIff p q) heaps
		# (used1, heaps)					= getUsedSymbols p heaps
		# (used2, heaps)					= getUsedSymbols q heaps
		= (used1 ++ used2, heaps)
	getUsedSymbols (CExprForall var p) heaps
		= getUsedSymbols p heaps
	getUsedSymbols (CExprExists var p) heaps
		= getUsedSymbols p heaps
	getUsedSymbols (CPropForall var p) heaps
		= getUsedSymbols p heaps
	getUsedSymbols (CPropExists var p) heaps
		= getUsedSymbols p heaps
	getUsedSymbols (CPredicate ptr es) heaps
		= getUsedSymbols es heaps

// -------------------------------------------------------------------------------------------------------------------------------------------------
GetUsedSymbols :: !a !*CHeaps -> (![HeapPtr], !*CHeaps) | getUsedSymbols a
// -------------------------------------------------------------------------------------------------------------------------------------------------
GetUsedSymbols x heaps
	# (ptrs, heaps)							= getUsedSymbols x heaps
	= (removeDup ptrs, heaps)
















// Input: list of names to used; output: list of names that were NOT found
// -------------------------------------------------------------------------------------------------------------------------------------------------
class isUsing a :: !a ![String] !*CHeaps !*CProject -> (![String], !*CHeaps, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance isUsing [a] | isUsing a
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	isUsing [x:xs] names heaps prj
		# (names, heaps, prj)				= isUsing x names heaps prj
		= isUsing xs names heaps prj
	isUsing [] names heaps prj
		= (names, heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance isUsing (Maybe a) | isUsing a
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	isUsing (Just x) names heaps prj
		= isUsing x names heaps prj
	isUsing Nothing names heaps prj
		= (names, heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance isUsing (CAlgPattern HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	isUsing pattern names heaps prj
		= isUsing pattern.atpResult names heaps prj

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance isUsing (CBasicPattern HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	isUsing pattern names heaps prj
		= isUsing pattern.bapResult names heaps prj

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance isUsing (CBasicValue HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	isUsing (CBasicArray exprs) names heaps prj
		= isUsing exprs names heaps prj
	isUsing other names heaps prj
		= (names, heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance isUsing (CCasePatterns HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	isUsing (CAlgPatterns _ patterns) names heaps prj
		= isUsing patterns names heaps prj
	isUsing (CBasicPatterns _ patterns) names heaps prj
		= isUsing patterns names heaps prj

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance isUsing (CExpr HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	isUsing (CExprVar ptr) names heaps prj
		= (names, heaps, prj)
	isUsing (CShared ptr) names heaps prj
		# (shared, heaps)					= readPointer ptr heaps
		= isUsing shared.shExpr names heaps prj
	isUsing (expr @# exprs) names heaps prj
		# (names, heaps, prj)				= isUsing expr names heaps prj
		= isUsing exprs names heaps prj
	isUsing (ptr @@# exprs) names heaps prj
		# (_, name, heaps, prj)				= getDefinitionName ptr heaps prj
		# names								= removeMember name names
		= isUsing exprs names heaps prj
	isUsing (CLet _ lets expr) names heaps prj
		# (_, exprs)						= unzip lets
		# (names, heaps, prj)				= isUsing exprs names heaps prj
		= isUsing expr names heaps prj
	isUsing (CCase expr patterns def) names heaps prj
		# (names, heaps, prj)				= isUsing expr names heaps prj
		# (names, heaps, prj)				= isUsing patterns names heaps prj
		= isUsing def names heaps prj
	isUsing (CBasicValue value) names heaps prj
		= isUsing value names heaps prj
	isUsing (CCode _ _) names heaps prj
		= (names, heaps, prj)
	isUsing CBottom names heaps prj
		= (names, heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance isUsing (CProp HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	isUsing (CPropVar ptr) names heaps prj
		= (names, heaps, prj)
	isUsing CTrue names heaps prj
		= (removeMember "TRUE" names, heaps, prj)
	isUsing CFalse names heaps prj
		= (removeMember "FALSE" names, heaps, prj)
	isUsing (CEqual e1 e2) names heaps prj
		# (names, heaps, prj)				= isUsing e1 names heaps prj
		= isUsing e2 names heaps prj
	isUsing (CNot p) names heaps prj
		# names								= removeMember "~" names
		= isUsing p names heaps prj
	isUsing (CAnd p q) names heaps prj
		# names								= removeMember "/\\" names
		# (names, heaps, prj)				= isUsing p names heaps prj
		= isUsing q names heaps prj
	isUsing (COr p q) names heaps prj
		# names								= removeMember "\\/" names
		# (names, heaps, prj)				= isUsing p names heaps prj
		= isUsing q names heaps prj
	isUsing (CImplies p q) names heaps prj
		# names								= removeMember "->" names
		# (names, heaps, prj)				= isUsing p names heaps prj
		= isUsing q names heaps prj
	isUsing (CIff p q) names heaps prj
		# names								= removeMember "<->" names
		# (names, heaps, prj)				= isUsing p names heaps prj
		= isUsing q names heaps prj
	isUsing (CExprForall var p) names heaps prj
		= isUsing p names heaps prj
	isUsing (CExprExists var p) names heaps prj
		= isUsing p names heaps prj
	isUsing (CPropForall var p) names heaps prj
		= isUsing p names heaps prj
	isUsing (CPropExists var p) names heaps prj
		= isUsing p names heaps prj
	isUsing (CPredicate ptr exprs) names heaps prj
		= isUsing exprs names heaps prj

// -------------------------------------------------------------------------------------------------------------------------------------------------
IsUsing :: !a ![String] !*CHeaps !*CProject -> (!Bool, !*CHeaps, !*CProject) | isUsing a
// -------------------------------------------------------------------------------------------------------------------------------------------------
IsUsing x names heaps prj
	# (names, heaps, prj)					= isUsing x names heaps prj
	= (isEmpty names, heaps, prj)



















// -------------------------------------------------------------------------------------------------------------------------------------------------
class removeDictSelections a :: !a !*CHeaps !*CProject -> (!a, !*CHeaps, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance removeDictSelections [a] | removeDictSelections a
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	removeDictSelections [x:xs] heaps prj
		#! (x, heaps, prj)					= removeDictSelections x heaps prj
		#! (xs, heaps, prj)					= removeDictSelections xs heaps prj
		= ([x:xs], heaps, prj)
	removeDictSelections [] heaps prj
		= ([], heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance removeDictSelections (Maybe a) | removeDictSelections a
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	removeDictSelections (Just x) heaps prj
		#! (x, heaps, prj)					= removeDictSelections x heaps prj
		= (Just x, heaps, prj)
	removeDictSelections Nothing heaps prj
		= (Nothing, heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance removeDictSelections (CAlgPattern HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	removeDictSelections pattern heaps prj
		#! (result, heaps, prj)				= removeDictSelections pattern.atpResult heaps prj
		# pattern							= {pattern & atpResult = result}
		= (pattern, heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance removeDictSelections (CBasicPattern HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	removeDictSelections pattern heaps prj
		#! (result, heaps, prj)				= removeDictSelections pattern.bapResult heaps prj
		# pattern							= {pattern & bapResult = result}
		= (pattern, heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance removeDictSelections (CBasicValue HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	removeDictSelections (CBasicArray exprs) heaps prj
		#! (exprs, heaps, prj)				= removeDictSelections exprs heaps prj
		= (CBasicArray exprs, heaps, prj)
	removeDictSelections other heaps prj
		= (other, heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance removeDictSelections (CCasePatterns HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	removeDictSelections (CAlgPatterns type patterns) heaps prj	
		#! (patterns, heaps, prj)			= removeDictSelections patterns heaps prj
		= (CAlgPatterns type patterns, heaps, prj)
	removeDictSelections (CBasicPatterns type patterns) heaps prj	
		#! (patterns, heaps, prj)			= removeDictSelections patterns heaps prj
		= (CBasicPatterns type patterns, heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance removeDictSelections (CExpr HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	removeDictSelections (CExprVar ptr) heaps prj
		= (CExprVar ptr, heaps, prj)
	removeDictSelections (CShared ptr) heaps prj
		# (shared, heaps)					= readPointer ptr heaps
		#! (expr, heaps, prj)				= removeDictSelections shared.shExpr heaps prj
		# shared							= {shared & shExpr = expr}
		# heaps								= writePointer ptr shared heaps
		= (CShared ptr, heaps, prj)
	removeDictSelections (expr @# exprs) heaps prj
		#! (expr, heaps, prj)				= removeDictSelections expr heaps prj
		#! (exprs, heaps, prj)				= removeDictSelections exprs heaps prj
		= (combine expr exprs, heaps, prj)
		where
			combine :: !CExprH ![CExprH] -> CExprH
			combine (ptr @@# es1) es2
				= ptr @@# (es1 ++ es2)
			combine e es
				= e @# es
	removeDictSelections (ptr @@# exprs) heaps prj
		#! (exprs, heaps, prj)				= removeDictSelections exprs heaps prj
		= remove ptr exprs heaps prj
		where
			remove :: !HeapPtr ![CExprH] !*CHeaps !*CProject -> (!CExprH, !*CHeaps, !*CProject)
			remove select_ptr [build_ptr @@# exprs: more_args] heaps prj
				# kind						= ptrKind select_ptr
				| kind <> CFun				= (select_ptr @@# [build_ptr @@# exprs: more_args], heaps, prj)
				# (_, fun, prj)				= getFunDef select_ptr prj
				# is_selector				= fun.fdIsRecordSelector
				| not is_selector			= (select_ptr @@# [build_ptr @@# exprs: more_args], heaps, prj)
				# (_, field, prj)			= getRecordFieldDef fun.fdRecordFieldDef prj
				= (combine (exprs !! field.rfIndex) more_args, heaps, prj)
			remove ptr exprs heaps prj
				= (ptr @@# exprs, heaps, prj)
			
			combine :: !CExprH ![CExprH] -> CExprH
			combine (ptr @@# es1) es2
				= ptr @@# (es1 ++ es2)
			combine e es
				= e @# es
	removeDictSelections (CCase expr patterns def) heaps prj
		#! (expr, heaps, prj)				= removeDictSelections expr heaps prj
		#! (patterns, heaps, prj)			= removeDictSelections patterns heaps prj
		#! (def, heaps, prj)				= removeDictSelections def heaps prj
		= (CCase expr patterns def, heaps, prj)
	removeDictSelections (CLet strict lets expr) heaps prj
		# (vars, exprs)						= unzip lets
		#! (exprs, heaps, prj)				= removeDictSelections exprs heaps prj
		# lets								= zip2 vars exprs
		#! (expr, heaps, prj)				= removeDictSelections expr heaps prj
		= (CLet strict lets expr, heaps, prj)
	removeDictSelections (CBasicValue value) heaps prj
		#! (value, heaps, prj)				= removeDictSelections value heaps prj
		= (CBasicValue value, heaps, prj)
	removeDictSelections (CCode codetype codecontents) heaps prj
		= (CCode codetype codecontents, heaps, prj)
	removeDictSelections CBottom heaps prj
		= (CBottom, heaps, prj)






















// -------------------------------------------------------------------------------------------------------------------------------------------------
:: FindLocations =
// -------------------------------------------------------------------------------------------------------------------------------------------------
	{ findVars					:: !Bool
	, findCases					:: !Bool
	, findLets					:: !Bool
	, findKinds					:: ![DefinitionKind]
	}
instance DummyValue FindLocations
	where DummyValue = {findVars = True, findCases = True, findLets = True, findKinds = [CFun, CDataCons]}

// -------------------------------------------------------------------------------------------------------------------------------------------------
class getExprLocations a :: !FindLocations !a ![(CName, Int)] !*CHeaps !*CProject -> (![(CName, Int)], !*CHeaps, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------

// -------------------------------------------------------------------------------------------------------------------------------------------------
insertLocation :: !CName ![(CName, Int)] -> [(CName, Int)]
// -------------------------------------------------------------------------------------------------------------------------------------------------
insertLocation name []
	= [(name, 1)]
insertLocation name [(name1,index1): locations]
	| name <> name1							= [(name1, index1): insertLocation name locations]
	= case locations of
		[]						-> [(name1, index1), (name, index1+1)]
		[(name2,index2):rest]	-> case name == name2 of
									True	-> [(name1, index1): insertLocation name locations]
									False	-> [(name1, index1), (name, index1+1): locations]

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance getExprLocations [a] | getExprLocations a
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	getExprLocations find [x:xs] locations heaps prj
		# (locations, heaps, prj)					= getExprLocations find x locations heaps prj
		= getExprLocations find xs locations heaps prj
	getExprLocations find [] locations heaps prj
		= (locations, heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance getExprLocations (Maybe a) | getExprLocations a
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	getExprLocations find (Just x) locations heaps prj
		= getExprLocations find x locations heaps prj
	getExprLocations find Nothing locations heaps prj
		= (locations, heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance getExprLocations (CAlgPattern HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	getExprLocations find pattern locations heaps prj
		= getExprLocations find pattern.atpResult locations heaps prj

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance getExprLocations (CBasicPattern HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	getExprLocations find pattern locations heaps prj
		= getExprLocations find pattern.bapResult locations heaps prj

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance getExprLocations (CBasicValue HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	getExprLocations find (CBasicArray exprs) locations heaps prj
		= getExprLocations find exprs locations heaps prj
	getExprLocations find _ locations heaps prj
		= (locations, heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance getExprLocations (CCasePatterns HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	getExprLocations find (CAlgPatterns type patterns) locations heaps prj
		= getExprLocations find patterns locations heaps prj
	getExprLocations find (CBasicPatterns type patterns) locations heaps prj
		= getExprLocations find patterns locations heaps prj

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance getExprLocations (CExpr HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	getExprLocations find (CExprVar ptr) locations heaps prj
		| not find.findVars								= (locations, heaps, prj)
		# (var, heaps)									= readPointer ptr heaps
		= (insertLocation var.evarName locations, heaps, prj)
	getExprLocations find (CShared ptr) locations heaps prj
		# (shared, heaps)								= readPointer ptr heaps
		= getExprLocations find shared.shExpr locations heaps prj
	getExprLocations find (expr @# exprs) locations heaps prj
		# (locations, heaps, prj)						= getExprLocations find expr locations heaps prj
		= getExprLocations find exprs locations heaps prj
	getExprLocations find (ptr @@# exprs) locations heaps prj
		# (_, info, heaps, prj)							= getDefinitionInfo ptr heaps prj
		| not (isMember info.diKind find.findKinds)		= getExprLocations find exprs locations heaps prj
		| info.diInfix && length exprs == 2
			# (locations, heaps, prj)					= getExprLocations find (exprs !! 0) locations heaps prj
			# locations									= insertLocation info.diName locations
			= getExprLocations find (exprs !! 1) locations heaps prj
		# locations										= insertLocation info.diName locations
		= getExprLocations find exprs locations heaps prj
	getExprLocations find (CLet strict lets expr) locations heaps prj
		# locations										= if find.findLets (insertLocation "let" locations) locations
		# (vars, exprs)									= unzip lets
		# (locations, heaps, prj)						= getExprLocations find exprs locations heaps prj
		= getExprLocations find expr locations heaps prj
	getExprLocations find (CCase expr patterns def) locations heaps prj
		# locations										= if find.findCases (insertLocation "case" locations) locations
		# (locations, heaps, prj)						= getExprLocations find expr locations heaps prj
		# (locations, heaps, prj)						= getExprLocations find patterns locations heaps prj
		= getExprLocations find def locations heaps prj
	getExprLocations find (CBasicValue value) locations heaps prj
		= getExprLocations find value locations heaps prj
	getExprLocations find (CCode codetype codecontents) locations heaps prj
		= (locations, heaps, prj)
	getExprLocations find CBottom locations heaps prj
		= (locations, heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance getExprLocations (CProp HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	getExprLocations find (CPropVar ptr) locations heaps prj
		= (locations, heaps, prj)
	getExprLocations find CTrue locations heaps prj
		= (locations, heaps, prj)
	getExprLocations find CFalse locations heaps prj
		= (locations, heaps, prj)
	getExprLocations find (CEqual e1 e2) locations heaps prj
		# (locations, heaps, prj)						= getExprLocations find e1 locations heaps prj
		= getExprLocations find e2 locations heaps prj
	getExprLocations find (CNot p) locations heaps prj
		= getExprLocations find p locations heaps prj
	getExprLocations find (CAnd p q) locations heaps prj
		# (locations, heaps, prj)						= getExprLocations find p locations heaps prj
		= getExprLocations find q locations heaps prj
	getExprLocations find (COr p q) locations heaps prj
		# (locations, heaps, prj)						= getExprLocations find p locations heaps prj
		= getExprLocations find q locations heaps prj
	getExprLocations find (CImplies p q) locations heaps prj
		# (locations, heaps, prj)						= getExprLocations find p locations heaps prj
		= getExprLocations find q locations heaps prj
	getExprLocations find (CIff p q) locations heaps prj
		# (locations, heaps, prj)						= getExprLocations find p locations heaps prj
		= getExprLocations find q locations heaps prj
	getExprLocations find (CExprForall ptr p) locations heaps prj
		= getExprLocations find p locations heaps prj
	getExprLocations find (CExprExists ptr p) locations heaps prj
		= getExprLocations find p locations heaps prj
	getExprLocations find (CPropForall ptr p) locations heaps prj
		= getExprLocations find p locations heaps prj
	getExprLocations find (CPropExists ptr p) locations heaps prj
		= getExprLocations find p locations heaps prj
	getExprLocations find (CPredicate ptr exprs) locations heaps prj
		= getExprLocations find exprs locations heaps prj

// -------------------------------------------------------------------------------------------------------------------------------------------------
GetExprLocations :: !FindLocations !a !*CHeaps !*CProject -> (![(CName, Int)], !*CHeaps, !*CProject) | getExprLocations a
// -------------------------------------------------------------------------------------------------------------------------------------------------
GetExprLocations find x heaps prj
	# (locs, heaps, prj)								= getExprLocations find x [] heaps prj
	= (sortBy smaller_n_i locs, heaps, prj)
	where
		smaller_n_i :: !(!CName, !Int) !(!CName, !Int) -> Bool
		smaller_n_i (n1,i1) (n2,i2)
			| n1 < n2									= True
			| n1 > n2									= False
			= i1 < i2

// -------------------------------------------------------------------------------------------------------------------------------------------------
getExprOnLocationInExpr :: !CName !Int !CExprH !*CHeaps !*CProject -> (!Bool, !CExprH, !*CHeaps, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------
getExprOnLocationInExpr name index x heaps prj
	# (_, (ok, _, expr, _), heaps, prj)					= actOnSubExpr name index Nothing x get heaps prj
	= (ok, expr, heaps, prj)
	where
		get expr heaps prj
			= (OK, (True, expr), heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
getExprOnLocationInProp :: !CName !Int !CPropH !*CHeaps !*CProject -> (!Bool, !CExprH, !*CHeaps, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------
getExprOnLocationInProp name index x heaps prj
	# (_, (ok, _, expr, _), heaps, prj)					= actOnSubExpr name index Nothing x get heaps prj
	= (ok, expr, heaps, prj)
	where
		get expr heaps prj
			= (OK, (True, expr), heaps, prj)
















// -------------------------------------------------------------------------------------------------------------------------------------------------
:: ExprFun :== (CExprH -> *(*CHeaps -> *(*CProject -> *(Error, (Bool, CExprH), *CHeaps, *CProject))))
// -------------------------------------------------------------------------------------------------------------------------------------------------

// -------------------------------------------------------------------------------------------------------------------------------------------------
class actOnSubExpr a :: !CName !Int !(Maybe Int) !a !ExprFun !*CHeaps !*CProject -> (!Error, !(!Bool, !Int, !CExprH, !a), !*CHeaps, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance actOnSubExpr [a] | actOnSubExpr a
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	actOnSubExpr name index mb_argindex [x:xs] f heaps prj
		# (error, (changed, index, e, x), heaps, prj)		= actOnSubExpr name index mb_argindex x f heaps prj
		| isError error										= (error, DummyValue, heaps, prj)
		| index <= 0										= (OK, (changed, 0, e, [x:xs]), heaps, prj)
		# (error, (changed, index, e, xs), heaps, prj)		= actOnSubExpr name index mb_argindex xs f heaps prj
		| isError error										= (error, DummyValue, heaps, prj)
		= (OK, (changed, index, e, [x:xs]), heaps, prj)
	actOnSubExpr name index mb_argindex [] f heaps prj
		= (OK, (False, index, DummyValue, []), heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance actOnSubExpr (Maybe a) | actOnSubExpr a
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	actOnSubExpr name index mb_argindex (Just x) f heaps prj
		# (error, (changed, index, e, x), heaps, prj)		= actOnSubExpr name index mb_argindex x f heaps prj
		| isError error										= (error, DummyValue, heaps, prj)
		= (OK, (changed, index, e, Just x), heaps, prj)
	actOnSubExpr name index mb_argindex Nothing f heaps prj
		= (OK, (False, index, DummyValue, Nothing), heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance actOnSubExpr (CAlgPattern HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	actOnSubExpr name index mb_argindex pattern f heaps prj
		# (error, (changed, index, e, expr), heaps, prj)	= actOnSubExpr name index mb_argindex pattern.atpResult f heaps prj
		| isError error										= (error, DummyValue, heaps, prj)
		# pattern											= {pattern & atpResult = expr}
		= (OK, (changed, index, e, pattern), heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance actOnSubExpr (CBasicPattern HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	actOnSubExpr name index mb_argindex pattern f heaps prj
		# (error, (changed, index, e, expr), heaps, prj)	= actOnSubExpr name index mb_argindex pattern.bapResult f heaps prj
		| isError error										= (error, DummyValue, heaps, prj)
		# pattern											= {pattern & bapResult = expr}
		= (OK, (changed, index, e, pattern), heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance actOnSubExpr (CBasicValue HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	actOnSubExpr name index mb_argindex (CBasicArray exprs) f heaps prj
		# (error, (changed, index, e, exprs), heaps, prj)	= actOnSubExpr name index mb_argindex exprs f heaps prj
		| isError error										= (error, DummyValue, heaps, prj)
		= (OK, (changed, index, e, CBasicArray exprs), heaps, prj)
	actOnSubExpr name index mb_argindex other f heaps prj
		= (OK, (False, index, DummyValue, other), heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance actOnSubExpr (CCasePatterns HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	actOnSubExpr name index mb_argindex (CAlgPatterns type patterns) f heaps prj
		# (error, (changed, index, e, patterns), heaps, prj)= actOnSubExpr name index mb_argindex patterns f heaps prj
		| isError error										= (error, DummyValue, heaps, prj)
		= (OK, (changed, index, e, CAlgPatterns type patterns), heaps, prj)
	actOnSubExpr name index mb_argindex (CBasicPatterns type patterns) f heaps prj
		# (error, (changed, index, e, patterns), heaps, prj)= actOnSubExpr name index mb_argindex patterns f heaps prj
		| isError error										= (error, DummyValue, heaps, prj)
		= (OK, (changed, index, e, CBasicPatterns type patterns), heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance actOnSubExpr (CExpr HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	actOnSubExpr name index mb_argindex (CExprVar ptr) f heaps prj
		# (varname, heaps)									= getPointerName ptr heaps
		| name == varname
			| index <> 1									= (OK, (False, index-1, DummyValue, CExprVar ptr), heaps, prj)
			# (error, (changed, expr), heaps, prj)			= f (CExprVar ptr) heaps prj
			| isError error									= (error, DummyValue, heaps, prj)
			= (OK, (changed, 0, CExprVar ptr, expr), heaps, prj)
//		| name <> varname
			= (OK, (False, index, DummyValue, CExprVar ptr), heaps, prj)
	actOnSubExpr name index mb_argindex (CShared ptr) f heaps prj
		# (shared, heaps)									= readPointer ptr heaps
		# (error, (changed, index, e, expr), heaps, prj)	= actOnSubExpr name index mb_argindex shared.shExpr f heaps prj
		| isError error										= (error, DummyValue, heaps, prj)
		# shared											= {shared & shExpr = expr}
		# heaps												= writePointer ptr shared heaps
		= (OK, (changed, index, e, CShared ptr), heaps, prj)
	actOnSubExpr name index mb_argindex (expr @# exprs) f heaps prj
		# (error, (changed, index, e, expr), heaps, prj)	= actOnSubExpr name index mb_argindex expr f heaps prj
		| isError error										= (error, DummyValue, heaps, prj)
		| index <= 0										= (OK, (changed, index, e, expr @# exprs), heaps, prj)
		# (error, (changed, index, e, exprs), heaps, prj)	= actOnSubExpr name index mb_argindex exprs f heaps prj
		| isError error										= (error, DummyValue, heaps, prj)
		= (OK, (changed, index, e, expr @# exprs), heaps, prj)
	actOnSubExpr name index mb_argindex (ptr @@# exprs) f heaps prj
		# (error, definfo, heaps, prj)						= getDefinitionInfo ptr heaps prj
		| isError error										= (error, DummyValue, heaps, prj)
		# ptrname											= definfo.diName
		| definfo.diInfix && length exprs == 2 && name == ptrname
			# (error, (changed, index, e, e1), heaps, prj)	= actOnSubExpr name index mb_argindex (exprs !! 0) f heaps prj
			| isError error									= (error, DummyValue, heaps, prj)
			| index <= 0									= (OK, (changed, index, e, ptr @@# [e1:tl exprs]), heaps, prj)
			| index == 1
				# (error, (changed, e, expr), heaps, prj)	= actOnSubExprArg mb_argindex ptr [e1: tl exprs] f heaps prj
				| isError error								= (error, DummyValue, heaps, prj)
				= (OK, (changed, 0, e, expr), heaps, prj)
			# (error, (changed, index, e, e2), heaps, prj)	= actOnSubExpr name (index-1) mb_argindex (exprs !! 1) f heaps prj
			| isError error									= (error, DummyValue, heaps, prj)
			= (OK, (changed, index, e, ptr @@# [e1,e2]), heaps, prj)
		| definfo.diInfix && length exprs == 2 && name <> ptrname
			# (error, (changed, index, e, e1), heaps, prj)	= actOnSubExpr name index mb_argindex (exprs !! 0) f heaps prj
			| isError error									= (error, DummyValue, heaps, prj)
			| index <= 0									= (OK, (changed, index, e, ptr @@# [e1:tl exprs]), heaps, prj)
			# (error, (changed, index, e, e2), heaps, prj)	= actOnSubExpr name index mb_argindex (exprs !! 1) f heaps prj
			| isError error									= (error, DummyValue, heaps, prj)
			= (OK, (changed, index, e, ptr @@# [e1,e2]), heaps, prj)
		| name == ptrname
			| index == 1
				# (error, (changed, e, expr), heaps, prj)	= actOnSubExprArg mb_argindex ptr exprs f heaps prj
				| isError error								= (error, DummyValue, heaps, prj)
				= (OK, (changed, 0, e, expr), heaps, prj)
			# (error, (changed, index, e, exprs), heaps, prj)
															= actOnSubExpr name (index-1) mb_argindex exprs f heaps prj
			| isError error									= (error, DummyValue, heaps, prj)
			= (OK, (changed, index, e, ptr @@# exprs), heaps, prj)
//		| name <> ptrname
			# (error, (changed, index, e, exprs), heaps, prj)
															= actOnSubExpr name index mb_argindex exprs f heaps prj
			| isError error									= (error, DummyValue, heaps, prj)
			= (OK, (changed, index, e, ptr @@# exprs), heaps, prj)
	actOnSubExpr "let" 1 _ e=:(CLet strict lets expr) f heaps prj
		# (error, (changed, expr), heaps, prj)				= f e heaps prj
		| isError error										= (error, DummyValue, heaps, prj)
		= (OK, (changed, 0, e, expr), heaps, prj)
	actOnSubExpr name index mb_argindex (CLet strict lets expr) f heaps prj
		# index												= if (name == "let") (index-1) index
		# (vars, exprs)										= unzip lets
		# (error, (changed, index, e, exprs), heaps, prj)	= actOnSubExpr name index mb_argindex exprs f heaps prj
		| isError error										= (error, DummyValue, heaps, prj)
		# lets												= zip2 vars exprs
		| index <= 0										= (OK, (changed, index, e, CLet strict lets expr), heaps, prj)
		# (error, (changed, index, e, expr), heaps, prj)	= actOnSubExpr name index mb_argindex expr f heaps prj
		| isError error										= (error, DummyValue, heaps, prj)
		= (OK, (changed, index, e, CLet strict lets expr), heaps, prj)
	actOnSubExpr "case" 1 _ e=:(CCase expr patterns def) f heaps prj
		# (error, (changed, expr), heaps, prj)				= f (CCase expr patterns def) heaps prj
		| isError error										= (error, DummyValue, heaps, prj)
		= (OK, (changed, 0, e, expr), heaps, prj)
	actOnSubExpr name index mb_argindex (CCase expr patterns def) f heaps prj
		# index												= if (name == "case") (index-1) index
		# (error, (changed, index, e, expr), heaps, prj)	= actOnSubExpr name index mb_argindex expr f heaps prj
		| isError error										= (error, DummyValue, heaps, prj)
		| index <= 0										= (OK, (changed, index, e, CCase expr patterns def), heaps, prj)
		# (error, (changed, index, e, patterns), heaps, prj)
															= actOnSubExpr name index mb_argindex patterns f heaps prj
		| isError error										= (error, DummyValue, heaps, prj)
		| index <= 0										= (OK, (changed, index, e, CCase expr patterns def), heaps, prj)
		# (error, (changed, index, e, def), heaps, prj)		= actOnSubExpr name index mb_argindex def f heaps prj
		| isError error										= (error, DummyValue, heaps, prj)
		= (OK, (changed, index, e, CCase expr patterns def), heaps, prj)
	actOnSubExpr name index mb_argindex (CBasicValue value) f heaps prj
		# (error, (changed, index, e, value), heaps, prj)	= actOnSubExpr name index mb_argindex value f heaps prj
		| isError error										= (error, DummyValue, heaps, prj)
		= (OK, (changed, index, e, CBasicValue value), heaps, prj)
	actOnSubExpr name index mb_argindex (CCode codetype codecontents) f heaps prj
		= (OK, (False, index, DummyValue, CCode codetype codecontents), heaps, prj)
	actOnSubExpr name index mb_argindex CBottom f heaps prj
		= (OK, (False, index, DummyValue, CBottom), heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance actOnSubExpr (CProp HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	actOnSubExpr name index mb_argindex (CPropVar ptr) f heaps prj
		= (OK, (False, index, DummyValue, CPropVar ptr), heaps, prj)
	actOnSubExpr name index mb_argindex CTrue f heaps prj
		= (OK, (False, index, DummyValue, CTrue), heaps, prj)
	actOnSubExpr name index mb_argindex CFalse f heaps prj
		= (OK, (False, index, DummyValue, CFalse), heaps, prj)
	actOnSubExpr name index mb_argindex (CEqual e1 e2) f heaps prj
		# (error, (changed, index, e, e1), heaps, prj)		= actOnSubExpr name index mb_argindex e1 f heaps prj
		| isError error										= (error, DummyValue, heaps, prj)
		| index <= 0										= (OK, (changed, index, e, CEqual e1 e2), heaps, prj)
		# (error, (changed, index, e, e2), heaps, prj)		= actOnSubExpr name index mb_argindex e2 f heaps prj
		| isError error										= (error, DummyValue, heaps, prj)
		= (OK, (changed, index, e, CEqual e1 e2), heaps, prj)
	actOnSubExpr name index mb_argindex (CNot p) f heaps prj
		# (error, (changed, index, e, p), heaps, prj)		= actOnSubExpr name index mb_argindex p f heaps prj
		| isError error										= (error, DummyValue, heaps, prj)
		= (OK, (changed, index, e, CNot p), heaps, prj)
	actOnSubExpr name index mb_argindex (CAnd p q) f heaps prj
		# (error, (changed, index, e, p), heaps, prj)		= actOnSubExpr name index mb_argindex p f heaps prj
		| isError error										= (error, DummyValue, heaps, prj)
		| index <= 0										= (OK, (changed, index, e, CAnd p q), heaps, prj)
		# (error, (changed, index, e, q), heaps, prj)		= actOnSubExpr name index mb_argindex q f heaps prj
		| isError error										= (error, DummyValue, heaps, prj)
		= (OK, (changed, index, e, CAnd p q), heaps, prj)
	actOnSubExpr name index mb_argindex (COr p q) f heaps prj
		# (error, (changed, index, e, p), heaps, prj)		= actOnSubExpr name index mb_argindex p f heaps prj
		| isError error										= (error, DummyValue, heaps, prj)
		| index <= 0										= (OK, (changed, index, e, COr p q), heaps, prj)
		# (error, (changed, index, e, q), heaps, prj)		= actOnSubExpr name index mb_argindex q f heaps prj
		| isError error										= (error, DummyValue, heaps, prj)
		= (OK, (changed, index, e, COr p q), heaps, prj)
	actOnSubExpr name index mb_argindex (CImplies p q) f heaps prj
		# (error, (changed, index, e, p), heaps, prj)		= actOnSubExpr name index mb_argindex p f heaps prj
		| isError error										= (error, DummyValue, heaps, prj)
		| index <= 0										= (OK, (changed, index, e, CImplies p q), heaps, prj)
		# (error, (changed, index, e, q), heaps, prj)		= actOnSubExpr name index mb_argindex q f heaps prj
		| isError error										= (error, DummyValue, heaps, prj)
		= (OK, (changed, index, e, CImplies p q), heaps, prj)
	actOnSubExpr name index mb_argindex (CIff p q) f heaps prj
		# (error, (changed, index, e, p), heaps, prj)		= actOnSubExpr name index mb_argindex p f heaps prj
		| isError error										= (error, DummyValue, heaps, prj)
		| index <= 0										= (OK, (changed, index, e, CIff p q), heaps, prj)
		# (error, (changed, index, e, q), heaps, prj)		= actOnSubExpr name index mb_argindex q f heaps prj
		| isError error										= (error, DummyValue, heaps, prj)
		= (OK, (changed, index, e, CIff p q), heaps, prj)
	actOnSubExpr name index mb_argindex (CExprForall ptr p) f heaps prj
		# (error, (changed, index, e, p), heaps, prj)		= actOnSubExpr name index mb_argindex p f heaps prj
		| isError error										= (error, DummyValue, heaps, prj)
		= (OK, (changed, index, e, CExprForall ptr p), heaps, prj)
	actOnSubExpr name index mb_argindex (CExprExists ptr p) f heaps prj
		# (error, (changed, index, e, p), heaps, prj)		= actOnSubExpr name index mb_argindex p f heaps prj
		| isError error										= (error, DummyValue, heaps, prj)
		= (OK, (changed, index, e, CExprExists ptr p), heaps, prj)
	actOnSubExpr name index mb_argindex (CPropForall ptr p) f heaps prj
		# (error, (changed, index, e, p), heaps, prj)		= actOnSubExpr name index mb_argindex p f heaps prj
		| isError error										= (error, DummyValue, heaps, prj)
		= (OK, (changed, index, e, CPropForall ptr p), heaps, prj)
	actOnSubExpr name index mb_argindex (CPropExists ptr p) f heaps prj
		# (error, (changed, index, e, p), heaps, prj)		= actOnSubExpr name index mb_argindex p f heaps prj
		| isError error										= (error, DummyValue, heaps, prj)
		= (OK, (changed, index, e, CPropExists ptr p), heaps, prj)
	actOnSubExpr name index mb_argindex (CPredicate ptr exprs) f heaps prj
		# (error, (changed, index, e, exprs), heaps, prj)	= actOnSubExpr name index mb_argindex exprs f heaps prj
		| isError error										= (error, DummyValue, heaps, prj)
		= (OK, (changed, index, e, CPredicate ptr exprs), heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
actOnSubExprArg :: !(Maybe Int) !HeapPtr ![CExprH] !ExprFun !*CHeaps !*CProject -> (!Error, !(!Bool, !CExprH, !CExprH), !*CHeaps, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------
actOnSubExprArg Nothing ptr args f heaps prj
	# old_expr												= ptr @@# args
	# (error, (changed, new_expr), heaps, prj)				= f old_expr heaps prj
	= (error, (changed, old_expr, new_expr), heaps, prj)
actOnSubExprArg (Just index) ptr args f heaps prj
	| index < 1												= ([X_Internal "Invalid index in location."], DummyValue, heaps, prj)
	| index > length args									= ([X_Internal "Invalid index in location."], DummyValue, heaps, prj)
	# old_arg												= args !! (index-1)
	# (error, (changed, new_arg), heaps, prj)				= f old_arg heaps prj
	| isError error											= (error, DummyValue, heaps, prj)
	# args													= updateAt (index-1) new_arg args
	= (OK, (changed, old_arg, ptr @@# args), heaps, prj)





















// -------------------------------------------------------------------------------------------------------------------------------------------------
actOnAllSubExprs :: !CPropH !ExprFun !*CHeaps !*CProject -> (!Error, !(!Bool, !CPropH), !*CHeaps, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------
actOnAllSubExprs (CPropVar ptr) f heaps prj
	= (OK, (False, CPropVar ptr), heaps, prj)
actOnAllSubExprs CTrue f heaps prj
	= (OK, (False, CTrue), heaps, prj)
actOnAllSubExprs CFalse f heaps prj
	= (OK, (False, CFalse), heaps, prj)
actOnAllSubExprs (CEqual e1 e2) f heaps prj
	# (error, (changed1, e1), heaps, prj)				= f e1 heaps prj
	| isError error										= (error, DummyValue, heaps, prj)
	# (error, (changed2, e2), heaps, prj)				= f e2 heaps prj
	| isError error										= (error, DummyValue, heaps, prj)
	= (OK, (changed1 || changed2, CEqual e1 e2), heaps, prj)
actOnAllSubExprs (CNot p) f heaps prj
	# (error, (changed, p), heaps, prj)					= actOnAllSubExprs p f heaps prj
	| isError error										= (error, DummyValue, heaps, prj)
	= (OK, (changed, CNot p), heaps, prj)
actOnAllSubExprs (CAnd p q) f heaps prj
	# (error, (changed1, p), heaps, prj)				= actOnAllSubExprs p f heaps prj
	| isError error										= (error, DummyValue, heaps, prj)
	# (error, (changed2, q), heaps, prj)				= actOnAllSubExprs q f heaps prj
	| isError error										= (error, DummyValue, heaps, prj)
	= (OK, (changed1 || changed2, CAnd p q), heaps, prj)
actOnAllSubExprs (COr p q) f heaps prj
	# (error, (changed1, p), heaps, prj)				= actOnAllSubExprs p f heaps prj
	| isError error										= (error, DummyValue, heaps, prj)
	# (error, (changed2, q), heaps, prj)				= actOnAllSubExprs q f heaps prj
	| isError error										= (error, DummyValue, heaps, prj)
	= (OK, (changed1 || changed2, COr p q), heaps, prj)
actOnAllSubExprs (CImplies p q) f heaps prj
	# (error, (changed1, p), heaps, prj)				= actOnAllSubExprs p f heaps prj
	| isError error										= (error, DummyValue, heaps, prj)
	# (error, (changed2, q), heaps, prj)				= actOnAllSubExprs q f heaps prj
	| isError error										= (error, DummyValue, heaps, prj)
	= (OK, (changed1 || changed2, CImplies p q), heaps, prj)
actOnAllSubExprs (CIff p q) f heaps prj
	# (error, (changed1, p), heaps, prj)				= actOnAllSubExprs p f heaps prj
	| isError error										= (error, DummyValue, heaps, prj)
	# (error, (changed2, q), heaps, prj)				= actOnAllSubExprs q f heaps prj
	| isError error										= (error, DummyValue, heaps, prj)
	= (OK, (changed1 || changed2, CIff p q), heaps, prj)
actOnAllSubExprs (CExprForall ptr p) f heaps prj
	# (error, (changed, p), heaps, prj)					= actOnAllSubExprs p f heaps prj
	| isError error										= (error, DummyValue, heaps, prj)
	= (OK, (changed, CExprForall ptr p), heaps, prj)
actOnAllSubExprs (CExprExists ptr p) f heaps prj
	# (error, (changed, p), heaps, prj)					= actOnAllSubExprs p f heaps prj
	| isError error										= (error, DummyValue, heaps, prj)
	= (OK, (changed, CExprExists ptr p), heaps, prj)
actOnAllSubExprs (CPropForall ptr p) f heaps prj
	# (error, (changed, p), heaps, prj)					= actOnAllSubExprs p f heaps prj
	| isError error										= (error, DummyValue, heaps, prj)
	= (OK, (changed, CPropForall ptr p), heaps, prj)
actOnAllSubExprs (CPropExists ptr p) f heaps prj
	# (error, (changed, p), heaps, prj)					= actOnAllSubExprs p f heaps prj
	| isError error										= (error, DummyValue, heaps, prj)
	= (OK, (changed, CPropExists ptr p), heaps, prj)
actOnAllSubExprs (CPredicate ptr exprs) f heaps prj
	# (error, (changed, exprs), heaps, prj)				= act_list exprs f heaps prj
	| isError error										= (error, DummyValue, heaps, prj)
	= (OK, (changed, CPredicate ptr exprs), heaps, prj)
	where
		act_list [expr:exprs] f heaps prj
			# (error, (changed1, expr), heaps, prj)		= f expr heaps prj
			| isError error								= (error, DummyValue, heaps, prj)
			# (error, (changed2, exprs), heaps, prj)	= act_list exprs f heaps prj
			| isError error								= (error, DummyValue, heaps, prj)
			= (error, (changed1 || changed2, [expr:exprs]), heaps, prj)
		act_list [] f heaps prj
			= (OK, (False, []), heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
actOnExprLocation :: !ExprLocation !CPropH !ExprFun !*CHeaps !*CProject -> (!Error, !(!Bool, !CPropH), !*CHeaps, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------
actOnExprLocation AllSubExprs p f heaps prj
	= actOnAllSubExprs p f heaps prj
actOnExprLocation (SelectedSubExpr name index mb_argindex) p f heaps prj
	# (error, (changed, _, _, p), heaps, prj)			= actOnSubExpr name index mb_argindex p f heaps prj
	= (error, (changed, p), heaps, prj)









// applies the expression fun on all SUBexpressions (as well as on the expression as a whole)
// works inside out
// -------------------------------------------------------------------------------------------------------------------------------------------------
class recurse a :: !ExprFun !a !*CHeaps !*CProject -> (!Error, !(!Bool, !a), !*CHeaps, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance recurse [a] | recurse a
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	recurse fun [x:xs] heaps prj
		# (error, (changed1, x), heaps, prj)			= recurse fun x heaps prj
		| isError error									= (error, DummyValue, heaps, prj)
		# (error, (changed2, xs), heaps, prj)			= recurse fun xs heaps prj
		| isError error									= (error, DummyValue, heaps, prj)
		= (OK, (changed1 || changed2, [x:xs]), heaps, prj)
	recurse fun [] heaps prj
		= (OK, (False, []), heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance recurse (Maybe a) | recurse a
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	recurse fun (Just x) heaps prj
		# (error, (changed, x), heaps, prj)				= recurse fun x heaps prj
		= (error, (changed, Just x), heaps, prj)
	recurse fun Nothing heaps prj
		= (OK, (False, Nothing), heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance recurse (CAlgPattern HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	recurse fun pattern heaps prj
		# (error, (changed, expr), heaps, prj)			= recurse fun pattern.atpResult heaps prj
		# pattern										= {pattern & atpResult = expr}
		= (error, (changed, pattern), heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance recurse (CBasicPattern HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	recurse fun pattern heaps prj
		# (error, (changed, expr), heaps, prj)			= recurse fun pattern.bapResult heaps prj
		# pattern										= {pattern & bapResult = expr}
		= (error, (changed, pattern), heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance recurse (CBasicValue HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	recurse fun (CBasicArray exprs) heaps prj
		# (error, (changed, exprs), heaps, prj)			= recurse fun exprs heaps prj
		= (error, (changed, CBasicArray exprs), heaps, prj)
	recurse fun other heaps prj
		= (OK, (False, other), heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance recurse (CCasePatterns HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	recurse fun (CAlgPatterns ptr patterns) heaps prj
		# (error, (changed, patterns), heaps, prj)		= recurse fun patterns heaps prj
		= (error, (changed, CAlgPatterns ptr patterns), heaps, prj)
	recurse fun (CBasicPatterns ptr patterns) heaps prj
		# (error, (changed, patterns), heaps, prj)		= recurse fun patterns heaps prj
		= (error, (changed, CBasicPatterns ptr patterns), heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance recurse (CExpr HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	recurse fun expr=:(CExprVar _) heaps prj
		= fun expr heaps prj
	recurse fun (CShared ptr) heaps prj
		# (shared, heaps)								= readPointer ptr heaps
		# (error, (changed, expr), heaps, prj)			= recurse fun shared.shExpr heaps prj
		# shared										= {shared & shExpr = expr}
		# heaps											= writePointer ptr shared heaps
		= (error, (changed, CShared ptr), heaps, prj)
	recurse fun (expr @# exprs) heaps prj
		# (error, (changed1, expr), heaps, prj)			= recurse fun expr heaps prj
		| isError error									= (error, DummyValue, heaps, prj)
		# (error, (changed2, exprs), heaps, prj)		= recurse fun exprs heaps prj
		| isError error									= (error, DummyValue, heaps, prj)
		# (error, (changed3, total), heaps, prj)		= fun (expr @# exprs) heaps prj
		= (error, (changed1 || changed2 || changed3, total), heaps, prj)
	recurse fun (ptr @@# exprs) heaps prj
		# (error, (changed1, exprs), heaps, prj)		= recurse fun exprs heaps prj
		| isError error									= (error, DummyValue, heaps, prj)
		# (error, (changed2, total), heaps, prj)		= fun (ptr @@# exprs) heaps prj
		= (error, (changed1 || changed2, total), heaps, prj)
	recurse fun (CLet strict lets expr) heaps prj
		# (vars, exprs)									= unzip lets
		# (error, (changed1, exprs), heaps, prj)		= recurse fun exprs heaps prj
		| isError error									= (error, DummyValue, heaps, prj)
		# lets											= zip2 vars exprs
		# (error, (changed2, expr), heaps, prj)			= recurse fun expr heaps prj
		| isError error									= (error, DummyValue, heaps, prj)
		# (error, (changed3, total), heaps, prj)		= fun (CLet strict lets expr) heaps prj
		= (error, (changed1 || changed2 || changed3, total), heaps, prj)
	recurse fun (CCase expr patterns def) heaps prj
		# (error, (changed1, expr), heaps, prj)			= recurse fun expr heaps prj
		| isError error									= (error, DummyValue, heaps, prj)
		# (error, (changed2, patterns), heaps, prj)		= recurse fun patterns heaps prj
		| isError error									= (error, DummyValue, heaps, prj)
		# (error, (changed3, def), heaps, prj)			= recurse fun def heaps prj
		| isError error									= (error, DummyValue, heaps, prj)
		# (error, (changed4, total), heaps, prj)		= fun (CCase expr patterns def) heaps prj
		= (error, (changed1 || changed2 || changed3 || changed4, total), heaps, prj)
	recurse fun (CBasicValue value) heaps prj
		# (error, (changed1, value), heaps, prj)		= recurse fun value heaps prj
		| isError error									= (error, DummyValue, heaps, prj)
		# (error, (changed2, total), heaps, prj)		= fun (CBasicValue value) heaps prj
		= (error, (changed1 || changed2, total), heaps, prj)
	recurse fun expr=:(CCode _ _) heaps prj
		= fun expr heaps prj
	recurse fun expr=:CBottom heaps prj
		= fun expr heaps prj

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance recurse (CProp HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	recurse fun (CPropVar ptr) heaps prj
		= (OK, (False, CPropVar ptr), heaps, prj)
	recurse fun CTrue heaps prj
		= (OK, (False, CTrue), heaps, prj)
	recurse fun CFalse heaps prj
		= (OK, (False, CFalse), heaps, prj)
	recurse fun (CEqual e1 e2) heaps prj
		# (error, (changed1, e1), heaps, prj)			= recurse fun e1 heaps prj
		| isError error									= (error, DummyValue, heaps, prj)
		# (error, (changed2, e2), heaps, prj)			= recurse fun e2 heaps prj
		= (error, (changed1 || changed2, CEqual e1 e2), heaps, prj)
	recurse fun (CNot p) heaps prj
		# (error, (changed, p), heaps, prj)				= recurse fun p heaps prj
		= (error, (changed, CNot p), heaps, prj)
	recurse fun (CAnd p q) heaps prj
		# (error, (changed1, p), heaps, prj)			= recurse fun p heaps prj
		| isError error									= (error, DummyValue, heaps, prj)
		# (error, (changed2, q), heaps, prj)			= recurse fun q heaps prj
		= (error, (changed1 || changed2, CAnd p q), heaps, prj)
	recurse fun (COr p q) heaps prj
		# (error, (changed1, p), heaps, prj)			= recurse fun p heaps prj
		| isError error									= (error, DummyValue, heaps, prj)
		# (error, (changed2, q), heaps, prj)			= recurse fun q heaps prj
		= (error, (changed1 || changed2, COr p q), heaps, prj)
	recurse fun (CImplies p q) heaps prj
		# (error, (changed1, p), heaps, prj)			= recurse fun p heaps prj
		| isError error									= (error, DummyValue, heaps, prj)
		# (error, (changed2, q), heaps, prj)			= recurse fun q heaps prj
		= (error, (changed1 || changed2, CImplies p q), heaps, prj)
	recurse fun (CIff p q) heaps prj
		# (error, (changed1, p), heaps, prj)			= recurse fun p heaps prj
		| isError error									= (error, DummyValue, heaps, prj)
		# (error, (changed2, q), heaps, prj)			= recurse fun q heaps prj
		= (error, (changed1 || changed2, CIff p q), heaps, prj)
	recurse fun (CExprForall ptr p) heaps prj
		# (error, (changed, p), heaps, prj)				= recurse fun p heaps prj
		= (error, (changed, CExprForall ptr p), heaps, prj)
	recurse fun (CExprExists ptr p) heaps prj
		# (error, (changed, p), heaps, prj)				= recurse fun p heaps prj
		= (error, (changed, CExprExists ptr p), heaps, prj)
	recurse fun (CPropForall ptr p) heaps prj
		# (error, (changed, p), heaps, prj)				= recurse fun p heaps prj
		= (error, (changed, CPropForall ptr p), heaps, prj)
	recurse fun (CPropExists ptr p) heaps prj
		# (error, (changed, p), heaps, prj)				= recurse fun p heaps prj
		= (error, (changed, CPropExists ptr p), heaps, prj)
	recurse fun (CPredicate ptr exprs) heaps prj
		# (error, (changed, exprs), heaps, prj)			= recurse fun exprs heaps prj
		= (error, (changed, CPredicate ptr exprs), heaps, prj)
















// BEZIG
// Exchanges the overloaded <=, >, and >= by the arguments in their dictionary (used in Definedness)
// -------------------------------------------------------------------------------------------------------------------------------------------------
class toSmaller a :: !IntFunctions !a -> a
// -------------------------------------------------------------------------------------------------------------------------------------------------

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance toSmaller [a] | toSmaller a
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	toSmaller funs [x:xs]
		= [toSmaller funs x: toSmaller funs xs]
	toSmaller funs []
		= []

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance toSmaller (Maybe a) | toSmaller a
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	toSmaller funs (Just x)
		= Just (toSmaller funs x)
	toSmaller funs Nothing
		= Nothing

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance toSmaller (CAlgPattern HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	toSmaller funs pattern
		= {pattern & atpResult = toSmaller funs pattern.atpResult}

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance toSmaller (CBasicPattern HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	toSmaller funs pattern
		= {pattern & bapResult = toSmaller funs pattern.bapResult}

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance toSmaller (CBasicValue HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	toSmaller funs (CBasicArray exprs)
		= CBasicArray (toSmaller funs exprs)
	toSmaller funs other
		= other

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance toSmaller (CCasePatterns HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	toSmaller funs (CAlgPatterns type patterns)
		= CAlgPatterns type (toSmaller funs patterns)
	toSmaller funs (CBasicPatterns type patterns)
		= CBasicPatterns type (toSmaller funs patterns)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance toSmaller (CExpr HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	toSmaller funs (CExprVar ptr)
		= CExprVar ptr
	toSmaller funs (expr @# exprs)
		# (ok, ptr)							= get_dict_arg expr
		| not ok							= (toSmaller funs expr) @# (toSmaller funs exprs)
		= ptr @@# (toSmaller funs exprs)
		where
			get_dict_arg :: !CExprH -> (!Bool, !HeapPtr)
			get_dict_arg (fun_ptr @@# [create_record_ptr @@# [dict_arg_ptr @@# []]])
//				# check						= [funs.claGreater, funs.claGreaterEqual, funs.claSmallerEqual]
				# check						= []
				= (isMember fun_ptr check, dict_arg_ptr)
			get_dict_arg other
				= (False, DummyValue)
	toSmaller funs (ptr @@# args)
//		# check								= [funs.claGreater, funs.claGreaterEqual, funs.claSmallerEqual]
		# check								= []
		| not (isMember ptr check)			= ptr @@# (toSmaller funs args)
		# (ok, arg_ptr, more_args)			= get_dict_arg args
		| not ok							= ptr @@# (toSmaller funs args)
		= arg_ptr @@# (toSmaller funs more_args)
		where
			get_dict_arg :: ![CExprH] -> (!Bool, !HeapPtr, ![CExprH])
			get_dict_arg [create_record_ptr @@# [dict_arg_ptr @@# []]: more_args]
				= (True, dict_arg_ptr, more_args)
			get_dict_arg other
				= (False, DummyValue, [])
	toSmaller funs (CLet strict lets expr)
		# (vars, exprs)						= unzip lets
		# exprs								= toSmaller funs exprs
		# vars								= zip2 vars exprs
		# expr								= toSmaller funs expr
		= CLet strict lets expr
	toSmaller funs (CCase expr patterns def)
		= CCase (toSmaller funs expr) (toSmaller funs patterns) (toSmaller funs def)
	toSmaller funs (CBasicValue value)
		= CBasicValue (toSmaller funs value)
	toSmaller funs (CCode codetype codecontents)
		= CCode codetype codecontents
	toSmaller funs CBottom
		= CBottom
















// -------------------------------------------------------------------------------------------------------------------------------------------------
fromEither :: !(Choice a b) -> a
// -------------------------------------------------------------------------------------------------------------------------------------------------
fromEither (Either a)
	= a

// -------------------------------------------------------------------------------------------------------------------------------------------------
fromOr :: !(Choice a b) -> b
// -------------------------------------------------------------------------------------------------------------------------------------------------
fromOr (Or b)
	= b

// -------------------------------------------------------------------------------------------------------------------------------------------------
class appE a
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	appE :: !CExprLoc !a !(CExprH -> *(*CHeaps -> *(*CProject -> *(Error, CExprH, *CHeaps, *CProject)))) !*CHeaps !*CProject -> (!Bool, !Error, !CExprLoc, !a, !*CHeaps, !*CProject)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance appE (a,b) | appE b
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	appE l (a,b) f heaps prj
		# (ok, error, l, b, heaps, prj)				= appE l b f heaps prj
		= (ok, error, l, (a,b), heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance appE [a] | appE a
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	appE l [] f heaps prj
		= (False, OK, l, [], heaps, prj)
	appE l [a:as] f heaps prj
		# (ok, error, l, a, heaps, prj)				= appE l a f heaps prj
		| ok										= (True, error, l, [a:as], heaps, prj)
		# (ok, error, l, as, heaps, prj)			= appE l as f heaps prj
		= (ok, error, l, [a:as], heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance appE (Maybe a) | appE a
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	appE l (Just a) f heaps prj
		# (ok, error, l, a, heaps, prj)				= appE l a f heaps prj
		= (ok, error, l, Just a, heaps, prj)
	appE l Nothing f heaps prj
		= (False, OK, l, Nothing, heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance appE CAlgPatternH
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	appE l pattern f heaps prj
		# (ok, error, l, result, heaps, prj)		= appE l pattern.atpResult f heaps prj
		# pattern									= {pattern & atpResult = result}
		= (ok, error, l, pattern, heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance appE CBasicPatternH
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	appE l pattern f heaps prj
		# (ok, error, l, result, heaps, prj)		= appE l pattern.bapResult f heaps prj
		# pattern									= {pattern & bapResult = result}
		= (ok, error, l, pattern, heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance appE CCasePatternsH
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	appE l (CAlgPatterns ptr patterns) f heaps prj
		# (ok, error, l, patterns, heaps, prj)		= appE l patterns f heaps prj
		= (ok, error, l, CAlgPatterns ptr patterns, heaps, prj)
	appE l (CBasicPatterns type patterns) f heaps prj
		# (ok, error, l, patterns, heaps, prj)		= appE l patterns f heaps prj
		= (ok, error, l, CBasicPatterns type patterns, heaps, prj)
 
// -------------------------------------------------------------------------------------------------------------------------------------------------
instance appE CExprH
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	appE l expr f heaps prj
		# (ok, l)									= match l expr
		| ok
			# (error, expr, heaps, prj)				= f expr heaps prj
			= (True, error, l, expr, heaps, prj)
		= app_E l expr heaps prj
		where
			match :: !CExprLoc !CExprH -> (!Bool, !CExprLoc)
			match (LocVar x i) (CExprVar y)
				| x == y							= (i == 1, LocVar x (i-1))
				= (False, LocVar x i)
			match (LocFunApp f i) (g @@# _)
				| f == g							= (i == 1, LocFunApp f (i-1))
				= (False, LocFunApp f i)
			match (LocLet i) (CLet _ _ _)
				= (i == 1, LocLet (i-1))
			match (LocCase i) (CCase _ _ _)
				= (i == 1, LocCase (i-1))
			match l _
				= (False, l)
			
			app_E :: !CExprLoc !CExprH !*CHeaps !*CProject -> (!Bool, !Error, !CExprLoc, !CExprH, !*CHeaps, !*CProject)
			app_E l (e @# es) heaps prj
				# (ok, error, l, e, heaps, prj)		= appE l e f heaps prj
				| ok								= (True, error, l, e @# es, heaps, prj)
				# (ok, error, l, es, heaps, prj)	= appE l es f heaps prj
				= (ok, error, l, e @# es, heaps, prj)
			app_E l (ptr @@# es) heaps prj
				# (ok, error, l, es, heaps, prj)	= appE l es f heaps prj
				= (ok, error, l, ptr @@# es, heaps, prj)
			app_E l (CLet strict binds expr) heaps prj
				# (ok, error, l, binds, heaps, prj)	= appE l binds f heaps prj
				| ok								= (True, error, l, CLet strict binds expr, heaps, prj)
				# (ok, error, l, expr, heaps, prj)	= appE l expr f heaps prj
				= (ok, error, l, CLet strict binds expr, heaps, prj)
			app_E l (CCase expr ptrns mb_def) heaps prj
				# (ok, error, l, expr, heaps, prj)	= appE l expr f heaps prj
				| ok								= (True, error, l, CCase expr ptrns mb_def, heaps, prj)
				# (ok, error, l, ptrns, heaps, prj)	= appE l ptrns f heaps prj
				| ok								= (True, error, l, CCase expr ptrns mb_def, heaps, prj)
				# (ok, error, l, mb_def, heaps, prj)= appE l mb_def f heaps prj
				= (ok, error, l, CCase expr ptrns mb_def, heaps, prj)
			app_E l (CBasicValue (CBasicArray es)) heaps prj
				# (ok, error, l, es, heaps, prj)	= appE l es f heaps prj
				= (ok, error, l, CBasicValue (CBasicArray es), heaps, prj)
			app_E l other heaps prj
				= (False, OK, l, other, heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance appE CPropH
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	appE l (CEqual e1 e2) f heaps prj
		# (ok, error, l, e1, heaps, prj)			= appE l e1 f heaps prj
		| ok										= (True, error, l, CEqual e1 e2, heaps, prj)
		# (ok, error, l, e2, heaps, prj)			= appE l e2 f heaps prj
		= (ok, error, l, CEqual e1 e2, heaps, prj)
	appE l (CNot p) f heaps prj
		# (ok, error, l, p, heaps, prj)				= appE l p f heaps prj
		= (ok, error, l, CNot p, heaps, prj)
	appE l (CAnd p q) f heaps prj
		# (ok, error, l, p, heaps, prj)				= appE l p f heaps prj
		| ok										= (True, error, l, CAnd p q, heaps, prj)
		# (ok, error, l, q, heaps, prj)				= appE l q f heaps prj
		= (ok, error, l, CAnd p q, heaps, prj)
	appE l (COr p q) f heaps prj
		# (ok, error, l, p, heaps, prj)				= appE l p f heaps prj
		| ok										= (True, error, l, COr p q, heaps, prj)
		# (ok, error, l, q, heaps, prj)				= appE l q f heaps prj
		= (ok, error, l, COr p q, heaps, prj)
	appE l (CImplies p q) f heaps prj
		# (ok, error, l, p, heaps, prj)				= appE l p f heaps prj
		| ok										= (True, error, l, CImplies p q, heaps, prj)
		# (ok, error, l, q, heaps, prj)				= appE l q f heaps prj
		= (ok, error, l, CImplies p q, heaps, prj)
	appE l (CIff p q) f heaps prj
		# (ok, error, l, p, heaps, prj)				= appE l p f heaps prj
		| ok										= (True, error, l, CIff p q, heaps, prj)
		# (ok, error, l, q, heaps, prj)				= appE l q f heaps prj
		= (ok, error, l, CIff p q, heaps, prj)
	appE l (CExprForall x p) f heaps prj
		# (ok, error, l, p, heaps, prj)				= appE l p f heaps prj
		= (ok, error, l, CExprForall x p, heaps, prj)
	appE l (CExprExists x p) f heaps prj
		# (ok, error, l, p, heaps, prj)				= appE l p f heaps prj
		= (ok, error, l, CExprExists x p, heaps, prj)
	appE l (CPropForall x p) f heaps prj
		# (ok, error, l, p, heaps, prj)				= appE l p f heaps prj
		= (ok, error, l, CPropForall x p, heaps, prj)
	appE l (CPropExists x p) f heaps prj
		# (ok, error, l, p, heaps, prj)				= appE l p f heaps prj
		= (ok, error, l, CPropExists x p, heaps, prj)
	appE l other f heaps prj
		= (False, OK, l, other, heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
applyToInnerExpr :: !CExprLoc !a !(CExprH -> *(*CHeaps -> *(*CProject -> *(Error, CExprH, *CHeaps, *CProject)))) !*CHeaps !*CProject -> (!Error, !a, !*CHeaps, !*CProject) | appE a
// -------------------------------------------------------------------------------------------------------------------------------------------------
applyToInnerExpr l a f heaps prj
	# (ok, error, l2, a, heaps, prj)				= appE l a f heaps prj
	| not ok
		| l == l2									= (pushError (mkError1 l) OK, a, heaps, prj)
													= (pushError (mkError2 l) OK, a, heaps, prj)
	= (error, a, heaps, prj)
	where
		mkError1 :: !CExprLoc -> ErrorCode
		mkError1 (LocVar _ _)						= X_Internal "Variable not found in current goal"
		mkError1 (LocFunApp _ _)					= X_Internal "Function application not found in current goal"
		mkError1 (LocLet _)							= X_Internal "No let found in current goal"
		mkError1 (LocCase _)						= X_Internal "No case found in current goal"
		
		mkError2 :: !CExprLoc -> ErrorCode
		mkError2 (LocVar _ _)						= X_Internal "Invalid variable index"
		mkError2 (LocFunApp _ _)					= X_Internal "Invalid function application index"
		mkError2 (LocLet _)							= X_Internal "Invalid let index"
		mkError2 (LocCase _)						= X_Internal "Invalid case index"