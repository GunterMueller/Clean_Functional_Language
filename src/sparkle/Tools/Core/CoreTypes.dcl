/*
** Program: Clean Prover System
** Module:  CoreTypes (.dcl)
** 
** Author:  Maarten de Mol
** Created: 22 August 2000
*/

definition module 
	CoreTypes

import
	StdEnv,
	ProverOptions,
	LTypes,
	frontend,
	Errors

// NOT (by a long shot) complete as yet.
// ------------------------------------------------------------------------------------------------------------------------
:: ABCFunctions =
// ------------------------------------------------------------------------------------------------------------------------
	{ stdBool				:: !BoolFunctions
	, stdInt				:: !IntFunctions
	, stdString				:: !StringFunctions
	}
instance DummyValue ABCFunctions

// ------------------------------------------------------------------------------------------------------------------------
:: BoolFunctions =
// ------------------------------------------------------------------------------------------------------------------------
	{ boolAnd				:: !HeapPtr
	, boolNot				:: !HeapPtr
	, boolOr				:: !HeapPtr
	}
instance DummyValue BoolFunctions

// ------------------------------------------------------------------------------------------------------------------------
:: IntFunctions =
// ------------------------------------------------------------------------------------------------------------------------
	{ intAdd				:: !HeapPtr
	, intBitAnd				:: !HeapPtr
	, intBitNot				:: !HeapPtr
	, intBitOr				:: !HeapPtr
	, intBitXor				:: !HeapPtr
	, intDivide				:: !HeapPtr
	, intEqual				:: !HeapPtr
	, intIsEven				:: !HeapPtr
	, intIsOdd				:: !HeapPtr
	, intModulo				:: !HeapPtr
	, intMultiply			:: !HeapPtr
	, intOne				:: !HeapPtr
	, intNegate				:: !HeapPtr
	, intSmaller			:: !HeapPtr
	, intSubtract			:: !HeapPtr
	, intZero				:: !HeapPtr
	}
instance DummyValue IntFunctions

// ------------------------------------------------------------------------------------------------------------------------
:: StringFunctions =
// ------------------------------------------------------------------------------------------------------------------------
	{ stringEqual			:: !HeapPtr
	}
instance DummyValue StringFunctions





































// -------------------------------------------------------------------------------------------------------------------------------------------------
:: Options =
// -------------------------------------------------------------------------------------------------------------------------------------------------
	{ optCombineLets				:: !Bool
	, optAutomaticDiscard			:: !Bool
	, optDisplaySpecial				:: !Bool
	, optHintsViewThreshold			:: !Int
	, optHintsApplyThreshold		:: !Int
	}
instance DummyValue Options

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: CompilerDefinitionKind =
// -------------------------------------------------------------------------------------------------------------------------------------------------
	  CheckedTypeDef
	| ClassDef
	| ClassInstance
	| ConsDef
	| FunDef
	| FunType
	| MemberDef
	| SelectorDef
instance DummyValue CompilerDefinitionKind
instance toString CompilerDefinitionKind
instance == CompilerDefinitionKind

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: IndexedPtr =
// -------------------------------------------------------------------------------------------------------------------------------------------------
	  IclDefinitionPtr	!ModuleName !Int !CName !CompilerDefinitionKind !CDefIndex
	| DclDefinitionPtr	!ModuleName      !CName !CompilerDefinitionKind !CDefIndex
instance DummyValue IndexedPtr

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: HeapPtr =
// -------------------------------------------------------------------------------------------------------------------------------------------------
	  CAlgTypePtr		!ModulePtr	!(Ptr CAlgTypeDefH)
	| CClassPtr			!ModulePtr	!(Ptr CClassDefH)
	| CDataConsPtr		!ModulePtr	!(Ptr CDataConsDefH)
	| CFunPtr			!ModulePtr	!(Ptr CFunDefH)
	| CInstancePtr		!ModulePtr	!(Ptr CInstanceDefH)
	| CMemberPtr		!ModulePtr	!(Ptr CMemberDefH)
	| CRecordFieldPtr	!ModulePtr	!(Ptr CRecordFieldDefH)
	| CRecordTypePtr	!ModulePtr	!(Ptr CRecordTypeDefH)
	// predefined types
	| CTuplePtr			!CArity
	| CNormalArrayPtr
	| CStrictArrayPtr
	| CUnboxedArrayPtr
	| CListPtr
	// predefined constructors
	| CBuildTuplePtr	!CArity
	| CConsPtr
	| CNilPtr
	// predefined functions
	| CTupleSelectPtr	!CArity !Int
	// dynamics
	| CTCPtr
	| CTCDictPtr
