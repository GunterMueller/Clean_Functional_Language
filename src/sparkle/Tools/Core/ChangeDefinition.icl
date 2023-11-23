/*
** Program: Clean Prover System
** Module:  ChangeDefinition (.icl)
** 
** Author:  Maarten de Mol
** Created: 23 August 2000
**
** Note: Operates under the assumption that no sharing is present.
*/

implementation module 
	ChangeDefinition

import
	StdEnv,
	CoreTypes,
	CoreAccess,
	Predefined
	, RWSDebug

// -------------------------------------------------------------------------------------------------------------------------------------------------
find2 :: !String ![(String, a)] -> (!Bool, !a) | DummyValue a
// -------------------------------------------------------------------------------------------------------------------------------------------------
find2 this_name [(name,key):modules]
	| this_name == name			= (True, key)
	= find2 this_name modules
find2 this_name []
	= (False, DummyValue)

// -------------------------------------------------------------------------------------------------------------------------------------------------
find :: !String ![ModuleName] ![ModulePtr] -> (!Bool, !ModulePtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
find this_name [name:names] [ptr:ptrs]
	| this_name == name			= (True, ptr)
	= find this_name names ptrs
find this_name [] []
	= (False, nilPtr)

// -------------------------------------------------------------------------------------------------------------------------------------------------
multiple_find :: !String ![String] ![ModuleName] ![ModulePtr] -> (!Bool, ![ModulePtr])
// -------------------------------------------------------------------------------------------------------------------------------------------------
multiple_find icl_name ["_predefined":names] offered_names offered_ptrs
	= multiple_find icl_name names offered_names offered_ptrs
multiple_find icl_name [name:names] offered_names offered_ptrs
	| name == icl_name			= multiple_find icl_name names offered_names offered_ptrs
	# (found, ptr)				= find name offered_names offered_ptrs
	| not found					= (False, [])
	# (found, ptrs)				= multiple_find icl_name names offered_names offered_ptrs
	| not found					= (False, [])
	= (True, [ptr:ptrs])
multiple_find icl_name [] offered_names offered_ptrs
	= (True, [])

// -------------------------------------------------------------------------------------------------------------------------------------------------
findConversions :: !(Maybe CompilerConversion) !String ![ModuleName] ![ModulePtr] !*CHeaps -> (!Bool, !CompilerConversion, !*CHeaps)
// -------------------------------------------------------------------------------------------------------------------------------------------------
findConversions (Just conversions) _ _ _ heaps
	= (True, conversions, heaps)
findConversions Nothing dcl_name all_names all_ptrs heaps
	# (found, ptr)				= find dcl_name all_names all_ptrs
	| not found					= (False, DummyValue, heaps)
	# (mod, heaps)				= readPointer ptr heaps
	= (True, mod.pmCompilerConversion, heaps)

// In case John shows up at your pc, HIDE the code beneath (or face the consequences)!
// -------------------------------------------------------------------------------------------------------------------------------------------------
bindPredefined :: !CName !CompilerDefinitionKind !Index !*CHeaps -> (!Error, !HeapPtr, !*CHeaps)
// -------------------------------------------------------------------------------------------------------------------------------------------------
bindPredefined name CheckedTypeDef index heaps
	= case name of
		"_List"					-> (OK, CListPtr, heaps)
		"_Array"				-> (OK, CNormalArrayPtr, heaps)
		"_!Array"				-> (OK, CStrictArrayPtr, heaps)
		"_#Array"				-> (OK, CUnboxedArrayPtr, heaps)
//		"{#}"					-> 
		"_Tuple2"				-> (OK, CTuplePtr 2, heaps)
		"_Tuple3"				-> (OK, CTuplePtr 3, heaps)
		"_Tuple4"				-> (OK, CTuplePtr 4, heaps)
		"_Tuple5"				-> (OK, CTuplePtr 5, heaps)
		"_Tuple6"				-> (OK, CTuplePtr 6, heaps)
		"_Tuple7"				-> (OK, CTuplePtr 7, heaps)
		"_Tuple8"				-> (OK, CTuplePtr 8, heaps)
		"_Tuple9"				-> (OK, CTuplePtr 9, heaps)
		"_Tuple10"				-> (OK, CTuplePtr 10, heaps)
		"_Tuple11"				-> (OK, CTuplePtr 11, heaps)
		"_Tuple12"				-> (OK, CTuplePtr 12, heaps)
		"_Tuple13"				-> (OK, CTuplePtr 13, heaps)
		"_Tuple14"				-> (OK, CTuplePtr 14, heaps)
		"_Tuple15"				-> (OK, CTuplePtr 15, heaps)
		"_Tuple16"				-> (OK, CTuplePtr 16, heaps)
		"_Tuple17"				-> (OK, CTuplePtr 17, heaps)
		"_Tuple18"				-> (OK, CTuplePtr 18, heaps)
		"_Tuple19"				-> (OK, CTuplePtr 19, heaps)
		"_Tuple20"				-> (OK, CTuplePtr 20, heaps)
		"_Tuple21"				-> (OK, CTuplePtr 21, heaps)
		"_Tuple22"				-> (OK, CTuplePtr 22, heaps)
		"_Tuple23"				-> (OK, CTuplePtr 23, heaps)
		"_Tuple24"				-> (OK, CTuplePtr 24, heaps)
		"_Tuple25"				-> (OK, CTuplePtr 25, heaps)
		"_Tuple26"				-> (OK, CTuplePtr 26, heaps)
		"_Tuple27"				-> (OK, CTuplePtr 27, heaps)
		"_Tuple28"				-> (OK, CTuplePtr 28, heaps)
		"_Tuple29"				-> (OK, CTuplePtr 29, heaps)
		"_Tuple30"				-> (OK, CTuplePtr 30, heaps)
		"_Tuple31"				-> (OK, CTuplePtr 31, heaps)
		"_Tuple32"				-> (OK, CTuplePtr 32, heaps)
		_						-> (pushError (X_Internal ("Unrecognized CheckedTypeDef ptr to _predefined (" +++ name +++ ", " +++ toString index +++ ")")) OK, DummyValue, heaps)
bindPredefined name ConsDef index heaps
	= case name of
		"_Cons"					-> (OK, CConsPtr, heaps)
		"_Nil"					-> (OK, CNilPtr, heaps)
		"_Tuple2"				-> (OK, CBuildTuplePtr 2, heaps)
		"_Tuple3"				-> (OK, CBuildTuplePtr 3, heaps)
		"_Tuple4"				-> (OK, CBuildTuplePtr 4, heaps)
		"_Tuple5"				-> (OK, CBuildTuplePtr 5, heaps)
		"_Tuple6"				-> (OK, CBuildTuplePtr 6, heaps)
		"_Tuple7"				-> (OK, CBuildTuplePtr 7, heaps)
		"_Tuple8"				-> (OK, CBuildTuplePtr 8, heaps)
		"_Tuple9"				-> (OK, CBuildTuplePtr 9, heaps)
		"_Tuple10"				-> (OK, CBuildTuplePtr 10, heaps)
		"_Tuple11"				-> (OK, CBuildTuplePtr 11, heaps)
		"_Tuple12"				-> (OK, CBuildTuplePtr 12, heaps)
		"_Tuple13"				-> (OK, CBuildTuplePtr 13, heaps)
		"_Tuple14"				-> (OK, CBuildTuplePtr 14, heaps)
		"_Tuple15"				-> (OK, CBuildTuplePtr 15, heaps)
		"_Tuple16"				-> (OK, CBuildTuplePtr 16, heaps)
		"_Tuple17"				-> (OK, CBuildTuplePtr 17, heaps)
		"_Tuple18"				-> (OK, CBuildTuplePtr 18, heaps)
		"_Tuple19"				-> (OK, CBuildTuplePtr 19, heaps)
		"_Tuple20"				-> (OK, CBuildTuplePtr 20, heaps)
		"_Tuple21"				-> (OK, CBuildTuplePtr 21, heaps)
		"_Tuple22"				-> (OK, CBuildTuplePtr 22, heaps)
		"_Tuple23"				-> (OK, CBuildTuplePtr 23, heaps)
		"_Tuple24"				-> (OK, CBuildTuplePtr 24, heaps)
		"_Tuple25"				-> (OK, CBuildTuplePtr 25, heaps)
		"_Tuple26"				-> (OK, CBuildTuplePtr 26, heaps)
		"_Tuple27"				-> (OK, CBuildTuplePtr 27, heaps)
		"_Tuple28"				-> (OK, CBuildTuplePtr 28, heaps)
		"_Tuple29"				-> (OK, CBuildTuplePtr 29, heaps)
		"_Tuple30"				-> (OK, CBuildTuplePtr 30, heaps)
		"_Tuple31"				-> (OK, CBuildTuplePtr 31, heaps)
		"_Tuple32"				-> (OK, CBuildTuplePtr 32, heaps)
		_						-> (pushError (X_Internal ("Unrecognized ConsDef ptr to _predefined (" +++ name +++ ", " +++ toString index +++ ")")) OK, DummyValue, heaps)
// Internal dummy value to catch the special compiler symbol 'dummyForStrictAlias'.
// This dummy symbol is removed in the module Bind.
bindPredefined name FunDef 0 heaps
	= (OK, CBuildTuplePtr 42, heaps)
bindPredefined name other index heaps
	= (pushError (X_Internal ("Unrecognized ptr to _predefined. (" +++ (toString index) +++ ")")) OK, DummyValue, heaps)

// =================================================================================================================================================
// Exception: pointers to record-constructors for dictionaries are not included in the dcl_convtable
//            Solution: replace by pointer to the class, revert this change in 'Bind'
// -------------------------------------------------------------------------------------------------------------------------------------------------
bindDefinition :: !(Maybe CompilerConversion) ![ModuleName] ![ModulePtr] !IndexedPtr !*CHeaps -> (!Error, !HeapPtr, !*CHeaps)
// -------------------------------------------------------------------------------------------------------------------------------------------------
bindDefinition mb_conversions all_names all_ptrs (DclDefinitionPtr dcl_name def_name def_kind def_index) heaps
	| dcl_name == "_predefined"		= bindPredefined def_name def_kind def_index heaps
	# (ok, conversions, heaps)		= findConversions mb_conversions dcl_name all_names all_ptrs heaps
	| not ok						= (pushError (X_Internal ("Rule 'bindDefinition' does not match. (unknown dclmodule " +++ dcl_name +++ ")")) OK, DummyValue, heaps)
	# dcl_icl_table					= conversions.ccDclIclConversions
	| def_kind == FunDef
		# def_index					= if (size dcl_icl_table > 0) dcl_icl_table.[def_index] def_index
		= bindDefinition (Just conversions) all_names all_ptrs (IclDefinitionPtr dcl_name (-2) def_name def_kind def_index) heaps
	# conv_tables					= conversions.ccConversionTable
	# conv_index					= case def_kind of
										CheckedTypeDef		-> cTypeDefs
										ConsDef				-> cConstructorDefs
										SelectorDef			-> cSelectorDefs
										ClassDef			-> cClassDefs
										MemberDef			-> cMemberDefs
										ClassInstance		-> cInstanceDefs
	# conv_table					= conv_tables.[conv_index]
	| (def_kind <> ConsDef) && (def_index >= size conv_table)
		# dicts						= conversions.ccDictionaries
		# icl_ptr					= check_dictionary def_name def_kind dicts (IclDefinitionPtr dcl_name (-2) def_name def_kind def_index)
		= bindDefinition (Just conversions) all_names all_ptrs icl_ptr heaps
	# (nr_conses, heaps)			= find_nr_conses dcl_name all_names all_ptrs heaps
	| (def_kind == ConsDef) && (def_index >= nr_conses)
		// Constructor is a dictionary creator, which cannot be converted at this time.
		// Therefore, it is replaced by the class that the dictionary belongs to and is later converted back.
		# def_name					= remove_last_semicolon def_name
		# class_ptr					= (DclDefinitionPtr dcl_name def_name ClassDef (def_index-nr_conses))
		= bindDefinition (Just conversions) all_names all_ptrs class_ptr heaps
	# def_index						= case def_index >= size conv_table of
										True	-> def_index
										False	-> conv_table.[def_index]
	= bindDefinition (Just conversions) all_names all_ptrs (IclDefinitionPtr dcl_name (-2) def_name def_kind def_index) heaps
	where
		check_dictionary :: !String !CompilerDefinitionKind ![(CName, IndexedPtr)] !IndexedPtr -> IndexedPtr
		check_dictionary defname CheckedTypeDef dicts oldptr
			# (found, newptr)			= find2 defname dicts
			| not found					= oldptr
			= newptr
		check_dictionary defname other dicts oldptr
			= oldptr
		
		// When temporary converting dictionary_creators (conses) to classes, its index has to be adjusted by the number of real conses in the dcl.
		// This number is stored in the module (and set by the function 'convertFrontEndSyntaxTree' in 'Conversion.icl'.
		find_nr_conses :: !String ![ModuleName] ![ModulePtr] !*CHeaps -> (!Int, !*CHeaps)
		find_nr_conses dcl_name [name:names] [ptr:ptrs] heaps
			| dcl_name <> name			= find_nr_conses dcl_name names ptrs heaps
			# (mod, heaps)				= readPointer ptr heaps
			= (mod.pmOriginalNrDclConses, heaps)
		find_nr_conses _ _ _ heaps
			= (0, heaps)
		
		// When temporary converting record-constructors to class pointers, the last ; has to be removed to get the proper class name.
		remove_last_semicolon :: !String -> String
		remove_last_semicolon name
			# size_name					= size name
			| size_name == 0			= name
			# last_char					= name.[size_name - 1]
			| last_char <> ';'			= name
			= name % (0, size name - 2)
bindDefinition mb_conversions all_names all_ptrs (IclDefinitionPtr icl_name icl_key _ CheckedTypeDef def_index) heaps
	# (ok, conversions, heaps)			= findConversions mb_conversions icl_name all_names all_ptrs heaps
	| not ok							= (pushError (X_Internal ("Rule 'bindDefinition' does not match. (unknown iclmodule " +++ icl_name +++ ")")) OK, DummyValue, heaps)
	= (OK, conversions.ccCheckedTypePtrs.[def_index], heaps)
bindDefinition mb_conversions all_names all_ptrs (IclDefinitionPtr "_tuplecreate" arity _ ConsDef _) heaps
	= (OK, CBuildTuplePtr arity, heaps)
bindDefinition mb_conversions all_names all_ptrs (IclDefinitionPtr icl_name icl_key _ ConsDef def_index) heaps
	# (ok, conversions, heaps)			= findConversions mb_conversions icl_name all_names all_ptrs heaps
	| not ok							= (pushError (X_Internal ("Rule 'bindDefinition' does not match. (unknown iclmodule " +++ icl_name +++ ")")) OK, DummyValue, heaps)
	= (OK, conversions.ccConsPtrs.[def_index], heaps)
bindDefinition mb_conversions all_names all_ptrs (IclDefinitionPtr icl_name icl_key _ ClassDef def_index) heaps
	# (ok, conversions, heaps)			= findConversions mb_conversions icl_name all_names all_ptrs heaps
	| not ok							= (pushError (X_Internal ("Rule 'bindDefinition' does not match. (unknown iclmodule " +++ icl_name +++ ")")) OK, DummyValue, heaps)
	
	| def_index >= size conversions.ccClassPtrs		= abort "HALLO! NIET DOEN!"
	
	= (OK, conversions.ccClassPtrs.[def_index], heaps)
bindDefinition mb_conversions all_names all_ptrs (IclDefinitionPtr "_tupleselect" icl_key _ FunDef def_index) heaps
	= (OK, CTupleSelectPtr icl_key def_index, heaps)
bindDefinition mb_conversions all_names all_ptrs (IclDefinitionPtr icl_name icl_key _ FunDef def_index) heaps
	# (ok, conversions, heaps)			= findConversions mb_conversions icl_name all_names all_ptrs heaps
	| not ok							= (pushError (X_Internal ("Rule 'bindDefinition' does not match. (unknown iclmodule " +++ icl_name +++ ")")) OK, DummyValue, heaps)
	= (OK, conversions.ccFunPtrs.[def_index], heaps)
bindDefinition mb_conversions all_names all_ptrs (IclDefinitionPtr icl_name icl_key _ ClassInstance def_index) heaps
	# (ok, conversions, heaps)			= findConversions mb_conversions icl_name all_names all_ptrs heaps
	| not ok							= (pushError (X_Internal ("Rule 'bindDefinition' does not match. (unknown iclmodule " +++ icl_name +++ ")")) OK, DummyValue, heaps)
	= (OK, conversions.ccInstancePtrs.[def_index], heaps)
bindDefinition mb_conversions all_names all_ptrs (IclDefinitionPtr icl_name icl_key _ MemberDef def_index) heaps
	# (ok, conversions, heaps)			= findConversions mb_conversions icl_name all_names all_ptrs heaps
	| not ok							= (pushError (X_Internal ("Rule 'bindDefinition' does not match. (unknown iclmodule " +++ icl_name +++ ")")) OK, DummyValue, heaps)
	= (OK, conversions.ccMemberPtrs.[def_index], heaps)
bindDefinition mb_conversions all_names all_ptrs (IclDefinitionPtr icl_name icl_key _ SelectorDef def_index) heaps
	# (ok, conversions, heaps)			= findConversions mb_conversions icl_name all_names all_ptrs heaps
	| not ok							= (pushError (X_Internal ("Rule 'bindDefinition' does not match. (unknown iclmodule " +++ icl_name +++ ")")) OK, DummyValue, heaps)
	= (OK, conversions.ccSelectorPtrs.[def_index], heaps)
















// -------------------------------------------------------------------------------------------------------------------------------------------------   
class changeDefinition c :: !(a -> *CHeaps -> (Error, b, *CHeaps)) !(c a) !*CHeaps -> (!Error, !(c b), !*CHeaps) | DummyValue a & DummyValue b
// -------------------------------------------------------------------------------------------------------------------------------------------------   

// -------------------------------------------------------------------------------------------------------------------------------------------------   
instance changeDefinition CAlgPattern
// -------------------------------------------------------------------------------------------------------------------------------------------------   
where
	changeDefinition f algpattern=:{atpDataCons, atpExprVarScope, atpResult} heaps
		# (error, fDataCons, heaps)		= f atpDataCons heaps
		| isError error					= (error, DummyValue, heaps)
		# (error, fResult, heaps)		= changeDefinition f atpResult heaps
		| isError error					= (error, DummyValue, heaps)
		= (OK, {atpDataCons = fDataCons, atpExprVarScope = atpExprVarScope, atpResult = fResult}, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------   
instance changeDefinition CAlgTypeDef
// -------------------------------------------------------------------------------------------------------------------------------------------------   
where
	changeDefinition f at_def=:{atdConstructors} heaps
		# (error, fconses, heaps)		= umapError f atdConstructors heaps
		| isError error					= (error, DummyValue, heaps)
		= (error, {at_def & atdConstructors = fconses}, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------   
instance changeDefinition CBasicPattern
// -------------------------------------------------------------------------------------------------------------------------------------------------   
where
	changeDefinition f basicpattern=:{bapBasicValue, bapResult} heaps
		# (error, fResult, heaps)		= changeDefinition f bapResult heaps
		| isError error					= (error, DummyValue, heaps)
		# (error, fValue, heaps)		= changeDefinition f bapBasicValue heaps
		| isError error					= (error, DummyValue, heaps)
		= (OK, {bapBasicValue = fValue, bapResult = fResult}, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance changeDefinition CBasicValue
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	changeDefinition f (CBasicCharacter c) heaps
		= (OK, CBasicCharacter c, heaps)
	changeDefinition f (CBasicInteger n) heaps
		= (OK, CBasicInteger n, heaps)
	changeDefinition f (CBasicRealNumber r) heaps
		= (OK, CBasicRealNumber r, heaps)
	changeDefinition f (CBasicBoolean b) heaps
		= (OK, CBasicBoolean b, heaps)
	changeDefinition f (CBasicString s) heaps
		= (OK, CBasicString s, heaps)
	changeDefinition f (CBasicArray list) heaps
		# (error, flist, heaps)			= umapError (changeDefinition f) list heaps
		| isError error					= (error, DummyValue, heaps)
		= (OK, CBasicArray flist, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance changeDefinition CCasePatterns
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	changeDefinition f (CAlgPatterns ptr algpatterns) heaps
		# (error, fpatterns, heaps)		= umapError (changeDefinition f) algpatterns heaps
		| isError error					= (error, DummyValue, heaps)
		# (error, fptr, heaps)			= f ptr heaps
		| isOK error					= (OK, CAlgPatterns fptr fpatterns, heaps)
		// 'ptr' = DummyValue when the source was a MatchExpr
		// compensate by temporarily exchanging it with the ConsDef-ptr
		| length fpatterns <> 1			= (error, DummyValue, heaps)
		# cons_ptr						= (hd fpatterns).atpDataCons
		= (OK, CAlgPatterns cons_ptr fpatterns, heaps)
	changeDefinition f (CBasicPatterns type basicpatterns) heaps
		# (error, fpatterns, heaps)		= umapError (changeDefinition f) basicpatterns heaps
		| isError error					= (error, DummyValue, heaps)
		= (OK, CBasicPatterns type fpatterns, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance changeDefinition CClassDef
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	changeDefinition f classdef heaps
		# fscope						= classdef.cldTypeVarScope
		# (error, frestrictions, heaps)	= umapError (changeDefinition f) classdef.cldClassRestrictions heaps
		| isError error					= (error, DummyValue, heaps)
		# (error, fmembers, heaps)		= umapError f classdef.cldMembers heaps
		| isError error					= (error, DummyValue, heaps)
		# (error, fdictionary, heaps)	= f classdef.cldDictionary heaps
		| isError error					= (error, DummyValue, heaps)
		# (error, finstances, heaps)	= umapError f classdef.cldInstances heaps
		| isError error					= (error, DummyValue, heaps)
		= (OK,	{ cldName				= classdef.cldName
				, cldArity				= classdef.cldArity
				, cldTypeVarScope		= fscope
				, cldClassRestrictions	= frestrictions
				, cldMembers			= fmembers
				, cldDictionary			= fdictionary
				, cldInstances			= finstances
				}, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance changeDefinition CClassRestriction
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	changeDefinition f classr heaps
		# (error, fccrClass, heaps)		= f classr.ccrClass heaps
		| isError error					= (error, DummyValue, heaps)
		# (error, fccrTypes, heaps)		= umapError (changeDefinition f) classr.ccrTypes heaps
		| isError error					= (error, DummyValue, heaps)
		= (OK, {classr & ccrClass = fccrClass, ccrTypes = fccrTypes}, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance changeDefinition CDataConsDef
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	changeDefinition f dcd_def heaps
		# (error, falgtype, heaps)		= f dcd_def.dcdAlgType heaps
		| isError error					= (error, DummyValue, heaps)
		# (error, fsymboltype, heaps)	= changeDefinition f dcd_def.dcdSymbolType heaps
		| isError error					= (error, DummyValue, heaps)
		= (OK, {dcd_def & dcdAlgType = falgtype, dcdSymbolType = fsymboltype}, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance changeDefinition CExpr
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	changeDefinition f (CExprVar ptr) heaps
		= (OK, CExprVar ptr, heaps)
	changeDefinition f (CShared ptr) heaps
		= (OK, CShared ptr, heaps)
	changeDefinition f (expr @# exprs) heaps
		# (error, fexpr, heaps)			= changeDefinition f expr heaps
		| isError error					= (error, DummyValue, heaps)
		# (error, fexprs, heaps)		= umapError (changeDefinition f) exprs heaps
		| isError error					= (error, DummyValue, heaps)
		= (OK, fexpr @# fexprs, heaps)
	changeDefinition f (a @@# exprs) heaps
		# (error, fa, heaps)			= f a heaps
		| isError error					= (error, DummyValue, heaps)
		# (error, fexprs, heaps)		= umapError (changeDefinition f) exprs heaps
		| isError error					= (error, DummyValue, heaps)
		= (OK, fa @@# fexprs, heaps)
	changeDefinition f (CLet strict lets expr) heaps
		# (vars, exprs)					= unzip lets
		# (error, fexprs, heaps)		= umapError (changeDefinition f) exprs heaps
		| isError error					= (error, DummyValue, heaps)
		# flets							= zip2 vars fexprs
		# (error, fexpr, heaps)			= changeDefinition f expr heaps
		| isError error					= (error, DummyValue, heaps)
		= (OK, CLet strict flets fexpr, heaps)
	changeDefinition f (CCase expr patterns defaul) heaps
		# (error, fexpr, heaps)			= changeDefinition f expr heaps
		| isError error					= (error, DummyValue, heaps)
		# (error, fpatns, heaps)		= changeDefinition f patterns heaps
		| isError error					= (error, DummyValue, heaps)
		| isNothing defaul				= (OK, CCase fexpr fpatns Nothing, heaps)
		# (error, fdefault, heaps)		= changeDefinition f (fromJust defaul) heaps
		| isError error					= (error, DummyValue, heaps)
		= (OK, CCase fexpr fpatns (Just fdefault), heaps)
	changeDefinition f (CBasicValue basicvalue) heaps
		# (error, fbasicvalue, heaps)	= changeDefinition f basicvalue heaps
		| isError error					= (error, DummyValue, heaps)
		= (OK, CBasicValue fbasicvalue, heaps)      
	changeDefinition f (CCode codetype codetexts) heaps
		= (OK, CCode codetype codetexts, heaps)
	changeDefinition f CBottom heaps
		= (OK, CBottom, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance changeDefinition CFunDef
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	changeDefinition f fun_def heaps
		# (error, fsymboltype, heaps)	= changeDefinition f fun_def.fdSymbolType heaps
		| isError error					= (error, DummyValue, heaps)
		# (error, fbody, heaps)			= changeDefinition f fun_def.fdBody heaps
		| isError error					= (error, DummyValue, heaps)
		# ok1							= fun_def.fdIsRecordSelector
		# ok2							= fun_def.fdIsRecordUpdater
		| not ok1 && not ok2			= (OK, {fun_def & fdSymbolType = fsymboltype, fdBody = fbody, fdRecordFieldDef = DummyValue}, heaps)
		# (error, ffield, heaps)		= f fun_def.fdRecordFieldDef heaps
		| isError error					= (error, DummyValue, heaps)
		= (OK, {fun_def & fdSymbolType = fsymboltype, fdBody = fbody, fdRecordFieldDef = ffield}, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------   
instance changeDefinition CInstanceDef
// -------------------------------------------------------------------------------------------------------------------------------------------------   
where
	changeDefinition f instancedef heaps
		# (error, fclass, heaps)		= f instancedef.indClass heaps
		| isError error					= (error, DummyValue, heaps)
		# (error, ftypes, heaps)		= umapError (changeDefinition f) instancedef.indClassArguments heaps
		| isError error					= (error, DummyValue, heaps)
		# (error, frestrictions, heaps)	= umapError (changeDefinition f) instancedef.indClassRestrictions heaps
		| isError error					= (error, DummyValue, heaps)
		# (error, fmemberfuns, heaps)	= umapError f instancedef.indMemberFunctions heaps
		| isError error					= (error, DummyValue, heaps)
		= (OK,	{ instancedef &
				  indClass				= fclass
				, indClassArguments		= ftypes
				, indClassRestrictions	= frestrictions
				, indMemberFunctions	= fmemberfuns
				}, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------   
instance changeDefinition CMemberDef
// -------------------------------------------------------------------------------------------------------------------------------------------------   
where
	changeDefinition f memberdef heaps
		# (error, fclass, heaps)		= f memberdef.mbdClass heaps
		| isError error					= (error, DummyValue, heaps)
		# (error, fsymboltype, heaps)	= changeDefinition f memberdef.mbdSymbolType heaps
		| isError error					= (error, DummyValue, heaps)
		= (OK,	{ mbdName				= memberdef.mbdName
				, mbdClass				= fclass
				, mbdSymbolType			= fsymboltype
				, mbdInfix				= memberdef.mbdInfix
				}, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------   
instance changeDefinition CRecordFieldDef
// -------------------------------------------------------------------------------------------------------------------------------------------------   
where
	changeDefinition f rcf_def heaps
		# (error, fsymboltype, heaps)	= changeDefinition f rcf_def.rfSymbolType heaps
		| isError error					= (error, DummyValue, heaps)
		# (error, fRtype, heaps)		= f rcf_def.rfRecordType heaps
		| isError error					= (error, DummyValue, heaps)
		= (OK, {rcf_def & rfSymbolType = fsymboltype, rfRecordType = fRtype, rfSelectorFun = DummyValue, rfUpdaterFun = DummyValue}, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------   
instance changeDefinition CRecordTypeDef
// -------------------------------------------------------------------------------------------------------------------------------------------------   
where
	changeDefinition f rct_def heaps
		# (error, ffields, heaps)		= umapError f rct_def.rtdFields heaps
		| isError error					= (error, DummyValue, heaps)
		| not rct_def.rtdIsDictionary	= (OK, {rct_def & rtdFields = ffields, rtdRecordConstructor = DummyValue, rtdClassDef = DummyValue}, heaps)
		# (error, fclass, heaps)		= f rct_def.rtdClassDef heaps
		| isError error					= (error, DummyValue, heaps)
		= (OK, {rct_def & rtdFields = ffields, rtdRecordConstructor = DummyValue, rtdClassDef = fclass}, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance changeDefinition CSymbolType
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	changeDefinition f symboltype heaps
		# fscope						= symboltype.sytTypeVarScope
		# (error, farguments, heaps)	= umapError (changeDefinition f) symboltype.sytArguments heaps
		| isError error					= (error, DummyValue, heaps)
		# (error, fresult, heaps)		= changeDefinition f symboltype.sytResult heaps
		| isError error					= (error, DummyValue, heaps)
		# (error, frestrictions, heaps)	= umapError (changeDefinition f) symboltype.sytClassRestrictions heaps
		| isError error					= (error, DummyValue, heaps)
		= (OK,	{ sytArguments			= farguments
				, sytTypeVarScope		= symboltype.sytTypeVarScope
				, sytResult				= fresult
				, sytClassRestrictions	= frestrictions
				}, heaps)
                                                          
// -------------------------------------------------------------------------------------------------------------------------------------------------   
instance changeDefinition CType
// -------------------------------------------------------------------------------------------------------------------------------------------------   
where
	changeDefinition f (CTypeVar ptr) heaps
		= (OK, CTypeVar ptr, heaps)
	changeDefinition f (type1 ==> type2) heaps
		# (error, ftype1, heaps)		= changeDefinition f type1 heaps
		| isError error					= (error, DummyValue, heaps)
		# (error, ftype2, heaps)		= changeDefinition f type2 heaps
		| isError error					= (error, DummyValue, heaps)
		= (OK, ftype1 ==> ftype2, heaps)      
	changeDefinition f (type @^ types) heaps
		# (error, ftype, heaps)			= changeDefinition f type heaps
		| isError error					= (error, DummyValue, heaps)
		# (error, ftypes, heaps)		= umapError (changeDefinition f) types heaps
		| isError error					= (error, DummyValue, heaps)
		= (OK, ftype @^ ftypes, heaps)
	changeDefinition f (def @@^ types) heaps
		# (error, fdef, heaps)			= f def heaps
		| isError error					= (error, DummyValue, heaps)
		# (error, ftypes, heaps)		= umapError (changeDefinition f) types heaps
		| isError error					= (error, DummyValue, heaps)
		= (OK, fdef @@^ ftypes, heaps) 
	changeDefinition f (CBasicType basictype) heaps
		= (OK, CBasicType basictype, heaps)
	changeDefinition f (CStrict type) heaps
		# (error, ftype, heaps)			= changeDefinition f type heaps
		| isError error					= (error, DummyValue, heaps)
		= (OK, CStrict ftype, heaps)
	changeDefinition f CUnTypable heaps
		= (OK, CUnTypable, heaps)






















// -------------------------------------------------------------------------------------------------------------------------------------------------   
bindModule :: ![ModuleName] ![ModulePtr] !ModulePtr !*CHeaps !*CProject -> (!Error, !CModule, !*CHeaps, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------   
bindModule all_names all_ptrs mod_ptr heaps prj
	# (mod, heaps)						= readPointer mod_ptr heaps
	| isNothing mod.pmCompilerStore		= (pushError (X_Internal ("Cannot bind, no CompilerStore was found for module " +++ mod.pmName +++ ".")) OK, DummyValue, heaps, prj)
	# store								= fromJust mod.pmCompilerStore
	
	# alg_ptrs							= [ptr \\ ptr <-: mod.pmCompilerConversion.ccCheckedTypePtrs | ptr <> DummyValue && ptrKind ptr == CAlgType]
	# (error, heaps, prj)				= bindAlgTypes alg_ptrs store.csAlgTypeDefs heaps prj
	| isError error						= (error, DummyValue, heaps, prj)
	
	# class_ptrs						= [ptr \\ ptr <-: mod.pmCompilerConversion.ccClassPtrs | ptr <> DummyValue]
	# (error, heaps, prj)				= bindClasses class_ptrs store.csClassDefs heaps prj
	| isError error						= (error, DummyValue, heaps, prj)
	
	# cons_ptrs							= [ptr \\ ptr <-: mod.pmCompilerConversion.ccConsPtrs | ptr <> DummyValue]
	# (error, heaps, prj)				= bindDataConses cons_ptrs store.csDataConsDefs heaps prj
	| isError error						= (error, DummyValue, heaps, prj)
	
	# fun_ptrs							= [ptr \\ ptr <-: mod.pmCompilerConversion.ccFunPtrs | ptr <> DummyValue]
	# (error, heaps, prj)				= bindFuns fun_ptrs store.csFunDefs heaps prj
	| isError error						= (error, DummyValue, heaps, prj)
	
	# instance_ptrs						= [ptr \\ ptr <-: mod.pmCompilerConversion.ccInstancePtrs | ptr <> DummyValue]
	# (error, heaps, prj)				= bindInstances instance_ptrs store.csInstanceDefs heaps prj
	| isError error						= (error, DummyValue, heaps, prj)
	
	# member_ptrs						= [ptr \\ ptr <-: mod.pmCompilerConversion.ccMemberPtrs | ptr <> DummyValue]
	# (error, heaps, prj)				= bindMembers member_ptrs store.csMemberDefs heaps prj
	| isError error						= (error, DummyValue, heaps, prj)
	
	# field_ptrs						= [ptr \\ ptr <-: mod.pmCompilerConversion.ccSelectorPtrs | ptr <> DummyValue]
	# (error, heaps, prj)				= bindRecordFields field_ptrs store.csRecordFieldDefs heaps prj
	| isError error						= (error, DummyValue, heaps, prj)
	
	# rec_ptrs							= [ptr \\ ptr <-: mod.pmCompilerConversion.ccCheckedTypePtrs | ptr <> DummyValue && ptrKind ptr == CRecordType]
	# (error, heaps, prj)				= bindRecordTypes rec_ptrs store.csRecordTypeDefs heaps prj
	| isError error						= (error, DummyValue, heaps, prj)
	
	# (_, imports)						= multiple_find mod.pmName store.csImports all_names all_ptrs
	# mod								= {mod	& pmImportedModules		= imports
												, pmAlgTypePtrs			= alg_ptrs
												, pmClassPtrs			= class_ptrs
												, pmDataConsPtrs		= cons_ptrs
												, pmFunPtrs				= fun_ptrs
												, pmInstancePtrs		= instance_ptrs
												, pmMemberPtrs			= member_ptrs
												, pmRecordFieldPtrs		= field_ptrs
												, pmRecordTypePtrs		= rec_ptrs
												, pmCompilerStore		= Nothing
										  }
	# heaps								= writePointer mod_ptr mod heaps
	= (OK, mod, heaps, prj)
	where
		bindAlgTypes :: ![HeapPtr] ![CAlgTypeDefI] !*CHeaps !*CProject -> (!Error, !*CHeaps, !*CProject)
		bindAlgTypes [ptr:ptrs] [def:defs] heaps prj
			# (error, def, heaps)		= changeDefinition (bindDefinition Nothing all_names all_ptrs) def heaps
			| isError error				= (error, heaps, prj)
			# (error, prj)				= putAlgTypeDef ptr def prj
			| isError error				= (error, heaps, prj)
			= bindAlgTypes ptrs defs heaps prj
		bindAlgTypes _ _ heaps prj
			= (OK, heaps, prj)
		
		bindClasses :: ![HeapPtr] ![CClassDefI] !*CHeaps !*CProject -> (!Error, !*CHeaps, !*CProject)
		bindClasses [ptr:ptrs] [def:defs] heaps prj
			# (error, def, heaps)		= changeDefinition (bindDefinition Nothing all_names all_ptrs) def heaps
			| isError error				= (error, heaps, prj)
			# (error, prj)				= putClassDef ptr def prj
			| isError error				= (error, heaps, prj)
			= bindClasses ptrs defs heaps prj
		bindClasses _ _ heaps prj
			= (OK, heaps, prj)
		
		bindDataConses :: ![HeapPtr] ![CDataConsDefI] !*CHeaps !*CProject -> (!Error, !*CHeaps, !*CProject)
		bindDataConses [ptr:ptrs] [def:defs] heaps prj
			# (error, def, heaps)		= changeDefinition (bindDefinition Nothing all_names all_ptrs) def heaps
			| isError error				= (error, heaps, prj)
			# (error, prj)				= putDataConsDef ptr def prj
			| isError error				= (error, heaps, prj)
			= bindDataConses ptrs defs heaps prj
		bindDataConses _ _ heaps prj
			= (OK, heaps, prj)
		
		bindFuns :: ![HeapPtr] ![CFunDefI] !*CHeaps !*CProject -> (!Error, !*CHeaps, !*CProject)
		bindFuns [ptr:ptrs] [def:defs] heaps prj
			# (error, def, heaps)		= changeDefinition (bindDefinition Nothing all_names all_ptrs) def heaps
			| isError error				= (error, heaps, prj)
			# (body, prj)				= fixCases def.fdBody prj
			# def						= {def & fdBody = body}
			# (error, prj)				= putFunDef ptr def prj
			| isError error				= (error, heaps, prj)
			= bindFuns ptrs defs heaps prj
		bindFuns _ _ heaps prj
			= (OK, heaps, prj)
		
		bindInstances :: ![HeapPtr] ![CInstanceDefI] !*CHeaps !*CProject -> (!Error, !*CHeaps, !*CProject)
		bindInstances [ptr:ptrs] [def:defs] heaps prj
			# (error, def, heaps)		= changeDefinition (bindDefinition Nothing all_names all_ptrs) def heaps
			| isError error				= (error, heaps, prj)
			# (error, prj)				= putInstanceDef ptr def prj
			| isError error				= (error, heaps, prj)
			= bindInstances ptrs defs heaps prj
		bindInstances _ _ heaps prj
			= (OK, heaps, prj)
		
		bindMembers :: ![HeapPtr] ![CMemberDefI] !*CHeaps !*CProject -> (!Error, !*CHeaps, !*CProject)
		bindMembers [ptr:ptrs] [def:defs] heaps prj
			# (error, def, heaps)		= changeDefinition (bindDefinition Nothing all_names all_ptrs) def heaps
			| isError error				= (error, heaps, prj)
			# (error, prj)				= putMemberDef ptr def prj
			| isError error				= (error, heaps, prj)
			= bindMembers ptrs defs heaps prj
		bindMembers _ _ heaps prj
			= (OK, heaps, prj)
		
		bindRecordFields :: ![HeapPtr] ![CRecordFieldDefI] !*CHeaps !*CProject -> (!Error, !*CHeaps, !*CProject)
		bindRecordFields [ptr:ptrs] [def:defs] heaps prj
			# (error, def, heaps)		= changeDefinition (bindDefinition Nothing all_names all_ptrs) def heaps
			| isError error				= (error, heaps, prj)
			# (error, prj)				= putRecordFieldDef ptr def prj
			| isError error				= (error, heaps, prj)
			= bindRecordFields ptrs defs heaps prj
		bindRecordFields _ _ heaps prj
			= (OK, heaps, prj)
		
		bindRecordTypes :: ![HeapPtr] ![CRecordTypeDefI] !*CHeaps !*CProject -> (!Error, !*CHeaps, !*CProject)
		bindRecordTypes [ptr:ptrs] [def:defs] heaps prj
			# (error, def, heaps)		= changeDefinition (bindDefinition Nothing all_names all_ptrs) def heaps
			| isError error				= (error, heaps, prj)
			# (error, prj)				= putRecordTypeDef ptr def prj
			| isError error				= (error, heaps, prj)
			= bindRecordTypes ptrs defs heaps prj
		bindRecordTypes _ _ heaps prj
			= (OK, heaps, prj)













// Checks if the algebraic type stored in a CAlgPatterns is really a CAlgType.
// If not, it derives the correct type.
// -------------------------------------------------------------------------------------------------------------------------------------------------   
class fixCases term :: !term !*CProject -> (!term, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------   

// -------------------------------------------------------------------------------------------------------------------------------------------------   
instance fixCases (a, term) | fixCases term
// -------------------------------------------------------------------------------------------------------------------------------------------------   
where
	fixCases (a, term) prj
		# (term, prj)					= fixCases term prj
		= ((a, term), prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------   
instance fixCases (Maybe term) | fixCases term
// -------------------------------------------------------------------------------------------------------------------------------------------------   
where
	fixCases (Just term) prj
		# (term, prj)					= fixCases term prj
		= (Just term, prj)
	fixCases Nothing prj
		= (Nothing, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------   
instance fixCases [term] | fixCases term
// -------------------------------------------------------------------------------------------------------------------------------------------------   
where
	fixCases [term:terms] prj
		# (term, prj)					= fixCases term prj
		# (terms, prj)					= fixCases terms prj
		= ([term:terms], prj)
	fixCases [] prj
		= ([], prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------   
instance fixCases CAlgPatternH
// -------------------------------------------------------------------------------------------------------------------------------------------------   
where
	fixCases pattern prj
		# (result, prj)					= fixCases pattern.atpResult prj
		# pattern						= {pattern & atpResult = result}
		= (pattern, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------   
instance fixCases CBasicPatternH
// -------------------------------------------------------------------------------------------------------------------------------------------------   
where
	fixCases pattern prj
		# (result, prj)					= fixCases pattern.bapResult prj
		# pattern						= {pattern & bapResult = result}
		= (pattern, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------   
instance fixCases CBasicValueH
// -------------------------------------------------------------------------------------------------------------------------------------------------   
where
	fixCases (CBasicArray exprs) prj
		# (exprs, prj)					= fixCases exprs prj
		= (CBasicArray exprs, prj)
	fixCases value prj
		= (value, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------   
instance fixCases CCasePatternsH
// -------------------------------------------------------------------------------------------------------------------------------------------------   
where
	fixCases (CAlgPatterns ptr patterns) prj
		# (patterns, prj)				= fixCases patterns prj
		| ptrKind ptr == CDataCons
			# (_, consdef, prj)			= getDataConsDef ptr prj
			= (CAlgPatterns consdef.dcdAlgType patterns, prj)
		= (CAlgPatterns ptr patterns, prj)
	fixCases (CBasicPatterns type patterns) prj
		# (patterns, prj)				= fixCases patterns prj
		= (CBasicPatterns type patterns, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------   
instance fixCases CExprH
// -------------------------------------------------------------------------------------------------------------------------------------------------   
where
	fixCases expr=:(CExprVar _) prj
		= (expr, prj)
	fixCases expr=:(CShared _) prj
		= (expr, prj)
	fixCases (expr @# exprs) prj
		# (expr, prj)					= fixCases expr prj
		# (exprs, prj)					= fixCases exprs prj
		= (expr @# exprs, prj)
	fixCases (ptr @@# exprs) prj
		# (exprs, prj)					= fixCases exprs prj
		= (ptr @@# exprs, prj)
	fixCases (CLet strict defs expr) prj
		# (defs, prj)					= fixCases defs prj
		# (expr, prj)					= fixCases expr prj
		= (CLet strict defs expr, prj)
	fixCases (CCase expr patterns mb_default) prj
		# (expr, prj)					= fixCases expr prj
		# (patterns, prj)				= fixCases patterns prj
		# (mb_default, prj)				= fixCases mb_default prj
		= (CCase expr patterns mb_default, prj)
	fixCases (CBasicValue value) prj
		# (value, prj)					= fixCases value prj
		= (CBasicValue value, prj)
	fixCases expr=:(CCode _ _) prj
		= (expr, prj)
	fixCases expr=:(CBottom) prj
		= (expr, prj)