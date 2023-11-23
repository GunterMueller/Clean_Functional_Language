implementation module directory_structure;

import StdEnv;
import Directory;
import StdMaybe;
import ExtFile;
from DynIDMacros import DS_LIBRARIES_DIR,DS_SYSTEM_DYNAMICS_DIR,ADD_CODE_LIBRARY_EXTENSION;

/* Directory structure:
**
** There's is a root-directory called 'Dynamics'. This directory
** contains the following file:
** - DynamicLinker.exe
**
** And the following subdirectories:
** - libraries
** - lazy dynamics
** - conversion
** - utilities
*/

ds_generate_unique_name application_name dir dynamic_linker_path files
	# (name,extension)
		= ExtractPathFileAndExtension application_name;
		
	# base_path_name
		= dynamic_linker_path +++ "\\" +++ dir +++ "\\" +++ name;
	= gen_unique_name 0 base_path_name extension files;
where {
	gen_unique_name i base_path_name extension files
		# path_name
			= base_path_name +++ "_" +++ toString i +++ "c." +++ extension;
		# ((ok,path),files)
			= pd_StringToPath path_name files;
		| not ok
			= abort "gen_unique_name: could not convert to path";
		
		# ((dir_error,_),files)
			= getFileInfo path files;
		| dir_error == DoesntExist 
			= (path_name,files);
			
		= gen_unique_name (inc i) base_path_name extension files;
};
	
// auxillary functions; create a directory
ds_create_directory :: !{#.Char} !{#.Char} !*a -> *(.(Maybe {#Char}),*a) | FileSystem a;
ds_create_directory directory dynamic_linker_path files
	#! directory_to_be_created
		= dynamic_linker_path +++ "\\" +++ directory;
	#! ((ok,path),files)
		= pd_StringToPath directory_to_be_created files;
	| not ok
		= (Just directory_to_be_created,files);
		
	#! (_,files)
		= createDirectory path files;
	= (Nothing,files);

// append to file name
ds_append_to_file_name suffix path_name_extension 
	# (path_name,extension)
		= ExtractPathFileAndExtension path_name_extension;
	= path_name +++ suffix +++ extension;
	
APPEND_LIBRARY_PATH ddir id :== ddir +++ "\\" +++ DS_LIBRARIES_DIR +++ "\\" +++ id;

APPEND_LAZY_DYNAMIC_PATH ddir id :== ddir +++ "\\" +++ DS_SYSTEM_DYNAMICS_DIR +++ "\\" +++ id +++ ".sysdyn";

