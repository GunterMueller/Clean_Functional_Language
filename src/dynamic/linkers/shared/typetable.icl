implementation module typetable;

import type_io_read;
import StdMaybe;
import ExtArray;
from type_io_common import PredefinedModuleName, UnderscoreSystemModule;
import predefined_types;
import utilities;
import DefaultElem;
import StdDynamicTypes;

:: *TypeTable = {
	// Name
		tt_name					:: !String
	,	tt_loaded				:: !Bool				// type tables are loaded lazily
	// type information
	,	tt_type_io_state		:: !*TypeIOState
	,	tt_tio_common_defs		:: !*{#TIO_CommonDefs}
	,	tt_n_tio_common_defs	:: !Int
	// library info; should move to .lib
	, 	tt_rti					:: RTI
		// hash 
	,	tt_hash_table			:: !{#{#TypeTableHashElement}}
	};

:: HashTable :== {#{#TypeTableHashElement}};

default_type_table :: *TypeTable;
default_type_table = {
	// Name
		tt_name					= {}
	,	tt_loaded				= False
	// type information
	,	tt_type_io_state		= default_type_io_state
	,	tt_tio_common_defs		= {}
	,	tt_n_tio_common_defs	= 0	
	// library info
	,	tt_rti					= default_RTI
	// hash 
	,	tt_hash_table			= {}
	};

:: TypeTableHashElement
	= {
		tthe_module_index	:: !Int								// stringtable index for Module
	,	tthe_kind			:: !TypeTableHashElementNameKind	// for Type and Constructor
	};
	
:: TypeTableHashElementNameKind
	= TTHE_ModuleName
	| TTHE_TypeName !TIO_TypeReference	!Int				// type reference, stringtable index of Type name
	| TTHE_ConstructorName !TIO_TypeReference !Int			// constructor type reference, stringtable index of Constructor name
	| TTHE_PredefinedConstructorName !TIO_TypeReference		// isTypeWithoutDefinition must return True on the type reference
	; 
		
instance DefaultElem TypeTableHashElement
where {
	default_elem
		= {
			tthe_module_index		= -20
		,	tthe_kind		= TTHE_ModuleName
		};
};

class TypeTableOps s
where {
	AddReferenceToTypeTable :: !String !*s -> (!Int,!*s);
	
	AddTypeTable :: !Int *TypeTable !*s -> *s
};

import RWSDebugChoice;

instance TypeTableOps ({#*TypeTable})
where {
	AddReferenceToTypeTable type_table_reference array
		# (array,result)
			= loopAfill lookup_type_table_reference array Nothing;
		| isJust result
			= (fromJust result,array);

			= add_reference_to_type_table type_table_reference array;
	where {
		lookup_type_table_reference i a s=:(Just _)
			= (a,s);
		lookup_type_table_reference i a s
			# (tt_name,a)
				= a![i].tt_name;
			| tt_name == type_table_reference
				= (a,Just i);
				= (a,s);
				
		add_reference_to_type_table type_table_reference cs_type_tables
			# (s_old_cs_type_tables,cs_type_tables)
				= usize cs_type_tables;
			# new_cs_type_tables
				= copy_array 0 s_old_cs_type_tables cs_type_tables { default_type_table \\ i <- [0..s_old_cs_type_tables] };
			# cs_new_type_table
				= { default_type_table &
					tt_name		= type_table_reference 
				};
				
			= (s_old_cs_type_tables,{ new_cs_type_tables & [s_old_cs_type_tables] = cs_new_type_table});
		where {
			copy_array i limit old_array new_array 
				| i == limit
					= new_array;
		
					# (elem,old_array)
						= replace old_array i default_type_table;	
					= copy_array (inc i) limit old_array {new_array & [i] = elem};
		} // add_reference_to_type_table

	} // Add ReferenceToTypeTable
	
	AddTypeTable type_table_index type_table=:{tt_n_tio_common_defs,tt_type_io_state={tis_string_table}} a
		# hash_table
			= { [] \\ i <- [0 .. dec cHashTableSize] }; 
		# (hash_table,type_table)
			= loopAst loop_on_module (hash_table,type_table) tt_n_tio_common_defs;

		# hash_table
			= foldSt enter_predefined_type PredefinedTypes hash_table;

		# hash_table
			= { { element \\ element <- list }  \\ list <-: hash_table };

		# (tt_name,a)
			= a![type_table_index].tt_name;
		# type_table
			= { type_table &
				tt_name			= tt_name
			,	tt_loaded		= True
			,	tt_hash_table	= hash_table
			};
		= { a & [type_table_index] = type_table };
	where {
		enter_predefined_type :: !PredefinedType !*{[TypeTableHashElement]} -> *{[TypeTableHashElement]};
		enter_predefined_type {pt_type_name,pt_constructor_names} hash_table
			# type_without_definition
				= TTHE_PredefinedConstructorName (makeTypeWithoutDefinition pt_type_name);
			= foldSt (\constructor_name hash_table -> enter_name_in_hash_table constructor_name default_elem type_without_definition hash_table) pt_constructor_names hash_table;
		
		loop_on_module tio_tr_module_n (hash_table,type_table)
			// enter module name
			# (tio_module,type_table)
				= type_table!tt_tio_common_defs.[tio_tr_module_n].tio_module;
			# module_name
				= get_name_from_string_table tio_module tis_string_table;
			# hash_table
				= enter_name_in_hash_table module_name tio_module TTHE_ModuleName hash_table;

			// loop on type definitions
			# (tio_com_type_defs,type_table)
				= type_table!tt_tio_common_defs.[tio_tr_module_n].tio_com_type_defs;
			# (_,hash_table,type_table)
				= mapAiSt loop_on_type_defs tio_com_type_defs (tio_module,hash_table,type_table);
				
			// loop on constructor definitons
			# (tio_com_cons_defs,type_table)
				= type_table!tt_tio_common_defs.[tio_tr_module_n].tio_com_cons_defs;
			# (_,hash_table,type_table)
				= mapAiSt loop_on_cons_defs tio_com_cons_defs (tio_module,hash_table,type_table);
			= (hash_table,type_table);
		where {
			loop_on_type_defs tio_tr_type_def_n {tio_td_name} (tio_module,hash_table,type_table)
				# tio_type_ref
					= { default_elem &
						tio_tr_module_n		= tio_tr_module_n
					,	tio_tr_type_def_n	= tio_tr_type_def_n
					};
				# q
					= get_name_from_string_table tio_td_name tis_string_table;
					
				# hash_table
					= enter_name_in_hash_table (q) tio_module (TTHE_TypeName tio_type_ref tio_td_name) hash_table;
				= (tio_module,hash_table,type_table);
				
			loop_on_cons_defs tio_tr_type_def_n {tio_cons_symb,tio_cons_type_index} (tio_module,hash_table,type_table)
				// reference to type definition of the constructor
				# tio_type_ref
					= { default_elem &
						tio_tr_module_n		= tio_tr_module_n
					,	tio_tr_type_def_n	= tio_cons_type_index
					};
				# x
					= get_name_from_string_table tio_cons_symb tis_string_table;
				# hash_table
					= enter_name_in_hash_table (x) tio_module (TTHE_ConstructorName tio_type_ref tio_cons_symb) hash_table;
				= (tio_module,hash_table,type_table);
				
		}; // loop_on_module
	}; // AddTypeTable
}; //gettypetable

enter_name_in_hash_table name module_index_in_stringtable tthe_kind hash_table
	# hash_value_of_name
		= hashValue name;
	# (hash_table_elements,hash_table)
		= hash_table![hash_value_of_name];
		
	# type_table_hash_element
		= { default_elem &
			tthe_module_index	= module_index_in_stringtable
		,	tthe_kind	= tthe_kind
		};
	= { hash_table & [hash_value_of_name] = [type_table_hash_element:hash_table_elements] };
 
// HASH TABLE IMPLEMENTATION
cHashTableSize	:==	1023;

hashValue :: !String -> Int;
hashValue name
	# hash_val = hash_value name (size name) 0 rem cHashTableSize;
	| hash_val < 0
		= hash_val + cHashTableSize;
		= hash_val;
where {
	hash_value :: !String !Int !Int -> Int;
	hash_value name index val
		| index == 0
			= val;
		# index = dec index;
		  char = name.[index];
		= hash_value name index (val << 2 + toInt char);
};

class findTypeUsingTypeName s :: !String !String !Int !*s -> (!Maybe TIO_TypeReference,!*s);

instance findTypeUsingTypeName {#TypeTable}
where {
	findTypeUsingTypeName type_name module_name type_table_i type_tables
		| module_name == PredefinedModuleName
			# tio_type_reference
				= { default_elem & tio_type_without_definition = Just type_name};
			= (Just tio_type_reference,type_tables);
			
		// get string index for module name
		# (maybe_module_name_string_index,type_tables)
			= findModuleName module_name type_table_i type_tables;
		| isNothing maybe_module_name_string_index
			= abort ("stoppen" +++ type_name +++ " - " +++ module_name +++ " , " +++ toString type_table_i);
		
		# module_name_string_index
			= fromJust maybe_module_name_string_index;
			
		// find type name
		# (hash_entries,type_tables)
			= type_tables![type_table_i].tt_hash_table.[hashValue type_name];
		# (string_table,type_tables)
			= type_tables![type_table_i].tt_type_io_state.tis_string_table;
		# result
			= findAi (find_type_name string_table module_name_string_index) hash_entries;
		= (result,type_tables);
	where {
		find_type_name string_table module_name_string_index _ {tthe_module_index,tthe_kind=TTHE_TypeName tio_type_ref type_name_string_table_index}
			# type_name2
				= get_name_from_string_table type_name_string_table_index string_table
			| module_name_string_index == tthe_module_index && type_name2 == type_name
				= Just tio_type_ref;
				= Nothing;
		find_type_name _ _ _ _
			= Nothing;
	};
};

class findTypeUsingConstructorName s :: !String !String !Int !*s -> (!Maybe TIO_TypeReference,!*s);

instance findTypeUsingConstructorName {#TypeTable}
where {
	 findTypeUsingConstructorName constructor_name module_name type_table_i type_tables
		// find type name
		# (hash_entries,type_tables)
			= type_tables![type_table_i].tt_hash_table.[hashValue constructor_name];
		# (string_table,type_tables)
			= type_tables![type_table_i].tt_type_io_state.tis_string_table;

		# (result,type_tables)
			= case module_name == UnderscoreSystemModule of {
				False	
					// get string index for module name
					# (Just module_name_string_index,type_tables)
						= findModuleName module_name type_table_i type_tables
					-> (findAi (find_constructor_name string_table module_name_string_index) hash_entries,type_tables);
				True	
					-> (findAi (find_predefined_constructor_name string_table) hash_entries,type_tables);
			};
		= (result,type_tables);
	where {
		find_constructor_name string_table module_name_string_index _ {tthe_module_index,tthe_kind=TTHE_ConstructorName tio_type_ref constructor_name_string_table_index}
			# constructor_name2
				= get_name_from_string_table constructor_name_string_table_index string_table
			| module_name_string_index == tthe_module_index && constructor_name2 == constructor_name // <<- constructor_name2
				= Just tio_type_ref;
				= Nothing;
		find_constructor_name _ _ _ _
			= Nothing;
				
		find_predefined_constructor_name string_table _ {tthe_kind=TTHE_PredefinedConstructorName tio_type_ref=:{tio_type_without_definition=Just constructor_name2}}
			| constructor_name2 == constructor_name
				= Just tio_type_ref;
				= Nothing;
		find_predefined_constructor_name string_table _ _
			= Nothing;
	};
};

class findModuleName s :: !String !Int !*s -> (!Maybe Int,!*s);

instance findModuleName {#TypeTable}
where {
	findModuleName module_name type_table_i type_tables
		# (hash_entries,type_tables)
			= type_tables![type_table_i].tt_hash_table.[hashValue module_name];
		# (string_table,type_tables)
			= type_tables![type_table_i].tt_type_io_state.tis_string_table;
		# result
			= findAi (find_module_name string_table) hash_entries;
		= (result,type_tables) ;
	where {
		find_module_name string_table _ {tthe_module_index,tthe_kind=TTHE_ModuleName}
			# module_name2
				= get_name_from_string_table tthe_module_index string_table
			| module_name == module_name2
				= Just tthe_module_index
				= Nothing;
		find_module_name string_table _ _
			= Nothing;
	};
};

