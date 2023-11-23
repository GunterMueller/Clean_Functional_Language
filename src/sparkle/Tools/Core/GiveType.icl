/*
** Program: Clean Prover System
** Module:  GiveType (.icl)
** 
** Author:  Maarten de Mol
** Created: 16 October 2000
*/

implementation module 
	GiveType

import
	StdEnv,
	CoreTypes,
	CoreAccess,
	Predefined,
	Operate,
	Rewrite,
	Print,
	RWSDebug

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: TypingInfo =
// -------------------------------------------------------------------------------------------------------------------------------------------------
	{ tiNextIndex		:: !Int							// used to generate readable variable names
	, tiUnify			:: ![(CTypeVarPtr, CTypeH)]
	, tiSymbolTypes		:: ![CSymbolTypeH]				// used in bindLexeme only!
	, tiEqualType		:: !CTypeVarPtr					// used when e1=e2 must be typed
	}
instance DummyValue TypingInfo
	where DummyValue = {tiNextIndex = 0, tiUnify = [], tiSymbolTypes = [], tiEqualType = nilPtr}

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: TypingInfoP =
// -------------------------------------------------------------------------------------------------------------------------------------------------
	{ tpNextIndex		:: !Int
	, tpUnify			:: ![(CName, CType CName)]
	, tpSymbolTypes		:: ![CSymbolType CName]				// used in bindLexeme only!
	}

