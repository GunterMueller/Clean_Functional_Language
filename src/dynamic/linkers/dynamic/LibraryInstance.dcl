definition module LibraryInstance;

from StdMaybe import :: Maybe;
from NamesTable import :: NamesTable, :: SNamesTable, :: NamesTableElement;
from pdSymbolTable import ::LibraryList;

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
	
:: *LibraryInstances
	= {	lis_n_library_instances		:: !Int
	,	lis_library_instances		:: !*{#*LibraryInstance}
	,	lis_all_libraries :: !Libraries
	};

::	Libraries = Libraries !LibraryList !Libraries | EmptyLibraries;

default_library_instances :: *LibraryInstances;

class Library_Instances a
where {
	AddLibraryInstance :: !(Maybe Int) !String !Int !*a -> (!Int,!*a)
};

instance Library_Instances LibraryInstances;
