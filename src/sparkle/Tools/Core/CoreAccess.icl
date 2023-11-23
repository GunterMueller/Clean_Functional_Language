/*
** Program: Clean Prover System
** Module:  CoreAccess (.icl)
** 
** Author:  Maarten de Mol
** Created: 23 August 2000
*/

implementation module 
	CoreAccess

import
	StdEnv,
	CoreTypes,
	Predefined
	, RWSDebug

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: DefinitionInfo =
// -------------------------------------------------------------------------------------------------------------------------------------------------
	{ diPointer			:: !HeapPtr
	, diInfix			:: !Bool							// hack -- is handy!
	, diKind			:: !DefinitionKind
	, diModuleName		:: !CName
	, diName			:: !CName
	, diArity			:: !CArity
	}
instance DummyValue DefinitionInfo
	where DummyValue =  {diPointer = DummyValue, diInfix = DummyValue, diKind = DummyValue
						,diModuleName = DummyValue, diName = DummyValue, diArity = DummyValue}

























// -------------------------------------------------------------------------------------------------------------------------------------------------
getAlgTypeDef :: !HeapPtr !*CProject -> (!Error, !CAlgTypeDefH, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------
getAlgTypeDef (CAlgTypePtr _ ptr) prj
	# (def, heap)					= readPtr ptr prj.prjAlgTypeHeap
	# prj							= {prj & prjAlgTypeHeap = heap}
	= (OK, def, prj)
getAlgTypeDef (CTuplePtr arity) prj
	# (tuple, prj)					= prj!prjPredefined.preTuple
	= (OK, tuple arity, prj)
getAlgTypeDef CNormalArrayPtr prj
	# (array, prj)					= prj!prjPredefined.preNormalArray
	= (OK, array, prj)
getAlgTypeDef CStrictArrayPtr prj
	# (array, prj)					= prj!prjPredefined.preStrictArray
	= (OK, array, prj)
getAlgTypeDef CUnboxedArrayPtr prj
	# (array, prj)					= prj!prjPredefined.preUnboxedArray
	= (OK, array, prj)
getAlgTypeDef CListPtr prj
	# (list, prj)					= prj!prjPredefined.preList
	= (OK, list, prj)
getAlgTypeDef other project
	= (pushError (X_Internal "Expected a pointer to an algebraic type in module CoreAccess(get).") OK, DummyValue, project)

// -------------------------------------------------------------------------------------------------------------------------------------------------
getClassDef :: !HeapPtr !*CProject -> (!Error, !CClassDefH, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------
getClassDef (CClassPtr _ ptr) prj
	# (def, heap)					= readPtr ptr prj.prjClassHeap
	# prj							= {prj & prjClassHeap = heap}
	= (OK, def, prj)
getClassDef CTCPtr prj
	# (tc, prj)						= prj!prjPredefined.preTC
	= (OK, tc, prj)
getClassDef other project
	= (pushError (X_Internal "Expected a pointer to a class in module CoreAccess(get).") OK, DummyValue, project)

// -------------------------------------------------------------------------------------------------------------------------------------------------
getDataConsDef :: !HeapPtr !*CProject -> (!Error, !CDataConsDefH, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------
getDataConsDef (CDataConsPtr _ ptr) prj
	# (def, heap)					= readPtr ptr prj.prjDataConsHeap
	# prj							= {prj & prjDataConsHeap = heap}
	= (OK, def, prj)
getDataConsDef (CBuildTuplePtr arity) prj
	# (build_tuple, prj)			= prj!prjPredefined.preBuildTuple
	= (OK, build_tuple arity, prj)
getDataConsDef CNilPtr prj
	# (nil, prj)					= prj!prjPredefined.preNil
	= (OK, nil, prj)
getDataConsDef CConsPtr prj
	# (cons, prj)					= prj!prjPredefined.preCons
	= (OK, cons, prj)
getDataConsDef other project
	= (pushError (X_Internal "Expected a pointer to a data-contructor in module CoreAccess(get).") OK, DummyValue, project)

// -------------------------------------------------------------------------------------------------------------------------------------------------
getFunDef :: !HeapPtr !*CProject -> (!Error, !CFunDefH, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------
getFunDef (CFunPtr _ ptr) prj
	# (def, heap)					= readPtr ptr prj.prjFunHeap
	# prj							= {prj & prjFunHeap = heap}
	= (OK, def, prj)
getFunDef (CTupleSelectPtr arity index) prj
	# (tuple_select, prj)			= prj!prjPredefined.preTupleSelect
	= (OK, tuple_select arity index, prj)
getFunDef other project
	= (pushError (X_Internal "Expected a pointer to a function in module CoreAccess(get).") OK, DummyValue, project)

// -------------------------------------------------------------------------------------------------------------------------------------------------
getInstanceDef :: !HeapPtr !*CProject -> (!Error, !CInstanceDefH, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------
getInstanceDef (CInstancePtr _ ptr) prj
	# (def, heap)					= readPtr ptr prj.prjInstanceHeap
	# prj							= {prj & prjInstanceHeap = heap}
	= (OK, def, prj)
getInstanceDef other project
	= (pushError (X_Internal "Expected a pointer to an instance in module CoreAccess(get).") OK, DummyValue, project)

// -------------------------------------------------------------------------------------------------------------------------------------------------
getMemberDef :: !HeapPtr !*CProject -> (!Error, !CMemberDefH, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------
getMemberDef (CMemberPtr _ ptr) prj
	# (def, heap)					= readPtr ptr prj.prjMemberHeap
	# prj							= {prj & prjMemberHeap = heap}
	= (OK, def, prj)
getMemberDef other project
	= (pushError (X_Internal "Expected a pointer to a member in module CoreAccess(get).") OK, DummyValue, project)

// -------------------------------------------------------------------------------------------------------------------------------------------------
getRecordFieldDef :: !HeapPtr !*CProject -> (!Error, !CRecordFieldDefH, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------
getRecordFieldDef (CRecordFieldPtr _ ptr) prj
	# (def, heap)					= readPtr ptr prj.prjRecordFieldHeap
	# prj							= {prj & prjRecordFieldHeap = heap}
	= (OK, def, prj)
getRecordFieldDef other project
	= (pushError (X_Internal "Expected a pointer to a record field in module CoreAccess(get).") OK, DummyValue, project)

// -------------------------------------------------------------------------------------------------------------------------------------------------
getRecordTypeDef :: !HeapPtr !*CProject -> (!Error, !CRecordTypeDefH, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------
getRecordTypeDef (CRecordTypePtr _ ptr) prj
	# (def, heap)					= readPtr ptr prj.prjRecordTypeHeap
	# prj							= {prj & prjRecordTypeHeap = heap}
	= (OK, def, prj)
getRecordTypeDef CTCDictPtr prj
	# (tc_dict, prj)				= prj!prjPredefined.preTCDict
	= (OK, tc_dict, prj)
getRecordTypeDef other project
	= (pushError (X_Internal "Expected a pointer to a record type in module CoreAccess(get).") OK, DummyValue, project)

// -------------------------------------------------------------------------------------------------------------------------------------------------
putAlgTypeDef :: !HeapPtr !CAlgTypeDefH !*CProject -> (!Error, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------
putAlgTypeDef (CAlgTypePtr _ ptr) def prj
	# heap							= writePtr ptr def prj.prjAlgTypeHeap
	# prj							= {prj & prjAlgTypeHeap = heap}
	= (OK, prj)
putAlgTypeDef other def project
	= (pushError (X_Internal "Expected a pointer to an algebraic type in module CoreAccess(put).") OK, project)

// -------------------------------------------------------------------------------------------------------------------------------------------------
putClassDef :: !HeapPtr !CClassDefH !*CProject -> (!Error, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------
putClassDef (CClassPtr _ ptr) def prj
	# heap							= writePtr ptr def prj.prjClassHeap
	# prj							= {prj & prjClassHeap = heap}
	= (OK, prj)
putClassDef other def project
	= (pushError (X_Internal "Expected a pointer to a class in module CoreAccess(put).") OK, project)

// -------------------------------------------------------------------------------------------------------------------------------------------------
putDataConsDef :: !HeapPtr !CDataConsDefH !*CProject -> (!Error, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------
putDataConsDef (CDataConsPtr _ ptr) def prj
	# heap							= writePtr ptr def prj.prjDataConsHeap
	# prj							= {prj & prjDataConsHeap = heap}
	= (OK, prj)
putDataConsDef other def project
	= (pushError (X_Internal "Expected a pointer to a data-constructor in module CoreAccess(put).") OK, project)

// -------------------------------------------------------------------------------------------------------------------------------------------------
putFunDef :: !HeapPtr !CFunDefH !*CProject -> (!Error, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------
putFunDef (CFunPtr _ ptr) def prj
	# heap							= writePtr ptr def prj.prjFunHeap
	# prj							= {prj & prjFunHeap = heap}
	= (OK, prj)
putFunDef other def project
	= (pushError (X_Internal "Expected a pointer to a function in module CoreAccess(put).") OK, project)

// -------------------------------------------------------------------------------------------------------------------------------------------------
putInstanceDef :: !HeapPtr !CInstanceDefH !*CProject -> (!Error, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------
putInstanceDef (CInstancePtr _ ptr) def prj
	# heap							= writePtr ptr def prj.prjInstanceHeap
	# prj							= {prj & prjInstanceHeap = heap}
	= (OK, prj)
putInstanceDef other def project
	= (pushError (X_Internal "Expected a pointer to an instance in module CoreAccess(put).") OK, project)

// -------------------------------------------------------------------------------------------------------------------------------------------------
putMemberDef :: !HeapPtr !CMemberDefH !*CProject -> (!Error, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------
putMemberDef (CMemberPtr _ ptr) def prj
	# heap							= writePtr ptr def prj.prjMemberHeap
	# prj							= {prj & prjMemberHeap = heap}
	= (OK, prj)
putMemberDef other def project
	= (pushError (X_Internal "Expected a pointer to a member in module CoreAccess(put).") OK, project)

// -------------------------------------------------------------------------------------------------------------------------------------------------
putRecordFieldDef :: !HeapPtr !CRecordFieldDefH !*CProject -> (!Error, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------
putRecordFieldDef (CRecordFieldPtr _ ptr) def prj
	# heap							= writePtr ptr def prj.prjRecordFieldHeap
	# prj							= {prj & prjRecordFieldHeap = heap}
	= (OK, prj)
putRecordFieldDef other def project
	= (pushError (X_Internal "Expected a pointer to a record field in module CoreAccess(put).") OK, project)

// -------------------------------------------------------------------------------------------------------------------------------------------------
putRecordTypeDef :: !HeapPtr !CRecordTypeDefH !*CProject -> (!Error, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------
putRecordTypeDef (CRecordTypePtr _ ptr) def prj
	# heap							= writePtr ptr def prj.prjRecordTypeHeap
	# prj							= {prj & prjRecordTypeHeap = heap}
	= (OK, prj)
putRecordTypeDef other def project
	= (pushError (X_Internal "Expected a pointer to a record type in module CoreAccess(put).") OK, project)


















































// Convention: nilPtr is used to denote the predefined module
// -------------------------------------------------------------------------------------------------------------------------------------------------
getHeapPtrs :: ![ModulePtr] ![DefinitionKind] !*CHeaps -> (!Error, ![HeapPtr], !*CHeaps)
// -------------------------------------------------------------------------------------------------------------------------------------------------
getHeapPtrs [ptr:ptrs] kinds heaps
	# (mod, heaps)						= case isNilPtr ptr of
											True	-> (CPredefined, heaps)
											False	-> readPointer ptr heaps
	# definition_ptrs					= flatten (map (get_mod_ptrs mod) kinds)
	# (error, more_ptrs, heaps)			= getHeapPtrs ptrs kinds heaps
	= (error, definition_ptrs ++ more_ptrs, heaps)
	where
		get_mod_ptrs :: !CModule !DefinitionKind -> [HeapPtr]
		get_mod_ptrs mod CAlgType		= mod.pmAlgTypePtrs
		get_mod_ptrs mod CClass			= mod.pmClassPtrs
		get_mod_ptrs mod CDataCons		= mod.pmDataConsPtrs
		get_mod_ptrs mod CFun			= mod.pmFunPtrs
		get_mod_ptrs mod CInstance		= mod.pmInstancePtrs
		get_mod_ptrs mod CMember		= mod.pmMemberPtrs
		get_mod_ptrs mod CRecordField	= mod.pmRecordFieldPtrs
		get_mod_ptrs mod CRecordType	= mod.pmRecordTypePtrs
getHeapPtrs [] kinds heaps
	= (OK, [], heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
getDefinitionInfo :: !HeapPtr !*CHeaps !*CProject -> (!Error, !DefinitionInfo, !*CHeaps, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------
getDefinitionInfo ptr heaps prj
	= get_info (ptrKind ptr) (ptrModule ptr) ptr heaps prj
	where
		get_info CAlgType mod ptr heaps prj
			# (error, def, prj)			= getAlgTypeDef ptr prj
			| isError error				= (error, DummyValue, heaps, prj)
			# (name, heaps)				= case isNilPtr mod of
											True	-> ("_Predefined", heaps)
											False	-> getPointerName mod heaps
			= (OK, {diName = def.atdName, diPointer = ptr, diInfix = False, diKind = CAlgType, diModuleName = name, diArity = def.atdArity}, heaps, prj)
		get_info CClass mod ptr heaps prj
			# (error, def, prj)			= getClassDef ptr prj
			| isError error				= (error, DummyValue, heaps, prj)
			# (name, heaps)				= case isNilPtr mod of
											True	-> ("_Predefined", heaps)
											False	-> getPointerName mod heaps
			= (OK, {diName = def.cldName, diPointer = ptr, diInfix = False, diKind = CClass, diModuleName = name, diArity = def.cldArity}, heaps, prj)
		get_info CDataCons mod ptr heaps prj
			# (error, def, prj)			= getDataConsDef ptr prj
			| isError error				= (error, DummyValue, heaps, prj)
			# (name, heaps)				= case isNilPtr mod of
											True	-> ("_Predefined", heaps)
											False	-> getPointerName mod heaps
			= (OK, {diName = def.dcdName, diPointer = ptr, diInfix = isInfix def.dcdInfix, diKind = CDataCons, diModuleName = name, diArity = def.dcdArity}, heaps, prj)
		get_info CFun mod ptr heaps prj
			# (error, def, prj)			= getFunDef ptr prj
			| isError error				= (error, DummyValue, heaps, prj)
			# (name, heaps)				= case isNilPtr mod of
											True	-> ("_Predefined", heaps)
											False	-> getPointerName mod heaps
			= (OK, {diName = def.fdName, diPointer = ptr, diInfix = isInfix def.fdInfix, diKind = CFun, diModuleName = name, diArity = def.fdArity}, heaps, prj)
		get_info CInstance mod ptr heaps prj
			# (error, def, prj)			= getInstanceDef ptr prj
			| isError error				= (error, DummyValue, heaps, prj)
			# (name, heaps)				= case isNilPtr mod of
											True	-> ("_Predefined", heaps)
											False	-> getPointerName mod heaps
			= (OK, {diName = def.indName, diPointer = ptr, diInfix = False, diKind = CInstance, diModuleName = name, diArity = -1}, heaps, prj)
		get_info CMember mod ptr heaps prj
			# (error, def, prj)			= getMemberDef ptr prj
			| isError error				= (error, DummyValue, heaps, prj)
			# (name, heaps)				= case isNilPtr mod of
											True	-> ("_Predefined", heaps)
											False	-> getPointerName mod heaps
			= (OK, {diName = def.mbdName, diPointer = ptr, diInfix = isInfix def.mbdInfix, diKind = CMember, diModuleName = name, diArity = -1}, heaps, prj)
		get_info CRecordField mod ptr heaps prj
			# (error, def, prj)			= getRecordFieldDef ptr prj
			| isError error				= (error, DummyValue, heaps, prj)
			# (name, heaps)				= case isNilPtr mod of
											True	-> ("_Predefined", heaps)
											False	-> getPointerName mod heaps
			= (OK, {diName = def.rfName, diPointer = ptr, diInfix = False, diKind = CRecordField, diModuleName = name, diArity = -1}, heaps, prj)
		get_info CRecordType mod ptr heaps prj
			# (error, def, prj)			= getRecordTypeDef ptr prj
			| isError error				= (error, DummyValue, heaps, prj)
			# (name, heaps)				= case isNilPtr mod of
											True	-> ("_Predefined", heaps)
											False	-> getPointerName mod heaps
			= (OK, {diName = def.rtdName, diPointer = ptr, diInfix = False, diKind = CRecordType, diModuleName = name, diArity = def.rtdArity}, heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
getDefinitionArity :: !HeapPtr !*CHeaps !*CProject -> (!Error, !CArity, !*CHeaps, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------
getDefinitionArity ptr heaps prj
	# (error, info, heaps, prj)			= getDefinitionInfo ptr heaps prj
	| isError error						= (error, DummyValue, heaps, prj)
	= (OK, info.diArity, heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
getDefinitionInfix :: !HeapPtr !*CHeaps !*CProject -> (!Error, !CInfix, !*CHeaps, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------
getDefinitionInfix ptr heaps prj
	| ptrKind ptr == CDataCons
		# (error, def, prj)		= getDataConsDef ptr prj
		| isError error			= (error, DummyValue, heaps, prj)
		= (OK, def.dcdInfix, heaps, prj)
	| ptrKind ptr == CFun
		# (error, def, prj)		= getFunDef ptr prj
		| isError error			= (error, DummyValue, heaps, prj)
		= (OK, def.fdInfix, heaps, prj)
	| ptrKind ptr == CMember
		# (error, def, prj)		= getMemberDef ptr prj
		| isError error			= (error, DummyValue, heaps, prj)
		= (OK, def.mbdInfix, heaps, prj)
	# (error, name, heaps, prj)	= getDefinitionName ptr heaps prj
	| isError error				= (error, DummyValue, heaps, prj)
	= (pushError (X_Internal ("Could not retreive infix information of '" +++ name +++ "'")) OK, DummyValue, heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
getDefinitionName :: !HeapPtr !*CHeaps !*CProject -> (!Error, !CName, !*CHeaps, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------
getDefinitionName ptr heaps prj
	# (error, info, heaps, prj)	= getDefinitionInfo ptr heaps prj
	| isError error				= (error, DummyValue, heaps, prj)
	= (OK, info.diName, heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
getSymbolType :: !HeapPtr !*CHeaps !*CProject -> (!Error, !CSymbolTypeH, !*CHeaps, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------
getSymbolType ptr heaps prj
	# kind						= ptrKind ptr
	| kind == CDataCons
		# (error, def, prj)		= getDataConsDef ptr prj
		| isError error			= (error, DummyValue, heaps, prj)
		= (OK, def.dcdSymbolType, heaps, prj)
	| kind == CFun
		# (error, def, prj)		= getFunDef ptr prj
		| isError error			= (error, DummyValue, heaps, prj)
		= (OK, def.fdSymbolType, heaps, prj)
	| kind == CMember
		# (error, def, prj)		= getMemberDef ptr prj
		| isError error			= (error, DummyValue, heaps, prj)
		= (OK, def.mbdSymbolType, heaps, prj)
	# (error, name, heaps, prj)	= getDefinitionName ptr heaps prj
	| isError error				= (error, DummyValue, heaps, prj)
	= (pushError (X_Type ("Could not build symboltype of '" +++ name +++ "'.")) OK, DummyValue, heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
isDictionary :: !CTypeH !*CProject -> (!Bool, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------
isDictionary (ptr @@^ types) prj
	# (error, def, prj)			= getRecordTypeDef ptr prj
	| isError error				= (False, prj)
	= (def.rtdIsDictionary, prj)
isDictionary (CStrict type) prj
	= isDictionary type prj
isDictionary other prj
	= (False, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
countDictionaries :: !CSymbolTypeH !*CProject -> (!Int, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------
countDictionaries symboltype prj
	= count 0 symboltype.sytArguments prj
	where
		count num [type:types] prj
			# (is_dict, prj)				= isDictionary type prj
			| is_dict						= count (num+1) types prj
			= (num, prj)
		count num [] prj
			= (num, prj)










// -------------------------------------------------------------------------------------------------------------------------------------------------
safePtrEq :: !(Ptr a) !(Ptr a) -> Bool
// -------------------------------------------------------------------------------------------------------------------------------------------------
safePtrEq ptr1 ptr2
	# nil1									= isNilPtr ptr1
	# nil2									= isNilPtr ptr2
	| nil1 && nil2							= True
	| nil1 || nil2							= False
	= ptr1 == ptr2
























// ------------------------------------------------------------------------------------------------------------------------
findABCFunctions :: !*CHeaps !*CProject -> (!*CHeaps, !*CProject)
// ------------------------------------------------------------------------------------------------------------------------
findABCFunctions heaps prj
	# abc									= DummyValue
	# (modules, prj)						= prj!prjModules
	// StdBool
	# (ok, stdbool, heaps)					= find_module "StdBool" modules heaps
	# (abc, prj)							= case ok of
												True	-> check_stdbool abc stdbool.pmFunPtrs prj
												False	-> (abc, prj)
	// StdInt
	# (ok, stdint, heaps)					= find_module "StdInt" modules heaps
	# (abc, prj)							= case ok of
												True	-> check_stdint abc stdint.pmFunPtrs prj
												False	-> (abc, prj)
	// StdString
	# (ok, stdstring, heaps)				= find_module "StdString" modules heaps
	# (abc, prj)							= case ok of
												True	-> check_stdstring abc stdstring.pmFunPtrs prj
												False	-> (abc, prj)
	= (heaps, {prj & prjABCFunctions = abc})
	where
		find_module :: !ModuleName ![ModulePtr] !*CHeaps -> (!Bool, !CModule, !*CHeaps)
		find_module name [ptr:ptrs] heaps
			# (mod, heaps)					= readPointer ptr heaps
			| mod.pmName == name			= (True, mod, heaps)
			= find_module name ptrs heaps
		find_module name [] heaps
			= (False, DummyValue, heaps)
		
		check_stdbool :: !ABCFunctions ![HeapPtr] !*CProject -> (!ABCFunctions, !*CProject)
		check_stdbool abc [ptr:ptrs] prj
			# (error, fundef, prj)			= getFunDef ptr prj
			| isError error					= check_stdint abc ptrs prj
			| not fundef.fdIsDeltaRule		= check_stdint abc ptrs prj
			# abc							= case fundef.fdName of
												"&&"		-> {abc & stdBool.boolAnd		= ptr}
												"not"		-> {abc & stdBool.boolNot		= ptr}
												"||"		-> {abc & stdBool.boolOr		= ptr}
												_			-> abc
			= check_stdbool abc ptrs prj
		check_stdbool abc [] prj
			= (abc, prj)
		
		check_stdint :: !ABCFunctions ![HeapPtr] !*CProject -> (!ABCFunctions, !*CProject)
		check_stdint abc [ptr:ptrs] prj
			# (error, fundef, prj)			= getFunDef ptr prj
			| isError error					= check_stdint abc ptrs prj
			| not fundef.fdIsDeltaRule		= check_stdint abc ptrs prj
			# abc							= case fundef.fdName of
												"+_int"			-> {abc & stdInt.intAdd			= ptr}
												"bitand"		-> {abc & stdInt.intBitAnd		= ptr}
												"bitnot"		-> {abc & stdInt.intBitNot		= ptr}
												"bitor"			-> {abc & stdInt.intBitOr		= ptr}
												"bitxor"		-> {abc & stdInt.intBitXor		= ptr}
												"/_int"			-> {abc & stdInt.intDivide		= ptr}
												"==_int"		-> {abc & stdInt.intEqual		= ptr}
												"isEven_int"	-> {abc & stdInt.intIsEven		= ptr}
												"isOdd_int"		-> {abc & stdInt.intIsOdd		= ptr}
												"*_int"			-> {abc & stdInt.intMultiply	= ptr}
												"mod_int"		-> {abc & stdInt.intModulo		= ptr}
												"~_int"			-> {abc & stdInt.intNegate		= ptr}
												"one_int"		-> {abc & stdInt.intOne			= ptr}
												"-_int"			-> {abc & stdInt.intSubtract	= ptr}
												"<_int"			-> {abc & stdInt.intSmaller		= ptr}
												"zero_int"		-> {abc & stdInt.intZero		= ptr}
												_				-> abc
			= check_stdint abc ptrs prj
		check_stdint abc [] prj
			= (abc, prj)
		
		check_stdstring :: !ABCFunctions ![HeapPtr] !*CProject -> (!ABCFunctions, !*CProject)
		check_stdstring abc [ptr:ptrs] prj
			# (error, fundef, prj)			= getFunDef ptr prj
			| isError error					= check_stdstring abc ptrs prj
			| not fundef.fdIsDeltaRule		= check_stdstring abc ptrs prj
			# abc							= case fundef.fdName of
												"==_uarray"		-> {abc & stdString.stringEqual	= ptr}
												_				-> abc
			= check_stdstring abc ptrs prj
		check_stdstring abc [] prj
			= (abc, prj)
























// ========================================================================================================================
// Only for debugging purposes. (does not work with sharing)
// ------------------------------------------------------------------------------------------------------------------------
class eval a :: !a -> a
// ------------------------------------------------------------------------------------------------------------------------

// ------------------------------------------------------------------------------------------------------------------------
instance eval (a, b) | eval b
// ------------------------------------------------------------------------------------------------------------------------
where
	eval (x, y)
		#! y						= eval y
		= (x, y)

// ========================================================================================================================
// Fooling the compiler not to optimize the Nil case.
// ------------------------------------------------------------------------------------------------------------------------
instance eval [a] | eval a
// ------------------------------------------------------------------------------------------------------------------------
where
	eval list
		| isEmpty list				= list
	eval [x:xs]
		#! x						= eval x
		#! xs						= eval xs
		= [x:xs]
	eval _
		= abort "?"

// ------------------------------------------------------------------------------------------------------------------------
instance eval (Maybe a) | eval a
// ------------------------------------------------------------------------------------------------------------------------
where
	eval (Just x)
		#! x						= eval x
		= Just x
	eval Nothing
		= Nothing

// ------------------------------------------------------------------------------------------------------------------------
instance eval (CAlgPattern a)
// ------------------------------------------------------------------------------------------------------------------------
where
	eval pattern
		#! result					= eval pattern.atpResult
		= {pattern & atpResult = result}

// ------------------------------------------------------------------------------------------------------------------------
instance eval (CBasicPattern a)
// ------------------------------------------------------------------------------------------------------------------------
where
	eval pattern
		#! result					= eval pattern.bapResult
		= {pattern & bapResult = result}

// ------------------------------------------------------------------------------------------------------------------------
instance eval (CBasicValue a)
// ------------------------------------------------------------------------------------------------------------------------
where
	eval (CBasicInteger n)
		= CBasicInteger n
	eval (CBasicCharacter c)
		= CBasicCharacter c
	eval (CBasicRealNumber r)
		= CBasicRealNumber r
	eval (CBasicBoolean b)
		= CBasicBoolean b
	eval (CBasicString s)
		= CBasicString s
	eval (CBasicArray exprs)
		#! exprs					= eval exprs
		= CBasicArray exprs

// ------------------------------------------------------------------------------------------------------------------------
instance eval (CCasePatterns a)
// ------------------------------------------------------------------------------------------------------------------------
where
	eval (CAlgPatterns ptr patterns)
		#! patterns					= eval patterns
		= CAlgPatterns ptr patterns
	eval (CBasicPatterns ptr patterns)
		#! patterns					= eval patterns
		= CBasicPatterns ptr patterns

// ------------------------------------------------------------------------------------------------------------------------
instance eval (CExpr a)
// ------------------------------------------------------------------------------------------------------------------------
where
	eval (CExprVar ptr)
		= CExprVar ptr
	eval (CShared ptr)
		= CShared ptr
	eval (expr @# exprs)
		#! expr						= eval expr
		#! exprs					= eval exprs
		= expr @# exprs
	eval (ptr @@# exprs)
		#! exprs					= eval exprs
		= ptr @@# exprs
	eval (CLet strict lets expr)
		#! lets						= eval lets
		#! expr						= eval expr
		= CLet strict lets expr
	eval (CCase expr patterns def)
		#! expr						= eval expr
		#! patterns					= eval patterns
		#! def						= eval def
		= CCase expr patterns def
	eval (CBasicValue value)
		#! value					= eval value
		= CBasicValue value
	eval (CCode codetype codecontents)
		= CCode codetype codecontents
	eval CBottom
		= CBottom

// ------------------------------------------------------------------------------------------------------------------------
instance eval (CProp a)
// ------------------------------------------------------------------------------------------------------------------------
where
	eval CTrue
		= CTrue
	eval CFalse
		= CFalse
	eval (CPropVar ptr)
		= CPropVar ptr
	eval (CEqual e1 e2)
		#! e1						= eval e1
		#! e2						= eval e2
		= CEqual e1 e2
	eval (CNot p)
		#! p						= eval p
		= CNot p
	eval (CAnd p q)
		#! p						= eval p
		#! q						= eval q
		= CAnd p q
	eval (COr p q)
		#! p						= eval p
		#! q						= eval q
		= COr p q
	eval (CImplies p q)
		#! p						= eval p
		#! q						= eval q
		= CImplies p q
	eval (CIff p q)
		#! p						= eval p
		#! q						= eval q
		= CIff p q
	eval (CExprForall ptr p)
		#! p						= eval p
		= CExprForall ptr p
	eval (CExprExists ptr p)
		#! p						= eval p
		= CExprExists ptr p
	eval (CPropForall ptr p)
		#! p						= eval p
		= CPropForall ptr p
	eval (CPropExists ptr p)
		#! p						= eval p
		= CPropExists ptr p
	eval (CPredicate ptr exprs)
		#! exprs					= eval exprs
		= CPredicate ptr exprs

// ========================================================================================================================
// Only for debugging purposes. (does not work with sharing)
// ------------------------------------------------------------------------------------------------------------------------
class cleanVars a :: !a !*CHeaps -> *CHeaps
// ------------------------------------------------------------------------------------------------------------------------

// ------------------------------------------------------------------------------------------------------------------------
cleanExprVars :: ![CExprVarPtr] !*CHeaps -> *CHeaps
// ------------------------------------------------------------------------------------------------------------------------
cleanExprVars [ptr:ptrs] heaps
	#! (var, heaps)					= readPointer ptr heaps
	#! var							= {var & evarInfo = EVar_Nothing}
	#! heaps						= writePointer ptr var heaps
	= cleanExprVars ptrs heaps
cleanExprVars [] heaps
	= heaps

// ------------------------------------------------------------------------------------------------------------------------
cleanPropVars :: ![CPropVarPtr] !*CHeaps -> *CHeaps
// ------------------------------------------------------------------------------------------------------------------------
cleanPropVars [ptr:ptrs] heaps
	#! (var, heaps)					= readPointer ptr heaps
	#! var							= {var & pvarInfo = PVar_Nothing}
	#! heaps						= writePointer ptr var heaps
	= cleanPropVars ptrs heaps
cleanPropVars [] heaps
	= heaps

// ------------------------------------------------------------------------------------------------------------------------
instance cleanVars [a] | cleanVars a
// ------------------------------------------------------------------------------------------------------------------------
where
	cleanVars [x:xs] heaps
		#! heaps					= cleanVars x heaps
		= cleanVars xs heaps
	cleanVars [] heaps
		= heaps

// ------------------------------------------------------------------------------------------------------------------------
instance cleanVars (Maybe a) | cleanVars a
// ------------------------------------------------------------------------------------------------------------------------
where
	cleanVars (Just x) heaps
		= cleanVars x heaps
	cleanVars Nothing heaps
		= heaps

// ------------------------------------------------------------------------------------------------------------------------
instance cleanVars (CAlgPattern HeapPtr)
// ------------------------------------------------------------------------------------------------------------------------
where
	cleanVars pattern heaps
		#! heaps					= cleanExprVars pattern.atpExprVarScope heaps
		= cleanVars pattern.atpResult heaps

// ------------------------------------------------------------------------------------------------------------------------
instance cleanVars (CBasicPattern HeapPtr)
// ------------------------------------------------------------------------------------------------------------------------
where
	cleanVars pattern heaps
		= cleanVars pattern.bapResult heaps

// ------------------------------------------------------------------------------------------------------------------------
instance cleanVars (CBasicValue HeapPtr)
// ------------------------------------------------------------------------------------------------------------------------
where
	cleanVars (CBasicArray exprs) heaps
		= cleanVars exprs heaps
	cleanVars _ heaps
		= heaps

// ------------------------------------------------------------------------------------------------------------------------
instance cleanVars (CCasePatterns HeapPtr)
// ------------------------------------------------------------------------------------------------------------------------
where
	cleanVars (CAlgPatterns ptr patterns) heaps
		= cleanVars patterns heaps
	cleanVars (CBasicPatterns ptr patterns) heaps
		= cleanVars patterns heaps

// ------------------------------------------------------------------------------------------------------------------------
instance cleanVars (CExpr HeapPtr)
// ------------------------------------------------------------------------------------------------------------------------
where
	cleanVars (CExprVar ptr) heaps
		= cleanExprVars [ptr] heaps
	cleanVars (CShared ptr) heaps
		= heaps
	cleanVars (expr @# exprs) heaps
		#! heaps					= cleanVars expr heaps
		= cleanVars exprs heaps
	cleanVars (ptr @@# exprs) heaps
		= cleanVars exprs heaps
	cleanVars (CLet strict lets expr) heaps
		#! heaps					= clean_lets lets heaps
		= cleanVars expr heaps
		where
			clean_lets :: ![(CExprVarPtr, CExprH)] !*CHeaps -> *CHeaps
			clean_lets [(ptr,expr):lets] heaps
				#! heaps			= cleanExprVars [ptr] heaps
				#! heaps			= cleanVars expr heaps
				= clean_lets lets heaps
			clean_lets [] heaps
				= heaps
	cleanVars (CCase expr patterns def) heaps
		#! heaps					= cleanVars expr heaps
		#! heaps					= cleanVars patterns heaps
		= cleanVars def heaps
	cleanVars (CBasicValue value) heaps
		= cleanVars value heaps
	cleanVars (CCode codetype codecontents) heaps
		= heaps
	cleanVars CBottom heaps
		= heaps

// ------------------------------------------------------------------------------------------------------------------------
instance cleanVars (CProp HeapPtr)
// ------------------------------------------------------------------------------------------------------------------------
where
	cleanVars CTrue heaps
		= heaps
	cleanVars CFalse heaps
		= heaps
	cleanVars (CPropVar ptr) heaps
		= cleanPropVars [ptr] heaps
	cleanVars (CEqual e1 e2) heaps
		#! heaps					= cleanVars e1 heaps
		= cleanVars e2 heaps
	cleanVars (CNot p) heaps
		= cleanVars p heaps
	cleanVars (CAnd p q) heaps
		#! heaps					= cleanVars p heaps
		= cleanVars q heaps
	cleanVars (COr p q) heaps
		#! heaps					= cleanVars p heaps
		= cleanVars q heaps
	cleanVars (CImplies p q) heaps
		#! heaps					= cleanVars p heaps
		= cleanVars q heaps
	cleanVars (CIff p q) heaps
		#! heaps					= cleanVars p heaps
		= cleanVars q heaps
	cleanVars (CExprForall ptr p) heaps
		#! heaps					= cleanExprVars [ptr] heaps
		= cleanVars p heaps
	cleanVars (CExprExists ptr p) heaps
		#! heaps					= cleanExprVars [ptr] heaps
		= cleanVars p heaps
	cleanVars (CPropForall ptr p) heaps
		#! heaps					= cleanPropVars [ptr] heaps
		= cleanVars p heaps
	cleanVars (CPropExists ptr p) heaps
		#! heaps					= cleanPropVars [ptr] heaps
		= cleanVars p heaps
	cleanVars (CPredicate ptr exprs) heaps
		= cleanVars exprs heaps