/*
** Program: Clean Prover System
** Module:  Predefined (.icl)
** 
** Author:  Maarten de Mol
** Created: 23 August 2000
**
** Remark: The variables occuring in a tuple{type/build/select}, are SHARED for all
**         arities!!!!
*/

implementation module 
	Predefined

import
	StdEnv,
	CoreTypes,
	Heaps

// -------------------------------------------------------------------------------------------------------------------------------------------------
CTuple :: !*CHeaps -> (!CArity -> CAlgTypeDefH, !*CHeaps)
// -------------------------------------------------------------------------------------------------------------------------------------------------
CTuple heaps
	# tvar_defs				= [{tvarName = "t" +++ (toString num), tvarInfo = DummyValue} \\ num <- [1..32]]
	# (tvar_ptrs, heaps)	= newPointers tvar_defs heaps
	= (tuple tvar_ptrs, heaps)
	where
		tuple :: ![CTypeVarPtr] !CArity -> CAlgTypeDefH
		tuple tvars arity
			=	{ atdName			= "_Tuple_" +++ (toString arity)
				, atdArity			= arity
				, atdTypeVarScope	= take arity tvars
				, atdConstructors	= [CBuildTuplePtr arity]
				}

// -------------------------------------------------------------------------------------------------------------------------------------------------
CNormalArray :: !*CHeaps -> (!CAlgTypeDefH, !*CHeaps)
// -------------------------------------------------------------------------------------------------------------------------------------------------
CNormalArray heaps
	# tvar_def				= {tvarName = "a", tvarInfo = DummyValue}
	# (tvar_ptr, heaps)		= newPointer tvar_def heaps
	= (array tvar_ptr, heaps)
	where
		array :: !CTypeVarPtr -> CAlgTypeDefH
		array tvar
			=	{ atdName			= "{}"
				, atdArity			= 1
				, atdTypeVarScope	= [tvar]
				, atdConstructors	= []
				}

// -------------------------------------------------------------------------------------------------------------------------------------------------
CStrictArray :: !*CHeaps -> (!CAlgTypeDefH, !*CHeaps)
// -------------------------------------------------------------------------------------------------------------------------------------------------
CStrictArray heaps
	# tvar_def				= {tvarName = "a", tvarInfo = DummyValue}
	# (tvar_ptr, heaps)		= newPointer tvar_def heaps
	= (array tvar_ptr, heaps)
	where
		array :: !CTypeVarPtr -> CAlgTypeDefH
		array tvar
			=	{ atdName			= "{!}"
				, atdArity			= 1
				, atdTypeVarScope	= [tvar]
				, atdConstructors	= []
				}

// -------------------------------------------------------------------------------------------------------------------------------------------------
CUnboxedArray :: !*CHeaps -> (!CAlgTypeDefH, !*CHeaps)
// -------------------------------------------------------------------------------------------------------------------------------------------------
CUnboxedArray heaps
	# tvar_def				= {tvarName = "a", tvarInfo = DummyValue}
	# (tvar_ptr, heaps)		= newPointer tvar_def heaps
	= (array tvar_ptr, heaps)
	where
		array :: !CTypeVarPtr -> CAlgTypeDefH
		array tvar
			=	{ atdName			= "{#}"
				, atdArity			= 1
				, atdTypeVarScope	= [tvar]
				, atdConstructors	= []
				}

// -------------------------------------------------------------------------------------------------------------------------------------------------
CList :: !*CHeaps -> (!CAlgTypeDefH, !*CHeaps)
// -------------------------------------------------------------------------------------------------------------------------------------------------
CList heaps
	# tvar_def				= {tvarName = "a", tvarInfo = DummyValue}
	# (tvar_ptr, heaps)		= newPointer tvar_def heaps
	= (list tvar_ptr, heaps)
	where
		list :: !CTypeVarPtr -> CAlgTypeDefH
		list tvar
			=	{ atdName			= "[]"
				, atdArity			= 1
				, atdTypeVarScope	= [tvar]
				, atdConstructors	= [CNilPtr, CConsPtr]
				}

