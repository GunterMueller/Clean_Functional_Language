implementation module LibraryInstance;

import StdEnv;
import StdMaybe;
import StdDynamicLowLevelInterface;
import NamesTable;
import DefaultElem;
from DynID import extract_dynamic_or_library_identification;
from pdSymbolTable import ::LibraryList, EmptyLibraryList;

:: *LibraryInstance 
	= {	li_id				:: !String
	,	li_library_name		:: !String			// file name of library
	,	li_type_table_i		:: !Int				// index in cs_type_tables
	,	li_names_table		:: !*NamesTable		// names table
	,	li_library_list		:: !LibraryList
	,	li_library_initialized	:: !Bool		// names table is non-empty, marked_bool_a, marked_offset_a, etc. are adapted which is reflected in app_linker_state (DLClientState)
	,	li_memory_areas		:: [MemoryArea]
	};

:: MemoryArea
	= {	ma_begin			:: !Int
	,	ma_end				:: !Int
	};

default_library_instance :: *LibraryInstance;
default_library_instance
	= {	li_id				= "reset"
	,	li_library_name		= "reserved"
	,	li_type_table_i		= 0	
	,	li_names_table		= {}
	,	li_library_list		= EmptyLibraryList
	,	li_library_initialized	= False
	,	li_memory_areas		= []
	};

:: *LibraryInstances
	= {	lis_n_library_instances		:: !Int
	,	lis_library_instances		:: !*{#*LibraryInstance}
	,	lis_all_libraries :: !Libraries
	};

default_library_instances :: *LibraryInstances;
default_library_instances 
	= { 
		lis_n_library_instances		= RTID_LIBRARY_INSTANCE_ID_START
	,	lis_library_instances		= { default_library_instance\\ _ <- [0..dec RTID_LIBRARY_INSTANCE_ID_START]}
	,	lis_all_libraries = EmptyLibraries
	};

class Library_Instances a
where {
	AddLibraryInstance :: !(Maybe Int) !String !Int !*a -> (!Int,!*a)
};

instance Library_Instances LibraryInstances
where {
	AddLibraryInstance dynamic_index library_name type_table_i library_instances=:{lis_n_library_instances,lis_library_instances}
		# new_library_instance
			= { default_library_instance & 		
				li_id				= extract_dynamic_or_library_identification library_name
			,	li_library_name		= library_name
			,	li_type_table_i		= type_table_i
			};
		// enlarge library instance array & add new element
		# lis_library_instances
			= { extend_array 1 lis_library_instances & [lis_n_library_instances] = new_library_instance };		
		# library_instances
			= { library_instances &
				lis_n_library_instances		= inc lis_n_library_instances
			,	lis_library_instances		= lis_library_instances
			};
		= (lis_n_library_instances,library_instances);
};

instance DefaultElemU LibraryInstance
where {
	default_elemU = default_library_instance;
};

extend_array :: .Int *(a *b) -> *(c *b) | Array c b & Array a b & DefaultElemU b;
extend_array n_new_elements a 
	# (s_a,a) = usize a;
	= copy_array 0 s_a a { default_elemU \\ i <- [1..(s_a + n_new_elements)] };
where {
	copy_array i limit old_array new_array 
		| i == limit
			= new_array;
			# (elem,old_array) = replace old_array i default_elemU;	
			= copy_array (inc i) limit old_array {new_array & [i] = elem};
};
