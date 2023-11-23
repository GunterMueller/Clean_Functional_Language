/*
** Program: Clean Prover System
** Module:  CoreTypes (.icl)
** 
** Author:  Maarten de Mol
** Created: 22 August 2000
*/

implementation module 
	CoreTypes

import
	StdEnv,
	Heap,
	ProverOptions,
	Errors,
	LTypes,
	frontend
	, RWSDebug

from StdSystem import applicationpath

// NOT (by a long shot) complete as yet.
// ------------------------------------------------------------------------------------------------------------------------
:: ABCFunctions =
// ------------------------------------------------------------------------------------------------------------------------
	{ stdBool				:: !BoolFunctions
	, stdInt				:: !IntFunctions
	, stdString				:: !StringFunctions
	}
instance DummyValue ABCFunctions
	where DummyValue =	{ stdBool					= DummyValue
						, stdInt					= DummyValue
						, stdString					= DummyValue
						}

// ------------------------------------------------------------------------------------------------------------------------
:: BoolFunctions =
// ------------------------------------------------------------------------------------------------------------------------
	{ boolAnd				:: !HeapPtr
	, boolNot				:: !HeapPtr
	, boolOr				:: !HeapPtr
	}
instance DummyValue BoolFunctions
	where DummyValue =	{ boolAnd					= DummyValue
						, boolNot					= DummyValue
						, boolOr					= DummyValue
						}

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
	where DummyValue =	{ intAdd					= DummyValue
						, intBitAnd					= DummyValue
						, intBitNot					= DummyValue
						, intBitOr					= DummyValue
						, intBitXor					= DummyValue
						, intDivide					= DummyValue
						, intEqual					= DummyValue
						, intIsEven					= DummyValue
						, intIsOdd					= DummyValue
						, intModulo					= DummyValue
						, intMultiply				= DummyValue
						, intNegate					= DummyValue
						, intOne					= DummyValue
						, intSmaller				= DummyValue
						, intSubtract				= DummyValue
						, intZero					= DummyValue
						}

// ------------------------------------------------------------------------------------------------------------------------
:: StringFunctions =
// ------------------------------------------------------------------------------------------------------------------------
	{ stringEqual			:: !HeapPtr
	}
instance DummyValue StringFunctions
	where DummyValue =	{ stringEqual				= DummyValue
						}





































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
	where DummyValue	=	{ optCombineLets			= True
							, optAutomaticDiscard		= True
							, optDisplaySpecial			= True
							, optHintsViewThreshold		= 50
							, optHintsApplyThreshold	= 100
							}

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
	where DummyValue = CheckedTypeDef

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance toString CompilerDefinitionKind
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	toString CheckedTypeDef 	= "CheckedTypeDef"
	toString ClassDef			= "ClassDef"
	toString ClassInstance		= "ClassInstance"
	toString ConsDef			= "ConsDef"
	toString FunDef				= "FunDef"
	toString FunType			= "FunType"
	toString MemberDef			= "MemberDef"
	toString SelectorDef		= "SelectorDef"

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: IndexedPtr =
// -------------------------------------------------------------------------------------------------------------------------------------------------
	  IclDefinitionPtr	!ModuleName !Int !CName !CompilerDefinitionKind !CDefIndex
	| DclDefinitionPtr	!ModuleName      !CName !CompilerDefinitionKind !CDefIndex
instance DummyValue IndexedPtr
	where DummyValue = DclDefinitionPtr "" "" CheckedTypeDef 65535

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
	where DummyValue = CTuplePtr 10000
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
	where DummyValue = CAlgType

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance toString DefinitionKind
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	toString CAlgType				= "algebraic type"
	toString CClass					= "class"
	toString CDataCons				= "data-constructor"
	toString CFun					= "function"
	toString CInstance				= "class instance"
	toString CMember				= "class member"
	toString CRecordField			= "record field"
	toString CRecordType			= "record type"

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
	where DummyValue = {csAlgTypeDefs = [], csClassDefs = [], csDataConsDefs = [], csFunDefs = [],
						csInstanceDefs = [], csMemberDefs = [], csRecordFieldDefs = [], csRecordTypeDefs = [],
						csImports = []}

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
	where DummyValue = {ccCheckedTypePtrs = {}, ccClassPtrs = {}, ccConsPtrs = {}, ccFunPtrs = {},
						ccInstancePtrs = {}, ccMemberPtrs = {}, ccSelectorPtrs = {},
						ccDictionaries = [], ccConversionTable = {}, ccDclIclConversions = {}}

