instance DummyValue HeapPtr
instance == HeapPtr
// CONVENTION: DummyValue must be distinguishable from all other pointers.

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: DefinitionKind =
// -------------------------------------------------------------------------------------------------------------------------------------------------
	  CAlgType
	| CClass
	| CDataCons
	| CFun
	| CInstance
	| CMember
	| CRecordField
	| CRecordType
instance DummyValue DefinitionKind
instance toString DefinitionKind
instance == DefinitionKind

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: CompilerStore =
// -------------------------------------------------------------------------------------------------------------------------------------------------
	{ csAlgTypeDefs			:: ![CAlgTypeDefI]
	, csClassDefs			:: ![CClassDefI]
	, csDataConsDefs		:: ![CDataConsDefI]
	, csFunDefs				:: ![CFunDefI]
	, csInstanceDefs		:: ![CInstanceDefI]
	, csMemberDefs			:: ![CMemberDefI]
	, csRecordFieldDefs		:: ![CRecordFieldDefI]
	, csRecordTypeDefs		:: ![CRecordTypeDefI]
	, csImports				:: ![CName]
	}
instance DummyValue CompilerStore

:: ConversionTable :== {#{#Int}}

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: CompilerConversion =
// -------------------------------------------------------------------------------------------------------------------------------------------------
	// the next tables take a solved icl-index as input and yield the right HeapPtr
	{ ccCheckedTypePtrs		:: !{!HeapPtr}
	, ccClassPtrs			:: !{!HeapPtr}
	, ccConsPtrs			:: !{!HeapPtr}
	, ccFunPtrs				:: !{!HeapPtr}
	, ccInstancePtrs		:: !{!HeapPtr}
	, ccMemberPtrs			:: !{!HeapPtr}
	, ccSelectorPtrs		:: !{!HeapPtr}
	// other conversion stuff
	, ccDictionaries		:: ![(CName, IndexedPtr)]			// list of dictionaries tupled with class name (ICL)
	, ccConversionTable		:: !ConversionTable					// from compiler
	, ccDclIclConversions	:: !{#Index}						// from compiler
	}
instance DummyValue CompilerConversion

























// -------------------------------------------------------------------------------------------------------------------------------------------------   
:: CAlgPattern def_ptr =
// -------------------------------------------------------------------------------------------------------------------------------------------------   
	{ atpDataCons				:: !def_ptr
	, atpExprVarScope			:: ![CExprVarPtr]
	, atpResult					:: !CExpr def_ptr
	}
instance DummyValue (CAlgPattern def_ptr) | DummyValue def_ptr
instance == (CAlgPattern def_ptr) | == def_ptr
                                  
// -------------------------------------------------------------------------------------------------------------------------------------------------   
:: CAlgTypeDef def_ptr =
// -------------------------------------------------------------------------------------------------------------------------------------------------   
	{ atdName					:: !CName
	, atdArity					:: !CArity                
	, atdTypeVarScope			:: ![CTypeVarPtr]
	, atdConstructors			:: ![def_ptr]
	}
instance DummyValue (CAlgTypeDef def_ptr) | DummyValue def_ptr
   
// -------------------------------------------------------------------------------------------------------------------------------------------------   
:: CBasicPattern def_ptr =
// -------------------------------------------------------------------------------------------------------------------------------------------------   
	{ bapBasicValue				:: !CBasicValue def_ptr
	, bapResult					:: !CExpr def_ptr
	}
instance DummyValue (CBasicPattern def_ptr) | DummyValue def_ptr
instance == (CBasicPattern def_ptr) | == def_ptr

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: CBasicType = 
// -------------------------------------------------------------------------------------------------------------------------------------------------
	  CInteger
	| CCharacter
	| CRealNumber
	| CBoolean
	| CString
instance DummyValue CBasicType
instance == CBasicType

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: CBasicValue def_ptr = 
// -------------------------------------------------------------------------------------------------------------------------------------------------
	  CBasicInteger		!Int  
	| CBasicCharacter	!Char
	| CBasicRealNumber	!Real
	| CBasicBoolean		!Bool  
	| CBasicString		!String
	| CBasicArray		!.[CExpr def_ptr]
instance DummyValue (CBasicValue def_ptr)
instance == (CBasicValue def_ptr) | == def_ptr

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: CCasePatterns def_ptr = 
// -------------------------------------------------------------------------------------------------------------------------------------------------
	  CAlgPatterns		def_ptr			!.[CAlgPattern def_ptr]
	| CBasicPatterns 	!CBasicType		!.[CBasicPattern def_ptr]
instance DummyValue (CCasePatterns def_ptr) | DummyValue def_ptr
instance == (CCasePatterns def_ptr) | == def_ptr

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: CClassDef def_ptr =
// -------------------------------------------------------------------------------------------------------------------------------------------------
	{ cldName					:: !CName
	, cldArity					:: !CArity
	, cldTypeVarScope			:: ![CTypeVarPtr]
	, cldClassRestrictions		:: !.[CClassRestriction def_ptr]
	, cldMembers				:: ![def_ptr]
	, cldDictionary				:: !def_ptr
	, cldInstances				:: ![def_ptr]
	}
instance DummyValue (CClassDef def_ptr) | DummyValue def_ptr

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: CClassRestriction def_ptr =
// -------------------------------------------------------------------------------------------------------------------------------------------------
	{ ccrClass					:: !def_ptr
	, ccrTypes					:: !.[CType def_ptr]
	}
instance DummyValue (CClassRestriction def_ptr) | DummyValue def_ptr
instance == (CClassRestriction def_ptr) | == def_ptr
            
// -------------------------------------------------------------------------------------------------------------------------------------------------
:: CDataConsDef def_ptr =
// -------------------------------------------------------------------------------------------------------------------------------------------------
	{ dcdName					:: !CName
	, dcdArity					:: !CArity
	, dcdAlgType				:: !def_ptr
	, dcdSymbolType				:: !CSymbolType def_ptr
	, dcdInfix					:: !CInfix
	, dcdTypeVarScope			:: ![CTypeVarPtr]       // existential typevariables
	}   
instance DummyValue (CDataConsDef def_ptr) | DummyValue def_ptr

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: CExpr def_ptr = 
// -------------------------------------------------------------------------------------------------------------------------------------------------
	  CExprVar					!CExprVarPtr
	| CShared					!CSharedPtr
	| (@#) infixr 9				!(CExpr def_ptr) !.[CExpr def_ptr]
	| (@@#) infixr 9			!def_ptr !.[CExpr def_ptr]
	| CLet						!CIsStrict !.[.(CExprVarPtr, CExpr def_ptr)] !(CExpr def_ptr)
	| CCase						!(CExpr def_ptr) !(CCasePatterns def_ptr) !.(Maybe (CExpr def_ptr))
	| CBasicValue				!(CBasicValue def_ptr)
	| CCode						!String ![String]
	| CBottom
instance DummyValue (CExpr def_ptr) | DummyValue def_ptr
instance == (CExpr def_ptr) | == def_ptr
      
// -------------------------------------------------------------------------------------------------------------------------------------------------
:: CExprLoc =
// -------------------------------------------------------------------------------------------------------------------------------------------------
	  LocVar					!CExprVarPtr	!Int
	| LocFunApp					!HeapPtr		!Int
	| LocLet					!Int
	| LocCase					!Int
instance DummyValue CExprLoc
instance == CExprLoc

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: CExprVarDef =
// -------------------------------------------------------------------------------------------------------------------------------------------------
	{ evarName					:: !CName
	, evarInfo					:: !CExprVarInfo
	}      
instance DummyValue CExprVarDef

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: CExprVarInfo =
// -------------------------------------------------------------------------------------------------------------------------------------------------
	  EVar_Nothing 
	| EVar_InCase										// used in conversion phase only
	| EVar_Fresh				!CExprVarPtr			// always deleted afterwards
	| EVar_Num					!Int
	| EVar_Subst				!CExprH					// always deleted afterwards
	| EVar_Temp					!CExprH					// NOT always deleted afterwards (used in findStrictVars)
	| EVar_Type					!CTypeH
instance DummyValue CExprVarInfo

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: CFunctionDefinedness
// -------------------------------------------------------------------------------------------------------------------------------------------------
	= CDefinednessUnknown
	| CDefinedBy				![Bool]					// length of list of bools must be equal to arity
														// CDefinedIff indicates the following property:
														//    if all indicated arguments are defined, then
														//    the app of the function as a whole is defined
instance DummyValue CFunctionDefinedness
CF 		:== CDefinednessUnknown
CT 		:== CDefinedBy  [True]
CTT		:== CDefinedBy  [True,  True]
CFT		:== CDefinedBy  [False, True]
CTF		:== CDefinedBy  [True, False]

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: CFunDef def_ptr =
// -------------------------------------------------------------------------------------------------------------------------------------------------
	{ fdName					:: !CName
	, fdOldName					:: !CName				// used when a suffix is generated for instance functions
	, fdArity					:: !CArity
	, fdCaseVariables			:: ![Int]				// indexes of variables where a case distinction is carried out on in the body
	, fdStrictVariables			:: ![Int]				// indexes of variables that are 100% certain to be strict, judging from the body
	, fdInfix					:: !CInfix
	, fdSymbolType				:: !CSymbolType def_ptr
	, fdHasType					:: !Bool
	, fdExprVarScope			:: ![CExprVarPtr]
	, fdBody					:: !CExpr def_ptr
	, fdIsRecordSelector		:: !Bool
	, fdIsRecordUpdater			:: !Bool
	, fdNrDictionaries			:: !Int
	, fdRecordFieldDef			:: !def_ptr
	, fdIsDeltaRule				:: !Bool
	, fdDeltaRule				:: !([LExpr] -> LExpr)
	, fdOpaque					:: !Bool				// used during proving
	, fdDefinedness				:: !CFunctionDefinedness
	}
instance DummyValue (CFunDef def_ptr) | DummyValue def_ptr
   
// -------------------------------------------------------------------------------------------------------------------------------------------------
:: CInfix =
// -------------------------------------------------------------------------------------------------------------------------------------------------
	  CNoInfix
	| CLeftAssociative			!CPriority
	| CRightAssociative			!CPriority
	| CNotAssociative			!CPriority
instance DummyValue CInfix

// -------------------------------------------------------------------------------------------------------------------------------------------------   
:: CInstanceDef def_ptr =
// -------------------------------------------------------------------------------------------------------------------------------------------------   
	{ indName					:: !CName
	, indClass					:: !def_ptr
	, indTypeVarScope			:: ![CTypeVarPtr]
	, indClassArguments			:: !.[CType def_ptr]
	, indClassRestrictions		:: !.[CClassRestriction def_ptr]
	, indMemberFunctions		:: ![def_ptr]
	}
instance DummyValue (CInstanceDef def_ptr) | DummyValue def_ptr
instance < (CInstanceDef def_ptr)

// -------------------------------------------------------------------------------------------------------------------------------------------------   
:: CMemberDef def_ptr =
// -------------------------------------------------------------------------------------------------------------------------------------------------   
	{ mbdName					:: !CName
	, mbdClass					:: !def_ptr
	, mbdSymbolType				:: !CSymbolType def_ptr
	, mbdInfix					:: !CInfix
	}
instance DummyValue (CMemberDef def_ptr) | DummyValue def_ptr

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: CModule =
// -------------------------------------------------------------------------------------------------------------------------------------------------
	{ pmName				:: !CName
	, pmPath				:: !String
	, pmImportedModules		:: ![ModulePtr]
	, pmAlgTypePtrs			:: ![HeapPtr]
	, pmClassPtrs			:: ![HeapPtr]
	, pmDataConsPtrs		:: ![HeapPtr]
	, pmFunPtrs				:: ![HeapPtr]
	, pmInstancePtrs		:: ![HeapPtr]
	, pmMemberPtrs			:: ![HeapPtr]
	, pmRecordTypePtrs		:: ![HeapPtr]
	, pmRecordFieldPtrs		:: ![HeapPtr]
	, pmCompilerStore		:: !Maybe CompilerStore
	, pmCompilerConversion	:: !CompilerConversion
	, pmOriginalNrDclConses	:: !Int						// needed for conversion of dictionary creation conses (which are translated via classes)
	}
instance DummyValue CModule

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: CPredefined =
// -------------------------------------------------------------------------------------------------------------------------------------------------
	{ preTuple				:: !CArity -> CAlgTypeDefH
	, preNormalArray		:: !CAlgTypeDefH
	, preStrictArray		:: !CAlgTypeDefH
	, preUnboxedArray		:: !CAlgTypeDefH
	, preList				:: !CAlgTypeDefH
	, preBuildTuple			:: !CArity -> CDataConsDefH
	, preCons				:: !CDataConsDefH
	, preNil				:: !CDataConsDefH
	, preTupleSelect		:: !CArity Int -> CFunDefH
	, preTC					:: !CClassDefH
	, preTCDict				:: !CRecordTypeDefH
	}
instance DummyValue CPredefined

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: CProject =
// -------------------------------------------------------------------------------------------------------------------------------------------------
	{ prjModules			:: ![ModulePtr]
	, prjPredefined			:: !CPredefined
	, prjAlgTypeHeap		:: !.(Heap CAlgTypeDefH)
	, prjClassHeap			:: !.(Heap CClassDefH)
	, prjDataConsHeap		:: !.(Heap CDataConsDefH)
	, prjFunHeap			:: !.(Heap CFunDefH)
	, prjInstanceHeap		:: !.(Heap CInstanceDefH)
	, prjMemberHeap			:: !.(Heap CMemberDefH)
	, prjRecordTypeHeap		:: !.(Heap CRecordTypeDefH)
	, prjRecordFieldHeap	:: !.(Heap CRecordFieldDefH)
	, prjArraySelectMember	:: !Maybe HeapPtr			// overloaded select
	, prjABCFunctions		:: !ABCFunctions
	}
instance DummyValue CProject

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: CProp def_ptr = 
// -------------------------------------------------------------------------------------------------------------------------------------------------
	  CPropVar					!CPropVarPtr
	| CTrue
	| CFalse
	| CEqual					!(CExpr def_ptr) !(CExpr def_ptr)
	| CNot						!(CProp def_ptr)
	| CAnd						!(CProp def_ptr) !(CProp def_ptr)
	| COr						!(CProp def_ptr) !(CProp def_ptr)
	| CImplies					!(CProp def_ptr) !(CProp def_ptr)
	| CIff						!(CProp def_ptr) !(CProp def_ptr)
	| CExprForall				!CExprVarPtr !(CProp def_ptr)
	| CExprExists				!CExprVarPtr !(CProp def_ptr)
	| CPropForall				!CPropVarPtr !(CProp def_ptr)
	| CPropExists				!CPropVarPtr !(CProp def_ptr)
	| CPredicate				!def_ptr !.[CExpr def_ptr]
instance DummyValue (CProp def_ptr) | DummyValue def_ptr
instance == (CProp def_ptr) | == def_ptr

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: CPropVarDef =
// -------------------------------------------------------------------------------------------------------------------------------------------------
	{ pvarName					:: !CName
	, pvarInfo					:: !CPropVarInfo
	}
instance DummyValue CPropVarDef

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: CPropVarInfo =
// -------------------------------------------------------------------------------------------------------------------------------------------------
	  PVar_Nothing 
	| PVar_Fresh				!CPropVarPtr					// always deleted afterwards
	| PVar_Num					!Int
	| PVar_Subst				!CPropH							// always deleted afterwards
instance DummyValue CPropVarInfo

// -------------------------------------------------------------------------------------------------------------------------------------------------   
:: CRecordFieldDef def_ptr =
// -------------------------------------------------------------------------------------------------------------------------------------------------   
	{ rfName					:: !CName
	, rfIndex					:: !Int							// index in record type
	, rfRecordType				:: !def_ptr
	, rfSymbolType				:: !CSymbolType def_ptr
	, rfTempTypeVarScope		:: !(Maybe [CTypeVarPtr])		// temporarily holds existential types
	, rfSelectorFun				:: !def_ptr
	, rfUpdaterFun				:: !def_ptr
	}
instance DummyValue (CRecordFieldDef def_ptr) | DummyValue def_ptr
   
// -------------------------------------------------------------------------------------------------------------------------------------------------   
:: CRecordTypeDef def_ptr =
// -------------------------------------------------------------------------------------------------------------------------------------------------   
	{ rtdName					:: !CName
	, rtdArity					:: !CArity                     
	, rtdTypeVarScope			:: ![CTypeVarPtr]
	, rtdFields					:: ![def_ptr]
	, rtdRecordConstructor		:: !def_ptr
	, rtdIsDictionary			:: !Bool
	, rtdClassDef				:: !def_ptr
	}
instance DummyValue (CRecordTypeDef def_ptr) | DummyValue def_ptr

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: CShared =
// -------------------------------------------------------------------------------------------------------------------------------------------------
	{ shName					:: !CName
	, shExpr					:: !CExprH
	, shPassed					:: !Bool
	}
instance DummyValue CShared

// =================================================================================================================================================
// All type-variables (except existential ones) must be defined in the scope.
// Use 'getNamedVars' to establish a connection with, for example, the class that the symbol
// type corresponds to (when it is the type of an instantiated member function).
// -------------------------------------------------------------------------------------------------------------------------------------------------
:: CSymbolType def_ptr =
// -------------------------------------------------------------------------------------------------------------------------------------------------
	{ sytTypeVarScope			:: ![CTypeVarPtr]
	, sytArguments				:: !.[CType def_ptr]
	, sytResult					:: !CType def_ptr
	, sytClassRestrictions		:: !.[CClassRestriction def_ptr]
	}
instance DummyValue (CSymbolType def_ptr) | DummyValue def_ptr
      
// -------------------------------------------------------------------------------------------------------------------------------------------------
:: CType def_ptr = 
// -------------------------------------------------------------------------------------------------------------------------------------------------
	  CTypeVar					!CTypeVarPtr
	| (==>) infixr 9			!(CType def_ptr) !(CType def_ptr)
	| (@^)  infixr 9			!(CType def_ptr) !.[CType def_ptr]
	| (@@^) infixr 9			!def_ptr !.[CType def_ptr]
	| CBasicType				!CBasicType
	| CStrict					!(CType def_ptr)
	| CUnTypable                                                // needed for dictionaries
instance DummyValue (CType def_ptr) | DummyValue def_ptr
instance == (CType def_ptr) | == def_ptr
instance < (CType def_ptr)
               
// -------------------------------------------------------------------------------------------------------------------------------------------------
:: CTypeVarDef =
// -------------------------------------------------------------------------------------------------------------------------------------------------
	{ tvarName					:: !CName
	, tvarInfo					:: !CTypeVarInfo
	}
instance DummyValue CTypeVarDef

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: CTypeVarInfo =
// -------------------------------------------------------------------------------------------------------------------------------------------------
	  TVar_Nothing 
	| TVar_Fresh				!CTypeVarPtr
	| TVar_Subst				!CTypeH
instance DummyValue CTypeVarInfo

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: CAlgPatternI			:== CAlgPattern			IndexedPtr
:: CAlgTypeDefI			:== CAlgTypeDef			IndexedPtr
:: CBasicPatternI		:== CBasicPattern		IndexedPtr
:: CBasicValueI			:== CBasicValue			IndexedPtr
:: CCasePatternsI		:== CCasePatterns		IndexedPtr
:: CClassDefI			:== CClassDef			IndexedPtr
:: CClassRestrictionI	:== CClassRestriction	IndexedPtr
:: CDataConsDefI		:== CDataConsDef		IndexedPtr
:: CExprI				:== CExpr				IndexedPtr
:: CFunDefI				:== CFunDef				IndexedPtr
:: CInstanceDefI		:== CInstanceDef		IndexedPtr
:: CMemberDefI			:== CMemberDef			IndexedPtr
:: CPropI				:== CProp				IndexedPtr
:: CRecordFieldDefI		:== CRecordFieldDef		IndexedPtr
:: CRecordTypeDefI		:== CRecordTypeDef		IndexedPtr
:: CSymbolTypeI			:== CSymbolType			IndexedPtr
:: CTypeI				:== CType				IndexedPtr

:: CAlgPatternH			:== CAlgPattern			HeapPtr
:: CAlgTypeDefH			:== CAlgTypeDef			HeapPtr
:: CBasicPatternH		:== CBasicPattern		HeapPtr
:: CBasicValueH			:== CBasicValue			HeapPtr
:: CCasePatternsH		:== CCasePatterns		HeapPtr
:: CClassDefH			:== CClassDef			HeapPtr
:: CClassRestrictionH	:== CClassRestriction	HeapPtr
:: CDataConsDefH		:== CDataConsDef		HeapPtr
:: CExprH				:== CExpr				HeapPtr
:: CFunDefH				:== CFunDef				HeapPtr
:: CInstanceDefH		:== CInstanceDef		HeapPtr
:: CMemberDefH			:== CMemberDef			HeapPtr
:: CPropH				:== CProp				HeapPtr
:: CRecordFieldDefH		:== CRecordFieldDef		HeapPtr
:: CRecordTypeDefH		:== CRecordTypeDef		HeapPtr
:: CSymbolTypeH			:== CSymbolType			HeapPtr
:: CTypeH				:== CType				HeapPtr
// -------------------------------------------------------------------------------------------------------------------------------------------------
   
// -------------------------------------------------------------------------------------------------------------------------------------------------
:: ModuleName				:== String
:: ModuleKey				:== Int
:: ModulePtr				:== Ptr CModule

:: CArity					:== Int
:: CDefIndex				:== Int
:: CExprVarPtr				:== Ptr CExprVarDef
:: CIsExistential			:== Bool
:: CIsStrict				:== Bool
:: CName					:== String
:: CPriority				:== Int
:: CPropVarPtr				:== Ptr CPropVarDef
:: CSharedPtr				:== Ptr CShared
:: CTypeVarPtr				:== Ptr CTypeVarDef

SparkleCreationDate			:== "02-Jul-2008"
SparkleVersion				:== "1.0"
// -------------------------------------------------------------------------------------------------------------------------------------------------   

// -------------------------------------------------------------------------------------------------------------------------------------------------   
HExprVar			:: !CExprVarPtr				-> CExprH
HShared				:: !CSharedPtr				-> CExprH
HCode				:: !String ![String]		-> CExprH
HBottom				::							   CExprH

HPropVar			:: !CPropVarPtr				-> CPropH
HTrue				::							   CPropH
HFalse				::							   CPropH
// -------------------------------------------------------------------------------------------------------------------------------------------------   












class depth e		:: !e -> Int
instance depth CExprH

functionType		:: [CType a] -> CType a
getDefiningArgs		:: !CFunctionDefinedness -> (!Bool, ![Bool])
isInfix				:: !CInfix -> Bool
isNoInfix			:: !CInfix -> Bool
isLeftAssociative	:: !CInfix -> Bool
isRightAssociative	:: !CInfix -> Bool
getPriority			:: !CInfix -> Int
ptrKind				:: !HeapPtr -> DefinitionKind
ptrModule			:: !HeapPtr -> ModulePtr
zip3				:: [a] [b] [c] -> [(a,b,c)]
unknown				:: !CFunctionDefinedness -> Bool