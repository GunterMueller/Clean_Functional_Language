implementation module type_io_static

import type_io_read
import DefaultElem
import StdEnv
import StdMaybe
import BitSet
import StdDynamicTypes

// compiler

from utilities import foldSt, mapSt

// extended
from ExtString import CharIndex, CharIndexBackwards
from pdExtFile import path_separator
from ExtFile import ExtractPathFileAndExtension
from general import ::Optional(..)

import type_io_equal_types
import link_switches

collect_type_infoNEW :: ![String] !*Files -> (!Bool,!*{#TIO_CommonDefs},!*TypeIOState,!*Files)
collect_type_infoNEW module_names files
	# n_module_names = length module_names
	# type_io_state = { default_type_io_state & tis_n_common_defs = n_module_names };
	# tio_common_defs = createArray n_module_names empty_tio_common_def;
	= collect_type_info2 module_names 0 tio_common_defs type_io_state files;

collect_type_info2 :: [String] !Int !*{#TIO_CommonDefs} !*TypeIOState !*Files -> (!Bool,!*{#TIO_CommonDefs},!*TypeIOState,!*Files)
// The type information per module is read and inserted in the array	
collect_type_info2 [tcl_file_nameQ:tcl_file_names] i tio_common_defs type_io_state files
	# tcl_file_name = fst (ExtractPathFileAndExtension tcl_file_nameQ)
	# (ok1,tcl_file,files)
		= fopen (tcl_file_name +++ ".tcl") FReadData files;
	| not ok1
		# files = snd (fclose tcl_file files)
		= collect_type_info2 tcl_file_names i tio_common_defs type_io_state files;

	# (ok2,tio_common_def,tcl_file,type_io_state)
		= read_type_info tcl_file { type_io_state & tis_current_module_i = i};
	# (_,files)
		= fclose tcl_file files;
	| not ok2
		= abort ("error reading type info in module " +++ tcl_file_name +++ ".tcl");

	# module_name = snd (ExtractPathAndFile tcl_file_name);
	#  (tio_module,type_io_state)
		= insert_name (Yes i) No module_name type_io_state;
	// er worden geen namen opgeslagen
	# tio_common_def = { tio_common_def & tio_module = tio_module };
	= collect_type_info2 tcl_file_names (inc i) { tio_common_defs & [i] = tio_common_def } type_io_state files;
where
	ExtractPathAndFile :: !String -> (!String,!String);
	ExtractPathAndFile path_and_file 
		#! (dir_delimiter_found,i)
			= CharIndexBackwards path_and_file (size path_and_file - 1) path_separator;
		| dir_delimiter_found
			# file_name_with_extension
				= path_and_file % (i+1,size path_and_file - 1);
			= (if (i == 0) (toString path_separator) (path_and_file % (0,i-1)),file_name_with_extension);
			= ("",path_and_file);

collect_type_info2 [] tis_n_common_defs tio_common_defsNEW type_io_state=:{tis_current_string_index} files
	# tio_common_defs = { tio_common_defsNEW.[i] \\ i <- [0..dec tis_n_common_defs] }
	# (type_io_state) = { type_io_state & tis_n_common_defs	= tis_n_common_defs };

	# (string_table,type_io_state)
		= build_string_table 0 NAME_TABLE_SIZE (createArray tis_current_string_index '\0') type_io_state
	# type_io_state = { type_io_state & tis_string_table = string_table };

	# (tio_common_defs,type_io_state)
		= replace_string_offsets_in_tio_imported_modules_by_indices_in_tio_common_defs 0 tio_common_defs type_io_state;

	# (tio_common_defs,type_io_state)
		= initialize_type_io_state tio_common_defs type_io_state;

	# (tio_common_defs,type_io_state)
		= resolve_type_references2 0 tis_n_common_defs tio_common_defs type_io_state;

	#! tis_max_types = type_io_state.tis_max_types
	# is_type_already_checked = NewBitSet (tis_max_types * tis_max_types)

	# (tio_common_defs,type_io_state)
		= collect_equal_type_definitions 0 NAME_TABLE_SIZE is_type_already_checked tio_common_defs type_io_state [];

	= (True,tio_common_defs,type_io_state,files)	
where
	build_string_table i limit string_table type_io_state
		| i == limit
			= (string_table,type_io_state);
			
		# (hash_table_elements,type_io_state)
			= type_io_state!tis_string_hash_table.[i];
		# string_table
			= foldSt insert_string_in_string_table hash_table_elements string_table
		= build_string_table (inc i) limit string_table type_io_state;
	where
		insert_string_in_string_table {hte_name,hte_index} string_table
			= copy 0 (size hte_name) hte_index string_table;
		where
			copy i limit dest_i string_table
				| i == limit
					= string_table;
				= copy (inc i) limit (inc dest_i) { string_table & [dest_i] = hte_name.[i] };

	replace_string_offsets_in_tio_imported_modules_by_indices_in_tio_common_defs i tio_common_defs type_io_state
		| i == tis_n_common_defs //limit
			= (tio_common_defs,type_io_state);
			
			// get string offsets to be replaced by their indices in tio_common_defs				
			# (tio_common_def,tio_common_defs)
				= replace tio_common_defs i empty_tio_common_def	

			# n_imported_modules
				= size tio_common_def.tio_imported_modules;
			# (tio_imported_modules,type_io_state)
				= replace_within_tio_imported_modules 0 n_imported_modules tio_common_def.tio_imported_modules (createArray n_imported_modules (-1)) type_io_state;
				
			# tio_common_defs
				= { tio_common_defs & [i] = {tio_common_def & tio_imported_modules = tio_imported_modules } };
	
			= replace_string_offsets_in_tio_imported_modules_by_indices_in_tio_common_defs 
				(inc i) tio_common_defs type_io_state;
			
	where
		replace_within_tio_imported_modules :: !Int !Int !{#Int} !*{#Int} !*TypeIOState -> (!*{#Int},!*TypeIOState);
		replace_within_tio_imported_modules i limit tio_imported_modules new_tio_imported_modules type_io_state=:{tis_string_table}
			| i == limit
				= (new_tio_imported_modules,type_io_state);
				
				# (module_string_offset,tio_imported_modules)
					= tio_imported_modules![i];

				# (ok,null_index)
					= CharIndex tis_string_table module_string_offset '\0'
				| not ok
					= abort "replace_within_tio_imported_modules: internal error";
					
				// module names are looked up more than once if they are imported more than once
				# module_name
					= tis_string_table % (module_string_offset,dec null_index);
				# module_name_hashed
					= name_hash module_name;
				
				# (hash_table_elements,type_io_state)
					= type_io_state!tis_string_hash_table.[module_name_hashed];
				 # v = [ module_n \\ {hte_name,hte_module_ref=ModuleName module_n} <- hash_table_elements | hte_name == module_name];
				# module_n
					= hd v
				| isEmpty v
					= abort ("<" +++ module_name +++ ">" +++ toString null_index);
				= replace_within_tio_imported_modules (inc i) limit tio_imported_modules { new_tio_imported_modules & [i] = module_n } type_io_state;

:: *RTRState = {
		rtrs_current_icl_module :: !Int,
		rtrs_is_module_already_in_scope :: !*BitSet,
		rtrs_tio_common_defs :: !*{#TIO_CommonDefs}
	};

// pass 2: resolving type references	
resolve_type_references2 :: !Int !Int !*{#TIO_CommonDefs} !*TypeIOState -> (!*{#TIO_CommonDefs},!*TypeIOState)
resolve_type_references2 current_icl_module n_icl_modules tio_common_defs type_io_state=:{tis_string_table}
	| current_icl_module == n_icl_modules
		= (tio_common_defs,type_io_state);

	// init
	# is_module_already_in_scope = NewBitSet n_icl_modules
	# (is_module_already_in_scope,tio_common_defs)
		= build_scope [current_icl_module] is_module_already_in_scope tio_common_defs;

// new ...
	#! (tio_global_module_strings,tio_common_defs)
		= tio_common_defs![current_icl_module].tio_global_module_strings
	#! empty_tio_common_def1
		= USE_NEW_SCOPE_RESOLUTION_METHOD
			{empty_tio_common_def & tio_global_module_strings = tio_global_module_strings}
			empty_tio_common_def
// ... new

	# (tio_common_def,tio_common_defs)
		= replace tio_common_defs current_icl_module empty_tio_common_def1

	# rtrs = {	rtrs_current_icl_module = current_icl_module,
				rtrs_is_module_already_in_scope = is_module_already_in_scope,
				rtrs_tio_common_defs = tio_common_defs }

	# (tio_common_def,{rtrs_tio_common_defs=tio_common_defs},type_io_state)
		= resolve_type_references tio_common_def rtrs type_io_state
		
	# tio_common_defs = { tio_common_defs & [current_icl_module] = tio_common_def };
	= resolve_type_references2 (inc current_icl_module) n_icl_modules tio_common_defs type_io_state;
where
	build_scope :: [Int] !*BitSet !*{#TIO_CommonDefs} -> (!*BitSet,!*{#TIO_CommonDefs});
	build_scope [] is_module_already_in_scope tio_common_defs
		= (is_module_already_in_scope,tio_common_defs)
	build_scope [current_module_n:others] is_module_already_in_scope tio_common_defs 
		# (is_current_module_n_already_in_scope,is_module_already_in_scope)
			= isBitSetMember is_module_already_in_scope current_module_n;
		| is_current_module_n_already_in_scope
			= build_scope others is_module_already_in_scope tio_common_defs 

//		| current_icl_module == current_module_n
//			= abort ("sss1" +++ module_name)
			
		# is_module_already_in_scope
			= AddBitSet is_module_already_in_scope current_module_n;

		# (tio_imported_modules,tio_common_defs)
			= tio_common_defs![current_module_n].tio_imported_modules;
		=  build_scope (others ++ [tim \\ tim <-: tio_imported_modules]) is_module_already_in_scope tio_common_defs;

class ResolveTypeReferences a
where
	resolve_type_references :: a !*RTRState !*TypeIOState -> (a,!*RTRState,!*TypeIOState)

instance ResolveTypeReferences TIO_CommonDefs
where
	resolve_type_references tio_common_def=:{tio_com_type_defs,tio_com_cons_defs} rtrs type_io_state
		# (tio_com_type_defs,rtrs,type_io_state)
			= resolve_type_references tio_com_type_defs rtrs type_io_state;
		# (tio_com_cons_defs,rtrs,type_io_state)
			= resolve_type_references tio_com_cons_defs rtrs type_io_state;
		# tio_common_def 
			= { tio_common_def &
				tio_com_type_defs		= tio_com_type_defs
			,	tio_com_cons_defs		= tio_com_cons_defs
			};
		= (tio_common_def,rtrs,type_io_state);

instance ResolveTypeReferences (TIO_TypeDef a) | ResolveTypeReferences a
where
	resolve_type_references tio_type_def=:{tio_td_rhs} rtrs type_io_state
		# (tio_td_rhs,rtrs,type_io_state)
			= resolve_type_references tio_td_rhs rtrs type_io_state;		
		# tio_type_def = { tio_type_def & tio_td_rhs = tio_td_rhs };
		= (tio_type_def,rtrs,type_io_state);

instance ResolveTypeReferences TIO_TypeRhs
where
	resolve_type_references tio_alg_type=:(TIO_AlgType _) rtrs type_io_state
		= (tio_alg_type,rtrs,type_io_state);
	resolve_type_references (TIO_SynType tio_atype) rtrs type_io_state
		# (tio_atype,rtrs,type_io_state)
			= resolve_type_references tio_atype rtrs type_io_state;
		= (TIO_SynType tio_atype,rtrs,type_io_state);
	resolve_type_references tio_record_type=:(TIO_RecordType _) rtrs type_io_state
		= (tio_record_type,rtrs,type_io_state);
	resolve_type_references tio_record_type=:(TIO_GenericDictionaryType _) rtrs type_io_state
		= (tio_record_type,rtrs,type_io_state);
	resolve_type_references tio_abstract_type=:(TIO_AbstractType _) rtrs type_io_state
		= (tio_abstract_type,rtrs,type_io_state);
	resolve_type_references TIO_UnknownType rtrs type_io_state
		= (TIO_UnknownType,rtrs,type_io_state);
		
instance ResolveTypeReferences TIO_AType
where
	resolve_type_references tio_atype=:{tio_at_type} rtrs type_io_state
		# (tio_at_type,rtrs,type_io_state)
			= resolve_type_references tio_at_type rtrs type_io_state;
		# tio_atype = { tio_atype & tio_at_type = tio_at_type };
		= (tio_atype,rtrs,type_io_state);

instance ResolveTypeReferences TIO_Type
where
	resolve_type_references (TIO_TAS_tcl type_symb_ident global_type_index tio_a_types strictness) rtrs type_io_state	
		# (type_symb_ident,rtrs,type_io_state)
			= resolve_type_references_TA_symbol type_symb_ident global_type_index rtrs type_io_state;
		# (tio_a_types,rtrs,type_io_state)
			= resolve_type_references tio_a_types rtrs type_io_state;
		= (TIO_TAS type_symb_ident tio_a_types strictness,rtrs,type_io_state);

	resolve_type_references (tio_atype1 ----> tio_atype2) rtrs type_io_state	
		# (tio_atype1,rtrs,type_io_state)
			= resolve_type_references tio_atype1 rtrs type_io_state;
		# (tio_atype2,rtrs,type_io_state)
			= resolve_type_references tio_atype2 rtrs type_io_state;
		= (tio_atype1 ----> tio_atype2,rtrs,type_io_state);
		
	resolve_type_references (tio_cons_variable :@@: tio_atypes) rtrs type_io_state	
		# (tio_atypes,rtrs,type_io_state)
			= resolve_type_references tio_atypes rtrs type_io_state;
		= (tio_cons_variable :@@: tio_atypes,rtrs,type_io_state);
		
	resolve_type_references tb=:(TIO_TB tio_basic_type) rtrs type_io_state
		= case tio_basic_type of
			(TIO_BT_String tio_type)
				# (tio_type,rtrs,type_io_state)
					= resolve_type_references tio_type rtrs type_io_state;
				-> (TIO_TB (TIO_BT_String tio_type),rtrs,type_io_state);
			_
				-> (tb,rtrs,type_io_state);

	resolve_type_references (TIO_GenericFunction kind symbol_type) rtrs type_io_state
		# (symbol_type,rtrs,type_io_state)
			= resolve_type_references symbol_type rtrs type_io_state;
		= (TIO_GenericFunction kind symbol_type,rtrs,type_io_state);

	resolve_type_references tio_type  rtrs type_io_state
		= (tio_type,rtrs,type_io_state);

resolve_type_references_TA_symbol tio_type_symb_ident=:{tio_type_name_ref} global_type_index rtrs type_io_state
	# (tio_type_name_ref,rtrs,type_io_state)
		= USE_NEW_SCOPE_RESOLUTION_METHOD (yes tio_type_name_ref rtrs type_io_state) (resolve_type_references tio_type_name_ref rtrs type_io_state);
	# tio_type_symb_ident = { tio_type_symb_ident & tio_type_name_ref = tio_type_name_ref };
	= (tio_type_symb_ident,rtrs,type_io_state);
	where
		yes {tio_tr_module_n=type_name_offset} rtrs=:{rtrs_current_icl_module} type_io_state=:{tis_string_table}
			# (ok,null_index)
				= CharIndex tis_string_table type_name_offset '\0'
			| not ok
				= abort "find_type2: internal error; type name did not terminate with NULL"

			# type_name = tis_string_table % (type_name_offset,dec null_index)

			# (found,hte,type_io_state)
				= type_io_find_name type_name type_io_state;
			| not found
				= abort ("find_type: type '" +++ type_name +++ "' could not be found");
			
			| isNoTypeName hte.hte_type_refs
				// predefined
				# tio_type_reference = { default_elem & tio_type_without_definition	= Just type_name };
				= (tio_type_name_ref,rtrs,type_io_state)

			#! (module_name,rtrs) = rtrs!rtrs_tio_common_defs.[rtrs_current_icl_module].tio_global_module_strings.[global_type_index.tio_glob_module]
			# (found,hte=:{hte_name,hte_module_ref=ModuleName i},type_io_state)
				= type_io_find_name module_name type_io_state;
			| found
				#! tio_type_name_ref
					= { default_elem &
						tio_type_without_definition		= Nothing
					,	tio_tr_module_n					= i
					,	tio_tr_type_def_n				= global_type_index.tio_glob_object
					}
						
				= (tio_type_name_ref,rtrs,type_io_state)
				= abort "niet gevonden"
							
instance ResolveTypeReferences TIO_TypeReference
where
	resolve_type_references {tio_tr_module_n} rtrs type_io_state
		= find_type2 tio_tr_module_n rtrs type_io_state;
		
instance ResolveTypeReferences TIO_ConsDef
where
	resolve_type_references tio_com_cons_def=:{tio_cons_type} rtrs type_io_state
		# (tio_cons_type,rtrs,type_io_state)
			= resolve_type_references tio_cons_type rtrs type_io_state;
			
		# tio_com_cons_def
			= { tio_com_cons_def &
				tio_cons_type		= tio_cons_type
			};
		= (tio_com_cons_def,rtrs,type_io_state);

instance ResolveTypeReferences TIO_SymbolType
where
	resolve_type_references tio_symbol_type=:{tio_st_args,tio_st_result} rtrs type_io_state
		# (tio_st_args,rtrs,type_io_state)
			= resolve_type_references tio_st_args rtrs type_io_state;
		# (tio_st_result,rtrs,type_io_state)
			= resolve_type_references tio_st_result rtrs type_io_state;
			
		# tio_symbol_type
			= { tio_symbol_type &
				tio_st_args			= tio_st_args
			,	tio_st_result		= tio_st_result
			};
		= (tio_symbol_type,rtrs,type_io_state);

instance ResolveTypeReferences [a] | ResolveTypeReferences a
where 
	resolve_type_references list rtrs type_io_state
		# (list,(rtrs,type_io_state))
			= mapSt f list (rtrs,type_io_state);
		= (list,rtrs,type_io_state);
	where
		f a (rtrs,type_io_state)
			# (a,rtrs,type_io_state)
				= resolve_type_references a rtrs type_io_state;
			= (a,(rtrs,type_io_state))

instance ResolveTypeReferences {#b} | ResolveTypeReferences b & DefaultElem b & Array {#} b
where
	resolve_type_references array rtrs type_io_state
		# s_array = size array;
		# new_array = createArray s_array default_elem;
		= resolve_type_references_loop 0 s_array array new_array rtrs type_io_state;
	where
		resolve_type_references_loop i limit array new_array rtrs type_io_state
			| i == limit
				= (new_array,rtrs,type_io_state);
			# (elem,array) = array![i];
			# (elem,rtrs,type_io_state)
				= resolve_type_references elem rtrs type_io_state;
			= resolve_type_references_loop (inc i) limit array { new_array & [i] = elem } rtrs type_io_state;

:: Partition
	= NotPartitioned
	| BeingPartitioned
	| PartitionedIn !Int /*!Bool*/			// partition_i partition_has_multiple_implementations i.e. partition has at least size 2
	;
	
isNotPartitioned NotPartitioned		= True
isNotPartitioned BeingPartitioned	= abort "BeingPartitioned"
isNotPartitioned _				= False

isNotPartitioned_and_isNotBeingPartitioned NotPartitioned		= True
isNotPartitioned_and_isNotBeingPartitioned BeingPartitioned	= True
isNotPartitioned_and_isNotBeingPartitioned _				= False

extractPartitionIn (PartitionedIn i )	= i

collect_equal_type_definitions :: !Int !Int !*BitSet !*{#TIO_CommonDefs} !*TypeIOState ![EquivalentTypeDef] -> *(!*{#TIO_CommonDefs},!*TypeIOState);
collect_equal_type_definitions i limit is_type_already_checked tio_common_defs type_io_state equivalent_type_definitions
	| i == limit
		# type_io_state = {type_io_state &
							tis_equivalent_type_definitions	= { etd \\ etd <- equivalent_type_definitions }
						  };
		= (tio_common_defs,type_io_state);

	# (hash_table_elements,type_io_state) = type_io_state!tis_string_hash_table.[i];
	# (is_type_already_checked,tio_common_defs,type_io_state,equivalent_type_definitions)
		= foldSt collect_within_equally_named_types hash_table_elements (is_type_already_checked,tio_common_defs,type_io_state,equivalent_type_definitions);	

	= collect_equal_type_definitions (inc i) limit is_type_already_checked tio_common_defs type_io_state equivalent_type_definitions;
where
	collect_within_equally_named_types :: !.HashTableElement !*(!*BitSet,!*{#TIO_CommonDefs},!*TypeIOState,[EquivalentTypeDef])
														   -> *(!*BitSet,!*{#TIO_CommonDefs},!*TypeIOState,[EquivalentTypeDef]);
	collect_within_equally_named_types hte=:{hte_type_refs=TypeName type_refs=:[_,_:_],hte_name,hte_index} (is_type_already_checked,tio_common_defs,type_io_state,equivalent_type_definitions)
		// equal_types (type1,type2) == equal_types (type2,type1)  equal_types is a symmetric function
		// the type_refs are guaranteed to be different
		# type_refs = { type_ref \\ type_ref <- type_refs }
		# (n_type_refs,type_refs) = usize type_refs

		# type_ref_partition_status = createArray n_type_refs NotPartitioned;

		// partition type refs
		# (type_refs,n_partitions,type_ref_partition_status,is_type_already_checked,tio_common_defs,type_io_state)
			= assign_partition_to_type_definition 0 n_type_refs type_refs 0 type_ref_partition_status is_type_already_checked tio_common_defs type_io_state
			
		// each partition of equivalent types should only have one single implementation instead of n implementations where n
		// is the size of the partition. For partitions with n at least two, a single implementation must be chosen in order
		// to make a dynamic using the equivalent type associated with that particular partition usable in the contexts of the
		// other members of that same partition.
		# equivalent_types = createArray n_partitions [];
		# (equivalent_types,type_refs,type_ref_partition_status)
			= collect_partitions 0 n_type_refs equivalent_types type_refs type_ref_partition_status

		# equivalent_types
			= [ { p \\ p <- partition } \\ partition <-: equivalent_types | (length partition) > 1 ];
		| isEmpty equivalent_types
			// Example: class EncodeDynamic and :: EncodeDynamic. The type equivalent check will because the former is
			//          not a type. Thus there are no partitions and nothing is added.
			= (is_type_already_checked,tio_common_defs,type_io_state,equivalent_type_definitions);

		# equivalent_type_def
			= { EquivalentTypeDef |
				type_name	= hte_index
			,	partitions	= { p \\ p <- equivalent_types }
			};
		= (is_type_already_checked,tio_common_defs,type_io_state,[equivalent_type_def:equivalent_type_definitions])
	where
		collect_partitions :: !Int !Int !*{[TIO_TypeReference]} !*{#TIO_TypeReference} !*{Partition} -> (!*{[TIO_TypeReference]},!*{#TIO_TypeReference},!*{Partition})
		collect_partitions i n_type_refs equivalent_types type_refs type_ref_partition_status
			| i == n_type_refs
				= (equivalent_types,type_refs,type_ref_partition_status)
				
			# (PartitionedIn partition_i,type_ref_partition_status)
				= type_ref_partition_status![i]

			# (elem,type_refs) = type_refs![i]
			# (elems,equivalent_types) = equivalent_types![partition_i]
			# equivalent_types = { equivalent_types & [partition_i] = [elem:elems] }
			= collect_partitions (inc i) n_type_refs equivalent_types type_refs type_ref_partition_status
				
		assign_partition_to_type_definition :: !Int !Int !*{#TIO_TypeReference} !Int !*{Partition} !*BitSet !*{#TIO_CommonDefs} !*TypeIOState
													-> *(!*{#TIO_TypeReference},!Int,!*{Partition},!*BitSet,!*{#TIO_CommonDefs},!*TypeIOState);
		assign_partition_to_type_definition ith_type_ref n_type_refs type_refs n_partitions type_ref_partition_status is_type_already_checked tio_common_defs type_io_state
			| ith_type_ref == n_type_refs
				= (type_refs,n_partitions,type_ref_partition_status,is_type_already_checked,tio_common_defs,type_io_state);
				
			# (ith_type_ref_partition_status,type_ref_partition_status)
				= type_ref_partition_status![ith_type_ref];
			| not (isNotPartitioned ith_type_ref_partition_status)
				// ith type ref has already been partitioned, skip it
				= assign_partition_to_type_definition (inc ith_type_ref) n_type_refs type_refs n_partitions type_ref_partition_status is_type_already_checked tio_common_defs type_io_state
		
			// type_ref not partitioned, look if it fits in an existing partition
			# (found_a_partition,partition_n,type_refs,type_ref_partition_status,is_type_already_checked,tio_common_defs,type_io_state)
				= look_for_existing_partition 0 n_type_refs type_refs type_ref_partition_status is_type_already_checked tio_common_defs type_io_state
			| found_a_partition
				// type of current_type_ref is already element of partition partition_n, add current type to it
				# type_ref_partition_status
					= { type_ref_partition_status & [ith_type_ref] = PartitionedIn partition_n }
				= assign_partition_to_type_definition (inc ith_type_ref) n_type_refs type_refs n_partitions type_ref_partition_status is_type_already_checked tio_common_defs type_io_state
					
				// new partition is needed
				# type_ref_partition_status
					= { type_ref_partition_status & [ith_type_ref] = PartitionedIn n_partitions }
				= assign_partition_to_type_definition (inc ith_type_ref) n_type_refs type_refs (inc n_partitions) type_ref_partition_status is_type_already_checked tio_common_defs type_io_state
		where
			look_for_existing_partition :: !Int !Int !*{#TIO_TypeReference} !*{Partition} !*BitSet !*{#TIO_CommonDefs} !*TypeIOState
									  -> (!Bool,!Int,!*{#TIO_TypeReference},!*{Partition},!*BitSet,!*{#TIO_CommonDefs},!*TypeIOState)
			look_for_existing_partition i limit type_refs type_ref_partition_status is_type_already_checked tio_common_defs type_io_state
				| i == limit
					= (False,0,type_refs,type_ref_partition_status,is_type_already_checked,tio_common_defs,type_io_state)
					
				# (ith_type_ref_partition_status,type_ref_partition_status)
					= type_ref_partition_status![i];
				| isNotPartitioned_and_isNotBeingPartitioned ith_type_ref_partition_status
					= look_for_existing_partition (inc i) limit type_refs type_ref_partition_status is_type_already_checked tio_common_defs type_io_state
					
					// check that type in partion is equivalent to current type
					# partition_i = extractPartitionIn ith_type_ref_partition_status
					# (class_i_element,type_refs) = type_refs![i]; //partition_i]
					# (current_type_ref,type_refs) = type_refs![ith_type_ref]
	
					# (current_type_ref_belongs_to_parition_i,is_type_already_checked,tio_common_defs,type_io_state)
						= equal_types_TIO_TypeReference current_type_ref class_i_element is_type_already_checked tio_common_defs type_io_state;
					| current_type_ref_belongs_to_parition_i
						// current type is equivalent to other types in partition, mark them as such
						# (type_refs,type_ref_partition_status,is_type_already_checked,type_io_state)
							= mark_types_in_same_partition_as_equivalent (inc i) current_type_ref partition_i type_refs type_ref_partition_status is_type_already_checked type_io_state
						= (True,partition_i,type_refs,type_ref_partition_status,is_type_already_checked,tio_common_defs,type_io_state)

						= look_for_existing_partition (inc i) limit type_refs type_ref_partition_status is_type_already_checked tio_common_defs type_io_state
			where
				// updates the tis_is_type_already_checked table with current_type_ref and the existing type_refs in partition to
				// which the current_type_ref belongs.
				mark_types_in_same_partition_as_equivalent i current_type_ref partition_i type_refs type_ref_partition_status is_type_already_checked type_io_state
					| i == limit
						= (type_refs,type_ref_partition_status,is_type_already_checked,type_io_state)

					# (ith_type_ref_partition_status,type_ref_partition_status)
						= type_ref_partition_status![i]
					| isNotPartitioned_and_isNotBeingPartitioned ith_type_ref_partition_status
						= mark_types_in_same_partition_as_equivalent (inc i) current_type_ref partition_i type_refs type_ref_partition_status is_type_already_checked type_io_state
					| extractPartitionIn ith_type_ref_partition_status <> partition_i
						= mark_types_in_same_partition_as_equivalent (inc i) current_type_ref partition_i type_refs type_ref_partition_status is_type_already_checked type_io_state
						
						# (equivalent_type_ref,type_refs) = type_refs![i];
						# (bitset_index,type_io_state)
							= compute_index_in_type_cache current_type_ref equivalent_type_ref type_io_state;
						# is_type_already_checked = AddBitSet is_type_already_checked bitset_index;
						= mark_types_in_same_partition_as_equivalent (inc i) current_type_ref partition_i type_refs type_ref_partition_status is_type_already_checked type_io_state	
					
	collect_within_equally_named_types _ s
		= s

find_type2 :: !Int !*RTRState !*TypeIOState -> *(!TIO_TypeReference,!*RTRState,!*TypeIOState);
find_type2 type_name_offset rtrs=:{rtrs_current_icl_module} type_io_state=:{tis_string_table}
	# (ok,null_index)
		= CharIndex tis_string_table type_name_offset '\0';
	| not ok
		= abort "find_type2: internal error; type name did not terminate with NULL";
	# type_name = tis_string_table % (type_name_offset,dec null_index);
	# {rtrs_is_module_already_in_scope} = rtrs
	  rtrs = {rtrs & rtrs_is_module_already_in_scope = EmptyBitSet}
	# (tio_type_reference,rtrs_is_module_already_in_scope,rtrs,type_io_state)
		= find_type type_name rtrs_current_icl_module rtrs_is_module_already_in_scope rtrs type_io_state;
	  rtrs = {rtrs & rtrs_is_module_already_in_scope = rtrs_is_module_already_in_scope}
	= (tio_type_reference,rtrs,type_io_state);

find_type :: !{#Char} !Int !*BitSet !*RTRState !*TypeIOState -> *(!TIO_TypeReference,!*BitSet,!*RTRState,!*TypeIOState);
find_type type_name current_module_n is_module_already_in_scope rtrs type_io_state=:{tis_n_common_defs}
	# (found,hte,type_io_state)
		= type_io_find_name type_name type_io_state;
	| not found
		= abort ("find_type: type '" +++ type_name +++ "' could not be found");
	
	| isNoTypeName hte.hte_type_refs
		# tio_type_reference
			= { default_elem &
				tio_type_without_definition	= Just type_name
			};
		= (tio_type_reference,is_module_already_in_scope,rtrs,type_io_state);

	# {hte_type_refs=TypeName tio_type_references=:[_:_]}
		= hte;
	# (tio_type_reference,is_module_already_in_scope,rtrs)
		= find_type_in_scope tio_type_references is_module_already_in_scope rtrs;

	= (tio_type_reference,is_module_already_in_scope,rtrs,type_io_state);
where
	find_type_in_scope [] is_module_already_in_scope _
		// The order in which the compiler and linker see the modules which belong to a particular
		// project may be different. Therefore at compile-time references to symbols cannot be tied 
		// to their definitions.
		//
		// Obsolete and wrong:
		// The IDE guarantees the static linker that the object files and their corresponding tcl
		// files form an up-to-date project. If this error occurs then at least some of the tcl
		// files are corrupt.
		= abort "find_type_in_scope: internal error, some tcl-file is corrupt";
	find_type_in_scope [ref=:{tio_tr_module_n,tio_tr_type_def_n}:tio_type_references] is_module_already_in_scope rtrs
		| tio_tr_module_n == (-1)
			// a built-in type
			= (ref,is_module_already_in_scope,rtrs);
	
		| current_module_n == tio_tr_module_n 
			// a type within current module has been found
			= (ref,is_module_already_in_scope,rtrs);
		
		# (found,is_module_already_in_scope)
			= isBitSetMember is_module_already_in_scope tio_tr_module_n;
		# (tio_n_exported_com_type_defs,rtrs)
			= rtrs!rtrs_tio_common_defs.[tio_tr_module_n].tio_n_exported_com_type_defs
		
		| found && tio_tr_type_def_n < tio_n_exported_com_type_defs
			// There are two requiremens:
			// 1. the module tio_tr_module_n must be in the current scope
			// 2. the type definitions must be external
			= (ref,is_module_already_in_scope,rtrs);
			
			// module was not in scope
			| isEmpty tio_type_references
				= abort ("stop" +++ toString found +++ " " +++ toString tio_tr_module_n);
			= find_type_in_scope tio_type_references is_module_already_in_scope rtrs;