// -------------------------------------------------------------------------------------------------------------------------------------------------   
:: CAlgPattern def_ptr =
// -------------------------------------------------------------------------------------------------------------------------------------------------   
	{ atpDataCons				:: !def_ptr
	, atpExprVarScope			:: ![CExprVarPtr]
	, atpResult					:: !CExpr def_ptr
	}
instance DummyValue (CAlgPattern def_ptr) | DummyValue def_ptr
	where DummyValue = {atpDataCons = DummyValue, atpExprVarScope = [], atpResult = CBottom}
                                  
// -------------------------------------------------------------------------------------------------------------------------------------------------   
:: CAlgTypeDef def_ptr =
// -------------------------------------------------------------------------------------------------------------------------------------------------   
	{ atdName					:: !CName
	, atdArity					:: !CArity                
	, atdTypeVarScope			:: ![CTypeVarPtr]
	, atdConstructors			:: ![def_ptr]
	}
instance DummyValue (CAlgTypeDef def_ptr) | DummyValue def_ptr
	where DummyValue = {atdName = "", atdArity = 0, atdTypeVarScope = [], 
						atdConstructors = []}
   
// -------------------------------------------------------------------------------------------------------------------------------------------------   
:: CBasicPattern def_ptr =
// -------------------------------------------------------------------------------------------------------------------------------------------------   
	{ bapBasicValue				:: !CBasicValue def_ptr
	, bapResult					:: !CExpr def_ptr
	}
instance DummyValue (CBasicPattern def_ptr) | DummyValue def_ptr
	where DummyValue = {bapBasicValue = DummyValue, bapResult = CBottom}

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: CBasicType = 
// -------------------------------------------------------------------------------------------------------------------------------------------------
	  CInteger
	| CCharacter
	| CRealNumber
	| CBoolean
	| CString
instance DummyValue CBasicType
	where DummyValue = CInteger

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
	where DummyValue = CBasicInteger DummyValue

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: CCasePatterns def_ptr = 
// -------------------------------------------------------------------------------------------------------------------------------------------------
	  CAlgPatterns		def_ptr			!.[CAlgPattern def_ptr]
	| CBasicPatterns 	!CBasicType		!.[CBasicPattern def_ptr]
instance DummyValue (CCasePatterns def_ptr) | DummyValue def_ptr
	where DummyValue = CAlgPatterns DummyValue [] 

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
	where DummyValue = {cldName = "", cldArity = 0, cldTypeVarScope = [],
						cldClassRestrictions = [], cldMembers = [], cldDictionary = DummyValue,
						cldInstances = []}

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: CClassRestriction def_ptr =
// -------------------------------------------------------------------------------------------------------------------------------------------------
	{ ccrClass					:: !def_ptr
	, ccrTypes					:: !.[CType def_ptr]
	}
instance DummyValue (CClassRestriction def_ptr) | DummyValue def_ptr
	where DummyValue = {ccrClass = DummyValue, ccrTypes = []}
            
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
	where DummyValue =	{dcdName = "", dcdArity = 0, dcdAlgType = DummyValue, 
						 dcdSymbolType = DummyValue, dcdInfix = CNoInfix, dcdTypeVarScope = []}

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
	where DummyValue = CBottom

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: CExprLoc =
// -------------------------------------------------------------------------------------------------------------------------------------------------
	  LocVar					!CExprVarPtr	!Int
	| LocFunApp					!HeapPtr		!Int
	| LocLet					!Int
	| LocCase					!Int
instance DummyValue CExprLoc
	where DummyValue = LocLet (-1)
      