// -------------------------------------------------------------------------------------------------------------------------------------------------
CBuildTuple :: !*CHeaps -> (!CArity -> CDataConsDefH, !*CHeaps)
// -------------------------------------------------------------------------------------------------------------------------------------------------
CBuildTuple heaps
	# tvar_defs				= [{tvarName = "t" +++ toString num, tvarInfo = DummyValue} \\ num <- [1..32]]
	# (tvar_ptrs, heaps)	= newPointers tvar_defs heaps
	# evar_defs				= [{evarName = "t" +++ toString num, evarInfo = DummyValue} \\ num <- [1..32]]
	# (evar_ptrs, heaps)	= newPointers evar_defs heaps
	= (build_tuple tvar_ptrs evar_ptrs, heaps)
	where
		build_tuple :: ![CTypeVarPtr] ![CExprVarPtr] !CArity -> CDataConsDefH
		build_tuple tvars evars arity
			# types			= map CTypeVar tvars
			=	{ dcdName			= "_Tuple_" +++ (toString arity)
				, dcdArity			= arity
				, dcdAlgType		= CTuplePtr arity
				, dcdInfix			= CNoInfix
				, dcdSymbolType		= 	{ sytTypeVarScope		= take arity tvars
										, sytArguments			= take arity types
										, sytResult				= CTuplePtr arity @@^ (take arity types)
										, sytClassRestrictions	= []
										}
				, dcdTypeVarScope	= []
				}

// -------------------------------------------------------------------------------------------------------------------------------------------------
CNil :: !*CHeaps -> (!CDataConsDefH, !*CHeaps)
// -------------------------------------------------------------------------------------------------------------------------------------------------
CNil heaps
	# tvar_def				= {tvarName = "a", tvarInfo = DummyValue}
	# (tvar_ptr, heaps)		= newPointer tvar_def heaps
	= (nil tvar_ptr, heaps)
	where
		nil :: !CTypeVarPtr -> CDataConsDefH
		nil var
			=	{ dcdName			= "_Nil"
				, dcdArity			= 0
				, dcdAlgType		= CListPtr
				, dcdInfix			= CNoInfix
				, dcdSymbolType		=	{ sytTypeVarScope		= [var]
										, sytArguments			= []
										, sytResult				= CListPtr @@^ [CTypeVar var]
										, sytClassRestrictions	= []
										}
				, dcdTypeVarScope	= []
				}

// -------------------------------------------------------------------------------------------------------------------------------------------------
CCons :: !*CHeaps -> (!CDataConsDefH, !*CHeaps)
// -------------------------------------------------------------------------------------------------------------------------------------------------
CCons heaps
	# tvar_def				= {tvarName = "a", tvarInfo = DummyValue}
	# (tvar_ptr, heaps)		= newPointer tvar_def heaps
	= (cons tvar_ptr, heaps)
	where
		cons :: !CTypeVarPtr -> CDataConsDefH
		cons var
			=	{ dcdName			= "_Cons"
				, dcdArity			= 2
				, dcdAlgType		= CListPtr
				, dcdInfix			= CNotAssociative 9
				, dcdSymbolType		=	{ sytTypeVarScope		= [var]
										, sytArguments			= [CTypeVar var, CListPtr @@^ [CTypeVar var]]
										, sytResult				= CListPtr @@^ [CTypeVar var]
										, sytClassRestrictions	= []
										}
				, dcdTypeVarScope	= []
				}

// -------------------------------------------------------------------------------------------------------------------------------------------------
CTupleSelect :: !*CHeaps -> (!CArity Int -> CFunDefH, !*CHeaps)
// -------------------------------------------------------------------------------------------------------------------------------------------------
CTupleSelect heaps
	# tvar_defs				= [{tvarName = "t" +++ (toString num), tvarInfo = DummyValue} \\ num <- [1..32]]
	# (tvar_ptrs, heaps)	= newPointers tvar_defs heaps
	# evar_def				= {evarName = "_tuple", evarInfo = DummyValue}
	# (evar_ptr, heaps)		= newPointer evar_def heaps
	# evar_defs				= [{evarName = "e" +++ (toString num), evarInfo = DummyValue} \\ num <- [1..32]]
	# (evar_ptrs, heaps)	= newPointers evar_defs heaps
	= (tuple_select tvar_ptrs evar_ptr evar_ptrs, heaps)
	where
		tuple_select :: ![CTypeVarPtr] !CExprVarPtr ![CExprVarPtr] !CArity !Int -> CFunDefH
		tuple_select tvars tuple_var component_vars arity index
			# types			= map CTypeVar tvars
			=	{ fdName				= "_tupleselect_" +++ (toString arity) +++ "_" +++ (toString index)
				, fdOldName				= ""
				, fdArity				= 1
				, fdCaseVariables		= [0]
				, fdStrictVariables		= [0]
				, fdInfix				= CNoInfix
				, fdSymbolType			=	{ sytArguments			= [CTuplePtr arity @@^ (take arity types)]
											, sytTypeVarScope		= take arity tvars
											, sytResult				= types !! (index-1)
											, sytClassRestrictions	= []
											}
				, fdHasType				= True
				, fdExprVarScope		= [tuple_var]
				, fdBody				= CCase (CExprVar tuple_var) 
												(CAlgPatterns (CTuplePtr arity)
												[	{ atpDataCons		= CBuildTuplePtr arity
													, atpExprVarScope	= take arity component_vars
													, atpResult			= CExprVar (component_vars !! (index-1))
													}
												]
											) Nothing
				, fdIsRecordSelector	= False
				, fdIsRecordUpdater		= False
				, fdNrDictionaries		= 0
				, fdRecordFieldDef		= DummyValue
				, fdIsDeltaRule			= False
				, fdDeltaRule			= (\_ -> LBottom)
				, fdOpaque				= False
				, fdDefinedness			= CDefinednessUnknown
				}

