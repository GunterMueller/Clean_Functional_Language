implementation module type_io_equal_type_defs

import StdEnv,StdMaybe,StdDynamicTypes
from containers import equal_strictness_lists
import type_io_read
import typetable

:: OrderedTypeRef
	= {	otr_type_ref1	:: TypeTableTypeReference
	,	otr_type_ref2	:: TypeTableTypeReference
	};

:: *EqTypesState
	= {	ets_within_type_table			:: !Bool	// iff ets_left_i == ets_right_i
	,	ets_left_i						:: !Int		// type table index for left type (1st arg)
	,	ets_right_i						:: !Int		// type table index for right type (2nd arg)
	,	ets_left_module_i				:: !Int		// left module index
	,	ets_right_module_i				:: !Int		// right module index
	,	ets_assumed_type_equivalences	:: [OrderedTypeRef]
	,	ets_proven_type_equivalences	:: [OrderedTypeRef]
	,	ets_left_string_table			:: !String
	,	ets_right_string_table			:: !String
	}; 
	
default_eq_types_state :: *EqTypesState;
default_eq_types_state
	= { ets_within_type_table			= False
	,	ets_left_i						= -1
	,	ets_right_i						= -1
	,	ets_left_module_i				= -1
	,	ets_right_module_i				= -1
	,	ets_assumed_type_equivalences	= []
	,	ets_proven_type_equivalences	= []
	,	ets_left_string_table			= {}
	,	ets_right_string_table			= {}
	}; 
	
find_type_equivalence ordered_type_ref ets=:{ets_assumed_type_equivalences,ets_proven_type_equivalences}
	# ets_assumed_type_equivalent
		= filter ((==) ordered_type_ref) ets_assumed_type_equivalences
	# ets_proven_type_equivalent
		= filter ((==) ordered_type_ref) ets_proven_type_equivalences
	# found
		= not (isEmpty ets_assumed_type_equivalent) || not (isEmpty ets_proven_type_equivalent)
	= (found,ets)

assume_type_equivalence ordered_type_ref ets=:{ets_assumed_type_equivalences}
	= {ets & ets_assumed_type_equivalences = [ordered_type_ref:ets_assumed_type_equivalences] } 
	
get_assumed_type_equivalence ets=:{ets_assumed_type_equivalences=[assumed_type_equivalence:ets_assumed_type_equivalences]}
	# ets = {ets & ets_assumed_type_equivalences = ets_assumed_type_equivalences}
	= (assumed_type_equivalence,ets)

enter_proven_assumption proven_type_equivalence ets=:{ets_proven_type_equivalences}
	= {ets & ets_proven_type_equivalences = [proven_type_equivalence:ets_proven_type_equivalences]}

// type_table1 <> type_table2 otherwise it would be within a type table. it suffices for nf
order_type_ref type_ref1=:(TypeTableTypeReference type_table1 tio_type_ref1) type_ref2=:(TypeTableTypeReference type_table2 tio_type_ref2)
	| type_table1 < type_table2
		= {otr_type_ref1 = type_ref1,otr_type_ref2 = type_ref2}
		| type_table1 > type_table2
			= {otr_type_ref1 = type_ref2,otr_type_ref2 = type_ref1};
			= order_tio_type_reference tio_type_ref1 tio_type_ref2;
where
	order_tio_type_reference {tio_type_without_definition=Just _} {tio_type_without_definition=Just _}
		= {otr_type_ref1 = type_ref1,otr_type_ref2 = type_ref2};
	order_tio_type_reference t1=:{tio_tr_module_n=tio_tr_module_n1,tio_tr_type_def_n=tio_tr_type_def_n1} t2=:{tio_tr_module_n=tio_tr_module_n2,tio_tr_type_def_n=tio_tr_type_def_n2}
		| tio_tr_module_n1 < tio_tr_module_n2
			= {otr_type_ref1 = type_ref1,otr_type_ref2 = type_ref2};
			|  tio_tr_module_n1 > tio_tr_module_n2
				= {otr_type_ref1 = type_ref2,otr_type_ref2 = type_ref1};
				| tio_tr_type_def_n1 < tio_tr_type_def_n2
					= {otr_type_ref1 = type_ref1,otr_type_ref2 = type_ref2};
					| tio_tr_type_def_n1 > tio_tr_type_def_n2
						= {otr_type_ref1 = type_ref2,otr_type_ref2 = type_ref1};
						= {otr_type_ref1 = type_ref1,otr_type_ref2 = type_ref2};