// -------------------------------------------------------------------------------------------------------------------------------------------------
:: CExprVarDef =
// -------------------------------------------------------------------------------------------------------------------------------------------------
	{ evarName					:: !CName
	, evarInfo					:: !CExprVarInfo
	}      
instance DummyValue CExprVarDef
	where DummyValue = {evarName = "", evarInfo = DummyValue}

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
	where DummyValue = EVar_Nothing

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: CFunctionDefinedness
// -------------------------------------------------------------------------------------------------------------------------------------------------
	= CDefinednessUnknown
	| CDefinedBy				![Bool]					// length of list of bools must be equal to arity
														// CDefinedIff indicates the following property:
														//    if all indicated arguments are defined, then
														//    the app of the function as a whole is defined
instance DummyValue CFunctionDefinedness
	where DummyValue = CDefinednessUnknown
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
//	, fdDeltaRule				:: !Maybe ([CExprH] -> (Error, CExprH))
	, fdIsDeltaRule				:: !Bool
	, fdDeltaRule				:: !([LExpr] -> LExpr)
	, fdOpaque					:: !Bool				// used during proving
	, fdDefinedness				:: !CFunctionDefinedness
	}
instance DummyValue (CFunDef def_ptr) | DummyValue def_ptr
	where DummyValue =	{fdName = "", fdOldName = "", fdArity = 0, fdCaseVariables = [], fdStrictVariables = [], fdExprVarScope = [],
						 fdHasType = False, fdSymbolType = DummyValue, fdInfix = DummyValue, fdBody = DummyValue,
						 fdIsRecordSelector = False, fdIsRecordUpdater = False, fdRecordFieldDef = DummyValue,
						 fdIsDeltaRule = False, fdDeltaRule = (\_->DummyValue), fdOpaque = False, fdNrDictionaries = 0, fdDefinedness = DummyValue}
   
// -------------------------------------------------------------------------------------------------------------------------------------------------
:: CInfix =
// -------------------------------------------------------------------------------------------------------------------------------------------------
	  CNoInfix
	| CLeftAssociative			!CPriority
	| CRightAssociative			!CPriority
	| CNotAssociative			!CPriority
instance DummyValue CInfix
	where DummyValue = CNoInfix   

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
	where DummyValue = {indName = "", indClass = DummyValue, indTypeVarScope = [], 
						indClassArguments = [], indClassRestrictions = [], indMemberFunctions = []}

// -------------------------------------------------------------------------------------------------------------------------------------------------   
:: CMemberDef def_ptr =
// -------------------------------------------------------------------------------------------------------------------------------------------------   
	{ mbdName					:: !CName
	, mbdClass					:: !def_ptr
	, mbdSymbolType				:: !CSymbolType def_ptr
	, mbdInfix					:: !CInfix
	}
instance DummyValue (CMemberDef def_ptr) | DummyValue def_ptr
	where DummyValue = {mbdName = "", mbdClass = DummyValue, mbdSymbolType = DummyValue, mbdInfix = CNoInfix}

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
	where DummyValue = {pmName = "", pmPath = "", pmImportedModules = [], pmAlgTypePtrs = [], 
						pmClassPtrs = [], pmDataConsPtrs = [], pmFunPtrs = [],
						pmInstancePtrs = [], pmMemberPtrs = [], pmRecordTypePtrs = [],
						pmRecordFieldPtrs = [], pmCompilerStore = Nothing, pmCompilerConversion = DummyValue,
						pmOriginalNrDclConses = 0}

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
	where DummyValue =	{ preTuple				= \arity -> DummyValue
						, preNormalArray		= DummyValue
						, preStrictArray		= DummyValue
						, preUnboxedArray		= DummyValue
						, preList				= DummyValue
						, preBuildTuple			= \arity -> DummyValue
						, preCons				= DummyValue
						, preNil				= DummyValue
						, preTupleSelect		= \arity num -> DummyValue
						, preTC					= DummyValue
						, preTCDict				= DummyValue
						}

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
	where DummyValue = {prjModules = [], prjPredefined = DummyValue,
						prjAlgTypeHeap = newHeap, prjClassHeap = newHeap, prjDataConsHeap = newHeap,
						prjFunHeap = newHeap, prjInstanceHeap = newHeap, prjMemberHeap = newHeap,
						prjRecordTypeHeap = newHeap, prjRecordFieldHeap = newHeap,
						prjArraySelectMember = Nothing, prjABCFunctions = DummyValue}

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
	where DummyValue = CTrue

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: CPropVarDef =
// -------------------------------------------------------------------------------------------------------------------------------------------------
	{ pvarName					:: !CName
	, pvarInfo					:: !CPropVarInfo
	}
