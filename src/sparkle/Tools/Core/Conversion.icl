/*
** Program: Clean Prover System
** Module:  Conversion (.icl)
** 
** Author:  Maarten de Mol
** Created: 23 August 2000
*/

implementation module 
	Conversion

import
	StdEnv,
	CoreCheat,
	CoreTypes,
	CoreAccess,
	Heaps,
	frontend
	, RWSDebug

::	VarInfo
	| VI_CPSExprVar !CheatCompiler /* a pointer to a variable in CleanProverSystem is stored here, using a cast */

::	TypeVarInfo
	| TVI_CPSTypeVar !CheatCompiler /* a pointer to a variable in CleanProverSystem is stored here, using a cast */

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: ConvertEnv =
// -------------------------------------------------------------------------------------------------------------------------------------------------
	{	cenvIclName		:: !ModuleName
	,	cenvIclKey		:: !ModuleKey
	,	cenvIclPtr		:: !ModulePtr
	,	cenvDclNames	:: !{#ModuleName}
	,	cenvVarHeap		:: !.Heap VarInfo
	,	cenvTypeHeap	:: !.Heap TypeVarInfo
	,	cenvHeaps		:: !.CHeaps
	,	cenvPredefined	:: DclModule						// warning: filled with undef in erroronous cases
	}
instance DummyValue ConvertEnv
	where DummyValue =	{ cenvIclName		= DummyValue
						, cenvIclKey		= DummyValue
						, cenvIclPtr		= nilPtr
						, cenvDclNames		= {}
						, cenvVarHeap		= newHeap
						, cenvTypeHeap		= newHeap
						, cenvHeaps			= DummyValue
						, cenvPredefined	= undef
						}

// =================================================================================================================================================
// WARNING: Casts are used to convert CExprVarPtr to CheatProver to CheatCompiler.
// -------------------------------------------------------------------------------------------------------------------------------------------------
buildExprVars :: ![FreeVar] !*ConvertEnv -> (![CExprVarPtr], !*ConvertEnv)
// -------------------------------------------------------------------------------------------------------------------------------------------------
buildExprVars vars env=:{cenvVarHeap, cenvHeaps}
	# (ptrs, cenvVarHeap, cenvHeaps)		= build_vars vars cenvVarHeap cenvHeaps
	# env									= {env	& cenvVarHeap		= cenvVarHeap
													, cenvHeaps			= cenvHeaps
											  }
	= (ptrs, env)
	where
		build_vars :: ![FreeVar] !*(Heap VarInfo) !*CHeaps -> (![CExprVarPtr], !*Heap VarInfo, !*CHeaps)
		build_vars [var:vars] varheap heaps
			# new_def						= {evarName = var.fv_ident.id_name, evarInfo = DummyValue}
			# (new_ptr, heaps)				= newPointer new_def heaps
			# cheat							= toCompiler (CheatExpr new_ptr)
			# varheap						= writePtr var.fv_info_ptr (VI_CPSExprVar cheat) varheap
			# (new_ptrs, varheap, heaps)	= build_vars vars varheap heaps
			= ([new_ptr:new_ptrs], varheap, heaps)
		build_vars [] varheap heaps
			= ([], varheap, heaps)

