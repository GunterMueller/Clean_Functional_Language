definition module ddState;

from StdFile import class FileEnv, class FileSystem;
from StdMaybe import :: Maybe;
from memory import :: Mem;
from read_dynamic import :: BinaryDynamic;

:: *DDState = {
		file_name					:: !String				// filename of dynamic
	,	project_name				:: !String				// filename of application using that dynamic
	,	first_time					:: !Bool				// first time
	,	mem							:: *Mem
	
	,	int_descP					:: !Int
	,	char_descP					:: !Int
	,	bool_descP					:: !Int
	,	real_descP					:: !Int
	,	string_descP				:: !Int
	,	array_descP					:: !Int
	,	e__StdDynamic__rDynamicTemp	:: !Int
	,	build_block_label			:: !Int
	,	build_lazy_block_label		:: !Int
	,	type_cons_symbol_label		:: !Int
	
	,	dlink_dir					:: !String
	
	,	current_dynamic				:: !BinaryDynamic
	};
		
DefaultDDState :: !*Mem -> *DDState;

InitialDDState :: !*Mem !*f -> (!Bool,[String],!*DDState,!*f) | FileSystem f;
	
do_dynamic :: !*DDState !*a [String] (Maybe String) -> *(!*DDState,*a,[String]) | FileEnv, FileSystem a;

replace_command_line :: !String -> Bool;