instance DummyValue CPropVarDef
	where DummyValue = {pvarName = "", pvarInfo = DummyValue}

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: CPropVarInfo =
// -------------------------------------------------------------------------------------------------------------------------------------------------
	  PVar_Nothing 
	| PVar_Fresh				!CPropVarPtr					// always deleted afterwards
	| PVar_Num					!Int
	| PVar_Subst				!CPropH							// always deleted afterwards
instance DummyValue CPropVarInfo
	where DummyValue = PVar_Nothing

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
	where DummyValue =	{rfName = "", rfIndex = 0, rfRecordType = DummyValue, rfSymbolType = DummyValue, 
						 rfTempTypeVarScope = Nothing, rfSelectorFun = DummyValue, rfUpdaterFun = DummyValue}
   
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
	where DummyValue = {rtdName = "", rtdArity = 0, rtdTypeVarScope = [], 
						rtdFields = [], rtdRecordConstructor = DummyValue,
						rtdIsDictionary = False, rtdClassDef = DummyValue}   

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: CShared =
// -------------------------------------------------------------------------------------------------------------------------------------------------
	{ shName					:: !CName
	, shExpr					:: !CExprH
	, shPassed					:: !Bool
	}
instance DummyValue CShared
	where DummyValue = {shName = "", shExpr = CBottom, shPassed = False}

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
	where DummyValue = {sytArguments = [], sytTypeVarScope = [], 
						sytResult = DummyValue, sytClassRestrictions = []}
      
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
	where DummyValue = CUnTypable
               
// -------------------------------------------------------------------------------------------------------------------------------------------------
:: CTypeVarDef =
// -------------------------------------------------------------------------------------------------------------------------------------------------
	{ tvarName					:: !CName
	, tvarInfo					:: !CTypeVarInfo
	}
instance DummyValue CTypeVarDef
	where DummyValue = {tvarName = "", tvarInfo = DummyValue}

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: CTypeVarInfo =
// -------------------------------------------------------------------------------------------------------------------------------------------------
	  TVar_Nothing 
	| TVar_Fresh				!CTypeVarPtr
	| TVar_Subst				!CTypeH
instance DummyValue CTypeVarInfo
	where DummyValue = TVar_Nothing

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
instance == CompilerDefinitionKind
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	(==) CheckedTypeDef		CheckedTypeDef	= True
	(==) ClassDef			ClassDef		= True
	(==) ClassInstance		ClassInstance	= True
	(==) ConsDef			ConsDef			= True
	(==) FunDef				FunDef			= True
	(==) FunType			FunType			= True
	(==) MemberDef			MemberDef		= True
	(==) SelectorDef		SelectorDef		= True
	(==) _					_				= False

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance == DefinitionKind
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	(==) CAlgType			CAlgType		= True
	(==) CClass				CClass			= True
	(==) CDataCons			CDataCons		= True
	(==) CFun				CFun			= True
	(==) CInstance			CInstance		= True
	(==) CMember			CMember			= True
	(==) CRecordField		CRecordField	= True
	(==) CRecordType		CRecordType		= True
	(==) _					_				= False

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance == HeapPtr
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	(==) (CAlgTypePtr _ ptr1)		(CAlgTypePtr _ ptr2)		= ptr1 == ptr2
	(==) (CClassPtr _ ptr1)			(CClassPtr _ ptr2)			= ptr1 == ptr2
	(==) (CDataConsPtr _ ptr1)		(CDataConsPtr _ ptr2)		= ptr1 == ptr2
	(==) (CFunPtr _ ptr1)			(CFunPtr _ ptr2)			= ptr1 == ptr2
	(==) (CInstancePtr _ ptr1)		(CInstancePtr _ ptr2)		= ptr1 == ptr2
	(==) (CMemberPtr _ ptr1)		(CMemberPtr _ ptr2)			= ptr1 == ptr2
	(==) (CRecordFieldPtr _ ptr1)	(CRecordFieldPtr _ ptr2)	= ptr1 == ptr2
	(==) (CRecordTypePtr _ ptr1)	(CRecordTypePtr _ ptr2)		= ptr1 == ptr2
	(==) (CTuplePtr a1)				(CTuplePtr a2)				= a1 == a2
	(==) CNormalArrayPtr			CNormalArrayPtr				= True
	(==) CStrictArrayPtr			CStrictArrayPtr				= True
	(==) CUnboxedArrayPtr			CUnboxedArrayPtr			= True
	(==) CListPtr					CListPtr					= True
	(==) (CBuildTuplePtr a1)		(CBuildTuplePtr a2)			= a1 == a2
	(==) CConsPtr					CConsPtr					= True
	(==) CNilPtr					CNilPtr						= True
	(==) (CTupleSelectPtr a1 n1)	(CTupleSelectPtr a2 n2)		= a1 == a2 && n1 == n2
	(==) CTCPtr						CTCPtr						= True
	(==) CTCDictPtr					CTCDictPtr					= True
	(==) _							_							= False

