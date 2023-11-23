implementation module ddState;

// the executable may *never* be in the same folder as its project is because
// otherwise its project is taken to be proper project.
import StdEnv,StdMaybe,ArgEnv;
import read_dynamic,compute_graph,write_dynamic;
import memory,DynamicLinkerInterface,DynID;
import ExtFile,Directory,DefaultElem,pdExtFile,StdDynamicTypes;
import code from library "ClientChannel_library";

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
DefaultDDState mem
	= { DDState |
		file_name		= ""
	,	project_name	= ""
	,	first_time		= True
	
	,	mem				= mem
	,	int_descP		= 0
	,	char_descP		= 0
	,	bool_descP		= 0
	,	real_descP		= 0
	,	string_descP	= 0
	,	array_descP		= 0
	,	e__StdDynamic__rDynamicTemp	= 0
	,	build_block_label			= 0
	,	build_lazy_block_label		= 0
	,	type_cons_symbol_label		= 0
	
	,	dlink_dir					= ""

	,	current_dynamic				= default_elem
	};
	
InitialDDState :: !*Mem !*f -> (!Bool,[String],!*DDState,!*f) | FileSystem f;
InitialDDState mem f
	# cmd_line
		= getCommandLine;
	# (path,_)
		= ExtractPathAndFile cmd_line.[0];
	| not (ends path DS_UTILITIES_DIR)
		// dumpDynamic not in utilities-dir
		= abort "dumpDynamic should be in the utilities directory";
		
		// extract dynamics dir
		#! dlink_dir
			= path % (0,(size path) - 1 - (size DS_UTILITIES_DIR) - (size (toString path_separator)));
		#! ddState
			= { DefaultDDState mem & dlink_dir = dlink_dir };
		
		// check for dynamic linker		
		#! dlinker_path
			= dlink_dir +++ (toString path_separator) +++ DS_DYNAMIC_LINKER;
		#! ((ok,path),f)
			= pd_StringToPath dlinker_path f;
		#! ((dir_error,_),f)
			= getFileInfo path f;
		| dir_error <> NoDirError
			= abort ("dumpDynamic: dynamic linker cannot be found in '" +++ dlinker_path +++ "'");
			
		// setup registry correctly
		#! key_path
			= "prjfile\\shell\\dynamic link\\command\0";
		#! new_key
			= "\"" +++ dlinker_path +++ "\" /S \"%%1\"";
		#! b 
			= CleanNewKey key_path new_key;
		| b && size cmd_line == 1
			= (False,[],ddState,f);
			
		# system_dynamics_list
			= [ cmd_line.[i] \\ i <- [1..dec (size cmd_line)] ];
			
		= (False,system_dynamics_list,ddState,f);
where {
	doreqS :: !String -> String;
	doreqS s = 
		code { 
			ccall DoReqS "S-S"
		};
}
	
do_dynamic :: !*DDState !*a [String] (Maybe String) -> *(!*DDState,*a,[String]) | FileEnv, FileSystem a;
do_dynamic ddState=:{dlink_dir} files errors maybe_output_folder
	#! (file_name,ddState)
		= ddState!DDState.file_name;
	#! original_file_name = file_name;
		
	// check if system dynamic exists
	#! ((ok1,file_name),files)
		= FILE_IDENTIFICATION 
			(accFiles (get_system_dynamic_id file_name) files)
			// get_system_dynamic_identification1 file_name files) 
			((True,file_name),files)
			;
	#! ddState
		= { DDState | ddState & file_name = file_name };
	| not ok1
		#! error
			= "Error opening system dynamic of user dynamic '" +++ original_file_name +++ "'"
		= (ddState,files,[error:errors]);
			
	// read dynamic
	#! ((ok2,dynamic_info),files)
		= accFiles (read_dynamic file_name dlink_dir) files;
	| not ok2 || not ok1
		= abort ("error; error reading dynamic '" +++ file_name +++ "'");
	#! ddState = { ddState & current_dynamic = dynamic_info };


	// open file for writing ASCII representation
	#! (txt_file_name,files)
		= case maybe_output_folder of {
			Nothing
				-> (original_file_name +++ ".txt",files);
			Just output_folder
				#! (_,file_name_extension)
					= ExtractPathAndFile original_file_name;
				#! path_file_name
					= output_folder +++ "\\" +++ file_name_extension +++ ".txt"
				-> (path_file_name,files)
		};
		
	#! (ok1,file,files)
		= fopen txt_file_name FWriteText files;	
	| not ok1
		#! error
			= "Error: could not open '" +++ txt_file_name +++ "'";
		= (ddState,files,[error:errors]);

	// dump type&value; the first arg is ignored
	#! (nodes,desc_table,file,ddState,files)
		= do_look dynamic_info file ddState files;	

	// close file
	#! (ok2,files)
		= fclose file files
	= (ddState,files,errors);
where {
	get_system_dynamic_id file_name files
		#! (ok,file_name,files)
			= get_system_dynamic_identification file_name files;
		= ((ok,file_name),files);
		
	do_look :: !BinaryDynamic !*File !*DDState !*f -> *(*Nodes NodeKind,*DescriptorAddressTable,!*File,*DDState,!*f) | FileEnv f;
	do_look dynamic_info file ddState files
		#! file
			= WriteHeader  dynamic_info file;
					
		// internal computation
		#! (max_desc_name,max_mod_name,desc_table)
			= BuildDescriptorAddressTable  dynamic_info;
			
		#! (nodes,desc_table,ddState)
			= compute_nodes  desc_table dynamic_info ddState;
			

		#! file
			= fwritec '\n' file;
		#! (nodes,file,desc_table,ddState)
			= WriteGraph  desc_table dynamic_info nodes file ddState;

		#! file
			= fwritec '\n' file;
		#! file
			= WriteStringTable  dynamic_info file;
	
		#! file
			= fwritec '\n' file;
		#! (file,desc_table)
			= WriteDescriptorAddressTable max_desc_name max_mod_name dynamic_info desc_table file;

		#! file
			= fwritec '\n' file;
		#! file
			= WriteBlockTable dynamic_info file;

		# x = (WriteDynamicInfo dynamic_info.bd_dynamic_info file)
		# (file,files)
			= accFiles x files;

		= (nodes,desc_table,file,ddState,files);
}

replace_command_line :: !String -> Bool;
replace_command_line _
	= code {
		ccall replace_command_line "S-I"
	};
