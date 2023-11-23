implementation module type_io_equal_types

import StdEnv
from containers import equal_strictness_lists
import type_io_read
import BitSet;
import StdDynamicTypes;

// dereference a type reference
dereference_type_reference {tio_tr_module_n,tio_tr_type_def_n} ets type_io_state=:{tis_n_common_defs}
	| tio_tr_module_n == tis_n_common_defs
		= abort "dereference_type_reference; internal error predefined type cannot be indexed in tio_common_defs";
	# (tio_check_type_def,ets) = ets!ets_tio_common_defs.[tio_tr_module_n].tio_com_type_defs.[tio_tr_type_def_n];
	= (tio_check_type_def,ets,type_io_state);

// converts a a type reference into an (unique) index
compute_index_in_type_cache :: !TIO_TypeReference !TIO_TypeReference !*TypeIOState -> (!Int,!*TypeIOState)
compute_index_in_type_cache ref1 ref2 type_io_state=:{tis_max_types}
	# (ref1_bitset_index,type_io_state)
		= compute_index_in_tis_is_type_already_checked ref1 type_io_state
	# (ref2_bitset_index,type_io_state)
		= compute_index_in_tis_is_type_already_checked ref2 type_io_state
	# bitset_index
		= ref1_bitset_index * tis_max_types + ref2_bitset_index
	= (bitset_index,type_io_state)
where
	compute_index_in_tis_is_type_already_checked {tio_tr_module_n,tio_tr_type_def_n} type_io_state
		# (base_index,type_io_state) = type_io_state!tis_max_types_per_module.[tio_tr_module_n];
		= ((base_index + tio_tr_type_def_n),type_io_state);