// -------------------------------------------------------------------------------------------------------------------------------------------------
CTC :: !*CHeaps -> (!CClassDefH, !*CHeaps)
// -------------------------------------------------------------------------------------------------------------------------------------------------
CTC heaps
	# tvar_def				= {tvarName = "a", tvarInfo = DummyValue}
	# (tvar_ptr, heaps)		= newPointer tvar_def heaps
	= (tc tvar_ptr, heaps)
	where
		tc :: !CTypeVarPtr -> CClassDefH
		tc tvar
			=	{ cldName				= "TC"
				, cldArity				= 1
				, cldTypeVarScope		= [tvar]
				, cldClassRestrictions	= []
				, cldMembers			= []
				, cldDictionary			= CTCDictPtr
				, cldInstances			= []
				}

// -------------------------------------------------------------------------------------------------------------------------------------------------
CTCDict :: !*CHeaps -> (!CRecordTypeDefH, !*CHeaps)
// -------------------------------------------------------------------------------------------------------------------------------------------------
CTCDict heaps
	# tvar_def				= {tvarName = "a", tvarInfo = DummyValue}
	# (tvar_ptr, heaps)		= newPointer tvar_def heaps
	= (tc_dict tvar_ptr, heaps)
	where
		tc_dict :: !CTypeVarPtr -> CRecordTypeDefH
		tc_dict tvar
			=	{ rtdName				= "dictionary_TC"
				, rtdArity				= 1
				, rtdTypeVarScope		= [tvar]
				, rtdFields				= []
				, rtdRecordConstructor	= DummyValue
				, rtdIsDictionary		= True
				, rtdClassDef			= CTCPtr
				}












// -------------------------------------------------------------------------------------------------------------------------------------------------
CPredefined :: CModule
// -------------------------------------------------------------------------------------------------------------------------------------------------
CPredefined
	=	{ pmName				= "_Predefined"
		, pmPath				= "-"
		, pmImportedModules		= []
		, pmAlgTypePtrs			= [CListPtr, CNormalArrayPtr, CStrictArrayPtr, CUnboxedArrayPtr] ++ 
								  [CTuplePtr arity \\ arity <- [2..32]]
		, pmClassPtrs			= [CTCPtr]
		, pmDataConsPtrs		= [CNilPtr, CConsPtr] ++ 
								  [CBuildTuplePtr arity \\ arity <- [2..32]]
		, pmFunPtrs				= [CTupleSelectPtr arity index \\ arity <- [2..32], index <- [1..arity]]
		, pmInstancePtrs		= []
		, pmMemberPtrs			= []
		, pmRecordFieldPtrs		= []
		, pmRecordTypePtrs		= [CTCDictPtr]
		, pmCompilerStore		= Nothing
		, pmCompilerConversion	= DummyValue
		, pmOriginalNrDclConses	= DummyValue
		}

// -------------------------------------------------------------------------------------------------------------------------------------------------
buildPredefined :: !*CHeaps -> (!CPredefined, !*CHeaps)
// -------------------------------------------------------------------------------------------------------------------------------------------------
buildPredefined heaps
	# (preTuple, heaps)			= CTuple heaps
	# (preNormalArray, heaps)	= CNormalArray heaps
	# (preStrictArray, heaps)	= CStrictArray heaps
	# (preUnboxedArray, heaps)	= CUnboxedArray heaps
	# (preList, heaps)			= CList heaps
	# (preBuildTuple, heaps)	= CBuildTuple heaps
	# (preCons, heaps)			= CCons heaps
	# (preNil, heaps)			= CNil heaps
	# (preTupleSelect, heaps)	= CTupleSelect heaps
	# (preTC, heaps)			= CTC heaps
	# (preTCDict, heaps)		= CTCDict heaps
	= (	{ preTuple			= preTuple
		, preNormalArray	= preNormalArray
		, preStrictArray	= preStrictArray
		, preUnboxedArray	= preUnboxedArray
		, preList			= preList
		, preBuildTuple		= preBuildTuple
		, preCons			= preCons
		, preNil			= preNil
		, preTupleSelect	= preTupleSelect
		, preTC				= preTC
		, preTCDict			= preTCDict
		}, heaps)