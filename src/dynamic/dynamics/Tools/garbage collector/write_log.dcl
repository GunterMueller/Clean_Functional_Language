definition module write_log

from StdFile import class FileSystem
from StdMaybe import :: Maybe
from gc_state import :: State

:: Options
	= {
		// check options
		check_md5_system_dynamics					:: !Bool
	,	check_md5_system_libraries					:: !Bool
	
		// delete options (System)
	,	delete_unused_system_libraries 				:: !Bool
	,	delete_unused_system_dynamics				:: !Bool
	
	,	delete_unknown_files_in_system_folders		:: !Bool
	
		// delete options (User)
	,	delete_dangling_application_references		:: !Bool
	,	delete_dangling_dynamics_references			:: !Bool

		// really delete		
	,	really_delete								:: !Bool
			
		// log 
	,	log_path_name_ext							:: !Maybe String

	,	display_help								:: !Bool
	}	

initial_options :: Options	

write_log :: .Options !*State *a -> *a | FileSystem a