// =================================================================================================================================================
// WARNING: Casts are used to convert CTypeVarPtr to CheatProver to CheatCompiler.
// -------------------------------------------------------------------------------------------------------------------------------------------------
buildTypeVars :: ![TypeVar] !*ConvertEnv -> (![CTypeVarPtr], !*ConvertEnv)
// -------------------------------------------------------------------------------------------------------------------------------------------------
buildTypeVars vars env=:{cenvTypeHeap, cenvHeaps}
	# (ptrs, cenvTypeHeap, cenvHeaps)		= build_vars vars cenvTypeHeap cenvHeaps
	# env									= {env	& cenvTypeHeap		= cenvTypeHeap
													, cenvHeaps			= cenvHeaps
											  }
	= (ptrs, env)
	where
		build_vars :: ![TypeVar] !*(Heap TypeVarInfo) !*CHeaps -> (![CTypeVarPtr], !*Heap TypeVarInfo, !*CHeaps)
		build_vars [var:vars] typeheap heaps
			# new_def						= {tvarName = var.tv_ident.id_name, tvarInfo = DummyValue}
			# (new_ptr, heaps)				= newPointer new_def heaps
			# cheat							= toCompiler (CheatType new_ptr)
			# typeheap						= writePtr var.tv_info_ptr (TVI_CPSTypeVar cheat) typeheap
			# (new_ptrs, typeheap, heaps)	= build_vars vars typeheap heaps
			= ([new_ptr:new_ptrs], typeheap, heaps)
		build_vars [] typeheap heaps
			= ([], typeheap, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
makeConvertEnv :: !ModuleKey !ModulePtr !*FrontEndSyntaxTree !*CHeaps !*Heaps -> (!*ConvertEnv, !ModuleName, ![DclModule], !*FrontEndSyntaxTree, !*Heaps)
// -------------------------------------------------------------------------------------------------------------------------------------------------
makeConvertEnv icl_index icl_ptr tree cheaps heaps
	# typeheaps							= heaps.hp_type_heaps
	# typeHeap							= typeheaps.th_vars
	# typeheaps							= {typeheaps & th_vars = newHeap}
	# heaps								= {heaps & hp_type_heaps = typeheaps}
	# varHeap							= heaps.hp_var_heap
	# heaps								= {heaps & hp_var_heap = newHeap}
	#! (icl_name, tree)					= tree!fe_icl.icl_name.id_name
	#! (dcl_modules, tree)				= tree!fe_dcls 
	#! imported_dcl_modules				= [dcl_module \\ dcl_module <-: dcl_modules]
	#! (imported_dcl_names, predefined)	= get_names_and_predefined imported_dcl_modules Nothing
	= 	({ cenvIclName		= icl_name
		, cenvIclKey		= icl_index
		, cenvIclPtr		= icl_ptr
		, cenvDclNames		= {dcl_name \\ dcl_name <- imported_dcl_names}
		, cenvVarHeap		= varHeap
		, cenvTypeHeap		= typeHeap
		, cenvHeaps			= cheaps
		, cenvPredefined	= predefined
		}, icl_name, imported_dcl_modules, tree, heaps)
	where
		get_names_and_predefined :: ![DclModule] !(Maybe DclModule) -> (![String], !DclModule)
		get_names_and_predefined [mod:mods] mb_predefined
			# mod_name					= mod.dcl_name.id_name
			# mb_predefined				= case mod_name of
											"_predefined"	-> Just mod
											_				-> mb_predefined
			# (mod_names, predefined)	= get_names_and_predefined mods mb_predefined
			= ([mod_name:mod_names], predefined)
		get_names_and_predefined [] (Just mod)
			= ([], mod)
		get_names_and_predefined [] Nothing
			= abort "Error in makeConvertEnv: unable to find '_predefined' module"

// =================================================================================================================================================
// Used to make up names for '_x' that can occur as function arguments.
// -------------------------------------------------------------------------------------------------------------------------------------------------   
uniqueVariableNames :: ![String] -> (!Error, ![String])
// -------------------------------------------------------------------------------------------------------------------------------------------------   
uniqueVariableNames names 
	= unique_names ['abcdefghijklmnopqrstuvwxyz'] names
	where
		unique_names _ []
			= (OK, [])
		unique_names [] names
			= (pushError (X_Internal "Not enough variable names in uniqueVariableNames.") OK, DummyValue)
		unique_names [new_name: new_names] [name: names]
			# (error, restnames)		= if (name == "_x") (unique_names new_names names) (unique_names [new_name:new_names] names)
			| isError error				= (error, DummyValue)
			| name == "_x"				= (OK, ["_" +++ (toString new_name): restnames])
			= (OK, [name: restnames])













// -------------------------------------------------------------------------------------------------------------------------------------------------   
convertAlgebraicPattern :: !AlgebraicPattern !*ConvertEnv -> (!Error, !CAlgPatternI, !*ConvertEnv)
// -------------------------------------------------------------------------------------------------------------------------------------------------   
convertAlgebraicPattern algpattern cenv
	# (varptrs, cenv)					= buildExprVars algpattern.ap_vars cenv
	# (error, ptr, cenv)				= convertGlobalDefinedSymbol ConsDef algpattern.ap_symbol cenv
	| isError error						= (error, DummyValue, cenv)
	# (error, expr, cenv)				= convertExpression algpattern.ap_expr cenv
	| isError error						= (error, DummyValue, cenv)
	= (OK,	{ atpDataCons				= ptr
			, atpExprVarScope			= varptrs
			, atpResult					= expr
			}, cenv)

/*
// -------------------------------------------------------------------------------------------------------------------------------------------------   
convertAnnotation :: !Annotation -> CIsStrict
// -------------------------------------------------------------------------------------------------------------------------------------------------   
convertAnnotation AN_Strict	= True
convertAnnotation AN_None	= False  
*/

// BEZIG
// -------------------------------------------------------------------------------------------------------------------------------------------------   
convertAType :: !AType !*ConvertEnv -> (!Error, !CTypeI, !*ConvertEnv)
// -------------------------------------------------------------------------------------------------------------------------------------------------   
convertAType atype cenv
//	# strict							= convertAnnotation atype.at_annotation
	# strict							= False
	# (error, type, cenv)				= convertType atype.at_type cenv
	| isError error						= (error, DummyValue, DummyValue)
	| strict							= (OK, CStrict type, cenv)
	| otherwise							= (OK, type, cenv)

// -------------------------------------------------------------------------------------------------------------------------------------------------
convertATypes :: ![AType] !*ConvertEnv -> (!Error, ![CTypeI], !*ConvertEnv)
// -------------------------------------------------------------------------------------------------------------------------------------------------
convertATypes [] cenv
	= (OK, [], cenv)
convertATypes [type:types] cenv
	# (error, ctype, cenv)				= convertAType type cenv
	| isError error						= (error, DummyValue, DummyValue)
	# (error, ctypes, cenv)				= convertATypes types cenv
	| isError error						= (error, DummyValue, DummyValue)
	= (OK, [ctype:ctypes], cenv)

// -------------------------------------------------------------------------------------------------------------------------------------------------   
convertBasicPattern :: !BasicPattern !*ConvertEnv -> (!Error, !CBasicPatternI, !*ConvertEnv)
// -------------------------------------------------------------------------------------------------------------------------------------------------   
convertBasicPattern basicpattern cenv
	# (error, cbasicvalue)				= convertBasicValue basicpattern.bp_value
	| isError error						= (error, DummyValue, DummyValue)
	# (error, cexpr, cenv)				= convertExpression basicpattern.bp_expr cenv
	| isError error						= (error, DummyValue, DummyValue)
	= (OK, {bapBasicValue = cbasicvalue, bapResult = cexpr}, cenv)

// -------------------------------------------------------------------------------------------------------------------------------------------------   
convertBasicType :: !BasicType -> (!Error, !CBasicType)
// -------------------------------------------------------------------------------------------------------------------------------------------------   
convertBasicType BT_Int
	= (OK, CInteger)
convertBasicType BT_Char
	= (OK, CCharacter)
convertBasicType BT_Real
	= (OK, CRealNumber)
convertBasicType BT_Bool
	= (OK, CBoolean)
convertBasicType BT_Dynamic
	= (pushError (X_Internal "Encountered a 'Dynamic' during conversion.") OK, DummyValue)
convertBasicType BT_File
//	# ok								= OK --->> "Warning: encountered the 'File' type (changed to String)"
	= (OK, CString)
convertBasicType BT_World
//	# ok								= OK --->> "Warning: encountered the 'World' type (changed to String)"
	= (OK, CString)
convertBasicType (BT_String _)
	= (OK, CString)

// =================================================================================================================================================
// For strings, the character '"' has to be removed from the first and last position.
// -------------------------------------------------------------------------------------------------------------------------------------------------   
convertBasicValue :: !BasicValue -> (!Error, !CBasicValueI)
// -------------------------------------------------------------------------------------------------------------------------------------------------   
convertBasicValue (BVI text)			= (OK, CBasicInteger (toInt text))
convertBasicValue (BVInt int)			= (OK, CBasicInteger int)
convertBasicValue (BVC text)			= (OK, CBasicCharacter (select text 1))
convertBasicValue (BVB bool)			= (OK, CBasicBoolean bool)
convertBasicValue (BVR text)			= (OK, CBasicRealNumber (toReal text))
convertBasicValue (BVS text)			= (OK, CBasicString (text%(1,size text-2)))
//	#! list								= [c \\ c <-: text]
//	# list								= tl list
//	# list								= take (length list - 1) list
//	# text								= {c \\ c <- list}
//	= (OK, CBasicString text)

// -------------------------------------------------------------------------------------------------------------------------------------------------   
convertCasePatterns :: !CasePatterns !*ConvertEnv -> (!Error, !Bool, !CCasePatternsI, !*ConvertEnv)
// -------------------------------------------------------------------------------------------------------------------------------------------------   
convertCasePatterns (AlgebraicPatterns gindex algpatterns) cenv
	# (def_name, cenv)					= get_def_name gindex cenv
	# (error, ptr, cenv)				= convertGlobalIndex CheckedTypeDef gindex def_name cenv
	| isError error						= (error, DummyValue, DummyValue, cenv)
	# (error, calgpatterns, cenv)		= umapError convertAlgebraicPattern algpatterns cenv
	| isError error						= (error, DummyValue, DummyValue, cenv)
	= (OK, True, CAlgPatterns ptr calgpatterns, cenv)
	where
		get_def_name :: !GlobalIndex !*ConvertEnv -> (!String, !*ConvertEnv)
		get_def_name gindex cenv=:{cenvDclNames, cenvPredefined}
			# dclName					= select cenvDclNames gindex.gi_module
			| dclName <> "_predefined"	= ("?NO NAME KNOWN?", cenv)
			# def_name					= cenvPredefined.dcl_common.com_type_defs.[gindex.gi_index].td_ident.id_name
			= (def_name, cenv)
convertCasePatterns (BasicPatterns basictype basicpatterns) cenv
	# (error, ctype)					= convertBasicType basictype
	| isError error						= (error, DummyValue, DummyValue, cenv)
	# (error, cbasicpatterns, cenv)		= umapError convertBasicPattern basicpatterns cenv
	| isError error						= (error, DummyValue, DummyValue, cenv)
	= (OK, False, CBasicPatterns ctype cbasicpatterns, cenv)
convertCasePatterns (DynamicPatterns dynamicpatterns) cenv
	= (pushError (X_Internal "Encountered a 'DynamicPatterns' during conversion.") OK, DummyValue, DummyValue, cenv)
convertCasePatterns other cenv
	= (pushError (X_Internal "Unrecognized case-format in function convertCasePatterns.") OK, DummyValue, DummyValue, cenv)

class_args_to_list (ClassArg tv cas) = [tv:class_args_to_list cas]
class_args_to_list NoClassArgs = []

// -------------------------------------------------------------------------------------------------------------------------------------------------   
convertClassDef :: !ClassDef !*ConvertEnv -> (!Error, !CClassDefI, !(!CName, !IndexedPtr), !*ConvertEnv)
// -------------------------------------------------------------------------------------------------------------------------------------------------   
convertClassDef classdef cenv
	# (varptrs, cenv)					= buildTypeVars (class_args_to_list classdef.class_args) cenv
	# (error, restrictions, cenv)		= convertTypeContexts classdef.class_context cenv
	| isError error						= (error, DummyValue, DummyValue, DummyValue)
	#! (members, cenv)					= umap (convertDefinedSymbol MemberDef) [member \\ member <-: classdef.class_members] cenv
	# (dictionary, cenv)				= convertDefinedSymbol CheckedTypeDef classdef.class_dictionary cenv
	= (OK,	{ cldName					= classdef.class_ident.id_name
			, cldArity					= classdef.class_arity
			, cldTypeVarScope			= varptrs
			, cldClassRestrictions		= restrictions
			, cldMembers				= members
			, cldDictionary				= dictionary
			, cldInstances				= []
			}, (classdef.class_ident.id_name, dictionary), cenv)

// -------------------------------------------------------------------------------------------------------------------------------------------------   
convertClassDefs :: ![ClassDef] !*ConvertEnv !*CProject -> (!Error, !{!HeapPtr}, ![CClassDefI], ![(CName, IndexedPtr)], !*ConvertEnv, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------   
convertClassDefs classes cenv prj
	# (error, ptrs, defs, dicts, cenv, heap)	= convert classes cenv prj.prjClassHeap
	# prj										= {prj & prjClassHeap = heap}
	| isError error								= (error, DummyValue, DummyValue, DummyValue, cenv, prj)
	# ptrs										= {ptr \\ ptr <- ptrs}
	= (OK, ptrs, defs, dicts, cenv, prj)
	where
		convert :: ![ClassDef] !*ConvertEnv !*(Heap CClassDefH) -> (!Error, ![HeapPtr], ![CClassDefI], ![(CName, IndexedPtr)], !*ConvertEnv, !*(Heap CClassDefH))
		convert [def:defs] cenv heap
			# (mod_ptr, cenv)						= cenv!cenvIclPtr
			# (error, def, dict, cenv)				= convertClassDef def cenv
			| isError error							= (error, DummyValue, DummyValue, DummyValue, cenv, heap)
			# (ptr, heap)							= newPtr DummyValue heap
			# (error, ptrs, defs, dicts, cenv, heap)= convert defs cenv heap
			| isError error							= (error, DummyValue, DummyValue, DummyValue, cenv, heap)
			= (OK, [CClassPtr mod_ptr ptr:ptrs], [def:defs], [dict:dicts], cenv, heap)
		convert [] cenv heap
			= (OK, [], [], [], cenv, heap)

// -------------------------------------------------------------------------------------------------------------------------------------------------   
convertClassInstance :: !ClassInstance !*ConvertEnv -> (!Error, !CInstanceDefI, !*ConvertEnv)
// -------------------------------------------------------------------------------------------------------------------------------------------------   
convertClassInstance classinstance=:{ins_class_index,ins_class_ident={ci_ident=Ident ci_ident,ci_arity} } cenv
	# (varptrs, cenv)					= buildTypeVars classinstance.ins_type.it_vars cenv
	# class_ident = {glob_module=ins_class_index.gi_module,glob_object={ds_index=ins_class_index.gi_index,ds_ident=ci_ident,ds_arity=ci_arity}}
	# (error, classptr, cenv)			= convertGlobalDefinedSymbol ClassDef class_ident cenv
	| isError error						= (error, DummyValue, DummyValue)
	# (error, types, cenv)				= convertTypes classinstance.ins_type.it_types cenv
	| isError error						= (error, DummyValue, DummyValue)
	# (error, restrictions, cenv)		= convertTypeContexts classinstance.ins_type.it_context cenv
	| isError error						= (error, DummyValue, DummyValue)
	#! ins_members						= [{ds_ident=cim_ident,ds_arity=cim_arity,ds_index=cim_index} \\ {cim_ident,cim_arity,cim_index} <-: classinstance.ins_members]
	# (members, cenv)					= umap (convertDefinedSymbol FunDef) ins_members cenv
	= (OK,	{ indName					= classinstance.ins_ident.id_name
			, indClass					= classptr
			, indTypeVarScope			= varptrs
			, indClassArguments			= types
			, indClassRestrictions		= restrictions
			, indMemberFunctions		= members
			}, cenv)

// -------------------------------------------------------------------------------------------------------------------------------------------------   
convertClassInstances :: ![ClassInstance] !*ConvertEnv !*CProject -> (!Error, !{!HeapPtr}, ![CInstanceDefI], !*ConvertEnv, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------   
convertClassInstances instances cenv prj
	# (error, ptrs, defs, cenv, heap)	= convert instances cenv prj.prjInstanceHeap
	# prj								= {prj & prjInstanceHeap = heap}
	| isError error						= (error, DummyValue, DummyValue, cenv, prj)
	# ptrs								= {ptr \\ ptr <- ptrs}
	= (OK, ptrs, defs, cenv, prj)
	where
		convert :: ![ClassInstance] !*ConvertEnv !*(Heap CInstanceDefH) -> (!Error, ![HeapPtr], ![CInstanceDefI], !*ConvertEnv, !*(Heap CInstanceDefH))
		convert [def:defs] cenv heap
			# (mod_ptr, cenv)					= cenv!cenvIclPtr
			# (error, def,  cenv)				= convertClassInstance def cenv
			| isError error						= (error, DummyValue, DummyValue, cenv, heap)
			# (ptr, heap)						= newPtr DummyValue heap
			# (error, ptrs, defs, cenv, heap)	= convert defs cenv heap
			| isError error						= (error, DummyValue, DummyValue, cenv, heap)
			= (OK, [CInstancePtr mod_ptr ptr:ptrs], [def:defs], cenv, heap)
		convert [] cenv heap
			= (OK, [], [], cenv, heap)

// -------------------------------------------------------------------------------------------------------------------------------------------------   
convertConsDef :: !ConsDef !*ConvertEnv -> (!Error, !CDataConsDefI, !*ConvertEnv)
// -------------------------------------------------------------------------------------------------------------------------------------------------   
convertConsDef consdef cenv=:{cenvIclName, cenvIclKey}
	# vars								= smap (\atypevar -> atypevar.atv_variable) consdef.cons_exi_vars
	# (varptrs, cenv)					= buildTypeVars vars cenv
	# (error, symboltype, cenv)			= convertSymbolType consdef.cons_type cenv
	| isError error						= (error, DummyValue, cenv)
	# dcd_def							=	{ dcdName				= consdef.cons_ident.id_name
											, dcdArity				= consdef.cons_type.st_arity
											, dcdAlgType			= IclDefinitionPtr cenvIclName cenvIclKey consdef.cons_ident.id_name CheckedTypeDef consdef.cons_type_index
											, dcdSymbolType			= symboltype
											, dcdInfix				= convertPriority consdef.cons_priority
											, dcdTypeVarScope		= varptrs
											}
	= (error, dcd_def, cenv)

// -------------------------------------------------------------------------------------------------------------------------------------------------   
convertConsDefs :: ![ConsDef] !*ConvertEnv !*CProject -> (!Error, !{!HeapPtr}, ![CDataConsDefI], !*ConvertEnv, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------   
convertConsDefs conses cenv prj
	# (error, ptrs, defs, cenv, heap)	= convert conses cenv prj.prjDataConsHeap
	# prj								= {prj & prjDataConsHeap = heap}
	| isError error						= (error, DummyValue, DummyValue, cenv, prj)
	# ptrs								= {ptr \\ ptr <- ptrs}
	= (OK, ptrs, defs, cenv, prj)
	where
		convert :: ![ConsDef] !*ConvertEnv !*(Heap CDataConsDefH) -> (!Error, ![HeapPtr], ![CDataConsDefI], !*ConvertEnv, !*(Heap CDataConsDefH))
		convert [def:defs] cenv heap
			# (mod_ptr, cenv)					= cenv!cenvIclPtr
			# (error, def,  cenv)				= convertConsDef def cenv
			| isError error						= (error, DummyValue, DummyValue, cenv, heap)
			# (ptr, heap)						= newPtr DummyValue heap
			# (error, ptrs, defs, cenv, heap)	= convert defs cenv heap
			| isError error						= (error, DummyValue, DummyValue, cenv, heap)
			= (OK, [CDataConsPtr mod_ptr ptr:ptrs], [def:defs], cenv, heap)
		convert [] cenv heap
			= (OK, [], [], cenv, heap)

// -------------------------------------------------------------------------------------------------------------------------------------------------   
convertConsVariable :: !ConsVariable !*ConvertEnv -> (!Error, !CTypeVarPtr, !*ConvertEnv)
// -------------------------------------------------------------------------------------------------------------------------------------------------   
convertConsVariable (CV typevar) cenv=:{cenvTypeHeap}
	# (varinfo, cenvTypeHeap)			= readPtr typevar.tv_info_ptr cenvTypeHeap
	# cenv								= {cenv & cenvTypeHeap = cenvTypeHeap}
	# (error, ptr)						= convertTypeVarInfo varinfo
	| isError error						= (error, nilPtr, cenv)
	= (OK, ptr, cenv)
convertConsVariable _ cenv
	= (pushError (X_Internal "Rule 'convertConsVariable' does not match.") OK, nilPtr, cenv)

// -------------------------------------------------------------------------------------------------------------------------------------------------   
convertDefinedSymbol :: !CompilerDefinitionKind !DefinedSymbol !*ConvertEnv -> (!IndexedPtr, !*ConvertEnv)
// -------------------------------------------------------------------------------------------------------------------------------------------------   
convertDefinedSymbol symbol_kind defined_symbol cenv=:{cenvIclName, cenvIclKey}
	# symbol_name						= defined_symbol.ds_ident.id_name
	# symbol_index						= defined_symbol.ds_index
	// = DclDefinitionPtr cenvIclName (Just cenvIclKey) symbol_name symbol_kind symbol_index
	= (IclDefinitionPtr cenvIclName cenvIclKey symbol_name symbol_kind symbol_index, cenv)

// -------------------------------------------------------------------------------------------------------------------------------------------------   
convertExpression :: !Expression !*ConvertEnv -> (!Error, !CExprI, !*ConvertEnv)
// -------------------------------------------------------------------------------------------------------------------------------------------------   
convertExpression (Var boundvar) cenv=:{cenvVarHeap}
	# (varinfo, cenvVarHeap)			= readPtr boundvar.var_info_ptr cenvVarHeap
	# cenv								= {cenv & cenvVarHeap = cenvVarHeap}
	# (error, ptr)						= convertVarInfo varinfo
	| isError error						= (error, DummyValue, cenv)
	= (OK, CExprVar ptr, cenv)
convertExpression (App app) cenv
	# (error, ptr, cenv)				= convertSymbKind app.app_symb.symb_kind app.app_symb.symb_ident.id_name cenv
	| isError error						= (error, DummyValue, cenv)
	# (error, exprs, cenv)				= umapError convertExpression app.app_args cenv
	| isError error						= (error, DummyValue, DummyValue)
	= (OK, ptr @@# exprs, cenv)
convertExpression (expr @ exprs) cenv
	# (error, cexpr, cenv)				= convertExpression expr cenv
	| isError error						= (error, DummyValue, cenv)
	# (error, cexprs, cenv)				= umapError convertExpression exprs cenv
	| isError error						= (error, DummyValue, cenv)
	= (OK, cexpr @# cexprs, cenv)
convertExpression (Let letdef) cenv
	# (error, strict_binds, cenv)		= convert_expression cenv letdef.let_strict_binds
	| isError error						= (error, DummyValue, cenv)
	# (error, lazy_binds, cenv)			= convert_expression cenv letdef.let_lazy_binds 
	| isError error						= (error, DummyValue, cenv)
	# (error, cexpr, cenv)				= convertExpression letdef.let_expr cenv
	| isError error						= (error, DummyValue, cenv)
	| isEmpty strict_binds				= (OK, CLet False lazy_binds cexpr, cenv)
	| isEmpty lazy_binds				= (OK, CLet True strict_binds cexpr, cenv)
	= (OK, CLet True strict_binds (CLet False lazy_binds cexpr), cenv)
	where
		convert_expression cenv let_binds
			# vars						= [bind.lb_dst \\ bind <- let_binds]
			# (varptrs, cenv)			= buildExprVars vars cenv
			#! (error, cexprs, cenv)	= umapError convertExpression [bind.lb_src \\ bind <- let_binds] cenv
			| isError error				= (error, DummyValue, cenv)
			= (OK, (zip2 varptrs cexprs), cenv)
convertExpression (Case casedef) cenv
	# (error, cexpr, cenv)				= convertExpression casedef.case_expr cenv
	| isError error						= (error, DummyValue, cenv)
	# (error, cdefault, cenv)			= optional_convert casedef.case_default cenv
	| isError error						= (error, DummyValue, cenv)
	# (error, alg, cpatterns, cenv)		= convertCasePatterns casedef.case_guards cenv
	| isError error						= (error, DummyValue, cenv)
	# cenv								= admin_case_var cexpr cenv
	= (OK, CCase cexpr cpatterns cdefault, cenv)
	where
		optional_convert :: !(Optional Expression) !*ConvertEnv -> (!Error, !Maybe CExprI, !*ConvertEnv)
		optional_convert (Yes expr) cenv
			# (error, cexpr, cenv)		= convertExpression expr cenv
			| isError error				= (error, DummyValue, cenv)
			= (OK, Just cexpr, cenv)
		optional_convert No cenv
			= (OK, Nothing, cenv)
		
		admin_case_var :: !CExprI !*ConvertEnv -> *ConvertEnv
		admin_case_var (CExprVar ptr) cenv=:{cenvHeaps}
			# (var, heaps)				= readPointer ptr cenvHeaps
			# var						= {var & evarInfo = EVar_InCase}
			# heaps						= writePointer ptr var heaps
			= {cenv & cenvHeaps = heaps}
		admin_case_var expr cenv
			= cenv
convertExpression (BasicExpr basicvalue) cenv
	# (error, cvalue)					= convertBasicValue basicvalue
	| isError error						= (error, DummyValue, cenv)
	= (OK, CBasicValue cvalue, cenv)
convertExpression (Selection _ expr selections) cenv
	# (error, cexpr, cenv)				= convertExpression expr cenv
	| isError error						= (error, DummyValue, cenv)
	= convertSelections cexpr selections cenv
convertExpression (RecordUpdate _ expr binds) cenv
	# (error, cexpr, cenv)				= convertExpression expr cenv
	| isError error						= (error, DummyValue, cenv)
	= convertUpdates cexpr binds cenv
convertExpression (Update expr selections withexpr) cenv
	# (error, cselexpr, cenv)			= convertExpression (Selection NormalSelector expr selections) cenv
	| isError error						= (error, DummyValue, cenv)
	# (error, cwithexpr, cenv)			= convertExpression withexpr cenv
	| isError error						= (error, DummyValue, cenv)
	# (error, cresult)					= case cselexpr of
											// ptr should be "update" FUNCTION (array type is known)
											ptr @@# [carrayexpr, cindexexpr]	-> (OK, ptr @@# [carrayexpr, cindexexpr, cwithexpr])
											// expr should be a dictionary selecting "update" (array type is not known)
											sel @# [carrayexpr, cindexexpr]		-> (OK, sel @# [carrayexpr, cindexexpr, cwithexpr])
											_									-> (pushError (X_Internal "Unrecognized update in convertExpression in module Core.") OK, DummyValue)
	| isError error						= (error, DummyValue, cenv)
	= (OK, cresult, cenv)
convertExpression (TupleSelect tuplesymb sub expr) cenv
	# total								= tuplesymb.ds_arity
	# (error, cexpr, cenv)				= convertExpression expr cenv
	| isError error						= (error, DummyValue, cenv)
	# tempptr							= IclDefinitionPtr "_tupleselect" total "_tupleselect" FunDef (sub+1)
	= (OK, tempptr @@# [cexpr], cenv)
convertExpression (AnyCodeExpr _ _ codetext) cenv
	= (OK, CCode "inline" codetext, cenv)
convertExpression (ABCCodeExpr codetext bool) cenv
	= (OK, CCode "abc" codetext, cenv)
convertExpression (DynamicExpr dyn) cenv
	= (pushError (X_Internal "Encountered a dynamic in convertExpression.") OK, DummyValue, cenv)
convertExpression EE cenv
	= (OK, CBottom, cenv)
convertExpression (NoBind x) cenv
	= (pushError (X_Internal ("Rule convertExpression does not match [encountered NoBind].")) OK, DummyValue, cenv)
// BEZIG
// (MatchExpr symbol expr) is equivalent to:
// case expr of (symbol ....) -> (TUPLE ...)
convertExpression (MatchExpr symbol expr) cenv
	# (error, cexpr, cenv)				= convertExpression expr cenv
	| isError error						= (error, DummyValue, cenv)
	# symbol_arity						= symbol.glob_object.ds_arity
	# match_vars						= [{evarName = "m" +++ toString i, evarInfo = DummyValue} \\ i <- [1..symbol_arity]]
	# (match_var_ptrs, cenvHeaps)		= newPointers match_vars cenv.cenvHeaps
	# cenv								= {cenv & cenvHeaps = cenvHeaps}
	# (error, csymbol, cenv)			= convertGlobalDefinedSymbol ConsDef symbol cenv
	| isError error						= (error, DummyValue, cenv)
	# pattern							=	{	atpDataCons			= csymbol
											,	atpExprVarScope		= match_var_ptrs
											,	atpResult			= create_tuple symbol_arity match_var_ptrs
											}
	// algebraic type corresponding to the constructor must be inserted later
	= (OK, CCase cexpr (CAlgPatterns DummyValue [pattern]) Nothing, cenv)
	where
		create_tuple :: !Int ![CExprVarPtr] -> CExprI
		create_tuple 1 [ptr]
			= CExprVar ptr
		create_tuple arity ptrs
			# tuple_ptr					= IclDefinitionPtr "_tuplecreate" arity "_tuplecreate" ConsDef 0
			= tuple_ptr @@# (map CExprVar ptrs)
convertExpression other cenv
	# ok = OK --->> other
//	# ok = OK
	= (pushError (X_Internal ("Rule convertExpression does not match.")) ok, DummyValue, cenv)

// -------------------------------------------------------------------------------------------------------------------------------------------------   
convertFieldSymbol :: !FieldSymbol !*ConvertEnv -> (!IndexedPtr, !*ConvertEnv)
// -------------------------------------------------------------------------------------------------------------------------------------------------   
convertFieldSymbol fieldsymbol cenv=:{cenvIclName, cenvIclKey}
	# symbolname						= fieldsymbol.fs_ident.id_name
	# symbolindex						= fieldsymbol.fs_index
	= (IclDefinitionPtr cenvIclName cenvIclKey symbolname SelectorDef symbolindex, cenv)

// -------------------------------------------------------------------------------------------------------------------------------------------------
convertFrontEndSyntaxTree :: !*FrontEndSyntaxTree !*Heaps !ModuleKey !String !*CHeaps !*CProject -> (!Error, !ModulePtr, !*Heaps, !*CHeaps, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------
convertFrontEndSyntaxTree tree heaps mod_key mod_path cheaps prj
	# (mod_ptr, cheaps)										= newPointer DummyValue cheaps
	# (cenv, mod_name, dcl_modules, tree, heaps)			= makeConvertEnv mod_key mod_ptr tree cheaps heaps
	# icl_module											= tree.fe_icl
	# maybe_dcl_module										= find_own_dcl_module 0 (size tree.fe_dcls) mod_name tree.fe_dcls

	# checked_type_defs										= [def \\ def <-: icl_module.icl_common.com_type_defs]
	# (error, type_ptrs, alg_defs, rec_defs, cenv, prj)		= convertTypeDefs checked_type_defs cenv prj
	| isError error											= (pushError (X_ConvertModule mod_name) error, nilPtr, heaps, cenv.cenvHeaps, prj)	

	# class_defs											= [def \\ def <-: icl_module.icl_common.com_class_defs]
	# (error, class_ptrs, class_defs, dicts, cenv, prj)		= convertClassDefs class_defs cenv prj
	| isError error											= (pushError (X_ConvertModule mod_name) error, nilPtr, heaps, cenv.cenvHeaps, prj)

	# cons_defs												= [def \\ def <-: icl_module.icl_common.com_cons_defs]
	# (error, cons_ptrs, cons_defs, cenv, prj)				= convertConsDefs cons_defs cenv prj
	| isError error											= (pushError (X_ConvertModule mod_name) error, nilPtr, heaps, cenv.cenvHeaps, prj)

	# fun_defs												= [def \\ def <-: icl_module.icl_functions]
	# (error, fun_ptrs, fun_defs, cenv, prj)				= convertFunDefs fun_defs cenv prj
	| isError error											= (pushError (X_ConvertModule mod_name) error, nilPtr, heaps, cenv.cenvHeaps, prj)

	# instance_defs											= [def \\ def <-: icl_module.icl_common.com_instance_defs]
	# (error, instance_ptrs, instance_defs, cenv, prj)		= convertClassInstances instance_defs cenv prj
	| isError error											= (pushError (X_ConvertModule mod_name) error, nilPtr, heaps, cenv.cenvHeaps, prj)

	# member_defs											= [def \\ def <-: icl_module.icl_common.com_member_defs]
	# (error, member_ptrs, member_defs, cenv, prj)			= convertMemberDefs member_defs cenv prj
	| isError error											= (pushError (X_ConvertModule mod_name) error, nilPtr, heaps, cenv.cenvHeaps, prj)

	# selector_defs											= [def \\ def <-: icl_module.icl_common.com_selector_defs]
	# (error, selector_ptrs, field_defs, cenv, prj)			= convertSelectorDefs selector_defs cenv prj
	| isError error											= (pushError (X_ConvertModule mod_name) error, nilPtr, heaps, cenv.cenvHeaps, prj)

	# heaps													= {heaps & hp_type_heaps.th_vars = cenv.cenvTypeHeap, hp_var_heap = cenv.cenvVarHeap}
	#! dcl_modules											= tree.fe_dcls
	#! imported_names										= findImportedNames icl_module.icl_used_module_numbers dcl_modules
	
	#! conversion_table										= get_conversion_table mod_name tree.fe_dcls
	#! conversion_table										= adjustConversionTable conversion_table tree
	
	# mod													=	{ pmName				= mod_name
																, pmPath				= mod_path
																, pmImportedModules		= []
																, pmAlgTypePtrs			= []
																, pmClassPtrs			= []
																, pmDataConsPtrs		= []
																, pmFunPtrs				= []
																, pmInstancePtrs		= []
																, pmMemberPtrs			= []
																, pmRecordTypePtrs		= []
																, pmRecordFieldPtrs		= []
																, pmCompilerStore		= Just	{ csAlgTypeDefs			= alg_defs
																								, csClassDefs			= class_defs
																								, csDataConsDefs		= cons_defs
																								, csFunDefs				= fun_defs
																								, csInstanceDefs		= instance_defs
																								, csMemberDefs			= member_defs
																								, csRecordFieldDefs		= field_defs
																								, csRecordTypeDefs		= rec_defs
																								, csImports				= imported_names
																								}
																// suspicious revision due to compiler:
																// field fe_dclIclConversions from FrontEndSyntaxTree has been removed
																, pmCompilerConversion	=	{ ccCheckedTypePtrs		= type_ptrs
																							, ccClassPtrs			= class_ptrs
																							, ccConsPtrs			= cons_ptrs
																							, ccFunPtrs				= fun_ptrs
																							, ccInstancePtrs		= instance_ptrs
																							, ccMemberPtrs			= member_ptrs
																							, ccSelectorPtrs		= selector_ptrs
																							, ccDictionaries		= dicts
																							, ccConversionTable		= conversion_table
																							, ccDclIclConversions	= {} //fromOptional tree.fe_dclIclConversions
																							}
																, pmOriginalNrDclConses	= find_original_nr_dcl_conses maybe_dcl_module
																}
	# cheaps												= writePointer mod_ptr mod cenv.cenvHeaps
	= (OK, mod_ptr, heaps, cheaps, prj)
	where
		// optional_to_maybe :: !(Optional a) -> !Maybe a
		fromOptional (Yes a)	= a
		fromOptional No			= {}
		
		find_own_dcl_module :: !Int !Int !String !{#DclModule} -> Maybe DclModule
		find_own_dcl_module index nr_dcls module_name dcls
			| index >= nr_dcls							= Nothing
			# dcl										= dcls.[index]
			| dcl.dcl_name.id_name == module_name		= Just dcl
			= find_own_dcl_module (index+1) nr_dcls module_name dcls
		
		find_original_nr_dcl_conses :: !(Maybe DclModule) -> Int
		find_original_nr_dcl_conses Nothing
			= 0
		find_original_nr_dcl_conses (Just dcl)
			= (size dcl.dcl_common.com_cons_defs) - (size dcl.dcl_common.com_class_defs)
		
		get_conversion_table :: !ModuleName !{#DclModule} -> ConversionTable
		get_conversion_table modname dcls
			# si									= size dcls
			= get_conversion_table_i modname 0 si dcls
			where
				get_conversion_table_i :: !ModuleName !Int !Int !{#DclModule} -> ConversionTable
				get_conversion_table_i modname index len dcls
					| index >= len						= {}
					# dcl								= select dcls index
					| dcl.dcl_name.id_name == modname	= optional_to_array No // dcl.dcl_macro_conversions
					| otherwise							= get_conversion_table_i modname (index + 1) len dcls
				
				optional_to_array :: !(Optional {#Index}) -> ConversionTable
				optional_to_array No
					= {{}, {}, {}, {}, {}, {}, {}, {}, {}}
				optional_to_array (Yes table)
					= {{}, {}, {}, {}, {}, {}, {}, {}, table}

// -------------------------------------------------------------------------------------------------------------------------------------------------   
convertFunDef :: !FunDef !*ConvertEnv -> (!Error, !Bool, !CFunDefI, !*ConvertEnv)
// -------------------------------------------------------------------------------------------------------------------------------------------------   
convertFunDef fundef cenv
	# (iclName, cenv)					= cenv!cenvIclName
	# funtype							= toJust fundef.fun_type
	| not (is_function fundef.fun_kind)	= (OK, False, DummyValue, cenv)
	# (error, symboltype, cenv)			= case funtype of
											Nothing -> (OK, DummyValue, cenv)
											Just ft -> convertSymbolType ft cenv
	| isError error						= (error, DummyValue, DummyValue, DummyValue)
	// A function with a CheckedBody is a macro that has been completely expanded; it can be ignored
	| is_checked_body fundef.fun_body	= (OK, False, DummyValue, cenv)
	# (error, maybe_transformedbody)	= get_transformed_body fundef.fun_body
	| isError error						= (error, DummyValue, DummyValue, cenv)
	# transformedbody					= fromJust maybe_transformedbody
	# (varptrs, cenv)					= buildExprVars transformedbody.tb_args cenv
	# varnames							= smap (\freevar -> freevar.fv_ident.id_name) transformedbody.tb_args
	# (error, varnames)					= uniqueVariableNames varnames
	| isError error						= (error, True, DummyValue, cenv)
	# heaps								= changePointerNames varptrs varnames cenv.cenvHeaps
	# cenv								= {cenv & cenvHeaps = heaps}
	# (error, body, cenv)				= convertExpression transformedbody.tb_rhs cenv
	| isError error						= (error, True, DummyValue, cenv)
	# funname							= fundef.fun_ident.id_name
	# funname							= if (not (is_function fundef.fun_kind)) ("macro_" +++ funname) funname
	# (case_variables, cenv)			= find_case_variables 0 varptrs cenv
	# cfundef							=	{ fdName 				= funname
											, fdOldName				= ""
											, fdArity				= fundef.fun_arity
											, fdCaseVariables		= case_variables
											, fdStrictVariables		= []
											, fdSymbolType			= symboltype
											, fdHasType				= isJust funtype
											, fdExprVarScope		= varptrs
											, fdInfix				= convertPriority fundef.fun_priority
											, fdBody				= body
											, fdIsRecordSelector	= False
											, fdIsRecordUpdater		= False
											, fdNrDictionaries		= 0
											, fdRecordFieldDef		= DummyValue
											, fdIsDeltaRule			= False
											, fdDeltaRule			= \_ -> LBottom
											, fdOpaque				= False
											, fdDefinedness			= CDefinednessUnknown
											}
	= (OK, True, cfundef, cenv)
	where
		find_case_variables :: !Int ![CExprVarPtr] !*ConvertEnv -> (![Int], !*ConvertEnv)
		find_case_variables index [ptr:ptrs] cenv=:{cenvHeaps}
			# (var, heaps)				= readPointer ptr cenvHeaps
			# cenv						= {cenv & cenvHeaps = heaps}
			# (case_variables, cenv)	= find_case_variables (index+1) ptrs cenv
			| is_case var.evarInfo
				= ([index:case_variables], cenv)
				= (case_variables, cenv)
			where
				is_case EVar_InCase		= True
				is_case _				= False
		find_case_variables index [] cenv
			= ([], cenv)
	
		toJust :: !(Optional a) -> Maybe a
		toJust (Yes x)	= Just x
		toJust No		= Nothing
		
		is_checked_body :: !FunctionBody -> Bool
		is_checked_body (CheckedBody _)		= True
		is_checked_body _					= False
		
		is_function :: !FunKind -> Bool
		is_function (FK_Function _)			= True
		is_function _						= False
		
		get_transformed_body :: !FunctionBody -> (!Error, !Maybe TransformedBody)
		get_transformed_body (TransformedBody transformed_body)
			= (OK, Just transformed_body)
		get_transformed_body other
			= (pushError (X_Internal ("Function '" +++ fundef.fun_ident.id_name +++ "' does not have a TransformedBody.")) OK, Nothing)

// -------------------------------------------------------------------------------------------------------------------------------------------------   
convertFunDefs :: ![FunDef] !*ConvertEnv !*CProject -> (!Error, !{!HeapPtr}, ![CFunDefI], !*ConvertEnv, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------   
convertFunDefs funs cenv prj
	# (error, ptrs, defs, cenv, heap)	= convert funs cenv prj.prjFunHeap
	# prj								= {prj & prjFunHeap = heap}
	| isError error						= (error, DummyValue, DummyValue, cenv, prj)
	# ptrs								= {ptr \\ ptr <- ptrs}
	= (OK, ptrs, defs, cenv, prj)
	where
		convert :: ![FunDef] !*ConvertEnv !*(Heap CFunDefH) -> (!Error, ![HeapPtr], ![CFunDefI], !*ConvertEnv, !*(Heap CFunDefH))
		convert [def:defs] cenv heap
			# (mod_ptr, cenv)						= cenv!cenvIclPtr
			# (error, no_macro, def, cenv)			= convertFunDef def cenv
			| isError error							= (error, DummyValue, DummyValue, cenv, heap)
			| not no_macro
				# (error, ptrs, defs, cenv, heap)	= convert defs cenv heap
				| isError error						= (error, DummyValue, DummyValue, cenv, heap)
				= (OK, [DummyValue:ptrs], defs, cenv, heap)
			| no_macro
				# (ptr, heap)						= newPtr DummyValue heap
				# (error, ptrs, defs, cenv, heap)	= convert defs cenv heap
				| isError error						= (error, DummyValue, DummyValue, cenv, heap)
				= (OK, [CFunPtr mod_ptr ptr:ptrs], [def:defs], cenv, heap)
			= undef // unreachable; needed for uniqueness typing (??)
		convert [] cenv heap
			= (OK, [], [], cenv, heap)

// -------------------------------------------------------------------------------------------------------------------------------------------------   
convertGlobalDefinedSymbol :: !CompilerDefinitionKind !(Global DefinedSymbol) !*ConvertEnv -> (!Error, !IndexedPtr, !*ConvertEnv)
// -------------------------------------------------------------------------------------------------------------------------------------------------   
convertGlobalDefinedSymbol symbol_kind gsymbol cenv=:{cenvIclName, cenvIclKey, cenvDclNames}
	| gsymbol.glob_module < 0				= (pushError (X_Internal "Error in convertGlobalDefinedSymbol: index of dcl-module < 0.") OK, DummyValue, DummyValue)
	# nr_modules							= size cenvDclNames
	| gsymbol.glob_module+1 > nr_modules	= (pushError (X_Internal "Error in convertGlobalDefinedSymbol: index of dcl-module too large.") OK, DummyValue, DummyValue)
	# dclName								= select cenvDclNames gsymbol.glob_module
	| dclName == cenvIclName				= (OK, IclDefinitionPtr cenvIclName cenvIclKey gsymbol.glob_object.ds_ident.id_name symbol_kind gsymbol.glob_object.ds_index, cenv)
	= (OK, DclDefinitionPtr dclName gsymbol.glob_object.ds_ident.id_name symbol_kind gsymbol.glob_object.ds_index, cenv)

// -------------------------------------------------------------------------------------------------------------------------------------------------   
convertGlobalFieldSymbol :: !(Global FieldSymbol) !*ConvertEnv -> (!Error, !IndexedPtr, !*ConvertEnv)
// -------------------------------------------------------------------------------------------------------------------------------------------------   
convertGlobalFieldSymbol gsymbol cenv=:{cenvIclName, cenvIclKey, cenvDclNames}
	| gsymbol.glob_module < 0				= (pushError (X_Internal "Error in convertGlobalFieldSymbol: index of dcl-module < 0.") OK, DummyValue, DummyValue)
	# nr_modules							= size cenvDclNames
	| gsymbol.glob_module+1 > nr_modules	= (pushError (X_Internal "Error in convertGlobalFieldSymbol: index of dcl-module too large.") OK, DummyValue, DummyValue)
	# dclName								= select cenvDclNames gsymbol.glob_module
	# symbolname							= gsymbol.glob_object.fs_ident.id_name
	# symbolindex							= gsymbol.glob_object.fs_index
	| dclName == cenvIclName				= (OK, IclDefinitionPtr cenvIclName cenvIclKey symbolname SelectorDef symbolindex, cenv)
	= (OK, DclDefinitionPtr dclName symbolname SelectorDef symbolindex, cenv)

// -------------------------------------------------------------------------------------------------------------------------------------------------   
convertGlobal_Index :: !CompilerDefinitionKind !(Global Index) !CName !*ConvertEnv -> (!Error, !IndexedPtr, !*ConvertEnv)
// -------------------------------------------------------------------------------------------------------------------------------------------------   
convertGlobal_Index symbol_kind gindex def_name cenv=:{cenvIclName, cenvIclKey, cenvDclNames}
	| gindex.glob_module < 0				= (pushError (X_Internal "Error in convertGlobal_Index: index of dcl-module < 0.") OK, DummyValue, DummyValue)
	# nr_modules							= size cenvDclNames
	| gindex.glob_module+1 > nr_modules		= (pushError (X_Internal ("Error in convertGlobal_Index: index of dcl-module(" +++ toString gindex.glob_module +++ ") too large.")) OK, DummyValue, DummyValue)
	# dclName								= select cenvDclNames gindex.glob_module
	| dclName == cenvIclName				= (OK, IclDefinitionPtr cenvIclName cenvIclKey def_name symbol_kind gindex.glob_object, cenv)
	# the_dcl_ptr							= DclDefinitionPtr dclName def_name symbol_kind gindex.glob_object
	= (OK, the_dcl_ptr, cenv)

convertGlobalIndex :: !CompilerDefinitionKind !GlobalIndex !CName !*ConvertEnv -> (!Error, !IndexedPtr, !*ConvertEnv)
convertGlobalIndex symbol_kind gindex def_name cenv=:{cenvIclName, cenvIclKey, cenvDclNames}
	| gindex.gi_module < 0					= (pushError (X_Internal "Error in convertGlobalIndex: index of dcl-module < 0.") OK, DummyValue, DummyValue)
	# nr_modules							= size cenvDclNames
	| gindex.gi_module+1 > nr_modules		= (pushError (X_Internal ("Error in convertGlobalIndex: index of dcl-module(" +++ toString gindex.gi_module +++ ") too large.")) OK, DummyValue, DummyValue)
	# dclName								= select cenvDclNames gindex.gi_index
	| dclName == cenvIclName				= (OK, IclDefinitionPtr cenvIclName cenvIclKey def_name symbol_kind gindex.gi_index, cenv)
	# the_dcl_ptr							= DclDefinitionPtr dclName def_name symbol_kind gindex.gi_index
	= (OK, the_dcl_ptr, cenv)

// -------------------------------------------------------------------------------------------------------------------------------------------------   
convertMemberDef :: !MemberDef !*ConvertEnv -> (!Error, !CMemberDefI, !*ConvertEnv)
// -------------------------------------------------------------------------------------------------------------------------------------------------   
convertMemberDef memberdef cenv
	# (error, classptr, cenv)			= convertGlobal_Index ClassDef memberdef.me_class "Class name unknown" cenv
	| isError error						= (error, DummyValue, DummyValue)
	# (error, symboltype, cenv)			= convertSymbolType memberdef.me_type cenv
	| isError error						= (error, DummyValue, cenv)
	= (OK,	{ mbdName					= memberdef.me_ident.id_name
			, mbdClass					= classptr
			, mbdSymbolType				= symboltype
			, mbdInfix					= convertPriority memberdef.me_priority
			}, cenv)

// -------------------------------------------------------------------------------------------------------------------------------------------------   
convertMemberDefs :: ![MemberDef] !*ConvertEnv !*CProject -> (!Error, !{!HeapPtr}, ![CMemberDefI], !*ConvertEnv, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------   
convertMemberDefs members cenv prj
	# (error, ptrs, defs, cenv, heap)	= convert members cenv prj.prjMemberHeap
	# prj								= {prj & prjMemberHeap = heap}
	| isError error						= (error, DummyValue, DummyValue, cenv, prj)
	# ptrs								= {ptr \\ ptr <- ptrs}
	= (OK, ptrs, defs, cenv, prj)
	where
		convert :: ![MemberDef] !*ConvertEnv !*(Heap CMemberDefH) -> (!Error, ![HeapPtr], ![CMemberDefI], !*ConvertEnv, !*(Heap CMemberDefH))
		convert [def:defs] cenv heap
			# (mod_ptr, cenv)					= cenv!cenvIclPtr
			# (error, def,  cenv)				= convertMemberDef def cenv
			| isError error						= (error, DummyValue, DummyValue, cenv, heap)
			# (ptr, heap)						= newPtr DummyValue heap
			# (error, ptrs, defs, cenv, heap)	= convert defs cenv heap
			| isError error						= (error, DummyValue, DummyValue, cenv, heap)
			= (OK, [CMemberPtr mod_ptr ptr:ptrs], [def:defs], cenv, heap)
		convert [] cenv heap
			= (OK, [], [], cenv, heap)

// -------------------------------------------------------------------------------------------------------------------------------------------------
convertPriority :: !Priority -> CInfix
// -------------------------------------------------------------------------------------------------------------------------------------------------
convertPriority NoPrio					= CNoInfix
convertPriority (Prio LeftAssoc prio)	= CLeftAssociative prio
convertPriority (Prio RightAssoc prio)	= CRightAssociative prio
convertPriority (Prio NoAssoc prio)		= CNotAssociative prio

// When converting the selection of a record, an application is created with the FIELD at the application node.
// This ptr is converted later to the appriopriate function ptr.
// -------------------------------------------------------------------------------------------------------------------------------------------------
convertSelections :: !CExprI ![Selection] !*ConvertEnv -> (!Error, !CExprI, !*ConvertEnv)
// -------------------------------------------------------------------------------------------------------------------------------------------------
convertSelections expr [] cenv
	= (OK, expr, cenv)
convertSelections expr [ArraySelection gsymbol _ selexpr] cenv
	# (error, ptr, cenv)				= convertGlobalDefinedSymbol FunDef gsymbol cenv
	| isError error						= (error, DummyValue, cenv)
	# (error, cselexpr, cenv)			= convertExpression selexpr cenv
	| isError error						= (error, DummyValue, cenv)
//	= (OK, CArraySelect expr cselexpr, cenv)
	= (OK, ptr @@# [expr, cselexpr], cenv)
convertSelections expr [RecordSelection fieldsymbol fieldindex: sels] cenv
	# (error, fieldptr, cenv)			= convertGlobalDefinedSymbol SelectorDef fieldsymbol cenv
	| isError error						= (error, DummyValue, cenv)
	= convertSelections (fieldptr @@# [expr]) sels cenv
convertSelections expr [(DictionarySelection boundvar selections ptr dexpr): sels] cenv
	# (error, cexpr, cenv)				= convertExpression dexpr cenv
	| isError error						= (error, DummyValue, cenv)
	# (error, cboundvar, cenv)			= convertExpression (Var boundvar) cenv
	| isError error						= (error, DummyValue, cenv)
	# (error, cselectexpr, cenv)		= convertSelections cboundvar selections cenv
	| isError error						= (error, DummyValue, cenv)
	= convertSelections (cselectexpr @# [expr, cexpr]) sels cenv

// -------------------------------------------------------------------------------------------------------------------------------------------------
convertSelectorDef :: !SelectorDef !*ConvertEnv -> (!Error, !CRecordFieldDefI, !*ConvertEnv)
// -------------------------------------------------------------------------------------------------------------------------------------------------
convertSelectorDef selectordef cenv=:{cenvIclName, cenvIclKey}
	# record_type						= (hd selectordef.sd_type.st_args).at_type
	# exi_vars							= smap (\atypevar -> atypevar.atv_variable) selectordef.sd_exi_vars
	# (varptrs, cenv)					= buildTypeVars exi_vars cenv
	# (error, symboltype, cenv)			= convertSymbolType selectordef.sd_type cenv
	| isError error						= (error, DummyValue, cenv)
	# field_def							= 	{ rfName				= selectordef.sd_field.id_name
											, rfIndex				= selectordef.sd_field_nr
											, rfRecordType			= IclDefinitionPtr cenvIclName cenvIclKey selectordef.sd_field.id_name CheckedTypeDef selectordef.sd_type_index
											, rfSymbolType			= symboltype
											, rfTempTypeVarScope	= Just varptrs
											, rfSelectorFun			= DummyValue
											, rfUpdaterFun			= DummyValue
											}
	= (OK, field_def, cenv)
	where
		get_nr_type_args :: !Type -> Int
		get_nr_type_args (TA recordtype args)	= length args
		get_nr_type_args _						= abort "Error in convertSelectorDef: could not determine number of arguments of record."

// -------------------------------------------------------------------------------------------------------------------------------------------------   
convertSelectorDefs :: ![SelectorDef] !*ConvertEnv !*CProject -> (!Error, !{!HeapPtr}, ![CRecordFieldDefI], !*ConvertEnv, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------   
convertSelectorDefs selectors cenv prj
	# (error, ptrs, defs, cenv, heap)	= convert selectors cenv prj.prjRecordFieldHeap
	# prj								= {prj & prjRecordFieldHeap = heap}
	| isError error						= (error, DummyValue, DummyValue, cenv, prj)
	# ptrs								= {ptr \\ ptr <- ptrs}
	= (OK, ptrs, defs, cenv, prj)
	where
		convert :: ![SelectorDef] !*ConvertEnv !*(Heap CRecordFieldDefH) -> (!Error, ![HeapPtr], ![CRecordFieldDefI], !*ConvertEnv, !*(Heap CRecordFieldDefH))
		convert [def:defs] cenv heap
			# (mod_ptr, cenv)					= cenv!cenvIclPtr
			# (error, def,  cenv)				= convertSelectorDef def cenv
			| isError error						= (error, DummyValue, DummyValue, cenv, heap)
			# (ptr, heap)						= newPtr DummyValue heap
			# (error, ptrs, defs, cenv, heap)	= convert defs cenv heap
			| isError error						= (error, DummyValue, DummyValue, cenv, heap)
			= (OK, [CRecordFieldPtr mod_ptr ptr:ptrs], [def:defs], cenv, heap)
		convert [] cenv heap
			= (OK, [], [], cenv, heap)

// -------------------------------------------------------------------------------------------------------------------------------------------------
convertSymbKind :: !SymbKind !String !*ConvertEnv -> (!Error, !IndexedPtr, !*ConvertEnv)
// -------------------------------------------------------------------------------------------------------------------------------------------------
convertSymbKind (SK_Function gindex) name cenv
	# (error, ptr, cenv)				= convertGlobal_Index FunDef gindex name cenv
	| isError error						= (error, DummyValue, cenv)
	= (OK, ptr, cenv)
convertSymbKind (SK_Constructor gindex) name cenv
	# (error, ptr, cenv)				= convertGlobal_Index ConsDef gindex name cenv
	| isError error						= (error, DummyValue, cenv)
	= (OK, ptr, cenv)
convertSymbKind (SK_LocalMacroFunction index) name cenv=:{cenvIclName, cenvIclKey}
	= (OK, IclDefinitionPtr cenvIclName cenvIclKey name FunDef index, cenv)
convertSymbKind (SK_GeneratedFunction _ index) name cenv=:{cenvIclName, cenvIclKey}
	= (OK, IclDefinitionPtr cenvIclName cenvIclKey name FunDef index, cenv)
convertSymbKind (SK_OverloadedFunction gindex) name cenv=:{cenvIclName, cenvIclKey}
	# (error, ptr, cenv)				= convertGlobal_Index MemberDef gindex name cenv
	| isError error						= (error, DummyValue, cenv)
	= (OK, ptr, cenv)
convertSymbKind other name cenv
	= (pushError (X_Internal ("Rule 'convertSymbKind' does not match." +++ toString other)) OK, DummyValue, cenv)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance toString SymbKind where
// -------------------------------------------------------------------------------------------------------------------------------------------------
	toString SK_Unknown
		=	"SK_Unkown"
	toString (SK_Function index)
		=	"SK_Function" +++ toString index
	toString (SK_IclMacro index)
		=	"SK_IclMacro" +++ toString index
	toString (SK_LocalMacroFunction index)
		=	"SK_LocalMacroFunction" +++ toString index
	toString (SK_DclMacro index)
		=	"SK_DclMacro" +++ toString index
	toString (SK_LocalDclMacroFunction index)
		=	"SK_LocalDclMacroFunction" +++ toString index
	toString (SK_OverloadedFunction index)
		=	"SK_OverloadedFunction" +++ toString index
	toString (SK_GeneratedFunction _ index)
		=	"SK_GeneratedFunction" +++ toString index
	toString (SK_Constructor index)
		=	"SK_Constructor" +++ toString index
	toString (SK_Generic _ _)
		=	"SK_Generic ? ?"
	toString SK_TypeCode
		=	"SK_TypeCode"

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance toString (Global x) | toString x where
// -------------------------------------------------------------------------------------------------------------------------------------------------
	toString {glob_object, glob_module}
		=	"{glob_object=" +++ toString glob_object +++ ", glob_module=" +++ toString glob_module +++ "}"

// -------------------------------------------------------------------------------------------------------------------------------------------------
convertTCClass :: !TCClass !*ConvertEnv -> (!Error, !IndexedPtr, !*ConvertEnv)
// -------------------------------------------------------------------------------------------------------------------------------------------------
convertTCClass (TCClass g_symbol) cenv
	= convertGlobalDefinedSymbol ClassDef g_symbol cenv
convertTCClass (TCGeneric _) cenv
	= (pushError (X_Internal "Cannot internalize programs which make use of generics.") OK, DummyValue, cenv)

// -------------------------------------------------------------------------------------------------------------------------------------------------
convertSymbolType :: !SymbolType !*ConvertEnv -> (!Error, !CSymbolTypeI, !*ConvertEnv)
// -------------------------------------------------------------------------------------------------------------------------------------------------
convertSymbolType symboltype cenv
	# (varptrs, cenv)					= buildTypeVars symboltype.st_vars cenv
	# (error, args, cenv)				= convertATypes symboltype.st_args cenv
	| isError error						= (error, DummyValue, cenv)
	# args								= addStrictness 0 args symboltype.st_args_strictness
	# (error, result, cenv)				= convertAType symboltype.st_result cenv
	| isError error						= (error, DummyValue, cenv)
	# (error, restrictions, cenv)		= convertTypeContexts symboltype.st_context cenv
	| isError error						= (error, DummyValue, cenv)
	= (OK,	{ sytArguments				= smap clean_up args
			, sytTypeVarScope			= varptrs
			, sytResult					= clean_up result
			, sytClassRestrictions		= restrictions
			}, cenv)
	where
		clean_up :: !(CType a) -> CType a
		clean_up (type1 ==> type2)				= (clean_up type1) ==> (clean_up type2)
		clean_up ((ptr @@^ args1) @^ args2)		= clean_up (ptr @@^ (args1 ++ args2))
		clean_up (type @^ types)				= (clean_up type) @^ (smap clean_up types)
		clean_up (ptr @@^ types)				= ptr @@^ (smap clean_up types)
		clean_up other							= other

// -------------------------------------------------------------------------------------------------------------------------------------------------
convertType :: !Type !*ConvertEnv -> (!Error, !CTypeI, !*ConvertEnv)
// -------------------------------------------------------------------------------------------------------------------------------------------------
convertType (TA tsymbident types) cenv
	# (error, symbol, cenv)				= convertTypeSymbIdent tsymbident cenv
	| isError error						= (error, DummyValue, cenv)
	# (error, args, cenv)				= convertATypes types cenv
	| isError error						= (error, DummyValue, cenv)
	| is_string symbol					= (OK, unboxed_array @@^ [CBasicType CCharacter], cenv)
	= (OK, symbol @@^ args, cenv)
	where
		is_string :: !IndexedPtr -> Bool
		is_string (DclDefinitionPtr "_predefined" _ CheckedTypeDef 0)	= True
		is_string other													= False
		
		unboxed_array :: IndexedPtr
//		unboxed_array = DclDefinitionPtr "_predefined" "{#}" CheckedTypeDef 35
		unboxed_array = DclDefinitionPtr "_predefined" "_#Array" CheckedTypeDef 35
convertType (TAS tsymbident types strict) cenv
	# (error, symbol, cenv)				= convertTypeSymbIdent tsymbident cenv
	| isError error						= (error, DummyValue, cenv)
	# (error, args, cenv)				= convertATypes types cenv
	| isError error						= (error, DummyValue, cenv)
	# args								= addStrictness 0 args strict
	| is_string symbol					= (OK, unboxed_array @@^ [CBasicType CCharacter], cenv)
	= (OK, symbol @@^ args, cenv)
	where
		is_string :: !IndexedPtr -> Bool
		is_string (DclDefinitionPtr "_predefined" _ CheckedTypeDef 0)	= True
		is_string other													= False
		
		unboxed_array :: IndexedPtr
//		unboxed_array = DclDefinitionPtr "_predefined" "{#}" CheckedTypeDef 35
		unboxed_array = DclDefinitionPtr "_predefined" "_#Array" CheckedTypeDef 35
convertType (atype1 --> atype2) cenv
	# (error, ctype1, cenv)				= convertAType atype1 cenv
	| isError error						= (error, DummyValue, cenv)
	# (error, ctype2, cenv)				= convertAType atype2 cenv 
	| isError error						= (error, DummyValue, cenv)
	= (OK, ctype1 ==> ctype2, cenv)
convertType (consvar :@: atypes) cenv
	# (error, ptr, cenv)				= convertConsVariable consvar cenv
	| isError error						= (error, DummyValue, cenv)
	# (error, args, cenv)				= convertATypes atypes cenv
	| isError error						= (error, DummyValue, cenv)
	= (OK, (CTypeVar ptr) @^ args, cenv)
convertType (TB basictype) cenv
	# (error, type)						= convertBasicType basictype
	= (error, CBasicType type, cenv)
convertType (GTV typevar) cenv=:{cenvTypeHeap}
	# (varinfo, cenvTypeHeap)			= readPtr typevar.tv_info_ptr cenvTypeHeap
	# cenv								= {cenv & cenvTypeHeap = cenvTypeHeap}
	# (error, varptr)					= convertTypeVarInfo varinfo
	| isError error						= (error, DummyValue, cenv)
	= (OK, CTypeVar varptr, cenv)
convertType (TV typevar) cenv=:{cenvTypeHeap}
	# (varinfo, cenvTypeHeap)			= readPtr typevar.tv_info_ptr cenvTypeHeap
	# cenv								= {cenv & cenvTypeHeap = cenvTypeHeap}
	# (error, varptr)					= convertTypeVarInfo varinfo
	| isError error						= (error, DummyValue, cenv)
	= (OK, CTypeVar varptr, cenv)
convertType (TLifted typevar) cenv=:{cenvTypeHeap}
	# (varinfo, cenvTypeHeap)			= readPtr typevar.tv_info_ptr cenvTypeHeap
	# cenv								= {cenv & cenvTypeHeap = cenvTypeHeap}
	# (error, varptr)					= convertTypeVarInfo varinfo
	| isError error						= (error, DummyValue, cenv)
	= (OK, CTypeVar varptr, cenv)
convertType TE cenv
	= (OK, CUnTypable, cenv)
convertType other cenv
	= (pushError (X_Internal "Rule 'convertType' does not match.") OK, DummyValue, DummyValue)   

// -------------------------------------------------------------------------------------------------------------------------------------------------
convertTypes :: ![Type] !*ConvertEnv -> (!Error, ![CTypeI], !*ConvertEnv)
// -------------------------------------------------------------------------------------------------------------------------------------------------
convertTypes [] cenv
	= (OK, [], cenv)
convertTypes [type:types] cenv
	# (error, ctype, cenv)				= convertType type cenv
	| isError error						= (error, DummyValue, cenv)
	# (error, ctypes, cenv)				= convertTypes types cenv
	| isError error						= (error, DummyValue, cenv)
	= (OK, [ctype:ctypes], cenv)

// -------------------------------------------------------------------------------------------------------------------------------------------------
convertTypeContext :: !TypeContext !*ConvertEnv -> (!Error, !CClassRestrictionI, !*ConvertEnv)
// -------------------------------------------------------------------------------------------------------------------------------------------------
convertTypeContext tcontext cenv
	# (error, classdef, cenv)			= convertTCClass tcontext.tc_class cenv
	| isError error						= (error, DummyValue, DummyValue)
	# (error, types, cenv)				= convertTypes tcontext.tc_types cenv
	| isError error						= (error, DummyValue, DummyValue)
	= (OK, {ccrClass = classdef, ccrTypes = types}, cenv)

// -------------------------------------------------------------------------------------------------------------------------------------------------
convertTypeContexts :: ![TypeContext] !*ConvertEnv -> (!Error, ![CClassRestrictionI], !*ConvertEnv)
// -------------------------------------------------------------------------------------------------------------------------------------------------
convertTypeContexts [] cenv
	= (OK, [], cenv)
convertTypeContexts [context:contexts] cenv
	# (error, restriction, cenv)		= convertTypeContext context cenv
	| isError error						= (error, DummyValue, cenv)
	# (error, restrictions, cenv)		= convertTypeContexts contexts cenv
	| isError error						= (error, DummyValue, cenv)
	= (OK, [restriction:restrictions], cenv)

// -------------------------------------------------------------------------------------------------------------------------------------------------
convertTypeDefs	:: ![CheckedTypeDef] !*ConvertEnv !*CProject
				-> (!Error, !{!HeapPtr}, ![CAlgTypeDefI], ![CRecordTypeDefI], !*ConvertEnv, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------
convertTypeDefs typedefs cenv prj
	# algheap							= prj.prjAlgTypeHeap
	# recheap							= prj.prjRecordTypeHeap
	# (error, typeptrs, algdefs, recdefs, cenv, algheap, recheap)
										= convert typedefs cenv algheap recheap
	# prj								= {prj & prjAlgTypeHeap = algheap, prjRecordTypeHeap = recheap}
	| isError error						= (error, DummyValue, DummyValue, DummyValue, cenv, prj)
	# typeptrs							= {ptr \\ ptr <- typeptrs}
	= (OK, typeptrs, algdefs, recdefs, cenv, prj)
	where
		convert [typedef:typedefs] cenv algheap recheap
			# (modptr, cenv)							= cenv!cenvIclPtr
			# (error, mb_algdef, mb_recdef, cenv)		= convertTypeDef typedef typedef.td_rhs cenv
			| isError error								= (error, DummyValue, DummyValue, DummyValue, cenv, algheap, recheap)
			| isJust mb_algdef
				# algdef								= fromJust mb_algdef
				# (algptr, algheap)						= newPtr DummyValue algheap
				# (error, typeptrs, algdefs, recdefs, cenv, algheap, recheap)
														= convert typedefs cenv algheap recheap
				| isError error							= (error, DummyValue, DummyValue, DummyValue, cenv, algheap, recheap)
				= (OK, [CAlgTypePtr modptr algptr:typeptrs], [algdef:algdefs], recdefs, cenv, algheap, recheap)
			| isJust mb_recdef
				# recdef								= fromJust mb_recdef
				# (recptr, recheap)						= newPtr DummyValue recheap
				# (error, typeptrs, algdefs, recdefs, cenv, algheap, recheap)
														= convert typedefs cenv algheap recheap
				| isError error							= (error, DummyValue, DummyValue, DummyValue, cenv, algheap, recheap)
				= (OK, [CRecordTypePtr modptr recptr:typeptrs], algdefs, [recdef:recdefs], cenv, algheap, recheap)
			| otherwise
				# (error, typeptrs, algdefs, recdefs, cenv, algheap, recheap)
														= convert typedefs cenv algheap recheap
				| isError error							= (error, DummyValue, DummyValue, DummyValue, cenv, algheap, recheap)
				= (OK, [DummyValue:typeptrs], algdefs, recdefs, cenv, algheap, recheap)
		convert [] cenv algheap recheap
			= (OK, [], [], [], cenv, algheap, recheap)

// -------------------------------------------------------------------------------------------------------------------------------------------------   
convertTypeDef :: !CheckedTypeDef !TypeRhs !*ConvertEnv -> (!Error, !Maybe CAlgTypeDefI, !Maybe CRecordTypeDefI, !*ConvertEnv)
// -------------------------------------------------------------------------------------------------------------------------------------------------   
convertTypeDef type_def (AlgType symbols) cenv
	# vars								= smap (\atypevar -> atypevar.atv_variable) type_def.td_args
	# (varptrs, cenv)					= buildTypeVars vars cenv
	# (constructors, cenv)				= umap (convertDefinedSymbol ConsDef) symbols cenv
	# alg_type_def						=	{ atdName				= type_def.td_ident.id_name
											, atdArity				= type_def.td_arity
											, atdTypeVarScope		= varptrs
											, atdConstructors		= constructors
											}
	= (OK, Just alg_type_def, Nothing, cenv)
convertTypeDef type_def (SynType atype) cenv
	= (OK, Nothing, Nothing, cenv)
convertTypeDef type_def (RecordType rectype) cenv
	# vars								= smap (\atypevar -> atypevar.atv_variable) type_def.td_args
	# (varptrs, cenv)					= buildTypeVars vars cenv
	# (fields, cenv)					= umap convertFieldSymbol [field \\ field <-: rectype.rt_fields] cenv
	# rec_type_def						=	{ rtdName				= type_def.td_ident.id_name
											, rtdArity				= type_def.td_arity
											, rtdTypeVarScope		= varptrs
											, rtdFields				= fields
											, rtdRecordConstructor	= DummyValue
											, rtdIsDictionary		= False
											, rtdClassDef			= DummyValue
											}
	= (OK, Nothing, Just rec_type_def, cenv) 
convertTypeDef type_def rhs cenv
	= (pushError (X_Internal "Rule 'convertTypeDef' does not match") OK, Nothing, Nothing, DummyValue)

// -------------------------------------------------------------------------------------------------------------------------------------------------   
convertTypeSymbIdent :: !TypeSymbIdent !*ConvertEnv -> (!Error, !IndexedPtr, !*ConvertEnv)
// -------------------------------------------------------------------------------------------------------------------------------------------------   
convertTypeSymbIdent tsymbident cenv
	= convertGlobal_Index CheckedTypeDef tsymbident.type_index tsymbident.type_ident.id_name cenv

// -------------------------------------------------------------------------------------------------------------------------------------------------
convertTypeVarInfo :: !TypeVarInfo -> (!Error, !CTypeVarPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
convertTypeVarInfo (TVI_CPSTypeVar cheat)
	= (OK, fromType (toProver cheat))
convertTypeVarInfo other
	= (pushError (X_Internal "Error in convertTypeVarInfo: can not find variable pointer.") OK, nilPtr)

// -------------------------------------------------------------------------------------------------------------------------------------------------
convertUpdates :: !CExprI ![Bind Expression (Global FieldSymbol)] !*ConvertEnv -> (!Error, !CExprI, !*ConvertEnv)
// -------------------------------------------------------------------------------------------------------------------------------------------------
convertUpdates cexpr [bind: binds] cenv
	# expr								= bind.bind_src
	# fieldsymbol						= bind.bind_dst
	| isDummy expr						= convertUpdates cexpr binds cenv
	# (error, expr, cenv)				= convertExpression expr cenv
	| isError error						= (error, DummyValue, cenv)
	# (error, ptr, cenv)				= convertGlobalFieldSymbol fieldsymbol cenv
	| isError error						= (error, DummyValue, cenv)
	# cexpr								= ptr @@# [cexpr, expr]
	= convertUpdates cexpr binds cenv
	where
		isDummy EE						= True
		isDummy (NoBind _)				= True
		isDummy other					= False
convertUpdates cexpr [] cenv
	= (OK, cexpr, cenv)

// -------------------------------------------------------------------------------------------------------------------------------------------------
convertVarInfo :: !VarInfo -> (!Error, !CExprVarPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
convertVarInfo (VI_CPSExprVar cheat)
	= (OK, fromExpr (toProver cheat))
convertVarInfo other
	= (pushError (X_Internal "Error in convertVarInfo: can not find variable id.") OK, nilPtr)

























// -------------------------------------------------------------------------------------------------------------------------------------------------
addStrictness :: !Int ![CTypeI] !StrictnessList -> [CTypeI]
// -------------------------------------------------------------------------------------------------------------------------------------------------
addStrictness index [type:types] strict
	= case (arg_is_strict index strict) of
		True							-> [CStrict type: addStrictness (index+1) types strict]
		False							-> [        type: addStrictness (index+1) types strict]
addStrictness index [] strict
	= []

// =================================================================================================================================================
// The conversion table on the ST is invalid for SelectorDefs: if it is a field of a dictionary and the order of classes in 
// .icl and .dcl is different, the necessary conversion entries are missing.
// This function fills in these gaps, using the conversion table for classes. (which is valid)
// -------------------------------------------------------------------------------------------------------------------------------------------------
adjustConversionTable :: !ConversionTable !FrontEndSyntaxTree -> ConversionTable
// -------------------------------------------------------------------------------------------------------------------------------------------------
adjustConversionTable table tree
	# selector_table					= select table cSelectorDefs
	# class_table						= select table cClassDefs
	# maybe_dcl							= get_dcl 0 (size tree.fe_dcls) tree
	| isNothing maybe_dcl				= table
	# dcl								= fromJust maybe_dcl
	# icl_adjust						= getFirstClassSelector tree.fe_icl.icl_common.com_class_defs tree.fe_icl.icl_common.com_type_defs
	# dcl_first_selector				= getFirstClassSelector         dcl.dcl_common.com_class_defs         dcl.dcl_common.com_type_defs
	#!icl_class_members					= build_icl_class_members 0 [cdef \\ cdef <-: tree.fe_icl.icl_common.com_class_defs]
	#!dcl_class_members					= build_dcl_class_members [dt \\ dt <-: class_table] icl_class_members
	# dcl_class_members					= smap ((+) icl_adjust) (flatten dcl_class_members)
	# start_of_table					= case size selector_table of
											0	-> [index \\ index <- [0..dcl_first_selector-1]]
											_	-> [index \\ index <-: selector_table]
	# selector_table					= {index \\ index <- start_of_table ++ dcl_class_members}
	#!list_table						= [tab \\ tab <-: table]
	# list_table						= (take cSelectorDefs list_table) ++ [selector_table] ++ (drop (cSelectorDefs+1) list_table)
	= {tab \\ tab <- list_table}
	where
		getFirstClassSelector :: !{#ClassDef} !{#CheckedTypeDef} -> Int
		getFirstClassSelector classes types
			| size classes == 0					= 0
			# classdef							= select classes 0
			# dictionary						= select types classdef.class_dictionary.ds_index
			# recordtype						= case dictionary.td_rhs of
													RecordType rectype		-> rectype
													_						-> abort "Found a class with a dictionary which is not a record type."
			| size recordtype.rt_fields == 0	= 0
			# fieldsymbol						= select recordtype.rt_fields 0
			= fieldsymbol.fs_index
	
		get_dcl :: !Int !Int !FrontEndSyntaxTree -> Maybe DclModule
		get_dcl index size tree
			| index >= size								= Nothing
			# the_dcl									= select tree.fe_dcls index
			| the_dcl.dcl_name == tree.fe_icl.icl_name	= Just the_dcl
			= get_dcl (index+1) size tree
		
		build_icl_class_members :: !Int ![ClassDef] -> [[Int]]
		build_icl_class_members start [classdef: classdefs]
			# nr_members								= size classdef.class_members
			# table_entry								= smap ((+) start) [0..nr_members-1]
			= [table_entry: build_icl_class_members (start+nr_members) classdefs]
		build_icl_class_members start []
			= []
		
		build_dcl_class_members :: ![Int] ![[Int]] -> [[Int]]
		build_dcl_class_members [dcl: dcls] icls
			= [icls !! dcl : build_dcl_class_members dcls icls]
		build_dcl_class_members [] icls
			= []

// -------------------------------------------------------------------------------------------------------------------------------------------------
findImportedNames :: !NumberSet !{#DclModule} -> [CName]
// -------------------------------------------------------------------------------------------------------------------------------------------------
findImportedNames set modules
	# nr_modules						= size modules
	# module_numbers					= [0..nr_modules-1]
	# used_module_numbers				= [nr \\ nr <- module_numbers | inNumberSet nr set]
	# used_modules						= [modules.[nr] \\ nr <- used_module_numbers]
	= [dcl.dcl_name.id_name \\ dcl <- used_modules]