:: *EqTypeState = {
		ets_left_module_index :: !Int,
		ets_right_module_index :: !Int,
		ets_is_type_already_checked :: !*BitSet,
		ets_tio_common_defs :: !*{#TIO_CommonDefs}
	};

equal_types_TIO_TypeReference :: !TIO_TypeReference !TIO_TypeReference !*BitSet !*{#TIO_CommonDefs} !*TypeIOState
															 -> (!Bool,!*BitSet,!*{#TIO_CommonDefs},!*TypeIOState)
equal_types_TIO_TypeReference ref1 ref2 is_type_already_checked tio_common_defs type_io_state
	# ets = {ets_tio_common_defs=tio_common_defs, ets_is_type_already_checked=is_type_already_checked,
			 ets_left_module_index = -1, ets_right_module_index= -1};
	# (eq,ets,type_io_state) = equal_types ref1 ref2 ets type_io_state
	= (eq,ets.ets_is_type_already_checked,ets.ets_tio_common_defs,type_io_state);

// equality on type definitions
class EqTypes a
where
	equal_types :: a a !*EqTypeState !*TypeIOState -> (!Bool,!*EqTypeState,!*TypeIOState)

instance EqTypes TIO_TypeReference
where
	equal_types ref1=:{tio_tr_module_n=tio_tr_module_n1,tio_tr_type_def_n=tio_tr_type_def_n1} ref2=:{tio_tr_module_n=tio_tr_module_n2,tio_tr_type_def_n=tio_tr_type_def_n2}
			ets type_io_state
		| tio_tr_module_n1 == tio_tr_module_n2 && tio_tr_type_def_n1 == tio_tr_type_def_n2
			= (True,ets,type_io_state);

		# (bitset_index,type_io_state)
			= compute_index_in_type_cache ref1 ref2 type_io_state

		# (type_pair_has_already_been_checked,ets_is_type_already_checked)
			= isBitSetMember ets.ets_is_type_already_checked bitset_index;
		| type_pair_has_already_been_checked
			# ets = {ets & ets_is_type_already_checked = ets_is_type_already_checked}
			= (True,ets,type_io_state);

		// mark type pair as being checked			
		# ets_is_type_already_checked = AddBitSet ets_is_type_already_checked bitset_index;
		# ets = {ets & ets_is_type_already_checked = ets_is_type_already_checked}

		// get actual types
		# (type1,ets,type_io_state)
			= dereference_type_reference ref1 ets type_io_state
		# (type2,ets,type_io_state)
			= dereference_type_reference ref2 ets type_io_state

		# {ets_left_module_index,ets_right_module_index} = ets
		// set current defining module indices
		# ets = {ets & ets_left_module_index = tio_tr_module_n1, ets_right_module_index = tio_tr_module_n2};

		# (type1_equals_type2,ets,type_io_state)
			= equal_types type1 type2 ets type_io_state;

		// restore original defining module indices
		# ets = {ets & ets_left_module_index = ets_left_module_index, ets_right_module_index = ets_right_module_index};

		| type1_equals_type2		
			= (True,ets,type_io_state);

			# ets = {ets & ets_is_type_already_checked = DelBitSet ets.ets_is_type_already_checked bitset_index}
			= (False,ets,type_io_state);

instance EqTypes (TIO_TypeDef a) | EqTypes a
where
	equal_types {tio_td_name=tio_td_name1,tio_td_arity=tio_td_arity1,tio_td_rhs=tio_td_rhs1} 
				{tio_td_name=tio_td_name2,tio_td_arity=tio_td_arity2,tio_td_rhs=tio_td_rhs2} ets type_io_state
		| tio_td_name1 == tio_td_name1 && tio_td_arity1 == tio_td_arity2
			= equal_types tio_td_rhs1 tio_td_rhs2 ets type_io_state
			= (False,ets,type_io_state);

instance EqTypes TIO_TypeRhs
where
	equal_types (TIO_AlgType tio_defined_symbols1) (TIO_AlgType tio_defined_symbols2) ets type_io_state
		= equal_types tio_defined_symbols1 tio_defined_symbols2 ets type_io_state;
	equal_types (TIO_SynType syn1) (TIO_SynType syn2) ets type_io_state
		= equal_types syn1 syn2 ets type_io_state;
	equal_types (TIO_RecordType tio_record_type1) (TIO_RecordType tio_record_type2) ets type_io_state
		= equal_types tio_record_type1 tio_record_type2 ets type_io_state;
	equal_types (TIO_GenericDictionaryType tio_record_type1) (TIO_GenericDictionaryType tio_record_type2) ets type_io_state
		= equal_types tio_record_type1 tio_record_type2 ets type_io_state;
	equal_types (TIO_AbstractType _) (TIO_AbstractType _) ets type_io_state
		= abort "TIO_AbstractType"
	equal_types TIO_UnknownType TIO_UnknownType ets type_io_state
		= abort "UnknownType"
	equal_types q2 q1 ets type_io_state
		= (False,ets,type_io_state)

instance EqTypes TIO_RecordType
where
	equal_types {tio_rt_fields=tio_rt_fields1,tio_rt_constructor=tio_rt_constructor1} {tio_rt_fields=tio_rt_fields2,tio_rt_constructor=tio_rt_constructor2} ets type_io_state
		# (fields_eq,ets,type_io_state)
			= equal_types tio_rt_fields1 tio_rt_fields2 ets type_io_state;
		| fields_eq
			= equal_types tio_rt_constructor1 tio_rt_constructor2 ets type_io_state;
			= (False,ets,type_io_state);

instance EqTypes TIO_DefinedSymbol
where
	equal_types {tio_ds_ident=tio_ds_ident1,tio_ds_arity=tio_ds_arity1,tio_ds_index=tio_ds_index1} {tio_ds_ident=tio_ds_ident2,tio_ds_arity=tio_ds_arity2,tio_ds_index=tio_ds_index2}
			ets=:{ets_left_module_index,ets_right_module_index} type_io_state
		| tio_ds_ident1 == tio_ds_ident2 && tio_ds_arity1 == tio_ds_arity2
			# ets_tio_common_defs = ets.ets_tio_common_defs
			  (tio_cons_symb1,ets_tio_common_defs) = ets_tio_common_defs![ets_left_module_index ].tio_com_cons_defs.[tio_ds_index1];
			  (tio_cons_symb2,ets_tio_common_defs) = ets_tio_common_defs![ets_right_module_index].tio_com_cons_defs.[tio_ds_index2];
			  ets = {ets & ets_tio_common_defs=ets_tio_common_defs}
			= equal_types tio_cons_symb1 tio_cons_symb2 ets type_io_state;
			= (False,ets,type_io_state);
			
instance EqTypes TIO_ConsDef
where
	equal_types {tio_cons_symb=tio_cons_symb1,tio_cons_type=tio_cons_type1,tio_cons_exi_vars=tio_cons_exi_vars1} 
				{tio_cons_symb=tio_cons_symb2,tio_cons_type=tio_cons_type2,tio_cons_exi_vars=tio_cons_exi_vars2} ets type_io_state
		| tio_cons_symb1 == tio_cons_symb2
			// constructors are equally named
			= equal_types tio_cons_type1 tio_cons_type2 ets type_io_state;		
			= (False,ets,type_io_state);

instance EqTypes TIO_SymbolType
where
	equal_types {tio_st_vars=tio_st_vars1,tio_st_args=tio_st_args1,tio_st_arity=tio_st_arity1,tio_st_result=tio_st_result1,tio_st_args_strictness=tio_st_args_strictness1}
				{tio_st_vars=tio_st_vars2,tio_st_args=tio_st_args2,tio_st_arity=tio_st_arity2,tio_st_result=tio_st_result2,tio_st_args_strictness=tio_st_args_strictness2} ets type_io_state
		| tio_st_arity1 == tio_st_arity2 && equal_strictness_lists tio_st_args_strictness1 tio_st_args_strictness2
			# (are_st_vars_equal,ets,type_io_state)
				= equal_types tio_st_vars1 tio_st_vars2 ets type_io_state;
			| are_st_vars_equal
				# (are_st_args_equal,ets,type_io_state)
					= equal_types tio_st_args1 tio_st_args2 ets type_io_state;
				| are_st_args_equal
					= equal_types tio_st_result1 tio_st_result2 ets type_io_state;
					= (False,ets,type_io_state);
				= (False,ets,type_io_state);
			= (False,ets,type_io_state);

instance EqTypes TIO_AType
where
	equal_types {tio_at_type=tio_at_type1} {tio_at_type=tio_at_type2} ets type_io_state
		= equal_types tio_at_type1 tio_at_type2 ets type_io_state;
			
instance EqTypes TIO_Type
where
	equal_types (TIO_TAS tio_type_symb_ident1 tio_atypes1 strictness_list1) (TIO_TAS tio_type_symb_ident2 tio_atypes2 strictness_list2) ets type_io_state
		# (are_type_symb_idents_equal,ets,type_io_state)
			= equal_types tio_type_symb_ident1 tio_type_symb_ident2 ets type_io_state;
		| are_type_symb_idents_equal && equal_strictness_lists strictness_list1 strictness_list2 
			= equal_types tio_atypes1 tio_atypes2 ets type_io_state;
			= (False,ets,type_io_state);
	equal_types (tio_atype1a ----> tio_atype1b) (tio_atype2a ----> tio_atype2b) ets type_io_state
		# (are_atypes1_equal,ets,type_io_state)
			= equal_types tio_atype1a tio_atype2a ets type_io_state;
		| are_atypes1_equal
			= equal_types tio_atype1b tio_atype2b ets type_io_state;
			= (False,ets,type_io_state);
	equal_types (tio_cons_variable1 :@@: tio_atypes1) (tio_cons_variable2 :@@: tio_atypes2) ets type_io_state
		# (are_tio_cons_variables_equal,ets,type_io_state)
			= equal_types tio_cons_variable1 tio_cons_variable2 ets type_io_state;
		| are_tio_cons_variables_equal
			= equal_types tio_atypes1 tio_atypes2 ets type_io_state;
			= (False,ets,type_io_state);
	equal_types (TIO_TB tio_basic_type1) (TIO_TB tio_basic_type2) ets type_io_state
		= equal_types tio_basic_type1 tio_basic_type2 ets type_io_state;
	equal_types (TIO_GTV tio_type_var1) (TIO_GTV tio_type_var2) ets type_io_state
		= equal_types tio_type_var1 tio_type_var2 ets type_io_state;
	equal_types (TIO_TV tio_type_var1) (TIO_TV tio_type_var2) ets type_io_state
		= equal_types tio_type_var1 tio_type_var2 ets type_io_state;
	equal_types (TIO_TQV tio_type_var1) (TIO_TQV tio_type_var2) ets type_io_state
		= equal_types tio_type_var1 tio_type_var2 ets type_io_state;
	equal_types (TIO_GenericFunction kind1 tio_symbol_type1) (TIO_GenericFunction kind2 tio_symbol_type2) ets type_io_state
		| kind1==kind2
			= equal_types tio_symbol_type1 tio_symbol_type2 ets type_io_state
			= (False,ets,type_io_state);
	equal_types TIO_TE TIO_TE ets type_io_state
		= (True,ets,type_io_state);
	equal_types _ _ ets type_io_state
		= (False,ets,type_io_state);

instance EqTypes TIO_BasicType
where
	equal_types TIO_BT_Int TIO_BT_Int ets type_io_state
		= (True,ets,type_io_state);
	equal_types TIO_BT_Char TIO_BT_Char ets type_io_state
		= (True,ets,type_io_state);
	equal_types TIO_BT_Real TIO_BT_Real ets type_io_state
		= (True,ets,type_io_state);
	equal_types TIO_BT_Bool TIO_BT_Bool ets type_io_state
		= (True,ets,type_io_state);
	equal_types TIO_BT_Dynamic TIO_BT_Dynamic ets type_io_state
		= (True,ets,type_io_state);
	equal_types TIO_BT_File TIO_BT_File ets type_io_state
		= (True,ets,type_io_state);
	equal_types TIO_BT_World TIO_BT_World ets type_io_state
		= (True,ets,type_io_state);
	equal_types (TIO_BT_String tio_type1) (TIO_BT_String tio_type2) ets type_io_state
		= equal_types tio_type1 tio_type2 ets type_io_state;
	equal_types _ _ ets type_io_state
		= (False,ets,type_io_state);

instance EqTypes TIO_ConsVariable
where
	equal_types _ _ _ _
		= abort "instance equal_types TIO_ConsVariable";
		
instance EqTypes TIO_TypeSymbIdent
where
	equal_types {tio_type_name_ref=tio_type_name_ref1,tio_type_arity=tio_type_arity1} {tio_type_name_ref=tio_type_name_ref2,tio_type_arity=tio_type_arity2} ets type_io_state
		| tio_type_arity1 == tio_type_arity2
			= equal_types tio_type_name_ref1 tio_type_name_ref2 ets type_io_state;
			= (False,ets,type_io_state);
	
instance EqTypes TIO_ATypeVar
where
	equal_types {tio_atv_variable=tio_atv_variable1} {tio_atv_variable=tio_atv_variable2} ets type_io_state
		= equal_types tio_atv_variable1 tio_atv_variable2 ets type_io_state;
			
instance EqTypes TIO_TypeVar
where
	equal_types {tio_tv_name=tio_tv_name1} {tio_tv_name=tio_tv_name2} ets type_io_state
		= (tio_tv_name1 == tio_tv_name2,ets,type_io_state); 
		
instance EqTypes TIO_FieldSymbol
where
	equal_types {tio_fs_name=tio_fs_name1} {tio_fs_name=tio_fs_name2} ets type_io_state
		= (tio_fs_name1 == tio_fs_name2,ets,type_io_state);

instance EqTypes TIO_ConstructorSymbol
where
	equal_types {tio_cons=tio_cons1} {tio_cons=tio_cons2} ets type_io_state
		=	equal_types tio_cons1 tio_cons2 ets type_io_state

instance EqTypes [a] | EqTypes a
where
	equal_types [] [] ets type_io_state
		= (True,ets,type_io_state);
	equal_types [type1:types1] [type2:types2] ets type_io_state
		# (type1_equals_type2,ets,type_io_state)
			= equal_types type1 type2 ets type_io_state;
		| not type1_equals_type2
			= (False,ets,type_io_state);
		= equal_types types1 types2 ets type_io_state;
	equal_types _ _ ets type_io_state
		= (False,ets,type_io_state);

instance EqTypes {#a} | Array {#} a & EqTypes a
where
	equal_types a1 a2 ets type_io_state
		| s_a1 <> s_a2
			= (False,ets,type_io_state)
		= equal_types_loop 0 s_a1 ets type_io_state
	where 
		equal_types_loop i limit ets type_io_state
			| i == limit
				= (True,ets,type_io_state);			
			# (elements_are_equal,ets,type_io_state)
				= equal_types a1.[i] a2.[i] ets type_io_state;
			| not elements_are_equal
				= (False,ets,type_io_state);
			= equal_types_loop (inc i) limit ets type_io_state;
	
		s_a1 = size a1
		s_a2 = size a2
