implementation module overloading

import StdEnv,StdOverloadedList,compare_types

import syntax, type, expand_types, utilities, unitype, predef, checktypes
import genericsupport, type_io_common
from check_instances import ::SortedInstances(..)

::	LocalTypePatternVariable =
	{	ltpv_var			:: !Int
	,	ltpv_new_var		:: !VarInfoPtr
	}

::	ClassInstanceDescr = 
	{	cid_class_index		:: !GlobalIndex
	,	cid_types			:: ![Type]
	,	cid_inst_module		:: !Index
	,	cid_inst_members	:: !{#ClassInstanceMember}
	,	cid_red_contexts	:: ![ClassApplication]
	}

:: 	ReducedContext  = RC_Class		!ClassInstanceDescr [ReducedContext]
					| RC_TC_Global	!GlobalTCType ![ClassApplication]
					| RC_TC_Local	!VarInfoPtr
					| RC_TC_Context	!TypeContext // used if contextIsReducible yields True for a non reducible TC context

::	ClassApplication	= CA_Instance	!ReducedContext
						| CA_Context 	!TypeContext

:: ReducedOverloadedApplication =
	{	roa_symbol 		:: !SymbIdent
	,	roa_fun_index	:: !Index
	,	roa_expr_ptr	:: !ExprInfoPtr
	,	roa_rcs			:: ![ClassApplication]
	}

:: ReducedOverloadedContext =
	{	roc_fun_index	:: !Index
	,	roc_expr_ptr	:: !ExprInfoPtr
	,	roc_rcs			:: ![RC]
	}

::	RC  = RC_Context  !TypeContext
		| RC_Instance !CI

::	CI	= CI_Class !(Optional CD) ![CI]
		| CI_TC

::  CD  = { cd_inst_symbol		:: ! Global Int
		  , cd_inst_contexts	:: ![RC]
		  , cd_new_vars :: ![(TypeVarInfoPtr,Int)]
		  }

::	VarInfo | VI_ContextContainsFreeTypeVar !TypeContext | VI_MissingContext !TypeContext

instanceError symbol types err
	# err = errorHeading "Overloading error" err
	  format = { form_properties = cNoProperties, form_attr_position = No }
	= { err & ea_file = err.ea_file <<< " \"" <<< symbol <<< "\" no instance available of type "
									<:: (format, types, Yes initialTypeVarBeautifulizer) <<< '\n' }

cycleInTypeContextError symbol types err
	# err = errorHeading "Overloading error" err
	  format = { form_properties = cNoProperties, form_attr_position = No }
	= { err & ea_file = err.ea_file <<< " \"" <<< symbol <<< "\" context depends on context with the same class and type, for type "
									<:: (format, types, Yes initialTypeVarBeautifulizer) <<< '\n' }

uniqueError :: a b *ErrorAdmin -> *ErrorAdmin | writeType b & <<< a
uniqueError symbol types err
	# err = errorHeading "Overloading/Uniqueness error" err
	  format = { form_properties = cAnnotated, form_attr_position = No }
	= { err & ea_file = err.ea_file <<< " \"" <<< symbol
			<<< "\" uniqueness specification of instance conflicts with current application "
			<:: (format, types, Yes initialTypeVarBeautifulizer) <<< '\n'}

unboxError class_ident type err
	# err = errorHeading ("Overloading error of "+++class_ident+++" class") err
	  format = { form_properties = cNoProperties, form_attr_position = No }
	= { err & ea_file = err.ea_file <<< ' ' <:: (format, type, Yes initialTypeVarBeautifulizer) <<< " instance cannot be unboxed\n"}

beautifulizeIdent {id_name}
	= case optBeautifulizeIdent id_name of
		No
			-> id_name
		Yes (str, line_nr)
			-> str+++" [line "+++toString line_nr+++"]"

overloadingError op_symb err
	# err = errorHeading "Overloading error" err
	  str = beautifulizeIdent op_symb
	= { err & ea_file = err.ea_file <<< " internal overloading of \"" <<< str <<< "\" could not be solved\n" }

class_name :: !TCClass -> {#Char}
class_name (TCClass {glob_object={ds_ident={id_name}}})
	= id_name
class_name (TCGeneric {gtc_class={glob_object={ds_ident={id_name}}},gtc_kind})
	# i=find_last_underscore (size id_name-1) id_name
	| i>=0
		= id_name % (0,i-1)+++"{|" +++ toString gtc_kind +++ "|}"
		= id_name+++"{|" +++ toString gtc_kind +++ "|}"
where
	find_last_underscore i s
		| i>=0 && s.[i]<>'_'
			= find_last_underscore (i-1) s
			= i

overloadingErrorWithContext :: !Ident !TCClass ![Type] !*ErrorAdmin -> *ErrorAdmin
overloadingErrorWithContext op_symb tc_class tc_types err
	# err=:{ea_file} = errorHeading "Overloading error" err
	  str = beautifulizeIdent op_symb
	  format = { form_properties = cWriteUnderscoreforTE, form_attr_position = No }
	# ea_file = ea_file <<< " internal overloading of \"" <<< str <<< "\" "
						<<< "could not be solved for: "
						<<< class_name tc_class <<< ' ' <:: (format, tc_types, Yes initialTypeVarBeautifulizer)
						<<< " (contains type variable not in function type at _ )\n"
	= {err & ea_file = ea_file}

missingContextError :: !Ident !TCClass ![Type] !*ErrorAdmin -> *ErrorAdmin
missingContextError op_symb tc_class tc_types err
	# err=:{ea_file} = errorHeading "Overloading error" err
	  str = beautifulizeIdent op_symb
	  format = { form_properties = cWriteUnderscoreforTE, form_attr_position = No }
	# ea_file = ea_file <<< " internal overloading of \"" <<< str <<< "\" "
						<<< "could not be solved for: "
						<<< class_name tc_class <<< ' ' <:: (format, tc_types, Yes initialTypeVarBeautifulizer)
						<<< " (context does not occur in function type)\n"
	= {err & ea_file = ea_file}

sub_class_error op_symb err
	# err = errorHeading "Overloading error" err
	  str = beautifulizeIdent op_symb
	= {err & ea_file = err.ea_file <<< " internal overloading could not be solved, because subclass of \"" <<< str <<< "\" used\n"}

abstractTypeInDynamicError td_ident err=:{ea_ok}
	# err = errorHeading "Implementation restriction" err
	= { err & ea_file = err.ea_file <<< (" derived abstract type '" +++ toString td_ident +++ "' not permitted in a dynamic") <<< '\n' }

typeCodeInDynamicError err=:{ea_ok}
	# err = errorHeading "Warning" err
	  err = {err & ea_ok=ea_ok}
	= { err & ea_file = err.ea_file <<< "TC context not allowed in dynamic" <<< '\n' }

cycleAfterRemovingNewTypeConstructorsError ident err
	# err = errorHeading "Error" err
	= { err & ea_file = err.ea_file <<< (" cycle in definition of '" +++ toString ident +++ "' after removing newtype constructors") <<< '\n' }

typeImprovementError symbol types1 types2 err
	# err = errorHeading "Type error" err
	  format = { form_properties = cNoProperties, form_attr_position = No }
	= { err & ea_file = err.ea_file
			<<< " conflicting constraints: "
			<<< symbol <<< ' ' <:: (format, types1, Yes initialTypeVarBeautifulizer)
			<<< " and: "
			<<< symbol <<< ' ' <:: (format, types2, Yes initialTypeVarBeautifulizer)
			<<< '\n' }

cannotAddDictionaryError op_symb err
	# err = errorHeading "Overloading error" err
	  str = beautifulizeIdent op_symb
	= { err & ea_file = err.ea_file <<< " cannot add dictionary to missing overloaded argument of \"" <<< str <<< "\"\n" }

/*
	As soon as all overloaded variables in an type context are instantiated, context reduction is carried out.
	This reduction yields a type class instance (here represented by a an index) and a list of
	ClassApplications.
*/

containsContext :: !TypeContext ![TypeContext] -> Bool
containsContext new_tc []
	= False
containsContext new_tc [tc : tcs]
	= new_tc == tc || containsContext new_tc tcs

FoundObject object :== object.glob_module <> NotFound
ObjectNotFound 	:== { glob_module = NotFound, glob_object = NotFound }

:: ReduceState =
	{	rs_new_contexts			:: ![TypeContext]
	,	rs_special_instances	:: !.SpecialInstances
	,	rs_type_pattern_vars	:: ![LocalTypePatternVariable]
	,	rs_var_heap				:: !.VarHeap
	,	rs_type_heaps			:: !.TypeHeaps
	,	rs_subst				:: !.Subst
	,	rs_coercions			:: !.Coercions
	,	rs_predef_symbols		:: !.PredefinedSymbols
	,	rs_error				:: !.ErrorAdmin
	}

:: ReduceInfo =
	{	ri_defs 				:: !{# CommonDefs}
	,	ri_instance_info 		:: !ClassInstanceInfo
	}

:: FinReduceInfo =
	{	fri_defs 				:: !{# CommonDefs}
	,	fri_unboxed_array_and_list_info	:: !UnboxedArrayAndListInfo
	}

:: UnboxedArrayAndListInfo = {uaali_main_dcl_module_n :: !Int, uaali_instance_info :: !ClassInstanceInfo}

::	Subst =
	{	subst_changed	:: !Bool
	,	subst_array		:: !.{!Type}
	,	subst_next_var_n :: !Int
	,	subst_previous_context_n :: !Int
	,	subst_context_n_at_last_update :: !Int
	}

::	SubstC =
	{	substc_changes	:: ![#Int!]
	,	substc_array	:: !.{!Type}
	,	substc_next_var_n :: !Int
	}
		
:: PreRedState =
	{	prs_var_heap			:: !.VarHeap
	,	prs_type_heaps			:: !.TypeHeaps
	,	prs_predef_symbols		:: !.PredefinedSymbols
	,	prs_subst				:: !.Subst
	,	prs_error				:: !.ErrorAdmin
	}

continueContextReduction :: !ReduceInfo ![RC] !*PreRedState -> (!Bool, ![RC], !*PreRedState)
continueContextReduction info [] prs_state
	= (False, [], prs_state)
continueContextReduction info [rc : rcs] prs_state
	# (changed_rc, rc, prs_state) 		= continue_cr_of_rc info rc prs_state
	  (changed_rcs , rcs, prs_state)	= continue_cr_of_rcs info rcs prs_state
	= (changed_rc || changed_rcs, [rc : rcs], prs_state)
where
	continue_cr_of_rc info rc=:(RC_Context tc) prs_state=:{prs_predef_symbols, prs_subst}
		| contextIsReducible tc info.ri_defs prs_predef_symbols prs_subst.subst_array
			# rdla = {rdla_depth = -1,rdla_previous_context=NoPreviousContext}
			  (ci, prs_state) = reduceTCorNormalContext info rdla tc prs_state
			= (True, RC_Instance ci, prs_state)
			= (False, rc, prs_state)
	continue_cr_of_rc info rc=:(RC_Instance ci) prs_state
		# (changed, ci, prs_state) = continue_cr_of_ci info ci prs_state
		| changed
			= (True, RC_Instance ci, prs_state)
			= (False, rc, prs_state)

	continue_cr_of_ci info ci=:(CI_Class ocd cis) prs_state
		# (changed, ocd, prs_state) = continue_cr_of_opt_cd info ocd prs_state
		| changed
			# (_ , cis, prs_state) = continue_cr_of_cis info cis prs_state
			= (True, CI_Class ocd cis, prs_state)
			# (changed , cis, prs_state) = continue_cr_of_cis info cis prs_state
			| changed
				= (True, CI_Class ocd cis, prs_state)
				= (False, ci, prs_state)
	continue_cr_of_ci info ci prs_state
		= (False, ci, prs_state)

	continue_cr_of_opt_cd info ocd=:(Yes cd=:{cd_inst_contexts}) prs_state
		# (changed , cd_inst_contexts, prs_state) = continue_cr_of_rcs info cd_inst_contexts prs_state
		| changed
			= (True, Yes { cd & cd_inst_contexts = cd_inst_contexts }, prs_state)
			= (False, ocd, prs_state)
	continue_cr_of_opt_cd info ocd prs_state
		= (False, ocd, prs_state)
	
	continue_cr_of_cis info [] prs_state
		= (False, [], prs_state)
	continue_cr_of_cis info [ci:cis] prs_state
		# (changed, ci, prs_state) = continue_cr_of_ci info ci prs_state
		| changed
			# (_ , cis, prs_state) = continue_cr_of_cis info cis prs_state
			= (True,  [ci : cis], prs_state)
			# (changed , cis, prs_state) = continue_cr_of_cis info cis prs_state
			= (changed , [ci: cis], prs_state)
		
	continue_cr_of_rcs info [] prs_state
		= (False, [], prs_state)
	continue_cr_of_rcs info [rc : rcs] prs_state
		# (changed, rc, prs_state) = continue_cr_of_rc info rc prs_state
		| changed
			# (_ , rcs, prs_state) = continue_cr_of_rcs info rcs prs_state
			= (True,  [rc : rcs], prs_state)
			# (changed , rcs, prs_state) = continue_cr_of_rcs info rcs prs_state
			= (changed , [rc : rcs], prs_state)

:: DepTypesState =
	{	dts_contexts			:: ![TypeContext]
	,	dts_subst				:: !.Subst
	,	dts_var_heap			:: !.VarHeap
	,	dts_type_heaps			:: !.TypeHeaps
	,	dts_error				:: !.ErrorAdmin
	}

improveDepTypes :: !ReduceInfo ![RC] !*DepTypesState -> *DepTypesState
improveDepTypes info [] dts_state
	= dts_state
improveDepTypes info [rc : rcs] dts_state
	# dts_state = improve_rc info rc dts_state
	= improve_rcs info rcs dts_state
where
	improve_rc info=:{ri_defs} (RC_Context tc=:{tc_class=TCClass class_symb,tc_types}) dts_state=:{dts_contexts,dts_subst,dts_type_heaps}
		# class_fun_dep_vars = ri_defs.[class_symb.glob_module].com_class_defs.[class_symb.glob_object.ds_index].class_fun_dep_vars
		| class_fun_dep_vars<>0
			# (found,prev_tc_types,dts_subst) = tc_with_dep_type_occurs dts_contexts class_symb tc_types class_fun_dep_vars dts_subst
			| found // && trace_tn "improve_rc" ---> (class_fun_dep_vars,prev_tc_types,tc_types)
				# (ok,dts_subst,dts_type_heaps) = improve_dep_type_in_context ri_defs prev_tc_types tc_types class_fun_dep_vars dts_subst dts_type_heaps
				| ok
					= {dts_state & dts_subst = dts_subst, dts_type_heaps = dts_type_heaps}
					# (_, tc_types, subst_array) = arraySubst tc_types dts_subst.subst_array
					  (_, prev_tc_types, subst_array) = arraySubst prev_tc_types subst_array
					  dts_subst & subst_array = subst_array
					  dts_error = typeImprovementError class_symb.glob_object.ds_ident prev_tc_types tc_types dts_state.dts_error
					= {dts_state & dts_subst = dts_subst, dts_type_heaps = dts_type_heaps, dts_error = dts_error}
				= {dts_state & dts_contexts = [tc:dts_contexts], dts_subst=dts_subst}
			= dts_state
	improve_rc info (RC_Context tc) dts_state
		= dts_state
	improve_rc info (RC_Instance ci) dts_state
		= improve_ci info ci dts_state

	improve_ci info (CI_Class (Yes {cd_inst_contexts}) cis) dts_state
		# dts_state = improve_rcs info cd_inst_contexts dts_state
		= improve_cis info cis dts_state
	improve_ci info (CI_Class ocd cis) dts_state
		= improve_cis info cis dts_state
	improve_ci info ci dts_state
		= dts_state
	
	improve_cis info [ci:cis] dts_state
		# dts_state = improve_ci info ci dts_state
		= improve_cis info cis dts_state
	improve_cis info [] dts_state
		= dts_state

	improve_rcs info [rc:rcs] dts_state
		# dts_state = improve_rc info rc dts_state
		= improve_rcs info rcs dts_state
	improve_rcs info [] dts_state
		= dts_state

tc_with_dep_type_occurs :: [TypeContext] (Global DefinedSymbol) [Type] Int *Subst -> (!Bool,![Type],!*Subst)
tc_with_dep_type_occurs [{tc_class=TCClass prev_class_symb,tc_types=prev_tc_types}:contexts] class_symb tc_types fun_dep_vars subst
	| prev_class_symb==class_symb
		# (equal,subst) = equal_non_dep_context_types prev_tc_types tc_types fun_dep_vars subst
		| equal // && trace_tn "tc_with_dep_type_occurs True"
			= (True,prev_tc_types,subst)
			= tc_with_dep_type_occurs contexts class_symb tc_types fun_dep_vars subst
		= tc_with_dep_type_occurs contexts class_symb tc_types fun_dep_vars subst
tc_with_dep_type_occurs [_:contexts] class_symb tc_types fun_dep_vars subst
	= tc_with_dep_type_occurs contexts class_symb tc_types fun_dep_vars subst
tc_with_dep_type_occurs [] class_symb tc_types fun_dep_vars subst
	= (False,[],subst)

equal_non_dep_context_types :: [Type] [Type] Int *Subst -> (!Bool,!*Subst)
equal_non_dep_context_types [prev_type:prev_types] [type:types] fun_dep_vars subst
	| fun_dep_vars bitand 1==0
		# (equal,subst) = equal_type prev_type type subst
		| equal
			= equal_non_dep_context_types prev_types types (fun_dep_vars>>1) subst
			= (False,subst)
		= equal_non_dep_context_types prev_types types (fun_dep_vars>>1) subst
equal_non_dep_context_types [] [] fun_dep_vars subst
	= (True,subst)

equal_type :: Type Type *Subst -> (!Bool,!*Subst)
equal_type (TempV tv_number1) type2 subst
	# (stype1,subst) = subst!subst_array.[tv_number1]
	= case stype1 of
		TE
			-> equal_var_and_type tv_number1 type2 subst
		_
			-> equal_type stype1 type2 subst
equal_type type1 (TempV tv_number2) subst
	# (stype2,subst) = subst!subst_array.[tv_number2]
	= case stype2 of
		TE
			-> (False,subst) // ---> ("equal_type",type1,tv_number2)
		_
			-> equal_type type1 stype2 subst
equal_type (TA cons_id1 cons_args1) (TA cons_id2 cons_args2) subst
	| cons_id1==cons_id2
		= equal_atypes cons_args1 cons_args2 subst
		= (False,subst)
equal_type (TA cons_id1 cons_args1) (TAS cons_id2 cons_args2 _) subst
	| cons_id1==cons_id2
		= equal_atypes cons_args1 cons_args2 subst
		= (False,subst)
equal_type (TAS cons_id1 cons_args1 _) (TAS cons_id2 cons_args2 _) subst
	| cons_id1==cons_id2
		= equal_atypes cons_args1 cons_args2 subst
		= (False,subst)
equal_type (TAS cons_id1 cons_args1 _) (TA cons_id2 cons_args2) subst
	| cons_id1==cons_id2
		= equal_atypes cons_args1 cons_args2 subst
		= (False,subst)
equal_type (TB tb1) (TB tb2) subst
	= (tb1 == tb2,subst)
equal_type (arg_atype1-->res_atype1) (arg_atype2-->res_atype2) subst
	# (eq,subst) = equal_type arg_atype1.at_type arg_atype2.at_type subst
	| eq
		= equal_type res_atype1.at_type res_atype2.at_type subst
		= (False,subst)
equal_type (TempCV tv_n1 :@: atypes1) (TempCV tv_n2 :@: atypes2) subst
	# (eq,subst) = equal_type_vars1 tv_n1 tv_n2 subst
	| eq
		= equal_atypes atypes1 atypes2 subst
		= (False,subst)
equal_type (TArrow1 atype1) (TArrow1 atype2) subst
	= equal_type atype1.at_type atype2.at_type subst
equal_type TArrow TArrow subst
	= (True,subst)
equal_type type1 type2 subst
	= (False,subst) // ---> ("equal_type",type1,type2)

equal_atypes :: [AType] [AType] *Subst -> (!Bool,!*Subst)
equal_atypes [atype1:atypes1] [atype2:atypes2] subst
	# (eq,subst) = equal_type atype1.at_type atype2.at_type subst
	| eq
		= equal_atypes atypes1 atypes2 subst
		= (False,subst)
equal_atypes [] [] subst
	= (True,subst)
	
equal_var_and_type :: Int Type *Subst -> (!Bool,!*Subst)
equal_var_and_type tv_number1 (TempV tv_number2) subst
	| tv_number1==tv_number2 // && trace_tn ("equal_var_and_type True "+++toString tv_number1+++" "+++toString tv_number2)
		= (True,subst)
		= equal_type_vars2 tv_number1 tv_number2 subst
equal_var_and_type tv_number1 type2 subst
	= (False,subst) // ---> ("equal_var_and_type",tv_number1,type2)

equal_type_vars1 :: !Int !Int !*Subst -> (!Bool,!*Subst)
equal_type_vars1 tv_n1 tv_n2 subst
	| tv_n1==tv_n2
		= (True,subst)
	# (stype1,subst) = subst!subst_array.[tv_n1]
	= case stype1 of
		TempV tv_n1
			-> equal_type_vars1 tv_n1 tv_n2 subst
		_
			-> equal_type_vars2 tv_n1 tv_n2 subst

equal_type_vars2 :: !Int !Int !*Subst -> (!Bool,!*Subst)
equal_type_vars2 tv_n1 tv_n2 subst
	# (stype2,subst) = subst!subst_array.[tv_n2]
	= case stype2 of
		TempV tv_n2
			| tv_n1==tv_n2
				-> (True,subst)
				-> equal_type_vars2 tv_n1 tv_n2 subst
		_
			-> (False,subst) // ---> ("equal_type_vars2",tv_n1,tv_n2)

improve_dep_type_in_context :: !{#CommonDefs} [Type] [Type] Int *Subst !*TypeHeaps -> (!Bool,!*Subst,!*TypeHeaps)
improve_dep_type_in_context defs [prev_type:prev_types] [type:types] fun_dep_vars subst type_heaps
	| fun_dep_vars bitand 1<>0
		# (ok,subst,type_heaps) = improve_type defs prev_type type subst type_heaps
		| ok
			= improve_dep_type_in_context defs prev_types types (fun_dep_vars>>1) subst type_heaps
			= (False,subst,type_heaps)
		= improve_dep_type_in_context defs prev_types types (fun_dep_vars>>1) subst type_heaps
where
	improve_type :: !{#CommonDefs} Type Type *Subst !*TypeHeaps -> (!Bool,!*Subst,!*TypeHeaps)
	improve_type defs (TempV tv_n1) (TempV tv_n2) subst type_heaps
		= improve_type_vars defs tv_n1 tv_n2 subst type_heaps
	improve_type defs (TempV tv_n1) type2 subst type_heaps
		# (stype1,subst) = subst!subst_array.[tv_n1]
		= case stype1 of
			TE
				| containsTypeVariable tv_n1 type2 subst.subst_array
					-> (False,subst,type_heaps)
					# subst & subst_array.[tv_n1] = type2, subst_changed=True
					-> (True,subst,type_heaps)
			_
				-> improve_type defs stype1 type2 subst type_heaps
	improve_type defs type1 (TempV tv_n2) subst type_heaps
		# (stype2,subst) = subst!subst_array.[tv_n2]
		= case stype2 of
			TE
				| containsTypeVariable tv_n2 type1 subst.subst_array
					-> (False,subst,type_heaps)
					# subst & subst_array.[tv_n2] = type1, subst_changed=True
					-> (True,subst,type_heaps)
			_
				-> improve_type defs type1 stype2 subst type_heaps
	improve_type defs type1=:(TA cons_id1 cons_args1) type2=:(TA cons_id2 cons_args2) subst type_heaps
		| cons_id1==cons_id2
			= improve_atypes defs cons_args1 cons_args2 subst type_heaps
			= expand_and_improve defs cons_id1 cons_args1 cons_id2 cons_args2 type1 type2 subst type_heaps
	improve_type defs type1=:(TA cons_id1 cons_args1) type2=:(TAS cons_id2 cons_args2 _) subst type_heaps
		| cons_id1==cons_id2
			= improve_atypes defs cons_args1 cons_args2 subst type_heaps
			= expand_and_improve defs cons_id1 cons_args1 cons_id2 cons_args2 type1 type2 subst type_heaps
	improve_type defs type1=:(TAS cons_id1 cons_args1 _) type2=:(TAS cons_id2 cons_args2 _) subst type_heaps
		| cons_id1==cons_id2
			= improve_atypes defs cons_args1 cons_args2 subst type_heaps
			= expand_and_improve defs cons_id1 cons_args1 cons_id2 cons_args2 type1 type2 subst type_heaps
	improve_type defs type1=:(TAS cons_id1 cons_args1 _) type2=:(TA cons_id2 cons_args2) subst type_heaps
		| cons_id1==cons_id2
			= improve_atypes defs cons_args1 cons_args2 subst type_heaps
			= expand_and_improve defs cons_id1 cons_args1 cons_id2 cons_args2 type1 type2 subst type_heaps
	improve_type defs (TB tb1) (TB tb2) subst type_heaps
		= (tb1==tb2,subst,type_heaps)
	improve_type defs (arg_atype1-->res_atype1) (arg_atype2-->res_atype2) subst type_heaps
		# (ok,subst,type_heaps) = improve_type defs arg_atype1.at_type arg_atype2.at_type subst type_heaps
		| ok
			= improve_type defs res_atype1.at_type res_atype2.at_type subst type_heaps
			= (False,subst,type_heaps)
	improve_type defs (TempCV tv_n1 :@: atypes1) (TempCV tv_n2 :@: atypes2) subst type_heaps
		# (ok,subst,type_heaps) = improve_type_vars defs tv_n1 tv_n2 subst type_heaps
		| ok
			= improve_atypes defs atypes1 atypes2 subst type_heaps
			= (False,subst,type_heaps)
	improve_type defs (TArrow1 atype1) (TArrow1 atype2) subst type_heaps
		= improve_type defs atype1.at_type atype2.at_type subst type_heaps
	improve_type defs TArrow TArrow subst type_heaps
		= (True,subst,type_heaps)
	improve_type defs type1=:(TA cons_id1 cons_args1) type2 subst type_heaps
		# (succ,type1,type_heaps) = tryToExpandTypeSyn defs type1 cons_id1 cons_args1 type_heaps
		| succ
			= improve_type defs type1 type2 subst type_heaps
			= (False,subst,type_heaps)
	improve_type defs type1=:(TAS cons_id1 cons_args1 _) type2 subst type_heaps
		# (succ,type1,type_heaps) = tryToExpandTypeSyn defs type1 cons_id1 cons_args1 type_heaps
		| succ
			= improve_type defs type1 type2 subst type_heaps
			= (False,subst,type_heaps)
	improve_type defs type1 type2=:(TA cons_id2 cons_args2) subst type_heaps
		# (succ,type2,type_heaps) = tryToExpandTypeSyn defs type2 cons_id2 cons_args2 type_heaps
		| succ
			= improve_type defs type1 type2 subst type_heaps
			= (False,subst,type_heaps)
	improve_type defs type1 type2=:(TAS cons_id2 cons_args2 _) subst type_heaps
		# (succ,type2,type_heaps) = tryToExpandTypeSyn defs type2 cons_id2 cons_args2 type_heaps
		| succ
			= improve_type defs type1 type2 subst type_heaps
			= (False,subst,type_heaps)
	improve_type defs type1 type2 subst type_heaps
		= (False,subst,type_heaps)

	improve_type_vars :: !{#CommonDefs} Int Int *Subst !*TypeHeaps -> (!Bool,!*Subst,!*TypeHeaps)
	improve_type_vars defs tv_n1 tv_n2 subst type_heaps
		| tv_n1==tv_n2
			= (True,subst,type_heaps)
		# (stype1,subst) = subst!subst_array.[tv_n1]
		= case stype1 of
			TempV tv_n1
				-> improve_type_vars defs tv_n1 tv_n2 subst type_heaps
			_
				-> improve_type_vars2 defs tv_n1 tv_n2 stype1 subst type_heaps

	improve_type_vars2 :: !{#CommonDefs} Int Int Type *Subst !*TypeHeaps -> (!Bool,!*Subst,!*TypeHeaps)
	improve_type_vars2 defs tv_n1 tv_n2 stype1 subst type_heaps
		# (stype2,subst) = subst!subst_array.[tv_n2]
		= case stype2 of
			TempV tv_n2
				| tv_n1==tv_n2
					-> (True,subst,type_heaps)
					-> improve_type_vars2 defs tv_n1 tv_n2 stype1 subst type_heaps
			TE
				-> case stype1 of
					TE	# subst & subst_array.[tv_n2] = TempV tv_n1, subst_changed=True
						-> (True,subst,type_heaps)
					_
						| containsTypeVariable tv_n2 stype1 subst.subst_array
							-> (False,subst,type_heaps)
							# subst & subst_array.[tv_n2] = stype1, subst_changed=True
							-> (True,subst,type_heaps)
			_
				-> case stype1 of
					TE
						| containsTypeVariable tv_n1 stype2 subst.subst_array
							-> (False,subst,type_heaps)
							# subst & subst_array.[tv_n1] = stype2, subst_changed=True
							-> (True,subst,type_heaps)
					_
						-> improve_type defs stype1 stype2 subst type_heaps

	improve_atypes :: !{#CommonDefs} [AType] [AType] *Subst !*TypeHeaps -> (!Bool,!*Subst,!*TypeHeaps)
	improve_atypes defs [arg1:args1] [arg2:args2] subst type_heaps
		# (ok,subst,type_heaps) = improve_type defs arg1.at_type arg2.at_type subst type_heaps
		| ok
			= improve_atypes defs args1 args2 subst type_heaps
			= (False,subst,type_heaps)
	improve_atypes defs [] [] subst type_heaps
		= (True,subst,type_heaps)

	expand_and_improve :: {#CommonDefs} TypeSymbIdent [AType] TypeSymbIdent [AType] Type Type !*Subst *TypeHeaps -> (!Bool,!*Subst,!*TypeHeaps)
    expand_and_improve defs cons_id1 cons_args1 cons_id2 cons_args2 type1 type2 subst type_heaps
		# (succ1,type1,type_heaps) = tryToExpandTypeSyn defs type1 cons_id1 cons_args1 type_heaps
		# (succ2,type2,type_heaps) = tryToExpandTypeSyn defs type2 cons_id2 cons_args2 type_heaps
		| succ1 || succ2
			= improve_type defs type1 type2 subst  type_heaps
			= (False, subst, type_heaps)
improve_dep_type_in_context defs [] [] fun_dep_vars subst type_heaps
	= (True,subst,type_heaps)

:: ReduceTCState =
	{	rtcs_new_contexts		:: ![TypeContext]
	,	rtcs_type_pattern_vars	:: ![LocalTypePatternVariable]
	,	rtcs_var_heap			:: !.VarHeap
	,	rtcs_type_heaps			:: !.TypeHeaps
	,	rtcs_error				:: !.ErrorAdmin
	}

:: FinalRedState =
	{	frs_all_contexts		:: ![TypeContext]
	,	frs_special_instances	:: !.SpecialInstances
	,	frs_type_pattern_vars	:: ![LocalTypePatternVariable]
	,	frs_var_heap			:: !.VarHeap
	,	frs_type_heaps			:: !.TypeHeaps
	,	frs_predef_symbols		:: !.PredefinedSymbols
	,	frs_coercions 			:: !.Coercions
	,	frs_subst				:: !.{!Type}
	,	frs_error				:: !.ErrorAdmin
	}

finishContextReduction :: ![ReducedOverloadedContext] ![ExprInfoPtr] !Int !{#CommonDefs} !ClassInstanceInfo
	!*VarHeap !*TypeHeaps !*ExpressionHeap !*PredefinedSymbols !*SpecialInstances !*Coercions !*{!Type} !*ErrorAdmin
	-> (![ReducedOverloadedApplication], ![TypeContext], ![LocalTypePatternVariable], !*VarHeap, !*TypeHeaps, !*ExpressionHeap, !*PredefinedSymbols,
		!*SpecialInstances , !*Coercions, !*{!Type}, !*ErrorAdmin)
finishContextReduction roaps case_with_context_ptrs module_id com_defs instance_info
		var_heap type_heaps expr_heap predef_symbols special_instances coercion_env subst error
	= finishContextReduction_ roaps case_with_context_ptrs module_id com_defs instance_info
		var_heap type_heaps expr_heap predef_symbols special_instances coercion_env subst error

finishContextReduction_ :: ![ReducedOverloadedContext] ![ExprInfoPtr] !Int !{#CommonDefs} !ClassInstanceInfo
	!*VarHeap !*TypeHeaps !*ExpressionHeap !*PredefinedSymbols !*SpecialInstances !*Coercions !*{!Type} !*ErrorAdmin
	-> (![ReducedOverloadedApplication], ![TypeContext], ![LocalTypePatternVariable], !*VarHeap, !*TypeHeaps, !*ExpressionHeap, !*PredefinedSymbols,
		!*SpecialInstances , !*Coercions, !*{!Type}, !*ErrorAdmin)
finishContextReduction_ roaps case_with_context_ptrs module_id com_defs instance_info
		var_heap type_heaps expr_heap predef_symbols special_instances coercion_env subst error
	# fr_state = { frs_all_contexts = [], frs_special_instances = special_instances, frs_type_pattern_vars = [], frs_var_heap = var_heap,
				   frs_subst = subst,
				   frs_type_heaps = type_heaps, frs_predef_symbols = predef_symbols, frs_coercions = coercion_env, frs_error = error }
	  (roaps, (expr_heap, fr_state))
		= mapSt (get_tc_and_finish_rc {fri_defs=com_defs, fri_unboxed_array_and_list_info={uaali_main_dcl_module_n=module_id,uaali_instance_info=instance_info}})
					roaps (expr_heap, fr_state)
	  (expr_heap,all_contexts,subst,var_heap,predef_symbols)
	  	= foldSt (add_case_constructor_contexts com_defs) case_with_context_ptrs
	  		(expr_heap,fr_state.frs_all_contexts,fr_state.frs_subst,fr_state.frs_var_heap,fr_state.frs_predef_symbols)
	  fr_state & frs_all_contexts=all_contexts,frs_subst=subst,frs_var_heap=var_heap,frs_predef_symbols=predef_symbols
	= (roaps, fr_state.frs_all_contexts, fr_state.frs_type_pattern_vars, fr_state.frs_var_heap, fr_state.frs_type_heaps, expr_heap,
			  fr_state.frs_predef_symbols, fr_state.frs_special_instances, fr_state.frs_coercions, fr_state.frs_subst, fr_state.frs_error)
where
	get_tc_and_finish_rc info {roc_fun_index, roc_expr_ptr,roc_rcs} (expr_heap, fr_state=:{frs_all_contexts,frs_subst,frs_var_heap})
		# (over_symbol,act_tcs,expr_heap,all_contexts,subst,var_heap)
			= get_and_expand_tc roc_expr_ptr expr_heap frs_all_contexts frs_subst frs_var_heap 
		  fr_state & frs_all_contexts=all_contexts, frs_subst=subst, frs_var_heap=var_heap
		  (cas, fr_state) = finish_context_reduction info roc_rcs act_tcs fr_state
		= ({ roa_symbol = over_symbol, roa_fun_index = roc_fun_index, roa_expr_ptr = roc_expr_ptr, roa_rcs = cas },
				(expr_heap, fr_state))

	get_and_expand_tc expr_ptr expr_heap all_contexts subst var_heap
		= case readPtr expr_ptr expr_heap of
			(EI_Overloaded info=:{oc_symbol,oc_context},expr_heap)
				# (changed, oc_context, subst) = arraySubst oc_context subst
				| changed
					// update not necessary because EI_Overloaded is not used anymore ?
					# expr_heap = writePtr expr_ptr (EI_Overloaded {info & oc_context = oc_context}) expr_heap
					-> (oc_symbol, oc_context, expr_heap, all_contexts, subst, var_heap)
					-> (oc_symbol, oc_context, expr_heap, all_contexts, subst, var_heap)
			(EI_OverloadedWithVarContexts info=:{ocvc_symbol,ocvc_context,ocvc_var_contexts},expr_heap)
				# (changed, ocvc_context, subst) = arraySubst ocvc_context subst
				  (all_contexts,var_heap) = add_var_contexts ocvc_var_contexts all_contexts var_heap
				  ocvc_symbol = {ocvc_symbol & symb_kind = case ocvc_symbol.symb_kind of
															SK_TypeCode
																-> SK_TypeCodeAndContexts ocvc_var_contexts
				  											_
					  											-> SK_VarContexts ocvc_var_contexts
					  			}
				| changed
					// update not necessary because EI_OverloadedWithVarContexts is not used anymore ? 
					# expr_heap = writePtr expr_ptr (EI_OverloadedWithVarContexts {info & ocvc_context=ocvc_context,ocvc_symbol=ocvc_symbol}) expr_heap
					-> (ocvc_symbol, ocvc_context, expr_heap, all_contexts, subst, var_heap)
					// update not necessary because EI_OverloadedWithVarContexts is not used anymore ? 
					# expr_heap = writePtr expr_ptr (EI_OverloadedWithVarContexts {info & ocvc_symbol=ocvc_symbol}) expr_heap
					-> (ocvc_symbol, ocvc_context, expr_heap, all_contexts, subst, var_heap)
	where
		add_var_contexts NoVarContexts new_contexts var_heap
			= (new_contexts,var_heap)
		add_var_contexts (VarContext arg_n contexts arg_atype var_contexts) new_contexts var_heap
			# (new_contexts,var_heap) = add_contexts contexts new_contexts var_heap
			= add_var_contexts var_contexts new_contexts var_heap

	add_case_constructor_contexts :: {#CommonDefs} ExprInfoPtr *(*ExpressionHeap,[TypeContext],*{!Type},*VarHeap,*{#PredefinedSymbol})
															-> *(*ExpressionHeap,[TypeContext],*{!Type},*VarHeap,*{#PredefinedSymbol})
	add_case_constructor_contexts com_defs expr_ptr (expr_heap,all_contexts,subst,var_heap,predef_symbols)
		# (EI_CaseTypeWithContexts case_type constructor_contexts,expr_heap) = readPtr expr_ptr expr_heap
		  (all_contexts,constructor_contexts,predef_symbols,subst,var_heap)
		  	= add_constructor_contexts constructor_contexts all_contexts predef_symbols subst var_heap
		  expr_heap = writePtr expr_ptr (EI_CaseTypeWithContexts case_type constructor_contexts) expr_heap
		= (expr_heap,all_contexts,subst,var_heap,predef_symbols)
	where
		add_constructor_contexts [(constructor_symbol,constructor_context):constructor_contexts] new_contexts predef_symbols subst var_heap
			# (new_contexts,constructor_context,predef_symbols,subst,var_heap)
				= add_contexts_of_constructor constructor_context new_contexts predef_symbols subst var_heap
			# (new_contexts,constructor_contexts,predef_symbols,subst,var_heap)
				= add_constructor_contexts constructor_contexts new_contexts predef_symbols subst var_heap
			= (new_contexts,[(constructor_symbol,constructor_context):constructor_contexts],predef_symbols,subst,var_heap)
		add_constructor_contexts [] new_contexts predef_symbols subst var_heap
			= (new_contexts,[],predef_symbols,subst,var_heap)

		add_contexts_of_constructor [constructor_context:constructor_contexts] new_contexts predef_symbols subst var_heap
			# (changed, constructor_context, subst) = arraySubst constructor_context subst
			| contextIsReducible constructor_context com_defs predef_symbols subst
				# (new_contexts,constructor_contexts,predef_symbols,subst,var_heap)
					= add_contexts_of_constructor constructor_contexts new_contexts predef_symbols subst var_heap
				= (new_contexts,[constructor_context:constructor_contexts],predef_symbols,subst,var_heap)
			# (found,found_context=:{tc_var}) = lookup_context constructor_context new_contexts
			| found
				# var_heap
					= case readPtr tc_var var_heap of
						(VI_Empty,var_heap)
							-> writePtr tc_var VI_EmptyConstructorClassVar var_heap
						(VI_EmptyConstructorClassVar,var_heap)
							-> var_heap
				  (new_contexts,constructor_contexts,predef_symbols,subst,var_heap)
					= add_contexts_of_constructor constructor_contexts new_contexts predef_symbols subst var_heap
				  constructor_context = {constructor_context & tc_var=tc_var}
				= (new_contexts,[constructor_context:constructor_contexts],predef_symbols,subst,var_heap)
				# var_heap
					= case readPtr constructor_context.tc_var var_heap of
						(VI_Empty,var_heap)
							-> writePtr constructor_context.tc_var VI_EmptyConstructorClassVar var_heap
						(VI_EmptyConstructorClassVar,var_heap)
							-> var_heap
				  new_contexts = [constructor_context : new_contexts]
				  (new_contexts,constructor_contexts,predef_symbols,subst,var_heap)
					= add_contexts_of_constructor constructor_contexts new_contexts predef_symbols subst var_heap
				= (new_contexts,[constructor_context:constructor_contexts],predef_symbols,subst,var_heap)
			where
				lookup_context :: !TypeContext ![TypeContext] -> (!Bool,!TypeContext)
				lookup_context new_tc [tc : tcs]
					| new_tc==tc
						= (True,tc)
						= lookup_context new_tc tcs
				lookup_context new_tc []
					= (False,new_tc)
		add_contexts_of_constructor [] new_contexts predef_symbols subst var_heap
			= (new_contexts,[],predef_symbols,subst,var_heap)

	add_contexts contexts all_contexts var_heap
		= foldSt add_spec_context contexts (all_contexts,var_heap)
	where
		add_spec_context tc (contexts, var_heap)
			| containsContext tc contexts
				= (contexts, var_heap)
			  	# (tc_var,var_heap) = newPtr VI_Empty var_heap
				= ([{tc & tc_var = tc_var} : contexts], var_heap)

	finish_context_reduction :: FinReduceInfo [RC] [TypeContext] *FinalRedState -> *(![ClassApplication],!*FinalRedState)
	finish_context_reduction info [ ]		 [ ] 	  frs_state
		= ([], frs_state)
	finish_context_reduction info [rc : rcs] [tc:tcs] frs_state
		# (frc, frs_state) 	= finish_cr_of_rc info rc tc frs_state
		  (frcs, frs_state)	= finish_context_reduction info rcs tcs frs_state
		= ([frc : frcs], frs_state)

	finish_cr_of_rc info (RC_Context _) act_tc frs_state=:{frs_all_contexts, frs_var_heap}
		| containsContext act_tc frs_all_contexts
			= (CA_Context act_tc, frs_state)
			# (tc_var, frs_var_heap) = newPtr VI_Empty frs_var_heap
			= (CA_Context act_tc, {frs_state & frs_var_heap = frs_var_heap, frs_all_contexts = [{act_tc & tc_var = tc_var} : frs_all_contexts]})
	finish_cr_of_rc info (RC_Instance ci) act_tc frs_state
		# (rc, frs_state) = finish_cr_of_ci info ci act_tc frs_state
		= (CA_Instance rc, frs_state)

	finish_cr_of_ci info (CI_Class No cis) act_tc=:{tc_class,tc_types} frs_state
		# {glob_module,glob_object={ds_index}} = getClassSymbol tc_class
		# cid = {cid_class_index = {gi_module=glob_module,gi_index=ds_index}, cid_inst_module = NoIndex, cid_inst_members = {}, cid_types = tc_types, cid_red_contexts = []}
		# (rcs, frs_state) = finish_cr_of_cis info cis act_tc frs_state
		# {class_members,class_context} = info.fri_defs.[glob_module].com_class_defs.[ds_index]
		| size class_members==0
			| (case tc_types of [_] -> False; _ -> True
			|| case class_context of [_,_:_] -> False; _ -> True)
				// not implemented for multiparameter type classes or fewer than 2 class constraints
				= (RC_Class cid rcs, frs_state)
				// if a constraint of a class without members is reduced, and all classes in the constraint of that class appear
				// in the reduced constraints for a variable, add a constraint for the original class for that variable
				// (this causes removal of the other constraints later), to prevent functions with too many constraints
				# n_contexts = length class_context
				  required_used_contexts = (2<<(n_contexts-1))-1 // beware of 1<<32==0 on IA32
				  variables_and_contexts = collect_variable_and_contexts_of_rcs rcs [] class_context
				  variables = [variable \\ (variable,used_contexts)<-variables_and_contexts | used_contexts==required_used_contexts]		
				  frs_state = add_unexpanded_contexts variables tc_class frs_state
				= (RC_Class cid rcs, frs_state)
		= (RC_Class cid rcs, frs_state)
	finish_cr_of_ci info (CI_Class (Yes cd) cis) act_tc frs_state
		# (cid, frs_state) = finish_cr_of_cd info cd act_tc frs_state
		  (rcs, frs_state) = finish_cr_of_cis info cis act_tc frs_state
		= (RC_Class cid rcs, frs_state)
	finish_cr_of_ci info CI_TC act_tc=:{tc_class,tc_types} frs_state=:{frs_all_contexts, frs_type_pattern_vars, frs_var_heap, frs_type_heaps, frs_error}
		# (rc, { rtcs_new_contexts, rtcs_type_pattern_vars, rtcs_var_heap, rtcs_type_heaps, rtcs_error })
			= reduce_tc_context info.fri_defs tc_class (hd tc_types)
					{ rtcs_new_contexts = frs_all_contexts, rtcs_type_pattern_vars = frs_type_pattern_vars, rtcs_var_heap = frs_var_heap,
					  rtcs_type_heaps = frs_type_heaps, rtcs_error = frs_error }
		= (rc, { frs_state & frs_all_contexts = rtcs_new_contexts, frs_type_pattern_vars = rtcs_type_pattern_vars, frs_var_heap = rtcs_var_heap,
				                      frs_type_heaps = rtcs_type_heaps, frs_error = rtcs_error})

	finish_cr_of_cd info=:{fri_defs} {cd_inst_symbol={glob_module,glob_object},cd_inst_contexts,cd_new_vars} act_tc=:{tc_class,tc_types}
			frs_state=:{frs_type_heaps,frs_coercions,frs_predef_symbols,frs_special_instances,frs_error}
		# {ins_type={it_vars,it_attr_vars,it_types,it_context},ins_members,ins_class_index,ins_specials} = fri_defs.[glob_module].com_instance_defs.[glob_object]
		| not ins_specials=:SP_GenerateRecordInstances
			# frs_type_heaps & th_vars = clear_binding_of_type_vars it_vars frs_type_heaps.th_vars,
							   th_attrs = clear_attr_vars it_attr_vars frs_type_heaps.th_attrs
				with
					clear_attr_vars [{av_info_ptr}:attrs] attrs_heap = clear_attr_vars attrs (writePtr av_info_ptr AVI_Empty attrs_heap)
					clear_attr_vars [] attrs_heap = attrs_heap
			# (uni_ok, frs_type_heaps, frs_coercions) = bindListsOfTypes fri_defs it_types tc_types frs_type_heaps frs_coercions
			| uni_ok
				# frs_subst = frs_state.frs_subst
				# (frs_subst, frs_type_heaps) = bind_new_vars cd_new_vars frs_subst frs_type_heaps
				# (new_contexts,frs_type_heaps) = freshContexts it_context frs_type_heaps
				# frs_state & frs_type_heaps = frs_type_heaps, frs_coercions = frs_coercions, frs_subst = frs_subst
				# (appls, frs_state) = finish_context_reduction info cd_inst_contexts new_contexts frs_state
				= ({ cid_class_index = ins_class_index, cid_inst_module = glob_module, cid_inst_members = ins_members, cid_types = tc_types, cid_red_contexts = appls },
						frs_state)
				# {class_ident} = fri_defs.[ins_class_index.gi_module].com_class_defs.[ins_class_index.gi_index]
				= ({ cid_class_index = ins_class_index, cid_inst_module = glob_module, cid_inst_members = ins_members, cid_types = tc_types, cid_red_contexts = [] },
						{ frs_state & frs_type_heaps = frs_type_heaps, frs_coercions = frs_coercions, frs_error = uniqueError class_ident tc_types frs_error})
			= check_unboxed_array_or_list_type info.fri_unboxed_array_and_list_info glob_module ins_class_index ins_members tc_types fri_defs frs_state

	finish_cr_of_cis :: FinReduceInfo [CI] TypeContext *FinalRedState -> *(*[ReducedContext],*FinalRedState)
	finish_cr_of_cis info [] act_tc frs_state
		= ([], frs_state)
	finish_cr_of_cis info cis {tc_class,tc_types} frs_state=:{frs_type_heaps}
		# {glob_module,glob_object={ds_index}} = getClassSymbol tc_class
		# {class_context,class_args} = info.fri_defs.[glob_module].com_class_defs.[ds_index]
		| class_context=:[]
			= ([], frs_state)
		# th_vars = set_class_args_types class_args tc_types frs_type_heaps.th_vars
		# (act_contexts, frs_type_heaps) = freshContexts class_context { frs_type_heaps & th_vars = th_vars }
		= map2St (finish_cr_of_ci info) cis act_contexts {frs_state & frs_type_heaps = frs_type_heaps}

	getClassSymbol (TCClass class_symbol)	= class_symbol
	getClassSymbol (TCGeneric {gtc_class})	= gtc_class

	reduce_tc_context :: {#CommonDefs} TCClass Type *ReduceTCState -> (ReducedContext, !*ReduceTCState)
	reduce_tc_context defs type_code_class type=:(TA cons_id=:{type_index} cons_args) rtcs_state=:{rtcs_error,rtcs_type_heaps}
		# rtcs_error = disallow_abstract_types_in_dynamics defs type_index rtcs_error
		# (expanded, type, rtcs_type_heaps)
			=	tryToExpandTypeSyn defs type cons_id cons_args rtcs_type_heaps
		# rtcs_state = {rtcs_state & rtcs_error=rtcs_error, rtcs_type_heaps=rtcs_type_heaps}
		| expanded
			=	reduce_tc_context defs type_code_class type rtcs_state
		# type_constructor = toTypeCodeConstructor type_index defs
		  (rc_red_contexts, rtcs_state) = try_to_reduce_tc_contexts defs type_code_class cons_args rtcs_state
		= (RC_TC_Global type_constructor rc_red_contexts, rtcs_state)
	reduce_tc_context defs type_code_class (TAS cons_id cons_args _) rtcs_state
		= reduce_tc_context defs type_code_class (TA cons_id cons_args) rtcs_state
	reduce_tc_context defs type_code_class (TB basic_type) rtcs_state
		= (RC_TC_Global (GTT_Basic basic_type) [], rtcs_state)
	reduce_tc_context defs type_code_class (arg_type --> result_type) rtcs_state
		#  (rc_red_contexts, rtcs_state) = try_to_reduce_tc_contexts defs type_code_class [arg_type, result_type] rtcs_state
		= (RC_TC_Global GTT_Function rc_red_contexts, rtcs_state)
	reduce_tc_context defs type_code_class (TempQDV var_number) rtcs_state=:{rtcs_type_pattern_vars, rtcs_var_heap}
		# (inst_var, (rtcs_type_pattern_vars, rtcs_var_heap))
			= addLocalTCInstance var_number (rtcs_type_pattern_vars, rtcs_var_heap)
		# rtcs_state = {rtcs_state & rtcs_type_pattern_vars=rtcs_type_pattern_vars, rtcs_var_heap=rtcs_var_heap}
		= (RC_TC_Local inst_var, rtcs_state)
	reduce_tc_context defs type_code_class type rtcs_state=:{rtcs_var_heap, rtcs_new_contexts}
		/*	workaround for the following problem: a type synonym may yield a (TempCV (or TempQCV) _ :@: _),
			contextIsReducible then yields True for the unexpanded type synonym application,
			but after expanding the type synonym the resulting type may not be reducible
		*/
		| case type of TempCV _ :@: _ -> True; TempV _ -> True; TempQCV _ :@: _ -> True; TempQV _ -> True; _ -> False
			# (tc_var, rtcs_var_heap) = newPtr VI_Empty rtcs_var_heap
			  tc = {tc_class=type_code_class, tc_types=[type], tc_var=tc_var}
			  rtcs_new_contexts = if (containsContext tc rtcs_new_contexts) rtcs_new_contexts [tc : rtcs_new_contexts]
			  rtcs_state & rtcs_var_heap=rtcs_var_heap, rtcs_new_contexts=rtcs_new_contexts
			= (RC_TC_Context tc, rtcs_state)

	try_to_reduce_tc_contexts :: {#CommonDefs} TCClass [AType] *ReduceTCState -> (![ClassApplication], !*ReduceTCState)
	try_to_reduce_tc_contexts defs type_code_class cons_args rtcs_state
		= mapSt (\{at_type} -> try_to_reduce_tc_context defs type_code_class at_type) cons_args rtcs_state
	where
		try_to_reduce_tc_context :: {#CommonDefs} TCClass Type *ReduceTCState -> (!ClassApplication, !*ReduceTCState)
		try_to_reduce_tc_context defs type_code_class (TempV var_number) rtcs_state=:{rtcs_var_heap, rtcs_new_contexts}
			# (tc_var, rtcs_var_heap) = newPtr VI_Empty rtcs_var_heap
			# rtcs_state={rtcs_state & rtcs_var_heap=rtcs_var_heap}
			  tc = { tc_class = type_code_class, tc_types = [TempV var_number], tc_var = tc_var }
			| containsContext tc rtcs_new_contexts
				= (CA_Context tc, rtcs_state)
				= (CA_Context tc, {rtcs_state & rtcs_new_contexts = [tc : rtcs_new_contexts]})
		try_to_reduce_tc_context defs type_code_class (TempQV var_number) rtcs_state=:{rtcs_var_heap,rtcs_new_contexts}
			# (tc_var, rtcs_var_heap) = newPtr VI_Empty rtcs_var_heap
			# rtcs_state={rtcs_state & rtcs_var_heap=rtcs_var_heap}
			# tc = { tc_class = type_code_class, tc_types = [TempQV var_number], tc_var = tc_var }
			| containsContext tc rtcs_new_contexts
				= (CA_Context tc, rtcs_state)
				= (CA_Context tc, {rtcs_state & rtcs_new_contexts = [tc : rtcs_new_contexts]})
		try_to_reduce_tc_context defs type_code_class type=:(TempCV _ :@: _) rtcs_state=:{rtcs_var_heap, rtcs_new_contexts}
			# (tc_var, rtcs_var_heap) = newPtr VI_Empty rtcs_var_heap
			# rtcs_state={rtcs_state & rtcs_var_heap=rtcs_var_heap}
			  tc = { tc_class=type_code_class, tc_types=[type], tc_var=tc_var }
			| containsContext tc rtcs_new_contexts
				= (CA_Context tc, rtcs_state)
				= (CA_Context tc, {rtcs_state & rtcs_new_contexts = [tc : rtcs_new_contexts]})
		try_to_reduce_tc_context defs type_code_class type rtcs_state
			# (rc, rtcs_state) = reduce_tc_context  defs type_code_class type rtcs_state
			= (CA_Instance rc, rtcs_state)
			
	disallow_abstract_types_in_dynamics :: {#CommonDefs} (Global Index) *ErrorAdmin ->  *ErrorAdmin
	disallow_abstract_types_in_dynamics defs type_index=:{glob_module,glob_object} error
		| cPredefinedModuleIndex == glob_module
			= error			
		# {td_ident,td_rhs} = defs.[glob_module].com_type_defs.[glob_object]
		= case td_rhs of
				AbstractType _			-> abstractTypeInDynamicError td_ident error
				AbstractSynType _ _		-> abstractTypeInDynamicError td_ident error
				_						-> error

	bind_new_vars [(tv_info_ptr,tv_n):new_vars] subst type_heaps
		# (tv_info, th_vars) = readPtr tv_info_ptr type_heaps.th_vars
		= case tv_info of
			TVI_Empty
				# (_,type2,subst) = arraySubst (TempV tv_n) subst
			 	  type_heaps & th_vars = writePtr tv_info_ptr (TVI_Type type2) th_vars
				-> bind_new_vars new_vars subst type_heaps
			TVI_Type _
			 	-> bind_new_vars new_vars subst {type_heaps & th_vars = th_vars}
	bind_new_vars [] subst type_heaps
		= (subst,type_heaps)

check_unboxed_array_or_list_type :: UnboxedArrayAndListInfo Int GlobalIndex {#ClassInstanceMember} ![Type] {#CommonDefs} *FinalRedState
	-> (ClassInstanceDescr,*FinalRedState)
check_unboxed_array_or_list_type fri_unboxed_array_and_list_info glob_module ins_class_index ins_members tc_types fri_defs
		 	frs_state=:{frs_type_heaps,frs_coercions,frs_predef_symbols,frs_special_instances,frs_error}
	| is_predefined_global_symbol ins_class_index PD_ArrayClass frs_predef_symbols
		| is_unboxed_array tc_types
			# {class_members} = fri_defs.[ins_class_index.gi_module].com_class_defs.[ins_class_index.gi_index]
			  (rcs_class_context, frs_special_instances, frs_predef_symbols, frs_type_heaps, frs_error)
				= check_unboxed_array_type fri_unboxed_array_and_list_info glob_module ins_class_index ins_members tc_types class_members fri_defs
					frs_special_instances frs_predef_symbols frs_type_heaps frs_error
			= (rcs_class_context,
					{ frs_state & frs_predef_symbols = frs_predef_symbols, frs_type_heaps = frs_type_heaps, frs_error = frs_error, frs_special_instances = frs_special_instances})
		| is_packed_array tc_types
			# {class_members} = fri_defs.[ins_class_index.gi_module].com_class_defs.[ins_class_index.gi_index]
			  (rcs_class_context, frs_predef_symbols, frs_type_heaps, frs_error)
				= check_packed_array_type fri_unboxed_array_and_list_info glob_module ins_class_index ins_members tc_types fri_defs
					frs_predef_symbols frs_type_heaps frs_error
			= (rcs_class_context,
					{ frs_state & frs_predef_symbols = frs_predef_symbols, frs_type_heaps = frs_type_heaps, frs_error = frs_error})
			= abort "check_unboxed_array_or_list_type"
	| is_predefined_global_symbol ins_class_index PD_UListClass frs_predef_symbols
		# {class_members} = fri_defs.[ins_class_index.gi_module].com_class_defs.[ins_class_index.gi_index]
		  (rcs_class_context, frs_special_instances, frs_predef_symbols, frs_type_heaps, frs_error)
				= check_unboxed_list_type fri_unboxed_array_and_list_info glob_module ins_class_index ins_members tc_types class_members fri_defs 
				 	frs_special_instances frs_predef_symbols frs_type_heaps frs_error
		= (rcs_class_context,
				{ frs_state & frs_predef_symbols = frs_predef_symbols, frs_type_heaps = frs_type_heaps, frs_error = frs_error, frs_special_instances = frs_special_instances})
	| is_predefined_global_symbol ins_class_index PD_UTSListClass frs_predef_symbols
		# {class_members} = fri_defs.[ins_class_index.gi_module].com_class_defs.[ins_class_index.gi_index]
		  (rcs_class_context, frs_special_instances, frs_predef_symbols, frs_type_heaps, frs_error)
				= check_unboxed_tail_strict_list_type fri_unboxed_array_and_list_info glob_module ins_class_index ins_members tc_types class_members fri_defs 
				 	frs_special_instances frs_predef_symbols frs_type_heaps frs_error
		= (rcs_class_context,
				{ frs_state & frs_predef_symbols = frs_predef_symbols, frs_type_heaps = frs_type_heaps, frs_error = frs_error, frs_special_instances = frs_special_instances})
	| is_predefined_global_symbol ins_class_index PD_UMaybeClass frs_predef_symbols
		# {class_members} = fri_defs.[ins_class_index.gi_module].com_class_defs.[ins_class_index.gi_index]
		  (rcs_class_context, frs_special_instances, frs_predef_symbols, frs_type_heaps, frs_error)
				= check_unboxed_maybe_type fri_unboxed_array_and_list_info glob_module ins_class_index ins_members tc_types class_members fri_defs 
				 	frs_special_instances frs_predef_symbols frs_type_heaps frs_error
		= (rcs_class_context,
				{ frs_state & frs_predef_symbols = frs_predef_symbols, frs_type_heaps = frs_type_heaps, frs_error = frs_error, frs_special_instances = frs_special_instances})
where
	is_predefined_global_symbol :: !GlobalIndex !Int !PredefinedSymbols -> Bool
	is_predefined_global_symbol {gi_module,gi_index} predef_index predef_symbols
		# {pds_def,pds_module} = predef_symbols.[predef_index]
		= gi_module == pds_module && gi_index == pds_def

	is_unboxed_array:: [Type] -> Bool
	is_unboxed_array [TA {type_index={glob_module,glob_object},type_arity} _ : _]
		= glob_module==cPredefinedModuleIndex && glob_object==PD_UnboxedArrayTypeIndex
	is_unboxed_array _
		= False

	check_unboxed_array_type :: UnboxedArrayAndListInfo Int GlobalIndex {#ClassInstanceMember} ![Type] {#DefinedSymbol} {#CommonDefs} *SpecialInstances *PredefinedSymbols *TypeHeaps *ErrorAdmin
		-> (ClassInstanceDescr,*SpecialInstances,*PredefinedSymbols,*TypeHeaps, *ErrorAdmin)
	check_unboxed_array_type {uaali_main_dcl_module_n,uaali_instance_info} ins_module ins_class_index ins_members types=:[ _, elem_type :_] class_members defs special_instances predef_symbols type_heaps error
		# (unboxed_type, opt_record, type_heaps) = try_to_unbox elem_type defs type_heaps
		= case opt_record of
			Yes record
				# (ins_members, special_instances) = add_record_to_array_instances record class_members special_instances
				-> ({cid_class_index = ins_class_index, cid_inst_module = uaali_main_dcl_module_n, cid_inst_members = ins_members, cid_red_contexts = [], cid_types = types},
						special_instances, predef_symbols, type_heaps, error)
			No
				| not unboxed_type=:TE
					# array_instances = uaali_instance_info.[ins_class_index.gi_module].[ins_class_index.gi_index]
					  {glob_module,glob_object} = find_unboxed_or_packed_array_instance PD_UnboxedArrayTypeIndex unboxed_type array_instances defs
					| glob_module <> NotFound
						# {ins_members,ins_class_index} = defs.[glob_module].com_instance_defs.[glob_object]
						-> ({cid_class_index = ins_class_index, cid_inst_module = ins_module, cid_inst_members = ins_members, cid_red_contexts = [], cid_types = types},
								special_instances, predef_symbols, type_heaps, error)
						-> ({cid_class_index = ins_class_index, cid_inst_module = ins_module, cid_inst_members = ins_members, cid_red_contexts = [], cid_types = types},
								special_instances, predef_symbols, type_heaps, unboxError "Array" elem_type error)
					-> ({cid_class_index = ins_class_index, cid_inst_module = ins_module, cid_inst_members = ins_members, cid_red_contexts = [], cid_types = types},
							special_instances, predef_symbols, type_heaps, unboxError "Array" elem_type error)
	where
		add_record_to_array_instances :: !TypeSymbIdent !{#DefinedSymbol} !*SpecialInstances -> (!{#ClassInstanceMember},!*SpecialInstances)
		add_record_to_array_instances record members special_instances=:{si_next_generated_unboxed_record_member_index,si_array_instances}
			# may_be_there = look_up_generated_unboxed_record_instance record si_array_instances
			= case may_be_there of
				Yes inst
					-> (inst.ai_members, special_instances)
				No
					# inst = new_generated_unboxed_record_instance record members si_next_generated_unboxed_record_member_index
					-> (inst.ai_members, { special_instances &  si_next_generated_unboxed_record_member_index = si_next_generated_unboxed_record_member_index + size members,
																si_array_instances = [ inst : si_array_instances ] })

	is_packed_array:: [Type] -> Bool
	is_packed_array [TA {type_index={glob_module,glob_object},type_arity} _ : _]
		= glob_module==cPredefinedModuleIndex && glob_object==PD_PackedArrayTypeIndex
	is_packed_array _
		= False

	check_packed_array_type :: UnboxedArrayAndListInfo Int GlobalIndex {#ClassInstanceMember} ![Type] {#CommonDefs}
							   *PredefinedSymbols *TypeHeaps *ErrorAdmin
		-> (ClassInstanceDescr,*PredefinedSymbols,*TypeHeaps,*ErrorAdmin)
	check_packed_array_type {uaali_instance_info} ins_module ins_class_index ins_members types=:[ _, elem_type :_] defs predef_symbols type_heaps error
		# (packed_type, _, type_heaps) = try_to_unbox elem_type defs type_heaps
		| not (packed_type=:(TB BT_Int) || packed_type=:(TB BT_Real))
			= ({cid_class_index = ins_class_index, cid_inst_module = ins_module, cid_inst_members = ins_members, cid_red_contexts = [], cid_types = types},
				predef_symbols, type_heaps, packError elem_type error)
		# array_instances = uaali_instance_info.[ins_class_index.gi_module].[ins_class_index.gi_index]
		  {glob_module,glob_object} = find_unboxed_or_packed_array_instance PD_UnboxedArrayTypeIndex packed_type array_instances defs
		| glob_module <> NotFound
			# {ins_members,ins_class_index} = defs.[glob_module].com_instance_defs.[glob_object]
			= ({cid_class_index = ins_class_index, cid_inst_module = ins_module, cid_inst_members = ins_members, cid_red_contexts = [], cid_types = types},
				predef_symbols, type_heaps, error)
			= ({cid_class_index = ins_class_index, cid_inst_module = ins_module, cid_inst_members = ins_members, cid_red_contexts = [], cid_types = types},
				predef_symbols, type_heaps, packError elem_type error)
	where
		packError elem_type error
			# error = errorHeading "Overloading error of Array class" error
			  format = { form_properties = cNoProperties, form_attr_position = No }
			  error & ea_file = error.ea_file <<< ' ' <:: (format, elem_type, Yes initialTypeVarBeautifulizer) <<< " cannot be packed\n"
			= error

	check_unboxed_list_type :: UnboxedArrayAndListInfo Int GlobalIndex {#ClassInstanceMember} ![Type] {#DefinedSymbol} {#CommonDefs}
							   *SpecialInstances *PredefinedSymbols *TypeHeaps *ErrorAdmin
		-> (ClassInstanceDescr,*SpecialInstances,*PredefinedSymbols,*TypeHeaps,*ErrorAdmin)
	check_unboxed_list_type {uaali_main_dcl_module_n,uaali_instance_info} ins_module ins_class_index ins_members types=:[elem_type:_] class_members defs special_instances predef_symbols type_heaps error
		# (unboxed_type, opt_record, type_heaps) = try_to_unbox elem_type defs type_heaps
		= case opt_record of
			Yes record
				# (ins_members, special_instances) = add_record_to_list_instances record class_members special_instances
				-> ({cid_class_index = ins_class_index, cid_inst_module = uaali_main_dcl_module_n, cid_inst_members = ins_members, cid_red_contexts = [], cid_types = types},
						special_instances, predef_symbols, type_heaps, error)
			No
				| not unboxed_type=:TE
					# ulist_instances = uaali_instance_info.[ins_class_index.gi_module].[ins_class_index.gi_index]
					  {glob_module,glob_object} = find_unboxed_list_or_maybe_instance unboxed_type ulist_instances defs
					| glob_module <> NotFound
						# {ins_members,ins_class_index} = defs.[glob_module].com_instance_defs.[glob_object]
						-> ({cid_class_index = ins_class_index, cid_inst_module = ins_module, cid_inst_members = ins_members, cid_red_contexts = [], cid_types = types},
								special_instances, predef_symbols, type_heaps, error)
						-> ({cid_class_index = ins_class_index, cid_inst_module = ins_module, cid_inst_members = ins_members, cid_red_contexts = [], cid_types = types},
								special_instances, predef_symbols, type_heaps, unboxError "UList" elem_type error)
					-> ({cid_class_index = ins_class_index, cid_inst_module = ins_module, cid_inst_members = ins_members, cid_red_contexts = [], cid_types = types},
							special_instances, predef_symbols, type_heaps, unboxError "UList" elem_type error)
	where
		add_record_to_list_instances :: !TypeSymbIdent !{# DefinedSymbol} !*SpecialInstances -> (!{#ClassInstanceMember},!*SpecialInstances)
		add_record_to_list_instances record members special_instances=:{si_next_generated_unboxed_record_member_index,si_list_instances}
			# may_be_there = look_up_generated_unboxed_record_instance record si_list_instances
			= case may_be_there of
				Yes inst
					-> (inst.ai_members, special_instances)
				No
					# inst = new_generated_unboxed_record_instance record members si_next_generated_unboxed_record_member_index
					-> (inst.ai_members, { special_instances &  si_next_generated_unboxed_record_member_index = si_next_generated_unboxed_record_member_index + size members,
																si_list_instances = [ inst : si_list_instances ] })

	check_unboxed_tail_strict_list_type :: UnboxedArrayAndListInfo Int GlobalIndex {#ClassInstanceMember} ![Type] {#DefinedSymbol} {#CommonDefs}
							   *SpecialInstances *PredefinedSymbols *TypeHeaps *ErrorAdmin
		-> (ClassInstanceDescr,*SpecialInstances,*PredefinedSymbols,*TypeHeaps,*ErrorAdmin)
	check_unboxed_tail_strict_list_type {uaali_main_dcl_module_n,uaali_instance_info} ins_module ins_class_index ins_members types=:[elem_type:_] class_members defs special_instances predef_symbols type_heaps error
		# (unboxed_type, opt_record, type_heaps) = try_to_unbox elem_type defs type_heaps
		= case opt_record of
			Yes record
				# (ins_members, special_instances) = add_record_to_tail_strict_list_instances record class_members special_instances
				-> ({cid_class_index = ins_class_index, cid_inst_module = uaali_main_dcl_module_n, cid_inst_members = ins_members, cid_red_contexts = [], cid_types = types},
						special_instances, predef_symbols, type_heaps, error)
			No
				| not unboxed_type=:TE
					# utslist_instances = uaali_instance_info.[ins_class_index.gi_module].[ins_class_index.gi_index]
					  {glob_module,glob_object} = find_unboxed_list_or_maybe_instance unboxed_type utslist_instances defs
					| glob_module <> NotFound
						# {ins_members,ins_class_index} = defs.[glob_module].com_instance_defs.[glob_object]
						-> ({cid_class_index = ins_class_index, cid_inst_module = ins_module, cid_inst_members = ins_members, cid_red_contexts = [], cid_types = types},
								special_instances, predef_symbols, type_heaps, error)
						-> ({cid_class_index = ins_class_index, cid_inst_module = ins_module, cid_inst_members = ins_members, cid_red_contexts = [], cid_types = types},
								special_instances, predef_symbols, type_heaps, unboxError "UTSList" elem_type error)
					-> ({cid_class_index = ins_class_index, cid_inst_module = ins_module, cid_inst_members = ins_members, cid_red_contexts = [], cid_types = types},
							special_instances, predef_symbols, type_heaps, unboxError "UTSList" elem_type error)
	where
		add_record_to_tail_strict_list_instances :: !TypeSymbIdent !{#DefinedSymbol} !*SpecialInstances -> (!{#ClassInstanceMember},!*SpecialInstances)
		add_record_to_tail_strict_list_instances record members special_instances=:{si_next_generated_unboxed_record_member_index,si_tail_strict_list_instances}
			# may_be_there = look_up_generated_unboxed_record_instance record si_tail_strict_list_instances
			= case may_be_there of
				Yes inst
					-> (inst.ai_members, special_instances)
				No
					# inst = new_generated_unboxed_record_instance record members si_next_generated_unboxed_record_member_index
					-> (inst.ai_members, { special_instances &  si_next_generated_unboxed_record_member_index = si_next_generated_unboxed_record_member_index + size members,
																si_tail_strict_list_instances = [ inst : si_tail_strict_list_instances ] })

	check_unboxed_maybe_type :: UnboxedArrayAndListInfo Int GlobalIndex {#ClassInstanceMember} ![Type] {#DefinedSymbol} {#CommonDefs}
							   *SpecialInstances *PredefinedSymbols *TypeHeaps *ErrorAdmin
		-> (ClassInstanceDescr,*SpecialInstances,*PredefinedSymbols,*TypeHeaps,*ErrorAdmin)
	check_unboxed_maybe_type {uaali_main_dcl_module_n,uaali_instance_info} ins_module ins_class_index ins_members types=:[elem_type:_] class_members defs
			special_instances predef_symbols type_heaps error
		# (unboxed_type, opt_record, type_heaps) = try_to_unbox elem_type defs type_heaps
		= case opt_record of
			Yes record
				# (ins_members, special_instances) = add_record_to_maybe_instances record class_members special_instances
				-> ({cid_class_index = ins_class_index, cid_inst_module = uaali_main_dcl_module_n, cid_inst_members = ins_members, cid_red_contexts = [], cid_types = types},
						special_instances, predef_symbols, type_heaps, error)
			No
				| not unboxed_type=:TE
					# umaybe_instances = uaali_instance_info.[ins_class_index.gi_module].[ins_class_index.gi_index]
					  {glob_module,glob_object} = find_unboxed_list_or_maybe_instance unboxed_type umaybe_instances defs
					| glob_module <> NotFound
						# {ins_members,ins_class_index} = defs.[glob_module].com_instance_defs.[glob_object]
						-> ({cid_class_index = ins_class_index, cid_inst_module = ins_module, cid_inst_members = ins_members, cid_red_contexts = [], cid_types = types},
								special_instances, predef_symbols, type_heaps, error)
						# error = unboxError "UMaybe" elem_type error
						-> ({cid_class_index = ins_class_index, cid_inst_module = ins_module, cid_inst_members = ins_members, cid_red_contexts = [], cid_types = types},
								special_instances, predef_symbols, type_heaps, error)
					# error = unboxError "UMaybe" elem_type error
					-> ({cid_class_index = ins_class_index, cid_inst_module = ins_module, cid_inst_members = ins_members, cid_red_contexts = [], cid_types = types},
							special_instances, predef_symbols, type_heaps, error)
	where
		add_record_to_maybe_instances :: !TypeSymbIdent !{# DefinedSymbol} !*SpecialInstances -> (!{#ClassInstanceMember},!*SpecialInstances)
		add_record_to_maybe_instances record members special_instances=:{si_next_generated_unboxed_record_member_index,si_unboxed_maybe_instances}
			# may_be_there = look_up_generated_unboxed_record_instance record si_unboxed_maybe_instances
			= case may_be_there of
				Yes inst
					-> (inst.ai_members, special_instances)
				No
					# inst = new_generated_unboxed_record_instance record members si_next_generated_unboxed_record_member_index
					-> (inst.ai_members, { special_instances &  si_next_generated_unboxed_record_member_index = si_next_generated_unboxed_record_member_index + size members,
																si_unboxed_maybe_instances = [inst : si_unboxed_maybe_instances] })

	try_to_unbox :: Type !{#CommonDefs} !*TypeHeaps -> (!Type, !Optional TypeSymbIdent, !*TypeHeaps)
	try_to_unbox type=:(TB _) _ type_heaps
		= (type, No, type_heaps)
	try_to_unbox type=:(TA type_symb=:{type_index={glob_module,glob_object},type_arity} type_args) defs type_heaps
		# {td_arity,td_rhs,td_args,td_attribute} = defs.[glob_module].com_type_defs.[glob_object]
		= case td_rhs of
			RecordType _
				-> (TE, Yes type_symb, type_heaps)
			AbstractType _
				| glob_module==cPredefinedModuleIndex &&
					(glob_object==PD_LazyArrayTypeIndex || glob_object==PD_StrictArrayTypeIndex ||
					 glob_object==PD_UnboxedArrayTypeIndex || glob_object==PD_PackedArrayTypeIndex)
					-> (type, No, type_heaps)
					-> (TE, No, type_heaps)
			SynType {at_type}
				# (expanded_type, type_heaps) = substituteType td_attribute TA_Multi td_args type_args at_type type_heaps
				-> try_to_unbox expanded_type defs type_heaps
			NewType {ds_index}
				# {cons_type={st_args=[arg_type:_]}} = defs.[glob_module].com_cons_defs.[ds_index];
				# (expanded_type, type_heaps) = substituteType td_attribute TA_Multi td_args type_args arg_type.at_type type_heaps
				-> try_to_unbox expanded_type defs type_heaps
			_
				-> (TE, No, type_heaps)
	try_to_unbox type _ type_heaps
		= (TE, No, type_heaps)

	find_unboxed_or_packed_array_instance :: !Index Type !InstanceTree {#CommonDefs} -> Global Int
	find_unboxed_or_packed_array_instance array_type_index element_type (IT_Node this_inst_index=:{glob_object,glob_module} left right) defs
		# left_index = find_unboxed_or_packed_array_instance array_type_index element_type left defs
		| FoundObject left_index
			= left_index
		| unboxed_or_packed_array_instance_type_matches array_type_index defs.[glob_module].com_instance_defs.[glob_object].ins_type.it_types element_type
			= this_inst_index
			= find_unboxed_or_packed_array_instance array_type_index element_type right defs
	find_unboxed_or_packed_array_instance array_type_index element_type IT_Empty defs
		= ObjectNotFound
	find_unboxed_or_packed_array_instance array_type_index element_type (IT_Trees sorted_instances other_instances default_instances) defs
		# index = find_sorted_unboxed_or_packed_array_instance array_type_index element_type sorted_instances defs
		| FoundObject index
			= index
		# index = find_unboxed_or_packed_array_instance array_type_index element_type other_instances defs
		| FoundObject index
			= index
			= find_unboxed_or_packed_array_instance array_type_index element_type default_instances defs
	where
		find_sorted_unboxed_or_packed_array_instance array_type_index element_type (SI_Node instances left right) defs
			# left_index = find_sorted_unboxed_or_packed_array_instance array_type_index element_type left defs
			| FoundObject left_index
				= left_index
			# inst_index = find_unboxed_or_packed_array_instance_in_list array_type_index element_type instances defs
			| FoundObject inst_index
				= inst_index
				= find_sorted_unboxed_or_packed_array_instance array_type_index element_type right defs
		find_sorted_unboxed_or_packed_array_instance array_type_index element_type SI_Empty defs
			= ObjectNotFound
	
		find_unboxed_or_packed_array_instance_in_list array_type_index element_type [this_inst_index=:{glob_object,glob_module}:instances] defs
			| unboxed_or_packed_array_instance_type_matches array_type_index defs.[glob_module].com_instance_defs.[glob_object].ins_type.it_types element_type
				= this_inst_index
				= find_unboxed_or_packed_array_instance_in_list array_type_index element_type instances defs
		find_unboxed_or_packed_array_instance_in_list array_type_index element_type [] defs
			= ObjectNotFound

	unboxed_or_packed_array_instance_type_matches array_type_index [TA {type_index={glob_module,glob_object}} _,TB bt1:_] (TB bt2)
		= glob_module==cPredefinedModuleIndex && glob_object==array_type_index && bt1==bt2
	unboxed_or_packed_array_instance_type_matches array_type_index [TA {type_index={glob_module,glob_object}} _,TA {type_index=ti1} [_]:_] (TA {type_index=ti2} [_])
		// for array elements
		= glob_module==cPredefinedModuleIndex && glob_object==array_type_index && ti1==ti2
	unboxed_or_packed_array_instance_type_matches _ _ _
		= False

	find_unboxed_list_or_maybe_instance :: Type !InstanceTree {#CommonDefs} -> Global Int
	find_unboxed_list_or_maybe_instance element_type (IT_Node this_inst_index=:{glob_object,glob_module} left right) defs
		# left_index = find_unboxed_list_or_maybe_instance element_type left defs
		| FoundObject left_index
			= left_index
		| unboxed_list_or_maybe_instance_type_matches defs.[glob_module].com_instance_defs.[glob_object].ins_type.it_types element_type
			= this_inst_index
			= find_unboxed_list_or_maybe_instance element_type right defs
	find_unboxed_list_or_maybe_instance element_type IT_Empty defs
		= ObjectNotFound
	find_unboxed_list_or_maybe_instance element_type (IT_Trees sorted_instances other_instances default_instances) defs
		# index = find_sorted_unboxed_list_or_maybe_instance element_type sorted_instances defs
		| FoundObject index
			= index
		# index = find_unboxed_list_or_maybe_instance element_type other_instances defs
		| FoundObject index
			= index
			= find_unboxed_list_or_maybe_instance element_type default_instances defs
	where
		find_sorted_unboxed_list_or_maybe_instance element_type (SI_Node instances left right) defs
			# left_index = find_sorted_unboxed_list_or_maybe_instance element_type left defs
			| FoundObject left_index
				= left_index
			# inst_index = find_unboxed_list_or_maybe_instance_in_list element_type instances defs
			| FoundObject inst_index
				= inst_index
				= find_sorted_unboxed_list_or_maybe_instance element_type right defs
		find_sorted_unboxed_list_or_maybe_instance element_type SI_Empty defs
			= ObjectNotFound
	
		find_unboxed_list_or_maybe_instance_in_list element_type [this_inst_index=:{glob_object,glob_module}:instances] defs
			| unboxed_list_or_maybe_instance_type_matches defs.[glob_module].com_instance_defs.[glob_object].ins_type.it_types element_type
				= this_inst_index
				= find_unboxed_list_or_maybe_instance_in_list element_type instances defs
		find_unboxed_list_or_maybe_instance_in_list element_type [] defs
			= ObjectNotFound

	unboxed_list_or_maybe_instance_type_matches [TB bt1] (TB bt2) = bt1==bt2
	unboxed_list_or_maybe_instance_type_matches [TA {type_index=ti1} [_]] (TA {type_index=ti2} [_]) = ti1==ti2	// for array elements
	unboxed_list_or_maybe_instance_type_matches _ _ = False

	look_up_generated_unboxed_record_instance :: !TypeSymbIdent ![ArrayInstance] -> Optional ArrayInstance
	look_up_generated_unboxed_record_instance record [inst : insts]
		| record == inst.ai_record
			= Yes inst
			= look_up_generated_unboxed_record_instance record insts
	look_up_generated_unboxed_record_instance record []
		= No
	
	new_generated_unboxed_record_instance :: !TypeSymbIdent !{#DefinedSymbol} !Index -> ArrayInstance
	new_generated_unboxed_record_instance record members next_member_index
		= {	ai_members = { {cim_ident=ds_ident,cim_arity=ds_arity,cim_index=next_inst_index} \\ {ds_ident,ds_arity} <-: members & next_inst_index <- [next_member_index .. ]},
			ai_record = record }

collect_variable_and_contexts_of_rcs :: [ReducedContext] [(Int,Int)] [TypeContext] -> [(Int,Int)]
collect_variable_and_contexts_of_rcs [rc:rcs] variables_and_contexts class_context
	# variables_and_contexts = collect_variable_and_contexts_of_rc rc variables_and_contexts class_context
	= collect_variable_and_contexts_of_rcs rcs variables_and_contexts class_context
where
	collect_variable_and_contexts_of_rc :: ReducedContext [(Int,Int)] [TypeContext] -> [(Int,Int)]
	collect_variable_and_contexts_of_rc (RC_Class cid rcs) variables_and_contexts class_context
		# variables_and_contexts = collect_variable_and_contexts_of_context cid.cid_class_index cid.cid_types variables_and_contexts class_context
		# variables_and_contexts = collect_variable_and_contexts_of_cas cid.cid_red_contexts variables_and_contexts class_context
		= collect_variable_and_contexts_of_rcs rcs variables_and_contexts class_context
	collect_variable_and_contexts_of_rc (RC_TC_Global _ cas) variables_and_contexts class_context
		= collect_variable_and_contexts_of_cas cas variables_and_contexts class_context
	collect_variable_and_contexts_of_rc (RC_TC_Local _) variables_and_contexts class_context
		= variables_and_contexts
	collect_variable_and_contexts_of_rc (RC_TC_Context tc) variables_and_contexts class_context
		= collect_variable_and_contexts_of_cas [CA_Context tc] variables_and_contexts class_context

	collect_variable_and_contexts_of_context :: GlobalIndex [Type] [(Int,Int)] [TypeContext] -> [(Int,Int)]
	collect_variable_and_contexts_of_context cid_class_index [TempV type_var_n] variables_and_contexts class_context
		# context_index = determine_index_in_class_context cid_class_index class_context 0
		| context_index<0
			= variables_and_contexts
			= add_variable_and_context type_var_n (1<<context_index) variables_and_contexts
	where
		determine_index_in_class_context :: !GlobalIndex ![TypeContext] !Int -> Int
		determine_index_in_class_context cid_class_index=:{gi_module,gi_index} [{tc_class=TCClass {glob_module,glob_object={ds_index}}}:class_contexts] class_index
			| glob_module==gi_module && ds_index==gi_index
				= class_index
				= determine_index_in_class_context cid_class_index class_contexts (class_index+1)
		determine_index_in_class_context cid_class_index=:{gi_module,gi_index} [{tc_class=TCGeneric {gtc_class={glob_module,glob_object={ds_index}}}}:class_contexts] class_index
			| glob_module==gi_module && ds_index==gi_index
				= class_index
				= determine_index_in_class_context cid_class_index class_contexts (class_index+1)
		determine_index_in_class_context cid_class_index [] class_index
			= -1;

		add_variable_and_context :: !Int !Int ![(Int,Int)] -> [(Int,Int)]
		add_variable_and_context type_var_n tv_context [variable_and_context=:(variable,context):variables_and_contexts]
			| type_var_n==variable
				#! context=context bitor tv_context
				= [(variable,context) : variables_and_contexts]
				= [variable_and_context : add_variable_and_context type_var_n tv_context variables_and_contexts]
		add_variable_and_context type_var_n tv_context []
			= [(type_var_n,tv_context)]
	collect_variable_and_contexts_of_context _ _ variables_and_contexts class_context
		= variables_and_contexts

	collect_variable_and_contexts_of_cas :: [ClassApplication] [(Int,Int)] [TypeContext] -> [(Int,Int)]
	collect_variable_and_contexts_of_cas [CA_Instance rc:cas] variables_and_contexts class_context
		# variables_and_contexts = collect_variable_and_contexts_of_rc rc variables_and_contexts class_context
		= collect_variable_and_contexts_of_cas cas variables_and_contexts class_context
	collect_variable_and_contexts_of_cas [CA_Context {tc_class,tc_types}:cas] variables_and_contexts class_context
		# tc_index = case tc_class of
			TCClass {glob_module,glob_object={ds_index}} -> {gi_module=glob_module,gi_index=ds_index}
			TCGeneric {gtc_class={glob_module,glob_object={ds_index}}} -> {gi_module=glob_module,gi_index=ds_index}
		# variables_and_contexts = collect_variable_and_contexts_of_context tc_index tc_types variables_and_contexts class_context
		= collect_variable_and_contexts_of_cas cas variables_and_contexts class_context
	collect_variable_and_contexts_of_cas [] variables_and_contexts class_context
		= variables_and_contexts
collect_variable_and_contexts_of_rcs [] variables_and_contexts class_context
	= variables_and_contexts

add_unexpanded_contexts :: ![Int] !TCClass !*FinalRedState -> *FinalRedState
add_unexpanded_contexts [variable:variables] tc_class frs_state=:{frs_all_contexts,frs_var_heap}
	# tc = {tc_class = tc_class, tc_types = [TempV variable], tc_var = nilPtr}
	| containsContext tc frs_all_contexts
		= add_unexpanded_contexts variables tc_class frs_state
		# (tc_var, frs_var_heap) = newPtr VI_Empty frs_var_heap
		# frs_all_contexts = [{tc & tc_var = tc_var} : frs_all_contexts]
		= add_unexpanded_contexts variables tc_class {frs_state & frs_all_contexts=frs_all_contexts, frs_var_heap=frs_var_heap}
add_unexpanded_contexts [] tc_class frs_state
	= frs_state

:: ReduceDLA = { // reduce detect loop arguments
	rdla_depth :: !Int,
	rdla_previous_context :: !PreviousContext
   }

:: PreviousContext = NoPreviousContext | PreviousContext !(Global DefinedSymbol) ![Type] /*subst_previous_context_n*/!Int
 
tryToReduceContexts :: !ReduceInfo ![TypeContext] !ReduceDLA !*PreRedState -> (![RC], !*PreRedState)
tryToReduceContexts info tcs rdla prs_state
	= mapSt (try_to_reduce_context info rdla) tcs prs_state
where
	try_to_reduce_context :: !ReduceInfo !ReduceDLA !TypeContext !*PreRedState -> *(!RC, !*PreRedState)
	try_to_reduce_context info rdla tc prs_state=:{prs_predef_symbols, prs_subst}
		| contextIsReducible tc info.ri_defs prs_predef_symbols prs_subst.subst_array
			# (ci, prs_state) = reduceTCorNormalContext info rdla tc prs_state
			= (RC_Instance ci, prs_state)
			= (RC_Context tc, prs_state)

reduceTCorNormalContext :: !ReduceInfo !ReduceDLA !TypeContext !*PreRedState -> *(!CI, !*PreRedState)
reduceTCorNormalContext info rdla tc=:{tc_class=TCGeneric {gtc_class},tc_types} prs_state=:{prs_subst}
	#! rdla_depth=rdla.rdla_depth
	| rdla_depth<32
		# rdla & rdla_depth=rdla_depth+1
		= reduceContext info gtc_class tc rdla prs_state
	# (eq,prs_subst) = equal_previous_context gtc_class tc_types rdla.rdla_previous_context prs_subst
	| eq
		# (_, tc_types, subst_array) = arraySubst tc_types prs_subst.subst_array
		  prs_subst & subst_array = subst_array
		  prs_state & prs_subst = prs_subst, prs_error = cycleInTypeContextError gtc_class.glob_object.ds_ident tc_types prs_state.prs_error
		= (CI_Class No [],prs_state)
	| rdla_depth bitand (rdla_depth-1)<>0
		# prs_state & prs_subst=prs_subst
		# rdla & rdla_depth=rdla_depth+1
		= reduceContext info gtc_class tc rdla prs_state
		#! subst_previous_context_n = prs_subst.subst_previous_context_n+1
		# prs_state & prs_subst = {prs_subst & subst_previous_context_n = subst_previous_context_n}
		# rdla & rdla_depth=rdla_depth+1, rdla_previous_context=PreviousContext gtc_class tc_types subst_previous_context_n
		= reduceContext info gtc_class tc rdla prs_state
reduceTCorNormalContext info rdla tc=:{tc_class=TCClass class_symbol,tc_types} prs_state=:{prs_predef_symbols,prs_subst}
	| is_predefined_class class_symbol PD_TypeCodeClass prs_predef_symbols
		= (CI_TC, prs_state)
	#! rdla_depth=rdla.rdla_depth
	| rdla_depth<32
		# rdla & rdla_depth=rdla_depth+1
		= reduceContext info class_symbol tc rdla prs_state
	# (eq,prs_subst) = equal_previous_context class_symbol tc_types rdla.rdla_previous_context prs_subst
	| eq
		# (_, tc_types, subst_array) = arraySubst tc_types prs_subst.subst_array
		  prs_subst & subst_array = subst_array
		  prs_state & prs_subst = prs_subst, prs_error = cycleInTypeContextError class_symbol.glob_object.ds_ident tc_types prs_state.prs_error
		= (CI_Class No [],prs_state)
	| rdla_depth bitand (rdla_depth-1)<>0
		# prs_state & prs_subst=prs_subst
		# rdla & rdla_depth=rdla_depth+1
		= reduceContext info class_symbol tc rdla prs_state
		#! subst_previous_context_n = prs_subst.subst_previous_context_n+1
		# prs_state & prs_subst = {prs_subst & subst_previous_context_n = subst_previous_context_n}
		# rdla & rdla_depth=rdla_depth+1, rdla_previous_context=PreviousContext class_symbol tc_types subst_previous_context_n
		= reduceContext info class_symbol tc rdla prs_state
where
	is_predefined_class {glob_module,glob_object={ds_index}} prdef_index predef_symbols =
		is_predefined_symbol glob_module ds_index prdef_index predef_symbols

equal_previous_context :: !(Global DefinedSymbol) ![Type] !PreviousContext !*Subst -> (!Bool,!*Subst)
equal_previous_context tc_class tc_types (PreviousContext ptc_class ptc_types subst_previous_context_n) subst=:{subst_context_n_at_last_update}
	| subst_context_n_at_last_update>=subst_previous_context_n
		= (False,subst)	// ---> ("equal_types",subst_context_n_at_last_update,subst_previous_context_n)
	| tc_class==ptc_class
		= equal_types tc_types ptc_types subst	// ---> ("equal_types",tc_types,ptc_types)
		= (False,subst)
where
	equal_types :: [Type] [Type] *Subst -> (!Bool,!*Subst)
	equal_types [type1:types1] [type2:types2] subst
		# (eq,subst) = equal_type type1 type2 subst
		| eq
			= equal_types types1 types2 subst
			= (False,subst)
	equal_types [] [] subst
		= (True,subst)
equal_previous_context tc_class tc_types NoPreviousContext subst
	= (False,subst)

reduceContext :: !ReduceInfo !(Global DefinedSymbol) !TypeContext !ReduceDLA !*PreRedState -> *(!CI, !*PreRedState)
reduceContext info=:{ri_defs,ri_instance_info} class_symbol tc=:{tc_types} rdla prs_state=:{prs_predef_symbols}
	# {class_ident,class_members,class_args,class_context,class_fun_dep_vars} = getClassDef class_symbol ri_defs
	# (cis, prs_state) = reduce_contexts_in_constraints info tc_types class_args class_context prs_state
	| size class_members > 0
		# class_instances = getClassInstances class_symbol ri_instance_info
		| class_fun_dep_vars<>0
			# (opt_cd, prs_state) = reduce_function_context tc class_fun_dep_vars class_ident info class_instances rdla prs_state
			= (CI_Class opt_cd cis, prs_state)
			# (opt_cd, prs_state) = reduce_context class_ident info tc class_instances rdla prs_state
			= (CI_Class opt_cd cis, prs_state)
		= (CI_Class No cis, prs_state)
where
	reduce_context :: !Ident !ReduceInfo !TypeContext  !InstanceTree !ReduceDLA !*PreRedState -> *(!Optional CD, !*PreRedState)
	reduce_context class_ident info tc=:{tc_types} class_instances rdla prs_state=:{prs_type_heaps,prs_subst}
		# (gis, ins_contexts, prs_type_heaps, prs_subst) = find_instance tc_types class_instances info.ri_defs prs_type_heaps prs_subst
		| FoundObject gis
			# (rcs, prs_state) = tryToReduceContexts info ins_contexts rdla {prs_state & prs_type_heaps = prs_type_heaps, prs_subst = prs_subst}
			= (Yes {cd_inst_symbol = gis, cd_inst_contexts = rcs, cd_new_vars = []}, prs_state)
			# (_, tc_types, subst_array) = arraySubst tc_types prs_subst.subst_array
			# prs_state & prs_type_heaps = prs_type_heaps, prs_subst = {prs_subst & subst_array = subst_array}, prs_error = instanceError class_ident tc_types prs_state.prs_error
			= (No, prs_state)

	reduce_function_context :: !TypeContext !BITVECT !Ident !ReduceInfo !InstanceTree !ReduceDLA !*PreRedState -> *(!Optional CD, !*PreRedState)
	reduce_function_context tc class_fun_dep_vars class_ident info class_instances rdla prs_state=:{prs_type_heaps,prs_subst}
		# (gis, ins_contexts, new_vars, prs_type_heaps, prs_subst) = find_fun_dep_instance tc_types class_instances class_fun_dep_vars info.ri_defs prs_type_heaps prs_subst
		| FoundObject gis
			# (rcs, prs_state) = tryToReduceContexts info ins_contexts rdla {prs_state & prs_type_heaps = prs_type_heaps, prs_subst = prs_subst}
			= (Yes {cd_inst_symbol = gis, cd_inst_contexts = rcs, cd_new_vars = new_vars}, prs_state)
			# (_, tc_types, subst_array) = arraySubst tc_types prs_subst.subst_array
			# prs_state & prs_type_heaps = prs_type_heaps, prs_subst = {prs_subst & subst_array = subst_array}, prs_error = instanceError class_ident tc_types prs_state.prs_error
			= (No, prs_state)

	reduce_contexts_in_constraint :: !ReduceInfo ![Type] ![TypeVar] ![TypeContext] *PreRedState -> *(![CI], !*PreRedState)
	reduce_contexts_in_constraint info types class_args [] prs_state
		= ([], prs_state)
	reduce_contexts_in_constraints info types class_args tcs prs_state=:{prs_type_heaps=prs_type_heaps=:{th_vars}}
		# th_vars = set_class_args_types class_args types th_vars
		  (ftcs, prs_type_heaps) = freshContexts tcs { prs_type_heaps & th_vars = th_vars }
		= mapSt (reduceTCorNormalContext info rdla) ftcs {prs_state & prs_type_heaps = prs_type_heaps}

	find_instance ::  [Type] !InstanceTree {#CommonDefs} *TypeHeaps !*Subst -> *(!Global Int, ![TypeContext], !*TypeHeaps, !*Subst)
	find_instance co_types (IT_Trees sorted_instances other_instance_tree default_instance_tree) defs type_heaps subst
		# (found,instances,type_heaps,subst) = find_instance_group co_types sorted_instances defs type_heaps subst
		| found
			# (instance_index,context,type_heaps,subst) = find_instance_in_group co_types instances defs type_heaps subst
			| FoundObject instance_index
				= (instance_index,context,type_heaps,subst)
			= find_instance_in_tree co_types other_instance_tree defs type_heaps subst
			# (instance_index,context,type_heaps,subst) = find_instance_in_tree co_types other_instance_tree defs type_heaps subst
			| FoundObject instance_index
				= (instance_index,context,type_heaps,subst)
			= find_instance_in_tree co_types default_instance_tree defs type_heaps subst
	find_instance co_types IT_Empty defs type_heaps subst
		= (ObjectNotFound, [], type_heaps, subst)

	find_instance_group :: [Type] !SortedInstances !{#CommonDefs} !*TypeHeaps !*Subst -> *(!Bool, ![Global Int], !*TypeHeaps, !*Subst)
	find_instance_group co_types (SI_Node instances=:[this_inst_index=:{glob_object,glob_module}:_] left right) defs type_heaps subst
		#! {it_vars,it_types} = defs.[glob_module].com_instance_defs.[glob_object].ins_type
		# th_vars = clear_binding_of_type_vars it_vars type_heaps.th_vars
		  substc = {substc_changes=[#!], substc_array=subst.subst_array, substc_next_var_n=subst.subst_next_var_n}
		  (compare_value, type_heaps, substc) = compare_instance_root_types it_types co_types defs {type_heaps & th_vars=th_vars} substc
		  subst & subst_array=undo_substitutions substc
		| compare_value==Equal
			= (True, instances, type_heaps, subst)
		| compare_value==Greater
			= find_instance_group co_types left defs type_heaps subst
		| compare_value==Smaller
			= find_instance_group co_types right defs type_heaps subst
			= (False, [], type_heaps, subst)
	find_instance_group co_types SI_Empty defs type_heaps subst
		= (False, [], type_heaps, subst)

	find_instance_in_group :: [Type] ![Global Index] {#CommonDefs} *TypeHeaps !*Subst -> *(!Global Int, ![TypeContext], !*TypeHeaps, !*Subst)
	find_instance_in_group co_types [this_inst_index=:{glob_object,glob_module}:instances] defs type_heaps subst
		# {ins_type={it_vars,it_types,it_context}, ins_specials} = defs.[glob_module].com_instance_defs.[glob_object]
		  th_vars = clear_binding_of_type_vars it_vars type_heaps.th_vars
		  substc = {substc_changes=[#!], substc_array=subst.subst_array, substc_next_var_n=subst.subst_next_var_n}
		  (matched, type_heaps, substc) = matchListsOfTypes defs it_types co_types { type_heaps & th_vars = th_vars } substc
		| matched
			# (subst_changed,subst_context_n_at_last_update)
				= case substc.substc_changes of
					[#!]	-> (subst.subst_changed,subst.subst_context_n_at_last_update)
					_		-> (True,subst.subst_previous_context_n) // ---> ("substc_changes",[e\\e<|-substc.substc_changes])
			# subst & subst_array=substc.substc_array, subst_changed=subst_changed, subst_next_var_n=substc.substc_next_var_n,
					  subst_context_n_at_last_update=subst_context_n_at_last_update
			# (subst_context, type_heaps) = freshContexts it_context type_heaps
			  (spec_inst, type_heaps, subst) = trySpecializedInstances subst_context (get_specials ins_specials) type_heaps subst
			| FoundObject spec_inst
				= (spec_inst, [], type_heaps, subst)
				= (this_inst_index, subst_context, type_heaps, subst)
			# subst & subst_array=undo_substitutions substc
			= find_instance_in_group co_types instances defs type_heaps subst
	find_instance_in_group co_types [] defs heaps  subst
		= (ObjectNotFound, [], heaps, subst)

	find_instance_in_tree :: [Type] !InstanceTree {#CommonDefs} *TypeHeaps !*Subst -> *(!Global Int, ![TypeContext], !*TypeHeaps, !*Subst)
	find_instance_in_tree co_types (IT_Node this_inst_index=:{glob_object,glob_module} left right) defs type_heaps subst
		# (left_index, inst_contexts, type_heaps, subst) = find_instance_in_tree co_types left defs type_heaps subst
		| FoundObject left_index
			= (left_index, inst_contexts, type_heaps, subst)
			# {ins_type={it_vars,it_types,it_context}, ins_specials} = defs.[glob_module].com_instance_defs.[glob_object]
			  th_vars = clear_binding_of_type_vars it_vars type_heaps.th_vars
			  substc = {substc_changes=[#!], substc_array=subst.subst_array, substc_next_var_n=subst.subst_next_var_n}
			  (matched, type_heaps, substc) = matchListsOfTypes defs it_types co_types { type_heaps & th_vars = th_vars } substc
			| matched
				# subst & subst_array=substc.substc_array, subst_next_var_n=substc.substc_next_var_n
				= found_instance substc.substc_changes it_context ins_specials this_inst_index type_heaps subst
				# subst & subst_array=undo_substitutions substc
				= find_instance_in_tree co_types right defs type_heaps subst
	find_instance_in_tree co_types IT_Empty defs heaps  subst
		= (ObjectNotFound, [], heaps, subst)

	found_instance :: ![#Int!] ![TypeContext] !Specials !(Global Index) !*TypeHeaps !*Subst -> *(!Global Int, ![TypeContext], !*TypeHeaps, !*Subst)
	found_instance [#!] it_context ins_specials this_inst_index type_heaps subst
		# (subst_context, type_heaps) = freshContexts it_context type_heaps
		  (spec_inst, type_heaps, subst) = trySpecializedInstances subst_context (get_specials ins_specials) type_heaps subst
		| FoundObject spec_inst
			= (spec_inst, [], type_heaps, subst)
			= (this_inst_index, subst_context, type_heaps, subst)
	found_instance substc_changes it_context ins_specials this_inst_index type_heaps subst
		# subst & subst_changed=True, subst_context_n_at_last_update=subst.subst_previous_context_n
		# (subst_context, type_heaps) = freshContexts it_context type_heaps
		  (spec_inst, type_heaps, subst) = trySpecializedInstances subst_context (get_specials ins_specials) type_heaps subst
		| FoundObject spec_inst
			= (spec_inst, [], type_heaps, subst)
			= (this_inst_index, subst_context, type_heaps, subst)

	find_fun_dep_instance :: [Type] !InstanceTree BITVECT {#CommonDefs} *TypeHeaps !*Subst
			-> *(!Global Int, ![TypeContext], ![(TypeVarInfoPtr,Int)], !*TypeHeaps,!*Subst)
	find_fun_dep_instance co_types (IT_Trees sorted_instances other_instance_tree default_instance_tree) class_fun_dep_vars defs type_heaps subst
		# (found,instances,type_heaps,subst) = find_fun_dep_instance_group co_types sorted_instances class_fun_dep_vars defs type_heaps subst
		| found
			# (instance_index,context,new_vars,type_heaps,subst) = find_fun_dep_instance_in_group co_types instances class_fun_dep_vars defs type_heaps subst
			| FoundObject instance_index
				= (instance_index,context,new_vars,type_heaps,subst)
			= find_fun_dep_instance_in_tree co_types other_instance_tree class_fun_dep_vars defs type_heaps subst
			# (instance_index,context,new_vars,type_heaps,subst)= find_fun_dep_instance_in_tree co_types other_instance_tree class_fun_dep_vars defs type_heaps subst
			| FoundObject instance_index
				= (instance_index,context,new_vars,type_heaps,subst)
			= find_fun_dep_instance_in_tree co_types default_instance_tree class_fun_dep_vars defs type_heaps subst
	find_fun_dep_instance co_types IT_Empty class_fun_dep_vars defs type_heaps subst
		= (ObjectNotFound, [], [], type_heaps, subst)

	find_fun_dep_instance_group :: [Type] !SortedInstances !BITVECT !{#CommonDefs} !*TypeHeaps !*Subst -> *(!Bool, ![Global Int], !*TypeHeaps, !*Subst)
	find_fun_dep_instance_group co_types (SI_Node instances=:[this_inst_index=:{glob_object,glob_module}:_] left right) class_fun_dep_vars defs type_heaps subst
		#! {it_vars,it_types} = defs.[glob_module].com_instance_defs.[glob_object].ins_type
		# th_vars = clear_binding_of_type_vars it_vars type_heaps.th_vars
		  substc = {substc_changes=[#!], substc_array=subst.subst_array, substc_next_var_n=subst.subst_next_var_n}
		  (compare_value, type_heaps, substc) = compare_fun_dep_instance_root_types it_types co_types class_fun_dep_vars defs {type_heaps & th_vars=th_vars} substc
		  subst & subst_array=undo_substitutions substc
		| compare_value==Equal
			= (True, instances, type_heaps, subst)
		| compare_value==Greater
			= find_fun_dep_instance_group co_types left class_fun_dep_vars defs type_heaps subst
		| compare_value==Smaller
			= find_fun_dep_instance_group co_types right class_fun_dep_vars defs type_heaps subst
			= (False, [], type_heaps, subst)
	find_fun_dep_instance_group co_types SI_Empty class_fun_dep_vars defs type_heaps subst
		= (False, [], type_heaps, subst)

	find_fun_dep_instance_in_group :: [Type] ![Global Index] BITVECT {#CommonDefs} *TypeHeaps !*Subst
					   -> *(!Global Int, ![TypeContext], ![(TypeVarInfoPtr,Int)], !*TypeHeaps,!*Subst)
	find_fun_dep_instance_in_group co_types [this_inst_index=:{glob_object,glob_module}:instances] class_fun_dep_vars defs type_heaps subst
		# {ins_type={it_vars,it_types,it_context}, ins_specials} = defs.[glob_module].com_instance_defs.[glob_object]
		  th_vars = clear_binding_of_type_vars it_vars type_heaps.th_vars
		  substc = {substc_changes=[#!], substc_array=subst.subst_array, substc_next_var_n=subst.subst_next_var_n}
		  (matched, type_heaps, substc) = matchListsOfNonFunDepTypes defs it_types co_types class_fun_dep_vars {type_heaps & th_vars = th_vars} substc
		| matched
			#! all_vars_defined = check_if_all_vars_defined it_vars type_heaps.th_vars
			# (maybe_non_termination, substc)
				= if (not all_vars_defined)
					(checkFunDepTypesForPossibleNonTermination it_types co_types class_fun_dep_vars co_types class_fun_dep_vars substc)
					(False, substc)
			| maybe_non_termination
				# subst & subst_array=undo_substitutions substc
				= find_fun_dep_instance_in_group co_types instances class_fun_dep_vars defs type_heaps subst

			# (matched, type_heaps, substc) = matchListsOfFunDepTypes defs it_types co_types class_fun_dep_vars type_heaps substc
			| not matched
				# subst & subst_array=undo_substitutions substc
				= find_fun_dep_instance_in_group co_types instances class_fun_dep_vars defs type_heaps subst
			# subst & subst_array=substc.substc_array, subst_next_var_n=substc.substc_next_var_n
			= found_fun_dep_instance substc.substc_changes all_vars_defined it_vars it_context ins_specials this_inst_index type_heaps subst
			# subst & subst_array=undo_substitutions substc
			= find_fun_dep_instance_in_group co_types instances class_fun_dep_vars defs type_heaps subst
	find_fun_dep_instance_in_group co_types [] class_fun_dep_vars defs heaps subst
		= (ObjectNotFound, [], [], heaps, subst)

	find_fun_dep_instance_in_tree :: [Type] !InstanceTree BITVECT {#CommonDefs} *TypeHeaps !*Subst
					-> *(!Global Int, ![TypeContext], ![(TypeVarInfoPtr,Int)], !*TypeHeaps,!*Subst)
	find_fun_dep_instance_in_tree co_types (IT_Node this_inst_index=:{glob_object,glob_module} left right) class_fun_dep_vars defs type_heaps subst
		# (left_index, inst_contexts, new_vars, type_heaps, subst) = find_fun_dep_instance_in_tree co_types left class_fun_dep_vars defs type_heaps subst
		| FoundObject left_index
			= (left_index, inst_contexts, new_vars, type_heaps, subst)
			# {ins_type={it_vars,it_types,it_context}, ins_specials} = defs.[glob_module].com_instance_defs.[glob_object]
			  th_vars = clear_binding_of_type_vars it_vars type_heaps.th_vars
			  substc = {substc_changes=[#!], substc_array=subst.subst_array, substc_next_var_n=subst.subst_next_var_n}
			  (matched, type_heaps, substc) = matchListsOfNonFunDepTypes defs it_types co_types class_fun_dep_vars {type_heaps & th_vars = th_vars} substc
			| matched
				#! all_vars_defined = check_if_all_vars_defined it_vars type_heaps.th_vars
				# (maybe_non_termination, substc)
					= if (not all_vars_defined)
						(checkFunDepTypesForPossibleNonTermination it_types co_types class_fun_dep_vars co_types class_fun_dep_vars substc)
						(False, substc)
				| maybe_non_termination
					# subst & subst_array=undo_substitutions substc
					= find_fun_dep_instance_in_tree co_types right class_fun_dep_vars defs type_heaps subst

				# (matched, type_heaps, substc) = matchListsOfFunDepTypes defs it_types co_types class_fun_dep_vars type_heaps substc
				| not matched
					# subst & subst_array=undo_substitutions substc
					= find_fun_dep_instance_in_tree co_types right class_fun_dep_vars defs type_heaps subst
				# subst & subst_array=substc.substc_array, subst_next_var_n=substc.substc_next_var_n
				= found_fun_dep_instance substc.substc_changes all_vars_defined it_vars it_context ins_specials this_inst_index type_heaps subst
				# subst & subst_array=undo_substitutions substc
				= find_fun_dep_instance_in_tree co_types right class_fun_dep_vars defs type_heaps subst
	find_fun_dep_instance_in_tree co_types IT_Empty class_fun_dep_vars defs heaps subst
		= (ObjectNotFound, [], [], heaps, subst)

	found_fun_dep_instance :: ![#Int!] !Bool ![TypeVar] ![TypeContext] !Specials !(Global Index) !*TypeHeaps !*Subst
							 -> *(!Global Int, ![TypeContext], ![(TypeVarInfoPtr,Int)], !*TypeHeaps,!*Subst)
	found_fun_dep_instance substc_changes all_vars_defined it_vars it_context ins_specials this_inst_index type_heaps subst
		# (subst_changed,subst_context_n_at_last_update)
			= case substc_changes of
				[#!]	-> (subst.subst_changed,subst.subst_context_n_at_last_update)
				_		-> (True,subst.subst_previous_context_n) // ---> ("substc_changes",[e\\e<|-substc.substc_changes])
		# subst & subst_changed=subst_changed, subst_context_n_at_last_update=subst_context_n_at_last_update
		# (new_vars,type_heaps,subst)
			= if (not all_vars_defined)
				(foldSt fresh_type_var_only_in_context it_vars ([],type_heaps,subst))
				([],type_heaps,subst)
		# (subst_context, type_heaps) = freshContexts it_context type_heaps
		  (spec_inst, type_heaps, subst) = trySpecializedInstances subst_context (get_specials ins_specials) type_heaps subst
		| FoundObject spec_inst
			= (spec_inst, [], new_vars, type_heaps, subst)
			= (this_inst_index, subst_context, new_vars, type_heaps, subst) // ---> ("subst_context",subst_context)

	check_if_all_vars_defined [{tv_info_ptr}:vars] type_var_heap
		= (sreadPtr tv_info_ptr type_var_heap)=:TVI_Type _ && check_if_all_vars_defined vars type_var_heap
	check_if_all_vars_defined [] type_var_heap
		= True

	fresh_type_var_only_in_context {tv_info_ptr,tv_ident} (new_vars,type_heaps,subst)
		# (tv_info, th_vars) = readPtr tv_info_ptr type_heaps.th_vars
		  type_heaps & th_vars = th_vars
		= case tv_info of
			TVI_Type type
				-> (new_vars,type_heaps,subst)
			TVI_Empty
				# (tv_number,subst_array) = usize subst.subst_array
				#! subst_next_var_n = subst.subst_next_var_n
				| subst_next_var_n < tv_number
					# subst & subst_next_var_n = subst_next_var_n+1
					  type = TempV subst_next_var_n
					  type_heaps & th_vars = writePtr tv_info_ptr (TVI_Type type) type_heaps.th_vars
					  new_vars = [(tv_info_ptr,subst_next_var_n):new_vars]
					-> (new_vars,type_heaps, subst)
					# subst & subst_next_var_n = subst_next_var_n+1
					#! m = tv_number>>2
					# subst_array = arrayPlusList subst_array [TE \\ i<-[0..m]]
					  subst & subst_array = subst_array
					  type = TempV tv_number
					  type_heaps & th_vars = writePtr tv_info_ptr (TVI_Type type) type_heaps.th_vars					
					  new_vars = [(tv_info_ptr,tv_number):new_vars]
					-> (new_vars,type_heaps,subst)

clear_binding_of_type_vars vars type_var_heap
	= foldSt clear_binding_of_type_var vars type_var_heap
where
	clear_binding_of_type_var {tv_info_ptr} type_var_heap
		= type_var_heap <:= (tv_info_ptr, TVI_Empty)

undo_substitutions {substc_changes=[#!],substc_array}
	= substc_array
undo_substitutions subst=:{substc_changes=[#tv_n:substc_changes!],substc_array}
	= undo_substitutions {subst & substc_changes=substc_changes,substc_array={substc_array & [tv_n]=TE}}

getClassDef :: !(Global DefinedSymbol) !{# CommonDefs} -> ClassDef
getClassDef {glob_module,glob_object={ds_index,ds_ident}} defs = defs.[glob_module].com_class_defs.[ds_index]

getClassInstances {glob_module,glob_object={ds_index}} instances = instances.[glob_module].[ds_index]
	
getClassInstance :: !(Global Int) !{# CommonDefs}  -> ClassInstance
getClassInstance {glob_module,glob_object} defs = defs.[glob_module].com_instance_defs.[glob_object]

contextIsReducible :: TypeContext !{#CommonDefs} PredefinedSymbols {!Type} -> Bool
contextIsReducible {tc_class=TCClass class_symb,tc_types = [type : types]} defs predef_symbols subst_array
	# class_fun_dep_vars = defs.[class_symb.glob_module].com_class_defs.[class_symb.glob_object.ds_index].class_fun_dep_vars
	| class_fun_dep_vars==0
		# (type, subst_array) = expandOneStepA type subst_array
		= type_is_reducible type class_symb predef_symbols && types_are_reducible types type class_symb predef_symbols subst_array
		| class_fun_dep_vars bitand 1==0
			# (type, subst_array) = expandOneStepA type subst_array
			= type_is_reducible type class_symb predef_symbols && typesWithFunDepAreReducible types class_symb (class_fun_dep_vars>>1) predef_symbols subst_array
			= typesWithFunDepAreReducible types class_symb (class_fun_dep_vars>>1) predef_symbols subst_array

contextIsReducible tc=:{tc_class=TCGeneric {gtc_class}, tc_types = [type : types]} defs predef_symbols subst_array
	# (type, subst_array) = expandOneStepA type subst_array
	= type_is_reducible type gtc_class predef_symbols && types_are_reducible types type gtc_class predef_symbols subst_array

// isIndirection same as in module type
isIndirection TE	= False
isIndirection type	= True

expandOneStep :: !Type  !u:Subst -> (!Type, !v:Subst), [u <= v]
expandOneStep type=:(TempV tv_number) subst=:{subst_array}
	# (stype, subst_array) = subst_array![tv_number]
	| isIndirection stype
		= expandOneStep stype { subst & subst_array = subst_array }
		= (type,  { subst & subst_array = subst_array })
expandOneStep type=:(TempCV tv_number :@: types)  subst=:{subst_array}
	# (stype, subst_array) = subst_array![tv_number]
	| isIndirection stype
		# (etype, subst) = expandOneStep stype { subst & subst_array = subst_array }
		  (ok, simplified_type) = simplifyAndCheckTypeApplication etype types
		| ok 
			= (simplified_type, subst)
			= (type, subst)
		= (type,  { subst & subst_array = subst_array })
expandOneStep type subst
	= (type, subst)

expandOneStepC :: !Type !*SubstC -> (!Type, !*SubstC)
expandOneStepC type=:(TempV tv_number) subst=:{substc_array}
	# (stype, substc_array) = substc_array![tv_number]
	| isIndirection stype
		= expandOneStepC stype { subst & substc_array = substc_array }
		= (type, {subst & substc_array = substc_array})
expandOneStepC type=:(TempCV tv_number :@: types) subst=:{substc_array}
	# (stype, substc_array) = substc_array![tv_number]
	| isIndirection stype
		# (etype, subst) = expandOneStepC stype {subst & substc_array = substc_array}
		  (ok, simplified_type) = simplifyAndCheckTypeApplication etype types
		| ok 
			= (simplified_type, subst)
			= (type, subst)
		= (type, {subst & substc_array = substc_array})
expandOneStepC type subst
	= (type, subst)

expandOneStepA :: !Type  !u:{!Type} -> (!Type, !v:{!Type}), [u <= v]
expandOneStepA type=:(TempV tv_number) subst_array
	# (stype, subst_array) = subst_array![tv_number]
	| isIndirection stype
		= expandOneStepA stype subst_array
		= (type, subst_array)
expandOneStepA type=:(TempCV tv_number :@: types) subst_array
	# (stype, subst_array) = subst_array![tv_number]
	| isIndirection stype
		# (etype, subst_array) = expandOneStepA stype subst_array
		  (ok, simplified_type) = simplifyAndCheckTypeApplication etype types
		| ok 
			= (simplified_type, subst_array)
			= (type, subst_array)
		= (type, subst_array)
expandOneStepA type subst_array
	= (type, subst_array)

types_are_reducible :: [Type] Type (Global DefinedSymbol) PredefinedSymbols {!Type} -> Bool
types_are_reducible [] _ _ _ _
	= True
types_are_reducible [type : types] first_type tc_class predef_symbols subst_array
	# (type, subst_array) = expandOneStepA type subst_array
	= case type of
		TempV _
			->	is_lazy_or_strict_array_or_list_context
		_ :@: _
			->	is_lazy_or_strict_array_or_list_context
		TempQV _
			->	is_lazy_or_strict_array_or_list_context
		TempQDV _
			->	is_lazy_or_strict_array_or_list_context
		_
			-> is_reducible types tc_class predef_symbols subst_array
where
	is_lazy_or_strict_array_or_list_context
		=>	(is_predefined_symbol tc_class.glob_module tc_class.glob_object.ds_index PD_ArrayClass predef_symbols &&
			is_lazy_or_strict_array_type first_type)
			||
			(is_predefined_symbol tc_class.glob_module tc_class.glob_object.ds_index PD_ListClass predef_symbols &&
			is_lazy_or_strict_list_type first_type)
			||
			(is_predefined_symbol tc_class.glob_module tc_class.glob_object.ds_index PD_MaybeClass predef_symbols &&
			is_lazy_or_strict_maybe_type first_type)

	is_lazy_or_strict_array_type :: Type -> Bool
	is_lazy_or_strict_array_type (TA {type_index={glob_module,glob_object}} _)
		= glob_module==cPredefinedModuleIndex &&
			(glob_object==PD_LazyArrayTypeIndex || glob_object==PD_StrictArrayTypeIndex)
	is_lazy_or_strict_array_type _
		= False

	is_lazy_or_strict_list_type :: Type -> Bool
	is_lazy_or_strict_list_type (TA {type_index={glob_module,glob_object}} _)
		= glob_module==cPredefinedModuleIndex &&
			(glob_object==PD_ListTypeIndex || glob_object==PD_TailStrictListTypeIndex ||
			 glob_object==PD_StrictListTypeIndex || glob_object==PD_StrictTailStrictListTypeIndex ||
			 glob_object==PD_UnboxedListTypeIndex || glob_object==PD_UnboxedTailStrictListTypeIndex)
	is_lazy_or_strict_list_type _
		= False

	is_lazy_or_strict_maybe_type :: Type -> Bool
	is_lazy_or_strict_maybe_type (TA {type_index={glob_module,glob_object}} _)
		= glob_module==cPredefinedModuleIndex &&
			(glob_object==PD_MaybeTypeIndex || glob_object==PD_StrictMaybeTypeIndex || glob_object==PD_UnboxedMaybeTypeIndex)
	is_lazy_or_strict_maybe_type _
		= False

	is_reducible :: [Type] (Global DefinedSymbol) PredefinedSymbols {!Type} -> Bool
	is_reducible [] tc_class predef_symbols subst_array
		= True
	is_reducible [type : types] tc_class predef_symbols subst_array
		# (type, subst_array) = expandOneStepA type subst_array
		= type_is_reducible type tc_class predef_symbols && is_reducible types tc_class predef_symbols subst_array

type_is_reducible :: Type (Global DefinedSymbol) PredefinedSymbols -> Bool
type_is_reducible (TempV _) tc_class predef_symbols
	= False 
type_is_reducible (_ :@: _) tc_class predef_symbols
	= False
type_is_reducible (TempQV _) tc_class predef_symbols
	= False
type_is_reducible (TempQDV _) {glob_object={ds_index},glob_module} predef_symbols
	= is_predefined_symbol glob_module ds_index PD_TypeCodeClass predef_symbols
type_is_reducible _ tc_class predef_symbols
	= True

typesWithFunDepAreReducible :: [Type] (Global DefinedSymbol) BITVECT PredefinedSymbols {!Type} -> Bool
typesWithFunDepAreReducible [type : types] tc_class class_fun_dep_vars predef_symbols subst_array
	| class_fun_dep_vars bitand 1==0
		# (type, subst_array) = expandOneStepA type subst_array
		= type_is_reducible type tc_class predef_symbols && typesWithFunDepAreReducible types tc_class (class_fun_dep_vars>>1) predef_symbols subst_array
		= typesWithFunDepAreReducible types tc_class (class_fun_dep_vars>>1) predef_symbols subst_array
typesWithFunDepAreReducible [] _ _ _ _
	= True

is_predefined_symbol :: !Int !Int !Int !PredefinedSymbols -> Bool
is_predefined_symbol mod_index symb_index predef_index predef_symbols
	# {pds_def,pds_module} = predef_symbols.[predef_index]
	= mod_index == pds_module && symb_index == pds_def

get_specials :: Specials -> [Special]
get_specials (SP_ContextTypes specials) = specials
get_specials SP_None = []
get_specials SP_GenerateRecordInstances = []

freshContexts :: ![TypeContext] !*TypeHeaps -> (![TypeContext],*TypeHeaps)
freshContexts tcs type_heaps
	= mapSt fresh_context tcs type_heaps

fresh_context :: !TypeContext !*TypeHeaps -> (TypeContext,*TypeHeaps)
fresh_context tc=:{tc_types} type_heaps
	# (_, tc_types, type_heaps) = substitute tc_types type_heaps
	= ({ tc & tc_types = tc_types }, type_heaps)

addLocalTCInstance :: Int ([LocalTypePatternVariable], *VarHeap) -> (VarInfoPtr, ([LocalTypePatternVariable], *VarHeap))
addLocalTCInstance var_number (instances=:[inst : insts], ltp_var_heap)
	# cmp = var_number =< inst.ltpv_var
	| cmp == Equal
		= (inst.ltpv_new_var, (instances, ltp_var_heap))
	| cmp == Smaller
		# (ltpv_new_var, ltp_var_heap) = newPtr VI_Empty ltp_var_heap
		= (ltpv_new_var, ( [{ ltpv_new_var = ltpv_new_var, ltpv_var = var_number } : instances ], ltp_var_heap ))
		# (found_var, (insts, ltp_var_heap)) = addLocalTCInstance var_number (insts, ltp_var_heap)
		= (found_var, ([inst : insts ], ltp_var_heap))
addLocalTCInstance var_number ([], ltp_var_heap)
	# (ltpv_new_var, ltp_var_heap) = newPtr VI_Empty ltp_var_heap
	= (ltpv_new_var, ([{ ltpv_new_var = ltpv_new_var, ltpv_var = var_number }], ltp_var_heap))

tryToExpandTypeSyn :: {#CommonDefs} Type TypeSymbIdent [AType] *TypeHeaps -> (Bool, Type, *TypeHeaps)
tryToExpandTypeSyn defs type cons_id=:{type_ident,type_index={glob_object,glob_module}} type_args type_heaps
	# {td_ident,td_rhs,td_args,td_attribute} = defs.[glob_module].com_type_defs.[glob_object]
	= case td_rhs of
		SynType {at_type}
			# (expanded_type, type_heaps) = substituteType td_attribute TA_Multi td_args type_args at_type type_heaps
			-> (True, expanded_type, type_heaps) 
		_
			-> (False, type, type_heaps)

class match type :: !{#CommonDefs} !type !type !*TypeHeaps !*SubstC -> (!Bool, !*TypeHeaps, !*SubstC)

instance match AType
where
	match defs atype1 atype2 type_heaps subst
		= matchTypes defs atype1.at_type atype2.at_type type_heaps subst

expandAndMatch :: TypeSymbIdent [AType] TypeSymbIdent [AType] {#CommonDefs} Type Type *TypeHeaps !*SubstC -> (Bool, *TypeHeaps, !*SubstC)
expandAndMatch cons_id1 cons_args1 cons_id2 cons_args2 defs type1 type2 type_heaps subst
	# (succ1, type1, type_heaps) = tryToExpandTypeSyn defs type1 cons_id1 cons_args1 type_heaps
	# (succ2, type2, type_heaps) = tryToExpandTypeSyn defs type2 cons_id2 cons_args2 type_heaps
	| succ1 || succ2
		= matchTypes defs type1 type2 type_heaps subst
		= (False, type_heaps, subst)

//
// match is not symmetric: the first type is the (formal) instance type, the second type is
// the (actual) expression type.
//

matchTypes :: {#CommonDefs} Type Type !*TypeHeaps !*SubstC -> (!Bool,!*TypeHeaps,!*SubstC)
matchTypes defs type1 type2 type_heaps subst
	# (type2, subst) = expandOneStepC type2 subst
	= match defs type1 type2 type_heaps subst

matchTVandType defs {tv_info_ptr,tv_ident} type2 type_heaps=:{th_vars} subst
	# (tv_info, th_vars) = readPtr tv_info_ptr th_vars
	= case tv_info of
		TVI_Empty
			-> (True,  { type_heaps & th_vars = th_vars <:= (tv_info_ptr, TVI_Type type2)}, subst)
		TVI_Type type1
			# type_heaps & th_vars = th_vars
			-> equateTypes type1 type2 defs type_heaps subst // ---> ("equateTypes",tv_ident.id_name,type1,type2)

instance match Type
where
	match defs (TV tv) type2 type_heaps=:{th_vars} subst
		= matchTVandType defs tv type2 type_heaps subst
	match defs type1=:(TA cons_id1 cons_args1) type2=:(TA cons_id2 cons_args2) type_heaps subst
		| cons_id1 == cons_id2
			= matchListsOfATypes defs cons_args1 cons_args2 type_heaps subst
			= expandAndMatch cons_id1 cons_args1 cons_id2 cons_args2 defs type1 type2 type_heaps subst
	match defs type1=:(TA cons_id1 cons_args1) type2=:(TAS cons_id2 cons_args2 _) type_heaps subst
		| cons_id1 == cons_id2
			= matchListsOfATypes defs cons_args1 cons_args2 type_heaps subst
			= expandAndMatch cons_id1 cons_args1 cons_id2 cons_args2 defs type1 type2 type_heaps subst
	match defs type1=:(TAS cons_id1 cons_args1 _) type2=:(TA cons_id2 cons_args2) type_heaps subst
		| cons_id1 == cons_id2
			= matchListsOfATypes defs cons_args1 cons_args2 type_heaps subst
			= expandAndMatch cons_id1 cons_args1 cons_id2 cons_args2 defs type1 type2 type_heaps subst
	match defs type1=:(TAS cons_id1 cons_args1 _) type2=:(TAS cons_id2 cons_args2 _) type_heaps subst
		| cons_id1 == cons_id2
			= matchListsOfATypes defs cons_args1 cons_args2 type_heaps subst
			= expandAndMatch cons_id1 cons_args1 cons_id2 cons_args2 defs type1 type2 type_heaps subst
	match defs (TB tb1) (TB tb2) type_heaps subst
		= (tb1 == tb2, type_heaps, subst)
	match defs (arg_type1 --> res_type1) (arg_type2 --> res_type2) type_heaps subst
		= matchListsOfATypes defs [arg_type1,res_type1] [arg_type2,res_type2] type_heaps subst
	match defs (cv1 :@: types1) (cv2 :@: types2) type_heaps subst
		# type_heaps = matchConsVariable cv1 cv2 type_heaps
		= matchListsOfATypes defs types1 types2 type_heaps subst
	match defs type1=:(CV tv :@: types) type2=:(TA type_cons cons_args) type_heaps subst
		# (succ2, type2e, type_heaps) = tryToExpandTypeSyn defs type2 type_cons cons_args type_heaps
		| succ2
			= match defs type1 type2e type_heaps subst
			# diff = type_cons.type_arity - length types
			| diff >= 0
				# (matched, type_heaps, subst)
					= matchTVandType defs tv (TA {type_cons & type_arity = diff } (take diff cons_args)) type_heaps subst
				| matched
					= matchListsOfATypes defs types (drop diff cons_args) type_heaps subst
					= (False, type_heaps, subst)
				= (False, type_heaps, subst)
	match defs type1=:(CV tv :@: types) type2=:(TAS type_cons cons_args sl) type_heaps subst
		# (succ2, type2e, type_heaps) = tryToExpandTypeSyn defs type2 type_cons cons_args type_heaps
		| succ2
			= match defs type1 type2e type_heaps subst
			# diff = type_cons.type_arity - length types
			| diff >= 0
				# (matched, type_heaps, subst)
					= matchTVandType defs tv (TAS {type_cons & type_arity = diff } (take diff cons_args) sl) type_heaps subst
				| matched
					= matchListsOfATypes defs types (drop diff cons_args) type_heaps subst
					= (False, type_heaps, subst)
				= (False, type_heaps, subst)
	match defs TArrow TArrow type_heaps subst
		= (True, type_heaps, subst)
	match defs (TArrow1 t1) (TArrow1 t2) type_heaps subst
		= match defs t1 t2 type_heaps subst
	match defs type1=:(TA cons_id cons_args) type2 type_heaps subst
		# (succ, type1, type_heaps) = tryToExpandTypeSyn defs type1 cons_id cons_args type_heaps
		| succ
			= match defs type1 type2 type_heaps subst
			= (False, type_heaps, subst)
	match defs type1=:(TAS cons_id cons_args _) type2 type_heaps subst
		# (succ, type1, type_heaps) = tryToExpandTypeSyn defs type1 cons_id cons_args type_heaps
		| succ
			= match defs type1 type2 type_heaps subst
			= (False, type_heaps, subst)
	match defs type1 type2=:(TA cons_id cons_args) type_heaps subst
		# (succ, type2, type_heaps) = tryToExpandTypeSyn defs type2 cons_id cons_args type_heaps
		| succ
			= match defs type1 type2 type_heaps subst
			= (False, type_heaps, subst)
	match defs type1 type2=:(TAS cons_id cons_args _) type_heaps subst
		# (succ, type2, type_heaps) = tryToExpandTypeSyn defs type2 cons_id cons_args type_heaps
		| succ
			= match defs type1 type2 type_heaps subst
			= (False, type_heaps, subst)
	match defs type1 type2 type_heaps subst
		= (False, type_heaps, subst)

matchListsOfTypes :: {#CommonDefs} [Type] [Type] *TypeHeaps *SubstC -> (!Bool,!*TypeHeaps,!*SubstC)
matchListsOfTypes defs [t1 : ts1] [t2 : ts2] type_heaps subst
	# (matched, type_heaps, subst) = matchTypes defs t1 t2 type_heaps subst
	| matched
		= matchListsOfTypes defs ts1 ts2 type_heaps subst
		= (False, type_heaps, subst)
matchListsOfTypes defs [] [] type_heaps subst
	= (True, type_heaps, subst)

matchListsOfATypes :: {#CommonDefs} [AType] [AType] *TypeHeaps *SubstC -> (!Bool,!*TypeHeaps,!*SubstC)
matchListsOfATypes defs [t1 : ts1] [t2 : ts2] type_heaps subst
	# (matched, type_heaps, subst) = matchTypes defs t1.at_type t2.at_type type_heaps subst
	| matched
		= matchListsOfATypes defs ts1 ts2 type_heaps subst
		= (False, type_heaps, subst)
matchListsOfATypes defs [] [] type_heaps subst
	= (True, type_heaps, subst)

matchConsVariable (CV {tv_info_ptr}) cons_var type_heaps=:{th_vars}
	= { type_heaps & th_vars = th_vars <:= (tv_info_ptr,TVI_Type (consVariableToType cons_var))}

matchListsOfNonFunDepTypes :: {#CommonDefs} [Type] [Type] Int *TypeHeaps *SubstC -> (!Bool,!*TypeHeaps,!*SubstC)
matchListsOfNonFunDepTypes defs [t1 : ts1] [t2 : ts2] fun_dep_vars type_heaps subst
	| fun_dep_vars bitand 1<>0
		= matchListsOfNonFunDepTypes defs ts1 ts2 (fun_dep_vars>>1) type_heaps subst
	# (matched, type_heaps, subst) = matchTypes defs t1 t2 type_heaps subst
	| matched
		= matchListsOfNonFunDepTypes defs ts1 ts2 (fun_dep_vars>>1) type_heaps subst
		= (False, type_heaps, subst)
matchListsOfNonFunDepTypes defs [] [] fun_dep_vars type_heaps subst
	= (True, type_heaps, subst)

matchListsOfFunDepTypes :: {#CommonDefs} [Type] [Type] Int *TypeHeaps *SubstC -> (!Bool,!*TypeHeaps,!*SubstC)
matchListsOfFunDepTypes defs [t1 : ts1] [t2 : ts2] fun_dep_vars type_heaps subst
	| fun_dep_vars bitand 1==0
		= matchListsOfFunDepTypes defs ts1 ts2 (fun_dep_vars>>1) type_heaps subst
	# (matched, type_heaps, subst) = matchFunDepTypes t1 t2 defs type_heaps subst // ---> ("matchFunDepTypes",t1,t2)
	| matched
		= matchListsOfFunDepTypes defs ts1 ts2 (fun_dep_vars>>1) type_heaps subst
		= (False, type_heaps, subst)
matchListsOfFunDepTypes defs [] [] fun_dep_vars type_heaps subst
	= (True, type_heaps, subst)

checkFunDepTypesForPossibleNonTermination :: [Type] [Type] Int [Type] Int *SubstC -> (!Bool,!*SubstC)
checkFunDepTypesForPossibleNonTermination [t1 : ts1] [t2 : ts2] fun_dep_vars context_types all_fun_dep_vars substc
	| fun_dep_vars bitand 1==0
		= checkFunDepTypesForPossibleNonTermination ts1 ts2 (fun_dep_vars>>1) context_types all_fun_dep_vars substc
	# (maybe_non_termination, substc) = checkFunDepTypeForPossibleNonTermination t1 t2 context_types all_fun_dep_vars substc
	| maybe_non_termination
		= (True, substc)
		= checkFunDepTypesForPossibleNonTermination ts1 ts2 (fun_dep_vars>>1) context_types all_fun_dep_vars substc
checkFunDepTypesForPossibleNonTermination [] [] fun_dep_vars context_types all_fun_dep_vars substc
	= (False, substc)

checkFunDepTypeForPossibleNonTermination (TV _) t2 context_types all_fun_dep_vars substc
	= (False,substc)
checkFunDepTypeForPossibleNonTermination instance_type (TempV tv_n) context_types all_fun_dep_vars substc
	# (subst_type,substc) = substc!substc_array.[tv_n]
	= case subst_type of
		TE
			| funDepTypesContainTypeVariable tv_n context_types all_fun_dep_vars substc
				-> (True,substc)
				-> (False,substc)
		TempV tv_n
			-> checkFunDepTypeForPossibleNonTermination instance_type (TempV tv_n) context_types all_fun_dep_vars substc
		_
			-> (False,substc)
checkFunDepTypeForPossibleNonTermination _ _ context_types all_fun_dep_vars substc
	= (False,substc)

funDepTypesContainTypeVariable tv_n [type:types] fun_dep_vars substc
	| fun_dep_vars bitand 1<>0
		= funDepTypesContainTypeVariable tv_n types fun_dep_vars substc
	| containsTypeVariable tv_n type substc.substc_array
		= True
		= funDepTypesContainTypeVariable tv_n types (fun_dep_vars>>1) substc
funDepTypesContainTypeVariable tv_n [] fun_dep_vars substc
	= False

matchFunDepTypes :: Type Type {#CommonDefs} !*TypeHeaps !*SubstC -> (!Bool,!*TypeHeaps,!*SubstC)
matchFunDepTypes instance_type type defs type_heaps subst
	# (type,subst) = expandOneStepC type subst
	= matchExpandedFunDepTypes instance_type type defs type_heaps subst
where
	matchExpandedFunDepTypes :: Type Type {#CommonDefs} *TypeHeaps *SubstC -> (!Bool,!*TypeHeaps,!*SubstC)
	matchExpandedFunDepTypes (TV tv) type defs type_heaps substc
		= matchExpandedFunDepTVandType tv type defs type_heaps substc
	matchExpandedFunDepTypes instance_type (TempV tv_number) defs type_heaps substc
		= matchExpandedFunDepTypeAndTV instance_type tv_number defs type_heaps substc
	matchExpandedFunDepTypes (TempV tv_number) type defs type_heaps substc
		# (instance_type,substc) = substc!substc_array.[tv_number]
		= case instance_type of
			TE
				| containsTypeVariable tv_number type substc.substc_array
					-> (False,type_heaps,substc)
					# substc & substc_array.[tv_number] = type, substc_changes = [#tv_number:substc.substc_changes!]
					-> (True,type_heaps,substc)
			_
				-> matchExpandedFunDepTypes instance_type type defs type_heaps substc
	matchExpandedFunDepTypes (TB tb1) (TB tb2) defs type_heaps substc
		= (tb1==tb2, type_heaps, substc)
	matchExpandedFunDepTypes (TA instance_cons_id instance_cons_args) (TA cons_id cons_args) defs type_heaps substc
		| instance_cons_id==cons_id
			= matchExpandedFunDepListOfATypes instance_cons_args cons_args defs type_heaps substc
	matchExpandedFunDepTypes (TA instance_cons_id instance_cons_args) (TAS cons_id cons_args _) defs type_heaps substc
		| instance_cons_id==cons_id
			= matchExpandedFunDepListOfATypes instance_cons_args cons_args defs type_heaps substc
	matchExpandedFunDepTypes type1=:(TA instance_cons_id instance_cons_args) type2 defs type_heaps substc
		# (succ, type1, type_heaps) = tryToExpandTypeSyn defs type1 instance_cons_id instance_cons_args type_heaps
		| succ
			= matchExpandedFunDepTypes type1 type2 defs type_heaps substc
	matchExpandedFunDepTypes (TAS instance_cons_id instance_cons_args _) (TAS cons_id cons_args _) defs type_heaps substc
		| instance_cons_id==cons_id
			= matchExpandedFunDepListOfATypes instance_cons_args cons_args defs type_heaps substc
	matchExpandedFunDepTypes (TAS instance_cons_id instance_cons_args _) (TA cons_id cons_args) defs type_heaps substc
		| instance_cons_id==cons_id
			= matchExpandedFunDepListOfATypes instance_cons_args cons_args defs type_heaps substc
	matchExpandedFunDepTypes (instance_atype_arg-->instance_atype_res) (atype_arg-->atype_res) defs type_heaps substc
		# (ok,type_heaps,substc) = matchFunDepTypes instance_atype_arg.at_type atype_arg.at_type defs type_heaps substc
		| ok
			= matchFunDepTypes instance_atype_res.at_type atype_res.at_type defs type_heaps substc
			= (False,type_heaps,substc)
	matchExpandedFunDepTypes (cv1 :@: instance_types) (cv2 :@: types) defs type_heaps substc
		# (ok,type_heaps,substc) = matchExpandedFunDepConsVariable cv1 cv2 defs type_heaps substc
		| ok
			= matchExpandedFunDepListOfATypes instance_types types defs type_heaps substc
			= (False,type_heaps,substc);
	matchExpandedFunDepTypes type1=:(CV tv :@: types) type2=:(TA type_cons cons_args) defs type_heaps substc
		# (succ, type2e, type_heaps) = tryToExpandTypeSyn defs type2 type_cons cons_args type_heaps
		| succ
			= matchFunDepTypes type1 type2e defs type_heaps substc
			# diff = type_cons.type_arity - length types
			| diff >= 0
				# (matched, type_heaps, substc)
					= matchExpandedFunDepTVandType tv (TA {type_cons & type_arity = diff} (take diff cons_args)) defs type_heaps substc
				| matched
					= matchExpandedFunDepListOfATypes types (drop diff cons_args) defs type_heaps substc
					= (False, type_heaps, substc)
				= (False, type_heaps, substc)
	matchExpandedFunDepTypes type1=:(CV tv :@: types) type2=:(TAS type_cons cons_args sl) defs type_heaps substc
		# (succ, type2e, type_heaps) = tryToExpandTypeSyn defs type2 type_cons cons_args type_heaps
		| succ
			= matchFunDepTypes type1 type2e defs type_heaps substc
			# diff = type_cons.type_arity - length types
			| diff >= 0
				# (matched, type_heaps, substc)
					= matchExpandedFunDepTVandType tv (TAS {type_cons & type_arity = diff} (take diff cons_args) sl) defs type_heaps substc
				| matched
					= matchExpandedFunDepListOfATypes types (drop diff cons_args) defs type_heaps substc
					= (False, type_heaps, substc)
				= (False, type_heaps, substc)
	matchExpandedFunDepTypes type1 type2=:(TA cons_id cons_args) defs type_heaps substc
		# (succ, type2, type_heaps) = tryToExpandTypeSyn defs type2 cons_id cons_args type_heaps
		| succ
			= matchFunDepTypes type1 type2 defs type_heaps substc
	matchExpandedFunDepTypes type1=:(TA type_cons types1) type2=:(TempCV tv_n :@: types2) defs type_heaps substc
		# (succ, type1e, type_heaps) = tryToExpandTypeSyn defs type1 type_cons types1 type_heaps
		| succ
			= matchExpandedFunDepTypes type1e type2 defs type_heaps substc
			# diff = type_cons.type_arity - length types2
			| diff>=0
				# (matched, type_heaps, substc)
					= matchExpandedFunDepTypeAndTV (TA {type_cons & type_arity=diff} (take diff types1)) tv_n defs type_heaps substc
				| matched
					= matchExpandedFunDepListOfATypes (drop diff types1) types2 defs type_heaps substc
				= (False,type_heaps,substc)
	matchExpandedFunDepTypes (TAS type_cons types1 sl) (TempCV tv_n :@: types2) defs type_heaps substc
		// no tryToExpandTypeSyn necessary for TAS
		# diff = type_cons.type_arity - length types2
		| diff>=0
			# (matched, type_heaps, substc)
				= matchExpandedFunDepTypeAndTV (TAS {type_cons & type_arity=diff} (take diff types1) sl) tv_n defs type_heaps substc
			| matched
				= matchExpandedFunDepListOfATypes (drop diff types1) types2 defs type_heaps substc
			= (False,type_heaps,substc)
	matchExpandedFunDepTypes instance_type type defs type_heaps substc
		= (False,type_heaps,substc) ---> ("matchExpandedFunDepTypes False",instance_type,type)

	matchExpandedFunDepTypeAndTV :: Type Int {#CommonDefs} *TypeHeaps *SubstC -> (!Bool,!*TypeHeaps,!*SubstC)
	matchExpandedFunDepTypeAndTV instance_type tv_number defs type_heaps substc
		# (ok, instance_type, type_heaps, substc) = addNewTypeVarsInSubstFunDepType instance_type defs type_heaps substc
		| ok // && True ---> ("matchExpandedFunDepTypes",tv_number,instance_type)
			| isIndirection substc.substc_array.[tv_number]
				= abort "matchExpandedFunDepTypes TempV" // impossible because expandOneStepC expands the TempV
			| is_var tv_number instance_type substc.substc_array
				= (True,type_heaps,substc)
			// could also do this contains check in addNewTypeVarsInSubstFunDepType
			| containsTypeVariable tv_number instance_type substc.substc_array
				= (False,type_heaps,substc)
				# substc & substc_changes = [#tv_number:substc.substc_changes!], substc_array.[tv_number] = instance_type
				= (True,type_heaps,substc)
			= (False,type_heaps,substc)
		where
			is_var tv_number (TempV tv_number2) subst_array
				= case subst_array.[tv_number2] of
					TE
						-> tv_number2==tv_number
					instance_type
						-> is_var tv_number instance_type subst_array
			is_var tv_number instance_type subst_array
				= False
	
	matchExpandedFunDepTVandType :: TypeVar Type {#CommonDefs} *TypeHeaps *SubstC -> *(!Bool,!*TypeHeaps,!*SubstC)
	matchExpandedFunDepTVandType {tv_info_ptr,tv_ident} type defs type_heaps=:{th_vars} substc
		# (tv_info, th_vars) = readPtr tv_info_ptr th_vars
		= case tv_info of
			TVI_Type instance_type
				# type_heaps & th_vars = th_vars
				-> matchExpandedFunDepTypes instance_type type defs type_heaps substc
			TVI_Empty
				# type_heaps & th_vars = writePtr tv_info_ptr (TVI_Type type) th_vars
				-> (True,type_heaps,substc)
	
	matchExpandedFunDepListOfATypes :: [AType] [AType] {#CommonDefs} *TypeHeaps *SubstC -> (!Bool,!*TypeHeaps,!*SubstC)
	matchExpandedFunDepListOfATypes [instance_cons_arg:instance_cons_args] [cons_arg:cons_args] defs type_heaps substc
		# (ok,type_heaps,substc) = matchFunDepTypes instance_cons_arg.at_type cons_arg.at_type defs type_heaps substc
		| ok
			= matchExpandedFunDepListOfATypes instance_cons_args cons_args defs type_heaps substc
			= (False,type_heaps,substc)
	matchExpandedFunDepListOfATypes [] [] defs type_heaps substc
		= (True,type_heaps,substc)
	
	matchExpandedFunDepConsVariable :: ConsVariable ConsVariable {#CommonDefs} *TypeHeaps *SubstC -> (!Bool,!*TypeHeaps,!*SubstC)
	matchExpandedFunDepConsVariable (CV {tv_info_ptr,tv_ident}) cv2 defs type_heaps=:{th_vars} substc
		# type = consVariableToType cv2
		# (tv_info, th_vars) = readPtr tv_info_ptr th_vars
		= case tv_info of
			TVI_Type instance_type
				# type_heaps & th_vars = th_vars
				-> matchExpandedFunDepTypes instance_type type defs type_heaps substc
			TVI_Empty
				# type_heaps & th_vars = writePtr tv_info_ptr (TVI_Type type) th_vars
				-> (True,type_heaps,substc)

	addNewTypeVarsInSubstFunDepType :: Type {#CommonDefs} *TypeHeaps *SubstC -> *(!Bool,!Type,!*TypeHeaps,!*SubstC)
	addNewTypeVarsInSubstFunDepType (TV tv) defs type_heaps substc
		= addNewTypeVarsInSubstFunDepTV tv type_heaps substc
	addNewTypeVarsInSubstFunDepType type=:(TA cons_id cons_args) defs type_heaps substc
		# (ok, cons_args, type_heaps, substc) = addNewTypeVarsInSubstFunDepTypeArgs cons_args defs type_heaps substc
		= (ok, TA cons_id cons_args, type_heaps, substc)
	addNewTypeVarsInSubstFunDepType type=:(TAS cons_id cons_args strictness) defs type_heaps substc
		# (ok, cons_args, type_heaps, substc) = addNewTypeVarsInSubstFunDepTypeArgs cons_args defs type_heaps substc
		= (ok, TAS cons_id cons_args strictness, type_heaps, substc)
	addNewTypeVarsInSubstFunDepType type=:(TB _) defs type_heaps substc
		= (True, type, type_heaps, substc)
	addNewTypeVarsInSubstFunDepType type=:(arg_atype --> res_atype) defs type_heaps substc
		# (ok, arg_type, type_heaps, substc) = addNewTypeVarsInSubstFunDepType arg_atype.at_type defs type_heaps substc
		| not ok
			= (False, type, type_heaps, substc)
		# (ok, res_type, type_heaps, substc) = addNewTypeVarsInSubstFunDepType res_atype.at_type defs type_heaps substc
		| not ok
			= (False, type, type_heaps, substc)
			= (True, {arg_atype & at_type=arg_type} --> {res_atype & at_type=res_type}, type_heaps, substc)
	addNewTypeVarsInSubstFunDepType type=:(TempV tv_number) defs type_heaps substc
		# (subst_type,substc) = substc!substc_array.[tv_number]
		= case subst_type of
			TE
				-> (True, type, type_heaps, substc)
			_
				-> addNewTypeVarsInSubstFunDepType subst_type defs type_heaps substc
	addNewTypeVarsInSubstFunDepType type=:(CV tv :@: types) defs type_heaps substc
		# (ok, type1, type_heaps, substc) = addNewTypeVarsInSubstFunDepTV tv type_heaps substc
		| not ok
			= (False, type, type_heaps, substc);
		# (ok, types, type_heaps, substc) = addNewTypeVarsInSubstFunDepTypeArgs types defs type_heaps substc
		| not ok
			= (False, type, type_heaps, substc);
		# (ok, simplified_type) = simplifyAndCheckTypeApplication type1 types
		| ok
			= (True, simplified_type, type_heaps, substc)
			= abort "addNewTypeVarsInSubstFunDepType :@:" ---> (type,type1,types)
	addNewTypeVarsInSubstFunDepType type defs type_heaps substc
		= abort "addNewTypeVarsInSubstFunDepType" ---> type

	addNewTypeVarsInSubstFunDepTV :: TypeVar *TypeHeaps *SubstC -> (!Bool,!Type,!*TypeHeaps,!*SubstC)
	addNewTypeVarsInSubstFunDepTV {tv_info_ptr,tv_ident} type_heaps substc
		# (tv_info, th_vars) = readPtr tv_info_ptr type_heaps.th_vars
		  type_heaps & th_vars = th_vars
		// to do ? check if type contains TempV of new substc to prevent cycle
		= case tv_info of
			TVI_Type type
				-> (True, type, type_heaps, substc)
			TVI_Empty
				# (tv_number,substc_array) = usize substc.substc_array
				#! substc_next_var_n = substc.substc_next_var_n
				| substc_next_var_n < tv_number
					# substc & substc_next_var_n = substc_next_var_n+1
					  type = TempV substc_next_var_n
					  type_heaps & th_vars = writePtr tv_info_ptr (TVI_Type type) type_heaps.th_vars
					-> (True, type, type_heaps, substc)
					# substc & substc_next_var_n = substc_next_var_n+1
					#! m = tv_number>>2
					# substc_array = arrayPlusList substc_array [TE \\ i<-[0..m]]
					  substc & substc_array = substc_array
					  type = TempV tv_number
					  type_heaps & th_vars = writePtr tv_info_ptr (TVI_Type type) type_heaps.th_vars
					-> (True, type, type_heaps, substc)
	
	addNewTypeVarsInSubstFunDepTypeArgs :: [AType] {#CommonDefs} *TypeHeaps *SubstC -> (!Bool,![AType],!*TypeHeaps,!*SubstC)
	addNewTypeVarsInSubstFunDepTypeArgs atype_args=:[arg_atype:atype_next_args] defs type_heaps substc
		# (ok, arg_type, type_heaps, substc) = addNewTypeVarsInSubstFunDepType arg_atype.at_type defs type_heaps substc
		| not ok
			= (False, atype_args, type_heaps, substc)
		# (ok, atype_next_args, type_heaps, substc) = addNewTypeVarsInSubstFunDepTypeArgs atype_next_args defs type_heaps substc		
		= (ok, [{arg_atype & at_type=arg_type}:atype_next_args], type_heaps, substc)
	addNewTypeVarsInSubstFunDepTypeArgs [] defs type_heaps substc
		= (True, [], type_heaps, substc)

class equateTypes a :: !a !a !{#CommonDefs} !*TypeHeaps !*SubstC  -> (!Bool, !*TypeHeaps, !*SubstC)

instance equateTypes AType
where
	equateTypes atype1 atype2 defs type_heaps subst = equateTypes atype1.at_type atype2.at_type defs type_heaps subst

getSubstitutedType tv_number subst
	# (stype, subst) = subst![tv_number]
	| isIndirection stype
		= case stype of
			TempV tv_numbers
				-> getSubstitutedType tv_numbers subst
			_	-> (stype, subst)
		= (TempV tv_number, subst)

instance equateTypes Type
where
	equateTypes tv=:(TempV tv_number1) type2 defs type_heaps subst=:{substc_array,substc_changes}
		# (type1s, substc_array) = substc_array![tv_number1]
		| isIndirection type1s
			= equateTypes type1s type2 defs type_heaps {subst & substc_array = substc_array}
			= case type2 of
				TempV tv_number2
					# (type2s, substc_array) = getSubstitutedType tv_number2 substc_array
					-> case type2s of
						TempV tv_number2s
							-> (tv_number1 == tv_number2s, type_heaps, {subst & substc_array = substc_array})
						_
							| containsTypeVariable tv_number1 type2s substc_array
								-> (False, type_heaps, {subst & substc_array=substc_array})
								# subst & substc_changes = [#tv_number1:substc_changes!], substc_array = {substc_array & [tv_number1] = type2s}
								-> (True, type_heaps, subst)
				_
					| containsTypeVariable tv_number1 type2 substc_array
						-> (False, type_heaps, {subst & substc_array=substc_array})
						# subst & substc_changes = [#tv_number1:substc_changes!], substc_array = {substc_array & [tv_number1] = type2}
						-> (True, type_heaps, subst)
	equateTypes type1 (TempV tv_number2) defs type_heaps subst=:{substc_array,substc_changes}
		# (type2s, substc_array) = substc_array![tv_number2]
		| isIndirection type2s
			= equateTypes type1 type2s defs type_heaps {subst & substc_array = substc_array}
		| containsTypeVariable tv_number2 type1 substc_array
			= (False, type_heaps, {subst & substc_array=substc_array})
			# subst & substc_changes = [#tv_number2:substc_changes!], substc_array = {substc_array & [tv_number2] = type1}
			= (True, type_heaps, subst)
	equateTypes type1=:(TA cons_id1 cons_args1) type2=:(TA cons_id2 cons_args2) defs type_heaps subst
		| cons_id1 == cons_id2
			= equateTypes cons_args1 cons_args2 defs type_heaps subst
	equateTypes type1=:(TA cons_id1 cons_args1) type2=:(TAS cons_id2 cons_args2 _) defs type_heaps subst
		| cons_id1 == cons_id2
			= equateTypes cons_args1 cons_args2 defs type_heaps subst
	equateTypes type1=:(TA cons_id1 cons_args1) type2 defs type_heaps subst
		# (succ, type1, type_heaps) = tryToExpandTypeSyn defs type1 cons_id1 cons_args1 type_heaps
		| succ
			= equateTypes type1 type2 defs type_heaps subst
	equateTypes type1=:(TAS cons_id1 cons_args1 _) type2=:(TA cons_id2 cons_args2) defs type_heaps subst
		| cons_id1 == cons_id2
			= equateTypes cons_args1 cons_args2 defs type_heaps subst
	equateTypes type1=:(TAS cons_id1 cons_args1 _) type2=:(TAS cons_id2 cons_args2 _) defs type_heaps subst
		| cons_id1 == cons_id2
			= equateTypes cons_args1 cons_args2 defs type_heaps subst
	equateTypes (TB tb1) (TB tb2) defs type_heaps subst
		= (tb1 == tb2, type_heaps, subst)
	equateTypes (arg_type1 --> res_type1) (arg_type2 --> res_type2) defs type_heaps subst
		= equateTypes (arg_type1,res_type1) (arg_type2,res_type2) defs type_heaps subst
	equateTypes (TempCV tv_n1 :@: types1) (TempCV tv_n2 :@: types2) defs type_heaps subst
		# (succ, type_heaps, subst) = equate_type_vars1 tv_n1 tv_n2 defs type_heaps subst
		| succ
			= equateTypes types1 types2 defs type_heaps subst
			= (False, type_heaps, subst)
	equateTypes type1=:(TempCV tv_n :@: types) type2=:(TA type_cons cons_args) defs type_heaps subst
		# (succ, type2e, type_heaps) = tryToExpandTypeSyn defs type2 type_cons cons_args type_heaps
		| succ
			= equateTypes type1 type2e defs type_heaps subst
			# diff = type_cons.type_arity - length types
			| diff >= 0
				= equateTypes (TempV tv_n, types) (TA {type_cons & type_arity = diff} (take diff cons_args), drop diff cons_args) defs type_heaps subst
				= (False, type_heaps, subst)
	equateTypes type1=:(TempCV tv_n :@: types) type2=:(TAS type_cons cons_args sl) defs type_heaps subst
		# (succ, type2e, type_heaps) = tryToExpandTypeSyn defs type2 type_cons cons_args type_heaps
		| succ
			= equateTypes type1 type2e defs type_heaps subst
			# diff = type_cons.type_arity - length types
			| diff >= 0
				= equateTypes (TempV tv_n, types) (TAS {type_cons & type_arity = diff} (take diff cons_args) sl, drop diff cons_args) defs type_heaps subst
				= (False, type_heaps, subst)
	equateTypes type1 type2=:(TA cons_id2 cons_args2) defs type_heaps subst
		# (succ, type2, type_heaps) = tryToExpandTypeSyn defs type2 cons_id2 cons_args2 type_heaps
		| succ
			= equateTypes type1 type2 defs type_heaps subst
	equateTypes TArrow TArrow defs type_heaps subst
		= (True, type_heaps, subst)
	equateTypes (TArrow1 t1) (TArrow1 t2) defs type_heaps subst
		= equateTypes t1 t2 defs type_heaps subst
	equateTypes type1 type2 defs type_heaps subst
		= (False, type_heaps, subst)

equate_type_vars1 :: !Int !Int !{#CommonDefs} !*TypeHeaps !*SubstC -> (!Bool,!*TypeHeaps,!*SubstC)
equate_type_vars1 tv_n1 tv_n2 defs type_heaps subst=:{substc_array,substc_changes}
	| tv_n1==tv_n2
		= (True, type_heaps, subst)
	# (type1s, substc_array) = substc_array![tv_n1]
	= case type1s of
		TempV tv_n1
			-> equate_type_vars1 tv_n1 tv_n2 defs type_heaps {subst & substc_array = substc_array}
		TE
			# (type2s, substc_array) = getSubstitutedType tv_n2 substc_array
			-> case type2s of
				TempV tv_n2
					-> (tv_n1 == tv_n2, type_heaps, {subst & substc_array = substc_array})
				_
					| containsTypeVariable tv_n1 type2s substc_array
						-> (False, type_heaps, {subst & substc_array=substc_array})
						# subst & substc_changes = [#tv_n1:substc_changes!], substc_array = {substc_array & [tv_n1] = type2s}
						-> (True, type_heaps, subst)
		_	-> equate_type_vars2 type1s tv_n2 defs type_heaps {subst & substc_array = substc_array}

equate_type_vars2 :: !Type !Int !{#CommonDefs} !*TypeHeaps !*SubstC -> (!Bool,!*TypeHeaps,!*SubstC)
equate_type_vars2 type1 tv_n2 defs type_heaps subst=:{substc_array,substc_changes}
	# (type2s, substc_array) = substc_array![tv_n2]
	= case type2s of
		TE
			| containsTypeVariable tv_n2 type1 substc_array
				-> (False, type_heaps, {subst & substc_array=substc_array})
				# subst & substc_changes = [#tv_n2:substc_changes!], substc_array = {substc_array & [tv_n2] = type1}
				-> (True, type_heaps, subst)
		TempV tv2
			-> equate_type_vars2 type1 tv_n2 defs type_heaps {subst & substc_array = substc_array}
		_	-> equateTypes type1 type2s defs type_heaps {subst & substc_array = substc_array}

instance equateTypes (!a,!b) | equateTypes a & equateTypes b
where
	equateTypes (x1,y1) (x2,y2) defs type_heaps subst
		# (succ, type_heaps, subst) = equateTypes x1 x2 defs type_heaps subst
		| succ
			= equateTypes y1 y2 defs type_heaps subst
			= (False, type_heaps, subst)
			
instance equateTypes [a] | equateTypes a
where
	equateTypes [t1 : ts1] [t2 : ts2] defs type_heaps subst
		= equateTypes (t1,ts1) (t2,ts2) defs type_heaps subst
	equateTypes [] [] defs type_heaps subst
		= (True, type_heaps, subst)

consVariableToType (TempCV temp_var_id)
	= TempV temp_var_id
consVariableToType (TempQCV temp_var_id)
	= TempQV temp_var_id
consVariableToType (TempQCDV temp_var_id)
	= TempQDV temp_var_id

class bindAndAdjustAttrs type ::  !{# CommonDefs} !type !type !*TypeHeaps !*Coercions -> (!Bool, !*TypeHeaps, !*Coercions)

instance bindAndAdjustAttrs AType
where
	bindAndAdjustAttrs defs atype1 atype2 type_heaps coercion_env
		# (uni_ok,type_heaps,coercion_env) = adjust_attribute atype1.at_attribute atype2.at_attribute type_heaps coercion_env
		| uni_ok		
			= bindAndAdjustAttrs defs atype1.at_type atype2.at_type type_heaps coercion_env
			= (False, type_heaps, coercion_env)
	where
		// first attribute is attribute from instance type
		adjust_attribute :: !TypeAttribute !TypeAttribute !*TypeHeaps !*Coercions -> (!Bool, !*TypeHeaps, !*Coercions)
		adjust_attribute (TA_Var {av_info_ptr}) attr2 type_heaps coercion_env
			# (av_info,th_attrs) = readPtr av_info_ptr type_heaps.th_attrs
			= case av_info of
				AVI_Empty
					# type_heaps & th_attrs=writePtr av_info_ptr (AVI_Attr attr2) th_attrs
					-> (True,type_heaps,coercion_env)
				AVI_Attr var_attr
					# type_heaps & th_attrs=th_attrs
					-> case var_attr of
						TA_Unique
							-> adjust_attribute TA_Unique attr2 type_heaps coercion_env
						TA_Multi
							-> adjust_attribute TA_Multi attr2 type_heaps coercion_env
						TA_TempVar av_number
							-> case attr2 of
							TA_Unique
								# (ok,coercion_env) = tryToMakeUnique av_number coercion_env
								| ok
									# type_heaps & th_attrs=writePtr av_info_ptr (AVI_Attr TA_Unique) type_heaps.th_attrs
									-> (ok,type_heaps,coercion_env)									
									-> (ok,type_heaps,coercion_env)									
							TA_Multi
								# (ok,coercion_env) = tryToMakeNonUnique av_number coercion_env
								| ok
									# type_heaps & th_attrs=writePtr av_info_ptr (AVI_Attr TA_Multi) type_heaps.th_attrs
									-> (ok,type_heaps,coercion_env)									
									-> (ok,type_heaps,coercion_env)									
							TA_TempVar av_number2
							  	# (ok,coercion_env) = equalize_attribute_vars av_number av_number2 coercion_env
								-> (ok,type_heaps,coercion_env)
							_
								-> (True,type_heaps,coercion_env)
						_
							-> (True,type_heaps,coercion_env)
		adjust_attribute TA_Unique attr2 type_heaps coercion_env
			= case attr2 of
				TA_Unique
					-> (True,type_heaps,coercion_env)
				TA_TempVar av_number
					# (ok,coercion_env) = tryToMakeUnique av_number coercion_env
					-> (ok,type_heaps,coercion_env)
				_
					-> (False,type_heaps,coercion_env)
		adjust_attribute attr1 attr2 type_heaps coercion_env
			= case attr2 of
				TA_Multi
					-> (True,type_heaps,coercion_env)
				TA_TempVar av_number
					# (ok,coercion_env) = tryToMakeNonUnique av_number coercion_env
					-> (ok,type_heaps,coercion_env)
				_
					-> (False,type_heaps,coercion_env)

//
// match is not symmetric: the first type is the (formal) instance type, the second type is
// the (actual) expression type.
//

instance bindAndAdjustAttrs Type
where
	bindAndAdjustAttrs defs (TV {tv_info_ptr}) type2 type_heaps=:{th_vars} coercion_env
		# (type_info, th_vars) = readPtr tv_info_ptr th_vars
		= case type_info of
			TVI_Empty
				# type_heaps & th_vars = writePtr tv_info_ptr (TVI_Type type2) th_vars
				-> (True, type_heaps, coercion_env)
			TVI_Type type1
				# type_heaps & th_vars = th_vars
				-> equalize_type_attributes type1 type2 defs type_heaps coercion_env
	bindAndAdjustAttrs defs type1=:(TA cons_id1 cons_args1) type2=:(TA cons_id2 cons_args2) type_heaps coercion_env
		| cons_id1 == cons_id2
			= bindListsOfTypes defs cons_args1 cons_args2 type_heaps coercion_env
			= expand_and_bind cons_id1 cons_args1 cons_id2 cons_args2 defs type1 type2 type_heaps coercion_env
	bindAndAdjustAttrs defs type1=:(TA cons_id1 cons_args1) type2=:(TAS cons_id2 cons_args2 _) type_heaps coercion_env
		| cons_id1 == cons_id2
			= bindListsOfTypes defs cons_args1 cons_args2 type_heaps coercion_env
			= expand_and_bind cons_id1 cons_args1 cons_id2 cons_args2 defs type1 type2 type_heaps coercion_env
	bindAndAdjustAttrs defs type1=:(TAS cons_id1 cons_args1 _) type2=:(TA cons_id2 cons_args2) type_heaps coercion_env
		| cons_id1 == cons_id2
			= bindListsOfTypes defs cons_args1 cons_args2 type_heaps coercion_env
			= expand_and_bind cons_id1 cons_args1 cons_id2 cons_args2 defs type1 type2 type_heaps coercion_env
	bindAndAdjustAttrs defs type1=:(TAS cons_id1 cons_args1 _) type2=:(TAS cons_id2 cons_args2 _) type_heaps coercion_env
		| cons_id1 == cons_id2
			= bindListsOfTypes defs cons_args1 cons_args2 type_heaps coercion_env
			= expand_and_bind cons_id1 cons_args1 cons_id2 cons_args2 defs type1 type2 type_heaps coercion_env
	bindAndAdjustAttrs defs (arg_type1 --> res_type1) (arg_type2 --> res_type2) type_heaps coercion_env
		= bindListsOfTypes defs [arg_type1,res_type1] [arg_type2,res_type2] type_heaps coercion_env
	bindAndAdjustAttrs defs (CV {tv_info_ptr} :@: types1) (cv2 :@: types2) type_heaps=:{th_vars} coercion_env
		# type_heaps = { type_heaps & th_vars = th_vars <:= (tv_info_ptr, TVI_Type (consVariableToType cv2))}
		= bindListsOfTypes defs types1 types2 type_heaps coercion_env
	bindAndAdjustAttrs defs (CV {tv_info_ptr} :@: types) (TA type_cons cons_args) type_heaps=:{th_vars} coercion_env
		# diff = type_cons.type_arity - length types
		| diff >= 0
			# tv_type = TA { type_cons & type_arity = diff } (take diff cons_args)
			= bindListsOfTypes defs types (drop diff cons_args)  { type_heaps & th_vars = th_vars <:= (tv_info_ptr,TVI_Type tv_type)} coercion_env
			= abort "bindAndAdjustAttrs<Type>: incompatible types (5)"
	bindAndAdjustAttrs defs (CV {tv_info_ptr} :@: types) (TAS type_cons cons_args _) type_heaps=:{th_vars} coercion_env
		# diff = type_cons.type_arity - length types
		| diff >= 0
			# tv_type = TA { type_cons & type_arity = diff } (take diff cons_args)
			= bindListsOfTypes defs types (drop diff cons_args)  { type_heaps & th_vars = th_vars <:= (tv_info_ptr,TVI_Type tv_type)} coercion_env
			= abort "bindAndAdjustAttrs<Type>: incompatible types (6)"
	bindAndAdjustAttrs defs (TB tb1) (TB tb2) type_heaps coercion_env
		| tb1 == tb2
			= (True, type_heaps,  coercion_env)		
			= abort "bindAndAdjustAttrs<Type>: incompatible types (7)"
	bindAndAdjustAttrs defs TArrow TArrow type_heaps coercion_env
		= (True, type_heaps,  coercion_env)
	bindAndAdjustAttrs defs (TArrow1 t1) (TArrow1 t2) type_heaps coercion_env
		= bindAndAdjustAttrs defs t1 t2 type_heaps coercion_env
	bindAndAdjustAttrs defs type1=:(TA cons_id cons_args) type2 type_heaps coercion_env
		# (succ, type1, type_heaps) = tryToExpandTypeSyn defs type1 cons_id cons_args type_heaps
		| succ
			= bindAndAdjustAttrs defs type1 type2 type_heaps coercion_env
			= abort "bindAndAdjustAttrs<Type>: incompatible types (1)" ---> (type1,type2)
	bindAndAdjustAttrs defs type1=:(TAS cons_id cons_args _) type2 type_heaps coercion_env
		# (succ, type1, type_heaps) = tryToExpandTypeSyn defs type1 cons_id cons_args type_heaps
		| succ
			= bindAndAdjustAttrs defs type1 type2 type_heaps coercion_env
			= abort "bindAndAdjustAttrs<Type>: incompatible types (2)"
	bindAndAdjustAttrs defs type1 type2=:(TA cons_id cons_args) type_heaps coercion_env
		# (succ, type2, type_heaps) = tryToExpandTypeSyn defs type2 cons_id cons_args type_heaps
		| succ
			= bindAndAdjustAttrs defs type1 type2 type_heaps coercion_env
			= abort "bindAndAdjustAttrs<Type>: incompatible types (3)"
	bindAndAdjustAttrs defs type1 type2=:(TAS cons_id cons_args _) type_heaps coercion_env
		# (succ, type2, type_heaps) = tryToExpandTypeSyn defs type2 cons_id cons_args type_heaps
		| succ
			= bindAndAdjustAttrs defs type1 type2 type_heaps coercion_env
			= abort "bindAndAdjustAttrs<Type>: incompatible types (8)"
	bindAndAdjustAttrs defs type1 type2 type_heaps coercion_env
		= abort "bindAndAdjustAttrs<Type>: incompatible types (4)"

expand_and_bind :: TypeSymbIdent [AType] TypeSymbIdent [AType] {#CommonDefs} Type Type *TypeHeaps !*Coercions -> (!Bool, !*TypeHeaps, !*Coercions)
expand_and_bind cons_id1 cons_args1 cons_id2 cons_args2 defs type1 type2 type_heaps coercion_env
	# (succ1, type1, type_heaps) = tryToExpandTypeSyn defs type1 cons_id1 cons_args1 type_heaps
	# (succ2, type2, type_heaps) = tryToExpandTypeSyn defs type2 cons_id2 cons_args2 type_heaps
	| succ1 || succ2
		= bindAndAdjustAttrs defs type1 type2 type_heaps coercion_env		
		= abort "expand_and_bind: could not expand type synonyms"

bindListsOfTypes :: !{#CommonDefs} ![a] ![a] !*TypeHeaps !*Coercions -> (!Bool,!*TypeHeaps,!*Coercions) | bindAndAdjustAttrs a
bindListsOfTypes defs [t1 : ts1] [t2 : ts2] type_heaps coercion_env
	# (uni_ok, type_heaps, coercion_env) = bindAndAdjustAttrs defs t1 t2 type_heaps coercion_env
	| uni_ok
		= bindListsOfTypes defs ts1 ts2 type_heaps coercion_env
		= (False, type_heaps, coercion_env)
bindListsOfTypes defs [] [] type_heaps coercion_env
		= (True, type_heaps, coercion_env)

// compare_instance_root_types and compare_fun_dep_instance_root_types are not symmetric:
// the first type is the (formal) instance type, the second type is the (actual) expression type.

compare_instance_root_types :: ![Type] ![Type] !{#CommonDefs} !*TypeHeaps !*SubstC -> (!CompareValue,!*TypeHeaps,!*SubstC)
compare_instance_root_types [t1 : ts1] [t2 : ts2] defs type_heaps subst
	# (compare_value, type_heaps, subst) = compare_root_types t1 t2 defs type_heaps subst
	| compare_value==Equal
		= compare_instance_root_types ts1 ts2 defs type_heaps subst
		= (compare_value, type_heaps, subst)
compare_instance_root_types [] [] defs type_heaps subst
	= (Equal, type_heaps, subst)

compare_fun_dep_instance_root_types :: ![Type] ![Type] !BITVECT !{#CommonDefs} !*TypeHeaps !*SubstC -> (!CompareValue,!*TypeHeaps,!*SubstC)
compare_fun_dep_instance_root_types [t1 : ts1] [t2 : ts2] class_fun_dep_vars defs type_heaps subst
	| class_fun_dep_vars bitand 1==0
		# (compare_value, type_heaps, subst) = compare_root_types t1 t2 defs type_heaps subst
		| compare_value==Equal
			= compare_fun_dep_instance_root_types ts1 ts2 (class_fun_dep_vars>>1) defs type_heaps subst
			= (compare_value, type_heaps, subst)
		= compare_fun_dep_instance_root_types ts1 ts2 (class_fun_dep_vars>>1) defs type_heaps subst
compare_fun_dep_instance_root_types [] [] class_fun_dep_vars defs type_heaps subst
	= (Equal, type_heaps, subst)

compare_root_types :: !Type !Type !{#CommonDefs} !*TypeHeaps !*SubstC -> (!Int,!*TypeHeaps,!*SubstC)
compare_root_types type1 type2 defs type_heaps subst
	# (type2, subst) = expandOneStepC type2 subst
	= compare_root_types_after_expand type1 type2 defs type_heaps subst

compare_root_types_after_expand :: !Type !Type !{#CommonDefs} !*TypeHeaps !*SubstC -> (!Int,!*TypeHeaps,!*SubstC)
compare_root_types_after_expand type1=:(TA {type_index=type_index1} cons_args1) type2=:(TA {type_index=type_index2} cons_args2) defs type_heaps subst
	#! {td_rhs,td_args,td_attribute} = defs.[type_index1.glob_module].com_type_defs.[type_index1.glob_object]
	| td_rhs=:SynType _
		= compare_root_types_syn_type1 td_rhs td_args td_attribute cons_args1 type2 defs type_heaps subst
	#! {td_rhs,td_args} = defs.[type_index2.glob_module].com_type_defs.[type_index2.glob_object]
	| td_rhs=:SynType _
		= compare_root_types_syn_type2 type1 td_rhs td_args td_attribute cons_args2 defs type_heaps subst
		#! compare_value = compare_root_types_TAs type_index1 cons_args1 type_index2 cons_args2
		= (compare_value,type_heaps,subst)
compare_root_types_after_expand (TA {type_index=type_index1} cons_args1) type2=:(TAS {type_index=type_index2} cons_args2 _) defs type_heaps subst
	#! {td_rhs,td_args,td_attribute} = defs.[type_index1.glob_module].com_type_defs.[type_index1.glob_object]
	| td_rhs=:SynType _
		= compare_root_types_syn_type1 td_rhs td_args td_attribute cons_args1 type2 defs type_heaps subst
		#! compare_value = compare_root_types_TAs type_index1 cons_args1 type_index2 cons_args2
		= (compare_value,type_heaps,subst)
compare_root_types_after_expand (TA {type_index=type_index1} cons_args1) type2 defs type_heaps subst
	#! {td_rhs,td_args,td_attribute} = defs.[type_index1.glob_module].com_type_defs.[type_index1.glob_object]
	| td_rhs=:SynType _
		= compare_root_types_syn_type1 td_rhs td_args td_attribute cons_args1 type2 defs type_heaps subst
		= (Smaller,type_heaps,subst)
compare_root_types_after_expand (TAS {type_index=type_index1} cons_args1 _) (TAS {type_index=type_index2} cons_args2 _) defs type_heaps subst
	#! compare_value = compare_root_types_TAs type_index1 cons_args1 type_index2 cons_args2
	= (compare_value,type_heaps,subst)
compare_root_types_after_expand type1=:(TAS {type_index=type_index1} cons_args1 _) (TA {type_index=type_index2} cons_args2) defs type_heaps subst
	#! {td_rhs,td_args,td_attribute} = defs.[type_index2.glob_module].com_type_defs.[type_index2.glob_object]
	| td_rhs=:SynType _
		= compare_root_types_syn_type2 type1 td_rhs td_args td_attribute cons_args2 defs type_heaps subst
		#! compare_value = compare_root_types_TAs type_index1 cons_args1 type_index2 cons_args2
		= (compare_value,type_heaps,subst)
compare_root_types_after_expand type1 (TA {type_index=type_index2} cons_args2) defs type_heaps subst
	#! {td_rhs,td_args,td_attribute} = defs.[type_index2.glob_module].com_type_defs.[type_index2.glob_object]
	| td_rhs=:SynType _
		= compare_root_types_syn_type2 type1 td_rhs td_args td_attribute cons_args2 defs type_heaps subst
		= (Greater,type_heaps,subst)
compare_root_types_after_expand (TB type1) (TB type2) defs type_heaps subst
	| equal_constructor type1 type2
		= (Equal,type_heaps,subst)
	| less_constructor type1 type2
		= (Smaller,type_heaps,subst)
		= (Greater,type_heaps,subst)
compare_root_types_after_expand type1 type2 defs type_heaps subst
	| equal_constructor type1 type2
		= (Equal,type_heaps,subst)
	| less_constructor type1 type2
		= (Smaller,type_heaps,subst)
		= (Greater,type_heaps,subst)

compare_root_types_syn_type1 (SynType {at_type=type1=:TV _}) td_args td_attribute args1 type2 defs type_heaps subst
	# (expanded_type, type_heaps) = substituteType td_attribute TA_Multi td_args args1 type1 type_heaps
	= compare_root_types expanded_type type2 defs type_heaps subst
compare_root_types_syn_type1 (SynType {at_type=type1=:(CV _ :@: _)}) td_args td_attribute args1 type2 defs type_heaps subst
	# (expanded_type, type_heaps) = substituteType td_attribute TA_Multi td_args args1 type1 type_heaps
	= compare_root_types expanded_type type2 defs type_heaps subst
compare_root_types_syn_type1 (SynType {at_type=type1}) td_args td_attribute args1 type2 defs type_heaps subst
	= compare_root_types type1 type2 defs type_heaps subst

compare_root_types_syn_type2 type1 (SynType {at_type=type2=:TV _}) td_args td_attribute args2 defs type_heaps subst
	# (expanded_type, type_heaps) = substituteType td_attribute TA_Multi td_args args2 type2 type_heaps
	# (expanded_type, subst) = expandOneStepC expanded_type subst
	= compare_root_types type1 expanded_type defs type_heaps subst
compare_root_types_syn_type2 type1 (SynType {at_type=type2=:(CV _ :@: _)}) td_args td_attribute args2 defs type_heaps subst
	# (expanded_type, type_heaps) = substituteType td_attribute TA_Multi td_args args2 type2 type_heaps
	# (expanded_type, subst) = expandOneStepC expanded_type subst
	= compare_root_types type1 expanded_type defs type_heaps subst
compare_root_types_syn_type2 type1 (SynType {at_type=type2}) td_args td_attribute args2 defs type_heaps subst
	= compare_root_types type1 type2 defs type_heaps subst

compare_root_types_TAs :: !(Global Int) ![AType] !(Global Int) ![AType] -> CompareValue
compare_root_types_TAs type_index1 args1 type_index2 args2
	| type_index1.glob_module==type_index2.glob_module
		| type_index1.glob_object==type_index2.glob_object
			# n_args1 = length args1
			# n_args2 = length args1
			| n_args1==n_args2
				= Equal
			| n_args1<n_args2
				= Smaller
				= Greater
		| type_index1.glob_object<type_index2.glob_object
			= Smaller
			= Greater
	| type_index1.glob_module<type_index2.glob_module
		= Smaller
		= Greater

trySpecializedInstances :: [TypeContext] [Special] *TypeHeaps !*Subst -> (!Global Index, !*TypeHeaps, !*Subst)
trySpecializedInstances type_contexts [] type_heaps subst
	= (ObjectNotFound, type_heaps, subst)
trySpecializedInstances type_contexts specials type_heaps=:{th_vars} subst
	# (spec_index, th_vars, subst) = try_specialized_instances (map (\{tc_types} -> tc_types) type_contexts) specials th_vars subst
	= (spec_index, { type_heaps & th_vars = th_vars }, subst)
where
	try_specialized_instances :: [[Type]] [Special] *TypeVarHeap !*Subst -> (!Global Index, !*TypeVarHeap, !*Subst)
	try_specialized_instances type_contexts_types [{spec_index,spec_vars,spec_types} : specials] type_var_heap subst
		# type_var_heap = foldSt (\tv -> writePtr tv.tv_info_ptr TVI_Empty) spec_vars type_var_heap
		  (equ, type_var_heap, subst) = specialized_context_matches spec_types type_contexts_types type_var_heap subst
		| equ
			= (spec_index, type_var_heap, subst)
			= try_specialized_instances type_contexts_types specials type_var_heap subst
	try_specialized_instances type_contexts_types [] type_var_heap subst
		= (ObjectNotFound, type_var_heap, subst)

	specialized_context_matches :: [[Type]] ![[Type]] *TypeVarHeap !*Subst -> (!.Bool, !*TypeVarHeap, !*Subst)
	specialized_context_matches [spec_context_types:spec_contexts_types] [type_context_types:type_contexts_types] type_var_heap subst
		# (equal,type_var_heap, subst) = specialized_types_in_context_match spec_context_types type_context_types type_var_heap subst
		|  equal
			= specialized_context_matches spec_contexts_types type_contexts_types type_var_heap subst
			= (False, type_var_heap, subst)
	specialized_context_matches [] [] type_var_heap subst
		= (True, type_var_heap, subst)
	specialized_context_matches _ _ type_var_heap subst
		= (False, type_var_heap, subst)

	specialized_types_in_context_match :: [Type] ![Type] *TypeVarHeap !*Subst -> (!Bool, !*TypeVarHeap, !*Subst)
	specialized_types_in_context_match [TV _:spec_context_types] [_:type_context_types] type_var_heap subst
		// special case for type var in lazy or strict Array or List context
		// only these typevars are accepted by function checkAndCollectTypesOfContextsOfSpecials in check
		= specialized_types_in_context_match spec_context_types type_context_types type_var_heap subst
	specialized_types_in_context_match [spec_context_type:spec_context_types] [type_context_type:type_context_types] type_var_heap subst
		# (equal, type_var_heap, subst) = expandAndCompareTypes spec_context_type type_context_type type_var_heap subst
		|  equal
			= specialized_types_in_context_match spec_context_types type_context_types type_var_heap subst
			= (False, type_var_heap, subst)
	specialized_types_in_context_match [] [] type_var_heap subst
		= (True, type_var_heap, subst)
	specialized_types_in_context_match _ _ type_var_heap subst
		= (False, type_var_heap, subst)

startContextReduction :: ![OverloadedExpressions] ![[TypeContext]] !{# CommonDefs } !ClassInstanceInfo 
	!*VarHeap !*TypeHeaps !*ExpressionHeap !*PredefinedSymbols !*{!Type} !*ErrorAdmin
	-> (![ReducedOverloadedContext], ![ExprInfoPtr], !*VarHeap, !*TypeHeaps, !*ExpressionHeap, !*PredefinedSymbols, !*{!Type}, !*ErrorAdmin)
startContextReduction over_exprs specified_contexts_list defs instance_info prs_var_heap prs_type_heaps expr_heap prs_predef_symbols subst prs_error
	#! subst_next_var_n = size subst
	# prs_state = { prs_var_heap = prs_var_heap, prs_type_heaps = prs_type_heaps, prs_predef_symbols = prs_predef_symbols, prs_error = prs_error,
					prs_subst = {subst_changed = False, subst_array = subst, subst_next_var_n = subst_next_var_n,
								 subst_previous_context_n = -1, subst_context_n_at_last_update = -1}}
	  ri_info  = {ri_defs = defs, ri_instance_info = instance_info}
	# (rcss, case_with_context_ptrs, expr_heap, prs_state) = foldSt (try_to_reduce_contexts_in_function ri_info) over_exprs ([], [], expr_heap, prs_state)
	# (rcss, {prs_var_heap, prs_type_heaps, prs_predef_symbols, prs_error, prs_subst}) = iterate_cr ri_info rcss prs_state
	# dts_subst = {prs_subst & subst_changed = True}
	# dts_contexts = flatten specified_contexts_list
	# dts_state
		= {dts_contexts=dts_contexts, dts_subst=dts_subst, dts_var_heap=prs_var_heap, dts_type_heaps=prs_type_heaps, dts_error=prs_error}
	# (predef_symbols, {dts_contexts,dts_subst,dts_var_heap,dts_type_heaps,dts_error})
		= iterate_improve_dep_types_and_reduce rcss ri_info prs_predef_symbols dts_state
	= (rcss, case_with_context_ptrs, dts_var_heap, dts_type_heaps, expr_heap, predef_symbols, dts_subst.subst_array, dts_error)
where
	try_to_reduce_contexts_in_function ri_info {oe_expr_ptrs,oe_fun_index} rcss_case_with_context_ptrs_expr_heap_prs_state
		= foldSt (try_to_reduce_contexts_of_application oe_fun_index ri_info) oe_expr_ptrs rcss_case_with_context_ptrs_expr_heap_prs_state

	try_to_reduce_contexts_of_application fun_index ri_info over_info_ptr (rcss, case_with_context_ptrs, expr_heap,
			prs_state=:{prs_type_heaps,prs_var_heap,prs_subst,prs_predef_symbols})
		= case readPtr over_info_ptr expr_heap of
			(EI_Overloaded {oc_symbol,oc_context,oc_specials},expr_heap)
				# (glob_fun, prs_type_heaps, prs_subst) = trySpecializedInstances oc_context oc_specials prs_type_heaps prs_subst
				| FoundObject glob_fun
					# over_info = EI_Instance {glob_module = glob_fun.glob_module,
									glob_object = {ds_ident = oc_symbol.symb_ident, ds_arity = 0, ds_index = glob_fun.glob_object}} []
					# expr_heap = expr_heap <:= (over_info_ptr, over_info)
					-> (rcss, case_with_context_ptrs, expr_heap, { prs_state & prs_type_heaps = prs_type_heaps, prs_subst = prs_subst })
					# rdla = {rdla_depth = -1, rdla_previous_context=NoPreviousContext}
					  (rcs, prs_state) = tryToReduceContexts ri_info oc_context rdla {prs_state & prs_type_heaps = prs_type_heaps, prs_subst = prs_subst}
					  roc = {roc_fun_index = fun_index, roc_expr_ptr = over_info_ptr, roc_rcs = rcs}
					-> ([roc:rcss], case_with_context_ptrs, expr_heap, prs_state)
			(EI_OverloadedWithVarContexts {ocvc_symbol,ocvc_context,ocvc_var_contexts},expr_heap)
				# rdla = {rdla_depth = -1, rdla_previous_context=NoPreviousContext}
				  (rcs, prs_state) = tryToReduceContexts ri_info ocvc_context rdla prs_state
				  roc = {roc_fun_index = fun_index, roc_expr_ptr = over_info_ptr, roc_rcs = rcs}
				-> ([roc:rcss], case_with_context_ptrs, expr_heap, prs_state)
			(EI_CaseTypeWithContexts case_type constructor_contexts,expr_heap)
				-> (rcss, [over_info_ptr:case_with_context_ptrs], expr_heap, prs_state)

	iterate_cr ri_info rcss prs_state=:{prs_subst={subst_changed}}
		| subst_changed // && trace_tn "iterate_cr"
			# (rcss, prs_state) = redo_cr ri_info rcss {prs_state & prs_subst.subst_changed = False}
			= iterate_cr ri_info rcss prs_state
			= (rcss, prs_state)
	
	redo_cr ri_info [] prs_state
		= ([], prs_state)
	redo_cr ri_info [roc=:{roc_rcs} : rcss] prs_state
		# (changed, roc_rcs, prs_state) = continueContextReduction ri_info roc_rcs prs_state
		  (rcss, prs_state) = redo_cr ri_info rcss prs_state 
		| changed 
			= ([{ roc & roc_rcs = roc_rcs } : rcss], prs_state)
			= ([roc : rcss], prs_state)

	iterate_improve_dep_types_and_reduce rcss ri_info predef_symbols dts_state
		# dts_state = improve_dep_types rcss ri_info dts_state
		| dts_state.dts_subst.subst_changed
			# {dts_contexts,dts_subst,dts_var_heap,dts_type_heaps,dts_error} = dts_state
			  prs_state = {prs_subst=dts_subst, prs_var_heap=dts_var_heap, prs_type_heaps=dts_type_heaps, prs_error=dts_error, prs_predef_symbols=predef_symbols}
			  (rcss, {prs_subst,prs_var_heap,prs_type_heaps,prs_error,prs_predef_symbols}) = iterate_cr ri_info rcss prs_state
			  prs_subst & subst_changed = False
			  dts_state = {dts_contexts=dts_contexts, dts_subst=prs_subst, dts_var_heap=prs_var_heap, dts_type_heaps=prs_type_heaps, dts_error=prs_error}
			= iterate_improve_dep_types_and_reduce rcss ri_info prs_predef_symbols dts_state
			= (predef_symbols,dts_state)

	improve_dep_types [roc=:{roc_rcs} : rcss] ri_info dts_state
		# dts_state = improveDepTypes ri_info roc_rcs dts_state
		= improve_dep_types rcss ri_info dts_state 
	improve_dep_types [] ri_info dts_state
		= dts_state

addDictionaries :: ![[TypeContext]] ![TypeContext] ![ReducedOverloadedApplication] !{# CommonDefs } 
	!*Heaps !*{!Type} !*ErrorAdmin -> (![TypeContext], !DictionaryTypes, !*Heaps, !*{!Type}, !*ErrorAdmin)
addDictionaries spec_contexts contexts reduced_calls defs heaps=:{hp_var_heap,hp_type_heaps} subst os_error
	# (contexts, hp_var_heap, subst) = foldSt add_specified_contexts spec_contexts (contexts, hp_var_heap, subst)
	  (contexts, hp_type_heaps) = remove_super_classes contexts hp_type_heaps
	  (heaps, dict_types, os_error)
			= foldSt (convert_dictionaries defs contexts) reduced_calls
		  					({ heaps & hp_var_heap = hp_var_heap, hp_type_heaps = hp_type_heaps }, [], os_error)
	= (contexts, dict_types, heaps, subst, os_error)
where
	add_specified_contexts contexts all_contexts_subst_and_var_heap
		= foldSt add_spec_context contexts all_contexts_subst_and_var_heap
	where
		add_spec_context tc (contexts, var_heap, subst)
			# (changed, tc, subst)	= arraySubst tc subst
			| containsContext tc contexts
				= (contexts, var_heap, subst)
			  	# (tc_var,var_heap) = newPtr VI_Empty var_heap
				= ([{tc & tc_var = tc_var} : contexts], var_heap, subst)

	remove_super_classes contexts type_heaps
		# (super_classes, type_heaps) = foldSt generate_super_classes contexts ([], type_heaps)
		  sub_classes = foldSt (remove_doubles super_classes) contexts []
		= (sub_classes, type_heaps)

	generate_super_classes tc=:{tc_class=TCGeneric {gtc_class}} st
		= generate_super_classes {tc & tc_class=TCClass gtc_class} st
	generate_super_classes {tc_class=TCClass {glob_object={ds_index},glob_module},tc_types} (super_classes, type_heaps)
		# {class_args,class_members,class_context} = defs.[glob_module].com_class_defs.[ds_index]
		| class_context=:[]
			= (super_classes, type_heaps)
			# th_vars = set_class_args_types class_args tc_types type_heaps.th_vars
			= foldSt subst_context_and_generate_super_classes class_context (super_classes, { type_heaps & th_vars = th_vars })
	where
		subst_context_and_generate_super_classes class_context (super_classes, type_heaps)
			# (_, super_class, type_heaps) = substitute class_context type_heaps
			| containsContext super_class super_classes
				= (super_classes, type_heaps)
				= generate_super_classes super_class ([super_class : super_classes], type_heaps) 

	remove_doubles sub_classes tc context
		| containsContext tc sub_classes
			= context
			= [tc : context]

	convert_dictionaries :: !{#CommonDefs} ![TypeContext] !ReducedOverloadedApplication !(!*Heaps,!DictionaryTypes, !*ErrorAdmin)
		-> (!*Heaps, !DictionaryTypes, !*ErrorAdmin)
	convert_dictionaries defs contexts {roa_symbol = oc_symbol,roa_fun_index = index,roa_expr_ptr = over_info_ptr,roa_rcs = class_applications} (heaps, dict_types, error)
		# (heaps, ptrs, error) = convertOverloadedCall defs contexts oc_symbol over_info_ptr class_applications (heaps, [], error)
		| isEmpty ptrs
			= (heaps, dict_types, error)
			= (heaps, add_to_dict_types index ptrs dict_types, error)
	
	add_to_dict_types index ptrs []
		= [(index, ptrs)]
	add_to_dict_types new_index new_ptrs dt=:[(index, ptrs) : dict_types]
		| new_index == index
			= [(index, new_ptrs ++ ptrs) : dict_types]
			= [(new_index, new_ptrs) : dt]

selectFromDictionary dict_mod dict_index member_index defs
	# (RecordType {rt_fields}) = defs.[dict_mod].com_type_defs.[dict_index].td_rhs
	  { fs_ident, fs_index } = rt_fields.[member_index]
	= { glob_module = dict_mod, glob_object = { ds_ident = fs_ident, ds_index = fs_index, ds_arity = 1 }}

getDictionaryConstructorAndRecordType :: !GlobalIndex !{#CommonDefs} -> (!DefinedSymbol,!Type)
getDictionaryConstructorAndRecordType {gi_module,gi_index} defs	  
	# {class_dictionary} = defs.[gi_module].com_class_defs.[gi_index]
	  (RecordType {rt_constructor}) = defs.[gi_module].com_type_defs.[class_dictionary.ds_index].td_rhs
	  rec_type = defs.[gi_module].com_cons_defs.[rt_constructor.ds_index].cons_type.st_result.at_type
	= (rt_constructor, rec_type)

AttributedType type :== { at_attribute = TA_Multi, at_type = type }

convertOverloadedCall :: !{#CommonDefs} ![TypeContext] !SymbIdent !ExprInfoPtr ![ClassApplication] !(!*Heaps, ![ExprInfoPtr],!*ErrorAdmin) -> (!*Heaps, ![ExprInfoPtr],!*ErrorAdmin)
convertOverloadedCall defs contexts {symb_ident,symb_kind = SK_OverloadedFunction {glob_module,glob_object}} expr_ptr [class_appl:class_appls] (heaps,ptrs,error)
	# mem_def = defs.[glob_module].com_member_defs.[glob_object]
	  (class_exprs, heaps_and_ptrs) = convertClassApplsToExpressions defs contexts class_appls (heaps, ptrs)
	  (inst_expr, (heaps, ptrs)) = adjust_member_application defs contexts mem_def class_appl class_exprs heaps_and_ptrs
	= ({heaps & hp_expression_heap = heaps.hp_expression_heap <:= (expr_ptr, inst_expr)}, ptrs, error)
where
	adjust_member_application defs contexts mem_def (CA_Instance rc) class_exprs heaps_and_ptrs
		= adjust_member_instance  defs contexts mem_def rc class_exprs heaps_and_ptrs
	adjust_member_application defs contexts {me_offset,me_class={glob_module,glob_object}} (CA_Context tc) class_exprs (heaps=:{hp_type_heaps}, ptrs)
		# (class_context, address, hp_type_heaps) = determineContextAddress contexts defs tc hp_type_heaps
		# {class_dictionary={ds_index,ds_ident}} = defs.[glob_module].com_class_defs.[glob_object]
		  selector = selectFromDictionary glob_module ds_index me_offset defs
		= (EI_Selection (generateClassSelection address [RecordSelection selector me_offset]) class_context.tc_var class_exprs,
				({ heaps & hp_type_heaps = hp_type_heaps }, ptrs))
		
	adjust_member_instance defs contexts {me_ident,me_offset,me_class} (RC_Class cid rcs) class_exprs heaps_and_ptrs
		# (inst_module, inst_index, inst_ident, red_contexts_appls) = find_instance_of_member me_class me_offset cid rcs
		  (exprs, heaps_and_ptrs) = convertClassApplsToExpressions defs contexts red_contexts_appls heaps_and_ptrs
		  class_exprs = exprs ++ class_exprs
		| inst_index>=0
			= (EI_Instance { glob_module = inst_module, glob_object = { ds_ident = me_ident, ds_arity = length class_exprs, ds_index = inst_index }} class_exprs,
				 heaps_and_ptrs)
			= (EI_Instance { glob_module = inst_module, glob_object = { ds_ident = inst_ident, ds_arity = length class_exprs, ds_index = -1 - inst_index }} class_exprs,
				 heaps_and_ptrs)
	adjust_member_instance defs contexts {me_ident,me_offset,me_class={glob_module,glob_object}} (RC_TC_Global tci_constructor tci_contexts) _ heaps_and_ptrs
		# (exprs, heaps_and_ptrs) = convertClassApplsToExpressions defs contexts tci_contexts heaps_and_ptrs
		  typeCodeExpressions = expressionsToTypeCodeExpressions exprs
		= case tci_constructor of
			GTT_Constructor _ True
				-> (EI_TypeCode (TCE_UnqType (TCE_Constructor tci_constructor typeCodeExpressions)), heaps_and_ptrs)
			_
				-> (EI_TypeCode (TCE_Constructor tci_constructor typeCodeExpressions), heaps_and_ptrs)
	adjust_member_instance defs contexts {me_ident,me_offset,me_class={glob_module,glob_object}} (RC_TC_Local new_var_ptr) _ heaps_and_ptrs
		= (EI_TypeCode (TCE_Var new_var_ptr), heaps_and_ptrs)
	adjust_member_instance defs contexts {me_ident,me_offset,me_class={glob_module,glob_object}} (RC_TC_Context tc) class_exprs (heaps=:{hp_type_heaps}, ptrs)
		// same as adjust_member_application for CA_Context
		# (class_context, address, hp_type_heaps) = determineContextAddress contexts defs tc hp_type_heaps
		# {class_dictionary={ds_index,ds_ident}} = defs.[glob_module].com_class_defs.[glob_object]
		  selector = selectFromDictionary glob_module ds_index me_offset defs
		= (EI_Selection (generateClassSelection address [RecordSelection selector me_offset]) class_context.tc_var class_exprs,
				({heaps & hp_type_heaps = hp_type_heaps}, ptrs))

	find_instance_of_member :: (Global Int) Int ClassInstanceDescr [ReducedContext] -> (!Int,!Int,Ident,[ClassApplication])
	find_instance_of_member me_class me_offset {cid_class_index, cid_inst_module, cid_inst_members, cid_red_contexts} constraint_contexts
		| cid_class_index.gi_module == me_class.glob_module && cid_class_index.gi_index == me_class.glob_object
			# {cim_index,cim_arity,cim_ident} = cid_inst_members.[me_offset]
			| cim_index<0
				= (cim_arity, cim_index, cim_ident, cid_red_contexts)
				= (cid_inst_module, cim_index, cim_ident, cid_red_contexts)
			= find_instance_of_member_in_constraints me_class me_offset constraint_contexts
	where
		find_instance_of_member_in_constraint me_class me_offset [ RC_Class cid rcs : rcss ]
			= find_instance_of_member me_class me_offset cid (rcs ++ rcss)
		find_instance_of_member_in_constraints me_class me_offset [ _ : rcss ]
			= find_instance_of_member_in_constraints me_class me_offset rcss
		find_instance_of_member_in_constraints me_class me_offset []
			= abort "Error in module overloading: find_instance_of_member_in_constraints\n"
convertOverloadedCall defs contexts symbol=:{symb_ident, symb_kind = SK_Generic gen_glob kind} expr_ptr class_appls (heaps, expr_info_ptrs, error)
	#! (opt_member_glob, hp_generic_heap) = getGenericMember gen_glob kind defs heaps.hp_generic_heap
	#! heaps = { heaps & hp_generic_heap = hp_generic_heap }
	= case opt_member_glob of		
		No
			# error = checkError ("no generic instances of " +++ toString symb_ident +++ " for kind") kind error
			-> (heaps, expr_info_ptrs, error)
		Yes member_glob -> convertOverloadedCall defs contexts {symbol & symb_kind = SK_OverloadedFunction member_glob} expr_ptr class_appls (heaps, expr_info_ptrs, error)
convertOverloadedCall defs contexts {symb_ident,symb_kind = SK_TypeCode} expr_info_ptr class_appls (heaps, ptrs, error)
	# (class_expressions, (heaps, ptrs)) = convertClassApplsToExpressions defs contexts class_appls (heaps, ptrs)
	= ({heaps & hp_expression_heap = heaps.hp_expression_heap <:= (expr_info_ptr, EI_TypeCodes (map expressionToTypeCodeExpression class_expressions))}, ptrs, error)
convertOverloadedCall defs contexts {symb_kind=SK_TFACVar var_expr_ptr,symb_ident} expr_info_ptr appls (heaps,ptrs, error)
	# (class_expressions, (heaps, ptrs)) = convertClassApplsToExpressions defs contexts appls (heaps,ptrs)
	= ({heaps & hp_expression_heap = heaps.hp_expression_heap <:= (expr_info_ptr, EI_FPContext class_expressions var_expr_ptr)}, ptrs, error)
convertOverloadedCall defs contexts {symb_kind=SK_VarContexts var_contexts} expr_info_ptr appls (heaps,ptrs, error)
	# (var_contexts,error) = get_var_contexts var_contexts defs contexts error
	  (class_expressions, (heaps, ptrs)) = convertClassApplsToExpressions defs contexts appls (heaps,ptrs)
	  expr_info = EI_ContextWithVarContexts class_expressions var_contexts
	= ({heaps & hp_expression_heap = writePtr expr_info_ptr expr_info heaps.hp_expression_heap}, [expr_info_ptr:ptrs], error)
convertOverloadedCall defs contexts {symb_ident,symb_kind = SK_TypeCodeAndContexts univ_contexts} expr_info_ptr class_appls (heaps, ptrs, error)
	# (univ_contexts,error) = get_var_contexts univ_contexts defs contexts error
	  (class_expressions, (heaps, ptrs)) = convertClassApplsToExpressions defs contexts class_appls (heaps, ptrs)
	  expr_info = EI_TypeCodesWithContexts (expressionsToTypeCodeExpressions class_expressions) univ_contexts
	= ({heaps & hp_expression_heap = writePtr expr_info_ptr expr_info heaps.hp_expression_heap}, ptrs, error)
convertOverloadedCall defs contexts symbol expr_info_ptr appls (heaps,ptrs, error)
	# (class_expressions, (heaps, ptrs)) = convertClassApplsToExpressions defs contexts appls (heaps,ptrs)
	= ({heaps & hp_expression_heap = heaps.hp_expression_heap <:= (expr_info_ptr, EI_Context class_expressions)}, ptrs, error)

expressionsToTypeCodeExpressions class_expressions
	= map expressionToTypeCodeExpression class_expressions

class_to_dictionary_type glob_module ds_index tc_types defs
	# {class_dictionary} = defs.[glob_module].com_class_defs.[ds_index]
	  dict_type_symbol = MakeTypeSymbIdent {glob_module=glob_module,glob_object=class_dictionary.ds_index} class_dictionary.ds_ident class_dictionary.ds_arity
	= AttributedType (TA dict_type_symbol [AttributedType type \\ type <- tc_types])

get_var_contexts (VarContext arg_n context arg_atype var_contexts) defs contexts error
	# (cs,error) = get_var_context context contexts error 
	  cs = [convert_TypeContext_to_DictionaryAndClassType c defs \\ c <- cs]
	  (var_contexts,error) = get_var_contexts var_contexts defs contexts error
 	= (VarContext arg_n cs arg_atype var_contexts,error)
where
	get_var_context [] contexts error
		= ([],error)
	get_var_context [var_context:var_contexts] contexts error
		# (var_contexts,error) = get_var_context var_contexts contexts error
		= get_context var_context var_contexts contexts error

	get_context context var_contexts [c:cs] error
		| context==c
			= ([c:var_contexts],error)
			= get_context context var_contexts cs error
	get_context {tc_class=TCClass {glob_object={ds_ident}}} var_contexts [] error
		# error = sub_class_error ds_ident error
		= (var_contexts,error)

	convert_TypeContext_to_DictionaryAndClassType {tc_var,tc_class=TCClass {glob_module,glob_object={ds_index}},tc_types} defs
		= {dc_var=tc_var,dc_class_type=class_to_dictionary_type glob_module ds_index tc_types defs}
	convert_TypeContext_to_DictionaryAndClassType {tc_var,tc_class=TCGeneric {gtc_class={glob_module,glob_object={ds_index}}},tc_types} defs
		= {dc_var=tc_var,dc_class_type=class_to_dictionary_type glob_module ds_index tc_types defs}
get_var_contexts NoVarContexts defs contexts error
	= (NoVarContexts,error)

expressionToTypeCodeExpression (TypeCodeExpression texpr)
	= texpr
expressionToTypeCodeExpression (ClassVariable var_info_ptr)
	= TCE_TypeTerm var_info_ptr
expressionToTypeCodeExpression (Selection NormalSelector (ClassVariable var_info_ptr) selectors)
	= TCE_Selector selectors var_info_ptr
expressionToTypeCodeExpression expr
	= abort "expressionToTypeCodeExpression (overloading.icl)"

generateClassSelection address last_selectors
	= mapAppend (\(off_set,selector) -> RecordSelection selector off_set) address last_selectors

instance toString ClassApplication
where 
	toString (CA_Instance _)		= abort "CA_Instance"
	toString (CA_Context _)			= abort "CA_Context"

convertClassApplsToExpressions :: {#CommonDefs} [TypeContext] [ClassApplication] *( *Heaps, [ExprInfoPtr])
															-> *(![Expression], !*(!*Heaps,![ExprInfoPtr]))
convertClassApplsToExpressions defs contexts cl_appls heaps_and_ptrs
	= mapSt (convert_class_appl_to_expression defs contexts) cl_appls heaps_and_ptrs
where
	convert_class_appl_to_expression defs contexts (CA_Instance rc) heaps_and_ptrs
		= convert_reduced_contexts_to_expression defs contexts rc heaps_and_ptrs
	convert_class_appl_to_expression defs contexts (CA_Context tc) (heaps=:{hp_type_heaps}, ptrs)
		# (class_context, context_address, hp_type_heaps) = determineContextAddress contexts defs tc hp_type_heaps
		| isEmpty context_address
			= (ClassVariable class_context.tc_var, ({heaps & hp_type_heaps=hp_type_heaps}, ptrs))
			= (Selection NormalSelector (ClassVariable class_context.tc_var) (generateClassSelection context_address []), ({heaps & hp_type_heaps = hp_type_heaps}, ptrs))

	convert_reduced_contexts_to_expression defs contexts (RC_TC_Local new_var_ptr) heaps_and_ptrs
		= (TypeCodeExpression (TCE_Var new_var_ptr), heaps_and_ptrs)
	convert_reduced_contexts_to_expression defs contexts (RC_TC_Global tci_constructor tci_contexts) heaps_and_ptrs
		# (exprs, heaps_and_ptrs) = convertClassApplsToExpressions defs contexts tci_contexts heaps_and_ptrs
		  typeCodeExpressions = expressionsToTypeCodeExpressions exprs
		= case tci_constructor of
			GTT_Constructor _ True
				-> (TypeCodeExpression (TCE_UnqType (TCE_Constructor tci_constructor typeCodeExpressions)), heaps_and_ptrs)
			_
				-> (TypeCodeExpression (TCE_Constructor tci_constructor typeCodeExpressions), heaps_and_ptrs)
	convert_reduced_contexts_to_expression defs contexts (RC_Class cid rcs) heaps_and_ptrs
		# (rcs_exprs, heaps_and_ptrs) = mapSt (convert_reduced_contexts_to_expression defs contexts) rcs heaps_and_ptrs
		= convert_reduced_context_to_expression defs contexts cid rcs_exprs heaps_and_ptrs
	where
		convert_reduced_context_to_expression :: {#CommonDefs} [TypeContext] ClassInstanceDescr [Expression] *(*Heaps,[Ptr ExprInfo]) -> *(Expression,*(*Heaps,[Ptr ExprInfo]))
		convert_reduced_context_to_expression defs contexts {cid_class_index, cid_inst_module, cid_inst_members, cid_red_contexts, cid_types} dictionary_args heaps_and_ptrs
			# (expressions, (heaps, class_ptrs)) = convertClassApplsToExpressions defs contexts cid_red_contexts heaps_and_ptrs
			  context_size = length expressions
			  class_size   = size cid_inst_members
			| (class_size > 2 && context_size > 0) || (class_size==2 && (context_size>1 || not (is_small_context expressions)))
				# (let_binds, let_types, rev_dicts, hp_var_heap, hp_expression_heap)
						= foldSt (bind_shared_dictionary class_size) expressions ([], [], [], heaps.hp_var_heap, heaps.hp_expression_heap)
				  dictionary_args = build_class_members class_size cid_inst_members cid_inst_module (reverse rev_dicts) context_size dictionary_args
				  (dict_expr, hp_expression_heap, class_ptrs) = build_dictionary cid_class_index cid_types dictionary_args defs hp_expression_heap class_ptrs
				| isEmpty let_binds
					= (dict_expr, ({ heaps & hp_var_heap = hp_var_heap, hp_expression_heap = hp_expression_heap }, class_ptrs))
					# (let_info_ptr, hp_expression_heap) = newPtr (EI_LetType let_types) hp_expression_heap
					= (Let { let_strict_binds = [], let_lazy_binds = let_binds, let_expr = dict_expr, let_info_ptr = let_info_ptr, let_expr_position = NoPos },
						({ heaps & hp_var_heap = hp_var_heap, hp_expression_heap = hp_expression_heap }, [let_info_ptr : class_ptrs]))
				# dictionary_args = build_class_members class_size cid_inst_members cid_inst_module expressions context_size dictionary_args
				  (dict_expr, hp_expression_heap, class_ptrs) = build_dictionary cid_class_index cid_types dictionary_args defs heaps.hp_expression_heap class_ptrs
				= (dict_expr, ({ heaps & hp_expression_heap = hp_expression_heap }, class_ptrs))

		is_small_context [] = True;
		is_small_context [App {app_args}] = contains_no_dictionaries app_args;
			where
				contains_no_dictionaries [] = True
				contains_no_dictionaries [App {app_args=[]}:args] = contains_no_dictionaries args
				contains_no_dictionaries [ClassVariable _:args] = contains_no_dictionaries args
				contains_no_dictionaries [Selection _ (ClassVariable _) _:args] = contains_no_dictionaries args
				contains_no_dictionaries l = False // <<- ("contains_no_dictionaries",l);
		is_small_context [ClassVariable _] = True;
		is_small_context l = False // <<- ("is_small_context",l);

		build_class_members mem_offset ins_members mod_index class_arguments arity dictionary_args
			| mem_offset == 0
				= dictionary_args
				# mem_offset = dec mem_offset
				  {cim_ident,cim_index,cim_arity} = ins_members.[mem_offset]
				| cim_index<0
					# mem_expr =  App { app_symb = { symb_ident = cim_ident,
						  							 symb_kind = SK_Function {glob_object = -1 - cim_index, glob_module = cim_arity} },
										app_args = class_arguments,
										app_info_ptr = nilPtr }
					= build_class_members mem_offset ins_members mod_index class_arguments arity [mem_expr : dictionary_args]
					# mem_expr =  App { app_symb = { symb_ident = cim_ident,
						  							 symb_kind = SK_Function {glob_object = cim_index, glob_module = mod_index} },
										app_args = class_arguments,
										app_info_ptr = nilPtr }
					= build_class_members mem_offset ins_members mod_index class_arguments arity [mem_expr : dictionary_args]
		
		build_dictionary class_index instance_types dictionary_args defs expr_heap ptrs
			# (dict_cons,TA dict_record_type_symb _) = getDictionaryConstructorAndRecordType class_index defs
			  record_symbol = { symb_ident = dict_cons.ds_ident,
			  					symb_kind = SK_Constructor {glob_module = class_index.gi_module, glob_object = dict_cons.ds_index}
								}
			  class_type = TA dict_record_type_symb [AttributedType type \\ type <- instance_types]
			  (app_info_ptr, expr_heap) = newPtr (EI_DictionaryType class_type) expr_heap
			  rc_record = App {app_symb = record_symbol, app_args = dictionary_args, app_info_ptr = app_info_ptr}
			= (rc_record, expr_heap, [app_info_ptr : ptrs])

		bind_shared_dictionary nr_of_members dict=:(Let {let_expr=App {app_symb={symb_ident}, app_info_ptr}}) (binds, types, rev_dicts, var_heap, expr_heap)
			# (EI_DictionaryType class_type, expr_heap) = readPtr app_info_ptr expr_heap
		  	  (var_info_ptr, var_heap) = newPtr VI_Empty var_heap
		  	  fv = { fv_ident = symb_ident, fv_info_ptr = var_info_ptr, fv_def_level = NotALevel, fv_count = nr_of_members }
		  	  var = { var_ident = symb_ident, var_info_ptr = var_info_ptr, var_expr_ptr = nilPtr }
			= ([{lb_src = dict, lb_dst = fv, lb_position = NoPos } : binds ], [ AttributedType class_type : types ],
				[Var var : rev_dicts], var_heap, expr_heap)
		bind_shared_dictionary nr_of_members dict=:(App {app_symb={symb_ident}, app_info_ptr}) (binds, types, rev_dicts, var_heap, expr_heap)
			# (EI_DictionaryType class_type, expr_heap) = readPtr app_info_ptr expr_heap
		  	  (var_info_ptr, var_heap) = newPtr VI_Empty var_heap
		  	  fv = { fv_ident = symb_ident, fv_info_ptr = var_info_ptr, fv_def_level = NotALevel, fv_count = nr_of_members }
		  	  var = { var_ident = symb_ident, var_info_ptr = var_info_ptr, var_expr_ptr = nilPtr }
			= ([{lb_src = dict, lb_dst = fv, lb_position = NoPos} : binds ], [ AttributedType class_type : types ], [Var var : rev_dicts], var_heap, expr_heap)
		bind_shared_dictionary nr_of_members dict (binds, types, rev_dicts, var_heap, expr_heap)
			= (binds, types, [dict : rev_dicts], var_heap, expr_heap)
	convert_reduced_contexts_to_expression defs contexts (RC_TC_Context tc) (heaps=:{hp_type_heaps}, ptrs)
		// same as convert_class_appl_to_expression for CA_Context
		# (class_context, context_address, hp_type_heaps) = determineContextAddress contexts defs tc hp_type_heaps
		| isEmpty context_address
			= (ClassVariable class_context.tc_var, ({heaps & hp_type_heaps=hp_type_heaps}, ptrs))
			= (Selection NormalSelector (ClassVariable class_context.tc_var) (generateClassSelection context_address []), ({heaps & hp_type_heaps = hp_type_heaps}, ptrs))

determineContextAddress :: ![TypeContext] !{#CommonDefs} !TypeContext !*TypeHeaps
	-> (!TypeContext, ![(Int, Global DefinedSymbol)], !*TypeHeaps)
determineContextAddress contexts defs this_context type_heaps
	= look_up_context_and_address this_context contexts defs type_heaps
where
	look_up_context_and_address :: !TypeContext ![TypeContext] !{#CommonDefs} !*TypeHeaps -> (TypeContext, [(Int, Global DefinedSymbol)], !*TypeHeaps)
	look_up_context_and_address this_context [] defs type_heaps
		= abort "look_up_context_and_address (overloading.icl)"
	look_up_context_and_address this_context [tc : tcs] defs type_heaps
		#! (may_be_addres, type_heaps) = determine_address this_context tc [] defs type_heaps
		= case may_be_addres of
			Yes address
				-> (tc, address, type_heaps)
			No
				-> look_up_context_and_address this_context tcs defs type_heaps

	determine_address :: !TypeContext !TypeContext ![(Int, Global DefinedSymbol)] !{#CommonDefs} !*TypeHeaps
		-> (!Optional [(Int, Global DefinedSymbol)],!*TypeHeaps)
	determine_address tc1 tc2 address defs type_heaps=:{th_vars}
		| tc1 == tc2
			= (Yes address, type_heaps)
		| tc2.tc_class=:TCGeneric _
			= (No, type_heaps)	// class_context==[] for generic classes
			# {tc_class=TCClass {glob_object={ds_index},glob_module}} = tc2
			  {class_args,class_members,class_context,class_dictionary} = defs.[glob_module].com_class_defs.[ds_index]
			| class_context=:[]
				= (No, type_heaps)
			# th_vars = set_class_args_types class_args tc2.tc_types th_vars
			  (_, super_instances, type_heaps) = substitute class_context {type_heaps & th_vars = th_vars} 
			= find_super_instance tc1 super_instances (size class_members) address glob_module class_dictionary.ds_index defs type_heaps
	where
		find_super_instance :: !TypeContext ![TypeContext] !Index ![(Int, Global DefinedSymbol)] !Index !Index !{#CommonDefs} !*TypeHeaps
			-> (!Optional [(Int, Global DefinedSymbol)],!*TypeHeaps)
		find_super_instance context [] tc_index address dict_mod dict_index defs type_heaps
			= (No, type_heaps)
		find_super_instance context [tc : tcs] tc_index address dict_mod dict_index defs type_heaps
			#! (may_be_addres, type_heaps) = determine_address context tc address defs type_heaps
			= case may_be_addres of
				Yes address
					# selector = selectFromDictionary dict_mod dict_index tc_index defs
					-> (Yes [ (tc_index, selector) : address ], type_heaps)
				No
					-> find_super_instance context tcs (inc tc_index) address  dict_mod dict_index defs type_heaps

getClassVariable :: !Ident !VarInfoPtr !*VarHeap !*ErrorAdmin -> (!Ident, !VarInfoPtr, !*VarHeap, !*ErrorAdmin)
getClassVariable symb var_info_ptr var_heap error
	= case (readPtr var_info_ptr var_heap) of
		(VI_ClassVar var_ident new_info_ptr count, var_heap)
			-> (var_ident, new_info_ptr, var_heap <:= (var_info_ptr, VI_ClassVar var_ident new_info_ptr (inc count)), error)
		(VI_ContextContainsFreeTypeVar {tc_class,tc_types},var_heap)
			# (new_info_ptr, var_heap) = newPtr VI_Empty var_heap
			# error = overloadingErrorWithContext symb tc_class tc_types error
			-> (symb, new_info_ptr, var_heap <:= (var_info_ptr, VI_ClassVar symb new_info_ptr 1), error)
		(VI_MissingContext {tc_class,tc_types},var_heap)
			# (new_info_ptr, var_heap) = newPtr VI_Empty var_heap
			# error = missingContextError symb tc_class tc_types error
			-> (symb, new_info_ptr, var_heap <:= (var_info_ptr, VI_ClassVar symb new_info_ptr 1), error)
		(VI_ForwardTypeContextVar var_info_ptr,var_heap)
			-> getClassVariable symb var_info_ptr var_heap error
		(_,var_heap)
			# (new_info_ptr, var_heap) = newPtr VI_Empty var_heap
			# error = overloadingError symb error
			-> (symb, new_info_ptr, var_heap <:= (var_info_ptr, VI_ClassVar symb new_info_ptr 1), error)

removeOverloadedFunctionsWithoutUpdatingFunctions :: ![Index] ![LocalTypePatternVariable] ![ErrorContexts] !Int !*{#FunDef} !*{! FunctionType} !*ExpressionHeap
														   !*TypeCodeInfo !*VarHeap !*ErrorAdmin !*{#PredefinedSymbol}
		-> (!*{#FunDef},!*{!FunctionType},!*ExpressionHeap,!*TypeCodeInfo,!*VarHeap,!*ErrorAdmin,!*{#PredefinedSymbol})
removeOverloadedFunctionsWithoutUpdatingFunctions group type_pattern_vars comp_error_contexts main_dcl_module_n fun_defs fun_env symbol_heap type_code_info var_heap error predef_symbols
	# (_, fun_defs, fun_env, symbol_heap, type_code_info, var_heap, error, predef_symbols)
		= foldSt (remove_overloaded_function type_pattern_vars) group (comp_error_contexts, fun_defs, fun_env, symbol_heap, type_code_info, var_heap, error, predef_symbols)
	= (fun_defs, fun_env, symbol_heap, type_code_info, var_heap, error, predef_symbols)
where
	remove_overloaded_function type_pattern_vars fun_index ([error_contexts:comp_error_contexts], fun_defs, fun_env, symbol_heap, type_code_info, var_heap, error, predef_symbols)
		| error.ea_ok
			# (fun_def, fun_defs) = fun_defs![fun_index]  
			  (CheckedType st=:{st_context,st_args}, fun_env) = fun_env![fun_index]
			  {fun_body = TransformedBody {tb_args,tb_rhs},fun_info,fun_arity,fun_ident,fun_pos} = fun_def
			  var_heap = mark_FPC_arguments st_args tb_args var_heap

			  var_heap = store_ambiguous_and_missing_contexts_for_errors error_contexts var_heap
			  
			  error = setErrorPosition fun_ident fun_pos error
			  (rev_variables,var_heap,error) = determine_class_arguments st_context var_heap error
			  (type_code_info, symbol_heap, type_pattern_vars, var_heap, error)
			  		= convertDynamicTypes fun_info.fi_dynamics (type_code_info, symbol_heap, type_pattern_vars, var_heap, error)
			 
			  (_ /*tb_rhs*/, ui)
			  		= updateExpression fun_info.fi_group_index tb_rhs {ui_instance_calls = [], ui_local_vars = fun_info.fi_local_vars, ui_symbol_heap = symbol_heap,
			  				ui_var_heap = var_heap, ui_fun_defs = fun_defs, ui_fun_env = fun_env, ui_error = error,
							ui_has_type_codes = False,
						    ui_x = {x_type_code_info=type_code_info, x_predef_symbols=predef_symbols,x_main_dcl_module_n=main_dcl_module_n}}

			#  {ui_instance_calls, ui_local_vars, ui_symbol_heap, ui_var_heap, ui_fun_defs, ui_fun_env, ui_has_type_codes, ui_error, ui_x = {x_type_code_info = type_code_info, x_predef_symbols = predef_symbols}}
				=	ui
			# (tb_args, var_heap) = retrieve_class_arguments rev_variables tb_args ui_var_heap
			  // fun_body and fun_arity not updated
			  fun_def & fun_info = {fun_info & fi_calls = fun_info.fi_calls ++ ui_instance_calls, fi_local_vars = ui_local_vars,
											   fi_properties = if ui_has_type_codes
											   					(fun_info.fi_properties bitor FI_HasTypeCodes)
											   					fun_info.fi_properties}
			# var_heap = remove_error_contexts error_contexts var_heap
			# ui_fun_defs & [fun_index] = fun_def
			= (comp_error_contexts, ui_fun_defs, ui_fun_env, ui_symbol_heap, type_code_info, var_heap, ui_error, predef_symbols)
			= (comp_error_contexts, fun_defs, fun_env, symbol_heap, type_code_info, var_heap, error, predef_symbols)

removeOverloadedFunctions :: ![Index] ![LocalTypePatternVariable] ![ErrorContexts] !Int !*{#FunDef} !*{! FunctionType} !*ExpressionHeap
														   !*TypeCodeInfo !*VarHeap !*ErrorAdmin !*{#PredefinedSymbol}
		-> (!*{#FunDef},!*{!FunctionType},!*ExpressionHeap,!*TypeCodeInfo,!*VarHeap,!*ErrorAdmin,!*{#PredefinedSymbol})
removeOverloadedFunctions group type_pattern_vars comp_error_contexts main_dcl_module_n fun_defs fun_env symbol_heap type_code_info var_heap error predef_symbols
	# (_, fun_defs, fun_env, symbol_heap, type_code_info, var_heap, error, predef_symbols)
		= foldSt (remove_overloaded_function type_pattern_vars) group (comp_error_contexts, fun_defs, fun_env, symbol_heap, type_code_info, var_heap, error, predef_symbols)
	= (fun_defs, fun_env, symbol_heap, type_code_info, var_heap, error, predef_symbols)
where
	remove_overloaded_function type_pattern_vars fun_index ([error_contexts:comp_error_contexts], fun_defs, fun_env, symbol_heap, type_code_info, var_heap, error, predef_symbols)
		| error.ea_ok
			# (fun_def, fun_defs) = fun_defs![fun_index]  
			  (CheckedType st=:{st_context,st_args}, fun_env) = fun_env![fun_index]
			  {fun_body = TransformedBody {tb_args,tb_rhs},fun_info,fun_arity,fun_ident,fun_pos} = fun_def
			  var_heap = mark_FPC_arguments st_args tb_args var_heap
			  
			  var_heap = store_ambiguous_and_missing_contexts_for_errors error_contexts var_heap

			  error = setErrorPosition fun_ident fun_pos error
			  (rev_variables,var_heap,error) = determine_class_arguments st_context var_heap error
			  (type_code_info, symbol_heap, type_pattern_vars, var_heap, error)
			  		= convertDynamicTypes fun_info.fi_dynamics (type_code_info, symbol_heap, type_pattern_vars, var_heap, error)
			 
			  (tb_rhs, ui)
			  		= updateExpression fun_info.fi_group_index tb_rhs {ui_instance_calls = [], ui_local_vars = fun_info.fi_local_vars, ui_symbol_heap = symbol_heap,
			  				ui_var_heap = var_heap, ui_fun_defs = fun_defs, ui_fun_env = fun_env, ui_error = error,
							ui_has_type_codes = False,
						    ui_x = {x_type_code_info=type_code_info, x_predef_symbols=predef_symbols,x_main_dcl_module_n=main_dcl_module_n}}

			#  {ui_instance_calls, ui_local_vars, ui_symbol_heap, ui_var_heap, ui_fun_defs, ui_fun_env, ui_has_type_codes, ui_error, ui_x = {x_type_code_info = type_code_info, x_predef_symbols = predef_symbols}}
				=	ui
			# (tb_args, var_heap) = retrieve_class_arguments rev_variables tb_args ui_var_heap
			  fun_def & fun_body = TransformedBody {tb_args = tb_args, tb_rhs = tb_rhs}, fun_arity = length tb_args,
			  			fun_info = {fun_info & fi_calls = fun_info.fi_calls ++ ui_instance_calls, fi_local_vars = ui_local_vars,
											   fi_properties = if ui_has_type_codes
																	(fun_info.fi_properties bitor FI_HasTypeCodes)
																	fun_info.fi_properties}
			# var_heap = remove_error_contexts error_contexts var_heap
			# ui_fun_defs & [fun_index] = fun_def
			= (comp_error_contexts, ui_fun_defs, ui_fun_env, ui_symbol_heap, type_code_info, var_heap, ui_error, predef_symbols)
			= (comp_error_contexts, fun_defs, fun_env, symbol_heap, type_code_info, var_heap, error, predef_symbols)

store_ambiguous_and_missing_contexts_for_errors (AmbiguousContext tc=:{tc_var} error_contexts) var_heap
	| (sreadPtr tc_var var_heap)=:VI_Empty
		# var_heap = writePtr tc_var (VI_ContextContainsFreeTypeVar tc) var_heap
		= store_ambiguous_and_missing_contexts_for_errors error_contexts var_heap
		= store_ambiguous_and_missing_contexts_for_errors error_contexts var_heap
store_ambiguous_and_missing_contexts_for_errors (MissingContext tc=:{tc_var} error_contexts) var_heap
	| (sreadPtr tc_var var_heap)=:VI_Empty
		# var_heap = writePtr tc_var (VI_MissingContext tc) var_heap
		= store_ambiguous_and_missing_contexts_for_errors error_contexts var_heap
		= store_ambiguous_and_missing_contexts_for_errors error_contexts var_heap
store_ambiguous_and_missing_contexts_for_errors NoErrorContexts var_heap
	= var_heap;

mark_FPC_arguments :: ![AType] ![FreeVar] !*VarHeap -> *VarHeap
mark_FPC_arguments st_args tb_args var_heap
	| has_TFAC st_args
		= mark_FPC_vars st_args tb_args var_heap
		= var_heap

determine_class_arguments st_context var_heap error
	= foldSt determine_class_argument st_context ([],var_heap,error)
where
	determine_class_argument {tc_class, tc_var} (variables,var_heap,error)
		# (var_info, var_heap) = readPtr tc_var var_heap
		= case var_info of
			VI_ForwardClassVar var_info_ptr
				# (var_info, var_heap) = readPtr var_info_ptr var_heap
				-> case var_info of
					VI_Empty
						-> add_class_var var_info_ptr tc_class var_heap error
					VI_EmptyConstructorClassVar
						-> add_class_var var_info_ptr tc_class var_heap error
					VI_ClassVar _ _ _
						# error = errorHeading "Overloading error" error
						  error = {error & ea_file = error.ea_file <<< " a type context occurs multiple times in the specified type\n" }
						-> ([var_info_ptr : variables],var_heap,error)
			VI_Empty
				-> add_class_var tc_var tc_class var_heap error
			VI_EmptyConstructorClassVar
				-> add_class_var tc_var tc_class var_heap error
			VI_ForwardClassVars var_info_ptr forward_class_var_info
				# (new_info_ptr, var_heap) = newPtr VI_Empty var_heap
				  vi_class_var = VI_ClassVar (build_var_name (toString tc_class)) new_info_ptr 0
				  var_heap = writePtr var_info_ptr vi_class_var var_heap
				  (var_heap,error) = set_forward_class_vars forward_class_var_info vi_class_var var_heap error
				-> ([var_info_ptr : variables],var_heap,error)
	where
		add_class_var var tc_class var_heap error
			# (new_info_ptr, var_heap) = newPtr VI_Empty var_heap
			  var_heap = writePtr var (VI_ClassVar (build_var_name (toString tc_class)) new_info_ptr 0) var_heap
			= ([var : variables],var_heap,error)

		build_var_name id_name
			= { id_name = "_v" +++ id_name, id_info = nilPtr }

	set_forward_class_vars (VI_ForwardClassVars var_info_ptr forward_class_var_info) vi_class_var var_heap error
		# (var_heap,error) = set_forward_class_var var_info_ptr vi_class_var var_heap error
		= set_forward_class_vars forward_class_var_info vi_class_var var_heap error
	set_forward_class_vars (VI_ForwardClassVar var_info_ptr) vi_class_var var_heap error
		= set_forward_class_var var_info_ptr vi_class_var var_heap error

	set_forward_class_var var_info_ptr vi_class_var var_heap error
		# (var_info, var_heap) = readPtr var_info_ptr var_heap
		= case var_info of
			VI_Empty
				# var_heap = writePtr var_info_ptr vi_class_var var_heap
				-> (var_heap,error)
			VI_EmptyConstructorClassVar
				# var_heap = writePtr var_info_ptr vi_class_var var_heap
				-> (var_heap,error)
			VI_ClassVar _ _ _
				# error = errorHeading "Overloading error" error
				  error = {error & ea_file = error.ea_file <<< " a type context occurs multiple times in the specified type\n" }
				-> (var_heap,error)

retrieve_class_arguments rev_variables tb_args var_heap
	= foldSt retrieve_class_argument rev_variables (tb_args, var_heap) 
where
	retrieve_class_argument var_info_ptr (args, var_heap)
		# (VI_ClassVar var_ident new_info_ptr count, var_heap) = readPtr var_info_ptr var_heap
		= ([{fv_ident = var_ident, fv_info_ptr = new_info_ptr, fv_def_level = DictionaryLevel, fv_count = count } : args], var_heap <:= (var_info_ptr, VI_Empty))

remove_error_contexts (AmbiguousContext {tc_var} error_contexts) var_heap
	# var_heap = writePtr tc_var VI_Empty var_heap
	= remove_error_contexts error_contexts var_heap
remove_error_contexts (MissingContext {tc_var} error_contexts) var_heap
	# var_heap = writePtr tc_var VI_Empty var_heap
	= remove_error_contexts error_contexts var_heap
remove_error_contexts NoErrorContexts var_heap
	= var_heap;

has_TFAC [{at_type=TFAC _ _ _}:_] = True
has_TFAC [_:atypes] = has_TFAC atypes
has_TFAC [] = False

mark_FPC_vars [{at_type=TFAC _ _ _}:atypes] [{fv_info_ptr}:args] var_heap
	# var_heap = writePtr fv_info_ptr VI_FPC var_heap
	= mark_FPC_vars atypes args var_heap
mark_FPC_vars [_:atypes] [_:args] var_heap
	= mark_FPC_vars atypes args var_heap
mark_FPC_vars [] [] var_heap
	= var_heap

convertDynamicTypes :: [ExprInfoPtr]
	   *(*TypeCodeInfo,*ExpressionHeap,[LocalTypePatternVariable],*VarHeap,*ErrorAdmin)
	-> *(*TypeCodeInfo,*ExpressionHeap,[LocalTypePatternVariable],*VarHeap,*ErrorAdmin)
convertDynamicTypes dyn_ptrs update_info
	= foldSt update_dynamic dyn_ptrs update_info
where
	update_dynamic dyn_ptr (type_code_info, expr_heap, type_pattern_vars, var_heap, error)
		# (dyn_info, expr_heap) = readPtr dyn_ptr expr_heap 
		= case dyn_info of
			EI_TempDynamicType (Yes {dt_global_vars,dt_uni_vars,dt_type,dt_contexts}) loc_dynamics _ _ _ expr_ptr {symb_ident}
				# (expr_info, expr_heap) = readPtr expr_ptr expr_heap
				-> case expr_info of
					EI_TypeCodes type_codes
						# (type_var_heap, var_heap, error)
								= bind_type_vars_to_type_codes symb_ident dt_global_vars type_codes type_code_info.tci_type_var_heap var_heap error
						  (uni_vars, (type_var_heap, var_heap)) = newTypeVariables dt_uni_vars (type_var_heap, var_heap)
						  (type_code_expr, (type_code_info,var_heap,error)) = toTypeCodeExpression (add_universal_vars_to_type dt_uni_vars dt_type)
						  				({ type_code_info & tci_type_var_heap = type_var_heap }, var_heap, error)
						  expr_heap = expr_heap <:= (dyn_ptr, EI_TypeOfDynamic type_code_expr)
						-> convert_local_dynamics loc_dynamics (type_code_info, expr_heap, type_pattern_vars, var_heap, error)
					EI_Empty
						# (uni_vars, (type_var_heap, var_heap)) = newTypeVariables dt_uni_vars (type_code_info.tci_type_var_heap, var_heap)
						  (type_code_expr, (type_code_info,var_heap,error)) = toTypeCodeExpression (add_universal_vars_to_type dt_uni_vars dt_type)
						  			({ type_code_info & tci_type_var_heap = type_var_heap }, var_heap, error)
						  expr_heap = expr_heap <:= (dyn_ptr, EI_TypeOfDynamic type_code_expr)
						-> convert_local_dynamics loc_dynamics (type_code_info, expr_heap, type_pattern_vars, var_heap, error)
					EI_TypeCodesWithContexts type_codes univ_contexts=:(VarContext _ dictionaries_and_contexts _ _)
						# (type_var_heap, var_heap, error)
								= bind_type_vars_to_type_codes symb_ident dt_global_vars type_codes type_code_info.tci_type_var_heap var_heap error
						  (uni_vars, (type_var_heap, var_heap)) = newTypeVariables dt_uni_vars (type_var_heap, var_heap)
						  dt_type = add_types_of_dictionaries dt_contexts dt_type type_code_info.tci_common_defs
						  (type_code_expr, (type_code_info,var_heap,error)) = toTypeCodeExpression (add_universal_vars_to_type dt_uni_vars dt_type)
						  				({ type_code_info & tci_type_var_heap = type_var_heap }, var_heap, error)
						  expr_heap = expr_heap <:= (dyn_ptr, EI_TypeOfDynamicWithContexts type_code_expr univ_contexts)
						-> convert_local_dynamics loc_dynamics (type_code_info, expr_heap, type_pattern_vars, var_heap, error)
			EI_TempDynamicType No loc_dynamics _ _ _ expr_ptr {symb_ident}
				# (expr_info, expr_heap) = readPtr expr_ptr expr_heap
				-> case expr_info of
					EI_TypeCode type_expr
						# (type_expr, (undefined_tc_class_vars,var_heap)) = try_update_free_vars_of_TCE type_expr ([],var_heap)
						-> case undefined_tc_class_vars of
							[]
								# expr_heap = expr_heap <:= (dyn_ptr, EI_TypeOfDynamic type_expr)
								-> convert_local_dynamics loc_dynamics (type_code_info, expr_heap, type_pattern_vars, var_heap, error)
							_
								# expr_heap = expr_heap <:= (dyn_ptr, EI_TypeOfDynamicAndTCsToFind type_expr symb_ident undefined_tc_class_vars)
								-> convert_local_dynamics loc_dynamics (type_code_info, expr_heap, type_pattern_vars, var_heap, error)
					EI_Selection selectors record_var _
						# (var_info,var_heap) = readPtr record_var var_heap
						-> case var_info of
							VI_ClassVar var_ident new_info_ptr count
								# var_heap = writePtr record_var (VI_ClassVar var_ident new_info_ptr (inc count)) var_heap
								  expr_heap = expr_heap <:= (dyn_ptr, EI_TypeOfDynamic (convert_selectors selectors new_info_ptr))
								-> convert_local_dynamics loc_dynamics (type_code_info, expr_heap, type_pattern_vars, var_heap, error)
							_
								# type_expr = convert_selectors selectors record_var
								  expr_heap = expr_heap <:= (dyn_ptr, EI_TypeOfDynamicAndTCsToFind type_expr symb_ident [record_var])
								-> convert_local_dynamics loc_dynamics (type_code_info, expr_heap, type_pattern_vars, var_heap, error)
			EI_TempDynamicPattern type_vars {dt_global_vars,dt_uni_vars,dt_type,dt_contexts} loc_dynamics temp_local_vars _ _ expr_ptr {symb_ident}
				#! no_contexts = isEmpty dt_contexts
				# (expr_info, expr_heap) = readPtr expr_ptr expr_heap
				-> case expr_info of
					EI_TypeCodes type_codes
						# (type_var_heap, var_heap, error)
								= bind_type_vars_to_type_codes symb_ident dt_global_vars type_codes type_code_info.tci_type_var_heap var_heap error
						  (var_ptrs, (type_pattern_vars, var_heap)) = mapSt addLocalTCInstance temp_local_vars (type_pattern_vars, var_heap)
						  type_var_heap = bind_type_vars_to_type_var_codes type_vars var_ptrs type_var_heap
						  dt_type = add_types_of_dictionaries dt_contexts dt_type type_code_info.tci_common_defs
						  type_code_info = {type_code_info & tci_type_var_heap = type_var_heap}
						  (type_code_expr, (type_code_info,var_heap,error))
								= toTypeCodeExpression (add_universal_vars_to_type dt_uni_vars dt_type) (type_code_info, var_heap, error)
						  expr_heap = expr_heap <:= (dyn_ptr, EI_TypeOfDynamicPattern var_ptrs type_code_expr no_contexts)
						-> convert_local_dynamics loc_dynamics (type_code_info, expr_heap, type_pattern_vars, var_heap, error)
					EI_Empty
						# (var_ptrs, (type_pattern_vars, var_heap)) = mapSt addLocalTCInstance temp_local_vars (type_pattern_vars, var_heap)
						  type_var_heap = bind_type_vars_to_type_var_codes type_vars var_ptrs type_code_info.tci_type_var_heap
  						  dt_type = add_types_of_dictionaries dt_contexts dt_type type_code_info.tci_common_defs
						  type_code_info = {type_code_info & tci_type_var_heap = type_var_heap}
						  (type_code_expr, (type_code_info,var_heap,error))
								= toTypeCodeExpression (add_universal_vars_to_type dt_uni_vars dt_type) (type_code_info, var_heap, error)
						  expr_heap = expr_heap <:= (dyn_ptr, EI_TypeOfDynamicPattern var_ptrs type_code_expr no_contexts)
						-> convert_local_dynamics loc_dynamics (type_code_info, expr_heap, type_pattern_vars, var_heap, error)
	where
		add_types_of_dictionaries [{tc_var,tc_class=TCClass {glob_module,glob_object={ds_index}},tc_types}:dictionaries_and_contexts] atype common_defs
			# class_type = class_to_dictionary_type glob_module ds_index tc_types common_defs
			= {at_attribute=TA_Multi, at_type=class_type --> add_types_of_dictionaries dictionaries_and_contexts atype common_defs}
		add_types_of_dictionaries [] atype common_defs
			= atype

		bind_type_vars_to_type_codes symb_ident type_vars type_codes type_var_heap var_heap error
			= fold2St (bind_type_var_to_type_code symb_ident) type_vars type_codes (type_var_heap, var_heap, error)
		where
			bind_type_var_to_type_code symb_ident {tv_ident,tv_info_ptr} type_code (type_var_heap, var_heap, error)
				# (type_code, (var_heap, error)) = updateFreeVarsOfTCE symb_ident type_code (var_heap, error)
				= (type_var_heap <:= (tv_info_ptr, TVI_TypeCode type_code), var_heap, error)
	
		bind_type_vars_to_type_var_codes type_vars var_ptrs type_var_heap
			= fold2St bind_type_var_to_type_var_code type_vars var_ptrs type_var_heap
		where
			bind_type_var_to_type_var_code {tv_info_ptr} var_ptr type_var_heap
				= type_var_heap <:= (tv_info_ptr, TVI_TypeCode (TCE_Var var_ptr))

		add_universal_vars_to_type [] at
			= at
		add_universal_vars_to_type uni_vars at=:{at_type}
			= { at & at_type = TFA uni_vars at_type }

		convert_local_dynamics loc_dynamics state
			= foldSt update_dynamic loc_dynamics state

		convert_selectors [type_code_selector] var_info_ptr
			= TCE_TypeTerm var_info_ptr
		convert_selectors selectors var_info_ptr
			= TCE_Selector (init selectors) var_info_ptr

newTypeVariables uni_vars heaps
	= mapSt new_type_variable uni_vars heaps
where			
	new_type_variable {atv_variable = {tv_info_ptr}} (type_var_heap, var_heap)
		# (new_var_ptr, var_heap) = newPtr VI_Empty var_heap
		= (new_var_ptr, (type_var_heap <:= (tv_info_ptr, TVI_TypeCode (TCE_Var new_var_ptr)), var_heap))

updateFreeVarsOfTCE :: !Ident !TypeCodeExpression (!*VarHeap, !*ErrorAdmin) -> (!TypeCodeExpression, !(!*VarHeap, *ErrorAdmin))
updateFreeVarsOfTCE symb_ident (TCE_Constructor type_cons type_args) var_heap_and_error 
	# (type_args, var_heap_and_error) = mapSt (updateFreeVarsOfTCE symb_ident) type_args var_heap_and_error 
	= (TCE_Constructor type_cons type_args, var_heap_and_error)
updateFreeVarsOfTCE symb_ident (TCE_Selector selections var_info_ptr) var_heap_and_error
	# (var_info_ptr, var_heap_and_error) = getTCDictionary symb_ident var_info_ptr var_heap_and_error
	= (TCE_Selector selections var_info_ptr, var_heap_and_error)
updateFreeVarsOfTCE symb_ident (TCE_TypeTerm var_info_ptr) var_heap_and_error 
	# (var_info_ptr, var_heap_and_error) = getTCDictionary symb_ident var_info_ptr var_heap_and_error
	= (TCE_TypeTerm var_info_ptr, var_heap_and_error)
updateFreeVarsOfTCE symb_ident tce var_heap_and_error
	= (tce, var_heap_and_error)

try_update_free_vars_of_TCE :: !TypeCodeExpression !(![VarInfoPtr],!*VarHeap) -> (!TypeCodeExpression, !(![VarInfoPtr],!*VarHeap))
try_update_free_vars_of_TCE (TCE_Constructor type_cons type_args) var_info_ptrs_and_heap 
	# (type_args, var_info_ptrs_and_heap) = mapSt try_update_free_vars_of_TCE type_args var_info_ptrs_and_heap 
	= (TCE_Constructor type_cons type_args, var_info_ptrs_and_heap)
try_update_free_vars_of_TCE (TCE_Selector selections var_info_ptr) var_info_ptrs_and_heap
	# (var_info_ptr, var_info_ptrs_and_heap) = try_getTCDictionary var_info_ptr var_info_ptrs_and_heap
	= (TCE_Selector selections var_info_ptr, var_info_ptrs_and_heap)
try_update_free_vars_of_TCE (TCE_TypeTerm var_info_ptr) var_info_ptrs_and_heap 
	# (var_info_ptr, var_info_ptrs_and_heap) = try_getTCDictionary var_info_ptr var_info_ptrs_and_heap
	= (TCE_TypeTerm var_info_ptr, var_info_ptrs_and_heap)
try_update_free_vars_of_TCE tce var_info_ptrs_and_heap
	= (tce, var_info_ptrs_and_heap)

update_undefined_free_vars_of_TCE :: !Ident ![VarInfoPtr] !TypeCodeExpression !(!*VarHeap,!*ErrorAdmin) -> (!TypeCodeExpression,!(!*VarHeap,!*ErrorAdmin))
update_undefined_free_vars_of_TCE symb_ident undefined_var_info_ptrs (TCE_Constructor type_cons type_args) var_heap_and_error
	# (type_args, var_heap_and_error) = mapSt (update_undefined_free_vars_of_TCE symb_ident undefined_var_info_ptrs) type_args var_heap_and_error 
	= (TCE_Constructor type_cons type_args, var_heap_and_error)
update_undefined_free_vars_of_TCE symb_ident undefined_var_info_ptrs tce=:(TCE_Selector selections var_info_ptr) var_heap_and_error
	| IsMember var_info_ptr undefined_var_info_ptrs
		# (var_info_ptr, var_heap_and_error) = getTCDictionary symb_ident var_info_ptr var_heap_and_error
		= (TCE_Selector selections var_info_ptr, var_heap_and_error)
		= (tce, var_heap_and_error)
update_undefined_free_vars_of_TCE symb_ident undefined_var_info_ptrs tce=:(TCE_TypeTerm var_info_ptr) var_heap_and_error 
	| IsMember var_info_ptr undefined_var_info_ptrs
		# (var_info_ptr, var_heap_and_error) = getTCDictionary symb_ident var_info_ptr var_heap_and_error
		= (TCE_TypeTerm var_info_ptr, var_heap_and_error)
		= (tce, var_heap_and_error)
update_undefined_free_vars_of_TCE symb_ident undefined_var_info_ptrs tce var_heap_and_error
	= (tce, var_heap_and_error)

getTCDictionary symb_ident var_info_ptr (var_heap, error)
	# (var_info, var_heap) = readPtr var_info_ptr var_heap
	= case var_info of
		VI_ClassVar var_ident new_info_ptr count
			-> (new_info_ptr, (var_heap <:= (var_info_ptr, VI_ClassVar var_ident new_info_ptr (inc count)), error))
		_
			-> (var_info_ptr, (var_heap, overloadingError symb_ident error))

try_getTCDictionary :: !VarInfoPtr !(![VarInfoPtr],!*VarHeap) -> (!VarInfoPtr,!(![VarInfoPtr],!*VarHeap))
try_getTCDictionary var_info_ptr (var_info_ptrs,var_heap)
	# (var_info, var_heap) = readPtr var_info_ptr var_heap
	= case var_info of
		VI_ClassVar var_ident new_info_ptr count
			-> (new_info_ptr, (var_info_ptrs,writePtr var_info_ptr (VI_ClassVar var_ident new_info_ptr (inc count)) var_heap))
		_
			-> (var_info_ptr, ([var_info_ptr:var_info_ptrs],var_heap))

toTypeCodeConstructor type=:{glob_object=type_index, glob_module=module_index} common_defs
	| module_index == cPredefinedModuleIndex
		= GTT_PredefTypeConstructor type
	// otherwise
		# type = common_defs.[module_index].com_type_defs.[type_index]
		# td_fun_index = type.td_fun_index
		// sanity check ...
		| td_fun_index == NoIndex
			=	fatal "toTypeCodeConstructor" ("no function (" +++ type.td_ident.id_name +++ ")")
		// ... sanity check
		# type_fun
			=	{	symb_ident = {id_name = "TD;"+++type.td_ident.id_name, id_info = nilPtr}
				,	symb_kind = SK_Function {glob_module = module_index, glob_object = td_fun_index}
				}
		# is_unique_type
			= case type.td_attribute of
				TA_Unique -> True
				_ -> False
		= GTT_Constructor type_fun is_unique_type

fatal :: {#Char} {#Char} -> .a
fatal function_name message
	=	abort ("overloading, " +++ function_name +++ ": " +++ message)

class toTypeCodeExpression type :: type !(!*TypeCodeInfo,!*VarHeap,!*ErrorAdmin) -> (!TypeCodeExpression, !(!*TypeCodeInfo,!*VarHeap,!*ErrorAdmin))

instance toTypeCodeExpression Type where
	toTypeCodeExpression type=:(TA cons_id=:{type_index} type_args) (tci=:{tci_common_defs},var_heap,error)
		# type_heaps = {th_vars = tci.tci_type_var_heap, th_attrs = tci.tci_attr_var_heap}
		# (expanded, type, type_heaps)
			=	tryToExpandTypeSyn tci_common_defs type cons_id type_args type_heaps
		# tci = {tci & tci_type_var_heap = type_heaps.th_vars, tci_attr_var_heap = type_heaps.th_attrs}
		| expanded
			=	toTypeCodeExpression type (tci,var_heap,error)
		# type_constructor = toTypeCodeConstructor type_index tci_common_defs
		  (type_code_args, tci)
			=	mapSt toTypeCodeExpression type_args (tci,var_heap,error)
		= (TCE_Constructor type_constructor type_code_args, tci)
	toTypeCodeExpression (TAS cons_id type_args _) state
		=	toTypeCodeExpression (TA cons_id type_args) state
	toTypeCodeExpression (TB basic_type) (tci,var_heap,error)
		= (TCE_Constructor (GTT_Basic basic_type) [], (tci,var_heap,error))
	toTypeCodeExpression (arg_type --> result_type) (tci,var_heap,error)
		# (type_code_args, tci) = mapSt (toTypeCodeExpression) [arg_type, result_type] (tci,var_heap,error)
		= (TCE_Constructor GTT_Function type_code_args, tci)
	toTypeCodeExpression (TV var) st
		= toTypeCodeExpression var st
	toTypeCodeExpression (TFA vars type) (tci=:{tci_type_var_heap}, var_heap, error)
		# (new_vars, (tci_type_var_heap, var_heap)) = newTypeVariables vars (tci_type_var_heap, var_heap)
		  (type_code, tci) = toTypeCodeExpression type ({tci & tci_type_var_heap = tci_type_var_heap}, var_heap, error)
		= (TCE_UniType new_vars type_code, tci)
	toTypeCodeExpression (CV var :@: args) st
		# (type_code_var, st)
			=	toTypeCodeExpression var st
		  (type_code_args, st)
		  	=	mapSt (toTypeCodeExpression) args st
		= (foldl TCE_App type_code_var type_code_args, st)

instance toTypeCodeExpression TypeVar where
	toTypeCodeExpression {tv_ident,tv_info_ptr} (tci=:{tci_type_var_heap}, var_heap, error)
		# (type_info, tci_type_var_heap) = readPtr tv_info_ptr tci_type_var_heap
		  tci = { tci & tci_type_var_heap = tci_type_var_heap }
		= case type_info of
			TVI_TypeCode type_code
				-> (type_code, (tci,var_heap,error))
			_
				-> abort ("toTypeCodeExpression (TypeVar)" ---> ((ptrToInt tv_info_ptr, tv_ident)))

instance toTypeCodeExpression AType
where
	toTypeCodeExpression {at_attribute=TA_Unique, at_type} tci_and_var_heap_and_error
		# (tce, st)
			=	toTypeCodeExpression at_type tci_and_var_heap_and_error
		=	(TCE_UnqType tce, st)
	toTypeCodeExpression {at_type} tci_and_var_heap_and_error
		=	toTypeCodeExpression at_type tci_and_var_heap_and_error

::	UpdateInfo =
	{	ui_instance_calls	:: ![FunCall]
	,	ui_local_vars		:: ![FreeVar]
	,	ui_symbol_heap		:: !.ExpressionHeap
	,	ui_var_heap			:: !.VarHeap
	,	ui_fun_defs			:: !.{# FunDef}
	,	ui_fun_env			:: !.{! FunctionType}
	,	ui_error			:: !.ErrorAdmin
	,	ui_has_type_codes	:: !Bool
	,	ui_x 				:: !.UpdateInfoX
	}

:: UpdateInfoX =
	{	x_type_code_info	:: !.TypeCodeInfo
	,	x_predef_symbols	:: !.{#PredefinedSymbol}
	,	x_main_dcl_module_n :: !Int
	}

class updateExpression e :: !Index !e !*UpdateInfo -> (!e, !*UpdateInfo)

instance updateExpression Expression
where
	updateExpression group_index (App {app_symb={symb_kind=SK_NewTypeConstructor _},app_args=[arg]}) ui
		= updateExpression group_index arg ui
	updateExpression group_index (App app=:{app_symb=symb=:{symb_kind,symb_ident},app_args,app_info_ptr}) ui
		| isNilPtr app_info_ptr
			# (app_args, ui) = updateExpression group_index app_args ui
			= (App {app & app_args = app_args}, ui)
			# (symb_info, ui_symbol_heap) = readPtr app_info_ptr ui.ui_symbol_heap
			  ui = {ui & ui_symbol_heap = ui_symbol_heap}
			= case symb_info of
				EI_Empty
					# (app_args, ui) = updateExpression group_index app_args ui
					#! main_dcl_module_n = ui.ui_x.UpdateInfoX.x_main_dcl_module_n
					#! fun_index = get_recursive_fun_index group_index symb_kind main_dcl_module_n ui.ui_fun_defs
					| fun_index == NoIndex
						-> (App { app & app_args = app_args }, ui)
						# (CheckedType {st_context}, ui) = ui!ui_fun_env.[fun_index]
						  (app_args, (ui_var_heap, ui_error)) = mapAppendSt (build_context_arg symb_ident) st_context app_args (ui.ui_var_heap, ui.ui_error)
						-> (App { app & app_args = app_args }, { ui & ui_var_heap = ui_var_heap, ui_error = ui_error })
				EI_Context context_args
					# (app_args, ui) = updateExpression group_index app_args ui
					# (app_args, ui) = adjustClassExpressions symb_ident context_args app_args ui
					#! main_dcl_module_n = ui.ui_x.UpdateInfoX.x_main_dcl_module_n
					#! fun_index = get_recursive_fun_index group_index symb_kind main_dcl_module_n ui.ui_fun_defs
					| fun_index == NoIndex
						# app = { app & app_args = app_args}
						-> (App app, examine_calls context_args ui)
						# (CheckedType {st_context}, ui) = ui!ui_fun_env.[fun_index]
						  nr_of_context_args = length context_args
						  nr_of_lifted_contexts = length st_context - nr_of_context_args
						  (app_args, (ui_var_heap, ui_error)) = mapAppendSt (build_context_arg symb_ident) (take nr_of_lifted_contexts st_context) app_args (ui.ui_var_heap,ui.ui_error)
						-> (App { app & app_args = app_args }, examine_calls context_args {ui & ui_var_heap = ui_var_heap, ui_error = ui_error })
				EI_Instance inst_symbol context_args
					# (app_args, ui) = updateExpression group_index app_args ui
					# (context_args, ui=:{ui_var_heap, ui_error}) = adjustClassExpressions symb_ident context_args [] ui
					-> (build_application inst_symbol context_args app_args app_info_ptr,
							examine_calls context_args (new_call inst_symbol.glob_module inst_symbol.glob_object.ds_index
								{ ui & ui_var_heap = ui_var_heap, ui_error = ui_error }))
				EI_Selection selectors record_var context_args
					# (app_args, ui) = updateExpression group_index app_args ui
					# (all_args, ui=:{ui_var_heap, ui_error}) = adjustClassExpressions symb_ident context_args app_args ui
					  (var_ident, var_info_ptr, ui_var_heap, ui_error) = getClassVariable symb_ident record_var ui_var_heap ui_error
					  select_expr = Selection NormalSelector (Var { var_ident = var_ident, var_info_ptr = var_info_ptr, var_expr_ptr = nilPtr }) selectors
					| isEmpty all_args
						-> (select_expr, { ui & ui_var_heap = ui_var_heap, ui_error = ui_error })
						-> (select_expr @ all_args, examine_calls context_args
								{ ui & ui_var_heap = ui_var_heap, ui_error = ui_error })
				EI_ContextWithVarContexts context_args var_contexts
					# (app_args,ui) = add_class_vars_for_var_contexts_and_update_expressions var_contexts app_args 0 group_index symb_ident ui
					# (app_args, ui) = adjustClassExpressions symb_ident context_args app_args ui
					#! main_dcl_module_n = ui.ui_x.UpdateInfoX.x_main_dcl_module_n
					#! fun_index = get_recursive_fun_index group_index symb_kind main_dcl_module_n ui.ui_fun_defs
					| fun_index == NoIndex
						# app = {app & app_args = app_args}
						-> (App app, examine_calls context_args ui)
						# (CheckedType {st_context}, ui) = ui!ui_fun_env.[fun_index]
						  nr_of_context_args = length context_args
						  nr_of_lifted_contexts = length st_context - nr_of_context_args
						  (app_args, (ui_var_heap, ui_error)) = mapAppendSt (build_context_arg symb_ident) (take nr_of_lifted_contexts st_context) app_args (ui.ui_var_heap,ui.ui_error)
						-> (App {app & app_args = app_args}, examine_calls context_args {ui & ui_var_heap = ui_var_heap, ui_error = ui_error })
	where
		build_context_arg symb tc=:{tc_var} (var_heap, error)
			# (var_info, var_heap) = readPtr tc_var var_heap
			= case var_info of
				VI_ForwardClassVar var_info_ptr
					# (var_ident, var_info_ptr, var_heap, error) = getClassVariable symb var_info_ptr var_heap error
					-> (Var { var_ident = var_ident, var_info_ptr = var_info_ptr, var_expr_ptr = nilPtr }, (var_heap, error))
				VI_ClassVar var_ident new_info_ptr count
					-> (Var { var_ident = var_ident, var_info_ptr = new_info_ptr, var_expr_ptr = nilPtr },
								(var_heap <:= (tc_var, VI_ClassVar var_ident new_info_ptr (inc count)), error))
				VI_ContextContainsFreeTypeVar {tc_class,tc_types}
					# (new_info_ptr, var_heap) = newPtr VI_Empty var_heap
					# error = overloadingErrorWithContext symb tc_class tc_types error
					-> (Var { var_ident = symb, var_info_ptr = new_info_ptr, var_expr_ptr = nilPtr },
								(var_heap <:= (tc_var, VI_ClassVar symb new_info_ptr 1), error))
				VI_MissingContext {tc_class,tc_types}
					# (new_info_ptr, var_heap) = newPtr VI_Empty var_heap
					# error = missingContextError symb tc_class tc_types error
					-> (Var { var_ident = symb, var_info_ptr = new_info_ptr, var_expr_ptr = nilPtr },
								(var_heap <:= (tc_var, VI_ClassVar symb new_info_ptr 1), error))
				_
					# (new_info_ptr, var_heap) = newPtr VI_Empty var_heap
					-> (Var { var_ident = symb, var_info_ptr = new_info_ptr, var_expr_ptr = nilPtr },
								(var_heap <:= (tc_var, VI_ClassVar symb new_info_ptr 1), overloadingError symb error))

		add_class_vars_for_var_contexts_and_update_expressions var_contexts=:(VarContext arg_n context arg_atype var_contexts_t) [app_arg:app_args] app_arg_n group_index symb_ident ui
			| app_arg_n<arg_n
				# (app_arg,ui) = updateExpression group_index app_arg ui
				  (app_args,ui) = add_class_vars_for_var_contexts_and_update_expressions var_contexts app_args (app_arg_n+1) group_index symb_ident ui
				= ([app_arg:app_args],ui)
			| app_arg_n==arg_n
				# (old_var_infos,var_heap) = add_class_vars_for_var_context context ui.ui_var_heap
				  (app_arg,ui) = updateExpression group_index app_arg {ui & ui_var_heap=var_heap}
				#! (free_vars_and_types,local_vars,var_heap)
					= restore_old_var_infos_and_retrieve_class_vars context old_var_infos ui.ui_local_vars ui.ui_var_heap
				# ui = {ui & ui_local_vars=local_vars,ui_var_heap=var_heap}
				= case app_arg of
					expr @ args
						| same_args args free_vars_and_types
							# app_arg = expr
							  (app_args,ui) = add_class_vars_for_var_contexts_and_update_expressions var_contexts_t app_args (app_arg_n+1) group_index symb_ident ui
							-> ([app_arg:app_args],ui)
					_
						# app_arg = DictionariesFunction free_vars_and_types app_arg arg_atype
						  (app_args,ui) = add_class_vars_for_var_contexts_and_update_expressions var_contexts_t app_args (app_arg_n+1) group_index symb_ident ui
						-> ([app_arg:app_args],ui)
		add_class_vars_for_var_contexts_and_update_expressions (VarContext _ _ _ _) [] app_arg_n group_index symb_ident ui
			# ui & ui_error = cannotAddDictionaryError symb_ident ui.ui_error
			= ([],ui)
		add_class_vars_for_var_contexts_and_update_expressions NoVarContexts app_args app_arg_n group_index symb_ident ui
			= updateExpression group_index app_args ui

		same_args [] []
			= True
		same_args [Var {var_info_ptr}:args] [({fv_info_ptr},_):free_vars_and_types]
			= var_info_ptr==fv_info_ptr && same_args args free_vars_and_types
		same_args _ _
			= False

		get_recursive_fun_index :: !Index !SymbKind Int !{# FunDef} -> Index
		get_recursive_fun_index group_index (SK_Function {glob_module,glob_object}) main_dcl_module_n fun_defs
			| glob_module == main_dcl_module_n
				# {fun_info} = fun_defs.[glob_object]
				| fun_info.fi_group_index == group_index
					= glob_object
					= NoIndex
				= NoIndex
		get_recursive_fun_index group_index (SK_LocalMacroFunction glob_object) main_dcl_module_n fun_defs
			# {fun_info} = fun_defs.[glob_object]
			| fun_info.fi_group_index == group_index
				= glob_object
				= NoIndex
		get_recursive_fun_index group_index _ main_dcl_module_n fun_defs
			= NoIndex

		build_application def_symbol=:{glob_object} context_args orig_args app_info_ptr
			= App {app_symb = { symb_ident = glob_object.ds_ident,
									symb_kind = SK_Function { def_symbol & glob_object = glob_object.ds_index } },
				   app_args = context_args ++ orig_args, app_info_ptr = app_info_ptr }

	updateExpression group_index (expr @ exprs) ui
		# ((expr, exprs), ui) = updateExpression group_index (expr, exprs) ui
		= (expr @ exprs, ui)
	updateExpression group_index (Let lad=:{let_lazy_binds, let_strict_binds, let_expr}) ui
		# ui = set_aliases_for_binds_that_will_become_aliases let_lazy_binds ui
		# (let_lazy_binds, ui)		= updateExpression group_index let_lazy_binds ui
		# (let_strict_binds, ui)	= updateExpression group_index let_strict_binds ui
		# (let_expr, ui)			= updateExpression group_index let_expr ui
		= (Let {lad & let_lazy_binds = let_lazy_binds, let_strict_binds = let_strict_binds, let_expr = let_expr}, ui)

	updateExpression group_index (Case kees=:{case_guards=case_guards=:AlgebraicPatterns type patterns,case_expr,case_default,case_info_ptr}) ui
		# (case_info, ui_symbol_heap) = readPtr case_info_ptr ui.ui_symbol_heap
		  ui = {ui & ui_symbol_heap = ui_symbol_heap}
		= case case_info of
			EI_CaseTypeWithContexts case_type=:{ct_cons_types} constructorcontexts
				# (case_expr,ui) = updateExpression group_index case_expr ui
				  (patterns,ct_cons_types,ui) = update_constructors_with_contexts_patterns constructorcontexts patterns ct_cons_types group_index ui
				  case_guards = AlgebraicPatterns type patterns
				  (case_default,ui) = updateExpression group_index case_default ui
				  ui_symbol_heap = writePtr case_info_ptr (EI_CaseType {case_type & ct_cons_types=ct_cons_types}) ui.ui_symbol_heap
				  ui = {ui & ui_symbol_heap = ui_symbol_heap}
				-> (Case {kees & case_expr = case_expr, case_guards = case_guards, case_default = case_default}, ui)
			EI_CaseType {ct_cons_types}
				| Any has_TFAC ct_cons_types
					# (case_expr,ui) = updateExpression group_index case_expr ui
					  (patterns, ui) = update_algebraic_patterns patterns ct_cons_types group_index ui
					  case_guards = AlgebraicPatterns type patterns
					  (case_default, ui) = updateExpression group_index case_default ui
					-> (Case {kees & case_expr = case_expr, case_guards = case_guards, case_default = case_default}, ui)
			_
				# ((case_expr,(case_guards,case_default)), ui) = updateExpression group_index (case_expr,(case_guards,case_default)) ui
				-> (Case {kees & case_expr = case_expr, case_guards = case_guards, case_default = case_default}, ui)

	updateExpression group_index case_expr=:(Case {case_guards=NewTypePatterns _ _}) ui
		= remove_NewTypePatterns_case_and_update_expression case_expr group_index ui
	updateExpression group_index (Case kees=:{case_expr,case_guards,case_default}) ui
		# ((case_expr,(case_guards,case_default)), ui) = updateExpression group_index (case_expr,(case_guards,case_default)) ui
		= (Case { kees & case_expr = case_expr, case_guards = case_guards, case_default = case_default }, ui)
	updateExpression group_index (Selection is_unique expr selectors) ui
		# (expr, ui) = updateExpression group_index expr ui
		  (selectors, ui) = updateExpression group_index selectors ui
		= (Selection is_unique expr selectors, ui)
	updateExpression group_index (Update expr1 selectors expr2) ui
		# (expr1, ui) = updateExpression group_index expr1 ui
		  (selectors, ui) = updateExpression group_index selectors ui
		  (expr2, ui) = updateExpression group_index expr2 ui
		= (Update expr1 selectors expr2, ui)
	updateExpression group_index (RecordUpdate cons_symbol expression expressions) ui
		# (expression, ui) = updateExpression group_index expression ui
		  (expressions, ui) = updateExpression group_index expressions ui
		= (RecordUpdate cons_symbol expression expressions, ui)
	updateExpression group_index (DynamicExpr dyn=:{dyn_expr,dyn_info_ptr}) ui=:{ui_has_type_codes}
		# (dyn_info, ui_symbol_heap) = readPtr dyn_info_ptr ui.ui_symbol_heap
		  ui = {ui & ui_has_type_codes = False, ui_symbol_heap = ui_symbol_heap}
		  (dyn_expr,type_code,ui)
			= case dyn_info of
				EI_TypeOfDynamic type_code
					# (dyn_expr, ui) = updateExpression group_index dyn_expr ui
					-> (dyn_expr,type_code,ui)
				EI_TypeOfDynamicAndTCsToFind type_expr symb_ident undefined_tc_class_vars
					# (type_expr, (var_heap, error))
						= update_undefined_free_vars_of_TCE symb_ident undefined_tc_class_vars type_expr (ui.ui_var_heap, ui.ui_error)
					  ui & ui_var_heap=var_heap, ui_error=error
					  (dyn_expr, ui) = updateExpression group_index dyn_expr ui
					-> (dyn_expr,type_expr,ui)
				EI_TypeOfDynamicWithContexts type_code (VarContext _ context dynamic_expr_type NoVarContexts)
					# (old_var_infos,var_heap) = add_class_vars_for_var_context context ui.ui_var_heap
					  (dyn_expr,ui) = updateExpression group_index dyn_expr {ui & ui_var_heap=var_heap}
					  (free_vars_and_types,local_vars,var_heap)
						= restore_old_var_infos_and_retrieve_class_vars context old_var_infos ui.ui_local_vars ui.ui_var_heap
					  ui = {ui & ui_local_vars=local_vars,ui_var_heap=var_heap}
					  dyn_expr = DictionariesFunction free_vars_and_types dyn_expr dynamic_expr_type
					-> (dyn_expr,type_code,ui)
		  ui = check_type_codes_in_dynamic ui
			with
				check_type_codes_in_dynamic ui=:{ui_has_type_codes, ui_error}
					| ui_has_type_codes
						# ui_error = typeCodeInDynamicError ui_error
						= {ui & ui_error = ui_error}
						= ui
		  ui = {ui & ui_has_type_codes=ui_has_type_codes}
		= (DynamicExpr { dyn & dyn_expr = dyn_expr, dyn_type_code = type_code }, ui)
	updateExpression group_index (TupleSelect symbol argn_nr expr) ui
		# (expr, ui) = updateExpression group_index expr ui
		= (TupleSelect symbol argn_nr expr, ui)
	updateExpression group_index (MatchExpr cons_symbol=:{glob_object={ds_arity}} expr) ui
		| ds_arity <> -2
			# (expr, ui) = updateExpression group_index expr ui
			= (MatchExpr cons_symbol expr, ui)
			// newtype constructor
			= updateExpression group_index expr ui
	updateExpression group_index (IsConstructor expr cons_symbol cons_arity global_type_index case_ident position) ui
		# (expr, ui) = updateExpression group_index expr ui
		= (IsConstructor expr cons_symbol cons_arity global_type_index case_ident position, ui)
	updateExpression group_index (TypeSignature _ expr) ui
		= updateExpression group_index expr ui
	updateExpression group_index expr=:(Var {var_info_ptr,var_expr_ptr,var_ident}) ui
		# (var_info,var_heap) = readPtr var_info_ptr ui.ui_var_heap
		# ui = {ui & ui_var_heap = var_heap}
		= case var_info of
			VI_Alias var2
				# (var_info2,var_heap) = readPtr var2.var_info_ptr ui.ui_var_heap
				# ui = { ui & ui_var_heap = var_heap }
				-> skip_aliases var_info2 var2 var_info_ptr ui
			VI_FPC
				# (expr_info,ui_symbol_heap) = readPtr var_expr_ptr ui.ui_symbol_heap
				# ui = {ui & ui_symbol_heap=ui_symbol_heap}
				-> case expr_info of
					EI_FPContext context_args var_expr_ptr
						# (app_args, ui) = adjustClassExpressions var_ident context_args [] ui
						# ui = examine_calls context_args ui
						-> (expr @ app_args,ui)
			_
				-> (expr,ui)
	where
		skip_aliases var_info2=:(VI_Alias var3) var2 var_info_ptr1 ui=:{ui_var_heap}
			# ui = set_alias_and_detect_cycle var_info_ptr1 var3 ui
			| var3.var_info_ptr==var_info_ptr1
				= (Var var2,ui)
				# (var_info3,var_heap) = readPtr var3.var_info_ptr ui.ui_var_heap
				# ui = { ui & ui_var_heap = var_heap }
				= skip_aliases var_info3 var3 var2.var_info_ptr ui
		skip_aliases var_info2 var2 var_info ui
			= (Var var2,ui)
	updateExpression group_index expr ui
		= (expr, ui)

update_constructors_with_contexts_patterns [constructor_context:constructor_contexts] patterns cons_types group_index ui
	= update_constructor_with_contexts_patterns constructor_context constructor_contexts patterns cons_types group_index ui
where
	update_constructor_with_contexts_patterns constructor_context=:(constructor_symbol,context) constructor_contexts [pattern:patterns] [cons_type:cons_types] group_index ui
		| constructor_symbol==pattern.ap_symbol.glob_object
			# (old_var_infos,var_heap) = make_class_vars context ui.ui_var_heap
			  ui = {ui & ui_var_heap=var_heap}					  

			  (expr,ui) = updateExpression group_index pattern.ap_expr ui

			  vars = pattern.ap_vars
			  arity = pattern.ap_symbol.glob_object.ds_arity
			  (vars,arity,local_vars,var_heap) = add_class_vars_to_pattern_and_restore_old_var_infos context old_var_infos vars arity ui.ui_local_vars ui.ui_var_heap
			  ui = {ui & ui_local_vars=local_vars,ui_var_heap=var_heap}
			  pattern = {pattern & ap_vars=vars,ap_expr=expr,ap_symbol.glob_object.ds_arity=arity}
			  (patterns,cons_types,ui) = update_constructors_with_contexts_patterns constructor_contexts patterns cons_types group_index ui

			  (common_defs,ui) = ui!ui_x.x_type_code_info.tci_common_defs
			  cons_type = addTypesOfDictionaries common_defs context cons_type

			= ([pattern:patterns],[cons_type:cons_types],ui)

			# (pattern,ui) = updateExpression group_index pattern ui
			  (patterns,cons_types,ui) = update_constructor_with_contexts_patterns constructor_context constructor_contexts patterns cons_types group_index ui
			= ([pattern:patterns],[cons_type:cons_types],ui)

	make_class_vars [tc=:{tc_class,tc_var}:contexts] var_heap
		# (old_var_infos,var_heap) = make_class_vars contexts var_heap
		  (old_var_info,var_heap) = readPtr tc_var var_heap
	  	  (var_info_ptr, var_heap) = newPtr VI_Empty var_heap
		  ident = {id_name = "_v" +++ toString tc_class, id_info = nilPtr}
		  (new_info_ptr, var_heap) = newPtr VI_Empty var_heap
		  var_heap = writePtr tc_var (VI_ClassVar ident new_info_ptr 0) var_heap
		= ([old_var_info:old_var_infos],var_heap)
	make_class_vars [] var_heap
		= ([],var_heap)

	add_class_vars_to_pattern_and_restore_old_var_infos [{tc_var}:contexts] [old_var_info:old_var_infos] vars arity local_vars var_heap
		# (vars,arity,local_vars,var_heap) = add_class_vars_to_pattern_and_restore_old_var_infos contexts old_var_infos vars arity local_vars var_heap
		  (VI_ClassVar var_ident new_info_ptr count, var_heap) = readPtr tc_var var_heap
		  free_var = {fv_ident=var_ident, fv_info_ptr=new_info_ptr, fv_def_level=NotALevel, fv_count=count}
		  var_heap = writePtr tc_var old_var_info var_heap
		= ([free_var:vars],arity+1,[free_var:local_vars],var_heap)
	add_class_vars_to_pattern_and_restore_old_var_infos [] [] vars arity local_vars var_heap
		= (vars,arity,local_vars,var_heap)
update_constructors_with_contexts_patterns [] patterns cons_types group_index ui
	# (patters,ui) = updateExpression group_index patterns ui
	= (patters,cons_types,ui)

update_algebraic_patterns [pattern=:{ap_expr,ap_vars}:patterns] [cons_arg_types:conses_args_types] group_index ui
	# ui & ui_var_heap = mark_FPC_vars cons_arg_types ap_vars ui.ui_var_heap
	# (ap_expr,ui) = updateExpression group_index ap_expr ui
	# (patterns,ui) = update_algebraic_patterns patterns conses_args_types group_index ui
	= ([{pattern & ap_expr=ap_expr}:patterns],ui)
update_algebraic_patterns [] [] group_index ui
	= ([],ui)

add_class_vars_for_var_context [{dc_var}:contexts] var_heap
	# (var_info,var_heap) = readPtr dc_var var_heap
	  symb = {id_name = "_d", id_info = nilPtr}
	  (new_info_ptr, var_heap) = newPtr VI_Empty var_heap
	  var_heap = writePtr dc_var (VI_ClassVar symb new_info_ptr 0) var_heap
	  (old_var_infos,var_heap) = add_class_vars_for_var_context contexts var_heap
	= ([var_info:old_var_infos],var_heap)
add_class_vars_for_var_context [] var_heap
	= ([],var_heap)

restore_old_var_infos_and_retrieve_class_vars [{dc_var,dc_class_type}:contexts] [old_var_info:old_var_infos] local_vars var_heap		
	# (VI_ClassVar var_ident new_info_ptr count, var_heap) = readPtr dc_var var_heap
	  free_var = {fv_ident=var_ident, fv_info_ptr=new_info_ptr, fv_def_level=NotALevel, fv_count=count}
	  var_heap = writePtr dc_var old_var_info var_heap
	  (free_vars_and_types,local_vars,var_heap)
	  	= restore_old_var_infos_and_retrieve_class_vars contexts old_var_infos local_vars var_heap
	= ([(free_var,dc_class_type):free_vars_and_types],[free_var:local_vars],var_heap)
restore_old_var_infos_and_retrieve_class_vars [] [] local_vars var_heap
	= ([],local_vars,var_heap)

examine_calls [expr : exprs] ui
	= examine_calls exprs (examine_calls_in_expr expr ui)
where
	examine_calls_in_expr (App {app_symb = {symb_ident,symb_kind}, app_args}) ui
		= examine_calls app_args (examine_application symb_kind ui)
	examine_calls_in_expr (Let {let_expr,let_lazy_binds}) ui
		# ui = examine_calls_in_expr let_expr ui
		= foldSt (examine_calls_bind) let_lazy_binds (examine_calls_in_expr let_expr ui)
	examine_calls_in_expr _ ui
		= ui

	examine_calls_bind {lb_src,lb_dst} ui=:{ui_local_vars}
		= examine_calls_in_expr lb_src {ui & ui_local_vars = [lb_dst : ui_local_vars]}

	examine_application (SK_Function {glob_module,glob_object}) ui
		= new_call glob_module glob_object ui
	examine_application symb_kind ui
		= ui
examine_calls [] ui
	= ui

new_call mod_index symb_index ui=:{ui_instance_calls,ui_fun_defs}
	| mod_index == ui.ui_x.UpdateInfoX.x_main_dcl_module_n && symb_index < size ui_fun_defs
		# ui_instance_calls = add_call symb_index ui_instance_calls
		= {ui & ui_instance_calls = ui_instance_calls}
		= ui
where
	add_call fun_num []
		= [FunCall fun_num 0]
	add_call fun_num funs=:[call=:(FunCall fc_index _) : ui]
		| fun_num == fc_index
			= funs
		| fun_num < fc_index
			= [FunCall fun_num 0 : funs]
			= [call : add_call fun_num ui]

set_alias_and_detect_cycle info_ptr var ui
	| info_ptr<>var.var_info_ptr
		= { ui & ui_var_heap = writePtr info_ptr (VI_Alias var) ui.ui_var_heap }
	# (var_info,var_heap) = readPtr info_ptr ui.ui_var_heap
	# ui = { ui & ui_var_heap = var_heap }
	= case var_info of
		VI_Alias var
			| var.var_info_ptr==info_ptr // to prevent repeating cycle error
				-> ui
		_
			# ui = { ui & ui_var_heap = writePtr info_ptr (VI_Alias var) ui.ui_var_heap }
			-> {ui & ui_error = cycleAfterRemovingNewTypeConstructorsError var.var_ident ui.ui_error}

remove_NewTypePatterns_case_and_update_expression :: !Expression !Index !*UpdateInfo -> (!Expression,!*UpdateInfo)
remove_NewTypePatterns_case_and_update_expression (Case {case_guards=NewTypePatterns type [{ap_symbol,ap_vars=[ap_var=:{fv_info_ptr}],ap_expr,ap_position}],
													case_expr, case_default, case_explicit, case_info_ptr}) group_index ui
	# ap_expr = add_case_default ap_expr case_default
	# ap_expr = if case_explicit
					(mark_case_explicit ap_expr)
					ap_expr
	# (case_expr,ui) = updateExpression group_index case_expr ui
	= case case_expr of
		Var var
			# ui = set_alias_and_detect_cycle fv_info_ptr var ui
			-> updateExpression group_index ap_expr ui
		case_expr
			# (ap_expr,ui) = updateExpression group_index ap_expr ui
			# let_bind = {lb_dst = ap_var, lb_src = case_expr, lb_position = ap_position}
			# (EI_CaseType {ct_pattern_type}, ui_symbol_heap) = readPtr case_info_ptr ui.ui_symbol_heap
//			# (let_info_ptr, ui_symbol_heap) = newPtr (EI_LetType [ct_pattern_type]) ui_symbol_heap
			# let_info_ptr = case_info_ptr
			# ui_symbol_heap = writePtr case_info_ptr (EI_LetType [ct_pattern_type]) ui_symbol_heap
			# ui = { ui & ui_symbol_heap = ui_symbol_heap }
			# let_expr = Let {	let_strict_binds = [], let_lazy_binds = [let_bind], let_expr = ap_expr,
								let_info_ptr = let_info_ptr, let_expr_position = ap_position }
			-> (let_expr,ui)
	where
		mark_case_explicit (Case case_=:{case_explicit})
			= Case {case_ & case_explicit=True}
		mark_case_explicit (Let let_=:{let_expr})
			= Let {let_ & let_expr=mark_case_explicit let_expr}
		mark_case_explicit expr
			= expr

		add_case_default expr No
			= expr
		add_case_default expr (Yes default_expr)
			= add_default expr default_expr
		where
			add_default (Case kees=:{case_default=No,case_explicit=False}) default_expr
				= Case { kees & case_default = Yes default_expr }
			add_default (Case kees=:{case_default=Yes case_default_expr,case_explicit=False}) default_expr
				= Case { kees & case_default = Yes (add_default case_default_expr default_expr)}
			add_default (Let lad=:{let_expr}) default_expr
				= Let { lad & let_expr = add_default let_expr default_expr }
			add_default expr _
				= expr

instance updateExpression LetBind
where
	updateExpression group_index bind=:{lb_src} ui
		# (lb_src, ui) = updateExpression group_index lb_src ui
		= ({bind & lb_src = lb_src }, ui)

instance updateExpression (Bind a b) | updateExpression a
where
	updateExpression group_index bind=:{bind_src} ui
		# (bind_src, ui) = updateExpression group_index bind_src ui
		= ({bind & bind_src = bind_src }, ui)

instance updateExpression (Optional a) | updateExpression a
where
	updateExpression group_index (Yes x) ui
		# (x, ui) = updateExpression group_index x ui
		= (Yes x, ui)
	updateExpression group_index No ui
		= (No, ui)

instance updateExpression CasePatterns
where
	updateExpression group_index (AlgebraicPatterns type patterns) ui
		# (patterns, ui) = updateExpression group_index patterns ui
		= (AlgebraicPatterns type patterns, ui)
	updateExpression group_index (BasicPatterns type patterns) ui
		# (patterns, ui) = updateExpression group_index patterns ui
		= (BasicPatterns type patterns, ui)
	updateExpression group_index (OverloadedPatterns type decons_expr patterns) ui
		# (patterns, ui) = updateExpression group_index patterns ui
		# (decons_expr, ui) = updateExpression group_index decons_expr ui
		= (OverloadedPatterns type decons_expr patterns, ui)
	updateExpression group_index (DynamicPatterns patterns) ui
		# (patterns, ui) = updateExpression group_index patterns ui
		= (DynamicPatterns patterns, ui)
	
instance updateExpression AlgebraicPattern
where
	updateExpression group_index pattern=:{ap_expr} ui
		# (ap_expr, ui) =  updateExpression group_index ap_expr ui
		= ({ pattern & ap_expr = ap_expr }, ui)

instance updateExpression BasicPattern
where
	updateExpression group_index pattern=:{bp_expr} ui
		# (bp_expr, ui) = updateExpression group_index bp_expr ui
		= ({ pattern & bp_expr = bp_expr }, ui)

instance updateExpression Selection
where
  	updateExpression group_index (ArraySelection selector=:{glob_object={ds_ident}} expr_ptr index_expr) ui
		# (index_expr, ui) = updateExpression group_index index_expr ui
		  (symb_info, ui_symbol_heap) = readPtr expr_ptr ui.ui_symbol_heap
		  ui = { ui & ui_symbol_heap = ui_symbol_heap }
		= case symb_info of
			EI_Instance array_select []
				-> (ArraySelection array_select expr_ptr index_expr, ui)
			EI_Selection selectors record_var context_args
				# (var_ident, var_info_ptr, ui_var_heap, ui_error) = getClassVariable ds_ident record_var ui.ui_var_heap ui.ui_error
				-> (DictionarySelection { var_ident = var_ident, var_info_ptr = var_info_ptr, var_expr_ptr = nilPtr } selectors expr_ptr index_expr,
							{ ui & ui_var_heap = ui_var_heap, ui_error = ui_error })
  	updateExpression group_index selection ui
		= (selection, ui)

instance updateExpression DynamicPattern
where
	updateExpression group_index dp=:{dp_var,dp_type,dp_rhs} ui
		# (EI_TypeOfDynamicPattern type_pattern_vars type_code no_contexts, ui_symbol_heap) = readPtr dp_type ui.ui_symbol_heap
		  ui = {ui & ui_symbol_heap = ui_symbol_heap}
		| no_contexts
			# (dp_rhs, ui) = updateExpression group_index dp_rhs ui
			= ({dp & dp_rhs = dp_rhs, dp_type_code = type_code}, ui)
			# ui = {ui & ui_var_heap = writePtr dp_var.fv_info_ptr VI_FPC ui.ui_var_heap}
			  (dp_rhs, ui) = updateExpression group_index dp_rhs ui
			= ({dp & dp_rhs = dp_rhs, dp_type_code = type_code}, ui)

instance updateExpression (a,b) | updateExpression a & updateExpression b
where
	updateExpression group_index t ui
		= app2St (updateExpression group_index,updateExpression group_index) t ui

instance updateExpression [e] | updateExpression e
where
	updateExpression group_index l ui
		= mapSt (updateExpression group_index) l ui

set_aliases_for_binds_that_will_become_aliases :: ![LetBind] !*UpdateInfo -> *UpdateInfo
set_aliases_for_binds_that_will_become_aliases [] ui
	= ui
set_aliases_for_binds_that_will_become_aliases [{lb_dst={fv_info_ptr},lb_src}:let_binds] ui
	# ui = make_alias_if_expression_will_become_var lb_src fv_info_ptr ui
	= set_aliases_for_binds_that_will_become_aliases let_binds ui
where
	make_alias_if_expression_will_become_var (Var var) fv_info_ptr ui
		| not ((sreadPtr var.var_info_ptr ui.ui_var_heap)=:VI_FPC && (sreadPtr var.var_expr_ptr ui.ui_symbol_heap)=:EI_FPContext _ _)
			= set_alias_and_detect_cycle fv_info_ptr var ui
	make_alias_if_expression_will_become_var (App {app_symb={symb_kind=SK_NewTypeConstructor _},app_args=[arg]}) fv_info_ptr ui
		= skip_newtypes_and_make_alias_if_var arg fv_info_ptr ui
	make_alias_if_expression_will_become_var (MatchExpr {glob_object={ds_arity = -2}} expr) fv_info_ptr ui
		= skip_newtypes_and_make_alias_if_var expr fv_info_ptr ui
	make_alias_if_expression_will_become_var expr=:(Case {case_guards=NewTypePatterns _ _}) fv_info_ptr ui
		= skip_newtypes_and_make_alias_if_var expr fv_info_ptr ui
	make_alias_if_expression_will_become_var _ fv_info_ptr ui
		= ui

	skip_newtypes_and_make_alias_if_var expr fv_info_ptr ui
		# (expr,ui) = skip_newtypes expr ui
		= case expr of
			Var var
				| not ((sreadPtr var.var_info_ptr ui.ui_var_heap)=:VI_FPC && (sreadPtr var.var_expr_ptr ui.ui_symbol_heap)=:EI_FPContext _ _)
					-> set_alias_and_detect_cycle fv_info_ptr var ui
			_
				-> ui
	where
		skip_newtypes :: !Expression !*UpdateInfo -> (!Expression,!*UpdateInfo)
		skip_newtypes (App {app_symb={symb_kind=SK_NewTypeConstructor _},app_args=[arg]}) ui
			= skip_newtypes arg ui
		skip_newtypes (MatchExpr {glob_object={ds_arity = -2}} expr) ui
			= skip_newtypes expr ui
		skip_newtypes expr=:(Case {case_guards=NewTypePatterns type [{ap_symbol,ap_vars=[ap_var=:{fv_info_ptr}],ap_expr}],case_expr}) ui
			# (case_expr,ui) = skip_newtypes case_expr ui
			= case case_expr of
				Var case_var
					| not ((sreadPtr case_var.var_info_ptr ui.ui_var_heap)=:VI_FPC && (sreadPtr case_var.var_expr_ptr ui.ui_symbol_heap)=:EI_FPContext _ _)
						# (ap_expr,ui) = skip_newtypes ap_expr ui
						-> case ap_expr of
							Var rhs_var
								| rhs_var.var_info_ptr==fv_info_ptr
									-> (case_expr,ui)
									-> (ap_expr,ui)
							_
								-> (expr,ui)
				_
					-> (expr,ui)
		skip_newtypes expr ui
			= (expr,ui)

adjustClassExpressions symb_ident exprs tail_exprs ui
	= mapAppendSt (adjustClassExpression symb_ident) exprs tail_exprs ui
where
	adjustClassExpression symb_ident (App app=:{app_args}) ui
		# (app_args, ui) = adjustClassExpressions symb_ident app_args [] ui
		= (App {app & app_args = app_args}, ui)
	adjustClassExpression symb_ident (ClassVariable var_info_ptr) ui=:{ui_var_heap, ui_error}
		# (var_ident, var_info_ptr, ui_var_heap, ui_error) = getClassVariable symb_ident var_info_ptr ui_var_heap ui_error
		= (Var {var_ident = var_ident, var_info_ptr = var_info_ptr, var_expr_ptr = nilPtr}, {ui & ui_var_heap = ui_var_heap, ui_error = ui_error})
	adjustClassExpression symb_ident (Selection opt_type expr selectors) ui
		# (expr, ui) = adjustClassExpression symb_ident expr ui
		= (Selection opt_type expr selectors, ui)
	adjustClassExpression symb_ident tce=:(TypeCodeExpression type_code) ui
		# (type_code, ui) = adjust_type_code type_code ui
		= (TypeCodeExpression type_code, {ui & ui_has_type_codes = True})
	where
		adjust_type_code (TCE_TypeTerm var_info_ptr) ui=:{ui_var_heap,ui_error}
			# (var_info_ptr, (ui_var_heap,ui_error))
				= getTCDictionary symb_ident var_info_ptr (ui_var_heap, ui_error)
			# ui = {ui & ui_var_heap = ui_var_heap, ui_error = ui_error}
			= (TCE_TypeTerm var_info_ptr, ui)
		adjust_type_code (TCE_Selector selectors var_info_ptr) ui=:{ui_var_heap,ui_error}
			# (var_info_ptr, (ui_var_heap,ui_error))
				= getTCDictionary symb_ident var_info_ptr (ui_var_heap, ui_error)
			# ui = {ui & ui_var_heap = ui_var_heap, ui_error = ui_error}
			= (TCE_Selector selectors var_info_ptr, ui)
		adjust_type_code (TCE_Constructor cons typecode_exprs) ui
			# (typecode_exprs, ui) = mapSt adjust_type_code typecode_exprs ui
			= (TCE_Constructor cons typecode_exprs, ui)
		adjust_type_code (TCE_UniType uni_vars type_code) ui
			# (type_code, ui) = adjust_type_code type_code ui
			= (TCE_UniType uni_vars type_code, ui)
		adjust_type_code type_code ui
			= (type_code, ui)

	adjustClassExpression symb_ident (Let this_let=:{let_strict_binds, let_lazy_binds, let_expr }) ui
		# (let_strict_binds, ui) = adjust_let_binds symb_ident let_strict_binds ui
		  (let_lazy_binds, ui) = adjust_let_binds symb_ident let_lazy_binds ui
		  (let_expr, ui) = adjustClassExpression symb_ident let_expr ui
		= (Let { this_let & let_strict_binds = let_strict_binds, let_lazy_binds = let_lazy_binds, let_expr = let_expr }, ui)
	where
		adjust_let_binds symb_ident let_binds ui
			= mapSt (adjust_let_bind symb_ident) let_binds ui

		adjust_let_bind symb_ident let_bind=:{lb_src} ui
			# (lb_src, ui) = adjustClassExpression symb_ident lb_src ui
			= ({let_bind & lb_src = lb_src}, ui)

	adjustClassExpression symb_ident  expr ui
		= (expr, ui)

expandAndCompareTypes type unexp_type type_var_heap subst
	# (exp_type, subst) = expandOneStep unexp_type subst
	= equalTypes type exp_type type_var_heap subst

class equalTypes a :: !a !a !*TypeVarHeap !*Subst -> (!Bool, !*TypeVarHeap, !*Subst)

instance equalTypes AType
where
	equalTypes atype1 atype2 type_var_heap subst
		= expandAndCompareTypes atype1.at_type atype2.at_type type_var_heap subst

equalTypeVars {tv_info_ptr}	temp_var_id type_var_heap
	# (tv_info, type_var_heap) = readPtr tv_info_ptr type_var_heap
	= case tv_info of
		TVI_Forward forw_var_number
			-> (forw_var_number == temp_var_id, type_var_heap)
		_
			-> (True, type_var_heap <:= (tv_info_ptr, TVI_Forward temp_var_id))

instance equalTypes Type
where
	equalTypes (TV tv) (TempV var_number) type_var_heap subst
		# (eq, type_var_heap) = equalTypeVars tv var_number type_var_heap
		= (eq, type_var_heap, subst)
	equalTypes (arg_type1 --> restype1) (arg_type2 --> restype2) type_var_heap subst
		# (eq, type_var_heap, subst) = equalTypes arg_type1 arg_type2 type_var_heap subst
		| eq
			= equalTypes restype1 restype2 type_var_heap subst
			= (False, type_var_heap, subst)
	equalTypes (TA tc1 types1) (TA tc2 types2) type_var_heap subst
		| tc1 == tc2
			= equalTypes types1 types2 type_var_heap subst
			= (False, type_var_heap, subst)
	equalTypes (TA tc1 types1) (TAS tc2 types2 _) type_var_heap subst
		| tc1 == tc2
			= equalTypes types1 types2 type_var_heap subst
			= (False, type_var_heap, subst)
	equalTypes (TAS tc1 types1 _) (TA tc2 types2) type_var_heap subst
		| tc1 == tc2
			= equalTypes types1 types2 type_var_heap subst
			= (False, type_var_heap, subst)
	equalTypes (TAS tc1 types1 _) (TAS tc2 types2 _) type_var_heap subst
		| tc1 == tc2
			= equalTypes types1 types2 type_var_heap subst
			= (False, type_var_heap, subst)
	equalTypes (TB basic1) (TB basic2) type_var_heap subst
		= (basic1 == basic2, type_var_heap, subst)
	equalTypes TArrow TArrow type_var_heap subst
		= (True, type_var_heap, subst)
	equalTypes (TArrow1 x) (TArrow1 y) type_var_heap subst
		= equalTypes x y type_var_heap subst		
	equalTypes (CV tv :@: types1) (TempCV var_number :@: types2) type_var_heap subst
		# (eq, type_var_heap) = equalTypeVars tv var_number type_var_heap
		| eq
			= equalTypes types1 types2 type_var_heap subst
			= (False, type_var_heap, subst)
	equalTypes type1 type2 type_var_heap subst
		= (False, type_var_heap, subst)

instance equalTypes [a] | equalTypes a
where
	equalTypes [x:xs] [y:ys] type_var_heap subst
		# (eq, type_var_heap, subst) = equalTypes x y type_var_heap subst
		| eq 
			= equalTypes xs ys type_var_heap subst
			= (False, type_var_heap, subst)
	equalTypes [] [] type_var_heap subst
		= (True, type_var_heap, subst)
	equalTypes _ _ type_var_heap subst
		= (False, type_var_heap, subst)

instance <<< TypeContext
where
	(<<<) file tc = file <<< toString tc.tc_class <<< ' ' <<< tc.tc_types <<< " <" <<< tc.tc_var <<< '>'

instance <<< Special
where
	(<<<) file {spec_types} = file <<< spec_types

instance <<< (Ptr x)
where
	(<<<) file ptr = file <<< '<' <<< ptrToInt ptr <<< '>'

/*	
instance <<< TypeCodeExpression
where
	(<<<) file _ = file
*/

instance <<< DefinedSymbol
where
	(<<<) file ds = file <<< ds.ds_ident

instance <<< ExprInfo
where
	(<<<) file (EI_Instance symb exprs) = file <<< symb <<< exprs
	(<<<) file (EI_Selection sels var_ptr exprs) = file <<< sels <<< var_ptr <<< exprs
	(<<<) file (EI_Context exprs) = file <<< exprs
	(<<<) file _ = file

instance <<< ClassApplication
where
	(<<<) file (CA_Instance rc) = file <<< "CA_Instance"
	(<<<) file (CA_Context tc) = file <<< "CA_Context " <<< tc

equalize_atype_attributes :: !AType !AType !{#CommonDefs} !*TypeHeaps !*Coercions -> *(!Bool,!*TypeHeaps,!*Coercions)
equalize_atype_attributes {at_attribute=at_attribute1,at_type=at_type1} {at_attribute=at_attribute2,at_type=at_type2} defs type_heaps coercions
	# (ok1,coercions) = equalize_attributes at_attribute1 at_attribute2 coercions
	# (ok2,type_heaps,coercions) = equalize_type_attributes at_type1 at_type2 defs type_heaps coercions
	= (ok1 && ok2,type_heaps,coercions)

equalize_attributes :: !TypeAttribute !TypeAttribute !*Coercions -> (!Bool,!*Coercions)
equalize_attributes TA_Multi TA_Multi coercions
	= (True,coercions)
equalize_attributes TA_Multi (TA_TempVar av2_n) coercions
	= tryToMakeNonUnique av2_n coercions
equalize_attributes TA_Multi TA_Unique coercions
	= (False,coercions)
equalize_attributes TA_Unique TA_Unique coercions
	= (True,coercions)
equalize_attributes TA_Unique (TA_TempVar av2_n) coercions
	= tryToMakeUnique av2_n coercions
equalize_attributes TA_Unique TA_Multi coercions
	= (False,coercions)
equalize_attributes (TA_TempVar av1_n) TA_Multi coercions
	= tryToMakeNonUnique av1_n coercions
equalize_attributes (TA_TempVar av1_n) TA_Unique coercions
	= tryToMakeUnique av1_n coercions
equalize_attributes (TA_TempVar av1_n) (TA_TempVar av2_n) coercions
	= equalize_attribute_vars av1_n av2_n coercions
equalize_attributes attribute1 attribute2 coercions
	= abort "equalize_attributes" ---> (attribute1,attribute2)

equalize_type_attributes :: !Type !Type !{#CommonDefs} !*TypeHeaps !*Coercions -> (!Bool,!*TypeHeaps,!*Coercions)
equalize_type_attributes (arg_atype1-->res_atype1) (arg_atype2-->res_atype2) defs type_heaps coercions
	# (ok1,type_heaps,coercions) = equalize_atype_attributes arg_atype1 arg_atype2 defs type_heaps coercions
	# (ok2,type_heaps,coercions) = equalize_atype_attributes res_atype1 res_atype2 defs type_heaps coercions
	= (ok1 && ok2,type_heaps,coercions)
equalize_type_attributes type1=:(TA cons_id1 cons_args1) type2=:(TA cons_id2 cons_args2) defs type_heaps coercions
	| cons_id1==cons_id2
		= equalize_atypes_attributes cons_args1 cons_args2 defs type_heaps coercions
		= expand_and_equalize_type_attributes cons_id1 cons_args1 cons_id2 cons_args2 type1 type2 defs type_heaps coercions
equalize_type_attributes type1=:(TA cons_id1 cons_args1) type2=:(TAS cons_id2 cons_args2 _) defs type_heaps coercions
	| cons_id1==cons_id2
		= equalize_atypes_attributes cons_args1 cons_args2 defs type_heaps coercions
		= expand_and_equalize_type_attributes cons_id1 cons_args1 cons_id2 cons_args2 type1 type2 defs type_heaps coercions
equalize_type_attributes type1=:(TAS cons_id1 cons_args1 _) type2=:(TAS cons_id2 cons_args2 _) defs type_heaps coercions
	| cons_id1==cons_id2
		= equalize_atypes_attributes cons_args1 cons_args2 defs type_heaps coercions
		= expand_and_equalize_type_attributes cons_id1 cons_args1 cons_id2 cons_args2 type1 type2 defs type_heaps coercions
equalize_type_attributes type1=:(TAS cons_id1 cons_args1 _) type2=:(TA cons_id2 cons_args2) defs type_heaps coercions
	| cons_id1==cons_id2
		= equalize_atypes_attributes cons_args1 cons_args2 defs type_heaps coercions
		= expand_and_equalize_type_attributes cons_id1 cons_args1 cons_id2 cons_args2 type1 type2 defs type_heaps coercions
equalize_type_attributes (_ :@: atypes1) (_ :@: atypes2) defs type_heaps coercions
	= equalize_atypes_attributes atypes1 atypes2 defs type_heaps coercions
equalize_type_attributes (TArrow1 atype1) (TArrow1 atype2) defs type_heaps coercions
	= equalize_atype_attributes atype1 atype2 defs type_heaps coercions
equalize_type_attributes (TB _) (TB _) defs type_heaps coercions
	= (True,type_heaps,coercions)
equalize_type_attributes (TempV _) (TempV _) defs type_heaps coercions
	= (True,type_heaps,coercions)
equalize_type_attributes TArrow TArrow defs type_heaps coercions
	= (True,type_heaps,coercions)
equalize_type_attributes (TempQV temp_var_id1) (TempQV temp_var_id2) defs type_heaps coercions
	| temp_var_id1==temp_var_id2
		= (True,type_heaps,coercions)
equalize_type_attributes type1 type2 defs type_heaps coercions
	= abort "equalize_type_attributes" ---> (type1,type2)

expand_and_equalize_type_attributes cons_id1 cons_args1 cons_id2 cons_args2 type1 type2 defs type_heaps coercions
	# (succ1, type1, type_heaps) = tryToExpandTypeSyn defs type1 cons_id1 cons_args1 type_heaps
	# (succ2, type2, type_heaps) = tryToExpandTypeSyn defs type2 cons_id2 cons_args2 type_heaps
	| succ1 || succ2
		= equalize_type_attributes type1 type2 defs type_heaps coercions

equalize_atypes_attributes :: ![AType] ![AType] !{#CommonDefs} !*TypeHeaps !*Coercions -> *(!Bool,!*TypeHeaps,!*Coercions)
equalize_atypes_attributes [atype1:atypes1] [atype2:atypes2] defs type_heaps coercions
	# (ok1,type_heaps,coercions) = equalize_atype_attributes atype1 atype2 defs type_heaps coercions
	# (ok2,type_heaps,coercions) = equalize_atypes_attributes atypes1 atypes2 defs type_heaps coercions
	= (ok1 && ok2,type_heaps,coercions)
equalize_atypes_attributes [] [] defs type_heaps coercions
	= (True,type_heaps,coercions)

// containsTypeVariable copied from module type and extended
class containsTypeVariable a :: !Int !a !{!Type} -> Bool

instance containsTypeVariable [a] | containsTypeVariable a
where
	containsTypeVariable var_id [elem:list] subst
		= containsTypeVariable var_id elem subst || containsTypeVariable var_id list subst
	containsTypeVariable var_id [] _
		= False

instance containsTypeVariable AType
where
	containsTypeVariable var_id {at_type} subst = containsTypeVariable var_id at_type subst

instance containsTypeVariable Type
where
	containsTypeVariable var_id (TempV tv_number) subst
		# type = subst.[tv_number]
		| isIndirection type
			= containsTypeVariable var_id type subst 
			= tv_number == var_id
	containsTypeVariable var_id (arg_type --> res_type) subst
		= containsTypeVariable var_id arg_type subst || containsTypeVariable var_id res_type subst
	containsTypeVariable var_id (TA cons_id cons_args) subst
		= containsTypeVariable var_id cons_args subst
	containsTypeVariable var_id (TAS cons_id cons_args _) subst
		= containsTypeVariable var_id cons_args subst
	containsTypeVariable var_id (type :@: types) subst
		= containsTypeVariable var_id type subst || containsTypeVariable var_id types subst
	containsTypeVariable var_id (TArrow1 arg_type) subst
		= containsTypeVariable var_id arg_type subst
	containsTypeVariable _ _ _
		= False

instance containsTypeVariable ConsVariable
where
	containsTypeVariable var_id (TempCV tv_number) subst
		# type = subst.[tv_number]
		| isIndirection type
			= containsTypeVariable var_id type subst 
			= tv_number == var_id
	containsTypeVariable var_id _ _
		= False

liftNewVarSubstitutions :: ![ReducedOverloadedContext] !Int !*{!Type} -> (!*{#BOOLVECT},!*{!Type})
liftNewVarSubstitutions rocs n_type_variables subst
	#! size_subst = size subst
	| n_type_variables==size_subst
		= ({},subst)
		# m = createArray (inc (BITINDEX (size_subst-n_type_variables))) 0
		# (m,subst) = mark_new_vars rocs n_type_variables m subst
		= (m,subst)

mark_new_vars :: ![ReducedOverloadedContext] !Int !*{#BOOLVECT} !*{!Type} -> (!*{#BOOLVECT},!*{!Type})
mark_new_vars [{roc_rcs}:rocs] n_type_variables m subst
	# (m,subst) = mark_new_vars_rcs roc_rcs n_type_variables m subst
	= mark_new_vars rocs n_type_variables m subst
where
	mark_new_vars_rcs [rc:rcs] n_type_variables m subst
		# (m,subst) = mark_new_vars_rc rc n_type_variables m subst
		= mark_new_vars_rcs rcs n_type_variables m subst
	mark_new_vars_rcs [] n_type_variables m subst
		= (m,subst)

	mark_new_vars_rc (RC_Context _) n_type_variables m subst
		= (m,subst)
	mark_new_vars_rc (RC_Instance ci) n_type_variables m subst
		= mark_new_vars_cr_of_ci ci n_type_variables m subst

	mark_new_vars_cr_of_ci CI_TC n_type_variables m subst
		= (m,subst)
	mark_new_vars_cr_of_ci (CI_Class opt_cd cis) n_type_variables m subst
		# (m,subst) = mark_new_vars_cr_of_opt_cd opt_cd n_type_variables m subst
		= mark_new_vars_cr_of_cis cis n_type_variables m subst

	mark_new_vars_cr_of_opt_cd No n_type_variables m subst
		= (m,subst)
	mark_new_vars_cr_of_opt_cd (Yes {cd_inst_contexts,cd_new_vars}) n_type_variables m subst
		# (m,subst) = mark_new_vars_new_vars cd_new_vars n_type_variables m subst
		= mark_new_vars_rcs cd_inst_contexts n_type_variables m subst

	mark_new_vars_cr_of_cis [] n_type_variables m subst
		= (m,subst)
	mark_new_vars_cr_of_cis [ci:cis] n_type_variables m subst
		# (m,subst) = mark_new_vars_cr_of_ci ci n_type_variables m subst
		= mark_new_vars_cr_of_cis cis n_type_variables m subst
		
	mark_new_vars_new_vars [] n_type_variables m subst
		= (m,subst)
	mark_new_vars_new_vars [(_,tv_n):new_vars] n_type_variables m subst
		# (m,subst) = mark_new_vars_new_var tv_n n_type_variables m subst
		= mark_new_vars_new_vars new_vars n_type_variables m subst

	mark_new_vars_new_var :: !Int !Int !*{#BOOLVECT} !*{!Type} -> (!*{#BOOLVECT},!*{!Type})
	mark_new_vars_new_var tv_n n_type_variables m subst
		# i = tv_n - n_type_variables
		| i<0
			= (m,subst)
		# bit_index = BITINDEX i
		  (m_bit_index,m) = m![bit_index]
		  m & [bit_index] = m_bit_index bitor (1 << (BITNUMBER i))
		= (m,subst)
mark_new_vars [] n_type_variables m subst
	= (m,subst)
