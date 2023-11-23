definition module MemoryState;

from StdMaybe import :: Maybe;

:: MemoryState
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

class GetTypeTableIndex a
where {
	get_type_table_index :: a [MemoryState] -> Maybe Int
};

instance GetTypeTableIndex Int;