instance == OrderedTypeRef
where
	(==) ordered_type_refA ordered_type_refB
		= ordered_type_refA.otr_type_ref1 == ordered_type_refB.otr_type_ref1 &&
		  ordered_type_refA.otr_type_ref2 == ordered_type_refB.otr_type_ref2
			
// Properties:
// - the order of type tables is maintained. 1st arg b
class EqTypesExtended a
where
	equal_type_defs :: !a !a !{#*TypeTable} !*EqTypesState -> (!Bool,!{#*TypeTable},!*EqTypesState)

// only externally called
instance EqTypesExtended TypeTableTypeReference
where 
	equal_type_defs pt1=:(TypeTableTypeReference _ {tio_type_without_definition=Just type_name1}) pt2=:(TypeTableTypeReference _ {tio_type_without_definition=Just type_name2}) type_tables ets
		= (type_name1 == type_name2,type_tables,ets)

	equal_type_defs type_ref1=:(TypeTableTypeReference type_table1 type_reference1=:{tio_type_without_definition=Nothing}) type_ref2=:(TypeTableTypeReference type_table2 type_reference2=:{tio_type_without_definition=Nothing}) type_tables ets
		| type_ref1 == type_ref2
			= (True,type_tables,ets)

		# ets_within_type_table = type_table1 == type_table2
			
		// select {left,right} string tables
		# (ets_left_string_table,type_tables)
			= type_tables![type_table1].tt_type_io_state.tis_string_table
		# (ets_right_string_table,type_tables)
			= type_tables![type_table2].tt_type_io_state.tis_string_table

		# ets = { ets
			&	ets_within_type_table	= ets_within_type_table
			,	ets_left_i				= type_table1
			,	ets_right_i				= type_table2
			,	ets_left_string_table	= if ets_within_type_table {} ets_left_string_table
			,	ets_right_string_table	= if ets_within_type_table {} ets_right_string_table
			}; 
		= equal_type_defs type_reference1 type_reference2 type_tables ets
		
	equal_type_defs _ _ type_tables ets
		= (False,type_tables,ets)

