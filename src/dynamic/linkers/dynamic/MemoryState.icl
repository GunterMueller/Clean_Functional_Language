implementation module MemoryState;

from StdReal import entier; // RWS marker

import StdMaybe;
import StdEnv;

::MemoryState
	= {
	// Library name
		ms_library_name			:: !String
	,	ms_type_table_index		:: !Maybe Int				// Index in TypeTable array
		
	// run-time memory areas
	,	ms_code_begin			:: !Int
	,	ms_code_end				:: !Int
	,	ms_data_begin			:: !Int
	,	ms_data_end				:: !Int	
	};

default_memory_state :: MemoryState;
default_memory_state
	= {
	// Library name
		ms_library_name			= ""
	,	ms_type_table_index		= Nothing					// Index in TypeTable array
		
	// run-time memory areas
	,	ms_code_begin			= 0
	,	ms_code_end				= 0
	,	ms_data_begin			= 0
	,	ms_data_end				= 0
	};

class GetTypeTableIndex a
where {
	get_type_table_index :: a [MemoryState] -> Maybe Int
};

instance GetTypeTableIndex Int
where {
	get_type_table_index address [{ms_type_table_index,ms_data_begin,ms_data_end}:mss]
		| ms_data_begin <= address && address <= ms_data_end
			| isNothing ms_type_table_index
				= abort "GetTypeTableIndex !Int: no ms_type_table_index";
				= ms_type_table_index
			= get_type_table_index address mss;
	get_type_table_index address []
		= abort ("address not found: " +++ toString address);
};