// -------------------------------------------------------------------------------------------------------------------------------------------------
makePrintableI :: !TypingInfo !*CHeaps !*CProject -> (!TypingInfoP, !*CHeaps, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------
makePrintableI info heaps prj
	# (vars, types)			= unzip info.tiUnify
	# (var_names, heaps)	= getPointerNames vars heaps
	# (types, heaps, prj)	= makePrintableL types heaps prj
	# unify					= zip2 var_names types
	# (syt, heaps, prj)		= makePrintableL info.tiSymbolTypes heaps prj
	= (	{ tpNextIndex		= info.tiNextIndex
		, tpUnify			= unify
		, tpSymbolTypes		= syt}, heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
printUnification :: !TypingInfoP -> String
// -------------------------------------------------------------------------------------------------------------------------------------------------
printUnification info
	= show info.tpUnify
	where
		show [(name,type):unify]
			= "[[" +++ name +++ " = " +++ makeText type +++ "]]  " +++ show unify
		show []
			= ""

// -------------------------------------------------------------------------------------------------------------------------------------------------
showUnification :: ![(CTypeVarPtr, CTypeH)] !*CHeaps !*CProject -> (!String, !*CHeaps, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------
showUnification [(ptr,type):unify] heaps prj
	# (name, heaps)			= getPointerName ptr heaps
	# (ptype, heaps, prj)	= makePrintable type heaps prj
	# text					= "[[" +++ name +++ "=" +++ (makeText ptype) +++ "]]"
	# (mtext, heaps, prj)	= showUnification unify heaps prj
	= (text +++ "  " +++ mtext, heaps, prj)
showUnification [] heaps prj
	= ("", heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
find :: ![(a, Ptr b)] !a -> (!Bool, !Ptr b) | == a
// -------------------------------------------------------------------------------------------------------------------------------------------------
find [(xa,xb):xs] a
	| xa == a			= (True, xb)
	= find xs a
find [] a
	= (False, nilPtr)

// -------------------------------------------------------------------------------------------------------------------------------------------------
Fresh :: !TypingInfo !a !*CHeaps -> (!TypingInfo, !a, !*CHeaps) | fresh a
// -------------------------------------------------------------------------------------------------------------------------------------------------
Fresh info x heaps
	# (next, x, heaps)					= fresh info.tiNextIndex x heaps
	= ({info & tiNextIndex = next}, x, heaps)


























// -------------------------------------------------------------------------------------------------------------------------------------------------   
TypeBasicValue :: !(CBasicValue a) -> (!Bool, !CBasicType)
// -------------------------------------------------------------------------------------------------------------------------------------------------   
TypeBasicValue (CBasicInteger _)			= (True, CInteger)
TypeBasicValue (CBasicCharacter _)			= (True, CCharacter)
TypeBasicValue (CBasicRealNumber _)			= (True, CRealNumber)
TypeBasicValue (CBasicBoolean _)			= (True, CBoolean) 
TypeBasicValue (CBasicString _)				= (True, CString)
TypeBasicValue other						= (False, DummyValue)

// =================================================================================================================================================
// Adjusts a symbol type to a given number of arguments.
// Example: transforms 1: a->b->c to a->(b->c)
// Example: transforms 3: a->b->(c->d) to a->b->c->d
// -------------------------------------------------------------------------------------------------------------------------------------------------
adjustSymbolType :: !Int !CSymbolTypeH -> CSymbolTypeH
// -------------------------------------------------------------------------------------------------------------------------------------------------
adjustSymbolType wanted_nr_args symboltype
	# nr_args							= length symboltype.sytArguments
	| wanted_nr_args == nr_args			= symboltype
	| wanted_nr_args < nr_args			= decrease wanted_nr_args symboltype
	| wanted_nr_args > nr_args			= increase (wanted_nr_args - nr_args) symboltype
	where
		decrease n symboltype
			# (args, result)			= decrease n symboltype.sytArguments symboltype.sytResult
			= {symboltype & sytArguments = args, sytResult = result}
			where
				decrease 0 args result
					= ([], functionType (args ++ [result]))
				decrease n [arg:args] result
					# (args, result)		= decrease (n-1) args result
					= ([arg:args], result)
		
		increase n symboltype
			# (args, result)			= increase n symboltype.sytResult
			= {symboltype & sytArguments = symboltype.sytArguments ++ args, sytResult = result}
			where
				increase 0 type
					= ([], type)
				increase n (t1 ==> t2)
					# (args, result)	= increase (n-1) t2
					= ([t1:args], t2)
				increase n other
					= ([], other)

// -------------------------------------------------------------------------------------------------------------------------------------------------
flattenType :: ![CTypeH] !CTypeH -> CTypeH
// -------------------------------------------------------------------------------------------------------------------------------------------------
flattenType [arg:args] result
	= arg ==> (flattenType args result)
flattenType [] result
	= result

// Creates fresh expression variables, with fresh types as well.
// -------------------------------------------------------------------------------------------------------------------------------------------------
makeFreshExprArgs :: !TypingInfo ![CExprVarPtr] !*CHeaps -> (!TypingInfo, ![CExprH], !*CHeaps)
// -------------------------------------------------------------------------------------------------------------------------------------------------
makeFreshExprArgs info [old_ptr: old_ptrs] heaps
	# (name, next)						= generateTypeName info.tiNextIndex
	# info								= {info & tiNextIndex = next}
	# fresh_type_def					= {DummyValue & tvarName = name}
	# (fresh_type_ptr, heaps)			= newPointer fresh_type_def heaps
	# (old_var, heaps)					= readPointer old_ptr heaps
	# new_var							= {old_var & evarName = old_var.evarName, evarInfo = EVar_Type (CTypeVar fresh_type_ptr)}
	# (new_ptr, heaps)					= newPointer new_var heaps
	# new_arg							= CExprVar new_ptr
	# (info, new_args, heaps)			= makeFreshExprArgs info old_ptrs heaps
	= (info, [new_arg: new_args], heaps)
makeFreshExprArgs info [] heaps
	= (info, [], heaps)
/*
	# (name, next)						= generateTypeName info.tiNextIndex
	# info								= {info & tiNextIndex = next}
	# type_def							= {DummyValue & tvarName = name}
	# (type_ptr, heaps)					= newPointer type_def heaps
	# (expr_def, heaps)					= readPointer expr_ptr heaps
	# expr_def							= {expr_def & evarInfo = EVar_Type (CTypeVar type_ptr)}
	# heaps								= writePointer expr_ptr expr_def heaps
	# (info, type_ptrs, heaps)			= makeFreshVarTypes info expr_ptrs heaps
	= (info, [type_ptr:type_ptrs], heaps)
*/

// -------------------------------------------------------------------------------------------------------------------------------------------------
makeFreshFunctionType :: !TypingInfo !Int !*CHeaps -> (!TypingInfo, !CTypeH, !*CHeaps)
// -------------------------------------------------------------------------------------------------------------------------------------------------
makeFreshFunctionType info 0 heaps
	# (name, next)						= generateTypeName info.tiNextIndex
	# info								= {info & tiNextIndex = next}
	# def								= {DummyValue & tvarName = name}
	# (ptr, heaps)						= newPointer def heaps
	= (info, CTypeVar ptr, heaps)
makeFreshFunctionType info n heaps
	# (name, next)						= generateTypeName info.tiNextIndex
	# info								= {info & tiNextIndex = next}
	# def								= {DummyValue & tvarName = name}
	# (ptr, heaps)						= newPointer def heaps
	# (info, result, heaps)				= makeFreshFunctionType info (n-1) heaps
	= (info, CTypeVar ptr ==> result, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
makeFreshVarTypes :: !TypingInfo ![CExprVarPtr] !*CHeaps -> (!TypingInfo, ![CTypeVarPtr], !*CHeaps)
// -------------------------------------------------------------------------------------------------------------------------------------------------
makeFreshVarTypes info [] heaps
	= (info, [], heaps)
makeFreshVarTypes info [expr_ptr:expr_ptrs] heaps
	# (name, next)						= generateTypeName info.tiNextIndex
	# info								= {info & tiNextIndex = next}
	# type_def							= {DummyValue & tvarName = name}
	# (type_ptr, heaps)					= newPointer type_def heaps
	# (expr_def, heaps)					= readPointer expr_ptr heaps
	# expr_def							= {expr_def & evarInfo = EVar_Type (CTypeVar type_ptr)}
	# heaps								= writePointer expr_ptr expr_def heaps
	# (info, type_ptrs, heaps)			= makeFreshVarTypes info expr_ptrs heaps
	= (info, [type_ptr:type_ptrs], heaps)

// =================================================================================================================================================
// Expect: an algebraic type or a record type
// Returns: as many allocated type-variables as the ptr expects (its arity)
// -------------------------------------------------------------------------------------------------------------------------------------------------
makeFreshArgs :: !TypingInfo !HeapPtr !*CHeaps !*CProject -> (!TypingInfo, ![CTypeVarPtr], !*CHeaps, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------
makeFreshArgs info ptr heaps prj
	# (_, arity, heaps, prj)			= getDefinitionArity ptr heaps prj
	= fresh_args info arity heaps prj
	where
		fresh_args :: !TypingInfo !Int !*CHeaps !*CProject -> (!TypingInfo, ![CTypeVarPtr], !*CHeaps, !*CProject)
		fresh_args info 0 heaps prj
			= (info, [], heaps, prj)
		fresh_args info n heaps prj
			# (name, next)				= generateTypeName info.tiNextIndex
			# info						= {info & tiNextIndex = next}
			# def						= {DummyValue & tvarName = name}
			# (ptr, heaps)				= newPointer def heaps
			# (info, ptrs, heaps, prj)	= fresh_args info (n-1) heaps prj
			= (info, [ptr:ptrs], heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
setTypeInfos :: ![CExprVarPtr] ![CTypeH] !*CHeaps -> *CHeaps
// -------------------------------------------------------------------------------------------------------------------------------------------------
setTypeInfos [ptr:ptrs] [type:types] heaps
	# (def, heaps)						= readPointer ptr heaps
	# def								= {def & evarInfo = EVar_Type type}
	# heaps								= writePointer ptr def heaps
	= setTypeInfos ptrs types heaps
setTypeInfos _ _ heaps
	= heaps













// -------------------------------------------------------------------------------------------------------------------------------------------------
unifyFeedback :: !CTypeH !CTypeH -> (!Bool, ![(CTypeVarPtr, CTypeH)])
// -------------------------------------------------------------------------------------------------------------------------------------------------
unifyFeedback type1 type2
	#! (type1, type2)					= (type1, type2) --->> (type1, type2)
	= unify type1 type2

// -------------------------------------------------------------------------------------------------------------------------------------------------
class unify a :: !a !a -> (!Bool, ![(CTypeVarPtr, CTypeH)])
// -------------------------------------------------------------------------------------------------------------------------------------------------

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance unify [a] | unify a
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	unify [] []
		= (True, [])
	unify [x:xs] [y:ys]
		# (ok1, unify1)					= unify x y
		# (ok2, unify2)					= unify xs ys
		= (ok1 && ok2, unify1 ++ unify2)
	unify _ _
		= (False, [])

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance unify (CType HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	unify CUnTypable type
		= (True, [])
	unify type CUnTypable
		= (True, [])
	unify (CTypeVar ptr) type
		| CTypeVar ptr == type			= (True, [])
		= (True, [(ptr, type)])
	unify type (CTypeVar ptr)
		= unify (CTypeVar ptr) type
	unify (type1 ==> type2) (type3 ==> type4)
		# (ok1, unify1)					= unify type1 type3
		# (ok2, unify2)					= unify type2 type4
		= (ok1 && ok2, unify1 ++ unify2)
	unify (ptr1 @@^ types1) (ptr2 @@^ types2)
		| ptr1 <> ptr2					= (False, [])
		= unify types1 types2
	unify (type1 @^ types1) (type2 @^ types2)
		# (ok1, unify1)					= unify type1 type2
		# (ok2, unify2)					= unify types1 types2
		= (ok1 && ok2, unify1 ++ unify2)
	unify ((CTypeVar ptr1) @^ types1) (ptr2 @@^ types2)
		# (ok, unify)					= unify types1 types2
		= (ok, [(ptr1, ptr2 @@^ []): unify])
	unify (ptr1 @@^ types1) ((CTypeVar ptr2) @^ types2)
		# (ok, unify)					= unify types1 types2
		= (ok, [(ptr2, ptr1 @@^ []): unify])
	unify (CStrict type1) type2
		= unify type1 type2
	unify type1 (CStrict type2)
		= unify type1 type2
	unify (CBasicType type1) (CBasicType type2)
		| type1 <> type2				= (False, [])
		= (True, [])
	unify (CNormalArrayPtr @@^ [CBasicType CCharacter]) (CBasicType CString)
		= (True, [])
	unify (CStrictArrayPtr @@^ [CBasicType CCharacter]) (CBasicType CString)
		= (True, [])
	unify (CUnboxedArrayPtr @@^ [CBasicType CCharacter]) (CBasicType CString)
		= (True, [])
	unify (CBasicType CString) (CNormalArrayPtr @@^ [CBasicType CCharacter])
		= (True, [])
	unify (CBasicType CString) (CStrictArrayPtr @@^ [CBasicType CCharacter])
		= (True, [])
	unify (CBasicType CString) (CUnboxedArrayPtr @@^ [CBasicType CCharacter])
		= (True, [])
	unify _ _
		= (False, [])

// -------------------------------------------------------------------------------------------------------------------------------------------------
unifiable :: ![CTypeH] -> Bool
// -------------------------------------------------------------------------------------------------------------------------------------------------
unifiable []
	= True
unifiable [type:types]
	= compatable type types  // && (unifiable info types), superfluous!!
	where
		compatable :: !CTypeH ![CTypeH] -> Bool
		compatable type []
			= True
		compatable type1 [type2:types]
			# (ok1, _)					= unify type1 type2
			# ok2						= compatable type1 types
			= ok1 && ok2





























// -------------------------------------------------------------------------------------------------------------------------------------------------
solveUnification :: !TypingInfo -> (!Bool, !Substitution)
// -------------------------------------------------------------------------------------------------------------------------------------------------
solveUnification info
	# (ok, sub)						= solve [] info.tiUnify
	| not ok						= (False /*--->> "not unified"*/, DummyValue)
	| not (validate sub)			= (False /*--->> "not validated"*/, DummyValue)
	= (True, sub)
	where
		solve :: ![CTypeVarPtr] ![(CTypeVarPtr, CTypeH)] -> (!Bool, !Substitution)
		solve passed unify
//			#! passed				= passed --->> length passed
			# (ok, unpassed_var)	= find_unpassed_var passed unify
			| not ok				= (True, {DummyValue & subTypeVars = unify})
			# (results, unify)		= remove_var_results unpassed_var unify
			# (ok, unified_result)	= findMostSpecific results
			| not ok				= (False, DummyValue) // --->> length results
			# unify					= fill_in {DummyValue & subTypeVars = [(unpassed_var, unified_result)]} unify
			# (ok, unify)			= extend unify unpassed_var unified_result results
			| not ok				= (False, DummyValue)
			= solve [unpassed_var:passed] unify
		
		find_unpassed_var :: ![CTypeVarPtr] ![(CTypeVarPtr, CTypeH)] -> (!Bool, !CTypeVarPtr)
		find_unpassed_var passed [(ptr,type):unify]
			| isMember ptr passed	= find_unpassed_var passed unify
			= (True, ptr)
		find_unpassed_var passed []
			= (False, nilPtr)
		
		remove_var_results :: !CTypeVarPtr ![(CTypeVarPtr, CTypeH)] -> (![CTypeH], ![(CTypeVarPtr, CTypeH)])
		remove_var_results ptr1 [(ptr2,type2): unify]
			# (results, unify)		= remove_var_results ptr1 unify
			= case ptr1 == ptr2 of
				True				-> ([type2:results], unify)
				False				-> (results, [(ptr2,type2):unify])
		remove_var_results ptr []
			= ([], [])
		
		fill_in :: !Substitution ![(CTypeVarPtr, CTypeH)] -> [(CTypeVarPtr, CTypeH)]
		fill_in sub [(ptr,type):unify]
			# type					= SimpleSubst sub type
			# unify					= fill_in sub unify
			= [(ptr,type):unify]
		fill_in sub []
			= []
		
		extend :: ![(CTypeVarPtr, CTypeH)] !CTypeVarPtr !CTypeH ![CTypeH] -> (!Bool, ![(CTypeVarPtr, CTypeH)])
		extend initial_unify var rhs [type:types]
			| type == rhs			= extend initial_unify var rhs types
			# (ok, extra_unify)		= unify type rhs
			| not ok				= (False, DummyValue)
			= extend (initial_unify ++ extra_unify) var rhs types
		extend unify var rhs []
			= (True, [(var,rhs): unify])
		
		// checks for substitutions of the form a = ... a ... , i.e. a = [a]
		validate :: !Substitution -> Bool
		validate sub=:{subTypeVars}
			= check subTypeVars
			where
				check :: ![(CTypeVarPtr, CTypeH)] -> Bool
				check [(_,CTypeVar _):sub]
					= check sub
				check [(ptr, type):sub]
					= case present ptr type of
						True	-> False
						False	-> check sub
				check []
					= True
				
				present :: !CTypeVarPtr !CTypeH -> Bool
				present ptr1 (CTypeVar ptr2)
					= ptr1 == ptr2
				present ptr (type1 ==> type2)
					= present ptr type1 || present ptr type2
				present ptr (type @^ types)
					= present ptr type || or (map (present ptr) types)
				present ptr (_ @@^ types)
					= or (map (present ptr) types)
				present ptr (CStrict type)
					= present ptr type
				present ptr (CBasicType _)
					= False
				present ptr CUnTypable
					= False

// =================================================================================================================================================
// Checks if a list of types is 'compatable' (i.e. can possibly be the same).
// If so, returns the most specific version present in the list.
// -------------------------------------------------------------------------------------------------------------------------------------------------
findMostSpecific :: ![CTypeH] -> (!Bool, !CTypeH)
// -------------------------------------------------------------------------------------------------------------------------------------------------
findMostSpecific []
	= (False, DummyValue)
findMostSpecific [type:types]
	= merge_most_specific type types
	where
		merge_most_specific :: !CTypeH ![CTypeH] -> (!Bool, !CTypeH)
		merge_most_specific type []
			= (True, type)
		merge_most_specific type1 [type2:types]
			# (ok, type3)				= mergeTypes type1 type2
			| not ok					= (False, DummyValue)
			= merge_most_specific type3 types
	/*
	= find list list
	where
		find :: ![CTypeH] ![CTypeH] -> (!Bool, !CTypeH)
		find [] types
			= (False, DummyValue)
		find [type1:types1] types2
			# bools						= map (isMoreSpecific type1) types2
			| and bools					= (True, type1)
			= find types1 types2
		
		// returns true if types are unifiable and the first type is more specific than the second
		isMoreSpecific :: !CTypeH !CTypeH -> Bool
		isMoreSpecific type (CTypeVar ptr)
			= True
		isMoreSpecific (type1 ==> type2) (type3 ==> type4)
			= (isMoreSpecific type1 type3) && (isMoreSpecific type2 type4)
		isMoreSpecific (type1 @^ types1) (type2 @^ types2)
			= (isMoreSpecific type1 type2) && (isMoreSpecificL types1 types2)
		isMoreSpecific (ptr1 @@^ types1) (ptr2 @@^ types2)
			| ptr1 <> ptr2				= False
			= isMoreSpecificL types1 types2
		isMoreSpecific (ptr1 @@^ types1) ((CTypeVar ptr2) @^ types2)
			= isMoreSpecificL types1 types2
		isMoreSpecific other1 other2
			= other1 == other2
		
		isMoreSpecificL :: ![CTypeH] ![CTypeH] -> Bool
		isMoreSpecificL [] []
			= True
		isMoreSpecificL [type1:types1] [type2:types2]
			= (isMoreSpecific type1 type2) && (isMoreSpecificL types1 types2)
		*/
		
		// tries to merge two generic types to their most specific common divisor
		// for example: mergeTypes (Int->a, b->Bool) = Int->Bool
		mergeTypes :: !CTypeH !CTypeH -> (!Bool, !CTypeH)
		mergeTypes (type1 @^ []) type2
			= mergeTypes type1 type2
		mergeTypes type1 (type2 @^ [])
			= mergeTypes type1 type2
		mergeTypes (CTypeVar ptr) type
			= (True, type)
		mergeTypes type (CTypeVar ptr)
			= (True, type)
		mergeTypes (type1 ==> type2) (type3 ==> type4)
			# (ok, type5)				= mergeTypes type1 type3
			| not ok					= (False, DummyValue)
			# (ok, type6)				= mergeTypes type2 type4
			| not ok					= (False, DummyValue)
			= (True, type5 ==> type6)
		mergeTypes (ptr1 @@^ types1) (ptr2 @@^ types2)
			| ptr1 <> ptr2				= (False, DummyValue)
			# (ok, types3)				= mergeTypesL types1 types2
			| not ok					= (False, DummyValue)
			= (True, ptr1 @@^ types3)
		mergeTypes ((CTypeVar _) @^ types1) (ptr @@^ types2)
			# (ok, types3)				= mergeTypesL types1 types2
			| not ok					= (False, DummyValue)
			= (True, ptr @@^ types3)
		mergeTypes (ptr @@^ types1) ((CTypeVar _) @^ types2)
			# (ok, types3)				= mergeTypesL types1 types2
			| not ok					= (False, DummyValue)
			= (True, ptr @@^ types3)
		mergeTypes (type1 @^ types1) (type2 @^ types2)
			# (ok, type3)				= mergeTypes type1 type2
			| not ok					= (False, DummyValue)
			# (ok, types3)				= mergeTypesL types1 types2
			| not ok					= (False, DummyValue)
			= (True, type3 @^ types3)
		mergeTypes (CBasicType basictype1) (CBasicType basictype2)
			| basictype1 == basictype2	= (True, CBasicType basictype1)
			= (False, DummyValue)
		mergeTypes CUnTypable CUnTypable
			= (True, CUnTypable)
		mergeTypes (CNormalArrayPtr @@^ [CBasicType CCharacter]) (CBasicType CString)
			= (True, CBasicType CString)
		mergeTypes (CStrictArrayPtr @@^ [CBasicType CCharacter]) (CBasicType CString)
			= (True, CBasicType CString)
		mergeTypes (CUnboxedArrayPtr @@^ [CBasicType CCharacter]) (CBasicType CString)
			= (True, CBasicType CString)
		mergeTypes (CBasicType CString) (CNormalArrayPtr @@^ [CBasicType CCharacter])
			= (True, CBasicType CString)
		mergeTypes (CBasicType CString) (CStrictArrayPtr @@^ [CBasicType CCharacter])
			= (True, CBasicType CString)
		mergeTypes (CBasicType CString) (CUnboxedArrayPtr @@^ [CBasicType CCharacter])
			= (True, CBasicType CString)
		mergeTypes _ _
			= (False, DummyValue)
		
		mergeTypesL :: ![CTypeH] ![CTypeH] -> (!Bool, ![CTypeH])
		mergeTypesL [] []
			= (True, [])
		mergeTypesL [type1:types1] [type2:types2]
			# (ok, type3)				= mergeTypes type1 type2
			| not ok					= (False, DummyValue)
			# (ok, types3)				= mergeTypesL types1 types2
			| not ok					= (False, DummyValue)
			= (True, [type3:types3])
		mergeTypesL _ _
			= (False, DummyValue)





















// =================================================================================================================================================
// Preconditions:
//  -  Free expression variables must have a EVar_Type value in the heap.
//  -  The EVar_Type value in the heap will be set for bound expression variables.
//  -  No cycles may be present.
// Remark:
//  -  All strictness information is IGNORED.
// -------------------------------------------------------------------------------------------------------------------------------------------------
class checkType a :: !TypingInfo !CTypeH !a !*CHeaps !*CProject -> (!Error, !TypingInfo, !*CHeaps, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------

// -------------------------------------------------------------------------------------------------------------------------------------------------
checkDifferentTypes :: !TypingInfo ![CTypeH] ![a] !*CHeaps !*CProject -> (!Error, !TypingInfo, !*CHeaps, !*CProject) | checkType a
// -------------------------------------------------------------------------------------------------------------------------------------------------
checkDifferentTypes info [] [] heaps prj
	= (OK, info, heaps, prj)
checkDifferentTypes info [type:types] [expr:exprs] heaps prj
	# (error, info, heaps, prj)			= checkType info type expr heaps prj
	| isError error						= (error, info, heaps, prj)
	= checkDifferentTypes info types exprs heaps prj
checkDifferentTypes info _ _ heaps prj
	= (pushError (X_Type "Nr of arguments of application does not match type.") OK, info, heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance checkType [a] | checkType a
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	checkType info demanded [] heaps prj
		= (OK, info, heaps, prj)
	checkType info demanded [type:types] heaps prj
		# (error, info, heaps, prj)		= checkType info demanded type heaps prj
		| isError error					= (error, info, heaps, prj)
		= checkType info demanded types heaps prj

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance checkType (Maybe a) | checkType a
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	checkType info demanded Nothing heaps prj
		= (OK, info, heaps, prj)
	checkType info demanded (Just x) heaps prj
		= checkType info demanded x heaps prj

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance checkType (CExpr HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	checkType info (CStrict type) expr heaps prj
		= checkType info type expr heaps prj
	checkType info demanded (CExprVar ptr) heaps prj
		# (def, heaps)					= readPointer ptr heaps
		# (has_type, type)				= read_type def.evarInfo
		| not has_type					= (pushError (X_Type (error_msg1 def.evarName)) OK, info, heaps, prj)
		# (ok, unification)				= unify demanded type
		| not ok						= (pushError (X_Type (error_msg2 def.evarName)) OK, info, heaps, prj)
		= (OK, {info & tiUnify = unification ++ info.tiUnify}, heaps, prj)
		where
			read_type :: !CExprVarInfo -> (!Bool, !CTypeH)
			read_type (EVar_Type type)	= (True, type)
			read_type other				= (False, DummyValue)
			
			error_msg1 name => "No type available for free expression variable " +++ name +++ "."
			error_msg2 name => "Conflicting types for free expression variable " +++ name +++ "."
	checkType info demanded (CShared ptr) heaps prj
		# (shared, heaps)				= readPointer ptr heaps
		= checkType info demanded shared.shExpr heaps prj
	checkType info demanded (expr @# exprs) heaps prj
		# (info, fun_type, heaps)		= makeFreshFunctionType info (length exprs) heaps
		# (error, info, heaps, prj)		= checkType info fun_type expr heaps prj
		| isError error					= (error, info, heaps, prj)
		# (arg_types, result_type)		= disect fun_type
		# (error, info, heaps, prj)		= checkDifferentTypes info arg_types exprs heaps prj
		| isError error					= (error, info, heaps, prj)
		# (_, unification)				= unify demanded result_type
		= (OK, {info & tiUnify = unification ++ info.tiUnify}, heaps, prj)
		where
			disect :: !CTypeH -> (![CTypeH], !CTypeH)
			disect (t1 ==> t2)
				# (args, result)		= disect t2
				= ([t1:args], result)
			disect other
				= ([], other)
	checkType info demanded (ptr @@# exprs) heaps prj
		# (error, symboltype, heaps, prj)	= getSymbolType ptr heaps prj
		| isError error					= (error, info, heaps, prj)
		# (info, symboltype, heaps)		= Fresh info symboltype heaps
		# symboltype					= removeStrictness symboltype
		# symboltype					= adjustSymbolType (length exprs) symboltype
//		# info							= {info & tiSymbolTypes = info.tiSymbolTypes ++ [symboltype]}
		// compensate for valid applications on more arguments than arity (i.e. undef 7)
		# (info, fun_type, heaps)		= makeFreshFunctionType info (length exprs) heaps
		# fun_symbol_type				= flattenType symboltype.sytArguments symboltype.sytResult
		# (ok, unification)				= unify fun_type fun_symbol_type
		| not ok						= generate_arity_error ptr info heaps prj
		# info							= {info & tiUnify = unification ++ info.tiUnify}
		# (args, result)				= disect fun_type
		// the added symboltype is dangerous! watch it!
		# symboltype					= adjust_symbol_type_arguments symboltype args
		# info							= {info & tiSymbolTypes = info.tiSymbolTypes ++ [symboltype]}
		// end compensate
		# (error, info, heaps, prj)		= checkDifferentTypes info args exprs heaps prj
		| isError error					= (error, info, heaps, prj)
		# (ok, unification)				= unify demanded result
		| not ok						= generate_error ptr info heaps prj
		= (OK, {info & tiUnify = unification ++ info.tiUnify}, heaps, prj)
		where
			disect :: !CTypeH -> (![CTypeH], !CTypeH)
			disect (t1 ==> t2)
				# (args, result)		= disect t2
				= ([t1:args], result)
			disect other
				= ([], other)
			
			// only needed in case the arity of the symboltype is too low
			adjust_symbol_type_arguments :: !CSymbolTypeH ![CTypeH] -> CSymbolTypeH
			adjust_symbol_type_arguments symboltype=:{sytArguments} new_args
				| length sytArguments >= length new_args
										= symboltype
				# first					= take (length sytArguments - 1) sytArguments
				# rest					= drop (length sytArguments - 1) new_args
				# symboltype			= {symboltype & sytArguments = first ++ rest}
				= symboltype
			
			generate_error ptr info heaps prj
				# (error, name, heaps, prj)		= getDefinitionName ptr heaps prj
				| isError error					= (error, info, heaps, prj)
				= (pushError (X_Type ("Could not unify result type of '" +++ name +++ "'.")) OK, info, heaps, prj)
			
			generate_arity_error ptr info heaps prj
				# (error, name, heaps, prj)		= getDefinitionName ptr heaps prj
				| isError error					= (error, info, heaps, prj)
				= (pushError (X_Type ("Invalid number of arguments of symbol '" +++ name +++ "'.")) OK, info, heaps, prj)
	checkType info demanded (CLet _ lets expr) heaps prj
		# (vars, exprs)					= unzip lets
		# (info, var_types, heaps)		= makeFreshVarTypes info vars heaps
		# let_types						= map CTypeVar var_types
		# (error, info, heaps, prj)		= checkDifferentTypes info let_types exprs heaps prj
		| isError error					= (error, info, heaps, prj)
		# (error, info, heaps, prj)		= checkType info demanded expr heaps prj
		| isError error					= (error, info, heaps, prj)
		= (OK, info, heaps, prj)
	checkType info demanded (CCase expr (CBasicPatterns type patterns) def) heaps prj
		# (error, info, heaps, prj)		= checkType info (CBasicType type) expr heaps prj
		| isError error					= (error, info, heaps, prj)
		# results						= map (\bap -> bap.bapResult) patterns
		# (error, info, heaps, prj)		= checkType info demanded results heaps prj
		| isError error					= (error, info, heaps, prj)
		# (error, info, heaps, prj)		= checkType info demanded def heaps prj
		| isError error					= (error, info, heaps, prj)
		= (OK, info, heaps, prj)
	checkType info demanded (CCase expr (CAlgPatterns ptr patterns) def) heaps prj
		# (info, alg_args, heaps, prj)	= makeFreshArgs info ptr heaps prj
		# alg_type						= ptr @@^ (map CTypeVar alg_args)
		# (error, info, heaps, prj)		= checkType info alg_type expr heaps prj
		| isError error					= (error, info, heaps, prj)
		# (error, info, heaps, prj)		= checkPatterns info alg_type demanded patterns heaps prj
		| isError error					= (error, info, heaps, prj)
		# (error, info, heaps, prj)		= checkType info demanded def heaps prj
		| isError error					= (error, info, heaps, prj)
		= (OK, info, heaps, prj)
		where
			checkPatterns :: !TypingInfo !CTypeH !CTypeH ![CAlgPatternH] !*CHeaps !*CProject -> (!Error, !TypingInfo, !*CHeaps, !*CProject)
			checkPatterns info alg_type demanded [] heaps prj
				= (OK, info, heaps, prj)
			checkPatterns info alg_type demanded [pattern:patterns] heaps prj
				# old_scope						= pattern.atpExprVarScope
				# (info, fresh_args, heaps)		= makeFreshExprArgs info old_scope heaps
				# (error, info, heaps, prj)		= checkType info alg_type (pattern.atpDataCons @@# fresh_args) heaps prj
				| isError error					= (error, info, heaps, prj)
				# (fresh_result, heaps)			= SafeSubst {DummyValue & subExprVars = zip2 old_scope fresh_args} pattern.atpResult heaps
				# (error, info, heaps, prj)		= checkType info demanded fresh_result heaps prj
				| isError error					= (error, info, heaps, prj)
				= checkPatterns info alg_type demanded patterns heaps prj
	// BEZIG -- dit is nog geen correct gedrag
	checkType info demanded (CBasicValue (CBasicArray exprs)) heaps prj
		# (name, next)					= generateTypeName info.tiNextIndex
		# info							= {info & tiNextIndex = next}
		# el_def						= {DummyValue & tvarName = name}
		# (el_type, heaps)				= newPointer el_def heaps
		# (error, info, heaps, prj)		= checkType info (CTypeVar el_type) exprs heaps prj
		| isError error					= (error, info, heaps, prj)
		# (ok, unification)				= unify demanded (CNormalArrayPtr @@^ [CTypeVar el_type])
		| not ok						= (pushError (X_Internal "Could not type array denotation; no array offered.") OK, info, heaps, prj)
		= (OK, {info & tiUnify = unification ++ info.tiUnify}, heaps, prj)
//		where
//			get_array_type :: !CTypeH !*CHeaps -> (!Bool, !CTypeH, !*CHeaps)
//			get_array_type (CNormalArrayPtr @@^ [type])		= (True, type)
//			get_array_type (CStrictArrayPtr @@^ [type])		= (True, type)
//			get_array_type (CUnboxedArrayPtr @@^ [type])	= (True, type)
//			get_array_type (CBasicType CString)				= (True, CBasicType CCharacter)
//			get_array_type other							= (False, DummyValue)
	checkType info demanded (CBasicValue value) heaps prj
		# (ok, type)					= TypeBasicValue value
		| not ok						= (pushError (X_Type "Could not type basic value.") OK, info, heaps, prj)
		# (ok, unification)				= unify demanded (CBasicType type)
		| not ok						= (pushError (X_Type "Could not unify basic value.") OK, info, heaps, prj)
		= (OK, {info & tiUnify = unification ++ info.tiUnify}, heaps, prj)
	checkType info demanded (CCode codetext codecontents) heaps prj
		= (pushError (X_Type "Could not type abc-code.") OK, info, heaps, prj)
	checkType info demanded CBottom heaps prj
		= (OK, info, heaps, prj)

// =================================================================================================================================================
// Types all subexpressions of a proposition.
// Creates the 'demanded' types itself.
// -------------------------------------------------------------------------------------------------------------------------------------------------
checkProp :: !TypingInfo !CPropH ![(CName, CTypeH)] !*CHeaps !*CProject -> (!Error, !TypingInfo, !*CHeaps, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------
checkProp info CTrue var_types heaps prj
	= (OK, info, heaps, prj)
checkProp info CFalse var_types heaps prj
	= (OK, info, heaps, prj)
checkProp info (CPropVar ptr) var_types heaps prj
	= (OK, info, heaps, prj)
checkProp info (CNot p) var_types heaps prj
	= checkProp info p var_types heaps prj
checkProp info (CAnd p q) var_types heaps prj
	# (error, info, heaps, prj)			= checkProp info p var_types heaps prj
	| isError error						= (error, info, heaps, prj)
	# (error, info, heaps, prj)			= checkProp info q var_types heaps prj
	| isError error						= (error, info, heaps, prj)
	= (OK, info, heaps, prj)
checkProp info (COr p q) var_types heaps prj
	# (error, info, heaps, prj)			= checkProp info p var_types heaps prj
	| isError error						= (error, info, heaps, prj)
	# (error, info, heaps, prj)			= checkProp info q var_types heaps prj
	| isError error						= (error, info, heaps, prj)
	= (OK, info, heaps, prj)
checkProp info (CImplies p q) var_types heaps prj
	# (error, info, heaps, prj)			= checkProp info p var_types heaps prj
	| isError error						= (error, info, heaps, prj)
	# (error, info, heaps, prj)			= checkProp info q var_types heaps prj
	| isError error						= (error, info, heaps, prj)
	= (OK, info, heaps, prj)
checkProp info (CIff p q) var_types heaps prj
	# (error, info, heaps, prj)			= checkProp info p var_types heaps prj
	| isError error						= (error, info, heaps, prj)
	# (error, info, heaps, prj)			= checkProp info q var_types heaps prj
	| isError error						= (error, info, heaps, prj)
	= (OK, info, heaps, prj)
checkProp info (CExprForall ptr p) [] heaps prj
	# (info, _, heaps)					= makeFreshVarTypes info [ptr] heaps
	= checkProp info p [] heaps prj
checkProp info (CExprForall ptr p) var_types heaps prj
	# (var, heaps)						= readPointer ptr heaps
	= check var var_types heaps prj
	where
		check var [(name,type):more] heaps prj
			| var.evarName <> name		= check var more heaps prj
			# var						= {var & evarInfo = EVar_Type type}
			# heaps						= writePointer ptr var heaps
			= checkProp info p var_types heaps prj
		check var [] heaps prj
			# (info, _, heaps)			= makeFreshVarTypes info [ptr] heaps
			= checkProp info p var_types heaps prj
checkProp info (CExprExists ptr p) [] heaps prj
	# (info, _, heaps)					= makeFreshVarTypes info [ptr] heaps
	= checkProp info p [] heaps prj
checkProp info (CExprExists ptr p) var_types heaps prj
	# (var, heaps)						= readPointer ptr heaps
	= check var var_types heaps prj
	where
		check var [(name,type):more] heaps prj
			| var.evarName <> name		= check var more heaps prj
			# var						= {var & evarInfo = EVar_Type type}
			# heaps						= writePointer ptr var heaps
			= checkProp info p var_types heaps prj
		check var [] heaps prj
			# (info, _, heaps)			= makeFreshVarTypes info [ptr] heaps
			= checkProp info p var_types heaps prj
checkProp info (CPropForall _ p) var_types heaps prj
	= checkProp info p var_types heaps prj
checkProp info (CPropExists _ p) var_types heaps prj
	= checkProp info p var_types heaps prj
checkProp info (CEqual e1 e2) var_types heaps prj
	# (name, next)						= generateTypeName info.tiNextIndex
	# info								= {info & tiNextIndex = next}
	# def								= {DummyValue & tvarName = name}
	# (ptr, heaps)						= newPointer def heaps
	# info								= {info & tiEqualType = ptr}
	= checkType info (CTypeVar ptr) [e1,e2] heaps prj
// nothing is done here as yet; has to be updated
checkProp info (CPredicate ptr exprs) var_types heaps prj
	= (OK, info, heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
checkHyps :: !TypingInfo ![HypothesisPtr] !*CHeaps !*CProject -> (!Error, !TypingInfo, !*CHeaps, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------
checkHyps info [ptr:ptrs] heaps prj
	# (hyp, heaps)						= readPointer ptr heaps
	# (error, info, heaps, prj)			= checkProp info hyp.hypProp [] heaps prj
	| isError error						= (error, info, heaps, prj)
	= checkHyps info ptrs heaps prj
checkHyps info [] heaps prj
	= (OK, info, heaps, prj)






























// =================================================================================================================================================
// Precondition: of all free expression-variables, the EVar_Type field must be set.
// -------------------------------------------------------------------------------------------------------------------------------------------------
typeExpr :: !CExprH !*CHeaps !*CProject -> (!Error, !(!TypingInfo, !CTypeH), !*CHeaps, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------
typeExpr expr heaps prj
	# info								= DummyValue
	# demanded_def						= {DummyValue & tvarName = "_demanded"}
	# (demanded_ptr, heaps)				= newPointer demanded_def heaps
	# (error, info, heaps, prj)			= checkType info (CTypeVar demanded_ptr) expr heaps prj
	| isError error						= (error, (info, DummyValue), heaps, prj)
	# (ok, sub)							= solveUnification info
//	# (ok, sub, heaps, prj)				= solveUnification2 info heaps prj
	| not ok							= (pushError (X_Type "Could not solve unification.") OK, (info, DummyValue), heaps, prj)
	# info								= {info & tiSymbolTypes = map (SimpleSubst sub) info.tiSymbolTypes}
	# result_type						= SimpleSubst sub (CTypeVar demanded_ptr)
	= (OK, (info, result_type), heaps, prj)

// =================================================================================================================================================
// Precondition: of all free expression-variables, the EVar_Type field must be set.
// -------------------------------------------------------------------------------------------------------------------------------------------------
typeProp :: !CPropH ![(CName, CTypeH)] !*CHeaps !*CProject -> (!Error, !TypingInfo, !*CHeaps, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------
typeProp prop var_types heaps prj
	# (error, info, heaps, prj)			= checkProp DummyValue prop var_types heaps prj
	| isError error						= (error, info, heaps, prj)
	# (ok, sub)							= solveUnification info
	| not ok							= (pushError (X_Type "Could not solve unification.") OK, info, heaps, prj)
	# info								= {info & tiSymbolTypes = map (SimpleSubst sub) info.tiSymbolTypes}
	= (OK, info, heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
wellTyped :: !Goal !*CHeaps !*CProject -> (!Error, !Substitution, !TypingInfo, !*CHeaps, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------
wellTyped goal heaps prj
	# info								= DummyValue
	# (info, _, heaps)					= makeFreshVarTypes info goal.glExprVars heaps
	# (error, info, heaps, prj)			= checkHyps info goal.glHypotheses heaps prj
	| isError error						= (error, DummyValue, info, heaps, prj)
	# (error, info, heaps, prj)			= checkProp info goal.glToProve [] heaps prj
	| isError error						= (error, DummyValue, info, heaps, prj)
	# (ok, sub)							= solveUnification info
	| not ok							= ([X_Type "Unable to solve unification."], DummyValue, info, heaps, prj)
	# info								= {info & tiSymbolTypes = map (SimpleSubst sub) info.tiSymbolTypes}
	= (OK, sub, info, heaps, prj)

// WARNING: The tiSymbolTypes field is determined completely by the expression.
// -------------------------------------------------------------------------------------------------------------------------------------------------
typeExprInGoal :: !CExprH !Goal !*CHeaps !*CProject -> (!Error, !(!TypingInfo, !CTypeH), !*CHeaps, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------
typeExprInGoal expr goal heaps prj
	# info								= DummyValue
	# evars								= goal.glExprVars
	# (info, _, heaps)					= makeFreshVarTypes info evars heaps
	# demanded_def						= {DummyValue & tvarName = "_demanded"}
	# (demanded_ptr, heaps)				= newPointer demanded_def heaps
	# (error, info, heaps, prj)			= checkHyps info goal.glHypotheses heaps prj
	| isError error						= (error, DummyValue, heaps, prj)
	# (error, info, heaps, prj)			= checkProp info goal.glToProve [] heaps prj
	| isError error						= (error, DummyValue, heaps, prj)
	# info								= {info & tiSymbolTypes = []}
	# (error, info, heaps, prj)			= checkType info (CTypeVar demanded_ptr) expr heaps prj
	| isError error						= (error, DummyValue, heaps, prj)
	# (ok, sub)							= solveUnification info
	| not ok							= (pushError (X_Type "Could not solve unification.") OK, DummyValue, heaps, prj)
	# result_type						= SimpleSubst sub (CTypeVar demanded_ptr)
	# info								= {info & tiSymbolTypes = map (SimpleSubst sub) info.tiSymbolTypes}
	= (OK, (info, result_type), heaps, prj)

// WARNING: The tiSymbolTypes field is determined completely by the expression.
// -------------------------------------------------------------------------------------------------------------------------------------------------
typePropInGoal :: !CPropH !Goal ![(CName, CTypeH)] !*CHeaps !*CProject -> (!Error, !TypingInfo, !*CHeaps, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------
typePropInGoal prop goal var_types heaps prj
	# info								= DummyValue
	# evars								= goal.glExprVars
	# (info, _, heaps)					= makeFreshVarTypes info evars heaps
	# (error, info, heaps, prj)			= checkHyps info goal.glHypotheses heaps prj
	| isError error						= (error, DummyValue, heaps, prj)
	# (error, info, heaps, prj)			= checkProp info goal.glToProve [] heaps prj
	| isError error						= (error, DummyValue, heaps, prj)
	# info								= {info & tiSymbolTypes = []}
	# (error, info, heaps, prj)			= checkProp info prop var_types heaps prj
	| isError error						= (error, DummyValue, heaps, prj)
	# (ok, sub)							= solveUnification info
	| not ok							= (pushError (X_Type "Could not solve unification.") OK, DummyValue, heaps, prj)
	# info								= {info & tiSymbolTypes = map (SimpleSubst sub) info.tiSymbolTypes}
	= (OK, info, heaps, prj)