class DerefTypeReference a
where
	deref_type_reference :: a !{#TypeTable} -> (TIO_CheckedTypeDef,!{#TypeTable})

instance DerefTypeReference TypeTableTypeReference
where
	deref_type_reference type1=:(TypeTableTypeReference type_table_i type=:{tio_tr_module_n,tio_tr_type_def_n,tio_type_without_definition=Nothing}) type_tables
		| type_table_i<0 || type_table_i>=size type_tables
			= abort ("deref_type_reference: invalid type table reference " +++ toString type_table_i +++ " - " +++ toString (size type_tables))
		= type_tables![type_table_i].tt_tio_common_defs.[tio_tr_module_n].tio_com_type_defs.[tio_tr_type_def_n]

// types within one type table and types across type tables
instance EqTypesExtended TIO_TypeReference
where
	equal_type_defs type_ref1a=:{tio_tr_module_n=tio_tr_module_n1} type_ref2a=:{tio_tr_module_n=tio_tr_module_n2} type_tables ets=:{/*ets_within_type_table=False,*/ets_left_module_i,ets_right_module_i,ets_left_i,ets_right_i}
		# type_ref1 = TypeTableTypeReference ets_left_i type_ref1a
		# type_ref2 = TypeTableTypeReference ets_right_i type_ref2a
		
		| type_ref1 == type_ref2
			= (True,type_tables,ets)

			// check whether type pair is assumed or proven to be equivalent
			# ordered_type_ref
				= order_type_ref type_ref1 type_ref2
			# (are_types_equivalent,ets)
				= find_type_equivalence ordered_type_ref ets
			| are_types_equivalent
				= (True,type_tables,ets)
	
				// assume type equivalence (termination)
				# ets = assume_type_equivalence ordered_type_ref ets
	
				// dereference type reference
				# (type1,type_tables)
					= deref_type_reference type_ref1 type_tables
				# (type2,type_tables )
					= deref_type_reference type_ref2 type_tables
										
				// set defining modules of new types
				# ets = { ets & ets_left_module_i = tio_tr_module_n1, ets_right_module_i = tio_tr_module_n2 }
					
				// check it
				# (is_type_pair_equivalent,type_tables,ets)
					= equal_type_defs type1 type2 type_tables ets
	
				// restore old defining modules
				# ets = { ets & ets_left_module_i = ets_left_module_i, ets_right_module_i = ets_right_module_i }

				# (assumed_type_equivalence,ets)
					= get_assumed_type_equivalence ets
				| is_type_pair_equivalent
					// assumption has been proven
					# ets = enter_proven_assumption assumed_type_equivalence ets				
					= (True,type_tables,ets)
	
					= (False,type_tables,ets)
					
	equal_type_defs t1 t2 type_tables ets
		= abort "equal_type_defs; internal error";

instance EqTypesExtended (TIO_TypeDef a) | EqTypesExtended a
where
	equal_type_defs {tio_td_name=tio_td_name1,tio_td_arity=tio_td_arity1,tio_td_rhs=tio_td_rhs1} 
				{tio_td_name=tio_td_name2,tio_td_arity=tio_td_arity2,tio_td_rhs=tio_td_rhs2} type_tables ets=:{ets_within_type_table,ets_left_string_table,ets_right_string_table}
		# tio_td_name
			= if ets_within_type_table (tio_td_name1 == tio_td_name2) (get_name_from_string_table tio_td_name1 ets_left_string_table == get_name_from_string_table tio_td_name2 ets_right_string_table)
		| tio_td_name && tio_td_arity1 == tio_td_arity2
			= equal_type_defs tio_td_rhs1 tio_td_rhs2 type_tables ets
			= (False,type_tables,ets)
	
instance EqTypesExtended TIO_TypeRhs
where
	equal_type_defs (TIO_AlgType tio_defined_symbols1) (TIO_AlgType tio_defined_symbols2) type_tables ets
		= equal_type_defs tio_defined_symbols1 tio_defined_symbols2 type_tables ets;
	equal_type_defs (TIO_RecordType tio_record_type1) (TIO_RecordType tio_record_type2) type_tables ets
		= equal_type_defs tio_record_type1 tio_record_type2 type_tables ets;
	equal_type_defs (TIO_GenericDictionaryType tio_record_type1) (TIO_GenericDictionaryType tio_record_type2) type_tables ets
		= equal_type_defs tio_record_type1 tio_record_type2 type_tables ets;
	equal_type_defs TIO_UnknownType TIO_UnknownType type_tables ets
		= abort "UnknownType";
	equal_type_defs (TIO_SynType syn_type1) (TIO_SynType syn_type2) type_tables ets
		= equal_type_defs syn_type1 syn_type2 type_tables ets;
	equal_type_defs _ _ type_tables ets
		= (False,type_tables,ets)

instance EqTypesExtended TIO_ConstructorSymbol
where
	equal_type_defs {tio_cons=tio_cons1} {tio_cons=tio_cons2} type_tables ets
		=	equal_type_defs tio_cons1 tio_cons2 type_tables ets

instance EqTypesExtended TIO_RecordType
where
	equal_type_defs {tio_rt_fields=tio_rt_fields1,tio_rt_constructor=tio_rt_constructor1} {tio_rt_fields=tio_rt_fields2,tio_rt_constructor=tio_rt_constructor2} type_tables ets
		# (fields_eq,type_tables,ets) = equal_type_defs tio_rt_fields1 tio_rt_fields2 type_tables ets
		| fields_eq
			= equal_type_defs tio_rt_constructor1 tio_rt_constructor2 type_tables ets
			= (False,type_tables,ets)

instance EqTypesExtended TIO_DefinedSymbol
where
	equal_type_defs {tio_ds_ident=tio_ds_ident1,tio_ds_arity=tio_ds_arity1,tio_ds_index=tio_ds_index1} {tio_ds_ident=tio_ds_ident2,tio_ds_arity=tio_ds_arity2,tio_ds_index=tio_ds_index2} 
			type_tables ets=:{ets_within_type_table,ets_left_string_table,ets_right_string_table,ets_left_i,ets_right_i,ets_left_module_i,ets_right_module_i}
		# tio_ds_ident
			= if ets_within_type_table (tio_ds_ident1 == tio_ds_ident2) 
				(get_name_from_string_table tio_ds_ident1 ets_left_string_table == get_name_from_string_table tio_ds_ident2 ets_right_string_table)
		| tio_ds_ident && tio_ds_arity1 == tio_ds_arity2 
			# (tio_cons_symb1,type_tables)
				= type_tables![ets_left_i].tt_tio_common_defs.[ets_left_module_i].tio_com_cons_defs.[tio_ds_index1];
			# (tio_cons_symb2,type_tables)
				= type_tables![ets_right_i].tt_tio_common_defs.[ets_right_module_i].tio_com_cons_defs.[tio_ds_index2];
			= equal_type_defs tio_cons_symb1 tio_cons_symb2 type_tables ets;			
			= (False,type_tables,ets);
	equal_type_defs _ _ type_tables ets
		= abort "instance EqTypesExtended TIO_DefinedSymbol";

instance EqTypesExtended TIO_ConsDef
where
	equal_type_defs {tio_cons_symb=tio_cons_symb1,tio_cons_type=tio_cons_type1,tio_cons_exi_vars=tio_cons_exi_vars1} 
				{tio_cons_symb=tio_cons_symb2,tio_cons_type=tio_cons_type2,tio_cons_exi_vars=tio_cons_exi_vars2} type_tables ets=:{ets_within_type_table,ets_left_string_table,ets_right_string_table}
		# tio_cons_symb
			= if ets_within_type_table (tio_cons_symb1 == tio_cons_symb2) (get_name_from_string_table tio_cons_symb1 ets_left_string_table == get_name_from_string_table tio_cons_symb2 ets_right_string_table)
		| tio_cons_symb
			// constructors are equally named
			= equal_type_defs tio_cons_type1 tio_cons_type2 type_tables ets
			= (False,type_tables,ets);

instance EqTypesExtended TIO_SymbolType
where
	equal_type_defs {tio_st_vars=tio_st_vars1,tio_st_args=tio_st_args1,tio_st_arity=tio_st_arity1,tio_st_result=tio_st_result1,tio_st_args_strictness=tio_st_args_strictness1}
				{tio_st_vars=tio_st_vars2,tio_st_args=tio_st_args2,tio_st_arity=tio_st_arity2,tio_st_result=tio_st_result2,tio_st_args_strictness=tio_st_args_strictness2} type_tables ets
		| tio_st_arity1 == tio_st_arity2 && equal_strictness_lists tio_st_args_strictness1 tio_st_args_strictness2
			# (are_st_vars_equal,type_tables,ets)
				= equal_type_defs tio_st_vars1 tio_st_vars2 type_tables ets;
			| are_st_vars_equal
				# (are_st_args_equal,type_tables,ets)
					= equal_type_defs tio_st_args1 tio_st_args2 type_tables ets;
				| are_st_args_equal
					= equal_type_defs tio_st_result1 tio_st_result2 type_tables ets;
					// tio_st_args1 <> tio_st_args2
					= (False,type_tables,ets) 
				// tio_st_vars1 <> tio_st_vars2
				= (False,type_tables,ets)
			// tio_st_arity1 <> tio_st_arity2
			= (False,type_tables,ets)
			
	equal_type_defs _ _ type_tables ets
		= abort "instance EqTypesExtended TIO_SymbolType";

instance EqTypesExtended TIO_AType
where
	equal_type_defs {tio_at_type=tio_at_type1} {tio_at_type=tio_at_type2} type_tables ets
		= equal_type_defs tio_at_type1 tio_at_type2 type_tables ets;
			
instance EqTypesExtended TIO_Type
where
	equal_type_defs (TIO_TAS tio_type_symb_ident1 tio_atypes1 strictness1) (TIO_TAS tio_type_symb_ident2 tio_atypes2 strictness2) type_tables ets
		# (are_type_symb_idents_equal,type_tables,ets)
			= equal_type_defs tio_type_symb_ident1 tio_type_symb_ident2 type_tables ets;
		| are_type_symb_idents_equal && equal_strictness_lists strictness1 strictness2
			= equal_type_defs tio_atypes1 tio_atypes2 type_tables ets;
			= (False,type_tables,ets);
	equal_type_defs (tio_atype1a ----> tio_atype1b) (tio_atype2a ----> tio_atype2b) type_tables ets
		# (are_atypes1_equal,type_tables,ets)
			= equal_type_defs tio_atype1a tio_atype2a type_tables ets;
		| are_atypes1_equal
			= equal_type_defs tio_atype1b tio_atype2b type_tables ets;
			= (False,type_tables,ets);
	equal_type_defs (tio_cons_variable1 :@@: tio_atypes1) (tio_cons_variable2 :@@: tio_atypes2) type_tables ets
		# (are_tio_cons_variables_equal,type_tables,ets)
			= equal_type_defs tio_cons_variable1 tio_cons_variable2 type_tables ets;
		| are_tio_cons_variables_equal
			= equal_type_defs tio_atypes1 tio_atypes2 type_tables ets;
			= (False,type_tables,ets);
	equal_type_defs (TIO_TB tio_basic_type1) (TIO_TB tio_basic_type2) type_tables ets
		= equal_type_defs tio_basic_type1 tio_basic_type2 type_tables ets;
	equal_type_defs (TIO_GTV tio_type_var1) (TIO_GTV tio_type_var2) type_tables ets
		= equal_type_defs tio_type_var1 tio_type_var2 type_tables ets;
	equal_type_defs (TIO_TV tio_type_var1) (TIO_TV tio_type_var2) type_tables ets
		= equal_type_defs tio_type_var1 tio_type_var2 type_tables ets;
	equal_type_defs (TIO_TQV tio_type_var1) (TIO_TQV tio_type_var2) type_tables ets
		= equal_type_defs tio_type_var1 tio_type_var2 type_tables ets;
	equal_type_defs (TIO_GenericFunction kind1 tio_symbol_type1) (TIO_GenericFunction kind2 tio_symbol_type2) type_tables ets
		| kind1==kind2
			= equal_type_defs tio_symbol_type1 tio_symbol_type2 type_tables ets
			= (False,type_tables,ets);
	equal_type_defs TIO_TE TIO_TE type_tables ets
		= (True,type_tables,ets);
	equal_type_defs _ _ type_tables ets
		= (False,type_tables,ets);
		
instance EqTypesExtended TIO_BasicType
where
	equal_type_defs TIO_BT_Int TIO_BT_Int type_tables ets
		= (True,type_tables,ets)
	equal_type_defs TIO_BT_Char TIO_BT_Char type_tables ets
		= (True,type_tables,ets)
	equal_type_defs TIO_BT_Real TIO_BT_Real type_tables ets
		= (True,type_tables,ets)
	equal_type_defs TIO_BT_Bool TIO_BT_Bool type_tables ets
		= (True,type_tables,ets)
	equal_type_defs TIO_BT_Dynamic TIO_BT_Dynamic type_tables ets
		= (True,type_tables,ets)
	equal_type_defs TIO_BT_File TIO_BT_File type_tables ets
		= (True,type_tables,ets)
	equal_type_defs TIO_BT_World TIO_BT_World type_tables ets
		= (True,type_tables,ets)
	equal_type_defs (TIO_BT_String tio_type1) (TIO_BT_String tio_type2) type_tables ets
		= equal_type_defs tio_type1 tio_type2 type_tables ets;
	equal_type_defs _ _ type_tables ets
		= (False,type_tables,ets);
		
instance EqTypesExtended TIO_ConsVariable
where
	equal_type_defs (TIO_CV tio_type_var1) (TIO_CV tio_type_var2) type_tables ets
		= equal_type_defs tio_type_var1 tio_type_var2 type_tables ets;
	equal_type_defs (TIO_TempCV _) (TIO_TempCV _) type_tables ets
		= abort "instance equal_type_defs TIO_ConsVariable; TIO_TempCV";
	equal_type_defs (TIO_TempQCV _) (TIO_TempQCV _) type_tables ets
		= abort "instance equal_type_defs TIO_ConsVariable; TIO_TempQCV";
	equal_type_defs _ _ type_tables ets
		= (False,type_tables,ets);

instance EqTypesExtended TIO_TypeSymbIdent
where
	equal_type_defs {tio_type_name_ref=tio_type_name_ref1,tio_type_arity=tio_type_arity1} {tio_type_name_ref=tio_type_name_ref2,tio_type_arity=tio_type_arity2} type_tables ets
		| tio_type_arity1 == tio_type_arity2
			= equal_type_defs tio_type_name_ref1 tio_type_name_ref2 type_tables ets;
			= (False,type_tables,ets);

instance EqTypesExtended TIO_ATypeVar
where
	equal_type_defs {tio_atv_variable=tio_atv_variable1} {tio_atv_variable=tio_atv_variable2} type_tables ets
		= equal_type_defs tio_atv_variable1 tio_atv_variable2 type_tables ets;

instance EqTypesExtended TIO_TypeVar
where
	equal_type_defs {tio_tv_name=tio_tv_name1} {tio_tv_name=tio_tv_name2} type_tables ets=:{ets_within_type_table,ets_left_string_table,ets_right_string_table}
		= (tio_tv_name1 == tio_tv_name2,type_tables,ets)
		
instance EqTypesExtended TIO_FieldSymbol
where
	equal_type_defs {tio_fs_name=tio_fs_name1} {tio_fs_name=tio_fs_name2} type_tables 
				ets=:{ets_within_type_table,ets_left_string_table,ets_right_string_table}
		# w1 = get_name_from_string_table tio_fs_name1 ets_left_string_table;
		# w2 = get_name_from_string_table tio_fs_name2 ets_right_string_table;
		# tio_fs_name_eq = if ets_within_type_table
							(tio_fs_name1 == tio_fs_name2)
							(w1 == w2);
		= (tio_fs_name_eq,type_tables,ets);

instance EqTypesExtended [a] | EqTypesExtended a
where
	equal_type_defs [] [] tio_common_defs type_io_state
		= (True,tio_common_defs,type_io_state);
	equal_type_defs [type1:types1] [type2:types2] tio_common_defs type_io_state
		# (type1_equals_type2,tio_common_defs,type_io_state)
			= equal_type_defs type1 type2 tio_common_defs type_io_state;
		| not type1_equals_type2
			= (False,tio_common_defs,type_io_state);
		= equal_type_defs types1 types2 tio_common_defs type_io_state;
	equal_type_defs _ _ tio_common_defs type_io_state
		= (False,tio_common_defs,type_io_state);
			
instance EqTypesExtended {#a} | Array {#} a & EqTypesExtended a
where
	equal_type_defs a1 a2 type_tables ets
		| s_a1 <> s_a2
			= (False,type_tables,ets)
		= equal_type_defs_loop 0 s_a1 type_tables ets
	where 
		equal_type_defs_loop i limit type_tables ets
			| i == limit
				= (True,type_tables,ets)
			# (elements_are_equal,type_tables,ets)
				= equal_type_defs a1.[i] a2.[i] type_tables ets;
			| not elements_are_equal
				= (False,type_tables,ets);
			= equal_type_defs_loop (inc i) limit type_tables ets;

		s_a1 = size a1
		s_a2 = size a2
