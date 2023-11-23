implementation module checktypes

import StdEnv
import syntax, checksupport, check, typesupport, utilities, RWSDebug


::	TypeSymbols = 
	{	ts_type_defs		:: !.{# CheckedTypeDef}
	,	ts_cons_defs 		:: !.{# ConsDef}
	,	ts_selector_defs	:: !.{# SelectorDef}
	,	ts_modules			:: !.{# DclModule}
	}
	
::	TypeInfo =
	{	ti_var_heap			:: !.VarHeap
	,	ti_type_heaps		:: !.TypeHeaps
	}

::	CurrentTypeInfo =
	{	cti_module_index	:: !Index
	,	cti_type_index		:: !Index
	,	cti_lhs_attribute	:: !TypeAttribute
	}

class bindTypes type :: !CurrentTypeInfo !type !(!*TypeSymbols, !*TypeInfo, !*CheckState)
	-> (!type, !TypeAttribute, !(!*TypeSymbols, !*TypeInfo, !*CheckState))

instance bindTypes AType
where
	bindTypes cti atype=:{at_attribute,at_type} ts_ti_cs
		# (at_type, type_attr, (ts, ti, cs)) = bindTypes cti at_type ts_ti_cs
		  (combined_attribute, cs_error) = check_type_attribute at_attribute type_attr cti.cti_lhs_attribute cs.cs_error
		= ({ atype & at_attribute = combined_attribute, at_type = at_type }, combined_attribute, (ts, ti, { cs & cs_error = cs_error }))
	where
		check_type_attribute :: !TypeAttribute !TypeAttribute !TypeAttribute !*ErrorAdmin -> (!TypeAttribute,!*ErrorAdmin)
		check_type_attribute TA_Anonymous type_attr root_attr error
			| try_to_combine_attributes type_attr root_attr
				= (root_attr, error)
				= (TA_Multi, checkError "" "conflicting attribution of type definition" error)
		check_type_attribute TA_Unique type_attr root_attr error
			| try_to_combine_attributes TA_Unique type_attr || try_to_combine_attributes TA_Unique root_attr
				= (TA_Unique, error)
				= (TA_Multi, checkError "" "conflicting attribution of type definition" error)
		check_type_attribute (TA_Var var) _ _ error
			= (TA_Multi, checkError var "attribute variable not allowed" error)
		check_type_attribute (TA_RootVar var) _ _ error
			= (TA_Multi, checkError var "attribute variable not allowed" error)
		check_type_attribute _ type_attr root_attr error
			= (type_attr, error)

		try_to_combine_attributes :: !TypeAttribute !TypeAttribute -> Bool
		try_to_combine_attributes TA_Multi _
			= True
		try_to_combine_attributes (TA_Var attr_var1) (TA_Var attr_var2)
			= attr_var1.av_name == attr_var2.av_name
		try_to_combine_attributes TA_Unique TA_Unique
			= True
		try_to_combine_attributes TA_Unique TA_Multi
			= True
		try_to_combine_attributes _ _
			= False

instance bindTypes TypeVar
where
	bindTypes cti tv=:{tv_name=var_id=:{id_info}} (ts, ti, cs=:{cs_symbol_table /* TD ... */, cs_x={x_type_var_position,x_is_dcl_module} /* ... TD */ })
		# (var_def, cs_symbol_table) = readPtr id_info cs_symbol_table
		  cs = { cs & cs_symbol_table = cs_symbol_table }
		= case var_def.ste_kind of
			STE_BoundTypeVariable bv=:{stv_attribute, stv_info_ptr, stv_count /* TD */, stv_position}
				# cs = { cs & cs_symbol_table = cs.cs_symbol_table <:= (id_info, { var_def & ste_kind = STE_BoundTypeVariable { bv & stv_count = inc stv_count }})}
				-> ({ tv & tv_info_ptr = stv_info_ptr /* TD ... */, tv_name = if x_is_dcl_module tv.tv_name { tv.tv_name & id_name = toString stv_position } /* ... TD */ }, stv_attribute, (ts, ti, cs))
			_
				-> (tv, TA_Multi, (ts, ti, { cs & cs_error = checkError var_id "undefined" cs.cs_error }))

instance bindTypes [a] | bindTypes a
where
	bindTypes cti [] ts_ti_cs
		= ([], TA_Multi, ts_ti_cs)
	bindTypes cti [x : xs] ts_ti_cs
		# (x, _, ts_ti_cs) = bindTypes cti x ts_ti_cs
		  (xs, attr, ts_ti_cs) = bindTypes cti xs ts_ti_cs
		= ([x : xs], attr, ts_ti_cs)
	

instance bindTypes Type
where
	bindTypes cti (TV tv) ts_ti_cs
		# (tv, attr, ts_ti_cs) = bindTypes cti tv ts_ti_cs
		= (TV tv, attr, ts_ti_cs)
	bindTypes cti=:{cti_module_index,cti_type_index,cti_lhs_attribute} type=:(TA type_cons=:{type_name=type_name=:{id_info}} types)
					(ts=:{ts_type_defs,ts_modules}, ti, cs=:{cs_symbol_table})
		# (entry, cs_symbol_table)	= readPtr id_info cs_symbol_table
		  cs = { cs & cs_symbol_table = cs_symbol_table }
		  (type_index, type_module)	= retrieveGlobalDefinition entry STE_Type cti_module_index
		| type_index <> NotFound
			# ({td_arity,td_attribute,td_rhs},type_index,ts_type_defs,ts_modules) = getTypeDef type_index type_module cti_module_index ts_type_defs ts_modules
			  ts = { ts & ts_type_defs = ts_type_defs, ts_modules = ts_modules }
			| checkArityOfType type_cons.type_arity td_arity td_rhs
				# (types, _, ts_ti_cs) = bindTypes cti types (ts, ti, cs)
				| type_module == cti_module_index && cti_type_index == type_index
					= (TA { type_cons & type_index = { glob_object = type_index, glob_module = type_module}} types, cti_lhs_attribute, ts_ti_cs)
					= (TA { type_cons & type_index = { glob_object = type_index, glob_module = type_module}} types,
								determine_type_attribute td_attribute, ts_ti_cs)
				= (type, TA_Multi, (ts, ti, { cs & cs_error = checkError type_cons.type_name " used with wrong arity" cs.cs_error }))
			= (type, TA_Multi, (ts, ti, { cs & cs_error = checkError type_cons.type_name " undefined" cs.cs_error}))
	where
		determine_type_attribute TA_Unique		= TA_Unique
		determine_type_attribute _				= TA_Multi
	
	bindTypes cti (arg_type --> res_type) ts_ti_cs
		# (arg_type, _, ts_ti_cs) = bindTypes cti arg_type ts_ti_cs
		  (res_type, _, ts_ti_cs) = bindTypes cti res_type ts_ti_cs
		= (arg_type --> res_type, TA_Multi, ts_ti_cs)
	bindTypes cti (CV tv :@: types) ts_ti_cs
		# (tv, type_attr, ts_ti_cs) = bindTypes cti tv ts_ti_cs
		  (types, _, ts_ti_cs) = bindTypes cti types ts_ti_cs
		= (CV tv :@: types, type_attr, ts_ti_cs)
	bindTypes cti type ts_ti_cs
		= (type, TA_Multi, ts_ti_cs)
	

addToAttributeEnviron :: !TypeAttribute !TypeAttribute ![AttrInequality] !*ErrorAdmin -> (![AttrInequality],!*ErrorAdmin)
addToAttributeEnviron TA_Multi _ attr_env error
	= (attr_env, error)
addToAttributeEnviron _ TA_Unique attr_env error
	= (attr_env, error)
addToAttributeEnviron (TA_Var attr_var) (TA_Var root_var) attr_env error
	| attr_var.av_info_ptr == root_var.av_info_ptr
		= (attr_env, error)
		= ([ { ai_demanded = attr_var, ai_offered = root_var } :  attr_env], error)
addToAttributeEnviron (TA_RootVar attr_var) root_attr attr_env error
	= (attr_env, error)
addToAttributeEnviron _ _ attr_env error
	= (attr_env, checkError "" "inconsistent attribution of type definition" error)

bindTypesOfConstructors :: !CurrentTypeInfo !Index ![TypeVar] ![AttributeVar] !AType ![DefinedSymbol] !(!*TypeSymbols,!*TypeInfo,!*CheckState)
	-> (!*TypeSymbols, !*TypeInfo, !*CheckState)
bindTypesOfConstructors _ _ _ _ _ [] ts_ti_cs
	= ts_ti_cs
bindTypesOfConstructors cti=:{cti_lhs_attribute} cons_index free_vars free_attrs type_lhs [{ds_index}:conses] (ts=:{ts_cons_defs}, ti=:{ti_type_heaps}, cs)
	# (cons_def, ts_cons_defs) = ts_cons_defs![ds_index]
	# (exi_vars, (ti_type_heaps, cs))
	  		= addExistentionalTypeVariablesToSymbolTable cti_lhs_attribute cons_def.cons_exi_vars ti_type_heaps cs
	  (st_args, cons_arg_vars, st_attr_env, (ts, ti, cs))
	  		= bind_types_of_cons cons_def.cons_type.st_args cti free_vars []
	  				({ ts & ts_cons_defs = ts_cons_defs }, { ti  & ti_type_heaps = ti_type_heaps }, cs)
	  cs_symbol_table = removeAttributedTypeVarsFromSymbolTable cOuterMostLevel exi_vars cs.cs_symbol_table
	  (ts, ti, cs) = bindTypesOfConstructors cti (inc cons_index) free_vars free_attrs type_lhs conses
							(ts, ti, { cs & cs_symbol_table = cs_symbol_table }) 
	  cons_type = { cons_def.cons_type & st_vars = free_vars, st_args = st_args, st_result = type_lhs, st_attr_vars = free_attrs, st_attr_env = st_attr_env }
	  (new_type_ptr, ti_var_heap) = newPtr VI_Empty ti.ti_var_heap
	= ({ ts & ts_cons_defs = { ts.ts_cons_defs & [ds_index] =
			{ cons_def & cons_type = cons_type, cons_index = cons_index, cons_type_index = cti.cti_type_index, cons_exi_vars = exi_vars,
					cons_type_ptr = new_type_ptr, cons_arg_vars = cons_arg_vars }}}, { ti & ti_var_heap = ti_var_heap }, cs)
where
	bind_types_of_cons :: ![AType] !CurrentTypeInfo ![TypeVar] ![AttrInequality] !(!*TypeSymbols, !*TypeInfo, !*CheckState)
		-> !(![AType], ![[ATypeVar]], ![AttrInequality], !(!*TypeSymbols, !*TypeInfo, !*CheckState))
	bind_types_of_cons [] cti free_vars attr_env ts_ti_cs
		= ([], [], attr_env, ts_ti_cs)
	bind_types_of_cons [type : types] cti free_vars attr_env ts_ti_cs
		# (types, local_vars_list, attr_env, ts_ti_cs)
				= bind_types_of_cons types cti free_vars attr_env ts_ti_cs
		  (type, type_attr, (ts, ti, cs)) = bindTypes cti type ts_ti_cs
		  (local_vars, cs_symbol_table /* TD ... */, _ /* ... TD */ ) = foldSt retrieve_local_vars free_vars ([], cs.cs_symbol_table /* TD ...*/, cs.cs_x /* ... TD */ )
		  (attr_env, cs_error) = addToAttributeEnviron type_attr cti.cti_lhs_attribute attr_env cs.cs_error
		= ([type : types], [local_vars : local_vars_list], attr_env, (ts, ti , { cs & cs_symbol_table = cs_symbol_table, cs_error = cs_error }))
	where 
		retrieve_local_vars tv=:{tv_name={id_info}} (local_vars, symbol_table /* TD ... */, cs_x=:{x_is_dcl_module} /* ... TD */ )
			# (ste=:{ste_kind = STE_BoundTypeVariable bv=:{stv_attribute, stv_info_ptr, stv_count /* TD ... */,stv_position  /* ... TD */ }}, symbol_table) = readPtr id_info symbol_table
			| stv_count == 0
				= (local_vars, symbol_table /* TD ... */, cs_x /* ... TD */)
				
				= ([{ atv_variable = { tv & tv_info_ptr = stv_info_ptr /* TD ... */, tv_name = if x_is_dcl_module tv.tv_name { tv.tv_name & id_name = toString stv_position } /* ... TD */ }, atv_attribute = stv_attribute, atv_annotation = AN_None } : local_vars],
						symbol_table <:= (id_info, { ste & ste_kind = STE_BoundTypeVariable { bv & stv_count = 0}})/* TD ... */, cs_x /* ... TD */)
						
//
checkRhsOfTypeDef :: !CheckedTypeDef ![AttributeVar] !CurrentTypeInfo !(!*TypeSymbols, !*TypeInfo, !*CheckState)
	-> (!TypeRhs, !(!*TypeSymbols, !*TypeInfo, !*CheckState))
//
checkRhsOfTypeDef {td_name,td_arity,td_args,td_rhs = td_rhs=:AlgType conses} attr_vars cti=:{cti_module_index,cti_type_index,cti_lhs_attribute} ts_ti_cs
	# type_lhs = { at_annotation = AN_None, at_attribute = cti_lhs_attribute,
			  	   at_type = TA (MakeTypeSymbIdent { glob_object = cti_type_index, glob_module = cti_module_index } td_name td_arity)
								[{at_annotation = AN_None, at_attribute = atv_attribute,at_type = TV atv_variable} \\ {atv_variable, atv_attribute} <- td_args]}
	  ts_ti_cs = bindTypesOfConstructors cti 0 [ atv_variable \\ {atv_variable} <- td_args] attr_vars type_lhs conses ts_ti_cs
	= (td_rhs, ts_ti_cs)
checkRhsOfTypeDef {td_name,td_arity,td_args,td_rhs = td_rhs=:RecordType {rt_constructor=rec_cons=:{ds_index}, rt_fields}}
		attr_vars cti=:{cti_module_index,cti_type_index,cti_lhs_attribute} ts_ti_cs
	# type_lhs = {	at_annotation = AN_None, at_attribute = cti_lhs_attribute,
					at_type = TA (MakeTypeSymbIdent { glob_object = cti_type_index, glob_module = cti_module_index } td_name td_arity)
			[{at_annotation = AN_None, at_attribute = atv_attribute,at_type = TV atv_variable} \\ {atv_variable, atv_attribute} <- td_args]}
	  (ts, ti, cs) = bindTypesOfConstructors cti 0  [ atv_variable \\ {atv_variable} <- td_args]
	  						attr_vars type_lhs [rec_cons] ts_ti_cs
	# (rec_cons_def, ts) = ts!ts_cons_defs.[ds_index]
	# {cons_type = { st_vars,st_args,st_result,st_attr_vars }, cons_exi_vars} = rec_cons_def

	| size rt_fields<>length st_args
		= abort ("checkRhsOfTypeDef "+++rt_fields.[0].fs_name.id_name+++" "+++rec_cons_def.cons_symb.id_name+++toString ds_index)

	# (ts_selector_defs, ti_var_heap, cs_error) = check_selectors 0 rt_fields cti_type_index st_args st_result st_vars st_attr_vars cons_exi_vars
				ts.ts_selector_defs ti.ti_var_heap cs.cs_error
	= (td_rhs, ({ ts & ts_selector_defs = ts_selector_defs }, { ti & ti_var_heap = ti_var_heap }, { cs & cs_error = cs_error}))
where
	check_selectors :: !Index !{# FieldSymbol} !Index ![AType] !AType ![TypeVar] ![AttributeVar] ![ATypeVar] !*{#SelectorDef} !*VarHeap !*ErrorAdmin
		-> (!*{#SelectorDef}, !*VarHeap, !*ErrorAdmin)
	check_selectors field_nr fields rec_type_index sel_types rec_type st_vars st_attr_vars exi_vars selector_defs var_heap error
		| field_nr < size fields
			# {fs_index} = fields.[field_nr]
			# (sel_def, selector_defs) = selector_defs![fs_index]
			# [sel_type:sel_types] = sel_types
			# (st_attr_env, error) = addToAttributeEnviron sel_type.at_attribute rec_type.at_attribute [] error
			# (new_type_ptr, var_heap) = newPtr VI_Empty var_heap
			  sd_type = { sel_def.sd_type &  st_arity = 1, st_args = [rec_type], st_result = sel_type, st_vars = st_vars,
			  				st_attr_vars = st_attr_vars, st_attr_env = st_attr_env }
			  selector_defs = { selector_defs & [fs_index] = { sel_def & sd_type = sd_type, sd_field_nr = field_nr, sd_type_index = rec_type_index,
			  									sd_type_ptr = new_type_ptr, sd_exi_vars = exi_vars  } }
			= check_selectors (inc field_nr) fields rec_type_index sel_types  rec_type st_vars st_attr_vars exi_vars selector_defs var_heap error
			= (selector_defs, var_heap, error)
checkRhsOfTypeDef {td_rhs = SynType type} _ cti ts_ti_cs
	# (type, type_attr, ts_ti_cs) = bindTypes cti type ts_ti_cs
	= (SynType type, ts_ti_cs)
checkRhsOfTypeDef {td_rhs} _ _ ts_ti_cs
	= (td_rhs, ts_ti_cs)

emptyIdent name :== { id_name = name, id_info = nilPtr }

isATopConsVar cv		:== cv < 0
encodeTopConsVar cv		:== dec (~cv)
decodeTopConsVar cv		:== ~(inc cv)

checkTypeDef :: /* TD */ !Bool !Index !Index !*TypeSymbols !*TypeInfo !*CheckState -> (!*TypeSymbols, !*TypeInfo, !*CheckState);
checkTypeDef /* TD */ is_dcl_module type_index module_index ts=:{ts_type_defs} ti=:{ti_type_heaps} cs=:{cs_error}
	# (type_def, ts_type_defs) = ts_type_defs![type_index]
	# {td_name,td_pos,td_args,td_attribute} = type_def
	
	// TD ...
	// in case of an icl-module, the arguments i.e. the type variables of type constructors are normalized which makes
	// comparison by the static linker easier.
	# (cs=:{cs_error})
		= { cs & cs_x = { cs.cs_x & x_is_dcl_module = is_dcl_module, x_type_var_position = 0 } }
// 	| FB (not is_dcl_module)  ("checkTypeDef: " +++ td_name.id_name) True
	#
 	// ... TD
 	
	  position = newPosition td_name td_pos
	  cs_error = pushErrorAdmin position cs_error
	  (td_attribute, attr_vars, th_attrs) = determine_root_attribute td_attribute td_name.id_name ti_type_heaps.th_attrs
	  (type_vars, (attr_vars, ti_type_heaps, cs))
	  		= addTypeVariablesToSymbolTable td_args attr_vars { ti_type_heaps & th_attrs = th_attrs } { cs & cs_error = cs_error }
	  type_def = {	type_def & td_args = type_vars, td_index = type_index, td_attrs = attr_vars, td_attribute = td_attribute }
	  (td_rhs, (ts, ti, cs)) = checkRhsOfTypeDef type_def attr_vars
			{ cti_module_index = module_index, cti_type_index = type_index, cti_lhs_attribute = td_attribute }
				({ ts & ts_type_defs = ts_type_defs },{ ti & ti_type_heaps = ti_type_heaps}, cs)
	= ({ ts & ts_type_defs = { ts.ts_type_defs & [type_index] = { type_def & td_rhs = td_rhs }}}, ti,
				{ cs &	cs_error = popErrorAdmin cs.cs_error,
						cs_symbol_table = removeAttributedTypeVarsFromSymbolTable cOuterMostLevel type_vars cs.cs_symbol_table
	// TD ...
						, cs_x = { cs.cs_x & x_is_dcl_module = False}      })
	// ... TD 
where
	determine_root_attribute TA_None name attr_var_heap
		# (attr_info_ptr, attr_var_heap) = newPtr AVI_Empty attr_var_heap
		  new_var = { av_name = emptyIdent name, av_info_ptr = attr_info_ptr}
		= (TA_Var new_var, [new_var], attr_var_heap)
	determine_root_attribute TA_Unique name attr_var_heap
		= (TA_Unique, [], attr_var_heap)

CS_Checked	:== 1
CS_Checking	:== 0

::	ExpandState =
	{	exp_type_defs	::!.{# CheckedTypeDef}
	,	exp_modules		::!.{# DclModule}
	,	exp_marks		::!.{# Int}
	,	exp_type_heaps	::!.TypeHeaps
	,	exp_error		::!.ErrorAdmin
	}

class expand a :: !Index !a  !*ExpandState -> (!a, !*ExpandState)

expandTypeVariable :: TypeVar !*ExpandState -> (!Type, !*ExpandState)
expandTypeVariable {tv_info_ptr} expst=:{exp_type_heaps}
	# (TVI_Type type, th_vars) = readPtr tv_info_ptr exp_type_heaps.th_vars
	= (type, { expst & exp_type_heaps = { exp_type_heaps & th_vars  = th_vars }})

expandTypeAttribute :: !TypeAttribute !*ExpandState -> (!TypeAttribute, !*ExpandState)
expandTypeAttribute (TA_Var {av_info_ptr}) expst=:{exp_type_heaps}
	# (AVI_Attr attr, th_attrs) = readPtr av_info_ptr exp_type_heaps.th_attrs
	= (attr, { expst & exp_type_heaps = { exp_type_heaps & th_attrs = th_attrs }})
expandTypeAttribute attr expst
	= (attr, expst)

instance expand Type
where
	expand module_index (TV tv) expst
		= expandTypeVariable tv expst
	expand module_index type=:(TA type_cons=:{type_name,type_index={glob_object,glob_module}} types) expst=:{exp_marks,exp_error}
		| module_index == glob_module
			#! mark = exp_marks.[glob_object]
			| mark == CS_NotChecked
				# expst = expandSynType module_index glob_object expst
				  (types, expst) = expand module_index types expst
				= (TA type_cons types,expst)
			| mark == CS_Checked
				# (types, expst) = expand module_index types expst
				= (TA type_cons types, expst)
//			| mark == CS_Checking
				= (type, { expst & exp_error = checkError type_name "cyclic dependency between type synonyms" exp_error })
			# (types, expst) = expand module_index types expst
			= (TA type_cons types, expst)
	expand module_index (arg_type --> res_type) expst
		# (arg_type, expst) = expand module_index arg_type expst
		  (res_type, expst) = expand module_index res_type expst
		= (arg_type --> res_type, expst)
	expand module_index (CV tv :@: types) expst
		# (type, expst) = expandTypeVariable tv expst
		  (types, expst) = expand module_index types expst
		= (simplify_type_appl type types, expst) 
		where
			simplify_type_appl :: !Type ![AType] -> Type
			simplify_type_appl (TA type_cons=:{type_arity} cons_args) type_args
				= TA { type_cons & type_arity = type_arity + length type_args } (cons_args ++ type_args)
			simplify_type_appl (TV tv) type_args
				= CV tv :@: type_args
	expand module_index type expst
		= (type, expst)

instance expand [a] | expand a
where
	expand module_index [x:xs] expst
		# (x, expst) = expand module_index x expst
		  (xs, expst) = expand module_index xs expst
		= ([x:xs], expst)
	expand module_index [] expst
		= ([], expst)

instance expand AType
where
	expand module_index atype=:{at_type,at_attribute} expst
		# (at_attribute, expst) = expandTypeAttribute at_attribute expst
		  (at_type, expst) = expand module_index at_type expst
		= ({ atype & at_type = at_type, at_attribute = at_attribute }, expst)

class look_for_cycles a :: !Index !a !*ExpandState -> *ExpandState

instance look_for_cycles Type
where
	look_for_cycles module_index type=:(TA type_cons=:{type_name,type_index={glob_object,glob_module}} types) expst=:{exp_marks,exp_error}
		| module_index == glob_module
			#! mark = exp_marks.[glob_object]
			| mark == CS_NotChecked
				# expst = expandSynType module_index glob_object expst
				= look_for_cycles module_index types expst
			| mark == CS_Checked
				= look_for_cycles module_index types expst
				= { expst & exp_error = checkError type_name "cyclic dependency between type synonyms" exp_error }
		= look_for_cycles module_index types expst
	look_for_cycles module_index (arg_type --> res_type) expst
		= look_for_cycles module_index res_type (look_for_cycles module_index arg_type expst)
	look_for_cycles module_index (type :@: types) expst
		= look_for_cycles module_index types expst
	look_for_cycles module_index type expst
		= expst
	
instance look_for_cycles [a] | look_for_cycles a
where
	look_for_cycles mod_index l expst
		= foldr (look_for_cycles mod_index) expst l

instance look_for_cycles AType
where
	look_for_cycles mod_index {at_type} expst
		= look_for_cycles mod_index at_type expst

expandSynType ::  !Index !Index !*ExpandState -> *ExpandState
expandSynType mod_index type_index expst=:{exp_type_defs}
	# (type_def, exp_type_defs) = exp_type_defs![type_index]
	  expst = { expst & exp_type_defs = exp_type_defs }
	= case type_def.td_rhs of
		SynType type=:{at_type = TA {type_name,type_index={glob_object,glob_module}} types}
	   		# ({td_args,td_attribute,td_rhs}, _, exp_type_defs, exp_modules) = getTypeDef glob_object glob_module mod_index expst.exp_type_defs expst.exp_modules
	   		  expst = { expst & exp_type_defs = exp_type_defs, exp_modules = exp_modules }
			-> case td_rhs of
				SynType rhs_type
					# exp_type_heaps = bindTypeVarsAndAttributes td_attribute type_def.td_attribute td_args types expst.exp_type_heaps
					  position = newPosition type_def.td_name type_def.td_pos
					  exp_error = pushErrorAdmin position expst.exp_error
	  		  		  exp_marks = { expst.exp_marks & [type_index] = CS_Checking }			  
					  (exp_type, expst) = expand mod_index rhs_type.at_type { expst & exp_marks = exp_marks,
										exp_error = exp_error, exp_type_heaps = exp_type_heaps }
					-> {expst & exp_type_defs = { expst.exp_type_defs & [type_index] = { type_def & td_rhs = SynType { type & at_type = exp_type }}},
						 		exp_marks = { expst.exp_marks & [type_index] = CS_Checked },
						 		exp_type_heaps = clearBindingsOfTypeVarsAndAttributes td_attribute td_args expst.exp_type_heaps,
								exp_error = popErrorAdmin expst.exp_error }

				_
					# exp_marks = { expst.exp_marks & [type_index] = CS_Checking }
					  position = newPosition type_def.td_name type_def.td_pos
	  		  		  expst = look_for_cycles mod_index types { expst & exp_marks = exp_marks, exp_error = pushErrorAdmin position expst.exp_error }
					-> { expst & exp_marks = { expst.exp_marks & [type_index] = CS_Checked }, exp_error = popErrorAdmin expst.exp_error }
		_
			-> { expst &  exp_marks = { expst.exp_marks & [type_index] = CS_Checked }}

instance toString KindInfo
where
	toString (KI_Var ptr) 		= "*" +++ toString (ptrToInt ptr)
	toString (KI_Const) 		= "*"
	toString (KI_Arrow kinds)	= kind_list_to_string kinds
	where
		kind_list_to_string [k] = "* -> *"
		kind_list_to_string [k:ks] = "* -> " +++ kind_list_to_string ks
/*
instance toString TypeKind
where
	toString (KindVar var_num) = "*" +++ toString var_num
	toString (KindConst) = "*"
	toString (KindArrow [k:ks]) = toString k +++ kind_list_to_string ks +++ " -> *"
	where
		kind_list_to_string [] = ""
		kind_list_to_string [k:ks] = " -> " +++ toString k +++ kind_list_to_string ks
*/

checkTypeDefs :: /* TD */ !Bool !Bool !*{# CheckedTypeDef} !Index !*{# ConsDef} !*{# SelectorDef} !*{# DclModule} !*VarHeap !*TypeHeaps !*CheckState
	-> (!*{# CheckedTypeDef}, !*{# ConsDef}, !*{# SelectorDef}, !*{# DclModule}, !*VarHeap, !*TypeHeaps, !*CheckState)
checkTypeDefs /* TD */ is_dcl_module is_main_dcl type_defs module_index  cons_defs selector_defs modules var_heap type_heaps cs
	#! nr_of_types = size type_defs
	#  ts = { ts_type_defs = type_defs, ts_cons_defs = cons_defs, ts_selector_defs = selector_defs, ts_modules = modules }
	   ti = { ti_type_heaps = type_heaps, ti_var_heap = var_heap  }
	= check_type_defs is_main_dcl 0 nr_of_types module_index ts ti cs
where
	check_type_defs is_main_dcl type_index nr_of_types module_index ts ti=:{ti_type_heaps,ti_var_heap} cs
		| type_index == nr_of_types
			= (ts.ts_type_defs, ts.ts_cons_defs, ts.ts_selector_defs, ts.ts_modules, ti_var_heap, ti_type_heaps, cs)
			# (ts, ti, cs) = checkTypeDef /* TD */ is_dcl_module type_index module_index ts ti cs
			= check_type_defs is_main_dcl (inc type_index) nr_of_types module_index ts ti cs

expand_syn_types module_index type_index nr_of_types expst
	| type_index == nr_of_types
		= expst
	| expst.exp_marks.[type_index] == CS_NotChecked
		# expst = expandSynType module_index type_index expst
		= expand_syn_types module_index (inc type_index) nr_of_types expst
		= expand_syn_types module_index (inc type_index) nr_of_types expst

expandSynonymTypes :: !.Index !*{#CheckedTypeDef} !*{#.DclModule} !*TypeHeaps !*ErrorAdmin
	-> (!.{#CheckedTypeDef},!.{#DclModule},!.TypeHeaps,!.ErrorAdmin)
expandSynonymTypes module_index exp_type_defs exp_modules exp_type_heaps exp_error
	#! nr_of_types
			= size exp_type_defs
	# marks 
			= createArray nr_of_types CS_NotChecked
	  {exp_type_defs,exp_modules,exp_type_heaps,exp_error}
			= expand_syn_types module_index 0 nr_of_types
			  		{	exp_type_defs = exp_type_defs, exp_modules = exp_modules, exp_marks = marks,
			  			exp_type_heaps = exp_type_heaps, exp_error = exp_error }
	= (exp_type_defs,exp_modules,exp_type_heaps,exp_error)
	
::	OpenTypeInfo =
	{	oti_heaps		:: !.TypeHeaps
	,	oti_all_vars	:: ![TypeVar]
	,	oti_all_attrs	:: ![AttributeVar]
	,	oti_global_vars	:: ![TypeVar]
	}

::	OpenTypeSymbols =
	{	ots_type_defs	:: .{# CheckedTypeDef}
	,	ots_modules		:: .{# DclModule}
	}

determineAttributeVariable attr_var=:{av_name=attr_name=:{id_info}} oti=:{oti_heaps,oti_all_attrs} symbol_table
	# (entry=:{ste_kind,ste_def_level}, symbol_table) = readPtr id_info symbol_table
	| ste_kind == STE_Empty || ste_def_level == cModuleScope
		#! (new_attr_ptr, th_attrs) = newPtr AVI_Empty oti_heaps.th_attrs
		# symbol_table = symbol_table <:= (id_info,{	ste_index = NoIndex, ste_kind = STE_TypeAttribute new_attr_ptr,
														ste_def_level = cGlobalScope, ste_previous = entry })
		  new_attr = { attr_var & av_info_ptr = new_attr_ptr}
		= (new_attr, { oti & oti_heaps = { oti_heaps & th_attrs = th_attrs }, oti_all_attrs = [new_attr : oti_all_attrs] }, symbol_table)
		# (STE_TypeAttribute attr_ptr) = ste_kind
		= ({ attr_var & av_info_ptr = attr_ptr}, oti, symbol_table)

::	DemandedAttributeKind = DAK_Ignore | DAK_Unique | DAK_None

newAttribute :: !DemandedAttributeKind {#Char} TypeAttribute !*OpenTypeInfo !*CheckState -> (!TypeAttribute, !*OpenTypeInfo, !*CheckState)
newAttribute DAK_Ignore var_name _ oti cs
	= (TA_Multi, oti, cs)
newAttribute DAK_Unique var_name new_attr  oti cs
	= case new_attr of
		TA_Unique
			-> (TA_Unique, oti, cs)
		TA_Multi
			-> (TA_Unique, oti, cs)
		TA_None
			-> (TA_Unique, oti, cs)
		_
			-> (TA_Unique, oti, { cs & cs_error = checkError var_name "inconsistently attributed" cs.cs_error })
newAttribute DAK_None var_name (TA_Var attr_var) oti cs=:{cs_symbol_table}
	# (attr_var, oti, cs_symbol_table) = determineAttributeVariable attr_var oti cs_symbol_table
	= (TA_Var attr_var, oti, { cs & cs_symbol_table = cs_symbol_table })
newAttribute DAK_None var_name TA_Anonymous oti=:{oti_heaps, oti_all_attrs} cs
	# (new_attr_ptr, th_attrs) = newPtr AVI_Empty oti_heaps.th_attrs
	  new_attr = { av_info_ptr = new_attr_ptr, av_name = emptyIdent var_name }
	= (TA_Var new_attr, { oti & oti_heaps = { oti_heaps & th_attrs = th_attrs }, oti_all_attrs = [new_attr : oti_all_attrs] }, cs)
newAttribute DAK_None var_name TA_Unique oti cs
	= (TA_Unique, oti, cs)
newAttribute DAK_None var_name attr oti cs
	= (TA_Multi, oti, cs)
			

getTypeDef :: !Index !Index !Index !u:{# CheckedTypeDef} !v:{# DclModule} -> (!CheckedTypeDef, !Index , !u:{# CheckedTypeDef}, !v:{# DclModule})
getTypeDef type_index type_module module_index type_defs modules
	| type_module == module_index
		# (type_def, type_defs) = type_defs![type_index]
		= (type_def, type_index, type_defs, modules)
		# ({dcl_common={com_type_defs},dcl_conversions}, modules) = modules![type_module]
		  type_def = com_type_defs.[type_index]
		  type_index = convertIndex type_index (toInt STE_Type) dcl_conversions
		= (type_def, type_index, type_defs, modules)

checkArityOfType act_arity form_arity (SynType _)
	= form_arity == act_arity
checkArityOfType act_arity form_arity _
	= form_arity >= act_arity

getClassDef :: !Index !Index !Index !u:{# ClassDef} !v:{# DclModule} -> (!ClassDef, !Index , !u:{# ClassDef}, !v:{# DclModule})
getClassDef class_index type_module module_index class_defs modules
	| type_module == module_index
		#! si = size class_defs
		# (class_def, class_defs) = class_defs![class_index]
		= (class_def, class_index, class_defs, modules)
		# ({dcl_common={com_class_defs},dcl_conversions}, modules) = modules![type_module]
		  class_def = com_class_defs.[class_index]
		  class_index = convertIndex class_index (toInt STE_Class) dcl_conversions
		= (class_def, class_index, class_defs, modules)


checkTypeVar :: !Level !DemandedAttributeKind !TypeVar !TypeAttribute !(!*OpenTypeInfo, !*CheckState)
					-> (! TypeVar, !TypeAttribute, !(!*OpenTypeInfo, !*CheckState))
checkTypeVar scope dem_attr tv=:{tv_name=var_name=:{id_name,id_info}} tv_attr (oti, cs=:{cs_symbol_table})
	# (entry=:{ste_kind,ste_def_level},cs_symbol_table) = readPtr id_info cs_symbol_table
	| ste_kind == STE_Empty || ste_def_level == cModuleScope
		# (new_attr, oti=:{oti_heaps,oti_all_vars}, cs) = newAttribute dem_attr id_name tv_attr oti { cs & cs_symbol_table = cs_symbol_table }
		  (new_var_ptr, th_vars) = newPtr (TVI_Attribute new_attr) oti_heaps.th_vars
		  new_var = { tv & tv_info_ptr = new_var_ptr }
		= (new_var, new_attr, ({ oti & oti_heaps = { oti_heaps & th_vars = th_vars }, oti_all_vars = [new_var : oti_all_vars]},
				{ cs & cs_symbol_table = cs.cs_symbol_table <:= (id_info, {ste_index = NoIndex, ste_kind = STE_TypeVariable new_var_ptr,
								ste_def_level = scope, ste_previous = entry })}))
		# (STE_TypeVariable tv_info_ptr) = ste_kind
		  {oti_heaps} = oti
		  (var_info, th_vars) = readPtr tv_info_ptr oti_heaps.th_vars
		  (var_attr, oti, cs) = check_attribute id_name dem_attr var_info tv_attr { oti & oti_heaps = { oti_heaps & th_vars = th_vars }}
		  								{ cs & cs_symbol_table = cs_symbol_table }
		= ({ tv & tv_info_ptr = tv_info_ptr }, var_attr, (oti, cs))
where
	check_attribute var_name DAK_Ignore (TVI_Attribute prev_attr) this_attr oti cs=:{cs_error}
		= (TA_Multi, oti, cs)
	check_attribute var_name dem_attr (TVI_Attribute prev_attr) this_attr oti cs=:{cs_error}
		# (new_attr, cs_error) = determine_attribute var_name dem_attr this_attr cs_error
		= check_var_attribute prev_attr new_attr oti { cs & cs_error = cs_error }
	where					
		check_var_attribute (TA_Var old_var) (TA_Var new_var) oti cs=:{cs_symbol_table,cs_error}
			# (new_var, oti, cs_symbol_table) = determineAttributeVariable new_var oti cs_symbol_table
			| old_var.av_info_ptr == new_var.av_info_ptr
				= (TA_Var old_var, oti, { cs &  cs_symbol_table = cs_symbol_table })
				= (TA_Var old_var, oti, { cs &  cs_symbol_table = cs_symbol_table,
						cs_error = checkError new_var.av_name "inconsistently attributed" cs_error })
		check_var_attribute var_attr=:(TA_Var old_var) TA_Anonymous oti cs
			= (var_attr, oti, cs)
		check_var_attribute TA_Unique new_attr oti cs
			= case new_attr of
				TA_Unique
					-> (TA_Unique, oti, cs)
				_
					-> (TA_Unique, oti, { cs & cs_error = checkError var_name "inconsistently attributed" cs.cs_error })
		check_var_attribute TA_Multi new_attr oti cs
			= case new_attr of
				TA_Multi
					-> (TA_Multi, oti, cs)
				TA_None
					-> (TA_Multi, oti, cs)
				_
					-> (TA_Multi, oti, { cs & cs_error = checkError var_name "inconsistently attributed" cs.cs_error })
		check_var_attribute var_attr new_attr oti cs
			= (var_attr, oti, { cs & cs_error = checkError var_name "inconsistently attributed" cs.cs_error })// ---> (var_attr, new_attr)
		
		
		determine_attribute var_name DAK_Unique new_attr error
			= case new_attr of
				 TA_Multi
				 	-> (TA_Unique, error)
				 TA_None
				 	-> (TA_Unique, error)
				 TA_Unique
				 	-> (TA_Unique, error)
				 _
				 	-> (TA_Unique, checkError var_name "inconsistently attributed" error)
		determine_attribute var_name dem_attr TA_None error
			= (TA_Multi, error)
		determine_attribute var_name dem_attr new_attr error
			= (new_attr, error)

	check_attribute var_name dem_attr _ this_attr oti cs
		= (TA_Multi, oti, cs)

checkOpenAType :: !Index !Int !DemandedAttributeKind !AType !(!u:OpenTypeSymbols, !*OpenTypeInfo, !*CheckState)
	-> (!AType, !(!u:OpenTypeSymbols, !*OpenTypeInfo, !*CheckState))
checkOpenAType mod_index scope dem_attr type=:{at_type = TV tv, at_attribute} (ots, oti, cs)
	# (tv, at_attribute, (oti, cs)) = checkTypeVar scope dem_attr tv at_attribute (oti, cs)
	= ({ type & at_type = TV tv, at_attribute = at_attribute }, (ots, oti, cs))
checkOpenAType mod_index scope dem_attr type=:{at_type = GTV var_id=:{tv_name={id_info}}} (ots, oti=:{oti_heaps,oti_global_vars}, cs=:{cs_symbol_table})
	# (entry, cs_symbol_table) = readPtr id_info cs_symbol_table
	  (type_var, oti_global_vars, th_vars, entry) = retrieve_global_variable var_id entry oti_global_vars oti_heaps.th_vars
	= ({type & at_type = TV type_var, at_attribute = TA_Multi }, (ots, { oti & oti_heaps = { oti_heaps & th_vars = th_vars }, oti_global_vars = oti_global_vars },
								{ cs & cs_symbol_table = cs_symbol_table <:= (id_info, entry) }))
where
	retrieve_global_variable var entry=:{ste_kind = STE_Empty} global_vars var_heap
		# (new_var_ptr, var_heap) = newPtr TVI_Used var_heap
		  var = { var & tv_info_ptr = new_var_ptr }
		= (var, [var : global_vars], var_heap, 
				{ entry  & ste_kind = STE_TypeVariable new_var_ptr, ste_def_level = cModuleScope, ste_previous = entry }) 
	retrieve_global_variable var entry=:{ste_kind,ste_def_level, ste_previous} global_vars var_heap
		| ste_def_level == cModuleScope
			= case ste_kind of
				STE_TypeVariable glob_info_ptr
					# var = { var & tv_info_ptr = glob_info_ptr }
					  (var_info, var_heap) = readPtr glob_info_ptr var_heap
					-> case var_info of
						TVI_Empty
							-> (var, [var : global_vars], var_heap <:= (glob_info_ptr, TVI_Used), entry)
						TVI_Used
							-> (var, global_vars, var_heap, entry)
			# (var, global_vars, var_heap, ste_previous) = retrieve_global_variable var ste_previous global_vars var_heap
			= (var, global_vars, var_heap, { entry & ste_previous = ste_previous })
//
checkOpenAType mod_index scope dem_attr type=:{ at_type=TA type_cons=:{type_name=type_name=:{id_name,id_info}} types, at_attribute}
		(ots=:{ots_type_defs,ots_modules}, oti, cs=:{cs_symbol_table})
	# (entry, cs_symbol_table) = readPtr id_info cs_symbol_table
	  cs = { cs & cs_symbol_table = cs_symbol_table }
	  (type_index, type_module) = retrieveGlobalDefinition entry STE_Type mod_index
	| type_index <> NotFound
		# ({td_arity,td_args,td_attribute,td_rhs},type_index,ots_type_defs,ots_modules) = getTypeDef type_index type_module mod_index ots_type_defs ots_modules
		  ots = { ots & ots_type_defs = ots_type_defs, ots_modules = ots_modules }
		| checkArityOfType type_cons.type_arity td_arity td_rhs
			# type_cons = { type_cons & type_index = { glob_object = type_index, glob_module = type_module }}
			  (types, (ots, oti, cs)) = check_args_of_type_cons mod_index scope /* dem_attr */ types td_args (ots, oti, cs)
			  (new_attr, oti, cs) = newAttribute (new_demanded_attribute dem_attr td_attribute) id_name at_attribute oti cs
			= ({ type & at_type = TA type_cons types, at_attribute = new_attr } , (ots, oti, cs)) 
			= (type, (ots, oti, {cs & cs_error = checkError type_name "used with wrong arity" cs.cs_error}))
		= (type, (ots, oti, {cs & cs_error = checkError type_name "undefined" cs.cs_error}))
where
	check_args_of_type_cons :: !Index !Int ![AType] ![ATypeVar] !(!u:OpenTypeSymbols, !*OpenTypeInfo, !*CheckState)
		-> (![AType], !(!u:OpenTypeSymbols, !*OpenTypeInfo, !*CheckState))
	check_args_of_type_cons mod_index scope [] _ cot_state
		= ([], cot_state)
	check_args_of_type_cons mod_index scope [arg_type : arg_types] [ {atv_attribute} : td_args ] cot_state
		# (arg_type, cot_state) = checkOpenAType mod_index scope (new_demanded_attribute DAK_None atv_attribute) arg_type cot_state
		  (arg_types, cot_state) = check_args_of_type_cons mod_index scope arg_types td_args cot_state
		= ([arg_type : arg_types], cot_state)

	new_demanded_attribute DAK_Ignore _
		= DAK_Ignore
	new_demanded_attribute _ TA_Unique
		= DAK_Unique
	new_demanded_attribute dem_attr _
		= dem_attr

checkOpenAType mod_index scope dem_attr type=:{at_type = arg_type --> result_type, at_attribute} cot_state
	# (arg_type, cot_state) = checkOpenAType mod_index scope DAK_None arg_type cot_state
	  (result_type, (ots, oti, cs)) = checkOpenAType mod_index scope DAK_None result_type cot_state
	  (new_attr, oti, cs) = newAttribute dem_attr "-->" at_attribute oti cs
	= ({ type & at_type = arg_type --> result_type, at_attribute = new_attr }, (ots, oti, cs))
checkOpenAType mod_index scope dem_attr type=:{at_type = CV tv :@: types, at_attribute} (ots, oti, cs)
	# (cons_var, _, (oti, cs)) =  checkTypeVar scope DAK_None tv TA_Multi (oti, cs)
	  (types, (ots, oti, cs)) = mapSt (checkOpenAType mod_index scope DAK_None) types (ots, oti, cs)
	  (new_attr, oti, cs) = newAttribute dem_attr ":@:" at_attribute oti cs
	= ({ type & at_type = CV cons_var :@: types, at_attribute = new_attr }, (ots, oti, cs))
checkOpenAType mod_index scope dem_attr type=:{at_attribute} (ots, oti, cs)
	# (new_attr, oti, cs) = newAttribute dem_attr "." at_attribute oti cs
	= ({ type & at_attribute = new_attr}, (ots, oti, cs))

checkOpenTypes mod_index scope dem_attr types cot_state
	= mapSt (checkOpenType mod_index scope dem_attr) types cot_state

checkOpenType mod_index scope dem_attr type cot_state
	# ({at_type}, cot_state) = checkOpenAType mod_index scope dem_attr { at_type = type, at_attribute = TA_Multi, at_annotation = AN_None } cot_state
	= (at_type, cot_state)
	
checkOpenATypes mod_index scope types cot_state
	= mapSt (checkOpenAType mod_index scope DAK_None) types cot_state

checkInstanceType :: !Index !(Global DefinedSymbol) !InstanceType !Specials !u:{# CheckedTypeDef} !v:{# ClassDef} !u:{# DclModule} !*TypeHeaps !*CheckState
	-> (!InstanceType, !Specials, !u:{# CheckedTypeDef}, !v:{# ClassDef}, !u:{# DclModule}, !*TypeHeaps, !*CheckState)
checkInstanceType mod_index ins_class it=:{it_types,it_context} specials type_defs class_defs modules heaps cs
	# cs_error
			= check_fully_polymorphity it_types it_context cs.cs_error
	  ots = { ots_type_defs = type_defs, ots_modules = modules }
	  oti = { oti_heaps = heaps, oti_all_vars = [], oti_all_attrs = [], oti_global_vars= [] }
	  (it_types, (ots, {oti_heaps,oti_all_vars,oti_all_attrs}, cs)) = checkOpenTypes mod_index cGlobalScope DAK_None it_types (ots, oti, { cs & cs_error = cs_error })
	  (it_context, type_defs, class_defs, modules, heaps, cs) = checkTypeContexts it_context mod_index ots.ots_type_defs class_defs ots.ots_modules oti_heaps cs
	  cs_error
	  		= foldSt (compare_context_and_instance_types ins_class it_types) it_context cs.cs_error
	  (specials, cs) = checkSpecialTypeVars specials { cs & cs_error = cs_error }
	  cs_symbol_table = removeVariablesFromSymbolTable cGlobalScope oti_all_vars cs.cs_symbol_table
	  cs_symbol_table = removeAttributesFromSymbolTable oti_all_attrs cs_symbol_table
	  (specials, type_defs, modules, heaps, cs) = checkSpecialTypes mod_index specials type_defs modules heaps { cs & cs_symbol_table = cs_symbol_table }
	= ({it & it_vars = oti_all_vars, it_types = it_types, it_attr_vars = oti_all_attrs, it_context = it_context },
	    	specials, type_defs, class_defs, modules, heaps, cs)
  where
	check_fully_polymorphity it_types it_context cs_error
		| all is_type_var it_types && not (isEmpty it_context)
			= checkError "" "context restriction not allowed for fully polymorph instance" cs_error
		= cs_error
	  where
		is_type_var (TV _) = True
		is_type_var _ = False

	compare_context_and_instance_types ins_class it_types {tc_class, tc_types} cs_error
		| ins_class<>tc_class
			= cs_error
		# are_equal
				= fold2St compare_context_and_instance_type it_types tc_types True
		| are_equal
			= checkError ins_class.glob_object.ds_ident "context restriction equals instance type" cs_error
		= cs_error
	  where
		compare_context_and_instance_type (TA {type_index=ti1} _) (TA {type_index=ti2} _) are_equal_accu
			= ti1==ti2 && are_equal_accu
		compare_context_and_instance_type (_ --> _) (_ --> _) are_equal_accu
			= are_equal_accu
		compare_context_and_instance_type (CV tv1 :@: _) (CV tv2 :@: _) are_equal_accu
			= tv1==tv2 && are_equal_accu
		compare_context_and_instance_type (TB bt1) (TB bt2) are_equal_accu
			= bt1==bt2 && are_equal_accu
		compare_context_and_instance_type (TV tv1) (TV tv2) are_equal_accu
			= tv1==tv2 && are_equal_accu
		compare_context_and_instance_type _ _ are_equal_accu
			= False


checkSymbolType :: !Index !SymbolType !Specials !u:{# CheckedTypeDef} !v:{# ClassDef} !u:{# DclModule} !*TypeHeaps !*CheckState
	-> (!SymbolType, !Specials, !u:{# CheckedTypeDef}, !v:{# ClassDef}, !u:{# DclModule}, !*TypeHeaps, !*CheckState)
checkSymbolType  mod_index st=:{st_args,st_result,st_context,st_attr_env} specials type_defs class_defs modules heaps cs
	# ots = { ots_type_defs = type_defs, ots_modules = modules }
	  oti = { oti_heaps = heaps, oti_all_vars = [], oti_all_attrs = [], oti_global_vars= [] }
	  (st_args, cot_state) = checkOpenATypes mod_index cGlobalScope st_args (ots, oti, cs)
	  (st_result, (ots, {oti_heaps,oti_all_vars,oti_all_attrs}, cs)) = checkOpenAType mod_index cGlobalScope DAK_None st_result cot_state
	  (st_context, type_defs, class_defs, modules, heaps, cs) = checkTypeContexts st_context mod_index ots.ots_type_defs class_defs ots.ots_modules oti_heaps cs
	  (st_attr_env, cs) = check_attr_inequalities st_attr_env cs
	  (specials, cs) = checkSpecialTypeVars specials cs 
	  cs_symbol_table = removeVariablesFromSymbolTable cGlobalScope oti_all_vars cs.cs_symbol_table
	  cs_symbol_table = removeAttributesFromSymbolTable oti_all_attrs cs_symbol_table
	  (specials, type_defs, modules, heaps, cs) = checkSpecialTypes mod_index specials type_defs modules heaps { cs & cs_symbol_table = cs_symbol_table }
	  checked_st = {st & st_vars = oti_all_vars, st_args = st_args, st_result = st_result, st_context = st_context,
	    					st_attr_vars = oti_all_attrs, st_attr_env = st_attr_env }
	= (checked_st, specials, type_defs, class_defs, modules, heaps, cs)
		//  ---> ("checkSymbolType", st, checked_st)
where
	check_attr_inequalities [ineq : ineqs] cs
		# (ineq, cs) = check_attr_inequality ineq cs
		  (ineqs, cs) = check_attr_inequalities ineqs cs
		= ([ineq : ineqs], cs)
	check_attr_inequalities [] cs
		= ([], cs)

	check_attr_inequality ineq=:{ai_demanded=ai_demanded=:{av_name=dem_name},ai_offered=ai_offered=:{av_name=off_name}} cs=:{cs_symbol_table,cs_error}
		# (dem_entry, cs_symbol_table) = readPtr dem_name.id_info cs_symbol_table
		# (found_dem_attr, dem_attr_ptr) = retrieve_attribute dem_entry
		| found_dem_attr
		   	# (off_entry, cs_symbol_table) = readPtr off_name.id_info cs_symbol_table
			# (found_off_attr, off_attr_ptr) = retrieve_attribute off_entry
			| found_off_attr
				= ({ai_demanded = { ai_demanded & av_info_ptr = dem_attr_ptr }, ai_offered = { ai_offered & av_info_ptr = off_attr_ptr }},
						{ cs & cs_symbol_table = cs_symbol_table })
				= (ineq, { cs & cs_error = checkError off_name "attribute variable undefined" cs_error, cs_symbol_table = cs_symbol_table })
			= (ineq, { cs & cs_error = checkError dem_name "attribute variable undefined" cs_error, cs_symbol_table = cs_symbol_table })

	retrieve_attribute {ste_kind = STE_TypeAttribute attr_ptr, ste_def_level, ste_index}
		| ste_def_level == cGlobalScope
			= (True, attr_ptr)
	retrieve_attribute entry
		= (False, abort "no attribute")

checkTypeContexts :: ![TypeContext] !Index !u:{# CheckedTypeDef} !v:{# ClassDef} !u:{# DclModule} !*TypeHeaps !*CheckState
	-> (![TypeContext], !u:{#CheckedTypeDef}, !v:{# ClassDef}, !u:{# DclModule}, !*TypeHeaps, !*CheckState)
checkTypeContexts [tc : tcs] mod_index type_defs class_defs modules heaps cs
	# (tc, type_defs, class_defs, modules, heaps, cs) = check_type_context tc mod_index type_defs class_defs modules heaps cs
	  (tcs, type_defs, class_defs, modules, heaps, cs) =  checkTypeContexts tcs mod_index type_defs class_defs modules heaps cs
	= ([tc : tcs], type_defs, class_defs, modules, heaps, cs)
where

	check_type_context :: !TypeContext !Index v:{#CheckedTypeDef} !x:{#ClassDef} !u:{#.DclModule} !*TypeHeaps !*CheckState
		-> (!TypeContext,!z:{#CheckedTypeDef},!x:{#ClassDef},!w:{#DclModule},!*TypeHeaps,!*CheckState), [u v <= w, v u <= z]
	check_type_context tc=:{tc_class=tc_class=:{glob_object=class_name=:{ds_ident=ds_ident=:{id_name,id_info},ds_arity}},tc_types}
		mod_index type_defs class_defs modules heaps cs=:{cs_symbol_table, cs_predef_symbols}
		# (entry, cs_symbol_table) = readPtr id_info cs_symbol_table
		  cs = { cs & cs_symbol_table = cs_symbol_table }
		# (class_index, class_module) = retrieveGlobalDefinition entry STE_Class mod_index
		| class_index <> NotFound
			# (class_def, class_index, class_defs, modules) = getClassDef class_index class_module mod_index class_defs modules
			  ots = { ots_modules = modules, ots_type_defs = type_defs }
			  oti = { oti_heaps = heaps, oti_all_vars = [], oti_all_attrs = [], oti_global_vars = [] }
			  (tc_types, (ots, {oti_all_vars,oti_all_attrs,oti_heaps}, cs)) = checkOpenTypes mod_index cGlobalScope DAK_Ignore tc_types (ots, oti, cs)
			  cs = check_context_types 	class_def.class_name tc_types cs
			  cs = foldr (\ {tv_name} cs=:{cs_symbol_table,cs_error} -> 
						 { cs & cs_symbol_table =  removeDefinitionFromSymbolTable cGlobalScope tv_name cs_symbol_table,
						   cs_error = checkError tv_name " undefined" cs_error}) cs oti_all_vars 
			  cs = foldr (\ {av_name} cs=:{cs_symbol_table,cs_error} -> 
						 { cs & cs_symbol_table =  removeDefinitionFromSymbolTable cGlobalScope av_name cs_symbol_table,
						   cs_error = checkError av_name " undefined" cs_error}) cs oti_all_attrs 
			  tc = { tc & tc_class = { tc_class & glob_object = { class_name & ds_index = class_index }, glob_module = class_module }, tc_types = tc_types}
			| class_def.class_arity == ds_arity
				= (tc, ots.ots_type_defs, class_defs, ots.ots_modules, oti_heaps, cs)
				= (tc, ots.ots_type_defs, class_defs, ots.ots_modules, oti_heaps, {  cs & cs_error = checkError id_name "used with wrong arity" cs.cs_error })
			= (tc, type_defs, class_defs, modules, heaps, { cs & cs_error = checkError id_name "undefined" cs.cs_error })
	
	check_context_types tc_class [] cs=:{cs_error}
		= { cs & cs_error = checkError tc_class " type context should contain one or more type variables" cs_error}
	check_context_types tc_class [TV _ : types] cs
		= cs
	check_context_types tc_class [type : types] cs
		= check_context_types tc_class types cs

checkTypeContexts [] _ type_defs class_defs modules heaps cs
	= ([], type_defs, class_defs, modules, heaps, cs)

checkDynamicTypes :: !Index ![ExprInfoPtr] !(Optional SymbolType) !u:{# CheckedTypeDef} !u:{# DclModule} !*TypeHeaps !*ExpressionHeap !*CheckState
	-> (!u:{# CheckedTypeDef}, !u:{# DclModule}, !*TypeHeaps, !*ExpressionHeap, !*CheckState)
checkDynamicTypes mod_index dyn_type_ptrs No type_defs modules type_heaps expr_heap cs
	# (type_defs, modules, heaps, expr_heap, cs) = checkDynamics mod_index (inc cModuleScope) dyn_type_ptrs type_defs modules type_heaps expr_heap cs
	  (expr_heap, cs_symbol_table) = remove_global_type_variables_in_dynamics dyn_type_ptrs (expr_heap, cs.cs_symbol_table)
	= (type_defs, modules, heaps, expr_heap, { cs & cs_symbol_table = cs_symbol_table })
where
	remove_global_type_variables_in_dynamics dyn_info_ptrs expr_heap_and_symbol_table
		= foldSt remove_global_type_variables_in_dynamic dyn_info_ptrs expr_heap_and_symbol_table
	where
		remove_global_type_variables_in_dynamic dyn_info_ptr (expr_heap, symbol_table)
			# (dyn_info, expr_heap) = readPtr dyn_info_ptr expr_heap
			= case dyn_info of
				EI_Dynamic (Yes {dt_global_vars})
					-> (expr_heap, remove_global_type_variables dt_global_vars symbol_table)
				EI_Dynamic No
					-> (expr_heap, symbol_table)
				EI_DynamicTypeWithVars loc_type_vars {dt_global_vars} loc_dynamics
					-> remove_global_type_variables_in_dynamics loc_dynamics (expr_heap, remove_global_type_variables dt_global_vars symbol_table)
						
	
		remove_global_type_variables global_vars symbol_table
			= foldSt remove_global_type_variable global_vars symbol_table
		where		
			remove_global_type_variable {tv_name=tv_name=:{id_info}} symbol_table
				# (entry, symbol_table) = readPtr id_info symbol_table
				| entry.ste_kind == STE_Empty
					= symbol_table
					= symbol_table <:= (id_info, entry.ste_previous)
							 
checkDynamicTypes mod_index dyn_type_ptrs (Yes {st_vars}) type_defs modules type_heaps expr_heap cs=:{cs_symbol_table}
	# (th_vars, cs_symbol_table) = foldSt add_type_variable_to_symbol_table st_vars (type_heaps.th_vars, cs_symbol_table)
	  (type_defs, modules, heaps, expr_heap, cs) = checkDynamics mod_index (inc cModuleScope) dyn_type_ptrs type_defs modules
	  		{ type_heaps & th_vars = th_vars } expr_heap { cs & cs_symbol_table = cs_symbol_table }
	  cs_symbol_table =	removeVariablesFromSymbolTable cModuleScope st_vars cs.cs_symbol_table
	  (expr_heap, cs) = check_global_type_variables_in_dynamics dyn_type_ptrs (expr_heap, { cs & cs_symbol_table = cs_symbol_table })
	= (type_defs, modules, heaps, expr_heap, cs) 
where
	add_type_variable_to_symbol_table {tv_name={id_info},tv_info_ptr} (var_heap,symbol_table)
		# (entry, symbol_table) = readPtr id_info symbol_table
		= (	var_heap <:= (tv_info_ptr, TVI_Empty),
			symbol_table <:= (id_info, {ste_index = NoIndex, ste_kind = STE_TypeVariable tv_info_ptr,
									ste_def_level = cModuleScope, ste_previous = entry }))

	check_global_type_variables_in_dynamics dyn_info_ptrs expr_heap_and_cs
		= foldSt check_global_type_variables_in_dynamic dyn_info_ptrs expr_heap_and_cs
	where
		check_global_type_variables_in_dynamic dyn_info_ptr (expr_heap, cs)
			# (dyn_info, expr_heap) = readPtr dyn_info_ptr expr_heap
			= case dyn_info of
				EI_Dynamic (Yes {dt_global_vars})
					-> (expr_heap, check_global_type_variables dt_global_vars cs)
				EI_Dynamic No
					-> (expr_heap, cs)
				EI_DynamicTypeWithVars loc_type_vars {dt_global_vars} loc_dynamics
					-> check_global_type_variables_in_dynamics loc_dynamics (expr_heap, check_global_type_variables dt_global_vars cs)
						
	
		check_global_type_variables global_vars cs
			= foldSt check_global_type_variable global_vars cs
		where		
			check_global_type_variable {tv_name=tv_name=:{id_info}} cs=:{cs_symbol_table, cs_error}
				# (entry, cs_symbol_table) = readPtr id_info cs_symbol_table
				| entry.ste_kind == STE_Empty
					= { cs & cs_symbol_table = cs_symbol_table }
					= { cs & cs_symbol_table = cs_symbol_table <:= (id_info, entry.ste_previous),
							 cs_error = checkError tv_name.id_name " global type variable not used in type of the function" cs_error }

checkDynamics mod_index scope dyn_type_ptrs type_defs modules type_heaps expr_heap cs
	= foldSt (check_dynamic mod_index scope) dyn_type_ptrs (type_defs, modules, type_heaps, expr_heap, cs)
where	
	check_dynamic mod_index scope dyn_info_ptr (type_defs, modules, type_heaps, expr_heap, cs)
		# (dyn_info, expr_heap) = readPtr dyn_info_ptr expr_heap
		= case dyn_info of
			EI_Dynamic opt_type
				-> case opt_type of
					Yes dyn_type
						# (dyn_type, loc_type_vars, type_defs, modules, type_heaps, cs) = check_dynamic_type mod_index scope dyn_type type_defs modules type_heaps cs
						| isEmpty loc_type_vars
							-> (type_defs, modules, type_heaps, expr_heap <:= (dyn_info_ptr, EI_Dynamic (Yes dyn_type)), cs)
				  			# cs_symbol_table = removeVariablesFromSymbolTable scope loc_type_vars cs.cs_symbol_table
							  cs_error = checkError loc_type_vars " type variable(s) not defined" cs.cs_error
							-> (type_defs, modules, type_heaps, expr_heap <:= (dyn_info_ptr, EI_Dynamic (Yes dyn_type)),
									{ cs & cs_error = cs_error, cs_symbol_table = cs_symbol_table })
					No
						-> (type_defs, modules, type_heaps, expr_heap, cs)
			EI_DynamicType dyn_type loc_dynamics
				# (dyn_type, loc_type_vars, type_defs, modules, type_heaps, cs) = check_dynamic_type mod_index scope dyn_type type_defs modules type_heaps cs
				  (type_defs, modules, type_heaps, expr_heap, cs) = check_local_dynamics mod_index scope loc_dynamics type_defs modules type_heaps expr_heap cs
				  cs_symbol_table = removeVariablesFromSymbolTable scope loc_type_vars cs.cs_symbol_table
				-> (type_defs, modules, type_heaps, expr_heap <:= (dyn_info_ptr, EI_DynamicTypeWithVars loc_type_vars dyn_type loc_dynamics),
							{ cs & cs_symbol_table = cs_symbol_table }) 
						// ---> ("check_dynamic ", scope, dyn_type, loc_type_vars)

	check_local_dynamics mod_index scope local_dynamics type_defs modules type_heaps expr_heap cs
		= foldSt (check_dynamic mod_index (inc scope)) local_dynamics (type_defs, modules, type_heaps, expr_heap, cs)

	check_dynamic_type mod_index scope dt=:{dt_uni_vars,dt_type} type_defs modules type_heaps=:{th_vars} cs
		# (dt_uni_vars, (th_vars, cs)) = mapSt (add_type_variable_to_symbol_table scope) dt_uni_vars (th_vars, cs)
		  ots = { ots_type_defs = type_defs, ots_modules = modules }
		  oti = { oti_heaps = { type_heaps & th_vars = th_vars }, oti_all_vars = [], oti_all_attrs = [], oti_global_vars = [] }
		  (dt_type, ( {ots_type_defs, ots_modules}, {oti_heaps,oti_all_vars,oti_all_attrs, oti_global_vars}, cs))
		  		= checkOpenAType mod_index scope DAK_Ignore dt_type (ots, oti, cs)
		  th_vars = foldSt (\{tv_info_ptr} -> writePtr tv_info_ptr TVI_Empty) oti_global_vars oti_heaps.th_vars
	  	  cs_symbol_table = removeAttributedTypeVarsFromSymbolTable scope dt_uni_vars cs.cs_symbol_table
		| isEmpty oti_all_attrs
			= ({ dt & dt_uni_vars = dt_uni_vars, dt_global_vars = oti_global_vars, dt_type = dt_type },
					oti_all_vars, ots_type_defs, ots_modules, { oti_heaps & th_vars = th_vars }, { cs & cs_symbol_table = cs_symbol_table })
			# cs_symbol_table = removeAttributesFromSymbolTable oti_all_attrs cs_symbol_table
			= ({ dt & dt_uni_vars = dt_uni_vars, dt_global_vars = oti_global_vars, dt_type = dt_type },
					oti_all_vars, ots_type_defs, ots_modules, { oti_heaps & th_vars = th_vars },
					{ cs & cs_symbol_table = cs_symbol_table, cs_error = checkError (hd oti_all_attrs).av_name " type attribute variable not allowed" cs.cs_error})
		
	add_type_variable_to_symbol_table :: !Level !ATypeVar !*(!*TypeVarHeap,!*CheckState) -> (!ATypeVar,!(!*TypeVarHeap, !*CheckState))
	add_type_variable_to_symbol_table scope atv=:{atv_variable=atv_variable=:{tv_name}, atv_attribute} (type_var_heap, cs=:{cs_symbol_table,cs_error})
		#  var_info = tv_name.id_info
		   (var_entry, cs_symbol_table) = readPtr var_info cs_symbol_table
		| var_entry.ste_kind == STE_Empty || scope < var_entry.ste_def_level
			#! (new_var_ptr, type_var_heap) = newPtr TVI_Empty type_var_heap
			# cs_symbol_table = cs_symbol_table <:=
				(var_info, {ste_index = NoIndex, ste_kind = STE_TypeVariable new_var_ptr, ste_def_level = scope, ste_previous = var_entry })
			= ({atv & atv_attribute = TA_Multi, atv_variable = { atv_variable & tv_info_ptr = new_var_ptr }}, (type_var_heap,
					{ cs & cs_symbol_table = cs_symbol_table, cs_error = check_attribute atv_attribute cs_error}))
			= (atv, (type_var_heap, { cs & cs_symbol_table = cs_symbol_table, cs_error = checkError tv_name.id_name " type variable already defined" cs_error }))

	check_attribute TA_Unique error
		= error
	check_attribute TA_Multi error
		= error
	check_attribute TA_None error
		= error
	check_attribute attr error
		= checkError attr " attribute not allowed in type of dynamic" error
	
	
checkSpecialTypeVars :: !Specials !*CheckState -> (!Specials, !*CheckState)
checkSpecialTypeVars (SP_ParsedSubstitutions env) cs
	# (env, cs) = mapSt (mapSt check_type_var) env cs
	= (SP_ParsedSubstitutions env, cs)
where		
	check_type_var bind=:{bind_dst=type_var=:{tv_name={id_name,id_info}}} cs=:{cs_symbol_table,cs_error}
		# ({ste_kind,ste_def_level}, cs_symbol_table) = readPtr id_info cs_symbol_table
		| ste_kind <> STE_Empty && ste_def_level == cGlobalScope
			# (STE_TypeVariable tv_info_ptr) = ste_kind
			= ({ bind & bind_dst = { type_var & tv_info_ptr = tv_info_ptr}}, { cs & cs_symbol_table = cs_symbol_table })
			= (bind, { cs & cs_symbol_table= cs_symbol_table, cs_error = checkError id_name " type variable not defined" cs_error })
checkSpecialTypeVars SP_None cs
	= (SP_None, cs)
/*	
checkSpecialTypes :: !Index !Specials !u:{#.CheckedTypeDef} !u:{#.DclModule} !*TypeHeaps !*CheckState
	-> (!Specials, !u:{#CheckedTypeDef},!u:{#DclModule},!*TypeHeaps,!*CheckState)
*/
checkSpecialTypes mod_index (SP_ParsedSubstitutions envs) type_defs modules heaps cs
	# ots = { ots_type_defs = type_defs, ots_modules = modules }
	  (specials, (heaps, ots, cs)) = mapSt (check_environment mod_index) envs (heaps, ots, cs)
	= (SP_Substitutions specials, ots.ots_type_defs, ots.ots_modules, heaps, cs)
where
	check_environment mod_index env (heaps, ots, cs)
	 	# oti = { oti_heaps = heaps, oti_all_vars = [], oti_all_attrs = [], oti_global_vars = [] }
	 	  (env, (ots, {oti_heaps,oti_all_vars,oti_all_attrs}, cs)) = mapSt (check_substituted_type mod_index) env (ots, oti, cs)
	  	  cs_symbol_table = removeVariablesFromSymbolTable cGlobalScope oti_all_vars cs.cs_symbol_table
		  cs_symbol_table = removeAttributesFromSymbolTable oti_all_attrs cs_symbol_table
		= ({ ss_environ = env, ss_context = [], ss_vars = oti_all_vars, ss_attrs = oti_all_attrs}, (oti_heaps, ots, { cs & cs_symbol_table = cs_symbol_table }))

	check_substituted_type mod_index bind=:{bind_src} cot_state
		 # (bind_src, cot_state) = checkOpenType mod_index cGlobalScope DAK_Ignore bind_src cot_state
		 = ({ bind & bind_src = bind_src }, cot_state)
checkSpecialTypes mod_index SP_None type_defs modules heaps cs
	= (SP_None, type_defs, modules, heaps, cs)


cOuterMostLevel :== 0

addTypeVariablesToSymbolTable :: ![ATypeVar] ![AttributeVar] !*TypeHeaps !*CheckState
	-> (![ATypeVar], !(![AttributeVar], !*TypeHeaps, !*CheckState))
addTypeVariablesToSymbolTable type_vars attr_vars heaps cs /* TD */ =:{cs_x={x_type_var_position,x_is_dcl_module}}
// TD ...
	| x_type_var_position <> 0	= abort "addTypeVariablesToSymbolTable: x_type_var_position must be zero-initialized"

	# ((a_type_vars,t=:(attribute_vars, type_heaps, check_state)))
		= mapSt (add_type_variable_to_symbol_table) type_vars (attr_vars, heaps, cs)
	| x_is_dcl_module
		= (a_type_vars,t)
		
		// in case of an icl-module, the type variables of the type definition need to be normalized by storing its
		// argument number for later use. To avoid incomprehensible error messages the constructor's type variables
		// are changed below.
		# (a_type_vars,check_state)
			= mapSt change_type_variables_into_their_type_constructor_position a_type_vars check_state
		= (a_type_vars,(attribute_vars, type_heaps, check_state))		
// ... TD	
where
// TD ...
	change_type_variables_into_their_type_constructor_position :: !ATypeVar !*CheckState -> (!ATypeVar, !*CheckState)
	change_type_variables_into_their_type_constructor_position	atv=:{atv_variable=atv_variable=:{tv_name}, atv_attribute} cs=:{cs_symbol_table}
		# tv_info = tv_name.id_info
		  (entry, cs_symbol_table) = readPtr tv_info cs_symbol_table	  
		# stv_position
			= case entry.ste_kind of
				STE_BoundTypeVariable {stv_position}
					-> stv_position
		# atv
			= { atv & atv_variable.tv_name.id_name = toString stv_position }
		= (atv,{cs & cs_symbol_table = cs_symbol_table})		
// ... TD

	add_type_variable_to_symbol_table :: !ATypeVar !(![AttributeVar], !*TypeHeaps, !*CheckState)
		-> (!ATypeVar, !(![AttributeVar], !*TypeHeaps, !*CheckState))
	add_type_variable_to_symbol_table atv=:{atv_variable=atv_variable=:{tv_name}, atv_attribute}
		(attr_vars, heaps=:{th_vars,th_attrs}, cs=:{ cs_symbol_table, cs_error /* TD ... */, cs_x={x_type_var_position} /* ... TD */})
		# tv_info = tv_name.id_info
		  (entry, cs_symbol_table) = readPtr tv_info cs_symbol_table	  
		| entry.ste_def_level < cOuterMostLevel
			# (tv_info_ptr, th_vars) = newPtr TVI_Empty th_vars
		      atv_variable = { atv_variable & tv_info_ptr = tv_info_ptr }
		      (atv_attribute, attr_vars, th_attrs, cs_error) = check_attribute atv_attribute tv_name.id_name attr_vars th_attrs cs_error
			  cs_symbol_table = cs_symbol_table <:= (tv_info, {ste_index = NoIndex, ste_kind = STE_BoundTypeVariable {stv_attribute = atv_attribute,
			  						stv_info_ptr = tv_info_ptr, stv_count = 0 /* TD */, stv_position = x_type_var_position}, ste_def_level = cOuterMostLevel, ste_previous = entry })
			  heaps = { heaps & th_vars = th_vars, th_attrs = th_attrs }
			= ({atv & atv_variable = atv_variable, atv_attribute = atv_attribute},
					(attr_vars, heaps, { cs & cs_symbol_table = cs_symbol_table, cs_error = cs_error /* TD ... */, cs_x = {cs.cs_x & x_type_var_position = inc x_type_var_position}		/* ... TD */}))
			= (atv, (attr_vars, { heaps & th_vars = th_vars },
					 { cs & cs_symbol_table = cs_symbol_table, cs_error = checkError tv_name.id_name " type variable already defined" cs_error /* TD ... */, cs_x = {cs.cs_x & x_type_var_position = inc x_type_var_position}		/* ... TD */}))

	check_attribute :: !TypeAttribute !String ![AttributeVar] !*AttrVarHeap !*ErrorAdmin
		-> (!TypeAttribute, ![AttributeVar], !*AttrVarHeap, !*ErrorAdmin)
	check_attribute TA_Multi name attr_vars attr_var_heap cs
			# (attr_info_ptr, attr_var_heap) = newPtr AVI_Empty attr_var_heap
			  new_var = { av_name = emptyIdent name, av_info_ptr = attr_info_ptr}
			= (TA_Var new_var, [new_var : attr_vars], attr_var_heap, cs)
	check_attribute TA_None name attr_vars attr_var_heap cs
			# (attr_info_ptr, attr_var_heap) = newPtr AVI_Empty attr_var_heap
			  new_var = { av_name = emptyIdent name, av_info_ptr = attr_info_ptr}
			= (TA_Var new_var, [new_var : attr_vars], attr_var_heap, cs)
	check_attribute TA_Unique name attr_vars attr_var_heap cs
		= (TA_Unique, attr_vars, attr_var_heap, cs)
	check_attribute _ name attr_vars attr_var_heap cs
		= (TA_Multi, attr_vars, attr_var_heap, checkError name "specified attribute variable not allowed" cs)


addExistentionalTypeVariablesToSymbolTable :: !TypeAttribute ![ATypeVar] !*TypeHeaps !*CheckState
	-> (![ATypeVar], !(!*TypeHeaps, !*CheckState))
addExistentionalTypeVariablesToSymbolTable root_attr type_vars heaps cs
	= mapSt (add_type_variable_to_symbol_table root_attr) type_vars (heaps, cs)
where
	add_type_variable_to_symbol_table :: !TypeAttribute !ATypeVar !(!*TypeHeaps, !*CheckState)
		-> (!ATypeVar, !(!*TypeHeaps, !*CheckState))
	add_type_variable_to_symbol_table root_attr atv=:{atv_variable=atv_variable=:{tv_name}, atv_attribute}
		(heaps=:{th_vars,th_attrs}, cs=:{ cs_symbol_table, cs_error /* TD ... */, cs_x={x_type_var_position} /* ... TD */})
		# tv_info = tv_name.id_info
		  (entry, cs_symbol_table) = readPtr tv_info cs_symbol_table
		| entry.ste_def_level < cOuterMostLevel
			# (tv_info_ptr, th_vars) = newPtr TVI_Empty th_vars
		      atv_variable = { atv_variable & tv_info_ptr = tv_info_ptr }
		      (atv_attribute, cs_error) = check_attribute atv_attribute root_attr tv_name.id_name cs_error
			  cs_symbol_table = cs_symbol_table <:= (tv_info, {ste_index = NoIndex, ste_kind = STE_BoundTypeVariable {stv_attribute = atv_attribute,
			  						stv_info_ptr = tv_info_ptr, stv_count = 0 /* TD */, stv_position = x_type_var_position }, ste_def_level = cOuterMostLevel, ste_previous = entry })
			  heaps = { heaps & th_vars = th_vars }
			= ({atv & atv_variable = atv_variable, atv_attribute = atv_attribute},
					(heaps, { cs & cs_symbol_table = cs_symbol_table, cs_error = cs_error /* TD ... */, cs_x = {cs.cs_x & x_type_var_position = inc x_type_var_position}		/* ... TD */ }))
			= (atv, ({ heaps & th_vars = th_vars },
					 { cs & cs_symbol_table = cs_symbol_table, cs_error = checkError tv_name.id_name " type variable already defined" cs_error /* TD ... */, cs_x = {cs.cs_x & x_type_var_position = inc x_type_var_position}		/* ... TD */}))

	check_attribute :: !TypeAttribute !TypeAttribute !String !*ErrorAdmin
		-> (!TypeAttribute, !*ErrorAdmin)
	check_attribute TA_Multi root_attr name error
		= (TA_Multi, error)
	check_attribute TA_None root_attr name error
		= (TA_Multi, error)
	check_attribute TA_Unique root_attr name error
		= (TA_Unique, error)
	check_attribute TA_Anonymous root_attr name error
		= case root_attr of
			TA_Var var
				-> (TA_RootVar var, error)
			_
				-> (PA_BUG (TA_RootVar (abort "SwitchUniquenessBug is on")) root_attr, error)
	check_attribute attr root_attr name error
		= (TA_Multi, checkError name "specified attribute not allowed" error)
	
retrieveKinds :: ![ATypeVar] *TypeVarHeap -> (![TypeKind], !*TypeVarHeap)
retrieveKinds type_vars var_heap = mapSt retrieve_kind type_vars var_heap
where
	retrieve_kind {atv_variable = {tv_info_ptr}} var_heap
		# (TVI_TypeKind kind_info_ptr, var_heap) = readPtr tv_info_ptr var_heap
		= (KindVar kind_info_ptr, var_heap)

removeAttributedTypeVarsFromSymbolTable :: !Level ![ATypeVar] !*SymbolTable -> *SymbolTable
removeAttributedTypeVarsFromSymbolTable level vars symbol_table
	= foldr (\{atv_variable={tv_name}} -> removeDefinitionFromSymbolTable level tv_name) symbol_table vars


cExistentialVariable	:== True
cUniversalVariable 		:== False

removeDefinitionFromSymbolTable level {id_info} symbol_table
	| isNilPtr id_info
		= symbol_table
		# ({ste_def_level, ste_previous}, symbol_table) = readPtr id_info symbol_table
		| ste_def_level == level
			= symbol_table <:= (id_info, ste_previous)
			= symbol_table

removeAttributesFromSymbolTable :: ![AttributeVar] !*SymbolTable -> *SymbolTable
removeAttributesFromSymbolTable attrs symbol_table
	= foldr (\{av_name} -> removeDefinitionFromSymbolTable cGlobalScope av_name) symbol_table attrs

removeVariablesFromSymbolTable :: !Int ![TypeVar] !*SymbolTable -> *SymbolTable
removeVariablesFromSymbolTable scope vars symbol_table
	= foldr (\{tv_name} -> removeDefinitionFromSymbolTable scope tv_name) symbol_table vars

::	Indexes =
	{	index_type		:: !Index
	,	index_cons		:: !Index
	,	index_selector	:: !Index
	}

makeAttributedType attr annot type :== { at_attribute = attr, at_annotation = annot, at_type = type }

createClassDictionaries :: !Index !*{#ClassDef} !u:{#.DclModule} !Index !Index !Index !*TypeVarHeap !*VarHeap !*CheckState
	-> (!*{#ClassDef}, !u:{#DclModule}, ![CheckedTypeDef], ![SelectorDef], ![ConsDef], !*TypeVarHeap, !*VarHeap, !*CheckState)
createClassDictionaries mod_index class_defs modules first_type_index first_selector_index first_cons_index type_var_heap var_heap cs
	| cs.cs_error.ea_ok
		# (class_defs, modules, rev_dictionary_list, indexes, type_var_heap, var_heap, cs) = create_class_dictionaries mod_index 0  class_defs modules []
				{ index_type = first_type_index, index_cons= first_cons_index, index_selector = first_selector_index } type_var_heap var_heap cs
		  (type_defs, sel_defs, cons_defs, cs_symbol_table) = foldSt collect_type_def rev_dictionary_list  ([], [], [], cs.cs_symbol_table)
		= (class_defs, modules, type_defs, sel_defs, cons_defs, type_var_heap, var_heap, {cs & cs_symbol_table = cs_symbol_table })
		= (class_defs, modules, [], [], [], type_var_heap, var_heap, cs)
where
	collect_type_def type_ptr (type_defs, sel_defs, cons_defs, symbol_table)
		# ({ ste_kind = STE_DictType type_def }, symbol_table) = readPtr type_ptr symbol_table
		  (RecordType {rt_constructor, rt_fields}) = type_def.td_rhs
		  ({ ste_kind = STE_DictCons cons_def }, symbol_table) = readPtr rt_constructor.ds_ident.id_info symbol_table
	 	  (sel_defs, symbol_table) = collect_fields 0 rt_fields (sel_defs, symbol_table)
	 	= ( [type_def : type_defs ] , sel_defs, [cons_def : cons_defs], symbol_table)
	 where
		collect_fields field_nr fields (sel_defs, symbol_table)
			| field_nr < size fields
				# (sel_defs, symbol_table) = collect_fields (inc field_nr) fields (sel_defs, symbol_table)
				  ({ ste_kind = STE_DictField sel_def }, symbol_table) = readPtr fields.[field_nr].fs_name.id_info symbol_table
				= ( [ sel_def : sel_defs ], symbol_table)
				= ( sel_defs, symbol_table)
	
	create_class_dictionaries mod_index class_index class_defs modules rev_dictionary_list indexes type_var_heap var_heap cs
		| class_index < size class_defs
			# (class_defs, modules, rev_dictionary_list, indexes, type_var_heap, var_heap, cs) = 
					create_class_dictionary mod_index class_index class_defs modules rev_dictionary_list indexes type_var_heap var_heap cs
			= create_class_dictionaries mod_index (inc class_index) class_defs modules rev_dictionary_list indexes type_var_heap var_heap cs
			= (class_defs, modules, rev_dictionary_list, indexes, type_var_heap, var_heap, cs)			

	create_class_dictionary mod_index class_index  class_defs =:{[class_index] = class_def } modules rev_dictionary_list
			indexes type_var_heap var_heap cs=:{cs_symbol_table,cs_error}
		# {class_name,class_args,class_arity,class_members,class_context,class_dictionary=ds=:{ds_ident={id_info}}} = class_def
		| isNilPtr id_info
			# (type_id_info, cs_symbol_table) = newPtr EmptySymbolTableEntry cs_symbol_table
			  nr_of_members = size class_members
			  nr_of_fields = nr_of_members + length class_context
			  rec_type_id = { class_name &  id_info = type_id_info}
			  class_dictionary = { ds & ds_ident = rec_type_id }
			  class_defs = { class_defs & [class_index] = { class_def & class_dictionary = class_dictionary}}
			  (class_defs, modules, rev_dictionary_list, indexes, type_var_heap, var_heap, cs)
			  		= create_class_dictionaries_of_contexts mod_index class_context class_defs modules
			  				rev_dictionary_list indexes type_var_heap var_heap { cs & cs_symbol_table = cs_symbol_table }
			
			  { index_type, index_cons, index_selector } = indexes

			  type_symb = MakeTypeSymbIdent { glob_object = index_type, glob_module = mod_index } rec_type_id class_arity

			  rec_type		= makeAttributedType TA_Multi AN_Strict (TA type_symb [makeAttributedType TA_Multi AN_None TE \\ i <- [1..class_arity]])
			  field_type	= makeAttributedType TA_Multi AN_None TE

			  (rev_fields, var_heap, cs_symbol_table)
		  			= build_fields 0 nr_of_members class_members rec_type field_type index_type index_selector [] var_heap cs.cs_symbol_table
			  (index_selector, rev_fields, rev_field_types, class_defs, modules, var_heap, cs_symbol_table)
		  			= build_context_fields mod_index nr_of_members class_context rec_type index_type (index_selector + nr_of_members) rev_fields
		  					[ { field_type & at_annotation = AN_Strict } \\ i <- [1..nr_of_members] ] class_defs modules var_heap cs_symbol_table

			  (cons_id_info, cs_symbol_table) = newPtr EmptySymbolTableEntry cs_symbol_table
			  rec_cons_id = { class_name & id_info = cons_id_info}
			  cons_symbol = { ds_ident = rec_cons_id, ds_arity = nr_of_fields, ds_index = index_cons }
			  (cons_type_ptr, var_heap) = newPtr VI_Empty var_heap

			  (td_args, type_var_heap) = mapSt new_attributed_type_variable class_args type_var_heap
			  

	  		  type_def =
			 	{	td_name			= rec_type_id
				,	td_index		= index_type
				,	td_arity		= 0
				,	td_args			= td_args
				,	td_attrs		= []
				,	td_context		= []
				,	td_rhs			= RecordType {rt_constructor = cons_symbol, rt_fields = { field \\ field <- reverse rev_fields }}
				,	td_attribute	= TA_None
				,	td_pos			= NoPos
//				,	td_kinds		= []
//				,	td_properties	= cAllBitsClear
//				,	td_info			= EmptyTypeDefInfo
				}
			
			  cons_def = 	
				{	cons_symb		= rec_cons_id
				,	cons_type		= { st_vars	= [], st_args = reverse rev_field_types, st_result = rec_type,
									    st_arity = nr_of_fields, st_context = [], st_attr_vars = [], st_attr_env = [] }
				,	cons_priority	= NoPrio
				,	cons_index		= 0
				,	cons_type_index	= index_type
				,	cons_exi_vars	= []
//				,	cons_exi_attrs	= []
				,	cons_arg_vars	= []
				,	cons_type_ptr	= cons_type_ptr
				,	cons_pos		= NoPos
				}
			= ({ class_defs & [class_index] = { class_def & class_dictionary = { class_dictionary & ds_index = index_type }}}, modules,
					 [ type_id_info : rev_dictionary_list ], { index_type = inc index_type, index_cons = inc index_cons, index_selector = index_selector },
						type_var_heap, var_heap, { cs & cs_symbol_table = cs_symbol_table
							<:= (type_id_info, { ste_kind = STE_DictType type_def, ste_index = index_type,
											ste_def_level = NotALevel, ste_previous = abort "empty SymbolTableEntry" })
							<:= (cons_id_info, { ste_kind = STE_DictCons cons_def, ste_index = index_cons,
											ste_def_level = NotALevel, ste_previous = abort "empty SymbolTableEntry" })})
		# ({ste_kind}, cs_symbol_table) = readPtr id_info cs_symbol_table
		| ste_kind == STE_Empty
			= (class_defs, modules, rev_dictionary_list, indexes, type_var_heap, var_heap,
				{ cs & cs_symbol_table = cs_symbol_table, cs_error = checkError class_name "cyclic dependencies between type classes" cs_error})
			= (class_defs, modules, rev_dictionary_list, indexes, type_var_heap, var_heap, { cs & cs_symbol_table = cs_symbol_table })

	create_class_dictionaries_of_contexts mod_index [{tc_class = {glob_module, glob_object={ds_index}}}:tcs] class_defs modules
			rev_dictionary_list indexes type_var_heap var_heap cs
		| mod_index == glob_module
			# (class_defs, modules, rev_dictionary_list, indexes, type_var_heap, var_heap, cs)
					= create_class_dictionary mod_index ds_index class_defs modules rev_dictionary_list indexes type_var_heap var_heap cs
			= create_class_dictionaries_of_contexts mod_index tcs class_defs modules rev_dictionary_list indexes type_var_heap var_heap cs
			= create_class_dictionaries_of_contexts mod_index tcs class_defs modules rev_dictionary_list indexes type_var_heap var_heap cs
	create_class_dictionaries_of_contexts mod_index [] class_defs modules rev_dictionary_list indexes type_var_heap var_heap cs
		= (class_defs, modules, rev_dictionary_list, indexes, type_var_heap, var_heap, cs)
	
	new_attributed_type_variable tv type_var_heap
		# (new_tv_ptr, type_var_heap) = newPtr TVI_Empty type_var_heap
		= ({atv_attribute = TA_Multi, atv_annotation = AN_None , atv_variable = { tv & tv_info_ptr = new_tv_ptr }}, type_var_heap)
		
	build_fields field_nr nr_of_fields class_members rec_type field_type rec_type_index next_selector_index rev_fields var_heap symbol_table
		| field_nr < nr_of_fields
			# (field, var_heap, symbol_table) = build_field field_nr class_members.[field_nr].ds_ident.id_name rec_type_index
											rec_type field_type next_selector_index var_heap symbol_table
			= build_fields (inc field_nr) nr_of_fields class_members rec_type field_type rec_type_index (inc next_selector_index)
				 [ field : rev_fields ] var_heap symbol_table
			= (rev_fields, var_heap, symbol_table)			

	build_context_fields mod_index field_nr [{tc_class = {glob_module, glob_object={ds_index}}}:tcs] rec_type rec_type_index
			next_selector_index rev_fields rev_field_types class_defs modules var_heap symbol_table
		# ({class_name, class_arity, class_dictionary = {ds_ident, ds_index}}, _, class_defs, modules) = getClassDef ds_index glob_module mod_index class_defs modules
		  type_symb = MakeTypeSymbIdent { glob_object = ds_index, glob_module = glob_module } ds_ident class_arity
		  field_type = makeAttributedType TA_Multi AN_Strict (TA type_symb [makeAttributedType TA_Multi AN_None TE \\ i <- [1..class_arity]])
		  (field, var_heap, symbol_table) = build_field field_nr class_name.id_name rec_type_index rec_type field_type next_selector_index var_heap symbol_table
		= build_context_fields mod_index (inc field_nr) tcs rec_type rec_type_index (inc next_selector_index) [ field : rev_fields ]
				 [field_type : rev_field_types] class_defs modules var_heap symbol_table
	build_context_fields mod_index field_nr [] rec_type rec_type_index next_selector_index rev_fields rev_field_types class_defs modules var_heap symbol_table
		= (next_selector_index, rev_fields, rev_field_types , class_defs, modules, var_heap, symbol_table)			

	build_field field_nr field_name rec_type_index rec_type field_type selector_index var_heap symbol_table
		# (id_info, symbol_table) = newPtr EmptySymbolTableEntry symbol_table
		  (sd_type_ptr, var_heap) = newPtr VI_Empty var_heap
  		  field_id = { id_name = field_name, id_info = id_info }
  		  sel_def =
  		  	{	sd_symb			= field_id
  		  	,	sd_field		= field_id
  		  	,	sd_type			= { st_vars	= [], st_args = [ rec_type ], st_result = field_type, st_arity = 1,
  		  	                        st_context = [], st_attr_vars = [], st_attr_env = [] }
			,	sd_exi_vars		= []
//			,	sd_exi_attrs	= []
			,	sd_field_nr		= field_nr
			,	sd_type_index	= rec_type_index
			,	sd_type_ptr		= sd_type_ptr
			,	sd_pos			= NoPos
			}
		  field = { fs_name = field_id, fs_var = field_id, fs_index = selector_index }
		= (field, var_heap, symbol_table <:= (id_info, { ste_kind = STE_DictField sel_def, ste_index = selector_index,
				ste_def_level = NotALevel, ste_previous = abort "empty SymbolTableEntry" }))

bindTypeVarsAndAttributes :: !TypeAttribute !TypeAttribute ![ATypeVar] ![AType] !*TypeHeaps -> *TypeHeaps;
bindTypeVarsAndAttributes form_root_attribute act_root_attribute form_type_args act_type_args type_heaps
	# th_attrs = bind_attribute form_root_attribute act_root_attribute type_heaps.th_attrs
	= fold2St bind_type_and_attr form_type_args act_type_args { type_heaps & th_attrs = th_attrs }
where
	bind_type_and_attr {atv_attribute, atv_variable={tv_info_ptr}} {at_type,at_attribute} type_heaps=:{th_vars,th_attrs}
		= { type_heaps &	th_vars = th_vars <:= (tv_info_ptr, TVI_Type at_type),
							th_attrs = bind_attribute atv_attribute at_attribute th_attrs }
		
	bind_attribute (TA_Var {av_info_ptr}) attr th_attrs
		= th_attrs <:= (av_info_ptr, AVI_Attr attr)
	bind_attribute _ _ th_attrs
		= th_attrs

clearBindingsOfTypeVarsAndAttributes :: !TypeAttribute ![ATypeVar] !*TypeHeaps -> *TypeHeaps;
clearBindingsOfTypeVarsAndAttributes form_root_attribute form_type_args type_heaps
	# th_attrs = clear_attribute form_root_attribute type_heaps.th_attrs
	= foldSt clear_type_and_attr form_type_args { type_heaps & th_attrs = th_attrs }
where
	clear_type_and_attr {atv_attribute, atv_variable={tv_info_ptr}} type_heaps=:{th_vars,th_attrs}
		= { type_heaps & th_vars = th_vars <:= (tv_info_ptr, TVI_Empty), th_attrs = clear_attribute atv_attribute th_attrs }
		
	clear_attribute (TA_Var {av_info_ptr}) th_attrs
		= th_attrs <:= (av_info_ptr, AVI_Empty)
	clear_attribute _ th_attrs
		= th_attrs

class toVariable var :: !STE_Kind !Ident -> var

instance toVariable TypeVar
where
	toVariable (STE_TypeVariable info_ptr) ident = { tv_name = ident, tv_info_ptr = info_ptr }

instance toVariable AttributeVar
where
	toVariable (STE_TypeAttribute info_ptr) ident = { av_name = ident, av_info_ptr = info_ptr }

instance == AttributeVar
where
	(==) av1 av2 = av1.av_info_ptr == av2.av_info_ptr

instance <<< DynamicType
where
	(<<<) file {dt_global_vars,dt_type} = file <<< dt_global_vars <<< dt_type