// -------------------------------------------------------------------------------------------------------------------------------------------------   
instance == (CAlgPattern def_ptr) | == def_ptr
// -------------------------------------------------------------------------------------------------------------------------------------------------   
where
	(==) pattern1 pattern2		= (pattern1.atpDataCons			== pattern2.atpDataCons) &&
								  (pattern1.atpExprVarScope		== pattern2.atpExprVarScope) &&
								  (pattern1.atpResult			== pattern2.atpResult)

// -------------------------------------------------------------------------------------------------------------------------------------------------   
instance == (CBasicPattern def_ptr) | == def_ptr
// -------------------------------------------------------------------------------------------------------------------------------------------------   
where
	(==) pattern1 pattern2		= (pattern1.bapBasicValue		== pattern2.bapBasicValue) &&
								  (pattern1.bapResult			== pattern2.bapResult)

// -------------------------------------------------------------------------------------------------------------------------------------------------   
instance == CBasicType
// -------------------------------------------------------------------------------------------------------------------------------------------------   
where
	(==) CInteger			CInteger		= True
	(==) CCharacter			CCharacter		= True
	(==) CRealNumber		CRealNumber		= True
	(==) CBoolean			CBoolean		= True
	(==) CString			CString			= True
	(==) _					_				= False

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance == (CBasicValue def_ptr) | == def_ptr
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	(==) (CBasicInteger int1)		(CBasicInteger int2)		= int1 == int2
	(==) (CBasicCharacter char1)	(CBasicCharacter char2)		= char1 == char2
	(==) (CBasicRealNumber real1)	(CBasicRealNumber real2)	= real1 == real2
	(==) (CBasicBoolean bool1)		(CBasicBoolean bool2)		= bool1 == bool2
	(==) (CBasicString string1)		(CBasicString string2)		= string1 == string2
	(==) (CBasicArray l1)			(CBasicArray l2)			= l1 == l2
	(==) _							_							= False

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance == (CCasePatterns def_ptr) | == def_ptr
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	(==) (CAlgPatterns ptr1 patterns1)		(CAlgPatterns ptr2 patterns2)		= ptr1 == ptr2 && patterns1 == patterns2
	(==) (CBasicPatterns type1 patterns1)	(CBasicPatterns type2 patterns2)	= type1 == type2 && patterns1 == patterns2
	(==) _									_									= False

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance == (CClassRestriction def_ptr) | == def_ptr
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	(==) restr1 restr2			= (restr1.ccrClass				== restr2.ccrClass) &&
								  (restr1.ccrTypes				== restr2.ccrTypes)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance == (CExpr def_ptr) | == def_ptr
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	(==) (CExprVar ptr1)			(CExprVar ptr2)				= ptr1 == ptr2
	(==) (CShared ptr1)				(CShared ptr2)				= ptr1 == ptr2
	(==) (expr1 @# exprs1)			(expr2 @# exprs2)			= (expr1 == expr2) && (exprs1 == exprs2)
	(==) (ptr1 @@# exprs1)			(ptr2 @@# exprs2)			= (ptr1 == ptr2) && (exprs1 == exprs2)
	(==) (CLet strict1 binds1 expr1)(CLet strict2 binds2 expr2)	= (strict1 == strict2) && (binds1 == binds2) && (expr1 == expr2)
	(==) (CCase expr1 cases1 def1)	(CCase expr2 cases2 def2)	= (expr1 == expr2) && (cases1 == cases2) && (def1 == def2)
	(==) (CBasicValue value1)		(CBasicValue value2)		= value1 == value2
	(==) (CCode type1 code1)		(CCode type2 code2)			= (type1 == type2) && (code1 == code2)
	(==) CBottom					CBottom						= True
	(==) _							_							= False

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance == CExprLoc
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	(==) (LocVar x i)				(LocVar y j)				= x == y && i == j
	(==) (LocFunApp f i)			(LocFunApp g j)				= f == g && i == j
	(==) (LocLet i)					(LocLet j)					= i == j
	(==) (LocCase i)				(LocCase j)					= i == j
	(==) _							_							= False

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance == (CProp def_ptr) | == def_ptr
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	(==) (CPropVar ptr1)			(CPropVar ptr2)				= ptr1 == ptr2
	(==) CTrue						CTrue						= True
	(==) CFalse						CFalse						= True
	(==) (CEqual e1 e2)				(CEqual e3 e4)				= (e1 == e3) && (e2 == e4)
	(==) (CNot p1)					(CNot p2)					= p1 == p2
	(==) (CAnd p1 q1)				(CAnd p2 q2)				= (p1 == p2) && (q1 == q2)
	(==) (COr p1 q1)				(COr p2 q2)					= (p1 == p2) && (q1 == q2)
	(==) (CImplies p1 q1)			(CImplies p2 q2)			= (p1 == p2) && (q1 == q2)
	(==) (CIff p1 q1)				(CIff p2 q2)				= (p1 == p2) && (q1 == q2)
	(==) (CExprForall x1 p1)		(CExprForall x2 p2)			= (x1 == x2) && (p1 == p2)
	(==) (CExprExists x1 p1)		(CExprExists x2 p2)			= (x1 == x2) && (p1 == p2)
	(==) (CPropForall x1 p1)		(CPropForall x2 p2)			= (x1 == x2) && (p1 == p2)
	(==) (CPropExists x1 p1)		(CPropExists x2 p2)			= (x1 == x2) && (p1 == p2)
	(==) (CPredicate ptr1 es1)		(CPredicate ptr2 es2)		= (ptr1 == ptr2) && (es1 == es2)
	(==) _							_							= False

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance == (CType def_ptr) | == def_ptr
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	(==) (CTypeVar ptr1)			(CTypeVar ptr2)				= ptr1 == ptr2
	(==) (type1 ==> type2)			(type3 ==> type4)			= (type1 == type3) && (type2 == type4)
	(==) (type1 @^ types1)			(type2 @^ types2)			= (type1 == type2) && (types1 == types2)
	(==) (ptr1 @@^ types1)			(ptr2 @@^ types2)			= (ptr1 == ptr2) && (types1 == types2)
	(==) (CBasicType basictype1)	(CBasicType basictype2)		= basictype1 == basictype2
	(==) (CStrict type1)			(CStrict type2)				= type1 == type2
	(==) CUnTypable					CUnTypable					= True
	(==) _							_							= False

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance < (CType def_ptr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	(<) (CBasicType _) (CBasicType _)
		= False
	(<) (CBasicType _) other
		= True
	(<) (_ @@^ _) (_ @^ _)
		= True
	(<) (_ @@^ types1) (_ @@^ types2)
		= types1 < types2
	(<) (type1 @^ types1) (type2 @^ types2)
		= [type1:types1] < [type2:types2]
	(<) (type1 ==> type2) (type3 ==> type4)
		= [type1,type2] < [type3,type4]
	(<) _ (CTypeVar ptr)
		= True
	(<) _ _
		= False

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance < (CInstanceDef def_ptr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	(<) indef1 indef2
		= indef1.indClassArguments < indef2.indClassArguments












// -------------------------------------------------------------------------------------------------------------------------------------------------
class depth e
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	depth :: !e -> Int

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance depth (Maybe e) | depth e
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	depth (Just e)
		= depth e
	depth Nothing
		= 0

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance depth [e] | depth e
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	depth [e:es]
		= max (depth e) (depth es)
	depth []
		= 0

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance depth CAlgPatternH
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	depth pattern
		= depth pattern.atpResult

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance depth CBasicPatternH
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	depth pattern
		= depth pattern.bapResult

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance depth CCasePatternsH
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	depth (CAlgPatterns _ patterns)
		= depth patterns
	depth (CBasicPatterns _ patterns)
		= depth patterns

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance depth CExprH
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	depth (e @# es)
		= 1 + depth [e:es]
	depth (ptr @@# es)
		= 1 + depth es
	depth (CLet _ defs e)
		= 1 + depth [e:map snd defs]
	depth (CCase e patterns mb_default)
		= 1 + max (depth e) (max (depth patterns) (depth mb_default))
	depth (CBasicValue (CBasicArray es))
		= 1 + depth es
	depth _
		= 0























// -------------------------------------------------------------------------------------------------------------------------------------------------
HExprVar :: !CExprVarPtr -> CExprH
// -------------------------------------------------------------------------------------------------------------------------------------------------
HExprVar ptr
	= CExprVar ptr

// -------------------------------------------------------------------------------------------------------------------------------------------------
HShared :: !CSharedPtr -> CExprH
// -------------------------------------------------------------------------------------------------------------------------------------------------
HShared ptr
	= CShared ptr

// -------------------------------------------------------------------------------------------------------------------------------------------------
HCode :: !String ![String] -> CExprH
// -------------------------------------------------------------------------------------------------------------------------------------------------
HCode type contents
	= HCode type contents

// -------------------------------------------------------------------------------------------------------------------------------------------------
HBottom :: CExprH
// -------------------------------------------------------------------------------------------------------------------------------------------------
HBottom
	= CBottom

// -------------------------------------------------------------------------------------------------------------------------------------------------
HPropVar :: !CPropVarPtr -> CPropH
// -------------------------------------------------------------------------------------------------------------------------------------------------
HPropVar ptr
	= CPropVar ptr

// -------------------------------------------------------------------------------------------------------------------------------------------------
HTrue :: CPropH
// -------------------------------------------------------------------------------------------------------------------------------------------------
HTrue
	= CTrue

// -------------------------------------------------------------------------------------------------------------------------------------------------
HFalse :: CPropH
// -------------------------------------------------------------------------------------------------------------------------------------------------
HFalse
	= CFalse













// -------------------------------------------------------------------------------------------------------------------------------------------------
functionType :: [CType a] -> CType a
// -------------------------------------------------------------------------------------------------------------------------------------------------
functionType []
	= abort "Error in functionType in module CoreTypes: called on empty list."
functionType [type]
	= type
functionType [type:types]
	= type ==> (functionType types)

// -------------------------------------------------------------------------------------------------------------------------------------------------   
getDefiningArgs :: !CFunctionDefinedness -> (!Bool, ![Bool])
// -------------------------------------------------------------------------------------------------------------------------------------------------   
getDefiningArgs CDefinednessUnknown
	= (False, [])
getDefiningArgs (CDefinedBy args)
	= (True, args)

// -------------------------------------------------------------------------------------------------------------------------------------------------   
isInfix :: !CInfix -> Bool
// -------------------------------------------------------------------------------------------------------------------------------------------------   
isInfix CNoInfix	= False
isInfix _			= True

// -------------------------------------------------------------------------------------------------------------------------------------------------   
isNoInfix :: !CInfix -> Bool
// -------------------------------------------------------------------------------------------------------------------------------------------------   
isNoInfix CNoInfix	= True
isNoInfix _			= False

// -------------------------------------------------------------------------------------------------------------------------------------------------   
isLeftAssociative :: !CInfix -> Bool
// -------------------------------------------------------------------------------------------------------------------------------------------------   
isLeftAssociative (CLeftAssociative _)	= True
isLeftAssociative _						= False

// -------------------------------------------------------------------------------------------------------------------------------------------------   
isRightAssociative :: !CInfix -> Bool
// -------------------------------------------------------------------------------------------------------------------------------------------------   
isRightAssociative (CRightAssociative _)	= True
isRightAssociative _						= False

// -------------------------------------------------------------------------------------------------------------------------------------------------   
getPriority :: !CInfix -> Int
// -------------------------------------------------------------------------------------------------------------------------------------------------   
getPriority (CLeftAssociative p)	= p
getPriority (CRightAssociative p)	= p
getPriority (CNotAssociative p)		= p
getPriority _						= 0

// -------------------------------------------------------------------------------------------------------------------------------------------------
ptrKind :: !HeapPtr -> DefinitionKind
// -------------------------------------------------------------------------------------------------------------------------------------------------
ptrKind (CAlgTypePtr _ _)		= CAlgType
ptrKind (CClassPtr _ _)			= CClass
ptrKind (CDataConsPtr _ _)		= CDataCons
ptrKind (CFunPtr _ _)			= CFun
ptrKind (CInstancePtr _ _)		= CInstance
ptrKind (CMemberPtr _ _)		= CMember
ptrKind (CRecordFieldPtr _ _)	= CRecordField
ptrKind (CRecordTypePtr _ _)	= CRecordType
ptrKind (CTuplePtr _)			= CAlgType
ptrKind CNormalArrayPtr			= CAlgType
ptrKind CStrictArrayPtr			= CAlgType
ptrKind CUnboxedArrayPtr		= CAlgType
ptrKind CListPtr				= CAlgType
ptrKind (CBuildTuplePtr _)		= CDataCons
ptrKind CNilPtr					= CDataCons
ptrKind CConsPtr				= CDataCons
ptrKind (CTupleSelectPtr _ _)	= CFun
ptrKind CTCPtr					= CClass
ptrKind CTCDictPtr				= CRecordType

// -------------------------------------------------------------------------------------------------------------------------------------------------
ptrModule :: !HeapPtr -> ModulePtr
// -------------------------------------------------------------------------------------------------------------------------------------------------
ptrModule (CAlgTypePtr m _)		= m
ptrModule (CClassPtr m _)		= m
ptrModule (CDataConsPtr m _)	= m
ptrModule (CFunPtr m _)			= m
ptrModule (CInstancePtr m _)	= m
ptrModule (CMemberPtr m _)		= m
ptrModule (CRecordFieldPtr m _)	= m
ptrModule (CRecordTypePtr m _)	= m
ptrModule (CTuplePtr _)			= nilPtr
ptrModule CNormalArrayPtr		= nilPtr
ptrModule CStrictArrayPtr		= nilPtr
ptrModule CUnboxedArrayPtr		= nilPtr
ptrModule CListPtr				= nilPtr
ptrModule (CBuildTuplePtr _)	= nilPtr
ptrModule CNilPtr				= nilPtr
ptrModule CConsPtr				= nilPtr
ptrModule (CTupleSelectPtr _ _)	= nilPtr
ptrModule CTCPtr				= nilPtr
ptrModule CTCDictPtr			= nilPtr

// -------------------------------------------------------------------------------------------------------------------------------------------------   
unknown :: !CFunctionDefinedness -> Bool
// -------------------------------------------------------------------------------------------------------------------------------------------------   
unknown CDefinednessUnknown
	= True
unknown (CDefinedBy _)
	= False

// -------------------------------------------------------------------------------------------------------------------------------------------------   
zip3 :: [a] [b] [c] -> [(a,b,c)]
// -------------------------------------------------------------------------------------------------------------------------------------------------   
zip3 [x:xs] [y:ys] [z:zs]	= [(x,y,z):zip3 xs ys zs]
zip3 _ _ _					= []